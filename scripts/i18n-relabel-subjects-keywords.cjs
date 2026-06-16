/* ===========================================================================
 * i18n-relabel-subjects-keywords.cjs
 * 2b-clarif (thésaurus v1) : le champ texte libre `subjects` devient « Mots-clés »
 * (registre libre), distinct du picker contrôlé « Sujets (autorité matière) ».
 * Remplacement ciblé de la valeur (préserve format/ordre). 1 clé × 10 locales.
 * Session : Fédération — Communs & Entraide
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const KEY = 'catalogacao.field.subjects';
const NEW = {
  fr: 'Mots-clés', 'pt-BR': 'Palavras-chave', es: 'Palabras clave', en: 'Keywords',
  it: 'Parole chiave', de: 'Schlagwörter', ca: 'Paraules clau', eo: 'Ŝlosilvortoj',
  nl: 'Trefwoorden', el: 'Λέξεις-κλειδιά',
};

const reKey = '"' + KEY.replace(/\./g, '\\.') + '":\\s*';
for (const loc of Object.keys(NEW)) {
  const file = path.join(DIR, loc + '.json');
  let c = fs.readFileSync(file, 'utf8');
  const re = new RegExp('(' + reKey + ')"(?:[^"\\\\]|\\\\.)*"');
  if (!re.test(c)) throw new Error('clé absente: ' + loc);
  c = c.replace(re, '$1' + JSON.stringify(NEW[loc]));
  JSON.parse(c); // valide
  fs.writeFileSync(file, c, 'utf8');
  console.log(loc + ': ' + KEY + ' -> ' + NEW[loc]);
}
console.log('\nTerminé.');
