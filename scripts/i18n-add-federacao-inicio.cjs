/* ===========================================================================
 * i18n-add-federacao-inicio.cjs
 * Onglet Accueil de la fédération : ajoute 7 clés + reformule inicio.body,
 * dans les 10 locales. Insertion idempotente (sentinelle federacao.inicio.pending).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.inicio.pending';

const ADD = {
  'pt-BR': {
    "federacao.inicio.welcome": "Boas-vindas à federação",
    "federacao.inicio.pending": "O que te espera",
    "federacao.inicio.pending.body": "Um pedido de adesão aguarda o consentimento do círculo « {circle} ».",
    "federacao.inicio.annuaire": "O diretório dos coletivos",
    "federacao.inicio.toCircles": "Abrir os círculos",
    "federacao.inicio.toAnnuaire": "Abrir o diretório",
    "federacao.inicio.soon": "Em breve"
  },
  fr: {
    "federacao.inicio.welcome": "Bienvenue dans la fédération",
    "federacao.inicio.pending": "Ce qui t’attend",
    "federacao.inicio.pending.body": "Une demande d’adhésion attend le consentement du cercle « {circle} ».",
    "federacao.inicio.annuaire": "L’annuaire des collectifs",
    "federacao.inicio.toCircles": "Ouvrir les cercles",
    "federacao.inicio.toAnnuaire": "Ouvrir l’annuaire",
    "federacao.inicio.soon": "À venir"
  },
  es: {
    "federacao.inicio.welcome": "Bienvenida a la federación",
    "federacao.inicio.pending": "Lo que te espera",
    "federacao.inicio.pending.body": "Una solicitud de adhesión espera el consentimiento del círculo « {circle} ».",
    "federacao.inicio.annuaire": "El directorio de los colectivos",
    "federacao.inicio.toCircles": "Abrir los círculos",
    "federacao.inicio.toAnnuaire": "Abrir el directorio",
    "federacao.inicio.soon": "Próximamente"
  },
  en: {
    "federacao.inicio.welcome": "Welcome to the federation",
    "federacao.inicio.pending": "What awaits you",
    "federacao.inicio.pending.body": "A membership request is awaiting the consent of the « {circle} » circle.",
    "federacao.inicio.annuaire": "The directory of collectives",
    "federacao.inicio.toCircles": "Open the circles",
    "federacao.inicio.toAnnuaire": "Open the directory",
    "federacao.inicio.soon": "Coming soon"
  },
  it: {
    "federacao.inicio.welcome": "Benvenuti nella federazione",
    "federacao.inicio.pending": "Ciò che ti aspetta",
    "federacao.inicio.pending.body": "Una richiesta di adesione attende il consenso del circolo « {circle} ».",
    "federacao.inicio.annuaire": "L’elenco dei collettivi",
    "federacao.inicio.toCircles": "Apri i cerchi",
    "federacao.inicio.toAnnuaire": "Apri l’elenco",
    "federacao.inicio.soon": "Prossimamente"
  },
  de: {
    "federacao.inicio.welcome": "Willkommen in der Föderation",
    "federacao.inicio.pending": "Was dich erwartet",
    "federacao.inicio.pending.body": "Ein Beitrittsgesuch wartet auf die Zustimmung des Kreises « {circle} ».",
    "federacao.inicio.annuaire": "Das Verzeichnis der Kollektive",
    "federacao.inicio.toCircles": "Kreise öffnen",
    "federacao.inicio.toAnnuaire": "Verzeichnis öffnen",
    "federacao.inicio.soon": "Demnächst"
  },
  ca: {
    "federacao.inicio.welcome": "Benvinguda a la federació",
    "federacao.inicio.pending": "El que t’espera",
    "federacao.inicio.pending.body": "Una sol·licitud d’adhesió espera el consentiment del cercle « {circle} ».",
    "federacao.inicio.annuaire": "El directori dels col·lectius",
    "federacao.inicio.toCircles": "Obrir els cercles",
    "federacao.inicio.toAnnuaire": "Obrir el directori",
    "federacao.inicio.soon": "Properament"
  },
  eo: {
    "federacao.inicio.welcome": "Bonvenon al la federacio",
    "federacao.inicio.pending": "Kio atendas vin",
    "federacao.inicio.pending.body": "Aliĝpeto atendas la konsenton de la rondo « {circle} ».",
    "federacao.inicio.annuaire": "La adresaro de la kolektivoj",
    "federacao.inicio.toCircles": "Malfermi la rondojn",
    "federacao.inicio.toAnnuaire": "Malfermi la adresaron",
    "federacao.inicio.soon": "Baldaŭ"
  },
  nl: {
    "federacao.inicio.welcome": "Welkom bij de federatie",
    "federacao.inicio.pending": "Wat je te wachten staat",
    "federacao.inicio.pending.body": "Een toetredingsverzoek wacht op de instemming van de kring « {circle} ».",
    "federacao.inicio.annuaire": "De gids van de collectieven",
    "federacao.inicio.toCircles": "Kringen openen",
    "federacao.inicio.toAnnuaire": "Gids openen",
    "federacao.inicio.soon": "Binnenkort"
  },
  el: {
    "federacao.inicio.welcome": "Καλώς ήρθατε στην ομοσπονδία",
    "federacao.inicio.pending": "Τι σας περιμένει",
    "federacao.inicio.pending.body": "Ένα αίτημα ένταξης περιμένει τη συναίνεση του κύκλου « {circle} ».",
    "federacao.inicio.annuaire": "Ο κατάλογος των συλλογικοτήτων",
    "federacao.inicio.toCircles": "Άνοιγμα των κύκλων",
    "federacao.inicio.toAnnuaire": "Άνοιγμα του καταλόγου",
    "federacao.inicio.soon": "Σύντομα"
  }
};

const BODY = {
  'pt-BR': "Sem painel, sem números — seus círculos, as portas abertas, e o diretório dos coletivos.",
  fr: "Pas de tableau de bord, pas de chiffres — tes cercles, les portes ouvertes, et l’annuaire des collectifs.",
  es: "Sin panel, sin números — tus círculos, las puertas abiertas y el directorio de los colectivos.",
  en: "No dashboard, no numbers — your circles, the open doors, and the directory of collectives.",
  it: "Nessun pannello, nessun numero — i tuoi cerchi, le porte aperte e l’elenco dei collettivi.",
  de: "Kein Dashboard, keine Zahlen — deine Kreise, die offenen Türen und das Verzeichnis der Kollektive.",
  ca: "Sense panell, sense números — els teus cercles, les portes obertes i el directori dels col·lectius.",
  eo: "Neniu panelo, neniuj nombroj — viaj rondoj, la malfermitaj pordoj, kaj la adresaro de la kolektivoj.",
  nl: "Geen dashboard, geen cijfers — jouw kringen, de open deuren, en de gids van de collectieven.",
  el: "Κανένας πίνακας, κανένας αριθμός — οι κύκλοι σου, οι ανοιχτές πόρτες, και ο κατάλογος των συλλογικοτήτων.",
};

function setKey(content, key, value) {
  const re = new RegExp('("' + key.replace(/\./g, '\\.') + '":\\s*)"[^"]*"');
  if (!re.test(content)) throw new Error('clé introuvable pour update: ' + key);
  return content.replace(re, '$1' + JSON.stringify(value));
}

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  content = setKey(content, 'federacao.inicio.body', BODY[loc]); // reformulation
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
  console.log(loc + ': inicio.body reformulé + 7 clés (si absentes), JSON valide.');
}
console.log('\nTerminé.');
