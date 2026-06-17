/* ===========================================================================
 * i18n-add-publib-viewonmap.cjs
 * PUBLIB-O1 — lien « Voir sur la carte » (OpenStreetMap, clic-pour-charger) sur
 * l'adresse publique de la fiche. 1 clé × 10. Idempotent (sentinelle viewOnMap).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'bibliotecaPublica.viewOnMap';

const VAL = {
  'pt-BR': 'Ver no mapa', fr: 'Voir sur la carte', es: 'Ver en el mapa', en: 'View on map',
  it: 'Vedi sulla mappa', de: 'Auf der Karte ansehen', ca: 'Veure al mapa', eo: 'Vidi sur la mapo',
  nl: 'Bekijk op de kaart', el: 'Δείτε στον χάρτη',
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    if (VAL[loc] == null) throw new Error('Traduction manquante: ' + loc);
    const entry = '  ' + JSON.stringify(SENTINEL) + ': ' + JSON.stringify(VAL[loc]);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': viewOnMap (si absente), JSON valide.');
}
console.log('\nTerminé.');
