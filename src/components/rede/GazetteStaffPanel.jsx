import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase, apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';

// ═══════════════════════════════════════════════════════════════════════════
// GazetteStaffPanel — onglet « Gazette » de RedePage (réservé network_staff).
//
// 100% frontend : accès direct aux tables (RLS *_network_staff en ALL autorise
// la lecture des brouillons + l'écriture). Deux sections :
//   • Contributions : triage des gazette_submissions (accepter / rejeter).
//   • Numéros : liste (brouillons inclus), aperçu de relecture des 10 locales,
//     et publication (draft → published). PAS d'auto-publication ailleurs.
// La diffusion à tout le staff (bouton « Diffuser ») viendra à l'Étape C.
// ═══════════════════════════════════════════════════════════════════════════

const GZ_LOCALES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'el', 'ca', 'eo', 'nl'];
const SUB_STATUSES = ['new', 'accepted', 'rejected', 'published'];

function blockText(b) {
  // Extrait le texte lisible d'un bloc de contenu (pour la relecture).
  const parts = [];
  if (b.label) parts.push(b.label);
  if (b.h) parts.push(b.h);
  if (b.title) parts.push(b.title);
  if (b.byline) parts.push(b.byline);
  if (Array.isArray(b.p)) parts.push(...b.p);
  if (b.src) parts.push('— ' + b.src);
  if (Array.isArray(b.items)) {
    for (const it of b.items) parts.push(Array.isArray(it) ? it.join(' · ') : String(it));
  }
  return parts;
}

