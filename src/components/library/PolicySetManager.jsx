import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

// =============================================================================
// PolicySetManager (EA-05, chantier-cadre Biblioteca, 21/05/2026)
// =============================================================================
// Gestionnaire des jeux de règles de circulation (library_circulation_policy_sets)
// et de leurs règles (library_circulation_policy_rules).
//
// Restaure la fonctionnalité du HTML d'origine absente du JSX : le JSX ne
// montrait que le jeu ACTIF (.eq('is_active',true).maybeSingle()) sans aucun
// moyen de gérer les jeux. Cf. docs/journal/chantiers/CHANTIER_audit_biblioteca_...md
//
// Doctrine RPC v3 (21/05) :
//   - lecture jeux + règles : supabase.from() simple (lecture protégée RLS)
//   - écriture : RPC (action DB → RPC obligatoire)
//       upsert_library_circulation_policy_set(p_library_id, p_payload)
//       set_library_circulation_policy_set_active(p_policy_set_id)
//       upsert_library_circulation_policy_rule(p_policy_set_id, p_rule)
//       delete_library_circulation_policy_rule(p_rule_id)
//
// Arbitrage EA-05 (21/05) : champs techniques config_version / activation_note
// / metadata OMIS du formulaire (agencement plus clair). Les RPC les gèrent
// par défaut (config_version=1, le reste null).
//
// Périmètre des champs de règle : identique à l'éditeur inline historique de
// BibliotecaPage (loan_days, renewal_days, renewal_max_count, quantity_max,
// loan_allowed, renewable, public_note). circulation_mode reste au défaut RPC.
// =============================================================================

const SET_STATUSES = ['draft', 'active', 'archived'];

function emptySetForm() {
  return {
    id: null,
    label: '',
    status: 'draft',
    regulation_document_id: '',
    effective_from: '',
    effective_until: '',
    scope_note: '',
  };
}

function setRowToForm(row) {
  return {
    id: row.id,
    label: row.label || '',
    status: SET_STATUSES.includes(row.status) ? row.status : 'draft',
    regulation_document_id: row.regulation_document_id != null ? String(row.regulation_document_id) : '',
    effective_from: row.effective_from || '',
    effective_until: row.effective_until || '',
    scope_note: row.scope_note || '',
  };
}

