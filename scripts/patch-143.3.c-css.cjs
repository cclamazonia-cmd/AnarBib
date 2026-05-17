// ============================================================
// Patch 143.3.c — CSS sections + tableaux historiques (hybride)
// ============================================================
// Deuxieme sous-patch du #143.3.
//
// Ajoute :
//   - .ab-painel-history-section : <details> collapsible avec marker
//   - .ab-painel-history-section__summary : ligne titre + count
//   - .ab-painel-history-section__count : badge count d'items
//   - .ab-painel-history-table : tableau dense desktop (reutilise visuel
//     de .ab-painel-table existant)
//   - .ab-painel-history-loadmore : bouton 'load more' centre
//   - Media query mobile : transforme le tableau en cards (display:block
//     sur table/tbody/tr/td, chaque td devient une ligne avec ::before
//     comme label)
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'src/pages/painel/PanelPage.css');

console.log('===== Patch 143.3.c CSS sections + tableaux =====\n');

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
if (content.includes('ab-painel-history-section')) {
  console.log('[INFO] Patch deja applique (.ab-painel-history-section deja present).');
  process.exit(0);
}

const CSS_LF = `
/* ═══════════════════════════════════════════════════════════
   Onglet Historique - Sections collapsibles + tableaux hybrides
   (#143.3.c - 17/05/2026)
   ═══════════════════════════════════════════════════════════ */

/* Section <details> collapsible par type */
.ab-painel-history-section {
  border: 1px solid rgba(255,255,255,.08);
  border-radius: var(--brand-radius-sm);
  margin-bottom: 14px;
  overflow: hidden;
  background: rgba(255,255,255,.02);
}
.ab-painel-history-section[open] {
  background: rgba(255,255,255,.04);
}
.ab-painel-history-section__summary {
  display: flex; align-items: center; gap: 12px;
  padding: 12px 16px;
  cursor: pointer;
  font-size: .92rem;
  font-weight: 700;
  list-style: none;
  user-select: none;
  transition: .15s;
}
.ab-painel-history-section__summary:hover {
  background: rgba(255,255,255,.04);
}
.ab-painel-history-section__summary::-webkit-details-marker {
  display: none;
}
.ab-painel-history-section__summary::before {
  content: '▶';
  font-size: .7rem;
  color: var(--brand-muted);
  transition: transform .15s;
}
.ab-painel-history-section[open] > .ab-painel-history-section__summary::before {
  transform: rotate(90deg);
}
.ab-painel-history-section__title { flex: 1; }
.ab-painel-history-section__count {
  font-size: .78rem;
  font-weight: 600;
  color: var(--brand-muted);
  background: rgba(255,255,255,.06);
  padding: 2px 10px;
  border-radius: 999px;
}
.ab-painel-history-section__body {
  padding: 12px 16px 16px;
  border-top: 1px solid rgba(255,255,255,.06);
}

/* Tableau historique (reutilise styles de .ab-painel-table) */
.ab-painel-history-table {
  width: 100%; border-collapse: collapse; font-size: .86rem;
}
.ab-painel-history-table th {
  text-align: left; padding: 10px 8px; font-weight: 700;
  color: var(--brand-muted);
  border-bottom: 1px solid rgba(255,255,255,.12);
  white-space: nowrap;
}
.ab-painel-history-table td {
  padding: 8px;
  border-bottom: 1px solid rgba(255,255,255,.05);
  vertical-align: top;
}
.ab-painel-history-table tr:hover { background: rgba(255,255,255,.03); }
.ab-painel-history-table .truncate {
  max-width: 280px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Cellule motif (peut etre long, autoriser wrap) */
.ab-painel-history-table .cell-motif {
  font-size: .82rem;
  color: var(--brand-muted);
  max-width: 320px;
}

/* Bouton load more */
.ab-painel-history-loadmore {
  margin: 14px 0 6px;
  text-align: center;
}
.ab-painel-history-loadmore button {
  background: rgba(255,255,255,.04);
  border: 1px solid rgba(255,255,255,.12);
  color: var(--brand-text);
  padding: 8px 20px;
  border-radius: 6px;
  font-size: .86rem;
  font-weight: 600;
  cursor: pointer;
  transition: .18s;
}
.ab-painel-history-loadmore button:hover {
  background: rgba(255,255,255,.08);
}
.ab-painel-history-loadmore button:disabled {
  opacity: .5; cursor: not-allowed;
}

/* Type pill (uni/groupe) */
.ab-painel-history-typepill {
  display: inline-block;
  font-size: .76rem;
  font-weight: 700;
  padding: 2px 8px;
  border-radius: 4px;
  background: rgba(100,140,255,.15);
  color: #8ab4ff;
}
.ab-painel-history-typepill[data-type="groupe"] {
  background: rgba(200,150,0,.15);
  color: #e8c44a;
}

/* ─── Mobile : tableau -> cards ────────────────────────────── */
@media (max-width: 768px) {
  .ab-painel-history-table,
  .ab-painel-history-table thead,
  .ab-painel-history-table tbody,
  .ab-painel-history-table tr,
  .ab-painel-history-table th,
  .ab-painel-history-table td {
    display: block;
  }
  .ab-painel-history-table thead {
    display: none;  /* labels via ::before sur td */
  }
  .ab-painel-history-table tr {
    background: rgba(255,255,255,.03);
    border: 1px solid rgba(255,255,255,.08);
    border-radius: var(--brand-radius-sm);
    margin-bottom: 12px;
    padding: 10px 12px;
  }
  .ab-painel-history-table tr:hover { background: rgba(255,255,255,.05); }
  .ab-painel-history-table td {
    border: none;
    padding: 4px 0;
    position: relative;
    padding-left: 40%;
    min-height: 24px;
  }
  .ab-painel-history-table td::before {
    content: attr(data-label) ':';
    position: absolute;
    left: 0;
    width: 35%;
    font-weight: 700;
    color: var(--brand-muted);
    font-size: .78rem;
  }
  .ab-painel-history-table .truncate {
    max-width: none;
    white-space: normal;
  }
}
`;

