import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';
import LocaleSelector from '@/components/library/LocaleSelector';
import LibraryContactProfileSection from '@/components/library/LibraryContactProfileSection';

// ═══════════════════════════════════════════════════════════════════════════
// AtelierVolet1Identite — ONBO-Q2 Lot 2
// Volet 1 « Identité » câblé sur la biblio PRÉ-ACTIVE : première vraie édition de
// config depuis l'atelier de constitution (fin des leurres). On édite la langue
// d'identité (libraries.default_locale) et le profil de contact
// (library_contact_profiles) via les composants/RLS existants, scopés à la biblio
// provisionnée pré-active (is_active=false) — éditable car la coordinatrice y a une
// membership coordenador active (cf. fn_provision_preactive_library + policies
// libraries_staff_read / can_manage_library_contact_profile, toutes staff-based).
//
// NB : les assets visuels (LibraryVisualAssetsSection) passent par storage bucket +
// RPC thèmes → audit RLS pré-active dédié, reporté au Lot 3.
// ═══════════════════════════════════════════════════════════════════════════
export default function AtelierVolet1Identite({ libraryId, canEdit }) {
  const { formatMessage: t } = useIntl();
  const { notifyError } = useToast();
  const [locale, setLocale] = useState(null);
  const [savingLocale, setSavingLocale] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase.from('libraries').select('default_locale').eq('id', libraryId).single();
        if (!cancelled) setLocale(data?.default_locale || 'pt-BR');
      } catch { if (!cancelled) setLocale('pt-BR'); }
    })();
    return () => { cancelled = true; };
  }, [libraryId]);

  const onLocaleChange = useCallback(async (loc) => {
    setLocale(loc);
    setSavingLocale(true);
    try {
      const { error } = await supabase.from('libraries').update({ default_locale: loc }).eq('id', libraryId);
      if (error) throw error;
    } catch (e) { notifyError(localizeError(e, t)); }
    finally { setSavingLocale(false); }
  }, [libraryId, notifyError, t]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div className="ab-atl-field">
        <label>{t({ id: 'biblioteca.identity.defaultLocale' })}</label>
        <LocaleSelector value={locale} onChange={onLocaleChange} disabled={!canEdit || savingLocale} />
      </div>
      <LibraryContactProfileSection libraryId={libraryId} canEdit={canEdit} />
    </div>
  );
}
