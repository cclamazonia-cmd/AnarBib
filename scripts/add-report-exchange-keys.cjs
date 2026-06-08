/**
 * Add i18n keys for the inter-library exchanges (trocas) block in the
 * text report (BibliotecaPage generateReportText).
 * Session : Completude rapports (consultations + trocas)
 */
const fs = require('fs');
const path = require('path');
const LOCALES_DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'biblioteca.report.exchangesSection': {
    'pt-BR': 'Trocas interbibliotecas',
    en: 'Inter-library exchanges',
    fr: 'Échanges inter-biblios',
    es: 'Intercambios interbibliotecarios',
    de: 'Interbibliothekarischer Tausch',
    it: 'Scambi interbibliotecari',
    ca: 'Intercanvis interbibliotecaris',
    eo: 'Interbibliotekaj interŝanĝoj',
    nl: 'Uitwisselingen tussen bibliotheken',
    el: 'Διαβιβλιοθηκικές ανταλλαγές',
  },
  'biblioteca.report.exchangesProposed': {
    'pt-BR': 'Propostas (semana): {count}',
    en: 'Proposed (week): {count}',
    fr: 'Proposés (semaine) : {count}',
    es: 'Propuestos (semana): {count}',
    de: 'Vorgeschlagen (Woche): {count}',
    it: 'Proposti (settimana): {count}',
    ca: 'Proposats (setmana): {count}',
    eo: 'Proponitaj (semajno): {count}',
    nl: 'Voorgesteld (week): {count}',
    el: 'Προτάσεις (εβδομάδα): {count}',
  },
  'biblioteca.report.exchangesAccepted': {
    'pt-BR': 'Aceitas (semana): {count}',
    en: 'Accepted (week): {count}',
    fr: 'Acceptés (semaine) : {count}',
    es: 'Aceptados (semana): {count}',
    de: 'Angenommen (Woche): {count}',
    it: 'Accettati (settimana): {count}',
    ca: 'Acceptats (setmana): {count}',
    eo: 'Akceptitaj (semajno): {count}',
    nl: 'Geaccepteerd (week): {count}',
    el: 'Αποδεκτές (εβδομάδα): {count}',
  },
  'biblioteca.report.exchangesOngoing': {
    'pt-BR': 'Em curso: {count}',
    en: 'Ongoing: {count}',
    fr: 'En cours : {count}',
    es: 'En curso: {count}',
    de: 'Laufend: {count}',
    it: 'In corso: {count}',
    ca: 'En curs: {count}',
    eo: 'Daŭrantaj: {count}',
    nl: 'Lopend: {count}',
    el: 'Σε εξέλιξη: {count}',
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
