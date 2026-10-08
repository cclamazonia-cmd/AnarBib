/* i18n-add-correspondance-lot3.cjs — G19 lot 3 (08/10/2026) : un HINT de plus,
 * error.correspondance.library_isolated (une bibliothèque isolée du réseau ne
 * reçoit pas de correspondance). Idempotent, source de la clé. */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const CLES = {
  'error.correspondance.library_isolated': {
    fr: 'Cette bibliothèque ne participe pas au réseau : elle ne reçoit pas de correspondance.',
    'pt-BR': 'Esta biblioteca não participa da rede: ela não recebe correspondência.',
    en: 'This library does not take part in the network: it does not receive correspondence.',
    es: 'Esta biblioteca no participa en la red: no recibe correspondencia.',
    ca: 'Aquesta biblioteca no participa a la xarxa: no rep correspondència.',
    it: 'Questa biblioteca non partecipa alla rete: non riceve corrispondenza.',
    de: 'Diese Bibliothek nimmt nicht am Netzwerk teil: sie empfängt keine Korrespondenz.',
    nl: 'Deze bibliotheek neemt niet deel aan het netwerk: ze ontvangt geen correspondentie.',
    eo: 'Ĉi tiu biblioteko ne partoprenas la reton: ĝi ne ricevas korespondadon.',
    el: 'Αυτή η βιβλιοθήκη δεν συμμετέχει στο δίκτυο: δεν δέχεται αλληλογραφία.',
  },
};
const ligneDe = (cle) => new RegExp('^  ' + JSON.stringify(cle).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ': (".*?")(,?)$', 'm');
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let ajoutees = 0;
  for (const [cle, valeurs] of Object.entries(CLES)) {
    const val = valeurs[loc];
    if (!val) throw new Error(`Valeur manquante : ${cle} / ${loc}`);
    if (content.match(ligneDe(cle))) continue;
    const entry = '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    ajoutees++;
  }
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(`${loc} : ${ajoutees} clé(s) ajoutée(s), JSON valide.`);
}
