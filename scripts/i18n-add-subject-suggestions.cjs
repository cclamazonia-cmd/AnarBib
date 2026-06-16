/* ===========================================================================
 * i18n-add-subject-suggestions.cjs
 * Bloc « suggestions » du picker matière (thésaurus v2 G). 2 clés × 10 locales.
 * Idempotent (sentinelle catalogacao.subjects.suggestions).
 * Session : Fédération — Communs & Entraide
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const PREFIX = 'catalogacao.subjects.';
const SENTINEL = PREFIX + 'suggestions';

const K = ['suggestions', 'suggestionsHint'];

const V = {
  fr: ['Suggestions :', 'D’après les autres livres de l’auteur·rice. Clique pour ajouter.'],
  'pt-BR': ['Sugestões:', 'A partir dos outros livros da autoria. Clica para adicionar.'],
  es: ['Sugerencias:', 'A partir de los otros libros de la autoría. Haz clic para añadir.'],
  en: ['Suggestions:', 'From the author’s other books. Click to add.'],
  it: ['Suggerimenti:', 'Dagli altri libri dell’autore/trice. Clicca per aggiungere.'],
  de: ['Vorschläge:', 'Aus den anderen Büchern der Autor*innen. Zum Hinzufügen klicken.'],
  ca: ['Suggeriments:', 'A partir dels altres llibres de l’autoria. Clica per afegir.'],
  eo: ['Sugestoj:', 'El la aliaj libroj de la aŭtor-in-o. Klaku por aldoni.'],
  nl: ['Suggesties:', 'Uit de andere boeken van de auteur. Klik om toe te voegen.'],
  el: ['Προτάσεις:', 'Από τα άλλα βιβλία της συγγραφής. Κάνε κλικ για προσθήκη.'],
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const vals = V[loc];
    if (!vals || vals.length !== K.length) throw new Error('Valeurs manquantes: ' + loc);
    const entries = K.map((k, i) => '  ' + JSON.stringify(PREFIX + k) + ': ' + JSON.stringify(vals[i]));
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 2 clés suggestions (si absentes), JSON valide.');
}
console.log('\nTerminé.');
