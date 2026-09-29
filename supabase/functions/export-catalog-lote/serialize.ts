// Serialiseur de catalogue pour l'export de lote (Lot 5, IMP-13 ; H23, H24).
//
// Session : Lot 5 — Export de lote
// Auteur  : Claude Opus 4.8
//
// Miroir (sens inverse) du parser d'import marc.ts : prend un tableau de
// notices NORMALISEES et produit un fichier dans un format de sortie.
//
// H23 (28/09/2026) : les formats MARC s'écrivent depuis la table de
// correspondance COMMUNE à l'import et à l'export (_shared/marc/) — UNIMARC en
// ISO 2709 et en XML (la forme « XML MARC » que PMB relit), MARC21 en ISO 2709
// et en MARCXML. La correspondance n'est plus écrite deux fois.
//
// Notice normalisée : la forme rendue par public.fn_export_catalog_lote (voir
// NoticeExport, _shared/marc/ecriture.ts) ; la forme d'avant H24 (authors,
// subjects en texte) reste lue.

import { enregistrement, type NoticeExport } from '../_shared/marc/ecriture.ts';
import { ecrireIso2709, type Avertissement } from '../_shared/marc/iso2709.ts';
import { ecrireMarcXml } from '../_shared/marc/marcxml.ts';

export const SERIALIZER_VERSION = 'export_v2';

export const SUPPORTED_FORMATS = ['csv', 'marcxml', 'json', 'unimarc_iso2709', 'unimarc_xml', 'marc21_iso2709'];

function s(value) {
  if (value === null || value === undefined) return '';
  return String(value);
}

function authorNames(record) {
  if (Array.isArray(record.contributors) && record.contributors.length) {
    return record.contributors.map((c) => s(c?.name).trim()).filter(Boolean);
  }
  const list = Array.isArray(record.authors) ? record.authors : [];
  return list.map((a) => s(a?.name).trim()).filter(Boolean);
}

function subjectList(record) {
  const list = Array.isArray(record.subjects) ? record.subjects : [];
  return list.map((x) => s(typeof x === 'object' && x !== null ? x.label : x).trim()).filter(Boolean);
}

// ── CSV (RFC 4180) ──────────────────────────────────────────
//
// En-tetes choisis pour etre RECONNUS par l'importeur (mapRecord/mapRisRecord
// acceptent ces alias) -> un export CSV peut etre re-importe (round-trip).

const CSV_COLUMNS = [
  { header: 'external_key', get: (r) => s(r.originId) || s(r.bibRef) || s(r.id) },
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

// ── MARC (UNIMARC, MARC21) ──────────────────────────────────

export interface OptionsMarc {
  date?: string;
  bibliotheque?: { nom?: string | null; pays?: string | null; langue?: string | null } | null;
}

// PMB lit un fichier dans l'ordre. Un article dont la 461 ne porte pas à la
// fois le titre et un volume n'est rattaché à sa revue que par la 464 de la
// revue, lue AVANT lui (admin/import/import_func.inc.php, sous « Générer les
// liens entre notices ? » : la 464 met l'article « en attente », consommée
// quand sa notice arrive ; un article lu sans rien en attente redevient une
// monographie). Mesuré au banc le 29/09 : dans l'ordre de l'écran (par id),
// huit articles précédaient leur revue, 7 rattachés sur 15 ; rangés, 15 sur 15.
// Les périodiques d'abord, les articles en dernier, l'ordre reçu entre eux —
// en MARC seulement (le CSV et le JSON gardent l'ordre reçu).
const RANG_MARC: Record<string, number> = { periodico: 0, artigo: 2 };
export function ordreMarc<T extends { materialType?: string | null }>(records: T[]): T[] {
  return records.map((r, i) => ({ r, i }))
    .sort((a, b) => ((RANG_MARC[a.r?.materialType ?? ''] ?? 1) - (RANG_MARC[b.r?.materialType ?? ''] ?? 1)) || (a.i - b.i))
    .map((x) => x.r);
}

function notices(records: NoticeExport[], dialecte: 'unimarc' | 'marc21', opts: OptionsMarc = {}) {
  return ordreMarc(records).map((r) => enregistrement(r, { dialecte, date: opts.date, bibliotheque: opts.bibliotheque }));
}

// MARCXML en MARC21 (espace de noms MARC21 slim).
export function toMarcXml(records, opts: OptionsMarc = {}) {
  return ecrireMarcXml(notices(records, 'marc21', opts), { espaceDeNoms: true });
}

// UNIMARC en XML : la forme « XML MARC » de PMB, sans espace de noms.
export function toUnimarcXml(records, opts: OptionsMarc = {}) {
  return ecrireMarcXml(notices(records, 'unimarc', opts), { espaceDeNoms: false });
}

export function toIso2709(records, dialecte: 'unimarc' | 'marc21', opts: OptionsMarc = {}) {
  return ecrireIso2709(notices(records, dialecte, opts));
}

// ── JSON ────────────────────────────────────────────────────

export function toJson(records) {
  return JSON.stringify(records, null, 2) + '\n';
}

// ── Dispatcher ──────────────────────────────────────────────

// Retourne { ext, mime, content, avertissements } pour le format demande.
// content : une chaîne, ou des octets (ISO 2709).
export function serializeCatalog(records, format, opts: OptionsMarc = {}): {
  ext: string; mime: string; content: string | Uint8Array; avertissements: Avertissement[];
} {
  const rows = Array.isArray(records) ? records : [];
  switch (format) {
    case 'csv':
      return { ext: 'csv', mime: 'text/csv; charset=utf-8', content: toCsv(rows), avertissements: [] };
    case 'marcxml':
      return { ext: 'xml', mime: 'application/marcxml+xml; charset=utf-8', content: toMarcXml(rows, opts), avertissements: [] };
    case 'unimarc_xml':
      return { ext: 'xml', mime: 'application/xml; charset=utf-8', content: toUnimarcXml(rows, opts), avertissements: [] };
    case 'unimarc_iso2709':
    case 'marc21_iso2709': {
      const r = toIso2709(rows, format === 'unimarc_iso2709' ? 'unimarc' : 'marc21', opts);
      return { ext: 'mrc', mime: 'application/marc', content: r.octets, avertissements: r.avertissements };
    }
    case 'json':
      return { ext: 'json', mime: 'application/json; charset=utf-8', content: toJson(rows), avertissements: [] };
    default:
      throw new Error(`Unsupported export format: ${format}`);
  }
}
