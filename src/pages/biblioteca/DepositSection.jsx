// src/pages/biblioteca/DepositSection.jsx — E6, BibliotecaPage lot 3 (29/09/2026)
// Le dépôt de garantie (DEPOT-1/6) de l'onglet « Regimento e circulação », sorti
// de BibliotecaPage.jsx sans en changer une ligne de logique : opt-in strict par
// bibliothèque, plafonds anti-barrière (vide = illimité), règles (créer,
// modifier, activer, supprimer). La liste des règles et la fiche de la
// bibliothèque restent chargées par le parent (loadCore) et arrivent avec leur
// setter ; seul l'état d'édition en cours vit ici.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { fs, ls, bx, lw } from './styles';

export default function DepositSection({ libraryId, lib, setLib, rules, setRules, setMsg }) {
  const { formatMessage: t } = useIntl();
  const [saving, setSaving] = useState(false);
  const depositRules = rules;
  const setDepositRules = setRules;
  const [editingDepositRule, setEditingDepositRule] = useState(null);

  // ── Dépôt de garantie (deposit) — DEPOT-1/6 ──────────
  async function toggleDepositEnabled(next) {
    setSaving(true);
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.from('libraries').update({ deposit_enabled: next }).eq('id', libraryId);
      if (error) throw error;
      setLib(prev => prev ? { ...prev, deposit_enabled: next } : prev);
      setMsg({ text: t({ id: next ? 'deposit.config.msg.enabledOn' : 'deposit.config.msg.enabledOff' }), kind: 'ok' });
    } catch (e) { setMsg({ text: localizeError(e, t), kind: 'error' }); }
    finally { setSaving(false); }
  }

  // Plafonds dépôt (anti-barrière) : champs vides = NULL = illimité.
  async function saveDepositLimit(field, rawValue) {
    const value = rawValue === '' || rawValue == null ? null : Number(rawValue);
    if (value != null && (Number.isNaN(value) || value < 0)) {
      setMsg({ text: t({ id: 'deposit.config.msg.amountRequired' }), kind: 'error' });
      return;
    }
    setSaving(true);
    try {
      const { error } = await supabase.from('libraries').update({ [field]: value }).eq('id', libraryId);
      if (error) throw error;
      setLib(prev => prev ? { ...prev, [field]: value } : prev);
      setMsg({ text: t({ id: 'deposit.config.msg.limitsSaved' }), kind: 'ok' });
    } catch (e) { setMsg({ text: localizeError(e, t), kind: 'error' }); }
    finally { setSaving(false); }
  }

  function startEditDepositRule(rule) {
    setEditingDepositRule({ ...rule });
    setMsg({ text: '', kind: '' });
  }

  function startNewDepositRule() {
    setEditingDepositRule({
      id: 'new',
      name: '',
      description: '',
      scope: 'per_loan',
      amount: 0,
      currency: 'EUR',
      refundable: true,
      is_active: true,
      display_order: depositRules.length * 10,
    });
    setMsg({ text: '', kind: '' });
  }

  function cancelDepositRule() {
    setEditingDepositRule(null);
  }

  async function saveDepositRule() {
    if (!editingDepositRule) return;
    const r = editingDepositRule;
    if (!r.name?.trim()) {
      setMsg({ text: t({ id: 'deposit.config.rule.namePlaceholder' }), kind: 'error' });
      return;
    }
    if (Number(r.amount) < 0) {
      setMsg({ text: t({ id: 'deposit.config.msg.amountRequired' }), kind: 'error' });
      return;
    }
    setSaving(true);
    try {
      const payload = {
        library_id: libraryId,
        name: r.name.trim(),
        description: r.description?.trim() || null,
        scope: ['per_item', 'per_loan', 'standing'].includes(r.scope) ? r.scope : 'per_loan',
        amount: Number(r.amount) || 0,
        currency: (r.currency || 'EUR').toUpperCase(),
        refundable: r.refundable !== false,
        is_active: !!r.is_active,
        display_order: r.display_order ?? 0,
      };
      if (r.id === 'new') {
        const { data, error } = await supabase.from('library_deposit_rules').insert(payload).select().single();
        if (error) throw error;
        setDepositRules(prev => [...prev, data]);
        setMsg({ text: t({ id: 'deposit.config.msg.created' }), kind: 'ok' });
      } else {
        const { data, error } = await supabase.from('library_deposit_rules').update(payload).eq('id', r.id).select().single();
        if (error) throw error;
        setDepositRules(prev => prev.map(x => x.id === r.id ? data : x));
        setMsg({ text: t({ id: 'deposit.config.msg.saved' }), kind: 'ok' });
      }
      setEditingDepositRule(null);
    } catch (e) { setMsg({ text: localizeError(e, t), kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function toggleDepositRuleActive(rule) {
    const willDeactivate = rule.is_active;
    if (willDeactivate && !confirm(t({ id: 'deposit.config.action.deactivateConfirm' }))) return;
    setSaving(true);
    try {
      const { data, error } = await supabase.from('library_deposit_rules')
        .update({ is_active: !rule.is_active }).eq('id', rule.id).select().single();
      if (error) throw error;
      setDepositRules(prev => prev.map(x => x.id === rule.id ? data : x));
      setMsg({ text: t({ id: willDeactivate ? 'deposit.config.msg.deactivated' : 'deposit.config.msg.reactivated' }), kind: 'ok' });
    } catch (e) { setMsg({ text: localizeError(e, t), kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function deleteDepositRule(rule) {
    if (!confirm(t({ id: 'deposit.config.action.deleteConfirm' }, { name: rule.name }))) return;
    setSaving(true);
    try {
      const { error } = await supabase.from('library_deposit_rules').delete().eq('id', rule.id);
      if (error) throw error;
      setDepositRules(prev => prev.filter(x => x.id !== rule.id));
      setMsg({ text: t({ id: 'deposit.config.msg.deleted' }), kind: 'ok' });
    } catch (e) { setMsg({ text: localizeError(e, t), kind: 'error' }); }
    finally { setSaving(false); }
  }

  return (
    <div style={bx}>
      <h4 style={{ margin:'0 0 6px' }}>{t({ id: 'deposit.config.title' })}</h4>
      <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:12 }}>{t({ id: 'deposit.config.hint' })}</div>

      {/* Interrupteur maître */}
      <div style={{ display:'flex', alignItems:'center', gap:10, padding:'10px 12px', borderRadius:8, background:'rgba(0,0,0,.15)', marginBottom:12 }}>
        <input
          type="checkbox"
          id="deposit_enabled_toggle"
          checked={!!lib?.deposit_enabled}
          onChange={e => toggleDepositEnabled(e.target.checked)}
          disabled={saving}
        />
        <label htmlFor="deposit_enabled_toggle" style={{ flex:1, cursor:'pointer' }}>
          <div style={{ fontWeight:600, fontSize:'.9rem' }}>{t({ id: 'deposit.config.enabled' })}</div>
          <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
            {lib?.deposit_enabled
              ? t({ id: 'deposit.config.enabledHint' })
              : t({ id: 'deposit.config.disabledHint' })}
          </div>
        </label>
      </div>

      {/* Règles de dépôt : visibles seulement si le système est activé */}
      {lib?.deposit_enabled && (<>
        {/* Plafonds anti-barrière (vide = illimité) */}
        <div style={{ display:'flex', gap:18, flexWrap:'wrap', marginBottom:14 }}>
          <label style={{ fontSize:'.82rem', display:'flex', flexDirection:'column', fontWeight:600 }}>
            {t({ id: 'deposit.config.capPerReader' })}
            <input
              type="number" step="0.01" min="0"
              defaultValue={lib?.deposit_cap_per_reader ?? ''}
              placeholder={t({ id: 'deposit.config.noLimit' })}
              onBlur={e => saveDepositLimit('deposit_cap_per_reader', e.target.value)}
              style={{ ...fs, width:150, marginTop:3 }}
            />
            <span style={{ fontSize:'.72rem', fontWeight:400, color:'var(--brand-muted)', maxWidth:230 }}>{t({ id: 'deposit.config.capPerReaderHint' })}</span>
          </label>
          <label style={{ fontSize:'.82rem', display:'flex', flexDirection:'column', fontWeight:600 }}>
            {t({ id: 'deposit.config.maxPerRule' })}
            <input
              type="number" step="0.01" min="0"
              defaultValue={lib?.deposit_max_per_rule ?? ''}
              placeholder={t({ id: 'deposit.config.noLimit' })}
              onBlur={e => saveDepositLimit('deposit_max_per_rule', e.target.value)}
              style={{ ...fs, width:150, marginTop:3 }}
            />
            <span style={{ fontSize:'.72rem', fontWeight:400, color:'var(--brand-muted)', maxWidth:230 }}>{t({ id: 'deposit.config.maxPerRuleHint' })}</span>
          </label>
        </div>

        <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:8 }}>
          <strong style={{ fontSize:'.9rem' }}>{t({ id: 'deposit.config.rules.title' })}</strong>
          {!editingDepositRule && (
            <button className="cat-btn secondary" onClick={startNewDepositRule} style={{ fontSize:'.82rem', padding:'5px 12px' }}>
              + {t({ id: 'deposit.config.rules.add' })}
            </button>
          )}
        </div>

        {depositRules.length === 0 && !editingDepositRule && (
          <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', padding:'10px 0' }}>
            {t({ id: 'deposit.config.rules.empty' })}
          </div>
        )}

        {editingDepositRule && (
          <div style={{ ...bx, background:'rgba(0,120,255,.06)', borderColor:'rgba(0,120,255,.25)', marginBottom:12 }}>
            <div className="cat-book-grid" style={{ gap:8 }}>
              <div className="cat-field" style={{ gridColumn:'span 3' }}>
                <label style={ls}>{t({ id: 'deposit.config.rule.name' })} *</label>
                <input
                  type="text"
                  value={editingDepositRule.name || ''}
                  placeholder={t({ id: 'deposit.config.rule.namePlaceholder' })}
                  onChange={e => setEditingDepositRule(p => ({ ...p, name: e.target.value }))}
                  style={fs}
                />
              </div>
              <div className="cat-field" style={{ gridColumn:'span 3' }}>
                <label style={ls}>{t({ id: 'deposit.config.rule.description' })}</label>
                <input
                  type="text"
                  value={editingDepositRule.description || ''}
                  placeholder={t({ id: 'deposit.config.rule.descriptionPlaceholder' })}
                  onChange={e => setEditingDepositRule(p => ({ ...p, description: e.target.value }))}
                  style={fs}
                />
              </div>
              <div className="cat-field" style={{ gridColumn:'span 2' }}>
                <label style={ls}>{t({ id: 'deposit.config.rule.scope' })}</label>
                <select
                  value={editingDepositRule.scope || 'per_loan'}
                  onChange={e => setEditingDepositRule(p => ({ ...p, scope: e.target.value }))}
                  style={fs}
                >
                  <option value="per_loan">{t({ id: 'deposit.scope.per_loan' })}</option>
                  <option value="per_item">{t({ id: 'deposit.scope.per_item' })}</option>
                  <option value="standing">{t({ id: 'deposit.scope.standing' })}</option>
                </select>
              </div>
              <div className="cat-field">
                <label style={ls}>{t({ id: 'deposit.config.rule.amount' })} *</label>
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  value={editingDepositRule.amount ?? 0}
                  onChange={e => setEditingDepositRule(p => ({ ...p, amount: e.target.value }))}
                  style={fs}
                />
              </div>
              <div className="cat-field">
                <label style={ls}>{t({ id: 'deposit.config.rule.currency' })}</label>
                <input
                  type="text"
                  maxLength={3}
                  value={editingDepositRule.currency || 'EUR'}
                  onChange={e => setEditingDepositRule(p => ({ ...p, currency: e.target.value.toUpperCase() }))}
                  style={fs}
                />
              </div>
              <div className="cat-field" style={{ gridColumn:'span 3' }}>
                <label style={{ ...ls, display:'flex', gap:6, alignItems:'center', cursor:'pointer' }}>
                  <input
                    type="checkbox"
                    checked={editingDepositRule.is_active !== false}
                    onChange={e => setEditingDepositRule(p => ({ ...p, is_active: e.target.checked }))}
                  />
                  {t({ id: 'deposit.config.rule.isActive' })}
                </label>
              </div>
              <div className="cat-field" style={{ gridColumn:'span 3', display:'flex', gap:8, marginTop:6 }}>
                <button className="cat-btn primary" onClick={saveDepositRule} disabled={saving} style={{ fontSize:'.85rem' }}>
                  {t({ id: 'deposit.config.action.save' })}
                </button>
                <button className="cat-btn secondary" onClick={cancelDepositRule} style={{ fontSize:'.85rem' }}>
                  {t({ id: 'deposit.config.action.cancel' })}
                </button>
              </div>
            </div>
          </div>
        )}

        {depositRules.length > 0 && (
          <div style={lw}>
            {depositRules.map((r, i) => (
              <div key={r.id} style={{ padding:'10px 12px', background:i%2===0?'rgba(0,0,0,.08)':'transparent', borderBottom:'1px solid rgba(255,255,255,.04)', opacity: r.is_active ? 1 : 0.55 }}>
                <div style={{ display:'flex', justifyContent:'space-between', alignItems:'flex-start', gap:8 }}>
                  <div style={{ flex:1 }}>
                    <div style={{ fontSize:'.9rem', fontWeight:600, display:'flex', alignItems:'center', gap:6 }}>
                      {r.name}
                      {!r.is_active && <span className="cat-pill" style={{ fontSize:'.65rem', padding:'1px 6px', background:'rgba(255,255,255,.1)' }}>{t({ id: 'biblioteca.rules.inactive' })}</span>}
                    </div>
                    <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginTop:2 }}>
                      {t({ id: 'deposit.rule.amount' }, { amount: r.amount, currency: r.currency })}
                      {' · '}{t({ id: `deposit.scope.${r.scope}` })}
                    </div>
                    {r.description && (
                      <div style={{ fontSize:'.78rem', color:'var(--brand-muted)', marginTop:3, fontStyle:'italic' }}>
                        {r.description}
                      </div>
                    )}
                  </div>
                  {!editingDepositRule && (
                    <div style={{ display:'flex', gap:6 }}>
                      <button className="cat-btn secondary" onClick={() => startEditDepositRule(r)} style={{ fontSize:'.78rem', padding:'4px 10px' }}>
                        {t({ id: 'deposit.config.action.edit' })}
                      </button>
                      <button className="cat-btn ghost" onClick={() => toggleDepositRuleActive(r)} style={{ fontSize:'.78rem', padding:'4px 10px', color: r.is_active ? '#f87171' : '#86efac' }}>
                        {t({ id: r.is_active ? 'deposit.config.action.deactivate' : 'deposit.config.action.reactivate' })}
                      </button>
                      <button className="cat-btn ghost" onClick={() => deleteDepositRule(r)} style={{ fontSize:'.78rem', padding:'4px 10px', color:'#dc2626', borderColor:'rgba(220,38,38,.4)' }}>
                        {t({ id: 'deposit.config.action.delete' })}
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </>)}
    </div>
  );
}
