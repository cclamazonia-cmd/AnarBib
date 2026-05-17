// ============================================================
// Patch 143.1 — Tabs PanelPage sur 2 lignes (flex-wrap)
// ============================================================
// Sous-paquet du chantier #143 (Painel : onglet Historique + tabs 2 lignes).
//
// Bug UX : la barre d'onglets de PanelPage utilise display:flex + 
// overflow-x:auto + white-space:nowrap, ce qui force tous les onglets
// sur une seule ligne avec scroll horizontal ("balai lateral") quand
// le nombre d'onglets depasse la largeur disponible.
//
// Actuellement 8 onglets visibles (trabalho-do-dia, acoes, reservas,
// consultas-locais, emprestimos-livro, emprestimos-lote, leitor,
// contribuicoes), bientot 9 avec Historique. Le scroll horizontal
// degrade l'experience surtout sur ecran moyen/laptop.
//
// Fix CSS minimal :
//   - Ajouter flex-wrap: wrap (les onglets passent a la ligne quand
//     l'espace manque)
//   - Retirer overflow-x: auto (plus de scroll horizontal force)
//   - Conserver white-space: nowrap sur chaque onglet (chaque onglet
//     reste insecable, c'est le conteneur qui wrappe)
//
// Comportement final :
//   - Grand ecran : 1 ligne tant que ca rentre
//   - Ecran moyen : wrap naturel sur 2 lignes (ou plus si besoin)
//   - Mobile (<640px) : colonne (deja gere par la media-query existante)
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'src/pages/painel/PanelPage.css');

console.log('===== Patch 143.1 tabs PanelPage 2 lignes =====\n');

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

// Idempotence
if (content.includes('flex-wrap: wrap') && !content.includes('overflow-x: auto;\n  border-bottom')) {
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

console.log('[1/1] Ajout flex-wrap + retrait overflow-x dans ab-painel-tabs...');

patchZone('M1',
`.ab-painel-tabs {
  display: flex; gap: 0; overflow-x: auto;
  border-bottom: 1px solid rgba(255,255,255,.10);
  background: rgba(12,12,12,.5);
}`,

`/* Paquet 143.1 (17/05/2026) : tabs sur 2 lignes via flex-wrap
   Avant : overflow-x:auto + white-space:nowrap forçait tous les onglets
   sur 1 ligne avec scroll horizontal (balai latéral). Après : flex-wrap
   laisse les onglets passer à la ligne quand l'espace manque. */
.ab-painel-tabs {
  display: flex; flex-wrap: wrap; gap: 0;
  border-bottom: 1px solid rgba(255,255,255,.10);
  background: rgba(12,12,12,.5);
}`);

console.log('\n===== Verifications =====');

// flex-wrap doit etre present
const flexWrapCount = (content.match(/\.ab-painel-tabs\s*{[^}]*flex-wrap:\s*wrap/g) || []).length;
console.log(`  .ab-painel-tabs avec flex-wrap : ${flexWrapCount} (att 1)`);

// overflow-x: auto ne doit plus etre dans .ab-painel-tabs (mais peut rester ailleurs)
const overflowInTabs = (content.match(/\.ab-painel-tabs\s*{[^}]*overflow-x:\s*auto/g) || []).length;
console.log(`  .ab-painel-tabs avec overflow-x:auto : ${overflowInTabs} (att 0)`);

// La media query mobile doit etre intacte (.ab-painel-tabs en flex-direction:column < 640px)
const mobileColumnCount = (content.match(/\.ab-painel-tabs\s*{\s*flex-direction:\s*column/g) || []).length;
console.log(`  .ab-painel-tabs flex-direction:column (mobile) : ${mobileColumnCount} (att 1)`);

if (flexWrapCount !== 1 || overflowInTabs !== 0 || mobileColumnCount !== 1) {
  console.error('\n[FATAL] Compteurs incoherents');
  process.exit(1);
}

console.log('\n===== Ecriture =====');
const newBuf = Buffer.from(content, 'utf8');
const newMd5 = crypto.createHash('md5').update(newBuf).digest('hex');
const newSize = newBuf.length;
fs.writeFileSync(FILE, newBuf);

console.log(`  PanelPage.css : ${originalSize} -> ${newSize} bytes (${newSize - originalSize >= 0 ? '+' : ''}${newSize - originalSize})`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);

console.log('\n===== Patch 143.1 applique avec succes =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff src/pages/painel/PanelPage.css');
console.log('  2. npm run build');
console.log('  3. git add + commit + push');
console.log('  4. Verifier en prod : redimensionner la fenetre pour voir');
console.log('     les onglets wraper sur 2 lignes au lieu de scroller');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
