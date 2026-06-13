import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';

// ═══════════════════════════════════════════════════════════════════════════
// AtelierVolet4Catalogacao — ONBO-Q2 (refonte structurée)
// Volet 4 « Catalogação » : aide à la décision structurée, sur `libraries`
// (édité sur la biblio pré-active via libraries_staff_read/_update du Lot 1) —
//   1) système de cote/classification (cataloging_classification_system),
//   2) champs obligatoires à la catalogation (cataloging_mandatory_fields, text[],
//      clés alignées sur catalogacao.field.*),
//   3) notes libres complémentaires (cataloging_policy_notes).
// Le catalog_mode lui-même est choisi au volet 0. Alimente le regimento (volet 10).
// Sauvegarde au change (select/cases) / au blur (notes), toast de confirmation.
// ═══════════════════════════════════════════════════════════════════════════

// Valeurs alignées sur le CHECK libraries_cataloging_classification_system_chk.
const CLASSIF = ['adhoc', 'cdd', 'cdu', 'thematic', 'other'];
// Clés alignées sur catalogacao.field.* (libellés réutilisés).
const MANDATORY = ['author', 'title', 'year', 'publisher', 'isbn', 'language', 'subjects', 'edition'];

export default function AtelierVolet4Catalogacao({ libraryId, canEdit }) {
  const { formatMessage: t } = useIntl();
  const { notifyError, notifySuccess } = useToast();
  const [lib, setLib] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase.from('libraries')
          .select('cataloging_classification_system, cataloging_mandatory_fields, cataloging_policy_notes')
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
  const selected = new Set(lib.cataloging_mandatory_fields || []);

  const toggleField = (f) => {
    const next = new Set(selected);
    if (next.has(f)) next.delete(f); else next.add(f);
    save({ cataloging_mandatory_fields: MANDATORY.filter(k => next.has(k)) });
  };

  const taStyle = {
    width: '100%', padding: '9px 12px', borderRadius: 9,
    border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))',
    background: 'rgba(0,0,0,.3)', color: 'var(--brand-text,#f4f1ee)',
    fontFamily: 'inherit', fontSize: '.84rem', resize: 'vertical', lineHeight: 1.5,
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
      {/* 1. Système de cote / classification */}
      <div className="ab-atl-field">
        <label>{t({ id: 'atelier.volet4.classifSystem' })}</label>
        <select value={lib.cataloging_classification_system || ''} disabled={dis}
          onChange={e => save({ cataloging_classification_system: e.target.value || null })}>
          <option value="">—</option>
          {CLASSIF.map(c => <option key={c} value={c}>{t({ id: `atelier.volet4.classif.${c}` })}</option>)}
        </select>
      </div>

      {/* 2. Champs obligatoires à la catalogation */}
      <div>
        <label style={{ display: 'block', marginBottom: 8, fontSize: '.84rem', color: 'var(--brand-text,#f4f1ee)' }}>
          {t({ id: 'atelier.volet4.mandatoryFields' })}
        </label>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))', gap: '6px 14px' }}>
          {MANDATORY.map(f => (
            <label key={f} style={{ display: 'flex', gap: 7, alignItems: 'center', fontSize: '.82rem' }}>
              <input type="checkbox" checked={selected.has(f)} disabled={dis} onChange={() => toggleField(f)} />
              {t({ id: `catalogacao.field.${f}` })}
            </label>
          ))}
        </div>
      </div>

      {/* 3. Notes complémentaires */}
      <div className="ab-atl-field">
        <label>{t({ id: 'atelier.volet4.notes' })}</label>
        <textarea
          defaultValue={lib.cataloging_policy_notes || ''} disabled={dis} rows={5} style={taStyle}
          placeholder={t({ id: 'atelier.volet_4_catalogacao.sub' })}
          onBlur={e => save({ cataloging_policy_notes: e.target.value.trim() || null })}
        />
      </div>
    </div>
  );
}
