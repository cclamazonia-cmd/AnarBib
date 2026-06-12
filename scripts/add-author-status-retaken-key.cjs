/**
 * Add missing i18n key `catalogacao.status.retaken` to all 10 locales.
 *
 * Bug console (12/06/2026) : AuthorDraftForm.jsx ACTION_KEYS.update pointe sur
 * `catalogacao.status.retaken`, jamais definie -> MISSING_TRANSLATION par ligne
 * de la file de catalogage. Libelle affiche en minuscules, en miroir de
 * `catalogacao.status.new` (action "create"). Sens : le brouillon met a jour une
 * autorite existante (vs. en creer une nouvelle).
 *
 * ADDITIF PUR (insertion textuelle) : on n'ecrase jamais une cle existante et on
 * NE reserialise PAS le JSON (les locales ne sont pas en ordre alphabetique
 * strict -> un JSON.stringify trie reordonnerait tout le fichier). On insere la
 * cle juste avant le `}` final, en preservant l'ordre et le formatage existants
 * (2 espaces, LF, sans BOM). Parite des 10 locales preservee.
 *
 * Auteur  : Claude Opus 4.8
 * Session : Perf mission 2/3 + cleanup
 */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'catalogacao.status.retaken': {
    'pt-BR': 'atualização',
    en: 'update',
    fr: 'mise à jour',
    es: 'actualización',
    de: 'aktualisierung',
    it: 'aggiornamento',
    ca: 'actualització',
    eo: 'ĝisdatigo',
    nl: 'bijwerking',
    el: 'ενημέρωση',
  },
};

// Insere une cle/valeur juste avant le `}` final, sans reserialiser le fichier.
function appendKeyTextually(text, key, value) {
  const closeIdx = text.lastIndexOf('}');
  if (closeIdx < 0) throw new Error('JSON sans accolade fermante');
  let before = text.slice(0, closeIdx).replace(/\s+$/, '');
  const tail = text.slice(closeIdx + 1); // ce qui suit le } (newline final)
  const entry = `${JSON.stringify(key)}: ${JSON.stringify(value)}`;
  // Si l'objet n'est pas vide, la derniere propriete recoit une virgule.
  const sep = before.endsWith('{') ? '\n  ' : ',\n  ';
  return `${before}${sep}${entry}\n}${tail.length ? tail : '\n'}`;
}

const FILES = fs.readdirSync(LOCALES_DIR).filter(f => f.endsWith('.json'));

for (const file of FILES) {
  const locale = file.replace('.json', '');
  const filePath = path.join(LOCALES_DIR, file);
  let text = fs.readFileSync(filePath, 'utf8');
  const data = JSON.parse(text); // valide le JSON + verifie l'existence des cles

  let added = 0;
  for (const [key, translations] of Object.entries(KEYS)) {
    if (data[key] === undefined) {
      const value = translations[locale] || translations['en'];
      text = appendKeyTextually(text, key, value);
      data[key] = value; // au cas ou plusieurs cles seraient ajoutees
      added++;
    }
  }

  if (added > 0) fs.writeFileSync(filePath, text, 'utf8');
  console.log(`${file}: ${added} key(s) added`);
}
