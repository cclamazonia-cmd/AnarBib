import { useCallback, useEffect, useRef, useState } from 'react';
import { useIntl } from 'react-intl';
import {
  DEFAULT_PREFS,
  TEXT_SCALES,
  applyPrefs,
  readPrefs,
  writePrefs,
} from '@/lib/a11y';
import './AccessibilityWidget.css';

/* ════════════════════════════════════════════════════════════════════════
   AnarBib — AccessibilityWidget
   Bouton flottant + panneau de réglages d'accessibilité.

   Monté UNE SEULE FOIS dans App.jsx, à côté de <Routes> et de ScrollButtons
   (même registre : position fixe, il flotte au-dessus de n'importe quelle
   page sans avoir à toucher chaque page individuellement). Aucune route
   n'est exclue — un réglage d'accessibilité qui disparaît sur la liseuse
   serait absent précisément là où on lit.

   Répartition des rôles :
   - lib/a11y.js  : modèle, stockage, application au DOM (hors React) ;
   - ce fichier   : l'interface qui pilote ce modèle ;
   - le CSS       : tous les effets, déclenchés par les attributs data-a11y-*.

   Le panneau n'est PAS une modale : il ne piège pas le focus et ne bloque pas
   la page. C'est délibéré — on veut pouvoir grossir le texte tout en lisant
   ce qu'il y a derrière, et vérifier l'effet du réglage en direct.
   ════════════════════════════════════════════════════════════════════════ */

