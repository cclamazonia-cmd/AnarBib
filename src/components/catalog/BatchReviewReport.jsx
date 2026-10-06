import { useIntl } from 'react-intl';
import { coverageItemLabel } from '../../lib/importCoverage.js';

// BatchReviewReport — rendu du rapport de revision d'un lot (05/09/2026).
// H16 (26/09/2026) : section « couverture » — pour chaque import dont le lot
// est issu, ce qui n'a PAS été repris dans les notices (report.coverage).
//
// Le rapport est produit par la base (fn_batch_review_report) : conventions,
// doublons, autorites, chacun avec un compte total et un echantillon borne a
// 40 lignes. Ce composant ne calcule rien, il lit. Il sert aux DEUX bords du
// circuit : la coordination (onglet Lots, avant et apres la demande) et
// l'administration (Reseau > Revisions).

const secTitle = { margin: '0 0 6px', fontSize: '.86rem', fontWeight: 700 };
const list = { margin: '4px 0 0 18px', padding: 0, lineHeight: 1.5 };
const muted = { color: 'var(--brand-muted, #999)' };
// H19 : raisons d'un exemplaire importé bloquant (fn_batch_review_report, clé items).
const ITEM_REASONS = ['without_library', 'library_mismatch', 'library_without_numbering', 'code_taken', 'code_twice', 'code_pending_elsewhere'];

const ORDRE_COUVERTURE = { brut: 0, indice: 1, laisse: 2 };

// H21 lot 3 (05/10/2026) : les verdicts de la comparaison à trois états (base
// de l'import précédent, notice AnarBib, nouveau fichier), dans l'ordre du
// rapport (clé `updates` de fn_batch_review_report, absente des instantanés
// d'avant et des lots sans notice déjà importée).
const VERDICTS = ['conflit', 'source_seule', 'sans_base', 'local_seul', 'identique', 'inchange'];
// Une valeur comparée, lisible : vide, liste de responsabilités [nom, rôle],
// ensemble de vedettes, texte (coupé).
function valeurComparee(v) {
  if (v == null || (Array.isArray(v) && v.length === 0)) return '∅';
  if (Array.isArray(v)) {
    return v.map((x) => (Array.isArray(x) ? `${x[0] ?? '?'}${x[1] ? ` (${x[1]})` : ''}` : String(x))).join(' ; ');
  }
  const s = String(v);
  return s.length > 120 ? `${s.slice(0, 117)}…` : s;
}

