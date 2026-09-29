// src/pages/biblioteca/MembershipSection.jsx — E6, BibliotecaPage lot 3 (29/09/2026)
// La cotisation associative de l'onglet « Regimento e circulação », sortie de
// BibliotecaPage.jsx sans en changer une ligne de logique : l'interrupteur du
// système, les règles (créer, modifier, activer, supprimer avec confirmation
// à deux niveaux). La liste des règles et la fiche de la bibliothèque restent
// chargées par le parent (loadCore) et arrivent avec leur setter ; seul l'état
// d'édition en cours vit ici.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useLibrary } from '@/contexts/LibraryContext';
import { fs, ls, bx, lw } from './styles';

export default function MembershipSection({ libraryId, lib, setLib, rules, setRules, setMsg }) {
  const { formatMessage: t } = useIntl();
  const { patchLibrary } = useLibrary();
  const [saving, setSaving] = useState(false);
  const membershipRules = rules;
  const setMembershipRules = setRules;
  const [editingMembershipRule, setEditingMembershipRule] = useState(null); // null = aucun, 'new' = nouveau, ou {id,...} pour édition

  // ── Cotisation (membership) ──────────────────────────
  async function toggleMembershipEnabled(next) {
    setSaving(true);
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.from('libraries').update({ membership_enabled: next }).eq('id', libraryId);
      if (error) throw error;
      setLib(prev => prev ? { ...prev, membership_enabled: next } : prev);
      // « Mon compte » et le tableau de bord lisent ce réglage dans le contexte
      // de session : sans ce report, il ne s'y voyait qu'après un rechargement.
      patchLibrary(libraryId, { membership_enabled: next });
      setMsg({ text: t({ id: next ? 'membership.config.msg.enabledOn' : 'membership.config.msg.enabledOff' }), kind: 'ok' });
    } catch (e) { setMsg({ text: localizeError(e, t), kind: 'error' }); }
    finally { setSaving(false); }
  }

  function startEditMembershipRule(rule) {
    setEditingMembershipRule({ ...rule, amount_suggested: rule.amount_suggested ?? '' });
    setMsg({ text: '', kind: '' });
  }

  function startNewMembershipRule() {
    setEditingMembershipRule({
      id: 'new',
      name: '',
      description: '',
      amount_min: 0,
      amount_suggested: '',
      currency: 'EUR',
      period_type: 'annual',
      period_anchor: 'rolling',
      is_required: true,
      is_active: true,
      display_order: membershipRules.length * 10,
    });
    setMsg({ text: '', kind: '' });
  }

  function cancelMembershipRule() {
    setEditingMembershipRule(null);
  }

  async function saveMembershipRule() {
    if (!editingMembershipRule) return;
    const r = editingMembershipRule;
    if (!r.name?.trim()) {
      setMsg({ text: t({ id: 'membership.config.rule.namePlaceholder' }), kind: 'error' });
      return;
    }
    if (Number(r.amount_min) < 0) {
      setMsg({ text: t({ id: 'membership.config.msg.minRequired' }), kind: 'error' });
      return;
    }
    setSaving(true);
    try {
      const payload = {
        library_id: libraryId,
        name: r.name.trim(),
        description: r.description?.trim() || null,
        amount_min: Number(r.amount_min) || 0,
        amount_suggested: r.amount_suggested === '' || r.amount_suggested === null
          ? null
          : Number(r.amount_suggested),
        currency: (r.currency || 'EUR').toUpperCase(),
        period_type: r.period_type,
        period_anchor: r.period_anchor,
        is_required: !!r.is_required,
        is_active: !!r.is_active,
        display_order: r.display_order ?? 0,
      };
      if (r.id === 'new') {
        const { data, error } = await supabase.from('library_membership_rules').insert(payload).select().single();
        if (error) throw error;
        setMembershipRules(prev => [...prev, data]);
        setMsg({ text: t({ id: 'membership.config.msg.created' }), kind: 'ok' });
      } else {
        const { data, error } = await supabase.from('library_membership_rules').update(payload).eq('id', r.id).select().single();
        if (error) throw error;
        setMembershipRules(prev => prev.map(x => x.id === r.id ? data : x));
        setMsg({ text: t({ id: 'membership.config.msg.saved' }), kind: 'ok' });
      }
      setEditingMembershipRule(null);
    } catch (e) { setMsg({ text: localizeError(e, t), kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function toggleMembershipRuleActive(rule) {
    const willDeactivate = rule.is_active;
    if (willDeactivate && !confirm(t({ id: 'membership.config.action.deactivateConfirm' }))) return;
    setSaving(true);
    try {
      const { data, error } = await supabase.from('library_membership_rules')
        .update({ is_active: !rule.is_active }).eq('id', rule.id).select().single();
      if (error) throw error;
      setMembershipRules(prev => prev.map(x => x.id === rule.id ? data : x));
      setMsg({
        text: t({ id: willDeactivate ? 'membership.config.msg.deactivated' : 'membership.config.msg.reactivated' }),
        kind: 'ok',
      });
    } catch (e) { setMsg({ text: localizeError(e, t), kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function deleteMembershipRule(rule) {
    // Confirm fort à 2 niveaux : avertissement + saisie du nom de la règle
    if (!confirm(t({ id: 'membership.config.action.deleteConfirm' }, { name: rule.name }))) return;
    const typed = prompt(t({ id: 'membership.config.action.deleteConfirmTyped' }, { name: rule.name }));
    if (typed !== rule.name) {
      if (typed !== null) setMsg({ text: t({ id: 'membership.config.action.deleteCancelled' }), kind: 'info' });
      return;
    }
    setSaving(true);
    try {
      const { error } = await supabase.from('library_membership_rules').delete().eq('id', rule.id);
      if (error) throw error;
      setMembershipRules(prev => prev.filter(x => x.id !== rule.id));
      setMsg({ text: t({ id: 'membership.config.msg.deleted' }), kind: 'ok' });
    } catch (e) { setMsg({ text: localizeError(e, t), kind: 'error' }); }
    finally { setSaving(false); }
  }

  return (
    <div style={bx}>
      <h4 style={{ margin:'0 0 6px' }}>{t({ id: 'membership.config.title' })}</h4>
      <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:12 }}>{t({ id: 'membership.config.hint' })}</div>

      {/* Toggle d'activation du système */}
      <div style={{ display:'flex', alignItems:'center', gap:10, padding:'10px 12px', borderRadius:8, background:'rgba(0,0,0,.15)', marginBottom:12 }}>
        <input
          type="checkbox"
          id="membership_enabled_toggle"
          checked={!!lib?.membership_enabled}
          onChange={e => toggleMembershipEnabled(e.target.checked)}
          disabled={saving}
        />
        <label htmlFor="membership_enabled_toggle" style={{ flex:1, cursor:'pointer' }}>
          <div style={{ fontWeight:600, fontSize:'.9rem' }}>{t({ id: 'membership.config.enabled' })}</div>
          <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
            {lib?.membership_enabled
              ? t({ id: 'membership.config.enabledHint' })
              : t({ id: 'membership.config.disabledHint' })}
          </div>
        </label>
      </div>

      {/* Liste des règles + édition inline */}
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:8 }}>
        <strong style={{ fontSize:'.9rem' }}>{t({ id: 'membership.config.rules.title' })}</strong>
        {!editingMembershipRule && (
          <button className="cat-btn secondary" onClick={startNewMembershipRule} style={{ fontSize:'.82rem', padding:'5px 12px' }}>
            + {t({ id: 'membership.config.rules.add' })}
          </button>
        )}
      </div>

      {membershipRules.length === 0 && !editingMembershipRule && (
        <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', padding:'10px 0' }}>
          {t({ id: 'membership.config.rules.empty' })}
        </div>
      )}

      {/* Éditeur (nouvelle règle ou édition) */}
      {editingMembershipRule && (
        <div style={{ ...bx, background:'rgba(0,120,255,.06)', borderColor:'rgba(0,120,255,.25)', marginBottom:12 }}>
          <div className="cat-book-grid" style={{ gap:8 }}>
            <div className="cat-field" style={{ gridColumn:'span 3' }}>
              <label style={ls}>{t({ id: 'membership.config.rule.name' })} *</label>
              <input
                type="text"
                value={editingMembershipRule.name || ''}
                placeholder={t({ id: 'membership.config.rule.namePlaceholder' })}
                onChange={e => setEditingMembershipRule(p => ({ ...p, name: e.target.value }))}
                style={fs}
              />
            </div>
            <div className="cat-field" style={{ gridColumn:'span 3' }}>
              <label style={ls}>{t({ id: 'membership.config.rule.description' })}</label>
              <input
                type="text"
                value={editingMembershipRule.description || ''}
                placeholder={t({ id: 'membership.config.rule.descriptionPlaceholder' })}
                onChange={e => setEditingMembershipRule(p => ({ ...p, description: e.target.value }))}
                style={fs}
              />
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'membership.config.rule.amountMin' })}</label>
              <input
                type="number"
                step="0.01"
                min="0"
                value={editingMembershipRule.amount_min ?? 0}
                onChange={e => setEditingMembershipRule(p => ({ ...p, amount_min: e.target.value }))}
                style={fs}
              />
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'membership.config.rule.amountSuggested' })}</label>
              <input
                type="number"
                step="0.01"
                min="0"
                value={editingMembershipRule.amount_suggested ?? ''}
                onChange={e => setEditingMembershipRule(p => ({ ...p, amount_suggested: e.target.value }))}
                style={fs}
              />
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'membership.config.rule.currency' })}</label>
              <input
                type="text"
                maxLength={3}
                value={editingMembershipRule.currency || 'EUR'}
                onChange={e => setEditingMembershipRule(p => ({ ...p, currency: e.target.value.toUpperCase() }))}
                style={fs}
              />
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'membership.config.rule.periodType' })}</label>
              <select
                value={editingMembershipRule.period_type || 'annual'}
                onChange={e => setEditingMembershipRule(p => ({ ...p, period_type: e.target.value }))}
                style={fs}
              >
                <option value="annual">{t({ id: 'membership.period.annual' })}</option>
                <option value="quarterly">{t({ id: 'membership.period.quarterly' })}</option>
                <option value="monthly">{t({ id: 'membership.period.monthly' })}</option>
                <option value="lifetime">{t({ id: 'membership.period.lifetime' })}</option>
                <option value="none">{t({ id: 'membership.period.none' })}</option>
              </select>
            </div>
            <div className="cat-field" style={{ gridColumn:'span 2' }}>
              <label style={ls}>{t({ id: 'membership.config.rule.periodAnchor' })}</label>
              <select
                value={editingMembershipRule.period_anchor || 'rolling'}
                onChange={e => setEditingMembershipRule(p => ({ ...p, period_anchor: e.target.value }))}
                disabled={['lifetime','none'].includes(editingMembershipRule.period_type)}
                style={fs}
              >
                <option value="rolling">{t({ id: 'membership.config.rule.periodAnchor.rolling' })}</option>
                <option value="calendar">{t({ id: 'membership.config.rule.periodAnchor.calendar' })}</option>
              </select>
            </div>
            <div className="cat-field" style={{ gridColumn:'span 3' }}>
              <label style={{ ...ls, display:'flex', gap:8, alignItems:'flex-start', cursor:'pointer' }}>
                <input
                  type="checkbox"
                  checked={!!editingMembershipRule.is_required}
                  onChange={e => setEditingMembershipRule(p => ({ ...p, is_required: e.target.checked }))}
                  style={{ marginTop:3 }}
                />
                <span>
                  <span style={{ fontWeight:600 }}>{t({ id: 'membership.config.rule.isRequired' })}</span>
                  <br />
                  <span style={{ fontSize:'.78rem', fontWeight:400, color:'var(--brand-muted)' }}>
                    {t({ id: 'membership.config.rule.isRequiredHint' })}
                  </span>
                </span>
              </label>
            </div>
            <div className="cat-field" style={{ gridColumn:'span 3' }}>
              <label style={{ ...ls, display:'flex', gap:6, alignItems:'center', cursor:'pointer' }}>
                <input
                  type="checkbox"
                  checked={editingMembershipRule.is_active !== false}
                  onChange={e => setEditingMembershipRule(p => ({ ...p, is_active: e.target.checked }))}
                />
                {t({ id: 'membership.config.rule.isActive' })}
              </label>
            </div>
            <div className="cat-field" style={{ gridColumn:'span 3', display:'flex', gap:8, marginTop:6 }}>
              <button className="cat-btn primary" onClick={saveMembershipRule} disabled={saving} style={{ fontSize:'.85rem' }}>
                {t({ id: 'membership.config.action.save' })}
              </button>
              <button className="cat-btn secondary" onClick={cancelMembershipRule} style={{ fontSize:'.85rem' }}>
                {t({ id: 'membership.config.action.cancel' })}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Liste des règles existantes (lecture seule) */}
      {membershipRules.length > 0 && (
        <div style={lw}>
          {membershipRules.map((r, i) => (
            <div key={r.id} style={{ padding:'10px 12px', background:i%2===0?'rgba(0,0,0,.08)':'transparent', borderBottom:'1px solid rgba(255,255,255,.04)', opacity: r.is_active ? 1 : 0.55 }}>
              <div style={{ display:'flex', justifyContent:'space-between', alignItems:'flex-start', gap:8 }}>
                <div style={{ flex:1 }}>
                  <div style={{ fontSize:'.9rem', fontWeight:600, display:'flex', alignItems:'center', gap:6 }}>
                    {r.name}
                    {!r.is_active && <span className="cat-pill" style={{ fontSize:'.65rem', padding:'1px 6px', background:'rgba(255,255,255,.1)' }}>{t({ id: 'biblioteca.rules.inactive' })}</span>}
                    {r.is_required && r.is_active && <span className="cat-pill warn" style={{ fontSize:'.65rem', padding:'1px 6px' }}>{t({ id: 'membership.rule.required' })}</span>}
                  </div>
                  <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginTop:2 }}>
                    {r.amount_min > 0
                      ? t({ id: 'membership.rule.minimumAmount' }, { amount: r.amount_min, currency: r.currency })
                      : t({ id: 'membership.rule.freePrice' })}
                    {r.amount_suggested && r.amount_suggested !== r.amount_min &&
                      ` · ${t({ id: 'membership.rule.suggestedAmount' }, { amount: r.amount_suggested, currency: r.currency })}`}
                    {' · '}{t({ id: `membership.period.${r.period_type}` })}
                    {!['lifetime','none'].includes(r.period_type) &&
                      ` (${t({ id: `membership.config.rule.periodAnchor.${r.period_anchor}` })})`}
                  </div>
                  {r.description && (
                    <div style={{ fontSize:'.78rem', color:'var(--brand-muted)', marginTop:3, fontStyle:'italic' }}>
                      {r.description}
                    </div>
                  )}
                </div>
                {!editingMembershipRule && (
                  <div style={{ display:'flex', gap:6 }}>
                    <button className="cat-btn secondary" onClick={() => startEditMembershipRule(r)} style={{ fontSize:'.78rem', padding:'4px 10px' }}>
                      {t({ id: 'membership.config.action.edit' })}
                    </button>
                    <button
                      className="cat-btn ghost"
                      onClick={() => toggleMembershipRuleActive(r)}
                      style={{ fontSize:'.78rem', padding:'4px 10px', color: r.is_active ? '#f87171' : '#86efac' }}
                    >
                      {t({ id: r.is_active ? 'membership.config.action.deactivate' : 'membership.config.action.reactivate' })}
                    </button>
                    <button
                      className="cat-btn ghost"
                      onClick={() => deleteMembershipRule(r)}
                      style={{ fontSize:'.78rem', padding:'4px 10px', color:'#dc2626', borderColor:'rgba(220,38,38,.4)' }}
                      title={t({ id: 'membership.config.action.deleteHint' })}
                    >
                      {t({ id: 'membership.config.action.delete' })}
                    </button>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
