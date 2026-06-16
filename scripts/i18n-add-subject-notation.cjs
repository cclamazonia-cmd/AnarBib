/* ===========================================================================
 * i18n-add-subject-notation.cjs
 * Champ notation (code CDD) de l'éditeur de libellés (thésaurus v2 F).
 * 1 clé × 10 locales. Idempotent (sentinelle catalogacao.subjectGov.editNotation).
 * Session : Fédération — Communs & Entraide
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const KEY = 'catalogacao.subjectGov.editNotation';

const V = {
  fr: 'Notation (CDD)', 'pt-BR': 'Notação (CDD)', es: 'Notación (CDD)', en: 'Notation (DDC)',
  it: 'Notazione (CDD)', de: 'Notation (DDC)', ca: 'Notació (CDD)', eo: 'Notacio (CDD)',
  nl: 'Notatie (DDC)', el: 'Σημείωση (DDC)',
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + KEY + '"')) {
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n  ' + JSON.stringify(KEY) + ': ' + JSON.stringify(V[loc]) + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': editNotation (si absente), JSON valide.');
}
console.log('\nTerminé.');
