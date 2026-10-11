/* ===========================================================================
 * i18n-recherche-approchee.cjs — 11/10/2026 : (1) le catalogue dit quand il
 * n'a rien trouvé d'exact et montre des résultats à une ou deux lettres près ;
 * (2) le formulaire d'autorité titre chaque champ de biographie par sa langue
 * (« Biographie en français »…).
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

// Le nom de chaque langue, dans chaque langue, avec sa tournure (« en », « em »,
// « auf », « στα »…) : une phrase entière par clé, pas un gabarit.
const TITRES = {
  ptBR: { fr: 'Biographie en portugais (Brésil)', 'pt-BR': 'Biografia em português (Brasil)', es: 'Biografía en portugués (Brasil)', en: 'Biography in Portuguese (Brazil)', it: 'Biografia in portoghese (Brasile)', de: 'Biografie auf Portugiesisch (Brasilien)', ca: 'Biografia en portuguès (Brasil)', eo: 'Biografio en la portugala (Brazilo)', nl: 'Biografie in het Portugees (Brazilië)', el: 'Βιογραφία στα πορτογαλικά (Βραζιλίας)' },
  fr:   { fr: 'Biographie en français', 'pt-BR': 'Biografia em francês', es: 'Biografía en francés', en: 'Biography in French', it: 'Biografia in francese', de: 'Biografie auf Französisch', ca: 'Biografia en francès', eo: 'Biografio en la franca', nl: 'Biografie in het Frans', el: 'Βιογραφία στα γαλλικά' },
  es:   { fr: 'Biographie en espagnol', 'pt-BR': 'Biografia em espanhol', es: 'Biografía en español', en: 'Biography in Spanish', it: 'Biografia in spagnolo', de: 'Biografie auf Spanisch', ca: 'Biografia en castellà', eo: 'Biografio en la hispana', nl: 'Biografie in het Spaans', el: 'Βιογραφία στα ισπανικά' },
  en:   { fr: 'Biographie en anglais', 'pt-BR': 'Biografia em inglês', es: 'Biografía en inglés', en: 'Biography in English', it: 'Biografia in inglese', de: 'Biografie auf Englisch', ca: 'Biografia en anglès', eo: 'Biografio en la angla', nl: 'Biografie in het Engels', el: 'Βιογραφία στα αγγλικά' },
  it:   { fr: 'Biographie en italien', 'pt-BR': 'Biografia em italiano', es: 'Biografía en italiano', en: 'Biography in Italian', it: 'Biografia in italiano', de: 'Biografie auf Italienisch', ca: 'Biografia en italià', eo: 'Biografio en la itala', nl: 'Biografie in het Italiaans', el: 'Βιογραφία στα ιταλικά' },
  de:   { fr: 'Biographie en allemand', 'pt-BR': 'Biografia em alemão', es: 'Biografía en alemán', en: 'Biography in German', it: 'Biografia in tedesco', de: 'Biografie auf Deutsch', ca: 'Biografia en alemany', eo: 'Biografio en la germana', nl: 'Biografie in het Duits', el: 'Βιογραφία στα γερμανικά' },
  ca:   { fr: 'Biographie en catalan', 'pt-BR': 'Biografia em catalão', es: 'Biografía en catalán', en: 'Biography in Catalan', it: 'Biografia in catalano', de: 'Biografie auf Katalanisch', ca: 'Biografia en català', eo: 'Biografio en la kataluna', nl: 'Biografie in het Catalaans', el: 'Βιογραφία στα καταλανικά' },
  eo:   { fr: 'Biographie en espéranto', 'pt-BR': 'Biografia em esperanto', es: 'Biografía en esperanto', en: 'Biography in Esperanto', it: 'Biografia in esperanto', de: 'Biografie auf Esperanto', ca: 'Biografia en esperanto', eo: 'Biografio en Esperanto', nl: 'Biografie in het Esperanto', el: 'Βιογραφία στην εσπεράντο' },
  nl:   { fr: 'Biographie en néerlandais', 'pt-BR': 'Biografia em neerlandês', es: 'Biografía en neerlandés', en: 'Biography in Dutch', it: 'Biografia in olandese', de: 'Biografie auf Niederländisch', ca: 'Biografia en neerlandès', eo: 'Biografio en la nederlanda', nl: 'Biografie in het Nederlands', el: 'Βιογραφία στα ολλανδικά' },
  el:   { fr: 'Biographie en grec', 'pt-BR': 'Biografia em grego', es: 'Biografía en griego', en: 'Biography in Greek', it: 'Biografia in greco', de: 'Biografie auf Griechisch', ca: 'Biografia en grec', eo: 'Biografio en la greka', nl: 'Biografie in het Grieks', el: 'Βιογραφία στα ελληνικά' },
};

const CLES = {
  'catalog.results.approx': {
    fr: 'Rien d’exact : résultats à une ou deux lettres près',
    'pt-BR': 'Nada exato: resultados com uma ou duas letras de diferença',
    en: 'No exact match: results within one or two letters',
    es: 'Nada exacto: resultados con una o dos letras de diferencia',
    ca: 'Res d’exacte: resultats amb una o dues lletres de diferència',
    it: 'Niente di esatto: risultati con una o due lettere di differenza',
    de: 'Nichts Genaues: Treffer mit ein oder zwei Buchstaben Abweichung',
    eo: 'Nenio ekzakta: rezultoj kun unu aŭ du literoj da diferenco',
    nl: 'Niets exacts: resultaten met één of twee letters verschil',
    el: 'Τίποτα ακριβές: αποτελέσματα με διαφορά ενός ή δύο γραμμάτων',
  },
};
for (const [code, valeurs] of Object.entries(TITRES)) CLES['catalogacao.bio.titleIn.' + code] = valeurs;

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
