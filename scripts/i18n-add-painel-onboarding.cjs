/* ===========================================================================
 * i18n-add-painel-onboarding.cjs
 * Ajoute les clés de la prise en main du Painel (ONBO-Q4) aux 10 locales.
 * Méthode sûre (doctrine anarbib-i18n) : insertion purement textuelle avant le
 * `}` final, idempotente. Indentation 2 espaces, LF, UTF-8 sans BOM.
 * Auteur  : Xavier (AnarBib)
 * Session : Onboarding — prise en main du Painel
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'panel.onboarding.replay';

// key -> { locale: value }
const KEYS = {
  'panel.onboarding.replay': {
    ca: 'Refer la visita guiada', de: 'Geführte Tour wiederholen', el: 'Επανάληψη της ξενάγησης',
    en: 'Replay the guided tour', eo: 'Refari la gviditan viziton', es: 'Rehacer la visita guiada',
    fr: 'Refaire la visite guidée', it: 'Rifare la visita guidata', nl: 'De rondleiding opnieuw doen',
    'pt-BR': 'Refazer a visita guiada',
  },
  'panel.onboarding.tour.stepCounter': {
    ca: 'Etapa {current} / {total}', de: 'Schritt {current} / {total}', el: 'Βήμα {current} / {total}',
    en: 'Step {current} / {total}', eo: 'Paŝo {current} / {total}', es: 'Etapa {current} / {total}',
    fr: 'Étape {current} / {total}', it: 'Passo {current} / {total}', nl: 'Stap {current} / {total}',
    'pt-BR': 'Etapa {current} / {total}',
  },
  'panel.onboarding.tour.skip': {
    ca: 'Ometre', de: 'Überspringen', el: 'Παράλειψη', en: 'Skip', eo: 'Preterlasi', es: 'Saltar',
    fr: 'Passer', it: 'Salta', nl: 'Overslaan', 'pt-BR': 'Pular',
  },
  'panel.onboarding.tour.prev': {
    ca: 'Anterior', de: 'Zurück', el: 'Προηγούμενο', en: 'Previous', eo: 'Antaŭa', es: 'Anterior',
    fr: 'Précédent', it: 'Precedente', nl: 'Vorige', 'pt-BR': 'Anterior',
  },
  'panel.onboarding.tour.next': {
    ca: 'Següent', de: 'Weiter', el: 'Επόμενο', en: 'Next', eo: 'Sekva', es: 'Siguiente',
    fr: 'Suivant', it: 'Avanti', nl: 'Volgende', 'pt-BR': 'Próximo',
  },
  'panel.onboarding.tour.finish': {
    ca: 'Finalitzar', de: 'Abschließen', el: 'Ολοκλήρωση', en: 'Finish', eo: 'Fini', es: 'Finalizar',
    fr: 'Terminer', it: 'Concludi', nl: 'Afronden', 'pt-BR': 'Concluir',
  },
  'panel.onboarding.tour.dailyWork.title': {
    ca: 'Comença sempre aquí', de: 'Beginne immer hier', el: 'Ξεκίνα πάντα από εδώ',
    en: 'Always start here', eo: 'Ĉiam komencu ĉi tie', es: 'Empieza siempre aquí',
    fr: 'Commence toujours ici', it: 'Comincia sempre da qui', nl: 'Begin altijd hier',
    'pt-BR': 'Comece sempre aqui',
  },
  'panel.onboarding.tour.dailyWork.text': {
    ca: '« Treball del dia » resumeix el que avui necessita de tu: retards, reserves i consultes pendents, tasques internes. És el teu punt de partida.',
    de: '« Tagesarbeit » fasst zusammen, was heute deine Aufmerksamkeit braucht: Überfälligkeiten, offene Reservierungen und Einsichtnahmen, interne Aufgaben. Dein Ausgangspunkt.',
    el: 'Η « Δουλειά της ημέρας » συνοψίζει τι χρειάζεται από σένα σήμερα: καθυστερήσεις, εκκρεμείς κρατήσεις και επιτόπιες αναγνώσεις, εσωτερικές εργασίες. Είναι το σημείο εκκίνησής σου.',
    en: '“Daily work” sums up what needs you today: overdue items, pending reservations and on-site consultations, internal tasks. It is your starting point.',
    eo: '« Taglaboro » resumas kio bezonas vin hodiaŭ: malfruoj, pritraktotaj rezervoj kaj surlokaj konsultoj, internaj taskoj. Ĝi estas via deirpunkto.',
    es: '« Trabajo del día » resume lo que hoy te necesita: atrasos, reservas y consultas pendientes, tareas internas. Es tu punto de partida.',
    fr: '« Travail du jour » résume ce qui a besoin de toi aujourd’hui : retards, réservations et consultations en attente, tâches internes. C’est ton point de départ.',
    it: '« Lavoro del giorno » riassume ciò che oggi ha bisogno di te: ritardi, prenotazioni e consultazioni in sospeso, compiti interni. È il tuo punto di partenza.',
    nl: '« Werk van de dag » vat samen wat vandaag je aandacht vraagt: te late items, openstaande reserveringen en raadplegingen ter plaatse, interne taken. Je startpunt.',
    'pt-BR': '« Trabalho do dia » resume o que precisa de você hoje: atrasos, reservas e consultas pendentes, tarefas internas. É o seu ponto de partida.',
  },
  'panel.onboarding.tour.actions.title': {
    ca: 'Prestar i retornar', de: 'Ausleihen und zurücknehmen', el: 'Δανεισμός και επιστροφή',
    en: 'Lend and return', eo: 'Pruntedoni kaj redoni', es: 'Prestar y devolver',
    fr: 'Prêter et rendre', it: 'Prestare e restituire', nl: 'Uitlenen en innemen',
    'pt-BR': 'Emprestar e devolver',
  },
  'panel.onboarding.tour.actions.text': {
    ca: 'És a la pestanya « Accions » on registres un préstec o dones de baixa una devolució. Les accions més freqüents del dia a dia queden a mà.',
    de: 'Im Tab « Aktionen » verbuchst du eine Ausleihe oder eine Rückgabe. Die häufigsten Handgriffe des Alltags liegen griffbereit.',
    el: 'Στην καρτέλα « Ενέργειες » καταχωρείς έναν δανεισμό ή μια επιστροφή. Οι πιο συχνές καθημερινές ενέργειες είναι πρόχειρες.',
    en: 'The “Actions” tab is where you record a loan or check in a return. The most frequent everyday actions are at hand.',
    eo: 'En la langeto « Agoj » vi registras prunton aŭ enskribas redonon. La plej oftaj ĉiutagaj agoj estas je via mano.',
    es: 'En la pestaña « Acciones » registras un préstamo o das de baja una devolución. Las acciones más frecuentes del día a día quedan a mano.',
    fr: 'C’est dans l’onglet « Actions » que tu enregistres un prêt ou que tu valides un retour. Les gestes les plus fréquents du quotidien restent à portée de main.',
    it: 'È nella scheda « Azioni » che registri un prestito o una restituzione. Le azioni più frequenti del quotidiano restano a portata di mano.',
    nl: 'Op het tabblad « Acties » registreer je een uitlening of verwerk je een teruggave. De meest voorkomende dagelijkse handelingen liggen binnen handbereik.',
    'pt-BR': 'É na aba « Ações » que você registra um empréstimo ou dá baixa numa devolução. As ações mais frequentes do dia a dia ficam à mão.',
  },
  'panel.onboarding.tour.loans.title': {
    ca: 'Els préstecs en curs', de: 'Die laufenden Ausleihen', el: 'Οι τρέχοντες δανεισμοί',
    en: 'Loans in progress', eo: 'La nunaj pruntoj', es: 'Los préstamos en curso',
    fr: 'Les prêts en cours', it: 'I prestiti in corso', nl: 'De lopende uitleningen',
    'pt-BR': 'Os empréstimos em curso',
  },
  'panel.onboarding.tour.loans.text': {
    ca: 'La llista dels préstecs, amb terminis i renovacions. El que està endarrerit apareix destacat.',
    de: 'Die Liste der Ausleihen mit Fristen und Verlängerungen. Überfälliges wird hervorgehoben.',
    el: 'Η λίστα των δανεισμών, με προθεσμίες και ανανεώσεις. Ό,τι έχει καθυστερήσει εμφανίζεται τονισμένο.',
    en: 'The list of loans, with due dates and renewals. Overdue items stand out.',
    eo: 'La listo de la pruntoj, kun limdatoj kaj renovigoj. Kio malfruas, aperas elstare.',
    es: 'La lista de los préstamos, con plazos y renovaciones. Lo que está atrasado aparece destacado.',
    fr: 'La liste des prêts, avec leurs échéances et renouvellements. Ce qui est en retard ressort en évidence.',
    it: 'L’elenco dei prestiti, con scadenze e rinnovi. Ciò che è in ritardo appare in evidenza.',
    nl: 'De lijst met uitleningen, met termijnen en verlengingen. Wat te laat is, valt op.',
    'pt-BR': 'A lista dos empréstimos, com prazos e renovações. O que está em atraso aparece em destaque.',
  },
  'panel.onboarding.tour.reservations.title': {
    ca: 'La cua d’espera', de: 'Die Warteschlange', el: 'Η λίστα αναμονής', en: 'The waiting queue',
    eo: 'La atendovico', es: 'La fila de espera', fr: 'La file d’attente', it: 'La coda d’attesa',
    nl: 'De wachtrij', 'pt-BR': 'A fila de espera',
  },
  'panel.onboarding.tour.reservations.text': {
    ca: 'Les peticions de reserva i qui està esperant. Prepares la recollida i acordes l’horari amb la persona lectora.',
    de: 'Die Reservierungswünsche und wer wartet. Du bereitest die Abholung vor und stimmst die Uhrzeit mit der lesenden Person ab.',
    el: 'Τα αιτήματα κράτησης και ποιος περιμένει. Ετοιμάζεις την παραλαβή και κανονίζεις την ώρα με το άτομο που διαβάζει.',
    en: 'Reservation requests and who is waiting. You prepare the pickup and arrange the time with the reader.',
    eo: 'La rezervpetoj kaj kiu atendas. Vi pretigas la elprenon kaj interkonsentas la horon kun la leganta persono.',
    es: 'Los pedidos de reserva y quién está esperando. Preparas la entrega y acuerdas el horario con la persona lectora.',
    fr: 'Les demandes de réservation et qui attend. Tu prépares le retrait et tu conviens de l’horaire avec la personne lectrice.',
    it: 'Le richieste di prenotazione e chi è in attesa. Prepari il ritiro e concordi l’orario con la persona lettrice.',
    nl: 'De reserveringsaanvragen en wie er wacht. Je bereidt de afhaling voor en stemt het tijdstip af met de lezer.',
    'pt-BR': 'Os pedidos de reserva e quem está esperando. Você prepara a retirada e combina o horário com a pessoa leitora.',
  },
  'panel.onboarding.tour.reader.title': {
    ca: 'Tenir cura de qui llegeix', de: 'Sich um die kümmern, die lesen', el: 'Φροντίδα για όποια·ον διαβάζει',
    en: 'Caring for the people who read', eo: 'Zorgi pri tiuj, kiuj legas', es: 'Cuidar a quien lee',
    fr: 'Prendre soin de qui lit', it: 'Prendersi cura di chi legge', nl: 'Zorgen voor wie leest',
    'pt-BR': 'Cuidar de quem lê',
  },
  'panel.onboarding.tour.reader.text': {
    ca: 'Troba una persona lectora pel nom o el codi, mira el seu historial, ajusta el que calgui. Sempre disponible.',
    de: 'Finde eine lesende Person über Name oder Code, sieh dir ihren Verlauf an, passe an, was nötig ist. Immer verfügbar.',
    el: 'Βρες ένα άτομο που διαβάζει με το όνομα ή τον κωδικό, δες το ιστορικό του, ρύθμισε ό,τι χρειάζεται. Πάντα διαθέσιμο.',
    en: 'Find a reader by name or code, look at their history, adjust whatever is needed. Always available.',
    eo: 'Trovu legantan personon laŭ nomo aŭ kodo, vidu ĝian historion, alĝustigu kio necesas. Ĉiam disponebla.',
    es: 'Encuentra una persona lectora por el nombre o el código, mira su historial, ajusta lo que haga falta. Siempre disponible.',
    fr: 'Retrouve une personne lectrice par son nom ou son code, consulte son historique, ajuste ce qu’il faut. Toujours disponible.',
    it: 'Trova una persona lettrice per nome o codice, guarda la sua cronologia, regola ciò che serve. Sempre disponibile.',
    nl: 'Vind een lezer op naam of code, bekijk de geschiedenis, pas aan wat nodig is. Altijd beschikbaar.',
    'pt-BR': 'Encontre uma pessoa leitora pelo nome ou código, veja seu histórico, ajuste o que for preciso. Sempre disponível.',
  },
  'panel.onboarding.tour.history.title': {
    ca: 'La memòria de la biblioteca', de: 'Das Gedächtnis der Bibliothek', el: 'Η μνήμη της βιβλιοθήκης',
    en: 'The library’s memory', eo: 'La memoro de la biblioteko', es: 'La memoria de la biblioteca',
    fr: 'La mémoire de la bibliothèque', it: 'La memoria della biblioteca', nl: 'Het geheugen van de bibliotheek',
    'pt-BR': 'A memória da biblioteca',
  },
  'panel.onboarding.tour.history.text': {
    ca: 'Tot el que ja s’ha conclòs i arxivat queda aquí, per si necessites reobrir o consultar.',
    de: 'Alles, was bereits abgeschlossen und archiviert wurde, bleibt hier, falls du etwas wieder öffnen oder nachschlagen musst.',
    el: 'Ό,τι έχει ήδη ολοκληρωθεί και αρχειοθετηθεί μένει εδώ, αν χρειαστεί να το ανοίξεις ξανά ή να το δεις.',
    en: 'Everything already completed and archived stays here, in case you need to reopen or look something up.',
    eo: 'Ĉio jam finita kaj arkivita restas ĉi tie, se vi bezonas remalfermi aŭ konsulti.',
    es: 'Todo lo que ya se concluyó y archivó queda aquí, por si necesitas reabrir o consultar.',
    fr: 'Tout ce qui a déjà été conclu et archivé reste ici, si tu as besoin de rouvrir ou de consulter.',
    it: 'Tutto ciò che è già stato concluso e archiviato resta qui, se hai bisogno di riaprire o consultare.',
    nl: 'Alles wat al is afgerond en gearchiveerd blijft hier, mocht je iets opnieuw moeten openen of opzoeken.',
    'pt-BR': 'Tudo que já foi concluído e arquivado fica aqui, se você precisar reabrir ou consultar.',
  },
  'panel.onboarding.steps.title': {
    ca: 'Les teves primeres accions', de: 'Deine ersten Schritte', el: 'Οι πρώτες σου ενέργειες',
    en: 'Your first actions', eo: 'Viaj unuaj agoj', es: 'Tus primeras acciones',
    fr: 'Tes premières actions', it: 'Le tue prime azioni', nl: 'Je eerste acties',
    'pt-BR': 'Suas primeiras ações',
  },
  'panel.onboarding.steps.subtitle': {
    ca: 'No és un examen. Marca el que ja has fet — i deixa la resta per quan ho necessitis.',
    de: 'Das ist keine Prüfung. Hak ab, was du schon gemacht hast — und lass den Rest für später.',
    el: 'Δεν είναι εξέταση. Σημείωσε ό,τι έχεις ήδη κάνει — και άφησε τα υπόλοιπα για όταν χρειαστεί.',
    en: 'It is not an exam. Check off what you have already done — and leave the rest for when you need it.',
    eo: 'Ĝi ne estas ekzameno. Marku kion vi jam faris — kaj lasu la reston por kiam vi bezonos.',
    es: 'No es un examen. Marca lo que ya hiciste — y deja el resto para cuando lo necesites.',
    fr: 'Ce n’est pas un examen. Coche ce que tu as déjà fait — et laisse le reste pour quand tu en auras besoin.',
    it: 'Non è un esame. Spunta ciò che hai già fatto — e lascia il resto per quando servirà.',
    nl: 'Het is geen examen. Vink af wat je al hebt gedaan — en laat de rest voor wanneer je het nodig hebt.',
    'pt-BR': 'Não é um exame. Marque o que você já fez — e deixe o resto para quando precisar.',
  },
  'panel.onboarding.steps.progress': {
    ca: '{done} / {total}', de: '{done} / {total}', el: '{done} / {total}', en: '{done} / {total}',
    eo: '{done} / {total}', es: '{done} / {total}', fr: '{done} / {total}', it: '{done} / {total}',
    nl: '{done} / {total}', 'pt-BR': '{done} / {total}',
  },
  'panel.onboarding.steps.dismiss': {
    ca: 'Finalitzar i amagar', de: 'Abschließen und ausblenden', el: 'Ολοκλήρωση και απόκρυψη',
    en: 'Finish and hide', eo: 'Fini kaj kaŝi', es: 'Finalizar y ocultar', fr: 'Terminer et masquer',
    it: 'Concludi e nascondi', nl: 'Afronden en verbergen', 'pt-BR': 'Concluir e ocultar',
  },
  'panel.onboarding.step.reader.label': {
    ca: 'Trobar una persona lectora', de: 'Eine lesende Person finden', el: 'Εύρεση ατόμου που διαβάζει',
    en: 'Find a reader', eo: 'Trovi legantan personon', es: 'Encontrar una persona lectora',
    fr: 'Trouver une personne lectrice', it: 'Trovare una persona lettrice', nl: 'Een lezer vinden',
    'pt-BR': 'Encontrar uma pessoa leitora',
  },
  'panel.onboarding.step.reader.sub': {
    ca: 'Cerca pel nom o pel codi (ex. U0000030).', de: 'Suche nach Name oder Code (z. B. U0000030).',
    el: 'Αναζήτησε με το όνομα ή τον κωδικό (π.χ. U0000030).', en: 'Search by name or code (e.g. U0000030).',
    eo: 'Serĉu laŭ nomo aŭ kodo (ekz. U0000030).', es: 'Busca por el nombre o por el código (ej. U0000030).',
    fr: 'Cherche par le nom ou par le code (ex. U0000030).', it: 'Cerca per nome o per codice (es. U0000030).',
    nl: 'Zoek op naam of code (bijv. U0000030).', 'pt-BR': 'Busque pelo nome ou pelo código (ex. U0000030).',
  },
  'panel.onboarding.step.loan.label': {
    ca: 'Registrar un primer préstec', de: 'Eine erste Ausleihe verbuchen', el: 'Καταχώριση ενός πρώτου δανεισμού',
    en: 'Record a first loan', eo: 'Registri unuan prunton', es: 'Registrar un primer préstamo',
    fr: 'Enregistrer un premier prêt', it: 'Registrare un primo prestito', nl: 'Een eerste uitlening registreren',
    'pt-BR': 'Registrar um primeiro empréstimo',
  },
  'panel.onboarding.step.loan.sub': {
    ca: 'Tria la persona, escaneja o escriu la referència del document.',
    de: 'Wähle die Person, scanne oder tippe die Signatur des Dokuments.',
    el: 'Διάλεξε το άτομο, σκάναρε ή πληκτρολόγησε τον κωδικό του τεκμηρίου.',
    en: 'Choose the person, scan or type the document reference.',
    eo: 'Elektu la personon, skanu aŭ tajpu la referencon de la dokumento.',
    es: 'Elige la persona, escanea o escribe la referencia del documento.',
    fr: 'Choisis la personne, scanne ou saisis la référence du document.',
    it: 'Scegli la persona, scansiona o digita la collocazione del documento.',
    nl: 'Kies de persoon, scan of typ de referentie van het document.',
    'pt-BR': 'Escolha a pessoa, escaneie ou digite a referência do documento.',
  },
  'panel.onboarding.step.return.label': {
    ca: 'Donar de baixa una devolució', de: 'Eine Rückgabe verbuchen', el: 'Καταχώριση μιας επιστροφής',
    en: 'Check in a return', eo: 'Enskribi redonon', es: 'Dar de baja una devolución',
    fr: 'Valider un retour', it: 'Registrare una restituzione', nl: 'Een teruggave verwerken',
    'pt-BR': 'Dar baixa numa devolução',
  },
  'panel.onboarding.step.return.sub': {
    ca: 'Indica el número del préstec i confirma el retorn.',
    de: 'Gib die Ausleihnummer ein und bestätige die Rückgabe.',
    el: 'Δώσε τον αριθμό του δανεισμού και επιβεβαίωσε την επιστροφή.',
    en: 'Enter the loan number and confirm the return.',
    eo: 'Indiku la numeron de la prunto kaj konfirmu la redonon.',
    es: 'Indica el número del préstamo y confirma la devolución.',
    fr: 'Indique le numéro du prêt et confirme le retour.',
    it: 'Indica il numero del prestito e conferma la restituzione.',
    nl: 'Geef het uitleennummer op en bevestig de teruggave.',
    'pt-BR': 'Informe o número do empréstimo e confirme o retorno.',
  },
  'panel.onboarding.step.reservation.label': {
    ca: 'Preparar una reserva per a la recollida', de: 'Eine Reservierung zur Abholung vorbereiten',
    el: 'Προετοιμασία κράτησης για παραλαβή', en: 'Prepare a reservation for pickup',
    eo: 'Pretigi rezervon por elpreno', es: 'Preparar una reserva para la entrega',
    fr: 'Préparer une réservation pour le retrait', it: 'Preparare una prenotazione per il ritiro',
    nl: 'Een reservering klaarzetten voor afhaling', 'pt-BR': 'Preparar uma reserva para retirada',
  },
  'panel.onboarding.step.reservation.sub': {
    ca: 'Avisa la persona i proposa un horari de recollida.',
    de: 'Benachrichtige die Person und schlage eine Abholzeit vor.',
    el: 'Ειδοποίησε το άτομο και πρότεινε ώρα παραλαβής.',
    en: 'Notify the person and propose a pickup time.',
    eo: 'Avizu la personon kaj proponu horon por elpreno.',
    es: 'Avisa a la persona y propone un horario de entrega.',
    fr: 'Préviens la personne et propose un horaire de retrait.',
    it: 'Avvisa la persona e proponi un orario di ritiro.',
    nl: 'Laat het de persoon weten en stel een afhaaltijd voor.',
    'pt-BR': 'Avise a pessoa e proponha um horário de retirada.',
  },
  'panel.onboarding.step.day.label': {
    ca: 'Revisar el « Treball del dia »', de: 'Die « Tagesarbeit » durchsehen', el: 'Έλεγχος της « Δουλειάς της ημέρας »',
    en: 'Check the “Daily work”', eo: 'Kontroli la « Taglaboron »', es: 'Revisar el « Trabajo del día »',
    fr: 'Consulter le « Travail du jour »', it: 'Controllare il « Lavoro del giorno »',
    nl: 'Het « Werk van de dag » nakijken', 'pt-BR': 'Conferir o « Trabalho do dia »',
  },
  'panel.onboarding.step.day.sub': {
    ca: 'Agafa el costum d’obrir aquesta pestanya en arribar.',
    de: 'Mach es dir zur Gewohnheit, diesen Tab beim Ankommen zu öffnen.',
    el: 'Κάνε συνήθεια να ανοίγεις αυτή την καρτέλα μόλις φτάνεις.',
    en: 'Get into the habit of opening this tab when you arrive.',
    eo: 'Akiru la kutimon malfermi ĉi tiun langeton ĉe via alveno.',
    es: 'Agarra el hábito de abrir esta pestaña al llegar.',
    fr: 'Prends l’habitude d’ouvrir cet onglet en arrivant.',
    it: 'Prendi l’abitudine di aprire questa scheda appena arrivi.',
    nl: 'Maak er een gewoonte van dit tabblad te openen als je binnenkomt.',
    'pt-BR': 'Pegue o hábito de abrir esta aba ao chegar.',
  },
  'panel.onboarding.human.tag': {
    ca: 'Canal humà · primer', de: 'Menschlicher Kanal · zuerst', el: 'Ανθρώπινο κανάλι · πρώτα',
    en: 'Human channel · first', eo: 'Homa kanalo · unue', es: 'Canal humano · primero',
    fr: 'Canal humain · d’abord', it: 'Canale umano · prima', nl: 'Menselijk kanaal · eerst',
    'pt-BR': 'Canal humano · primeiro',
  },
  'panel.onboarding.human.title': {
    ca: 'Ningú no neix ensenyat.', de: 'Niemand wird mit Wissen geboren.', el: 'Κανείς δεν γεννιέται ξέροντας.',
    en: 'Nobody is born knowing how.', eo: 'Neniu naskiĝas scianta.', es: 'Nadie nace sabiendo.',
    fr: 'Personne ne naît en sachant.', it: 'Nessuno nasce imparato.', nl: 'Niemand wordt wijs geboren.',
    'pt-BR': 'Ninguém nasce sabendo.',
  },
  'panel.onboarding.human.text': {
    ca: 'T’has encallat en alguna cosa? No busquis cap manual amagat. Escriu a algú de la xarxa que ja coneix l’eina — o pregunta a la teva coordinació aquí mateix a la biblioteca.',
    de: 'Irgendwo hängengeblieben? Such kein verstecktes Handbuch. Schreib jemandem aus dem Netzwerk, das das Werkzeug schon kennt — oder frag deine Koordination hier in der Bibliothek.',
    el: 'Κόλλησες κάπου; Μην ψάχνεις κρυμμένο εγχειρίδιο. Γράψε σε κάποια·ον από το δίκτυο που ξέρει ήδη το εργαλείο — ή ρώτησε τον συντονισμό σου εδώ στη βιβλιοθήκη.',
    en: 'Stuck on something? Do not go hunting for a hidden manual. Write to someone in the network who already knows the tool — or ask your coordination right here in the library.',
    eo: 'Ĉu vi blokiĝis pri io? Ne serĉu kaŝitan manlibron. Skribu al iu el la reto, kiu jam konas la ilon — aŭ demandu vian kunordigon ĉi tie en la biblioteko.',
    es: '¿Te trabaste con algo? No busques un manual escondido. Escribe a alguien de la red que ya conoce la herramienta — o pregunta a tu coordinación aquí mismo en la biblioteca.',
    fr: 'Bloqué·e sur quelque chose ? Ne cherche pas un manuel caché. Écris à quelqu’un du réseau qui connaît déjà l’outil — ou demande à ta coordination ici même, dans la bibliothèque.',
    it: 'Ti sei bloccat* su qualcosa? Non cercare un manuale nascosto. Scrivi a qualcuno della rete che conosce già lo strumento — oppure chiedi al tuo coordinamento qui in biblioteca.',
    nl: 'Ergens vastgelopen? Ga niet op zoek naar een verborgen handleiding. Schrijf iemand uit het netwerk dat de tool al kent — of vraag het je coördinatie hier in de bibliotheek.',
    'pt-BR': 'Travou em algo? Não procure um manual escondido. Escreva a alguém da rede que já conhece a ferramenta — ou pergunte à sua coordenação aqui mesmo na biblioteca.',
  },
};

let totalAdded = 0;
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (content.includes('"' + SENTINEL + '"')) {
    console.log(`${loc}: déjà présent, sauté.`);
    continue;
  }
  const entries = Object.keys(KEYS).map(k => {
    const v = KEYS[k][loc];
    if (v == null) throw new Error(`Traduction manquante: ${k} / ${loc}`);
    return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(v);
  });
  const marker = content.lastIndexOf('}');
  const head = content.slice(0, marker).replace(/\s*$/, '');
  const tail = content.slice(marker); // '}' + éventuel '\n'
  content = head + ',\n' + entries.join(',\n') + '\n' + tail;
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  // Validation stricte
  JSON.parse(fs.readFileSync(file, 'utf8'));
  totalAdded += entries.length;
  console.log(`${loc}: +${entries.length} clés, JSON valide.`);
}
console.log(`\nTerminé. ${totalAdded} clés ajoutées (${Object.keys(KEYS).length} × locales restantes).`);
