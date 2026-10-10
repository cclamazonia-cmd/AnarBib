/* ===========================================================================
 * i18n-add-atelier-erreurs.cjs — E36 (10/10/2026)
 * Les refus de l'Atelier des autorités disent pourquoi : 25 clés × 10 locales.
 * `localizeError` ne traduit que les HINT en `error.*` : les anciens HINT
 * `atelier.error.*` deviennent `error.atelier.*` dans les RPC (migration E36).
 * Idempotent, source des clés.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const CLES = {
  'error.atelier.reserved': {
    fr: 'L’Atelier des autorités est réservé aux équipes des bibliothèques, aux contributeurs du réseau et à l’administration. Connecte-toi avec un compte d’équipe.',
    'pt-BR': 'O Ateliê das autoridades é reservado às equipes das bibliotecas, às pessoas contribuidoras da rede e à administração. Entre com uma conta de equipe.',
    en: 'The authorities workshop is reserved for library teams, network contributors and the administration. Sign in with a team account.',
    es: 'El Taller de autoridades está reservado a los equipos de las bibliotecas, a las personas contribuidoras de la red y a la administración. Conéctate con una cuenta de equipo.',
    ca: 'El Taller d’autoritats està reservat als equips de les biblioteques, a les persones contribuïdores de la xarxa i a l’administració. Connecta’t amb un compte d’equip.',
    it: 'L’Atelier delle autorità è riservato ai gruppi delle biblioteche, alle persone che contribuiscono alla rete e all’amministrazione. Accedi con un account di gruppo.',
    de: 'Die Werkstatt der Normdaten ist den Bibliotheksteams, den Beitragenden des Netzwerks und der Verwaltung vorbehalten. Melde dich mit einem Teamkonto an.',
    nl: 'Het atelier van de autoriteiten is voorbehouden aan de bibliotheekteams, de bijdragers van het netwerk en het beheer. Meld je aan met een teamaccount.',
    eo: 'La Ateliero de aŭtoritatoj estas rezervita al la teamoj de la bibliotekoj, al la kontribuantoj de la reto kaj al la administrado. Ensalutu per teama konto.',
    el: 'Το Εργαστήριο καθιερωμένων όρων προορίζεται για τις ομάδες των βιβλιοθηκών, τα συνεισφέροντα μέλη του δικτύου και τη διαχείριση. Συνδέσου με λογαριασμό ομάδας.',
  },
  'error.atelier.reservedStaff': {
    fr: 'La file de vérification est réservée aux équipes des bibliothèques.',
    'pt-BR': 'A fila de verificação é reservada às equipes das bibliotecas.',
    en: 'The review queue is reserved for library teams.',
    es: 'La cola de verificación está reservada a los equipos de las bibliotecas.',
    ca: 'La cua de verificació està reservada als equips de les biblioteques.',
    it: 'La coda di verifica è riservata ai gruppi delle biblioteche.',
    de: 'Die Prüfwarteschlange ist den Bibliotheksteams vorbehalten.',
    nl: 'De controlewachtrij is voorbehouden aan de bibliotheekteams.',
    eo: 'La kontrolvico estas rezervita al la teamoj de la bibliotekoj.',
    el: 'Η ουρά ελέγχου προορίζεται για τις ομάδες των βιβλιοθηκών.',
  },
  'error.atelier.notContributor': {
    fr: 'Proposer est réservé aux équipes des bibliothèques et aux contributeurs du réseau.',
    'pt-BR': 'Propor é reservado às equipes das bibliotecas e às pessoas contribuidoras da rede.',
    en: 'Proposing is reserved for library teams and network contributors.',
    es: 'Proponer está reservado a los equipos de las bibliotecas y a las personas contribuidoras de la red.',
    ca: 'Proposar està reservat als equips de les biblioteques i a les persones contribuïdores de la xarxa.',
    it: 'Proporre è riservato ai gruppi delle biblioteche e alle persone che contribuiscono alla rete.',
    de: 'Vorschlagen ist den Bibliotheksteams und den Beitragenden des Netzwerks vorbehalten.',
    nl: 'Voorstellen is voorbehouden aan de bibliotheekteams en de bijdragers van het netwerk.',
    eo: 'Proponi estas rezervita al la teamoj de la bibliotekoj kaj al la kontribuantoj de la reto.',
    el: 'Οι προτάσεις επιτρέπονται μόνο στις ομάδες των βιβλιοθηκών και στα συνεισφέροντα μέλη του δικτύου.',
  },
  'error.atelier.notStaff': {
    fr: 'Appliquer une proposition est réservé aux équipes des bibliothèques.',
    'pt-BR': 'Aplicar uma proposta é reservado às equipes das bibliotecas.',
    en: 'Applying a proposal is reserved for library teams.',
    es: 'Aplicar una propuesta está reservado a los equipos de las bibliotecas.',
    ca: 'Aplicar una proposta està reservat als equips de les biblioteques.',
    it: 'Applicare una proposta è riservato ai gruppi delle biblioteche.',
    de: 'Das Anwenden eines Vorschlags ist den Bibliotheksteams vorbehalten.',
    nl: 'Een voorstel toepassen is voorbehouden aan de bibliotheekteams.',
    eo: 'Apliki proponon estas rezervita al la teamoj de la bibliotekoj.',
    el: 'Η εφαρμογή μιας πρότασης επιτρέπεται μόνο στις ομάδες των βιβλιοθηκών.',
  },
  'error.atelier.notCoordenador': {
    fr: 'Objecter se fait au nom d’une bibliothèque dont tu coordonnes l’équipe.',
    'pt-BR': 'Objetar se faz em nome de uma biblioteca cuja equipe você coordena.',
    en: 'An objection is made on behalf of a library whose team you coordinate.',
    es: 'Objetar se hace en nombre de una biblioteca cuyo equipo coordinas.',
    ca: 'Objectar es fa en nom d’una biblioteca l’equip de la qual coordines.',
    it: 'Un’obiezione si fa a nome di una biblioteca di cui coordini il gruppo.',
    de: 'Ein Einspruch wird im Namen einer Bibliothek erhoben, deren Team du koordinierst.',
    nl: 'Bezwaar maak je namens een bibliotheek waarvan je het team coördineert.',
    eo: 'Oni obĵetas nome de biblioteko, kies teamon vi kunordigas.',
    el: 'Η ένσταση γίνεται εξ ονόματος μιας βιβλιοθήκης της οποίας συντονίζεις την ομάδα.',
  },
  'error.atelier.notUsingAuthority': {
    fr: 'Cette bibliothèque n’utilise pas cette autorité : elle ne peut pas objecter.',
    'pt-BR': 'Esta biblioteca não usa esta autoridade: ela não pode objetar.',
    en: 'This library does not use this authority: it cannot object.',
    es: 'Esta biblioteca no usa esta autoridad: no puede objetar.',
    ca: 'Aquesta biblioteca no fa servir aquesta autoritat: no pot objectar.',
    it: 'Questa biblioteca non usa questa autorità: non può obiettare.',
    de: 'Diese Bibliothek verwendet diesen Normdatensatz nicht: Sie kann keinen Einspruch erheben.',
    nl: 'Deze bibliotheek gebruikt deze autoriteit niet: ze kan geen bezwaar maken.',
    eo: 'Ĉi tiu biblioteko ne uzas ĉi tiun aŭtoritaton: ĝi ne povas obĵeti.',
    el: 'Αυτή η βιβλιοθήκη δεν χρησιμοποιεί αυτόν τον καθιερωμένο όρο: δεν μπορεί να υποβάλει ένσταση.',
  },
  'error.atelier.notResolvedConsent': {
    fr: 'Cette proposition n’est pas encore au consentement acquis : attends la fin du délai, sans objection.',
    'pt-BR': 'Esta proposta ainda não está em consentimento adquirido: espere o fim do prazo, sem objeção.',
    en: 'This proposal has not reached consent yet: wait for the deadline to pass without objection.',
    es: 'Esta propuesta aún no está en consentimiento adquirido: espera el fin del plazo, sin objeción.',
    ca: 'Aquesta proposta encara no té el consentiment adquirit: espera el final del termini, sense objecció.',
    it: 'Questa proposta non è ancora al consenso acquisito: aspetta la fine del termine, senza obiezioni.',
    de: 'Dieser Vorschlag hat noch keine Zustimmung erreicht: Warte das Ende der Frist ohne Einspruch ab.',
    nl: 'Dit voorstel heeft nog geen verworven instemming: wacht tot de termijn zonder bezwaar verstrijkt.',
    eo: 'Ĉi tiu propono ankoraŭ ne atingis konsenton: atendu la finon de la limdato, sen obĵeto.',
    el: 'Αυτή η πρόταση δεν έχει ακόμη αποκτήσει συναίνεση: περίμενε να λήξει η προθεσμία χωρίς ένσταση.',
  },
  'error.atelier.applyKindDeferred': {
    fr: 'Ce type de proposition ne s’applique pas encore depuis l’Atelier : il est noté, l’équipe l’appliquera par migration.',
    'pt-BR': 'Este tipo de proposta ainda não se aplica a partir do Ateliê: fica anotado, a equipe o aplicará por migração.',
    en: 'This kind of proposal cannot be applied from the workshop yet: it is noted, the team will apply it by migration.',
    es: 'Este tipo de propuesta aún no se aplica desde el Taller: queda anotado, el equipo lo aplicará por migración.',
    ca: 'Aquest tipus de proposta encara no s’aplica des del Taller: queda anotat, l’equip l’aplicarà per migració.',
    it: 'Questo tipo di proposta non si applica ancora dall’Atelier: è annotato, il gruppo lo applicherà per migrazione.',
    de: 'Diese Art von Vorschlag kann noch nicht aus der Werkstatt angewendet werden: Sie ist vermerkt, das Team wendet sie per Migration an.',
    nl: 'Dit soort voorstel kan nog niet vanuit het atelier worden toegepast: het is genoteerd, het team past het toe via een migratie.',
    eo: 'Ĉi tiu speco de propono ankoraŭ ne aplikeblas el la Ateliero: ĝi estas notita, la teamo aplikos ĝin per migrado.',
    el: 'Αυτό το είδος πρότασης δεν εφαρμόζεται ακόμη από το Εργαστήριο: σημειώνεται και η ομάδα θα το εφαρμόσει με μετανάστευση.',
  },
  'error.atelier.scissionAuthorOnly': {
    fr: 'Une scission ne vaut que pour une personne.',
    'pt-BR': 'Uma cisão só vale para uma pessoa.',
    en: 'A split only applies to a person.',
    es: 'Una escisión solo vale para una persona.',
    ca: 'Una escissió només val per a una persona.',
    it: 'Una scissione vale solo per una persona.',
    de: 'Eine Aufteilung gilt nur für eine Person.',
    nl: 'Een splitsing geldt alleen voor een persoon.',
    eo: 'Disigo validas nur por persono.',
    el: 'Η διάσπαση ισχύει μόνο για πρόσωπο.',
  },
  'error.atelier.scissionParts': {
    fr: 'Une scission demande au moins deux parts.',
    'pt-BR': 'Uma cisão pede ao menos duas partes.',
    en: 'A split needs at least two parts.',
    es: 'Una escisión necesita al menos dos partes.',
    ca: 'Una escissió necessita almenys dues parts.',
    it: 'Una scissione richiede almeno due parti.',
    de: 'Eine Aufteilung braucht mindestens zwei Teile.',
    nl: 'Een splitsing vraagt minstens twee delen.',
    eo: 'Disigo postulas almenaŭ du partojn.',
    el: 'Η διάσπαση χρειάζεται τουλάχιστον δύο μέρη.',
  },
  'error.atelier.scissionPartIncomplete': {
    fr: 'Chaque part d’une scission porte un nom retenu et une forme de tri.',
    'pt-BR': 'Cada parte de uma cisão traz um nome preferido e uma forma de ordenação.',
    en: 'Each part of a split carries a preferred name and a sort form.',
    es: 'Cada parte de una escisión lleva un nombre preferido y una forma de ordenación.',
    ca: 'Cada part d’una escissió porta un nom preferit i una forma d’ordenació.',
    it: 'Ogni parte di una scissione porta un nome preferito e una forma di ordinamento.',
    de: 'Jeder Teil einer Aufteilung trägt einen bevorzugten Namen und eine Sortierform.',
    nl: 'Elk deel van een splitsing draagt een voorkeursnaam en een sorteervorm.',
    eo: 'Ĉiu parto de disigo portas preferatan nomon kaj ordigan formon.',
    el: 'Κάθε μέρος μιας διάσπασης φέρει ένα προτιμώμενο όνομα και μια μορφή ταξινόμησης.',
  },
  'error.atelier.scissionBadType': {
    fr: 'Le type d’une part de scission est inconnu.',
    'pt-BR': 'O tipo de uma parte da cisão é desconhecido.',
    en: 'The type of a split part is unknown.',
    es: 'El tipo de una parte de la escisión es desconocido.',
    ca: 'El tipus d’una part de l’escissió és desconegut.',
    it: 'Il tipo di una parte della scissione è sconosciuto.',
    de: 'Der Typ eines Aufteilungsteils ist unbekannt.',
    nl: 'Het type van een splitsingsdeel is onbekend.',
    eo: 'La tipo de disiga parto estas nekonata.',
    el: 'Ο τύπος ενός μέρους της διάσπασης είναι άγνωστος.',
  },
  'error.atelier.scissionPartExists': {
    fr: 'Une part de la scission porte le nom d’une autorité qui existe déjà : propose plutôt une fusion ou un rattachement.',
    'pt-BR': 'Uma parte da cisão traz o nome de uma autoridade que já existe: proponha antes uma fusão ou um vínculo.',
    en: 'A split part carries the name of an authority that already exists: propose a merge or a link instead.',
    es: 'Una parte de la escisión lleva el nombre de una autoridad que ya existe: propón más bien una fusión o una vinculación.',
    ca: 'Una part de l’escissió porta el nom d’una autoritat que ja existeix: proposa més aviat una fusió o una vinculació.',
    it: 'Una parte della scissione porta il nome di un’autorità che esiste già: proponi piuttosto una fusione o un collegamento.',
    de: 'Ein Aufteilungsteil trägt den Namen eines bereits vorhandenen Normdatensatzes: Schlage stattdessen eine Zusammenführung oder eine Verknüpfung vor.',
    nl: 'Een splitsingsdeel draagt de naam van een autoriteit die al bestaat: stel liever een samenvoeging of een koppeling voor.',
    eo: 'Disiga parto portas la nomon de jam ekzistanta aŭtoritato: prefere proponu kunfandon aŭ ligon.',
    el: 'Ένα μέρος της διάσπασης φέρει το όνομα καθιερωμένου όρου που υπάρχει ήδη: πρότεινε καλύτερα συγχώνευση ή σύνδεση.',
  },
  'error.atelier.splitTargetChanged': {
    fr: 'L’autorité à scinder a changé depuis la proposition : relis-la avant d’appliquer.',
    'pt-BR': 'A autoridade a cindir mudou desde a proposta: releia antes de aplicar.',
    en: 'The authority to split has changed since the proposal: review it before applying.',
    es: 'La autoridad a escindir cambió desde la propuesta: reléela antes de aplicar.',
    ca: 'L’autoritat a escindir ha canviat des de la proposta: rellegeix-la abans d’aplicar.',
    it: 'L’autorità da scindere è cambiata dopo la proposta: rileggila prima di applicare.',
    de: 'Der aufzuteilende Normdatensatz hat sich seit dem Vorschlag geändert: Prüfe ihn vor dem Anwenden.',
    nl: 'De te splitsen autoriteit is veranderd sinds het voorstel: lees ze na voor je toepast.',
    eo: 'La disigenda aŭtoritato ŝanĝiĝis post la propono: relegu ĝin antaŭ ol apliki.',
    el: 'Ο καθιερωμένος όρος προς διάσπαση άλλαξε από την πρόταση: ξαναδιάβασέ τον πριν την εφαρμογή.',
  },
  'error.atelier.workNotFound': {
    fr: 'Cette œuvre n’existe pas.', 'pt-BR': 'Esta obra não existe.', en: 'This work does not exist.', es: 'Esta obra no existe.', ca: 'Aquesta obra no existeix.',
    it: 'Quest’opera non esiste.', de: 'Dieses Werk gibt es nicht.', nl: 'Dit werk bestaat niet.', eo: 'Ĉi tiu verko ne ekzistas.', el: 'Αυτό το έργο δεν υπάρχει.',
  },
  'error.atelier.workKind': {
    fr: 'Ce type de proposition ne vaut pas pour une œuvre.', 'pt-BR': 'Este tipo de proposta não vale para uma obra.', en: 'This kind of proposal does not apply to a work.',
    es: 'Este tipo de propuesta no vale para una obra.', ca: 'Aquest tipus de proposta no val per a una obra.', it: 'Questo tipo di proposta non vale per un’opera.',
    de: 'Diese Art von Vorschlag gilt nicht für ein Werk.', nl: 'Dit soort voorstel geldt niet voor een werk.', eo: 'Ĉi tiu speco de propono ne validas por verko.', el: 'Αυτό το είδος πρότασης δεν ισχύει για έργο.',
  },
  'error.atelier.workLang': {
    fr: 'Indique la langue du titre, parmi les locales du réseau.', 'pt-BR': 'Indique a língua do título, entre as locales da rede.', en: 'Give the language of the title, among the network locales.',
    es: 'Indica la lengua del título, entre las locales de la red.', ca: 'Indica la llengua del títol, entre les locales de la xarxa.', it: 'Indica la lingua del titolo, tra le locali della rete.',
    de: 'Gib die Sprache des Titels an, aus den Sprachen des Netzwerks.', nl: 'Geef de taal van de titel op, uit de talen van het netwerk.', eo: 'Indiku la lingvon de la titolo, el la lokaĵoj de la reto.', el: 'Δώσε τη γλώσσα του τίτλου, από τις γλώσσες του δικτύου.',
  },
  'error.atelier.workTitle': {
    fr: 'Le titre proposé est vide ou identique à celui de l’œuvre.', 'pt-BR': 'O título proposto está vazio ou é igual ao da obra.', en: 'The proposed title is empty or identical to the work’s.',
    es: 'El título propuesto está vacío o es idéntico al de la obra.', ca: 'El títol proposat és buit o idèntic al de l’obra.', it: 'Il titolo proposto è vuoto o identico a quello dell’opera.',
    de: 'Der vorgeschlagene Titel ist leer oder mit dem des Werks identisch.', nl: 'De voorgestelde titel is leeg of identiek aan die van het werk.', eo: 'La proponita titolo estas malplena aŭ identa al tiu de la verko.', el: 'Ο προτεινόμενος τίτλος είναι κενός ή ίδιος με του έργου.',
  },
  'error.atelier.workMergeTarget': {
    fr: 'Une fusion d’œuvres demande une œuvre canonique, différente de celle qui est absorbée.', 'pt-BR': 'Uma fusão de obras pede uma obra canônica, diferente da absorvida.', en: 'Merging works needs a canonical work, different from the one being absorbed.',
    es: 'Una fusión de obras necesita una obra canónica, distinta de la absorbida.', ca: 'Una fusió d’obres necessita una obra canònica, diferent de l’absorbida.', it: 'Una fusione di opere richiede un’opera canonica, diversa da quella assorbita.',
    de: 'Eine Zusammenführung von Werken braucht ein kanonisches Werk, verschieden vom aufgenommenen.', nl: 'Een samenvoeging van werken vraagt een canoniek werk, verschillend van het opgenomen werk.', eo: 'Kunfando de verkoj postulas kanonan verkon, malsaman de la absorbita.', el: 'Η συγχώνευση έργων χρειάζεται ένα κανονικό έργο, διαφορετικό από αυτό που απορροφάται.',
  },
  'error.atelier.workNotSame': {
    fr: 'Les deux œuvres ne sont pas de même nature : elles ne se fusionnent pas.', 'pt-BR': 'As duas obras não são da mesma natureza: não se fundem.', en: 'The two works are not of the same kind: they cannot be merged.',
    es: 'Las dos obras no son de la misma naturaleza: no se fusionan.', ca: 'Les dues obres no són de la mateixa natura: no es fusionen.', it: 'Le due opere non sono della stessa natura: non si fondono.',
    de: 'Die beiden Werke sind nicht von derselben Art: Sie lassen sich nicht zusammenführen.', nl: 'De twee werken zijn niet van dezelfde aard: ze kunnen niet samengevoegd worden.', eo: 'La du verkoj ne estas samspecaj: ili ne kunfandiĝas.', el: 'Τα δύο έργα δεν είναι της ίδιας φύσης: δεν συγχωνεύονται.',
  },
  'error.atelier.workBook': {
    fr: 'Indique la notice à rattacher à l’œuvre.', 'pt-BR': 'Indique a notícia a vincular à obra.', en: 'Give the record to attach to the work.',
    es: 'Indica la noticia que se vinculará a la obra.', ca: 'Indica la notícia que cal vincular a l’obra.', it: 'Indica la notizia da collegare all’opera.',
    de: 'Gib den Datensatz an, der dem Werk zugeordnet wird.', nl: 'Geef de beschrijving op die aan het werk gekoppeld wordt.', eo: 'Indiku la registron ligotan al la verko.', el: 'Δώσε την εγγραφή που θα συνδεθεί με το έργο.',
  },
  'error.atelier.workBookSame': {
    fr: 'Cette notice est déjà rattachée à cette œuvre.', 'pt-BR': 'Esta notícia já está vinculada a esta obra.', en: 'This record is already attached to this work.',
    es: 'Esta noticia ya está vinculada a esta obra.', ca: 'Aquesta notícia ja està vinculada a aquesta obra.', it: 'Questa notizia è già collegata a quest’opera.',
    de: 'Dieser Datensatz ist diesem Werk bereits zugeordnet.', nl: 'Deze beschrijving is al aan dit werk gekoppeld.', eo: 'Ĉi tiu registro jam estas ligita al ĉi tiu verko.', el: 'Αυτή η εγγραφή είναι ήδη συνδεδεμένη με αυτό το έργο.',
  },
  'error.atelier.workTomes': {
    fr: 'Les tomes demandent au moins deux notices, chacune avec son rang.', 'pt-BR': 'Os tomos pedem ao menos duas notícias, cada uma com sua ordem.', en: 'Volumes need at least two records, each with its rank.',
    es: 'Los tomos necesitan al menos dos noticias, cada una con su orden.', ca: 'Els toms necessiten almenys dues notícies, cadascuna amb el seu ordre.', it: 'I tomi richiedono almeno due notizie, ciascuna con il suo ordine.',
    de: 'Bände brauchen mindestens zwei Datensätze, jeder mit seiner Nummer.', nl: 'Delen vragen minstens twee beschrijvingen, elk met hun volgnummer.', eo: 'Volumoj postulas almenaŭ du registrojn, ĉiu kun sia rango.', el: 'Οι τόμοι χρειάζονται τουλάχιστον δύο εγγραφές, καθεμία με τη σειρά της.',
  },
  'error.atelier.workPartBooks': {
    fr: 'Chaque part d’une scission d’œuvre reprend au moins une notice.', 'pt-BR': 'Cada parte de uma cisão de obra leva ao menos uma notícia.', en: 'Each part of a work split takes at least one record.',
    es: 'Cada parte de una escisión de obra se lleva al menos una noticia.', ca: 'Cada part d’una escissió d’obra s’emporta almenys una notícia.', it: 'Ogni parte di una scissione d’opera prende almeno una notizia.',
    de: 'Jeder Teil einer Werkaufteilung übernimmt mindestens einen Datensatz.', nl: 'Elk deel van een werksplitsing neemt minstens één beschrijving mee.', eo: 'Ĉiu parto de verka disigo prenas almenaŭ unu registron.', el: 'Κάθε μέρος μιας διάσπασης έργου παίρνει τουλάχιστον μία εγγραφή.',
  },
  'error.atelier.scissionDuplicateParts': {
    fr: 'Deux parts de la scission portent le même nom.',
    'pt-BR': 'Duas partes da cisão trazem o mesmo nome.',
    en: 'Two split parts carry the same name.',
    es: 'Dos partes de la escisión llevan el mismo nombre.',
    ca: 'Dues parts de l’escissió porten el mateix nom.',
    it: 'Due parti della scissione portano lo stesso nome.',
    de: 'Zwei Aufteilungsteile tragen denselben Namen.',
    nl: 'Twee splitsingsdelen dragen dezelfde naam.',
    eo: 'Du disigaj partoj portas la saman nomon.',
    el: 'Δύο μέρη της διάσπασης φέρουν το ίδιο όνομα.',
  },
};
const ligneDe = (cle) => new RegExp('^  ' + JSON.stringify(cle).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ': (".*?")(,?)$', 'm');
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let ajoutees = 0, corrigees = 0;
  for (const [cle, valeurs] of Object.entries(CLES)) {
    const val = valeurs[loc];
    if (!val) throw new Error(`Valeur manquante : ${cle} / ${loc}`);
    const m = content.match(ligneDe(cle));
    if (m) {
      if (JSON.parse(m[1]) !== val) { content = content.replace(m[0], '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val) + m[2]); corrigees++; }
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
