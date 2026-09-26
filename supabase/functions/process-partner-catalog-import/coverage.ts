// Couverture d'un import CSV/TSV ou RIS (H16, 26/09/2026) — pendant de
// marcCoverage (marc.ts) pour les formats à colonnes ou à balises.
//
// Pour chaque colonne (CSV) ou balise (RIS) du fichier : REPRISE (elle
// alimente un champ de la notice), INDICE (une fonction SQL la relit après coup
// dans l'enregistrement brut : collection, cote locale — voir
// ingest.fn_partner_catalog_extract_collection_hint et
// …_local_classification_hint), ou gardée seulement en BRUT (raw_payload →
// book_drafts.marc_json : rien n'est détruit, rien n'entre dans la notice).
// Relevé du 26/09 : l'import Solidaires (1 673 lignes) n'a repris que 4
// colonnes sur 17, sans que rien ne le dise.
//
// Module pur, sans import : testé sous Deno comme sous vitest (pont).

const COVERAGE_EXAMPLE_LEN = 80;

function clean(value) {
  if (value === null || value === undefined) return null;
  const s = String(value).trim();
  return s.length ? s : null;
}
const exemple = (v) => (v && v.length > COVERAGE_EXAMPLE_LEN ? v.slice(0, COVERAGE_EXAMPLE_LEN) + '…' : v);

// headers    : en-têtes NORMALISÉS (rowsToObjects)
// records    : objets en-tête → valeur
// fieldAliases : { champ: [alias normalisés] } — ceux de mapRecord
// columnMappings : profil { champ: 'Nom de colonne' } (normalisé par normalize)
// hintKeys   : { en-tête: 'collection' | 'cote' } relus par le SQL
// → { kind: 'csv', records, columns: [{ header, status, field, occurrences, example }] }
export function csvCoverage({ headers, records, fieldAliases, columnMappings = null, hintKeys = {}, normalize = (s) => s }) {
  const champDe = new Map();
  for (const [champ, aliases] of Object.entries(fieldAliases || {})) {
    for (const a of aliases) if (!champDe.has(a)) champDe.set(a, champ);
  }
  for (const [champ, col] of Object.entries(columnMappings || {})) {
    const h = clean(col) ? normalize(String(col)) : null;
    if (h) champDe.set(h, champ); // le profil l'emporte
  }
  const columns = (headers || []).map((header) => {
    let occurrences = 0;
    let example = null;
    for (const r of records || []) {
      const v = clean(r?.[header]);
      if (!v) continue;
      occurrences += 1;
      if (!example) example = exemple(v);
    }
    const field = champDe.get(header) || null;
    const status = field ? 'repris' : (hintKeys[header] ? 'indice' : 'brut');
    return { header, status, field: field || hintKeys[header] || null, occurrences, example };
  });
  return { kind: 'csv', records: (records || []).length, columns };
}

// records : objets { TAG: [valeurs] } (parseRis)
// consumed : balises lues par mapRisRecord ; hintTags : { TAG: 'collection' | 'cote' }
// → { kind: 'ris', records, tags: [{ tag, status, occurrences, records, example }] }
export function risCoverage({ records, consumed, hintTags = {} }) {
  const tags = new Map();
  for (const r of records || []) {
    for (const [tag, valeurs] of Object.entries(r || {})) {
      const vals = (Array.isArray(valeurs) ? valeurs : [valeurs]).map(clean).filter(Boolean);
      if (!vals.length) continue;
      let t = tags.get(tag);
      if (!t) {
        const status = consumed.includes(tag) ? 'repris' : (hintTags[tag] ? 'indice' : 'brut');
        t = { tag, status, occurrences: 0, records: 0, example: null };
        tags.set(tag, t);
      }
      t.occurrences += vals.length;
      t.records += 1;
      if (!t.example) t.example = exemple(vals[0]);
    }
  }
  return { kind: 'ris', records: (records || []).length, tags: [...tags.values()].sort((a, b) => a.tag.localeCompare(b.tag)) };
}

// Résumé chiffré commun aux trois formats, pour l'écran et le rapport de révision.
export function coverageCounts(coverage) {
  if (!coverage) return null;
  const items = coverage.zones || coverage.columns || coverage.tags || [];
  const n = (s) => items.filter((x) => x.status === s).length;
  return { repris: n('repris'), indice: n('indice'), brut: n('brut'), total: items.length };
}
