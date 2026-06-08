/**
 * Add i18n keys for consultations + reservations lines in the text report
 * (BibliotecaPage generateReportText).
 * Session : Completude rapports (consultations + trocas)
 */
const fs = require('fs');
const path = require('path');
const LOCALES_DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'biblioteca.report.reservationsActive': {
    'pt-BR': 'Reservas ativas: {count}',
    en: 'Active reservations: {count}',
    fr: 'Réservations actives : {count}',
    es: 'Reservas activas: {count}',
    de: 'Aktive Reservierungen: {count}',
    it: 'Prenotazioni attive: {count}',
    ca: 'Reserves actives: {count}',
    eo: 'Aktivaj rezervoj: {count}',
    nl: 'Actieve reserveringen: {count}',
    el: 'Ενεργές κρατήσεις: {count}',
  },
  'biblioteca.report.consultationsActive': {
    'pt-BR': 'Consultas ativas: {count}',
    en: 'Active consultations: {count}',
    fr: 'Consultations actives : {count}',
    es: 'Consultas activas: {count}',
    de: 'Aktive Einsichtnahmen: {count}',
    it: 'Consultazioni attive: {count}',
    ca: 'Consultes actives: {count}',
    eo: 'Aktivaj konsultoj: {count}',
    nl: 'Actieve raadplegingen: {count}',
    el: 'Ενεργές επιτόπιες αναγνώσεις: {count}',
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
