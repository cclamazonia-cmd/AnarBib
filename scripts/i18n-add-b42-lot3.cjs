/* ===========================================================================
 * i18n-add-b42-lot3.cjs — B42 lot 3 (13/10/2026) : le refus « double
 * authentification requise » d'une Edge Function (code aal2_required, lu par
 * src/lib/edgeError.js → error.edge.aal2_required). Première fonction à
 * l'émettre : attach-received-asset. Tutoiement ; pt-BR au « você » ; el au
 * singulier.
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const CLE = 'error.edge.aal2_required';
const VAL = {
  fr: 'Double authentification requise : reconnecte-toi avec ton code pour faire cette opération.',
  'pt-BR': 'Autenticação em dois fatores obrigatória: entre de novo com o seu código para fazer esta operação.',
  en: 'Two-factor authentication required: sign in again with your code to do this.',
  es: 'Autenticación en dos pasos obligatoria: vuelve a iniciar sesión con tu código para hacer esta operación.',
  ca: "Autenticació en dos passos obligatòria: torna a iniciar la sessió amb el codi per fer aquesta operació.",
  it: 'Autenticazione a due fattori obbligatoria: accedi di nuovo con il tuo codice per fare questa operazione.',
  de: 'Zwei-Faktor-Authentifizierung erforderlich: Melde dich mit deinem Code erneut an, um das zu tun.',
  nl: 'Tweestapsverificatie verplicht: log opnieuw in met je code om dit te doen.',
  eo: 'Dufaktora aŭtentigo deviga: ensalutu denove per via kodo por fari tion.',
  el: 'Απαιτείται έλεγχος δύο παραγόντων: συνδέσου ξανά με τον κωδικό σου για να το κάνεις.',
};

const ligne = new RegExp('^  ' + JSON.stringify(CLE).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ': (".*?")(,?)$', 'm');
for (const loc of LOCALES) {
  if (!VAL[loc]) throw new Error('valeur manquante ' + loc);
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  const m = content.match(ligne);
  let etat = 'inchangée';
  if (m) {
    if (JSON.parse(m[1]) !== VAL[loc]) { content = content.replace(m[0], '  ' + JSON.stringify(CLE) + ': ' + JSON.stringify(VAL[loc]) + m[2]); etat = 'corrigée'; }
  } else {
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n  ' + JSON.stringify(CLE) + ': ' + JSON.stringify(VAL[loc]) + '\n' + content.slice(marker);
    etat = 'ajoutée';
  }
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(`${loc} : ${etat}, JSON valide.`);
}
