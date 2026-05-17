// ============================================================
// Patch 143.2.c v2 — JSX onglet Historique dans PanelPage.jsx
// ============================================================
// Corrections vs v1 :
//   - useEffect et useMemo deja importes (ligne 1), donc M1 = no-op
//   - Utilisation directe de useEffect, plus de React.useEffect
//     (qui aurait plante au build car React n'est pas importe par defaut)
//
// 3 modifications (au lieu de 4) :
//
//   M2. Insertion dans TABS (apres 'leitor', avant spread contribuicoes)
//
//   M3. State + logique apres useState selectedRes :
//       - historyTypes (useState | null)
//       - dominantHistoryType (useMemo)
//       - useEffect d'init au premier render
//       - toggleHistoryType (callback)
//
//   M4. Section onglet avant `tab === 'contribuicoes' && isCoordOrAdmin &&`
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'src/pages/painel/PanelPage.jsx');

console.log('===== Patch 143.2.c v2 JSX onglet Historique =====\n');

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

// Pre-check : verifier que useEffect et useMemo sont bien importes
const importLine = content.split('\n')[0];
if (!importLine.includes('useEffect') || !importLine.includes('useMemo')) {
  throw new Error(`Imports React incomplets ligne 1 : '${importLine}'. Attendu useEffect ET useMemo dans la liste.`);
}
console.log('  OK : useEffect et useMemo deja importes (ligne 1)');

// ============================================================
// MODIF 2 — Ajout dans TABS (position 8, avant spread contribuicoes)
// ============================================================
console.log('\n[1/3] Insertion onglet historico dans TABS...');

patchZone('M2',
`    { key: 'leitor', label: t({ id: 'panel.tab.reader' }), hint: t({ id: 'panel.tab.reader.hint' }) },
    ...(isCoordOrAdmin && membershipEnabled ? [`,

`    { key: 'leitor', label: t({ id: 'panel.tab.reader' }), hint: t({ id: 'panel.tab.reader.hint' }) },
    { key: 'historico', label: t({ id: 'panel.tab.history' }), hint: t({ id: 'panel.tab.history.hint' }) },
    ...(isCoordOrAdmin && membershipEnabled ? [`);

// ============================================================
// MODIF 3 — State + logique apres selectedRes
// ============================================================
console.log('\n[2/3] State + logique historyTypes apres selectedRes...');

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

  useEffect(() => {
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
// MODIF 4 — Section onglet avant contribuicoes
// ============================================================
console.log('\n[3/3] Section JSX onglet historico avant contribuicoes...');

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
  { name: "tab === 'historico' (section)", pattern: /tab\s*===\s*'historico'/g, expected: 1 },
  { name: 'historyTypes (declarations + usages)', pattern: /historyTypes/g, min: 5, max: 15 },
  { name: 'dominantHistoryType', pattern: /dominantHistoryType/g, min: 2, max: 5 },
  { name: 'toggleHistoryType', pattern: /toggleHistoryType/g, min: 2, max: 5 },
  { name: 'ab-painel-history-pill', pattern: /ab-painel-history-pill/g, min: 1, max: 3 },
  // React.useEffect ne doit PAS apparaitre (bug v1 corrige)
  { name: 'React.useEffect (ne doit PAS apparaitre)', pattern: /React\.useEffect/g, expected: 0 },
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

console.log('\n===== Ecriture =====');
const newBuf = Buffer.from(content, 'utf8');
const newMd5 = crypto.createHash('md5').update(newBuf).digest('hex');
const newSize = newBuf.length;
fs.writeFileSync(FILE, newBuf);

console.log(`  PanelPage.jsx : ${originalSize} -> ${newSize} bytes (+${newSize - originalSize})`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);

console.log('\n===== Patch 143.2.c v2 applique =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff src/pages/painel/PanelPage.jsx');
console.log('  2. npm run build');
console.log('  3. Commit + push (i18n + CSS + JSX en 1 commit)');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
