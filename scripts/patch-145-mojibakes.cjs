// ============================================================
// Patch #145 — Fix mojibakes AccountPage.jsx
// ============================================================
// Item hygiene cosmetique du backlog v15.
//
// 3 mojibakes lignes 1123-1125 :
//   'â€"' → '—' (em dash U+2014)  - 2 occurrences (lignes 1123, 1125)
//   ' Â· ' → ' · ' (middot U+00B7) - 1 occurrence (ligne 1125)
//
// Cause : encodage Windows-1252 -> UTF-8 mal interprete (chaine
// initialement deja UTF-8 vue comme CP1252 puis re-encodee).
//
// Methode UTF-8 safe : Node fs.readFileSync/writeFileSync (UTF-8 default).
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'src/pages/account/AccountPage.jsx');

console.log('===== Patch #145 fix mojibakes =====\n');

if (!fs.existsSync(FILE)) {
  console.error(`[FATAL] Fichier introuvable : ${FILE}`);
  process.exit(1);
}

const originalBuf = fs.readFileSync(FILE);
let content = originalBuf.toString('utf8');
const originalMd5 = crypto.createHash('md5').update(originalBuf).digest('hex');
const originalSize = originalBuf.length;

console.log(`Fichier : ${FILE}`);
console.log(`  Avant : ${originalSize} bytes, MD5=${originalMd5.slice(0, 8)}\n`);

// Idempotence : si les mojibakes ont deja ete corriges, on s'arrete
const mojibakeDashCount = (content.match(/â€"/g) || []).length;
const mojibakeDotCount = (content.match(/Â·/g) || []).length;

console.log(`Mojibakes detectes :`);
console.log(`  â€" (em dash casse) : ${mojibakeDashCount} occurrences`);
console.log(`  Â· (middot casse)  : ${mojibakeDotCount} occurrences\n`);

if (mojibakeDashCount === 0 && mojibakeDotCount === 0) {
  console.log('[INFO] Aucun mojibake trouve. Patch deja applique ou inutile.');
  process.exit(0);
}

// Remplacements
content = content.replace(/â€"/g, '—');     // em dash
content = content.replace(/Â·/g, '·');     // middot

// Verification post-fix
const remainingDash = (content.match(/â€"/g) || []).length;
const remainingDot = (content.match(/Â·/g) || []).length;
const newDashCount = (content.match(/—/g) || []).length;
const newDotCount = (content.match(/·/g) || []).length;

console.log(`Apres remplacement :`);
console.log(`  Mojibakes restants : ${remainingDash + remainingDot} (att 0)`);
console.log(`  '—' total dans fichier : ${newDashCount}`);
console.log(`  '·' total dans fichier : ${newDotCount}\n`);

if (remainingDash > 0 || remainingDot > 0) {
  console.error('[FATAL] Mojibakes residuels apres patch');
  process.exit(1);
}

// Ecriture
const newBuf = Buffer.from(content, 'utf8');
const newMd5 = crypto.createHash('md5').update(newBuf).digest('hex');
const newSize = newBuf.length;
fs.writeFileSync(FILE, newBuf);

console.log(`  AccountPage.jsx : ${originalSize} -> ${newSize} bytes (${newSize - originalSize} delta)`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);

console.log('\n===== Patch #145 applique =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff src/pages/account/AccountPage.jsx');
console.log('  2. Verifier visuellement les 3 lignes corrigees');
console.log('  3. Commit + push (ou attendre regroupement avec autres commits)');
