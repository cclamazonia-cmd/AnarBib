// Écriture MARC — le miroir de la lecture (H23, aller-retour PMB, 28/09/2026).
//
// Une notice d'export (la forme que rend public.fn_export_catalog_lote, H24)
// devient une notice au MODÈLE COMMUN de l'import (marc.ts) :
//   { leader, fields: [{ tag, value } | { tag, ind1, ind2, subfields: [{ code, value }] }] }
// en UNIMARC ou en MARC21, d'après la table partagée avec l'import
// (correspondance.ts) : chaque champ AnarBib s'écrit dans la PREMIÈRE zone
// que l'import lit pour lui. Les écrivains ISO 2709 et MARCXML (iso2709.ts,
// marcxml.ts) sérialisent ce modèle ; l'import le relit tel quel.
//
// Ce que l'import a rangé dans les notes, l'export le rend à sa zone : la ligne
// « Endereço eletrônico: … » redevient une 856, « Assuntos importados: … » des
// 606 (vedette -- subdivisions). Des paragraphes de note identiques à une 330
// ou à une 327 de l'enregistrement d'origine y retournent ; les autres vont en
// 300 / 500.
//
// Réémission prudente (décision du 28/09, H24, REGISTRE IMP-22) : pour la
// bibliothèque d'où vient la notice, et dans le même dialecte, les zones de
// l'enregistrement d'origine que l'import ne lit PAS (ni champ, ni sujet, ni
// responsabilité, ni exemplaire) ressortent telles quelles. Une zone
// qu'AnarBib tient ne ressort jamais de l'origine : une valeur retouchée
// depuis l'import ne peut pas être contredite par une valeur périmée. De
// l'origine, l'export reprend aussi ce qui ne contredit rien : les types de
// subdivision d'un sujet dont la chaîne est inchangée, les dates d'une
// personne que la fiche d'autorité ne donne pas, le type d'enregistrement du
// guide (carte, musique…) quand il dit encore le type qu'AnarBib tient.
import {
  CHAMPS, SUJETS, SEPARATEUR_SUBDIVISION, RESPONSABILITES, CODE_ROLE, roleDepuisCode, codeRelation,
  DEFAULT_ITEM_MAPPINGS, guidePourType, typeDepuisGuide, type Dialecte,
} from './correspondance.ts';

export interface SousZone { code: string; value: string }
// origine : réémise de l'enregistrement d'origine ; note : une note (ce que
// l'écrivain ISO 2709 laisse tomber en premier si la notice est trop longue).
export interface ChampMarc { tag: string; value?: string; ind1?: string; ind2?: string; subfields?: SousZone[]; origine?: boolean; note?: boolean }
export interface NoticeMarc { leader: string; fields: ChampMarc[] }

export interface Contributeur {
  name: string; nature?: string | null; role?: string | null; roleCode?: string | null;
  primary?: boolean; authorId?: number | string | null; dates?: string | null;
}
export interface Exemplaire { tombo?: string | null; code?: string | null; callNumber?: string | null; note?: string | null }
export interface Sujet { id?: number | string | null; label: string }
export interface NoticeExport {
  id?: number | string; bibRef?: string | null; originId?: string | null;
  externalIds?: { scheme?: string; label?: string; value: string }[];
  title?: string | null; subtitle?: string | null; responsibility?: string | null; volume?: string | null;
  edition?: string | null; place?: string | null; publisher?: string | null; year?: string | number | null;
  isbn?: string | null; issn?: string | null; language?: string | null;
  pages?: number | string | null; articlePages?: string | null; cdd?: string | null; collection?: string | null;
  materialType?: string | null; notes?: string | null; url?: string | null; keyTitle?: string | null;
  host?: { title?: string | null; volume?: string | null; issn?: string | null } | null;
  issue?: { number?: string | null; date?: string | null; title?: string | null } | null;
  work?: { id?: number | string | null; title?: string | null } | null;
  serial?: { id?: number | string | null; title?: string | null; issn?: string | null } | null;
  contributors?: Contributeur[]; authors?: { name: string; role?: string | null; ord?: number }[];
  subjects?: (string | Sujet)[]; keywords?: string[];
  items?: Exemplaire[];
  // itemTag : la zone d'exemplaire que l'import a lue (995, 852, ou celle du
  // profil) : elle ne ressort jamais de l'origine.
  source?: { dialect?: string; leader?: string | null; itemTag?: string | null; fields?: ChampMarc[] } | null;
}
export interface OptionsEcriture {
  dialecte: Dialecte;
  date?: string;                  // AAAAMMJJ (100 $a, 008, 801 $c) ; défaut : aujourd'hui
  bibliotheque?: { nom?: string | null; pays?: string | null; langue?: string | null } | null;
}

