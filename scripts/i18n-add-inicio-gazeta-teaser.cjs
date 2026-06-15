/* ===========================================================================
 * i18n-add-inicio-gazeta-teaser.cjs
 * Teaser « Gazette » dans l'onglet Accueil de la fédération : 4 clés
 * (titre, description, CTA, pill « Nouveau ») dans les 10 locales.
 * Insertion idempotente (sentinelle federacao.inicio.gazeta).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.inicio.gazeta';

const ADD = {
  'pt-BR': {
    'federacao.inicio.gazeta': 'A gazeta da rede',
    'federacao.inicio.gazeta.desc': 'Números mensais — lutas, culturas, agenda, apoio mútuo.',
    'federacao.inicio.toGazeta': 'Abrir a gazeta',
    'federacao.inicio.new': 'Novo',
  },
  fr: {
    'federacao.inicio.gazeta': 'La gazette du réseau',
    'federacao.inicio.gazeta.desc': 'Numéros mensuels — luttes, cultures, agenda, entraide.',
    'federacao.inicio.toGazeta': 'Ouvrir la gazette',
    'federacao.inicio.new': 'Nouveau',
  },
  es: {
    'federacao.inicio.gazeta': 'La gaceta de la red',
    'federacao.inicio.gazeta.desc': 'Números mensuales — luchas, culturas, agenda, apoyo mutuo.',
    'federacao.inicio.toGazeta': 'Abrir la gaceta',
    'federacao.inicio.new': 'Nuevo',
  },
  en: {
    'federacao.inicio.gazeta': 'The network gazette',
    'federacao.inicio.gazeta.desc': 'Monthly issues — struggles, cultures, agenda, mutual aid.',
    'federacao.inicio.toGazeta': 'Open the gazette',
    'federacao.inicio.new': 'New',
  },
  it: {
    'federacao.inicio.gazeta': 'La gazzetta della rete',
    'federacao.inicio.gazeta.desc': 'Numeri mensili — lotte, culture, agenda, mutuo soccorso.',
    'federacao.inicio.toGazeta': 'Apri la gazzetta',
    'federacao.inicio.new': 'Nuovo',
  },
  de: {
    'federacao.inicio.gazeta': 'Die Gazette des Netzwerks',
    'federacao.inicio.gazeta.desc': 'Monatliche Ausgaben — Kämpfe, Kulturen, Termine, gegenseitige Hilfe.',
    'federacao.inicio.toGazeta': 'Gazette öffnen',
    'federacao.inicio.new': 'Neu',
  },
  ca: {
    'federacao.inicio.gazeta': 'La gaseta de la xarxa',
    'federacao.inicio.gazeta.desc': 'Números mensuals — lluites, cultures, agenda, suport mutu.',
    'federacao.inicio.toGazeta': 'Obrir la gaseta',
    'federacao.inicio.new': 'Nou',
  },
  eo: {
    'federacao.inicio.gazeta': 'La gazeto de la reto',
    'federacao.inicio.gazeta.desc': 'Monataj numeroj — luktoj, kulturoj, tagordo, reciproka helpo.',
    'federacao.inicio.toGazeta': 'Malfermi la gazeton',
    'federacao.inicio.new': 'Nova',
  },
  nl: {
    'federacao.inicio.gazeta': 'De gazette van het netwerk',
    'federacao.inicio.gazeta.desc': 'Maandelijkse nummers — strijd, cultuur, agenda, wederzijdse hulp.',
    'federacao.inicio.toGazeta': 'Gazette openen',
    'federacao.inicio.new': 'Nieuw',
  },
  el: {
    'federacao.inicio.gazeta': 'Η εφημερίδα του δικτύου',
    'federacao.inicio.gazeta.desc': 'Μηνιαία τεύχη — αγώνες, κουλτούρες, ατζέντα, αλληλοβοήθεια.',
    'federacao.inicio.toGazeta': 'Άνοιγμα της εφημερίδας',
    'federacao.inicio.new': 'Νέο',
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
  console.log(loc + ': 4 clés teaser gazette (si absentes), JSON valide.');
}
console.log('\nTerminé.');
