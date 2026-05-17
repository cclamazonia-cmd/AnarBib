// ============================================================
// Patch 143.2.c — JSX onglet Historique dans PanelPage.jsx
// ============================================================
// Troisieme et dernier sous-patch du #143.2 (structure UI onglet Historique).
//
// 3 modifications dans PanelPage.jsx :
//
//   M1. Imports : ajouter useMemo a la liste des imports React si absent.
//
//   M2. Insertion dans TABS (apres 'leitor', avant 'contribuicoes') :
//       { key: 'historico', label: ..., hint: ... }
//
//   M3. State + logique dominant + toggle (apres useState selectedRes) :
//       - historyTypes (useState | null)
//       - dominantHistoryType (useMemo)
//       - useEffect d'init au premier render
//       - toggleHistoryType (callback)
//
//   M4. Section onglet (apres section 'leitor', avant section 'contribuicoes') :
//       <h2>, pills, placeholder liste vide
//
// Methode UTF-8 safe : Buffer + readFileSync/writeFileSync (Node UTF-8
// par defaut).
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'src/pages/painel/PanelPage.jsx');

console.log('===== Patch 143.2.c JSX onglet Historique =====\n');

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
if (content.includes("key: 'historico'") || content.includes('historyTypes')) {
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

// ============================================================
// MODIF 1 — useMemo dans les imports
// ============================================================
console.log('[1/4] Verification useMemo dans imports React...');

// Le useState/useEffect/useCallback sont deja importes ; on verifie si useMemo l'est
const hasUseMemo = /\buseMemo\b/.test(content.split('\n').slice(0, 30).join('\n'));
if (hasUseMemo) {
  console.log('  OK : useMemo deja importe');
} else {
  // Chercher l'import React et ajouter useMemo
  const reactImportMatch = content.match(/^import React,\s*\{([^}]+)\}\s*from\s*['"]react['"];?\s*$/m);
  if (reactImportMatch) {
    const oldImport = reactImportMatch[0];
    const hooks = reactImportMatch[1];
    if (!hooks.includes('useMemo')) {
      const newImport = oldImport.replace(/\{([^}]+)\}/, (_, h) => `{ ${h.trim()}, useMemo }`);
      content = content.replace(oldImport, newImport);
      console.log('  OK : useMemo ajoute aux imports React');
    }
  } else {
    // Fallback : pattern d'import alternatif
    const altMatch = content.match(/^import\s*\{([^}]+)\}\s*from\s*['"]react['"];?\s*$/m);
    if (altMatch) {
      const oldImport = altMatch[0];
      const hooks = altMatch[1];
      if (!hooks.includes('useMemo')) {
        const newImport = oldImport.replace(/\{([^}]+)\}/, (_, h) => `{ ${h.trim()}, useMemo }`);
        content = content.replace(oldImport, newImport);
        console.log('  OK : useMemo ajoute aux imports React (fallback pattern)');
      }
    } else {
      throw new Error('Import React introuvable - inspecter manuellement les premieres lignes du fichier');
    }
  }
}

// ============================================================
// MODIF 2 — Ajout dans TABS (position 8, avant contribuicoes)
// ============================================================
console.log('\n[2/4] Insertion onglet historico dans TABS...');

patchZone('M2',
`    { key: 'leitor', label: t({ id: 'panel.tab.reader' }), hint: t({ id: 'panel.tab.reader.hint' }) },
    ...(isCoordOrAdmin && membershipEnabled ? [`,

`    { key: 'leitor', label: t({ id: 'panel.tab.reader' }), hint: t({ id: 'panel.tab.reader.hint' }) },
    { key: 'historico', label: t({ id: 'panel.tab.history' }), hint: t({ id: 'panel.tab.history.hint' }) },
    ...(isCoordOrAdmin && membershipEnabled ? [`);

// ============================================================
// MODIF 3 — State + logique apres selectedRes
// ============================================================
console.log('\n[3/4] State + logique historyTypes apres selectedRes...');

patchZone('M3',
`  const [selectedRes, setSelectedRes] = useState(new Set());`,

`  const [selectedRes, setSelectedRes] = useState(new Set());

  // === Onglet Historique (#143.2) =============================
  // Pills cochables multi-selection pour filtrer par type d'item.
  // Initialise au type le plus utilise (dynamique selon les comptes).
  const [historyTypes, setHistoryTypes] = useState(null);

  const dominantHistoryType = useMemo(() => {
    const counts = {
      reservas: (reservations || []).filter(r => ['cancelada_leitor','cancelada_biblioteca','convertida_em_emprestimo','expirada','liberada_para_circulacao'].includes(r.item_status)).length,
      consultas: (consultations || []).filter(c => ['cancelada_biblioteca','cancelada_leitor','consultada','expirada'].includes(c.item_status)).length,
      emprestimos: (loans || []).filter(l => l.status_global === 'encerrado').length,
    };
    if (counts.consultas >= counts.reservas && counts.consultas >= counts.emprestimos) return 'consultas';
    if (counts.reservas >= counts.emprestimos) return 'reservas';
    return 'emprestimos';
  }, [reservations, consultations, loans]);

  React.useEffect(() => {
    if (historyTypes === null && dominantHistoryType) {
      setHistoryTypes(new Set([dominantHistoryType]));
    }
  }, [dominantHistoryType, historyTypes]);

  const toggleHistoryType = (type) => {
    setHistoryTypes(prev => {
      const next = new Set(prev || []);
      if (next.has(type)) next.delete(type);
      else next.add(type);
      return next;
    });
  };
  // === Fin onglet Historique ==================================`);

// ============================================================
// MODIF 4 — Section onglet apres leitor, avant contribuicoes
// ============================================================
console.log('\n[4/4] Section JSX onglet historico apres leitor...');

// Ancre : la fin de la section 'leitor' et le debut de 'contribuicoes'.
// On capture le dernier '}' fermant de la section leitor + le }
// Recherchons d'abord le bon point d'insertion : juste avant `{tab === 'contribuicoes' && ...}`
patchZone('M4',
`          {tab === 'contribuicoes' && isCoordOrAdmin && (`,

`          {tab === 'historico' && (
            <div>
              <h2 className="ab-painel-h2">{t({ id: 'panel.history.title' })}</h2>
              <p className="ab-painel-hint">{t({ id: 'panel.history.subtitle' })}</p>

              <div className="ab-painel-history-filters">
                {['reservas', 'consultas', 'emprestimos'].map(type => (
                  <button
                    key={type}
                    type="button"
                    className={\`ab-painel-history-pill \${(historyTypes || new Set()).has(type) ? 'active' : ''}\`}
                    onClick={() => toggleHistoryType(type)}
                    aria-pressed={(historyTypes || new Set()).has(type)}
                  >
                    {t({ id: \`panel.history.filter.\${type}\` })}
                  </button>
                ))}
              </div>

              <div className="ab-painel-history-list">
                {(historyTypes || new Set()).size === 0 ? (
                  <p className="ab-painel-hint">{t({ id: 'panel.history.noFilter' })}</p>
                ) : (
                  <p className="ab-painel-hint">{t({ id: 'panel.history.empty' })}</p>
                )}
              </div>
            </div>
          )}

          {tab === 'contribuicoes' && isCoordOrAdmin && (`);

console.log('\n===== Verifications =====');

const checks = [
  { name: "key: 'historico' dans TABS", pattern: /key:\s*'historico'/g, expected: 1 },
  { name: 'tab === \'historico\' (section)', pattern: /tab\s*===\s*'historico'/g, expected: 1 },
  { name: 'historyTypes (declarations + usages)', pattern: /historyTypes/g, min: 5, max: 15 },
  { name: 'dominantHistoryType (declaration + usage)', pattern: /dominantHistoryType/g, min: 2, max: 5 },
  { name: 'toggleHistoryType (declaration + usage)', pattern: /toggleHistoryType/g, min: 2, max: 5 },
  { name: 'ab-painel-history-pill (classNames)', pattern: /ab-painel-history-pill/g, min: 1, max: 3 },
];

let allOk = true;
for (const c of checks) {
  const count = (content.match(c.pattern) || []).length;
  let ok;
  if (c.expected !== undefined) {
    ok = count === c.expected;
    console.log(`  ${ok ? 'OK' : '!!'}  ${c.name.padEnd(46)} : ${count} (att ${c.expected})`);
  } else {
    ok = count >= c.min && count <= c.max;
    console.log(`  ${ok ? 'OK' : '!!'}  ${c.name.padEnd(46)} : ${count} (range [${c.min},${c.max}])`);
  }
  if (!ok) allOk = false;
}

if (!allOk) {
  console.error('\n[FATAL] Compteurs incoherents');
  process.exit(1);
}

// Ecriture
console.log('\n===== Ecriture =====');
const newBuf = Buffer.from(content, 'utf8');
const newMd5 = crypto.createHash('md5').update(newBuf).digest('hex');
const newSize = newBuf.length;
fs.writeFileSync(FILE, newBuf);

console.log(`  PanelPage.jsx : ${originalSize} -> ${newSize} bytes (+${newSize - originalSize})`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);

console.log('\n===== Patch 143.2.c applique =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff src/pages/painel/PanelPage.jsx');
console.log('  2. npm run build (verifier compilation)');
console.log('  3. Commit + push les 3 sous-patches (a, b, c) en 1 ou 3 commits');
console.log('  4. Verifier en prod : onglet Historique apparait en position 8,');
console.log('     pills clickables, l\'une preselectionnee dynamiquement');
console.log('  5. Enchaîner sur 143.3 (vues SQL + fetch + affichage liste)');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
