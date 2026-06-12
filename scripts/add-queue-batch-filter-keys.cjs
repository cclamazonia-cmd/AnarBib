/**
 * Add i18n keys for the QueuePanel batch (lot) filter (Mission 3) to the 10 locales.
 *
 *   catalogacao.queue.batchLabel  -> libelle du filtre « Lot »
 *   catalogacao.queue.allBatches  -> option « Tous les lots »
 *   catalogacao.queue.noBatch     -> option « Sans lot » (batch_id null)
 *
 * Termes neutres (aucun referent de personne -> pas de question de charte).
 * Coherent avec catalogacao.queue.batchPrefix existant (lot/lote/lotto/loĉo...).
 *
 * ADDITIF PUR (insertion textuelle, pas de reserialisation JSON : les locales ne
 * sont pas en ordre alphabetique strict). Parite des 10 locales preservee.
 *
 * Auteur  : Claude Opus 4.8
 * Session : Perf mission 2/3 + cleanup
 */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'catalogacao.queue.batchLabel': {
    'pt-BR': 'Lote', en: 'Batch', fr: 'Lot', es: 'Lote', de: 'Charge',
    it: 'Lotto', ca: 'Lot', eo: 'Loĉo', nl: 'Batch', el: 'Παρτίδα',
  },
  'catalogacao.queue.allBatches': {
    'pt-BR': 'Todos os lotes', en: 'All batches', fr: 'Tous les lots',
    es: 'Todos los lotes', de: 'Alle Chargen', it: 'Tutti i lotti',
    ca: 'Tots els lots', eo: 'Ĉiuj loĉoj', nl: 'Alle batches',
    el: 'Όλες οι παρτίδες',
  },
  'catalogacao.queue.noBatch': {
    'pt-BR': 'Sem lote', en: 'No batch', fr: 'Sans lot', es: 'Sin lote',
    de: 'Ohne Charge', it: 'Senza lotto', ca: 'Sense lot', eo: 'Sen loĉo',
    nl: 'Zonder batch', el: 'Χωρίς παρτίδα',
  },
};

// Insere une cle/valeur juste avant le `}` final, sans reserialiser le fichier.
function appendKeyTextually(text, key, value) {
  const closeIdx = text.lastIndexOf('}');
  if (closeIdx < 0) throw new Error('JSON sans accolade fermante');
  let before = text.slice(0, closeIdx).replace(/\s+$/, '');
  const tail = text.slice(closeIdx + 1);
  const entry = `${JSON.stringify(key)}: ${JSON.stringify(value)}`;
  const sep = before.endsWith('{') ? '\n  ' : ',\n  ';
  return `${before}${sep}${entry}\n}${tail.length ? tail : '\n'}`;
}

const FILES = fs.readdirSync(LOCALES_DIR).filter(f => f.endsWith('.json'));

for (const file of FILES) {
  const locale = file.replace('.json', '');
  const filePath = path.join(LOCALES_DIR, file);
  let text = fs.readFileSync(filePath, 'utf8');
  const data = JSON.parse(text);

  let added = 0;
  for (const [key, translations] of Object.entries(KEYS)) {
    if (data[key] === undefined) {
      const value = translations[locale] || translations['en'];
      text = appendKeyTextually(text, key, value);
      data[key] = value;
      added++;
    }
  }

  if (added > 0) fs.writeFileSync(filePath, text, 'utf8');
  console.log(`${file}: ${added} key(s) added`);
}
