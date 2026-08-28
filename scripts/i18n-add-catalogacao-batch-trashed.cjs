/* ===========================================================================
 * i18n-add-catalogacao-batch-trashed.cjs
 * Onglet « Lots » : seconde confirmation quand le lot ne retient plus que des
 * brouillons a la corbeille. Ils sont supprimes avec le lot — le dire avant.
 * 1 cle x 10 locales. Idempotent (sentinelle catalogacao.batchTrashedWillBeDeleted).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalogacao.batchTrashedWillBeDeleted';

const K = ['batchTrashedWillBeDeleted'];

const V = {
  fr: ['Ce lot ne retient plus que {count} brouillon(s) à la corbeille. Ils seront supprimés définitivement avec le lot. Continuer ?'],
  'pt-BR': ['Este lote só contém mais {count} rascunho(s) na lixeira. Eles serão excluídos definitivamente junto com o lote. Continuar?'],
  es: ['Este lote solo retiene {count} borrador(es) en la papelera. Se eliminarán definitivamente junto con el lote. ¿Continuar?'],
  en: ['This batch only holds {count} draft(s) in the trash. They will be permanently deleted along with the batch. Continue?'],
  it: ['Questo lotto trattiene solo {count} bozza/e nel cestino. Saranno eliminate definitivamente insieme al lotto. Continuare?'],
  de: ['Dieses Los enthält nur noch {count} Entwurf/Entwürfe im Papierkorb. Sie werden zusammen mit dem Los endgültig gelöscht. Fortfahren?'],
  ca: ['Aquest lot només reté {count} esborrany(s) a la paperera. S’eliminaran definitivament juntament amb el lot. Voleu continuar?'],
  eo: ['Ĉi tiu loto retenas nur {count} malneto(j)n en la rubujo. Ili estos definitive forigitaj kune kun la loto. Ĉu daŭrigi?'],
  nl: ['Dit lot bevat alleen nog {count} concept(en) in de prullenbak. Ze worden samen met het lot definitief verwijderd. Doorgaan?'],
  el: ['Αυτή η παρτίδα κρατά μόνο {count} πρόχειρο(α) στον κάδο. Θα διαγραφούν οριστικά μαζί με την παρτίδα. Συνέχεια;'],
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const vals = V[loc];
    if (!vals || vals.length !== K.length) throw new Error('Valeurs manquantes: ' + loc);
    const entries = K.map((k, i) => '  ' + JSON.stringify('catalogacao.' + k) + ': ' + JSON.stringify(vals[i]));
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 1 cle batchTrashed (si absente), JSON valide.');
}
console.log('\nTermine.');