const CSS = eolStyle === 'CRLF' ? CSS_LF.replace(/\n/g, '\r\n') : CSS_LF;

let newContent = content;
const trailingEol = eolStyle === 'CRLF' ? '\r\n' : '\n';
if (!newContent.endsWith(trailingEol)) {
  newContent += trailingEol;
}
newContent += CSS;

// Verifications
const sectionCount = (newContent.match(/\.ab-painel-history-section\b/g) || []).length;
const tableCount = (newContent.match(/\.ab-painel-history-table\b/g) || []).length;
const loadmoreCount = (newContent.match(/\.ab-painel-history-loadmore\b/g) || []).length;
const typepillCount = (newContent.match(/\.ab-painel-history-typepill\b/g) || []).length;

console.log(`  .ab-painel-history-section  : ${sectionCount} (att >= 3)`);
console.log(`  .ab-painel-history-table    : ${tableCount} (att >= 5)`);
console.log(`  .ab-painel-history-loadmore : ${loadmoreCount} (att >= 2)`);
console.log(`  .ab-painel-history-typepill : ${typepillCount} (att >= 1)`);

if (sectionCount < 3 || tableCount < 5 || loadmoreCount < 2 || typepillCount < 1) {
  console.error('\n[FATAL] Compteurs incoherents');
  process.exit(1);
}

const newBuf = Buffer.from(newContent, 'utf8');
const newMd5 = crypto.createHash('md5').update(newBuf).digest('hex');
const newSize = newBuf.length;
fs.writeFileSync(FILE, newBuf);

console.log(`\n  PanelPage.css : ${originalSize} -> ${newSize} bytes (+${newSize - originalSize})`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);

console.log('\n===== Patch 143.3.c applique =====');
console.log('\nProchaine etape : 143.3.d (JSX fetch + affichage)');
