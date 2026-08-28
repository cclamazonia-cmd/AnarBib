/* ===========================================================================
 * i18n-restore.cjs
 * Levier 2 : le journal des suppressions definitives et leur rejeu.
 * 6 cles d'ecran + 3 hints leves par public.fn_restore_deleted_draft.
 * 9 cles x 10 locales. Idempotent (sentinelle catalogacao.queue.deletedTitle).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalogacao.queue.deletedTitle';

const K = [
  'catalogacao.queue.deletedTitle',
  'catalogacao.queue.deletedDescription',
  'catalogacao.queue.deletedEmpty',
  'catalogacao.queue.restoreDeleted',
  'catalogacao.queue.restoreDeletedConfirm',
  'catalogacao.queue.restoreDeletedResult',
  'error.catalog.restore_not_found',
  'error.catalog.restore_no_snapshot',
  'error.catalog.restore_already',
];

const V = {
  fr: [
    'Suppressions définitives',
    'Chaque suppression garde un instantané rejouable pendant 90 jours. Au-delà, la trace reste, l’instantané non.',
    'Aucune suppression définitive enregistrée.',
    'Restaurer',
    'Restaurer ce brouillon supprimé ? Il reviendra dans la corbeille, d’où tu pourras le remettre en brouillon.',
    'Brouillon {id} restauré.',
    'Cette entrée de journal est introuvable, ou ce n’est pas une suppression.',
    'L’instantané de ce brouillon a été purgé (au-delà de 90 jours) : la trace reste, mais il n’est plus rejouable.',
    'Ce brouillon existe déjà : il a probablement été restauré entre-temps.',
  ],
  'pt-BR': [
    'Exclusões definitivas',
    'Cada exclusão guarda um instantâneo restaurável por 90 dias. Depois disso, o registo permanece, o instantâneo não.',
    'Nenhuma exclusão definitiva registada.',
    'Restaurar',
    'Restaurar este rascunho excluído? Ele voltará para a lixeira, de onde podes devolvê-lo a rascunho.',
    'Rascunho {id} restaurado.',
    'Esta entrada de registo não existe, ou não é uma exclusão.',
    'O instantâneo deste rascunho foi purgado (mais de 90 dias): o registo permanece, mas já não é restaurável.',
    'Este rascunho já existe: provavelmente foi restaurado entretanto.',
  ],
  es: [
    'Eliminaciones definitivas',
    'Cada eliminación guarda una instantánea restaurable durante 90 días. Después, queda el rastro, no la instantánea.',
    'Ninguna eliminación definitiva registrada.',
    'Restaurar',
    '¿Restaurar este borrador eliminado? Volverá a la papelera, desde donde podrás devolverlo a borrador.',
    'Borrador {id} restaurado.',
    'Esta entrada del registro no existe, o no es una eliminación.',
    'La instantánea de este borrador fue purgada (más de 90 días): queda el rastro, pero ya no es restaurable.',
    'Este borrador ya existe: probablemente fue restaurado mientras tanto.',
  ],
  en: [
    'Permanent deletions',
    'Every deletion keeps a restorable snapshot for 90 days. After that the trace remains, the snapshot does not.',
    'No permanent deletion recorded.',
    'Restore',
    'Restore this deleted draft? It will come back in the trash, from where you can return it to draft.',
    'Draft {id} restored.',
    'This log entry does not exist, or is not a deletion.',
    'This draft’s snapshot was purged (over 90 days old): the trace remains, but it can no longer be restored.',
    'This draft already exists: it was probably restored in the meantime.',
  ],
  it: [
    'Eliminazioni definitive',
    'Ogni eliminazione conserva un’istantanea ripristinabile per 90 giorni. Dopo resta la traccia, non l’istantanea.',
    'Nessuna eliminazione definitiva registrata.',
    'Ripristina',
    'Ripristinare questa bozza eliminata? Tornerà nel cestino, da dove potrai rimetterla in bozza.',
    'Bozza {id} ripristinata.',
    'Questa voce di registro non esiste, o non è un’eliminazione.',
    'L’istantanea di questa bozza è stata eliminata (oltre 90 giorni): la traccia resta, ma non è più ripristinabile.',
    'Questa bozza esiste già: probabilmente è stata ripristinata nel frattempo.',
  ],
  de: [
    'Endgültige Löschungen',
    'Jede Löschung bewahrt 90 Tage lang eine wiederherstellbare Momentaufnahme. Danach bleibt die Spur, die Momentaufnahme nicht.',
    'Keine endgültige Löschung verzeichnet.',
    'Wiederherstellen',
    'Diesen gelöschten Entwurf wiederherstellen? Er landet wieder im Papierkorb, von dort kannst du ihn zurück in den Entwurf holen.',
    'Entwurf {id} wiederhergestellt.',
    'Dieser Journaleintrag existiert nicht oder ist keine Löschung.',
    'Die Momentaufnahme dieses Entwurfs wurde gelöscht (älter als 90 Tage): die Spur bleibt, wiederherstellbar ist er nicht mehr.',
    'Dieser Entwurf existiert bereits: er wurde vermutlich zwischenzeitlich wiederhergestellt.',
  ],
  ca: [
    'Eliminacions definitives',
    'Cada eliminació conserva una instantània restaurable durant 90 dies. Després queda el rastre, no la instantània.',
    'Cap eliminació definitiva registrada.',
    'Restaura',
    'Vols restaurar aquest esborrany eliminat? Tornarà a la paperera, des d’on podràs recuperar-lo com a esborrany.',
    'Esborrany {id} restaurat.',
    'Aquesta entrada del registre no existeix, o no és una eliminació.',
    'La instantània d’aquest esborrany s’ha purgat (més de 90 dies): el rastre queda, però ja no es pot restaurar.',
    'Aquest esborrany ja existeix: probablement s’ha restaurat mentrestant.',
  ],
  eo: [
    'Definitivaj forigoj',
    'Ĉiu forigo konservas restaŭreblan momentfoton dum 90 tagoj. Poste restas la spuro, ne la momentfoto.',
    'Neniu definitiva forigo registrita.',
    'Restaŭri',
    'Ĉu restaŭri ĉi tiun forigitan malneton? Ĝi revenos en la rubujon, de kie vi povos remeti ĝin kiel malneton.',
    'Malneto {id} restaŭrita.',
    'Ĉi tiu ĵurnalero ne ekzistas, aŭ ne estas forigo.',
    'La momentfoto de ĉi tiu malneto estis purigita (pli ol 90 tagoj): la spuro restas, sed ĝi ne plu restaŭreblas.',
    'Ĉi tiu malneto jam ekzistas: ĝi verŝajne estis restaŭrita intertempe.',
  ],
  nl: [
    'Definitieve verwijderingen',
    'Elke verwijdering bewaart 90 dagen een herstelbare momentopname. Daarna blijft het spoor, de momentopname niet.',
    'Geen definitieve verwijdering geregistreerd.',
    'Herstellen',
    'Dit verwijderde concept herstellen? Het komt terug in de prullenbak, vanwaar je het weer concept kunt maken.',
    'Concept {id} hersteld.',
    'Deze logregel bestaat niet, of is geen verwijdering.',
    'De momentopname van dit concept is gewist (ouder dan 90 dagen): het spoor blijft, herstellen kan niet meer.',
    'Dit concept bestaat al: het is waarschijnlijk intussen hersteld.',
  ],
  el: [
    'Οριστικές διαγραφές',
    'Κάθε διαγραφή κρατά ένα επαναφέρσιμο στιγμιότυπο για 90 ημέρες. Μετά μένει το ίχνος, όχι το στιγμιότυπο.',
    'Καμία οριστική διαγραφή καταγεγραμμένη.',
    'Επαναφορά',
    'Επαναφορά αυτού του διαγραμμένου προχείρου; Θα επιστρέψει στον κάδο, από όπου μπορείς να το ξανακάνεις πρόχειρο.',
    'Το πρόχειρο {id} επαναφέρθηκε.',
    'Αυτή η εγγραφή ημερολογίου δεν υπάρχει, ή δεν είναι διαγραφή.',
    'Το στιγμιότυπο αυτού του προχείρου διαγράφηκε (πάνω από 90 ημέρες): το ίχνος μένει, αλλά δεν επαναφέρεται πια.',
    'Αυτό το πρόχειρο υπάρχει ήδη: πιθανότατα επαναφέρθηκε στο μεταξύ.',
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
  for (const k of K) if (parsed[k] === undefined) throw new Error('cle absente apres ecriture: ' + loc + ' / ' + k);
  console.log(loc + ': ' + K.length + ' cles rejeu (si absentes), JSON valide.');
}
console.log('\nTermine.');
