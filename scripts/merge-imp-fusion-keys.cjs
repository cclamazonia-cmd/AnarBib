/**
 * Livraison 2 — fusion complète des 3 circuits : « Adicionar registros »
 * (origine unique : fichier / busca / oai), tableau de bord, liste de lotes.
 * Additif textuel. Run : node scripts/merge-imp-fusion-keys.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

const K = {
  'importacoes.dashboard.title':  { 'pt-BR': 'Visão geral', fr: 'Vue d’ensemble', es: 'Visión general', en: 'Overview', it: 'Panoramica', de: 'Übersicht', ca: 'Visió general', eo: 'Superrigardo', nl: 'Overzicht', el: 'Επισκόπηση' },
  'importacoes.add.title':        { 'pt-BR': 'Adicionar registros', fr: 'Ajouter des notices', es: 'Añadir registros', en: 'Add records', it: 'Aggiungere notizie', de: 'Datensätze hinzufügen', ca: 'Afegir registres', eo: 'Aldoni registrojn', nl: 'Records toevoegen', el: 'Προσθήκη εγγραφών' },
  'importacoes.add.mode.arquivo': { 'pt-BR': 'Arquivo', fr: 'Fichier', es: 'Archivo', en: 'File', it: 'File', de: 'Datei', ca: 'Fitxer', eo: 'Dosiero', nl: 'Bestand', el: 'Αρχείο' },
  'importacoes.add.mode.busca':   { 'pt-BR': 'Busca externa', fr: 'Recherche externe', es: 'Búsqueda externa', en: 'External search', it: 'Ricerca esterna', de: 'Externe Suche', ca: 'Cerca externa', eo: 'Ekstera serĉo', nl: 'Externe zoekopdracht', el: 'Εξωτερική αναζήτηση' },
  'importacoes.add.mode.oai':     { 'pt-BR': 'Coleta OAI', fr: 'Moisson OAI', es: 'Recolección OAI', en: 'OAI harvest', it: 'Raccolta OAI', de: 'OAI-Ernte', ca: 'Recol·lecció OAI', eo: 'OAI-rikolto', nl: 'OAI-oogst', el: 'Συγκομιδή OAI' },
  'importacoes.lotes.title':      { 'pt-BR': 'Lotes de importação', fr: 'Lots d’import', es: 'Lotes de importación', en: 'Import batches', it: 'Lotti di importazione', de: 'Import-Stapel', ca: 'Lots d’importació', eo: 'Importaj lotoj', nl: 'Importbatches', el: 'Παρτίδες εισαγωγής' },
  'importacoes.lotes.empty':      { 'pt-BR': 'Nenhum lote ainda.', fr: 'Aucun lot pour l’instant.', es: 'Ningún lote todavía.', en: 'No batches yet.', it: 'Ancora nessun lotto.', de: 'Noch keine Stapel.', ca: 'Encara cap lot.', eo: 'Ankoraŭ neniu loto.', nl: 'Nog geen batches.', el: 'Καμία παρτίδα ακόμη.' },
};

let total = 0;
for (const loc of FILES) {
  const p = path.join(DIR, loc + '.json');
  let txt = fs.readFileSync(p, 'utf8');
  const toAdd = Object.entries(K).filter(([k]) => !txt.includes('"' + k + '"')).map(([k, v]) => [k, v[loc]]);
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
