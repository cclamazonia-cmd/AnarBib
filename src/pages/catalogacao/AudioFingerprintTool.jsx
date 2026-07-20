// AudioFingerprintTool.jsx
// Chantier #AUDIO-fonds — P3c : capture d'empreinte Chromaprint + lookup AcoustID.
// L'empreinte est calculée CÔTE CLIENT (wasm @unimusic/chromaprint, lazy-load) à
// partir d'un fichier audio choisi par le staff ; on interroge l'EF audio_fingerprint_lookup
// (AcoustID) ; les candidats MusicBrainz sont des CANDIDATS (FS-D1, jamais écrits en
// aveugle). « Appliquer » pose le résultat sur une CIBLE :
//   - un SEGMENT (audio_tracks.external_ids ← MBID d'enregistrement) — P3c(A) ;
//   - une RESSOURCE numérique audio (chromaprint_fp/acoustid_id) — grain fichier.
// spec-fonds-sonores §6, P3c. Session : Fonds sonores

import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase, apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

export default function AudioFingerprintTool({ bookId, onMsg, tracks }) {
  const { formatMessage: t } = useIntl();
  const [resources, setResources] = useState([]);
  const [targetKey, setTargetKey] = useState(''); // 'res:<id>' | 'track:<id>'
  const [busy, setBusy] = useState(null); // 'fp' | 'lookup' | 'apply' | null
  const [fp, setFp] = useState(null);     // { fingerprint, duration }
  const [candidates, setCandidates] = useState([]);

  const notify = useCallback((text, kind) => { if (onMsg) onMsg(text, kind); }, [onMsg]);

  useEffect(() => {
    let alive = true;
    (async () => {
      if (!bookId) return;
      const { data } = await supabase.from('book_digital_resources')
        .select('id, label, mime_type')
        .eq('book_id', Number(bookId)).in('resource_type', ['audio', 'video']).order('id');
      if (alive) setResources(data || []);
    })();
    return () => { alive = false; };
  }, [bookId]);

  // Cibles possibles : ressources audio + segments.
  const targets = [
    ...resources.map(r => ({ key: `res:${r.id}`, label: `📄 ${r.label || '#' + r.id}` })),
    ...(tracks || []).map(tr => ({ key: `track:${tr.track_id}`, label: `▸ ${tr.position}. ${tr.title || t({ id: 'catalogacao.audio.seg.untitled' })}` })),
  ];

  // Auto-sélection si une seule cible.
  useEffect(() => {
    if (!targetKey && targets.length === 1) setTargetKey(targets[0].key);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [resources, tracks]);

  async function runFingerprint(file) {
    if (!file) return;
    setBusy('fp'); setCandidates([]); setFp(null);
    try {
      const buf = await file.arrayBuffer();
      // Empreinte Chromaprint + durée, calculées côté client (wasm @unimusic/chromaprint,
      // lazy-load via un wrapper sans top-level await — cf. lib/chromaprintFingerprint.js).
      const { computeChromaprint } = await import('@/lib/chromaprintFingerprint');
      const { fingerprint, duration } = await computeChromaprint(buf);
      setFp({ fingerprint, duration });
      setBusy('lookup');
      const { data, error } = await supabase.functions.invoke('audio_fingerprint_lookup', {
        body: { fingerprint, duration },
      });
      if (error) throw error;
      if (data && data.ok === false) { notify(localizeError(data.error, t), 'error'); }
      setCandidates(data?.candidates || []);
      if ((data?.candidates || []).length === 0 && (!data || data.ok !== false)) {
        notify(t({ id: 'catalogacao.audio.fp.empty' }), 'info');
      }
    } catch (e) {
      notify(t({ id: 'common.errorPrefix' }, { message: localizeError(e, t) }), 'error');
    } finally { setBusy(null); }
  }

  async function applyCandidate(candidate) {
    if (!targetKey) { notify(t({ id: 'catalogacao.audio.fp.noTarget' }), 'error'); return; }
    const sep = targetKey.indexOf(':');
    const kind = targetKey.slice(0, sep);
    const id = Number(targetKey.slice(sep + 1));
    setBusy('apply');
    try {
      if (kind === 'track') {
        if (!candidate.recording_mbid && !candidate.acoustid) { notify(t({ id: 'catalogacao.audio.fp.empty' }), 'error'); return; }
        await apiRpc('audio_track_set_recording_mbid', {
          p_track_id: id,
          p_recording_mbid: candidate.recording_mbid || null,
          p_acoustid: candidate.acoustid || null,
        });
      } else {
        await apiRpc('audio_resource_set_fingerprint', {
          p_resource_id: id,
          p_chromaprint: fp?.fingerprint || null,
          p_duration_ms: fp ? Math.round(fp.duration * 1000) : null,
          p_acoustid: candidate.acoustid || null,
        });
      }
      notify(t({ id: 'catalogacao.audio.fp.applied' }), 'ok');
    } catch (e) {
      notify(t({ id: 'common.errorPrefix' }, { message: localizeError(e, t) }), 'error');
    } finally { setBusy(null); }
  }

  const inputStyle = { padding: '4px 6px', fontSize: '.8rem', borderRadius: 6, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.25)', color: 'inherit' };
  const labelStyle = { fontSize: '.7rem', color: 'var(--brand-muted, #aaa)', display: 'block', marginBottom: 2 };
  const busyLabel = busy === 'fp' ? t({ id: 'catalogacao.audio.fp.computing' })
    : busy === 'lookup' ? t({ id: 'catalogacao.audio.fp.looking' }) : null;

  if (!bookId) return null;

  return (
    <div style={{ marginTop: 12, paddingTop: 10, borderTop: '1px dashed rgba(255,255,255,.12)' }}>
      <strong style={{ fontSize: '.84rem' }}>{t({ id: 'catalogacao.audio.fp.title' })}</strong>
      <p style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)', margin: '2px 0 8px' }}>
        {t({ id: 'catalogacao.audio.fp.intro' })}
      </p>

      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'flex-end' }}>
        <label className="ab-button ab-button--sm" style={{ cursor: busy ? 'default' : 'pointer' }}>
          {t({ id: 'catalogacao.audio.fp.chooseFile' })}
          <input type="file" accept="audio/*,video/*" disabled={!!busy} style={{ display: 'none' }}
            onChange={e => runFingerprint(e.target.files?.[0])} />
        </label>
        {busyLabel && <span style={{ fontSize: '.76rem', color: 'var(--brand-muted, #aaa)' }}>{busyLabel}</span>}
        {targets.length > 0 && (
          <span>
            <label style={labelStyle}>{t({ id: 'catalogacao.audio.fp.target' })}</label>
            <select value={targetKey} onChange={e => setTargetKey(e.target.value)} style={inputStyle}>
              <option value="">—</option>
              {targets.map(tg => <option key={tg.key} value={tg.key}>{tg.label}</option>)}
            </select>
          </span>
        )}
      </div>

      {targets.length === 0 && fp && (
        <div style={{ fontSize: '.72rem', color: '#fbbf24', marginTop: 6 }}>{t({ id: 'catalogacao.audio.fp.noTarget' })}</div>
      )}

      {candidates.length > 0 && (
        <ul style={{ listStyle: 'none', margin: '10px 0 0', padding: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
          {candidates.map((c, i) => (
            <li key={i} style={{ display: 'flex', justifyContent: 'space-between', gap: 8, alignItems: 'center', flexWrap: 'wrap', padding: 8, borderRadius: 8, background: 'rgba(0,0,0,.2)', border: '1px solid rgba(255,255,255,.07)' }}>
              <div style={{ minWidth: 0 }}>
                <div style={{ fontSize: '.84rem' }}>{c.title || c.recording_mbid || c.acoustid}</div>
                <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>
                  {[c.artist_display, c.score ? `${t({ id: 'catalogacao.audio.fp.score' })} ${Math.round(c.score * 100)}%` : null].filter(Boolean).join(' · ')}
                  {c.musicbrainz_url && <> · <a href={c.musicbrainz_url} target="_blank" rel="noreferrer">MusicBrainz</a></>}
                </div>
              </div>
              <button type="button" className="ab-button ab-button--mini" disabled={!!busy || !targetKey}
                onClick={() => applyCandidate(c)} title={!targetKey ? t({ id: 'catalogacao.audio.fp.noTarget' }) : ''}>
                {t({ id: 'catalogacao.audio.fp.apply' })}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
