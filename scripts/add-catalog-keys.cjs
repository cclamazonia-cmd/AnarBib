/**
 * Add missing i18n keys for CatalogPanel.jsx
 */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'catalogacao.catalog.loading': {
    'pt-BR': 'Carregando…',
    en: 'Loading…',
    fr: 'Chargement…',
    es: 'Cargando…',
    de: 'Laden…',
    it: 'Caricamento…',
    ca: 'Carregant…',
    eo: 'Ŝargante…',
    nl: 'Laden…',
    el: 'Φόρτωση…',
  },
  'catalogacao.catalog.refreshing': {
    'pt-BR': 'Atualizando…',
    en: 'Refreshing…',
    fr: 'Actualisation…',
    es: 'Actualizando…',
    de: 'Aktualisierung…',
    it: 'Aggiornamento…',
    ca: 'Actualitzant…',
    eo: 'Aŭdatigante…',
    nl: 'Vernieuwen…',
    el: 'Ανανέωση…',
  },
};

const FILES = fs.readdirSync(LOCALES_DIR).filter(f => f.endsWith('.json'));

for (const file of FILES) {
  const locale = file.replace('.json', '');
  const filePath = path.join(LOCALES_DIR, file);
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));

  let added = 0;
  for (const [key, translations] of Object.entries(KEYS)) {
    if (!data[key]) {
      data[key] = translations[locale] || translations['en'];
      added++;
    }
  }

  const sorted = {};
  for (const k of Object.keys(data).sort()) sorted[k] = data[k];
  fs.writeFileSync(filePath, JSON.stringify(sorted, null, 2) + '\n', 'utf8');
  console.log(`${file}: ${added} key(s) added (total: ${Object.keys(sorted).length})`);
}
