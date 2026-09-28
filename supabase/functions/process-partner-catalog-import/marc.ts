// Parser MARC pour le pipeline d'import de catalogues partenaires (Lot 4).
//
// Session : Lot 4 — Parser MARC/UNIMARC
// Auteur  : Claude Opus 4.8
//
// Couvre : UNIMARC + MARC21, en MARCXML et en ISO 2709 binaire.
// Produit la MEME forme normalisee que mapRecord/mapRisRecord de index.ts,
// pour se brancher sans friction sur le writer de staging existant :
//   { title, subtitle, responsibilityStatement, authorsArray, publisher,
//     placeOfPublication, publicationYear, editionStatement, language,
//     isbn, issn, subjectsArray, itemType, externalKey }
//
// Frontiere d'encodage (ISO 2709) : on decode avec l'encodage que l'appelant a
// retenu (index.ts, encoding.ts : UTF-8 strict, sinon windows-1252 suppose, ou
// l'encodage impose) — 'utf-8' par defaut. Si une notice MARC21 a son leader/9
// blanc (MARC-8), on emet un warning explicite plutot que de corrompre
// silencieusement — le transcodage MARC-8 -> Unicode (table de centaines
// d'entrees + diacritiques combinants) est hors perimetre.
// H15 (26/09/2026) : en UNIMARC, leader/9 n'est PAS defini et vaut un blanc
// (constate sur un export reel de PMB 8.1) ; l'avertissement MARC-8 y etait
// faux sur chaque fichier. L'UNIMARC declare son jeu de caracteres en
// 100 $a positions 26-29 (unimarcDeclaredCharset).

// H17/H18/H23 (27/09/2026) : les zones lues viennent de la table commune à
// l'import et à l'export (_shared/marc/correspondance.ts) ; la forme normalisée
// gagne pagination, collection, notes, classification, adresse, volume,
// périodique et article (H17) et les responsabilités structurées — nom,
// nature, rôle, code d'origine (H18). marc_v2 : cette forme-là.
import {
  CHAMPS, SUJETS, RESPONSABILITES, SEPARATEUR_SUBDIVISION, roleDepuisCode, codeRelation, zoneLaissee,
  typeDepuisGuide, DEFAULT_ITEM_MAPPINGS as EXEMPLAIRES_PAR_DEFAUT,
} from '../_shared/marc/correspondance.ts';

export const MARC_PARSER_VERSION = 'marc_v2';

// ── Modele commun ───────────────────────────────────────────
//
// Un enregistrement MARC normalise en objet :
//   { leader: string,
//     fields: [
//       { tag: '001', value: 'ctrl' }                      // controlfield
//       { tag: '200', ind1: ' ', ind2: '0',                // datafield
//         subfields: [{ code: 'a', value: '...' }, ...] }
//     ] }

// ── Tables de zones par dialecte ────────────────────────────
// Dans _shared/marc/correspondance.ts (CHAMPS, SUJETS, RESPONSABILITES) : une
// seule table pour l'import, l'export et la couverture.
const CONTROLE = '001';

// ── Exemplaires (H19, 26/09/2026 — REGISTRE IMP-21) ─────────
//
// Une zone d'exemplaire par exemplaire physique : 995 en UNIMARC (convention
// PMB), 852 en MARC21. Chaque cle de la correspondance nomme la ou les
// sous-zones a lire (plusieurs lettres = concatenees, dans cet ordre) :
//   code        -> code d'origine (code-barres PMB) : exemplares.source_item_code
//   call_number -> cote : shelf_location
//   note        -> note d'exemplaire : notes
//   owner       -> proprietaire / preteur : source_library
//   item_type, public, status -> gardes dans la note de provenance ; la
//                  correspondance vers la politique de circulation attend
//                  l'echantillon de DIRA (IMP-21 d).
// Defaut UNIMARC = ce que PMB 8.1 ecrit (fixtures tests/pmb) ; la
// correspondance se regle dans le PROFIL d'import de la bibliotheque
// (ingest.import_profiles.items_mapping), qui surcharge cle par cle.
export const DEFAULT_ITEM_MAPPINGS = EXEMPLAIRES_PAR_DEFAUT;
export const ITEM_STRUCTURED_KEYS = ['code', 'call_number', 'note', 'owner'];
export const ITEM_NOTE_KEYS = ['item_type', 'public', 'status'];
const ITEM_KEYS = [...ITEM_STRUCTURED_KEYS, ...ITEM_NOTE_KEYS];
// Une seule valeur par exemplaire : la PREMIERE occurrence de la sous-zone ;
// une repetition dans la meme zone est comptee en surplus par la couverture.
// Les autres cles lisent TOUTES les occurrences (852 $i ou $z sont repetables
// en MARC21 : « v.2 » ou une seconde note ne se perdent pas).
export const ITEM_SINGLE_KEYS = ['code', 'owner'];
const ITEM_JOIN = { call_number: ' ', note: ' ; ', item_type: ', ', public: ', ', status: ', ' };

// Surcharge du profil sur le defaut du dialecte ; une valeur invalide est
// ignoree (le defaut reste), une chaine vide coupe la cle.
export function resolveItemMapping(dialect, override) {
  const base = { ...(dialect === 'marc21' ? DEFAULT_ITEM_MAPPINGS.marc21 : DEFAULT_ITEM_MAPPINGS.unimarc) };
  if (!override || typeof override !== 'object') return base;
  if (typeof override.tag === 'string' && /^\d{3}$/.test(override.tag.trim())) base.tag = override.tag.trim();
  for (const k of ITEM_KEYS) {
    const v = override[k];
    if (typeof v !== 'string') continue;
    const s = v.trim().toLowerCase();
    if (s === '' || /^[0-9a-z]{1,4}$/.test(s)) base[k] = s;
  }
  return base;
}

function readItemValue(field, codes, key) {
  if (!codes) return null;
  const single = ITEM_SINGLE_KEYS.includes(key);
  const parts = [];
  for (const c of codes) {
    const found = (field.subfields || []).filter((s) => s.code === c);
    for (const sf of (single ? found.slice(0, 1) : found)) {
      const v = clean(sf?.value);
      if (v) parts.push(v);
    }
  }
  return parts.length ? parts.join(ITEM_JOIN[key] || ' ') : null;
}

