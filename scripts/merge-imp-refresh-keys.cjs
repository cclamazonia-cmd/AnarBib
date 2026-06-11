/**
 * Ajoute les clés importacoes.refresh / .refreshing (bouton refresh de la page
 * Importações) aux 10 locales. Insertion TEXTUELLE additive.
 * Run : node scripts/merge-imp-refresh-keys.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = { 'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json', it: 'it.json', de: 'de.json', ca: 'ca.json', eo: 'eo.json', nl: 'nl.json', el: 'el.json' };

const K = (refresh, refreshing) => ({ 'importacoes.refresh': refresh, 'importacoes.refreshing': refreshing });

const KEYS = {
  'pt-BR': K('Atualizar', 'Atualizando…'),
  fr: K('Actualiser', 'Actualisation…'),
  es: K('Actualizar', 'Actualizando…'),
  en: K('Refresh', 'Refreshing…'),
  it: K('Aggiorna', 'Aggiornamento…'),
  de: K('Aktualisieren', 'Wird aktualisiert…'),
  ca: K('Actualitza', 'S’està actualitzant…'),
  eo: K('Aktualigi', 'Aktualigado…'),
  nl: K('Vernieuwen', 'Bezig met vernieuwen…'),
  el: K('Ανανέωση', 'Ανανέωση…'),
};

let total = 0;
for (const [loc, file] of Object.entries(FILES)) {
  const p = path.join(DIR, file);
  let txt = fs.readFileSync(p, 'utf8');
  const toAdd = Object.entries(KEYS[loc]).filter(([k]) => !txt.includes('"' + k + '"'));
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
