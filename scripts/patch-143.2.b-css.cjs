// ============================================================
// Patch 143.2.b — CSS pills onglet Historique
// ============================================================
// Deuxieme sous-patch du #143.2 (structure UI onglet Historique).
//
// Ajoute un bloc CSS pour les pills cochables multi-selection
// et la liste vide a la fin de PanelPage.css.
//
// Classes :
//   .ab-painel-history-filters : conteneur flex-wrap des pills
//   .ab-painel-history-pill    : pill arrondie avec etat active/inactif
//   .ab-painel-history-list    : conteneur de la liste (placeholder
//                                en 143.2, items reels en 143.3)
//
// Style : coherent avec .ab-painel-chips et .ab-painel-tab.
// Couleur active : var(--brand-color-primary) (rouge AnarBib).
//
// Methode UTF-8 safe : utilise fs.readFileSync/writeFileSync (Node UTF-8
// par defaut). Ajout en fin de fichier, non destructif.
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'src/pages/painel/PanelPage.css');

console.log('===== Patch 143.2.b CSS pills Historique =====\n');

if (!fs.existsSync(FILE)) {
  console.error(`[FATAL] Fichier introuvable : ${FILE}`);
  process.exit(1);
}

const originalBuf = fs.readFileSync(FILE);
const content = originalBuf.toString('utf8');
const originalMd5 = crypto.createHash('md5').update(originalBuf).digest('hex');
const eolStyle = content.includes('\r\n') ? 'CRLF' : 'LF';
const originalSize = originalBuf.length;

console.log(`Fichier : ${FILE}`);
console.log(`  Avant : ${originalSize} bytes, EOL=${eolStyle}, MD5=${originalMd5.slice(0, 8)}\n`);

// Idempotence
if (content.includes('ab-painel-history-filters') || content.includes('ab-painel-history-pill')) {
  console.log('[INFO] Patch deja applique (classes ab-painel-history-* deja presentes).');
  process.exit(0);
}

const CSS_LF = `
/* ═══════════════════════════════════════════════════════════
   Onglet Historique (#143.2 - 17/05/2026)
   Pills cochables multi-selection pour filtrer par type
   ═══════════════════════════════════════════════════════════ */

.ab-painel-history-filters {
  display: flex; flex-wrap: wrap; gap: 8px;
  margin: 12px 0 18px;
}
.ab-painel-history-pill {
  background: rgba(255,255,255,.04);
  border: 1px solid rgba(255,255,255,.12);
  color: var(--brand-muted);
  padding: 6px 14px;
  border-radius: 999px;
  font-size: .86rem;
  font-weight: 600;
  cursor: pointer;
  transition: .18s;
  white-space: nowrap;
}
.ab-painel-history-pill:hover {
  color: var(--brand-text);
  border-color: rgba(255,255,255,.24);
}
.ab-painel-history-pill.active {
  background: rgba(200,0,0,.15);
  border-color: var(--brand-color-primary);
  color: #fff;
}
.ab-painel-history-list {
  min-height: 200px;
}
`;

// Normaliser les EOL pour matcher le style du fichier
const CSS = eolStyle === 'CRLF' ? CSS_LF.replace(/\n/g, '\r\n') : CSS_LF;

// Concatenation : assurer qu'il y a une newline avant l'ajout
let newContent = content;
const trailingEol = eolStyle === 'CRLF' ? '\r\n' : '\n';
if (!newContent.endsWith(trailingEol)) {
  newContent += trailingEol;
}
newContent += CSS;

// Verifications
const filtersCount = (newContent.match(/\.ab-painel-history-filters/g) || []).length;
const pillCount = (newContent.match(/\.ab-painel-history-pill/g) || []).length;
const listCount = (newContent.match(/\.ab-painel-history-list/g) || []).length;

console.log(`  .ab-painel-history-filters : ${filtersCount} (att 1)`);
console.log(`  .ab-painel-history-pill    : ${pillCount} (att 3 selecteurs)`);
console.log(`  .ab-painel-history-list    : ${listCount} (att 1)`);

if (filtersCount !== 1 || pillCount < 3 || listCount !== 1) {
  console.error('\n[FATAL] Compteurs incoherents');
  process.exit(1);
}

// Ecriture
const newBuf = Buffer.from(newContent, 'utf8');
const newMd5 = crypto.createHash('md5').update(newBuf).digest('hex');
const newSize = newBuf.length;
fs.writeFileSync(FILE, newBuf);

console.log(`\n  PanelPage.css : ${originalSize} -> ${newSize} bytes (+${newSize - originalSize})`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);

console.log('\n===== Patch 143.2.b applique =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff src/pages/painel/PanelPage.css');
console.log('  2. Enchaîner sur 143.2.c (JSX)');
