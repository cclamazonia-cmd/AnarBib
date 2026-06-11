/**
 * Renomme le bouton de lancement du wizard : importacoes.wizard.launch
 * « Novo import » -> « Guia » (plus clair : assistant guidé). UPDATE de valeur
 * (pas un ajout) : remplacement textuel ciblé, sans re-sérialiser le JSON.
 * Run : node scripts/update-wizard-launch-label.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const NEW = {
  'pt-BR.json': 'Guia', 'fr.json': 'Guide', 'es.json': 'Guía', 'en.json': 'Guide',
  'it.json': 'Guida', 'de.json': 'Anleitung', 'ca.json': 'Guia', 'eo.json': 'Gvidilo',
  'nl.json': 'Gids', 'el.json': 'Οδηγός',
};
const RE = /("importacoes\.wizard\.launch":\s*)"[^"]*"/;
for (const [file, val] of Object.entries(NEW)) {
  const p = path.join(DIR, file);
  let txt = fs.readFileSync(p, 'utf8');
  if (!RE.test(txt)) { console.log(file.padEnd(11), 'CLE INTROUVABLE'); continue; }
  txt = txt.replace(RE, '$1' + JSON.stringify(val));
  fs.writeFileSync(p, txt, 'utf8');
  JSON.parse(fs.readFileSync(p, 'utf8'));
  console.log(file.padEnd(11), '-> ' + val);
}
