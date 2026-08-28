/* ===========================================================================
 * i18n-trash-scope.cjs
 * Portee du vidage de corbeille.
 *   (a) AJOUTE catalogacao.queue.emptyTrashBatchConfirm — vidage limite a un lot.
 *   (b) REECRIT catalogacao.queue.emptyTrashConfirm — le cas non filtre porte sur
 *       TOUTE la corbeille du reseau ; l'ancienne phrase ne le disait pas, et
 *       c'est ce silence qui a fait supprimer 259 brouillons de 5 bibliotheques
 *       la ou on en visait 237 d'un seul lot (28/08/2026).
 * 10 locales. Idempotent : (a) par sentinelle, (b) par comparaison a la valeur.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const ADD_KEY = 'catalogacao.queue.emptyTrashBatchConfirm';
const REWRITE_KEY = 'catalogacao.queue.emptyTrashConfirm';

const ADD = {
  fr: 'Vider la corbeille du lot « {batch} » ? {count} brouillon(s) seront définitivement supprimé(s).',
  'pt-BR': 'Esvaziar a lixeira do lote “{batch}”? {count} rascunho(s) serão apagados de forma irreversível.',
  es: 'Vaciar la papelera del lote «{batch}»? {count} borrador(es) serán eliminados de forma irreversible.',
  en: 'Empty the trash for batch “{batch}”? {count} draft(s) will be permanently deleted.',
  it: 'Svuotare il cestino del lotto «{batch}»? {count} bozza/e verranno eliminate in modo irreversibile.',
  de: 'Papierkorb des Loses „{batch}“ leeren? {count} Entwurf/Entwürfe werden endgültig gelöscht.',
  ca: 'Buidar la paperera del lot «{batch}»? {count} esborrany(s) seran eliminats de forma irreversible.',
  eo: 'Ĉu malplenigi la rubujon de la loto «{batch}»? {count} malneto(j) estos definitive forigita(j).',
  nl: 'Prullenbak van lot “{batch}” legen? {count} concept(en) worden definitief verwijderd.',
  el: 'Άδειασμα κάδου της παρτίδας «{batch}»; {count} προσχέδια θα διαγραφούν οριστικά.',
};

const REWRITE = {
  fr: 'Vider TOUTE la corbeille ? {count} brouillon(s) de tous les lots et de toutes les bibliothèques seront définitivement supprimé(s). Pour n’en viser qu’un, choisis un lot dans la liste à côté du bouton.',
  'pt-BR': 'Esvaziar TODA a lixeira? {count} rascunho(s) de todos os lotes e de todas as bibliotecas serão apagados de forma irreversível. Para visar apenas um, escolhe um lote na lista ao lado do botão.',
  es: 'Vaciar TODA la papelera? {count} borrador(es) de todos los lotes y de todas las bibliotecas serán eliminados de forma irreversible. Para apuntar a uno solo, elige un lote en la lista junto al botón.',
  en: 'Empty the WHOLE trash? {count} draft(s) from every batch and every library will be permanently deleted. To target just one, pick a batch from the list next to the button.',
  it: 'Svuotare TUTTO il cestino? {count} bozza/e di tutti i lotti e di tutte le biblioteche verranno eliminate in modo irreversibile. Per limitarti a uno, scegli un lotto nell’elenco accanto al pulsante.',
  de: 'Den GESAMTEN Papierkorb leeren? {count} Entwurf/Entwürfe aus allen Losen und allen Bibliotheken werden endgültig gelöscht. Um nur eines zu treffen, wähle ein Los in der Liste neben der Schaltfläche.',
  ca: 'Buidar TOTA la paperera? {count} esborrany(s) de tots els lots i de totes les biblioteques seran eliminats de forma irreversible. Per apuntar només a un, tria un lot a la llista del costat del botó.',
  eo: 'Ĉu malplenigi la TUTAN rubujon? {count} malneto(j) el ĉiuj lotoj kaj ĉiuj bibliotekoj estos definitive forigita(j). Por celi nur unu, elektu loton en la listo apud la butono.',
  nl: 'De HELE prullenbak legen? {count} concept(en) uit alle loten en alle bibliotheken worden definitief verwijderd. Kies een lot in de lijst naast de knop om er maar één te treffen.',
  el: 'Άδειασμα ΟΛΟΚΛΗΡΟΥ του κάδου; {count} προσχέδια από όλες τις παρτίδες και όλες τις βιβλιοθήκες θα διαγραφούν οριστικά. Για να στοχεύσεις μία μόνο, διάλεξε παρτίδα από τη λίστα δίπλα στο κουμπί.',
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let touched = [];

  // (a) ajout
  if (!content.includes('"' + ADD_KEY + '"')) {
    const val = ADD[loc];
    if (!val) throw new Error('Valeur manquante (ajout): ' + loc);
    const entry = '  ' + JSON.stringify(ADD_KEY) + ': ' + JSON.stringify(val);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    touched.push('ajout');
  }

  // (b) reecriture ciblee : on ne touche QUE la ligne de cette cle.
  const before = JSON.parse(content)[REWRITE_KEY];
  if (before === undefined) throw new Error(REWRITE_KEY + ' absente de ' + loc);
  if (before !== REWRITE[loc]) {
    const line = new RegExp('^(\\s*' + JSON.stringify(REWRITE_KEY).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\s*:\\s*).*?(,?)$', 'm');
    if (!line.test(content)) throw new Error('ligne ' + REWRITE_KEY + ' introuvable dans ' + loc);
    content = content.replace(line, (m, head, tail) => head + JSON.stringify(REWRITE[loc]) + tail);
    touched.push('reecriture');
  }

  fs.writeFileSync(file, content, 'utf8');
  const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (parsed[REWRITE_KEY] !== REWRITE[loc]) throw new Error('reecriture ratee: ' + loc);
  if (parsed[ADD_KEY] !== ADD[loc]) throw new Error('ajout rate: ' + loc);
  console.log(loc + ': ' + (touched.length ? touched.join(' + ') : 'deja a jour') + ', JSON valide.');
}
console.log('\nTermine.');