export default function PolicySetManager({ libraryId, canEdit, regulationDocs = [], seedT }) {
  const { formatMessage: t } = useIntl();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });

  const [sets, setSets] = useState([]);
  const [rules, setRules] = useState([]);
  const [selectedSetId, setSelectedSetId] = useState(null);
  const [setForm, setSetForm] = useState(() => emptySetForm());
  const [editingRule, setEditingRule] = useState(null);

  // fallback si le parent ne passe pas seedT : identité simple
  const translateSeed = useMemo(() => {
    if (typeof seedT === 'function') return seedT;
    return (entity, fallbackField) => entity?.[fallbackField];
  }, [seedT]);

  // ── Chargement des jeux (lecture simple .from(), doctrine RPC v3) ─────────
  const loadSets = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    setMsg({ text: '', kind: '' });
    try {
      const { data, error } = await supabase
        .from('library_circulation_policy_sets')
        .select('*')
        .eq('library_id', libraryId)
        .order('is_active', { ascending: false })
        .order('updated_at', { ascending: false });
      if (error) throw error;
      const list = data || [];
      setSets(list);
      // Sélection par défaut : le jeu actif, sinon le premier
      setSelectedSetId(prev => {
        if (prev && list.some(s => s.id === prev)) return prev;
        const active = list.find(s => s.is_active);
        return active ? active.id : (list[0]?.id ?? null);
      });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [libraryId, t]);

  useEffect(() => { loadSets(); }, [loadSets]);

  // ── Chargement des règles du jeu sélectionné ──────────────────────────────
  const loadRules = useCallback(async (setId) => {
    if (!setId) { setRules([]); return; }
    try {
      const { data, error } = await supabase
        .from('library_circulation_policy_rules')
        .select('*')
        .eq('policy_set_id', setId)
        .order('priority', { ascending: true });
      if (error) throw error;
      setRules(data || []);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    }
  }, [t]);

  useEffect(() => {
    loadRules(selectedSetId);
    setEditingRule(null);
    // charger le jeu sélectionné dans le formulaire
    const row = sets.find(s => s.id === selectedSetId);
    setSetForm(row ? setRowToForm(row) : emptySetForm());
  }, [selectedSetId, sets, loadRules]);

  // ── Actions jeux ──────────────────────────────────────────────────────────

  function selectSet(id) {
    if (saving) return;
    setSelectedSetId(id);
  }

  function startNewSet() {
    if (saving) return;
    setSelectedSetId(null);
    setSetForm(emptySetForm());
    setRules([]);
    setEditingRule(null);
    setMsg({ text: '', kind: '' });
  }

  async function saveSet() {
    if (!canEdit) return;
    setSaving(true);
    setMsg({ text: '', kind: '' });
    try {
      const payload = {
        label: setForm.label.trim(),
        status: setForm.status,
        regulation_document_id: setForm.regulation_document_id || null,
        effective_from: setForm.effective_from || null,
        effective_until: setForm.effective_until || null,
        scope_note: setForm.scope_note.trim() || null,
      };
      if (setForm.id) payload.id = setForm.id;

      const { data, error } = await supabase.rpc('upsert_library_circulation_policy_set', {
        p_library_id: libraryId,
        p_payload: payload,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.policySets.setSaved' }), kind: 'ok' });
      const savedId = data?.id ?? null;
      await loadSets();
      if (savedId) setSelectedSetId(savedId);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  async function activateSet(setId) {
    if (!canEdit) return;
    setSaving(true);
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.rpc('set_library_circulation_policy_set_active', {
        p_policy_set_id: setId,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.policySets.setActivated' }), kind: 'ok' });
      await loadSets();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // ── Actions règles ────────────────────────────────────────────────────────

  function startNewRule() {
    if (saving || !selectedSetId) return;
    setEditingRule({
      id: null, rule_label: '', loan_days: null, renewal_days: null,
      renewal_max_count: null, quantity_max: null,
      loan_allowed: true, renewable: true, public_note: '',
    });
    setMsg({ text: '', kind: '' });
  }

  async function saveRule() {
    if (!canEdit || !editingRule || !selectedSetId) return;
    setSaving(true);
    setMsg({ text: '', kind: '' });
    try {
      const rule = {
        rule_label: (editingRule.rule_label || '').trim() || null,
        loan_days: editingRule.loan_days,
        renewal_days: editingRule.renewal_days,
        renewal_max_count: editingRule.renewal_max_count,
        quantity_max: editingRule.quantity_max,
        loan_allowed: editingRule.loan_allowed,
        renewable: editingRule.renewable,
        public_note: (editingRule.public_note || '').trim() || null,
      };
      if (editingRule.id) rule.id = editingRule.id;

      const { error } = await supabase.rpc('upsert_library_circulation_policy_rule', {
        p_policy_set_id: selectedSetId,
        p_rule: rule,
      });
      if (error) throw error;
      setEditingRule(null);
      setMsg({ text: t({ id: 'biblioteca.rules.saved' }), kind: 'ok' });
      await loadRules(selectedSetId);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  async function deleteRule(ruleId) {
    if (!canEdit || !ruleId) return;
    setSaving(true);
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.rpc('delete_library_circulation_policy_rule', {
        p_rule_id: ruleId,
      });
      if (error) throw error;
      setEditingRule(null);
      setMsg({ text: t({ id: 'biblioteca.rules.deleted' }), kind: 'ok' });
      await loadRules(selectedSetId);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  const setField = (key, value) => setSetForm(f => ({ ...f, [key]: value }));
  const setRuleField = (key, value) => setEditingRule(r => ({ ...r, [key]: value }));

  // ── Styles ────────────────────────────────────────────────────────────────
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
    setRow: (isSelected, isActive) => ({
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      gap: 8, padding: '10px 12px', borderRadius: 8, marginBottom: 6,
      background: 'rgba(0,0,0,.15)',
      border: isSelected
        ? '2px solid rgba(96,165,250,.6)'
        : (isActive ? '1px solid rgba(126,224,168,.3)' : '1px solid rgba(255,255,255,.06)'),
    }),
    pill: (kind) => ({
      fontSize: '.65rem', padding: '2px 8px', borderRadius: 6, marginLeft: 8,
      background: kind === 'active' ? 'rgba(126,224,168,.18)'
        : kind === 'archived' ? 'rgba(255,255,255,.06)' : 'rgba(255,255,255,.1)',
      color: kind === 'active' ? '#7ee0a8'
        : kind === 'archived' ? 'var(--brand-muted)' : '#ddd',
    }),
    fieldLabel: {
      display: 'block', fontSize: '.78rem',
      color: 'var(--brand-muted, #ccc)', marginBottom: 4,
    },
    input: {
      width: '100%', padding: '8px 10px', borderRadius: 8,
      border: '1px solid rgba(255,255,255,.12)',
      background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem',
    },
  }), []);

  if (loading) {
    return <div style={{ fontSize: '.88rem', color: 'var(--brand-muted)' }}>
      {t({ id: 'common.loading' })}
    </div>;
  }

  const selectedSet = sets.find(s => s.id === selectedSetId) || null;

  return (
    <div>
      {/* ── Liste des jeux ──────────────────────────────────────────────── */}
      <div style={styles.card}>
        <div style={styles.cardTitle}>
          {t({ id: 'biblioteca.policySets.listTitle' })}
        </div>
        <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginBottom: 10 }}>
          {t({ id: 'biblioteca.policySets.listHint' })}
        </div>
        {sets.length === 0 && (
          <div style={{ fontSize: '.88rem', color: 'var(--brand-muted)' }}>
            {t({ id: 'biblioteca.policySets.empty' })}
          </div>
        )}
        {sets.map(s => {
          const isSelected = s.id === selectedSetId;
          const statusKind = s.is_active ? 'active' : s.status;
          return (
            <div key={s.id} style={styles.setRow(isSelected, s.is_active)}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <span style={{ fontSize: '.9rem', fontWeight: 600 }}>
                  {translateSeed(s, 'label', 'set.label') || s.label}
                </span>
                <span style={styles.pill(statusKind)}>
                  {s.is_active
                    ? t({ id: 'biblioteca.policySets.statusInUse' })
                    : t({ id: `biblioteca.policySets.status.${s.status}`, defaultMessage: s.status })}
                </span>
              </div>
              <div style={{ display: 'flex', gap: 6 }}>
                {!isSelected && (
                  <button className="cat-btn secondary" onClick={() => selectSet(s.id)}
                    disabled={saving} style={{ fontSize: '.78rem', padding: '4px 10px' }}>
                    {t({ id: 'biblioteca.policySets.select' })}
                  </button>
                )}
                {isSelected && (
                  <span style={{ fontSize: '.78rem', color: 'var(--brand-muted)', alignSelf: 'center' }}>
                    {t({ id: 'biblioteca.policySets.selected' })}
                  </span>
                )}
                {canEdit && !s.is_active && s.status !== 'archived' && (
                  <button className="cat-btn primary" onClick={() => activateSet(s.id)}
                    disabled={saving} style={{ fontSize: '.78rem', padding: '4px 10px' }}>
                    {t({ id: 'biblioteca.policySets.putInUse' })}
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* ── Formulaire d'édition d'un jeu ───────────────────────────────── */}
      {canEdit && (
        <div style={styles.card}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <div style={styles.cardTitle}>
              {setForm.id
                ? t({ id: 'biblioteca.policySets.editTitle' })
                : t({ id: 'biblioteca.policySets.newTitle' })}
            </div>
            <button className="cat-btn secondary" onClick={startNewSet} disabled={saving}
              style={{ fontSize: '.78rem', padding: '4px 10px' }}>
              {t({ id: 'biblioteca.policySets.newSet' })}
            </button>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            <div style={{ gridColumn: '1 / -1' }}>
              <label style={styles.fieldLabel}>{t({ id: 'biblioteca.policySets.fieldLabel' })}</label>
              <input type="text" style={styles.input} value={setForm.label}
                onChange={e => setField('label', e.target.value)} />
            </div>
            <div>
              <label style={styles.fieldLabel}>{t({ id: 'biblioteca.policySets.fieldStatus' })}</label>
              <select style={styles.input} value={setForm.status}
                onChange={e => setField('status', e.target.value)}>
                {SET_STATUSES.map(st => (
                  <option key={st} value={st}>
                    {t({ id: `biblioteca.policySets.status.${st}`, defaultMessage: st })}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label style={styles.fieldLabel}>{t({ id: 'biblioteca.policySets.fieldRegulationDoc' })}</label>
              <select style={styles.input} value={setForm.regulation_document_id}
                onChange={e => setField('regulation_document_id', e.target.value)}>
                <option value="">{t({ id: 'biblioteca.policySets.noRegulationDoc' })}</option>
                {regulationDocs.map(d => (
                  <option key={d.id} value={String(d.id)}>
                    {d.version_label || t({ id: 'biblioteca.regulation.versionFallback' }, { id: d.id })}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label style={styles.fieldLabel}>{t({ id: 'biblioteca.policySets.fieldEffectiveFrom' })}</label>
              <input type="date" style={styles.input} value={setForm.effective_from}
                onChange={e => setField('effective_from', e.target.value)} />
            </div>
            <div>
              <label style={styles.fieldLabel}>{t({ id: 'biblioteca.policySets.fieldEffectiveUntil' })}</label>
              <input type="date" style={styles.input} value={setForm.effective_until}
                onChange={e => setField('effective_until', e.target.value)} />
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <label style={styles.fieldLabel}>{t({ id: 'biblioteca.policySets.fieldScopeNote' })}</label>
              <input type="text" style={styles.input} value={setForm.scope_note}
                onChange={e => setField('scope_note', e.target.value)} />
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 12 }}>
            <button className="cat-btn primary" onClick={saveSet}
              disabled={saving || !setForm.label.trim()} style={{ fontSize: '.85rem' }}>
              {saving ? t({ id: 'common.saving' }) : t({ id: 'biblioteca.policySets.saveSet' })}
            </button>
          </div>
        </div>
      )}

      {/* ── Règles du jeu sélectionné ───────────────────────────────────── */}
      <div style={styles.card}>
        <div style={styles.cardTitle}>
          {selectedSet
            ? t({ id: 'biblioteca.policySets.rulesOf' }, {
                label: translateSeed(selectedSet, 'label', 'set.label') || selectedSet.label,
              })
            : t({ id: 'biblioteca.policySets.rulesTitle' })}
        </div>

        {!selectedSet && (
          <div style={{ fontSize: '.88rem', color: 'var(--brand-muted)' }}>
            {t({ id: 'biblioteca.policySets.selectSetFirst' })}
          </div>
        )}

        {selectedSet && rules.length === 0 && !editingRule && (
          <div style={{ fontSize: '.88rem', color: 'var(--brand-muted)', marginBottom: 10 }}>
            {t({ id: 'biblioteca.regulation.noRules' })}
          </div>
        )}

        {selectedSet && rules.map((r, i) => (
          <div key={r.id} style={{
            padding: '10px 12px', borderRadius: 8, marginBottom: 6,
            background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'rgba(0,0,0,.03)',
          }}>
            {editingRule?.id === r.id ? (
              <RuleEditor
                rule={editingRule} styles={styles} t={t} saving={saving}
                onField={setRuleField} onSave={saveRule}
                onCancel={() => setEditingRule(null)}
                onDelete={() => deleteRule(r.id)}
              />
            ) : (
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8 }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: '.9rem', fontWeight: 600 }}>
                    {translateSeed(r, 'rule_label', 'rule.label') || r.rule_label
                      || t({ id: 'biblioteca.rules.ruleNumberFallback' }, { id: r.id })}
                  </div>
                  <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
                    {r.loan_allowed
                      ? (r.loan_days != null
                          ? t({ id: 'biblioteca.regulation.loanAllowed' }, { days: r.loan_days })
                          : t({ id: 'biblioteca.regulation.loanAllowedNoDays' }))
                      : t({ id: 'biblioteca.regulation.loanNotAllowed' })}
                    {r.renewable && (
                      (r.renewal_days != null && r.renewal_max_count != null)
                        ? ` · ${t({ id: 'biblioteca.regulation.renewable' }, { days: r.renewal_days, times: r.renewal_max_count })}`
                        : ` · ${t({ id: 'biblioteca.regulation.renewableNoDetail' })}`
                    )}
                  </div>
                </div>
                {canEdit && (
                  <button className="cat-btn secondary" onClick={() => setEditingRule({ ...r })}
                    style={{ fontSize: '.78rem', padding: '4px 10px' }}>
                    {t({ id: 'biblioteca.rules.edit' })}
                  </button>
                )}
              </div>
            )}
          </div>
        ))}

        {/* Édition d'une nouvelle règle (id null) */}
        {selectedSet && editingRule && editingRule.id == null && (
          <div style={{ padding: '10px 12px', borderRadius: 8, background: 'rgba(0,0,0,.08)', marginBottom: 6 }}>
            <RuleEditor
              rule={editingRule} styles={styles} t={t} saving={saving}
              onField={setRuleField} onSave={saveRule}
              onCancel={() => setEditingRule(null)}
              onDelete={null}
            />
          </div>
        )}

        {canEdit && selectedSet && !editingRule && (
          <button className="cat-btn secondary" onClick={startNewRule} disabled={saving}
            style={{ fontSize: '.82rem', marginTop: 4 }}>
            {t({ id: 'biblioteca.policySets.newRule' })}
          </button>
        )}
      </div>

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

// ── Sous-composant : éditeur d'une règle ────────────────────────────────────
function RuleEditor({ rule, styles, t, saving, onField, onSave, onCancel, onDelete }) {
  return (
    <div className="cat-book-grid" style={{ gap: 8 }}>
      <div className="cat-field" style={{ gridColumn: 'span 3' }}>
        <label style={styles.fieldLabel}>{t({ id: 'biblioteca.rules.ruleLabel' })}</label>
        <input type="text" style={styles.input} value={rule.rule_label || ''}
          onChange={e => onField('rule_label', e.target.value)} />
      </div>
      <div className="cat-field">
        <label style={styles.fieldLabel}>{t({ id: 'biblioteca.rules.loanDays' })}</label>
        <input type="number" style={styles.input} value={rule.loan_days ?? ''}
          onChange={e => onField('loan_days', Number(e.target.value) || null)} />
      </div>
      <div className="cat-field">
        <label style={styles.fieldLabel}>{t({ id: 'biblioteca.rules.renewalDays' })}</label>
        <input type="number" style={styles.input} value={rule.renewal_days ?? ''}
          onChange={e => onField('renewal_days', Number(e.target.value) || null)} />
      </div>
      <div className="cat-field">
        <label style={styles.fieldLabel}>{t({ id: 'biblioteca.rules.renewalMax' })}</label>
        <input type="number" style={styles.input} value={rule.renewal_max_count ?? ''}
          onChange={e => onField('renewal_max_count', Number(e.target.value) || null)} />
      </div>
      <div className="cat-field">
        <label style={styles.fieldLabel}>{t({ id: 'biblioteca.rules.maxItems' })}</label>
        <input type="number" style={styles.input} value={rule.quantity_max ?? ''}
          onChange={e => onField('quantity_max', Number(e.target.value) || null)} />
      </div>
      <div className="cat-field">
        <label style={{ ...styles.fieldLabel, display: 'flex', gap: 6, alignItems: 'center' }}>
          <input type="checkbox" checked={rule.loan_allowed || false}
            onChange={e => onField('loan_allowed', e.target.checked)} />
          {t({ id: 'biblioteca.rules.loanAllowed' })}
        </label>
      </div>
      <div className="cat-field">
        <label style={{ ...styles.fieldLabel, display: 'flex', gap: 6, alignItems: 'center' }}>
          <input type="checkbox" checked={rule.renewable || false}
            onChange={e => onField('renewable', e.target.checked)} />
          {t({ id: 'biblioteca.rules.renewable' })}
        </label>
      </div>
      <div className="cat-field" style={{ gridColumn: 'span 3' }}>
        <label style={styles.fieldLabel}>{t({ id: 'biblioteca.rules.publicNote' })}</label>
        <input type="text" style={styles.input} value={rule.public_note || ''}
          onChange={e => onField('public_note', e.target.value)} />
      </div>
      <div className="cat-field" style={{ gridColumn: 'span 3', display: 'flex', gap: 8, justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="cat-btn primary" onClick={onSave} disabled={saving}
            style={{ fontSize: '.85rem' }}>
            {t({ id: 'biblioteca.rules.save' })}
          </button>
          <button className="cat-btn secondary" onClick={onCancel} disabled={saving}
            style={{ fontSize: '.85rem' }}>
            {t({ id: 'biblioteca.rules.cancel' })}
          </button>
        </div>
        {onDelete && (
          <button className="cat-btn ghost" onClick={onDelete} disabled={saving}
            style={{ fontSize: '.78rem', padding: '4px 10px', color: '#dc2626', borderColor: 'rgba(220,38,38,.4)' }}
            title={t({ id: 'biblioteca.rules.deleteHint' })}>
            {t({ id: 'biblioteca.rules.delete' })}
          </button>
        )}
      </div>
    </div>
  );
}