// ── Petits outils ───────────────────────────────────────────────────────────
function txt(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s.length ? s : null;
}
function sz(code: string, value: unknown): SousZone | null {
  const v = txt(value);
  return v === null ? null : { code, value: v };
}
function champ(tag: string, ind: string, subs: (SousZone | null)[]): ChampMarc | null {
  const s = subs.filter((x): x is SousZone => x !== null);
  return s.length ? { tag, ind1: ind[0] ?? ' ', ind2: ind[1] ?? ' ', subfields: s } : null;
}
function zone(d: Dialecte, cle: string): [string, string] | null {
  const z = CHAMPS[d][cle]?.zones?.[0];
  return z ? [z[0], z[1]] : null;
}

// Indicateurs par zone : ceux qu'écrit PMB 8.1 en UNIMARC (fixtures
// tests/pmb), les usuels en MARC21. Défaut : deux blancs.
const INDICATEURS: Record<Dialecte, Record<string, string>> = {
  unimarc: { '101': '0 ', '200': '1 ', '225': '2 ', '410': ' 0', '461': ' 0', '463': ' 0', '500': '10',
    '610': '0 ', '700': ' 1', '701': ' 1', '702': ' 1', '801': ' 3', '856': '4 ' },
  marc21: { '041': '0 ', '082': '04', '222': ' 0', '245': '10', '264': ' 1', '490': '0 ', '505': '0 ',
    '130': '0 ', '240': '10', '773': '0 ', '856': '4 ' },
};
const ind = (d: Dialecte, tag: string) => INDICATEURS[d][tag] ?? '  ';

// Langues : AnarBib tient du BCP-47 (books.idioma : pt-BR, es, fr…) ; 101 $a,
// 041 $a, 008/35-37 et 100 $a/22-24 veulent l'ISO 639-2/B (por, spa, fre).
// Les 36 langues de src/lib/languages.js. Inconnue : ni 101 ni 041.
const ISO639_2B: Record<string, string> = {
  'pt-BR': 'por', pt: 'por', ar: 'ara', bg: 'bul', ca: 'cat', cs: 'cze', da: 'dan', de: 'ger', el: 'gre', en: 'eng',
  eo: 'epo', es: 'spa', eu: 'baq', fa: 'per', fi: 'fin', fr: 'fre', gl: 'glg', he: 'heb', hi: 'hin', hr: 'hrv',
  hu: 'hun', id: 'ind', it: 'ita', ja: 'jpn', ko: 'kor', nb: 'nob', nl: 'dut', oc: 'oci', pl: 'pol', ro: 'rum',
  ru: 'rus', sk: 'slo', sr: 'srp', sv: 'swe', tr: 'tur', uk: 'ukr', zh: 'chi',
};
export function codeLangue(v: unknown): string | null {
  const t = txt(v);
  if (!t) return null;
  if (/^[A-Za-z]{3}$/.test(t)) return t.toLowerCase();
  return ISO639_2B[t] ?? ISO639_2B[t.split('-')[0].toLowerCase()] ?? null;
}

// Pays (801 $a, obligatoire en UNIMARC) : libraries.country est un texte libre
// (« Brasil », « France ») ; un code à deux lettres passe tel quel.
const PAYS_ISO: Record<string, string> = {
  brasil: 'BR', brazil: 'BR', bresil: 'BR', brasile: 'BR', brasilien: 'BR',
  france: 'FR', franca: 'FR', francia: 'FR', frankreich: 'FR', frankrijk: 'FR',
  belgium: 'BE', belgique: 'BE', belgie: 'BE', belgica: 'BE', belgio: 'BE', belgien: 'BE',
  portugal: 'PT', espana: 'ES', spain: 'ES', espanha: 'ES', italia: 'IT', italy: 'IT',
  suisse: 'CH', switzerland: 'CH', argentina: 'AR', uruguay: 'UY', chile: 'CL', mexico: 'MX',
  germany: 'DE', deutschland: 'DE', alemanha: 'DE', greece: 'GR', ellada: 'GR',
  nederland: 'NL', netherlands: 'NL', catalunya: 'ES',
};
export function codePays(v: unknown): string | null {
  const t = txt(v);
  if (!t) return null;
  if (/^[A-Za-z]{2}$/.test(t)) return t.toUpperCase();
  return PAYS_ISO[t.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase()] ?? null;
}

function aujourdhui(): string {
  return new Date().toISOString().slice(0, 10).replace(/-/g, '');
}