// → [{ source_item_code, call_number, note, owner, item_type, public, status }]
//   (un objet par zone d'exemplaire ayant au moins une valeur lue)
export function extractItems(record, dialect, mappingOverride = null) {
  const m = resolveItemMapping(dialect, mappingOverride);
  const out = [];
  for (const f of fieldsByTag(record, m.tag)) {
    if (!f.subfields) continue;
    const item = {
      source_item_code: readItemValue(f, m.code, 'code'),
      call_number: readItemValue(f, m.call_number, 'call_number'),
      note: readItemValue(f, m.note, 'note'),
      owner: readItemValue(f, m.owner, 'owner'),
      item_type: readItemValue(f, m.item_type, 'item_type'),
      public: readItemValue(f, m.public, 'public'),
      status: readItemValue(f, m.status, 'status'),
    };
    if (Object.values(item).some((v) => v !== null)) out.push(item);
  }
  return out;
}

// ── Helpers d'acces au modele ───────────────────────────────

function clean(value) {
  if (value === null || value === undefined) return null;
  const s = String(value).trim();
  return s.length ? s : null;
}

function fieldsByTag(record, tag) {
  return record.fields.filter((f) => f.tag === tag);
}

function controlValue(record, tag) {
  const f = record.fields.find((x) => x.tag === tag && typeof x.value === 'string');
  return f ? clean(f.value) : null;
}

// Premiere valeur de sous-zone pour une liste de {tag, code}.
function firstFromList(record, list) {
  for (const { tag, code } of list) {
    for (const f of fieldsByTag(record, tag)) {
      if (!f.subfields) continue;
      for (const s of f.subfields) {
        if (s.code !== code) continue;
        const v = clean(s.value);
        if (v) return v;
      }
    }
  }
  return null;
}

// Toutes les valeurs de sous-zone pour une liste de {tag, code} (dedoublonnees).
function allFromList(record, list) {
  const out = [];
  const seen = new Set();
  for (const { tag, code } of list) {
    for (const f of fieldsByTag(record, tag)) {
      if (!f.subfields) continue;
      for (const s of f.subfields) {
        if (s.code !== code) continue;
        const v = clean(s.value);
        if (v && !seen.has(v)) { seen.add(v); out.push(v); }
      }
    }
  }
  return out;
}

// Un champ de la table commune : [tag, sous-zone] -> la 1re valeur, toutes, ou
// toutes jointes.
function lireChamp(record, champ) {
  const liste = (champ?.zones || []).map(([tag, code]) => ({ tag, code }));
  if (!champ || champ.mode === 'first') return liste.length ? firstFromList(record, liste) : null;
  const toutes = liste.length ? allFromList(record, liste) : [];
  return champ.mode === 'join' ? (toutes.length ? toutes.join(champ.sep || ' ; ') : null) : toutes;
}

function premiere(field, code) {
  if (!code) return null;
  return clean((field.subfields || []).find((s) => s.code === code)?.value);
}

function toutes(field, code) {
  if (!code) return [];
  return (field.subfields || []).filter((s) => s.code === code).map((s) => clean(s.value)).filter(Boolean);
}

// MARC21 (LC, OCLC, Koha…) garde la ponctuation ISBD dans les sous-zones ;
// l'UNIMARC non. Retirée (revue du 28/09) : « Bakunin, Mikhail, » ne rejoignait
// pas son autorité, « Anarchism : » gardait ses deux-points. Le point d'une
// initiale (« Walker, Mildred D. ») et d'une abréviation courante reste.
// qualif : un $n/$d/$c de 111, entre parenthèses.
const INITIALE_FINALE = /(?:^|[\s.])\p{Lu}\.$/u;
const ABREVIATION_FINALE = /\b(?:p|pp|v|vol|vols|il|ill|cm|mm|ed|éd|eds|org|orgs|dir|coord|trad|comp|rev|aum|impr|reimpr|ca|n|no|t|et al|etc|jr|sr|st|ste|dr|dra|prof|fig|col|coll)\.$/i;
function sansIsbd(v, qualif = false) {
  let s = clean(v);
  if (!s) return null;
  let avant;
  do {
    avant = s;
    s = s.replace(/[\s,;:/=]+$/, '');
    if (qualif) s = s.replace(/^\(\s*/, '').replace(/\s*\)$/, '');
    if (s.endsWith('.') && !INITIALE_FINALE.test(s) && !ABREVIATION_FINALE.test(s)) s = s.slice(0, -1).trimEnd();
  } while (s !== avant);
  return s || null;
}

// H17 (revue) : le titre de collection et son numéro viennent de la MÊME zone
// (225 / 410, ou 490 / 830) : la première qui porte un titre, puis son propre
// $v — jamais le $v d'une autre occurrence.
function collection(record, def) {
  const numeros = new Map(def.seriesNumber.zones);
  for (const [tag, code] of def.seriesTitle.zones) {
    for (const f of fieldsByTag(record, tag)) {
      const titre = premiere(f, code);
      if (titre) return { titre, numero: premiere(f, numeros.get(tag)) };
    }
  }
  return { titre: null, numero: null };
}

// Sujets : la vedette ($a, $b) puis ses subdivisions dans l'ordre de la zone
// (UNIMARC 606 $a « Anarchisme » $y « France » $z « 19e siècle » ->
// « Anarchisme -- France -- 19e siècle ») ; puis les mots-clés libres (610 /
// 653), une zone pouvant en porter plusieurs séparés par « ; » (PMB).
function sujets(record, dialect) {
  const d = SUJETS[dialect];
  const out = [];
  const seen = new Set();
  const ajouter = (v) => { if (v && !seen.has(v)) { seen.add(v); out.push(v); } };
  for (const tag of d.tags) {
    for (const f of fieldsByTag(record, tag)) {
      if (!f.subfields) continue;
      const vedette = d.vedette.map((c) => premiere(f, c)).filter(Boolean).join(', ');
      const subdivisions = f.subfields.filter((s) => d.subdivisions.includes(s.code)).map((s) => clean(s.value)).filter(Boolean);
      ajouter([vedette, ...subdivisions].filter(Boolean).join(SEPARATEUR_SUBDIVISION) || null);
    }
  }
  return out;
}

