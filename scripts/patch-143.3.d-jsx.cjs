// ============================================================
// Patch 143.3.d — JSX fetch + affichage listes historiques
// ============================================================
// Troisieme sous-patch du #143.3.
//
// 3 modifications dans PanelPage.jsx :
//
//   M1. State pour l'historique (apres le bloc historyTypes existant) :
//       - historyData : { reservas: [], consultas: [], emprestimos: [] }
//       - historyOffsets, historyHasMore, historyLoading
//
//   M2. Fonction loadHistorySection + useEffect d'auto-load au tab/pill
//       (apres toggleHistoryType, dans le meme bloc onglet Historique)
//
//   M3. Remplacement de la section JSX vide actuelle par les 3 sections
//       <details> avec tableaux differencies.
//
// Le code est dense. On ajoute environ 150 lignes au fichier.
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'src/pages/painel/PanelPage.jsx');

console.log('===== Patch 143.3.d JSX fetch + affichage historique =====\n');

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
if (content.includes('historyData') || content.includes('loadHistorySection')) {
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
// MODIF 1 — State pour donnees historiques (apres toggleHistoryType)
// ============================================================
console.log('[1/3] State historyData/offsets/hasMore/loading...');

patchZone('M1',
`  const toggleHistoryType = (type) => {
    setHistoryTypes(prev => {
      const next = new Set(prev || []);
      if (next.has(type)) next.delete(type);
      else next.add(type);
      return next;
    });
  };
  // === Fin onglet Historique ==================================`,

`  const toggleHistoryType = (type) => {
    setHistoryTypes(prev => {
      const next = new Set(prev || []);
      if (next.has(type)) next.delete(type);
      else next.add(type);
      return next;
    });
  };

  // Donnees historiques (chargees a la demande, paginees par 50)
  const [historyData, setHistoryData] = useState({ reservas: [], consultas: [], emprestimos: [] });
  const [historyOffsets, setHistoryOffsets] = useState({ reservas: 0, consultas: 0, emprestimos: 0 });
  const [historyHasMore, setHistoryHasMore] = useState({ reservas: true, consultas: true, emprestimos: true });
  const [historyLoading, setHistoryLoading] = useState({ reservas: false, consultas: false, emprestimos: false });

  const HISTORY_PAGE_SIZE = 50;
  const HISTORY_VIEW_NAMES = {
    reservas: 'painel_reservations_history_v1',
    consultas: 'painel_consultas_history_v1',
    emprestimos: 'painel_loans_history_v1'
  };

  const loadHistorySection = useCallback(async (type, append = false) => {
    if (historyLoading[type]) return;
    setHistoryLoading(prev => ({ ...prev, [type]: true }));
    
    const offset = append ? historyOffsets[type] : 0;
    const viewName = HISTORY_VIEW_NAMES[type];
    
    try {
      const { data, error } = await supabase
        .schema('api').from(viewName)
        .select('*')
        .range(offset, offset + HISTORY_PAGE_SIZE - 1);
      
      if (error) {
        console.error(\`load \${type} history error:\`, error);
        setHistoryLoading(prev => ({ ...prev, [type]: false }));
        return;
      }
      
      const items = data || [];
      const hasMore = items.length === HISTORY_PAGE_SIZE;
      
      setHistoryData(prev => ({
        ...prev,
        [type]: append ? [...prev[type], ...items] : items
      }));
      setHistoryOffsets(prev => ({ ...prev, [type]: offset + items.length }));
      setHistoryHasMore(prev => ({ ...prev, [type]: hasMore }));
    } catch (err) {
      console.error(\`load \${type} history exception:\`, err);
    } finally {
      setHistoryLoading(prev => ({ ...prev, [type]: false }));
    }
  }, [historyLoading, historyOffsets]);

  // Auto-load des sections cochees a l'ouverture de l'onglet
  useEffect(() => {
    if (tab !== 'historico' || !historyTypes) return;
    for (const type of ['reservas', 'consultas', 'emprestimos']) {
      if (historyTypes.has(type) && historyData[type].length === 0 && historyHasMore[type] && !historyLoading[type]) {
        loadHistorySection(type, false);
      }
    }
  }, [tab, historyTypes, historyData, historyHasMore, historyLoading, loadHistorySection]);
  // === Fin onglet Historique ==================================`);

// ============================================================
// MODIF 2 — Helpers de formatage (avant le return du composant)
// On les ajoute pres de la fin du composant pour rester ranges.
// ============================================================
// Note : on n'ajoute pas de helpers JS dedies, on inline les formatages
// directement dans le JSX pour rester compact.

// ============================================================
// MODIF 3 — Remplacement de la section JSX placeholder par les 3 sections
// ============================================================
console.log('\n[2/3] Remplacement section JSX (placeholder -> 3 sections collapsibles)...');

const placeholderAnchor = normalizeEol(`              <div className="ab-painel-history-list">
                {(historyTypes || new Set()).size === 0 ? (
                  <p className="ab-painel-hint">{t({ id: 'panel.history.noFilter' })}</p>
                ) : (
                  <p className="ab-painel-hint">{t({ id: 'panel.history.empty' })}</p>
                )}
              </div>`);

const newSectionsLF = `              {(historyTypes || new Set()).size === 0 ? (
                <p className="ab-painel-hint">{t({ id: 'panel.history.noFilter' })}</p>
              ) : (
                <div className="ab-painel-history-list">

                  {/* Section Reservations */}
                  {(historyTypes || new Set()).has('reservas') && (
                    <details className="ab-painel-history-section">
                      <summary className="ab-painel-history-section__summary">
                        <span className="ab-painel-history-section__title">{t({ id: 'panel.history.section.reservations' })}</span>
                        <span className="ab-painel-history-section__count">
                          {t({ id: 'panel.history.itemsCount' }, { count: historyData.reservas.length })}
                        </span>
                      </summary>
                      <div className="ab-painel-history-section__body">
                        {historyLoading.reservas && historyData.reservas.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'common.loading' })}</p>
                        ) : historyData.reservas.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'panel.history.section.empty' })}</p>
                        ) : (
                          <>
                            <div className="ab-painel-table-wrap">
                              <table className="ab-painel-history-table">
                                <thead>
                                  <tr>
                                    <th>{t({ id: 'panel.history.col.title' })}</th>
                                    <th>{t({ id: 'panel.history.col.status' })}</th>
                                    <th>{t({ id: 'panel.history.col.reader' })}</th>
                                    <th>{t({ id: 'panel.history.col.requested' })}</th>
                                    <th>{t({ id: 'panel.history.col.closed' })}</th>
                                    <th>{t({ id: 'panel.history.col.motif' })}</th>
                                  </tr>
                                </thead>
                                <tbody>
                                  {historyData.reservas.map((r, i) => (
                                    <tr key={\`hr-\${r.reserva_item_id || r.reserva_id + '-' + r.line_no || i}\`}>
                                      <td data-label={t({ id: 'panel.history.col.title' })}>
                                        <div className="truncate">{r.titulo || r.bib_ref || '—'}</div>
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.status' })}>
                                        {t({ id: \`reservation.stage.\${r.item_status}\`, defaultMessage: r.item_status })}
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.reader' })}>
                                        {r.user_name || r.user_email || r.user_public_id || '—'}
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.requested' })}>
                                        {r.requested_at ? new Date(r.requested_at).toLocaleDateString() : '—'}
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.closed' })}>
                                        {r.closed_at ? new Date(r.closed_at).toLocaleDateString() : '—'}
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.motif' })} className="cell-motif">
                                        {r.workflow_note || '—'}
                                      </td>
                                    </tr>
                                  ))}
                                </tbody>
                              </table>
                            </div>
                            {historyHasMore.reservas && (
                              <div className="ab-painel-history-loadmore">
                                <button type="button"
                                  onClick={() => loadHistorySection('reservas', true)}
                                  disabled={historyLoading.reservas}>
                                  {historyLoading.reservas ? '...' : t({ id: 'panel.history.loadMore' })}
                                </button>
                              </div>
                            )}
                          </>
                        )}
                      </div>
                    </details>
                  )}

                  {/* Section Consultas */}
                  {(historyTypes || new Set()).has('consultas') && (
                    <details className="ab-painel-history-section">
                      <summary className="ab-painel-history-section__summary">
                        <span className="ab-painel-history-section__title">{t({ id: 'panel.history.section.consultas' })}</span>
                        <span className="ab-painel-history-section__count">
                          {t({ id: 'panel.history.itemsCount' }, { count: historyData.consultas.length })}
                        </span>
                      </summary>
                      <div className="ab-painel-history-section__body">
                        {historyLoading.consultas && historyData.consultas.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'common.loading' })}</p>
                        ) : historyData.consultas.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'panel.history.section.empty' })}</p>
                        ) : (
                          <>
                            <div className="ab-painel-table-wrap">
                              <table className="ab-painel-history-table">
                                <thead>
                                  <tr>
                                    <th>{t({ id: 'panel.history.col.title' })}</th>
                                    <th>{t({ id: 'panel.history.col.status' })}</th>
                                    <th>{t({ id: 'panel.history.col.reader' })}</th>
                                    <th>{t({ id: 'panel.history.col.scheduled' })}</th>
                                    <th>{t({ id: 'panel.history.col.closed' })}</th>
                                    <th>{t({ id: 'panel.history.col.motif' })}</th>
                                  </tr>
                                </thead>
                                <tbody>
                                  {historyData.consultas.map((c, i) => {
                                    const motif = c.schedule_reply_note || c.workflow_note;
                                    return (
                                      <tr key={\`hc-\${c.consulta_item_id || c.consulta_id + '-' + c.line_no || i}\`}>
                                        <td data-label={t({ id: 'panel.history.col.title' })}>
                                          <div className="truncate">{c.titulo || c.bib_ref || '—'}</div>
                                        </td>
                                        <td data-label={t({ id: 'panel.history.col.status' })}>
                                          {t({ id: \`consultation.stage.\${c.item_status}\`, defaultMessage: c.item_status })}
                                        </td>
                                        <td data-label={t({ id: 'panel.history.col.reader' })}>
                                          {c.user_name || c.user_email || c.user_public_id || '—'}
                                        </td>
                                        <td data-label={t({ id: 'panel.history.col.scheduled' })}>
                                          {c.scheduled_for ? new Date(c.scheduled_for).toLocaleDateString() : '—'}
                                        </td>
                                        <td data-label={t({ id: 'panel.history.col.closed' })}>
                                          {c.closed_at ? new Date(c.closed_at).toLocaleDateString() : '—'}
                                        </td>
                                        <td data-label={t({ id: 'panel.history.col.motif' })} className="cell-motif">
                                          {motif || '—'}
                                        </td>
                                      </tr>
                                    );
                                  })}
                                </tbody>
                              </table>
                            </div>
                            {historyHasMore.consultas && (
                              <div className="ab-painel-history-loadmore">
                                <button type="button"
                                  onClick={() => loadHistorySection('consultas', true)}
                                  disabled={historyLoading.consultas}>
                                  {historyLoading.consultas ? '...' : t({ id: 'panel.history.loadMore' })}
                                </button>
                              </div>
                            )}
                          </>
                        )}
                      </div>
                    </details>
                  )}

                  {/* Section Emprestimos */}
                  {(historyTypes || new Set()).has('emprestimos') && (
                    <details className="ab-painel-history-section">
                      <summary className="ab-painel-history-section__summary">
                        <span className="ab-painel-history-section__title">{t({ id: 'panel.history.section.emprestimos' })}</span>
                        <span className="ab-painel-history-section__count">
                          {t({ id: 'panel.history.itemsCount' }, { count: historyData.emprestimos.length })}
                        </span>
                      </summary>
                      <div className="ab-painel-history-section__body">
                        {historyLoading.emprestimos && historyData.emprestimos.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'common.loading' })}</p>
                        ) : historyData.emprestimos.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'panel.history.section.empty' })}</p>
                        ) : (
                          <>
                            <div className="ab-painel-table-wrap">
                              <table className="ab-painel-history-table">
                                <thead>
                                  <tr>
                                    <th>{t({ id: 'panel.history.col.items' })}</th>
                                    <th>{t({ id: 'panel.history.col.type' })}</th>
                                    <th>{t({ id: 'panel.history.col.reader' })}</th>
                                    <th>{t({ id: 'panel.history.col.returned' })}</th>
                                  </tr>
                                </thead>
                                <tbody>
                                  {historyData.emprestimos.map((e, i) => (
                                    <tr key={\`he-\${e.emprestimo_id || i}\`}>
                                      <td data-label={t({ id: 'panel.history.col.items' })}>
                                        <div className="truncate" title={e.titulos || ''}>
                                          {e.titulos || e.bib_refs || '—'}
                                        </div>
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.type' })}>
                                        <span className="ab-painel-history-typepill" data-type={e.loan_type}>
                                          {t({ id: \`panel.history.type.\${e.loan_type}\`, defaultMessage: e.loan_type })}
                                          {e.items_count > 1 && \` (\${e.items_count})\`}
                                        </span>
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.reader' })}>
                                        {e.user_name || e.user_email || e.user_public_id || '—'}
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.returned' })}>
                                        {e.returned_at ? new Date(e.returned_at).toLocaleDateString() : '—'}
                                      </td>
                                    </tr>
                                  ))}
                                </tbody>
                              </table>
                            </div>
                            {historyHasMore.emprestimos && (
                              <div className="ab-painel-history-loadmore">
                                <button type="button"
                                  onClick={() => loadHistorySection('emprestimos', true)}
                                  disabled={historyLoading.emprestimos}>
                                  {historyLoading.emprestimos ? '...' : t({ id: 'panel.history.loadMore' })}
                                </button>
                              </div>
                            )}
                          </>
                        )}
                      </div>
                    </details>
                  )}

                </div>
              )}`;

const newSections = normalizeEol(newSectionsLF);

if (!content.includes(placeholderAnchor)) {
  throw new Error('M3 : ancre placeholder introuvable - le placeholder de #143.2.c v2 doit etre present');
}
content = content.replace(placeholderAnchor, newSections);
console.log('  OK : M3 (placeholder remplace par 3 sections)');

console.log('\n[3/3] Verifications...');

const checks = [
  { name: 'historyData (state + usages)', pattern: /historyData/g, min: 8, max: 30 },
  { name: 'loadHistorySection (decl + usages)', pattern: /loadHistorySection/g, min: 4, max: 10 },
  { name: 'HISTORY_VIEW_NAMES', pattern: /HISTORY_VIEW_NAMES/g, min: 2, max: 4 },
  { name: 'painel_reservations_history_v1 (string)', pattern: /painel_reservations_history_v1/g, expected: 1 },
  { name: 'painel_consultas_history_v1 (string)', pattern: /painel_consultas_history_v1/g, expected: 1 },
  { name: 'painel_loans_history_v1 (string)', pattern: /painel_loans_history_v1/g, expected: 1 },
  { name: '<details className=ab-painel-history-section', pattern: /<details className="ab-painel-history-section/g, expected: 3 },
  { name: 'React.useEffect (ne doit PAS apparaitre)', pattern: /React\.useEffect/g, expected: 0 },
];

let allOk = true;
for (const c of checks) {
  const count = (content.match(c.pattern) || []).length;
  let ok;
  if (c.expected !== undefined) {
    ok = count === c.expected;
    console.log(`  ${ok ? 'OK' : '!!'}  ${c.name.padEnd(54)} : ${count} (att ${c.expected})`);
  } else {
    ok = count >= c.min && count <= c.max;
    console.log(`  ${ok ? 'OK' : '!!'}  ${c.name.padEnd(54)} : ${count} (range [${c.min},${c.max}])`);
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

console.log('\n===== Patch 143.3.d applique =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff src/pages/painel/PanelPage.jsx');
console.log('  2. npm run build (verifier compilation)');
console.log('  3. Commit + push les 3 sous-patches b/c/d en 1 commit');
console.log('  4. Verifier en prod : aller sur /painel, onglet Historique');
console.log('     - 1 section visible avec count (la dominante prechoisie)');
console.log('     - Clic sur summary deplie le tableau');
console.log('     - Coller plusieurs pills affiche plusieurs sections');
console.log('     - Bouton Load more charge 50 items de plus');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