// ── Les notes : paragraphes, et ce que l'import y avait rangé ───────────────
const RE_ADRESSE = /^Endereço eletrônico: (\S+)$/;
const RE_SUJETS = /^Assuntos importados: (.*?)(?: (Classificação \/ cote local preservada da parceira: .*))?$/s;
// H27 : les mots-clés libres (610 / 653) que l'import range à part des vedettes.
const RE_MOTS_CLES = /^Palavras-chave importadas: (.*)$/s;
const paragraphes = (t: string) => t.replace(/\r\n?/g, '\n').split(/\n[ \t]*\n/).map((x) => x.trim()).filter(Boolean);

interface NotesDepliees { paragraphes: string[]; adresses: string[]; sujets: string[]; motsCles: string[] }
export function deplierNotes(notes: unknown): NotesDepliees {
  const out: NotesDepliees = { paragraphes: [], adresses: [], sujets: [], motsCles: [] };
  const t = txt(notes);
  if (!t) return out;
  for (const p of paragraphes(t)) {
    const a = p.match(RE_ADRESSE);
    if (a) { out.adresses.push(a[1]); continue; }
    const k = p.match(RE_MOTS_CLES);
    if (k) {
      for (const x of k[1].split(/\s*;\s+/)) { const v = txt(x); if (v) out.motsCles.push(v); }
      continue;
    }
    const s = p.match(RE_SUJETS);
    if (s) {
      for (const x of s[1].split(/\s*;\s+/)) { const v = txt(x); if (v) out.sujets.push(v); }
      if (s[2]) out.paragraphes.push(s[2].trim());
      continue;
    }
    out.paragraphes.push(p);
  }
  return out;
}

// ── Responsabilités ─────────────────────────────────────────────────────────
function contributeurs(rec: NoticeExport): Contributeur[] {
  if (Array.isArray(rec.contributors) && rec.contributors.length) {
    return rec.contributors.filter((c) => txt(c?.name));
  }
  // Forme d'avant H24 : des noms seuls, la première en principale.
  const a = Array.isArray(rec.authors) ? [...rec.authors] : [];
  a.sort((x, y) => (x?.ord ?? 0) - (y?.ord ?? 0));
  return a.filter((x) => txt(x?.name)).map((x, i) => ({ name: String(x.name), nature: 'person', role: 'autor', primary: i === 0 }));
}

// Le code de fonction : celui d'origine s'il est de ce dialecte et dit encore
// le rôle qu'AnarBib tient ; sinon celui de la table (CODE_ROLE).
export function codeFonction(d: Dialecte, c: Contributeur): string {
  const role = txt(c.role) || 'autor';
  const code = (txt(c.roleCode) || '').toLowerCase();
  const forme = d === 'unimarc' ? /^\d{3}$/ : /^[a-z]{3}$/;
  if (forme.test(code) && roleDepuisCode(d, code) === role) return code;
  return CODE_ROLE[d][role] ?? CODE_ROLE[d].outro;
}

const AUTEURS = new Set(['autor', 'coautor', 'organizacao']);

// Le numéro d'une fiche d'autorité : la 001 de l'export d'autorités (H25) et le
// $3 qui y mène depuis une notice. Préfixé (revue du 28/09) : PMB cherche un
// numéro favori sans filtrer l'origine (import_func.inc.php, keep_authority_
// infos) — un « 12 » nu retrouverait l'auteur 12 d'une autre origine. Jamais
// 14 caractères : authority_import::format_authority_number tronque une 001 de
// 14 caractères (« FRBNF »), pas le $3 des notices.
export function numeroAutorite(genre: 'nom' | 'sujet', id: unknown): string | null {
  const v = txt(id);
  return v === null ? null : `AnarBib-${genre === 'sujet' ? 'S' : 'A'}${v.padStart(8, '0')}`;
}

// « Congrès anarchiste (3 ; 1907 ; Amsterdam) » → base + qualificatifs
// (UNIMARC $d $f $e ; MARC21 $n $d $c). L'import ne joint que les
// qualificatifs présents : la date (un millésime) fixe la place des autres.
// Partagé avec l'export d'autorités (autorites.ts) : la 210 d'un congrès et
// la 71X de ses notices disent la même chose.
export function congres(nom: string, codes: string[]): { base: string; subs: (SousZone | null)[] } {
  const m = nom.match(/^(.*\S)\s*\(([^()]*)\)$/);
  if (!m) return { base: nom, subs: [] };
  const parts = m[2].split(/\s*;\s*/).map((x) => x.trim()).filter(Boolean);
  const k = parts.findIndex((p) => /\d{4}/.test(p));
  const [num, date, lieu] = parts.length >= 3 ? parts
    : k >= 0 ? [k > 0 ? parts[0] : null, parts[k], parts[k + 1] ?? null]
    : parts.length === 2 ? [parts[0], null, parts[1]]
    : /^\d/.test(parts[0] ?? '') ? [parts[0], null, null] : [null, null, parts[0] ?? null];
  return { base: m[1], subs: [sz(codes[0], num), sz(codes[1], date), sz(codes[2], lieu)] };
}

