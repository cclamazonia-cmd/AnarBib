// ============================================================
// Patch sous-paquet 141.2.G — Fix title non interpole mail workflow
// ============================================================
// Bug repere apres deploiement 141.2.E+F en QA prod 16/05/2026 soiree :
// 
// Le mail lecteur 'nao_compareceu' affichait dans le titre (preheader):
//   "Você foi marcado(a/e) como ausente na consulta local agendada para
//   {date}, das {time_start} às {time_end}..."
// 
// Les placeholders {date}, {time_start}, {time_end} n'etaient pas
// interpoles dans le 'title:' du renderEmail (mail lecteur workflow event).
// Le corps du mail (introHtml) etait OK car utilisait deja 'interpolated'.
//
// Cause : ligne consultas.ts L560 utilisait tMail(locale, readerKey) brut
// au lieu de la variable 'interpolated' deja calculee 11 lignes plus haut.
// L'auteur initial avait fait l'interpolation pour readerSubject, preheader
// et introHtml, mais avait oublie pour title.
//
// Fix : aligner title sur le pattern utilise pour readerSubject (L549).
//
// Note : ce bug n'affectait pas les 3 autres 'title:' du fichier (lifecycle
// mail lecteur/staff + workflow mail staff) car ils utilisent des cles i18n
// dont les templates sont des titres courts sans placeholders.
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'supabase/functions/_shared/domain/consultas.ts');

console.log('===== Patch 141.2.G - fix title non interpole =====\n');

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

// Idempotence : si la nouvelle forme est deja la
if (content.includes('title: interpolated.split(":")[0] || interpolated')) {
  console.log('[INFO] Patch deja applique.');
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

console.log('[1/1] Fix title non interpole (workflow handler, mail lecteur)...');

// Ancre : la ligne preheader: interpolated juste avant + la ligne title bugguee
// Suivie de greeting: pour bien delimiter et eviter de matcher d'autres endroits.
patchZone('M1',
`    const { html, text } = renderEmail({
      preheader: interpolated,
      title: tMail(locale, readerKey).split(":")[0] || tMail(locale, readerKey),
      greeting: greeting(locale, user?.name),`,

`    const { html, text } = renderEmail({
      preheader: interpolated,
      title: interpolated.split(":")[0] || interpolated,
      greeting: greeting(locale, user?.name),`);

console.log('\n===== Verifications =====');
const interpolatedTitleCount = (content.match(/title: interpolated\.split\(":"\)\[0\] \|\| interpolated/g) || []).length;
console.log(`  title interpole : ${interpolatedTitleCount} occurrence (attendu 1)`);
if (interpolatedTitleCount !== 1) {
  console.error('\n[FATAL] Compteur incoherent');
  process.exit(1);
}

console.log('\n===== Ecriture =====');
const newBuf = Buffer.from(content, 'utf8');
const newMd5 = crypto.createHash('md5').update(newBuf).digest('hex');
const newSize = newBuf.length;
fs.writeFileSync(FILE, newBuf);

console.log(`  consultas.ts : ${originalSize} -> ${newSize} bytes (${newSize - originalSize >= 0 ? '+' : ''}${newSize - originalSize})`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);

console.log('\n===== Patch 141.2.G applique avec succes =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff supabase/functions/_shared/domain/consultas.ts');
console.log('  2. npm run build');
console.log('  3. git add + commit + push');
console.log('  4. supabase functions deploy notify-event --no-verify-jwt');
console.log('  5. Re-tester B5 nao_compareceu : verifier que le titre du mail');
console.log('     contient bien la date interpolee et non les placeholders.');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
