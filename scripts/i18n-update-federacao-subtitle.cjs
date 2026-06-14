/* Reformule federacao.subtitle (sous-titre descriptif du hero) dans les 10 locales. */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SUB = {
  'pt-BR': "Círculos, diretório dos coletivos, entreajuda — em livre associação.",
  fr: "Cercles, annuaire des collectifs, entraide — en libre association.",
  es: "Círculos, directorio de los colectivos, apoyo mutuo — en libre asociación.",
  en: "Circles, directory of collectives, mutual aid — in free association.",
  it: "Cerchi, elenco dei collettivi, mutuo soccorso — in libera associazione.",
  de: "Kreise, Verzeichnis der Kollektive, gegenseitige Hilfe — in freier Assoziation.",
  ca: "Cercles, directori dels col·lectius, suport mutu — en lliure associació.",
  eo: "Rondoj, adresaro de la kolektivoj, reciproka helpo — en libera asociiĝo.",
  nl: "Kringen, gids van de collectieven, wederzijdse hulp — in vrije associatie.",
  el: "Κύκλοι, κατάλογος συλλογικοτήτων, αλληλοβοήθεια — σε ελεύθερη ένωση.",
};
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let c = fs.readFileSync(file, 'utf8');
  const re = /("federacao\.subtitle":\s*)"[^"]*"/;
  if (!re.test(c)) throw new Error('federacao.subtitle introuvable: ' + loc);
  c = c.replace(re, '$1' + JSON.stringify(SUB[loc]));
  fs.writeFileSync(file, c, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': federacao.subtitle reformulé.');
}
console.log('Terminé.');
