/* ===========================================================================
 * i18n-add-entraide-routing.cjs
 * Routage par cercles (entraide v2) : sélecteur + badges. 4 clés × 10 locales.
 * Idempotent (sentinelle federacao.entraide.circleLabel).
 * Session : Fédération — Communs & Entraide
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const PREFIX = 'federacao.entraide.';
const SENTINEL = PREFIX + 'circleLabel';

const K = ['circleLabel', 'networkWide', 'escalated', 'circle'];

const V = {
  fr: ['Router vers un cercle :', 'Tout le réseau', 'Escaladé au réseau', 'Cercle'],
  'pt-BR': ['Encaminhar a um círculo:', 'Toda a rede', 'Ampliado à rede', 'Círculo'],
  es: ['Encaminar a un círculo:', 'Toda la red', 'Ampliado a la red', 'Círculo'],
  en: ['Route to a circle:', 'Whole network', 'Widened to network', 'Circle'],
  it: ['Indirizza a un cerchio:', 'Tutta la rete', 'Esteso alla rete', 'Cerchio'],
  de: ['An einen Kreis leiten:', 'Ganzes Netzwerk', 'Auf Netzwerk erweitert', 'Kreis'],
  ca: ['Encaminar a un cercle:', 'Tota la xarxa', 'Ampliat a la xarxa', 'Cercle'],
  eo: ['Sendi al rondo:', 'La tuta reto', 'Vastigita al la reto', 'Rondo'],
  nl: ['Naar een kring sturen:', 'Het hele netwerk', 'Uitgebreid naar netwerk', 'Kring'],
  el: ['Δρομολόγηση σε κύκλο:', 'Όλο το δίκτυο', 'Διευρύνθηκε στο δίκτυο', 'Κύκλος'],
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const vals = V[loc];
    if (!vals || vals.length !== K.length) throw new Error('Valeurs manquantes: ' + loc);
    const entries = K.map((k, i) => '  ' + JSON.stringify(PREFIX + k) + ': ' + JSON.stringify(vals[i]));
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 4 clés entraide-routing (si absentes), JSON valide.');
}
console.log('\nTerminé.');
