// Écrivain ISO 2709 (H23, 28/09/2026) — l'inverse de parseMarcIso2709 (marc.ts).
//
// Une notice au modèle commun ({ leader, fields }) devient un enregistrement
// ISO 2709 : guide de 24 caractères, répertoire (zone, longueur, position),
// puis les zones. Les LONGUEURS ET POSITIONS SE COMPTENT EN OCTETS UTF-8, pas
// en caractères : « Černá » fait 5 caractères et 6 octets ; un lecteur qui se
// fie au répertoire (PMB, yaz) couperait la notice suivante au mauvais endroit.
//
// Limites du format : 9 999 octets par zone (4 chiffres), 99 999 par notice
// (5 chiffres). Une zone trop longue à une seule sous-zone (une note) est
// découpée en zones répétées ; une notice trop longue perd d'abord les zones
// réémises de l'origine, puis les notes ; si elle déborde encore, elle est
// écartée et le rapport le dit — jamais un enregistrement faux.
//
// H26 (mesure du 28/09) : chaque zone est assemblée en texte et mesurée par un
// compte d'octets sans allocation ; la notice entière n'est encodée qu'une fois
// (des milliers de petits encodages coûtaient 0,5 ms par notice).
import type { ChampMarc, NoticeMarc } from './ecriture.ts';

const FT = '\x1e'; // fin de zone
const SD = '\x1f'; // début de sous-zone
const RT = '\x1d'; // fin d'enregistrement
const enc = new TextEncoder();

export interface Avertissement { notice: number; message: string }
export interface ResultatIso { octets: Uint8Array; ecrites: number; avertissements: Avertissement[] }

// Les trois séparateurs du format ne peuvent pas figurer dans une valeur.
const SEPARATEURS = /[\x1d\x1e\x1f]|\r\n?/;
function propre(v: string): string {
  return SEPARATEURS.test(v) ? v.replace(/[\x1d\x1e\x1f]/g, ' ').replace(/\r\n?/g, '\n') : v;
}

// Longueur UTF-8 d'une chaîne, sans l'encoder (une moitié de paire de
// substitution isolée s'encode en U+FFFD : 3 octets, comme TextEncoder).
export function octetsUtf8(s: string): number {
  let n = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c < 0x80) n += 1;
    else if (c < 0x800) n += 2;
    else if (c >= 0xd800 && c <= 0xdbff && i + 1 < s.length) {
      const d = s.charCodeAt(i + 1);
      if (d >= 0xdc00 && d <= 0xdfff) { n += 4; i++; } else n += 3;
    } else n += 3;
  }
  return n;
}

function texteZone(f: ChampMarc): string {
  if (typeof f.value === 'string') return propre(f.value) + FT;
  let s = ((f.ind1 || ' ')[0] ?? ' ') + ((f.ind2 || ' ')[0] ?? ' ');
  for (const sz of f.subfields ?? []) s += SD + (sz.code[0] ?? ' ') + propre(sz.value);
  return s + FT;
}

// Coupe une chaîne en morceaux d'au plus `max` octets UTF-8, sans couper un
// caractère (ni une paire de substitution).
export function couperOctets(v: string, max: number): string[] {
  const out: string[] = [];
  let cur = '';
  let n = 0;
  for (const ch of v) {
    const l = octetsUtf8(ch);
    if (n + l > max && cur) { out.push(cur); cur = ''; n = 0; }
    cur += ch; n += l;
  }
  if (cur || !out.length) out.push(cur);
  return out;
}

const MAX_ZONE = 9999;
const MAX_NOTICE = 99999;

interface Zone { champ: ChampMarc; texte: string; octets: number }
const zoneDe = (champ: ChampMarc): Zone => { const texte = texteZone(champ); return { champ, texte, octets: octetsUtf8(texte) }; };

// Coupe une note trop longue d'abord après une fin de phrase, sinon sur un
// blanc, dans la seconde moitié du morceau ; sinon au caractère. L'import
// rejoint les zones répétées par une ligne vide : une coupe en plein mot y
// reviendrait en deux paragraphes.
export function couperAuxBlancs(v: string, max: number): string[] {
  const out: string[] = [];
  let reste = v;
  while (octetsUtf8(reste) > max) {
    const tete = couperOctets(reste, max)[0];
    const moitie = tete.length / 2;
    const fin = Math.max(tete.lastIndexOf('. '), tete.lastIndexOf('\n'));
    const blanc = Math.max(tete.lastIndexOf(' '), tete.lastIndexOf('\n'));
    const i = fin > moitie ? fin + 1 : blanc > moitie ? blanc : tete.length;
    out.push(tete.slice(0, i).trim());
    reste = reste.slice(i).trim();
  }
  if (reste || !out.length) out.push(reste);
  return out;
}

