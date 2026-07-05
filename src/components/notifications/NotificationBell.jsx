import { useState, useRef, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { useNavigate, useLocation } from 'react-router-dom';
import { useNotifications } from '@/hooks/useNotifications';

// Cloche de notifications in-app (MVP) : badge non-lus + panneau déroulant.
// Backend : user_notifications (RLS « read own ») + RPC fn_mark_notifications_read.
// Le clic sur une notif la marque lue et, pour les types connus, navigue vers
// l'objet concerné (link_type / link_id). Types inconnus : marquage seul.

function resolveRoute(n) {
  switch (n.link_type) {
    case 'reserva':
      return '/conta';
    case 'library_event':
      return '/conta';
    default:
      return null;
  }
}

export default function NotificationBell() {
  const { formatMessage: t, formatDate } = useIntl();
  const navigate = useNavigate();
  const location = useLocation();
  const { items, unreadCount, loading, error, markRead, markAllRead, reload } = useNotifications();
  const [open, setOpen] = useState(false);
  const rootRef = useRef(null);

  // Fermeture au clic extérieur.
  useEffect(() => {
    if (!open) return undefined;
    function onDown(e) {
      if (rootRef.current && !rootRef.current.contains(e.target)) setOpen(false);
    }
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [open]);

  // Fermeture à la navigation.
  useEffect(() => { setOpen(false); }, [location.pathname]);

  function toggle() {
    const next = !open;
    setOpen(next);
    if (next) reload();
  }

  function onItemClick(n) {
    if (!n.is_read) markRead([n.id]);
    const route = resolveRoute(n);
    if (route) { setOpen(false); navigate(route); }
  }

  // Les notifs récentes stockent une CLÉ i18n (ex. « notif.reserva.prontaParaRetirada.title »)
  // à traduire au rendu ; les anciennes/ponctuelles stockent du texte littéral. On ne traduit
  // que si ça ressemble à une clé (mot.mot, sans espace) — sinon on rend le littéral tel quel.
  // Même règle que l'onglet « Avisos » d'AccountPage (tNotifText).
  const tNotifText = (s) => (s && /^[\w.]+$/.test(s) && s.includes('.')) ? t({ id: s, defaultMessage: s }) : s;

  const badge = unreadCount > 9 ? '9+' : String(unreadCount);

  return (
    <div ref={rootRef} style={{ position: 'relative', display: 'inline-flex' }}>
      <button
        type="button"
        onClick={toggle}
        aria-label={t({ id: 'notifications.bell' })}
        aria-haspopup="true"
        aria-expanded={open}
        style={{
          position: 'relative', display: 'inline-flex', alignItems: 'center',
          justifyContent: 'center', background: 'none', border: 'none',
          color: 'inherit', cursor: 'pointer', padding: 6, lineHeight: 0,
        }}
      >
        <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
          <path
            d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0"
            stroke="currentColor" strokeWidth="2" strokeLinecap="round"
            strokeLinejoin="round" fill="none"
          />
        </svg>
        {unreadCount > 0 && (
          <span
            aria-hidden="true"
            style={{
              position: 'absolute', top: 0, right: 0, minWidth: 16, height: 16,
              padding: '0 4px', borderRadius: 8, background: 'var(--brand-accent, #c44)',
              color: '#fff', fontSize: '.66rem', fontWeight: 700, lineHeight: '16px',
              textAlign: 'center',
            }}
          >
            {badge}
          </span>
        )}
      </button>

      {open && (
        <div
          role="dialog"
          aria-label={t({ id: 'notifications.title' })}
          style={{
            position: 'absolute', top: 'calc(100% + 8px)', right: 0, zIndex: 1000,
            width: 'min(360px, 92vw)', maxHeight: '70vh', overflowY: 'auto',
            background: 'var(--brand-surface, #161616)',
            border: '1px solid rgba(255,255,255,.14)', borderRadius: 12,
            boxShadow: '0 16px 40px rgba(0,0,0,.5)', color: 'var(--brand-fg, #f4f4f4)',
          }}
        >
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            gap: 8, padding: '12px 14px', borderBottom: '1px solid rgba(255,255,255,.08)',
            position: 'sticky', top: 0, background: 'var(--brand-surface, #161616)',
          }}>
            <strong style={{ fontSize: '.92rem' }}>{t({ id: 'notifications.title' })}</strong>
            {unreadCount > 0 && (
              <button
                type="button"
                onClick={markAllRead}
                style={{
                  background: 'none', border: 'none', color: 'var(--brand-accent, #c44)',
                  cursor: 'pointer', fontSize: '.78rem', padding: 0,
                }}
              >
                {t({ id: 'notifications.markAllRead' })}
              </button>
            )}
          </div>

          {error ? (
            <div style={{ padding: 16, fontSize: '.85rem', color: 'var(--brand-muted, #aaa)' }}>
              {t({ id: 'notifications.loadError' })}
            </div>
          ) : items.length === 0 ? (
            <div style={{ padding: 20, fontSize: '.85rem', color: 'var(--brand-muted, #999)', textAlign: 'center' }}>
              {loading ? '…' : t({ id: 'notifications.empty' })}
            </div>
          ) : (
            <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
              {items.map((n) => {
                const clickable = !n.is_read || resolveRoute(n);
                return (
                  <li key={n.id}>
                    <button
                      type="button"
                      onClick={() => onItemClick(n)}
                      style={{
                        display: 'block', width: '100%', textAlign: 'left',
                        padding: '11px 14px', border: 'none', cursor: clickable ? 'pointer' : 'default',
                        background: n.is_read ? 'transparent' : 'rgba(196,68,68,.07)',
                        borderLeft: n.is_read ? '3px solid transparent' : '3px solid var(--brand-accent, #c44)',
                        borderBottom: '1px solid rgba(255,255,255,.05)', color: 'inherit',
                      }}
                    >
                      {n.title && (
                        <div style={{ fontSize: '.86rem', fontWeight: n.is_read ? 500 : 700, marginBottom: 2 }}>
                          {tNotifText(n.title)}
                        </div>
                      )}
                      {n.body && (
                        <div style={{
                          fontSize: '.8rem', color: 'var(--brand-muted, #bbb)', lineHeight: 1.4,
                          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
                          overflow: 'hidden',
                        }}>
                          {tNotifText(n.body)}
                        </div>
                      )}
                      <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)', marginTop: 4 }}>
                        {formatDate(n.created_at, { dateStyle: 'medium', timeStyle: 'short' })}
                      </div>
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
