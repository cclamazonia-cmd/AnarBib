// Écriture UNIMARC Autorités (H25, aller-retour PMB, 28/09/2026).
//
// Les fiches d'autorité d'une bibliothèque (public.fn_export_authorities_lote)
// deviennent des notices d'autorité au modèle commun ({ leader, fields }),
// sérialisées ensuite par iso2709.ts ou marcxml.ts. Leur 001 est le numéro
// que l'export bibliographique porte en $3 (700-712, 606 ; numeroAutorite,
// ecriture.ts). Dans PMB (import avec « Tenir compte des notices
// d'autorités ») : une 7XX rejoint sa fiche par ce $3 (numéro, type, origine
// AnarBib) ; une 606, elle, est rapprochée par son LIBELLÉ, dans le thésaurus
// par défaut de PMB (func_cpt_rameau_first_level ignore le $3) — les
// vedettes doivent donc y être importées (tests/pmb/README.md).
//
//   200 personne ($a nom, $b prénom, $f dates) · 210 collectivité ou congrès
//   (ind1 0 / 1 ; $d $f $e d'un congrès) · 250 sujet · 4XX formes rejetées ·
//   550 $5 g le terme générique, 550 les termes associés · 033 les
//   identifiants pérennes (VIAF, ISNI, Wikidata, IdRef, LCCN) · 100 $a
//   données générales (jeu 50, Unicode) · 102 pays · 801 AnarBib.
import { codePays, codeLangue, congres, numeroAutorite, type ChampMarc, type NoticeMarc, type SousZone } from './ecriture.ts';

export interface AutoriteNom {
  id: number | string; type?: string | null; preferredName?: string | null; sortName?: string | null;
  birthYear?: number | null; deathYear?: number | null; activityPeriod?: string | null;
  country?: string | null; variants?: string[] | null;
  viaf?: string | null; isni?: string | null; wikidata?: string | null; idref?: string | null; lccn?: string | null;
  note?: string | null;
}
export interface AutoriteSujet {
  id: number | string; label: string; alt?: string[] | null; broader?: number | string | null;
  related?: (number | string)[] | null; notation?: string | null; scopeNote?: string | null;
}
export interface OptionsAutorites {
  date?: string;
  bibliotheque?: { pays?: string | null; langue?: string | null } | null;
  // Le numéro écrit en 001 (et que l'export bibliographique porte en $3).
  numero?: (genre: 'nom' | 'sujet', id: number | string) => string;
}

const txt = (v: unknown): string | null => {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s.length ? s : null;
};
const sz = (code: string, value: unknown): SousZone | null => { const v = txt(value); return v === null ? null : { code, value: v }; };
function champ(tag: string, ind: string, subs: (SousZone | null)[]): ChampMarc | null {
  const s = subs.filter((x): x is SousZone => x !== null);
  return s.length ? { tag, ind1: ind[0] ?? ' ', ind2: ind[1] ?? ' ', subfields: s } : null;
}
const numeroParDefaut = (genre: 'nom' | 'sujet', id: number | string) => numeroAutorite(genre, id) ?? String(id);

// Guide UNIMARC/A : n (nouvelle), x (notice d'autorité), 9 = type d'entité
// (a personne, b collectivité — congrès compris —, j sujet).
function guide(entite: string): string {
  // 17 : niveau de codage (blanc = complet) ; 18-19 non définis.
  return `00000nx  ${entite}2200000   450 `;
}
function donneesGenerales(date: string, langue: string): ChampMarc {
  // 0-7 date, 8 statut (a établie), 9-11 langue de catalogage,
  // 12 translittération (y aucune), 13-16 jeu (50 : Unicode), 17-20 jeu
  // additionnel, 21-22 écriture (ba latin), 23 sens (0).
  return champ('100', '  ', [sz('a', `${date}a${langue}y50      ba0`)])!;
}
// 801 : PMB range chaque autorité importée sous l'origine nommée par 801 $b
// (origin_authorities) et la retrouve par (001, type, origine) ; $a le pays.
// Pas de $c (date) : PMB ne met à jour une fiche déjà importée que si 801 $c
// est postérieure à sa dernière mise à jour (authority_import.class.php,
// DATEDIFF > 0) — une correction réimportée le même jour serait ignorée en
// silence. Sans $c, PMB met toujours à jour : AnarBib est la référence. La
// date reste en 100 $a (revue du 28/09).
function pied(pays: string | null): ChampMarc[] {
  return [champ('801', ' 0', [sz('a', codePays(pays)), sz('b', 'AnarBib')])!];
}

function nomEnZone(tag: string, type: string, nom: string, dates: string | null): ChampMarc | null {
  if (type === 'collective') return champ(tag, '02', [sz('a', nom)]);
  // Congrès : le même découpage que la 71X des notices (ecriture.ts).
  if (type === 'congress') { const q = congres(nom, ['d', 'f', 'e']); return champ(tag, '12', [sz('a', q.base), ...q.subs]); }
  const i = nom.indexOf(', ');
  return champ(tag, i > 0 ? ' 1' : ' 0', [sz('a', i > 0 ? nom.slice(0, i) : nom), sz('b', i > 0 ? nom.slice(i + 2) : null), sz('f', dates)]);
}

