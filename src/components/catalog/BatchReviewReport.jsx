import { useIntl } from 'react-intl';

// BatchReviewReport — rendu du rapport de revision d'un lot (05/09/2026).
//
// Le rapport est produit par la base (fn_batch_review_report) : conventions,
// doublons, autorites, chacun avec un compte total et un echantillon borne a
// 40 lignes. Ce composant ne calcule rien, il lit. Il sert aux DEUX bords du
// circuit : la coordination (onglet Lots, avant et apres la demande) et
// l'administration (Reseau > Revisions).

const secTitle = { margin: '0 0 6px', fontSize: '.86rem', fontWeight: 700 };
const list = { margin: '4px 0 0 18px', padding: 0, lineHeight: 1.5 };
const muted = { color: 'var(--brand-muted, #999)' };

export default function BatchReviewReport({ report }) {
  const { formatMessage: t, formatDate } = useIntl();
  if (!report) return null;
  const b = report.batch || {};
  const tot = report.totals || {};
  const conv = Array.isArray(report.conventions) ? report.conventions : [];
  const dup = report.duplicates || {};
  const auth = report.authorities || {};
  const matching = dup.import_matching && typeof dup.import_matching === 'object' ? Object.entries(dup.import_matching) : [];

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
                {it.suggested_sort_name && <span style={{ color: 'var(--brand-accent, #4ade80)' }}> — {t({ id: 'review.report.auth.suggested' }, { name: it.suggested_sort_name })}</span>}
              </li>
            ))}
            {more(auth.unlinked_count ?? 0, auth.unlinked.length)}
          </ul>
        )}
      </section>
    </div>
  );
}