export default function GazetteStaffPanel() {
  const { formatMessage: t, locale } = useIntl();
  const { user } = useAuth();
  const [section, setSection] = useState('contributions');
  const [subs, setSubs] = useState([]);
  const [subFilter, setSubFilter] = useState('new');
  const [issues, setIssues] = useState([]);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(null);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [preview, setPreview] = useState(null); // { issue, byLocale, loc }
  const [reviewLabel, setReviewLabel] = useState(''); // collectif relecteur saisi

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [s, i] = await Promise.all([
        supabase.from('gazette_submissions')
          .select('id,rubric,locale,title,body,title_i18n,body_i18n,i18n_status,link,event_date,contributor_name,contributor_collective,status,created_at')
          .order('created_at', { ascending: false }),
        supabase.from('gazette_issues')
          .select('id,number,slug,masthead_title,cover_date,status,published_at,published_broadcast_at')
          .order('number', { ascending: false }),
      ]);
      if (s.error) throw s.error;
      if (i.error) throw i.error;
      setSubs(s.data || []);
      setIssues(i.data || []);
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [t]);
  useEffect(() => { load(); }, [load]);

  async function decideSubmission(id, status) {
    setBusy('sub:' + id);
    try {
      const { error } = await supabase.from('gazette_submissions')
        .update({ status, reviewed_by: user?.id || null, reviewed_at: new Date().toISOString() })
        .eq('id', id);
      if (error) throw error;
      setMsg({ text: t({ id: 'common.dataSaved' }), kind: 'ok' });
      await load();
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(null);
    }
  }

  async function publishIssue(issue) {
    if (!window.confirm(t({ id: 'rede.gazeta.publishConfirm' }, { number: issue.number }))) return;
    setBusy('pub:' + issue.id);
    try {
      const { error } = await supabase.from('gazette_issues')
        .update({ status: 'published', published_at: issue.published_at || new Date().toISOString() })
        .eq('id', issue.id);
      if (error) throw error;
      setMsg({ text: t({ id: 'rede.gazeta.published' }, { number: issue.number }), kind: 'ok' });
      await load();
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(null);
    }
  }

  async function broadcastIssue(issue) {
    if (!window.confirm(t({ id: 'rede.gazeta.broadcastConfirm' }, { number: issue.number }))) return;
    setBusy('bc:' + issue.id);
    try {
      const { data, error } = await apiRpc('fn_gazette_broadcast', { p_issue_id: issue.id });
      if (error) throw error;
      setMsg({ text: t({ id: 'rede.gazeta.broadcastDone' }, { count: data ?? 0 }), kind: 'ok' });
      await load();
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(null);
    }
  }

  async function openPreview(issue) {
    setBusy('prev:' + issue.id);
    try {
      const { data, error } = await supabase.from('gazette_issue_locales')
        .select('locale,tagline,masthead,content,translation_status,source_locale,reviewed_by_label,reviewed_at')
        .eq('issue_id', issue.id);
      if (error) throw error;
      const byLocale = Object.fromEntries((data || []).map((r) => [r.locale, r]));
      const loc = GZ_LOCALES.find((l) => byLocale[l]) || null;
      setReviewLabel((loc && byLocale[loc]?.reviewed_by_label) || '');
      setPreview({ issue, byLocale, loc });
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(null);
    }
  }

  // Provenance d'une langue — ce que le colophon public imprimera.
  // « Retirer la relecture » ne peut pas rebasculer sur 'machine' en aveugle : le
  // n°01 a été écrit à la main en fr ET en pt-BR, et ces deux lignes portent
  // 'original'. Règle honnête : pas de langue source enregistrée = ce n'est pas
  // une traduction, donc retour à 'original' et non à 'machine'.
  async function setProvenance(loc, reviewed) {
    if (!preview) return;
    const label = reviewLabel.trim();
    if (reviewed && !label) return;
    setBusy('rev:' + loc);
    try {
      const patch = reviewed
        ? { translation_status: 'human_reviewed', reviewed_by_label: label, reviewed_at: new Date().toISOString() }
        : {
          translation_status: preview.byLocale[loc]?.source_locale ? 'machine' : 'original',
          reviewed_by_label: null,
          reviewed_at: null,
        };
      const { error } = await supabase.from('gazette_issue_locales')
        .update(patch).eq('issue_id', preview.issue.id).eq('locale', loc);
      if (error) throw error;
      setPreview((pv) => ({ ...pv, byLocale: { ...pv.byLocale, [loc]: { ...pv.byLocale[loc], ...patch } } }));
      if (!reviewed) setReviewLabel('');
      setMsg({ text: t({ id: 'rede.gazeta.review.saved' }), kind: 'ok' });
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(null);
    }
  }

  const fmtDate = (d) => (d ? new Date(d).toLocaleDateString(locale) : '—');
  const subStatusPill = (s) => (s === 'accepted' ? 'ok' : s === 'rejected' ? 'danger' : s === 'published' ? 'info' : 'warn');
  const filteredSubs = subFilter ? subs.filter((s) => s.status === subFilter) : subs;

  const box = { padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 14 };

  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 14, flexWrap: 'wrap' }}>
        <button className={`cat-tab-btn${section === 'contributions' ? ' active' : ''}`} onClick={() => setSection('contributions')}>
          {t({ id: 'rede.gazeta.contributions' })}{subs.filter((s) => s.status === 'new').length > 0 ? ` (${subs.filter((s) => s.status === 'new').length})` : ''}
        </button>
        <button className={`cat-tab-btn${section === 'issues' ? ' active' : ''}`} onClick={() => setSection('issues')}>
          {t({ id: 'rede.gazeta.issues' })}
        </button>
        <span style={{ flex: 1 }} />
        <button className="cat-btn secondary" onClick={load} disabled={loading}>
          {loading ? t({ id: 'rede.refreshing' }) : t({ id: 'rede.refresh' })}
        </button>
      </div>

      {msg.text && (
        <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.9rem', marginBottom: 14, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>
          {msg.text}
        </div>
      )}

      {/* ─── Contributions ─── */}
      {section === 'contributions' && (
        <div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12, gap: 10, flexWrap: 'wrap' }}>
            <h3 style={{ margin: 0 }}>{t({ id: 'rede.gazeta.contributions' })} ({filteredSubs.length})</h3>
            <select value={subFilter} onChange={(e) => setSubFilter(e.target.value)} style={{ padding: '8px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.9rem' }}>
              <option value="">{t({ id: 'common.all' })}</option>
              {SUB_STATUSES.map((s) => <option key={s} value={s}>{t({ id: `rede.gazeta.status.${s}` })}</option>)}
            </select>
          </div>
          {filteredSubs.length === 0 && <div style={{ ...box, color: 'var(--brand-muted)' }}>{t({ id: 'common.empty' })}</div>}
          {filteredSubs.map((s) => (
            <div key={s.id} style={box}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
                <div style={{ flex: 1, minWidth: 'min(220px, 100%)' }}>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginBottom: 4 }}>
                    <span className="cat-pill" style={{ fontSize: '.68rem' }}>{t({ id: `federacao.gazeta.rubric.${s.rubric}` })}</span>
                    {s.locale && <span className="cat-pill" style={{ fontSize: '.68rem' }}>{s.locale}</span>}
                    <span className={`cat-pill ${subStatusPill(s.status)}`} style={{ fontSize: '.68rem' }}>{t({ id: `rede.gazeta.status.${s.status}` })}</span>
                    {s.i18n_status && <span className={`cat-pill ${s.i18n_status === 'done' ? 'ok' : s.i18n_status === 'error' ? 'danger' : 'warn'}`} style={{ fontSize: '.68rem' }}>{t({ id: `rede.gazeta.i18nStatus.${s.i18n_status}` })}</span>}
                  </div>
                  <div style={{ fontWeight: 700, fontSize: '.98rem' }}>{(s.title_i18n && s.title_i18n[locale]) || s.title}</div>
                  <div style={{ fontSize: '.86rem', color: 'var(--brand-muted)', margin: '4px 0', whiteSpace: 'pre-wrap' }}>{(s.body_i18n && s.body_i18n[locale]) || s.body}</div>
                  <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)' }}>
                    {[s.contributor_name, s.contributor_collective].filter(Boolean).join(' · ') || '—'}
                    {s.event_date ? ` · ${fmtDate(s.event_date)}` : ''} · {fmtDate(s.created_at)}
                    {s.link && <> · <a href={s.link} target="_blank" rel="noopener noreferrer" style={{ color: 'var(--brand-link, #7fb0e0)' }}>{t({ id: 'rede.gazeta.source' })}</a></>}
                  </div>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'flex-end' }}>
                  {s.status !== 'accepted' && (
                    <button className="cat-btn primary" disabled={busy === 'sub:' + s.id} onClick={() => decideSubmission(s.id, 'accepted')}>
                      {t({ id: 'rede.gazeta.accept' })}
                    </button>
                  )}
                  {s.status !== 'rejected' && (
                    <button className="cat-btn ghost" style={{ color: '#f87171' }} disabled={busy === 'sub:' + s.id} onClick={() => decideSubmission(s.id, 'rejected')}>
                      {t({ id: 'rede.gazeta.reject' })}
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* ─── Numéros & publication ─── */}
      {section === 'issues' && (
        <div>
          <h3 style={{ marginBottom: 12 }}>{t({ id: 'rede.gazeta.issues' })} ({issues.length})</h3>
          {issues.length === 0 && <div style={{ ...box, color: 'var(--brand-muted)' }}>{t({ id: 'common.empty' })}</div>}
          {issues.map((iss) => (
            <div key={iss.id} style={box}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
                <div>
                  <div style={{ fontWeight: 700, fontSize: '1rem' }}>
                    N°{String(iss.number).padStart(2, '0')} — {((iss.masthead_title || '').split(' — ')[0] || iss.slug)} — {t({ id: 'rede.gazeta.tagline' })}
                    <span className={`cat-pill ${iss.status === 'published' ? 'ok' : 'warn'}`} style={{ fontSize: '.66rem', marginLeft: 8 }}>
                      {t({ id: `rede.gazeta.status.${iss.status}` })}
                    </span>
                  </div>
                  <div style={{ fontSize: '.8rem', color: 'var(--brand-muted)' }}>
                    {fmtDate(iss.cover_date)}{iss.published_at ? ` · ${t({ id: 'rede.gazeta.publishedAt' }, { date: fmtDate(iss.published_at) })}` : ''}
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  <button className="cat-btn secondary" disabled={busy === 'prev:' + iss.id} onClick={() => openPreview(iss)}>
                    {t({ id: 'rede.gazeta.preview' })}
                  </button>
                  {iss.status !== 'published' && (
                    <button className="cat-btn primary" disabled={busy === 'pub:' + iss.id} onClick={() => publishIssue(iss)}>
                      {t({ id: 'rede.gazeta.publish' })}
                    </button>
                  )}
                  {iss.status === 'published' && !iss.published_broadcast_at && (
                    <button className="cat-btn" style={{ background: 'rgba(52,211,153,.15)', borderColor: 'rgba(52,211,153,.45)', color: '#34d399' }} disabled={busy === 'bc:' + iss.id} onClick={() => broadcastIssue(iss)}>
                      {t({ id: 'rede.gazeta.broadcast' })}
                    </button>
                  )}
                  {iss.published_broadcast_at && (
                    <span className="cat-pill ok" style={{ fontSize: '.66rem', alignSelf: 'center' }}>
                      {t({ id: 'rede.gazeta.broadcastedAt' }, { date: fmtDate(iss.published_broadcast_at) })}
                    </span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* ─── Aperçu de relecture (modale simple) ─── */}
      {preview && (
        <div
          onClick={() => setPreview(null)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.6)', zIndex: 1000, display: 'flex', alignItems: 'flex-start', justifyContent: 'center', padding: '4vh 12px', overflow: 'auto' }}
        >
          <div onClick={(e) => e.stopPropagation()} style={{ background: '#17141d', border: '1px solid rgba(255,255,255,.12)', borderRadius: 14, maxWidth: 820, width: '100%', padding: 18 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, marginBottom: 12, flexWrap: 'wrap' }}>
              <h3 style={{ margin: 0 }}>{t({ id: 'rede.gazeta.previewTitle' }, { number: preview.issue.number })}</h3>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <select
                  value={preview.loc || ''}
                  onChange={(e) => {
                    const nl = e.target.value;
                    setReviewLabel(preview.byLocale[nl]?.reviewed_by_label || '');
                    setPreview((p) => ({ ...p, loc: nl }));
                  }}
                  style={{ padding: '6px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4' }}
                >
                  {GZ_LOCALES.filter((l) => preview.byLocale[l]).map((l) => (
                    <option key={l} value={l}>
                      {l} · {t({ id: `rede.gazeta.transStatus.${preview.byLocale[l]?.translation_status || 'machine'}` })}
                    </option>
                  ))}
                </select>
                <button className="cat-btn ghost" onClick={() => setPreview(null)}>{t({ id: 'common.close' })}</button>
              </div>
            </div>
            {(() => {
              const row = preview.loc ? preview.byLocale[preview.loc] : null;
              if (!row) return <p style={{ color: 'var(--brand-muted)' }}>{t({ id: 'rede.gazeta.previewEmpty' })}</p>;
              const pages = Array.isArray(row.content) ? row.content : [];
              return (
                <div style={{ maxHeight: '70vh', overflow: 'auto' }}>
                  <div style={{ color: 'var(--brand-muted)', fontSize: '.85rem', marginBottom: 10 }}>
                    {row.tagline} · {row.masthead?.mid || ''}
                  </div>
                  {/* Provenance : ce que le colophon public imprimera pour cette langue. */}
                  <div style={{ ...box, display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                    <span className={`cat-pill ${row.translation_status === 'human_reviewed' ? 'ok' : 'warn'}`} style={{ fontSize: '.66rem' }}>
                      {t({ id: `rede.gazeta.transStatus.${row.translation_status || 'machine'}` })}
                    </span>
                    {row.reviewed_at && (
                      <span style={{ fontSize: '.78rem', color: 'var(--brand-muted)' }}>{fmtDate(row.reviewed_at)}</span>
                    )}
                    <span style={{ flex: 1 }} />
                    <label htmlFor="gz-review-by" style={{ fontSize: '.78rem', color: 'var(--brand-muted)' }}>
                      {t({ id: 'rede.gazeta.review.by' })}
                    </label>
                    <input
                      id="gz-review-by"
                      value={reviewLabel}
                      onChange={(e) => setReviewLabel(e.target.value)}
                      placeholder={t({ id: 'rede.gazeta.review.placeholder' })}
                      style={{ padding: '6px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem', minWidth: 180 }}
                    />
                    <button
                      className="cat-btn primary"
                      disabled={busy === 'rev:' + preview.loc || !reviewLabel.trim()}
                      onClick={() => setProvenance(preview.loc, true)}
                    >
                      {t({ id: 'rede.gazeta.review.mark' })}
                    </button>
                    {row.translation_status === 'human_reviewed' && (
                      <button
                        className="cat-btn ghost"
                        disabled={busy === 'rev:' + preview.loc}
                        onClick={() => setProvenance(preview.loc, false)}
                      >
                        {t({ id: 'rede.gazeta.review.undo' })}
                      </button>
                    )}
                  </div>
                  {pages.map((pg, pi) => (
                    <div key={pi} style={{ marginBottom: 14, paddingBottom: 10, borderBottom: '1px solid rgba(255,255,255,.07)' }}>
                      <div style={{ fontWeight: 800, textTransform: 'uppercase', letterSpacing: '.04em', fontSize: '.8rem', color: '#cf6f6f', marginBottom: 4 }}>
                        {String(pi + 1).padStart(2, '0')} · {pg.sec}
                      </div>
                      {pg.intro && <div style={{ fontStyle: 'italic', color: 'var(--brand-muted)', fontSize: '.85rem', marginBottom: 6 }}>{pg.intro}</div>}
                      {(pg.blocks || []).map((b, bi) => (
                        <div key={bi} style={{ marginBottom: 8 }}>
                          {blockText(b).map((line, li) => (
                            <div key={li} style={{ fontSize: li === 0 ? '.95rem' : '.86rem', fontWeight: li === 0 ? 700 : 400, color: li === 0 ? 'inherit' : 'var(--brand-muted)', lineHeight: 1.5 }}>{line}</div>
                          ))}
                        </div>
                      ))}
                    </div>
                  ))}
                </div>
              );
            })()}
          </div>
        </div>
      )}
    </div>
  );
}