// Mots-clés libres (610 UNIMARC, 653 MARC21), une zone pouvant en porter
// plusieurs séparés par « ; » (PMB). H27 : gardés à part des vedettes — un
// mot-clé n'est pas une vedette, et l'export les rend à leur zone (610/653)
// au lieu d'en faire des 606, que PMB change en catégories au réimport.
function motsCles(record, dialect) {
  const out = [];
  const seen = new Set();
  for (const v of lireChamp(record, CHAMPS[dialect].keywords)) {
    for (const mot of String(v).split(/\s*;\s*/)) {
      const m = clean(mot);
      if (m && !seen.has(m)) { seen.add(m); out.push(m); }
    }
  }
  return out;
}

// Responsabilités (H18) : pour chaque zone 70x/71x (UNIMARC), 1XX/7XX (MARC21),
// dans l'ordre de la notice, la zone principale d'abord : nom, nature
// (personne, collectivité, congrès), rôle AnarBib (depuis $4, ou le terme en
// clair $e/$j en MARC21), le code d'origine, les dates, la référence
// d'autorité ($3 UNIMARC, $0 MARC21 ; le $9 de PMB est un identifiant interne,
// laissé). Une personne : « $a, $b » ; une collectivité : « $a. $b ».
function responsabilites(record, dialect) {
  const zones = new Map(RESPONSABILITES[dialect].map((z) => [z.tag, z]));
  const out = [];
  const seen = new Set();
  record.fields.forEach((f, ordre) => {
    const z = zones.get(f.tag);
    if (!z || !f.subfields) return;
    const nature = z.nature === 'ind1' ? (f.ind1 === '1' ? 'congress' : 'collective') : z.nature;
    const isbd = (v, q = false) => (dialect === 'marc21' ? sansIsbd(v, q) : clean(v));
    // Toutes les $b (la hiérarchie d'une collectivité : « France. Ministère »).
    const parts = z.nom.flatMap((c) => toutes(f, c)).map((v) => isbd(v)).filter(Boolean);
    const base = parts.join(nature === 'person' ? ', ' : '. ');
    if (!base) return;
    // Numéro, date, lieu d'un congrès (ou d'une collectivité qui les porte).
    const qualif = (z.qualificatifs || []).map((c) => isbd(premiere(f, c), true)).filter(Boolean);
    const name = qualif.length ? `${base} (${qualif.join(' ; ')})` : base;
    // Tous les rôles ($4, $e répétables) : une entrée par rôle.
    const codes = toutes(f, z.role);
    const termes = toutes(f, z.roleTerme).map((v) => isbd(v));
    const paires = codes.length ? codes.map((c) => [c, termes[0] || null])
      : termes.length ? termes.map((t) => [null, t]) : [[null, null]];
    const authorityRef = (z.autorite || []).map((c) => premiere(f, c)).find(Boolean) || null;
    for (const [roleCode, roleTerme] of paires) {
      const role = roleDepuisCode(dialect, roleCode, roleTerme, !!z.secondaire);
      const cle = `${name}|${role}`;
      if (seen.has(cle)) continue;
      seen.add(cle);
      out.push({
        name, nature, role, roleCode: codeRelation(roleCode) || roleTerme || null, primary: !!z.principale,
        dates: isbd(premiere(f, z.dates)), authorityRef, tag: f.tag, ordre,
      });
    }
  });
  // La zone principale (700/710, 1XX) d'abord, puis l'ordre de la notice.
  out.sort((a, b) => (Number(b.primary) - Number(a.primary)) || (a.ordre - b.ordre));
  return out.map(({ ordre, ...c }) => c);
}

// Nombre de pages d'une étendue (215 $a / 300 $a) : « 166 p. », « 318 pages »,
// « Cartonné - 48 pages », « 1 vol. (212 p.) ». Rien pour une étendue qui n'est
// pas un nombre de pages (« p. 4-9 » d'un article, « 3 vol. ») : elle reste
// entière dans extent.
function pagesDepuisEtendue(extent) {
  const v = clean(extent);
  if (!v) return null;
  // Plusieurs volumes paginés chacun (« 2 vol. (318, 352 p.) ») : aucun nombre
  // ne vaut pour l'ensemble ; l'étendue reste entière.
  const vol = v.match(/^(\d+)\s*(?:vols?|v|t|tomes?)\b\.?\s*(?:\(([^)]*)\))?/i);
  if (vol && parseInt(vol[1], 10) > 1 && vol[2] && vol[2].includes(',')) return null;
  // Feuillets préliminaires (« 2 p. l. ») et planches (« 20 f. de pl. ») : pas
  // la pagination principale.
  const m = v.match(/(\d{1,5})\s*(?:p\.|p\b|pages?\b|pp\.?|f\.|ff\.|folios?\b)(?!\.?\s*l\.)(?!\.?\s*(?:de|of)\s+pl)/i);
  if (!m) return null;
  const n = parseInt(m[1], 10);
  return Number.isInteger(n) && n > 0 && n < 100000 ? n : null;
}

// Annee : extrait un millesime a 4 chiffres si present, sinon la valeur nettoyee.
function yearText(value) {
  const v = clean(value);
  if (!v) return null;
  const m = v.match(/\d{4}/);
  return m ? m[0] : v;
}

// ── Detection de dialecte (par enregistrement) ──────────────

export function detectDialect(record) {
  const has = (tag) => record.fields.some((f) => f.tag === tag);
  // Le titre est l'indicateur le plus fiable.
  if (has('245')) return 'marc21';
  if (has('200')) return 'unimarc';
  // Fallback : zone de publication.
  if (has('210')) return 'unimarc';
  if (has('260') || has('264')) return 'marc21';
  // Defaut prudent : MARC21 (le plus repandu).
  return 'marc21';
}

// ── Mapping vers la forme normalisee ────────────────────────

