/* ===========================================================================
 * i18n-add-h21-lot6a.cjs — H21 lot 6a (REGISTRE IMP-33, 08/10/2026) :
 * reconnaître les exemplaires d'un réimport.
 * Importations : sur une ligne, les exemplaires du fichier et leur verdict
 * (nouveau, déjà là, déjà en brouillon, sans code-barres, déplacé dans PMB,
 * réétiqueté, code repris) ; les comptes par verdict dans le message de
 * « Rapprocher » et les lignes signalées. Rapport de révision : les
 * exemplaires écartés et pourquoi. Refus traduits : la trace d'import d'un
 * exemplaire (error.import.item_trace_reserved), la sortie de corbeille d'un
 * exemplaire dont le code est repris (error.import.item_restore_code_taken),
 * l'identifiant d'origine déjà pris à la publication
 * (error.publish.source_item_id_taken).
 * Tutoiement partout ; pt-BR au « você ». Vocabulaire repris des clés voisines
 * (importacoes.fila.*, review.report.items.*, error.publish.*).
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  // ── Importations : la liste des exemplaires d'une ligne ──
  'importacoes.items.title': {
    fr: '{n, plural, one {# exemplaire du fichier} other {# exemplaires du fichier}}',
    'pt-BR': '{n, plural, one {# exemplar do arquivo} other {# exemplares do arquivo}}',
    en: '{n, plural, one {# copy in the file} other {# copies in the file}}',
    es: '{n, plural, one {# ejemplar del archivo} other {# ejemplares del archivo}}',
    ca: '{n, plural, one {# exemplar del fitxer} other {# exemplars del fitxer}}',
    it: '{n, plural, one {# esemplare del file} other {# esemplari del file}}',
    de: '{n, plural, one {# Exemplar der Datei} other {# Exemplare der Datei}}',
    nl: '{n, plural, one {# exemplaar uit het bestand} other {# exemplaren uit het bestand}}',
    eo: '{n, plural, one {# ekzemplero de la dosiero} other {# ekzempleroj de la dosiero}}',
    el: '{n, plural, one {# αντίτυπο του αρχείου} other {# αντίτυπα του αρχείου}}',
  },
  'importacoes.items.noCode': {
    fr: 'sans code-barres', 'pt-BR': 'sem código de barras', en: 'no barcode', es: 'sin código de barras',
    ca: 'sense codi de barres', it: 'senza codice a barre', de: 'ohne Barcode', nl: 'zonder streepjescode',
    eo: 'sen strekkodo', el: 'χωρίς γραμμωτό κώδικα',
  },
  'importacoes.items.verdict.none': {
    fr: 'pas encore constaté (au prochain « Rapprocher » ou « Promouvoir »)',
    'pt-BR': 'ainda não verificado (no próximo «Aproximar» ou «Promover»)',
    en: 'not checked yet (at the next “Reconcile” or “Promote”)',
    es: 'aún no comprobado (en el próximo «Aproximar» o «Promover»)',
    ca: 'encara no comprovat (al proper «Aproximar» o «Promoure»)',
    it: 'non ancora verificato (al prossimo «Riconcilia» o «Promuovi»)',
    de: 'noch nicht geprüft (beim nächsten „Abgleichen“ oder „Übernehmen“)',
    nl: 'nog niet nagegaan (bij de volgende „Koppelen” of „Promoveren”)',
    eo: 'ankoraŭ ne kontrolita (ĉe la venonta «Proksimigi» aŭ «Promocii»)',
    el: 'δεν έχει ελεγχθεί ακόμη (στην επόμενη «Αντιστοίχιση» ή «Προώθηση»)',
  },
  'importacoes.items.verdict.nouveau': {
    fr: 'nouveau : brouillon d’exemplaire', 'pt-BR': 'novo: rascunho de exemplar', en: 'new: copy draft',
    es: 'nuevo: borrador de ejemplar', ca: 'nou: esborrany d’exemplar', it: 'nuovo: bozza di esemplare',
    de: 'neu: Exemplar-Entwurf', nl: 'nieuw: exemplaarconcept', eo: 'nova: malneto de ekzemplero',
    el: 'νέο: πρόχειρο αντιτύπου',
  },
  'importacoes.items.verdict.deja_la': {
    fr: 'déjà là', 'pt-BR': 'já está na biblioteca', en: 'already here', es: 'ya está aquí', ca: 'ja hi és',
    it: 'già presente', de: 'schon vorhanden', nl: 'al aanwezig', eo: 'jam ĉi tie', el: 'υπάρχει ήδη',
  },
  'importacoes.items.verdict.deja_en_brouillon': {
    fr: 'déjà en brouillon', 'pt-BR': 'já em rascunho', en: 'already in a draft', es: 'ya en borrador',
    ca: 'ja en esborrany', it: 'già in bozza', de: 'schon im Entwurf', nl: 'al in een concept',
    eo: 'jam en malneto', el: 'ήδη σε πρόχειρο',
  },
  'importacoes.items.verdict.sans_code': {
    fr: 'sans code-barres : à ajouter à la main', 'pt-BR': 'sem código de barras: acrescente à mão',
    en: 'no barcode: add it by hand', es: 'sin código de barras: añádelo a mano',
    ca: 'sense codi de barres: afegeix-lo a mà', it: 'senza codice a barre: aggiungilo a mano',
    de: 'ohne Barcode: von Hand hinzufügen', nl: 'zonder streepjescode: voeg het met de hand toe',
    eo: 'sen strekkodo: aldonu ĝin permane', el: 'χωρίς γραμμωτό κώδικα: πρόσθεσέ το με το χέρι',
  },
  'importacoes.items.verdict.deplace': {
    fr: 'déplacé dans PMB vers « {notice} » — dans AnarBib il est sur « {ailleurs} » : rien n’est déplacé, à faire à la main',
    'pt-BR': 'movido no PMB para «{notice}» — no AnarBib ele está em «{ailleurs}»: nada é movido, faça à mão',
    en: 'moved in PMB to “{notice}” — in AnarBib it is on “{ailleurs}”: nothing is moved, do it by hand',
    es: 'movido en PMB a «{notice}» — en AnarBib está en «{ailleurs}»: no se mueve nada, hazlo a mano',
    ca: 'traslladat a PMB a «{notice}» — a AnarBib és a «{ailleurs}»: no es trasllada res, fes-ho a mà',
    it: 'spostato in PMB su «{notice}» — in AnarBib è su «{ailleurs}»: non si sposta nulla, fallo a mano',
    de: 'in PMB zu „{notice}“ verschoben — in AnarBib hängt es an „{ailleurs}“: nichts wird verschoben, mach es von Hand',
    nl: 'in PMB verplaatst naar „{notice}” — in AnarBib staat het bij „{ailleurs}”: er wordt niets verplaatst, doe het met de hand',
    eo: 'movita en PMB al «{notice}» — en AnarBib ĝi estas ĉe «{ailleurs}»: nenio estas movita, faru tion permane',
    el: 'μετακινήθηκε στο PMB στο «{notice}» — στο AnarBib είναι στο «{ailleurs}»: δεν μετακινείται τίποτα, κάν’ το με το χέρι',
  },
  'importacoes.items.verdict.reetiquete': {
    fr: 'réétiqueté dans PMB ({ancien} → {nouveau}) : rien n’est changé dans AnarBib',
    'pt-BR': 'reetiquetado no PMB ({ancien} → {nouveau}): nada muda no AnarBib',
    en: 'relabelled in PMB ({ancien} → {nouveau}): nothing changes in AnarBib',
    es: 'reetiquetado en PMB ({ancien} → {nouveau}): nada cambia en AnarBib',
    ca: 'reetiquetat a PMB ({ancien} → {nouveau}): res no canvia a AnarBib',
    it: 'rietichettato in PMB ({ancien} → {nouveau}): in AnarBib non cambia nulla',
    de: 'in PMB neu etikettiert ({ancien} → {nouveau}): in AnarBib ändert sich nichts',
    nl: 'in PMB opnieuw geëtiketteerd ({ancien} → {nouveau}): in AnarBib verandert niets',
    eo: 'reetikedita en PMB ({ancien} → {nouveau}): nenio ŝanĝiĝas en AnarBib',
    el: 'επανασημάνθηκε στο PMB ({ancien} → {nouveau}): τίποτα δεν αλλάζει στο AnarBib',
  },
  'importacoes.items.verdict.code_repris': {
    fr: 'code repris par un autre exemplaire dans PMB : rien n’est créé, à vérifier',
    'pt-BR': 'código retomado por outro exemplar no PMB: nada é criado, verifique',
    en: 'barcode taken over by another copy in PMB: nothing is created, check it',
    es: 'código retomado por otro ejemplar en PMB: no se crea nada, compruébalo',
    ca: 'codi reprès per un altre exemplar a PMB: no es crea res, comprova-ho',
    it: 'codice ripreso da un altro esemplare in PMB: non si crea nulla, verificalo',
    de: 'Barcode in PMB von einem anderen Exemplar übernommen: nichts wird angelegt, prüfe es',
    nl: 'streepjescode in PMB overgenomen door een ander exemplaar: er wordt niets aangemaakt, controleer het',
    eo: 'strekkodo reprenita de alia ekzemplero en PMB: nenio estas kreita, kontrolu',
    el: 'ο κώδικας πέρασε σε άλλο αντίτυπο στο PMB: δεν δημιουργείται τίποτα, έλεγξέ το',
  },
  // ── les comptes par verdict (message de « Rapprocher », rapport) ──
  'importacoes.items.count.nouveau': {
    fr: '{n, plural, one {# nouveau} other {# nouveaux}}', 'pt-BR': '{n, plural, one {# novo} other {# novos}}',
    en: '{n} new', es: '{n, plural, one {# nuevo} other {# nuevos}}', ca: '{n, plural, one {# nou} other {# nous}}',
    it: '{n, plural, one {# nuovo} other {# nuovi}}', de: '{n} neu', nl: '{n} nieuw',
    eo: '{n, plural, one {# nova} other {# novaj}}', el: '{n, plural, one {# νέο} other {# νέα}}',
  },
  'importacoes.items.count.deja_la': {
    fr: '{n} déjà là', 'pt-BR': '{n} já na biblioteca', en: '{n} already here', es: '{n} ya aquí', ca: '{n} ja hi són',
    it: '{n} già presenti', de: '{n} schon vorhanden', nl: '{n} al aanwezig', eo: '{n} jam ĉi tie', el: '{n} υπάρχουν ήδη',
  },
  'importacoes.items.count.deja_en_brouillon': {
    fr: '{n} déjà en brouillon', 'pt-BR': '{n} já em rascunho', en: '{n} already in a draft', es: '{n} ya en borrador',
    ca: '{n} ja en esborrany', it: '{n} già in bozza', de: '{n} schon im Entwurf', nl: '{n} al in een concept',
    eo: '{n} jam en malneto', el: '{n} ήδη σε πρόχειρο',
  },
  'importacoes.items.count.sans_code': {
    fr: '{n} sans code-barres (à ajouter à la main)', 'pt-BR': '{n} sem código de barras (acrescente à mão)',
    en: '{n} without barcode (add by hand)', es: '{n} sin código de barras (añádelos a mano)',
    ca: '{n} sense codi de barres (afegeix-los a mà)', it: '{n} senza codice a barre (aggiungili a mano)',
    de: '{n} ohne Barcode (von Hand hinzufügen)', nl: '{n} zonder streepjescode (met de hand toevoegen)',
    eo: '{n} sen strekkodo (aldonu permane)', el: '{n} χωρίς γραμμωτό κώδικα (πρόσθεσέ τα με το χέρι)',
  },
  'importacoes.items.count.deplace': {
    fr: '{n, plural, one {# déplacé dans PMB} other {# déplacés dans PMB}}',
    'pt-BR': '{n, plural, one {# movido no PMB} other {# movidos no PMB}}',
    en: '{n} moved in PMB', es: '{n, plural, one {# movido en PMB} other {# movidos en PMB}}',
    ca: '{n, plural, one {# traslladat a PMB} other {# traslladats a PMB}}',
    it: '{n, plural, one {# spostato in PMB} other {# spostati in PMB}}', de: '{n} in PMB verschoben',
    nl: '{n} verplaatst in PMB', eo: '{n, plural, one {# movita en PMB} other {# movitaj en PMB}}',
    el: '{n, plural, one {# μετακινήθηκε στο PMB} other {# μετακινήθηκαν στο PMB}}',
  },
  'importacoes.items.count.reetiquete': {
    fr: '{n, plural, one {# réétiqueté} other {# réétiquetés}}', 'pt-BR': '{n, plural, one {# reetiquetado} other {# reetiquetados}}',
    en: '{n} relabelled', es: '{n, plural, one {# reetiquetado} other {# reetiquetados}}',
    ca: '{n, plural, one {# reetiquetat} other {# reetiquetats}}', it: '{n, plural, one {# rietichettato} other {# rietichettati}}',
    de: '{n} neu etikettiert', nl: '{n} opnieuw geëtiketteerd', eo: '{n, plural, one {# reetikedita} other {# reetikeditaj}}',
    el: '{n, plural, one {# επανασημάνθηκε} other {# επανασημάνθηκαν}}',
  },
  'importacoes.items.count.code_repris': {
    fr: '{n, plural, one {# code repris} other {# codes repris}}', 'pt-BR': '{n, plural, one {# código retomado} other {# códigos retomados}}',
    en: '{n, plural, one {# barcode taken over} other {# barcodes taken over}}',
    es: '{n, plural, one {# código retomado} other {# códigos retomados}}', ca: '{n, plural, one {# codi reprès} other {# codis represos}}',
    it: '{n, plural, one {# codice ripreso} other {# codici ripresi}}', de: '{n, plural, one {# Barcode übernommen} other {# Barcodes übernommen}}',
    nl: '{n, plural, one {# streepjescode overgenomen} other {# streepjescodes overgenomen}}',
    eo: '{n, plural, one {# kodo reprenita} other {# kodoj reprenitaj}}', el: '{n, plural, one {# κώδικας ξαναχρησιμοποιήθηκε} other {# κώδικες ξαναχρησιμοποιήθηκαν}}',
  },
  'importacoes.items.counts': {
    fr: 'Exemplaires du fichier : {list}.', 'pt-BR': 'Exemplares do arquivo: {list}.', en: 'Copies in the file: {list}.',
    es: 'Ejemplares del archivo: {list}.', ca: 'Exemplars del fitxer: {list}.', it: 'Esemplari del file: {list}.',
    de: 'Exemplare der Datei: {list}.', nl: 'Exemplaren uit het bestand: {list}.', eo: 'Ekzempleroj de la dosiero: {list}.',
    el: 'Αντίτυπα του αρχείου: {list}.',
  },
  'importacoes.items.rowsSignalled': {
    fr: '{n, plural, one {# ligne signalée reste sans brouillon ni rejet : vois ses exemplaires dans la liste et fais le geste à la main.} other {# lignes signalées restent sans brouillon ni rejet : vois leurs exemplaires dans la liste et fais le geste à la main.}}',
    'pt-BR': '{n, plural, one {# linha sinalizada fica sem rascunho nem rejeição: veja os exemplares dela na lista e faça o gesto à mão.} other {# linhas sinalizadas ficam sem rascunho nem rejeição: veja os exemplares delas na lista e faça o gesto à mão.}}',
    en: '{n, plural, one {# flagged row is left with no draft and not rejected: see its copies in the list and act by hand.} other {# flagged rows are left with no draft and not rejected: see their copies in the list and act by hand.}}',
    es: '{n, plural, one {# fila señalada queda sin borrador ni rechazo: mira sus ejemplares en la lista y haz el gesto a mano.} other {# filas señaladas quedan sin borrador ni rechazo: mira sus ejemplares en la lista y haz el gesto a mano.}}',
    ca: '{n, plural, one {# fila assenyalada queda sense esborrany ni rebuig: mira’n els exemplars a la llista i fes el gest a mà.} other {# files assenyalades queden sense esborrany ni rebuig: mira’n els exemplars a la llista i fes el gest a mà.}}',
    it: '{n, plural, one {# riga segnalata resta senza bozza né rifiuto: guarda i suoi esemplari nell’elenco e fai il gesto a mano.} other {# righe segnalate restano senza bozza né rifiuto: guarda i loro esemplari nell’elenco e fai il gesto a mano.}}',
    de: '{n, plural, one {# gemeldete Zeile bleibt ohne Entwurf und ohne Ablehnung: sieh dir ihre Exemplare in der Liste an und handle von Hand.} other {# gemeldete Zeilen bleiben ohne Entwurf und ohne Ablehnung: sieh dir ihre Exemplare in der Liste an und handle von Hand.}}',
    nl: '{n, plural, one {# gemelde rij blijft zonder concept en zonder afwijzing: bekijk de exemplaren in de lijst en handel met de hand.} other {# gemelde rijen blijven zonder concept en zonder afwijzing: bekijk de exemplaren in de lijst en handel met de hand.}}',
    eo: '{n, plural, one {# signalita linio restas sen malneto kaj sen malakcepto: vidu ĝiajn ekzemplerojn en la listo kaj agu permane.} other {# signalitaj linioj restas sen malneto kaj sen malakcepto: vidu iliajn ekzemplerojn en la listo kaj agu permane.}}',
    el: '{n, plural, one {# επισημασμένη γραμμή μένει χωρίς πρόχειρο και χωρίς απόρριψη: δες τα αντίτυπά της στη λίστα και κάνε την κίνηση με το χέρι.} other {# επισημασμένες γραμμές μένουν χωρίς πρόχειρο και χωρίς απόρριψη: δες τα αντίτυπά τους στη λίστα και κάνε την κίνηση με το χέρι.}}',
  },
  // ── rapport de révision ──
  'review.report.itemsSetAside': {
    fr: 'Exemplaires du fichier écartés', 'pt-BR': 'Exemplares do arquivo deixados de lado', en: 'Copies in the file set aside',
    es: 'Ejemplares del archivo descartados', ca: 'Exemplars del fitxer descartats', it: 'Esemplari del file scartati',
    de: 'Zurückgestellte Exemplare der Datei', nl: 'Terzijde gelegde exemplaren uit het bestand',
    eo: 'Flankenmetitaj ekzempleroj de la dosiero', el: 'Αντίτυπα του αρχείου που παραμερίστηκαν',
  },
  'review.report.itemsSetAside.summary': {
    fr: '{count, plural, one {# exemplaire du fichier écarté} other {# exemplaires du fichier écartés}} ({rows, plural, one {# ligne} other {# lignes}}) : aucun brouillon pour eux, rien n’est écrit sur l’existant.',
    'pt-BR': '{count, plural, one {# exemplar do arquivo deixado de lado} other {# exemplares do arquivo deixados de lado}} ({rows, plural, one {# linha} other {# linhas}}): nenhum rascunho para eles, nada é escrito no que já existe.',
    en: '{count, plural, one {# copy in the file set aside} other {# copies in the file set aside}} ({rows, plural, one {# row} other {# rows}}): no draft for them, nothing is written over what exists.',
    es: '{count, plural, one {# ejemplar del archivo descartado} other {# ejemplares del archivo descartados}} ({rows, plural, one {# fila} other {# filas}}): ningún borrador para ellos, no se escribe nada sobre lo existente.',
    ca: '{count, plural, one {# exemplar del fitxer descartat} other {# exemplars del fitxer descartats}} ({rows, plural, one {# fila} other {# files}}): cap esborrany per a ells, no s’escriu res sobre el que ja hi ha.',
    it: '{count, plural, one {# esemplare del file scartato} other {# esemplari del file scartati}} ({rows, plural, one {# riga} other {# righe}}): nessuna bozza per loro, non si scrive nulla sull’esistente.',
    de: '{count, plural, one {# Exemplar der Datei zurückgestellt} other {# Exemplare der Datei zurückgestellt}} ({rows, plural, one {# Zeile} other {# Zeilen}}): kein Entwurf für sie, am Bestehenden wird nichts geschrieben.',
    nl: '{count, plural, one {# exemplaar uit het bestand terzijde gelegd} other {# exemplaren uit het bestand terzijde gelegd}} ({rows, plural, one {# rij} other {# rijen}}): geen concept voor hen, er wordt niets over het bestaande geschreven.',
    eo: '{count, plural, one {# ekzemplero de la dosiero flankenmetita} other {# ekzempleroj de la dosiero flankenmetitaj}} ({rows, plural, one {# linio} other {# linioj}}): neniu malneto por ili, nenio estas skribita sur la ekzistanta.',
    el: '{count, plural, one {# αντίτυπο του αρχείου παραμερίστηκε} other {# αντίτυπα του αρχείου παραμερίστηκαν}} ({rows, plural, one {# γραμμή} other {# γραμμές}}): κανένα πρόχειρο γι’ αυτά, τίποτα δεν γράφεται πάνω στα υπάρχοντα.',
  },
  'review.report.itemsSetAside.tombo': {
    fr: 'dans AnarBib : {tombo}', 'pt-BR': 'no AnarBib: {tombo}', en: 'in AnarBib: {tombo}', es: 'en AnarBib: {tombo}',
    ca: 'a AnarBib: {tombo}', it: 'in AnarBib, inventario {tombo}', de: 'in AnarBib, Inventarnummer {tombo}', nl: 'in AnarBib, inventarisnummer {tombo}',
    eo: 'en AnarBib: {tombo}', el: 'στο AnarBib: {tombo}',
  },
  // ── refus traduits ──
  'error.import.item_trace_reserved': {
    fr: 'La trace d’import d’un exemplaire (identifiant d’origine, source, run) ne se pose pas à la main : elle vient de la promotion ou de « Rapprocher ».',
    'pt-BR': 'O rastro de importação de um exemplar (identificador de origem, fonte, execução) não se põe à mão: ele vem da promoção ou de «Aproximar».',
    en: 'A copy’s import trace (source identifier, source, run) is not set by hand: it comes from promotion or from “Reconcile”.',
    es: 'El rastro de importación de un ejemplar (identificador de origen, fuente, ejecución) no se pone a mano: viene de la promoción o de «Aproximar».',
    ca: 'El rastre d’importació d’un exemplar (identificador d’origen, font, execució) no es posa a mà: ve de la promoció o d’«Aproximar».',
    it: 'La traccia d’importazione di un esemplare (identificativo d’origine, fonte, esecuzione) non si mette a mano: viene dalla promozione o da «Riconcilia».',
    de: 'Die Importspur eines Exemplars (Herkunftskennung, Quelle, Lauf) wird nicht von Hand gesetzt: Sie kommt aus der Übernahme oder aus „Abgleichen“.',
    nl: 'Het importspoor van een exemplaar (herkomst-ID, bron, run) zet je niet met de hand: het komt uit de promotie of uit „Koppelen”.',
    eo: 'La importa spuro de ekzemplero (deveno-identigilo, fonto, rulo) ne estas metita permane: ĝi venas de la promocio aŭ de «Proksimigi».',
    el: 'Το ίχνος εισαγωγής ενός αντιτύπου (αναγνωριστικό προέλευσης, πηγή, εκτέλεση) δεν μπαίνει με το χέρι: προέρχεται από την προώθηση ή την «Αντιστοίχιση».',
  },
  'error.import.item_restore_code_taken': {
    fr: 'Cet exemplaire ne sort pas de la corbeille : son code-barres d’origine (ou son identifiant d’origine) est désormais porté par un autre exemplaire ou un autre brouillon de ta bibliothèque.',
    'pt-BR': 'Este exemplar não sai da lixeira: o código de barras de origem dele (ou o identificador de origem) agora pertence a outro exemplar ou outro rascunho da sua biblioteca.',
    en: 'This copy cannot leave the trash: its original barcode (or source identifier) is now carried by another copy or draft in your library.',
    es: 'Este ejemplar no sale de la papelera: su código de barras de origen (o su identificador de origen) lo lleva ahora otro ejemplar u otro borrador de tu biblioteca.',
    ca: 'Aquest exemplar no surt de la paperera: el seu codi de barres d’origen (o el seu identificador d’origen) ara el porta un altre exemplar o un altre esborrany de la teva biblioteca.',
    it: 'Questo esemplare non esce dal cestino: il suo codice a barre d’origine (o il suo identificativo d’origine) è ora portato da un altro esemplare o da un’altra bozza della tua biblioteca.',
    de: 'Dieses Exemplar kann nicht aus dem Papierkorb: Sein ursprünglicher Barcode (oder seine Herkunftskennung) gehört jetzt einem anderen Exemplar oder Entwurf deiner Bibliothek.',
    nl: 'Dit exemplaar kan niet uit de prullenbak: de oorspronkelijke streepjescode (of herkomst-ID) staat nu op een ander exemplaar of concept van je bibliotheek.',
    eo: 'Ĉi tiu ekzemplero ne eliras el la rubujo: ĝian originan strekkodon (aŭ deveno-identigilon) nun portas alia ekzemplero aŭ malneto de via biblioteko.',
    el: 'Αυτό το αντίτυπο δεν βγαίνει από τον κάδο: τον αρχικό γραμμωτό κώδικά του (ή το αναγνωριστικό προέλευσης) τον έχει πλέον άλλο αντίτυπο ή πρόχειρο της βιβλιοθήκης σου.',
  },
  'error.publish.source_item_id_taken': {
    fr: 'Un exemplaire de cette bibliothèque porte déjà cet identifiant d’origine (expl_id) : publication refusée.',
    'pt-BR': 'Um exemplar desta biblioteca já tem este identificador de origem (expl_id): publicação recusada.',
    en: 'A copy in this library already carries this source identifier (expl_id): publication refused.',
    es: 'Un ejemplar de esta biblioteca ya lleva este identificador de origen (expl_id): publicación rechazada.',
    ca: 'Un exemplar d’aquesta biblioteca ja porta aquest identificador d’origen (expl_id): publicació refusada.',
    it: 'Un esemplare di questa biblioteca porta già questo identificativo d’origine (expl_id): pubblicazione rifiutata.',
    de: 'Ein Exemplar dieser Bibliothek trägt bereits diese Herkunftskennung (expl_id): Veröffentlichung abgelehnt.',
    nl: 'Een exemplaar van deze bibliotheek heeft al deze herkomst-ID (expl_id): publicatie geweigerd.',
    eo: 'Ekzemplero de ĉi tiu biblioteko jam portas ĉi tiun deveno-identigilon (expl_id): publikigo rifuzita.',
    el: 'Ένα αντίτυπο αυτής της βιβλιοθήκης έχει ήδη αυτό το αναγνωριστικό προέλευσης (expl_id): η δημοσίευση απορρίφθηκε.',
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
