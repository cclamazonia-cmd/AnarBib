/**
 * Brique 2 : clés de sélection par-ligne (validation individuelle des
 * nouveautés) + filtre de correspondance, file de revue Importações.
 * Additif textuel. Run : node scripts/merge-imp-fila-select-keys.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

const K = {
  'importacoes.fila.selectAll':     { 'pt-BR': 'Selecionar tudo', fr: 'Tout sélectionner', es: 'Seleccionar todo', en: 'Select all', it: 'Seleziona tutto', de: 'Alle auswählen', ca: 'Selecciona-ho tot', eo: 'Elekti ĉion', nl: 'Alles selecteren', el: 'Επιλογή όλων' },
  'importacoes.fila.selectedCount': { 'pt-BR': '{n} selecionada(s)', fr: '{n} sélectionnée(s)', es: '{n} seleccionada(s)', en: '{n} selected', it: '{n} selezionata/e', de: '{n} ausgewählt', ca: '{n} seleccionada/es', eo: '{n} elektita(j)', nl: '{n} geselecteerd', el: '{n} επιλεγμένες' },
  'importacoes.fila.createSelected':{ 'pt-BR': 'Criar {n} rascunho(s)', fr: 'Créer {n} brouillon(s)', es: 'Crear {n} borrador(es)', en: 'Create {n} draft(s)', it: 'Crea {n} bozza/e', de: '{n} Entwurf/Entwürfe erstellen', ca: 'Crea {n} esborrany(s)', eo: 'Krei {n} malneto(j)n', nl: '{n} concept(en) maken', el: 'Δημιουργία {n} προσχεδίων' },
  'importacoes.fila.clearSelection':{ 'pt-BR': 'Limpar seleção', fr: 'Effacer la sélection', es: 'Borrar selección', en: 'Clear selection', it: 'Annulla selezione', de: 'Auswahl aufheben', ca: 'Esborra la selecció', eo: 'Vakigi elekton', nl: 'Selectie wissen', el: 'Καθαρισμός επιλογής' },
  'importacoes.fila.allMatches':    { 'pt-BR': 'Todas as correspondências', fr: 'Toutes les correspondances', es: 'Todas las correspondencias', en: 'All matches', it: 'Tutte le corrispondenze', de: 'Alle Treffer', ca: 'Totes les correspondències', eo: 'Ĉiuj kongruoj', nl: 'Alle overeenkomsten', el: 'Όλες οι αντιστοιχίσεις' },
  'importacoes.fila.filterNew':     { 'pt-BR': 'Novidades', fr: 'Nouveautés', es: 'Novedades', en: 'New records', it: 'Novità', de: 'Neuzugänge', ca: 'Novetats', eo: 'Novaĵoj', nl: 'Nieuw', el: 'Νέες εγγραφές' },
  'importacoes.fila.filterDup':     { 'pt-BR': 'Possíveis duplicados', fr: 'Doublons possibles', es: 'Posibles duplicados', en: 'Possible duplicates', it: 'Possibili duplicati', de: 'Mögliche Duplikate', ca: 'Possibles duplicats', eo: 'Eblaj duplikatoj', nl: 'Mogelijke duplicaten', el: 'Πιθανά διπλότυπα' },
};

let total = 0;
for (const loc of FILES) {
  const p = path.join(DIR, loc + '.json');
  let txt = fs.readFileSync(p, 'utf8');
  const toAdd = Object.entries(K).filter(([k]) => !txt.includes('"' + k + '"')).map(([k, v]) => [k, v[loc]]);
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
