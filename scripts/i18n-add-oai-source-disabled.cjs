/* ===========================================================================
 * i18n-add-oai-source-disabled.cjs
 * Paquet ALIGNER-LE-BOUTON — fn_import_harvest_oai refuse desormais une source
 * dont import_enabled est faux, avec HINT = 'error.oai.sourceDisabled'. Il lui
 * fallait un message, sinon le refus tombait sur le generique
 * « common.error.unknown » et personne ne comprenait pourquoi.
 * 1 cle x 10 locales. Idempotent, purement textuel.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'error.oai.sourceDisabled';

// Le message dit CE QU'IL FAUT FAIRE, pas seulement ce qui est refuse : la
// personne qui clique est coordinatrice, pas admin reseau, et ne peut pas
// reactiver la source elle-meme.
const VAL = {
  'pt-BR': 'Esta fonte está desativada para importação. Peça a reativação a uma administradora da rede.',
  fr: 'Cette source est désactivée pour l’importation. Demande sa réactivation à une admin réseau.',
  es: 'Esta fuente está desactivada para la importación. Pide su reactivación a una administradora de la red.',
  en: 'This source is disabled for importing. Ask a network admin to re-enable it.',
  it: 'Questa fonte è disattivata per l’importazione. Chiedi la riattivazione a un’amministratrice della rete.',
  de: 'Diese Quelle ist für den Import deaktiviert. Bitte eine Netzwerk-Admin um die Reaktivierung.',
  ca: 'Aquesta font està desactivada per a la importació. Demana’n la reactivació a una administradora de la xarxa.',
  eo: 'Ĉi tiu fonto estas malŝaltita por importado. Petu ĝian reaktivigon al reta administranto.',
  nl: 'Deze bron is uitgeschakeld voor import. Vraag een netwerkbeheerder om deze weer in te schakelen.',
  el: 'Αυτή η πηγή είναι απενεργοποιημένη για εισαγωγή. Ζήτησε την επανενεργοποίησή της από διαχειριστή του δικτύου.',
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    if (VAL[loc] == null) throw new Error('Traduction manquante: ' + loc);
    const entry = '  ' + JSON.stringify(SENTINEL) + ': ' + JSON.stringify(VAL[loc]);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ' : oai.sourceDisabled (si absente), JSON valide.');
}
console.log('\nTerminé.');
