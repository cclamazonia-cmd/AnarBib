// AudioFingerprintTool.jsx
// Chantier #AUDIO-fonds — P3c : capture d'empreinte Chromaprint + lookup AcoustID.
// L'empreinte est calculée CÔTE CLIENT (wasm @unimusic/chromaprint, lazy-load) à
// partir d'un fichier audio choisi par le staff ; on interroge l'EF audio_fingerprint_lookup
// (AcoustID) ; les candidats MusicBrainz sont des CANDIDATS (FS-D1, jamais écrits en
// aveugle). « Appliquer » persiste l'empreinte + l'AcoustID choisi sur la ressource
// numérique audio (api.audio_resource_set_fingerprint). spec-fonds-sonores §6, P3c.
// Session : Fonds sonores

import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase, apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

export default function AudioFingerprintTool({ bookId, onMsg }) {
  const { formatMessage: t } = useIntl();
  const [resources, setResources] = useState([]);
  const [resourceId, setResourceId] = useState('');
  const [busy, setBusy] = useState(null); // 'fp' | 'lookup' | 'apply' | null
  const [fp, setFp] = useState(null);     // { fingerprint, duration }
  const [candidates, setCandidates] = useState([]);

  const notify = useCallback((text, kind) => { if (onMsg) onMsg(text, kind); }, [onMsg]);

  useEffect(() => {
    let alive = true;
    (async () => {
      if (!bookId) return;
      const { data } = await supabase.from('book_digital_resources')
        .select('id, label, mime_type, acoustid_id')
        .eq('book_id', Number(bookId)).in('resource_type', ['audio', 'video']).order('id');
      if (!alive) return;
      const rows = data || [];
      setResources(rows);
      if (rows.length === 1) setResourceId(String(rows[0].id));
    })();
    return () => { alive = false; };
  }, [bookId]);

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
      // Lookup AcoustID via l'EF.
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

  async function applyFingerprint(candidate) {
    if (!resourceId) { notify(t({ id: 'catalogacao.audio.fp.noResource' }), 'error'); return; }
    setBusy('apply');
    try {
      await apiRpc('audio_resource_set_fingerprint', {
        p_resource_id: Number(resourceId),
        p_chromaprint: fp?.fingerprint || null,
        p_duration_ms: fp ? Math.round(fp.duration * 1000) : null,
        p_acoustid: candidate.acoustid || null,
      });
      notify(t({ id: 'catalogacao.audio.fp.applied' }), 'ok');
    } catch (e) {
      notify(t({ id: 'common.errorPrefix' }, { message: localizeError(e, t) }), 'error');
    } finally { setBusy(null); }
  }

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

      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
        <label className="ab-button ab-button--sm" style={{ cursor: busy ? 'default' : 'pointer' }}>
          {t({ id: 'catalogacao.audio.fp.chooseFile' })}
          <input type="file" accept="audio/*,video/*" disabled={!!busy} style={{ display: 'none' }}
            onChange={e => runFingerprint(e.target.files?.[0])} />
        </label>
        {busyLabel && <span style={{ fontSize: '.76rem', color: 'var(--brand-muted, #aaa)' }}>{busyLabel}</span>}
        {resources.length > 1 && (
          <span>
            <label style={labelStyle}>{t({ id: 'catalogacao.audio.fp.resource' })}</label>
            <select value={resourceId} onChange={e => setResourceId(e.target.value)}
              style={{ padding: '4px 6px', fontSize: '.8rem', borderRadius: 6, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.25)', color: 'inherit' }}>
              <option value="">—</option>
              {resources.map(r => <option key={r.id} value={r.id}>{r.label || `#${r.id}`} ({r.mime_type})</option>)}
            </select>
          </span>
        )}
      </div>

      {resources.length === 0 && fp && (
        <div style={{ fontSize: '.72rem', color: '#fbbf24', marginTop: 6 }}>{t({ id: 'catalogacao.audio.fp.noResource' })}</div>
      )}

      {candidates.length > 0 && (
        <ul style={{ listStyle: 'none', margin: '10px 0 0', padding: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
          {candidates.map((c, i) => (
            <li key={i} style={{ display: 'flex', justifyContent: 'space-between', gap: 8, alignItems: 'center', padding: 8, borderRadius: 8, background: 'rgba(0,0,0,.2)', border: '1px solid rgba(255,255,255,.07)' }}>
              <div style={{ minWidth: 0 }}>
                <div style={{ fontSize: '.84rem' }}>{c.title || c.recording_mbid || c.acoustid}</div>
                <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>
                  {[c.artist_display, c.score ? `${t({ id: 'catalogacao.audio.fp.score' })} ${Math.round(c.score * 100)}%` : null].filter(Boolean).join(' · ')}
                  {c.musicbrainz_url && <> · <a href={c.musicbrainz_url} target="_blank" rel="noreferrer">MusicBrainz</a></>}
                </div>
              </div>
              <button type="button" className="ab-button ab-button--mini" disabled={!!busy || !resourceId}
                onClick={() => applyFingerprint(c)} title={!resourceId ? t({ id: 'catalogacao.audio.fp.noResource' }) : ''}>
                {t({ id: 'catalogacao.audio.fp.apply' })}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