export function mapMarcRecord(record, dialect, itemMapping = null) {
  const def = CHAMPS[dialect === 'unimarc' ? 'unimarc' : 'marc21'];
  // MARC21 : la ponctuation ISBD retirée des zones descriptives (revue du 28/09).
  const ISBD = new Set(['title', 'subtitle', 'responsibility', 'volumeNumber', 'volumeName', 'place', 'publisher', 'keyTitle', 'hostTitle']);
  const lire = (k) => {
    const v = lireChamp(record, def[k]);
    return dialect === 'marc21' && ISBD.has(k) && typeof v === 'string' ? sansIsbd(v) : v;
  };

  let title = lire('title');
  const subtitle = lire('subtitle');
  const responsibility = lire('responsibility');
  const contributors = responsabilites(record, dialect === 'unimarc' ? 'unimarc' : 'marc21');
  const names = contributors.map((c) => c.name);
  const publisher = lire('publisher');
  const placeOfPublication = lire('place');
  const publicationYear = yearText(lire('year'));
  const editionStatement = lire('edition');
  const language = lire('language');
  const isbn = lire('isbn');
  const issn = lire('issn');
  const subjectsArray = sujets(record, dialect === 'unimarc' ? 'unimarc' : 'marc21');
  const keywordsArray = motsCles(record, dialect === 'unimarc' ? 'unimarc' : 'marc21');
  const externalKey = controlValue(record, CONTROLE);

  // itemType : type d'enregistrement (leader/06) + niveau bibliographique
  // (leader/07), tels quels — diagnostic, non normalise plus avant ici.
  // materialType : le type AnarBib qui s'en déduit (H17 : un article dépouillé,
  // un périodique, un enregistrement sonore ne sont plus des « livro »).
  const leader = typeof record.leader === 'string' ? record.leader : '';
  const itemType = clean((leader[6] || '') + (leader[7] || '')) || null;
  let materialType = typeDepuisGuide(leader, dialect === 'unimarc' ? 'unimarc' : 'marc21');

  // responsibilityStatement : la mention de responsabilite si presente,
  // sinon la liste des noms concatenee (fallback).
  const responsibilityStatement = responsibility || (names.length ? names.join('; ') : null);

  // H17 : étendue et pages ; volume (200 $h $i, ou le $v d'une 461 de
  // monographie) ; collection (225/410) ; notes (résumé, note, sommaire) ;
  // classification (676 / 082) ; adresse (856) ; titre clé (530) ; notice hôte
  // et fascicule d'un article dépouillé (461 / 463, 773).
  const extent = lire('extent');
  const host = { title: lire('hostTitle'), issn: lire('hostIssn'), volume: lire('hostVolume') };
  const issue = { number: lire('issueNumber'), date: lire('issueDate'), title: lire('issueTitle') };
  let volume = [lire('volumeNumber'), lire('volumeName')].filter(Boolean).join(' : ')
    || (materialType !== 'artigo' ? host.volume : null) || null;
  const serie = collection(record, def);
  const seriesTitle = dialect === 'marc21' ? sansIsbd(serie.titre) : serie.titre;
  const seriesNumber = dialect === 'marc21' ? sansIsbd(serie.numero) : serie.numero;
  let keyTitle = lire('keyTitle');
  // PMB : la « notice de bulletin » qui porte les exemplaires d'un fascicule
  // sans notice propre (463 $9 lnk:bull_expl ; 200 « Notice de bulletin »,
  // $h le périodique, $i le numéro). C'est un fascicule : un périodique, son
  // titre, son numéro, sa date — pas un article sans revue (revue du 28/09).
  const bulletinPmb = dialect === 'unimarc' && fieldsByTag(record, '463').some((f) =>
    (f.subfields || []).some((s) => s.code === '9' && clean(s.value) === 'lnk:bull_expl'));
  if (bulletinPmb) {
    const perio = issue.title || lire('volumeNumber');
    materialType = 'periodico';
    keyTitle = perio || keyTitle;
    title = perio || title;
    volume = issue.number || lire('volumeName') || null;
    issue.title = null;
  }
  const notes = [...lire('summary'), ...lire('notes'), ...lire('contents')];

  return {
    title,
    subtitle,
    responsibilityStatement,
    authorsArray: names,
    publisher,
    placeOfPublication,
    publicationYear,
    editionStatement,
    language,
    isbn,
    issn,
    subjectsArray,
    keywordsArray,
    itemType,
    externalKey,
    // H19 : les exemplaires physiques (995 / 852), selon la correspondance
    // du profil de la bibliotheque (defaut PMB 8.1).
    items: extractItems(record, dialect, itemMapping),
    // H17
    materialType,
    extent,
    pages: pagesDepuisEtendue(extent),
    volume,
    series: seriesTitle ? (seriesNumber ? `${seriesTitle} ; ${seriesNumber}` : seriesTitle) : null,
    notes: notes.length ? notes.join('\n\n') : null,
    classification: lire('classification'),
    url: lire('url'),
    keyTitle,
    host: (host.title || host.issn || host.volume) ? host : null,
    issue: (issue.number || issue.date || issue.title) ? issue : null,
    // H18
    contributors,
  };
}

// H17 / H18 : ce que la forme normalisée MARC porte au-delà du socle commun
// aux formats (CSV, RIS…), pour la ligne de staging (normalized_payload) —
// seulement ce qui a une valeur. Lu par ingest.fn_create_book_drafts_from_import_rows.
export function mappedExtras(mapped) {
  const out = {};
  const scalaires = {
    material_type: mapped.materialType, extent: mapped.extent, pages: mapped.pages, volume: mapped.volume,
    series: mapped.series, notes: mapped.notes, classification: mapped.classification, url: mapped.url,
    key_title: mapped.keyTitle, host: mapped.host, issue: mapped.issue,
  };
  for (const [k, v] of Object.entries(scalaires)) if (v !== null && v !== undefined && v !== '') out[k] = v;
  // H27 : les mots-clés libres, à part des vedettes (subjects).
  if (Array.isArray(mapped.keywordsArray) && mapped.keywordsArray.length) out.keywords = mapped.keywordsArray;
  if (Array.isArray(mapped.contributors) && mapped.contributors.length) {
    out.contributors = mapped.contributors.map((c) => ({
      name: c.name, nature: c.nature, role: c.role, role_code: c.roleCode ?? null,
      primary: !!c.primary, dates: c.dates ?? null, authority_ref: c.authorityRef ?? null, tag: c.tag ?? null,
    }));
  }
  return out;
}

