// ═══════════════════════════════════════════════════════════════════════════
// LettreStaffPanel — onglet « Lettre » de RedePage (réservé network_staff/admin).
//
// Cycle d'un numéro de la Lettre de la fédération (newsletter opt-in) :
//   créer un brouillon AUTO-assemblé (fn_lettre_draft_create : cercles récents +
//   assemblées à venir + dernière Rizoma) → relire/éditer (intro libre + items
//   retenus, fn_lettre_issue_update) → envoyer aux abonné·es (fn_lettre_issue_send,
//   fan-out idempotent). Lecture lettre_issues (RLS staff). Modèle = GazetteStaffPanel.
// ═══════════════════════════════════════════════════════════════════════════
import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase, apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

export default function LettreStaffPanel() {
  const { formatMessage: t, locale } = useIntl();
  const [issues, setIssues] = useState([]);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(null);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [editing, setEditing] = useState(null); // { id, intro, items:[{...,_excluded?}] }

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.from('lettre_issues')
        .select('id,number,status,intro_md,items,created_at,sent_at,recipients_count')
        .order('number', { ascending: false });
      if (error) throw error;
      setIssues(data || []);
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [t]);
  useEffect(() => { load(); }, [load]);

  async function createDraft() {
    setBusy('create');
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await apiRpc('fn_lettre_draft_create', {});
      if (error) throw error;
      setMsg({ text: t({ id: 'rede.lettre.draftCreated' }), kind: 'ok' });
      await load();
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(null);
    }
  }

  function startEdit(iss) {
    setEditing({ id: iss.id, intro: iss.intro_md || '', items: Array.isArray(iss.items) ? iss.items.map((it) => ({ ...it })) : [] });
  }
  function toggleItem(idx) {
    setEditing((e) => ({ ...e, items: e.items.map((it, i) => (i === idx ? { ...it, _excluded: !it._excluded } : it)) }));
  }

  async function saveEdit() {
    setBusy('save');
    try {
      const kept = editing.items
        .filter((it) => !it._excluded)
        .map(({ _excluded, ...rest }) => rest);
      const { error } = await apiRpc('fn_lettre_issue_update', {
        p_id: editing.id, p_intro_md: editing.intro.trim() || null, p_items: kept,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'common.dataSaved' }), kind: 'ok' });
      setEditing(null);
      await load();
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(null);
    }
  }

  async function sendIssue(iss) {
    if (!window.confirm(t({ id: 'rede.lettre.sendConfirm' }, { number: iss.number }))) return;
    setBusy('send:' + iss.id);
    try {
      const { data, error } = await apiRpc('fn_lettre_issue_send', { p_id: iss.id });
      if (error) throw error;
      setMsg({ text: t({ id: 'rede.lettre.sentDone' }, { count: data ?? 0 }), kind: 'ok' });
      await load();
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(null);
    }
  }

  const fmtDate = (d) => (d ? new Date(d).toLocaleDateString(locale) : '—');
  const itemLabel = (it) => {
    if (it.kind === 'circle') return `${t({ id: 'rede.lettre.item.circle' })} · ${it.name}`;
    if (it.kind === 'assembly') return `${t({ id: 'rede.lettre.item.assembly' })} · ${it.title}`;
    if (it.kind === 'gazette') return t({ id: 'rede.lettre.item.gazette' }, { number: it.number });
    return JSON.stringify(it);
  };
  const box = { padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 14 };

  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 6, alignItems: 'center', flexWrap: 'wrap' }}>
        <h3 style={{ margin: 0 }}>{t({ id: 'rede.lettre.title' })} ({issues.length})</h3>
        <span style={{ flex: 1 }} />
        <button className="cat-btn secondary" onClick={load} disabled={loading}>
          {loading ? t({ id: 'rede.refreshing' }) : t({ id: 'rede.refresh' })}
        </button>
        <button className="cat-btn primary" onClick={createDraft} disabled={busy === 'create'}>
          + {t({ id: 'rede.lettre.newDraft' })}
        </button>
      </div>
      <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem', marginTop: 0, marginBottom: 14 }}>{t({ id: 'rede.lettre.lead' })}</p>

      {msg.text && (
        <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.9rem', marginBottom: 14, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>
          {msg.text}
        </div>
      )}

      {issues.length === 0 && <div style={{ ...box, color: 'var(--brand-muted)' }}>{t({ id: 'rede.lettre.empty' })}</div>}

      {issues.map((iss) => (
        <div key={iss.id} style={box}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
            <div>
              <div style={{ fontWeight: 700, fontSize: '1rem' }}>
                N°{String(iss.number).padStart(2, '0')}
                <span className={`cat-pill ${iss.status === 'sent' ? 'ok' : 'warn'}`} style={{ fontSize: '.66rem', marginLeft: 8 }}>
                  {t({ id: `rede.lettre.status.${iss.status}` })}
                </span>
              </div>
              <div style={{ fontSize: '.8rem', color: 'var(--brand-muted)' }}>
                {fmtDate(iss.created_at)}
                {iss.status === 'sent'
                  ? ` · ${t({ id: 'rede.lettre.sentTo' }, { count: iss.recipients_count })}`
                  : ` · ${t({ id: 'rede.lettre.itemsCount' }, { count: (iss.items || []).length })}`}
              </div>
            </div>
            {iss.status === 'draft' && (
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                <button className="cat-btn secondary" onClick={() => startEdit(iss)}>{t({ id: 'rede.lettre.edit' })}</button>
                <button className="cat-btn primary" disabled={busy === 'send:' + iss.id} onClick={() => sendIssue(iss)}>{t({ id: 'rede.lettre.send' })}</button>
              </div>
            )}
          </div>

          {(iss.items || []).length > 0 && (
            <ul style={{ margin: '8px 0 0', paddingLeft: '1.2rem', fontSize: '.85rem', color: 'var(--brand-muted)' }}>
              {iss.items.map((it, i) => <li key={i}>{itemLabel(it)}</li>)}
            </ul>
          )}
          {iss.intro_md && <div style={{ marginTop: 6, fontStyle: 'italic', fontSize: '.85rem' }}>{iss.intro_md}</div>}
        </div>
      ))}

      {/* ─── Modale d'édition du brouillon ─── */}
      {editing && (
        <div onClick={() => setEditing(null)} style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.6)', zIndex: 1000, display: 'flex', alignItems: 'flex-start', justifyContent: 'center', padding: '6vh 12px', overflow: 'auto' }}>
          <div onClick={(e) => e.stopPropagation()} style={{ background: '#17141d', border: '1px solid rgba(255,255,255,.12)', borderRadius: 14, maxWidth: 620, width: '100%', padding: 18 }}>
            <h3 style={{ marginTop: 0 }}>{t({ id: 'rede.lettre.editTitle' })}</h3>

            <label style={{ display: 'block', fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 4 }}>{t({ id: 'rede.lettre.intro' })}</label>
            <textarea
              value={editing.intro}
              onChange={(e) => setEditing((ed) => ({ ...ed, intro: e.target.value }))}
              rows={3} maxLength={1000}
              style={{ width: '100%', fontFamily: 'inherit', fontSize: '.9rem', color: '#f4f4f4', background: 'rgba(0,0,0,.3)', border: '1px solid rgba(255,255,255,.12)', borderRadius: 8, padding: '8px 11px', marginBottom: 14 }}
            />

            <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 6 }}>{t({ id: 'rede.lettre.items' })}</div>
            {editing.items.length === 0 && <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 10 }}>{t({ id: 'common.empty' })}</div>}
            {editing.items.map((it, i) => (
              <label key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6, cursor: 'pointer' }}>
                <input type="checkbox" checked={!it._excluded} onChange={() => toggleItem(i)} />
                <span style={{ fontSize: '.88rem' }}>{itemLabel(it)}</span>
              </label>
            ))}

            <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
              <button className="cat-btn primary" disabled={busy === 'save'} onClick={saveEdit}>{t({ id: 'common.save' })}</button>
              <button className="cat-btn ghost" onClick={() => setEditing(null)}>{t({ id: 'common.cancel' })}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
