import { useEffect, useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// ─── Constantes ──────────────────────────────────────────────────────────────

const DEFAULT_LOANS = 730;          // 24 mois
const DEFAULT_RESERVATIONS = 365;   // 12 mois
const DEFAULT_CONSULTATIONS = 365;  // 12 mois
const DEFAULT_NOTIFICATIONS = 90;   // 90 jours

// ─── Styles ──────────────────────────────────────────────────────────────────

const cardStyle = {
  padding: 18,
  borderRadius: 10,
  background: 'rgba(255,255,255,.025)',
  border: '1px solid rgba(255,255,255,.08)',
  marginBottom: 16,
};

const fieldGridStyle = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
  gap: 14,
  marginBottom: 14,
};

const fieldStyle = {
  display: 'flex',
  flexDirection: 'column',
  gap: 4,
};

const labelStyle = {
  fontSize: '.82rem',
  fontWeight: 600,
  color: 'var(--brand-fg, #f4f4f4)',
};

const helperStyle = {
  fontSize: '.78rem',
  color: 'var(--brand-muted, #999)',
};

const inputStyle = {
  padding: '8px 12px',
  borderRadius: 6,
  border: '1px solid rgba(255,255,255,.15)',
  background: 'rgba(0,0,0,.25)',
  color: 'var(--brand-fg, #f4f4f4)',
  fontSize: '.9rem',
  fontFamily: 'inherit',
  width: '100%',
  boxSizing: 'border-box',
};

const textareaStyle = {
  ...inputStyle,
  minHeight: 60,
  resize: 'vertical',
};

const buttonStyle = (primary = false) => ({
  padding: '9px 18px',
  borderRadius: 6,
  border: '1px solid ' + (primary ? 'var(--brand-accent, #c44)' : 'rgba(255,255,255,.2)'),
  background: primary ? 'var(--brand-accent, #c44)' : 'transparent',
  color: primary ? '#fff' : 'var(--brand-fg, #f4f4f4)',
  fontSize: '.88rem',
  fontWeight: 600,
  cursor: 'pointer',
  fontFamily: 'inherit',
  marginRight: 8,
});

const noticeStyle = (kind) => ({
  padding: '10px 14px',
  borderRadius: 6,
  fontSize: '.85rem',
  marginBottom: 14,
  background:
    kind === 'success' ? 'rgba(21,128,61,.12)' :
    kind === 'error' ? 'rgba(220,38,38,.12)' :
    'rgba(29,78,216,.08)',
  color:
    kind === 'success' ? '#4ade80' :
    kind === 'error' ? '#f87171' :
    '#60a5fa',
});

// ─── Helpers ────────────────────────────────────────────────────────────────

/**
 * Convertit une valeur input en int, ou en NULL si vide / 'défaut'.
 * Le user peut entrer:
 *   - vide ou "défaut" → NULL (utilise le défaut AnarBib)
 *   - 0 → 0 (rétention infinie)
 *   - >0 → durée en jours
 */
function parseValue(str) {
  const trimmed = String(str || '').trim();
  if (trimmed === '' || trimmed.toLowerCase() === 'default' || trimmed.toLowerCase() === 'défaut' || trimmed === '—') {
    return null;
  }
  const n = parseInt(trimmed, 10);
  if (isNaN(n) || n < 0) return null;
  return n;
}

/**
 * Affiche une durée en jours sous forme lisible :
 *   - 0 → "infini"
 *   - 90 → "90 jours"
 *   - 365 → "1 an"
 *   - 730 → "2 ans"
 *   - 30 → "30 jours"
 *   - 730 → "2 ans"
 */
function formatDuration(days, t) {
  if (days === 0) return t({ id: 'biblioteca.privacy.duration.infinite' });
  if (days === null || days === undefined) return t({ id: 'biblioteca.privacy.duration.default' });
  if (days >= 365 && days % 365 === 0) {
    const years = days / 365;
    return t({ id: 'biblioteca.privacy.duration.years' }, { count: years });
  }
  if (days >= 30 && days % 30 === 0) {
    const months = days / 30;
    return t({ id: 'biblioteca.privacy.duration.months' }, { count: months });
  }
  return t({ id: 'biblioteca.privacy.duration.days' }, { count: days });
}

// ─── Composant principal ─────────────────────────────────────────────────────

/**
 * RetentionPolicySection
 * Affiche et permet de configurer les durées de rétention RGPD d'une biblio.
 *
 * Props:
 *   libraryId : uuid de la biblio
 *   canEdit   : boolean — true si user peut modifier (coord+admin)
 *               false si user est librarian (lecture seule)
 */
