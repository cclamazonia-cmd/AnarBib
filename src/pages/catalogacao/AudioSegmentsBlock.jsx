// AudioSegmentsBlock.jsx
// Chantier #AUDIO-fonds — P3b : bloc « Segments » du catalogage audio.
// Affiché dans BookDraftForm pour une notice audio/audiovisuelle PUBLIÉE (book_id réel) :
// liste/édite les audio_tracks (MB Track) + leurs contributeur·rices (grain segment),
// avec rattachement d'œuvre (public.works) par recherche. Écritures via les RPC P1
// (api.audio_track_*) ; lecture via la vue staff v_audio_tracklist. spec-fonds-sonores §5.
// Session : Fonds sonores

import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase, apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import AudioFingerprintTool from './AudioFingerprintTool';

// Rôles au grain segment — labels réutilisés de catalogacao.role.* (déjà i18nisés ×10).
const SEG_ROLE_KEYS = ['locutor', 'interprete', 'narrador', 'compositor', 'autor', 'tradutor', 'produtor', 'organizacao', 'outro'];

const EMPTY_DRAFT = {
  track_id: null, position: '', title: '', start_offset: '', duration: '',
  recording_type: '', recording_date: '', recording_date_approx: '', place_text: '',
  work_id: null, work_title: '',
};

