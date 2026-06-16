/* ===========================================================================
 * i18n-add-inicio-lettre.cjs
 * Pill « Lettre de la fédération » sur l'accueil Início : 3 clés UI dans les 10
 * locales. Insertion idempotente (sentinelle federacao.inicio.toLettre).
 * Convention reprise de i18n-add-federacao-gazeta.cjs.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.inicio.toLettre';

const ADD = {
  'pt-BR': {
    'federacao.inicio.lettre': 'Boletim da rede',
    'federacao.inicio.lettre.desc': 'O caderno da rede na tua caixa de entrada, se pedires.',
    'federacao.inicio.toLettre': 'Inscrever-me',
  },
  fr: {
    'federacao.inicio.lettre': 'Lettre de la fédération',
    'federacao.inicio.lettre.desc': 'Le carnet du réseau dans ta boîte mail, si tu le demandes.',
    'federacao.inicio.toLettre': 'M’abonner',
  },
  es: {
    'federacao.inicio.lettre': 'Boletín de la red',
    'federacao.inicio.lettre.desc': 'El cuaderno de la red en tu correo, si lo pides.',
    'federacao.inicio.toLettre': 'Suscribirme',
  },
  en: {
    'federacao.inicio.lettre': 'Federation letter',
    'federacao.inicio.lettre.desc': 'The network’s notebook in your inbox, if you ask for it.',
    'federacao.inicio.toLettre': 'Subscribe',
  },
  it: {
    'federacao.inicio.lettre': 'Lettera della rete',
    'federacao.inicio.lettre.desc': 'Il taccuino della rete nella tua casella, se lo chiedi.',
    'federacao.inicio.toLettre': 'Iscrivermi',
  },
  de: {
    'federacao.inicio.lettre': 'Netzwerk-Rundbrief',
    'federacao.inicio.lettre.desc': 'Das Notizbuch des Netzwerks in deinem Postfach, wenn du möchtest.',
    'federacao.inicio.toLettre': 'Abonnieren',
  },
  ca: {
    'federacao.inicio.lettre': 'Butlletí de la xarxa',
    'federacao.inicio.lettre.desc': 'El quadern de la xarxa al teu correu, si ho demanes.',
    'federacao.inicio.toLettre': 'Subscriure’m',
  },
  eo: {
    'federacao.inicio.lettre': 'Reta bulteno',
    'federacao.inicio.lettre.desc': 'La kajero de la reto en via leterkesto, se vi petas.',
    'federacao.inicio.toLettre': 'Aboni',
  },
  nl: {
    'federacao.inicio.lettre': 'Nieuwsbrief van het netwerk',
    'federacao.inicio.lettre.desc': 'Het logboek van het netwerk in je inbox, als je erom vraagt.',
    'federacao.inicio.toLettre': 'Inschrijven',
  },
  el: {
    'federacao.inicio.lettre': 'Ενημερωτικό δελτίο του δικτύου',
    'federacao.inicio.lettre.desc': 'Το σημειωματάριο του δικτύου στα εισερχόμενά σου, αν το ζητήσεις.',
    'federacao.inicio.toLettre': 'Εγγραφή',
  },
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
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 3 clés inicio.lettre (si absentes), JSON valide.');
}
console.log('\nTerminé.');
