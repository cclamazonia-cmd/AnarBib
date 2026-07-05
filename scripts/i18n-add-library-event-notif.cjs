/* ===========================================================================
 * i18n-add-library-event-notif.cjs
 * Titre de l'avis in-app « nouvel événement à la bibliothèque » (cloche + onglet
 * avisos), émis par le trigger trg_notify_library_event_created. Le corps de la
 * notif est littéral (titre de l'événement · biblio), pas de clé.
 * 1 clé × 10 locales. Idempotent (sentinelle notif.libraryEvent.created.title).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'notif.libraryEvent.created.title';

const ADD = {
  'pt-BR': { 'notif.libraryEvent.created.title': 'Novo evento na biblioteca' },
  fr: { 'notif.libraryEvent.created.title': 'Nouvel événement à la bibliothèque' },
  es: { 'notif.libraryEvent.created.title': 'Nuevo evento en la biblioteca' },
  en: { 'notif.libraryEvent.created.title': 'New event at the library' },
  it: { 'notif.libraryEvent.created.title': 'Nuovo evento in biblioteca' },
  de: { 'notif.libraryEvent.created.title': 'Neue Veranstaltung in der Bibliothek' },
  ca: { 'notif.libraryEvent.created.title': 'Nou esdeveniment a la biblioteca' },
  eo: { 'notif.libraryEvent.created.title': 'Nova evento en la biblioteko' },
  nl: { 'notif.libraryEvent.created.title': 'Nieuw evenement in de bibliotheek' },
  el: { 'notif.libraryEvent.created.title': 'Νέα εκδήλωση στη βιβλιοθήκη' },
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const map = ADD[loc];
    const keys = Object.keys(ADD['pt-BR']);
    const entries = keys.map((k) => {
      if (map[k] == null) throw new Error('Traduction manquante: ' + k + ' / ' + loc);
      return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(map[k]);
    });
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 1 clé (si absente), JSON valide.');
}
console.log('\nTerminé.');