// Dates d'une personne : celles de sa fiche (RPC) ; sinon la $f (UNIMARC) /
// $d (MARC21) de la zone d'origine qui porte le même nom — même dialecte,
// bibliothèque d'origine (l'import ne les garde dans aucune colonne).
function datesDOrigine(d: Dialecte, rec: NoticeExport): Map<string, string> {
  const m = new Map<string, string>();
  if (!rec.source || rec.source.dialect !== d) return m;
  const net = (v: string) => (d === 'marc21' ? v.replace(/\s*[,.:;/]+$/, '') : v);
  for (const z of RESPONSABILITES[d]) {
    if (!z.dates || z.nature !== 'person') continue;
    for (const f of rec.source.fields ?? []) {
      if (f?.tag !== z.tag) continue;
      const val = (c: string) => (f.subfields ?? []).filter((s) => s?.code === c).map((s) => txt(s.value)).filter((x): x is string => !!x).map(net);
      const nom = z.nom.flatMap(val).join(', ');
      const dt = val(z.dates)[0];
      if (nom && dt && !m.has(nom)) m.set(nom, dt);
    }
  }
  return m;
}

// Le niveau d'une responsabilité secondaire en UNIMARC (70x/71x : 1 = autre
// auteur, 2 = secondaire) : celui de la zone d'origine qui porte le même nom —
// formé comme l'import le forme (« $a, $b » ; « $a. $b (qualificatifs) ») —
// et la même fonction. Même dialecte, bibliothèque d'origine. PMB range un
// illustrateur en 701 là où la table d'AnarBib dirait 702 ; rien ne contredit
// le choix d'origine tant que la fonction n'a pas changé (H27, revues du
// 28/09). Une zone nue (sans $4) ne dit pas de fonction : la table décide, et
// redonne le niveau dont l'import a tiré le rôle (autor → 1, outro → 2).
// Clé : « famille|nom|code » (famille 0 = 70x, 1 = 71x).
function niveauxDOrigine(d: Dialecte, rec: NoticeExport): Map<string, string> {
  const m = new Map<string, string>();
  if (d !== 'unimarc' || !rec.source || rec.source.dialect !== d) return m;
  const zones = new Map(RESPONSABILITES[d].map((z) => [z.tag, z]));
  for (const f of rec.source.fields ?? []) {
    const t = /^7([01])([12])$/.exec(f?.tag ?? '');
    if (!t || !Array.isArray(f.subfields)) continue;
    const val = (c: string) => f.subfields!.filter((s) => s?.code === c).map((s) => txt(s.value)).filter((x): x is string => !!x);
    const base = [...val('a'), ...val('b')].join(t[1] === '0' ? ', ' : '. ');
    if (!base) continue;
    const q = (zones.get(f.tag)?.qualificatifs ?? []).map((c) => val(c)[0]).filter(Boolean);
    const nom = q.length ? `${base} (${q.join(' ; ')})` : base;
    const codes = val('4').map((c) => codeRelation(c)).filter(Boolean);
    for (const code of codes) {
      const cle = `${t[1]}|${nom}|${code}`;
      if (!m.has(cle)) m.set(cle, t[2]);
    }
  }
  return m;
}

function responsabilites(d: Dialecte, rec: NoticeExport): ChampMarc[] {
  const out: ChampMarc[] = [];
  let principale = false;
  const qualif = (tag: string) => RESPONSABILITES[d].find((z) => z.tag === tag)?.qualificatifs ?? [];
  const datesSource = datesDOrigine(d, rec);
  const niveaux = niveauxDOrigine(d, rec);
  const niveauDOrigine = (famille: '0' | '1', nom: string, code: string): string | null =>
    niveaux.get(`${famille}|${nom}|${code}`) ?? null;
  for (const c of contributeurs(rec)) {
    const nature = c.nature === 'collective' || c.nature === 'congress' ? c.nature : 'person';
    const estPrincipale = !!c.primary && !principale;
    if (estPrincipale) principale = true;
    const code = codeFonction(d, c);
    const nom = String(c.name).trim();
    const dates = nature === 'person' ? (txt(c.dates) ?? datesSource.get(nom) ?? null) : null;
    if (d === 'unimarc') {
      const role = txt(c.role) || 'autor';
      const rang = estPrincipale ? '0'
        : niveauDOrigine(nature === 'person' ? '0' : '1', nom, code) ?? (AUTEURS.has(role) ? '1' : '2');
      if (nature === 'person') {
        const i = nom.indexOf(', ');
        out.push(champ(`70${rang}`, ind(d, `70${rang}`), [
          sz('a', i > 0 ? nom.slice(0, i) : nom), sz('b', i > 0 ? nom.slice(i + 2) : null),
          sz('f', dates), sz('4', code), sz('3', numeroAutorite('nom', c.authorId)),
        ])!);
      } else {
        const tag = `71${rang}`;
        const q = nature === 'congress' ? congres(nom, qualif(tag)) : { base: nom, subs: [] };
        out.push(champ(tag, nature === 'congress' ? '12' : '02', [
          sz('a', q.base), ...q.subs, sz('4', code), sz('3', numeroAutorite('nom', c.authorId)),
        ])!);
      }
    } else {
      const tag = nature === 'person' ? (estPrincipale ? '100' : '700')
        : nature === 'collective' ? (estPrincipale ? '110' : '710') : (estPrincipale ? '111' : '711');
      const i1 = nature === 'person' ? (nom.includes(', ') ? '1' : '0') : '2';
      const q = nature === 'congress' ? congres(nom, qualif(tag)) : { base: nom, subs: [] };
      out.push(champ(tag, `${i1} `, [
        // MARC21 : « 1957- » (les points de suspension de l'UNIMARC/BnF n'y ont pas cours)
        sz('a', q.base), ...q.subs, nature === 'person' ? sz('d', dates?.replace(/\.{4}/g, '')) : null,
        sz('4', code), sz('0', txt(c.authorId) ? `(AnarBib)${c.authorId}` : null),
      ])!);
    }
  }
  return out;
}

