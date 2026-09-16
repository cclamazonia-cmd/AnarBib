/* ===========================================================================
 * i18n-rename-gazette-fractale.cjs
 * GAZ-10 (16/09/2026) — la gazette ne s'appelle plus « Rizoma » (nom déjà
 * porté par le journal d'un collectif catalan rencontré à Bologne) mais
 * « Fractale ». Le nom propre n'est pas traduit : on remplace le mot dans les
 * VALEURS des trois clés qui le portent, dans les 10 locales, sans toucher
 * aux clés ni à la structure des fichiers (remplacement textuel, jamais de
 * re-sérialisation JSON).
 *
 * Idempotent : un fichier sans « Rizoma » est laissé tel quel.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const KEYS = ['rede.lettre.item.gazette', 'inicio.kw.gazette', 'inicio.kw.gazetteAdmin'];

let total = 0;
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  let n = 0;
  const out = lines.map((line) => {
    const key = KEYS.find((k) => line.startsWith('  ' + JSON.stringify(k) + ':'));
    if (!key || !line.includes('Rizoma')) return line;
    n++;
    return line.replace(/Rizoma/g, 'Fractale');
  });
  if (n > 0) fs.writeFileSync(file, out.join('\n'), 'utf8');
  const relu = fs.readFileSync(file, 'utf8');
  JSON.parse(relu);
  if (relu.includes('Rizoma')) throw new Error(loc + ' : « Rizoma » subsiste hors des trois clés attendues');
  total += n;
  console.log(loc + ' : ' + n + ' valeur(s) renommée(s), JSON valide.');
}
console.log('\nTerminé — ' + total + ' valeur(s) (' + KEYS.length + ' clés × ' + LOCALES.length + ' locales attendues = ' + (KEYS.length * LOCALES.length) + ').');
