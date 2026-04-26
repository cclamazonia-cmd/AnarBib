/* ═══════════════════════════════════════════════════════════
   AnarBib — Composants UI réutilisables
   Ces composants remplacent les patterns HTML/CSS copiés-collés
   dans chaque page monolithique. Ils respectent le système
   de variables CSS du theme-base.
   ═══════════════════════════════════════════════════════════ */

import './ui.css';

// ── Bouton ─────────────────────────────────────────────────

export function Button({
  children,
  variant = 'primary', // 'primary' | 'secondary' | 'mini' | 'danger'
  disabled = false,
  loading = false,
  href,
  onClick,
  className = '',
  ...rest
}) {
  const cls = [
    'ab-button',
    variant !== 'primary' && `ab-button--${variant}`,
    loading && 'ab-button--loading',
    className,
  ].filter(Boolean).join(' ');

  if (href) {
    return (
      <a href={href} className={cls} {...rest}>
        {children}
      </a>
    );
  }

  return (
    <button className={cls} disabled={disabled || loading} onClick={onClick} {...rest}>
      {loading ? '…' : children}
    </button>
  );
}

// ── Input ──────────────────────────────────────────────────

export function Input({ label, error, className = '', ...rest }) {
  return (
    <div className={`ab-field ${className}`}>
      {label && <label className="ab-field__label">{label}</label>}
      <input className="ab-input" {...rest} />
      {error && <span className="ab-field__error">{error}</span>}
    </div>
  );
}

// ── Select ─────────────────────────────────────────────────

export function Select({ label, options = [], placeholder, className = '', ...rest }) {
  return (
    <div className={`ab-field ${className}`}>
      {label && <label className="ab-field__label">{label}</label>}
      <select className="ab-select" {...rest}>
        {placeholder && <option value="">{placeholder}</option>}
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </div>
  );
}

// ── Textarea ───────────────────────────────────────────────

export function Textarea({ label, error, className = '', ...rest }) {
  return (
    <div className={`ab-field ${className}`}>
      {label && <label className="ab-field__label">{label}</label>}
      <textarea className="ab-textarea" {...rest} />
      {error && <span className="ab-field__error">{error}</span>}
    </div>
  );
}

// ── Card / Panel ───────────────────────────────────────────

export function Card({ children, className = '', ...rest }) {
  return (
    <div className={`ab-card ${className}`} {...rest}>
      {children}
    </div>
  );
}

// ── Sheet (card avec en-tête) ──────────────────────────────

export function Sheet({ title, actions, children, className = '' }) {
  return (
    <div className={`ab-sheet ${className}`}>
      {(title || actions) && (
        <div className="ab-sheet__head">
          {title && <span className="ab-sheet__title">{title}</span>}
          {actions && <div className="ab-sheet__actions">{actions}</div>}
        </div>
      )}
      <div className="ab-sheet__body">{children}</div>
    </div>
  );
}

// ── Pill / Badge ───────────────────────────────────────────

export function Pill({ children, variant = 'default', className = '' }) {
  return (
    <span className={`ab-pill ab-pill--${variant} ${className}`}>
      {children}
    </span>
  );
}

// ── Status Badge ───────────────────────────────────────────

export function StatusBadge({ status, label, className = '' }) {
  const variant = {
    ativa: 'ok', aberto: 'ok', active: 'ok',
    encerrada: 'muted', encerrado: 'muted', devolvido: 'muted',
    cancelada_leitor: 'warn', cancelada_biblioteca: 'warn', expirada: 'warn',
    atrasado: 'bad', overdue: 'bad',
  }[status] || 'default';

  return (
    <span className={`ab-status-badge ab-status-badge--${variant} ${className}`}>
      {label || status}
    </span>
  );
}

// ── Empty state ────────────────────────────────────────────

export function EmptyState({ message, children }) {
  return (
    <div className="ab-empty">
      <p>{message}</p>
      {children}
    </div>
  );
}

// ── Loading spinner ────────────────────────────────────────

export function Spinner({ size = 24 }) {
  return (
    <svg
      className="ab-spinner"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
    >
      <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" />
    </svg>
  );
}