// ── Sujets ──────────────────────────────────────────────────────────────────
function sujets(d: Dialecte, rec: NoticeExport, depuisNotes: string[], motsDesNotes: string[] = []): ChampMarc[] {
  const tag = d === 'unimarc' ? '606' : '650';
  const vus = new Set<string>();
  const out: ChampMarc[] = [];
  // Les types de subdivision ($x $y $z $j / $v) d'une vedette d'origine dont la
  // chaîne aplatie est inchangée ; sinon $x.
  const typage = new Map<string, SousZone[]>();
  if (rec.source?.dialect === d) {
    const S = SUJETS[d];
    for (const f of rec.source.fields ?? []) {
      if (!f || !S.tags.includes(f.tag) || !Array.isArray(f.subfields)) continue;
      const subdiv = f.subfields.filter((s) => s && S.subdivisions.includes(s.code) && txt(s.value));
      const vedette = S.vedette.map((c) => txt(f.subfields!.find((s) => s?.code === c)?.value)).filter(Boolean).join(', ');
      const cle = [vedette, ...subdiv.map((s) => txt(s.value))].filter(Boolean).join(SEPARATEUR_SUBDIVISION);
      if (cle && !typage.has(cle)) typage.set(cle, subdiv.map((s) => ({ code: s.code, value: txt(s.value)! })));
    }
  }
  const poser = (label: string, id: unknown) => {
    const parts = label.split(SEPARATEUR_SUBDIVISION).map((x) => x.trim()).filter(Boolean);
    const cle = parts.join(SEPARATEUR_SUBDIVISION);
    if (!parts.length || vus.has(cle)) return;
    vus.add(cle);
    const thesaurus = txt(id) !== null;
    const orig = typage.get(cle);
    const subs = [sz('a', parts[0]), ...(orig && orig.length === parts.length - 1
      ? orig.map((s) => sz(s.code, s.value)) : parts.slice(1).map((p) => sz('x', p)))];
    if (thesaurus) {
      subs.push(d === 'unimarc' ? sz('3', numeroAutorite('sujet', id)) : sz('0', `(AnarBib)${id}`), sz('2', 'anarbib'));
    }
    out.push(champ(tag, d === 'unimarc' ? '  ' : (thesaurus ? ' 7' : ' 4'), subs)!);
  };
  for (const s of rec.subjects ?? []) {
    if (typeof s === 'string') { const v = txt(s); if (v) poser(v, null); }
    else if (s && txt(s.label)) poser(String(s.label).trim(), s.id);
  }
  for (const s of depuisNotes) poser(s, null);
  // Mots-clés libres : 610 / 653, un par mot — ceux de la notice, puis ceux
  // que l'import a rangés dans les notes (H27). Dédoublonnés entre eux
  // seulement : un mot-clé égal à une vedette est une autre zone.
  const [tk, ck] = zone(d, 'keywords') ?? [d === 'unimarc' ? '610' : '653', 'a'];
  const mots = new Set<string>();
  for (const k of [...(rec.keywords ?? []), ...motsDesNotes]) {
    const v = txt(k);
    if (v && !mots.has(v)) { mots.add(v); out.push(champ(tk, ind(d, tk), [sz(ck, v)])!); }
  }
  return out;
}

