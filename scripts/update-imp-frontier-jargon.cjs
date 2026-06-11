/**
 * Humanise le bandeau « frontière » de la page Importações : retire le code de
 * spec interne ACQ-Q4 et le terme technique book_draft des 3 clés concernées,
 * dans les 10 locales. UPDATE de valeurs (remplacement textuel ciblé).
 * Run : node scripts/update-imp-frontier-jargon.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');

const V = {
  'pt-BR': {
    'importacoes.sentido.hint': 'A fronteira entre importação e coleção é a catalogação.',
    'importacoes.import.frontier.title': 'Fronteira da coleção',
    'importacoes.import.frontier.desc': 'O que entra por aqui chega como rascunho. A entrada em coleção passa pela Catalogação.',
  },
  fr: {
    'importacoes.sentido.hint': 'La frontière entre import et collection, c’est la catalogation.',
    'importacoes.import.frontier.title': 'Frontière de la collection',
    'importacoes.import.frontier.desc': 'Ce qui entre ici arrive comme brouillon. L’entrée en collection se fait par la Catalogation.',
  },
  es: {
    'importacoes.sentido.hint': 'La frontera entre importación y colección es la catalogación.',
    'importacoes.import.frontier.title': 'Frontera de la colección',
    'importacoes.import.frontier.desc': 'Lo que entra por aquí llega como borrador. La entrada en colección pasa por la Catalogación.',
  },
  en: {
    'importacoes.sentido.hint': 'The boundary between import and collection is cataloging.',
    'importacoes.import.frontier.title': 'Collection boundary',
    'importacoes.import.frontier.desc': 'What comes in here arrives as a draft. Entry into the collection goes through Cataloging.',
  },
  it: {
    'importacoes.sentido.hint': 'Il confine tra importazione e collezione è la catalogazione.',
    'importacoes.import.frontier.title': 'Confine della collezione',
    'importacoes.import.frontier.desc': 'Ciò che entra qui arriva come bozza. L’ingresso in collezione passa dalla Catalogazione.',
  },
  de: {
    'importacoes.sentido.hint': 'Die Grenze zwischen Import und Sammlung ist die Katalogisierung.',
    'importacoes.import.frontier.title': 'Grenze der Sammlung',
    'importacoes.import.frontier.desc': 'Was hier hereinkommt, kommt als Entwurf an. Die Aufnahme in die Sammlung erfolgt über die Katalogisierung.',
  },
  ca: {
    'importacoes.sentido.hint': 'La frontera entre importació i col·lecció és la catalogació.',
    'importacoes.import.frontier.title': 'Frontera de la col·lecció',
    'importacoes.import.frontier.desc': 'El que entra per aquí arriba com a esborrany. L’entrada a la col·lecció passa per la Catalogació.',
  },
  eo: {
    'importacoes.sentido.hint': 'La limo inter importo kaj kolekto estas la katalogado.',
    'importacoes.import.frontier.title': 'Limo de la kolekto',
    'importacoes.import.frontier.desc': 'Kio eniras ĉi tie alvenas kiel malneto. La eniro en la kolekton pasas tra la Katalogado.',
  },
  nl: {
    'importacoes.sentido.hint': 'De grens tussen import en collectie is de catalogisering.',
    'importacoes.import.frontier.title': 'Grens van de collectie',
    'importacoes.import.frontier.desc': 'Wat hier binnenkomt, komt als concept aan. De opname in de collectie verloopt via Catalogiseren.',
  },
  el: {
    'importacoes.sentido.hint': 'Το όριο μεταξύ εισαγωγής και συλλογής είναι η καταλογογράφηση.',
    'importacoes.import.frontier.title': 'Όριο της συλλογής',
    'importacoes.import.frontier.desc': 'Ό,τι εισέρχεται εδώ φτάνει ως προσχέδιο. Η ένταξη στη συλλογή γίνεται μέσω της Καταλογογράφησης.',
  },
};

const FILES = { 'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json', it: 'it.json', de: 'de.json', ca: 'ca.json', eo: 'eo.json', nl: 'nl.json', el: 'el.json' };

let total = 0;
for (const [loc, file] of Object.entries(FILES)) {
  const p = path.join(DIR, file);
  let txt = fs.readFileSync(p, 'utf8');
  let n = 0;
  for (const [key, val] of Object.entries(V[loc])) {
    const re = new RegExp('("' + key.replace(/\./g, '\\.') + '":\\s*)"[^"]*"');
    if (re.test(txt)) { txt = txt.replace(re, '$1' + JSON.stringify(val)); n++; }
    else console.log('  !', loc, key, 'INTROUVABLE');
  }
  fs.writeFileSync(p, txt, 'utf8');
  JSON.parse(fs.readFileSync(p, 'utf8'));
  console.log(loc.padEnd(6), n + '/3');
  total += n;
}
console.log('\nTotal :', total);