// ── MARCXML ─────────────────────────────────────────────────

function decodeXmlEntities(s) {
  return s
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#x([0-9a-fA-F]+);/g, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)))
    .replace(/&amp;/g, '&'); // en dernier pour ne pas re-decoder
}

// Detecte si un texte ressemble a du MARCXML.
export function looksLikeMarcXml(text) {
  if (!text) return false;
  const head = text.slice(0, 4000);
  const hasRecord = /<(?:\w+:)?record[\s>]/.test(head) || /<(?:\w+:)?record[\s>]/.test(text);
  const hasMarcEl = /<(?:\w+:)?(?:leader|controlfield|datafield)\b/.test(text);
  return hasRecord && hasMarcEl;
}

// Parse un MARCXML (tolerant aux prefixes de namespace type "marc:").
// Retourne un tableau d'enregistrements au modele commun.
export function parseMarcXml(text) {
  const records = [];
  const recordRe = /<(?:\w+:)?record\b[^>]*>([\s\S]*?)<\/(?:\w+:)?record>/g;
  let rm;
  while ((rm = recordRe.exec(text)) !== null) {
    const body = rm[1];
    const fields = [];
    let leader = '';

    const leaderM = body.match(/<(?:\w+:)?leader\b[^>]*>([\s\S]*?)<\/(?:\w+:)?leader>/);
    if (leaderM) leader = decodeXmlEntities(leaderM[1]);

    const ctrlRe = /<(?:\w+:)?controlfield\b[^>]*\btag="([^"]*)"[^>]*>([\s\S]*?)<\/(?:\w+:)?controlfield>/g;
    let cm;
    while ((cm = ctrlRe.exec(body)) !== null) {
      fields.push({ tag: cm[1].trim(), value: decodeXmlEntities(cm[2]) });
    }

    const dataRe = /<(?:\w+:)?datafield\b([^>]*)>([\s\S]*?)<\/(?:\w+:)?datafield>/g;
    let dm;
    while ((dm = dataRe.exec(body)) !== null) {
      const attrs = dm[1];
      const inner = dm[2];
      const tag = (attrs.match(/\btag="([^"]*)"/) || [, ''])[1].trim();
      const ind1 = (attrs.match(/\bind1="([^"]*)"/) || [, ' '])[1] || ' ';
      const ind2 = (attrs.match(/\bind2="([^"]*)"/) || [, ' '])[1] || ' ';
      const subfields = [];
      const subRe = /<(?:\w+:)?subfield\b[^>]*\bcode="([^"]*)"[^>]*>([\s\S]*?)<\/(?:\w+:)?subfield>/g;
      let sm;
      while ((sm = subRe.exec(inner)) !== null) {
        subfields.push({ code: sm[1].trim(), value: decodeXmlEntities(sm[2]) });
      }
      fields.push({ tag, ind1, ind2, subfields });
    }

    records.push({ leader, fields });
  }
  return records;
}

// ── XML propre à PMB (H22) ──────────────────────────────────
//
// L'export « UNIMARC PMB XML » de PMB : <unimarc><notice> ; le guide éclaté en
// <rs> (statut), <dt> (type), <bl> (niveau), <hl> (hiérarchie), <el> (niveau
// de codage), <ru> (règles) ; <f c="001">valeur</f> ; <f c="200" ind="1 ">
// <s c="a">…</s></f>. Lu vers le modèle commun : rien ne change en aval.
export function looksLikePmbXml(text) {
  if (!text) return false;
  const head = text.slice(0, 4000);
  return /<unimarc[\s>]/.test(head) && /<notice[\s>]/.test(text) && /<f\s+c="/.test(text);
}

export function parsePmbXml(text) {
  const records = [];
  const noticeRe = /<notice\b[^>]*>([\s\S]*?)<\/notice>/g;
  let nm;
  while ((nm = noticeRe.exec(text)) !== null) {
    const body = nm[1];
    const el = (name, defaut) => {
      const m = body.match(new RegExp(`<${name}>([^<]*)</${name}>`));
      const v = m ? decodeXmlEntities(m[1]) : '';
      return (v || defaut).slice(0, 1);
    };
    // Guide UNIMARC reconstitué : longueur et adresse à zéro (sans objet hors
    // ISO 2709), indicateurs « 22 », fin « 450 ».
    const leader = `00000${el('rs', 'n')}${el('dt', 'a')}${el('bl', 'm')}${el('hl', ' ')} 2200000${el('el', ' ')}${el('ru', ' ')} 450 `;
    const fields = [];
    const fRe = /<f\s+c="([^"]*)"([^>]*)>([\s\S]*?)<\/f>/g;
    let fm;
    while ((fm = fRe.exec(body)) !== null) {
      const tag = fm[1].trim();
      const inner = fm[3];
      if (!/<s\s+c="/.test(inner)) {
        fields.push({ tag, value: decodeXmlEntities(inner) });
        continue;
      }
      const ind = (fm[2].match(/\bind="([^"]*)"/) || [, '  '])[1];
      const subfields = [];
      const sRe = /<s\s+c="([^"]*)"[^>]*>([\s\S]*?)<\/s>/g;
      let sm;
      // PMB garde les fins de ligne Windows dans ce format (pas dans son ISO
      // 2709) : normalisées, pour que les deux exports donnent la même notice.
      while ((sm = sRe.exec(inner)) !== null) subfields.push({ code: sm[1], value: decodeXmlEntities(sm[2]).replace(/\r\n?/g, '\n') });
      fields.push({ tag, ind1: ind[0] || ' ', ind2: ind[1] || ' ', subfields });
    }
    records.push({ leader, fields });
  }
  return records;
}

// ── ISO 2709 binaire ────────────────────────────────────────

const RT = 0x1d; // record terminator
const FT = 0x1e; // field terminator
const SD = 0x1f; // subfield delimiter

// Detecte si un buffer d'octets ressemble a de l'ISO 2709.
// Heuristique : 5 premiers octets = chiffres ASCII (longueur d'enregistrement),
// base address (octets 12-16) = chiffres, presence d'un field terminator.
export function looksLikeIso2709(bytes) {
  if (!bytes || bytes.length < 26) return false;
  const isDigit = (b) => b >= 0x30 && b <= 0x39;
  for (let i = 0; i < 5; i++) if (!isDigit(bytes[i])) return false;
  for (let i = 12; i < 17; i++) if (!isDigit(bytes[i])) return false;
  return bytes.includes(FT);
}