// ── Icône d'accès universel ─────────────────────────────────────────────
// La figure aux bras écartés dans un cercle, PAS le pictogramme au fauteuil
// roulant. Trois raisons, dans cet ordre d'importance :
//
// 1. Le fauteuil serait faux ici. Les huit réglages de ce panneau servent la
//    basse vision, la dyslexie, le daltonisme, les troubles vestibulaires et
//    la navigation au clavier ; aucun n'aide quelqu'un DU FAIT qu'il utilise
//    un fauteuil. L'icône dirait donc à tous les autres publics — c'est-à-dire
//    à tout le public réel de ce panneau — que ce bouton n'est pas pour eux.
// 2. C'est la critique que portent les luttes handi contre ce pictogramme :
//    il ramène le handicap au fauteuil et efface ce qui ne se voit pas.
// 3. `♿` (U+267F) est à présentation emoji par défaut : Windows le rend en
//    pastille bleue en couleur, quel que soit le `color` du CSS. Un tracé SVG
//    en `currentColor` prend la couleur de marque et rend pareil partout.
//
// La figure d'accès universel est elle-même une convention répandue (Apple,
// Android, GNOME) : on ne perd donc pas la reconnaissance immédiate.
function AccessIcon({ size }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      aria-hidden="true"
      focusable="false"
    >
      <circle cx="12" cy="12" r="10.4" fill="none" stroke="currentColor" strokeWidth="1.5" />
      <circle cx="12" cy="6.6" r="1.75" fill="currentColor" />
      <path
        d="M4.9 10.1h14.2M12 9.7v3.7l-3.3 6.1M12 13.4l3.3 6.1"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

// ── Une bascule du panneau ──────────────────────────────────────────────
// `aria-pressed` (et non une case à cocher) : c'est un bouton qui reste
// enfoncé, ce que les lecteurs d'écran annoncent « activé / désactivé ».
// L'état est aussi porté VISUELLEMENT par une pastille cochée, pas seulement
// par la couleur — un réglage d'accessibilité qui ne se lit qu'à la couleur
// serait une contradiction dans les termes (WCAG 1.4.1).
function Toggle({ icon, label, pressed, onToggle }) {
  return (
    <button
      type="button"
      className="ab-a11y-toggle"
      aria-pressed={pressed}
      onClick={onToggle}
    >
      <span className="ab-a11y-toggle__icon" aria-hidden="true">{icon}</span>
      <span className="ab-a11y-toggle__label">{label}</span>
      <span className="ab-a11y-toggle__mark" aria-hidden="true" />
    </button>
  );
}

export default function AccessibilityWidget() {
  const intl = useIntl();
  const { formatMessage: t } = intl;

  const [open, setOpen] = useState(false);
  // Les préférences ont déjà été appliquées au DOM par main.jsx avant le
  // rendu ; on se contente ici de les relire pour peupler l'interface.
  const [prefs, setPrefs] = useState(readPrefs);

  const panelRef = useRef(null);
  const buttonRef = useRef(null);

  // Toute modification suit le même chemin : état React, DOM, stockage.
  const toggle = useCallback((key) => {
    setPrefs((current) => {
      const next = { ...current, [key]: !current[key] };
      applyPrefs(next);
      writePrefs(next);
      return next;
    });
  }, []);

  const stepTextScale = useCallback((direction) => {
    setPrefs((current) => {
      const index = TEXT_SCALES.indexOf(current.textScale);
      const nextIndex = Math.min(
        TEXT_SCALES.length - 1,
        Math.max(0, (index === -1 ? TEXT_SCALES.indexOf(100) : index) + direction),
      );
      const next = { ...current, textScale: TEXT_SCALES[nextIndex] };
      applyPrefs(next);
      writePrefs(next);
      return next;
    });
  }, []);

  const reset = useCallback(() => {
    applyPrefs(DEFAULT_PREFS);
    writePrefs(DEFAULT_PREFS);
    setPrefs({ ...DEFAULT_PREFS });
  }, []);

  const close = useCallback(() => {
    setOpen(false);
    // Le focus revient au bouton qui a ouvert le panneau : sans ça, une
    // navigation au clavier repart du haut du document à chaque fermeture.
    buttonRef.current?.focus();
  }, []);

  // Échap ferme, et un clic hors du panneau aussi. Les deux écouteurs ne sont
  // posés QUE panneau ouvert : pas de gestionnaire global qui traîne.
  useEffect(() => {
    if (!open) return undefined;

    const onKeyDown = (event) => {
      if (event.key === 'Escape') close();
    };
    const onPointerDown = (event) => {
      if (panelRef.current?.contains(event.target)) return;
      if (buttonRef.current?.contains(event.target)) return; // géré par le bouton
      setOpen(false);
    };

    document.addEventListener('keydown', onKeyDown);
    document.addEventListener('pointerdown', onPointerDown);
    return () => {
      document.removeEventListener('keydown', onKeyDown);
      document.removeEventListener('pointerdown', onPointerDown);
    };
  }, [open, close]);

  // À l'ouverture, le focus entre dans le panneau (conteneur `tabIndex={-1}`) :
  // un lecteur d'écran annonce alors le titre du panneau, et la tabulation
  // suivante tombe sur le premier réglage plutôt qu'en fin de page.
  useEffect(() => {
    if (open) panelRef.current?.focus();
  }, [open]);

  const scaleLabel = intl.formatNumber(prefs.textScale / 100, { style: 'percent' });
  const atMin = prefs.textScale === TEXT_SCALES[0];
  const atMax = prefs.textScale === TEXT_SCALES[TEXT_SCALES.length - 1];

  return (
    <div className="ab-a11y">
      {open && (
        <div
          ref={panelRef}
          className="ab-a11y-panel"
          role="dialog"
          aria-modal="false"
          aria-labelledby="ab-a11y-title"
          tabIndex={-1}
        >
          <div className="ab-a11y-panel__head">
            <span className="ab-a11y-panel__icon" aria-hidden="true"><AccessIcon size={20} /></span>
            <h2 id="ab-a11y-title" className="ab-a11y-panel__title">
              {t({ id: 'a11y.title' })}
            </h2>
            <button
              type="button"
              className="ab-a11y-close"
              onClick={close}
              title={t({ id: 'a11y.close' })}
              aria-label={t({ id: 'a11y.close' })}
            >
              ✕
            </button>
          </div>

          <div className="ab-a11y-panel__body">
            {/* ── Taille du texte ─────────────────────────────────────── */}
            <div className="ab-a11y-section">
              <span className="ab-a11y-section__label" id="ab-a11y-size-label">
                {t({ id: 'a11y.textSize' })}
              </span>
              <div className="ab-a11y-size" role="group" aria-labelledby="ab-a11y-size-label">
                <button
                  type="button"
                  className="ab-a11y-size__step"
                  onClick={() => stepTextScale(-1)}
                  disabled={atMin}
                  title={t({ id: 'a11y.textSmaller' })}
                  aria-label={t({ id: 'a11y.textSmaller' })}
                >
                  A<span className="ab-a11y-size__sign" aria-hidden="true">−</span>
                </button>
                {/* `aria-live` : le changement de taille est annoncé, sinon
                    rien ne signale l'effet du bouton à qui ne voit pas l'écran. */}
                <span className="ab-a11y-size__value" aria-live="polite">
                  {scaleLabel}
                </span>
                <button
                  type="button"
                  className="ab-a11y-size__step"
                  onClick={() => stepTextScale(1)}
                  disabled={atMax}
                  title={t({ id: 'a11y.textLarger' })}
                  aria-label={t({ id: 'a11y.textLarger' })}
                >
                  A<span className="ab-a11y-size__sign" aria-hidden="true">+</span>
                </button>
              </div>
            </div>

            {/* ── Bascules ────────────────────────────────────────────── */}
            <Toggle
              icon="◐"
              label={t({ id: 'a11y.contrast' })}
              pressed={prefs.contrast}
              onToggle={() => toggle('contrast')}
            />
            <Toggle
              icon="Aa"
              label={t({ id: 'a11y.readableFont' })}
              pressed={prefs.readableFont}
              onToggle={() => toggle('readableFont')}
            />
            <Toggle
              icon="↕"
              label={t({ id: 'a11y.spacing' })}
              pressed={prefs.spacing}
              onToggle={() => toggle('spacing')}
            />
            <Toggle
              icon="🔗"
              label={t({ id: 'a11y.underlineLinks' })}
              pressed={prefs.underlineLinks}
              onToggle={() => toggle('underlineLinks')}
            />
            <Toggle
              icon="↖"
              label={t({ id: 'a11y.bigCursor' })}
              pressed={prefs.bigCursor}
              onToggle={() => toggle('bigCursor')}
            />
            <Toggle
              icon="⏸"
              label={t({ id: 'a11y.reduceMotion' })}
              pressed={prefs.reduceMotion}
              onToggle={() => toggle('reduceMotion')}
            />
            <Toggle
              icon="⌨"
              label={t({ id: 'a11y.strongFocus' })}
              pressed={prefs.strongFocus}
              onToggle={() => toggle('strongFocus')}
            />

            <button type="button" className="ab-a11y-reset" onClick={reset}>
              ⟲ {t({ id: 'a11y.reset' })}
            </button>

            <p className="ab-a11y-hint">{t({ id: 'a11y.hint' })}</p>
          </div>
        </div>
      )}

      <button
        ref={buttonRef}
        type="button"
        className="ab-a11y-fab"
        onClick={() => (open ? close() : setOpen(true))}
        aria-expanded={open}
        aria-haspopup="dialog"
        title={t({ id: 'a11y.open' })}
        aria-label={t({ id: 'a11y.open' })}
      >
        <AccessIcon size={26} />
      </button>
    </div>
  );
}
