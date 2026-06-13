import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';

// ═══════════════════════════════════════════════════════════════════════════
// AtelierVolet7Emails — ONBO-Q2 Lot 3
// Volet 7 « E-mails » : identité d'envoi e-mail de la biblio, sur library_commons
// (contact_email = adresse d'envoi, reply_to_email, email_delivery_mode :
// normal | test_only | disabled). Édité sur la biblio pré-active : l'UPDATE passe
// par library_commons_staff_update, et la lecture par la policy dédiée
// library_commons_staff_read (migration 20260613134350) — sans quoi
// fn_library_visible_to_caller bloquerait le SELECT (is_active=true exigé).
// Sauvegarde au blur (champs) / au change (mode), toast de confirmation.
// Clés i18n réutilisées (biblioteca.comms.*).
// ═══════════════════════════════════════════════════════════════════════════
export default function AtelierVolet7Emails({ libraryId, canEdit }) {
  const { formatMessage: t } = useIntl();
  const { notifyError, notifySuccess } = useToast();
  const [lc, setLc] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase.from('library_commons')
          .select('contact_email, reply_to_email, email_delivery_mode')
          .eq('library_id', libraryId).maybeSingle();
        if (!cancelled) setLc(data || {});
      } catch { if (!cancelled) setLc({}); }
    })();
    return () => { cancelled = true; };
  }, [libraryId]);

  const save = useCallback(async (patch) => {
    setLc(prev => ({ ...prev, ...patch }));
    setSaving(true);
    try {
      const { error } = await supabase.from('library_commons').update(patch).eq('library_id', libraryId);
      if (error) throw error;
      notifySuccess(t({ id: 'atelier.toast.saved' }));
    } catch (e) { notifyError(localizeError(e, t)); }
    finally { setSaving(false); }
  }, [libraryId, notifyError, notifySuccess, t]);

  if (!lc) return null;
  const dis = !canEdit || saving;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div className="ab-atl-field">
        <label>{t({ id: 'biblioteca.comms.sendEmail' })}</label>
        <input type="email" defaultValue={lc.contact_email || ''} disabled={dis}
          placeholder="contato@biblioteca.org"
          onBlur={e => save({ contact_email: e.target.value.trim() || null })} />
      </div>
      <div className="ab-atl-field">
        <label>{t({ id: 'biblioteca.identity.replyEmail' })}</label>
        <input type="email" defaultValue={lc.reply_to_email || ''} disabled={dis}
          placeholder="resposta@biblioteca.org"
          onBlur={e => save({ reply_to_email: e.target.value.trim() || null })} />
      </div>
      <div className="ab-atl-field">
        <label>{t({ id: 'biblioteca.comms.sendMode' })}</label>
        <select value={lc.email_delivery_mode || 'normal'} disabled={dis}
          onChange={e => save({ email_delivery_mode: e.target.value })}>
          <option value="normal">{t({ id: 'biblioteca.comms.sendMode.normal' })}</option>
          <option value="test_only">{t({ id: 'biblioteca.comms.sendMode.test_only' })}</option>
          <option value="disabled">{t({ id: 'biblioteca.comms.sendMode.disabled' })}</option>
        </select>
      </div>
    </div>
  );
}