function leaderIsMarc8(leaderBytes) {
  // Position 9 du leader : 'a' (0x61) = UCS/Unicode, ' ' (0x20) = MARC-8.
  // Sens MARC21 seulement : en UNIMARC cette position n'est pas definie.
  return leaderBytes[9] === 0x20;
}

// Parse un buffer ISO 2709 (potentiellement multi-enregistrements).
// Retourne { records, warnings } ; warnings collecte les avertissements
// globaux (ex. encodage MARC-8 sur une notice MARC21).
// options.encoding : encodage retenu par l'appelant (defaut 'utf-8') ;
// options.forcedDialect : 'unimarc' | 'marc21' | null (sinon detectDialect).
export function parseMarcIso2709(bytes, options = {}) {
  const decoder = new TextDecoder(options.encoding || 'utf-8');
  const forcedDialect = options.forcedDialect || null;
  const records = [];
  const warnings = [];
  let marc8Warned = false;

  let pos = 0;
  while (pos < bytes.length) {
    // Sauter d'eventuels separateurs/espaces residuels entre enregistrements.
    while (pos < bytes.length && (bytes[pos] === RT || bytes[pos] === 0x0a || bytes[pos] === 0x0d)) pos++;
    if (pos >= bytes.length) break;
    if (bytes.length - pos < 24) break;

    // Longueur d'enregistrement = 5 premiers chiffres du leader.
    const lenStr = decoder.decode(bytes.subarray(pos, pos + 5));
    const recLen = parseInt(lenStr, 10);
    if (!Number.isInteger(recLen) || recLen < 26 || pos + recLen > bytes.length) {
      // Longueur invalide : on stoppe pour ne pas boucler.
      break;
    }
    const rec = bytes.subarray(pos, pos + recLen);
    pos += recLen;

    const leaderBytes = rec.subarray(0, 24);
    const leader = decoder.decode(leaderBytes);
    const leader9Blank = leaderIsMarc8(leaderBytes);

    // Base address of data = leader[12..16].
    const baseAddr = parseInt(decoder.decode(rec.subarray(12, 17)), 10);
    if (!Number.isInteger(baseAddr) || baseAddr < 24 || baseAddr > recLen) {
      records.push({ leader, fields: [] });
      continue;
    }

    // Directory : de l'octet 24 jusqu'au field terminator precedant baseAddr.
    const fields = [];
    const dirEnd = baseAddr - 1; // position du FT de fin de directory
    for (let d = 24; d + 12 <= dirEnd; d += 12) {
      const tag = decoder.decode(rec.subarray(d, d + 3));
      const fieldLen = parseInt(decoder.decode(rec.subarray(d + 3, d + 7)), 10);
      const startPos = parseInt(decoder.decode(rec.subarray(d + 7, d + 12)), 10);
      if (!Number.isInteger(fieldLen) || !Number.isInteger(startPos)) continue;
      const fStart = baseAddr + startPos;
      const fEnd = fStart + fieldLen;
      if (fStart >= rec.length || fEnd > rec.length) continue;
      // Donnees du champ sans le field terminator final.
      let dataEnd = fEnd;
      if (rec[dataEnd - 1] === FT) dataEnd -= 1;
      const fieldBytes = rec.subarray(fStart, dataEnd);

      if (tag < '010') {
        // Controlfield (00X) : valeur brute.
        fields.push({ tag, value: decoder.decode(fieldBytes) });
      } else {
        // Datafield : ind1, ind2, puis sous-zones delimitees par 0x1F.
        const ind1 = fieldBytes.length > 0 ? decoder.decode(fieldBytes.subarray(0, 1)) : ' ';
        const ind2 = fieldBytes.length > 1 ? decoder.decode(fieldBytes.subarray(1, 2)) : ' ';
        const subfields = [];
        // Le corps des sous-zones commence apres les 2 indicateurs.
        let i = 2;
        while (i < fieldBytes.length) {
          if (fieldBytes[i] === SD) {
            const code = String.fromCharCode(fieldBytes[i + 1]);
            let j = i + 2;
            while (j < fieldBytes.length && fieldBytes[j] !== SD) j++;
            const value = decoder.decode(fieldBytes.subarray(i + 2, j));
            subfields.push({ code, value });
            i = j;
          } else {
            i++;
          }
        }
        fields.push({ tag, ind1, ind2, subfields });
      }
    }

    const record = { leader, fields };
    // Le leader/9 blanc ne dit « MARC-8 » qu'en MARC21 : le dialecte se decide
    // sur la notice entiere (ou est impose par forced_vocabulary).
    if (!marc8Warned && leader9Blank && (forcedDialect || detectDialect(record)) === 'marc21') {
      warnings.push(`Encodage MARC-8 detecte (MARC21, leader/9=blank) : decode en ${decoder.encoding}, caracteres non-ASCII potentiellement corrompus. Re-exporter en UTF-8 recommande.`);
      marc8Warned = true;
    }
    records.push(record);
  }

  return { records, warnings };
}

// ── Jeu de caracteres declare (UNIMARC) ─────────────────────
//
// UNIMARC 100 $a, positions 26-27 (jeu G0) et 28-29 (jeu G1). Codes :
// 01 ISO 646 (ASCII), 02 ISO Registration #37 (cyrillique de base),
// 03 ISO 5426 (latin etendu), 04 ISO DIS 5427 (cyrillique etendu),
// 05 ISO 5428 (grec), 06 ISO 6438 (Afrique), 07 ISO 10586 (georgien),
// 08/09 ISO 8957 (hebreu), 11 ISO 5426-2, 50 ISO 10646 (Unicode).
// PMB 8.1 ecrit « 50 » (constate sur son jeu de test).
export const UNIMARC_CHARSETS = {
  '01': 'ISO 646', '02': 'ISO Registration #37', '03': 'ISO 5426', '04': 'ISO DIS 5427',
  '05': 'ISO 5428', '06': 'ISO 6438', '07': 'ISO 10586', '08': 'ISO 8957 (1)',
  '09': 'ISO 8957 (2)', '11': 'ISO 5426-2', '50': 'ISO 10646 (Unicode)',
};

