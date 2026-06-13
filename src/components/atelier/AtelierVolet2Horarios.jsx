import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';

// ═══════════════════════════════════════════════════════════════════════════
// AtelierVolet2Horarios — ONBO-Q2 Lot 3
// Volet 2 « Horários e plantões » câblé sur la biblio pré-active : édite
// library_service_state (mode de service, autorisations emprunts/réservations,
// message public). RLS staff-based (OK pré-active). Sauvegarde au changement
// (select/cases) ou au blur (message), avec toast de confirmation.
// Réutilise les clés i18n existantes (biblioteca.identity.* + rede.serviceMode.*).
// ═══════════════════════════════════════════════════════════════════════════
export default function AtelierVolet2Horarios({ libraryId, canEdit }) {
  const { formatMessage: t } = useIntl();
  const { notifyError, notifySuccess } = useToast();
  const [ss, setSs] = useState(null);
  const [saving, setSaving] = useState(false);

  const SERVICE_MODES = useMemo(() => ([
    { value: 'funcionamento_normal',   label: t({ id: 'rede.serviceMode.funcionamento_normal' }) },
    { value: 'funcionamento_reduzido', label: t({ id: 'rede.serviceMode.funcionamento_reduzido' }) },
    { value: 'recesso',                label: t({ id: 'rede.serviceMode.recesso' }) },
    { value: 'suspenso',               label: t({ id: 'rede.serviceMode.suspenso' }) },
  ]), [t]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase.from('library_service_state')
          .select('service_mode, allows_new_loans, allows_new_reservations, public_message')
          .eq('library_id', libraryId).maybeSingle();
        if (!cancelled) setSs(data || {});
      } catch { if (!cancelled) setSs({}); }
    })();
    return () => { cancelled = true; };
  }, [libraryId]);

  const save = useCallback(async (patch) => {
    setSs(prev => ({ ...prev, ...patch }));
    setSaving(true);
    try {
      const { error } = await supabase.from('library_service_state').update(patch).eq('library_id', libraryId);
      if (error) throw error;
      notifySuccess(t({ id: 'atelier.toast.saved' }));
    } catch (e) { notifyError(localizeError(e, t)); }
    finally { setSaving(false); }
  }, [libraryId, notifyError, notifySuccess, t]);

  if (!ss) return null;
  const dis = !canEdit || saving;
  const taStyle = {
    width: '100%', padding: '9px 12px', borderRadius: 9,
    border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))',
    background: 'rgba(0,0,0,.3)', color: 'var(--brand-text,#f4f1ee)',
    fontFamily: 'inherit', fontSize: '.84rem', resize: 'vertical',
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div className="ab-atl-field">
        <label>{t({ id: 'biblioteca.identity.serviceMode' })}</label>
        <select value={ss.service_mode || ''} disabled={dis} onChange={e => save({ service_mode: e.target.value })}>
          {SERVICE_MODES.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
        </select>
      </div>
      <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: '.84rem' }}>
        <input type="checkbox" checked={ss.allows_new_loans || false} disabled={dis} onChange={e => save({ allows_new_loans: e.target.checked })} />
        {t({ id: 'biblioteca.identity.allowsLoans' })}
      </label>
      <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: '.84rem' }}>
        <input type="checkbox" checked={ss.allows_new_reservations || false} disabled={dis} onChange={e => save({ allows_new_reservations: e.target.checked })} />
        {t({ id: 'biblioteca.identity.allowsReservations' })}
      </label>
      <div className="ab-atl-field">
        <label>{t({ id: 'biblioteca.identity.publicMessage' })}</label>
        <textarea
          value={ss.public_message || ''} disabled={dis} rows={2} style={taStyle}
          placeholder={t({ id: 'biblioteca.identity.publicMessagePlaceholder' })}
          onChange={e => setSs(prev => ({ ...prev, public_message: e.target.value }))}
          onBlur={e => save({ public_message: e.target.value })}
        />
      </div>
    </div>
  );
}
