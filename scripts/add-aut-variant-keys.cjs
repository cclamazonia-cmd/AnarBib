// scripts/add-aut-variant-keys.cjs
// Ajoute les clés i18n du chantier « formes du nom » (#AUT variant_forms) +
// champs structured_meta (activityPlace, pseudonyms) aux 10 locales, en parité
// exacte. Insertion à la position alphabétique sans réordonner les clés
// existantes (diff = lignes ajoutées seulement).
//
// Session : Catalogue longue traîne (recherche + fiche auteur)

const fs = require('fs');
const path = require('path');
const dir = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const LOCALES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

// Libellés neutres (aucune forme genrée → pas de marquage inclusif requis).
const T = {
  'author.activityPlace': {
    'pt-BR': 'Local de atividade', fr: "Lieu d'activité", es: 'Lugar de actividad',
    en: 'Place of activity', it: 'Luogo di attività', de: 'Wirkungsort',
    ca: "Lloc d'activitat", eo: 'Aktivloko', nl: 'Plaats van activiteit',
    el: 'Τόπος δράσης',
  },
  'author.pseudonyms': {
    'pt-BR': 'Pseudônimos', fr: 'Pseudonymes', es: 'Seudónimos', en: 'Pseudonyms',
    it: 'Pseudonimi', de: 'Pseudonyme', ca: 'Pseudònims', eo: 'Pseŭdonimoj',
    nl: 'Pseudoniemen', el: 'Ψευδώνυμα',
  },
  'author.variantForms': {
    'pt-BR': 'Outras formas do nome', fr: 'Autres formes du nom', es: 'Otras formas del nombre',
    en: 'Other name forms', it: 'Altre forme del nome', de: 'Weitere Namensformen',
    ca: 'Altres formes del nom', eo: 'Aliaj formoj de la nomo', nl: 'Andere naamsvormen',
    el: 'Άλλες μορφές του ονόματος',
  },
  'author.variantForms.less': {
    'pt-BR': 'Recolher', fr: 'Réduire', es: 'Contraer', en: 'Show less',
    it: 'Comprimi', de: 'Weniger anzeigen', ca: 'Replega', eo: 'Kunfaldi',
    nl: 'Minder tonen', el: 'Λιγότερα',
  },
  'author.variantForms.more': {
    'pt-BR': '+ {count} mais', fr: '+ {count} de plus', es: '+ {count} más',
    en: '+ {count} more', it: '+ {count} altre', de: '+ {count} weitere',
    ca: '+ {count} més', eo: '+ {count} pliaj', nl: '+ {count} meer',
    el: '+ {count} ακόμη',
  },
};

function insertSorted(entries, key, value) {
  if (entries.some(([k]) => k === key)) return false; // déjà présent
  const idx = entries.findIndex(([k]) => k > key);
  const entry = [key, value];
  if (idx === -1) entries.push(entry); else entries.splice(idx, 0, entry);
  return true;
}

const report = [];
for (const loc of LOCALES) {
  const file = path.join(dir, loc + '.json');
  const obj = JSON.parse(fs.readFileSync(file, 'utf8'));
  const entries = Object.entries(obj);
  let added = 0;
  for (const key of Object.keys(T)) {
    const val = T[key][loc];
    if (val == null) { console.error('MISSING translation', key, loc); process.exit(1); }
    if (insertSorted(entries, key, val)) added++;
  }
  const out = {};
  for (const [k, v] of entries) out[k] = v;
  fs.writeFileSync(file, JSON.stringify(out, null, 2) + '\n', 'utf8');
  report.push(loc + ': +' + added + ' -> ' + entries.length + ' clés');
}
console.log(report.join('\n'));
