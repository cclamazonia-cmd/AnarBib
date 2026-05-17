// ============================================================
// Patch 142 — cancelada_biblioteca : envoyer mail coordination (R8)
// ============================================================
// Bug doctrinal repere 17/05/2026 :
//
//   Quand la bibliotheque annule une consulta (cancelada_biblioteca),
//   seul le lecteur recoit un mail. La coordination ne recoit rien.
//   Or : l'operateur qui clique "annuler" n'est pas forcement le
//   coordenador qui doit etre au courant de cette action collective.
//
// Doctrine R8 (tracabilite coordination) appliquee aussi a cet event.
// Coherence avec le traitement nao_compareceu (deja R8 depuis hier).
//
// Le motif d'annulation est obligatoire (>= 5 chars) garanti par
// api.advance_consulta. Il est propage via workflow_note dans le
// payload (depuis #141.1) et affiche dans details du mail staff via
// noteDetailStaff (cable depuis #141.2.C mais inutilise jusqu'ici car
// staffKey etait null pour ce cas).
//
// Fix : routing du lifecycle handler pour cancelledBy === "biblioteca" :
//   AVANT : readerKey = "con.cancelStaff", staffKey = null, staffMailEnabled = false
//   APRES : readerKey = "con.cancelStaff", staffKey = "con.cancelStaff"
//
// La cle i18n con.cancelStaff est reutilisee (titre symetrique). Si
// besoin d'une formulation specifique mail staff plus tard, on creera
// con.staff.cancelStaff dans un sous-paquet ulterieur.
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'supabase/functions/_shared/domain/consultas.ts');

console.log('===== Patch 142 cancelada_biblioteca mail coordination =====\n');

if (!fs.existsSync(FILE)) {
  console.error(`[FATAL] Fichier introuvable : ${FILE}`);
  process.exit(1);
}

const originalBuf = fs.readFileSync(FILE);
let content = originalBuf.toString('utf8');
const originalMd5 = crypto.createHash('md5').update(originalBuf).digest('hex');
const eolStyle = content.includes('\r\n') ? 'CRLF' : 'LF';
const originalSize = originalBuf.length;

console.log(`Fichier : ${FILE}`);
console.log(`  Avant : ${originalSize} bytes, EOL=${eolStyle}, MD5=${originalMd5.slice(0, 8)}\n`);

// Idempotence : si le nouveau contenu est deja present
if (content.includes('// La biblio a annule -> mail au lecteur + mail coordination')) {
  console.log('[INFO] Patch deja applique. Aucune modification.');
  process.exit(0);
}

function normalizeEol(str) {
  const lf = str.replace(/\r\n/g, '\n');
  if (eolStyle === 'CRLF') return lf.replace(/\n/g, '\r\n');
  return lf;
}

function patchZone(label, anchor, replacement) {
  const a = normalizeEol(anchor);
  const r = normalizeEol(replacement);
  if (!content.includes(a)) {
    throw new Error(`${label} : ancre introuvable`);
  }
  let count = 0;
  let idx = 0;
  while ((idx = content.indexOf(a, idx)) !== -1) {
    count++;
    idx += a.length;
  }
  if (count !== 1) {
    throw new Error(`${label} : ancre trouvee ${count} fois (attendu 1)`);
  }
  content = content.replace(a, r);
  console.log(`  OK : ${label}`);
}

try {

console.log('[1/1] Routing cancelledBy === biblioteca : activer mail coordination...');

patchZone('M1',
`    } else if (cancelledBy === "biblioteca") {
      // La biblio a annule -> mail au lecteur uniquement
      readerKey = "con.cancelStaff";
      staffKey = null;
      staffMailEnabled = false;`,

`    } else if (cancelledBy === "biblioteca") {
      // La biblio a annule -> mail au lecteur + mail coordination (R8)
      // L'operateur qui clique "annuler" n'est pas forcement le coordenador
      // qui doit etre au courant. Motif d'annulation obligatoire (>= 5 chars)
      // garanti par api.advance_consulta, propage via workflow_note et
      // affiche dans details du mail staff via noteDetailStaff.
      readerKey = "con.cancelStaff";
      staffKey = "con.cancelStaff";`);

console.log('\n===== Verifications =====');

// La ligne "La biblio a annule -> mail au lecteur uniquement" ne doit plus exister
const oldCommentCount = (content.match(/La biblio a annule -> mail au lecteur uniquement/g) || []).length;
console.log(`  Ancien commentaire ('-> mail au lecteur uniquement') : ${oldCommentCount} (att 0)`);

// La nouvelle branche doit etre presente
const newCommentCount = (content.match(/La biblio a annule -> mail au lecteur \+ mail coordination/g) || []).length;
console.log(`  Nouveau commentaire ('+ mail coordination')           : ${newCommentCount} (att 1)`);

// staffMailEnabled = false ne doit plus apparaitre dans cette branche (mais peut
// rester dans d'autres branches comme em_preparacao - on cherche en contexte)
const staffMailEnabledFalseCount = (content.match(/staffMailEnabled = false/g) || []).length;
console.log(`  staffMailEnabled = false (toutes branches confondues)  : ${staffMailEnabledFalseCount} (att 1 ou 2 selon branches restantes)`);

if (oldCommentCount !== 0 || newCommentCount !== 1) {
  console.error('\n[FATAL] Compteurs incoherents');
  process.exit(1);
}

console.log('\n===== Ecriture =====');
const newBuf = Buffer.from(content, 'utf8');
const newMd5 = crypto.createHash('md5').update(newBuf).digest('hex');
const newSize = newBuf.length;
fs.writeFileSync(FILE, newBuf);

console.log(`  consultas.ts : ${originalSize} -> ${newSize} bytes (${newSize - originalSize >= 0 ? '+' : ''}${newSize - originalSize})`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);

console.log('\n===== Patch 142 applique avec succes =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff supabase/functions/_shared/domain/consultas.ts');
console.log('  2. npm run build');
console.log('  3. git add + commit + push');
console.log('  4. supabase functions deploy notify-event --no-verify-jwt');
console.log('  5. Test : biblio annule une consulta avec motif >= 5 chars');
console.log('     -> verifier mail lecteur (deja OK depuis #141)');
console.log('     -> verifier mail coordination (cclamazonia@gmail.com) avec motif dans details');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
