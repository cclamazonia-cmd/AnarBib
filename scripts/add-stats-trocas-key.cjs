/**
 * Add i18n key for the "Trocas ativas" stat card (BibliotecaPage reports grid).
 * Session : Completude rapports (consultations + trocas) -- reliquat grille
 */
const fs = require('fs');
const path = require('path');
const LOCALES_DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'biblioteca.stats.trocasActive': {
    'pt-BR': 'Trocas ativas',
    en: 'Active exchanges',
    fr: 'Échanges actifs',
    es: 'Intercambios activos',
    de: 'Aktive Tausche',
    it: 'Scambi attivi',
    ca: 'Intercanvis actius',
    eo: 'Aktivaj interŝanĝoj',
    nl: 'Actieve uitwisselingen',
    el: 'Ενεργές ανταλλαγές',
  },
};

const FILES = fs.readdirSync(LOCALES_DIR).filter(f => f.endsWith('.json'));
for (const file of FILES) {
  const locale = file.replace('.json', '');
  const filePath = path.join(LOCALES_DIR, file);
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  let added = 0;
  for (const [key, translations] of Object.entries(KEYS)) {
    if (!data[key]) { data[key] = translations[locale] || translations['en']; added++; }
  }
  const sorted = {};
  for (const k of Object.keys(data).sort()) sorted[k] = data[k];
  fs.writeFileSync(filePath, JSON.stringify(sorted, null, 2) + '\n', 'utf8');
  console.log(`${file}: ${added} key(s) added (total: ${Object.keys(sorted).length})`);
}
