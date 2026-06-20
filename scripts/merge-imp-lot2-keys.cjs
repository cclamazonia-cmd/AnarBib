/**
 * Merge Lot 2 i18n keys into all 10 locale files.
 * Run: node scripts/merge-imp-lot2-keys.cjs
 * Session : Lot 2 – Fontes externas bout-en-bout
 */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.resolve(__dirname, '../src/i18n/locales');

const NEW_KEYS = {
  'pt-BR': {
    'importacoes.fontes.importCandidate': 'Importer',
    'importacoes.fontes.importingCandidate': 'Importando candidato(a/e)…',
    'importacoes.fontes.candidateImported': '« {title} » importado(a/e) na fila de revisao.',
  },
  fr: {
    'importacoes.fontes.importCandidate': 'Importer',
    'importacoes.fontes.importingCandidate': 'Import du candidat en cours…',
    'importacoes.fontes.candidateImported': '« {title} » importé·e dans la file de révision.',
  },
  es: {
    'importacoes.fontes.importCandidate': 'Importar',
    'importacoes.fontes.importingCandidate': 'Importando candidate…',
    'importacoes.fontes.candidateImported': '« {title} » importade en la fila de revisión.',
  },
  en: {
    'importacoes.fontes.importCandidate': 'Import',
    'importacoes.fontes.importingCandidate': 'Importing candidate…',
    'importacoes.fontes.candidateImported': '"{title}" imported into the review queue.',
  },
  it: {
    'importacoes.fontes.importCandidate': 'Importare',
    'importacoes.fontes.importingCandidate': 'Importazione del candidat* in corso…',
    'importacoes.fontes.candidateImported': '« {title} » importat* nella coda di revisione.',
  },
  de: {
    'importacoes.fontes.importCandidate': 'Importieren',
    'importacoes.fontes.importingCandidate': 'Kandidat wird importiert…',
    'importacoes.fontes.candidateImported': '„{title}“ in die Prüfwarteschlange importiert.',
  },
  ca: {
    'importacoes.fontes.importCandidate': 'Importar',
    'importacoes.fontes.importingCandidate': 'Important candidat-a-e…',
    'importacoes.fontes.candidateImported': '« {title} » importat-da-de a la cua de revisió.',
  },
  eo: {
    'importacoes.fontes.importCandidate': 'Importi',
    'importacoes.fontes.importingCandidate': 'Importado de kandidat-in-o…',
    'importacoes.fontes.candidateImported': '« {title} » importita en la reviziovicon.',
  },
  nl: {
    'importacoes.fontes.importCandidate': 'Importeren',
    'importacoes.fontes.importingCandidate': 'Kandidaat wordt geïmporteerd…',
    'importacoes.fontes.candidateImported': '„{title}” geïmporteerd in de revisiewachtrij.',
  },
  el: {
    'importacoes.fontes.importCandidate': 'Εισαγωγή',
    'importacoes.fontes.importingCandidate': 'Εισαγωγή υποψηφίου…',
    'importacoes.fontes.candidateImported': '« {title} » εισήχθη στην ουρά αναθεώρησης.',
  },
};

const LOCALE_TO_FILE = {
  'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json',
  it: 'it.json', de: 'de.json', ca: 'ca.json', eo: 'eo.json',
  nl: 'nl.json', el: 'el.json',
};

let totalAdded = 0;
for (const [locale, newKeys] of Object.entries(NEW_KEYS)) {
  const filePath = path.join(LOCALES_DIR, LOCALE_TO_FILE[locale]);
  const raw = fs.readFileSync(filePath, 'utf8');
  const existing = JSON.parse(raw);
  let added = 0;
  for (const [k, v] of Object.entries(newKeys)) {
    if (!(k in existing)) { existing[k] = v; added++; }
  }
  const sorted = Object.keys(existing).sort().reduce((o, k) => { o[k] = existing[k]; return o; }, {});
  fs.writeFileSync(filePath, JSON.stringify(sorted, null, 2) + '\n', 'utf8');
  console.log(`${LOCALE_TO_FILE[locale]}: +${added} keys (total ${Object.keys(sorted).length})`);
  totalAdded += added;
}
console.log(`\nDone. Total new keys added: ${totalAdded}`);
