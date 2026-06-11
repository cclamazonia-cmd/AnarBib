/**
 * Ajoute les clés importacoes.deleteRun / .deleteRunConfirm / .deletingRun /
 * .runDeleted (suppression d'un run d'import) aux 10 locales. Additif textuel.
 * Run : node scripts/merge-imp-delete-run-keys.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = { 'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json', it: 'it.json', de: 'de.json', ca: 'ca.json', eo: 'eo.json', nl: 'nl.json', el: 'el.json' };

const K = (del, confirm, deleting, deleted) => ({
  'importacoes.deleteRun': del,
  'importacoes.deleteRunConfirm': confirm,
  'importacoes.deletingRun': deleting,
  'importacoes.runDeleted': deleted,
});

const KEYS = {
  'pt-BR': K('Excluir o tratamento', 'Excluir o tratamento #{id} e seu arquivo? Os rascunhos já criados são mantidos.', 'Excluindo…', 'Tratamento excluído.'),
  fr: K('Supprimer le run', 'Supprimer le run #{id} et son fichier ? Les brouillons déjà créés sont conservés.', 'Suppression…', 'Run supprimé.'),
  es: K('Eliminar el tratamiento', '¿Eliminar el tratamiento #{id} y su archivo? Los borradores ya creados se conservan.', 'Eliminando…', 'Tratamiento eliminado.'),
  en: K('Delete run', 'Delete run #{id} and its file? Drafts already created are kept.', 'Deleting…', 'Run deleted.'),
  it: K('Elimina l’elaborazione', 'Eliminare l’elaborazione #{id} e il suo file? Le bozze già create vengono mantenute.', 'Eliminazione…', 'Elaborazione eliminata.'),
  de: K('Lauf löschen', 'Lauf #{id} und seine Datei löschen? Bereits erstellte Entwürfe bleiben erhalten.', 'Wird gelöscht…', 'Lauf gelöscht.'),
  ca: K('Suprimeix el tractament', 'Voleu suprimir el tractament #{id} i el seu fitxer? Els esborranys ja creats es conserven.', 'S’està suprimint…', 'Tractament suprimit.'),
  eo: K('Forigi la traktadon', 'Ĉu forigi la traktadon #{id} kaj ĝian dosieron? La jam kreitaj malnetoj restas.', 'Forigado…', 'Traktado forigita.'),
  nl: K('Run verwijderen', 'Run #{id} en het bestand verwijderen? Reeds aangemaakte concepten blijven behouden.', 'Bezig met verwijderen…', 'Run verwijderd.'),
  el: K('Διαγραφή επεξεργασίας', 'Διαγραφή της επεξεργασίας #{id} και του αρχείου της; Τα προσχέδια που έχουν ήδη δημιουργηθεί διατηρούνται.', 'Διαγραφή…', 'Η επεξεργασία διαγράφηκε.'),
};

let total = 0;
for (const [loc, file] of Object.entries(FILES)) {
  const p = path.join(DIR, file);
  let txt = fs.readFileSync(p, 'utf8');
  const toAdd = Object.entries(KEYS[loc]).filter(([k]) => !txt.includes('"' + k + '"'));
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
