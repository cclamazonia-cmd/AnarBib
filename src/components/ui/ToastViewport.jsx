/* ════════════════════════════════════════════════════════════════════════
   AnarBib — ToastViewport
   Affichage visuel des toasts empilés. Piloté par ToastContext.
   Style cohérent avec ui.css (classes ab-*, variables --brand-* / --color-*).
   ════════════════════════════════════════════════════════════════════════ */

export default function ToastViewport({ toasts, onDismiss }) {
  if (!toasts || toasts.length === 0) return null;

  return (
    <div className="ab-toast-viewport" role="region" aria-live="polite">
      {toasts.map((t) => (
        <div
          key={t.id}
          className={`ab-toast ab-toast--${t.kind}`}
          role={t.kind === 'error' ? 'alert' : 'status'}
        >
          <span className="ab-toast__msg">{t.message}</span>
          <button
            type="button"
            className="ab-toast__close"
            onClick={() => onDismiss(t.id)}
            aria-label="Fermer"
          >
            ×
          </button>
        </div>
      ))}
    </div>
  );
}