export default function AudioSegmentsBlock({ bookId, onMsg }) {
  const { formatMessage: t } = useIntl();
  const [tracks, setTracks] = useState([]);
  const [recTypes, setRecTypes] = useState([]);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [draft, setDraft] = useState(null); // null = formulaire fermé
  const [workQuery, setWorkQuery] = useState('');
  const [workResults, setWorkResults] = useState([]);
  const [contribDraft, setContribDraft] = useState({}); // { [trackId]: { name, role } }

  const notify = useCallback((text, kind) => { if (onMsg) onMsg(text, kind); }, [onMsg]);

  const load = useCallback(async () => {
    if (!bookId) { setTracks([]); return; }
    setLoading(true);
    try {
      const [tl, rt] = await Promise.all([
        supabase.from('v_audio_tracklist').select('*').eq('book_id', Number(bookId)).order('position'),
        supabase.from('catalog_ref_audio_recording_types').select('code, label').eq('is_active', true).order('sort_order'),
      ]);
      setTracks(tl.data || []);
      setRecTypes(rt.data || []);
    } catch (e) {
      notify(t({ id: 'common.errorPrefix' }, { message: localizeError(e, t) }), 'error');
    } finally { setLoading(false); }
  }, [bookId, notify, t]);

  useEffect(() => { load(); }, [load]);

  // ── Recherche d'œuvre (picker complet) ──────────────────────────────
  async function searchWorks(q) {
    setWorkQuery(q);
    const term = q.trim();
    if (term.length < 2) { setWorkResults([]); return; }
    const { data } = await supabase.from('works')
      .select('id, uniform_title').ilike('uniform_title', `%${term}%`).order('uniform_title').limit(8);
    setWorkResults(data || []);
  }
  function attachWork(w) {
    setDraft(d => ({ ...d, work_id: w.id, work_title: w.uniform_title }));
    setWorkQuery(''); setWorkResults([]);
  }
  function detachWork() { setDraft(d => ({ ...d, work_id: null, work_title: '' })); }

  // ── Segment : ouvrir / enregistrer / supprimer ──────────────────────
  function openNew() {
    const nextPos = tracks.length ? Math.max(...tracks.map(x => Number(x.position) || 0)) + 1 : 1;
    setDraft({ ...EMPTY_DRAFT, position: String(nextPos) });
    setWorkQuery(''); setWorkResults([]);
  }
  function openEdit(tr) {
    setDraft({
      track_id: tr.track_id, position: String(tr.position ?? ''), title: tr.title || '',
      start_offset: tr.start_offset || '', duration: tr.duration || '',
      recording_type: tr.recording_type || '', recording_date: tr.recording_date || '',
      recording_date_approx: tr.recording_date_approx || '', place_text: tr.place_text || '',
      work_id: tr.work_id || null, work_title: tr.work_title || '',
    });
    setWorkQuery(''); setWorkResults([]);
  }
  function setF(field, value) { setDraft(d => ({ ...d, [field]: value })); }

  async function saveSegment() {
    if (!draft) return;
    const pos = parseInt(draft.position, 10);
    if (!Number.isFinite(pos)) { notify(t({ id: 'catalogacao.audio.seg.positionRequired' }), 'error'); return; }
    setBusy(true);
    try {
      await apiRpc('audio_track_upsert', {
        p_book_id: Number(bookId), p_position: pos,
        p_title: draft.title || null, p_start_offset: draft.start_offset || null, p_duration: draft.duration || null,
        p_work_id: draft.work_id || null, p_digital_resource_id: null,
        p_recording_type: draft.recording_type || null,
        p_recording_date: draft.recording_date || null, p_recording_date_approx: draft.recording_date_approx || null,
        p_place_text: draft.place_text || null, p_notes: null,
        p_track_id: draft.track_id || null,
      });
      notify(t({ id: 'catalogacao.audio.seg.saved' }), 'ok');
      setDraft(null);
      await load();
    } catch (e) {
      notify(t({ id: 'common.errorPrefix' }, { message: localizeError(e, t) }), 'error');
    } finally { setBusy(false); }
  }

  async function deleteSegment(trackId) {
    if (!confirm(t({ id: 'catalogacao.audio.seg.deleteConfirm' }))) return;
    setBusy(true);
    try {
      await apiRpc('audio_track_delete', { p_track_id: Number(trackId) });
      notify(t({ id: 'catalogacao.audio.seg.deleted' }), 'ok');
      await load();
    } catch (e) {
      notify(t({ id: 'common.errorPrefix' }, { message: localizeError(e, t) }), 'error');
    } finally { setBusy(false); }
  }

  // ── Contributeur·rices au grain segment ─────────────────────────────
  function setContrib(trackId, field, value) {
    setContribDraft(prev => ({ ...prev, [trackId]: { name: '', role: 'locutor', ...prev[trackId], [field]: value } }));
  }
  async function addContributor(trackId) {
    const cd = contribDraft[trackId] || {};
    const name = (cd.name || '').trim();
    if (!name) { notify(t({ id: 'catalogacao.audio.seg.nameRequired' }), 'error'); return; }
    setBusy(true);
    try {
      await apiRpc('audio_track_contributor_add', {
        p_track_id: Number(trackId), p_name: name, p_role: cd.role || 'locutor', p_author_id: null,
      });
      setContribDraft(prev => ({ ...prev, [trackId]: { name: '', role: cd.role || 'locutor' } }));
      await load();
    } catch (e) {
      notify(t({ id: 'common.errorPrefix' }, { message: localizeError(e, t) }), 'error');
    } finally { setBusy(false); }
  }
  async function removeContributor(contributorId) {
    setBusy(true);
    try {
      await apiRpc('audio_track_contributor_remove', { p_contributor_id: Number(contributorId) });
      await load();
    } catch (e) {
      notify(t({ id: 'common.errorPrefix' }, { message: localizeError(e, t) }), 'error');
    } finally { setBusy(false); }
  }

  const inputStyle = { width: '100%', padding: '5px 7px', fontSize: '.82rem', borderRadius: 6,
    border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.25)', color: 'inherit' };
  const labelStyle = { fontSize: '.7rem', color: 'var(--brand-muted, #aaa)', display: 'block', marginBottom: 2 };

  if (!bookId) return null;

  return (
    <section className="ab-audio-seg" style={{ marginTop: 18, padding: 14, borderRadius: 10, border: '1px solid rgba(255,255,255,.1)', background: 'rgba(0,0,0,.12)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
        <strong style={{ fontSize: '.92rem' }}>{t({ id: 'catalogacao.audio.seg.title' })}</strong>
        {!draft && (
          <button type="button" className="ab-button ab-button--sm" onClick={openNew} disabled={busy}>
            {t({ id: 'catalogacao.audio.seg.add' })}
          </button>
        )}
      </div>
      <p style={{ fontSize: '.74rem', color: 'var(--brand-muted, #aaa)', margin: '0 0 10px' }}>
        {t({ id: 'catalogacao.audio.seg.intro' })}
      </p>

      <AudioFingerprintTool bookId={bookId} onMsg={onMsg} tracks={tracks} />

      {/* Liste des segments */}
      {loading ? (
        <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'common.loading' })}</div>
      ) : tracks.length === 0 && !draft ? (
        <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.audio.seg.empty' })}</div>
      ) : (
        <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 8 }}>
          {tracks.map(tr => (
            <li key={tr.track_id} style={{ padding: 10, borderRadius: 8, background: 'rgba(0,0,0,.2)', border: '1px solid rgba(255,255,255,.07)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                <div style={{ minWidth: 0 }}>
                  <span style={{ fontWeight: 700, marginRight: 6 }}>{tr.position}.</span>
                  <span>{tr.title || t({ id: 'catalogacao.audio.seg.untitled' })}</span>
                  {tr.work_title && <span style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}> · {t({ id: 'catalogacao.audio.seg.work' })}: {tr.work_title}</span>}
                  <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)', marginTop: 2 }}>
                    {[tr.start_offset, tr.duration, tr.recording_type && (recTypes.find(r => r.code === tr.recording_type)?.label || tr.recording_type),
                      tr.recording_date || tr.recording_date_approx, tr.place_text].filter(Boolean).join(' · ')}
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 4, flexShrink: 0, alignItems: 'flex-start' }}>
                  <button type="button" className="ab-button ab-button--mini" onClick={() => openEdit(tr)} disabled={busy}>{t({ id: 'catalogacao.audio.seg.edit' })}</button>
                  <button type="button" className="ab-button ab-button--danger ab-button--mini" onClick={() => deleteSegment(tr.track_id)} disabled={busy}>{t({ id: 'catalogacao.audio.seg.delete' })}</button>
                </div>
              </div>

              {/* Contributeur·rices du segment */}
              <div style={{ marginTop: 8, paddingTop: 8, borderTop: '1px solid rgba(255,255,255,.06)' }}>
                <span style={labelStyle}>{t({ id: 'catalogacao.audio.seg.contributors' })}</span>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 6 }}>
                  {(tr.contributors || []).length === 0 && <span style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.audio.seg.noContrib' })}</span>}
                  {(tr.contributors || []).map(c => (
                    <span key={c.id} className="ab-pill" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                      {c.name} <em style={{ opacity: .7, fontStyle: 'normal', fontSize: '.7rem' }}>({t({ id: `catalogacao.role.${c.role}` })})</em>
                      <button type="button" onClick={() => removeContributor(c.id)} disabled={busy}
                        style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', padding: 0, opacity: .6 }} title={t({ id: 'catalogacao.audio.seg.delete' })}>×</button>
                    </span>
                  ))}
                </div>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  <input style={{ ...inputStyle, flex: 1, minWidth: 'min(140px, 100%)' }} placeholder={t({ id: 'catalogacao.audio.seg.contribName' })}
                    value={contribDraft[tr.track_id]?.name || ''} onChange={e => setContrib(tr.track_id, 'name', e.target.value)} />
                  <select style={{ ...inputStyle, width: 'auto' }} value={contribDraft[tr.track_id]?.role || 'locutor'} onChange={e => setContrib(tr.track_id, 'role', e.target.value)}>
                    {SEG_ROLE_KEYS.map(rk => <option key={rk} value={rk}>{t({ id: `catalogacao.role.${rk}` })}</option>)}
                  </select>
                  <button type="button" className="ab-button ab-button--mini" onClick={() => addContributor(tr.track_id)} disabled={busy}>{t({ id: 'catalogacao.audio.seg.contribAdd' })}</button>
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}

      {/* Formulaire d'ajout / édition */}
      {draft && (
        <div style={{ marginTop: 12, padding: 12, borderRadius: 8, background: 'rgba(0,0,0,.25)', border: '1px solid rgba(255,255,255,.12)' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 8 }}>
            <div><label style={labelStyle}>{t({ id: 'catalogacao.audio.seg.position' })}</label>
              <input style={inputStyle} type="number" min="1" value={draft.position} onChange={e => setF('position', e.target.value)} /></div>
            <div style={{ gridColumn: '1 / -1' }}><label style={labelStyle}>{t({ id: 'catalogacao.audio.seg.segTitle' })}</label>
              <input style={inputStyle} value={draft.title} onChange={e => setF('title', e.target.value)} /></div>
            <div><label style={labelStyle}>{t({ id: 'catalogacao.audio.seg.startOffset' })}</label>
              <input style={inputStyle} placeholder="00:12:30" value={draft.start_offset} onChange={e => setF('start_offset', e.target.value)} /></div>
            <div><label style={labelStyle}>{t({ id: 'catalogacao.audio.seg.duration' })}</label>
              <input style={inputStyle} value={draft.duration} onChange={e => setF('duration', e.target.value)} /></div>
            <div><label style={labelStyle}>{t({ id: 'catalogacao.audio.seg.recordingType' })}</label>
              <select style={inputStyle} value={draft.recording_type} onChange={e => setF('recording_type', e.target.value)}>
                <option value="">{t({ id: 'catalogacao.audio.seg.recordingTypeNone' })}</option>
                {recTypes.map(r => <option key={r.code} value={r.code}>{r.label}</option>)}
              </select></div>
            <div><label style={labelStyle}>{t({ id: 'catalogacao.audio.seg.recordingDate' })}</label>
              <input style={inputStyle} type="date" value={draft.recording_date || ''} onChange={e => setF('recording_date', e.target.value)} /></div>
            <div><label style={labelStyle}>{t({ id: 'catalogacao.audio.seg.recordingDateApprox' })}</label>
              <input style={inputStyle} placeholder={t({ id: 'catalogacao.audio.seg.recordingDateApproxPh' })} value={draft.recording_date_approx} onChange={e => setF('recording_date_approx', e.target.value)} /></div>
            <div><label style={labelStyle}>{t({ id: 'catalogacao.audio.seg.place' })}</label>
              <input style={inputStyle} value={draft.place_text} onChange={e => setF('place_text', e.target.value)} /></div>
          </div>

          {/* Picker d'œuvre */}
          <div style={{ marginTop: 8 }}>
            <label style={labelStyle}>{t({ id: 'catalogacao.audio.seg.work' })}</label>
            {draft.work_id ? (
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className="ab-pill">{draft.work_title}</span>
                <button type="button" className="ab-button ab-button--ghost ab-button--mini" onClick={detachWork}>{t({ id: 'catalogacao.audio.seg.workDetach' })}</button>
              </div>
            ) : (
              <div style={{ position: 'relative' }}>
                <input style={inputStyle} placeholder={t({ id: 'catalogacao.audio.seg.workSearch' })} value={workQuery} onChange={e => searchWorks(e.target.value)} />
                {workResults.length > 0 && (
                  <ul style={{ listStyle: 'none', margin: '4px 0 0', padding: 4, borderRadius: 6, border: '1px solid rgba(255,255,255,.15)', background: '#1a1a1a', maxHeight: 180, overflowY: 'auto' }}>
                    {workResults.map(w => (
                      <li key={w.id}>
                        <button type="button" onClick={() => attachWork(w)}
                          style={{ width: '100%', textAlign: 'left', padding: '4px 6px', background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', fontSize: '.8rem' }}>
                          {w.uniform_title}
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            )}
          </div>

          <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
            <button type="button" className="ab-button ab-button--sm" onClick={saveSegment} disabled={busy}>{t({ id: 'catalogacao.audio.seg.save' })}</button>
            <button type="button" className="ab-button ab-button--ghost ab-button--sm" onClick={() => setDraft(null)} disabled={busy}>{t({ id: 'catalogacao.audio.seg.cancel' })}</button>
          </div>
        </div>
      )}
    </section>
  );
}
