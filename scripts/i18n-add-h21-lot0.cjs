/* ===========================================================================
 * i18n-add-h21-lot0.cjs — H21 lot 0 (REGISTRE IMP-26 h, IMP-27, 29/09/2026)
 * Neuf HINT levés par la migration h21_lot0_la_revision_suit_le_brouillon_importe
 * (convention (a) de localizeError : RAISE ... USING HINT = 'error.…'), et
 * quatre chaînes d'écran (Importations : promotedPartial, rejectedPartial,
 * reconciledPartial ; Catalogage › Lots : afterReview). 13 clés × 10 locales ;
 * et le chemin cité par error.publish.review_required, corrigé dans quatre
 * langues. Tutoiement partout ; pt-BR au « você ». Les libellés cités sont
 * ceux que l'écran affiche dans chaque langue (« Rapprocher » = « Criar
 * exemplar »…).
 * Idempotent : ce script est la SOURCE des clés du lot — une clé déjà posée
 * n'est réécrite que si sa valeur a changé ici (cinquième passe, 30/09/2026 :
 * rejectedPartial, reconciledPartial et rows_held_by_items réécrites).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'error.publish.imported_needs_batch': {
    fr: 'Ce brouillon vient d’un import : il se publie dans un lot, après une révision approuvée par l’administration du réseau. Range-le dans un lot de sa bibliothèque, puis demande la révision (Catalogage › Lots › Demander la révision).',
    'pt-BR': 'Este rascunho vem de uma importação: ele se publica dentro de um lote, após revisão aprovada pela administração da rede. Coloque-o num lote da biblioteca dele e depois peça a revisão (Catalogação › Lotes › Pedir revisão).',
    en: 'This draft comes from an import: it is published within a batch, after a review approved by the network administration. Put it in a batch of its library, then request the review (Cataloging › Batches › Request review).',
    es: 'Este borrador procede de una importación: se publica dentro de un lote, tras una revisión aprobada por la administración de la red. Colócalo en un lote de su biblioteca y luego solicita la revisión (Catalogación › Lotes › Solicitar revisión).',
    ca: 'Aquest esborrany prové d’una importació: es publica dins d’un lot, després d’una revisió aprovada per l’administració de la xarxa. Posa’l en un lot de la seva biblioteca i després sol·licita la revisió (Catalogació › Lots › Sol·licitar revisió).',
    it: 'Questa bozza proviene da un’importazione: si pubblica all’interno di un lotto, dopo una revisione approvata dall’amministrazione della rete. Mettila in un lotto della sua biblioteca, poi richiedi la revisione (Catalogazione › Lotti › Richiedere la revisione).',
    de: 'Dieser Entwurf stammt aus einem Import: Er wird in einem Stapel veröffentlicht, nach einer von der Netzwerkverwaltung genehmigten Prüfung. Lege ihn in einen Stapel seiner Bibliothek und frage dann die Prüfung an (Katalogisierung › Stapel › Prüfung anfragen).',
    nl: 'Dit concept komt uit een import: het wordt gepubliceerd binnen een lot, na een door het netwerkbeheer goedgekeurde beoordeling. Zet het in een lot van zijn bibliotheek en vraag daarna de beoordeling aan (Catalogisering › Lots › Beoordeling aanvragen).',
    eo: 'Ĉi tiu malneto venas el importo: ĝi publikiĝas en loto, post revizio aprobita de la administrado de la reto. Metu ĝin en loton de ĝia biblioteko, poste petu la revizion (Katalogado › Lotoj › Peti revizion).',
    el: 'Αυτό το πρόχειρο προέρχεται από εισαγωγή: δημοσιεύεται μέσα σε παρτίδα, μετά από αναθεώρηση εγκεκριμένη από τη διαχείριση του δικτύου. Τοποθέτησέ το σε μια παρτίδα της βιβλιοθήκης του και μετά ζήτησε την αναθεώρηση (Καταλογογράφηση › Παρτίδες › Αίτηση αναθεώρησης).',
  },
  'error.publish.added_after_review': {
    fr: 'Ce brouillon est entré dans le lot après la demande de révision : l’approbation ne le couvre pas. Redemande la révision du lot (Catalogage › Lots › Demander la révision), puis publie-le.',
    'pt-BR': 'Este rascunho entrou no lote depois do pedido de revisão: a aprovação não o cobre. Peça de novo a revisão do lote (Catalogação › Lotes › Pedir revisão) e depois publique-o.',
    en: 'This draft entered the batch after the review was requested: the approval does not cover it. Request the batch review again (Cataloging › Batches › Request review), then publish it.',
    es: 'Este borrador entró en el lote después de la solicitud de revisión: la aprobación no lo cubre. Vuelve a solicitar la revisión del lote (Catalogación › Lotes › Solicitar revisión) y luego publícalo.',
    ca: 'Aquest esborrany ha entrat al lot després de la sol·licitud de revisió: l’aprovació no el cobreix. Torna a sol·licitar la revisió del lot (Catalogació › Lots › Sol·licitar revisió) i després publica’l.',
    it: 'Questa bozza è entrata nel lotto dopo la richiesta di revisione: l’approvazione non la copre. Richiedi di nuovo la revisione del lotto (Catalogazione › Lotti › Richiedere la revisione), poi pubblicala.',
    de: 'Dieser Entwurf kam nach der Prüfungsanfrage in den Stapel: Die Genehmigung deckt ihn nicht ab. Frage die Prüfung des Stapels erneut an (Katalogisierung › Stapel › Prüfung anfragen) und veröffentliche ihn dann.',
    nl: 'Dit concept kwam in het lot na de beoordelingsaanvraag: de goedkeuring dekt het niet. Vraag de beoordeling van het lot opnieuw aan (Catalogisering › Lots › Beoordeling aanvragen) en publiceer het daarna.',
    eo: 'Ĉi tiu malneto eniris la loton post la peto de revizio: la aprobo ne kovras ĝin. Petu denove la revizion de la loto (Katalogado › Lotoj › Peti revizion), poste publikigu ĝin.',
    el: 'Αυτό το πρόχειρο μπήκε στην παρτίδα μετά την αίτηση αναθεώρησης: η έγκριση δεν το καλύπτει. Ζήτησε ξανά την αναθεώρηση της παρτίδας (Καταλογογράφηση › Παρτίδες › Αίτηση αναθεώρησης) και μετά δημοσίευσέ το.',
  },
  'error.import.run_has_linked_drafts': {
    fr: 'Des brouillons nés de cet import attendent encore hors de leur lot d’origine. Publie-les (après révision) ou mets-les à la corbeille, puis supprime l’import.',
    'pt-BR': 'Ainda há rascunhos criados por esta importação fora do lote de origem. Publique-os (após a revisão) ou mande-os para a lixeira e depois exclua a importação.',
    en: 'Drafts created by this import are still waiting outside their original batch. Publish them (after review) or move them to the trash, then delete the import.',
    es: 'Hay borradores creados por esta importación que aún esperan fuera de su lote de origen. Publícalos (tras la revisión) o envíalos a la papelera y luego elimina la importación.',
    ca: 'Hi ha esborranys creats per aquesta importació que encara esperen fora del seu lot d’origen. Publica’ls (després de la revisió) o envia’ls a la paperera i després elimina la importació.',
    it: 'Ci sono bozze create da questa importazione che attendono ancora fuori dal loro lotto d’origine. Pubblicale (dopo la revisione) o spostale nel cestino, poi elimina l’importazione.',
    de: 'Aus diesem Import entstandene Entwürfe warten noch außerhalb ihres ursprünglichen Loses. Veröffentliche sie (nach der Prüfung) oder verschiebe sie in den Papierkorb und lösche dann den Import.',
    nl: 'Concepten uit deze import wachten nog buiten hun oorspronkelijke partij. Publiceer ze (na beoordeling) of verplaats ze naar de prullenbak en verwijder daarna de import.',
    eo: 'Malnetoj naskitaj el ĉi tiu importo ankoraŭ atendas ekster sia originala aro. Publikigu ilin (post revizio) aŭ metu ilin en la rubujon, poste forigu la importon.',
    el: 'Πρόχειρα που δημιούργησε αυτή η εισαγωγή περιμένουν ακόμη έξω από την αρχική τους παρτίδα. Δημοσίευσέ τα (μετά την αναθεώρηση) ή μετακίνησέ τα στον κάδο και μετά διάγραψε την εισαγωγή.',
  },
  'error.import.rattacher_par_rapprocher': {
    fr: 'Pour rattacher une ligne à une notice déjà au catalogue, utilise Rapprocher : il ajoute aussi l’exemplaire.',
    'pt-BR': 'Para vincular uma linha a uma ficha que já está no catálogo, use Criar exemplar: ele também registra o exemplar.',
    en: 'To link a row to a record already in the catalogue, use Create copy: it also adds the copy.',
    es: 'Para vincular una fila a una ficha que ya está en el catálogo, usa Crear ejemplar: también añade el ejemplar.',
    ca: 'Per vincular una fila a una fitxa que ja és al catàleg, fes servir Crear exemplar: també hi afegeix l’exemplar.',
    it: 'Per collegare una riga a una scheda già presente a catalogo, usa Crea esemplare: aggiunge anche l’esemplare.',
    de: 'Um eine Zeile mit einem bereits vorhandenen Katalogeintrag zu verknüpfen, nutze Exemplar anlegen: Das legt auch das Exemplar an.',
    nl: 'Om een regel te koppelen aan een record dat al in de catalogus staat, gebruik je Exemplaar aanmaken: dat voegt ook het exemplaar toe.',
    eo: 'Por ligi linion al slipo jam en la katalogo, uzu Krei ekzempleron: ĝi ankaŭ aldonas la ekzempleron.',
    el: 'Για να συνδέσεις μια γραμμή με εγγραφή που υπάρχει ήδη στον κατάλογο, χρησιμοποίησε Δημιουργία αντιτύπου: προσθέτει και το αντίτυπο.',
  },
  'error.catalog.restore_line_repromoted': {
    fr: 'Ce brouillon ne peut pas revenir : sa ligne d’import a déjà donné un autre brouillon depuis. Travaille sur celui-là.',
    'pt-BR': 'Este rascunho não pode voltar: a linha da importação dele já gerou outro rascunho desde então. Trabalhe nesse outro.',
    en: 'This draft cannot come back: its import row has since produced another draft. Work on that one.',
    es: 'Este borrador no puede volver: su fila de importación ya ha dado otro borrador desde entonces. Trabaja en ese.',
    ca: 'Aquest esborrany no pot tornar: la seva fila d’importació ja ha donat un altre esborrany des de llavors. Treballa en aquell.',
    it: 'Questa bozza non può tornare: la sua riga d’importazione ha già prodotto un’altra bozza nel frattempo. Lavora su quella.',
    de: 'Dieser Entwurf kann nicht zurückkehren: Seine Importzeile hat inzwischen einen anderen Entwurf ergeben. Arbeite an jenem weiter.',
    nl: 'Dit concept kan niet terugkomen: de importregel ervan heeft intussen een ander concept opgeleverd. Werk verder aan dat concept.',
    eo: 'Ĉi tiu malneto ne povas reveni: ĝia importa linio intertempe donis alian malneton. Laboru pri tiu.',
    el: 'Αυτό το πρόχειρο δεν μπορεί να επιστρέψει: η γραμμή εισαγωγής του έδωσε στο μεταξύ άλλο πρόχειρο. Δούλεψε σε εκείνο.',
  },
  'error.import.run_has_trashed_items': {
    fr: 'Des exemplaires rapprochés depuis cet import sont à la corbeille : vide la corbeille, ou restaure-les et publie-les après révision, puis supprime l’import.',
    'pt-BR': 'Há exemplares vinculados por esta importação na lixeira: esvazie a lixeira, ou restaure-os e publique-os após a revisão, e depois exclua a importação.',
    en: 'Copies matched from this import are in the trash: empty the trash, or restore them and publish them after review, then delete the import.',
    es: 'Hay ejemplares vinculados desde esta importación en la papelera: vacía la papelera, o restáuralos y publícalos tras la revisión, y luego elimina la importación.',
    ca: 'Hi ha exemplars vinculats des d’aquesta importació a la paperera: buida la paperera, o restaura’ls i publica’ls després de la revisió, i després elimina la importació.',
    it: 'Ci sono esemplari collegati da questa importazione nel cestino: svuota il cestino, oppure ripristinali e pubblicali dopo la revisione, poi elimina l’importazione.',
    de: 'Aus diesem Import zugeordnete Exemplare liegen im Papierkorb: Leere den Papierkorb, oder stelle sie wieder her und veröffentliche sie nach der Prüfung, und lösche dann den Import.',
    nl: 'Uit deze import gekoppelde exemplaren staan in de prullenbak: leeg de prullenbak, of zet ze terug en publiceer ze na beoordeling, en verwijder daarna de import.',
    eo: 'Ekzempleroj ligitaj el ĉi tiu importo estas en la rubujo: malplenigu la rubujon, aŭ restarigu ilin kaj publikigu ilin post revizio, poste forigu la importon.',
    el: 'Αντίτυπα που συνδέθηκαν από αυτή την εισαγωγή βρίσκονται στον κάδο: άδειασε τον κάδο ή επανάφερέ τα και δημοσίευσέ τα μετά την αναθεώρηση, και μετά διάγραψε την εισαγωγή.',
  },
  // Cinquième passe (30/09/2026) : le refus ne conseille plus « publie-les,
  // ou vide la corbeille, puis recommence » — « Retraiter » est désormais
  // refusé d'emblée (error.import.reparse_after_promotion) ; il dit ce qui
  // retient les lignes.
  'error.import.rows_held_by_items': {
    fr: 'Des exemplaires rapprochés depuis ce fichier ne sont pas encore publiés (corbeille comprise) : leurs lignes d’import ne peuvent pas être effacées.',
    'pt-BR': 'Há exemplares vinculados a partir deste arquivo que ainda não foram publicados (inclusive na lixeira): as linhas de importação deles não podem ser apagadas.',
    en: 'Copies matched from this file are not published yet (trash included): their import rows cannot be deleted.',
    es: 'Hay ejemplares vinculados desde este archivo que aún no se han publicado (papelera incluida): sus filas de importación no se pueden borrar.',
    ca: 'Hi ha exemplars vinculats des d’aquest fitxer que encara no s’han publicat (paperera inclosa): les seves files d’importació no es poden esborrar.',
    it: 'Ci sono esemplari collegati da questo file non ancora pubblicati (cestino compreso): le loro righe d’importazione non possono essere cancellate.',
    de: 'Aus dieser Datei zugeordnete Exemplare sind noch nicht veröffentlicht (Papierkorb eingeschlossen): Die zugehörigen Importzeilen können nicht gelöscht werden.',
    nl: 'Uit dit bestand gekoppelde exemplaren zijn nog niet gepubliceerd (prullenbak inbegrepen): hun importregels kunnen niet worden gewist.',
    eo: 'Ekzempleroj ligitaj el ĉi tiu dosiero ankoraŭ ne estas publikigitaj (inkluzive de la rubujo): iliaj importaj linioj ne povas esti forigitaj.',
    el: 'Αντίτυπα που συνδέθηκαν από αυτό το αρχείο δεν έχουν δημοσιευθεί ακόμη (μαζί με τον κάδο): οι γραμμές εισαγωγής τους δεν μπορούν να διαγραφούν.',
  },
  // Cinquième passe : plus de « les autres sont rapprochées » — l'écran fait
  // suivre ce message des comptes (importacoes.fila.reconciledCounts : créés,
  // codes déjà pris, lignes détenues), et une ligne sortie du run est ignorée
  // elle aussi.
  'importacoes.fila.reconciledPartial': {
    fr: '{skipped} ligne(s) sur {asked} ignorée(s) : déjà traitées, rejetées, écartées ou retirées ailleurs entre-temps. La liste est rechargée.',
    'pt-BR': '{skipped} linha(s) de {asked} ignorada(s): já tratadas, rejeitadas, descartadas ou removidas em outro lugar nesse meio-tempo. A lista foi recarregada.',
    en: '{skipped} of {asked} row(s) skipped: already handled, rejected, discarded or removed elsewhere in the meantime. The list has been reloaded.',
    es: '{skipped} fila(s) de {asked} ignorada(s): ya tratadas, rechazadas, descartadas o retiradas en otro lugar mientras tanto. La lista se ha recargado.',
    ca: '{skipped} fila(es) de {asked} ignorada(es): ja tractades, rebutjades, descartades o retirades en un altre lloc mentrestant. La llista s’ha recarregat.',
    it: '{skipped} riga/e su {asked} ignorata/e: già trattate, rifiutate, scartate o rimosse altrove nel frattempo. L’elenco è stato ricaricato.',
    de: '{skipped} von {asked} Zeile(n) übergangen: inzwischen anderswo bearbeitet, abgelehnt, verworfen oder entfernt. Die Liste wurde neu geladen.',
    nl: '{skipped} van {asked} regel(s) overgeslagen: intussen elders behandeld, afgewezen, verworpen of verwijderd. De lijst is opnieuw geladen.',
    eo: '{skipped} el {asked} linio(j) preterlasita(j): jam traktitaj, malakceptitaj, forĵetitaj aŭ forigitaj aliloke intertempe. La listo estas reŝargita.',
    el: 'Παραλείφθηκαν {skipped} από {asked} γραμμές: τις χειρίστηκαν, τις απέρριψαν, τις απέσυραν ή τις αφαίρεσαν αλλού στο μεταξύ. Η λίστα ξαναφορτώθηκε.',
  },
  'error.catalog.restore_item_import_gone': {
    fr: 'Cet exemplaire venait d’un import supprimé depuis : il ne peut pas revenir. Crée-le de nouveau à la main si besoin.',
    'pt-BR': 'Este exemplar vinha de uma importação que foi excluída depois: ele não pode voltar. Crie-o de novo à mão, se precisar.',
    en: 'This copy came from an import that has since been deleted: it cannot come back. Create it again by hand if needed.',
    es: 'Este ejemplar venía de una importación eliminada desde entonces: no puede volver. Créalo de nuevo a mano si hace falta.',
    ca: 'Aquest exemplar venia d’una importació eliminada des de llavors: no pot tornar. Torna’l a crear a mà si cal.',
    it: 'Questo esemplare veniva da un’importazione eliminata nel frattempo: non può tornare. Ricrealo a mano se serve.',
    de: 'Dieses Exemplar stammte aus einem inzwischen gelöschten Import: Es kann nicht zurückkehren. Lege es bei Bedarf von Hand neu an.',
    nl: 'Dit exemplaar kwam uit een import die intussen is verwijderd: het kan niet terugkomen. Maak het zo nodig opnieuw met de hand aan.',
    eo: 'Ĉi tiu ekzemplero venis el importo intertempe forigita: ĝi ne povas reveni. Kreu ĝin denove permane, se necese.',
    el: 'Αυτό το αντίτυπο προερχόταν από εισαγωγή που διαγράφηκε στο μεταξύ: δεν μπορεί να επιστρέψει. Δημιούργησέ το ξανά με το χέρι αν χρειάζεται.',
  },
  'error.publish.status_reserved': {
    fr: 'Seule la publication met un brouillon à l’état « publié ».',
    'pt-BR': 'Só a publicação coloca um rascunho no estado «publicado».',
    en: 'Only publishing sets a draft to “published”.',
    es: 'Solo la publicación pone un borrador en estado «publicado».',
    ca: 'Només la publicació posa un esborrany en estat «publicat».',
    it: 'Solo la pubblicazione porta una bozza allo stato «pubblicata».',
    de: 'Nur das Veröffentlichen setzt einen Entwurf auf „veröffentlicht“.',
    nl: 'Alleen publiceren zet een concept op ‘gepubliceerd’.',
    eo: 'Nur la publikigo metas malneton en la staton «publikigita».',
    el: 'Μόνο η δημοσίευση θέτει ένα πρόχειρο σε κατάσταση «δημοσιευμένο».',
  },
  // Sixième passe : une ligne sortie du run (« Retraiter » ailleurs) est
  // ignorée elle aussi.
  'importacoes.fila.promotedPartial': {
    fr: '{created} brouillon(s) créé(s) pour {asked} ligne(s) choisie(s) : les autres ne pouvaient plus en devenir (déjà traitées, décidées ou retirées ailleurs entre-temps). La liste est rechargée.',
    'pt-BR': '{created} rascunho(s) criado(s) para {asked} linha(s) escolhida(s): as demais já não podiam virar rascunho (já tratadas, decididas ou removidas em outro lugar nesse meio-tempo). A lista foi recarregada.',
    en: '{created} draft(s) created for {asked} selected row(s): the others could no longer become drafts (already handled, decided or removed elsewhere in the meantime). The list has been reloaded.',
    es: '{created} borrador(es) creado(s) para {asked} fila(s) elegida(s): las demás ya no podían convertirse en borradores (ya tratadas, decididas o retiradas en otro lugar mientras tanto). La lista se ha recargado.',
    ca: '{created} esborrany(s) creat(s) per a {asked} fila(es) triada(es): les altres ja no podien esdevenir esborranys (ja tractades, decidides o retirades en un altre lloc mentrestant). La llista s’ha recarregat.',
    it: '{created} bozza/e creata/e per {asked} riga/e scelta/e: le altre non potevano più diventare bozze (già trattate, decise o rimosse altrove nel frattempo). L’elenco è stato ricaricato.',
    de: '{created} Entwurf/Entwürfe für {asked} gewählte Zeile(n) erstellt: Die übrigen konnten keine Entwürfe mehr werden (inzwischen anderswo bearbeitet, entschieden oder entfernt). Die Liste wurde neu geladen.',
    nl: '{created} concept(en) aangemaakt voor {asked} gekozen regel(s): de andere konden geen concept meer worden (intussen elders behandeld, beslist of verwijderd). De lijst is opnieuw geladen.',
    eo: '{created} malneto(j) kreita(j) por {asked} elektita(j) linio(j): la aliaj ne plu povis fariĝi malnetoj (jam traktitaj, deciditaj aŭ forigitaj aliloke intertempe). La listo estas reŝargita.',
    el: 'Δημιουργήθηκαν {created} πρόχειρα για {asked} επιλεγμένες γραμμές: οι υπόλοιπες δεν μπορούσαν πια να γίνουν πρόχειρα (τις χειρίστηκαν, αποφασίστηκαν ή αφαιρέθηκαν αλλού στο μεταξύ). Η λίστα ξαναφορτώθηκε.',
  },
  // Cinquième passe : une ligne n'est pas ignorée seulement parce qu'elle a déjà
  // un brouillon — déjà rejetée, écartée, ou sortie du run, elle l'est aussi.
  'importacoes.fila.rejectedPartial': {
    fr: '{rejected} ligne(s) rejetée(s) sur {asked} : les autres étaient déjà traitées, rejetées ou retirées ailleurs entre-temps. La liste est rechargée.',
    'pt-BR': '{rejected} linha(s) rejeitada(s) de {asked}: as demais já tinham sido tratadas, rejeitadas ou removidas em outro lugar nesse meio-tempo. A lista foi recarregada.',
    en: '{rejected} of {asked} row(s) rejected: the others had already been handled, rejected or removed elsewhere in the meantime. The list has been reloaded.',
    es: '{rejected} fila(s) rechazada(s) de {asked}: las demás ya habían sido tratadas, rechazadas o retiradas en otro lugar mientras tanto. La lista se ha recargado.',
    ca: '{rejected} fila(es) rebutjada(es) de {asked}: les altres ja havien estat tractades, rebutjades o retirades en un altre lloc mentrestant. La llista s’ha recarregat.',
    it: '{rejected} riga/e rifiutata/e su {asked}: le altre erano già state trattate, rifiutate o rimosse altrove nel frattempo. L’elenco è stato ricaricato.',
    de: '{rejected} von {asked} Zeile(n) abgelehnt: Die übrigen waren inzwischen schon anderswo bearbeitet, abgelehnt oder entfernt worden. Die Liste wurde neu geladen.',
    nl: '{rejected} van {asked} regel(s) afgewezen: de andere waren intussen al elders behandeld, afgewezen of verwijderd. De lijst is opnieuw geladen.',
    eo: '{rejected} el {asked} linio(j) malakceptita(j): la aliaj jam estis traktitaj, malakceptitaj aŭ forigitaj aliloke intertempe. La listo estas reŝargita.',
    el: 'Απορρίφθηκαν {rejected} από {asked} γραμμές: τις υπόλοιπες τις είχαν ήδη χειριστεί, απορρίψει ή αφαιρέσει αλλού στο μεταξύ. Η λίστα ξαναφορτώθηκε.',
  },
  'catalogacao.batch.review.afterReview': {
    fr: '{n} brouillon(s) entré(s) après la demande : redemande la révision avant de les publier.',
    'pt-BR': '{n} rascunho(s) adicionado(s) depois do pedido: peça de novo a revisão antes de publicá-los.',
    en: '{n} draft(s) added after the request: request the review again before publishing them.',
    es: '{n} borrador(es) añadido(s) después de la solicitud: vuelve a solicitar la revisión antes de publicarlos.',
    ca: '{n} esborrany(s) afegit(s) després de la sol·licitud: torna a sol·licitar la revisió abans de publicar-los.',
    it: '{n} bozza/e aggiunta/e dopo la richiesta: richiedi di nuovo la revisione prima di pubblicarle.',
    de: '{n} Entwurf/Entwürfe nach der Anfrage hinzugekommen: Frage die Prüfung erneut an, bevor du sie veröffentlichst.',
    nl: '{n} concept(en) toegevoegd na de aanvraag: vraag de beoordeling opnieuw aan voordat je ze publiceert.',
    eo: '{n} malneto(j) aldonita(j) post la peto: petu denove la revizion antaŭ ol publikigi ilin.',
    el: '{n} πρόχειρα προστέθηκαν μετά την αίτηση: ζήτησε ξανά την αναθεώρηση πριν τα δημοσιεύσεις.',
  },
};

// Revue du lot (29/09) : le message d'une clé plus ancienne cite le même chemin
// que les messages du lot, et le citait faux dans quatre langues (l'onglet
// s'appelle « Stapel », « Lots », « Lotoj » ; en anglais, « Cataloging »). On
// ne corrige que ce segment.
const CHEMINS = {
  'error.publish.review_required': {
    de: ['(Katalogisierung › Lose › Prüfung anfragen)', '(Katalogisierung › Stapel › Prüfung anfragen)'],
    nl: ['(Catalogisering › Partijen › Beoordeling aanvragen)', '(Catalogisering › Lots › Beoordeling aanvragen)'],
    eo: ['(Katalogado › Aroj › Peti revizion)', '(Katalogado › Lotoj › Peti revizion)'],
    en: ['(Cataloguing › Batches › Request review)', '(Cataloging › Batches › Request review)'],
  },
};

const ligneDe = (cle) => new RegExp('^  ' + JSON.stringify(cle).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ': (".*?")(,?)$', 'm');

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let ajoutees = 0;
  let corrigees = 0;
  for (const [cle, valeurs] of Object.entries(CLES)) {
    const val = valeurs[loc];
    if (!val) throw new Error(`Valeur manquante : ${cle} / ${loc}`);
    const m = content.match(ligneDe(cle));
    if (m) {
      // Clé du lot déjà posée : ce script en est la source, on la réécrit si elle a changé.
      if (JSON.parse(m[1]) !== val) {
        content = content.replace(m[0], '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val) + m[2]);
        corrigees++;
      }
      continue;
    }
    const entry = '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    ajoutees++;
  }
  for (const [cle, parLocale] of Object.entries(CHEMINS)) {
    const paire = parLocale[loc];
    if (!paire) continue;
    const m = content.match(ligneDe(cle));
    if (!m) throw new Error(`Clé absente : ${cle} / ${loc}`);
    const ancien = JSON.parse(m[1]);
    if (ancien.includes(paire[1])) continue;
    if (!ancien.includes(paire[0])) throw new Error(`Chemin attendu absent : ${cle} / ${loc}`);
    content = content.replace(m[0], '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(ancien.replace(paire[0], paire[1])) + m[2]);
    corrigees++;
  }
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(`${loc} : ${ajoutees} clé(s) ajoutée(s), ${corrigees} corrigée(s), JSON valide.`);
}