// ── Exemplaires : 995 (UNIMARC, convention PMB) / 852 (MARC21) ──────────────
function exemplaires(d: Dialecte, rec: NoticeExport, opts: OptionsEcriture): ChampMarc[] {
  const m = DEFAULT_ITEM_MAPPINGS[d];
  const out: ChampMarc[] = [];
  for (const it of rec.items ?? []) {
    const c = champ(m.tag, '  ', [
      sz(m.owner[0], opts.bibliotheque?.nom),
      sz(m.code[0], txt(it.code) ?? txt(it.tombo)),
      sz(m.call_number[0], it.callNumber),
      sz(m.note[0], it.note),
    ]);
    if (c && c.subfields!.some((s) => s.code !== m.owner[0])) out.push(c);
  }
  return out;
}

// ── Les zones de l'origine que l'import ne lit pas ──────────────────────────
const JAMAIS_REEMISES: Record<Dialecte, string[]> = {
  // 001 : l'export écrit le sien ; 005/009 : dates de gestion, périmées par
  // nature ; 100 / 008, 040 : l'export écrit les siennes (040 n'est pas
  // répétable) ; 996 : exemplaire PMB détaillé, que les exemplaires
  // d'AnarBib remplacent.
  unimarc: ['001', '005', '009', '100', '996'],
  marc21: ['001', '005', '008', '040'],
};
export function zonesTenues(d: Dialecte): Set<string> {
  const t = new Set<string>(JAMAIS_REEMISES[d]);
  for (const c of Object.values(CHAMPS[d])) for (const [tag] of c.zones) t.add(tag);
  for (const tag of SUJETS[d].tags) t.add(tag);
  for (const z of RESPONSABILITES[d]) t.add(z.tag);
  t.add(DEFAULT_ITEM_MAPPINGS[d].tag);
  return t;
}
function reemises(d: Dialecte, rec: NoticeExport, ecrits: ChampMarc[]): ChampMarc[] {
  const src = rec.source;
  if (!src || src.dialect !== d || !Array.isArray(src.fields)) return [];
  const tenues = zonesTenues(d);
  if (txt(src.itemTag)) tenues.add(String(src.itemTag).trim());
  // Ce que l'export vient d'écrire ne ressort pas une seconde fois : un seul
  // titre uniforme (celui de l'œuvre), un seul 1XX (la 130 l'exclut), un
  // même identifiant 035 une fois.
  const tags = new Set(ecrits.map((f) => f.tag));
  if (tags.has('500') || tags.has('240') || tags.has('130')) for (const t of ['500', '240', '130']) tenues.add(t);
  if (d === 'marc21' && ['100', '110', '111', '130'].some((t) => tags.has(t))) tenues.add('130');
  const ids035 = new Set(ecrits.filter((f) => f.tag === '035').flatMap((f) => (f.subfields ?? []).map((s) => s.value)));
  const out: ChampMarc[] = [];
  for (const f of src.fields) {
    if (!f || typeof f.tag !== 'string' || !/^[0-9A-Za-z]{3}$/.test(f.tag) || tenues.has(f.tag)) continue;
    if (typeof f.value === 'string') { out.push({ tag: f.tag, value: f.value, origine: true }); continue; }
    const subs = (f.subfields ?? []).filter((s) => s && typeof s.code === 'string' && s.code.length === 1 && typeof s.value === 'string');
    if (f.tag === '035' && subs.every((s) => ids035.has(s.value))) continue;
    if (subs.length) out.push({ tag: f.tag, ind1: f.ind1 || ' ', ind2: f.ind2 || ' ', subfields: subs.map((s) => ({ code: s.code, value: s.value })), origine: true });
  }
  return out;
}

// Le guide : celui de la table ; le type d'enregistrement (06-07) d'origine
// (carte, manuscrit, musique, objet…) s'il est de ce dialecte et dit encore le
// type qu'AnarBib tient.
function guide(d: Dialecte, type: string, src: NoticeExport['source']): string {
  const g = guidePourType(type, d);
  const o = src?.dialect === d && typeof src.leader === 'string' ? src.leader : '';
  if (o.length < 8 || !/^[a-z]{2}$/.test(o.slice(6, 8)) || typeDepuisGuide(o, d) !== type) return g;
  return g.slice(0, 6) + o.slice(6, 8) + g.slice(8);
}

