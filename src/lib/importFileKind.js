// Format de fichier d'un import, deviné par son extension, tel que la page
// Importations et l'assistant l'envoient à fn_import_create (p_detected_format).
//
// Une seule copie : jusqu'au 26/09/2026 cette fonction existait deux fois
// (ImportacoesPage.jsx, ImportWizard.jsx) et envoyait 'marc21' pour un .mrc ou
// un .marc — mot absent de la CHECK partner_catalog_import_runs_detected_format_check :
// la création même du run échouait. UNIMARC ou MARC21 est un VOCABULAIRE,
// détecté notice par notice par l'EF (ou imposé par forced_vocabulary) ; le
// FORMAT d'un fichier binaire MARC est 'marc_iso2709', le mot que l'EF écrit
// elle-même (H28). PMB livre ses exports UNIMARC avec le suffixe « marc » ;
// « .iso » est l'autre suffixe courant de l'ISO 2709 en bibliothèque.
//
// Chaque valeur rendue ici doit appartenir à la CHECK : gardé par
// src/tests/import-file-kind.test.js, qui la lit dans la dernière migration.

export const IMPORT_FILE_KINDS = [
  'csv', 'tsv', 'ris', 'bibtex', 'marc_iso2709', 'marcxml', 'json', 'xml', 'zip', 'unknown',
];

export const ACCEPTED_IMPORT_EXTENSIONS =
  '.csv,.tsv,.txt,.ris,.bib,.bibtex,.mrc,.marc,.iso,.xlsx,.xls,.ods,.pdf,.json,.xml,.zip,.marcxml';

export function detectFileKind(fileName) {
  const n = (fileName || '').toLowerCase();
  if (n.endsWith('.csv')) return 'csv';
  if (n.endsWith('.tsv')) return 'tsv';
  if (n.endsWith('.ris')) return 'ris';
  if (n.endsWith('.bib') || n.endsWith('.bibtex')) return 'bibtex';
  if (n.endsWith('.mrc') || n.endsWith('.marc') || n.endsWith('.iso')) return 'marc_iso2709';
  if (n.endsWith('.marcxml')) return 'marcxml';
  if (n.endsWith('.json')) return 'json';
  if (n.endsWith('.xml')) return 'xml';
  if (n.endsWith('.zip')) return 'zip'; // EX-3 : paquet de fonds (manifest + fichiers)
  return 'unknown';
}
