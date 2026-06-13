import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';

// ═══════════════════════════════════════════════════════════════════════════
// AtelierVolet4Catalogacao — ONBO-Q2 Lot 3
// Volet 4 « Catalogação » : champ texte libre où le collectif consigne sa
// politique de catalogage (système de classification, champs obligatoires,
// conventions de nommage…). libraries.cataloging_policy_notes, édité sur la
// biblio pré-active (policies libraries_staff_read / libraries_staff_update du
// Lot 1). Sauvegarde au blur, toast de confirmation. Le catalog_mode lui-même
// est déjà réglé au volet 0. Placeholder = sous-titre du volet (clé i18n
// réutilisée, pas de nouvelle clé).
// ═══════════════════════════════════════════════════════════════════════════
export default function AtelierVolet4Catalogacao({ libraryId, canEdit }) {
  const { formatMessage: t } = useIntl();
  const { notifyError, notifySuccess } = useToast();
  const [notes, setNotes] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase.from('libraries')
          .select('cataloging_policy_notes')
          .eq('id', libraryId).maybeSingle();
        if (!cancelled) setNotes(data?.cataloging_policy_notes || '');
      } catch { if (!cancelled) setNotes(''); }
    })();
    return () => { cancelled = true; };
  }, [libraryId]);

  const save = useCallback(async (value) => {
    setSaving(true);
    try {
      const { error } = await supabase.from('libraries')
        .update({ cataloging_policy_notes: value || null }).eq('id', libraryId);
      if (error) throw error;
      notifySuccess(t({ id: 'atelier.toast.saved' }));
    } catch (e) { notifyError(localizeError(e, t)); }
    finally { setSaving(false); }
  }, [libraryId, notifyError, notifySuccess, t]);

  if (notes === null) return null;
  const dis = !canEdit || saving;
  const taStyle = {
    width: '100%', padding: '9px 12px', borderRadius: 9,
    border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))',
    background: 'rgba(0,0,0,.3)', color: 'var(--brand-text,#f4f1ee)',
    fontFamily: 'inherit', fontSize: '.84rem', resize: 'vertical', lineHeight: 1.5,
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <textarea
        value={notes} disabled={dis} rows={7} style={taStyle}
        placeholder={t({ id: 'atelier.volet_4_catalogacao.sub' })}
        onChange={e => setNotes(e.target.value)}
        onBlur={e => save(e.target.value)}
      />
    </div>
  );
}