// → { g0, g1 } (codes a 2 caracteres, blancs retires ; '' si absent) ou null
//   si la notice n'a pas de 100 $a assez long.
export function unimarcDeclaredCharset(record) {
  const f = (record?.fields || []).find((x) => x.tag === '100' && Array.isArray(x.subfields));
  const a = f?.subfields.find((s) => s.code === 'a')?.value;
  if (typeof a !== 'string' || a.length < 28) return null;
  return { g0: a.slice(26, 28).trim(), g1: a.slice(28, 30).trim() };
}

// Avertissements de run tires du jeu declare, compare a l'encodage retenu.
// declared : liste des codes G0 distincts des notices UNIMARC ;
// decoded  : { encoding, fallback } (encoding.ts) ; hasNonAscii : le fichier
// contient-il un octet > 0x7F (sinon aucun jeu ne peut etre faux).
export function unimarcCharsetWarnings(declared, decoded, hasNonAscii) {
  const out = [];
  const codes = [...new Set((declared || []).filter(Boolean))];
  if (!codes.length || !hasNonAscii) return out;
  if (codes.includes('50') && decoded?.fallback) {
    out.push('Le fichier declare de l\'Unicode (UNIMARC 100 $a/26-27 = 50) mais n\'est pas de l\'UTF-8 valide : encodage suppose ' + decoded.encoding + '.');
  }
  const nonGeres = codes.filter((c) => c !== '50' && c !== '01');
  if (nonGeres.length) {
    out.push('Jeu de caracteres declare non pris en charge (UNIMARC 100 $a/26-27 = '
      + nonGeres.map((c) => `${c} ${UNIMARC_CHARSETS[c] || 'inconnu'}`).join(', ')
      + ') : decode en ' + (decoded?.encoding || 'utf-8') + ', caracteres non-ASCII potentiellement faux. Re-exporter en UTF-8 recommande.');
  }
  return out;
}

// ── Entree de haut niveau ───────────────────────────────────

// ── Couverture (H16, 26/09/2026) ────────────────────────────
//
// Ce que l'import REPREND d'un fichier MARC, et ce qu'il laisse seulement dans
// l'enregistrement brut (raw_payload -> book_drafts.marc_json : rien n'est
// detruit, mais rien n'entre dans les champs de la notice). La SEULE reference
// de « repris » est la table de zones du dialecte (MARC21 / UNIMARC ci-dessus) :
// ajouter une zone a la table la fait passer d'elle-meme en « reprise ».
//
// Par sous-zone : occurrences, notices concernees, un exemple (tronque), et
// `surplus` = occurrences repetees dans une meme notice alors que la table n'en
// reprend qu'UNE (titre, editeur, langue… : firstFromList) — la 2e 101 $a d'un
// livre bilingue, par exemple, n'entre nulle part.
const COVERAGE_MAX_ZONES = 400;
const COVERAGE_EXAMPLE_LEN = 80;

// H17 : « repris » se lit dans la table commune — champs, sujets (vedette et
// subdivisions), responsabilités (nom, dates, rôle, autorité) — ; « laissé »
// (exprès, avec sa raison) dans ZONES_LAISSEES ; le reste est « brut ».
function consumedSubfields(dialect, itemMapping) {
  const m = new Map();
  // Le titre du fascicule ne va dans aucun champ du brouillon : laissé.
  const NON_ECRITS = new Set(['issueTitle']);
  for (const [cle, champ] of Object.entries(CHAMPS[dialect])) {
    if (NON_ECRITS.has(cle)) continue;
    for (const [tag, code] of champ.zones) m.set(`${tag}$${code}`, champ.mode === 'first' ? 'first' : 'all');
  }
  const s = SUJETS[dialect];
  for (const tag of s.tags) for (const code of [...s.vedette, ...s.subdivisions]) m.set(`${tag}$${code}`, 'all');
  for (const z of RESPONSABILITES[dialect]) {
    // Les dates et la référence d'autorité de la source restent dans
    // l'enregistrement d'origine (aucune colonne) : laissées, pas reprises.
    for (const code of [...z.nom, z.role, z.roleTerme, ...(z.qualificatifs || [])].filter(Boolean)) m.set(`${z.tag}$${code}`, 'all');
  }
  // H19 : sous-zones d'exemplaire. Les cles structurees entrent dans
  // l'exemplaire (reprises) ; type, public, statut vont dans sa note de
  // provenance (indice), en attendant leur correspondance (IMP-21 d).
  // 'item_single' (code, proprietaire) : une repetition DANS la meme zone
  // n'est pas reprise (surplus) ; une lettre lue aussi par une cle a valeurs
  // multiples ne perd rien ('item' l'emporte).
  if (itemMapping) {
    for (const k of ITEM_SINGLE_KEYS) for (const c of (itemMapping[k] || '')) m.set(`${itemMapping.tag}$${c}`, 'item_single');
    for (const k of ITEM_STRUCTURED_KEYS) {
      if (ITEM_SINGLE_KEYS.includes(k)) continue;
      for (const c of (itemMapping[k] || '')) m.set(`${itemMapping.tag}$${c}`, 'item');
    }
    for (const k of ITEM_NOTE_KEYS) for (const c of (itemMapping[k] || '')) if (!m.has(`${itemMapping.tag}$${c}`)) m.set(`${itemMapping.tag}$${c}`, 'item_note');
  }
  return m;
}

