// ============================================================================
// src/components/team/TeamActionsMenu.jsx
// ============================================================================
//
// Menu déroulant "Actions ▾" affiché sur chaque ligne de membership dans
// <TeamPanel />. Affiche uniquement les actions disponibles selon les
// permissions row-level calculées par availableTeamActions(ctx).
//
// Si aucune action n'est disponible : ne rend rien (pas de bouton vide).
//
// Comportement :
//   - Click sur "Actions ▾" → ouvre le menu
//   - Click sur une action → appelle onSelectAction(action) puis ferme le menu
//   - Click ailleurs (overlay) → ferme le menu
//   - Touche ESC → ferme le menu
//   - Scroll/resize → recalcule la position
//
// IMPLÉMENTATION : portal vers document.body
// -------------------------------------------
// Le menu déroulant a longtemps été rendu en position:absolute à l'intérieur
// de la ligne. Problème : .ab-team-list a `overflow: hidden` (pour clipper
// ses bordures arrondies), ce qui clippait aussi le menu déroulant.
//
// Solution : on rend le menu via createPortal directement dans document.body,
// avec position:fixed et calcul dynamique de la position. Ça libère le menu
// de toute contrainte d'overflow parent. Pattern utilisé par tous les
// composants de menu sérieux (radix-ui, headlessui, etc.).
//
// Props :
//   - actions       : Array<{action, label, kind, requiresReason}> issu de availableTeamActions
//   - onSelectAction: (actionDescriptor) => void  callback quand une action est sélectionnée
//   - disabled      : bool  désactive le bouton
//
// ============================================================================

import { useState, useEffect, useRef, useCallback } from 'react';
import { createPortal } from 'react-dom';
import { useIntl } from 'react-intl';

const MENU_MARGIN = 4;        // marge entre le trigger et le menu (en px)
const VIEWPORT_MARGIN = 8;    // marge de sécurité par rapport aux bords du viewport

export default function TeamActionsMenu({ actions, onSelectAction, disabled = false }) {
  const { formatMessage: t } = useIntl();
  const [open, setOpen] = useState(false);
  const [menuStyle, setMenuStyle] = useState(null);
  const triggerRef = useRef(null);
  const menuRef = useRef(null);

  // ── Calcul de la position du menu ────────────────────
  // Aligné à droite du trigger, juste en dessous. Si le menu déborde du
  // viewport en bas, on le rabat au-dessus du trigger.
  const computePosition = useCallback(() => {
    if (!triggerRef.current) return;
    const triggerRect = triggerRef.current.getBoundingClientRect();
    const menuEl = menuRef.current;

    // Estimation des dimensions du menu (s'il n'est pas encore monté, on
    // utilise des valeurs raisonnables : largeur min 200px, hauteur 40px
    // par item).
    const menuWidth = menuEl?.offsetWidth || 220;
    const menuHeight = menuEl?.offsetHeight || (actions.length * 40 + 8);

    // Position par défaut : sous le trigger, alignement à droite
    let top = triggerRect.bottom + MENU_MARGIN;
    let left = triggerRect.right - menuWidth;

    // Si le menu déborde en bas du viewport → rabattre au-dessus
    if (top + menuHeight + VIEWPORT_MARGIN > window.innerHeight) {
      top = triggerRect.top - menuHeight - MENU_MARGIN;
    }

    // Si le menu déborde à gauche du viewport → recaler
    if (left < VIEWPORT_MARGIN) {
      left = VIEWPORT_MARGIN;
    }

    // Si le menu déborde à droite du viewport → recaler
    if (left + menuWidth + VIEWPORT_MARGIN > window.innerWidth) {
      left = window.innerWidth - menuWidth - VIEWPORT_MARGIN;
    }

    setMenuStyle({
      position: 'fixed',
      top: `${top}px`,
      left: `${left}px`,
      minWidth: '200px',
    });
  }, [actions.length]);

  // ── Recalcul à l'ouverture + sur scroll/resize ───────
  useEffect(() => {
    if (!open) return;

    computePosition();

    const handleScrollOrResize = () => computePosition();
    // useCapture=true pour attraper aussi le scroll des conteneurs parents
    window.addEventListener('scroll', handleScrollOrResize, true);
    window.addEventListener('resize', handleScrollOrResize);

    return () => {
      window.removeEventListener('scroll', handleScrollOrResize, true);
      window.removeEventListener('resize', handleScrollOrResize);
    };
  }, [open, computePosition]);

  // ── Re-mesurer après le 1er rendu effectif du menu ────
  // Au 1er render, menuRef.current est encore null donc computePosition
  // utilise les estimations. Une fois le menu monté dans le DOM, on peut
  // mesurer sa taille réelle et corriger la position.
  useEffect(() => {
    if (open && menuRef.current) {
      computePosition();
    }
  }, [open, computePosition]);

  // ── Fermeture sur clic extérieur / ESC ───────────────
  useEffect(() => {
    if (!open) return;

    const handleClick = (e) => {
      const inTrigger = triggerRef.current?.contains(e.target);
      const inMenu = menuRef.current?.contains(e.target);
      if (!inTrigger && !inMenu) {
        setOpen(false);
      }
    };
    const handleKey = (e) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        setOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClick);
    document.addEventListener('keydown', handleKey);
    return () => {
      document.removeEventListener('mousedown', handleClick);
      document.removeEventListener('keydown', handleKey);
    };
  }, [open]);

  if (!actions || actions.length === 0) return null;

  const handleSelect = (action) => {
    setOpen(false);
    onSelectAction(action);
  };

  // ── Rendu du menu via portal ─────────────────────────
  const menuPortal = open && menuStyle
    ? createPortal(
        <ul
          ref={menuRef}
          className="ab-team-actions-list"
          role="menu"
          style={menuStyle}
        >
          {actions.map(a => (
            <li key={a.action} role="none">
              <button
                type="button"
                role="menuitem"
                className={`ab-team-actions-item ab-team-actions-item--${a.kind || 'default'}`}
                onClick={() => handleSelect(a)}
              >
                {t({ id: a.label })}
              </button>
            </li>
          ))}
        </ul>,
        document.body
      )
    : null;

  return (
    <div className="ab-team-actions-menu">
      <button
        ref={triggerRef}
        type="button"
        className="ab-team-actions-trigger"
        onClick={() => setOpen(o => !o)}
        disabled={disabled}
        aria-haspopup="menu"
        aria-expanded={open}
      >
        {t({ id: 'team.actions.menu' })} <span className="ab-team-actions-chevron">▾</span>
      </button>
      {menuPortal}
    </div>
  );
}
