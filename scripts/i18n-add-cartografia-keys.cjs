#!/usr/bin/env node
/* eslint-disable */
// ============================================================================
// i18n-add-cartografia-keys.cjs
// Auteur : AnarBib · Session : Carte réseau 10 locales
// Ajoute (parité 10 locales) les clés du filtre réseau/paysage (MAP-G), du
// message « aucun résultat », et de la page publique /cartografia (MAP-C).
// Idempotent : n'écrase pas une clé déjà présente. Écrit en UTF-8 sans BOM,
// indentation 2 espaces, ordre existant préservé (nouvelles clés ajoutées).
// Usage : node scripts/i18n-add-cartografia-keys.cjs
// ============================================================================
const fs = require('node:fs');
const path = require('node:path');

const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const T = {
  'federacao.carte.scope.reseau': {
    fr: 'Réseau AnarBib', 'pt-BR': 'Rede AnarBib', es: 'Red AnarBib', it: 'Rete AnarBib',
    de: 'AnarBib-Netzwerk', en: 'AnarBib network', ca: 'Xarxa AnarBib', eo: 'Reto AnarBib',
    nl: 'AnarBib-netwerk', el: 'Δίκτυο AnarBib',
  },
  'federacao.carte.scope.paysage': {
    fr: 'Paysage libertaire', 'pt-BR': 'Paisagem libertária', es: 'Paisaje libertario', it: 'Panorama libertario',
    de: 'Libertäre Landschaft', en: 'Libertarian landscape', ca: 'Paisatge llibertari', eo: 'Liberecana pejzaĝo',
    nl: 'Libertair landschap', el: 'Ελευθεριακό τοπίο',
  },
  'federacao.carte.empty': {
    fr: 'Aucun collectif ne correspond aux filtres.', 'pt-BR': 'Nenhum coletivo corresponde aos filtros.',
    es: 'Ningún colectivo coincide con los filtros.', it: 'Nessun collettivo corrisponde ai filtri.',
    de: 'Kein Kollektiv entspricht den Filtern.', en: 'No collective matches the filters.',
    ca: 'Cap col·lectiu coincideix amb els filtres.', eo: 'Neniu kolektivo kongruas kun la filtriloj.',
    nl: 'Geen enkel collectief komt overeen met de filters.', el: 'Κανένα συλλογικό δεν αντιστοιχεί στα φίλτρα.',
  },
  'cartografia.title': {
    fr: 'Cartographie du réseau', 'pt-BR': 'Cartografia da rede', es: 'Cartografía de la red', it: 'Cartografia della rete',
    de: 'Netzwerkkarte', en: 'Network map', ca: 'Cartografia de la xarxa', eo: 'Mapo de la reto',
    nl: 'Kaart van het netwerk', el: 'Χάρτης του δικτύου',
  },
  'cartografia.intro': {
    fr: 'Bibliothèques, archives et centres de documentation anarchistes à travers le monde.',
    'pt-BR': 'Bibliotecas, arquivos e centros de documentação anarquistas pelo mundo.',
    es: 'Bibliotecas, archivos y centros de documentación anarquistas por el mundo.',
    it: 'Biblioteche, archivi e centri di documentazione anarchici nel mondo.',
    de: 'Anarchistische Bibliotheken, Archive und Dokumentationszentren weltweit.',
    en: 'Anarchist libraries, archives and documentation centres around the world.',
    ca: 'Biblioteques, arxius i centres de documentació anarquistes arreu del món.',
    eo: 'Anarkiismaj bibliotekoj, arkivoj kaj dokumentcentroj tra la mondo.',
    nl: 'Anarchistische bibliotheken, archieven en documentatiecentra wereldwijd.',
    el: 'Αναρχικές βιβλιοθήκες, αρχεία και κέντρα τεκμηρίωσης σε όλο τον κόσμο.',
  },
};

let totalAdded = 0;
for (const file of fs.readdirSync(DIR).filter((f) => f.endsWith('.json'))) {
  const loc = file.replace(/\.json$/, '');
  const p = path.join(DIR, file);
  const obj = JSON.parse(fs.readFileSync(p, 'utf8'));
  let added = 0;
  for (const [key, byLoc] of Object.entries(T)) {
    const val = byLoc[loc];
    if (val == null) { console.warn(`[warn] pas de traduction ${key} pour ${loc}`); continue; }
    if (!(key in obj)) { obj[key] = val; added++; }
  }
  if (added) {
    fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n', { encoding: 'utf8' });
    totalAdded += added;
  }
  console.log(`${file.padEnd(11)} +${added}`);
}
console.log(`Total ajouté : ${totalAdded}`);
