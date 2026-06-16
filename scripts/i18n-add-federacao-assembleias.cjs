/* ===========================================================================
 * i18n-add-federacao-assembleias.cjs
 * Onglet « Assembleias » (AG du réseau) : 18 clés federacao.assembleias.*
 * dans les 10 locales. Insertion idempotente (sentinelle federacao.assembleias.lead).
 * Auteur : Claude (assistant)
 * Session : Fédération — Assemblée du réseau (AG)
 * Réf. design : docs/journal/cadrages/CADRAGE_assembleias_reseau_2026-06-16.md
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.assembleias.lead';

const ADD = {
  'pt-BR': {
    "federacao.assembleias.lead": "O espaço de decisão da rede federada — em prefiguração.",
    "federacao.assembleias.badge": "Em prefiguração",
    "federacao.assembleias.principle.title": "Uma assembleia, não uma autoridade",
    "federacao.assembleias.principle.body": "A assembleia da rede é o espaço onde as bibliotecas federadas deliberam e decidem juntas. Funciona por consentimento — a ausência de objeção motivada — e não pela contagem de votos. E, sobretudo: uma decisão de assembleia é uma recomendação, nunca uma imposição a uma biblioteca. A autonomia local permanece soberana. O que você lê aqui estabelece os princípios, antes da primeira convocação.",
    "federacao.assembleias.how.title": "Como ela acontecerá",
    "federacao.assembleias.how.body": "A assembleia acontecerá a distância, por videoconferência, com a ferramenta livre Jitsi já usada no apoio mútuo — sem criar conta, sem instalar nada, sem gravação. Buscamos hospedá-la em um coletivo militante amigo (provavelmente a Autistici) em vez de um serviço comercial; enquanto isso, a instância pública do Jitsi resolve. O link de acesso será comunicado junto com a convocação.",
    "federacao.assembleias.rules.title": "Como vamos decidir",
    "federacao.assembleias.rules.intro": "Estas regras são pontos de partida. A primeira assembleia se dará suas próprias regras — nada aqui está gravado em pedra.",
    "federacao.assembleias.rules.date": "Data e horário: cada coletivo indica primeiro suas disponibilidades e depois suas preferências. Fica o horário que reúne mais amplamente — cuidando da diversidade das línguas e regiões presentes, não apenas do número.",
    "federacao.assembleias.rules.quorum": "Quórum: contam-se os coletivos presentes e sua diversidade, não os indivíduos. A legitimidade vem da amplitude da rede reunida.",
    "federacao.assembleias.rules.consent": "Decisões: por consentimento — uma proposta passa na ausência de objeção motivada; a objeção abre a discussão em vez de contar os lados.",
    "federacao.assembleias.agenda.title": "Propor um ponto à ordem do dia",
    "federacao.assembleias.agenda.body": "Qualquer coletivo pode inscrever um ponto na ordem do dia, desde que o apresente antes de um prazo que antecede a assembleia. Ninguém filtra as propostas: a inscrição basta para incluir o ponto, e é a própria assembleia que adota sua ordem do dia no início da sessão. O prazo não serve para selecionar, mas para dar a cada coletivo tempo de preparar o ponto, traduzi-lo e debatê-lo em casa antes de vir. O envio on-line chegará aqui; até lá, os pontos se propõem pelos canais habituais da rede.",
    "federacao.assembleias.firstPoints.title": "Primeiros pontos previstos",
    "federacao.assembleias.firstPoints.intro": "Alguns temas já sobre a mesa para uma primeira assembleia:",
    "federacao.assembleias.firstPoints.rules": "Dar-nos nossas próprias regras de assembleia (data, quórum, mandato, ordem do dia) — confirmar ou emendar o que vem acima.",
    "federacao.assembleias.firstPoints.subjects": "Abrir a edição dos assuntos e palavras-chave a quem contribui (hoje reservada à coordenação).",
    "federacao.assembleias.firstPoints.terms": "A fábrica dos termos: como se adota (ou se objeta) um termo, e até onde aceitamos variantes por língua em vez de uma formulação única."
  },
  fr: {
    "federacao.assembleias.lead": "L’espace de décision du réseau fédéré — en préfiguration.",
    "federacao.assembleias.badge": "En préfiguration",
    "federacao.assembleias.principle.title": "Une assemblée, pas une autorité",
    "federacao.assembleias.principle.body": "L’assemblée du réseau est l’espace où les bibliothèques fédérées délibèrent et décident ensemble. Elle fonctionne au consentement — l’absence d’objection motivée — plutôt qu’au décompte des voix. Et surtout : une décision d’assemblée est une recommandation, jamais une contrainte imposée à une bibliothèque. L’autonomie locale reste souveraine. Ce que tu lis ici en pose les principes, avant la première convocation.",
    "federacao.assembleias.how.title": "Comment elle se tiendra",
    "federacao.assembleias.how.body": "L’assemblée se tiendra à distance, en visioconférence, avec l’outil libre Jitsi déjà utilisé pour l’entraide — sans compte à créer, sans installation, sans enregistrement. Nous cherchons à l’héberger chez un collectif militant ami (probablement Autistici) plutôt que sur un service commercial ; en attendant, l’instance publique de Jitsi fait l’affaire. Le lien d’accès sera communiqué avec la convocation.",
    "federacao.assembleias.rules.title": "Comment on décidera",
    "federacao.assembleias.rules.intro": "Ces règles sont des points de départ. La première assemblée se dotera elle-même de ses règles — rien ici n’est gravé.",
    "federacao.assembleias.rules.date": "Date et horaire : chaque collectif indique d’abord ses disponibilités, puis ses préférences. On retient le créneau qui rassemble le plus largement — en veillant à la diversité des langues et des régions présentes, pas seulement au nombre.",
    "federacao.assembleias.rules.quorum": "Quorum : on compte les collectifs présents et leur diversité, pas les individus. La légitimité tient à l’étendue du réseau réuni.",
    "federacao.assembleias.rules.consent": "Décisions : par consentement — une proposition passe en l’absence d’objection motivée ; l’objection ouvre la discussion plutôt qu’elle ne compte les camps.",
    "federacao.assembleias.agenda.title": "Proposer un point à l’ordre du jour",
    "federacao.assembleias.agenda.body": "Tout collectif peut inscrire un point à l’ordre du jour, à condition de le déposer avant un délai précédant l’assemblée. Personne ne filtre les propositions : le dépôt suffit à inscrire le point, et c’est l’assemblée elle-même qui adopte son ordre du jour au début de la séance. Le délai n’est pas là pour trier, mais pour laisser à chaque collectif le temps de préparer le point, le traduire et en débattre chez lui avant de venir. Le dépôt en ligne arrivera ici ; d’ici là, les points se proposent par les canaux habituels du réseau.",
    "federacao.assembleias.firstPoints.title": "Premiers points pressentis",
    "federacao.assembleias.firstPoints.intro": "Quelques sujets déjà sur la table pour une première assemblée :",
    "federacao.assembleias.firstPoints.rules": "Se doter de nos propres règles d’assemblée (date, quorum, mandat, ordre du jour) — confirmer ou amender ce qui précède.",
    "federacao.assembleias.firstPoints.subjects": "Ouvrir l’édition des sujets et mots-clés aux contributeur·rices (aujourd’hui réservée à la coordination).",
    "federacao.assembleias.firstPoints.terms": "La fabrique des termes : comment on adopte (ou objecte) un terme, et jusqu’où on accepte des variantes par langue plutôt qu’une formulation unique."
  },
  es: {
    "federacao.assembleias.lead": "El espacio de decisión de la red federada — en prefiguración.",
    "federacao.assembleias.badge": "En prefiguración",
    "federacao.assembleias.principle.title": "Una asamblea, no una autoridad",
    "federacao.assembleias.principle.body": "La asamblea de la red es el espacio donde las bibliotecas federadas deliberan y deciden juntas. Funciona por consentimiento — la ausencia de objeción motivada — y no por el recuento de votos. Y sobre todo: una decisión de asamblea es una recomendación, nunca una imposición a una biblioteca. La autonomía local sigue siendo soberana. Lo que lees aquí establece los principios, antes de la primera convocatoria.",
    "federacao.assembleias.how.title": "Cómo se realizará",
    "federacao.assembleias.how.body": "La asamblea se realizará a distancia, por videollamada, con la herramienta libre Jitsi que ya usamos para el apoyo mutuo — sin crear cuenta, sin instalar nada, sin grabación. Buscamos alojarla en un colectivo militante amigo (probablemente Autistici) en vez de un servicio comercial; mientras tanto, la instancia pública de Jitsi alcanza. El enlace de acceso se comunicará junto con la convocatoria.",
    "federacao.assembleias.rules.title": "Cómo vamos a decidir",
    "federacao.assembleias.rules.intro": "Estas reglas son puntos de partida. La primera asamblea se dará sus propias reglas — nada aquí está escrito en piedra.",
    "federacao.assembleias.rules.date": "Fecha y horario: cada colectivo indica primero sus disponibilidades y luego sus preferencias. Se elige el horario que reúne más ampliamente — cuidando la diversidad de las lenguas y regiones presentes, no solo el número.",
    "federacao.assembleias.rules.quorum": "Quórum: se cuentan los colectivos presentes y su diversidad, no las personas individuales. La legitimidad viene de la amplitud de la red reunida.",
    "federacao.assembleias.rules.consent": "Decisiones: por consentimiento — una propuesta avanza si no hay objeción motivada; la objeción abre la discusión en vez de contar los bandos.",
    "federacao.assembleias.agenda.title": "Proponer un punto al orden del día",
    "federacao.assembleias.agenda.body": "Cualquier colectivo puede inscribir un punto en el orden del día, siempre que lo presente antes de un plazo previo a la asamblea. Nadie filtra las propuestas: la inscripción basta para incluir el punto, y es la propia asamblea la que adopta su orden del día al inicio de la sesión. El plazo no está para seleccionar, sino para dar a cada colectivo tiempo de preparar el punto, traducirlo y debatirlo en casa antes de venir. El envío en línea llegará aquí; hasta entonces, los puntos se proponen por los canales habituales de la red.",
    "federacao.assembleias.firstPoints.title": "Primeros puntos previstos",
    "federacao.assembleias.firstPoints.intro": "Algunos temas ya sobre la mesa para una primera asamblea:",
    "federacao.assembleias.firstPoints.rules": "Darnos nuestras propias reglas de asamblea (fecha, quórum, mandato, orden del día) — confirmar o enmendar lo anterior.",
    "federacao.assembleias.firstPoints.subjects": "Abrir la edición de los temas y palabras clave a quienes contribuyen (hoy reservada a la coordinación).",
    "federacao.assembleias.firstPoints.terms": "La fábrica de los términos: cómo se adopta (u objeta) un término, y hasta dónde aceptamos variantes por lengua en vez de una formulación única."
  },
  en: {
    "federacao.assembleias.lead": "The federated network’s decision-making space — in the making.",
    "federacao.assembleias.badge": "In the making",
    "federacao.assembleias.principle.title": "An assembly, not an authority",
    "federacao.assembleias.principle.body": "The network assembly is the space where federated libraries deliberate and decide together. It works by consent — the absence of a reasoned objection — rather than by counting votes. Above all: an assembly decision is a recommendation, never something imposed on a library. Local autonomy remains sovereign. What you read here sets out the principles, ahead of the first convening.",
    "federacao.assembleias.how.title": "How it will be held",
    "federacao.assembleias.how.body": "The assembly will be held remotely, by video call, using the free software Jitsi already used for mutual aid — no account to create, nothing to install, no recording. We are looking to host it with a friendly activist collective (probably Autistici) rather than a commercial service; in the meantime, the public Jitsi instance does the job. The access link will be shared with the convening notice.",
    "federacao.assembleias.rules.title": "How we will decide",
    "federacao.assembleias.rules.intro": "These rules are starting points. The first assembly will give itself its own rules — nothing here is set in stone.",
    "federacao.assembleias.rules.date": "Date and time: each collective first marks its availability, then its preferences. We keep the slot that gathers the most widely — mindful of the diversity of languages and regions present, not just the headcount.",
    "federacao.assembleias.rules.quorum": "Quorum: we count the collectives present and their diversity, not individuals. Legitimacy comes from the breadth of the network gathered.",
    "federacao.assembleias.rules.consent": "Decisions: by consent — a proposal passes in the absence of a reasoned objection; an objection opens discussion rather than counting sides.",
    "federacao.assembleias.agenda.title": "Proposing an agenda item",
    "federacao.assembleias.agenda.body": "Any collective can add an item to the agenda, as long as it submits it before a deadline ahead of the assembly. No one filters the proposals: submitting is enough to include the item, and it is the assembly itself that adopts its agenda at the start of the session. The deadline is not there to select, but to give each collective time to prepare the item, translate it and discuss it at home before coming. Online submission will arrive here; until then, items are proposed through the network’s usual channels.",
    "federacao.assembleias.firstPoints.title": "First likely items",
    "federacao.assembleias.firstPoints.intro": "A few topics already on the table for a first assembly:",
    "federacao.assembleias.firstPoints.rules": "Giving ourselves our own assembly rules (date, quorum, mandate, agenda) — confirming or amending the above.",
    "federacao.assembleias.firstPoints.subjects": "Opening the editing of subjects and keywords to contributors (today restricted to coordination).",
    "federacao.assembleias.firstPoints.terms": "The making of terms: how a term is adopted (or objected to), and how far we accept variants per language rather than a single wording."
  },
  it: {
    "federacao.assembleias.lead": "Lo spazio decisionale della rete federata — in prefigurazione.",
    "federacao.assembleias.badge": "In prefigurazione",
    "federacao.assembleias.principle.title": "Un’assemblea, non un’autorità",
    "federacao.assembleias.principle.body": "L’assemblea della rete è lo spazio in cui le biblioteche federate deliberano e decidono insieme. Funziona per consenso — l’assenza di un’obiezione motivata — e non per conteggio dei voti. Soprattutto: una decisione dell’assemblea è una raccomandazione, mai un’imposizione a una biblioteca. L’autonomia locale resta sovrana. Ciò che leggi qui ne pone i principi, prima della prima convocazione.",
    "federacao.assembleias.how.title": "Come si svolgerà",
    "federacao.assembleias.how.body": "L’assemblea si svolgerà a distanza, in videoconferenza, con lo strumento libero Jitsi già usato per il supporto reciproco — senza creare un account, senza installare nulla, senza registrazione. Cerchiamo di ospitarla presso un collettivo militante amico (probabilmente Autistici) invece che su un servizio commerciale; nel frattempo, l’istanza pubblica di Jitsi va bene. Il link di accesso sarà comunicato insieme alla convocazione.",
    "federacao.assembleias.rules.title": "Come decideremo",
    "federacao.assembleias.rules.intro": "Queste regole sono punti di partenza. La prima assemblea si darà le proprie regole — qui nulla è scolpito nella pietra.",
    "federacao.assembleias.rules.date": "Data e orario: ogni collettivo indica prima le proprie disponibilità, poi le preferenze. Si tiene la fascia che riunisce più ampiamente — avendo cura della diversità delle lingue e delle regioni presenti, non solo del numero.",
    "federacao.assembleias.rules.quorum": "Quorum: si contano i collettivi presenti e la loro diversità, non gli individui. La legittimità nasce dall’ampiezza della rete riunita.",
    "federacao.assembleias.rules.consent": "Decisioni: per consenso — una proposta passa in assenza di un’obiezione motivata; l’obiezione apre la discussione invece di contare gli schieramenti.",
    "federacao.assembleias.agenda.title": "Proporre un punto all’ordine del giorno",
    "federacao.assembleias.agenda.body": "Ogni collettivo può inserire un punto all’ordine del giorno, purché lo presenti entro un termine che precede l’assemblea. Nessuno filtra le proposte: la presentazione basta a includere il punto, ed è l’assemblea stessa ad adottare il proprio ordine del giorno all’inizio della seduta. Il termine non serve a selezionare, ma a dare a ogni collettivo il tempo di preparare il punto, tradurlo e discuterlo a casa prima di venire. L’invio online arriverà qui; fino ad allora, i punti si propongono attraverso i canali abituali della rete.",
    "federacao.assembleias.firstPoints.title": "Primi punti previsti",
    "federacao.assembleias.firstPoints.intro": "Alcuni temi già sul tavolo per una prima assemblea:",
    "federacao.assembleias.firstPoints.rules": "Darci le nostre regole di assemblea (data, quorum, mandato, ordine del giorno) — confermare o emendare quanto sopra.",
    "federacao.assembleias.firstPoints.subjects": "Aprire la modifica dei soggetti e delle parole chiave a chi contribuisce (oggi riservata al coordinamento).",
    "federacao.assembleias.firstPoints.terms": "La fabbrica dei termini: come si adotta (o si obietta) un termine, e fino a che punto accettiamo varianti per lingua invece di un’unica formulazione."
  },
  de: {
    "federacao.assembleias.lead": "Der Entscheidungsraum des föderierten Netzwerks — im Entstehen.",
    "federacao.assembleias.badge": "Im Entstehen",
    "federacao.assembleias.principle.title": "Eine Versammlung, keine Autorität",
    "federacao.assembleias.principle.body": "Die Netzwerkversammlung ist der Raum, in dem die föderierten Bibliotheken gemeinsam beraten und entscheiden. Sie arbeitet im Konsent — dem Ausbleiben eines begründeten Einwands — statt durch Stimmenzählen. Vor allem: eine Entscheidung der Versammlung ist eine Empfehlung, niemals ein Zwang für eine Bibliothek. Die lokale Autonomie bleibt souverän. Was du hier liest, legt die Grundsätze fest, vor der ersten Einberufung.",
    "federacao.assembleias.how.title": "Wie sie stattfinden wird",
    "federacao.assembleias.how.body": "Die Versammlung findet aus der Ferne statt, per Videokonferenz, mit der freien Software Jitsi, die schon für die gegenseitige Hilfe genutzt wird — ohne Konto, ohne Installation, ohne Aufzeichnung. Wir möchten sie bei einem befreundeten militanten Kollektiv hosten (wahrscheinlich Autistici) statt bei einem kommerziellen Dienst; bis dahin tut es die öffentliche Jitsi-Instanz. Der Zugangslink wird mit der Einberufung mitgeteilt.",
    "federacao.assembleias.rules.title": "Wie wir entscheiden werden",
    "federacao.assembleias.rules.intro": "Diese Regeln sind Ausgangspunkte. Die erste Versammlung gibt sich ihre eigenen Regeln — nichts hier ist in Stein gemeißelt.",
    "federacao.assembleias.rules.date": "Datum und Uhrzeit: jedes Kollektiv gibt zuerst seine Verfügbarkeiten an, dann seine Vorlieben. Wir nehmen den Termin, der am breitesten zusammenführt — mit Blick auf die Vielfalt der anwesenden Sprachen und Regionen, nicht nur auf die Zahl.",
    "federacao.assembleias.rules.quorum": "Quorum: gezählt werden die anwesenden Kollektive und ihre Vielfalt, nicht die Einzelpersonen. Die Legitimität ergibt sich aus der Breite des versammelten Netzwerks.",
    "federacao.assembleias.rules.consent": "Entscheidungen: im Konsent — ein Vorschlag geht durch, wenn kein begründeter Einwand vorliegt; der Einwand eröffnet die Diskussion, statt Lager zu zählen.",
    "federacao.assembleias.agenda.title": "Einen Tagesordnungspunkt vorschlagen",
    "federacao.assembleias.agenda.body": "Jedes Kollektiv kann einen Punkt auf die Tagesordnung setzen, sofern es ihn vor einer Frist vor der Versammlung einreicht. Niemand filtert die Vorschläge: das Einreichen genügt, um den Punkt aufzunehmen, und es ist die Versammlung selbst, die zu Beginn der Sitzung ihre Tagesordnung annimmt. Die Frist dient nicht dem Aussortieren, sondern dazu, jedem Kollektiv Zeit zu geben, den Punkt vorzubereiten, zu übersetzen und zu Hause zu besprechen, bevor es kommt. Das Einreichen online kommt hierher; bis dahin werden die Punkte über die üblichen Kanäle des Netzwerks vorgeschlagen.",
    "federacao.assembleias.firstPoints.title": "Erste mögliche Punkte",
    "federacao.assembleias.firstPoints.intro": "Einige Themen, die schon für eine erste Versammlung auf dem Tisch liegen:",
    "federacao.assembleias.firstPoints.rules": "Uns eigene Versammlungsregeln geben (Datum, Quorum, Mandat, Tagesordnung) — das Obige bestätigen oder ändern.",
    "federacao.assembleias.firstPoints.subjects": "Das Bearbeiten der Themen und Schlagwörter für Mitwirkende öffnen (heute der Koordination vorbehalten).",
    "federacao.assembleias.firstPoints.terms": "Die Werkstatt der Begriffe: wie ein Begriff angenommen (oder beeinsprucht) wird, und wie weit wir Varianten je Sprache zulassen statt einer einzigen Formulierung."
  },
  ca: {
    "federacao.assembleias.lead": "L’espai de decisió de la xarxa federada — en prefiguració.",
    "federacao.assembleias.badge": "En prefiguració",
    "federacao.assembleias.principle.title": "Una assemblea, no una autoritat",
    "federacao.assembleias.principle.body": "L’assemblea de la xarxa és l’espai on les biblioteques federades deliberen i decideixen juntes. Funciona per consentiment — l’absència d’objecció motivada — i no pel recompte de vots. I sobretot: una decisió d’assemblea és una recomanació, mai una imposició a una biblioteca. L’autonomia local continua sent sobirana. El que llegeixes aquí en posa els principis, abans de la primera convocatòria.",
    "federacao.assembleias.how.title": "Com es durà a terme",
    "federacao.assembleias.how.body": "L’assemblea es durà a terme a distància, per videoconferència, amb l’eina lliure Jitsi ja emprada per al suport mutu — sense crear cap compte, sense instal·lar res, sense enregistrament. Volem allotjar-la en un col·lectiu militant amic (probablement Autistici) en lloc d’un servei comercial; mentrestant, la instància pública de Jitsi ja fa el fet. L’enllaç d’accés es comunicarà amb la convocatòria.",
    "federacao.assembleias.rules.title": "Com decidirem",
    "federacao.assembleias.rules.intro": "Aquestes regles són punts de partida. La primera assemblea es donarà les seves pròpies regles — aquí res no està gravat en pedra.",
    "federacao.assembleias.rules.date": "Data i hora: cada col·lectiu indica primer les seves disponibilitats i després les preferències. Es manté la franja que aplega més àmpliament — tot tenint cura de la diversitat de les llengües i regions presents, no només del nombre.",
    "federacao.assembleias.rules.quorum": "Quòrum: es compten els col·lectius presents i la seva diversitat, no els individus. La legitimitat ve de l’amplitud de la xarxa reunida.",
    "federacao.assembleias.rules.consent": "Decisions: per consentiment — una proposta passa en absència d’objecció motivada; l’objecció obre la discussió en lloc de comptar els bàndols.",
    "federacao.assembleias.agenda.title": "Proposar un punt a l’ordre del dia",
    "federacao.assembleias.agenda.body": "Qualsevol col·lectiu pot inscriure un punt a l’ordre del dia, sempre que el presenti abans d’un termini previ a l’assemblea. Ningú no filtra les propostes: la inscripció n’hi ha prou per incloure el punt, i és la mateixa assemblea qui adopta el seu ordre del dia a l’inici de la sessió. El termini no és per seleccionar, sinó per donar a cada col·lectiu temps de preparar el punt, traduir-lo i debatre’l a casa abans de venir. L’enviament en línia arribarà aquí; fins llavors, els punts es proposen pels canals habituals de la xarxa.",
    "federacao.assembleias.firstPoints.title": "Primers punts previstos",
    "federacao.assembleias.firstPoints.intro": "Alguns temes ja damunt la taula per a una primera assemblea:",
    "federacao.assembleias.firstPoints.rules": "Dotar-nos de les nostres pròpies regles d’assemblea (data, quòrum, mandat, ordre del dia) — confirmar o esmenar el que precedeix.",
    "federacao.assembleias.firstPoints.subjects": "Obrir l’edició dels temes i les paraules clau a qui hi col·labora (avui reservada a la coordinació).",
    "federacao.assembleias.firstPoints.terms": "La fàbrica dels termes: com s’adopta (o s’objecta) un terme, i fins on acceptem variants per llengua en lloc d’una formulació única."
  },
  eo: {
    "federacao.assembleias.lead": "La decida spaco de la federita reto — ankoraŭ konstruata.",
    "federacao.assembleias.badge": "Ankoraŭ konstruata",
    "federacao.assembleias.principle.title": "Asembleo, ne aŭtoritato",
    "federacao.assembleias.principle.body": "La asembleo de la reto estas la spaco kie la federitaj bibliotekoj kune diskutas kaj decidas. Ĝi funkcias per konsento — la manko de motivita kontraŭdiro — kaj ne per voĉkalkulado. Precipe: decido de la asembleo estas rekomendo, neniam altrudo al biblioteko. La loka aŭtonomio restas suverena. Tio, kion vi legas ĉi tie, starigas la principojn, antaŭ la unua kunvoko.",
    "federacao.assembleias.how.title": "Kiel ĝi okazos",
    "federacao.assembleias.how.body": "La asembleo okazos malproksime, per videokonferenco, kun la libera ilo Jitsi jam uzata por reciproka helpo — sen krei konton, sen instali ion, sen registrado. Ni serĉas gastigi ĝin ĉe amika aktivula kolektivo (verŝajne Autistici) anstataŭ ĉe komerca servo; dume, la publika Jitsi-instanco taŭgas. La aliro-ligilo estos komunikita kun la kunvoko.",
    "federacao.assembleias.rules.title": "Kiel ni decidos",
    "federacao.assembleias.rules.intro": "Tiuj reguloj estas elirpunktoj. La unua asembleo donos al si siajn proprajn regulojn — nenio ĉi tie estas ĉizita en ŝtono.",
    "federacao.assembleias.rules.date": "Dato kaj horo: ĉiu kolektivo unue indikas siajn disponeblecojn, poste siajn preferojn. Ni konservas la tempon kiu plej larĝe kunigas — atentante la diversecon de la ĉeestantaj lingvoj kaj regionoj, ne nur la nombron.",
    "federacao.assembleias.rules.quorum": "Kvorumo: oni kalkulas la ĉeestantajn kolektivojn kaj ilian diversecon, ne la individuojn. La legitimeco venas el la amplekso de la kunigita reto.",
    "federacao.assembleias.rules.consent": "Decidoj: per konsento — propono pasas kiam mankas motivita kontraŭdiro; la kontraŭdiro malfermas la diskuton anstataŭ kalkuli flankojn.",
    "federacao.assembleias.agenda.title": "Proponi punkton al la tagordo",
    "federacao.assembleias.agenda.body": "Ĉiu kolektivo povas enskribi punkton en la tagordon, kondiĉe ke ĝi prezentu ĝin antaŭ limdato antaŭ la asembleo. Neniu filtras la proponojn: la enskribo sufiĉas por inkluzivi la punkton, kaj estas la asembleo mem kiu adoptas sian tagordon je la komenco de la kunsido. La limdato ne servas por selekti, sed por doni al ĉiu kolektivo tempon prepari la punkton, traduki ĝin kaj pridiskuti ĝin hejme antaŭ ol veni. La reta sendado alvenos ĉi tien; ĝis tiam, la punktoj proponiĝas per la kutimaj kanaloj de la reto.",
    "federacao.assembleias.firstPoints.title": "Unuaj antaŭviditaj punktoj",
    "federacao.assembleias.firstPoints.intro": "Kelkaj temoj jam sur la tablo por unua asembleo:",
    "federacao.assembleias.firstPoints.rules": "Doni al ni niajn proprajn asembleajn regulojn (dato, kvorumo, mandato, tagordo) — konfirmi aŭ ŝanĝi la antaŭan.",
    "federacao.assembleias.firstPoints.subjects": "Malfermi la redaktadon de la temoj kaj ŝlosilvortoj al la kontribuantoj (hodiaŭ rezervita al la kunordigo).",
    "federacao.assembleias.firstPoints.terms": "La fabriko de la terminoj: kiel oni adoptas (aŭ kontraŭdiras) terminon, kaj ĝis kie ni akceptas variantojn laŭ lingvo anstataŭ unu sola formulo."
  },
  nl: {
    "federacao.assembleias.lead": "De besluitruimte van het gefedereerde netwerk — in wording.",
    "federacao.assembleias.badge": "In wording",
    "federacao.assembleias.principle.title": "Een vergadering, geen autoriteit",
    "federacao.assembleias.principle.body": "De netwerkvergadering is de ruimte waar de gefedereerde bibliotheken samen beraadslagen en beslissen. Ze werkt op basis van consent — het uitblijven van een gemotiveerd bezwaar — en niet door stemmen te tellen. Vooral: een besluit van de vergadering is een aanbeveling, nooit een verplichting opgelegd aan een bibliotheek. De lokale autonomie blijft soeverein. Wat je hier leest, legt de beginselen vast, vóór de eerste bijeenroeping.",
    "federacao.assembleias.how.title": "Hoe ze wordt gehouden",
    "federacao.assembleias.how.body": "De vergadering wordt op afstand gehouden, via videogesprek, met het vrije gereedschap Jitsi dat al voor onderlinge hulp wordt gebruikt — zonder account, zonder installatie, zonder opname. We zoeken een bevriend militant collectief om ze te hosten (waarschijnlijk Autistici) in plaats van een commerciële dienst; ondertussen volstaat de openbare Jitsi-instantie. De toegangslink wordt met de bijeenroeping meegedeeld.",
    "federacao.assembleias.rules.title": "Hoe we zullen beslissen",
    "federacao.assembleias.rules.intro": "Deze regels zijn vertrekpunten. De eerste vergadering geeft zichzelf haar eigen regels — niets hier staat in steen gebeiteld.",
    "federacao.assembleias.rules.date": "Datum en tijdstip: elk collectief geeft eerst zijn beschikbaarheden aan, daarna zijn voorkeuren. We houden het tijdstip dat het breedst samenbrengt — met oog voor de diversiteit van de aanwezige talen en regio’s, niet alleen voor het aantal.",
    "federacao.assembleias.rules.quorum": "Quorum: we tellen de aanwezige collectieven en hun diversiteit, niet de individuen. De legitimiteit komt voort uit de breedte van het verzamelde netwerk.",
    "federacao.assembleias.rules.consent": "Besluiten: bij consent — een voorstel gaat door als er geen gemotiveerd bezwaar is; het bezwaar opent het gesprek in plaats van kampen te tellen.",
    "federacao.assembleias.agenda.title": "Een agendapunt voorstellen",
    "federacao.assembleias.agenda.body": "Elk collectief kan een punt op de agenda zetten, op voorwaarde dat het dit indient vóór een termijn die aan de vergadering voorafgaat. Niemand filtert de voorstellen: indienen volstaat om het punt op te nemen, en het is de vergadering zelf die aan het begin van de zitting haar agenda vaststelt. De termijn dient niet om te selecteren, maar om elk collectief de tijd te geven het punt voor te bereiden, te vertalen en thuis te bespreken voordat het komt. Online indienen komt hierheen; tot dan worden punten voorgesteld via de gebruikelijke kanalen van het netwerk.",
    "federacao.assembleias.firstPoints.title": "Eerste mogelijke punten",
    "federacao.assembleias.firstPoints.intro": "Enkele onderwerpen die al op tafel liggen voor een eerste vergadering:",
    "federacao.assembleias.firstPoints.rules": "Onszelf eigen vergaderregels geven (datum, quorum, mandaat, agenda) — het bovenstaande bevestigen of wijzigen.",
    "federacao.assembleias.firstPoints.subjects": "Het bewerken van de onderwerpen en trefwoorden openstellen voor wie bijdraagt (vandaag voorbehouden aan de coördinatie).",
    "federacao.assembleias.firstPoints.terms": "De werkplaats van de termen: hoe een term wordt aangenomen (of er bezwaar tegen wordt gemaakt), en hoever we varianten per taal aanvaarden in plaats van één enkele formulering."
  },
  el: {
    "federacao.assembleias.lead": "Ο χώρος αποφάσεων του ομοσπονδιακού δικτύου — υπό διαμόρφωση.",
    "federacao.assembleias.badge": "Υπό διαμόρφωση",
    "federacao.assembleias.principle.title": "Μια συνέλευση, όχι μια αρχή",
    "federacao.assembleias.principle.body": "Η συνέλευση του δικτύου είναι ο χώρος όπου οι ομόσπονδες βιβλιοθήκες συσκέπτονται και αποφασίζουν από κοινού. Λειτουργεί με συναίνεση — την απουσία αιτιολογημένης ένστασης — και όχι με καταμέτρηση ψήφων. Πάνω απ’ όλα: μια απόφαση της συνέλευσης είναι σύσταση, ποτέ επιβολή σε μια βιβλιοθήκη. Η τοπική αυτονομία παραμένει κυρίαρχη. Αυτά που διαβάζεις εδώ θέτουν τις αρχές, πριν από την πρώτη σύγκληση.",
    "federacao.assembleias.how.title": "Πώς θα διεξαχθεί",
    "federacao.assembleias.how.body": "Η συνέλευση θα διεξαχθεί εξ αποστάσεως, με βιντεοκλήση, με το ελεύθερο εργαλείο Jitsi που χρησιμοποιείται ήδη για την αλληλοβοήθεια — χωρίς λογαριασμό, χωρίς εγκατάσταση, χωρίς καταγραφή. Επιδιώκουμε να τη φιλοξενήσουμε σε μια φιλική μαχητική συλλογικότητα (πιθανότατα την Autistici) αντί για εμπορική υπηρεσία· στο μεταξύ, η δημόσια υπηρεσία Jitsi επαρκεί. Ο σύνδεσμος πρόσβασης θα κοινοποιηθεί μαζί με τη σύγκληση.",
    "federacao.assembleias.rules.title": "Πώς θα αποφασίζουμε",
    "federacao.assembleias.rules.intro": "Αυτοί οι κανόνες είναι αφετηρίες. Η πρώτη συνέλευση θα θέσει τους δικούς της κανόνες — τίποτα εδώ δεν είναι χαραγμένο στην πέτρα.",
    "federacao.assembleias.rules.date": "Ημερομηνία και ώρα: κάθε συλλογικότητα δηλώνει πρώτα τη διαθεσιμότητά της και έπειτα τις προτιμήσεις της. Κρατάμε τη χρονική στιγμή που συγκεντρώνει όσο το δυνατόν ευρύτερα — με μέριμνα για την πολυμορφία των γλωσσών και των περιοχών που συμμετέχουν, όχι μόνο για τον αριθμό.",
    "federacao.assembleias.rules.quorum": "Απαρτία: μετράμε τις παρούσες συλλογικότητες και την πολυμορφία τους, όχι τα άτομα. Η νομιμοποίηση προέρχεται από το εύρος του δικτύου που συγκεντρώνεται.",
    "federacao.assembleias.rules.consent": "Αποφάσεις: με συναίνεση — μια πρόταση περνά εν απουσία αιτιολογημένης ένστασης· η ένσταση ανοίγει τη συζήτηση αντί να μετρά στρατόπεδα.",
    "federacao.assembleias.agenda.title": "Πρόταση θέματος στην ημερήσια διάταξη",
    "federacao.assembleias.agenda.body": "Κάθε συλλογικότητα μπορεί να εγγράψει ένα θέμα στην ημερήσια διάταξη, αρκεί να το υποβάλει πριν από μια προθεσμία που προηγείται της συνέλευσης. Κανείς δεν φιλτράρει τις προτάσεις: η υποβολή αρκεί για να συμπεριληφθεί το θέμα, και είναι η ίδια η συνέλευση που υιοθετεί την ημερήσια διάταξή της στην αρχή της συνεδρίασης. Η προθεσμία δεν υπάρχει για να επιλέγει, αλλά για να δίνει σε κάθε συλλογικότητα χρόνο να προετοιμάσει το θέμα, να το μεταφράσει και να το συζητήσει στον τόπο της πριν έρθει. Η ηλεκτρονική υποβολή θα έρθει εδώ· ως τότε, τα θέματα προτείνονται μέσω των συνηθισμένων διαύλων του δικτύου.",
    "federacao.assembleias.firstPoints.title": "Πρώτα πιθανά θέματα",
    "federacao.assembleias.firstPoints.intro": "Μερικά θέματα ήδη στο τραπέζι για μια πρώτη συνέλευση:",
    "federacao.assembleias.firstPoints.rules": "Να δώσουμε στους εαυτούς μας τους δικούς μας κανόνες συνέλευσης (ημερομηνία, απαρτία, εντολή, ημερήσια διάταξη) — να επιβεβαιώσουμε ή να τροποποιήσουμε τα παραπάνω.",
    "federacao.assembleias.firstPoints.subjects": "Να ανοίξουμε την επεξεργασία των θεμάτων και των λέξεων-κλειδιών σε όσα άτομα συνεισφέρουν (σήμερα περιορισμένη στον συντονισμό).",
    "federacao.assembleias.firstPoints.terms": "Το εργαστήρι των όρων: πώς υιοθετείται (ή αντιτίθεται κανείς σε) έναν όρο, και ως πού δεχόμαστε παραλλαγές ανά γλώσσα αντί για μία ενιαία διατύπωση."
  }
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const map = ADD[loc];
    const keys = Object.keys(ADD['pt-BR']);
    const entries = keys.map((k) => {
      if (map[k] == null) throw new Error('Traduction manquante: ' + k + ' / ' + loc);
      return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(map[k]);
    });
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
  }
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 18 clés federacao.assembleias.* (si absentes), JSON valide.');
}
console.log('\nTerminé.');
