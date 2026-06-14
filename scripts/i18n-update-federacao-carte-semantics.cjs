/* ===========================================================================
 * i18n-update-federacao-carte-semantics.cjs
 * Reformule 2 clés EXISTANTES dans les 10 locales (remplacement textuel ciblé,
 * diff minimal) :
 *   - federacao.tab.carte       → « Annuaire » (≠ « carte du réseau »)
 *   - federacao.circulos.foot   → distingue annuaire ≠ graphe de la fédération
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const TAB = {
  ca: 'Directori', de: 'Verzeichnis', el: 'Κατάλογος', en: 'Directory', eo: 'Adresaro',
  es: 'Directorio', fr: 'Annuaire', it: 'Elenco', nl: 'Gids', 'pt-BR': 'Diretório',
};
const FOOT = {
  'pt-BR': 'Nenhum grafo da federação, nenhuma vista de vigilância — seus círculos, as portas abertas, e o diretório dos coletivos.',
  fr: 'Aucun graphe de la fédération, aucune vue de surveillance — tes cercles, les portes ouvertes, et l’annuaire des collectifs.',
  es: 'Ningún grafo de la federación, ninguna vista de vigilancia — tus círculos, las puertas abiertas y el directorio de los colectivos.',
  en: 'No federation graph, no surveillance overview — your circles, the open doors, and the directory of collectives.',
  it: 'Nessun grafo della federazione, nessuna vista di sorveglianza — i tuoi cerchi, le porte aperte e l’elenco dei collettivi.',
  de: 'Kein Graph der Föderation, keine Überwachungsübersicht — deine Kreise, die offenen Türen und das Verzeichnis der Kollektive.',
  ca: 'Cap graf de la federació, cap vista de vigilància — els teus cercles, les portes obertes i el directori dels col·lectius.',
  eo: 'Neniu grafeo de la federacio, neniu gvatovido — viaj rondoj, la malfermitaj pordoj, kaj la adresaro de la kolektivoj.',
  nl: 'Geen grafiek van de federatie, geen surveillanceoverzicht — jouw kringen, de open deuren, en de gids van de collectieven.',
  el: 'Κανένα γράφημα της ομοσπονδίας, καμία εποπτεία — οι κύκλοι σου, οι ανοιχτές πόρτες, και ο κατάλογος των συλλογικοτήτων.',
};

function setKey(content, key, value) {
  const re = new RegExp('("' + key.replace(/\./g, '\\.') + '":\\s*)"[^"]*"');
  if (!re.test(content)) throw new Error('clé introuvable: ' + key);
  return content.replace(re, '$1' + JSON.stringify(value));
}

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  content = setKey(content, 'federacao.tab.carte', TAB[loc]);
  content = setKey(content, 'federacao.circulos.foot', FOOT[loc]);
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8')); // valide
  console.log(loc + ': tab.carte + circulos.foot reformulés, JSON valide.');
}
console.log('\nTerminé.');
