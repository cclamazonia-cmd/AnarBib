// Ajoute catalog.filters.libraryNSelected aux 10 locales (multi-select biblios).
const fs = require('fs'); const path = require('path');
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const V = { 'pt-BR':'{n} selecionadas', fr:'{n} sélectionnées', es:'{n} seleccionadas', en:'{n} selected', it:'{n} selezionate', de:'{n} ausgewählt', ca:'{n} seleccionades', eo:'{n} elektitaj', nl:'{n} geselecteerd', el:'{n} επιλεγμένες' };
const KEY = 'catalog.filters.libraryNSelected';
for (const loc of Object.keys(V)) {
  const file = path.join(DIR, `${loc}.json`);
  const obj = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!(KEY in obj)) obj[KEY] = V[loc];
  const sorted = {}; for (const k of Object.keys(obj).sort()) sorted[k] = obj[k];
  fs.writeFileSync(file, JSON.stringify(sorted, null, 2) + '\n', 'utf8');
  console.log(`${loc}: ok`);
}