export default function RetentionPolicySection({ libraryId, canEdit = false }) {
  const { formatMessage: t } = useIntl();
  const [policy, setPolicy] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState(null);

  // Form state (chaînes pour permettre la valeur vide = NULL)
  const [loansInput, setLoansInput] = useState('');
  const [reservationsInput, setReservationsInput] = useState('');
  const [consultationsInput, setConsultationsInput] = useState('');
  const [notificationsInput, setNotificationsInput] = useState('');
  const [notesInput, setNotesInput] = useState('');

  // ─── Chargement initial ────────────────────────────────────────────────────
  useEffect(() => {
    if (!libraryId) return;
    let cancelled = false;
    (async () => {
      setLoading(true);
      try {
        const { data, error } = await supabase.rpc('fn_get_retention_policy', { p_library_id: libraryId });
        if (cancelled) return;
        if (error) throw error;
        setPolicy(data);
        // Initialise les inputs avec les valeurs override (vide si pas d'override)
        setLoansInput(data?.overrides?.loans ? String(data.retention_loans_days) : '');
        setReservationsInput(data?.overrides?.reservations ? String(data.retention_reservations_days) : '');
        setConsultationsInput(data?.overrides?.consultations ? String(data.retention_consultations_days) : '');
        setNotificationsInput(data?.overrides?.notifications ? String(data.retention_notifications_days) : '');
        setNotesInput(data?.notes || '');
      } catch (err) {
        if (cancelled) return;
        setNotice({ kind: 'error', text: localizeError(err, t) });
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [libraryId]);

  // ─── Sauvegarde ────────────────────────────────────────────────────────────
  async function handleSave() {
    setSaving(true);
    setNotice(null);
    try {
      const { data, error } = await supabase.rpc('fn_set_retention_policy', {
        p_library_id: libraryId,
        p_loans_days: parseValue(loansInput),
        p_reservations_days: parseValue(reservationsInput),
        p_consultations_days: parseValue(consultationsInput),
        p_notifications_days: parseValue(notificationsInput),
        p_notes: notesInput.trim() || null,
      });
      if (error) throw error;
      setPolicy(data);
      setNotice({ kind: 'success', text: t({ id: 'biblioteca.privacy.saved' }) });
    } catch (err) {
      setNotice({ kind: 'error', text: localizeError(err, t) });
    } finally {
      setSaving(false);
    }
  }

  // ─── Réinitialisation aux défauts AnarBib ──────────────────────────────────
  function handleResetToDefaults() {
    setLoansInput('');
    setReservationsInput('');
    setConsultationsInput('');
    setNotificationsInput('');
    setNotice({ kind: 'info', text: t({ id: 'biblioteca.privacy.resetHint' }) });
  }

  if (loading) {
    return <div style={{ padding: 20, color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</div>;
  }

  return (
    <div>
      <h3 style={{ marginBottom: 4 }}>{t({ id: 'biblioteca.privacy.title' })}</h3>
      <p style={{ ...helperStyle, marginBottom: 16 }}>
        {t({ id: 'biblioteca.privacy.subtitle' })}
      </p>

      {/* Bandeau purge active */}
      <div style={noticeStyle('info')}>
        ℹ {t({ id: 'biblioteca.privacy.purgeActiveNotice' })}
      </div>

      {/* Bandeau de retour utilisateur */}
      {notice && (
        <div style={noticeStyle(notice.kind)}>{notice.text}</div>
      )}

      {/* Carte des durées effectives actuelles */}
      <div style={cardStyle}>
        <h4 style={{ margin: '0 0 8px', fontSize: '.95rem' }}>
          {t({ id: 'biblioteca.privacy.currentEffective' })}
        </h4>
        <ul style={{ fontSize: '.88rem', lineHeight: 1.7, margin: 0, paddingLeft: 18 }}>
          <li>
            {t({ id: 'biblioteca.privacy.loans' })} :{' '}
            <strong>{formatDuration(policy?.retention_loans_days, t)}</strong>
            {' '}{policy?.overrides?.loans
              ? <span style={{ color: '#fbbf24' }}>({t({ id: 'biblioteca.privacy.customized' })})</span>
              : <span style={{ color: 'var(--brand-muted)' }}>({t({ id: 'biblioteca.privacy.useDefault' })})</span>}
          </li>
          <li>
            {t({ id: 'biblioteca.privacy.reservations' })} :{' '}
            <strong>{formatDuration(policy?.retention_reservations_days, t)}</strong>
            {' '}{policy?.overrides?.reservations
              ? <span style={{ color: '#fbbf24' }}>({t({ id: 'biblioteca.privacy.customized' })})</span>
              : <span style={{ color: 'var(--brand-muted)' }}>({t({ id: 'biblioteca.privacy.useDefault' })})</span>}
          </li>
          <li>
            {t({ id: 'biblioteca.privacy.consultations' })} :{' '}
            <strong>{formatDuration(policy?.retention_consultations_days, t)}</strong>
            {' '}{policy?.overrides?.consultations
              ? <span style={{ color: '#fbbf24' }}>({t({ id: 'biblioteca.privacy.customized' })})</span>
              : <span style={{ color: 'var(--brand-muted)' }}>({t({ id: 'biblioteca.privacy.useDefault' })})</span>}
          </li>
          <li>
            {t({ id: 'biblioteca.privacy.notifications' })} :{' '}
            <strong>{formatDuration(policy?.retention_notifications_days, t)}</strong>
            {' '}{policy?.overrides?.notifications
              ? <span style={{ color: '#fbbf24' }}>({t({ id: 'biblioteca.privacy.customized' })})</span>
              : <span style={{ color: 'var(--brand-muted)' }}>({t({ id: 'biblioteca.privacy.useDefault' })})</span>}
          </li>
        </ul>
      </div>

      {/* Carte d'édition (cachée si !canEdit) */}
      {canEdit ? (
        <div style={cardStyle}>
          <h4 style={{ margin: '0 0 12px', fontSize: '.95rem' }}>
            {t({ id: 'biblioteca.privacy.editTitle' })}
          </h4>
          <p style={{ ...helperStyle, marginBottom: 12 }}>
            {t({ id: 'biblioteca.privacy.editHint' })}
          </p>

          <div style={fieldGridStyle}>
            <div style={fieldStyle}>
              <label style={labelStyle}>{t({ id: 'biblioteca.privacy.loans' })} ({t({ id: 'biblioteca.privacy.days' })})</label>
              <input type="number" min="0" placeholder={`${t({ id: 'biblioteca.privacy.default' })} : ${DEFAULT_LOANS}`}
                value={loansInput} onChange={e => setLoansInput(e.target.value)} style={inputStyle} />
              <span style={helperStyle}>{t({ id: 'biblioteca.privacy.loansHint' })}</span>
            </div>
            <div style={fieldStyle}>
              <label style={labelStyle}>{t({ id: 'biblioteca.privacy.reservations' })} ({t({ id: 'biblioteca.privacy.days' })})</label>
              <input type="number" min="0" placeholder={`${t({ id: 'biblioteca.privacy.default' })} : ${DEFAULT_RESERVATIONS}`}
                value={reservationsInput} onChange={e => setReservationsInput(e.target.value)} style={inputStyle} />
              <span style={helperStyle}>{t({ id: 'biblioteca.privacy.reservationsHint' })}</span>
            </div>
            <div style={fieldStyle}>
              <label style={labelStyle}>{t({ id: 'biblioteca.privacy.consultations' })} ({t({ id: 'biblioteca.privacy.days' })})</label>
              <input type="number" min="0" placeholder={`${t({ id: 'biblioteca.privacy.default' })} : ${DEFAULT_CONSULTATIONS}`}
                value={consultationsInput} onChange={e => setConsultationsInput(e.target.value)} style={inputStyle} />
              <span style={helperStyle}>{t({ id: 'biblioteca.privacy.consultationsHint' })}</span>
            </div>
            <div style={fieldStyle}>
              <label style={labelStyle}>{t({ id: 'biblioteca.privacy.notifications' })} ({t({ id: 'biblioteca.privacy.days' })})</label>
              <input type="number" min="0" placeholder={`${t({ id: 'biblioteca.privacy.default' })} : ${DEFAULT_NOTIFICATIONS}`}
                value={notificationsInput} onChange={e => setNotificationsInput(e.target.value)} style={inputStyle} />
              <span style={helperStyle}>{t({ id: 'biblioteca.privacy.notificationsHint' })}</span>
            </div>
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>{t({ id: 'biblioteca.privacy.notes' })}</label>
            <textarea value={notesInput} onChange={e => setNotesInput(e.target.value)}
              placeholder={t({ id: 'biblioteca.privacy.notesPlaceholder' })} style={textareaStyle} />
          </div>

          <div style={{ marginTop: 16 }}>
            <button onClick={handleSave} disabled={saving} style={buttonStyle(true)}>
              {saving ? t({ id: 'biblioteca.privacy.saving' }) : t({ id: 'biblioteca.privacy.save' })}
            </button>
            <button onClick={handleResetToDefaults} disabled={saving} style={buttonStyle(false)}>
              {t({ id: 'biblioteca.privacy.resetToDefaults' })}
            </button>
          </div>
        </div>
      ) : (
        <div style={{ ...noticeStyle('info'), marginTop: 8 }}>
          {t({ id: 'biblioteca.privacy.readonlyHint' })}
        </div>
      )}
    </div>
  );
}
