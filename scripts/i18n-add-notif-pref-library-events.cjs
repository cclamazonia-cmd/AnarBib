/* ===========================================================================
 * i18n-add-notif-pref-library-events.cjs
 * Libellé de la préférence opt-out « avis des événements de bibliothèque »
 * (onglet Profil du compte lecteur -> Préférences de notification).
 * 1 clé × 10 locales. Idempotent (sentinelle account.notifPrefs.disableLibraryEvents).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'account.notifPrefs.disableLibraryEvents';

const ADD = {
  'pt-BR': { 'account.notifPrefs.disableLibraryEvents': 'Não me avisar sobre novos eventos da biblioteca' },
  fr: { 'account.notifPrefs.disableLibraryEvents': "Ne plus m'avertir des nouveaux événements de la bibliothèque" },
  es: { 'account.notifPrefs.disableLibraryEvents': 'No avisarme de los nuevos eventos de la biblioteca' },
  en: { 'account.notifPrefs.disableLibraryEvents': 'Don’t notify me about new library events' },
  it: { 'account.notifPrefs.disableLibraryEvents': 'Non avvisarmi dei nuovi eventi della biblioteca' },
  de: { 'account.notifPrefs.disableLibraryEvents': 'Nicht über neue Veranstaltungen der Bibliothek benachrichtigen' },
  ca: { 'account.notifPrefs.disableLibraryEvents': 'No avisar-me dels nous esdeveniments de la biblioteca' },
  eo: { 'account.notifPrefs.disableLibraryEvents': 'Ne sciigi min pri novaj eventoj de la biblioteko' },
  nl: { 'account.notifPrefs.disableLibraryEvents': 'Mij niet op de hoogte brengen van nieuwe bibliotheekevenementen' },
  el: { 'account.notifPrefs.disableLibraryEvents': 'Να μην ειδοποιούμαι για νέες εκδηλώσεις της βιβλιοθήκης' },
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