// ── La notice ───────────────────────────────────────────────────────────────
export function enregistrement(rec: NoticeExport, opts: OptionsEcriture): NoticeMarc {
  const d = opts.dialecte;
  const date = /^\d{8}$/.test(opts.date || '') ? opts.date! : aujourdhui();
  const type = txt(rec.materialType) || 'livro';
  const langueCatalogage = codeLangue(opts.bibliotheque?.langue) ?? 'por';
  const langue = codeLangue(rec.language);
  const fields: ChampMarc[] = [];
  const push = (c: ChampMarc | null) => { if (c) fields.push(c); };

  // Zones groupées : chaque clé AnarBib dans la première zone que l'import lit.
  const groupes = new Map<string, SousZone[]>();
  const poser = (cle: string, valeur: unknown) => {
    const z = zone(d, cle);
    const s = z ? sz(z[1], valeur) : null;
    if (!z || !s) return;
    if (!groupes.has(z[0])) groupes.set(z[0], []);
    groupes.get(z[0])!.push(s);
  };

  // 001 : l'identifiant d'origine de la bibliothèque (H20), sinon la
  // référence AnarBib ; 035 : les autres.
  const ids = (rec.externalIds ?? []).filter((x) => txt(x?.value));
  const premier = txt(rec.originId) ?? txt(ids[0]?.value);
  push({ tag: '001', value: premier ?? txt(rec.bibRef) ?? String(rec.id ?? '') });
  const autres: [string, string][] = [];
  if (premier && txt(rec.bibRef)) autres.push(['AnarBib', String(rec.bibRef).trim()]);
  for (const x of ids) if (String(x.value).trim() !== premier) autres.push([txt(x.label) ?? txt(x.scheme) ?? 'source', String(x.value).trim()]);
  for (const [l, v] of autres) push(champ('035', '  ', [sz('a', `(${l})${v}`)]));

  // Identifiants normalisés : un ISBN par zone.
  for (const i of String(rec.isbn ?? '').split(/\s*[;|]\s*/)) poser('isbn', i);
  // Un article n'a pas d'ISSN à lui : celui qu'il porte est celui de sa revue
  // (l'import l'y range, H17) ; il ressort en 461 $x, pas en 011 (H27).
  if (type !== 'artigo') poser('issn', txt(rec.issn) ?? (type === 'periodico' ? rec.serial?.issn : null));

  const an = String(rec.year ?? '').match(/\d{4}/)?.[0];
  if (d === 'unimarc') {
    // 100 $a : données générales ; le jeu de caractères 50 (Unicode) en 26-29,
    // que l'import (et PMB) relisent. Un périodique : son année est celle d'un
    // fascicule, et l'on ne sait pas s'il paraît encore → 'u', dates à blanc.
    const a1 = type === 'periodico' ? undefined : an;
    push(champ('100', '  ', [sz('a', `${date}${a1 ? 'd' : 'u'}${(a1 ?? '').padEnd(4, ' ')}    u  u0${langueCatalogage}y50      ba`)]));
  } else {
    // 008 (40 positions) et 040 : les équivalents MARC21 de la 100 et de la 801.
    const dates = type === 'periodico' ? `u${an ?? 'uuuu'}uuuu` : an ? `s${an}    ` : 'nuuuuuuuu';
    push({ tag: '008', value: `${date.slice(2)}${dates}xx ${'|'.repeat(17)}${langue ?? '|||'} d` });
    push(champ('040', '  ', [sz('a', 'AnarBib'), sz('b', langueCatalogage), sz('c', 'AnarBib')]));
  }
  poser('language', langue);

  // Titre, mention de responsabilité, tome.
  poser('title', rec.title);
  const vol = txt(rec.volume);
  if (vol) {
    const i = vol.indexOf(' : ');
    poser('volumeNumber', i > 0 ? vol.slice(0, i) : vol);
    poser('volumeName', i > 0 ? vol.slice(i + 3) : null);
  }
  poser('subtitle', rec.subtitle);
  poser('responsibility', rec.responsibility);
  poser('edition', rec.edition);
  poser('place', rec.place);
  poser('publisher', rec.publisher);
  poser('year', rec.year);

  // Étendue : la pagination d'un article, sinon le nombre de pages.
  const pages = txt(rec.pages);
  poser('extent', type === 'artigo' ? (txt(rec.articlePages) ?? (pages ? `${pages} p.` : null)) : (pages ? `${pages} p.` : null));

  // Collection : « Titre ; numéro » (la forme que l'import compose).
  const col = txt(rec.collection);
  if (col) {
    const m = col.match(/^(.*\S)\s+;\s+([^;]+)$/);
    poser('seriesTitle', m ? m[1] : col);
    poser('seriesNumber', m ? m[2] : null);
  }

  // Périodique (titre clé, fascicule), article dépouillé (revue, fascicule).
  if (type === 'periodico') {
    poser('keyTitle', txt(rec.keyTitle) ?? rec.serial?.title);
    poser('issueNumber', rec.issue?.number);
    poser('issueDate', rec.issue?.date);
  }
  if (type === 'artigo') {
    poser('hostTitle', rec.host?.title);
    poser('hostIssn', txt(rec.host?.issn) ?? rec.issn);
    poser('hostVolume', rec.host?.volume);
    poser('issueNumber', rec.issue?.number);
    poser('issueDate', rec.issue?.date);
    poser('issueTitle', rec.issue?.title);
  }

  poser('classification', rec.cdd);

  // Notes : chaque paragraphe à sa zone ; une 330 / 327 d'origine à plusieurs
  // paragraphes (l'import les joint par une ligne vide) revient en une zone.
  const n = deplierNotes(rec.notes);
  const origines: { paras: string[]; cle: string }[] = [];
  if (rec.source?.dialect === d) {
    for (const cle of ['summary', 'contents']) {
      const z = zone(d, cle);
      if (!z) continue;
      for (const f of rec.source.fields ?? []) {
        if (f?.tag !== z[0]) continue;
        for (const s of f.subfields ?? []) {
          if (s?.code !== z[1] || !txt(s.value)) continue;
          const paras = paragraphes(String(s.value));
          if (paras.length) origines.push({ paras, cle });
        }
      }
    }
  }
  origines.sort((a, b) => b.paras.length - a.paras.length);
  const notesSimples: ChampMarc[] = [];
  for (let i = 0; i < n.paragraphes.length;) {
    const o = origines.find((x) => x.paras.every((p, k) => n.paragraphes[i + k] === p));
    const k = o ? o.paras.length : 1;
    const z = zone(d, o?.cle ?? 'notes');
    if (z) notesSimples.push({ ...champ(z[0], ind(d, z[0]), [sz(z[1], n.paragraphes.slice(i, i + k).join('\n\n'))])!, note: true });
    i += k;
  }

  // Adresses : celle d'une ressource numérique (MARC21 856 ind2 0 : la
  // ressource elle-même), celles rangées en note (lien sans nature dite).
  const propre = type === 'recurso_digital' ? txt(rec.url) : null;
  const adresses = [txt(rec.url), ...n.adresses].filter((x): x is string => !!x);
  const [tu, cu] = zone(d, 'url') ?? ['856', 'u'];
  const adressesChamps = [...new Set(adresses)].map((u) =>
    champ(tu, d === 'marc21' && u === propre ? '40' : ind(d, tu), [sz(cu, u)]));

  // Responsabilités d'abord : la vedette principale décide du titre uniforme
  // (MARC21 240 sous un 1XX, 130 sinon) et de la 245 ind1.
  const resps = responsabilites(d, rec);
  const vedette1XX = resps.some((f) => f.tag[0] === '1');
  const oeuvre = txt(rec.work?.title);
  const titreUniforme = oeuvre && oeuvre !== txt(rec.title)
    ? (d === 'unimarc' ? champ('500', ind(d, '500'), [sz('a', oeuvre)])
      : vedette1XX ? champ('240', ind(d, '240'), [sz('a', oeuvre)]) : champ('130', ind(d, '130'), [sz('a', oeuvre)]))
    : null;

  // 101 / 041 ind1 : « traduction » (1) si la notice a un traducteur.
  const traduction = contributeurs(rec).some((c) => txt(c.role) === 'tradutor');
  const tagLangue = zone(d, 'language')?.[0];
  for (const [tag, subs] of groupes) {
    // Zones répétables à une valeur par zone (ISBN) ; les autres groupées.
    if (tag === (zone(d, 'isbn') ?? [''])[0]) for (const s of subs) push(champ(tag, ind(d, tag), [s]));
    else if (traduction && tag === tagLangue) push(champ(tag, `1${ind(d, tag)[1]}`, subs));
    else if (d === 'marc21' && tag === '245') push(champ(tag, `${vedette1XX ? '1' : '0'}0`, subs));
    else push(champ(tag, ind(d, tag), subs));
  }
  for (const c of notesSimples) push(c);
  push(titreUniforme);
  for (const c of adressesChamps) push(c);
  for (const c of sujets(d, rec, n.sujets, n.motsCles)) push(c);
  for (const c of resps) push(c);
  // 801 : AnarBib, agence qui diffuse la notice, et le pays de la bibliothèque.
  if (d === 'unimarc') push(champ('801', ind(d, '801'), [sz('a', codePays(opts.bibliotheque?.pays)), sz('b', 'AnarBib'), sz('c', date)]));
  for (const c of exemplaires(d, rec, opts)) push(c);
  for (const c of reemises(d, rec, fields)) push(c);

  // Dans l'ordre des zones (stable : l'ordre d'écriture dans une même zone).
  const tries = fields.map((f, i) => [f, i] as const)
    .sort((a, b) => (a[0].tag < b[0].tag ? -1 : a[0].tag > b[0].tag ? 1 : a[1] - b[1]))
    .map(([f]) => f);
  return { leader: guide(d, type, rec.source), fields: tries };
}
