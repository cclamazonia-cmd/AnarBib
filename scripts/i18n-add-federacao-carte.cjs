/* ===========================================================================
 * i18n-add-federacao-carte.cjs
 * Ajoute les clés de l'onglet « Carte » (carte du réseau) aux 10 locales.
 * Méthode sûre (doctrine anarbib-i18n) : insertion textuelle avant le `}` final,
 * idempotente. 2 espaces, LF, UTF-8 sans BOM. Sentinelle = federacao.tab.carte.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.tab.carte';

const BYLOCALE = {
  'pt-BR': {
    "federacao.tab.carte": "Mapa",
    "federacao.carte.lead": "Os coletivos libertários com biblioteca pelo mundo. A cor do marcador indica o tipo de lugar; clique num ponto para ver os detalhes.",
    "federacao.carte.count": "{shown} / {total} coletivos",
    "federacao.carte.search": "Buscar (nome, cidade, país)…",
    "federacao.carte.member": "membro da rede",
    "federacao.carte.network": "rede",
    "federacao.carte.error": "Mapa indisponível no momento.",
    "federacao.carte.attribution": "Mapa colaborativo — base OpenStreetMap.",
    "federacao.carte.cat.biblioteca": "Biblioteca",
    "federacao.carte.cat.arquivo": "Arquivo",
    "federacao.carte.cat.centro_doc": "Centro de documentação",
    "federacao.carte.cat.ateneu": "Ateneu",
    "federacao.carte.cat.livraria": "Livraria",
    "federacao.carte.cat.misto": "Espaço misto"
  },
  fr: {
    "federacao.tab.carte": "Carte",
    "federacao.carte.lead": "Les collectifs libertaires avec bibliothèque à travers le monde. La couleur du marqueur indique le type de lieu ; clique sur un point pour le détail.",
    "federacao.carte.count": "{shown} / {total} collectifs",
    "federacao.carte.search": "Rechercher (nom, ville, pays)…",
    "federacao.carte.member": "membre du réseau",
    "federacao.carte.network": "réseau",
    "federacao.carte.error": "Carte indisponible pour le moment.",
    "federacao.carte.attribution": "Carte collaborative — fond OpenStreetMap.",
    "federacao.carte.cat.biblioteca": "Bibliothèque",
    "federacao.carte.cat.arquivo": "Archive",
    "federacao.carte.cat.centro_doc": "Centre de documentation",
    "federacao.carte.cat.ateneu": "Athénée",
    "federacao.carte.cat.livraria": "Librairie",
    "federacao.carte.cat.misto": "Espace mixte"
  },
  es: {
    "federacao.tab.carte": "Mapa",
    "federacao.carte.lead": "Los colectivos libertarios con biblioteca por todo el mundo. El color del marcador indica el tipo de lugar; hacé clic en un punto para ver el detalle.",
    "federacao.carte.count": "{shown} / {total} colectivos",
    "federacao.carte.search": "Buscar (nombre, ciudad, país)…",
    "federacao.carte.member": "miembro de la red",
    "federacao.carte.network": "red",
    "federacao.carte.error": "Mapa no disponible por el momento.",
    "federacao.carte.attribution": "Mapa colaborativo — base OpenStreetMap.",
    "federacao.carte.cat.biblioteca": "Biblioteca",
    "federacao.carte.cat.arquivo": "Archivo",
    "federacao.carte.cat.centro_doc": "Centro de documentación",
    "federacao.carte.cat.ateneu": "Ateneo",
    "federacao.carte.cat.livraria": "Librería",
    "federacao.carte.cat.misto": "Espacio mixto"
  },
  en: {
    "federacao.tab.carte": "Map",
    "federacao.carte.lead": "Libertarian collectives with a library around the world. The marker colour shows the type of place; click a point for details.",
    "federacao.carte.count": "{shown} / {total} collectives",
    "federacao.carte.search": "Search (name, city, country)…",
    "federacao.carte.member": "network member",
    "federacao.carte.network": "network",
    "federacao.carte.error": "Map unavailable right now.",
    "federacao.carte.attribution": "Collaborative map — OpenStreetMap basemap.",
    "federacao.carte.cat.biblioteca": "Library",
    "federacao.carte.cat.arquivo": "Archive",
    "federacao.carte.cat.centro_doc": "Documentation centre",
    "federacao.carte.cat.ateneu": "Athenaeum",
    "federacao.carte.cat.livraria": "Bookshop",
    "federacao.carte.cat.misto": "Mixed space"
  },
  it: {
    "federacao.tab.carte": "Mappa",
    "federacao.carte.lead": "I collettivi libertari con biblioteca nel mondo. Il colore del marcatore indica il tipo di luogo; clicca su un punto per i dettagli.",
    "federacao.carte.count": "{shown} / {total} collettivi",
    "federacao.carte.search": "Cerca (nome, città, paese)…",
    "federacao.carte.member": "membro della rete",
    "federacao.carte.network": "rete",
    "federacao.carte.error": "Mappa non disponibile al momento.",
    "federacao.carte.attribution": "Mappa collaborativa — base OpenStreetMap.",
    "federacao.carte.cat.biblioteca": "Biblioteca",
    "federacao.carte.cat.arquivo": "Archivio",
    "federacao.carte.cat.centro_doc": "Centro di documentazione",
    "federacao.carte.cat.ateneu": "Ateneo",
    "federacao.carte.cat.livraria": "Libreria",
    "federacao.carte.cat.misto": "Spazio misto"
  },
  de: {
    "federacao.tab.carte": "Karte",
    "federacao.carte.lead": "Libertäre Kollektive mit Bibliothek weltweit. Die Markerfarbe zeigt die Art des Ortes; klicke auf einen Punkt für Details.",
    "federacao.carte.count": "{shown} / {total} Kollektive",
    "federacao.carte.search": "Suchen (Name, Stadt, Land)…",
    "federacao.carte.member": "Netzwerkmitglied",
    "federacao.carte.network": "Netzwerk",
    "federacao.carte.error": "Karte momentan nicht verfügbar.",
    "federacao.carte.attribution": "Kollaborative Karte — Kartengrundlage OpenStreetMap.",
    "federacao.carte.cat.biblioteca": "Bibliothek",
    "federacao.carte.cat.arquivo": "Archiv",
    "federacao.carte.cat.centro_doc": "Dokumentationszentrum",
    "federacao.carte.cat.ateneu": "Athenäum",
    "federacao.carte.cat.livraria": "Buchhandlung",
    "federacao.carte.cat.misto": "Gemischter Raum"
  },
  ca: {
    "federacao.tab.carte": "Mapa",
    "federacao.carte.lead": "Els col·lectius llibertaris amb biblioteca arreu del món. El color del marcador indica el tipus de lloc; fes clic en un punt per veure'n el detall.",
    "federacao.carte.count": "{shown} / {total} col·lectius",
    "federacao.carte.search": "Cerca (nom, ciutat, país)…",
    "federacao.carte.member": "membre de la xarxa",
    "federacao.carte.network": "xarxa",
    "federacao.carte.error": "Mapa no disponible ara mateix.",
    "federacao.carte.attribution": "Mapa col·laboratiu — base OpenStreetMap.",
    "federacao.carte.cat.biblioteca": "Biblioteca",
    "federacao.carte.cat.arquivo": "Arxiu",
    "federacao.carte.cat.centro_doc": "Centre de documentació",
    "federacao.carte.cat.ateneu": "Ateneu",
    "federacao.carte.cat.livraria": "Llibreria",
    "federacao.carte.cat.misto": "Espai mixt"
  },
  eo: {
    "federacao.tab.carte": "Mapo",
    "federacao.carte.lead": "La liberecanaj kolektivoj kun biblioteko tra la mondo. La koloro de la markilo montras la tipon de loko; alklaku punkton por detaloj.",
    "federacao.carte.count": "{shown} / {total} kolektivoj",
    "federacao.carte.search": "Serĉi (nomo, urbo, lando)…",
    "federacao.carte.member": "membro de la reto",
    "federacao.carte.network": "reto",
    "federacao.carte.error": "Mapo nedisponebla nuntempe.",
    "federacao.carte.attribution": "Kunlabora mapo — bazo OpenStreetMap.",
    "federacao.carte.cat.biblioteca": "Biblioteko",
    "federacao.carte.cat.arquivo": "Arkivo",
    "federacao.carte.cat.centro_doc": "Dokumentadcentro",
    "federacao.carte.cat.ateneu": "Ateneo",
    "federacao.carte.cat.livraria": "Librovendejo",
    "federacao.carte.cat.misto": "Miksa spaco"
  },
  nl: {
    "federacao.tab.carte": "Kaart",
    "federacao.carte.lead": "Libertaire collectieven met een bibliotheek wereldwijd. De kleur van de markering geeft het type plek aan; klik op een punt voor details.",
    "federacao.carte.count": "{shown} / {total} collectieven",
    "federacao.carte.search": "Zoeken (naam, stad, land)…",
    "federacao.carte.member": "netwerklid",
    "federacao.carte.network": "netwerk",
    "federacao.carte.error": "Kaart momenteel niet beschikbaar.",
    "federacao.carte.attribution": "Collaboratieve kaart — ondergrond OpenStreetMap.",
    "federacao.carte.cat.biblioteca": "Bibliotheek",
    "federacao.carte.cat.arquivo": "Archief",
    "federacao.carte.cat.centro_doc": "Documentatiecentrum",
    "federacao.carte.cat.ateneu": "Atheneum",
    "federacao.carte.cat.livraria": "Boekhandel",
    "federacao.carte.cat.misto": "Gemengde ruimte"
  },
  el: {
    "federacao.tab.carte": "Χάρτης",
    "federacao.carte.lead": "Οι ελευθεριακές συλλογικότητες με βιβλιοθήκη σε όλο τον κόσμο. Το χρώμα του δείκτη δηλώνει τον τύπο του χώρου· κάντε κλικ σε ένα σημείο για λεπτομέρειες.",
    "federacao.carte.count": "{shown} / {total} συλλογικότητες",
    "federacao.carte.search": "Αναζήτηση (όνομα, πόλη, χώρα)…",
    "federacao.carte.member": "μέλος του δικτύου",
    "federacao.carte.network": "δίκτυο",
    "federacao.carte.error": "Ο χάρτης δεν είναι διαθέσιμος αυτή τη στιγμή.",
    "federacao.carte.attribution": "Συνεργατικός χάρτης — υπόβαθρο OpenStreetMap.",
    "federacao.carte.cat.biblioteca": "Βιβλιοθήκη",
    "federacao.carte.cat.arquivo": "Αρχείο",
    "federacao.carte.cat.centro_doc": "Κέντρο τεκμηρίωσης",
    "federacao.carte.cat.ateneu": "Αθήναιον",
    "federacao.carte.cat.livraria": "Βιβλιοπωλείο",
    "federacao.carte.cat.misto": "Μικτός χώρος"
  }
};

let totalAdded = 0;
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (content.includes('"' + SENTINEL + '"')) {
    console.log(`${loc}: déjà présent, sauté.`);
    continue;
  }
  const map = BYLOCALE[loc];
  if (!map) throw new Error(`Locale manquante dans BYLOCALE: ${loc}`);
  const keys = Object.keys(BYLOCALE['pt-BR']);
  const entries = keys.map((k) => {
    const v = map[k];
    if (v == null) throw new Error(`Traduction manquante: ${k} / ${loc}`);
    return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(v);
  });
  const marker = content.lastIndexOf('}');
  const head = content.slice(0, marker).replace(/\s*$/, '');
  const tail = content.slice(marker);
  content = head + ',\n' + entries.join(',\n') + '\n' + tail;
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  totalAdded += entries.length;
  console.log(`${loc}: +${entries.length} clés, JSON valide.`);
}
console.log(`\nTerminé. ${totalAdded} insertions.`);
