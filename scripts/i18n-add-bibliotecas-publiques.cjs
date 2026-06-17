/* ===========================================================================
 * i18n-add-bibliotecas-publiques.cjs
 * Annuaire public /bibliotecas (#PUB1) + fiche publique /bibliotecas/:slug (#PUB2).
 * 13 clés × 10 locales. Idempotent (sentinelle bibliotecaPublica.back).
 * Chaînes neutres (charte langage inclusif : pas de marqueur genré nécessaire).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'bibliotecaPublica.back';

const ADD = {
  'pt-BR': {
    'pageTitle.bibliotecas': 'Bibliotecas',
    'pageTitle.bibliotecaPublica': 'Biblioteca',
    'bibliotecas.title': 'Bibliotecas da rede',
    'bibliotecas.subtitle': 'As bibliotecas anarquistas que compõem a rede AnarBib.',
    'bibliotecas.empty': 'Nenhuma biblioteca pública por enquanto.',
    'bibliotecas.noticesCount': '{count} registros',
    'bibliotecas.status.online': 'Catálogo on-line',
    'bibliotecas.status.building': 'Em construção',
    'bibliotecas.viewCatalog': 'Ver o catálogo',
    'bibliotecas.website': 'Site',
    'bibliotecaPublica.notFound': 'Biblioteca não encontrada.',
    'bibliotecaPublica.serviceMessage': 'Recado da biblioteca',
    'bibliotecaPublica.back': '← Todas as bibliotecas',
  },
  fr: {
    'pageTitle.bibliotecas': 'Bibliothèques',
    'pageTitle.bibliotecaPublica': 'Bibliothèque',
    'bibliotecas.title': 'Bibliothèques du réseau',
    'bibliotecas.subtitle': 'Les bibliothèques anarchistes qui composent le réseau AnarBib.',
    'bibliotecas.empty': 'Aucune bibliothèque publique pour le moment.',
    'bibliotecas.noticesCount': '{count} notices',
    'bibliotecas.status.online': 'Catalogue en ligne',
    'bibliotecas.status.building': 'En construction',
    'bibliotecas.viewCatalog': 'Parcourir le catalogue',
    'bibliotecas.website': 'Site web',
    'bibliotecaPublica.notFound': 'Bibliothèque introuvable.',
    'bibliotecaPublica.serviceMessage': 'Le mot de la bibliothèque',
    'bibliotecaPublica.back': '← Toutes les bibliothèques',
  },
  es: {
    'pageTitle.bibliotecas': 'Bibliotecas',
    'pageTitle.bibliotecaPublica': 'Biblioteca',
    'bibliotecas.title': 'Bibliotecas de la red',
    'bibliotecas.subtitle': 'Las bibliotecas anarquistas que componen la red AnarBib.',
    'bibliotecas.empty': 'Ninguna biblioteca pública por ahora.',
    'bibliotecas.noticesCount': '{count} registros',
    'bibliotecas.status.online': 'Catálogo en línea',
    'bibliotecas.status.building': 'En construcción',
    'bibliotecas.viewCatalog': 'Ver el catálogo',
    'bibliotecas.website': 'Sitio web',
    'bibliotecaPublica.notFound': 'Biblioteca no encontrada.',
    'bibliotecaPublica.serviceMessage': 'Mensaje de la biblioteca',
    'bibliotecaPublica.back': '← Todas las bibliotecas',
  },
  en: {
    'pageTitle.bibliotecas': 'Libraries',
    'pageTitle.bibliotecaPublica': 'Library',
    'bibliotecas.title': 'Libraries in the network',
    'bibliotecas.subtitle': 'The anarchist libraries that make up the AnarBib network.',
    'bibliotecas.empty': 'No public library yet.',
    'bibliotecas.noticesCount': '{count} records',
    'bibliotecas.status.online': 'Online catalogue',
    'bibliotecas.status.building': 'Under construction',
    'bibliotecas.viewCatalog': 'Browse the catalogue',
    'bibliotecas.website': 'Website',
    'bibliotecaPublica.notFound': 'Library not found.',
    'bibliotecaPublica.serviceMessage': 'A word from the library',
    'bibliotecaPublica.back': '← All libraries',
  },
  it: {
    'pageTitle.bibliotecas': 'Biblioteche',
    'pageTitle.bibliotecaPublica': 'Biblioteca',
    'bibliotecas.title': 'Biblioteche della rete',
    'bibliotecas.subtitle': 'Le biblioteche anarchiche che compongono la rete AnarBib.',
    'bibliotecas.empty': 'Nessuna biblioteca pubblica per ora.',
    'bibliotecas.noticesCount': '{count} schede',
    'bibliotecas.status.online': 'Catalogo online',
    'bibliotecas.status.building': 'In costruzione',
    'bibliotecas.viewCatalog': 'Sfoglia il catalogo',
    'bibliotecas.website': 'Sito web',
    'bibliotecaPublica.notFound': 'Biblioteca non trovata.',
    'bibliotecaPublica.serviceMessage': 'Un messaggio dalla biblioteca',
    'bibliotecaPublica.back': '← Tutte le biblioteche',
  },
  de: {
    'pageTitle.bibliotecas': 'Bibliotheken',
    'pageTitle.bibliotecaPublica': 'Bibliothek',
    'bibliotecas.title': 'Bibliotheken im Netzwerk',
    'bibliotecas.subtitle': 'Die anarchistischen Bibliotheken des AnarBib-Netzwerks.',
    'bibliotecas.empty': 'Noch keine öffentliche Bibliothek.',
    'bibliotecas.noticesCount': '{count} Titel',
    'bibliotecas.status.online': 'Online-Katalog',
    'bibliotecas.status.building': 'Im Aufbau',
    'bibliotecas.viewCatalog': 'Katalog durchsuchen',
    'bibliotecas.website': 'Website',
    'bibliotecaPublica.notFound': 'Bibliothek nicht gefunden.',
    'bibliotecaPublica.serviceMessage': 'Ein Wort der Bibliothek',
    'bibliotecaPublica.back': '← Alle Bibliotheken',
  },
  ca: {
    'pageTitle.bibliotecas': 'Biblioteques',
    'pageTitle.bibliotecaPublica': 'Biblioteca',
    'bibliotecas.title': 'Biblioteques de la xarxa',
    'bibliotecas.subtitle': 'Les biblioteques anarquistes que formen la xarxa AnarBib.',
    'bibliotecas.empty': 'Cap biblioteca pública de moment.',
    'bibliotecas.noticesCount': '{count} registres',
    'bibliotecas.status.online': 'Catàleg en línia',
    'bibliotecas.status.building': 'En construcció',
    'bibliotecas.viewCatalog': 'Veure el catàleg',
    'bibliotecas.website': 'Lloc web',
    'bibliotecaPublica.notFound': 'Biblioteca no trobada.',
    'bibliotecaPublica.serviceMessage': 'Unes paraules de la biblioteca',
    'bibliotecaPublica.back': '← Totes les biblioteques',
  },
  eo: {
    'pageTitle.bibliotecas': 'Bibliotekoj',
    'pageTitle.bibliotecaPublica': 'Biblioteko',
    'bibliotecas.title': 'Bibliotekoj de la reto',
    'bibliotecas.subtitle': 'La anarkiismaj bibliotekoj kiuj formas la reton AnarBib.',
    'bibliotecas.empty': 'Ankoraŭ neniu publika biblioteko.',
    'bibliotecas.noticesCount': '{count} registroj',
    'bibliotecas.status.online': 'Reta katalogo',
    'bibliotecas.status.building': 'En konstruado',
    'bibliotecas.viewCatalog': 'Foliumi la katalogon',
    'bibliotecas.website': 'Retejo',
    'bibliotecaPublica.notFound': 'Biblioteko ne trovita.',
    'bibliotecaPublica.serviceMessage': 'Vorto de la biblioteko',
    'bibliotecaPublica.back': '← Ĉiuj bibliotekoj',
  },
  nl: {
    'pageTitle.bibliotecas': 'Bibliotheken',
    'pageTitle.bibliotecaPublica': 'Bibliotheek',
    'bibliotecas.title': 'Bibliotheken in het netwerk',
    'bibliotecas.subtitle': 'De anarchistische bibliotheken die het AnarBib-netwerk vormen.',
    'bibliotecas.empty': 'Nog geen openbare bibliotheek.',
    'bibliotecas.noticesCount': '{count} titels',
    'bibliotecas.status.online': 'Online catalogus',
    'bibliotecas.status.building': 'In opbouw',
    'bibliotecas.viewCatalog': 'Bekijk de catalogus',
    'bibliotecas.website': 'Website',
    'bibliotecaPublica.notFound': 'Bibliotheek niet gevonden.',
    'bibliotecaPublica.serviceMessage': 'Een woord van de bibliotheek',
    'bibliotecaPublica.back': '← Alle bibliotheken',
  },
  el: {
    'pageTitle.bibliotecas': 'Βιβλιοθήκες',
    'pageTitle.bibliotecaPublica': 'Βιβλιοθήκη',
    'bibliotecas.title': 'Βιβλιοθήκες του δικτύου',
    'bibliotecas.subtitle': 'Οι αναρχικές βιβλιοθήκες που απαρτίζουν το δίκτυο AnarBib.',
    'bibliotecas.empty': 'Καμία δημόσια βιβλιοθήκη ακόμη.',
    'bibliotecas.noticesCount': '{count} εγγραφές',
    'bibliotecas.status.online': 'Διαδικτυακός κατάλογος',
    'bibliotecas.status.building': 'Υπό κατασκευή',
    'bibliotecas.viewCatalog': 'Περιήγηση στον κατάλογο',
    'bibliotecas.website': 'Ιστότοπος',
    'bibliotecaPublica.notFound': 'Η βιβλιοθήκη δεν βρέθηκε.',
    'bibliotecaPublica.serviceMessage': 'Ένα μήνυμα από τη βιβλιοθήκη',
    'bibliotecaPublica.back': '← Όλες οι βιβλιοθήκες',
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
  console.log(loc + ': 13 clés (si absentes), JSON valide.');
}
console.log('\nTerminé.');
