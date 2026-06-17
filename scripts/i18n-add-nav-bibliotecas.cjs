/* ===========================================================================
 * i18n-add-nav-bibliotecas.cjs
 * Frontend PUBLIB Phase 1 — nav publique « Bibliothèques » (#PUB-NAV-1) +
 * rebond OPAC → fiche « À propos de cette bibliothèque » (#PUB6).
 * 2 clés × 10 locales. nav.bibliotecas est distinct de nav.library (admin).
 * Idempotent (sentinelle catalog.aboutLibrary).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalog.aboutLibrary';

const ADD = {
  'pt-BR': { 'nav.bibliotecas': 'Bibliotecas', 'catalog.aboutLibrary': 'Sobre esta biblioteca' },
  fr: { 'nav.bibliotecas': 'Bibliothèques', 'catalog.aboutLibrary': 'À propos de cette bibliothèque' },
  es: { 'nav.bibliotecas': 'Bibliotecas', 'catalog.aboutLibrary': 'Sobre esta biblioteca' },
  en: { 'nav.bibliotecas': 'Libraries', 'catalog.aboutLibrary': 'About this library' },
  it: { 'nav.bibliotecas': 'Biblioteche', 'catalog.aboutLibrary': 'Su questa biblioteca' },
  de: { 'nav.bibliotecas': 'Bibliotheken', 'catalog.aboutLibrary': 'Über diese Bibliothek' },
  ca: { 'nav.bibliotecas': 'Biblioteques', 'catalog.aboutLibrary': 'Sobre aquesta biblioteca' },
  eo: { 'nav.bibliotecas': 'Bibliotekoj', 'catalog.aboutLibrary': 'Pri ĉi tiu biblioteko' },
  nl: { 'nav.bibliotecas': 'Bibliotheken', 'catalog.aboutLibrary': 'Over deze bibliotheek' },
  el: { 'nav.bibliotecas': 'Βιβλιοθήκες', 'catalog.aboutLibrary': 'Σχετικά με αυτή τη βιβλιοθήκη' },
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
  console.log(loc + ': nav.bibliotecas + catalog.aboutLibrary (si absentes), JSON valide.');
}
console.log('\nTerminé.');
