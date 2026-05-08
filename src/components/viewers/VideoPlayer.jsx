// ═══════════════════════════════════════════════════════════
// VideoPlayer — lecteur vidéo AnarBib
// ═══════════════════════════════════════════════════════════
//
// Composant standalone pour lire des assets vidéo (MP4, WebM, etc.)
// avec un niveau de qualité comparable à PdfViewer et AudioPlayer.
//
// Particularités vidéo (par rapport à AudioPlayer) :
//   - Affichage du flux vidéo
//   - Sous-titres .vtt (multiples pistes possibles, sélection langue)
//   - Plein écran natif sur l'élément vidéo (mode kiosque)
//   - Filigrane SUPERPOSÉ sur l'image (et non décoratif comme l'audio :
//     c'est l'image qui peut fuir par capture d'écran, donc le filigrane
//     doit être visible et identifiant)
//
// Props :
//   src        : string — URL de la vidéo (blob: ou https:)
//   fileName   : string — étiquette affichée
//   onError    : (msg) => void
//   watermark  : string — texte filigrane sur l'image (optionnel)
//   bookmarkKey : string — clé localStorage pour reprise auto (optionnel)
//   tracks     : [{ src, srcLang, label, kind, default }] — sous-titres
//                (optionnel ; pour l'instant tracks reste un tableau vide
//                puisque la base ne stocke pas encore les .vtt — c'est
//                une porte ouverte pour le futur)

import { useEffect, useRef, useState, useCallback } from 'react';
import { useIntl } from 'react-intl';
import './VideoPlayer.css';

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

