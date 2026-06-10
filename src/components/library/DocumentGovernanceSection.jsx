import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// =============================================================================
// DocumentGovernanceSection (EA-08, chantier-cadre Biblioteca, 21/05/2026)
// =============================================================================
// Éditeur de la politique de gouvernance documentale d'une biblioteca.
// Restaure la fonctionnalité du HTML d'origine (bloc documentos) absente du
// JSX — cf. docs/journal/chantiers/CHANTIER_audit_biblioteca_parite_doctrinale_2026-05-21.md
//
// Doctrine actée (21/05) : gouvernance documentale = attribut LOCAL par
// biblioteca. Chaque biblioteca est souveraine sur ses conditions de
// mutualisation.
//
// Structure du config (jsonb dans library_document_governance.config),
// fidèle au schéma du formulaire HTML d'origine :
//   config.document_requests = {
//     allow_correction_requests, allow_local_copy_requests,
//     allow_digital_link_requests, notes
//   }
//   config.interlibrary_exchange = {
//     enabled, mutualization_only, require_available_now,
//     min_total_copies, min_available_copies,
//     policy_note, guardrail_note, notes
//   }
//
// Note : le champ « observação geral » (govNetworkNote du HTML) est écrit
// AUX DEUX clés document_requests.notes ET interlibrary_exchange.notes,
// comportement fidèle au HTML d'origine (collectGovernancePayload).
//
// Doctrine RPC v3 (21/05) :
//   - lecture du config : supabase.from() simple, autorisé (lecture protégée RLS)
//   - écriture : RPC upsert_library_document_governance (action DB → RPC obligatoire)
// =============================================================================

// Valeurs par défaut, conventions du HTML d'origine :
//   allow_* et enabled : !== false → cochés par défaut si absents
//   mutualization_only : === true  → décoché par défaut
//   require_available_now : !== false → coché par défaut
//   min_total_copies : défaut 2, plancher 2
//   min_available_copies : défaut 2, plancher 1
function normalizeConfig(rawConfig) {
  const cfg = rawConfig && typeof rawConfig === 'object' ? rawConfig : {};
  const dr = cfg.document_requests && typeof cfg.document_requests === 'object'
    ? cfg.document_requests : {};
  const ie = cfg.interlibrary_exchange && typeof cfg.interlibrary_exchange === 'object'
    ? cfg.interlibrary_exchange : {};

  return {
    allow_correction_requests:   dr.allow_correction_requests !== false,
    allow_local_copy_requests:   dr.allow_local_copy_requests !== false,
    allow_digital_link_requests: dr.allow_digital_link_requests !== false,
    enabled:                     ie.enabled !== false,
    mutualization_only:          ie.mutualization_only === true,
    require_available_now:       ie.require_available_now !== false,
    min_total_copies:            Math.max(2, Number(ie.min_total_copies || 2) || 2),
    min_available_copies:        Math.max(1, Number(ie.min_available_copies || 2) || 2),
    policy_note:                 typeof ie.policy_note === 'string' ? ie.policy_note : '',
    guardrail_note:              typeof ie.guardrail_note === 'string' ? ie.guardrail_note : '',
    // notes : on lit en priorité document_requests.notes, sinon interlibrary_exchange.notes
    network_note: (typeof dr.notes === 'string' && dr.notes)
      ? dr.notes
      : (typeof ie.notes === 'string' ? ie.notes : ''),
  };
}

// Reconstruit l'objet config jsonb à partir de l'état du formulaire,
// en préservant les clés inconnues éventuelles du config existant (merge).
function buildConfigPayload(form, existingConfig) {
  const base = existingConfig && typeof existingConfig === 'object'
    ? JSON.parse(JSON.stringify(existingConfig)) : {};

  const networkNote = form.network_note.trim() || null;

  base.document_requests = {
    ...(base.document_requests && typeof base.document_requests === 'object' ? base.document_requests : {}),
    allow_correction_requests:   form.allow_correction_requests,
    allow_local_copy_requests:   form.allow_local_copy_requests,
    allow_digital_link_requests: form.allow_digital_link_requests,
    notes: networkNote,
  };

  base.interlibrary_exchange = {
    ...(base.interlibrary_exchange && typeof base.interlibrary_exchange === 'object' ? base.interlibrary_exchange : {}),
    enabled:               form.enabled,
    mutualization_only:    form.mutualization_only,
    require_available_now: form.require_available_now,
    min_total_copies:      Math.max(2, Number(form.min_total_copies || 2) || 2),
    min_available_copies:  Math.max(1, Number(form.min_available_copies || 2) || 2),
    policy_note:           form.policy_note.trim() || null,
    guardrail_note:        form.guardrail_note.trim() || null,
    notes:                 networkNote,
  };

  return base;
}

