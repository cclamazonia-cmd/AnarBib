/* ===========================================================================
 * i18n-add-h21-lot1.cjs — H21 lot 1 (REGISTRE IMP-28, 05/10/2026) :
 * reconnaître une notice déjà importée (match_status 'known_record').
 * Page Importations : la pastille, le filtre, la notice reconnue
 * ({title} = proposed_title) et la mention « plus détenue » (proposed_book_held
 * = false). L'assistant reprend la pastille comme badge.
 * 4 clés × 10 locales. Tutoiement partout ; pt-BR au « você ». Vocabulaire
 * repris des clés voisines de chaque langue (match.matched_book, filterDup,
 * matchAgainst, reconcileRowHint).
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'importacoes.fila.match.known_record': {
    fr: 'Déjà importée',
    'pt-BR': 'Já importada',
    en: 'Already imported',
    es: 'Ya importada',
    ca: 'Ja importada',
    it: 'Già importata',
    de: 'Schon importiert',
    nl: 'Al geïmporteerd',
    eo: 'Jam importita',
    el: 'Ήδη εισαγμένη',
  },
  'importacoes.fila.filterKnown': {
    fr: 'Déjà importées',
    'pt-BR': 'Já importadas',
    en: 'Already imported',
    es: 'Ya importadas',
    ca: 'Ja importades',
    it: 'Già importate',
    de: 'Schon importiert',
    nl: 'Al geïmporteerd',
    eo: 'Jam importitaj',
    el: 'Ήδη εισαγμένες',
  },
  'importacoes.fila.knownRecordOf': {
    fr: 'Notice déjà importée par ta bibliothèque : {title}',
    'pt-BR': 'Ficha já importada pela sua biblioteca: {title}',
    en: 'Record already imported by your library: {title}',
    es: 'Ficha ya importada por tu biblioteca: {title}',
    ca: 'Fitxa ja importada per la teva biblioteca: {title}',
    it: 'Scheda già importata dalla tua biblioteca: {title}',
    de: 'Eintrag, den deine Bibliothek schon importiert hat: {title}',
    nl: 'Record dat jouw bibliotheek al heeft geïmporteerd: {title}',
    eo: 'Slipo jam importita de via biblioteko: {title}',
    el: 'Εγγραφή που η βιβλιοθήκη σου έχει ήδη εισαγάγει: {title}',
  },
  'importacoes.fila.knownRecordNotHeld': {
    fr: 'Notice plus détenue par ta bibliothèque.',
    'pt-BR': 'Ficha que sua biblioteca não possui mais.',
    en: 'Record no longer held by your library.',
    es: 'Ficha que tu biblioteca ya no posee.',
    ca: 'Fitxa que la teva biblioteca ja no té.',
    it: 'Scheda non più posseduta dalla tua biblioteca.',
    de: 'Eintrag, den deine Bibliothek nicht mehr besitzt.',
    nl: 'Record dat jouw bibliotheek niet meer bezit.',
    eo: 'Slipo ne plu posedata de via biblioteko.',
    el: 'Εγγραφή που η βιβλιοθήκη σου δεν κατέχει πλέον.',
  },
};

const ligneDe = (cle) => new RegExp('^  ' + JSON.stringify(cle).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ': (".*?")(,?)$', 'm');

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let ajoutees = 0;
  let corrigees = 0;
  for (const [cle, valeurs] of Object.entries(CLES)) {
    const val = valeurs[loc];
    if (!val) throw new Error(`Valeur manquante : ${cle} / ${loc}`);
    const m = content.match(ligneDe(cle));
    if (m) {
      if (JSON.parse(m[1]) !== val) {
        content = content.replace(m[0], '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val) + m[2]);
        corrigees++;
      }
      continue;
    }
    const entry = '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    ajoutees++;
  }
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(`${loc} : ${ajoutees} clé(s) ajoutée(s), ${corrigees} corrigée(s), JSON valide.`);
}