export default function VideoPlayer({ src, fileName, onError, watermark, bookmarkKey, tracks = [] }) {
  const { formatMessage: t } = useIntl();
  const videoRef = useRef(null);
  const playerRef = useRef(null);
  const blobUrlRef = useRef(null);
  const bookmarkTimerRef = useRef(null);
  const controlsHideTimerRef = useRef(null);

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
  const [controlsVisible, setControlsVisible] = useState(true);
  const [activeTrackIndex, setActiveTrackIndex] = useState(-1);  // -1 = pas de sous-titres

  // ── Anti-copie : scope au player ──────────────────────────

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
        (e.ctrlKey && !e.shiftKey && ['s'].includes(k)) ||
        (e.ctrlKey && e.shiftKey && ['i', 'j', 'c'].includes(k))
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

    if (!src) { setError(t({ id: 'video.error.noSource' })); setLoading(false); return; }

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
          const msg = t({ id: 'video.error.loading' }, { error: err.message || String(err) });
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

  // ── Restauration bookmark ─────────────────────────────────

  useEffect(() => {
    if (!bookmarkKey || !videoRef.current) return;
    try {
      const stored = localStorage.getItem(`anarbib.video.${bookmarkKey}`);
      if (stored) {
        const t = parseFloat(stored);
        if (Number.isFinite(t) && t > 0) {
          const video = videoRef.current;
          const onMeta = () => {
            video.currentTime = Math.min(t, video.duration || t);
            video.removeEventListener('loadedmetadata', onMeta);
          };
          video.addEventListener('loadedmetadata', onMeta);
        }
      }
    } catch {
      // ignore
    }
  }, [bookmarkKey, src_]);

  // ── Sauvegarde bookmark débouncée ─────────────────────────

  useEffect(() => {
    if (!bookmarkKey) return;
    if (bookmarkTimerRef.current) clearTimeout(bookmarkTimerRef.current);
    bookmarkTimerRef.current = setTimeout(() => {
      try {
        localStorage.setItem(`anarbib.video.${bookmarkKey}`, String(currentTime));
      } catch {
        // ignore
      }
    }, BOOKMARK_DEBOUNCE_MS);
    return () => {
      if (bookmarkTimerRef.current) clearTimeout(bookmarkTimerRef.current);
    };
  }, [currentTime, bookmarkKey]);

  // ── Synchro <video> ↔ état React ───────────────────────────

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    const onPlay = () => setPlaying(true);
    const onPause = () => setPlaying(false);
    const onTimeUpdate = () => setCurrentTime(video.currentTime);
    const onDurationChange = () => setDuration(video.duration || 0);
    const onVolumeChange = () => { setVolume(video.volume); setMuted(video.muted); };
    const onRateChange = () => setPlaybackRate(video.playbackRate);
    const onEnded = () => setPlaying(false);
    const onErr = () => {
      const msg = t({ id: 'video.error.playback' });
      setError(msg);
      if (onError) onError(msg);
    };

    video.addEventListener('play', onPlay);
    video.addEventListener('pause', onPause);
    video.addEventListener('timeupdate', onTimeUpdate);
    video.addEventListener('durationchange', onDurationChange);
    video.addEventListener('volumechange', onVolumeChange);
    video.addEventListener('ratechange', onRateChange);
    video.addEventListener('ended', onEnded);
    video.addEventListener('error', onErr);

    return () => {
      video.removeEventListener('play', onPlay);
      video.removeEventListener('pause', onPause);
      video.removeEventListener('timeupdate', onTimeUpdate);
      video.removeEventListener('durationchange', onDurationChange);
      video.removeEventListener('volumechange', onVolumeChange);
      video.removeEventListener('ratechange', onRateChange);
      video.removeEventListener('ended', onEnded);
      video.removeEventListener('error', onErr);
    };
  }, [src_, t, onError]);

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

  // ── Auto-hide des contrôles en plein écran ─────────────────

  const showControlsTemporarily = useCallback(() => {
    setControlsVisible(true);
    if (controlsHideTimerRef.current) clearTimeout(controlsHideTimerRef.current);
    if (isFullscreen && playing) {
      controlsHideTimerRef.current = setTimeout(() => {
        setControlsVisible(false);
      }, 2500);
    }
  }, [isFullscreen, playing]);

  useEffect(() => {
    if (!isFullscreen) {
      setControlsVisible(true);
      if (controlsHideTimerRef.current) clearTimeout(controlsHideTimerRef.current);
      return;
    }
    showControlsTemporarily();
  }, [isFullscreen, playing, showControlsTemporarily]);

  // ── Sous-titres ────────────────────────────────────────────
  //
  // Active une piste de sous-titres (par index dans la prop `tracks`)
  // ou désactive toutes les pistes si index = -1.

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !video.textTracks) return;
    const list = video.textTracks;
    for (let i = 0; i < list.length; i++) {
      list[i].mode = (i === activeTrackIndex) ? 'showing' : 'disabled';
    }
  }, [activeTrackIndex, tracks, src_]);

  // ── Contrôles ──────────────────────────────────────────────

  const togglePlay = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    if (video.paused) video.play().catch(() => {});
    else video.pause();
  }, []);

  const skip = useCallback((seconds) => {
    const video = videoRef.current;
    if (!video) return;
    video.currentTime = Math.max(0, Math.min(video.duration || 0, video.currentTime + seconds));
  }, []);

  const onScrub = useCallback((e) => {
    const video = videoRef.current;
    if (!video) return;
    const value = parseFloat(e.target.value);
    if (Number.isFinite(value)) video.currentTime = value;
  }, []);

  const onVolumeChange = useCallback((e) => {
    const video = videoRef.current;
    if (!video) return;
    const v = parseFloat(e.target.value);
    video.volume = v;
    if (v > 0 && video.muted) video.muted = false;
  }, []);

  const toggleMute = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    video.muted = !video.muted;
  }, []);

  const cycleRate = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    const idx = PLAYBACK_RATES.indexOf(video.playbackRate);
    const next = PLAYBACK_RATES[(idx + 1) % PLAYBACK_RATES.length];
    video.playbackRate = next;
  }, []);

  const cycleSubtitles = useCallback(() => {
    if (!tracks || tracks.length === 0) return;
    setActiveTrackIndex((idx) => {
      // Cycle : -1 (off) → 0 → 1 → ... → tracks.length-1 → -1
      if (idx >= tracks.length - 1) return -1;
      return idx + 1;
    });
  }, [tracks]);

  const subtitleLabel = activeTrackIndex >= 0 && tracks[activeTrackIndex]
    ? tracks[activeTrackIndex].label || tracks[activeTrackIndex].srcLang || `#${activeTrackIndex + 1}`
    : t({ id: 'video.subtitlesOff' });

  // ── Rendu ──────────────────────────────────────────────────

  if (loading) {
    return (
      <div ref={playerRef} className="ab-video-player ab-video-player--loading">
        <p>{t({ id: 'video.loading' })}</p>
      </div>
    );
  }

  if (error) {
    return (
      <div ref={playerRef} className="ab-video-player ab-video-player--error">
        <p>{error}</p>
      </div>
    );
  }

  return (
    <div
      ref={playerRef}
      className={`ab-video-player ${isFullscreen ? 'ab-video-player--fullscreen' : ''} ${controlsVisible ? '' : 'ab-video-player--controls-hidden'}`}
      onMouseMove={showControlsTemporarily}
      tabIndex={0}
    >
      {/* Stage : vidéo + filigrane par-dessus */}
      <div className="ab-video-stage" onClick={togglePlay}>
        <video
          ref={videoRef}
          src={src_}
          preload="metadata"
          controlsList="nodownload noplaybackrate"
          disablePictureInPicture
          onContextMenu={(e) => e.preventDefault()}
          className="ab-video-element"
          playsInline
        >
          {tracks.map((trk, i) => (
            <track
              key={i}
              src={trk.src}
              srcLang={trk.srcLang}
              label={trk.label}
              kind={trk.kind || 'subtitles'}
              default={trk.default}
            />
          ))}
        </video>

        {/* Filigrane par-dessus l'image (le but est qu'il soit capturé
            avec n'importe quelle capture d'écran). */}
        {watermark && (
          <div className="ab-video-watermark" aria-hidden="true">
            {[...Array(6)].map((_, i) => <span key={i}>{watermark}</span>)}
          </div>
        )}

        {/* Indicateur play/pause central pour feedback visuel */}
        {!playing && (
          <div className="ab-video-play-overlay" aria-hidden="true">
            <span className="ab-video-play-overlay__icon">▶</span>
          </div>
        )}
      </div>

      {/* Header */}
      {fileName && !isFullscreen && (
        <div className="ab-video-header">
          <span className="ab-video-header__title">{fileName}</span>
        </div>
      )}

      {/* Scrub */}
      <div className="ab-video-scrub">
        <span className="ab-video-time ab-video-time--current">{formatTime(currentTime)}</span>
        <input
          type="range"
          className="ab-video-scrub__bar"
          min={0}
          max={duration || 0}
          step={0.1}
          value={currentTime}
          onChange={onScrub}
          aria-label={t({ id: 'video.scrub' })}
        />
        <span className="ab-video-time ab-video-time--total">{formatTime(duration)}</span>
      </div>

      {/* Contrôles */}
      <div className="ab-video-controls">
        <div className="ab-video-controls__group">
          <button
            type="button"
            className="ab-video-btn"
            onClick={() => skip(-SKIP_SECONDS)}
            aria-label={t({ id: 'video.skipBack' }, { sec: SKIP_SECONDS })}
            title={t({ id: 'video.skipBack' }, { sec: SKIP_SECONDS })}
          >
            ⏪ {SKIP_SECONDS}s
          </button>

          <button
            type="button"
            className="ab-video-btn ab-video-btn--play"
            onClick={togglePlay}
            aria-label={playing ? t({ id: 'video.pause' }) : t({ id: 'video.play' })}
            title={playing ? t({ id: 'video.pause' }) : t({ id: 'video.play' })}
          >
            {playing ? '⏸' : '▶'}
          </button>

          <button
            type="button"
            className="ab-video-btn"
            onClick={() => skip(SKIP_SECONDS)}
            aria-label={t({ id: 'video.skipForward' }, { sec: SKIP_SECONDS })}
            title={t({ id: 'video.skipForward' }, { sec: SKIP_SECONDS })}
          >
            {SKIP_SECONDS}s ⏩
          </button>
        </div>

        <div className="ab-video-controls__group">
          <button
            type="button"
            className="ab-video-btn"
            onClick={toggleMute}
            aria-label={muted ? t({ id: 'video.unmute' }) : t({ id: 'video.mute' })}
            title={muted ? t({ id: 'video.unmute' }) : t({ id: 'video.mute' })}
          >
            {muted || volume === 0 ? '🔇' : volume < 0.5 ? '🔉' : '🔊'}
          </button>
          <input
            type="range"
            className="ab-video-volume"
            min={0}
            max={1}
            step={0.05}
            value={muted ? 0 : volume}
            onChange={onVolumeChange}
            aria-label={t({ id: 'video.volume' })}
          />

          <button
            type="button"
            className="ab-video-btn ab-video-btn--rate"
            onClick={cycleRate}
            aria-label={t({ id: 'video.speed' }, { rate: playbackRate })}
            title={t({ id: 'video.speed' }, { rate: playbackRate })}
          >
            {playbackRate}×
          </button>

          {tracks && tracks.length > 0 && (
            <button
              type="button"
              className={`ab-video-btn ab-video-btn--cc ${activeTrackIndex >= 0 ? 'ab-video-btn--cc-active' : ''}`}
              onClick={cycleSubtitles}
              aria-label={t({ id: 'video.subtitles' }, { label: subtitleLabel })}
              title={t({ id: 'video.subtitles' }, { label: subtitleLabel })}
            >
              CC
            </button>
          )}

          <button
            type="button"
            className="ab-video-btn"
            onClick={toggleFullscreen}
            aria-label={t({ id: isFullscreen ? 'video.fullscreenExit' : 'video.fullscreen' })}
            title={t({ id: isFullscreen ? 'video.fullscreenExit' : 'video.fullscreen' })}
          >
            {isFullscreen ? '⤡' : '⤢'}
          </button>
        </div>
      </div>

      {/* Notice */}
      {!isFullscreen && (
        <p className="ab-video-notice">
          {t({ id: 'video.notice' })}
        </p>
      )}
    </div>
  );
}
