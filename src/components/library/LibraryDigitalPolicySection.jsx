import { useEffect, useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';
import { useConfirm } from '@/contexts/ConfirmContext';

// ═══════════════════════════════════════════════════════════════════════════
// LibraryDigitalPolicySection — lecture publique d'œuvres sous droits
// (Xavier, 04/10/2026 : « réglage de bibliothèque » ; migration 20261005092916).
//
// Par défaut, une œuvre sous droits ne se lit en ligne que par les lecteur·rices
// des bibliothèques qui la détiennent. La bibliothèque peut choisir de l'ouvrir
// à tout le monde (œuvre déjà librement trouvable en ligne, par exemple) : le
// formulaire de dépôt proposera alors cette option, avec un avertissement et une
// justification. Ce choix engage sa responsabilité légale : seule sa
// coordination le change (la base le garde : trg_libraries_digital_policy_coord_only).
// Props : libraryId (uuid), canEdit (bool : coordination).
// ═══════════════════════════════════════════════════════════════════════════

export default function LibraryDigitalPolicySection({ libraryId, canEdit = false }) {
  const { formatMessage: t } = useIntl();
  const { notifySuccess, notifyError } = useToast();
  const confirmer = useConfirm();
  const [ouverte, setOuverte] = useState(null);   // null : en chargement
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let annule = false;
    if (!libraryId) return undefined;
    supabase.from('libraries').select('digital_public_under_rights').eq('id', libraryId).maybeSingle()
      .then(({ data, error }) => { if (!annule) setOuverte(error ? false : !!data?.digital_public_under_rights); });
    return () => { annule = true; };
  }, [libraryId]);

  async function basculer(valeur) {
    if (valeur) {
      const ok = await confirmer({
        title: t({ id: 'library.digitalPolicy.title' }),
        message: t({ id: 'library.digitalPolicy.confirm' }),
        confirmLabel: t({ id: 'library.digitalPolicy.confirmLabel' }),
        tone: 'danger',
      });
      if (!ok) return;
    }
    setSaving(true);
    try {
      const { data, error } = await supabase.from('libraries')
        .update({ digital_public_under_rights: valeur }).eq('id', libraryId).select('digital_public_under_rights');
      if (error) throw error;
      if (!data?.length) throw new Error(t({ id: 'error.library.digital_policy_coord_only' }));
      setOuverte(!!data[0].digital_public_under_rights);
      notifySuccess(t({ id: valeur ? 'library.digitalPolicy.opened' : 'library.digitalPolicy.closed' }));
    } catch (e) {
      notifyError(localizeError(e, t), e);
    } finally { setSaving(false); }
  }

  if (ouverte === null) return null;
  return (
    <div style={{ padding: 16, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 12 }}>
      <div style={{ fontSize: '.95rem', fontWeight: 600, marginBottom: 8 }}>{t({ id: 'library.digitalPolicy.title' })}</div>
      <p style={{ fontSize: '.84rem', color: 'var(--brand-muted)', margin: '0 0 10px', lineHeight: 1.5 }}>
        {t({ id: 'library.digitalPolicy.body' })}
      </p>
      <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start', fontSize: '.86rem', cursor: canEdit ? 'pointer' : 'default' }}>
        <input type="checkbox" checked={ouverte} disabled={!canEdit || saving} style={{ marginTop: 3 }}
          onChange={(e) => basculer(e.target.checked)} />
        <span>{t({ id: 'library.digitalPolicy.toggle' })}</span>
      </label>
      {!canEdit && (
        <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)', marginTop: 6 }}>{t({ id: 'library.digitalPolicy.coordOnly' })}</div>
      )}
    </div>
  );
}
