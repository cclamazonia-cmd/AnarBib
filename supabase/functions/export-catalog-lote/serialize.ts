// Serialiseur de catalogue pour l'export de lote (Lot 5, IMP-13).
//
// Session : Lot 5 — Export de lote
// Auteur  : Claude Opus 4.8
//
// Miroir (sens inverse) du parser d'import marc.ts : prend un tableau de
// notices NORMALISEES et produit un fichier dans un format de sortie.
// Iteration 1 : CSV, MARCXML, JSON (UNIMARC ISO 2709 / Dublin Core / BibTeX
// viendront ensuite, cf. IMP-13).
//
// Notice normalisee attendue (assemblee par l'EF depuis books + book_authors
// + authors) :
//   { id, bibRef, title, subtitle, authors: [{ name, role, ord }],
//     responsibility, publisher, year, place, edition, isbn, issn, language,
//     pages, cdd, subjects: [string], collection, materialType, notes }

export const SERIALIZER_VERSION = 'export_v1';

export const SUPPORTED_FORMATS = ['csv', 'marcxml', 'json'];

function s(value) {
  if (value === null || value === undefined) return '';
  return String(value);
}

function authorNames(record) {
  const list = Array.isArray(record.authors) ? record.authors : [];
  return list.map((a) => s(a?.name).trim()).filter(Boolean);
}

function subjectList(record) {
  const list = Array.isArray(record.subjects) ? record.subjects : [];
  return list.map((x) => s(x).trim()).filter(Boolean);
}

// ── CSV (RFC 4180) ──────────────────────────────────────────
//
// En-tetes choisis pour etre RECONNUS par l'importeur (mapRecord/mapRisRecord
// acceptent ces alias) -> un export CSV peut etre re-importe (round-trip).

const CSV_COLUMNS = [
  { header: 'external_key', get: (r) => s(r.bibRef) || s(r.id) },
  { header: 'title', get: (r) => s(r.title) },
  { header: 'subtitle', get: (r) => s(r.subtitle) },
  { header: 'authors', get: (r) => authorNames(r).join('; ') },
  { header: 'publisher', get: (r) => s(r.publisher) },
  { header: 'place_of_publication', get: (r) => s(r.place) },
  { header: 'publication_year', get: (r) => s(r.year) },
  { header: 'edition_statement', get: (r) => s(r.edition) },
  { header: 'isbn', get: (r) => s(r.isbn) },
  { header: 'issn', get: (r) => s(r.issn) },
  { header: 'language', get: (r) => s(r.language) },
  { header: 'subjects', get: (r) => subjectList(r).join('; ') },
  { header: 'pages', get: (r) => s(r.pages) },
  { header: 'cdd', get: (r) => s(r.cdd) },
  { header: 'collection', get: (r) => s(r.collection) },
  { header: 'item_type', get: (r) => s(r.materialType) },
  { header: 'notes', get: (r) => s(r.notes) },
];

function csvEscape(value) {
  const v = s(value);
  return /[",\n\r]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v;
}

export function toCsv(records) {
  const header = CSV_COLUMNS.map((c) => c.header).join(',');
  const lines = records.map((r) => CSV_COLUMNS.map((c) => csvEscape(c.get(r))).join(','));
  // CRLF (RFC 4180). BOM ajoute par l'EF si besoin Excel.
  return [header, ...lines].join('\r\n') + '\r\n';
}

// ── MARCXML (MARC21 slim) ───────────────────────────────────

function xmlEscape(value) {
  return s(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// controlfield : omis si vide.
function cf(tag, value) {
  const v = s(value).trim();
  if (!v) return '';
  return `    <controlfield tag="${tag}">${xmlEscape(v)}</controlfield>`;
}

// datafield : subs = [[code, value], ...]. Sous-zones vides ignorees ;
// le champ entier est omis si plus aucune sous-zone.
function df(tag, ind1, ind2, subs) {
  const sf = subs
    .filter(([, v]) => s(v).trim())
    .map(([code, v]) => `      <subfield code="${code}">${xmlEscape(v)}</subfield>`)
    .join('\n');
  if (!sf) return '';
  return `    <datafield tag="${tag}" ind1="${ind1}" ind2="${ind2}">\n${sf}\n    </datafield>`;
}

function marcRecordXml(r) {
  const names = authorNames(r);
  const fields = [];
  fields.push(cf('001', s(r.bibRef) || s(r.id)));
  fields.push(df('020', ' ', ' ', [['a', r.isbn]]));
  fields.push(df('022', ' ', ' ', [['a', r.issn]]));
  fields.push(df('041', '0', ' ', [['a', r.language]]));
  fields.push(df('082', '0', '4', [['a', r.cdd]]));
  // 100 : entree principale (1re mention de responsabilite).
  if (names[0]) fields.push(df('100', '1', ' ', [['a', names[0]]]));
  // 245 : titre / sous-titre / mention de responsabilite.
  fields.push(df('245', '1', '0', [['a', r.title], ['b', r.subtitle], ['c', r.responsibility]]));
  fields.push(df('250', ' ', ' ', [['a', r.edition]]));
  // 264 : production/publication (place / editeur / date).
  fields.push(df('264', ' ', '1', [['a', r.place], ['b', r.publisher], ['c', r.year]]));
  // 300 : description materielle (pagination).
  fields.push(df('300', ' ', ' ', [['a', s(r.pages).trim() ? `${s(r.pages)} p.` : '']]));
  fields.push(df('490', '0', ' ', [['a', r.collection]]));
  fields.push(df('500', ' ', ' ', [['a', r.notes]]));
  // 650 : sujets (un champ par sujet).
  for (const subj of subjectList(r)) fields.push(df('650', ' ', '0', [['a', subj]]));
  // 700 : entrees secondaires (auteur·rices au-dela de la premiere).
  for (const name of names.slice(1)) fields.push(df('700', '1', ' ', [['a', name]]));

  const leader = '00000nam a2200000 a 4500';
  const body = fields.filter(Boolean).join('\n');
  return `  <record>\n    <leader>${leader}</leader>\n${body}\n  </record>`;
}

export function toMarcXml(records) {
  const recs = records.map(marcRecordXml).join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>\n` +
    `<collection xmlns="http://www.loc.gov/MARC21/slim">\n${recs}\n</collection>\n`;
}

// ── JSON ────────────────────────────────────────────────────

export function toJson(records) {
  return JSON.stringify(records, null, 2) + '\n';
}

// ── Dispatcher ──────────────────────────────────────────────

// Retourne { ext, mime, content } pour le format demande.
export function serializeCatalog(records, format) {
  const rows = Array.isArray(records) ? records : [];
  switch (format) {
    case 'csv':
      return { ext: 'csv', mime: 'text/csv; charset=utf-8', content: toCsv(rows) };
    case 'marcxml':
      return { ext: 'xml', mime: 'application/marcxml+xml; charset=utf-8', content: toMarcXml(rows) };
    case 'json':
      return { ext: 'json', mime: 'application/json; charset=utf-8', content: toJson(rows) };
    default:
      throw new Error(`Unsupported export format: ${format}`);
  }
}
