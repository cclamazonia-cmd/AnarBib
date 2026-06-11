/**
 * Correctif Fila : barrière « en cours / échoué », lisibilité des doublons
 * (titre du candidat au lieu du 0%), action de rejet. Additif textuel.
 * Run : node scripts/merge-imp-fila-fix-keys.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

const K = {
  'importacoes.fila.processing.title': { 'pt-BR': 'Importação em processamento', fr: 'Import en cours de traitement', es: 'Importación en proceso', en: 'Import processing', it: 'Importazione in corso', de: 'Import wird verarbeitet', ca: 'Importació en procés', eo: 'Importo traktata', nl: 'Import wordt verwerkt', el: 'Επεξεργασία εισαγωγής' },
  'importacoes.fila.processing.desc': { 'pt-BR': 'As linhas ainda estão sendo analisadas e comparadas com o catálogo. Aguarde e atualize em alguns instantes.', fr: 'Les lignes sont encore analysées et comparées au catalogue. Patientez et actualisez dans un instant.', es: 'Las líneas aún se están analizando y comparando con el catálogo. Espere y actualice en unos instantes.', en: 'Rows are still being parsed and matched against the catalog. Please wait and refresh in a moment.', it: 'Le righe sono ancora in analisi e confronto col catalogo. Attendi e aggiorna tra poco.', de: 'Die Zeilen werden noch analysiert und mit dem Katalog abgeglichen. Bitte warten und gleich aktualisieren.', ca: 'Les línies encara s’analitzen i es comparen amb el catàleg. Espereu i actualitzeu d’aquí a poc.', eo: 'La linioj ankoraŭ estas analizataj kaj komparataj kun la katalogo. Bonvolu atendi kaj aktualigi post momento.', nl: 'De regels worden nog verwerkt en vergeleken met de catalogus. Wacht even en vernieuw zo.', el: 'Οι γραμμές αναλύονται ακόμη και αντιπαραβάλλονται με τον κατάλογο. Περιμένετε και ανανεώστε σε λίγο.' },
  'importacoes.fila.failed.title': { 'pt-BR': 'Importação falhou', fr: 'Import échoué', es: 'La importación falló', en: 'Import failed', it: 'Importazione fallita', de: 'Import fehlgeschlagen', ca: 'La importació ha fallat', eo: 'Importo malsukcesis', nl: 'Import mislukt', el: 'Η εισαγωγή απέτυχε' },
  'importacoes.fila.failed.desc': { 'pt-BR': 'Este lote não pôde ser processado. Você pode arquivá-lo ou excluí-lo na lista de lotes.', fr: 'Ce lot n’a pas pu être traité. Vous pouvez l’archiver ou le supprimer dans la liste des lots.', es: 'Este lote no pudo procesarse. Puede archivarlo o eliminarlo en la lista de lotes.', en: 'This batch could not be processed. You can archive or delete it in the batch list.', it: 'Questo lotto non è stato elaborato. Puoi archiviarlo o eliminarlo nell’elenco dei lotti.', de: 'Dieser Stapel konnte nicht verarbeitet werden. Sie können ihn in der Stapelliste archivieren oder löschen.', ca: 'Aquest lot no s’ha pogut processar. El podeu arxivar o eliminar a la llista de lots.', eo: 'Ĉi tiu loto ne povis esti traktita. Vi povas arkivi aŭ forigi ĝin en la listo de lotoj.', nl: 'Deze batch kon niet worden verwerkt. U kunt hem archiveren of verwijderen in de batchlijst.', el: 'Αυτή η παρτίδα δεν μπόρεσε να επεξεργαστεί. Μπορείτε να την αρχειοθετήσετε ή να τη διαγράψετε στη λίστα παρτίδων.' },
  'importacoes.fila.matchAgainst': { 'pt-BR': 'Possível duplicado de: {title}', fr: 'Doublon possible de : {title}', es: 'Posible duplicado de: {title}', en: 'Possible duplicate of: {title}', it: 'Possibile duplicato di: {title}', de: 'Mögliches Duplikat von: {title}', ca: 'Possible duplicat de: {title}', eo: 'Ebla duplikato de: {title}', nl: 'Mogelijk duplicaat van: {title}', el: 'Πιθανό διπλότυπο του: {title}' },
  'importacoes.fila.matchVerify': { 'pt-BR': 'Correspondência no catálogo — verificar', fr: 'Correspondance au catalogue — à vérifier', es: 'Coincidencia en el catálogo — verificar', en: 'Catalog match — to verify', it: 'Corrispondenza in catalogo — da verificare', de: 'Katalogtreffer — prüfen', ca: 'Coincidència al catàleg — verificar', eo: 'Kongruo en katalogo — kontroli', nl: 'Catalogusmatch — controleren', el: 'Αντιστοίχιση στον κατάλογο — έλεγχος' },
  'importacoes.fila.reject': { 'pt-BR': 'Rejeitar {n}', fr: 'Rejeter {n}', es: 'Rechazar {n}', en: 'Reject {n}', it: 'Rifiuta {n}', de: '{n} ablehnen', ca: 'Rebutja {n}', eo: 'Malakcepti {n}', nl: '{n} afwijzen', el: 'Απόρριψη {n}' },
  'importacoes.fila.rejecting': { 'pt-BR': 'Rejeitando linhas…', fr: 'Rejet des lignes…', es: 'Rechazando líneas…', en: 'Rejecting rows…', it: 'Rifiuto righe…', de: 'Zeilen werden abgelehnt…', ca: 'Rebutjant línies…', eo: 'Malakceptante liniojn…', nl: 'Regels afwijzen…', el: 'Απόρριψη γραμμών…' },
  'importacoes.fila.rejected': { 'pt-BR': 'Linhas rejeitadas.', fr: 'Lignes écartées.', es: 'Líneas rechazadas.', en: 'Rows rejected.', it: 'Righe rifiutate.', de: 'Zeilen abgelehnt.', ca: 'Línies rebutjades.', eo: 'Linioj malakceptitaj.', nl: 'Regels afgewezen.', el: 'Οι γραμμές απορρίφθηκαν.' },
};

let total = 0;
for (const loc of FILES) {
  const p = path.join(DIR, loc + '.json');
  let txt = fs.readFileSync(p, 'utf8');
  const toAdd = Object.entries(K).filter(([k]) => !txt.includes('"' + k + '"')).map(([k, v]) => [k, v[loc]]);
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
