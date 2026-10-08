/* ===========================================================================
 * i18n-add-h21-lot6b.cjs — H21 lot 6b (REGISTRE IMP-33 c, 08/10/2026) :
 * la cote et la note d'un exemplaire, comme les notices.
 * Importations : sur une ligne « Déjà importée », les exemplaires à mettre à
 * jour ; le détail champ par champ des exemplaires déjà là (cote, note :
 * base / AnarBib / fichier / verdict) ; le message de « Préparer la mise à
 * jour » compte les exemplaires préparés et ignorés, par raison. Rapport de
 * révision : les mises à jour d'exemplaires préparées (champs appliqués,
 * montrés). Refus traduits de la publication d'une mise à jour d'exemplaire
 * (error.publish.item_update_*), de la trace réservée
 * (error.import.item_update_trace_reserved) et de la fusion
 * (error.import.item_update_not_mergeable).
 * Revue sceptique du 08/10 : l’état « masqué » d’un exemplaire hors de vue,
 * un brouillon vivant ailleurs, la republication refusée sur un exemplaire
 * changé, « Éditer » refusé pendant une mise à jour, la mise à jour supplantée.
 * Tutoiement partout ; pt-BR au « você ». Vocabulaire repris des clés voisines
 * (importacoes.fila.prepare*, importacoes.items.*, review.report.prepared.*,
 * error.publish.update_*).
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  // ── Importations : le message de « Préparer la mise à jour » ──
  'importacoes.fila.preparedItems': {
    fr: '{n, plural, one {# exemplaire à mettre à jour (cote, note) préparé} other {# exemplaires à mettre à jour (cote, note) préparés}} dans le lot n° {batch} : relis-les, puis demande la révision du lot.',
    'pt-BR': '{n, plural, one {# exemplar a atualizar (localização, nota) preparado} other {# exemplares a atualizar (localização, nota) preparados}} no lote nº {batch}: revise-os e depois peça a revisão do lote.',
    en: '{n, plural, one {# copy update (shelf mark, note) prepared} other {# copy updates (shelf mark, note) prepared}} in batch no. {batch}: check them, then request the batch review.',
    es: '{n, plural, one {# ejemplar por actualizar (signatura, nota) preparado} other {# ejemplares por actualizar (signatura, nota) preparados}} en el lote n.º {batch}: revísalos y luego pide la revisión del lote.',
    ca: '{n, plural, one {# exemplar per actualitzar (signatura, nota) preparat} other {# exemplars per actualitzar (signatura, nota) preparats}} al lot núm. {batch}: revisa’ls i després demana la revisió del lot.',
    it: '{n, plural, one {# esemplare da aggiornare (collocazione, nota) preparato} other {# esemplari da aggiornare (collocazione, nota) preparati}} nel lotto n. {batch}: rileggili, poi chiedi la revisione del lotto.',
    de: '{n, plural, one {# Exemplar-Aktualisierung (Signatur, Notiz) vorbereitet} other {# Exemplar-Aktualisierungen (Signatur, Notiz) vorbereitet}} im Stapel Nr. {batch}: prüfe sie und beantrage dann die Prüfung des Stapels.',
    nl: '{n, plural, one {# exemplaar om bij te werken (signatuur, notitie) voorbereid} other {# exemplaren om bij te werken (signatuur, notitie) voorbereid}} in partij nr. {batch}: lees ze na en vraag dan de controle van de partij aan.',
    eo: '{n, plural, one {# ĝisdatigo de ekzemplero (signaturo, noto) preparita} other {# ĝisdatigoj de ekzempleroj (signaturo, noto) preparitaj}} en la aro n-ro {batch}: relegu ilin, poste petu la revizion de la aro.',
    el: '{n, plural, one {# ενημέρωση αντιτύπου (ταξιθετικός αριθμός, σημείωση) προετοιμάστηκε} other {# ενημερώσεις αντιτύπων (ταξιθετικός αριθμός, σημείωση) προετοιμάστηκαν}} στην παρτίδα αρ. {batch}: έλεγξέ τις και μετά ζήτησε τον έλεγχο της παρτίδας.',
  },
  'importacoes.fila.prepareItemsSkipped': {
    fr: 'Exemplaires ignorés : {list}.', 'pt-BR': 'Exemplares ignorados: {list}.', en: 'Copies skipped: {list}.',
    es: 'Ejemplares ignorados: {list}.', ca: 'Exemplars ignorats: {list}.', it: 'Esemplari ignorati: {list}.',
    de: 'Übergangene Exemplare: {list}.', nl: 'Overgeslagen exemplaren: {list}.', eo: 'Preterlasitaj ekzempleroj: {list}.',
    el: 'Αντίτυπα που παραλείφθηκαν: {list}.',
  },
  'importacoes.fila.prepareItemSkip.signale': {
    fr: '{n, plural, one {# signalé (déplacé, réétiqueté, code repris ou sans code-barres : jamais mis à jour d’office)} other {# signalés (déplacés, réétiquetés, codes repris ou sans code-barres : jamais mis à jour d’office)}}',
    'pt-BR': '{n, plural, one {# sinalizado (movido, reetiquetado, código retomado ou sem código de barras: nunca atualizado de ofício)} other {# sinalizados (movidos, reetiquetados, códigos retomados ou sem código de barras: nunca atualizados de ofício)}}',
    en: '{n, plural, one {# flagged (moved, relabelled, barcode reused or no barcode: never updated automatically)} other {# flagged (moved, relabelled, barcode reused or no barcode: never updated automatically)}}',
    es: '{n, plural, one {# señalado (movido, reetiquetado, código reutilizado o sin código de barras: nunca actualizado de oficio)} other {# señalados (movidos, reetiquetados, códigos reutilizados o sin código de barras: nunca actualizados de oficio)}}',
    ca: '{n, plural, one {# assenyalat (mogut, reetiquetat, codi reutilitzat o sense codi de barres: mai actualitzat d’ofici)} other {# assenyalats (moguts, reetiquetats, codis reutilitzats o sense codi de barres: mai actualitzats d’ofici)}}',
    it: '{n, plural, one {# segnalato (spostato, rietichettato, codice ripreso o senza codice a barre: mai aggiornato d’ufficio)} other {# segnalati (spostati, rietichettati, codici ripresi o senza codice a barre: mai aggiornati d’ufficio)}}',
    de: '{n, plural, one {# gemeldet (verschoben, umetikettiert, Barcode wiederverwendet oder ohne Barcode: nie automatisch aktualisiert)} other {# gemeldet (verschoben, umetikettiert, Barcode wiederverwendet oder ohne Barcode: nie automatisch aktualisiert)}}',
    nl: '{n, plural, one {# gemeld (verplaatst, opnieuw gelabeld, code hergebruikt of zonder streepjescode: nooit vanzelf bijgewerkt)} other {# gemeld (verplaatst, opnieuw gelabeld, code hergebruikt of zonder streepjescode: nooit vanzelf bijgewerkt)}}',
    eo: '{n, plural, one {# signalita (movita, reetikedita, reprenita kodo aŭ sen strekkodo: neniam aŭtomate ĝisdatigita)} other {# signalitaj (movitaj, reetikeditaj, reprenitaj kodoj aŭ sen strekkodo: neniam aŭtomate ĝisdatigitaj)}}',
    el: '{n, plural, one {# επισημάνθηκε (μετακινημένο, με νέα ετικέτα, κώδικας που ξαναχρησιμοποιήθηκε ή χωρίς γραμμωτό κώδικα: ποτέ αυτόματη ενημέρωση)} other {# επισημάνθηκαν (μετακινημένα, με νέα ετικέτα, κώδικες που ξαναχρησιμοποιήθηκαν ή χωρίς γραμμωτό κώδικα: ποτέ αυτόματη ενημέρωση)}}',
  },
  'importacoes.fila.prepareItemSkip.pas_au_catalogue': {
    fr: '{n, plural, one {# pas encore au catalogue (nouveau ou déjà en brouillon : « Rapprocher »)} other {# pas encore au catalogue (nouveaux ou déjà en brouillon : « Rapprocher »)}}',
    'pt-BR': '{n, plural, one {# ainda fora do catálogo (novo ou já em rascunho: «Aproximar»)} other {# ainda fora do catálogo (novos ou já em rascunho: «Aproximar»)}}',
    en: '{n, plural, one {# not in the catalogue yet (new or already drafted: “Reconcile”)} other {# not in the catalogue yet (new or already drafted: “Reconcile”)}}',
    es: '{n, plural, one {# aún fuera del catálogo (nuevo o ya en borrador: «Aproximar»)} other {# aún fuera del catálogo (nuevos o ya en borrador: «Aproximar»)}}',
    ca: '{n, plural, one {# encara fora del catàleg (nou o ja en esborrany: «Aproximar»)} other {# encara fora del catàleg (nous o ja en esborrany: «Aproximar»)}}',
    it: '{n, plural, one {# non ancora in catalogo (nuovo o già in bozza: «Riconcilia»)} other {# non ancora in catalogo (nuovi o già in bozza: «Riconcilia»)}}',
    de: '{n, plural, one {# noch nicht im Katalog (neu oder schon als Entwurf: „Abgleichen“)} other {# noch nicht im Katalog (neu oder schon als Entwurf: „Abgleichen“)}}',
    nl: '{n, plural, one {# nog niet in de catalogus (nieuw of al als concept: „Koppelen”)} other {# nog niet in de catalogus (nieuw of al als concept: „Koppelen”)}}',
    eo: '{n, plural, one {# ankoraŭ ne en la katalogo (nova aŭ jam malneta: «Proksimigi»)} other {# ankoraŭ ne en la katalogo (novaj aŭ jam malnetaj: «Proksimigi»)}}',
    el: '{n, plural, one {# δεν είναι ακόμη στον κατάλογο (νέο ή ήδη πρόχειρο: «Αντιστοίχιση»)} other {# δεν είναι ακόμη στον κατάλογο (νέα ή ήδη πρόχειρα: «Αντιστοίχιση»)}}',
  },
  'importacoes.fila.prepareItemSkip.rejetee': {
    fr: '{n, plural, one {# d’une ligne rejetée ou écartée} other {# de lignes rejetées ou écartées}}',
    'pt-BR': '{n, plural, one {# de uma linha rejeitada ou descartada} other {# de linhas rejeitadas ou descartadas}}',
    en: '{n, plural, one {# from a rejected or discarded row} other {# from rejected or discarded rows}}',
    es: '{n, plural, one {# de una línea rechazada o descartada} other {# de líneas rechazadas o descartadas}}',
    ca: '{n, plural, one {# d’una línia rebutjada o descartada} other {# de línies rebutjades o descartades}}',
    it: '{n, plural, one {# di una riga rifiutata o scartata} other {# di righe rifiutate o scartate}}',
    de: '{n, plural, one {# aus einer abgelehnten oder verworfenen Zeile} other {# aus abgelehnten oder verworfenen Zeilen}}',
    nl: '{n, plural, one {# uit een afgewezen of afgevoerde regel} other {# uit afgewezen of afgevoerde regels}}',
    eo: '{n, plural, one {# el rifuzita aŭ forlasita linio} other {# el rifuzitaj aŭ forlasitaj linioj}}',
    el: '{n, plural, one {# από απορριφθείσα ή παραμερισμένη γραμμή} other {# από απορριφθείσες ή παραμερισμένες γραμμές}}',
  },
  'importacoes.fila.prepareItemSkip.autre_bibliotheque': {
    fr: '{n, plural, one {# d’une autre bibliothèque (jamais touché)} other {# d’une autre bibliothèque (jamais touchés)}}',
    'pt-BR': '{n, plural, one {# de outra biblioteca (nunca tocado)} other {# de outra biblioteca (nunca tocados)}}',
    en: '{n, plural, one {# from another library (never touched)} other {# from another library (never touched)}}',
    es: '{n, plural, one {# de otra biblioteca (nunca tocado)} other {# de otra biblioteca (nunca tocados)}}',
    ca: '{n, plural, one {# d’una altra biblioteca (mai tocat)} other {# d’una altra biblioteca (mai tocats)}}',
    it: '{n, plural, one {# di un’altra biblioteca (mai toccato)} other {# di un’altra biblioteca (mai toccati)}}',
    de: '{n, plural, one {# einer anderen Bibliothek (nie angetastet)} other {# einer anderen Bibliothek (nie angetastet)}}',
    nl: '{n, plural, one {# van een andere bibliotheek (nooit aangeraakt)} other {# van een andere bibliotheek (nooit aangeraakt)}}',
    eo: '{n, plural, one {# de alia biblioteko (neniam tuŝita)} other {# de alia biblioteko (neniam tuŝitaj)}}',
    el: '{n, plural, one {# άλλης βιβλιοθήκης (δεν αγγίζεται ποτέ)} other {# άλλης βιβλιοθήκης (δεν αγγίζονται ποτέ)}}',
  },
  'importacoes.fila.prepareItemSkip.deja_preparee': {
    fr: '{n, plural, one {# déjà préparé} other {# déjà préparés}}',
    'pt-BR': '{n, plural, one {# já preparado} other {# já preparados}}',
    en: '{n, plural, one {# already prepared} other {# already prepared}}',
    es: '{n, plural, one {# ya preparado} other {# ya preparados}}',
    ca: '{n, plural, one {# ja preparat} other {# ja preparats}}',
    it: '{n, plural, one {# già preparato} other {# già preparati}}',
    de: '{n, plural, one {# schon vorbereitet} other {# schon vorbereitet}}',
    nl: '{n, plural, one {# al voorbereid} other {# al voorbereid}}',
    eo: '{n, plural, one {# jam preparita} other {# jam preparitaj}}',
    el: '{n, plural, one {# έχει ήδη προετοιμαστεί} other {# έχουν ήδη προετοιμαστεί}}',
  },
  'importacoes.fila.prepareItemSkip.brouillon_en_cours': {
    fr: '{n, plural, one {# avec un autre brouillon en cours (« Éditer »)} other {# avec un autre brouillon en cours (« Éditer »)}}',
    'pt-BR': '{n, plural, one {# com outro rascunho em andamento («Editar»)} other {# com outro rascunho em andamento («Editar»)}}',
    en: '{n, plural, one {# with another draft in progress (“Edit”)} other {# with another draft in progress (“Edit”)}}',
    es: '{n, plural, one {# con otro borrador en curso («Editar»)} other {# con otro borrador en curso («Editar»)}}',
    ca: '{n, plural, one {# amb un altre esborrany en curs («Editar»)} other {# amb un altre esborrany en curs («Editar»)}}',
    it: '{n, plural, one {# con un’altra bozza in corso («Modifica»)} other {# con un’altra bozza in corso («Modifica»)}}',
    de: '{n, plural, one {# mit einem anderen laufenden Entwurf („Bearbeiten“)} other {# mit einem anderen laufenden Entwurf („Bearbeiten“)}}',
    nl: '{n, plural, one {# met een ander lopend concept („Bewerken”)} other {# met een ander lopend concept („Bewerken”)}}',
    eo: '{n, plural, one {# kun alia malneto en laboro («Redakti»)} other {# kun alia malneto en laboro («Redakti»)}}',
    el: '{n, plural, one {# με άλλο πρόχειρο σε εξέλιξη («Επεξεργασία»)} other {# με άλλο πρόχειρο σε εξέλιξη («Επεξεργασία»)}}',
  },
  'importacoes.fila.prepareItemSkip.sans_base': {
    fr: '{n, plural, one {# sans base (à revoir)} other {# sans base (à revoir)}}',
    'pt-BR': '{n, plural, one {# sem base (a rever)} other {# sem base (a rever)}}',
    en: '{n, plural, one {# without baseline (to review)} other {# without baseline (to review)}}',
    es: '{n, plural, one {# sin base (por revisar)} other {# sin base (por revisar)}}',
    ca: '{n, plural, one {# sense base (per revisar)} other {# sense base (per revisar)}}',
    it: '{n, plural, one {# senza base (da rivedere)} other {# senza base (da rivedere)}}',
    de: '{n, plural, one {# ohne Basis (zu prüfen)} other {# ohne Basis (zu prüfen)}}',
    nl: '{n, plural, one {# zonder basis (na te kijken)} other {# zonder basis (na te kijken)}}',
    eo: '{n, plural, one {# sen bazo (revizienda)} other {# sen bazo (reviziendaj)}}',
    el: '{n, plural, one {# χωρίς βάση (προς έλεγχο)} other {# χωρίς βάση (προς έλεγχο)}}',
  },
  'importacoes.fila.prepareItemSkip.rien_a_appliquer': {
    fr: '{n, plural, one {# sans rien à appliquer} other {# sans rien à appliquer}}',
    'pt-BR': '{n, plural, one {# sem nada a aplicar} other {# sem nada a aplicar}}',
    en: '{n, plural, one {# with nothing to apply} other {# with nothing to apply}}',
    es: '{n, plural, one {# sin nada que aplicar} other {# sin nada que aplicar}}',
    ca: '{n, plural, one {# sense res a aplicar} other {# sense res a aplicar}}',
    it: '{n, plural, one {# senza nulla da applicare} other {# senza nulla da applicare}}',
    de: '{n, plural, one {# ohne etwas anzuwenden} other {# ohne etwas anzuwenden}}',
    nl: '{n, plural, one {# zonder iets toe te passen} other {# zonder iets toe te passen}}',
    eo: '{n, plural, one {# sen io aplikebla} other {# sen io aplikebla}}',
    el: '{n, plural, one {# χωρίς τίποτα προς εφαρμογή} other {# χωρίς τίποτα προς εφαρμογή}}',
  },
  'importacoes.fila.prepareItemSkip.non_comparee': {
    fr: '{n, plural, one {# non comparé} other {# non comparés}}',
    'pt-BR': '{n, plural, one {# não comparado} other {# não comparados}}',
    en: '{n, plural, one {# not compared} other {# not compared}}',
    es: '{n, plural, one {# no comparado} other {# no comparados}}',
    ca: '{n, plural, one {# no comparat} other {# no comparats}}',
    it: '{n, plural, one {# non confrontato} other {# non confrontati}}',
    de: '{n, plural, one {# nicht verglichen} other {# nicht verglichen}}',
    nl: '{n, plural, one {# niet vergeleken} other {# niet vergeleken}}',
    eo: '{n, plural, one {# ne komparita} other {# ne komparitaj}}',
    el: '{n, plural, one {# δεν συγκρίθηκε} other {# δεν συγκρίθηκαν}}',
  },
  // ── Importations : la ligne et son détail ──
  'importacoes.fila.comparison.items': {
    fr: '{n, plural, one {# exemplaire à mettre à jour (cote, note)} other {# exemplaires à mettre à jour (cote, note)}}',
    'pt-BR': '{n, plural, one {# exemplar a atualizar (localização, nota)} other {# exemplares a atualizar (localização, nota)}}',
    en: '{n, plural, one {# copy to update (shelf mark, note)} other {# copies to update (shelf mark, note)}}',
    es: '{n, plural, one {# ejemplar por actualizar (signatura, nota)} other {# ejemplares por actualizar (signatura, nota)}}',
    ca: '{n, plural, one {# exemplar per actualitzar (signatura, nota)} other {# exemplars per actualitzar (signatura, nota)}}',
    it: '{n, plural, one {# esemplare da aggiornare (collocazione, nota)} other {# esemplari da aggiornare (collocazione, nota)}}',
    de: '{n, plural, one {# Exemplar zu aktualisieren (Signatur, Notiz)} other {# Exemplare zu aktualisieren (Signatur, Notiz)}}',
    nl: '{n, plural, one {# exemplaar om bij te werken (signatuur, notitie)} other {# exemplaren om bij te werken (signatuur, notitie)}}',
    eo: '{n, plural, one {# ekzemplero ĝisdatigenda (signaturo, noto)} other {# ekzempleroj ĝisdatigendaj (signaturo, noto)}}',
    el: '{n, plural, one {# αντίτυπο προς ενημέρωση (ταξιθετικός αριθμός, σημείωση)} other {# αντίτυπα προς ενημέρωση (ταξιθετικός αριθμός, σημείωση)}}',
  },
  'importacoes.fila.detail.items': {
    fr: 'Exemplaires déjà là : cote et note', 'pt-BR': 'Exemplares já presentes: localização e nota',
    en: 'Copies already here: shelf mark and note', es: 'Ejemplares ya presentes: signatura y nota',
    ca: 'Exemplars ja presents: signatura i nota', it: 'Esemplari già presenti: collocazione e nota',
    de: 'Bereits vorhandene Exemplare: Signatur und Notiz', nl: 'Exemplaren al aanwezig: signatuur en notitie',
    eo: 'Ekzempleroj jam ĉeestaj: signaturo kaj noto', el: 'Αντίτυπα που υπάρχουν ήδη: ταξιθετικός αριθμός και σημείωση',
  },
  'importacoes.fila.detail.itemsMasked': {
    fr: 'Exemplaire hors de ta vue : ses valeurs AnarBib sont masquées, les verdicts restent.',
    'pt-BR': 'Exemplar fora da sua visão: os valores do AnarBib ficam ocultos, os veredictos permanecem.',
    en: 'Copy outside your view: its AnarBib values are hidden, the verdicts remain.',
    es: 'Ejemplar fuera de tu vista: sus valores de AnarBib se ocultan, los veredictos quedan.',
    ca: 'Exemplar fora de la teva vista: els seus valors d’AnarBib s’amaguen, els veredictes queden.',
    it: 'Esemplare fuori dalla tua vista: i suoi valori AnarBib sono nascosti, i verdetti restano.',
    de: 'Exemplar außerhalb deiner Sicht: seine AnarBib-Werte sind verborgen, die Befunde bleiben.',
    nl: 'Exemplaar buiten je zicht: de AnarBib-waarden zijn verborgen, de oordelen blijven.',
    eo: 'Ekzemplero ekster via vido: ĝiaj valoroj en AnarBib estas kaŝitaj, la verdiktoj restas.',
    el: 'Αντίτυπο εκτός της ορατότητάς σου: οι τιμές του στο AnarBib αποκρύπτονται, οι κρίσεις μένουν.',
  },
  'importacoes.fila.detail.itemUnchanged': {
    fr: 'cote et note inchangées', 'pt-BR': 'localização e nota inalteradas', en: 'shelf mark and note unchanged',
    es: 'signatura y nota sin cambios', ca: 'signatura i nota sense canvis', it: 'collocazione e nota invariate',
    de: 'Signatur und Notiz unverändert', nl: 'signatuur en notitie ongewijzigd', eo: 'signaturo kaj noto neŝanĝitaj',
    el: 'ταξιθετικός αριθμός και σημείωση αμετάβλητα',
  },
  'importacoes.items.field.shelf_location': {
    fr: 'Cote', 'pt-BR': 'Localização', en: 'Shelf mark', es: 'Signatura', ca: 'Signatura', it: 'Collocazione',
    de: 'Signatur', nl: 'Signatuur', eo: 'Signaturo', el: 'Ταξιθετικός αριθμός',
  },
  'importacoes.items.field.notes': {
    fr: 'Note', 'pt-BR': 'Nota', en: 'Note', es: 'Nota', ca: 'Nota', it: 'Nota', de: 'Notiz', nl: 'Notitie',
    eo: 'Noto', el: 'Σημείωση',
  },
  'importacoes.items.exemplar': {
    fr: 'exemplaire {tombo}', 'pt-BR': 'exemplar {tombo}', en: 'copy {tombo}', es: 'ejemplar {tombo}',
    ca: 'exemplar {tombo}', it: 'esemplare {tombo}', de: 'Exemplar {tombo}', nl: 'exemplaar {tombo}',
    eo: 'ekzemplero {tombo}', el: 'αντίτυπο {tombo}',
  },
  'importacoes.items.update.prepared': {
    fr: 'mise à jour d’exemplaire préparée (brouillon n° {id})', 'pt-BR': 'atualização de exemplar preparada (rascunho nº {id})',
    en: 'copy update prepared (draft no. {id})', es: 'actualización de ejemplar preparada (borrador n.º {id})',
    ca: 'actualització d’exemplar preparada (esborrany núm. {id})', it: 'aggiornamento dell’esemplare preparato (bozza n. {id})',
    de: 'Exemplar-Aktualisierung vorbereitet (Entwurf Nr. {id})', nl: 'exemplaarupdate voorbereid (concept nr. {id})',
    eo: 'ĝisdatigo de ekzemplero preparita (malneto n-ro {id})', el: 'ενημέρωση αντιτύπου προετοιμάστηκε (πρόχειρο αρ. {id})',
  },
  'importacoes.items.update.published': {
    fr: 'mise à jour d’exemplaire publiée (brouillon n° {id})', 'pt-BR': 'atualização de exemplar publicada (rascunho nº {id})',
    en: 'copy update published (draft no. {id})', es: 'actualización de ejemplar publicada (borrador n.º {id})',
    ca: 'actualització d’exemplar publicada (esborrany núm. {id})', it: 'aggiornamento dell’esemplare pubblicato (bozza n. {id})',
    de: 'Exemplar-Aktualisierung veröffentlicht (Entwurf Nr. {id})', nl: 'exemplaarupdate gepubliceerd (concept nr. {id})',
    eo: 'ĝisdatigo de ekzemplero publikigita (malneto n-ro {id})', el: 'ενημέρωση αντιτύπου δημοσιεύτηκε (πρόχειρο αρ. {id})',
  },
  // ── Rapport de révision ──
  'review.report.preparedItems': {
    fr: 'Mises à jour d’exemplaires préparées (cote, note)', 'pt-BR': 'Atualizações de exemplares preparadas (localização, nota)',
    en: 'Copy updates prepared (shelf mark, note)', es: 'Actualizaciones de ejemplares preparadas (signatura, nota)',
    ca: 'Actualitzacions d’exemplars preparades (signatura, nota)', it: 'Aggiornamenti di esemplari preparati (collocazione, nota)',
    de: 'Vorbereitete Exemplar-Aktualisierungen (Signatur, Notiz)', nl: 'Voorbereide exemplaarupdates (signatuur, notitie)',
    eo: 'Preparitaj ĝisdatigoj de ekzempleroj (signaturo, noto)', el: 'Προετοιμασμένες ενημερώσεις αντιτύπων (ταξιθετικός αριθμός, σημείωση)',
  },
  'review.report.preparedItems.summary': {
    fr: '{count, plural, one {# brouillon de mise à jour d’exemplaire} other {# brouillons de mise à jour d’exemplaire}} ; {applied, plural, one {# champ appliqué} other {# champs appliqués}} ; {shown, plural, =0 {aucun champ montré sans être appliqué} one {# champ montré, non appliqué} other {# champs montrés, non appliqués}}',
    'pt-BR': '{count, plural, one {# rascunho de atualização de exemplar} other {# rascunhos de atualização de exemplar}}; {applied, plural, one {# campo aplicado} other {# campos aplicados}}; {shown, plural, =0 {nenhum campo mostrado sem ser aplicado} one {# campo mostrado, não aplicado} other {# campos mostrados, não aplicados}}',
    en: '{count, plural, one {# copy update draft} other {# copy update drafts}}; {applied, plural, one {# field applied} other {# fields applied}}; {shown, plural, =0 {no field shown without being applied} one {# field shown, not applied} other {# fields shown, not applied}}',
    es: '{count, plural, one {# borrador de actualización de ejemplar} other {# borradores de actualización de ejemplar}}; {applied, plural, one {# campo aplicado} other {# campos aplicados}}; {shown, plural, =0 {ningún campo mostrado sin aplicarse} one {# campo mostrado, no aplicado} other {# campos mostrados, no aplicados}}',
    ca: '{count, plural, one {# esborrany d’actualització d’exemplar} other {# esborranys d’actualització d’exemplar}}; {applied, plural, one {# camp aplicat} other {# camps aplicats}}; {shown, plural, =0 {cap camp mostrat sense aplicar-se} one {# camp mostrat, no aplicat} other {# camps mostrats, no aplicats}}',
    it: '{count, plural, one {# bozza di aggiornamento di esemplare} other {# bozze di aggiornamento di esemplare}}; {applied, plural, one {# campo applicato} other {# campi applicati}}; {shown, plural, =0 {nessun campo mostrato senza essere applicato} one {# campo mostrato, non applicato} other {# campi mostrati, non applicati}}',
    de: '{count, plural, one {# Entwurf einer Exemplar-Aktualisierung} other {# Entwürfe von Exemplar-Aktualisierungen}}; {applied, plural, one {# Feld angewendet} other {# Felder angewendet}}; {shown, plural, =0 {kein Feld gezeigt, ohne angewendet zu werden} one {# Feld gezeigt, nicht angewendet} other {# Felder gezeigt, nicht angewendet}}',
    nl: '{count, plural, one {# concept voor exemplaarupdate} other {# concepten voor exemplaarupdates}}; {applied, plural, one {# veld toegepast} other {# velden toegepast}}; {shown, plural, =0 {geen veld getoond zonder toegepast te worden} one {# veld getoond, niet toegepast} other {# velden getoond, niet toegepast}}',
    eo: '{count, plural, one {# malneto de ĝisdatigo de ekzemplero} other {# malnetoj de ĝisdatigo de ekzempleroj}}; {applied, plural, one {# kampo aplikita} other {# kampoj aplikitaj}}; {shown, plural, =0 {neniu kampo montrita sen esti aplikita} one {# kampo montrita, ne aplikita} other {# kampoj montritaj, ne aplikitaj}}',
    el: '{count, plural, one {# πρόχειρο ενημέρωσης αντιτύπου} other {# πρόχειρα ενημέρωσης αντιτύπων}}· {applied, plural, one {# πεδίο εφαρμόστηκε} other {# πεδία εφαρμόστηκαν}}· {shown, plural, =0 {κανένα πεδίο δεν εμφανίστηκε χωρίς να εφαρμοστεί} one {# πεδίο εμφανίστηκε, δεν εφαρμόστηκε} other {# πεδία εμφανίστηκαν, δεν εφαρμόστηκαν}}',
  },
  // ── Refus traduits ──
  'error.publish.item_update_gone': {
    fr: 'L’exemplaire que vise cette mise à jour n’existe plus : une mise à jour ne crée jamais d’exemplaire. Mets le brouillon à la corbeille.',
    'pt-BR': 'O exemplar visado por esta atualização não existe mais: uma atualização nunca cria exemplar. Mande o rascunho para a lixeira.',
    en: 'The copy this update targets no longer exists: an update never creates a copy. Move the draft to the trash.',
    es: 'El ejemplar al que apunta esta actualización ya no existe: una actualización nunca crea un ejemplar. Manda el borrador a la papelera.',
    ca: 'L’exemplar que vol actualitzar aquest esborrany ja no existeix: una actualització mai no crea cap exemplar. Envia l’esborrany a la paperera.',
    it: 'L’esemplare a cui punta questo aggiornamento non esiste più: un aggiornamento non crea mai un esemplare. Metti la bozza nel cestino.',
    de: 'Das Exemplar, auf das diese Aktualisierung zielt, existiert nicht mehr: Eine Aktualisierung legt nie ein Exemplar an. Lege den Entwurf in den Papierkorb.',
    nl: 'Het exemplaar waarop deze update doelt, bestaat niet meer: een update maakt nooit een exemplaar aan. Zet het concept in de prullenbak.',
    eo: 'La ekzemplero, kiun celas ĉi tiu ĝisdatigo, ne plu ekzistas: ĝisdatigo neniam kreas ekzempleron. Metu la malneton en la rubujon.',
    el: 'Το αντίτυπο που στοχεύει αυτή η ενημέρωση δεν υπάρχει πια: μια ενημέρωση δεν δημιουργεί ποτέ αντίτυπο. Βάλε το πρόχειρο στον κάδο.',
  },
  'error.publish.item_update_library_changed': {
    fr: 'L’exemplaire n’est plus dans la bibliothèque qui a préparé cette mise à jour, ou le brouillon vise une autre bibliothèque : publication refusée. Mets le brouillon à la corbeille.',
    'pt-BR': 'O exemplar não está mais na biblioteca que preparou esta atualização, ou o rascunho visa outra biblioteca: publicação recusada. Mande o rascunho para a lixeira.',
    en: 'The copy is no longer in the library that prepared this update, or the draft targets another library: publication refused. Move the draft to the trash.',
    es: 'El ejemplar ya no está en la biblioteca que preparó esta actualización, o el borrador apunta a otra biblioteca: publicación rechazada. Manda el borrador a la papelera.',
    ca: 'L’exemplar ja no és a la biblioteca que va preparar aquesta actualització, o l’esborrany apunta a una altra biblioteca: publicació refusada. Envia l’esborrany a la paperera.',
    it: 'L’esemplare non è più nella biblioteca che ha preparato questo aggiornamento, o la bozza punta a un’altra biblioteca: pubblicazione rifiutata. Metti la bozza nel cestino.',
    de: 'Das Exemplar ist nicht mehr in der Bibliothek, die diese Aktualisierung vorbereitet hat, oder der Entwurf zielt auf eine andere Bibliothek: Veröffentlichung abgelehnt. Lege den Entwurf in den Papierkorb.',
    nl: 'Het exemplaar zit niet meer in de bibliotheek die deze update heeft voorbereid, of het concept doelt op een andere bibliotheek: publicatie geweigerd. Zet het concept in de prullenbak.',
    eo: 'La ekzemplero ne plu estas en la biblioteko, kiu preparis ĉi tiun ĝisdatigon, aŭ la malneto celas alian bibliotekon: publikigo rifuzita. Metu la malneton en la rubujon.',
    el: 'Το αντίτυπο δεν βρίσκεται πια στη βιβλιοθήκη που προετοίμασε αυτή την ενημέρωση ή το πρόχειρο στοχεύει άλλη βιβλιοθήκη: η δημοσίευση απορρίφθηκε. Βάλε το πρόχειρο στον κάδο.',
  },
  'error.publish.item_update_moved': {
    fr: 'L’exemplaire a changé de notice ou de fonds depuis la préparation, ou le brouillon vise un autre fonds : publication refusée. Mets le brouillon à la corbeille et prépare de nouveau la mise à jour.',
    'pt-BR': 'O exemplar mudou de ficha ou de acervo desde a preparação, ou o rascunho visa outro acervo: publicação recusada. Mande o rascunho para a lixeira e prepare de novo a atualização.',
    en: 'The copy has moved to another record or holding since it was prepared, or the draft targets another holding: publication refused. Move the draft to the trash and prepare the update again.',
    es: 'El ejemplar cambió de registro o de fondo desde la preparación, o el borrador apunta a otro fondo: publicación rechazada. Manda el borrador a la papelera y vuelve a preparar la actualización.',
    ca: 'L’exemplar ha canviat de registre o de fons des de la preparació, o l’esborrany apunta a un altre fons: publicació refusada. Envia l’esborrany a la paperera i torna a preparar l’actualització.',
    it: 'L’esemplare ha cambiato scheda o fondo dalla preparazione, o la bozza punta a un altro fondo: pubblicazione rifiutata. Metti la bozza nel cestino e prepara di nuovo l’aggiornamento.',
    de: 'Das Exemplar hat seit der Vorbereitung Datensatz oder Bestand gewechselt, oder der Entwurf zielt auf einen anderen Bestand: Veröffentlichung abgelehnt. Lege den Entwurf in den Papierkorb und bereite die Aktualisierung neu vor.',
    nl: 'Het exemplaar is sinds de voorbereiding van record of bestand veranderd, of het concept doelt op een ander bestand: publicatie geweigerd. Zet het concept in de prullenbak en bereid de update opnieuw voor.',
    eo: 'La ekzemplero ŝanĝis rikordon aŭ fondaĵon ekde la preparo, aŭ la malneto celas alian fondaĵon: publikigo rifuzita. Metu la malneton en la rubujon kaj denove preparu la ĝisdatigon.',
    el: 'Το αντίτυπο άλλαξε εγγραφή ή συλλογή από την προετοιμασία ή το πρόχειρο στοχεύει άλλη συλλογή: η δημοσίευση απορρίφθηκε. Βάλε το πρόχειρο στον κάδο και προετοίμασε ξανά την ενημέρωση.',
  },
  'error.publish.item_update_import_row_gone': {
    fr: 'Cette mise à jour d’exemplaire n’est plus liée à sa ligne d’import : publication refusée. Mets le brouillon à la corbeille et prépare de nouveau la mise à jour depuis le fichier.',
    'pt-BR': 'Esta atualização de exemplar não está mais ligada à sua linha de importação: publicação recusada. Mande o rascunho para a lixeira e prepare de novo a atualização a partir do arquivo.',
    en: 'This copy update is no longer linked to its import row: publication refused. Move the draft to the trash and prepare the update again from the file.',
    es: 'Esta actualización de ejemplar ya no está ligada a su línea de importación: publicación rechazada. Manda el borrador a la papelera y vuelve a preparar la actualización desde el archivo.',
    ca: 'Aquesta actualització d’exemplar ja no està lligada a la seva línia d’importació: publicació refusada. Envia l’esborrany a la paperera i torna a preparar l’actualització des del fitxer.',
    it: 'Questo aggiornamento di esemplare non è più legato alla sua riga di importazione: pubblicazione rifiutata. Metti la bozza nel cestino e prepara di nuovo l’aggiornamento dal file.',
    de: 'Diese Exemplar-Aktualisierung ist nicht mehr mit ihrer Importzeile verbunden: Veröffentlichung abgelehnt. Lege den Entwurf in den Papierkorb und bereite die Aktualisierung aus der Datei neu vor.',
    nl: 'Deze exemplaarupdate is niet meer gekoppeld aan haar importregel: publicatie geweigerd. Zet het concept in de prullenbak en bereid de update opnieuw voor vanuit het bestand.',
    eo: 'Ĉi tiu ĝisdatigo de ekzemplero ne plu estas ligita al sia importa linio: publikigo rifuzita. Metu la malneton en la rubujon kaj denove preparu la ĝisdatigon el la dosiero.',
    el: 'Αυτή η ενημέρωση αντιτύπου δεν συνδέεται πια με τη γραμμή εισαγωγής της: η δημοσίευση απορρίφθηκε. Βάλε το πρόχειρο στον κάδο και προετοίμασε ξανά την ενημέρωση από το αρχείο.',
  },
  'error.publish.item_update_baseline_changed': {
    fr: 'La base de cet exemplaire (ce que le dernier fichier accepté a apporté) a changé depuis la préparation : publication refusée. Mets le brouillon à la corbeille et prépare de nouveau la mise à jour.',
    'pt-BR': 'A base deste exemplar (o que o último arquivo aceito trouxe) mudou desde a preparação: publicação recusada. Mande o rascunho para a lixeira e prepare de novo a atualização.',
    en: 'This copy’s baseline (what the last accepted file brought) has changed since it was prepared: publication refused. Move the draft to the trash and prepare the update again.',
    es: 'La base de este ejemplar (lo que trajo el último archivo aceptado) cambió desde la preparación: publicación rechazada. Manda el borrador a la papelera y vuelve a preparar la actualización.',
    ca: 'La base d’aquest exemplar (el que va aportar l’últim fitxer acceptat) ha canviat des de la preparació: publicació refusada. Envia l’esborrany a la paperera i torna a preparar l’actualització.',
    it: 'La base di questo esemplare (ciò che ha portato l’ultimo file accettato) è cambiata dalla preparazione: pubblicazione rifiutata. Metti la bozza nel cestino e prepara di nuovo l’aggiornamento.',
    de: 'Die Basis dieses Exemplars (was die zuletzt angenommene Datei gebracht hat) hat sich seit der Vorbereitung geändert: Veröffentlichung abgelehnt. Lege den Entwurf in den Papierkorb und bereite die Aktualisierung neu vor.',
    nl: 'De basis van dit exemplaar (wat het laatst aanvaarde bestand bracht) is sinds de voorbereiding veranderd: publicatie geweigerd. Zet het concept in de prullenbak en bereid de update opnieuw voor.',
    eo: 'La bazo de ĉi tiu ekzemplero (kion alportis la lasta akceptita dosiero) ŝanĝiĝis ekde la preparo: publikigo rifuzita. Metu la malneton en la rubujon kaj denove preparu la ĝisdatigon.',
    el: 'Η βάση αυτού του αντιτύπου (ό,τι έφερε το τελευταίο αποδεκτό αρχείο) άλλαξε από την προετοιμασία: η δημοσίευση απορρίφθηκε. Βάλε το πρόχειρο στον κάδο και προετοίμασε ξανά την ενημέρωση.',
  },
  'error.publish.item_update_changed': {
    fr: 'L’exemplaire a changé depuis la préparation de cette mise à jour : publier la copie déferait ces changements. Mets le brouillon à la corbeille et prépare de nouveau la mise à jour depuis le fichier.',
    'pt-BR': 'O exemplar mudou desde a preparação desta atualização: publicar a cópia desfaria essas mudanças. Mande o rascunho para a lixeira e prepare de novo a atualização a partir do arquivo.',
    en: 'The copy has changed since this update was prepared: publishing the copy would undo those changes. Move the draft to the trash and prepare the update again from the file.',
    es: 'El ejemplar cambió desde la preparación de esta actualización: publicar la copia desharía esos cambios. Manda el borrador a la papelera y vuelve a preparar la actualización desde el archivo.',
    ca: 'L’exemplar ha canviat des de la preparació d’aquesta actualització: publicar la còpia desfaria aquests canvis. Envia l’esborrany a la paperera i torna a preparar l’actualització des del fitxer.',
    it: 'L’esemplare è cambiato dalla preparazione di questo aggiornamento: pubblicare la copia annullerebbe queste modifiche. Metti la bozza nel cestino e prepara di nuovo l’aggiornamento dal file.',
    de: 'Das Exemplar hat sich seit der Vorbereitung dieser Aktualisierung geändert: Die Kopie zu veröffentlichen würde diese Änderungen rückgängig machen. Lege den Entwurf in den Papierkorb und bereite die Aktualisierung aus der Datei neu vor.',
    nl: 'Het exemplaar is veranderd sinds deze update werd voorbereid: de kopie publiceren zou die wijzigingen ongedaan maken. Zet het concept in de prullenbak en bereid de update opnieuw voor vanuit het bestand.',
    eo: 'La ekzemplero ŝanĝiĝis ekde la preparo de ĉi tiu ĝisdatigo: publikigi la kopion malfarus tiujn ŝanĝojn. Metu la malneton en la rubujon kaj denove preparu la ĝisdatigon el la dosiero.',
    el: 'Το αντίτυπο άλλαξε από την προετοιμασία αυτής της ενημέρωσης: η δημοσίευση του αντιγράφου θα αναιρούσε αυτές τις αλλαγές. Βάλε το πρόχειρο στον κάδο και προετοίμασε ξανά την ενημέρωση από το αρχείο.',
  },
  'error.publish.item_update_side_effect': {
    fr: 'Une mise à jour d’exemplaire préparée par un réimport ne change que la cote et la note : ce brouillon a été retouché ailleurs (numéro, étiquette, fonds…). Remets ces champs comme ils étaient, ou passe par « Éditer » après la publication.',
    'pt-BR': 'Uma atualização de exemplar preparada por uma reimportação só muda a localização e a nota: este rascunho foi alterado em outro ponto (número, etiqueta, acervo…). Volte esses campos ao que eram, ou use «Editar» depois da publicação.',
    en: 'A copy update prepared by a re-import only changes the shelf mark and the note: this draft was edited elsewhere (number, label, holding…). Put those fields back as they were, or use “Edit” after publication.',
    es: 'Una actualización de ejemplar preparada por una reimportación solo cambia la signatura y la nota: este borrador se retocó en otro sitio (número, etiqueta, fondo…). Deja esos campos como estaban, o usa «Editar» después de la publicación.',
    ca: 'Una actualització d’exemplar preparada per una reimportació només canvia la signatura i la nota: aquest esborrany s’ha retocat en un altre lloc (número, etiqueta, fons…). Torna aquests camps com eren, o fes servir «Editar» després de la publicació.',
    it: 'Un aggiornamento di esemplare preparato da una reimportazione cambia solo la collocazione e la nota: questa bozza è stata ritoccata altrove (numero, etichetta, fondo…). Rimetti quei campi com’erano, o usa «Modifica» dopo la pubblicazione.',
    de: 'Eine durch einen Reimport vorbereitete Exemplar-Aktualisierung ändert nur Signatur und Notiz: Dieser Entwurf wurde anderswo bearbeitet (Nummer, Etikett, Bestand …). Setze diese Felder zurück, oder nutze nach der Veröffentlichung „Bearbeiten“.',
    nl: 'Een exemplaarupdate die door een herimport is voorbereid, wijzigt alleen de signatuur en de notitie: dit concept is elders aangepast (nummer, etiket, bestand…). Zet die velden terug zoals ze waren, of gebruik „Bewerken” na de publicatie.',
    eo: 'Ĝisdatigo de ekzemplero preparita de reimporto ŝanĝas nur la signaturon kaj la noton: ĉi tiu malneto estis retuŝita aliloke (numero, etikedo, fondaĵo…). Remetu tiujn kampojn kiel ili estis, aŭ uzu «Redakti» post la publikigo.',
    el: 'Μια ενημέρωση αντιτύπου που προετοιμάστηκε από επανεισαγωγή αλλάζει μόνο τον ταξιθετικό αριθμό και τη σημείωση: αυτό το πρόχειρο τροποποιήθηκε αλλού (αριθμός, ετικέτα, συλλογή…). Επανάφερε αυτά τα πεδία ή χρησιμοποίησε «Επεξεργασία» μετά τη δημοσίευση.',
  },
  'error.import.item_update_trace_reserved': {
    fr: 'La trace d’une mise à jour d’exemplaire préparée par un réimport, et l’exemplaire qu’elle vise, ne se modifient pas.',
    'pt-BR': 'O rastro de uma atualização de exemplar preparada por uma reimportação, e o exemplar que ela visa, não se modificam.',
    en: 'The trace of a copy update prepared by a re-import, and the copy it targets, cannot be changed.',
    es: 'La huella de una actualización de ejemplar preparada por una reimportación, y el ejemplar al que apunta, no se modifican.',
    ca: 'La traça d’una actualització d’exemplar preparada per una reimportació, i l’exemplar al qual apunta, no es modifiquen.',
    it: 'La traccia di un aggiornamento di esemplare preparato da una reimportazione, e l’esemplare a cui punta, non si modificano.',
    de: 'Die Spur einer durch einen Reimport vorbereiteten Exemplar-Aktualisierung und das Exemplar, auf das sie zielt, lassen sich nicht ändern.',
    nl: 'Het spoor van een exemplaarupdate die door een herimport is voorbereid, en het exemplaar waarop ze doelt, kunnen niet gewijzigd worden.',
    eo: 'La spuro de ĝisdatigo de ekzemplero preparita de reimporto, kaj la ekzemplero, kiun ĝi celas, ne modifeblas.',
    el: 'Το ίχνος μιας ενημέρωσης αντιτύπου που προετοιμάστηκε από επανεισαγωγή, και το αντίτυπο που στοχεύει, δεν τροποποιούνται.',
  },
  'error.import.item_update_not_mergeable': {
    fr: 'Une mise à jour d’exemplaire préparée par un réimport vise ce brouillon de notice : la fusion la réécrirait. Publie-la ou mets-la à la corbeille d’abord.',
    'pt-BR': 'Uma atualização de exemplar preparada por uma reimportação visa este rascunho de ficha: a fusão a reescreveria. Publique-a ou mande-a para a lixeira antes.',
    en: 'A copy update prepared by a re-import targets this record draft: merging would rewrite it. Publish it or move it to the trash first.',
    es: 'Una actualización de ejemplar preparada por una reimportación apunta a este borrador de registro: la fusión la reescribiría. Publícala o mándala a la papelera antes.',
    ca: 'Una actualització d’exemplar preparada per una reimportació apunta a aquest esborrany de registre: la fusió la reescriuria. Publica-la o envia-la a la paperera abans.',
    it: 'Un aggiornamento di esemplare preparato da una reimportazione punta a questa bozza di scheda: la fusione lo riscriverebbe. Pubblicalo o mettilo nel cestino prima.',
    de: 'Eine durch einen Reimport vorbereitete Exemplar-Aktualisierung zielt auf diesen Datensatz-Entwurf: Die Zusammenführung würde sie umschreiben. Veröffentliche sie oder lege sie zuerst in den Papierkorb.',
    nl: 'Een exemplaarupdate die door een herimport is voorbereid, doelt op dit recordconcept: samenvoegen zou ze herschrijven. Publiceer ze of zet ze eerst in de prullenbak.',
    eo: 'Ĝisdatigo de ekzemplero preparita de reimporto celas ĉi tiun malneton de rikordo: la kunfando reskribus ĝin. Publikigu ĝin aŭ unue metu ĝin en la rubujon.',
    el: 'Μια ενημέρωση αντιτύπου που προετοιμάστηκε από επανεισαγωγή στοχεύει αυτό το πρόχειρο εγγραφής: η συγχώνευση θα την ξανάγραφε. Δημοσίευσέ την ή βάλ’ την πρώτα στον κάδο.',
  },
  // ── Revue sceptique du 08/10 ──
  'importacoes.fila.detail.itemFieldMasked': {
    fr: 'masqué (exemplaire hors de ta vue)', 'pt-BR': 'oculto (exemplar fora da sua visão)', en: 'hidden (copy outside your view)',
    es: 'oculto (ejemplar fuera de tu vista)', ca: 'amagat (exemplar fora de la teva vista)', it: 'nascosto (esemplare fuori dalla tua vista)',
    de: 'verborgen (Exemplar außerhalb deiner Sicht)', nl: 'verborgen (exemplaar buiten je zicht)', eo: 'kaŝita (ekzemplero ekster via vido)',
    el: 'κρυφό (αντίτυπο εκτός της ορατότητάς σου)',
  },
  'importacoes.fila.detail.itemFieldFile': {
    fr: 'fichier : {n}', 'pt-BR': 'arquivo: {n}', en: 'file: {n}', es: 'archivo: {n}', ca: 'fitxer: {n}', it: 'file: {n}',
    de: 'Datei: {n}', nl: 'bestand: {n}', eo: 'dosiero: {n}', el: 'αρχείο: {n}',
  },
  'importacoes.items.update.empeche.deja_preparee': {
    fr: 'une mise à jour de cet exemplaire est déjà préparée (autre import)', 'pt-BR': 'uma atualização deste exemplar já está preparada (outra importação)',
    en: 'an update of this copy is already prepared (another import)', es: 'ya hay una actualización de este ejemplar preparada (otra importación)',
    ca: 'ja hi ha una actualització d’aquest exemplar preparada (una altra importació)', it: 'un aggiornamento di questo esemplare è già preparato (altra importazione)',
    de: 'eine Aktualisierung dieses Exemplars ist schon vorbereitet (anderer Import)', nl: 'een update van dit exemplaar is al voorbereid (andere import)',
    eo: 'ĝisdatigo de ĉi tiu ekzemplero jam estas preparita (alia importo)', el: 'μια ενημέρωση αυτού του αντιτύπου έχει ήδη προετοιμαστεί (άλλη εισαγωγή)',
  },
  'importacoes.items.update.empeche.brouillon_en_cours': {
    fr: 'un brouillon « Éditer » de cet exemplaire est en cours : publie-le ou mets-le à la corbeille d’abord',
    'pt-BR': 'há um rascunho «Editar» deste exemplar em andamento: publique-o ou mande-o para a lixeira antes',
    en: 'an “Edit” draft of this copy is in progress: publish it or move it to the trash first',
    es: 'hay un borrador «Editar» de este ejemplar en curso: publícalo o mándalo a la papelera antes',
    ca: 'hi ha un esborrany «Editar» d’aquest exemplar en curs: publica’l o envia’l a la paperera abans',
    it: 'c’è una bozza «Modifica» di questo esemplare in corso: pubblicala o mettila nel cestino prima',
    de: 'ein „Bearbeiten“-Entwurf dieses Exemplars läuft: veröffentliche ihn oder lege ihn zuerst in den Papierkorb',
    nl: 'er loopt een „Bewerken”-concept van dit exemplaar: publiceer het of zet het eerst in de prullenbak',
    eo: 'malneto «Redakti» de ĉi tiu ekzemplero estas en laboro: publikigu ĝin aŭ unue metu ĝin en la rubujon',
    el: 'υπάρχει πρόχειρο «Επεξεργασία» αυτού του αντιτύπου σε εξέλιξη: δημοσίευσέ το ή βάλ’ το πρώτα στον κάδο',
  },
  'error.publish.item_update_changed_since_publication': {
    fr: 'L’exemplaire a changé depuis la publication de cette mise à jour (un « Éditer » publié entre-temps, par exemple) : la republier déferait ces changements. Ouvre « Éditer » pour retoucher l’exemplaire.',
    'pt-BR': 'O exemplar mudou desde a publicação desta atualização (um «Editar» publicado nesse meio-tempo, por exemplo): republicá-la desfaria essas mudanças. Abra «Editar» para retocar o exemplar.',
    en: 'The copy has changed since this update was published (an “Edit” published in the meantime, for instance): republishing it would undo those changes. Open “Edit” to touch up the copy.',
    es: 'El ejemplar cambió desde la publicación de esta actualización (un «Editar» publicado entretanto, por ejemplo): republicarla desharía esos cambios. Abre «Editar» para retocar el ejemplar.',
    ca: 'L’exemplar ha canviat des de la publicació d’aquesta actualització (un «Editar» publicat mentrestant, per exemple): republicar-la desfaria aquests canvis. Obre «Editar» per retocar l’exemplar.',
    it: 'L’esemplare è cambiato dalla pubblicazione di questo aggiornamento (una «Modifica» pubblicata nel frattempo, per esempio): ripubblicarlo annullerebbe queste modifiche. Apri «Modifica» per ritoccare l’esemplare.',
    de: 'Das Exemplar hat sich seit der Veröffentlichung dieser Aktualisierung geändert (etwa ein inzwischen veröffentlichtes „Bearbeiten“): sie erneut zu veröffentlichen würde diese Änderungen rückgängig machen. Öffne „Bearbeiten“, um das Exemplar zu überarbeiten.',
    nl: 'Het exemplaar is veranderd sinds deze update werd gepubliceerd (bijvoorbeeld een intussen gepubliceerde „Bewerken”): opnieuw publiceren zou die wijzigingen ongedaan maken. Open „Bewerken” om het exemplaar bij te werken.',
    eo: 'La ekzemplero ŝanĝiĝis ekde la publikigo de ĉi tiu ĝisdatigo (ekzemple intertempe publikigita «Redakti»): republikigi ĝin malfarus tiujn ŝanĝojn. Malfermu «Redakti» por retuŝi la ekzempleron.',
    el: 'Το αντίτυπο άλλαξε από τη δημοσίευση αυτής της ενημέρωσης (π.χ. μια «Επεξεργασία» που δημοσιεύτηκε στο μεταξύ): η αναδημοσίευση θα αναιρούσε αυτές τις αλλαγές. Άνοιξε «Επεξεργασία» για να διορθώσεις το αντίτυπο.',
  },
  'error.catalog.item_update_pending': {
    fr: 'Une mise à jour de cet exemplaire, préparée par un réimport, attend sa révision : publie-la ou mets-la à la corbeille avant d’ouvrir un autre brouillon de cet exemplaire.',
    'pt-BR': 'Uma atualização deste exemplar, preparada por uma reimportação, aguarda revisão: publique-a ou mande-a para a lixeira antes de abrir outro rascunho deste exemplar.',
    en: 'An update of this copy, prepared by a re-import, is awaiting review: publish it or move it to the trash before opening another draft of this copy.',
    es: 'Una actualización de este ejemplar, preparada por una reimportación, espera su revisión: publícala o mándala a la papelera antes de abrir otro borrador de este ejemplar.',
    ca: 'Una actualització d’aquest exemplar, preparada per una reimportació, espera la revisió: publica-la o envia-la a la paperera abans d’obrir un altre esborrany d’aquest exemplar.',
    it: 'Un aggiornamento di questo esemplare, preparato da una reimportazione, attende la revisione: pubblicalo o mettilo nel cestino prima di aprire un’altra bozza di questo esemplare.',
    de: 'Eine durch einen Reimport vorbereitete Aktualisierung dieses Exemplars wartet auf ihre Prüfung: veröffentliche sie oder lege sie in den Papierkorb, bevor du einen weiteren Entwurf dieses Exemplars öffnest.',
    nl: 'Een update van dit exemplaar, voorbereid door een herimport, wacht op controle: publiceer ze of zet ze in de prullenbak voor je een ander concept van dit exemplaar opent.',
    eo: 'Ĝisdatigo de ĉi tiu ekzemplero, preparita de reimporto, atendas revizion: publikigu ĝin aŭ metu ĝin en la rubujon antaŭ ol malfermi alian malneton de ĉi tiu ekzemplero.',
    el: 'Μια ενημέρωση αυτού του αντιτύπου, που προετοιμάστηκε από επανεισαγωγή, περιμένει έλεγχο: δημοσίευσέ την ή βάλ’ την στον κάδο πριν ανοίξεις άλλο πρόχειρο αυτού του αντιτύπου.',
  },
  'error.import.item_update_superseded': {
    fr: 'Une autre mise à jour de cet exemplaire a été préparée depuis : ce brouillon ne revient pas. Relis la plus récente.',
    'pt-BR': 'Outra atualização deste exemplar foi preparada desde então: este rascunho não volta. Revise a mais recente.',
    en: 'Another update of this copy has been prepared since: this draft does not come back. Check the most recent one.',
    es: 'Desde entonces se preparó otra actualización de este ejemplar: este borrador no vuelve. Revisa la más reciente.',
    ca: 'Des d’aleshores s’ha preparat una altra actualització d’aquest exemplar: aquest esborrany no torna. Revisa la més recent.',
    it: 'Da allora è stato preparato un altro aggiornamento di questo esemplare: questa bozza non torna. Rileggi il più recente.',
    de: 'Seitdem wurde eine andere Aktualisierung dieses Exemplars vorbereitet: dieser Entwurf kommt nicht zurück. Prüfe die neueste.',
    nl: 'Sindsdien is een andere update van dit exemplaar voorbereid: dit concept komt niet terug. Lees de recentste na.',
    eo: 'Ekde tiam alia ĝisdatigo de ĉi tiu ekzemplero estis preparita: ĉi tiu malneto ne revenas. Relegu la plej freŝan.',
    el: 'Από τότε προετοιμάστηκε άλλη ενημέρωση αυτού του αντιτύπου: αυτό το πρόχειρο δεν επιστρέφει. Έλεγξε την πιο πρόσφατη.',
  },
  'error.import.update_page_too_many_items': {
    fr: 'Trop d’exemplaires du fichier pour un seul appel (5 000 au plus) : sélectionne moins de lignes à la fois.',
    'pt-BR': 'Exemplares do arquivo demais para uma única chamada (no máximo 5 000): selecione menos linhas de cada vez.',
    en: 'Too many copies in the file for a single call (5,000 at most): select fewer rows at a time.',
    es: 'Demasiados ejemplares del archivo para una sola llamada (5 000 como máximo): selecciona menos líneas a la vez.',
    ca: 'Massa exemplars del fitxer per a una sola crida (5 000 com a màxim): selecciona menys línies alhora.',
    it: 'Troppi esemplari del file per una sola chiamata (5 000 al massimo): seleziona meno righe alla volta.',
    de: 'Zu viele Exemplare der Datei für einen einzigen Aufruf (höchstens 5 000): wähle weniger Zeilen auf einmal.',
    nl: 'Te veel exemplaren uit het bestand voor één aanroep (hoogstens 5 000): selecteer minder regels tegelijk.',
    eo: 'Tro da ekzempleroj de la dosiero por unu sola alvoko (maksimume 5 000): elektu malpli da linioj samtempe.',
    el: 'Πάρα πολλά αντίτυπα του αρχείου για μία μόνο κλήση (έως 5 000): επίλεξε λιγότερες γραμμές κάθε φορά.',
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
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(`${loc} : ${ajoutees} clé(s) ajoutée(s), ${corrigees} corrigée(s), JSON valide.`);
}
