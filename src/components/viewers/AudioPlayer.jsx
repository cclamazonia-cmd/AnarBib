// ═══════════════════════════════════════════════════════════
// AudioPlayer — lecteur audio AnarBib
// ═══════════════════════════════════════════════════════════
//
// Composant standalone pour lire des assets audio (MP3, OGG, FLAC, etc.)
// avec un niveau de qualité comparable à PdfViewer :
//
//   - Chargement en blob (l'URL signée n'est jamais exposée au DOM)
//   - Scope du clic droit / drag / save au conteneur du player
//   - Contrôles : play/pause, scrub, volume, vitesse (0.5x, 0.75x, 1x,
//     1.25x, 1.5x, 2x), saut de 10s en avant/arrière
//   - Bookmark de position dans localStorage (reprise auto)
//   - Filigrane optionnel (email/timestamp répété)
//   - i18n complète, conventions militantes 6 locales
//   - Accessibilité : labels ARIA, focus-visible, contrastes
//
// Limites connues (cf. notes anti-DRM):
//   - Le décourageant ne remplace pas un DRM. Les utilisateur·rices
//     déterminé·es peuvent toujours capturer l'audio (enregistreur
//     d'écran, hook WebAudio API, etc.). Le filigrane attribue, le
//     blob complique, mais rien ne protège absolument.
//
// Props :
//   src        : string — l'URL de l'audio (blob: ou https:)
//   fileName   : string — étiquette affichée
//   onError    : (msg) => void — callback d'erreur
//   watermark  : string — texte du filigrane (optionnel, ex: email)
//   bookmarkKey : string — clé localStorage pour la position (optionnel)

import { useEffect, useRef, useState, useCallback } from 'react';
import { useIntl } from 'react-intl';
import './AudioPlayer.css';

const PLAYBACK_RATES = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
const SKIP_SECONDS = 10;
const BOOKMARK_DEBOUNCE_MS = 2000;

function formatTime(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) return '0:00';
  const total = Math.floor(seconds);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

