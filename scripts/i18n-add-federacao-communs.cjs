/* ===========================================================================
 * i18n-add-federacao-communs.cjs
 * Onglet « Communs » (documents vivants) : 13 clés × 10 locales.
 * Idempotent (sentinelle federacao.tab.communs).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.tab.communs';

const ADD = {
  fr: {
    'federacao.tab.communs': 'Communs',
    'federacao.communs.intro': 'Les documents vivants du réseau — chartes et cadrages qui orientent AnarBib. À lire ici, pas enfouis dans un dépôt.',
    'federacao.communs.cat.chartes': 'Chartes',
    'federacao.communs.cat.cadrages': 'Cadrages',
    'federacao.communs.read': 'Lire',
    'federacao.communs.back': 'Retour',
    'federacao.communs.note': 'Documents en projet, à discuter et adopter par consentement, puis à traduire dans les dix langues.',
    'federacao.communs.doc.mainTendue.title': 'Charte relationnelle — « la main tendue »',
    'federacao.communs.doc.mainTendue.desc': 'L’éthique d’AnarBib envers les personnes : tendre la main, jamais saisir le poignet.',
    'federacao.communs.doc.langageInclusif.title': 'Charte de langage inclusif',
    'federacao.communs.doc.langageInclusif.desc': 'Les conventions inclusives des dix locales — situées, par communauté de langue.',
    'federacao.communs.doc.cadrageEntraide.title': 'Cadrage — entraide au catalogage',
    'federacao.communs.doc.cadrageEntraide.desc': 'Vision et architecture de l’entraide : trois degrés, le commun de savoir, la confidentialité.',
  },
  'pt-BR': {
    'federacao.tab.communs': 'Comuns',
    'federacao.communs.intro': 'Os documentos vivos da rede — cartas e enquadramentos que orientam o AnarBib. Para ler aqui, não enterrados num repositório.',
    'federacao.communs.cat.chartes': 'Cartas',
    'federacao.communs.cat.cadrages': 'Enquadramentos',
    'federacao.communs.read': 'Ler',
    'federacao.communs.back': 'Voltar',
    'federacao.communs.note': 'Documentos em projeto, a discutir e adotar por consentimento, depois a traduzir nas dez línguas.',
    'federacao.communs.doc.mainTendue.title': 'Carta relacional — « a mão estendida »',
    'federacao.communs.doc.mainTendue.desc': 'A ética do AnarBib para com as pessoas: estender a mão, nunca agarrar o pulso.',
    'federacao.communs.doc.langageInclusif.title': 'Carta de linguagem inclusiva',
    'federacao.communs.doc.langageInclusif.desc': 'As convenções inclusivas das dez locales — situadas, por comunidade de língua.',
    'federacao.communs.doc.cadrageEntraide.title': 'Enquadramento — entreajuda na catalogação',
    'federacao.communs.doc.cadrageEntraide.desc': 'Visão e arquitetura da entreajuda: três graus, o comum de saber, a confidencialidade.',
  },
  es: {
    'federacao.tab.communs': 'Comunes',
    'federacao.communs.intro': 'Los documentos vivos de la red — cartas y marcos que orientan AnarBib. Para leer aquí, no enterrados en un repositorio.',
    'federacao.communs.cat.chartes': 'Cartas',
    'federacao.communs.cat.cadrages': 'Marcos',
    'federacao.communs.read': 'Leer',
    'federacao.communs.back': 'Volver',
    'federacao.communs.note': 'Documentos en proyecto, a discutir y adoptar por consentimiento, luego a traducir en las diez lenguas.',
    'federacao.communs.doc.mainTendue.title': 'Carta relacional — « la mano tendida »',
    'federacao.communs.doc.mainTendue.desc': 'La ética de AnarBib hacia las personas: tender la mano, nunca agarrar la muñeca.',
    'federacao.communs.doc.langageInclusif.title': 'Carta de lenguaje inclusivo',
    'federacao.communs.doc.langageInclusif.desc': 'Las convenciones inclusivas de las diez locales — situadas, por comunidad de lengua.',
    'federacao.communs.doc.cadrageEntraide.title': 'Marco — apoyo mutuo en la catalogación',
    'federacao.communs.doc.cadrageEntraide.desc': 'Visión y arquitectura del apoyo mutuo: tres grados, el común de saber, la confidencialidad.',
  },
  en: {
    'federacao.tab.communs': 'Commons',
    'federacao.communs.intro': 'The network’s living documents — charters and framings that guide AnarBib. Read them here, not buried in a repository.',
    'federacao.communs.cat.chartes': 'Charters',
    'federacao.communs.cat.cadrages': 'Framings',
    'federacao.communs.read': 'Read',
    'federacao.communs.back': 'Back',
    'federacao.communs.note': 'Draft documents, to be discussed and adopted by consent, then translated into the ten languages.',
    'federacao.communs.doc.mainTendue.title': 'Relational charter — “the extended hand”',
    'federacao.communs.doc.mainTendue.desc': 'AnarBib’s ethic toward people: extend the hand, never grab the wrist.',
    'federacao.communs.doc.langageInclusif.title': 'Inclusive-language charter',
    'federacao.communs.doc.langageInclusif.desc': 'The inclusive conventions of the ten locales — situated, by language community.',
    'federacao.communs.doc.cadrageEntraide.title': 'Framing — mutual aid for cataloging',
    'federacao.communs.doc.cadrageEntraide.desc': 'Vision and architecture of mutual aid: three degrees, the knowledge commons, confidentiality.',
  },
  it: {
    'federacao.tab.communs': 'Beni comuni',
    'federacao.communs.intro': 'I documenti vivi della rete — carte e quadri che orientano AnarBib. Da leggere qui, non sepolti in un repository.',
    'federacao.communs.cat.chartes': 'Carte',
    'federacao.communs.cat.cadrages': 'Quadri',
    'federacao.communs.read': 'Leggi',
    'federacao.communs.back': 'Indietro',
    'federacao.communs.note': 'Documenti in bozza, da discutere e adottare per consenso, poi da tradurre nelle dieci lingue.',
    'federacao.communs.doc.mainTendue.title': 'Carta relazionale — « la mano tesa »',
    'federacao.communs.doc.mainTendue.desc': 'L’etica di AnarBib verso le persone: tendere la mano, mai afferrare il polso.',
    'federacao.communs.doc.langageInclusif.title': 'Carta del linguaggio inclusivo',
    'federacao.communs.doc.langageInclusif.desc': 'Le convenzioni inclusive delle dieci lingue — situate, per comunità linguistica.',
    'federacao.communs.doc.cadrageEntraide.title': 'Quadro — mutuo soccorso nella catalogazione',
    'federacao.communs.doc.cadrageEntraide.desc': 'Visione e architettura del mutuo soccorso: tre gradi, il comune del sapere, la riservatezza.',
  },
  de: {
    'federacao.tab.communs': 'Allmende',
    'federacao.communs.intro': 'Die lebendigen Dokumente des Netzwerks — Chartas und Rahmungen, die AnarBib leiten. Hier zu lesen, nicht in einem Repository vergraben.',
    'federacao.communs.cat.chartes': 'Chartas',
    'federacao.communs.cat.cadrages': 'Rahmungen',
    'federacao.communs.read': 'Lesen',
    'federacao.communs.back': 'Zurück',
    'federacao.communs.note': 'Entwürfe, zu diskutieren und im Konsens anzunehmen, dann in die zehn Sprachen zu übersetzen.',
    'federacao.communs.doc.mainTendue.title': 'Beziehungs-Charta — „die ausgestreckte Hand“',
    'federacao.communs.doc.mainTendue.desc': 'Die Ethik von AnarBib gegenüber Menschen: die Hand reichen, nie das Handgelenk packen.',
    'federacao.communs.doc.langageInclusif.title': 'Charta für inklusive Sprache',
    'federacao.communs.doc.langageInclusif.desc': 'Die inklusiven Konventionen der zehn Sprachen — situiert, je Sprachgemeinschaft.',
    'federacao.communs.doc.cadrageEntraide.title': 'Rahmung — gegenseitige Hilfe beim Katalogisieren',
    'federacao.communs.doc.cadrageEntraide.desc': 'Vision und Architektur der gegenseitigen Hilfe: drei Stufen, das Wissens-Gemeingut, Vertraulichkeit.',
  },
  ca: {
    'federacao.tab.communs': 'Comuns',
    'federacao.communs.intro': 'Els documents vius de la xarxa — cartes i marcs que orienten AnarBib. Per llegir aquí, no enterrats en un repositori.',
    'federacao.communs.cat.chartes': 'Cartes',
    'federacao.communs.cat.cadrages': 'Marcs',
    'federacao.communs.read': 'Llegir',
    'federacao.communs.back': 'Tornar',
    'federacao.communs.note': 'Documents en projecte, a discutir i adoptar per consentiment, després a traduir a les deu llengües.',
    'federacao.communs.doc.mainTendue.title': 'Carta relacional — « la mà estesa »',
    'federacao.communs.doc.mainTendue.desc': 'L’ètica d’AnarBib envers les persones: estendre la mà, mai agafar el canell.',
    'federacao.communs.doc.langageInclusif.title': 'Carta de llenguatge inclusiu',
    'federacao.communs.doc.langageInclusif.desc': 'Les convencions inclusives de les deu locales — situades, per comunitat de llengua.',
    'federacao.communs.doc.cadrageEntraide.title': 'Marc — suport mutu en la catalogació',
    'federacao.communs.doc.cadrageEntraide.desc': 'Visió i arquitectura del suport mutu: tres graus, el comú de saber, la confidencialitat.',
  },
  eo: {
    'federacao.tab.communs': 'Komunaĵoj',
    'federacao.communs.intro': 'La vivantaj dokumentoj de la reto — ĉartoj kaj kadroj kiuj gvidas AnarBib. Por legi ĉi tie, ne enterigitaj en deponejo.',
    'federacao.communs.cat.chartes': 'Ĉartoj',
    'federacao.communs.cat.cadrages': 'Kadroj',
    'federacao.communs.read': 'Legi',
    'federacao.communs.back': 'Reen',
    'federacao.communs.note': 'Malnetaj dokumentoj, por diskuti kaj adopti per konsento, poste traduki en la dek lingvojn.',
    'federacao.communs.doc.mainTendue.title': 'Rilata ĉarto — « la etendita mano »',
    'federacao.communs.doc.mainTendue.desc': 'La etiko de AnarBib al la homoj: etendi la manon, neniam kapti la pojnon.',
    'federacao.communs.doc.langageInclusif.title': 'Ĉarto de inkluziva lingvaĵo',
    'federacao.communs.doc.langageInclusif.desc': 'La inkluzivaj konvencioj de la dek lokaĵoj — situaj, laŭ lingvokomunumo.',
    'federacao.communs.doc.cadrageEntraide.title': 'Kadro — reciproka helpo en katalogado',
    'federacao.communs.doc.cadrageEntraide.desc': 'Vizio kaj arkitekturo de la reciproka helpo: tri gradoj, la scio-komunaĵo, la konfidenco.',
  },
  nl: {
    'federacao.tab.communs': 'Gemeengoed',
    'federacao.communs.intro': 'De levende documenten van het netwerk — handvesten en kaders die AnarBib sturen. Hier te lezen, niet begraven in een repository.',
    'federacao.communs.cat.chartes': 'Handvesten',
    'federacao.communs.cat.cadrages': 'Kaders',
    'federacao.communs.read': 'Lezen',
    'federacao.communs.back': 'Terug',
    'federacao.communs.note': 'Conceptdocumenten, te bespreken en bij consensus aan te nemen, daarna te vertalen in de tien talen.',
    'federacao.communs.doc.mainTendue.title': 'Relationeel handvest — “de uitgestoken hand”',
    'federacao.communs.doc.mainTendue.desc': 'De ethiek van AnarBib tegenover mensen: de hand reiken, nooit de pols grijpen.',
    'federacao.communs.doc.langageInclusif.title': 'Handvest inclusief taalgebruik',
    'federacao.communs.doc.langageInclusif.desc': 'De inclusieve conventies van de tien talen — gesitueerd, per taalgemeenschap.',
    'federacao.communs.doc.cadrageEntraide.title': 'Kader — wederzijdse hulp bij catalogiseren',
    'federacao.communs.doc.cadrageEntraide.desc': 'Visie en architectuur van wederzijdse hulp: drie graden, het kenniscommons, vertrouwelijkheid.',
  },
  el: {
    'federacao.tab.communs': 'Κοινά',
    'federacao.communs.intro': 'Τα ζωντανά έγγραφα του δικτύου — χάρτες και πλαίσια που καθοδηγούν το AnarBib. Διάβασέ τα εδώ, όχι θαμμένα σε ένα αποθετήριο.',
    'federacao.communs.cat.chartes': 'Χάρτες',
    'federacao.communs.cat.cadrages': 'Πλαίσια',
    'federacao.communs.read': 'Διάβασε',
    'federacao.communs.back': 'Πίσω',
    'federacao.communs.note': 'Έγγραφα σε σχέδιο, προς συζήτηση και υιοθέτηση με συναίνεση, και έπειτα μετάφραση στις δέκα γλώσσες.',
    'federacao.communs.doc.mainTendue.title': 'Σχεσιακός χάρτης — «το απλωμένο χέρι»',
    'federacao.communs.doc.mainTendue.desc': 'Η ηθική του AnarBib προς τους ανθρώπους: άπλωσε το χέρι, ποτέ μην αρπάξεις τον καρπό.',
    'federacao.communs.doc.langageInclusif.title': 'Χάρτης συμπεριληπτικής γλώσσας',
    'federacao.communs.doc.langageInclusif.desc': 'Οι συμπεριληπτικές συμβάσεις των δέκα γλωσσών — τοποθετημένες, ανά γλωσσική κοινότητα.',
    'federacao.communs.doc.cadrageEntraide.title': 'Πλαίσιο — αλληλοβοήθεια στην καταλογογράφηση',
    'federacao.communs.doc.cadrageEntraide.desc': 'Όραμα και αρχιτεκτονική της αλληλοβοήθειας: τρεις βαθμοί, το κοινό της γνώσης, η εμπιστευτικότητα.',
  },
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const map = ADD[loc];
    const keys = Object.keys(ADD.fr);
    const entries = keys.map((k) => {
      if (map[k] == null) throw new Error('Traduction manquante: ' + k + ' / ' + loc);
      return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(map[k]);
    });
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 13 clés communs (si absentes), JSON valide.');
}
console.log('\nTerminé.');