export function autoriteNom(a: AutoriteNom, opts: OptionsAutorites = {}): NoticeMarc {
  const date = /^\d{8}$/.test(opts.date || '') ? opts.date! : new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const langue = codeLangue(opts.bibliotheque?.langue) ?? 'por';
  const numero = opts.numero ?? numeroParDefaut;
  const type = a.type === 'collective' || a.type === 'congress' ? a.type : 'person';
  const tagVedette = type === 'person' ? '200' : '210';
  const tagRenvoi = type === 'person' ? '400' : '410';
  const dates = a.birthYear || a.deathYear ? `${a.birthYear ?? '....'}-${a.deathYear ?? '....'}` : txt(a.activityPeriod);
  const vedette = txt(a.sortName) ?? txt(a.preferredName) ?? String(a.id);
  const fields: (ChampMarc | null)[] = [
    { tag: '001', value: numero('nom', a.id) },
    ...[['VIAF', a.viaf, (v: string) => `http://viaf.org/viaf/${v}`], ['ISNI', a.isni, (v: string) => `https://isni.org/isni/${v.replace(/\s+/g, '')}`],
        ['Wikidata', a.wikidata, (v: string) => `http://www.wikidata.org/entity/${v}`], ['IdRef', a.idref, (v: string) => `https://www.idref.fr/${v}`],
        ['LCNAF', a.lccn, (v: string) => `http://id.loc.gov/authorities/names/${v.replace(/\s+/g, '')}`]]
      .filter(([, v]) => txt(v))
      .map(([src, v, url]) => champ('033', '  ', [sz('a', (url as (x: string) => string)(String(v).trim())), sz('2', src)])),
    donneesGenerales(date, langue),
    champ('102', '  ', [sz('a', txt(a.country) && /^[A-Za-z]{2}$/.test(String(a.country)) ? String(a.country).toUpperCase() : null)]),
    nomEnZone(tagVedette, type, vedette, type === 'congress' ? null : dates),
    txt(a.note) ? champ('300', '0 ', [sz('a', a.note)]) : null,
  ];
  const vus = new Set([vedette]);
  const pref = txt(a.preferredName);
  // La forme d'usage, si elle diffère de la vedette, est une forme rejetée.
  for (const v of [pref, ...(a.variants ?? [])]) {
    const f = txt(v);
    if (!f || vus.has(f)) continue;
    vus.add(f);
    fields.push(nomEnZone(tagRenvoi, type, f, null));
  }
  fields.push(...pied(txt(opts.bibliotheque?.pays)));
  const tries = fields.filter((f): f is ChampMarc => !!f)
    .map((f, i) => [f, i] as const).sort((x, y) => (x[0].tag < y[0].tag ? -1 : x[0].tag > y[0].tag ? 1 : x[1] - y[1])).map(([f]) => f);
  return { leader: guide(type === 'person' ? 'a' : 'b'), fields: tries };
}

export function autoriteSujet(s: AutoriteSujet, parId: Map<string, AutoriteSujet>, opts: OptionsAutorites = {}): NoticeMarc {
  const date = /^\d{8}$/.test(opts.date || '') ? opts.date! : new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const langue = codeLangue(opts.bibliotheque?.langue) ?? 'por';
  const numero = opts.numero ?? numeroParDefaut;
  const renvoi = (id: number | string, controle: string | null): ChampMarc | null => {
    const cible = parId.get(String(id));
    return cible ? champ('550', '  ', [sz('3', numero('sujet', cible.id)), sz('a', cible.label), controle ? sz('5', controle) : null]) : null;
  };
  const fields: (ChampMarc | null)[] = [
    { tag: '001', value: numero('sujet', s.id) },
    donneesGenerales(date, langue),
    champ('250', '  ', [sz('a', s.label)]),
    txt(s.scopeNote) ? champ('330', '  ', [sz('a', s.scopeNote)]) : null,
    txt(s.notation) ? champ('686', '  ', [sz('a', s.notation), sz('2', 'anarbib')]) : null,
    ...(s.alt ?? []).filter((x) => txt(x) && txt(x) !== txt(s.label)).map((x) => champ('450', '  ', [sz('a', x)])),
    s.broader !== null && s.broader !== undefined ? renvoi(s.broader, 'g') : null,
    ...(s.related ?? []).map((r) => renvoi(r, null)),
    ...pied(txt(opts.bibliotheque?.pays)),
  ];
  const tries = fields.filter((f): f is ChampMarc => !!f)
    .map((f, i) => [f, i] as const).sort((x, y) => (x[0].tag < y[0].tag ? -1 : x[0].tag > y[0].tag ? 1 : x[1] - y[1])).map(([f]) => f);
  return { leader: guide('j'), fields: tries };
}

// Tout un envoi : les noms, puis les sujets (les renvois 550 ne visent que des
// sujets présents dans l'envoi — la RPC y met les ancêtres).
export function autorites(donnees: { authors?: AutoriteNom[]; subjects?: AutoriteSujet[] }, opts: OptionsAutorites = {}): NoticeMarc[] {
  const sujets = Array.isArray(donnees.subjects) ? donnees.subjects : [];
  const parId = new Map(sujets.map((x) => [String(x.id), x]));
  return [
    ...(Array.isArray(donnees.authors) ? donnees.authors : []).map((a) => autoriteNom(a, opts)),
    ...sujets.map((x) => autoriteSujet(x, parId, opts)),
  ];
}
