/**
 * Add missing i18n keys for QueuePanel.jsx
 * Keys not covered by the initial add-i18n-keys.cjs batch.
 */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'catalogacao.queue.refreshing': {
    'pt-BR': 'Atualizando…',
    en: 'Refreshing…',
    fr: 'Actualisation…',
    es: 'Actualizando…',
    de: 'Aktualisierung…',
    it: 'Aggiornamento…',
    ca: 'Actualitzant…',
    eo: 'Aŭdatigante…',
    nl: 'Vernieuwen…',
    el: 'Ανανέωση…',
  },
  'catalogacao.queue.searchPlaceholder': {
    'pt-BR': 'Título, autor, tombo, referência…',
    en: 'Title, author, accession no., reference…',
    fr: 'Titre, auteur, no d’inventaire, référence…',
    es: 'Título, autor, registro, referencia…',
    de: 'Titel, Autor*in, Inventarnr., Referenz…',
    it: 'Titolo, autor*, numero, riferimento…',
    ca: 'Títol, autor-a-e, registre, referència…',
    eo: 'Titolo, aŭtor-in-o, numero, referenco…',
    nl: 'Titel, auteur, inventarisnr., referentie…',
    el: 'Τίτλος, συγγραφέας, αρ. εισαγωγής, αναφορά…',
  },
  'catalogacao.queue.selectAllFilter': {
    'pt-BR': 'Selecionar os {count} do filtro',
    en: 'Select all {count} in filter',
    fr: 'Sélectionner les {count} du filtre',
    es: 'Seleccionar los {count} del filtro',
    de: 'Alle {count} im Filter auswählen',
    it: 'Selezionare tutt* {count} del filtro',
    ca: 'Seleccionar els {count} del filtre',
    eo: 'Elekti ĉiujn {count} el filtro',
    nl: 'Alle {count} in filter selecteren',
    el: 'Επιλογή όλων {count} στο φίλτρο',
  },
  'catalogacao.queue.selectedAllFilter': {
    'pt-BR': '✓ {count} do filtro',
    en: '✓ {count} in filter',
    fr: '✓ {count} du filtre',
    es: '✓ {count} del filtro',
    de: '✓ {count} im Filter',
    it: '✓ {count} del filtro',
    ca: '✓ {count} del filtre',
    eo: '✓ {count} el filtro',
    nl: '✓ {count} in filter',
    el: '✓ {count} στο φίλτρο',
  },
  'catalogacao.queue.crossPage': {
    'pt-BR': ' (cross-page)',
    en: ' (cross-page)',
    fr: ' (multi-pages)',
    es: ' (multi-página)',
    de: ' (seitenübergreifend)',
    it: ' (multi-pagina)',
    ca: ' (multi-pàgina)',
    eo: ' (trans-paĝoj)',
    nl: ' (meerdere pagina’s)',
    el: ' (πολλαπλές σελίδες)',
  },
  'catalogacao.queue.batchPrefix': {
    'pt-BR': 'lote {id}',
    en: 'batch {id}',
    fr: 'lot {id}',
    es: 'lote {id}',
    de: 'Charge {id}',
    it: 'lotto {id}',
    ca: 'lot {id}',
    eo: 'loĉo {id}',
    nl: 'batch {id}',
    el: 'παρτίδα {id}',
  },
  'catalogacao.queue.refreshShort': {
    'pt-BR': 'Atualizar',
    en: 'Refresh',
    fr: 'Actualiser',
    es: 'Actualizar',
    de: 'Aktualisieren',
    it: 'Aggiornare',
    ca: 'Actualitzar',
    eo: 'Aŭdatigi',
    nl: 'Vernieuwen',
    el: 'Ανανέωση',
  },
};

const FILES = fs.readdirSync(LOCALES_DIR).filter(f => f.endsWith('.json'));

for (const file of FILES) {
  const locale = file.replace('.json', '');
  const filePath = path.join(LOCALES_DIR, file);
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));

  let added = 0;
  for (const [key, translations] of Object.entries(KEYS)) {
    if (!data[key]) {
      data[key] = translations[locale] || translations['en'];
      added++;
    }
  }

  const sorted = {};
  for (const k of Object.keys(data).sort()) sorted[k] = data[k];
  fs.writeFileSync(filePath, JSON.stringify(sorted, null, 2) + '\n', 'utf8');
  console.log(`${file}: ${added} key(s) added (total: ${Object.keys(sorted).length})`);
}
