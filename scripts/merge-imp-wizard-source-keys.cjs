/**
 * Ajoute les clés importacoes.wizard.source.* (étape Source du wizard, IMP-8 inc.2)
 * aux 10 locales. Méthode SÛRE : insertion TEXTUELLE additive, idempotente.
 * Run : node scripts/merge-imp-wizard-source-keys.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = { 'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json', it: 'it.json', de: 'de.json', ca: 'ca.json', eo: 'eo.json', nl: 'nl.json', el: 'el.json' };

const K = (uploadTitle, fontesTitle, sourceLabel, noSources, fileLabel, imp, importing, ready, isbnLabel, search, ingest, ingested) => ({
  'importacoes.wizard.source.uploadTitle': uploadTitle,
  'importacoes.wizard.source.fontesTitle': fontesTitle,
  'importacoes.wizard.source.sourceLabel': sourceLabel,
  'importacoes.wizard.source.noSources': noSources,
  'importacoes.wizard.source.fileLabel': fileLabel,
  'importacoes.wizard.source.import': imp,
  'importacoes.wizard.source.importing': importing,
  'importacoes.wizard.source.ready': ready,
  'importacoes.wizard.source.isbnLabel': isbnLabel,
  'importacoes.wizard.source.search': search,
  'importacoes.wizard.source.ingest': ingest,
  'importacoes.wizard.source.ingested': ingested,
});

const KEYS = {
  'pt-BR': K('Depositar um arquivo', 'Buscar em fontes externas', 'Fonte parceira', 'Nenhuma fonte parceira. Crie uma na página Importações.', 'Arquivo (CSV, RIS, MARCXML, MARC…)', 'Importar o arquivo', 'Importando…', 'Lote importado (run #{id}). Vá para a pré-visualização.', 'ISBN', 'Buscar', 'Importar', 'Notícia importada. Vá para a pré-visualização.'),
  fr: K('Déposer un fichier', 'Rechercher dans des sources externes', 'Source partenaire', 'Aucune source partenaire. Créez-en une depuis la page Importações.', 'Fichier (CSV, RIS, MARCXML, MARC…)', 'Importer le fichier', 'Import en cours…', 'Lot importé (run #{id}). Passez à l\'aperçu.', 'ISBN', 'Rechercher', 'Importer', 'Notice importée. Passez à l\'aperçu.'),
  es: K('Depositar un archivo', 'Buscar en fuentes externas', 'Fuente asociada', 'Ninguna fuente asociada. Cree una desde la página Importações.', 'Archivo (CSV, RIS, MARCXML, MARC…)', 'Importar el archivo', 'Importando…', 'Lote importado (run #{id}). Vaya a la vista previa.', 'ISBN', 'Buscar', 'Importar', 'Ficha importada. Vaya a la vista previa.'),
  en: K('Upload a file', 'Search external sources', 'Partner source', 'No partner source. Create one from the Importações page.', 'File (CSV, RIS, MARCXML, MARC…)', 'Import the file', 'Importing…', 'Batch imported (run #{id}). Go to preview.', 'ISBN', 'Search', 'Import', 'Record imported. Go to preview.'),
  it: K('Caricare un file', 'Cercare in fonti esterne', 'Fonte partner', 'Nessuna fonte partner. Creane una dalla pagina Importações.', 'File (CSV, RIS, MARCXML, MARC…)', 'Importa il file', 'Importazione…', 'Lotto importato (run #{id}). Vai all\'anteprima.', 'ISBN', 'Cerca', 'Importa', 'Scheda importata. Vai all\'anteprima.'),
  de: K('Datei hochladen', 'In externen Quellen suchen', 'Partnerquelle', 'Keine Partnerquelle. Erstelle eine auf der Importações-Seite.', 'Datei (CSV, RIS, MARCXML, MARC…)', 'Datei importieren', 'Import läuft…', 'Stapel importiert (Run #{id}). Weiter zur Vorschau.', 'ISBN', 'Suchen', 'Importieren', 'Datensatz importiert. Weiter zur Vorschau.'),
  ca: K('Dipositar un fitxer', 'Cercar en fonts externes', 'Font associada', 'Cap font associada. Creeu-ne una des de la pàgina Importações.', 'Fitxer (CSV, RIS, MARCXML, MARC…)', 'Importa el fitxer', 'Important…', 'Lot importat (run #{id}). Aneu a la vista prèvia.', 'ISBN', 'Cerca', 'Importa', 'Fitxa importada. Aneu a la vista prèvia.'),
  eo: K('Alŝuti dosieron', 'Serĉi en eksteraj fontoj', 'Partnera fonto', 'Neniu partnera fonto. Kreu unu el la paĝo Importações.', 'Dosiero (CSV, RIS, MARCXML, MARC…)', 'Importi la dosieron', 'Importado…', 'Loto importita (rulo #{id}). Iru al antaŭrigardo.', 'ISBN', 'Serĉi', 'Importi', 'Registro importita. Iru al antaŭrigardo.'),
  nl: K('Een bestand uploaden', 'Externe bronnen doorzoeken', 'Partnerbron', 'Geen partnerbron. Maak er een aan op de Importações-pagina.', 'Bestand (CSV, RIS, MARCXML, MARC…)', 'Bestand importeren', 'Bezig met importeren…', 'Partij geïmporteerd (run #{id}). Ga naar voorbeeld.', 'ISBN', 'Zoeken', 'Importeren', 'Record geïmporteerd. Ga naar voorbeeld.'),
  el: K('Μεταφόρτωση αρχείου', 'Αναζήτηση σε εξωτερικές πηγές', 'Πηγή-εταίρος', 'Καμία πηγή-εταίρος. Δημιουργήστε μία από τη σελίδα Importações.', 'Αρχείο (CSV, RIS, MARCXML, MARC…)', 'Εισαγωγή του αρχείου', 'Εισαγωγή…', 'Η παρτίδα εισήχθη (run #{id}). Πηγαίνετε στην προεπισκόπηση.', 'ISBN', 'Αναζήτηση', 'Εισαγωγή', 'Η εγγραφή εισήχθη. Πηγαίνετε στην προεπισκόπηση.'),
};

let total = 0;
for (const [loc, file] of Object.entries(FILES)) {
  const p = path.join(DIR, file);
  let txt = fs.readFileSync(p, 'utf8');
  const toAdd = Object.entries(KEYS[loc]).filter(([k]) => !txt.includes('"' + k + '"'));
  if (toAdd.length) {
    const ins = toAdd.map(([k, v]) => '  ' + JSON.stringify(k) + ': ' + JSON.stringify(v)).join(',\n');
    const i = txt.lastIndexOf('}');
    txt = txt.slice(0, i).replace(/\s*,?\s*$/, '') + ',\n' + ins + '\n' + txt.slice(i);
    fs.writeFileSync(p, txt, 'utf8');
  }
  JSON.parse(fs.readFileSync(p, 'utf8'));
  console.log(loc.padEnd(6), '+' + toAdd.length);
  total += toAdd.length;
}
console.log('\nTotal :', total);
