/* ===========================================================================
 * i18n-add-federacao-gazeta.cjs
 * Onglet Gazette : 3 clés d'état (empty / error / retry) dans les 10 locales.
 * Insertion idempotente (sentinelle federacao.gazeta.error).
 * Les libellés de rendu (langue, PDF, page, sources, bandeau de repli) vivent
 * dans la table UI du composant GazetteTab — pas ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.gazeta.error';

const ADD = {
  'pt-BR': {
    'federacao.gazeta.empty': 'Nenhum número publicado por enquanto.',
    'federacao.gazeta.error': 'Não foi possível carregar a gazeta.',
    'federacao.gazeta.retry': 'Tentar de novo',
  },
  fr: {
    'federacao.gazeta.empty': 'Aucun numéro publié pour l’instant.',
    'federacao.gazeta.error': 'Impossible de charger la gazette.',
    'federacao.gazeta.retry': 'Réessayer',
  },
  es: {
    'federacao.gazeta.empty': 'Ningún número publicado por ahora.',
    'federacao.gazeta.error': 'No se pudo cargar la gaceta.',
    'federacao.gazeta.retry': 'Reintentar',
  },
  en: {
    'federacao.gazeta.empty': 'No issue published yet.',
    'federacao.gazeta.error': 'The gazette could not be loaded.',
    'federacao.gazeta.retry': 'Retry',
  },
  it: {
    'federacao.gazeta.empty': 'Nessun numero pubblicato per ora.',
    'federacao.gazeta.error': 'Impossibile caricare la gazzetta.',
    'federacao.gazeta.retry': 'Riprova',
  },
  de: {
    'federacao.gazeta.empty': 'Noch keine Ausgabe veröffentlicht.',
    'federacao.gazeta.error': 'Die Gazette konnte nicht geladen werden.',
    'federacao.gazeta.retry': 'Erneut versuchen',
  },
  ca: {
    'federacao.gazeta.empty': 'Cap número publicat de moment.',
    'federacao.gazeta.error': 'No s’ha pogut carregar la gaseta.',
    'federacao.gazeta.retry': 'Torna-ho a provar',
  },
  eo: {
    'federacao.gazeta.empty': 'Ankoraŭ neniu numero publikigita.',
    'federacao.gazeta.error': 'Ne eblis ŝargi la gazeton.',
    'federacao.gazeta.retry': 'Reprovi',
  },
  nl: {
    'federacao.gazeta.empty': 'Nog geen nummer gepubliceerd.',
    'federacao.gazeta.error': 'De gazette kon niet worden geladen.',
    'federacao.gazeta.retry': 'Opnieuw proberen',
  },
  el: {
    'federacao.gazeta.empty': 'Κανένα τεύχος δεν έχει δημοσιευτεί ακόμη.',
    'federacao.gazeta.error': 'Δεν ήταν δυνατή η φόρτωση της εφημερίδας.',
    'federacao.gazeta.retry': 'Επανάληψη',
  },
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
  console.log(loc + ': 3 clés gazeta (si absentes), JSON valide.');
}
console.log('\nTerminé.');
