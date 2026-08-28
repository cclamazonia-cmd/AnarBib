/* ===========================================================================
 * i18n-add-catalogacao-trash-showing.cjs
 * Corbeille de la file editoriale : dire ce qui est AFFICHE quand la liste est
 * plafonnee (100 par type), sinon l'ecart avec le compte reel du pop-up de
 * vidage se lit comme une incoherence.
 * 1 cle x 10 locales. Idempotent (sentinelle catalogacao.queue.trashShowing).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalogacao.queue.trashShowing';

const V = {
  fr: '{shown} affichés sur {total}',
  'pt-BR': '{shown} exibidos de {total}',
  es: '{shown} mostrados de {total}',
  en: '{shown} shown out of {total}',
  it: '{shown} mostrati su {total}',
  de: '{shown} von {total} angezeigt',
  ca: '{shown} mostrats de {total}',
  eo: '{shown} montritaj el {total}',
  nl: '{shown} van {total} weergegeven',
  el: '{shown} από {total} εμφανίζονται',
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const val = V[loc];
    if (!val) throw new Error('Valeur manquante: ' + loc);
    const entry = '  ' + JSON.stringify(SENTINEL) + ': ' + JSON.stringify(val);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 1 cle trashShowing (si absente), JSON valide.');
}
console.log('\nTermine.');