export default function AudioPlayer({ src, fileName, onError, watermark, bookmarkKey }) {
  const { formatMessage: t } = useIntl();
  const audioRef = useRef(null);
  const playerRef = useRef(null);  // conteneur pour le scope anti-copie
  const blobUrlRef = useRef(null);
  const bookmarkTimerRef = useRef(null);

  const [src_, setSrc] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [playing, setPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(1);
  const [muted, setMuted] = useState(false);
  const [playbackRate, setPlaybackRate] = useState(1);
  const [isFullscreen, setIsFullscreen] = useState(false);

  // ── Anti-copie : scope au player (clic droit + drag + save) ──

  useEffect(() => {
    function inPlayer(e) {
      const node = playerRef.current;
      return Boolean(node && e.target && node.contains(e.target));
    }
    function block(e) {
      if (!inPlayer(e)) return;
      e.preventDefault();
      e.stopPropagation();
    }
    function blockKeys(e) {
      if (!playerRef.current) return;
      const k = (e.key || '').toLowerCase();
      if (
        (e.ctrlKey && !e.shiftKey && ['s'].includes(k)) ||  // Ctrl+S
        (e.ctrlKey && e.shiftKey && ['i', 'j', 'c'].includes(k))  // Ctrl+Shift+I/J/C
      ) {
        e.preventDefault();
        e.stopPropagation();
      }
    }
    document.addEventListener('contextmenu', block, true);
    document.addEventListener('dragstart', block, true);
    document.addEventListener('keydown', blockKeys, true);
    return () => {
      document.removeEventListener('contextmenu', block, true);
      document.removeEventListener('dragstart', block, true);
      document.removeEventListener('keydown', blockKeys, true);
    };
  }, []);

  // ── Chargement en blob ─────────────────────────────────────

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError('');

    if (!src) { setError(t({ id: 'audio.error.noSource' })); setLoading(false); return; }

    // Si src est déjà un blob: on l'utilise tel quel ; sinon on fetch
    if (src.startsWith('blob:')) {
      setSrc(src);
      setLoading(false);
      return;
    }

    (async () => {
      try {
        const res = await fetch(src);
        if (!res.ok) throw new Error(`${res.status}`);
        const blob = await res.blob();
        if (cancelled) return;
        const blobUrl = URL.createObjectURL(blob);
        blobUrlRef.current = blobUrl;
        setSrc(blobUrl);
      } catch (err) {
        if (!cancelled) {
          const msg = t({ id: 'audio.error.loading' }, { error: err.message || String(err) });
          setError(msg);
          if (onError) onError(msg);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
      if (blobUrlRef.current) {
        URL.revokeObjectURL(blobUrlRef.current);
        blobUrlRef.current = null;
      }
    };
  }, [src, onError, t]);

  // ── Restauration du bookmark ───────────────────────────────

  useEffect(() => {
    if (!bookmarkKey || !audioRef.current) return;
    try {
      const stored = localStorage.getItem(`anarbib.audio.${bookmarkKey}`);
      if (stored) {
        const t = parseFloat(stored);
        if (Number.isFinite(t) && t > 0) {
          // On attendra l'event loadedmetadata pour appliquer
          const audio = audioRef.current;
          const onMeta = () => {
            audio.currentTime = Math.min(t, audio.duration || t);
            audio.removeEventListener('loadedmetadata', onMeta);
          };
          audio.addEventListener('loadedmetadata', onMeta);
        }
      }
    } catch {
      // ignore
    }
  }, [bookmarkKey, src_]);

  // ── Sauvegarde bookmark débouncée ──────────────────────────

  useEffect(() => {
    if (!bookmarkKey) return;
    if (bookmarkTimerRef.current) clearTimeout(bookmarkTimerRef.current);
    bookmarkTimerRef.current = setTimeout(() => {
      try {
        localStorage.setItem(`anarbib.audio.${bookmarkKey}`, String(currentTime));
      } catch {
        // ignore
      }
    }, BOOKMARK_DEBOUNCE_MS);
    return () => {
      if (bookmarkTimerRef.current) clearTimeout(bookmarkTimerRef.current);
    };
  }, [currentTime, bookmarkKey]);

  // ── Synchro <audio> ↔ état React ────────────────────────────

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    const onPlay = () => setPlaying(true);
    const onPause = () => setPlaying(false);
    const onTimeUpdate = () => setCurrentTime(audio.currentTime);
    const onDurationChange = () => setDuration(audio.duration || 0);
    const onVolumeChange = () => { setVolume(audio.volume); setMuted(audio.muted); };
    const onRateChange = () => setPlaybackRate(audio.playbackRate);
    const onEnded = () => setPlaying(false);
    const onError = () => {
      const msg = t({ id: 'audio.error.playback' });
      setError(msg);
      if (onError) onError(msg);
    };

    audio.addEventListener('play', onPlay);
    audio.addEventListener('pause', onPause);
    audio.addEventListener('timeupdate', onTimeUpdate);
    audio.addEventListener('durationchange', onDurationChange);
    audio.addEventListener('volumechange', onVolumeChange);
    audio.addEventListener('ratechange', onRateChange);
    audio.addEventListener('ended', onEnded);
    audio.addEventListener('error', onError);

    return () => {
      audio.removeEventListener('play', onPlay);
      audio.removeEventListener('pause', onPause);
      audio.removeEventListener('timeupdate', onTimeUpdate);
      audio.removeEventListener('durationchange', onDurationChange);
      audio.removeEventListener('volumechange', onVolumeChange);
      audio.removeEventListener('ratechange', onRateChange);
      audio.removeEventListener('ended', onEnded);
      audio.removeEventListener('error', onError);
    };
  }, [src_, t]);

  // ── Plein écran ────────────────────────────────────────────

  useEffect(() => {
    const onFsChange = () => setIsFullscreen(Boolean(document.fullscreenElement));
    document.addEventListener('fullscreenchange', onFsChange);
    return () => document.removeEventListener('fullscreenchange', onFsChange);
  }, []);

  const toggleFullscreen = useCallback(() => {
    const node = playerRef.current;
    if (!node) return;
    if (!document.fullscreenElement) {
      if (node.requestFullscreen) node.requestFullscreen();
    } else {
      if (document.exitFullscreen) document.exitFullscreen();
    }
  }, []);

  // ── Contrôles ──────────────────────────────────────────────

  const togglePlay = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    if (audio.paused) audio.play().catch(() => {});
    else audio.pause();
  }, []);

  const skip = useCallback((seconds) => {
    const audio = audioRef.current;
    if (!audio) return;
    audio.currentTime = Math.max(0, Math.min(audio.duration || 0, audio.currentTime + seconds));
  }, []);

  const onScrub = useCallback((e) => {
    const audio = audioRef.current;
    if (!audio) return;
    const value = parseFloat(e.target.value);
    if (Number.isFinite(value)) audio.currentTime = value;
  }, []);

  const onVolumeChange = useCallback((e) => {
    const audio = audioRef.current;
    if (!audio) return;
    const v = parseFloat(e.target.value);
    audio.volume = v;
    if (v > 0 && audio.muted) audio.muted = false;
  }, []);

  const toggleMute = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    audio.muted = !audio.muted;
  }, []);

  const cycleRate = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    const idx = PLAYBACK_RATES.indexOf(audio.playbackRate);
    const next = PLAYBACK_RATES[(idx + 1) % PLAYBACK_RATES.length];
    audio.playbackRate = next;
  }, []);

  // ── Rendu ──────────────────────────────────────────────────

  if (loading) {
    return (
      <div ref={playerRef} className="ab-audio-player ab-audio-player--loading">
        <p>{t({ id: 'audio.loading' })}</p>
      </div>
    );
  }

  if (error) {
    return (
      <div ref={playerRef} className="ab-audio-player ab-audio-player--error">
        <p>{error}</p>
      </div>
    );
  }

  return (
    <div
      ref={playerRef}
      className={`ab-audio-player ${isFullscreen ? 'ab-audio-player--fullscreen' : ''}`}
      tabIndex={0}
    >
      {/* Filigrane */}
      {watermark && (
        <div className="ab-audio-watermark" aria-hidden="true">
          {[...Array(4)].map((_, i) => <span key={i}>{watermark}</span>)}
        </div>
      )}

      {/* Audio caché — controlsList sert à enlever le bouton de download
          natif sur les navigateurs qui le supportent (Chrome, Edge). */}
      <audio
        ref={audioRef}
        src={src_}
        preload="metadata"
        controlsList="nodownload noplaybackrate"
        disablePictureInPicture
        onContextMenu={(e) => e.preventDefault()}
      />

      {/* Header : titre */}
      {fileName && (
        <div className="ab-audio-header">
          <span className="ab-audio-header__title">{fileName}</span>
        </div>
      )}

      {/* Barre de scrub */}
      <div className="ab-audio-scrub">
        <span className="ab-audio-time ab-audio-time--current">{formatTime(currentTime)}</span>
        <input
          type="range"
          className="ab-audio-scrub__bar"
          min={0}
          max={duration || 0}
          step={0.1}
          value={currentTime}
          onChange={onScrub}
          aria-label={t({ id: 'audio.scrub' })}
        />
        <span className="ab-audio-time ab-audio-time--total">{formatTime(duration)}</span>
      </div>

      {/* Contrôles principaux */}
      <div className="ab-audio-controls">
        <div className="ab-audio-controls__group">
          <button
            type="button"
            className="ab-audio-btn"
            onClick={() => skip(-SKIP_SECONDS)}
            aria-label={t({ id: 'audio.skipBack' }, { sec: SKIP_SECONDS })}
            title={t({ id: 'audio.skipBack' }, { sec: SKIP_SECONDS })}
          >
            ⏪ {SKIP_SECONDS}s
          </button>

          <button
            type="button"
            className="ab-audio-btn ab-audio-btn--play"
            onClick={togglePlay}
            aria-label={playing ? t({ id: 'audio.pause' }) : t({ id: 'audio.play' })}
            title={playing ? t({ id: 'audio.pause' }) : t({ id: 'audio.play' })}
          >
            {playing ? '⏸' : '▶'}
          </button>

          <button
            type="button"
            className="ab-audio-btn"
            onClick={() => skip(SKIP_SECONDS)}
            aria-label={t({ id: 'audio.skipForward' }, { sec: SKIP_SECONDS })}
            title={t({ id: 'audio.skipForward' }, { sec: SKIP_SECONDS })}
          >
            {SKIP_SECONDS}s ⏩
          </button>
        </div>

        <div className="ab-audio-controls__group">
          {/* Volume */}
          <button
            type="button"
            className="ab-audio-btn"
            onClick={toggleMute}
            aria-label={muted ? t({ id: 'audio.unmute' }) : t({ id: 'audio.mute' })}
            title={muted ? t({ id: 'audio.unmute' }) : t({ id: 'audio.mute' })}
          >
            {muted || volume === 0 ? '🔇' : volume < 0.5 ? '🔉' : '🔊'}
          </button>
          <input
            type="range"
            className="ab-audio-volume"
            min={0}
            max={1}
            step={0.05}
            value={muted ? 0 : volume}
            onChange={onVolumeChange}
            aria-label={t({ id: 'audio.volume' })}
          />

          {/* Vitesse */}
          <button
            type="button"
            className="ab-audio-btn ab-audio-btn--rate"
            onClick={cycleRate}
            aria-label={t({ id: 'audio.speed' }, { rate: playbackRate })}
            title={t({ id: 'audio.speed' }, { rate: playbackRate })}
          >
            {playbackRate}×
          </button>

          {/* Fullscreen */}
          <button
            type="button"
            className="ab-audio-btn"
            onClick={toggleFullscreen}
            aria-label={t({ id: isFullscreen ? 'audio.fullscreenExit' : 'audio.fullscreen' })}
            title={t({ id: isFullscreen ? 'audio.fullscreenExit' : 'audio.fullscreen' })}
          >
            {isFullscreen ? '⤡' : '⤢'}
          </button>
        </div>
      </div>

      {/* Notice */}
      <p className="ab-audio-notice">
        {t({ id: 'audio.notice' })}
      </p>
    </div>
  );
}
