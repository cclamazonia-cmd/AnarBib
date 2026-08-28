/* ===========================================================================
 * i18n-add-catalogacao-batch-status.cjs
 * Onglet « Lots » du catalogage : libelle de l'etat « closed ».
 * Jusqu'au 29/08/2026 aucun lot ne pouvait etre ferme (la CHECK en base ne
 * connaissait pas 'closed'), donc la pastille d'etat n'avait jamais rien eu
 * d'autre que 'published' a afficher et retombait sur le code brut.
 * 1 cle x 10 locales. Idempotent (sentinelle catalogacao.batch.status.closed).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const PREFIX = 'catalogacao.batch.status.';
const SENTINEL = PREFIX + 'closed';

const K = ['closed'];

const V = {
  fr: ['Clos'],
  'pt-BR': ['Fechado'],
  es: ['Cerrado'],
  en: ['Closed'],
  it: ['Chiuso'],
  de: ['Geschlossen'],
  ca: ['Tancat'],
  eo: ['Fermita'],
  nl: ['Gesloten'],
  el: ['Κλειστό'],
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
  console.log(loc + ': 1 cle batch-status (si absente), JSON valide.');
}
console.log('\nTermine.');