// Une zone trop longue : découpée en zones répétées si elle n'a qu'une
// sous-zone ; sinon ses plus longues valeurs sont raccourcies, ou retirées,
// jusqu'à ce qu'elle tienne (et c'est dit).
function zonesTenantes(f: ChampMarc, idx: number, av: Avertissement[]): Zone[] {
  const z = zoneDe(f);
  if (z.octets <= MAX_ZONE) return [z];
  if (typeof f.value === 'string') {
    av.push({ notice: idx, message: `zone ${f.tag} tronquée (${z.octets} octets)` });
    return [zoneDe({ ...f, value: couperOctets(f.value, MAX_ZONE - 10)[0] })];
  }
  const subs = f.subfields ?? [];
  if (subs.length === 1) {
    const morceaux = couperAuxBlancs(subs[0].value, MAX_ZONE - 10);
    av.push({ notice: idx, message: `zone ${f.tag} découpée en ${morceaux.length} zones (${z.octets} octets)` });
    return morceaux.map((morceau) => zoneDe({ ...f, subfields: [{ code: subs[0].code, value: morceau }] }));
  }
  let cur = subs.map((s) => ({ code: s.code, value: s.value }));
  let r = z;
  const codes = new Set<string>();
  while (r.octets > MAX_ZONE && cur.length) {
    let plus = 0;
    cur.forEach((s, i) => { if (octetsUtf8(s.value) > octetsUtf8(cur[plus].value)) plus = i; });
    const garde = octetsUtf8(cur[plus].value) - (r.octets - (MAX_ZONE - 10));
    codes.add(cur[plus].code);
    cur = garde > 0
      ? cur.map((s, i) => (i === plus ? { code: s.code, value: couperOctets(s.value, garde)[0] } : s))
      : cur.filter((_, i) => i !== plus);
    r = zoneDe({ ...f, subfields: cur });
  }
  av.push({ notice: idx, message: `zone ${f.tag} $${[...codes].join(' $')} tronquée (${z.octets} octets)` });
  return cur.length ? [r] : [];
}

// → { texte, octets } de l'enregistrement entier.
function assembler(notice: NoticeMarc, zones: Zone[]): { texte: string; octets: number } {
  const base = 24 + 12 * zones.length + 1;
  let pos = 0;
  let rep = '';
  let corps = '';
  for (const z of zones) {
    rep += z.champ.tag.slice(0, 3).padStart(3, '0') + String(z.octets).padStart(4, '0') + String(pos).padStart(5, '0');
    pos += z.octets;
    corps += z.texte;
  }
  const longueur = base + pos + 1;
  const g = (notice.leader || '').padEnd(24, ' ').slice(0, 24);
  // Le guide et le répertoire sont en ASCII : un octet par caractère.
  const guide = String(longueur).padStart(5, '0') + g.slice(5, 10) + '22' + String(base).padStart(5, '0') + g.slice(17);
  return { texte: guide + rep + FT + corps + RT, octets: longueur };
}

export function ecrireIso2709(notices: NoticeMarc[]): ResultatIso {
  const av: Avertissement[] = [];
  const sorties: string[] = [];
  notices.forEach((n, idx) => {
    let zones = n.fields.flatMap((f) => zonesTenantes(f, idx, av));
    let rec = assembler(n, zones);
    if (rec.octets > MAX_NOTICE) {
      zones = zones.filter((z) => !z.champ.origine);
      rec = assembler(n, zones);
      if (rec.octets <= MAX_NOTICE) av.push({ notice: idx, message: 'zones de l\'origine non réémises (notice trop longue)' });
    }
    if (rec.octets > MAX_NOTICE) {
      zones = zones.filter((z) => !z.champ.note);
      rec = assembler(n, zones);
      if (rec.octets <= MAX_NOTICE) av.push({ notice: idx, message: 'notes non écrites (notice trop longue)' });
    }
    if (rec.octets > MAX_NOTICE) {
      av.push({ notice: idx, message: `notice écartée : ${rec.octets} octets, au-delà des 99 999 du format` });
      return;
    }
    // Garde : une zone de plus de 9 999 octets écrirait un répertoire faux.
    if (zones.some((z) => z.octets > MAX_ZONE)) {
      av.push({ notice: idx, message: 'notice écartée : une zone dépasse 9 999 octets' });
      return;
    }
    sorties.push(rec.texte);
  });
  return { octets: enc.encode(sorties.join('')), ecrites: sorties.length, avertissements: av };
}
