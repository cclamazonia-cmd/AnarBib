/* ===========================================================================
 * i18n-add-serial-detach-failed.cjs
 * Paquet PÉRIODIQUES P7b — le bouton « détacher » du sélecteur appelle
 * désormais api.fn_serial_detach_issue (le filet coalesce de publish_book_draft
 * l'a rendu nécessaire). Il lui fallait un message d'échec.
 * 1 clé × 10 locales. Idempotent, purement textuel.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalogacao.serial.detachFailed';

const VAL = {
  'pt-BR': 'Não foi possível desvincular o título.',
  fr: 'Le titre n’a pas pu être détaché.',
  es: 'No se ha podido desvincular el título.',
  en: 'The title could not be unlinked.',
  it: 'Non è stato possibile scollegare il titolo.',
  de: 'Der Titel konnte nicht gelöst werden.',
  ca: 'No s’ha pogut desvincular el títol.',
  eo: 'Ne eblis malligi la titolon.',
  nl: 'De titel kon niet worden ontkoppeld.',
  el: 'Δεν ήταν δυνατή η αποσύνδεση του τίτλου.',
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    if (VAL[loc] == null) throw new Error('Traduction manquante: ' + loc);
    const entry = '  ' + JSON.stringify(SENTINEL) + ': ' + JSON.stringify(VAL[loc]);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ' : detachFailed (si absente), JSON valide.');
}
console.log('\nTerminé.');