export default function BatchReviewReport({ report }) {
  const { formatMessage: t, formatDate } = useIntl();
  if (!report) return null;
  const b = report.batch || {};
  const tot = report.totals || {};
  const conv = Array.isArray(report.conventions) ? report.conventions : [];
  const dup = report.duplicates || {};
  const auth = report.authorities || {};
  const matching = dup.import_matching && typeof dup.import_matching === 'object' ? Object.entries(dup.import_matching) : [];
  const coverage = Array.isArray(report.coverage) ? report.coverage : [];
  // H19 : les exemplaires importés du lot (promus avec une notice, ou venus
  // d'un rapprochement), et ce qui empêcherait leur publication ; 40 problèmes
  // au plus, les comptes portent sur tout.
  const items = report.items && typeof report.items === 'object' ? report.items : null;
  const itemProblems = Array.isArray(items?.problems) ? items.problems : [];
  const itemProblemCount = Math.max(itemProblems.length, ITEM_REASONS.reduce((n, k) => n + Number(items?.[k] || 0), 0));
  // H21 lot 3 : les notices déjà importées du lot, comparées à trois états ;
  // 40 exemples au plus (conflits d'abord), les comptes portent sur tout.
  const updates = report.updates && typeof report.updates === 'object' ? report.updates : null;
  const updateCounts = updates?.counts && typeof updates.counts === 'object' ? updates.counts : {};
  const updateExamples = Array.isArray(updates?.examples) ? updates.examples : [];
  const updateNotable = ['conflit', 'source_seule', 'sans_base', 'local_seul'].reduce((n, k) => n + Number(updateCounts[k] || 0), 0);
  // H21 lot 4 (06/10/2026, IMP-31) : les brouillons de mise à jour préparés
  // par un réimport (clé `prepared_updates`, absente des instantanés d'avant
  // et des lots sans mise à jour) : pour chacun, les champs appliqués et les
  // champs MONTRÉS non appliqués (responsabilités changées dans le fichier,
  // conflits, sans base) ; 40 brouillons au plus, les comptes portent sur tout.
  const prepared = report.prepared_updates && typeof report.prepared_updates === 'object' ? report.prepared_updates : null;
  const preparedExamples = Array.isArray(prepared?.examples) ? prepared.examples : [];
  // B30 (27/09/2026) : le rapport dit pour quelle bibliothèque il a été rendu
  // (report.batch.library_id / library_name ; nulle = administration du
  // réseau). Les instantanés figés avant B30 n'en ont pas : on n'affiche rien.
  const bibliotheque = ('library_id' in b || 'library_name' in b)
    ? (b.library_name || (b.library_id == null ? t({ id: 'catalogacao.batch.library.network' }) : null))
    : null;

  const draftLabel = (it) => (
    <>
      <span style={muted}>{t({ id: 'review.report.draft' }, { id: it.draft_id })}</span>
      {it.titulo ? <> — {it.titulo}</> : null}
    </>
  );
  const more = (count, shown) => (count > shown
    ? <li style={muted}>{t({ id: 'review.report.more' }, { n: count - shown })}</li>
    : null);

  return (
    <div style={{ fontSize: '.84rem', display: 'grid', gap: 14 }}>
      <div>
        <div>{t({ id: 'review.report.summary' }, { active: b.drafts_active ?? 0, published: b.drafts_published ?? 0, cancelled: b.drafts_cancelled ?? 0 })}</div>
        {bibliotheque && (
          <div data-testid="review-report-library" style={muted}>{t({ id: 'review.report.library' }, { library: bibliotheque })}</div>
        )}
        <div style={{ fontWeight: 600 }}>{t({ id: 'review.report.totals' }, { issues: tot.convention_issues ?? 0, dups: tot.duplicates ?? 0, unlinked: tot.unlinked_authorities ?? 0 })}</div>
        {(b.title_entries ?? 0) > 0 && (
          <div style={muted}>{t({ id: 'review.report.titleEntries' }, { n: b.title_entries })}</div>
        )}
        {report.generated_at && (
          <div style={{ ...muted, fontSize: '.76rem' }}>{t({ id: 'review.report.generatedAt' }, { date: formatDate(report.generated_at, { dateStyle: 'medium', timeStyle: 'short' }) })}</div>
        )}
      </div>

      <section>
        <h5 style={secTitle}>{t({ id: 'review.report.conventions' })}</h5>
        {conv.length === 0 && <div style={muted}>{t({ id: 'review.report.noIssues' })}</div>}
        {conv.map((r) => (
          <details key={r.rule} style={{ marginBottom: 4 }}>
            <summary style={{ cursor: 'pointer' }}>
              {t({ id: `review.report.rule.${r.rule}`, defaultMessage: r.rule })} · <strong>{r.count}</strong>
            </summary>
            <ul style={list}>
              {(r.items || []).map((it, i) => (
                <li key={i}>{draftLabel(it)}{it.value ? <span style={muted}> : {it.value}</span> : null}</li>
              ))}
              {more(r.count, (r.items || []).length)}
            </ul>
          </details>
        ))}
      </section>

      <section>
        <h5 style={secTitle}>{t({ id: 'review.report.duplicates' })}</h5>
        {(dup.catalog_isbn || []).length === 0 && (dup.catalog_meta || []).length === 0 && (dup.intra_lot || []).length === 0 && (
          <div style={muted}>{t({ id: 'review.report.noIssues' })}</div>
        )}
        {(dup.catalog_isbn || []).length > 0 && (
          <details open>
            <summary style={{ cursor: 'pointer' }}>{t({ id: 'review.report.dup.catalogIsbn' })} · <strong>{dup.catalog_isbn.length}</strong></summary>
            <ul style={list}>{dup.catalog_isbn.map((it, i) => <li key={i}>{draftLabel(it)} → {t({ id: 'review.report.dup.book' }, { id: it.book_id })}</li>)}</ul>
          </details>
        )}
        {(dup.catalog_meta || []).length > 0 && (
          <details open>
            <summary style={{ cursor: 'pointer' }}>{t({ id: 'review.report.dup.catalogMeta' })} · <strong>{dup.catalog_meta.length}</strong></summary>
            <ul style={list}>{dup.catalog_meta.map((it, i) => <li key={i}>{draftLabel(it)} → {t({ id: 'review.report.dup.book' }, { id: it.book_id })}</li>)}</ul>
          </details>
        )}
        {(dup.intra_lot || []).length > 0 && (
          <details open>
            <summary style={{ cursor: 'pointer' }}>{t({ id: 'review.report.dup.intraLot' })} · <strong>{dup.intra_lot.length}</strong></summary>
            <ul style={list}>{dup.intra_lot.map((it, i) => <li key={i}>{it.titulo} <span style={muted}>({(it.draft_ids || []).join(', ')})</span></li>)}</ul>
          </details>
        )}
        {matching.length > 0 && (
          <div style={{ ...muted, marginTop: 6 }}>
            {t({ id: 'review.report.dup.importMatching' })} : {matching.map(([k, n]) => `${k} ${n}`).join(' · ')}
          </div>
        )}
      </section>

      <section>
        <h5 style={secTitle}>{t({ id: 'review.report.authorities' })}</h5>
        <div>{t({ id: 'review.report.auth.summary' }, { unlinked: auth.unlinked_count ?? 0, linkable: auth.linkable_count ?? 0 })}</div>
        {(auth.unlinked || []).length > 0 && (
          <ul style={list}>
            {auth.unlinked.map((it, i) => (
              <li key={i}>
                {it.name} <span style={muted}>({draftLabel(it)})</span>
                {it.suggested_sort_name && <span style={{ color: '#4ade80' }}> — {t({ id: 'review.report.auth.suggested' }, { name: it.suggested_sort_name })}</span>}
              </li>
            ))}
            {more(auth.unlinked_count ?? 0, auth.unlinked.length)}
          </ul>
        )}
      </section>

      {items && (items.count ?? 0) > 0 && (
        <section data-testid="review-items">
          <h5 style={secTitle}>{t({ id: 'review.report.items' })}</h5>
          <div>{t({ id: 'review.report.items.summary' }, { count: items.count ?? 0, withCode: items.with_code ?? 0 })}</div>
          {itemProblems.length === 0 ? (
            <div style={muted}>{t({ id: 'review.report.noIssues' })}</div>
          ) : (
            <ul style={list}>
              {itemProblems.slice(0, 40).map((p) => (
                <li key={p.item_draft_id} data-item-problem={p.reason}>
                  {/* Un exemplaire de rapprochement n'a pas de brouillon de notice : le titre de la notice visée. */}
                  {p.draft_id ? draftLabel(p) : (p.titulo || '—')}
                  {p.source_item_code ? <> · <code>{p.source_item_code}</code></> : null}
                  {' — '}<strong>{t({ id: `review.report.items.reason.${p.reason}` })}</strong>
                </li>
              ))}
              {more(itemProblemCount, Math.min(itemProblems.length, 40))}
            </ul>
          )}
        </section>
      )}

      {updates && Number(updates.rows || 0) > 0 && (
        <section data-testid="review-updates">
          <h5 style={secTitle}>{t({ id: 'review.report.updates' })}</h5>
          <div>{t({ id: 'review.report.updates.summary' }, { rows: Number(updates.rows || 0), changed: Number(updates.rows_with_changes || 0) })}</div>
          {/* Lu dans les comparaisons stockées : celles qui manquent (ou périmées) le disent. */}
          {'compared_rows' in updates && Number(updates.compared_rows || 0) < Number(updates.rows || 0) && (
            <div data-testid="review-updates-not-compared" style={muted}>
              {t({ id: 'review.report.updates.notCompared' }, { n: Number(updates.rows || 0) - Number(updates.compared_rows || 0) })}
            </div>
          )}
          <div style={muted}>
            {VERDICTS.filter((v) => Number(updateCounts[v] || 0) > 0)
              .map((v) => `${t({ id: `review.report.updates.verdict.${v}` })} ${Number(updateCounts[v])}`)
              .join(' · ')}
          </div>
          {updateExamples.length > 0 && (
            <ul style={list}>
              {updateExamples.slice(0, 40).map((e, i) => (
                <li key={`${e.row_id}-${e.champ}-${i}`} data-update-verdict={e.verdict}>
                  {e.titulo || '—'}
                  {e.external_key ? <span style={muted}> ({e.external_key})</span> : null}
                  {' · '}<code>{e.champ}</code>{' — '}
                  <strong>{t({ id: `review.report.updates.verdict.${e.verdict}` })}</strong>
                  <div style={muted}>
                    {t({ id: 'review.report.updates.values' }, {
                      b: valeurComparee(e.b),
                      // notice hors de la vue de qui lit : la base le masque, l'écran le dit
                      a: e.a_masque ? t({ id: 'review.report.updates.masked' }) : valeurComparee(e.a),
                      n: valeurComparee(e.n),
                    })}
                  </div>
                </li>
              ))}
              {more(updateNotable, Math.min(updateExamples.length, 40))}
            </ul>
          )}
        </section>
      )}

      {prepared && Number(prepared.count || 0) > 0 && (
        <section data-testid="review-prepared">
          <h5 style={secTitle}>{t({ id: 'review.report.prepared' })}</h5>
          <div>{t({ id: 'review.report.prepared.summary' }, {
            count: Number(prepared.count || 0),
            applied: Number(prepared.applied_fields || 0),
            shown: Number(prepared.shown_fields || 0),
          })}</div>
          <ul style={list}>
            {preparedExamples.slice(0, 40).map((e) => (
              <li key={e.draft_id} data-prepared-draft={e.draft_id}>
                {draftLabel({ draft_id: e.draft_id, titulo: e.titulo })}
                {e.external_key ? <span style={muted}> ({e.external_key})</span> : null}
                <ul style={list}>
                  {(Array.isArray(e.applied) ? e.applied : []).map((c, i) => (
                    <li key={`a-${c.champ}-${i}`} data-prepared-field="applied">
                      <code>{c.champ}</code>{' — '}<strong>{t({ id: 'review.report.prepared.applied' })}</strong>
                      <div style={muted}>{t({ id: 'review.report.updates.values' }, { b: valeurComparee(c.b), a: valeurComparee(c.a), n: valeurComparee(c.n) })}</div>
                    </li>
                  ))}
                  {(Array.isArray(e.shown) ? e.shown : []).map((c, i) => (
                    <li key={`s-${c.champ}-${i}`} data-prepared-field="shown" data-update-verdict={c.verdict}>
                      <code>{c.champ}</code>{' — '}<strong>{t({ id: 'review.report.prepared.shown' })}</strong>
                      {c.verdict ? <> · {t({ id: `review.report.updates.verdict.${c.verdict}` })}</> : null}
                      {/* IMP-31 c : un champ que le fichier vide est montré, jamais appliqué */}
                      {c.raison === 'efface_par_la_source' ? <> · {t({ id: 'review.report.prepared.erased' })}</> : null}
                      <div style={muted}>{t({ id: 'review.report.updates.values' }, { b: valeurComparee(c.b), a: valeurComparee(c.a), n: valeurComparee(c.n) })}</div>
                    </li>
                  ))}
                </ul>
              </li>
            ))}
            {more(Number(prepared.count || 0), Math.min(preparedExamples.length, 40))}
          </ul>
        </section>
      )}

      {coverage.length > 0 && (
        <section data-testid="review-coverage">
          <h5 style={secTitle}>{t({ id: 'review.report.coverage' })}</h5>
          {coverage.map((c) => {
            // H17 : le brut d'abord (à instruire), puis l'indice, puis le laissé
            // exprès — la liste est coupée à 40, le brut ne doit pas s'y noyer.
            const items = (Array.isArray(c.not_taken) ? [...c.not_taken] : [])
              .sort((a, b) => ((ORDRE_COUVERTURE[a.status] ?? 3) - (ORDRE_COUVERTURE[b.status] ?? 3)) || ((b.occurrences || 0) - (a.occurrences || 0)));
            return (
              <details key={c.run_id} style={{ marginBottom: 4 }}>
                <summary style={{ cursor: 'pointer' }}>
                  {t({ id: 'review.report.coverage.run' }, { id: c.run_id, file: c.original_filename || '—' })}
                  {c.counts ? <> · {t({ id: 'importacoes.coverage.counts' }, c.counts)}</> : null}
                  {Number(c.counts?.laisse || 0) > 0 ? <> · {t({ id: 'importacoes.coverage.countsLaisse' }, { n: Number(c.counts.laisse) })}</> : null}
                </summary>
                {Number(c.skipped_rows || 0) > 0 && (
                  <div style={muted}>{t({ id: 'importacoes.coverage.skipped' }, { n: Number(c.skipped_rows) })}</div>
                )}
                {c.encoding?.fallback && (
                  <div style={muted}>{t({ id: 'importacoes.run.encoding.fallback' }, { enc: c.encoding.used })}</div>
                )}
                {items.length === 0 ? (
                  <div style={muted}>{t({ id: c.counts ? 'review.report.coverage.allTaken' : 'importacoes.coverage.none' })}</div>
                ) : (
                  <ul style={list}>
                    {items.slice(0, 40).map((it, i) => (
                      <li key={i}>
                        <code>{coverageItemLabel(it)}</code> — {t({ id: `importacoes.coverage.status.${it.status}` })}
                        {it.status === 'laisse' && it.motif ? <span style={muted}> ({t({ id: `importacoes.coverage.motif.${it.motif}` })})</span> : null}
                        {' · '}{t({ id: 'importacoes.coverage.occurrences' }, { n: it.occurrences || 0 })}
                        {it.example ? <span style={muted}> : {it.example}</span> : null}
                      </li>
                    ))}
                    {more(items.length, Math.min(items.length, 40))}
                  </ul>
                )}
              </details>
            );
          })}
        </section>
      )}
    </div>
  );
}
