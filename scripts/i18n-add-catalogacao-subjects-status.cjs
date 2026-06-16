/* ===========================================================================
 * i18n-add-catalogacao-subjects-status.cjs
 * Picker matière enrichi (thésaurus v1 étape 2a) : badge « proposé » + 2 tooltips.
 * 3 clés × 10 locales. Idempotent (sentinelle catalogacao.subjects.proposed).
 * Session : Fédération — Communs & Entraide
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const PREFIX = 'catalogacao.subjects.';
const SENTINEL = PREFIX + 'proposed';

const K = ['proposed', 'proposedHint', 'missingLabelHint'];

const V = {
  fr: ['proposé', 'Terme proposé — en attente d’activation par la coordination catalogage.', 'Aucun libellé dans ta langue — affiché par repli. Tu peux le compléter.'],
  'pt-BR': ['proposto', 'Termo proposto — aguardando ativação pela coordenação de catalogação.', 'Sem rótulo no teu idioma — exibido por padrão. Podes completá-lo.'],
  es: ['propuesto', 'Término propuesto — a la espera de activación por la coordinación de catalogación.', 'Sin etiqueta en tu idioma — mostrado por defecto. Puedes completarlo.'],
  en: ['proposed', 'Proposed term — awaiting activation by the cataloging coordination.', 'No label in your language — shown by fallback. You can complete it.'],
  it: ['proposto', 'Termine proposto — in attesa di attivazione dalla coordinazione di catalogazione.', 'Nessuna etichetta nella tua lingua — mostrata per ripiego. Puoi completarla.'],
  de: ['vorgeschlagen', 'Vorgeschlagener Begriff — wartet auf Freischaltung durch die Katalogisierungskoordination.', 'Keine Bezeichnung in deiner Sprache — als Rückfall angezeigt. Du kannst sie ergänzen.'],
  ca: ['proposat', 'Terme proposat — a l’espera d’activació per la coordinació de catalogació.', 'Sense etiqueta en la teva llengua — mostrada per defecte. Pots completar-la.'],
  eo: ['proponita', 'Proponita termino — atendas aktivigon de la kataloga kunordigo.', 'Neniu etikedo en via lingvo — montrita per repuŝo. Vi povas kompletigi ĝin.'],
  nl: ['voorgesteld', 'Voorgestelde term — wacht op activering door de catalogiseringscoördinatie.', 'Geen label in jouw taal — weergegeven als terugval. Je kunt het aanvullen.'],
  el: ['προτεινόμενο', 'Προτεινόμενος όρος — αναμένει ενεργοποίηση από τον συντονισμό καταλογογράφησης.', 'Καμία ετικέτα στη γλώσσα σου — εμφανίζεται εφεδρικά. Μπορείς να τη συμπληρώσεις.'],
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const vals = V[loc];
    if (!vals || vals.length !== K.length) throw new Error('Valeurs manquantes: ' + loc);
    const entries = K.map((k, i) => '  ' + JSON.stringify(PREFIX + k) + ': ' + JSON.stringify(vals[i]));
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 3 clés subjects-status (si absentes), JSON valide.');
}
console.log('\nTerminé.');