export default function DocumentGovernanceSection({ libraryId, canEdit }) {
  const { formatMessage: t } = useIntl();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [existingConfig, setExistingConfig] = useState(null);
  const [form, setForm] = useState(() => normalizeConfig({}));

  // ── Chargement du config (lecture simple .from(), doctrine RPC v3) ────────
  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    setMsg({ text: '', kind: '' });
    try {
      const { data, error } = await supabase
        .from('library_document_governance')
        .select('config')
        .eq('library_id', libraryId)
        .maybeSingle();
      if (error) throw error;
      const cfg = data?.config || {};
      setExistingConfig(cfg);
      setForm(normalizeConfig(cfg));
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [libraryId, t]);

  useEffect(() => { load(); }, [load]);

  // ── Sauvegarde via RPC upsert_library_document_governance ─────────────────
  async function save() {
    if (!canEdit) return;
    setSaving(true);
    setMsg({ text: '', kind: '' });
    try {
      const payload = buildConfigPayload(form, existingConfig);
      const { error } = await supabase.rpc('upsert_library_document_governance', {
        p_library_id: libraryId,
        p_config: payload,
      });
      if (error) throw error;
      setExistingConfig(payload);
      setMsg({ text: t({ id: 'biblioteca.documents.governance.saved' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // helper de mise à jour d'un champ
  const setField = (key, value) => setForm(f => ({ ...f, [key]: value }));

  // ── Styles (locaux au composant, cohérents avec le thème sombre AnarBib) ──
  const styles = useMemo(() => ({
    card: {
      padding: 16, borderRadius: 10,
      background: 'rgba(255,255,255,.03)',
      border: '1px solid rgba(255,255,255,.08)',
      marginBottom: 12,
    },
    cardTitle: {
      fontSize: '.95rem', fontWeight: 600, marginBottom: 10,
      display: 'flex', alignItems: 'center', gap: 6,
    },
    check: {
      display: 'flex', alignItems: 'center', gap: 8,
      fontSize: '.88rem', marginBottom: 8, cursor: canEdit ? 'pointer' : 'default',
    },
    fieldLabel: {
      display: 'block', fontSize: '.78rem',
      color: 'var(--brand-muted, #ccc)', marginBottom: 4,
    },
    input: {
      width: '100%', padding: '8px 10px', borderRadius: 8,
      border: '1px solid rgba(255,255,255,.12)',
      background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem',
    },
    textarea: {
      width: '100%', padding: '8px 10px', borderRadius: 8,
      border: '1px solid rgba(255,255,255,.12)',
      background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem',
      resize: 'vertical', minHeight: 52, fontFamily: 'inherit',
    },
  }), [canEdit]);

  if (loading) {
    return <div style={{ fontSize: '.88rem', color: 'var(--brand-muted)' }}>
      {t({ id: 'common.loading' })}
    </div>;
  }

  return (
    <div>
      <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginBottom: 14 }}>
        {t({ id: 'biblioteca.documents.governance.intro' })}
      </div>

      {/* ── Carte 1 : Pedidos documentais ───────────────────────────────── */}
      <div style={styles.card}>
        <div style={styles.cardTitle}>
          {t({ id: 'biblioteca.documents.governance.requestsTitle' })}
        </div>
        <label style={styles.check}>
          <input type="checkbox" disabled={!canEdit}
            checked={form.allow_correction_requests}
            onChange={e => setField('allow_correction_requests', e.target.checked)} />
          {t({ id: 'biblioteca.documents.governance.allowCorrection' })}
        </label>
        <label style={styles.check}>
          <input type="checkbox" disabled={!canEdit}
            checked={form.allow_local_copy_requests}
            onChange={e => setField('allow_local_copy_requests', e.target.checked)} />
          {t({ id: 'biblioteca.documents.governance.allowLocalCopy' })}
        </label>
        <label style={{ ...styles.check, marginBottom: 0 }}>
          <input type="checkbox" disabled={!canEdit}
            checked={form.allow_digital_link_requests}
            onChange={e => setField('allow_digital_link_requests', e.target.checked)} />
          {t({ id: 'biblioteca.documents.governance.allowDigitalLink' })}
        </label>
      </div>

      {/* ── Carte 2 : Trocas interbibliotecas ───────────────────────────── */}
      <div style={styles.card}>
        <div style={styles.cardTitle}>
          {t({ id: 'biblioteca.documents.governance.exchangeTitle' })}
        </div>
        <label style={styles.check}>
          <input type="checkbox" disabled={!canEdit}
            checked={form.enabled}
            onChange={e => setField('enabled', e.target.checked)} />
          {t({ id: 'biblioteca.documents.governance.allowExchange' })}
        </label>
        <label style={styles.check}>
          <input type="checkbox" disabled={!canEdit}
            checked={form.mutualization_only}
            onChange={e => setField('mutualization_only', e.target.checked)} />
          {t({ id: 'biblioteca.documents.governance.mutualizationOnly' })}
        </label>
        <label style={{ ...styles.check, marginBottom: 12 }}>
          <input type="checkbox" disabled={!canEdit}
            checked={form.require_available_now}
            onChange={e => setField('require_available_now', e.target.checked)} />
          {t({ id: 'biblioteca.documents.governance.requireAvailableNow' })}
        </label>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div>
            <label style={styles.fieldLabel}>
              {t({ id: 'biblioteca.documents.governance.minTotalCopies' })}
            </label>
            <input type="number" min={2} step={1} disabled={!canEdit}
              style={styles.input}
              value={form.min_total_copies}
              onChange={e => setField('min_total_copies', e.target.value)} />
          </div>
          <div>
            <label style={styles.fieldLabel}>
              {t({ id: 'biblioteca.documents.governance.minAvailableCopies' })}
            </label>
            <input type="number" min={1} step={1} disabled={!canEdit}
              style={styles.input}
              value={form.min_available_copies}
              onChange={e => setField('min_available_copies', e.target.value)} />
          </div>
        </div>
      </div>

      {/* ── Carte 3 : Observações ───────────────────────────────────────── */}
      <div style={styles.card}>
        <div style={styles.cardTitle}>
          {t({ id: 'biblioteca.documents.governance.notesTitle' })}
        </div>
        <div style={{ marginBottom: 10 }}>
          <label style={styles.fieldLabel}>
            {t({ id: 'biblioteca.documents.governance.policyNote' })}
          </label>
          <textarea disabled={!canEdit} style={styles.textarea}
            placeholder={t({ id: 'biblioteca.documents.governance.policyNotePlaceholder' })}
            value={form.policy_note}
            onChange={e => setField('policy_note', e.target.value)} />
        </div>
        <div style={{ marginBottom: 10 }}>
          <label style={styles.fieldLabel}>
            {t({ id: 'biblioteca.documents.governance.guardrailNote' })}
          </label>
          <textarea disabled={!canEdit} style={styles.textarea}
            placeholder={t({ id: 'biblioteca.documents.governance.guardrailNotePlaceholder' })}
            value={form.guardrail_note}
            onChange={e => setField('guardrail_note', e.target.value)} />
        </div>
        <div>
          <label style={styles.fieldLabel}>
            {t({ id: 'biblioteca.documents.governance.networkNote' })}
          </label>
          <textarea disabled={!canEdit} style={styles.textarea}
            placeholder={t({ id: 'biblioteca.documents.governance.networkNotePlaceholder' })}
            value={form.network_note}
            onChange={e => setField('network_note', e.target.value)} />
        </div>
      </div>

      {/* ── Actions ─────────────────────────────────────────────────────── */}
      {canEdit && (
        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
          <button className="cat-btn secondary" onClick={load} disabled={saving}
            style={{ fontSize: '.88rem' }}>
            {t({ id: 'biblioteca.documents.governance.reload' })}
          </button>
          <button className="cat-btn primary" onClick={save} disabled={saving}
            style={{ fontSize: '.88rem' }}>
            {saving
              ? t({ id: 'common.saving' })
              : t({ id: 'biblioteca.documents.governance.save' })}
          </button>
        </div>
      )}

      {msg.text && (
        <div style={{
          marginTop: 10, fontSize: '.85rem',
          color: msg.kind === 'ok' ? '#7ee0a8' : '#e89090',
        }}>
          {msg.text}
        </div>
      )}
    </div>
  );
}
