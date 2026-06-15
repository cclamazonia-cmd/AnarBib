import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';

// ═══════════════════════════════════════════════════════════
// CatalogacaoWizard — Guide de découverte pas-à-pas
// Overlay modal expliquant chaque onglet et fonctionnalité
// de la page de catalogage.
// ═══════════════════════════════════════════════════════════

const WIZARD_SEEN_KEY = 'catalogacao_wizard_seen';

// Mapping step -> tab id (null = no tab navigation)
const STEP_TAB_MAP = [
  null,            // 0: welcome
  'booksPanel',    // 1: documento
  'authorsPanel',  // 2: autoria
  'indexPanel',    // 3: indexação
  'labelsPanel',   // 4: etiquetas
  'queuePanel',    // 5: fila/lotes/catálogo
  null,            // 6: tips
];

export default function CatalogacaoWizard({ onClose, onSwitchTab }) {
  const { formatMessage: t } = useIntl();
  const [step, setStep] = useState(0);
  const [dontShow, setDontShow] = useState(false);

  const STEPS = [
    {
      icon: '📚',
      titleKey: 'catalogacao.wizard.step.welcome.title',
      bodyKey:  'catalogacao.wizard.step.welcome.body',
    },
    {
      icon: '📝',
      titleKey: 'catalogacao.wizard.step.documento.title',
      bodyKey:  'catalogacao.wizard.step.documento.body',
      tipKey:   'catalogacao.wizard.step.documento.tip',
    },
    {
      icon: '✍️',
      titleKey: 'catalogacao.wizard.step.autoria.title',
      bodyKey:  'catalogacao.wizard.step.autoria.body',
      tipKey:   'catalogacao.wizard.step.autoria.tip',
    },
    {
      icon: '📦',
      titleKey: 'catalogacao.wizard.step.indexacao.title',
      bodyKey:  'catalogacao.wizard.step.indexacao.body',
      tipKey:   'catalogacao.wizard.step.indexacao.tip',
    },
    {
      icon: '🏷️',
      titleKey: 'catalogacao.wizard.step.etiquetas.title',
      bodyKey:  'catalogacao.wizard.step.etiquetas.body',
      tipKey:   'catalogacao.wizard.step.etiquetas.tip',
    },
    {
      icon: '📋',
      titleKey: 'catalogacao.wizard.step.fila.title',
      bodyKey:  'catalogacao.wizard.step.fila.body',
    },
    {
      icon: '💡',
      titleKey: 'catalogacao.wizard.step.dicas.title',
      bodyKey:  'catalogacao.wizard.step.dicas.body',
    },
  ];

  const total = STEPS.length;
  const isFirst = step === 0;
  const isLast = step === total - 1;
  const current = STEPS[step];

  const handleClose = useCallback(() => {
    if (dontShow) {
      try { localStorage.setItem(WIZARD_SEEN_KEY, '1'); } catch {}
    }
    onClose();
  }, [dontShow, onClose]);

  // Close on Escape
  useEffect(() => {
    function onKey(e) { if (e.key === 'Escape') handleClose(); }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [handleClose]);

  function goToTab() {
    const tabId = STEP_TAB_MAP[step];
    if (tabId && onSwitchTab) onSwitchTab(tabId);
  }

  // ── Styles ──
  const overlayStyle = {
    position: 'fixed', inset: 0, zIndex: 9999,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    background: 'rgba(0,0,0,.72)', backdropFilter: 'blur(4px)',
  };
  const cardStyle = {
    background: 'var(--brand-panel-bg, #1a1a1a)',
    border: '1px solid rgba(255,255,255,.12)',
    borderRadius: 16, padding: '28px 32px 20px',
    maxWidth: 560, width: '92vw',
    boxShadow: '0 24px 48px rgba(0,0,0,.5)',
    color: '#e8e0d6',
    position: 'relative',
  };
  const closeBtn = {
    position: 'absolute', top: 12, right: 14,
    background: 'none', border: 'none', cursor: 'pointer',
    color: 'var(--brand-muted)', fontSize: '1.2rem', lineHeight: 1,
  };
  const iconStyle = {
    fontSize: '2rem', marginBottom: 8, display: 'block',
  };
  const titleStyle = {
    fontSize: '1.1rem', fontWeight: 700, marginBottom: 8,
  };
  const bodyStyle = {
    fontSize: '.88rem', lineHeight: 1.55, color: '#d4cec3',
    marginBottom: 12, whiteSpace: 'pre-line',
  };
  const tipStyle = {
    fontSize: '.8rem', lineHeight: 1.45,
    padding: '8px 12px', borderRadius: 8,
    background: 'rgba(29,78,216,.1)', border: '1px solid rgba(29,78,216,.2)',
    color: '#93c5fd', marginBottom: 12,
  };
  const navStyle = {
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    gap: 8, marginTop: 8, flexWrap: 'wrap',
  };
  const btnBase = {
    padding: '8px 18px', borderRadius: 8, fontWeight: 600,
    fontSize: '.84rem', cursor: 'pointer', border: 'none',
    transition: 'background .15s',
  };
  const btnPrimary = {
    ...btnBase,
    background: 'linear-gradient(135deg, rgba(var(--brand-action-rgb,179,32,37),.92), var(--brand-color-primary, #b32025))',
    color: '#fff',
  };
  const btnSecondary = {
    ...btnBase,
    background: 'rgba(255,255,255,.08)', color: '#d4cec3',
  };
  const progressStyle = {
    display: 'flex', gap: 4, justifyContent: 'center', marginBottom: 16,
  };
  const dotStyle = (active) => ({
    width: 8, height: 8, borderRadius: '50%',
    background: active ? 'var(--brand-color-primary, #b32025)' : 'rgba(255,255,255,.15)',
    transition: 'background .2s',
  });

  return (
    <div style={overlayStyle} onClick={handleClose} role="dialog" aria-modal="true">
      <div style={cardStyle} onClick={e => e.stopPropagation()}>
        <button style={closeBtn} onClick={handleClose} aria-label="Close">✕</button>

        {/* Progress dots */}
        <div style={progressStyle}>
          {STEPS.map((_, i) => (
            <button
              key={i}
              style={{ ...dotStyle(i === step), cursor: 'pointer', border: 'none', padding: 0 }}
              onClick={() => setStep(i)}
              aria-label={`Step ${i + 1}`}
            />
          ))}
        </div>

        {/* Content */}
        <span style={iconStyle}>{current.icon}</span>
        <div style={titleStyle}>{t({ id: current.titleKey })}</div>
        <div style={bodyStyle}>{t({ id: current.bodyKey })}</div>
        {current.tipKey && (
          <div style={tipStyle}>
            💡 {t({ id: current.tipKey })}
          </div>
        )}

        {/* Go to tab button */}
        {STEP_TAB_MAP[step] && (
          <button style={{ ...btnSecondary, marginBottom: 8, width: '100%', textAlign: 'center' }} onClick={goToTab}>
            ➜ {t({ id: 'catalogacao.wizard.goToTab' })}
          </button>
        )}

        {/* Navigation */}
        <div style={navStyle}>
          <div style={{ display: 'flex', gap: 8 }}>
            {!isFirst && (
              <button style={btnSecondary} onClick={() => setStep(s => s - 1)}>
                ← {t({ id: 'catalogacao.wizard.prev' })}
              </button>
            )}
          </div>
          <span style={{ fontSize: '.78rem', color: 'var(--brand-muted)' }}>
            {t({ id: 'catalogacao.wizard.stepOf' }, { current: step + 1, total })}
          </span>
          <div style={{ display: 'flex', gap: 8 }}>
            {!isLast ? (
              <button style={btnPrimary} onClick={() => setStep(s => s + 1)}>
                {t({ id: 'catalogacao.wizard.next' })} →
              </button>
            ) : (
              <button style={btnPrimary} onClick={handleClose}>
                {t({ id: 'catalogacao.wizard.gotIt' })} ✓
              </button>
            )}
          </div>
        </div>

        {/* Don't show again — disponible a CHAQUE etape (et pas seulement a la
            derniere) : fermer tot (croix / Echap / clic overlay) avec la case
            cochee pose bien l'opt-out, sinon le wizard reapparait a chaque visite. */}
        <label style={{ display: 'flex', alignItems: 'center', gap: 6, justifyContent: 'center', marginTop: 12, fontSize: '.78rem', color: 'var(--brand-muted)', cursor: 'pointer' }}>
          <input type="checkbox" checked={dontShow} onChange={e => setDontShow(e.target.checked)} />
          {t({ id: 'catalogacao.wizard.dontShowAgain' })}
        </label>
      </div>
    </div>
  );
}

/**
 * Returns true if the wizard has NOT been dismissed by the user.
 * Used by CatalogacaoPage to auto-show the wizard on first visit.
 */
export function shouldShowWizard() {
  try { return localStorage.getItem(WIZARD_SEEN_KEY) !== '1'; } catch { return false; }
}
