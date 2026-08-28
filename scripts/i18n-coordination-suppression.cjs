/* ===========================================================================
 * i18n-coord.cjs
 * Deux cles : la note qui remplace les boutons de suppression definitive pour
 * qui n'est pas de la coordination, et le refus de publier dans une biblio
 * dont on n'est pas membre (HINT de publish_book_draft).
 * 2 cles x 10 locales. Idempotent (sentinelle catalogacao.coordOnlyDelete).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalogacao.coordOnlyDelete';
const K = ['catalogacao.coordOnlyDelete', 'error.publish.other_library'];

const V = {
  fr: [
    'Suppression définitive : coordination',
    'Ce brouillon est rattaché à une bibliothèque dont tu n’es pas membre. Sa publication est réservée à cette bibliothèque ou à une admin réseau.',
  ],
  'pt-BR': [
    'Exclusão definitiva: coordenação',
    'Este rascunho está vinculado a uma biblioteca da qual não fazes parte. A publicação cabe a essa biblioteca ou a uma administradora da rede.',
  ],
  es: [
    'Eliminación definitiva: coordinación',
    'Este borrador está vinculado a una biblioteca de la que no formas parte. Su publicación corresponde a esa biblioteca o a una administradora de la red.',
  ],
  en: [
    'Permanent deletion: coordination',
    'This draft belongs to a library you are not a member of. Publishing it is up to that library or a network admin.',
  ],
  it: [
    'Eliminazione definitiva: coordinamento',
    'Questa bozza è legata a una biblioteca di cui non fai parte. La pubblicazione spetta a quella biblioteca o a un’amministratrice di rete.',
  ],
  de: [
    'Endgültiges Löschen: Koordination',
    'Dieser Entwurf gehört zu einer Bibliothek, der du nicht angehörst. Die Veröffentlichung liegt bei dieser Bibliothek oder einer Netzwerk-Admin.',
  ],
  ca: [
    'Eliminació definitiva: coordinació',
    'Aquest esborrany està vinculat a una biblioteca de la qual no ets membre. La publicació correspon a aquesta biblioteca o a una administradora de la xarxa.',
  ],
  eo: [
    'Definitiva forigo: kunordigo',
    'Ĉi tiu malneto apartenas al biblioteko al kiu vi ne membras. Ĝia publikigo apartenas al tiu biblioteko aŭ al reta administranto.',
  ],
  nl: [
    'Definitief verwijderen: coördinatie',
    'Dit concept hoort bij een bibliotheek waar je geen lid van bent. Publiceren is aan die bibliotheek of aan een netwerkbeheerder.',
  ],
  el: [
    'Οριστική διαγραφή: συντονισμός',
    'Αυτό το πρόχειρο ανήκει σε βιβλιοθήκη της οποίας δεν είσαι μέλος. Η δημοσίευσή του ανήκει σε αυτή τη βιβλιοθήκη ή σε διαχειριστή δικτύου.',
  ],
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const vals = V[loc];
    if (!vals || vals.length !== K.length) throw new Error('Valeurs manquantes: ' + loc);
    const entries = K.map((k, i) => '  ' + JSON.stringify(k) + ': ' + JSON.stringify(vals[i]));
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const k of K) if (parsed[k] === undefined) throw new Error('cle absente: ' + loc + ' / ' + k);
  console.log(loc + ': 2 cles coordination (si absentes), JSON valide.');
}
console.log('\nTermine.');
