/**
 * Add i18n keys for QR-code labels (LabelSheetPrinter).
 * Session : QR codes etiquettes module mobile
 */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'labels.includeQr': {
    'pt-BR': 'Incluir QR codes',
    en: 'Include QR codes',
    fr: 'Inclure les QR codes',
    es: 'Incluir códigos QR',
    de: 'QR-Codes einfügen',
    it: 'Includere QR code',
    ca: 'Incloure codis QR',
    eo: 'Inkluzivi QR-kodojn',
    nl: 'QR-codes opnemen',
    el: 'Συμπερίληψη κωδικών QR',
  },
  'labels.generating': {
    'pt-BR': 'Gerando…',
    en: 'Generating…',
    fr: 'Génération…',
    es: 'Generando…',
    de: 'Erzeugen…',
    it: 'Generazione…',
    ca: 'Generant…',
    eo: 'Generante…',
    nl: 'Genereren…',
    el: 'Δημιουργία…',
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
