/**
 * Ajoute les clés importacoes.archiveRun / .unarchiveRun / .showArchived /
 * .archiving / .runArchived / .runUnarchived (archivage doux des runs) aux 10
 * locales. Additif textuel. Run : node scripts/merge-imp-archive-run-keys.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = { 'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json', it: 'it.json', de: 'de.json', ca: 'ca.json', eo: 'eo.json', nl: 'nl.json', el: 'el.json' };

const K = (archive, unarchive, show, archiving, archived, unarchived) => ({
  'importacoes.archiveRun': archive,
  'importacoes.unarchiveRun': unarchive,
  'importacoes.showArchived': show,
  'importacoes.archiving': archiving,
  'importacoes.runArchived': archived,
  'importacoes.runUnarchived': unarchived,
});

const KEYS = {
  'pt-BR': K('Arquivar', 'Desarquivar', 'Mostrar arquivados', 'Atualizando…', 'Tratamento arquivado.', 'Tratamento desarquivado.'),
  fr: K('Archiver', 'Désarchiver', 'Afficher les archivés', 'Mise à jour…', 'Run archivé.', 'Run désarchivé.'),
  es: K('Archivar', 'Desarchivar', 'Mostrar archivados', 'Actualizando…', 'Tratamiento archivado.', 'Tratamiento desarchivado.'),
  en: K('Archive', 'Unarchive', 'Show archived', 'Updating…', 'Run archived.', 'Run unarchived.'),
  it: K('Archivia', 'Annulla archiviazione', 'Mostra archiviati', 'Aggiornamento…', 'Elaborazione archiviata.', 'Archiviazione annullata.'),
  de: K('Archivieren', 'Wiederherstellen', 'Archivierte anzeigen', 'Wird aktualisiert…', 'Lauf archiviert.', 'Lauf wiederhergestellt.'),
  ca: K('Arxiva', 'Desarxiva', 'Mostra arxivats', 'S’està actualitzant…', 'Tractament arxivat.', 'Tractament desarxivat.'),
  eo: K('Arkivi', 'Malarkivi', 'Montri arkivitajn', 'Ĝisdatigado…', 'Traktado arkivita.', 'Traktado malarkivita.'),
  nl: K('Archiveren', 'Dearchiveren', 'Gearchiveerde tonen', 'Bijwerken…', 'Run gearchiveerd.', 'Run gedearchiveerd.'),
  el: K('Αρχειοθέτηση', 'Επαναφορά', 'Εμφάνιση αρχειοθετημένων', 'Ενημέρωση…', 'Η επεξεργασία αρχειοθετήθηκε.', 'Η επεξεργασία επαναφέρθηκε.'),
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
