import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';

// ═══════════════════════════════════════════════════════════════════════════
// AtelierVolet7Emails — ONBO-Q2 Lot 3
// Volet 7 « E-mails » : identité d'envoi e-mail de la biblio.
//   • contact_email / reply_to_email  → library_commons. Édité sur la biblio
//     pré-active : l'UPDATE passe par library_commons_staff_update et la lecture
//     par library_commons_staff_read (migration 20260613134350) — sans quoi
//     fn_library_visible_to_caller bloquerait le SELECT (is_active=true exigé).
//   • transport + envois actifs       → library_mail_channels.
//
// INTERRUPTEUR-UNIQUE (30/08/2026). Ce volet pilotait `email_delivery_mode`
// (normal | test_only | disabled) sur library_commons. Cette colonne n'est
// appliquée NULLE PART : ni les fonctions notify-*, qui passent toutes par
// safeSendEmail → transportDisabledReason, ni register ne la lisent pour
// décider d'un envoi. Une coordination qui choisissait « Desativado » ne coupait
// donc rien du tout, et n'avait aucun moyen de s'en apercevoir. Le piège tenait
// à la valeur `disabled`, partagée avec le vrai commutateur alors que les deux
// colonnes ne décrivent pas la même chose (volume d'envoi vs transport).
//
// On pilote désormais le seul commutateur réellement honoré,
// library_mail_channels : `active` coupe, `delivery_mode` choisit le transport.
// L'écriture passe par la RPC upsert_library_mail_channel — la seule voie qui
// CRÉE la ligne de canal quand elle manque, ce qui est le cas courant d'une
// biblio encore en constitution. Attention : cette RPC remplace la ligne
// entière, jamais un champ isolé — d'où la fusion explicite ci-dessous avec la
// ligne déjà chargée.
//
// Sauvegarde au blur (champs) / au change (transport, interrupteur), toast de
// confirmation. Clés i18n réutilisées (biblioteca.comms.*).
// ═══════════════════════════════════════════════════════════════════════════
export default function AtelierVolet7Emails({ libraryId, canEdit }) {
  const { formatMessage: t } = useIntl();
  const { notifyError, notifySuccess } = useToast();
  const [lc, setLc] = useState(null);
  const [mc, setMc] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [commonsR, channelR] = await Promise.all([
          supabase.from('library_commons')
            .select('contact_email, reply_to_email')
            .eq('library_id', libraryId).maybeSingle(),
          supabase.from('library_mail_channels')
            .select('*')
            .eq('library_id', libraryId).maybeSingle(),
        ]);
        if (!cancelled) { setLc(commonsR.data || {}); setMc(channelR.data || {}); }
      } catch { if (!cancelled) { setLc({}); setMc({}); } }
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

  // La RPC écrit la ligne entière : on part de la ligne chargée et on n'y
  // superpose que le champ édité, sinon un simple changement de transport
  // effacerait les adresses de notification déjà saisies.
  const saveChannel = useCallback(async (patch) => {
    const next = { ...(mc || {}), ...patch };
    setMc(next);
    setSaving(true);
    try {
      const { error } = await supabase.rpc('upsert_library_mail_channel', {
        p_library_id: libraryId,
        p_channel: {
          delivery_mode: next.delivery_mode || 'platform_shared',
          admin_notification_email: next.admin_notification_email || null,
          weekly_report_email: next.weekly_report_email || null,
          severe_alert_email: next.severe_alert_email || null,
          transport_state: next.transport_state || 'not_tested',
          transport_channel: next.transport_channel || null,
          last_tested_at: next.last_tested_at || null,
          active: next.active !== false,
        },
      });
      if (error) throw error;
      notifySuccess(t({ id: 'atelier.toast.saved' }));
    } catch (e) { notifyError(localizeError(e, t)); }
    finally { setSaving(false); }
  }, [libraryId, mc, notifyError, notifySuccess, t]);

  if (!lc || !mc) return null;
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
        <label>{t({ id: 'biblioteca.comms.transport' })}</label>
        <select value={mc.delivery_mode || 'platform_shared'} disabled={dis}
          onChange={e => saveChannel({ delivery_mode: e.target.value })}>
          <option value="platform_shared">{t({ id: 'biblioteca.comms.transport.platform_shared' })}</option>
          <option value="platform_shared_local_reply">{t({ id: 'biblioteca.comms.transport.platform_shared_local_reply' })}</option>
          <option value="library_own_transport">{t({ id: 'biblioteca.comms.transport.library_own_transport' })}</option>
        </select>
      </div>
      <div className="ab-atl-field">
        <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start' }}>
          <input type="checkbox" checked={mc.active !== false} disabled={dis}
            onChange={e => saveChannel({ active: e.target.checked })} style={{ marginTop: 3 }} />
          <span>
            <span>{t({ id: 'biblioteca.comms.channelActive' })}</span><br />
            <span style={{ fontSize: '.8rem', color: 'var(--brand-muted)', fontWeight: 400 }}>
              {t({ id: 'biblioteca.comms.channelActive.hint' })}
            </span>
          </span>
        </label>
      </div>
    </div>
  );
}
