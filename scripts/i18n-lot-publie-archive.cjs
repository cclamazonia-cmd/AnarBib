/* ===========================================================================
 * i18n-archive.cjs
 * Onglet Lots : distinguer EN COURS / PUBLIES / CORBEILLE, et dire qu'un lot
 * publie s'archive au lieu de se supprimer. Les deux dernieres cles sont les
 * HINT leves par le trigger fn_guard_catalog_batch_delete.
 * 5 cles x 10 locales. Idempotent (sentinelle catalogacao.batch.draftsInProgress).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalogacao.batch.draftsInProgress';
const K = [
  'catalogacao.batch.draftsInProgress',
  'catalogacao.batch.draftsPublished',
  'catalogacao.batchPublishedArchiveInstead',
  'error.batch.has_drafts_in_progress',
  'error.batch.published_archive_instead',
];

const V = {
  fr: [
    '{count} en cours',
    '{count} publié(s)',
    'Ce lot porte {count} fiche(s) déjà publiée(s) au catalogue : il garde la mémoire de cette séance de catalogage. Un lot publié s’archive — utilise « Archiver ».',
    'Ce lot retient encore du travail en cours. Traite-le ou mets-le au rebut avant de supprimer le lot.',
    'Ce lot porte des fiches publiées : il s’archive, il ne se supprime pas.',
  ],
  'pt-BR': [
    '{count} em curso',
    '{count} publicado(s)',
    'Este lote tem {count} ficha(s) já publicada(s) no catálogo: ele guarda a memória dessa sessão de catalogação. Um lote publicado arquiva-se — usa «Arquivar».',
    'Este lote ainda retém trabalho em curso. Trata-o ou manda-o para a lixeira antes de excluir o lote.',
    'Este lote tem fichas publicadas: ele arquiva-se, não se exclui.',
  ],
  es: [
    '{count} en curso',
    '{count} publicado(s)',
    'Este lote tiene {count} ficha(s) ya publicada(s) en el catálogo: guarda la memoria de esa sesión de catalogación. Un lote publicado se archiva — usa «Archivar».',
    'Este lote aún retiene trabajo en curso. Trátalo o descártalo antes de eliminar el lote.',
    'Este lote tiene fichas publicadas: se archiva, no se elimina.',
  ],
  en: [
    '{count} in progress',
    '{count} published',
    'This batch holds {count} record(s) already published to the catalogue: it keeps the memory of that cataloguing session. A published batch is archived — use “Archive”.',
    'This batch still holds work in progress. Deal with it or discard it before deleting the batch.',
    'This batch holds published records: it is archived, not deleted.',
  ],
  it: [
    '{count} in corso',
    '{count} pubblicata/e',
    'Questo lotto ha {count} scheda/e già pubblicata/e nel catalogo: conserva la memoria di quella sessione di catalogazione. Un lotto pubblicato si archivia — usa «Archivia».',
    'Questo lotto trattiene ancora lavoro in corso. Trattalo o scartalo prima di eliminare il lotto.',
    'Questo lotto ha schede pubblicate: si archivia, non si elimina.',
  ],
  de: [
    '{count} in Arbeit',
    '{count} veröffentlicht',
    'Dieses Los enthält {count} bereits im Katalog veröffentlichte Datensätze: es bewahrt die Erinnerung an diese Katalogisierungssitzung. Ein veröffentlichtes Los wird archiviert — nutze „Archivieren“.',
    'Dieses Los enthält noch laufende Arbeit. Bearbeite oder verwirf sie, bevor du das Los löschst.',
    'Dieses Los enthält veröffentlichte Datensätze: es wird archiviert, nicht gelöscht.',
  ],
  ca: [
    '{count} en curs',
    '{count} publicada/es',
    'Aquest lot té {count} fitxa/es ja publicada/es al catàleg: conserva la memòria d’aquella sessió de catalogació. Un lot publicat s’arxiva — fes servir «Arxiva».',
    'Aquest lot encara reté feina en curs. Tracta-la o descarta-la abans d’eliminar el lot.',
    'Aquest lot té fitxes publicades: s’arxiva, no s’elimina.',
  ],
  eo: [
    '{count} survoje',
    '{count} publikigita(j)',
    'Ĉi tiu loto portas {count} jam publikigita(j)n slipo(j)n en la katalogo: ĝi konservas la memoron de tiu kataloga kunsido. Publikigita loto arkiviĝas — uzu «Arkivi».',
    'Ĉi tiu loto ankoraŭ retenas laboron survoje. Traktu ĝin aŭ forĵetu ĝin antaŭ ol forigi la loton.',
    'Ĉi tiu loto portas publikigitajn slipojn: ĝi arkiviĝas, ĝi ne foriĝas.',
  ],
  nl: [
    '{count} in bewerking',
    '{count} gepubliceerd',
    'Dit lot bevat {count} reeds in de catalogus gepubliceerde fiche(s): het bewaart de herinnering aan die catalogiseersessie. Een gepubliceerd lot wordt gearchiveerd — gebruik “Archiveren”.',
    'Dit lot bevat nog werk in bewerking. Behandel het of gooi het weg voordat je het lot verwijdert.',
    'Dit lot bevat gepubliceerde fiches: het wordt gearchiveerd, niet verwijderd.',
  ],
  el: [
    '{count} σε εξέλιξη',
    '{count} δημοσιευμένα',
    'Αυτή η παρτίδα έχει {count} ήδη δημοσιευμένη/ες καρτέλα/ες στον κατάλογο: κρατά τη μνήμη εκείνης της συνεδρίας καταλογογράφησης. Μια δημοσιευμένη παρτίδα αρχειοθετείται — χρησιμοποίησε «Αρχειοθέτηση».',
    'Αυτή η παρτίδα κρατά ακόμη εργασία σε εξέλιξη. Διαχειρίσου την ή πέταξέ την πριν διαγράψεις την παρτίδα.',
    'Αυτή η παρτίδα έχει δημοσιευμένες καρτέλες: αρχειοθετείται, δεν διαγράφεται.',
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
  console.log(loc + ': 5 cles archive (si absentes), JSON valide.');
}
console.log('\nTermine.');
