import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import BatchReviewReport from '@/components/catalog/BatchReviewReport';

// BatchReviewsPanel — onglet « Revisions » de la page Reseau (05/09/2026).
//
// Un lot ne d'un import ne se publie qu'apres l'approbation de l'admin
// reseau. Ici : les demandes en attente (rapport fige a la demande, rapport
// a jour sur un clic), le verdict motive ; puis l'historique des tranchees.
// Les RPC restent l'autorite : fn_batch_review_verdict refuse les retouches
// sans note, l'ecran ne fait que le dire avant.

const card = {
  padding: 14, marginBottom: 12, borderRadius: 10,
  background: 'var(--brand-panel-bg, rgba(16,16,16,.86))',
  border: '1px solid var(--brand-panel-border, rgba(255,255,255,.1))',
};
const muted = { color: 'var(--brand-muted, #999)', fontSize: '.8rem' };

export default function BatchReviewsPanel() {
  const { formatMessage: t, formatDate } = useIntl();
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState(null);
  const [notes, setNotes] = useState({});        // review_id -> texte
  const [live, setLive] = useState({});          // batch_id -> rapport a jour
  const [busy, setBusy] = useState(null);        // review_id en cours

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('fn_batch_reviews_list');
      if (error) throw error;
      // Tous les lots importes, tour de revision ou pas : ce qui attend, ce
      // qui est tranche, et ce qui est encore EN FILE sans demande (05/09/2026,
      // vu par Xavier : « je ne les vois pas, les lots a corriger »).
      setRows((data || []).filter(r => r.imported));
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setLoading(false); }
  }, [t]);

  useEffect(() => { load(); }, [load]);

  async function refreshReport(batchId) {
    try {
      const { data, error } = await supabase.rpc('fn_batch_review_report', { p_batch_id: batchId });
      if (error) throw error;
      setLive(l => ({ ...l, [batchId]: data }));
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  async function verdict(r, v) {
    const n = (notes[r.review_id] || '').trim();
    if (v === 'changes_requested' && !n) {
      setMsg({ text: t({ id: 'error.review.notes_required' }), kind: 'error' });
      return;
    }
    setBusy(r.review_id);
    try {
      const { error } = await supabase.rpc('fn_batch_review_verdict', {
        p_review_id: r.review_id, p_verdict: v, p_notes: n || null,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'rede.reviews.decided.ok' }), kind: 'ok' });
      await load();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setBusy(null); }
  }

  const pending = rows.filter(r => r.review_id && r.status === 'requested');
  const decided = rows.filter(r => r.review_id && r.status !== 'requested');
  // En file : lot importe encore ouvert, sans aucun tour. Le rapport se lit,
  // le verdict attend la demande de la coordination — la regle ne change pas.
  const queued = rows.filter(r => !r.review_id && r.batch_status === 'open');
  const fmt = (d) => (d ? formatDate(d, { dateStyle: 'medium', timeStyle: 'short' }) : '—');

  return (
    <div>
      <h3 style={{ margin: '0 0 4px', fontSize: '1rem' }}>{t({ id: 'rede.reviews.title' })}</h3>
      <p style={{ ...muted, margin: '0 0 14px' }}>{t({ id: 'rede.reviews.intro' })}</p>
      {msg && <div style={{ padding: '8px 12px', borderRadius: 8, marginBottom: 12, fontSize: '.85rem', background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>{msg.text}</div>}
      {loading && <p style={muted}>{t({ id: 'common.loading' })}</p>}

      {!loading && pending.length === 0 && <p style={muted}>{t({ id: 'rede.reviews.empty' })}</p>}

      {pending.length > 0 && <h4 style={{ margin: '0 0 8px', fontSize: '.9rem' }}>{t({ id: 'rede.reviews.pending' })} ({pending.length})</h4>}
      {pending.map(r => (
        <div key={r.review_id} style={card}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap', alignItems: 'baseline' }}>
            <strong>{r.batch_name}</strong>
            <span style={muted}>{t({ id: 'catalogacao.batch.review.round' }, { n: r.round })} · {t({ id: 'rede.reviews.drafts' }, { n: r.drafts_active ?? 0 })}</span>
          </div>
          <div style={muted}>{t({ id: 'rede.reviews.requestedBy' }, { name: r.requester_name || '—', date: fmt(r.requested_at) })}</div>
          {r.coord_message && (
            <div style={{ margin: '8px 0', padding: '8px 10px', borderLeft: '3px solid var(--brand-accent, #4ade80)', fontSize: '.85rem' }}>
              <span style={muted}>{t({ id: 'rede.reviews.message' })} :</span> {r.coord_message}
            </div>
          )}
          <details open style={{ margin: '10px 0' }}>
            <summary style={{ cursor: 'pointer', fontSize: '.86rem' }}>
              {t({ id: 'review.report.title' })}
              <button type="button" className="ab-button ab-button--ghost" style={{ marginLeft: 10, fontSize: '.72rem', padding: '2px 8px' }}
                onClick={(e) => { e.preventDefault(); refreshReport(r.batch_id); }}>
                {t({ id: 'rede.reviews.refresh' })}
              </button>
            </summary>
            <div style={{ marginTop: 8 }}>
              <BatchReviewReport report={live[r.batch_id] || r.report} />
            </div>
          </details>
          <label style={{ display: 'block', fontSize: '.78rem', ...muted }}>{t({ id: 'rede.reviews.notes' })}</label>
          <textarea rows={3} value={notes[r.review_id] || ''} onChange={e => setNotes(n => ({ ...n, [r.review_id]: e.target.value }))}
            placeholder={t({ id: 'rede.reviews.notesPlaceholder' })}
            style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem', boxSizing: 'border-box' }} />
          <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
            <button className="ab-button" disabled={busy === r.review_id} onClick={() => verdict(r, 'approved')}>{t({ id: 'rede.reviews.approve' })}</button>
            <button className="ab-button ab-button--secondary" disabled={busy === r.review_id} onClick={() => verdict(r, 'changes_requested')}>{t({ id: 'rede.reviews.changes' })}</button>
          </div>
        </div>
      ))}

      {queued.length > 0 && (
        <div style={{ marginTop: 16 }}>
          <h4 style={{ margin: '0 0 4px', fontSize: '.9rem' }}>{t({ id: 'rede.reviews.queued' })} ({queued.length})</h4>
          <p style={{ ...muted, margin: '0 0 8px' }}>{t({ id: 'rede.reviews.queuedHint' })}</p>
          {queued.map(r => (
            <div key={r.batch_id} style={card}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap', alignItems: 'baseline' }}>
                <strong>{r.batch_name}</strong>
                <span style={muted}>{t({ id: 'rede.reviews.drafts' }, { n: r.drafts_active ?? 0 })}</span>
              </div>
              {live[r.batch_id]
                ? (
                  <details open style={{ marginTop: 8 }}>
                    <summary style={{ cursor: 'pointer', fontSize: '.86rem' }}>{t({ id: 'review.report.title' })}</summary>
                    <div style={{ marginTop: 8 }}><BatchReviewReport report={live[r.batch_id]} /></div>
                  </details>
                )
                : (
                  <button type="button" className="ab-button ab-button--ghost" style={{ marginTop: 8, fontSize: '.75rem', padding: '4px 10px' }}
                    onClick={() => refreshReport(r.batch_id)}>
                    {t({ id: 'rede.reviews.showReport' })}
                  </button>
                )}
            </div>
          ))}
        </div>
      )}

      {decided.length > 0 && (
        <details style={{ marginTop: 16 }}>
          <summary style={{ cursor: 'pointer', fontSize: '.86rem' }}>{t({ id: 'rede.reviews.decided' })} ({decided.length})</summary>
          {decided.map(r => (
            <div key={r.review_id} style={{ ...card, marginTop: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
                <strong>{r.batch_name}</strong>
                <span style={{ fontSize: '.8rem', color: r.status === 'approved' ? '#4ade80' : '#fbbf24' }}>
                  {t({ id: `catalogacao.batch.review.${r.status}` })} · {t({ id: 'catalogacao.batch.review.round' }, { n: r.round })}
                </span>
              </div>
              <div style={muted}>{t({ id: 'rede.reviews.reviewedBy' }, { name: r.reviewer_name || '—', date: fmt(r.reviewed_at) })}</div>
              {r.admin_notes && <div style={{ marginTop: 6, fontSize: '.84rem' }}>{r.admin_notes}</div>}
              <details style={{ marginTop: 8 }}>
                <summary style={{ cursor: 'pointer', fontSize: '.82rem' }}>{t({ id: 'review.report.title' })}</summary>
                <div style={{ marginTop: 8 }}><BatchReviewReport report={r.report} /></div>
              </details>
            </div>
          ))}
        </details>
      )}
    </div>
  );
}