// entries : sortie de buildParsedEntriesFromMarc ({ dialect, rawPayload }).
// itemMappingOverride : correspondance d'exemplaires du profil (H19), ou null.
// → { kind: 'marc', records, zones: [{ dialect, tag, code, status, occurrences,
//     records, surplus, example }], truncated }
//   status : 'repris' | 'indice' | 'laisse' | 'brut' ; code '' pour une zone
//   de controle ; motif : pourquoi une zone est laissée exprès (H17, codé :
//   correspondance.ts, MOTIFS).
export function marcCoverage(entries, itemMappingOverride = null) {
  const zones = new Map();
  const CONSUMED = {
    marc21: consumedSubfields('marc21', resolveItemMapping('marc21', itemMappingOverride)),
    unimarc: consumedSubfields('unimarc', resolveItemMapping('unimarc', itemMappingOverride)),
  };
  for (const e of entries || []) {
    const dialect = e.dialect === 'unimarc' ? 'unimarc' : 'marc21';
    const consumed = CONSUMED[dialect];
    const perRecord = new Map();
    const note = (tag, code, value, status, kind, repeatedInField = false) => {
      const key = `${dialect}|${tag}|${code}`;
      let z = zones.get(key);
      if (!z) {
        const motif = status === 'laisse' ? zoneLaissee(dialect, tag, code || '*') : null;
        z = { dialect, tag, code, status, occurrences: 0, records: 0, surplus: 0, example: null, ...(motif ? { motif } : {}) };
        zones.set(key, z);
      }
      z.occurrences += 1;
      const n = (perRecord.get(key) || 0) + 1;
      perRecord.set(key, n);
      if (n === 1) z.records += 1;
      else if (kind === 'first') z.surplus += 1;
      // Une notice porte plusieurs zones d'exemplaire : le surplus d'un code
      // d'exemplaire se compte PAR ZONE, pas par notice.
      if (kind === 'item_single' && repeatedInField) z.surplus += 1;
      const v = clean(value);
      if (!z.example && v) z.example = v.length > COVERAGE_EXAMPLE_LEN ? v.slice(0, COVERAGE_EXAMPLE_LEN) + '…' : v;
    };
    for (const f of (e.rawPayload?.fields || [])) {
      if (typeof f.value === 'string') {
        note(f.tag, '', f.value, f.tag === CONTROLE ? 'repris' : (zoneLaissee(dialect, f.tag, '*') ? 'laisse' : 'brut'), null);
      } else {
        const perField = new Map();
        for (const s of (f.subfields || [])) {
          const kind = consumed.get(`${f.tag}$${s.code}`) || null;
          const status = !kind ? (zoneLaissee(dialect, f.tag, s.code) ? 'laisse' : 'brut')
            : (kind === 'item_note' ? 'indice' : 'repris');
          const nf = (perField.get(s.code) || 0) + 1;
          perField.set(s.code, nf);
          note(f.tag, s.code, s.value, status, kind, nf > 1);
        }
      }
    }
  }
  const all = [...zones.values()].sort((a, b) =>
    a.dialect.localeCompare(b.dialect) || a.tag.localeCompare(b.tag) || a.code.localeCompare(b.code));
  return {
    kind: 'marc',
    records: (entries || []).length,
    zones: all.slice(0, COVERAGE_MAX_ZONES),
    truncated: all.length > COVERAGE_MAX_ZONES,
  };
}

// Construit les entrees normalisees a partir d'enregistrements MARC deja parses.
// Chaque entree : { rowNo, rawPayload, mapped, warnings, dialect }.
export function buildParsedEntriesFromMarc(records, baseWarnings = [], forcedDialect = null, itemMapping = null) {
  return records.map((record, idx) => {
    // forcedDialect ('unimarc' | 'marc21') = override de l'axe Vocabulário ; sinon auto.
    const dialect = forcedDialect || detectDialect(record);
    const mapped = mapMarcRecord(record, dialect, itemMapping);
    return {
      rowNo: idx + 1,
      // item_tag : la zone d'exemplaire lue (profil compris) ; l'export ne la
      // réémet jamais de l'origine (H24).
      rawPayload: { leader: record.leader, fields: record.fields, marc_dialect: dialect, item_tag: resolveItemMapping(dialect, itemMapping).tag },
      mapped,
      warnings: idx === 0 ? baseWarnings.slice() : [],
      dialect,
    };
  });
}

// Jeux G0 declares (UNIMARC 100 $a/26-27) des notices UNIMARC, distincts.
function declaredCharsets(entries) {
  const out = new Set();
  for (const e of entries) {
    if (e.dialect !== 'unimarc') continue;
    const cs = unimarcDeclaredCharset(e.rawPayload);
    if (cs && cs.g0) out.add(cs.g0);
  }
  return [...out];
}

// Detecte + parse un fichier MARC. Retourne null si ce n'est pas du MARC,
// sinon { format, entries, declaredCharsets }.
//   format : 'marcxml' | 'marc_iso2709'
//   encoding : encodage retenu par l'appelant pour les octets ISO 2709
//              (le MARCXML arrive deja decode dans `text`).
//   itemMapping : correspondance d'exemplaires du profil (H19), ou null.
export function parseMarcFile({ text, bytes, filename, forcedDialect = null, encoding = 'utf-8', itemMapping = null }) {
  const name = (filename || '').toLowerCase();

  // 1. MARCXML (texte). Prioritaire : signature XML tres distinctive.
  if (looksLikeMarcXml(text) || (name.endsWith('.xml') && /<(?:\w+:)?record\b/.test(text || ''))) {
    const records = parseMarcXml(text);
    if (records.length) {
      const entries = buildParsedEntriesFromMarc(records, [], forcedDialect, itemMapping);
      return { format: 'marcxml', entries, declaredCharsets: declaredCharsets(entries) };
    }
  }

  // 1 bis. XML propre à PMB (H22) : toujours de l'UNIMARC.
  if (looksLikePmbXml(text)) {
    const records = parsePmbXml(text);
    if (records.length) {
      const entries = buildParsedEntriesFromMarc(records, [], forcedDialect || 'unimarc', itemMapping);
      return { format: 'pmb_xml', entries, declaredCharsets: declaredCharsets(entries) };
    }
  }

  // 2. ISO 2709 binaire (octets).
  if (bytes && (looksLikeIso2709(bytes) || name.endsWith('.mrc') || name.endsWith('.marc') || name.endsWith('.iso'))) {
    if (looksLikeIso2709(bytes)) {
      const { records, warnings } = parseMarcIso2709(bytes, { encoding, forcedDialect });
      if (records.length) {
        const entries = buildParsedEntriesFromMarc(records, warnings, forcedDialect, itemMapping);
        return { format: 'marc_iso2709', entries, declaredCharsets: declaredCharsets(entries) };
      }
    }
  }

  return null;
}
