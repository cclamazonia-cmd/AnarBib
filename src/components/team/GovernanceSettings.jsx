import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useLibrary } from '@/contexts/LibraryContext';

/**
 * GovernanceSettings — réglages de gouvernance de l'équipe (v2 saut collégial,
 * GOUV-14).
 *
 * Affiché dans l'onglet Équipe (scope library). Transparence P5 : tout le
 * staff VOIT les réglages ; seule la coordination (ou l'admin réseau) peut
 * basculer le saut collégial. `team_admission_mode` est montré en lecture
 * seule : changer le quorum d'admission est une décision non outillée à ce
 * jour (elle se règle en base, sur décision du collectif — précédent v1).
 *
 * La bascule écrit directement `libraries.allow_direct_coordenador` (motif
 * établi : membership_enabled, deposit_enabled — RLS coordenador+). La
 * confirmation reprend le « prix du saut » de la spec §5.3 : c'est un choix
 * politique du collectif, pas une préférence d'affichage.
 */
export default function GovernanceSettings({ libraryId }) {
  const { formatMessage: t } = useIntl();
  const { effectiveRole } = useLibrary();
  const canToggle = effectiveRole === 'coordenador' || effectiveRole === 'network_admin';

  const [settings, setSettings] = useState(null); // { team_admission_mode, allow_direct_coordenador }
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });

  const load = useCallback(async () => {
    if (!libraryId) return;
    const { data, error } = await supabase
      .from('libraries')
      .select('team_admission_mode, allow_direct_coordenador')
      .eq('id', libraryId)
      .maybeSingle();
    if (!error && data) setSettings(data);
  }, [libraryId]);

  useEffect(() => { load(); }, [load]);

  async function toggleDirectCoord() {
    if (!settings || saving) return;
    const next = !(settings.allow_direct_coordenador === true);
    const confirmMsg = t({ id: next
      ? 'team.governance.directCoord.confirmOn'
      : 'team.governance.directCoord.confirmOff' });
    if (!window.confirm(confirmMsg)) return;
    setSaving(true);
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase
        .from('libraries')
        .update({ allow_direct_coordenador: next })
        .eq('id', libraryId);
      if (error) throw error;
      setSettings(prev => ({ ...prev, allow_direct_coordenador: next }));
      setMsg({ text: t({ id: next ? 'team.governance.directCoord.msgOn' : 'team.governance.directCoord.msgOff' }), kind: 'ok' });
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  if (!settings) return null;

  const admissionKey = ['cosignature', 'coordenador_seul', 'assemblee'].includes(settings.team_admission_mode)
    ? `team.governance.admissionMode.${settings.team_admission_mode}`
    : 'team.governance.admissionMode.cosignature';
  const directOn = settings.allow_direct_coordenador === true;

  return (
    <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, padding: '12px 16px', marginBottom: 16 }}>
      <div style={{ fontSize: '.8rem', fontWeight: 700, color: 'var(--brand-muted)', textTransform: 'uppercase', letterSpacing: '.04em', marginBottom: 8 }}>
        {t({ id: 'team.governance.title' })}
      </div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px 24px', alignItems: 'center' }}>
        <div style={{ fontSize: '.88rem' }}>
          {t({ id: 'team.governance.admissionMode.label' })}{' '}
          <span style={{ fontWeight: 600 }}>{t({ id: admissionKey })}</span>
        </div>
        <div style={{ fontSize: '.88rem', display: 'flex', alignItems: 'center', gap: 8 }}>
          {t({ id: 'team.governance.directCoord.label' })}{' '}
          <span style={{ fontWeight: 600 }}>
            {t({ id: directOn ? 'team.governance.directCoord.on' : 'team.governance.directCoord.off' })}
          </span>
          {canToggle && (
            <button
              className="cat-btn secondary"
              style={{ fontSize: '.75rem', padding: '3px 10px' }}
              onClick={toggleDirectCoord}
              disabled={saving}
            >
              {saving
                ? t({ id: 'common.loading' })
                : t({ id: directOn ? 'team.governance.directCoord.disable' : 'team.governance.directCoord.enable' })}
            </button>
          )}
        </div>
      </div>
      <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)', marginTop: 6 }}>
        {t({ id: 'team.governance.directCoord.help' })}
      </div>
      {msg.text && (
        <div style={{ marginTop: 8, fontSize: '.85rem', color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>
          {msg.text}
        </div>
      )}
    </div>
  );
}
