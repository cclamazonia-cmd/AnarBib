import { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { useIntl } from 'react-intl';
import './PanelOnboarding.css';

// ═══════════════════════════════════════════════════════════════════════════
// PanelOnboarding — prise en main du Painel (ONBO-Q4)
//
// Deux briques de la doctrine d'onboarding :
//   1. Coach-marks (visite guidée) : un spotlight assombrit la page et découpe
//      le vrai onglet ciblé ; une carte « coach » explique l'onglet. Ancré aux
//      VRAIS onglets via [data-painel-tab="<key>"] (≠ maquette : prod a fusionné
//      emprestimos-livro/-lote en 'emprestimos', refactor E.3).
//   2. Check-list de premières actions + canal humain.
//
// Piloté par le profil (circulation_mode) et la disponibilité réelle des
// onglets (availability). Aucune configuration : c'est de la prise en main.
//
// Persistance (deux niveaux, pas de migration) :
//   • opt-out PERMANENT (localStorage) : posé UNIQUEMENT quand la personne coche
//     « ne plus afficher ». Tant qu'il n'est pas posé, la visite se rejoue à
//     CHAQUE nouvelle connexion.
//   • « déjà vu cette session » (sessionStorage) : évite que la visite se
//     relance à chaque navigation/re-montage au sein d'une même connexion. Une
//     nouvelle connexion (nouvelle session navigateur) la fait réapparaître.
// Rejouable à la demande via « Refaire la visite » (ignore les deux niveaux).
// ═══════════════════════════════════════════════════════════════════════════

const OPTOUT_KEY_PREFIX = 'painel_onboarding_optout:';     // localStorage (permanent)
const SESSION_KEY_PREFIX = 'painel_onboarding_shown:';     // sessionStorage (par connexion)
const HOLE_PAD = 6;

// Adresses réseau (constantes, non traduites).
const NET_EMAIL = 'anarbib@proton.me';
const NET_MATRIX_URL = 'https://matrix.to/#/!RfxYttorZNdTIZXIRJ:matrix.org?via=matrix.org';
const NET_MATRIX_LABEL = 'Projeto AnarBib';

// Étapes de la visite, ancrées à des onglets (vrais clés prod). Filtrées par
// la disponibilité réelle des onglets (un onglet masqué = étape sautée).
const TOUR_STEPS = [
  { tab: 'trabalho-do-dia', titleKey: 'panel.onboarding.tour.dailyWork.title', textKey: 'panel.onboarding.tour.dailyWork.text' },
  { tab: 'acoes', titleKey: 'panel.onboarding.tour.actions.title', textKey: 'panel.onboarding.tour.actions.text' },
  { tab: 'emprestimos', titleKey: 'panel.onboarding.tour.loans.title', textKey: 'panel.onboarding.tour.loans.text' },
  { tab: 'reservas', titleKey: 'panel.onboarding.tour.reservations.title', textKey: 'panel.onboarding.tour.reservations.text' },
  { tab: 'leitor', titleKey: 'panel.onboarding.tour.reader.title', textKey: 'panel.onboarding.tour.reader.text' },
  { tab: 'historico', titleKey: 'panel.onboarding.tour.history.title', textKey: 'panel.onboarding.tour.history.text' },
];

// Premières actions, profil-aware. `where` = clé i18n d'un onglet existant.
const FIRST_STEPS = [
  { id: 'reader', need: () => true, labelKey: 'panel.onboarding.step.reader.label', subKey: 'panel.onboarding.step.reader.sub', whereKey: 'panel.tab.reader' },
  { id: 'loan', need: cm => cm !== 'off', labelKey: 'panel.onboarding.step.loan.label', subKey: 'panel.onboarding.step.loan.sub', whereKey: 'panel.tab.actions' },
  { id: 'return', need: cm => cm !== 'off', labelKey: 'panel.onboarding.step.return.label', subKey: 'panel.onboarding.step.return.sub', whereKey: 'panel.tab.actions' },
  { id: 'reservation', need: cm => cm === 'full_sigb', labelKey: 'panel.onboarding.step.reservation.label', subKey: 'panel.onboarding.step.reservation.sub', whereKey: 'panel.tab.reservations' },
  { id: 'day', need: () => true, labelKey: 'panel.onboarding.step.day.label', subKey: 'panel.onboarding.step.day.sub', whereKey: 'panel.tab.dailyWork' },
];

function isOptedOut(libraryId) {
  if (!libraryId) return false;
  try { return localStorage.getItem(OPTOUT_KEY_PREFIX + libraryId) === '1'; } catch { return false; }
}
function isSessionShown(libraryId) {
  if (!libraryId) return false;
  try { return sessionStorage.getItem(SESSION_KEY_PREFIX + libraryId) === '1'; } catch { return false; }
}
// La visite s'auto-lance si la personne n'a pas opté-out (permanent) ET ne l'a
// pas déjà vue dans cette session navigateur (évite le re-déclenchement à
// chaque navigation). Une nouvelle connexion la fait réapparaître.
export function shouldShowPanelOnboarding(libraryId) {
  if (!libraryId) return false;
  return !isOptedOut(libraryId) && !isSessionShown(libraryId);
}

export default function PanelOnboarding({ availability, circulationMode, libraryId, onNavigate }) {
  const { formatMessage: t } = useIntl();
  const cm = circulationMode || 'full_sigb';

  // Zone d'accueil (check-list + canal humain) : visible tant que la personne
  // n'a pas opté-out de façon permanente (« Concluir e ocultar »).
  const [zoneOpen, setZoneOpen] = useState(() => !isOptedOut(libraryId));
  // Cases cochées (mémoire de session seulement — pas un examen)
  const [doneSteps, setDoneSteps] = useState({});

  // ── État de la visite guidée ──────────────────────────────────────────
  const [tourActive, setTourActive] = useState(false);
  const [ti, setTi] = useState(0);
  const [hole, setHole] = useState(null);           // {top,left,width,height}
  const [coachPos, setCoachPos] = useState(null);   // {top,left}
  const coachRef = useRef(null);

  // Étapes de visite réellement applicables (onglet visible).
  const tour = useMemo(
    () => TOUR_STEPS.filter(s => availability?.[s.tab] !== false),
    [availability]
  );
  // Check-list applicable au profil.
  const steps = useMemo(() => FIRST_STEPS.filter(s => s.need(cm)), [cm]);
  const doneCount = steps.filter(s => doneSteps[s.id]).length;

  // Marque « déjà vu cette session » (sessionStorage) — empêche le re-déclenchement
  // automatique au sein de la même connexion.
  const markSessionShown = useCallback(() => {
    if (!libraryId) return;
    try { sessionStorage.setItem(SESSION_KEY_PREFIX + libraryId, '1'); } catch { /* ignore */ }
  }, [libraryId]);
  // Opt-out PERMANENT (localStorage) — posé uniquement sur action explicite.
  const persistOptout = useCallback(() => {
    if (!libraryId) return;
    try { localStorage.setItem(OPTOUT_KEY_PREFIX + libraryId, '1'); } catch { /* ignore */ }
  }, [libraryId]);

  // ── Positionnement du spotlight + de la carte coach ───────────────────
  const reposition = useCallback(() => {
    const step = tour[ti];
    if (!step) return;
    const el = document.querySelector(`[data-painel-tab="${step.tab}"]`);
    if (!el) { setHole(null); return; }
    const r = el.getBoundingClientRect();
    setHole({ top: r.top - HOLE_PAD, left: r.left - HOLE_PAD, width: r.width + HOLE_PAD * 2, height: r.height + HOLE_PAD * 2 });

    const cw = coachRef.current?.offsetWidth || 330;
    const ch = coachRef.current?.offsetHeight || 190;
    let top = r.bottom + HOLE_PAD + 14;
    let left = r.left - HOLE_PAD;
    if (left + cw > window.innerWidth - 16) left = window.innerWidth - cw - 16;
    if (left < 16) left = 16;
    if (top + ch > window.innerHeight - 16) top = Math.max(16, r.top - HOLE_PAD - ch - 14);
    setCoachPos({ top, left });
  }, [tour, ti]);

  const startTour = useCallback(() => {
    setZoneOpen(true);
    setTi(0);
    setTourActive(true);
    markSessionShown();
  }, [markSessionShown]);

  const endTour = useCallback(() => {
    setTourActive(false);
    setHole(null);
    markSessionShown();
  }, [markSessionShown]);

  // Quand la visite devient active ou change d'étape : naviguer vers l'onglet
  // ciblé (contexte visuel) puis repositionner après le rendu.
  useEffect(() => {
    if (!tourActive) return;
    const step = tour[ti];
    if (step && onNavigate) onNavigate(step.tab);
    // double rAF : laisser le DOM (onglet actif, lazy tab) se peindre.
    const id = requestAnimationFrame(() => requestAnimationFrame(reposition));
    return () => cancelAnimationFrame(id);
  }, [tourActive, ti, tour, onNavigate, reposition]);

  // Reposition sur resize/scroll pendant la visite + blocage du scroll de page.
  useEffect(() => {
    if (!tourActive) return;
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    const onMove = () => reposition();
    window.addEventListener('resize', onMove);
    window.addEventListener('scroll', onMove, true);
    return () => {
      document.body.style.overflow = prevOverflow;
      window.removeEventListener('resize', onMove);
      window.removeEventListener('scroll', onMove, true);
    };
  }, [tourActive, reposition]);

  // Démarrage auto (1ʳᵉ fois de la session, sauf opt-out permanent).
  useEffect(() => {
    if (!shouldShowPanelOnboarding(libraryId)) return;
    markSessionShown();
    const id = setTimeout(() => setTourActive(true), 480);
    return () => clearTimeout(id);
  }, [libraryId, markSessionShown]);

  // Raccourcis clavier pendant la visite.
  useEffect(() => {
    if (!tourActive) return;
    const onKey = (e) => {
      if (e.key === 'Escape') endTour();
      else if (e.key === 'ArrowRight') setTi(i => Math.min(i + 1, tour.length - 1));
      else if (e.key === 'ArrowLeft') setTi(i => Math.max(i - 1, 0));
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [tourActive, tour.length, endTour]);

  const next = useCallback(() => {
    if (ti < tour.length - 1) setTi(ti + 1);
    else endTour();
  }, [ti, tour.length, endTour]);

  // « Concluir e ocultar » = opt-out permanent (ne réapparaît plus aux connexions
  // suivantes, sauf « Refazer a visita »).
  const dismissZone = useCallback(() => {
    setZoneOpen(false);
    persistOptout();
  }, [persistOptout]);

  const replay = useCallback(() => {
    setDoneSteps({});
    startTour();
  }, [startTour]);

  if (!libraryId) return null;

  const showZone = zoneOpen;
  const currentStep = tour[ti];

  return (
    <div className="ab-pon">
      {/* ── Zone d'accueil : check-list + canal humain ── */}
      {showZone ? (
        <div className="ab-pon-zone">
          <section className="ab-pon-firststeps">
            <div className="ab-pon-fh">
              <h2>{t({ id: 'panel.onboarding.steps.title' })}</h2>
              <div className="ab-pon-miniring">{t({ id: 'panel.onboarding.steps.progress' }, { done: doneCount, total: steps.length })}</div>
            </div>
            <p className="ab-pon-fp">{t({ id: 'panel.onboarding.steps.subtitle' })}</p>

            {steps.map(s => {
              const isDone = !!doneSteps[s.id];
              return (
                <div key={s.id} className={`ab-pon-step${isDone ? ' is-done' : ''}`}>
                  <button
                    type="button"
                    className="ab-pon-tick"
                    aria-pressed={isDone}
                    aria-label={t({ id: s.labelKey })}
                    onClick={() => setDoneSteps(d => ({ ...d, [s.id]: !d[s.id] }))}
                  >✓</button>
                  <div className="ab-pon-si">
                    <b>{t({ id: s.labelKey })}</b>
                    <span>{t({ id: s.subKey })}</span>
                  </div>
                  <span className="ab-pon-where">{t({ id: s.whereKey })}</span>
                </div>
              );
            })}

            <div className="ab-pon-firststeps-foot">
              <button type="button" className="ab-pon-btn is-staff" onClick={replay}>
                ↻ {t({ id: 'panel.onboarding.replay' })}
              </button>
              <button type="button" className="ab-pon-btn is-ghost" onClick={dismissZone}>
                {t({ id: 'panel.onboarding.steps.dismiss' })}
              </button>
            </div>
          </section>

          <section className="ab-pon-human">
            <div className="ab-pon-ht">
              <div className="ab-pon-tag">{t({ id: 'panel.onboarding.human.tag' })}</div>
              <h3>{t({ id: 'panel.onboarding.human.title' })}</h3>
              <p>{t({ id: 'panel.onboarding.human.text' })}</p>
            </div>
            <div className="ab-pon-links">
              <a href={`mailto:${NET_EMAIL}`}>✉ {NET_EMAIL}</a>
              <a href={NET_MATRIX_URL} target="_blank" rel="noreferrer">⌗ {NET_MATRIX_LABEL}</a>
            </div>
          </section>
        </div>
      ) : (
        <div className="ab-pon-replaybar">
          <button type="button" className="ab-pon-btn is-ghost" onClick={replay}>
            ↻ {t({ id: 'panel.onboarding.replay' })}
          </button>
        </div>
      )}

      {/* ── Spotlight (visite guidée) ── */}
      {tourActive && currentStep && (
        <>
          <div className="ab-pon-spot is-on" onClick={endTour} />
          {hole && (
            <div
              className="ab-pon-hole is-on"
              style={{ top: hole.top, left: hole.left, width: hole.width, height: hole.height }}
            />
          )}
          <div
            ref={coachRef}
            className="ab-pon-coach"
            role="dialog"
            aria-modal="true"
            style={coachPos ? { top: coachPos.top, left: coachPos.left } : { top: 140, left: '50%', transform: 'translateX(-50%)' }}
          >
            <div className="ab-pon-cstep">
              {t({ id: 'panel.onboarding.tour.stepCounter' }, { current: ti + 1, total: tour.length })}
            </div>
            <h4>{t({ id: currentStep.titleKey })}</h4>
            <p>{t({ id: currentStep.textKey })}</p>
            <div className="ab-pon-nav">
              <div className="ab-pon-dots">
                {tour.map((_, i) => <div key={i} className={`ab-pon-dot${i === ti ? ' is-on' : ''}`} />)}
              </div>
              <button type="button" className="ab-pon-btn is-ghost" onClick={endTour}>
                {t({ id: 'panel.onboarding.tour.skip' })}
              </button>
              {ti > 0 && (
                <button type="button" className="ab-pon-btn" onClick={() => setTi(ti - 1)}>
                  {t({ id: 'panel.onboarding.tour.prev' })}
                </button>
              )}
              <button type="button" className="ab-pon-btn is-staff" onClick={next}>
                {ti === tour.length - 1 ? t({ id: 'panel.onboarding.tour.finish' }) : t({ id: 'panel.onboarding.tour.next' })}
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
