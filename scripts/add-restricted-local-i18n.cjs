/* =====================================================================
 * add-restricted-local-i18n.cjs
 * ---------------------------------------------------------------------
 * Ajoute la cle i18n "account.alert.restricted.local" dans les 8 locales,
 * IMMEDIATEMENT apres la cle existante "account.alert.restricted".
 *
 * Methode (doctrine JSON AnarBib) : insertion TEXTE pure, jamais de
 * ConvertFrom-Json / reconstruction. On localise la ligne de la cle
 * "account.alert.restricted" et on insere la nouvelle juste apres, en
 * copiant l'indentation et le style de quote. Validation JSON.parse en fin.
 *
 * Le motif {reason} reprend la meme variable que la cle globale (injectee
 * par le frontend via t({id}, {reason})).
 *
 * Lancer depuis la racine du repo :
 *   node scripts/add-restricted-local-i18n.cjs
 * (ou ajuster LOCALES_DIR ci-dessous)
 * ===================================================================== */

const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.join('src', 'i18n', 'locales');

// Textes par locale, conventions inclusives militantes respectees.
// {reason} = motif transmis par restrict_member (membership.restricted_reason).
const TEXTS = {
  'pt-BR':
    'Conta restringida localmente pela sua biblioteca. Motivo: {reason}. Procure a equipe da biblioteca para regularizar.',
  'fr':
    'Compte restreint localement par votre bibliothèque. Motif : {reason}. Rapprochez-vous de l’équipe de la bibliothèque pour régulariser.',
  'es':
    'Cuenta restringida localmente por su biblioteca. Motivo: {reason}. Acérquese al equipo de la biblioteca para regularizar.',
  'it':
    'Account limitato localmente dalla tua biblioteca. Motivo: {reason}. Rivolgiti al gruppo della biblioteca per regolarizzare.',
  'de':
    'Konto lokal durch deine Bibliothek eingeschränkt. Grund: {reason}. Wende dich an das Bibliotheksteam zur Klärung.',
  'en':
    'Account restricted locally by your library. Reason: {reason}. Please contact the library team to resolve this.',
  'ca':
    'Compte restringit localment per la teva biblioteca. Motiu: {reason}. Adreça’t a l’equip de la biblioteca per regularitzar.',
  'eo':
    'Konto loke limigita de via biblioteko. Kialo: {reason}. Kontaktu la bibliotekan teamon por solvi tion.',
};

const ANCHOR_KEY = 'account.alert.restricted';
const NEW_KEY = 'account.alert.restricted.local';

let failures = 0;

for (const [locale, text] of Object.entries(TEXTS)) {
  const file = path.join(LOCALES_DIR, `${locale}.json`);
  if (!fs.existsSync(file)) {
    console.error(`[SKIP] ${locale}: fichier introuvable (${file})`);
    failures++;
    continue;
  }

  // Lecture brute UTF-8 sans BOM (preserve l'encodage)
  let content = fs.readFileSync(file, 'utf8');

  // Idempotence : si la cle existe deja, on ne touche pas.
  if (content.includes(`"${NEW_KEY}"`)) {
    console.log(`[OK-DEJA] ${locale}: ${NEW_KEY} deja present, rien a faire.`);
    continue;
  }

  // Localiser la ligne EXACTE de la cle d'ancrage (pas une sous-cle type
  // account.alert.restricted.local qui n'existe pas encore, ni .cta).
  // On cible "account.alert.restricted" suivi de " (fin de cle).
  const lines = content.split('\n');
  let anchorIdx = -1;
  for (let i = 0; i < lines.length; i++) {
    // match : ..."account.alert.restricted":  (le " ferme la cle exacte)
    if (lines[i].includes(`"${ANCHOR_KEY}":`)) {
      anchorIdx = i;
      break;
    }
  }

  if (anchorIdx === -1) {
    console.error(`[FAIL] ${locale}: ancre "${ANCHOR_KEY}" introuvable.`);
    failures++;
    continue;
  }

  const anchorLine = lines[anchorIdx];

  // Reprendre l'indentation de la ligne d'ancrage.
  const indentMatch = anchorLine.match(/^(\s*)/);
  const indent = indentMatch ? indentMatch[1] : '  ';

  // La ligne d'ancrage se termine-t-elle par une virgule ? (elle le doit,
  // car ce n'est pas la derniere cle de l'objet). On insere une nouvelle
  // ligne apres, avec virgule finale.
  // Echapper les guillemets eventuels du texte (il n'y en a pas ici, mais
  // par securite) et conserver l'apostrophe typographique telle quelle.
  const safeText = text.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  const newLine = `${indent}"${NEW_KEY}": "${safeText}",`;

  lines.splice(anchorIdx + 1, 0, newLine);
  const newContent = lines.join('\n');

  // Validation stricte AVANT ecriture.
  try {
    JSON.parse(newContent);
  } catch (e) {
    console.error(`[FAIL] ${locale}: JSON.parse echoue apres insertion -> ${e.message}`);
    failures++;
    continue;
  }

  // Ecriture UTF-8 sans BOM.
  fs.writeFileSync(file, newContent, 'utf8');
  console.log(`[OK] ${locale}: ${NEW_KEY} insere apres ${ANCHOR_KEY}.`);
}

if (failures > 0) {
  console.error(`\n=== ${failures} echec(s). Aucune cle perdue (insertion atomique par fichier), mais verifie les FAIL ci-dessus. ===`);
  process.exit(1);
}
console.log('\n=== Termine. Lance maintenant: npm test (i18n) puis npm run build. ===');
