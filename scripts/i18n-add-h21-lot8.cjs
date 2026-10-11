/* ===========================================================================
 * i18n-add-h21-lot8.cjs — H21 lot 8 (REGISTRE IMP-35, 11/10/2026) : un
 * exemplaire réattribué est signalé « parti chez <bibliothèque> », jamais
 * recréé. Importations : le verdict d'un exemplaire du fichier et son compte
 * (message de « Rapprocher ») ; rapport de révision : les exemplaires écartés.
 * Tutoiement partout ; pt-BR au « você ». Vocabulaire repris des clés voisines
 * (importacoes.items.*).
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'importacoes.items.verdict.reattribue': {
    fr: 'parti chez « {bibliotheque} » (réattribué) : rien n’est recréé',
    'pt-BR': 'foi para «{bibliotheque}» (reatribuído): nada é recriado',
    en: 'gone to “{bibliotheque}” (reassigned): nothing is recreated',
    es: 'se fue a «{bibliotheque}» (reasignado): no se vuelve a crear nada',
    ca: 'ha anat a «{bibliotheque}» (reassignat): no es torna a crear res',
    it: 'passato a «{bibliotheque}» (riassegnato): non si ricrea nulla',
    de: 'zu „{bibliotheque}“ gegangen (neu zugeordnet): nichts wird neu angelegt',
    nl: 'naar „{bibliotheque}” gegaan (opnieuw toegewezen): er wordt niets opnieuw aangemaakt',
    eo: 'iris al «{bibliotheque}» (reasignita): nenio estas rekreita',
    el: 'πήγε στο «{bibliotheque}» (ανατέθηκε αλλού): δεν ξαναδημιουργείται τίποτα',
  },
  'importacoes.items.count.reattribue': {
    fr: '{n, plural, one {# parti chez une autre bibliothèque} other {# partis chez une autre bibliothèque}}',
    'pt-BR': '{n, plural, one {# foi para outra biblioteca} other {# foram para outra biblioteca}}',
    en: '{n} gone to another library',
    es: '{n, plural, one {# se fue a otra biblioteca} other {# se fueron a otra biblioteca}}',
    ca: '{n, plural, one {# ha anat a una altra biblioteca} other {# han anat a una altra biblioteca}}',
    it: '{n, plural, one {# passato a un’altra biblioteca} other {# passati a un’altra biblioteca}}',
    de: '{n} zu einer anderen Bibliothek gegangen',
    nl: '{n} naar een andere bibliotheek gegaan',
    eo: '{n} iris al alia biblioteko',
    el: '{n, plural, one {# πήγε σε άλλη βιβλιοθήκη} other {# πήγαν σε άλλη βιβλιοθήκη}}',
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
