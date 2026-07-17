/* ===========================================================================
 * i18n-add-book-published-next.cjs
 * Message affiché après publication d'un document : confirme la publication ET
 * signale que le formulaire est repassé sur une fiche vierge (catalogage en
 * série). Placeholder ICU {title}.
 * 1 clé × 10 locales. Idempotent (sentinelle catalogacao.msg.bookPublishedNext).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalogacao.msg.bookPublishedNext';

const ADD = {
  'pt-BR': { 'catalogacao.msg.bookPublishedNext': '« {title} » publicado. Nova ficha pronta para outro documento.' },
  fr: { 'catalogacao.msg.bookPublishedNext': '« {title} » publié. Nouvelle fiche prête pour un autre document.' },
  es: { 'catalogacao.msg.bookPublishedNext': '« {title} » publicado. Nueva ficha lista para otro documento.' },
  en: { 'catalogacao.msg.bookPublishedNext': '“{title}” published. New blank record ready for the next document.' },
  it: { 'catalogacao.msg.bookPublishedNext': '« {title} » pubblicato. Nuova scheda pronta per un altro documento.' },
  de: { 'catalogacao.msg.bookPublishedNext': '„{title}“ veröffentlicht. Neue leere Karte bereit für das nächste Dokument.' },
  ca: { 'catalogacao.msg.bookPublishedNext': '« {title} » publicat. Nova fitxa a punt per a un altre document.' },
  eo: { 'catalogacao.msg.bookPublishedNext': '« {title} » publikigita. Nova karto preta por alia dokumento.' },
  nl: { 'catalogacao.msg.bookPublishedNext': '„{title}“ gepubliceerd. Nieuwe lege fiche klaar voor het volgende document.' },
  el: { 'catalogacao.msg.bookPublishedNext': '«{title}» δημοσιεύτηκε. Νέα κενή καρτέλα έτοιμη για το επόμενο έγγραφο.' },
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
  console.log(loc + ': 1 clé (si absente), JSON valide.');
}
console.log('\nTerminé.');
