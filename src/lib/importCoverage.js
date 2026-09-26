// Couverture d'un import (H16, 26/09/2026) — lecture partagée par l'écran
// Importations (panneau d'un import) et le rapport de révision d'un lot.
//
// La couverture est écrite par l'EF process-partner-catalog-import dans
// summary.coverage : { kind: 'marc', zones } | { kind: 'csv', columns } |
// { kind: 'ris', tags }, chaque élément avec status 'repris' | 'indice' | 'brut'.
// « brut » ne veut pas dire « perdu » : l'élément reste dans l'enregistrement
// d'origine (raw_payload → book_drafts.marc_json), mais n'alimente aucun champ.

export function coverageItems(coverage) {
  if (!coverage) return [];
  return coverage.zones || coverage.columns || coverage.tags || [];
}

// « 995 $f », « 001 », « titulo », « SP ».
export function coverageItemLabel(item) {
  if (!item) return '';
  if (item.header !== undefined) return item.header;
  if (item.code !== undefined) return item.code ? `${item.tag} $${item.code}` : item.tag;
  return item.tag || '';
}

const csvCell = (v) => {
  const s = v === null || v === undefined ? '' : String(v);
  return /[",\n\r;]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

// Rapport complet (repris compris), en CSV RFC 4180 — le compte rendu qu'on
// peut envoyer tel quel à la bibliothèque qui a fourni le fichier.
export function coverageToCsv(coverage, { filename = '', runId = '' } = {}) {
  const items = coverageItems(coverage);
  const lignes = [['import', 'fichier', 'format', 'element', 'statut', 'champ', 'occurrences', 'notices', 'repetitions_non_reprises', 'exemple']];
  for (const it of items) {
    lignes.push([runId, filename, coverage?.kind || '', coverageItemLabel(it), it.status, it.field ?? '',
      it.occurrences ?? '', it.records ?? '', it.surplus ?? '', it.example ?? '']);
  }
  return lignes.map((l) => l.map(csvCell).join(',')).join('\r\n') + '\r\n';
}
