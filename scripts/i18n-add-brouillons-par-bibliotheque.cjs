/* ===========================================================================
 * i18n-add-brouillons-par-bibliotheque.cjs
 * B29 (27/09/2026, REGISTRE CAT-E18) — les brouillons de catalogage
 * appartiennent à leur bibliothèque : refus des fonctions (HINT), lecture seule
 * des autorités d'autrui, messages de la file.
 * 14 clés neuves × 10 locales (idempotent : une clé présente n'est pas réécrite)
 * — dont 4 ajoutées après la revue : lot inchangé, lot non supprimé, corbeille
 * partiellement vidée, bibliothèque hors portée dans « Biblioteca »
 * + 1 clé RÉÉCRITE : catalogacao.queue.emptyTrashConfirm disait « de toutes
 * les bibliothèques », ce qui devient faux (la corbeille est celle de ses
 * bibliothèques ; tout le réseau pour l'administration).
 * Usage : node scripts/i18n-add-brouillons-par-bibliotheque.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
// pt-BR au « você » (DOC-ADDR-1), après la revue du 27/09 : réécrites si elles diffèrent.
const REECRITES = ['catalogacao.queue.emptyTrashConfirm', 'error.catalog.draft_other_library', 'error.catalog.author_draft_creator_only',
  'error.batch.other_libraries', 'catalogacao.queue.someUnchanged', 'catalogacao.exemplar.libraryNotYours',
  'catalogacao.batchDeleteNothing', 'catalogacao.batch.reassign.warn.itemsDetached'];   // la corbeille ne compte plus (IMP-20 c)

const ADD = {
  fr: {
    'error.catalog.draft_other_library': 'Ce brouillon appartient à une bibliothèque dont tu n’es pas staff : seule cette bibliothèque (ou l’administration du réseau) peut agir dessus.',
    'error.catalog.author_draft_creator_only': 'Ce brouillon d’autorité a été créé par une autre personne : tu peux le lire, mais seule elle (ou l’administration du réseau) peut le modifier ou le publier.',
    'error.batch.other_libraries': 'Ce lot contient des brouillons que tu ne peux pas modifier (d’une autre bibliothèque, ou autorités créées par d’autres personnes) : seule l’administration du réseau peut agir sur tout le lot.',
    'catalogacao.author.readOnlyOtherCreator': 'Brouillon créé par une autre personne : lecture seule. Seule elle, ou l’administration du réseau, peut le modifier ou le publier.',
    'catalogacao.queue.someUnchanged': 'Certains éléments n’ont pas changé : ils ne sont pas modifiables par toi (autre bibliothèque, autorité créée par une autre personne) ou suivent leur notice.',
    'catalogacao.queue.authorOtherCreator': 'Autorité créée par une autre personne : lecture seule.',
    'catalogacao.queue.deleteNothing': 'Rien n’a été supprimé : la suppression définitive revient à la coordination de la bibliothèque du brouillon.',
    'catalogacao.queue.emptyTrashConfirm': 'Vider la corbeille ? {count} brouillon(s) de tes bibliothèques, tous lots confondus (tout le réseau pour l’administration), seront définitivement supprimé(s). Pour ne viser qu’un lot, choisis-le dans la liste à côté du bouton.',
  },
  'pt-BR': {
    'error.catalog.draft_other_library': 'Este rascunho pertence a uma biblioteca da qual você não é staff: só essa biblioteca (ou a administração da rede) pode agir sobre ele.',
    'error.catalog.author_draft_creator_only': 'Este rascunho de autoridade foi criado por outra pessoa: você pode lê-lo, mas só ela (ou a administração da rede) pode modificá-lo ou publicá-lo.',
    'error.batch.other_libraries': 'Este lote contém rascunhos que você não pode modificar (de outra biblioteca, ou autoridades criadas por outras pessoas): só a administração da rede pode agir sobre o lote inteiro.',
    'catalogacao.author.readOnlyOtherCreator': 'Rascunho criado por outra pessoa: somente leitura. Só ela, ou a administração da rede, pode modificá-lo ou publicá-lo.',
    'catalogacao.queue.someUnchanged': 'Alguns itens não mudaram: você não pode modificá-los (outra biblioteca, autoridade criada por outra pessoa) ou eles seguem a sua ficha.',
    'catalogacao.queue.authorOtherCreator': 'Autoridade criada por outra pessoa: somente leitura.',
    'catalogacao.queue.deleteNothing': 'Nada foi apagado: a exclusão definitiva cabe à coordenação da biblioteca do rascunho.',
    'catalogacao.queue.emptyTrashConfirm': 'Esvaziar a lixeira? {count} rascunho(s) das suas bibliotecas, de todos os lotes (a rede toda para a administração), serão apagados definitivamente. Para visar um só lote, escolha-o na lista ao lado do botão.',
  },
  es: {
    'error.catalog.draft_other_library': 'Este borrador pertenece a una biblioteca de la que no eres staff: solo esa biblioteca (o la administración de la red) puede actuar sobre él.',
    'error.catalog.author_draft_creator_only': 'Este borrador de autoridad lo creó otra persona: puedes leerlo, pero solo ella (o la administración de la red) puede modificarlo o publicarlo.',
    'error.batch.other_libraries': 'Este lote contiene borradores que no puedes modificar (de otra biblioteca, o autoridades creadas por otras personas): solo la administración de la red puede actuar sobre el lote entero.',
    'catalogacao.author.readOnlyOtherCreator': 'Borrador creado por otra persona: solo lectura. Solo ella, o la administración de la red, puede modificarlo o publicarlo.',
    'catalogacao.queue.someUnchanged': 'Algunos elementos no cambiaron: no puedes modificarlos (otra biblioteca, autoridad creada por otra persona) o siguen a su ficha.',
    'catalogacao.queue.authorOtherCreator': 'Autoridad creada por otra persona: solo lectura.',
    'catalogacao.queue.deleteNothing': 'No se eliminó nada: la eliminación definitiva corresponde a la coordinación de la biblioteca del borrador.',
    'catalogacao.queue.emptyTrashConfirm': '¿Vaciar la papelera? {count} borrador(es) de tus bibliotecas, de todos los lotes (toda la red para la administración), se eliminarán definitivamente. Para apuntar a un solo lote, elígelo en la lista junto al botón.',
  },
  en: {
    'error.catalog.draft_other_library': 'This draft belongs to a library where you are not staff: only that library (or the network administration) can act on it.',
    'error.catalog.author_draft_creator_only': 'This authority draft was created by someone else: you can read it, but only they (or the network administration) can edit or publish it.',
    'error.batch.other_libraries': 'This batch contains drafts you cannot edit (from another library, or authorities created by other people): only the network administration can act on the whole batch.',
    'catalogacao.author.readOnlyOtherCreator': 'Draft created by someone else: read-only. Only they, or the network administration, can edit or publish it.',
    'catalogacao.queue.someUnchanged': 'Some entries did not change: you cannot edit them (another library, an authority created by someone else) or they follow their record.',
    'catalogacao.queue.authorOtherCreator': 'Authority created by someone else: read-only.',
    'catalogacao.queue.deleteNothing': 'Nothing was deleted: permanent deletion is up to the coordination of the draft’s library.',
    'catalogacao.queue.emptyTrashConfirm': 'Empty the trash? {count} draft(s) from your libraries, across all batches (the whole network for the administration), will be permanently deleted. To target a single batch, pick it from the list next to the button.',
  },
  ca: {
    'error.catalog.draft_other_library': 'Aquest esborrany pertany a una biblioteca de la qual no ets staff: només aquesta biblioteca (o l’administració de la xarxa) hi pot actuar.',
    'error.catalog.author_draft_creator_only': 'Aquest esborrany d’autoritat l’ha creat una altra persona: el pots llegir, però només ella (o l’administració de la xarxa) el pot modificar o publicar.',
    'error.batch.other_libraries': 'Aquest lot conté esborranys que no pots modificar (d’una altra biblioteca, o autoritats creades per altres persones): només l’administració de la xarxa pot actuar sobre tot el lot.',
    'catalogacao.author.readOnlyOtherCreator': 'Esborrany creat per una altra persona: només lectura. Només ella, o l’administració de la xarxa, el pot modificar o publicar.',
    'catalogacao.queue.someUnchanged': 'Alguns elements no han canviat: no els pots modificar (una altra biblioteca, una autoritat creada per una altra persona) o segueixen la seva fitxa.',
    'catalogacao.queue.authorOtherCreator': 'Autoritat creada per una altra persona: només lectura.',
    'catalogacao.queue.deleteNothing': 'No s’ha suprimit res: la supressió definitiva correspon a la coordinació de la biblioteca de l’esborrany.',
    'catalogacao.queue.emptyTrashConfirm': 'Buidar la paperera? {count} esborrany(s) de les teves biblioteques, de tots els lots (tota la xarxa per a l’administració), se suprimiran definitivament. Per apuntar a un sol lot, tria’l a la llista al costat del botó.',
  },
  de: {
    'error.catalog.draft_other_library': 'Dieser Entwurf gehört zu einer Bibliothek, in der du nicht zum Team gehörst: nur diese Bibliothek (oder die Netzwerk-Administration) kann damit arbeiten.',
    'error.catalog.author_draft_creator_only': 'Dieser Normdaten-Entwurf wurde von einer anderen Person angelegt: du kannst ihn lesen, aber nur sie (oder die Netzwerk-Administration) kann ihn ändern oder veröffentlichen.',
    'error.batch.other_libraries': 'Dieser Stapel enthält Entwürfe, die du nicht ändern kannst (aus einer anderen Bibliothek oder von anderen Personen angelegte Normdaten): nur die Netzwerk-Administration kann mit dem ganzen Stapel arbeiten.',
    'catalogacao.author.readOnlyOtherCreator': 'Von einer anderen Person angelegter Entwurf: nur lesbar. Nur sie oder die Netzwerk-Administration kann ihn ändern oder veröffentlichen.',
    'catalogacao.queue.someUnchanged': 'Einige Einträge haben sich nicht geändert: du kannst sie nicht bearbeiten (andere Bibliothek, von einer anderen Person angelegte Normdaten) oder sie folgen ihrem Titel.',
    'catalogacao.queue.authorOtherCreator': 'Von einer anderen Person angelegte Normdaten: nur lesbar.',
    'catalogacao.queue.deleteNothing': 'Nichts wurde gelöscht: endgültiges Löschen ist Sache der Koordination der Bibliothek des Entwurfs.',
    'catalogacao.queue.emptyTrashConfirm': 'Papierkorb leeren? {count} Entwurf/Entwürfe deiner Bibliotheken aus allen Stapeln (das ganze Netzwerk für die Administration) werden endgültig gelöscht. Um nur einen Stapel zu treffen, wähle ihn in der Liste neben der Schaltfläche.',
  },
  el: {
    'error.catalog.draft_other_library': 'Αυτό το πρόχειρο ανήκει σε βιβλιοθήκη στην οποία δεν είσαι μέλος του προσωπικού: μόνο αυτή η βιβλιοθήκη (ή η διαχείριση του δικτύου) μπορεί να ενεργήσει σε αυτό.',
    'error.catalog.author_draft_creator_only': 'Αυτό το πρόχειρο καθιερωμένου ονόματος δημιουργήθηκε από άλλο πρόσωπο: μπορείς να το διαβάσεις, αλλά μόνο εκείνο (ή η διαχείριση του δικτύου) μπορεί να το τροποποιήσει ή να το δημοσιεύσει.',
    'error.batch.other_libraries': 'Αυτή η παρτίδα περιέχει πρόχειρα που δεν μπορείς να τροποποιήσεις (άλλης βιβλιοθήκης, ή καθιερωμένα ονόματα άλλων προσώπων): μόνο η διαχείριση του δικτύου μπορεί να ενεργήσει σε όλη την παρτίδα.',
    'catalogacao.author.readOnlyOtherCreator': 'Πρόχειρο που δημιούργησε άλλο πρόσωπο: μόνο ανάγνωση. Μόνο εκείνο, ή η διαχείριση του δικτύου, μπορεί να το τροποποιήσει ή να το δημοσιεύσει.',
    'catalogacao.queue.someUnchanged': 'Ορισμένα στοιχεία δεν άλλαξαν: δεν μπορείς να τα τροποποιήσεις (άλλη βιβλιοθήκη, καθιερωμένο όνομα άλλου προσώπου) ή ακολουθούν την εγγραφή τους.',
    'catalogacao.queue.authorOtherCreator': 'Καθιερωμένο όνομα που δημιούργησε άλλο πρόσωπο: μόνο ανάγνωση.',
    'catalogacao.queue.deleteNothing': 'Δεν διαγράφηκε τίποτα: η οριστική διαγραφή αφορά τον συντονισμό της βιβλιοθήκης του προχείρου.',
    'catalogacao.queue.emptyTrashConfirm': 'Άδειασμα του κάδου; {count} πρόχειρο(α) των βιβλιοθηκών σου, από όλες τις παρτίδες (όλο το δίκτυο για τη διαχείριση), θα διαγραφούν οριστικά. Για μία μόνο παρτίδα, διάλεξέ την στη λίστα δίπλα στο κουμπί.',
  },
  eo: {
    'error.catalog.draft_other_library': 'Ĉi tiu malneto apartenas al biblioteko, kies teamano vi ne estas: nur tiu biblioteko (aŭ la reta administrado) povas agi pri ĝi.',
    'error.catalog.author_draft_creator_only': 'Ĉi tiun aŭtoritatan malneton kreis alia persono: vi povas legi ĝin, sed nur ŝi (aŭ la reta administrado) povas ŝanĝi aŭ publikigi ĝin.',
    'error.batch.other_libraries': 'Ĉi tiu aro enhavas malnetojn, kiujn vi ne povas ŝanĝi (de alia biblioteko, aŭ aŭtoritatojn kreitajn de aliaj personoj): nur la reta administrado povas agi pri la tuta aro.',
    'catalogacao.author.readOnlyOtherCreator': 'Malneto kreita de alia persono: nur legebla. Nur ŝi, aŭ la reta administrado, povas ŝanĝi aŭ publikigi ĝin.',
    'catalogacao.queue.someUnchanged': 'Kelkaj eroj ne ŝanĝiĝis: vi ne povas ŝanĝi ilin (alia biblioteko, aŭtoritato kreita de alia persono) aŭ ili sekvas sian registron.',
    'catalogacao.queue.authorOtherCreator': 'Aŭtoritato kreita de alia persono: nur legebla.',
    'catalogacao.queue.deleteNothing': 'Nenio estis forigita: la definitiva forigo apartenas al la kunordigo de la biblioteko de la malneto.',
    'catalogacao.queue.emptyTrashConfirm': 'Malplenigi la rubujon? {count} malneto(j) de viaj bibliotekoj, el ĉiuj aroj (la tuta reto por la administrado), estos definitive forigitaj. Por celi nur unu aron, elektu ĝin en la listo apud la butono.',
  },
  it: {
    'error.catalog.draft_other_library': 'Questa bozza appartiene a una biblioteca di cui non fai parte dello staff: solo quella biblioteca (o l’amministrazione della rete) può agire su di essa.',
    'error.catalog.author_draft_creator_only': 'Questa bozza d’autorità è stata creata da un’altra persona: puoi leggerla, ma solo lei (o l’amministrazione della rete) può modificarla o pubblicarla.',
    'error.batch.other_libraries': 'Questo lotto contiene bozze che non puoi modificare (di un’altra biblioteca, o autorità create da altre persone): solo l’amministrazione della rete può agire sull’intero lotto.',
    'catalogacao.author.readOnlyOtherCreator': 'Bozza creata da un’altra persona: sola lettura. Solo lei, o l’amministrazione della rete, può modificarla o pubblicarla.',
    'catalogacao.queue.someUnchanged': 'Alcuni elementi non sono cambiati: non puoi modificarli (altra biblioteca, autorità creata da un’altra persona) o seguono la loro scheda.',
    'catalogacao.queue.authorOtherCreator': 'Autorità creata da un’altra persona: sola lettura.',
    'catalogacao.queue.deleteNothing': 'Non è stato eliminato nulla: l’eliminazione definitiva spetta al coordinamento della biblioteca della bozza.',
    'catalogacao.queue.emptyTrashConfirm': 'Svuotare il cestino? {count} bozza/e delle tue biblioteche, di tutti i lotti (tutta la rete per l’amministrazione), saranno eliminate definitivamente. Per un solo lotto, sceglilo nella lista accanto al pulsante.',
  },
  nl: {
    'error.catalog.draft_other_library': 'Dit concept hoort bij een bibliotheek waar je geen staff bent: alleen die bibliotheek (of het netwerkbeheer) kan ermee werken.',
    'error.catalog.author_draft_creator_only': 'Dit autoriteitsconcept is door iemand anders gemaakt: je kunt het lezen, maar alleen die persoon (of het netwerkbeheer) kan het wijzigen of publiceren.',
    'error.batch.other_libraries': 'Deze reeks bevat concepten die je niet kunt wijzigen (van een andere bibliotheek, of autoriteiten van andere personen): alleen het netwerkbeheer kan met de hele reeks werken.',
    'catalogacao.author.readOnlyOtherCreator': 'Concept gemaakt door iemand anders: alleen lezen. Alleen die persoon, of het netwerkbeheer, kan het wijzigen of publiceren.',
    'catalogacao.queue.someUnchanged': 'Sommige items zijn niet gewijzigd: je kunt ze niet bewerken (andere bibliotheek, autoriteit van iemand anders) of ze volgen hun record.',
    'catalogacao.queue.authorOtherCreator': 'Autoriteit gemaakt door iemand anders: alleen lezen.',
    'catalogacao.queue.deleteNothing': 'Er is niets verwijderd: definitief verwijderen is aan de coördinatie van de bibliotheek van het concept.',
    'catalogacao.queue.emptyTrashConfirm': 'Prullenbak legen? {count} concept(en) van jouw bibliotheken, uit alle reeksen (het hele netwerk voor het beheer), worden definitief verwijderd. Kies één reeks in de lijst naast de knop om alleen die te treffen.',
  },
};

// Après la revue (27/09) : ce que la base refuse désormais EN SILENCE (filtre
// RLS, 0 ligne) se dit à l'écran.
const ADD_REVUE = {
  fr: {
    'catalogacao.exemplar.libraryNotYours': 'Tu n’es pas staff de {library} : cet exemplaire ne peut pas y être rangé et garde sa bibliothèque actuelle (la tienne, pour un nouvel exemplaire). Seule {library}, ou l’administration du réseau, peut l’y cataloguer.',
    'catalogacao.queue.emptyTrashSomeKept': '{count} brouillon(s) restent dans la corbeille : leur suppression définitive revient à la coordination de leur bibliothèque.',
    'catalogacao.batchUpdateNothing': 'Le lot n’a pas changé : il contient des brouillons d’autres bibliothèques. Seule l’administration du réseau peut le fermer ou l’archiver.',
    'catalogacao.batchDeleteNothing': 'Le lot n’a pas été supprimé : sa suppression revient à une coordination dont les bibliothèques détiennent tous ses brouillons, ou à l’administration du réseau.',
  },
  'pt-BR': {
    'catalogacao.exemplar.libraryNotYours': 'Você não é staff de {library}: este exemplar não pode ser guardado lá e mantém a sua biblioteca atual (a sua, para um exemplar novo). Só {library}, ou a administração da rede, pode catalogá-lo lá.',
    'catalogacao.queue.emptyTrashSomeKept': '{count} rascunho(s) continuam na lixeira: a exclusão definitiva cabe à coordenação da biblioteca de cada um.',
    'catalogacao.batchUpdateNothing': 'O lote não mudou: contém rascunhos de outras bibliotecas. Só a administração da rede pode fechá-lo ou arquivá-lo.',
    'catalogacao.batchDeleteNothing': 'O lote não foi apagado: a exclusão cabe a uma coordenação cujas bibliotecas detêm todos os seus rascunhos, ou à administração da rede.',
  },
  es: {
    'catalogacao.exemplar.libraryNotYours': 'No eres staff de {library}: este ejemplar no puede guardarse allí y conserva su biblioteca actual (la tuya, para un ejemplar nuevo). Solo {library}, o la administración de la red, puede catalogarlo allí.',
    'catalogacao.queue.emptyTrashSomeKept': '{count} borrador(es) siguen en la papelera: su eliminación definitiva corresponde a la coordinación de su biblioteca.',
    'catalogacao.batchUpdateNothing': 'El lote no cambió: contiene borradores de otras bibliotecas. Solo la administración de la red puede cerrarlo o archivarlo.',
    'catalogacao.batchDeleteNothing': 'El lote no se eliminó: su eliminación corresponde a una coordinación cuyas bibliotecas tienen todos sus borradores, o a la administración de la red.',
  },
  en: {
    'catalogacao.exemplar.libraryNotYours': 'You are not staff at {library}: this copy cannot be filed there and keeps its current library (yours, for a new copy). Only {library}, or the network administration, can catalogue it there.',
    'catalogacao.queue.emptyTrashSomeKept': '{count} draft(s) remain in the trash: permanent deletion is up to the coordination of their library.',
    'catalogacao.batchUpdateNothing': 'The batch did not change: it contains drafts from other libraries. Only the network administration can close or archive it.',
    'catalogacao.batchDeleteNothing': 'The batch was not deleted: deleting it is up to a coordination whose libraries hold all its drafts, or to the network administration.',
  },
  ca: {
    'catalogacao.exemplar.libraryNotYours': 'No ets staff de {library}: aquest exemplar no s’hi pot desar i conserva la seva biblioteca actual (la teva, per a un exemplar nou). Només {library}, o l’administració de la xarxa, l’hi pot catalogar.',
    'catalogacao.queue.emptyTrashSomeKept': '{count} esborrany(s) continuen a la paperera: la supressió definitiva correspon a la coordinació de la seva biblioteca.',
    'catalogacao.batchUpdateNothing': 'El lot no ha canviat: conté esborranys d’altres biblioteques. Només l’administració de la xarxa el pot tancar o arxivar.',
    'catalogacao.batchDeleteNothing': 'El lot no s’ha suprimit: suprimir-lo correspon a una coordinació les biblioteques de la qual tenen tots els seus esborranys, o a l’administració de la xarxa.',
  },
  de: {
    'catalogacao.exemplar.libraryNotYours': 'Du gehörst nicht zum Team von {library}: dieses Exemplar kann dort nicht abgelegt werden und behält seine aktuelle Bibliothek (deine, bei einem neuen Exemplar). Nur {library} oder die Netzwerk-Administration kann es dort katalogisieren.',
    'catalogacao.queue.emptyTrashSomeKept': '{count} Entwurf/Entwürfe bleiben im Papierkorb: endgültiges Löschen ist Sache der Koordination ihrer Bibliothek.',
    'catalogacao.batchUpdateNothing': 'Der Stapel wurde nicht geändert: er enthält Entwürfe anderer Bibliotheken. Nur die Netzwerk-Administration kann ihn schließen oder archivieren.',
    'catalogacao.batchDeleteNothing': 'Der Stapel wurde nicht gelöscht: das ist Sache einer Koordination, deren Bibliotheken alle seine Entwürfe halten, oder der Netzwerk-Administration.',
  },
  el: {
    'catalogacao.exemplar.libraryNotYours': 'Δεν είσαι μέλος του προσωπικού της {library}: αυτό το αντίτυπο δεν μπορεί να καταχωριστεί εκεί και κρατά την τρέχουσα βιβλιοθήκη του (τη δική σου, για νέο αντίτυπο). Μόνο η {library}, ή η διαχείριση του δικτύου, μπορεί να το καταλογογραφήσει εκεί.',
    'catalogacao.queue.emptyTrashSomeKept': '{count} πρόχειρο(α) παραμένουν στον κάδο: η οριστική διαγραφή αφορά τον συντονισμό της βιβλιοθήκης τους.',
    'catalogacao.batchUpdateNothing': 'Η παρτίδα δεν άλλαξε: περιέχει πρόχειρα άλλων βιβλιοθηκών. Μόνο η διαχείριση του δικτύου μπορεί να την κλείσει ή να την αρχειοθετήσει.',
    'catalogacao.batchDeleteNothing': 'Η παρτίδα δεν διαγράφηκε: η διαγραφή της αφορά έναν συντονισμό του οποίου οι βιβλιοθήκες κατέχουν όλα τα πρόχειρά της, ή τη διαχείριση του δικτύου.',
  },
  eo: {
    'catalogacao.exemplar.libraryNotYours': 'Vi ne estas teamano de {library}: ĉi tiu ekzemplero ne povas esti tie registrita kaj konservas sian nunan bibliotekon (vian, por nova ekzemplero). Nur {library}, aŭ la reta administrado, povas katalogi ĝin tie.',
    'catalogacao.queue.emptyTrashSomeKept': '{count} malneto(j) restas en la rubujo: la definitiva forigo apartenas al la kunordigo de ilia biblioteko.',
    'catalogacao.batchUpdateNothing': 'La aro ne ŝanĝiĝis: ĝi enhavas malnetojn de aliaj bibliotekoj. Nur la reta administrado povas fermi aŭ arkivigi ĝin.',
    'catalogacao.batchDeleteNothing': 'La aro ne estis forigita: tio apartenas al kunordigo, kies bibliotekoj tenas ĉiujn ĝiajn malnetojn, aŭ al la reta administrado.',
  },
  it: {
    'catalogacao.exemplar.libraryNotYours': 'Non fai parte dello staff di {library}: questo esemplare non può essere collocato lì e mantiene la sua biblioteca attuale (la tua, per un nuovo esemplare). Solo {library}, o l’amministrazione della rete, può catalogarlo lì.',
    'catalogacao.queue.emptyTrashSomeKept': '{count} bozza/e restano nel cestino: l’eliminazione definitiva spetta al coordinamento della loro biblioteca.',
    'catalogacao.batchUpdateNothing': 'Il lotto non è cambiato: contiene bozze di altre biblioteche. Solo l’amministrazione della rete può chiuderlo o archiviarlo.',
    'catalogacao.batchDeleteNothing': 'Il lotto non è stato eliminato: eliminarlo spetta a un coordinamento le cui biblioteche detengono tutte le sue bozze, o all’amministrazione della rete.',
  },
  nl: {
    'catalogacao.exemplar.libraryNotYours': 'Je bent geen staff van {library}: dit exemplaar kan daar niet worden geplaatst en houdt zijn huidige bibliotheek (de jouwe, voor een nieuw exemplaar). Alleen {library}, of het netwerkbeheer, kan het daar catalogiseren.',
    'catalogacao.queue.emptyTrashSomeKept': '{count} concept(en) blijven in de prullenbak: definitief verwijderen is aan de coördinatie van hun bibliotheek.',
    'catalogacao.batchUpdateNothing': 'De reeks is niet gewijzigd: ze bevat concepten van andere bibliotheken. Alleen het netwerkbeheer kan ze sluiten of archiveren.',
    'catalogacao.batchDeleteNothing': 'De reeks is niet verwijderd: dat is aan een coördinatie waarvan de bibliotheken al haar concepten hebben, of aan het netwerkbeheer.',
  },
};
// Seconde vérification (27/09) : publier un lot qui porte les autorités d'une autre personne.
const OTHER_AUTHORS = {
  "fr": "Ce lot contient des brouillons d’autorité créés par d’autres personnes : tu ne peux pas publier tout le lot. Publie les tiens un par un, ou demande à l’administration du réseau.",
  "pt-BR": "Este lote contém rascunhos de autoridade criados por outras pessoas: você não pode publicar o lote inteiro. Publique os seus um a um, ou peça à administração da rede.",
  "es": "Este lote contiene borradores de autoridad creados por otras personas: no puedes publicar el lote entero. Publica los tuyos uno a uno, o pídeselo a la administración de la red.",
  "en": "This batch contains authority drafts created by other people: you cannot publish the whole batch. Publish yours one by one, or ask the network administration.",
  "ca": "Aquest lot conté esborranys d’autoritat creats per altres persones: no pots publicar tot el lot. Publica els teus un per un, o demana-ho a l’administració de la xarxa.",
  "de": "Dieser Stapel enthält Normdaten-Entwürfe anderer Personen: du kannst nicht den ganzen Stapel veröffentlichen. Veröffentliche deine einzeln oder frag die Netzwerk-Administration.",
  "el": "Αυτή η παρτίδα περιέχει πρόχειρα καθιερωμένων ονομάτων άλλων προσώπων: δεν μπορείς να δημοσιεύσεις όλη την παρτίδα. Δημοσίευσε τα δικά σου ένα-ένα ή ζήτα το από τη διαχείριση του δικτύου.",
  "eo": "Ĉi tiu aro enhavas aŭtoritatajn malnetojn de aliaj personoj: vi ne povas publikigi la tutan aron. Publikigu viajn unu post la alia, aŭ petu la retan administradon.",
  "it": "Questo lotto contiene bozze d’autorità create da altre persone: non puoi pubblicare l’intero lotto. Pubblica le tue una per una, o chiedi all’amministrazione della rete.",
  "nl": "Deze reeks bevat autoriteitsconcepten van andere personen: je kunt niet de hele reeks publiceren. Publiceer de jouwe een voor een, of vraag het netwerkbeheer."
};
for (const [loc, v] of Object.entries(OTHER_AUTHORS)) ADD_REVUE[loc]['error.batch.other_authors'] = v;
// Troisième vérification (27/09) : ce qui reste à la corbeille quand on supprime un lot, exemplaires sortis d'un lot réattribué.
const VAGUE3 = {
  "fr": {
    "catalogacao.batchTrashedLeft": "{count} brouillon(s) jeté(s) d’une autre bibliothèque ou d’une autre personne restent à leur corbeille, détachés du lot : leur suppression définitive ne te revient pas.",
    "catalogacao.batch.reassign.warn.itemsDetached": "{count} exemplaire(s) saisi(s) d’une autre bibliothèque, ou sans bibliothèque, sont sortis du lot : ils restent dans la file, hors lot."
  },
  "pt-BR": {
    "catalogacao.batchTrashedLeft": "{count} rascunho(s) descartado(s) de outra biblioteca ou de outra pessoa continuam na lixeira, fora do lote: a exclusão definitiva não cabe a você.",
    "catalogacao.batch.reassign.warn.itemsDetached": "{count} exemplar(es) cadastrado(s) de outra biblioteca, ou sem biblioteca, saíram do lote: continuam na fila, fora do lote."
  },
  "es": {
    "catalogacao.batchTrashedLeft": "{count} borrador(es) descartado(s) de otra biblioteca o de otra persona siguen en su papelera, fuera del lote: su eliminación definitiva no te corresponde.",
    "catalogacao.batch.reassign.warn.itemsDetached": "{count} ejemplar(es) registrado(s) de otra biblioteca, o sin biblioteca, salieron del lote: siguen en la cola, fuera del lote."
  },
  "en": {
    "catalogacao.batchTrashedLeft": "{count} discarded draft(s) from another library or another person remain in their trash, detached from the batch: permanently deleting them is not up to you.",
    "catalogacao.batch.reassign.warn.itemsDetached": "{count} manually entered copy draft(s) from another library, or with no library, left the batch: they stay in the queue, outside any batch."
  },
  "ca": {
    "catalogacao.batchTrashedLeft": "{count} esborrany(s) descartat(s) d’una altra biblioteca o d’una altra persona continuen a la seva paperera, fora del lot: la supressió definitiva no et correspon.",
    "catalogacao.batch.reassign.warn.itemsDetached": "{count} exemplar(s) introduït(s) d’una altra biblioteca, o sense biblioteca, han sortit del lot: continuen a la cua, fora del lot."
  },
  "de": {
    "catalogacao.batchTrashedLeft": "{count} verworfene(r) Entwurf/Entwürfe einer anderen Bibliothek oder Person bleiben in ihrem Papierkorb, vom Stapel gelöst: das endgültige Löschen ist nicht deine Sache.",
    "catalogacao.batch.reassign.warn.itemsDetached": "{count} erfasste(s) Exemplar(e) einer anderen Bibliothek oder ohne Bibliothek haben den Stapel verlassen: sie bleiben in der Warteschlange, außerhalb des Stapels."
  },
  "el": {
    "catalogacao.batchTrashedLeft": "{count} απορριφθέν(τα) πρόχειρο(α) άλλης βιβλιοθήκης ή άλλου προσώπου μένουν στον κάδο τους, εκτός παρτίδας: η οριστική διαγραφή δεν είναι δική σου υπόθεση.",
    "catalogacao.batch.reassign.warn.itemsDetached": "{count} καταχωρισμένο(α) αντίτυπο(α) άλλης βιβλιοθήκης, ή χωρίς βιβλιοθήκη, βγήκαν από την παρτίδα: μένουν στην ουρά, εκτός παρτίδας."
  },
  "eo": {
    "catalogacao.batchTrashedLeft": "{count} forĵetita(j) malneto(j) de alia biblioteko aŭ de alia persono restas en sia rubujo, apartigita(j) de la aro: la definitiva forigo ne apartenas al vi.",
    "catalogacao.batch.reassign.warn.itemsDetached": "{count} enigita(j) ekzemplero(j) de alia biblioteko, aŭ sen biblioteko, eliris el la aro: ili restas en la vico, ekster la aro."
  },
  "it": {
    "catalogacao.batchTrashedLeft": "{count} bozza/e scartata/e di un’altra biblioteca o di un’altra persona restano nel loro cestino, fuori dal lotto: l’eliminazione definitiva non spetta a te.",
    "catalogacao.batch.reassign.warn.itemsDetached": "{count} esemplare/i inserito/i di un’altra biblioteca, o senza biblioteca, sono usciti dal lotto: restano nella coda, fuori dal lotto."
  },
  "nl": {
    "catalogacao.batchTrashedLeft": "{count} weggegooid(e) concept(en) van een andere bibliotheek of persoon blijven in hun prullenbak, los van de reeks: definitief verwijderen is niet aan jou.",
    "catalogacao.batch.reassign.warn.itemsDetached": "{count} ingevoerd(e) exemplaar(en) van een andere bibliotheek, of zonder bibliotheek, hebben de reeks verlaten: ze blijven in de wachtrij, buiten de reeks."
  }
};
for (const [loc, o] of Object.entries(VAGUE3)) Object.assign(ADD_REVUE[loc], o);
for (const [loc, o] of Object.entries(ADD_REVUE)) Object.assign(ADD[loc], o);

let total = 0;
for (const loc of LOCALES) {
  const f = path.join(DIR, `${loc}.json`);
  const j = JSON.parse(fs.readFileSync(f, 'utf8'));
  const add = ADD[loc];
  if (!add || Object.keys(add).length !== Object.keys(ADD.fr).length) throw new Error(`${loc} : traductions incomplètes`);
  let n = 0;
  for (const [k, v] of Object.entries(add)) {
    if (!(k in j) || (REECRITES.includes(k) && j[k] !== v)) { j[k] = v; n++; }
  }
  fs.writeFileSync(f, JSON.stringify(j, null, 2) + '\n');
  total += n;
  console.log(`${loc}: +${n}`);
}
console.log(`total : ${total}`);
