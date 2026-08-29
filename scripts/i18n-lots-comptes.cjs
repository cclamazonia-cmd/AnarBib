/* ===========================================================================
 * i18n-lots.cjs
 * Onglet Lots et filtre de la file : dire ce qu'un lot contient, et marquer les
 * lots clos dans le menu.
 * 3 cles x 10 locales. Idempotent (sentinelle catalogacao.batch.thDrafts).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalogacao.batch.thDrafts';
const K = ['catalogacao.batch.thDrafts', 'catalogacao.batch.draftsTrashed', 'catalogacao.queue.batchClosed'];

const V = {
  fr: ['Brouillons', '{count} à la corbeille', 'clos'],
  'pt-BR': ['Rascunhos', '{count} na lixeira', 'fechado'],
  es: ['Borradores', '{count} en la papelera', 'cerrado'],
  en: ['Drafts', '{count} in the trash', 'closed'],
  it: ['Bozze', '{count} nel cestino', 'chiuso'],
  de: ['Entwürfe', '{count} im Papierkorb', 'geschlossen'],
  ca: ['Esborranys', '{count} a la paperera', 'tancat'],
  eo: ['Malnetoj', '{count} en la rubujo', 'fermita'],
  nl: ['Concepten', '{count} in de prullenbak', 'gesloten'],
  el: ['Πρόχειρα', '{count} στον κάδο', 'κλειστή'],
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const vals = V[loc];
    if (!vals || vals.length !== K.length) throw new Error('Valeurs manquantes: ' + loc);
    const entries = K.map((k, i) => '  ' + JSON.stringify(k) + ': ' + JSON.stringify(vals[i]));
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const k of K) if (parsed[k] === undefined) throw new Error('cle absente: ' + loc + ' / ' + k);
  console.log(loc + ': 3 cles lots (si absentes), JSON valide.');
}
console.log('\nTermine.');
