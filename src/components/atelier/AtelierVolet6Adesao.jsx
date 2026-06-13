import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';

// ═══════════════════════════════════════════════════════════════════════════
// AtelierVolet6Adesao — ONBO-Q2 Lot 3
// Volet 6 « Adesão » : politique d'adhésion lecteur·rice (comment on devient
// lecteur·rice). accepts_public_signup (inscription libre vs validation),
// reader_validation_mode (présentiel/à distance/aucun), membership_enabled
// (système de cotisation on/off) — tous sur `libraries`, lisibles+éditables sur
// la biblio pré-active (policies libraries_staff_read / libraries_staff_update).
// Les barèmes de cotisation détaillés (library_membership_rules) se règlent après
// activation dans Biblioteca. Clés i18n réutilisées.
// ═══════════════════════════════════════════════════════════════════════════
export default function AtelierVolet6Adesao({ libraryId, canEdit }) {
  const { formatMessage: t } = useIntl();
  const { notifyError, notifySuccess } = useToast();
  const [lib, setLib] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase.from('libraries')
          .select('accepts_public_signup, reader_validation_mode, membership_enabled')
          .eq('id', libraryId).maybeSingle();
        if (!cancelled) setLib(data || {});
      } catch { if (!cancelled) setLib({}); }
    })();
    return () => { cancelled = true; };
  }, [libraryId]);

  const save = useCallback(async (patch) => {
    setLib(prev => ({ ...prev, ...patch }));
    setSaving(true);
    try {
      const { error } = await supabase.from('libraries').update(patch).eq('id', libraryId);
      if (error) throw error;
      notifySuccess(t({ id: 'atelier.toast.saved' }));
    } catch (e) { notifyError(localizeError(e, t)); }
    finally { setSaving(false); }
  }, [libraryId, notifyError, notifySuccess, t]);

  if (!lib) return null;
  const dis = !canEdit || saving;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start', fontSize: '.84rem' }}>
        <input type="checkbox" checked={lib.accepts_public_signup || false} disabled={dis} style={{ marginTop: 3 }}
          onChange={e => save({ accepts_public_signup: e.target.checked })} />
        <span>
          <span>{t({ id: 'biblioteca.readerIdentity.publicSignup' })}</span><br />
          <span style={{ fontSize: '.8rem', color: 'var(--brand-muted)' }}>{t({ id: 'biblioteca.readerIdentity.publicSignup.hint' })}</span>
        </span>
      </label>
      <div className="ab-atl-field">
        <label>{t({ id: 'biblioteca.readerIdentity.mode' })}</label>
        <select value={lib.reader_validation_mode || 'presential'} disabled={dis} onChange={e => save({ reader_validation_mode: e.target.value })}>
          <option value="presential">{t({ id: 'biblioteca.readerIdentity.mode.presential' })}</option>
          <option value="remote">{t({ id: 'biblioteca.readerIdentity.mode.remote' })}</option>
          <option value="none">{t({ id: 'biblioteca.readerIdentity.mode.none' })}</option>
        </select>
      </div>
      <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: '.84rem' }}>
        <input type="checkbox" checked={lib.membership_enabled || false} disabled={dis}
          onChange={e => save({ membership_enabled: e.target.checked })} />
        {t({ id: 'membership.config.enabled' })}
      </label>
    </div>
  );
}
