import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { useLibrary } from '@/contexts/LibraryContext';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';

// ════════════════════════════════════════════════════════════════════
// LoanDepositPanel — encart « dépôt de garantie » attaché à un emprunt
// (DEPOT-5, soft-gate). Autonome : se gate sur deposit_enabled → null si OFF.
// Deux modes selon le scope de la règle active de la biblio :
//   - per_loan / per_item : un dépôt par emprunt (fn_record_deposit,
//     fn_deposit_status_for_loan).
//   - standing : un dépôt TOURNANT unique par lecteur·rice, couvrant tous les
//     emprunts (fn_record_standing_deposit, fn_standing_deposit_for_loan) ;
//     remboursable seulement quand plus aucun emprunt n'est en cours (la garde
//     est côté SQL ; l'erreur standing_deposit_has_open_loans est localisée).
// Actions communes : collecte, remboursement total, rétention (perte/dégât),
// via les fonctions SECURITY DEFINER fn_record/refund/retain_deposit.
// ════════════════════════════════════════════════════════════════════

// Cache de config par biblio (Promise) — évite une requête config par emprunt.
const _configCache = new Map();
function loadDepositConfig(libraryId) {
  if (_configCache.has(libraryId)) return _configCache.get(libraryId);
  const p = (async () => {
    const [{ data: lib }, { data: rules }] = await Promise.all([
      supabase.from('libraries').select('deposit_enabled').eq('id', libraryId).maybeSingle(),
      supabase.from('library_deposit_rules').select('*').eq('library_id', libraryId)
        .eq('is_active', true).order('display_order', { ascending: true }),
    ]);
    return { enabled: !!lib?.deposit_enabled, rules: rules || [] };
  })();
  _configCache.set(libraryId, p);
  return p;
}

const METHODS = ['cash', 'transfer', 'card', 'check', 'in_kind', 'exemption', 'other'];

export default function LoanDepositPanel({ emprestimoId }) {
  const { formatMessage: t } = useIntl();
  const { libraryId } = useLibrary();
  const { notifyError } = useToast();

  const [config, setConfig] = useState(null);
  const [deposits, setDeposits] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [method, setMethod] = useState('cash');
  const [amount, setAmount] = useState('');

  const standingMode = config?.rules?.[0]?.scope === 'standing';

  async function loadDeposits(standing) {
    const fn = standing ? 'fn_standing_deposit_for_loan' : 'fn_deposit_status_for_loan';
    const { data, error } = await supabase.rpc(fn, { p_emprestimo_id: emprestimoId });
    if (!error) setDeposits(data || []);
  }

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!libraryId) { setLoading(false); return; }
      const cfg = await loadDepositConfig(libraryId);
      if (cancelled) return;
      setConfig(cfg);
      if (cfg.enabled) {
        setAmount(cfg.rules[0]?.amount ?? '');
        await loadDeposits(cfg.rules?.[0]?.scope === 'standing');
      }
      if (!cancelled) setLoading(false);
    })();
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [libraryId, emprestimoId]);

  if (loading || !config || !config.enabled) return null;

  const rule = config.rules[0] || null;
  const held = deposits.find(d => d.status === 'detenu');
  const settled = deposits.filter(d => d.status !== 'detenu');
  const title = standingMode ? t({ id: 'deposit.panel.standingTitle' }) : t({ id: 'deposit.panel.title' });

  async function collect() {
    setBusy(true); setMsg('');
    try {
      // Mêmes paramètres nommés pour les deux fonctions (fn_record_deposit
      // ignore p_emprestimo_item_id par défaut ; le tournant n'en a pas).
      const fn = standingMode ? 'fn_record_standing_deposit' : 'fn_record_deposit';
      const { error } = await supabase.rpc(fn, {
        p_emprestimo_id: emprestimoId,
        p_rule_id: rule?.id ?? null,
        p_amount: method === 'exemption' ? 0 : (amount === '' ? null : Number(amount)),
        p_method: method,
        p_notes: null,
      });
      if (error) throw error;
      setMsg(t({ id: 'deposit.panel.msg.collected' }));
      await loadDeposits(standingMode);
    } catch (e) { notifyError(localizeError(e, t, 'deposit.panel.title'), e); }
    finally { setBusy(false); }
  }

  async function refund(dep) {
    setBusy(true); setMsg('');
    try {
      const { error } = await supabase.rpc('fn_refund_deposit', {
        p_deposit_id: dep.deposit_id,
        p_refunded_method: 'cash',
        p_refunded_amount: null, // remboursement total
        p_notes: null,
      });
      if (error) throw error;
      setMsg(t({ id: 'deposit.panel.msg.refunded' }));
      await loadDeposits(standingMode);
    } catch (e) { notifyError(localizeError(e, t, 'deposit.panel.title'), e); }
    finally { setBusy(false); }
  }

  async function retain(dep) {
    const reason = window.prompt(t({ id: 'deposit.panel.retainReasonPrompt' }));
    if (reason == null || !reason.trim()) return;
    setBusy(true); setMsg('');
    try {
      const { error } = await supabase.rpc('fn_retain_deposit', {
        p_deposit_id: dep.deposit_id,
        p_retention_reason: reason.trim(),
        p_partial_refund_amount: null,
        p_refunded_method: 'cash',
      });
      if (error) throw error;
      setMsg(t({ id: 'deposit.panel.msg.retained' }));
      await loadDeposits(standingMode);
    } catch (e) { notifyError(localizeError(e, t, 'deposit.panel.title'), e); }
    finally { setBusy(false); }
  }

  return (
    <div style={{ margin: '4px 14px 10px', padding: '8px 12px', borderRadius: 8, background: 'rgba(255,196,0,.06)', border: '1px solid rgba(255,196,0,.18)', fontSize: '.85rem' }}>
      <strong style={{ fontSize: '.82rem' }}>{title}</strong>

      {held ? (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 6, flexWrap: 'wrap' }}>
          <span>
            {t({ id: 'deposit.panel.heldLabel' })} : <strong>{held.amount} {held.currency}</strong>
            {' · '}{t({ id: `membership.method.${held.collected_method}` })}
          </span>
          <button className="ab-button ab-button--mini" disabled={busy} onClick={() => refund(held)}>
            {t({ id: 'deposit.panel.refundCta' })}
          </button>
          <button className="ab-button ab-button--secondary ab-button--mini" disabled={busy} onClick={() => retain(held)}>
            {t({ id: 'deposit.panel.retainCta' })}
          </button>
        </div>
      ) : settled.length > 0 ? (
        <div style={{ marginTop: 6 }}>
          {settled.map(d => (
            <div key={d.deposit_id} style={{ color: 'var(--brand-muted)' }}>
              {t({ id: `deposit.status.${d.status}` })}
              {' · '}{(d.refunded_amount ?? d.amount)} {d.currency}
            </div>
          ))}
        </div>
      ) : rule ? (
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8, marginTop: 6, flexWrap: 'wrap' }}>
          <label style={{ fontSize: '.78rem', display: 'flex', flexDirection: 'column' }}>
            {t({ id: 'deposit.panel.amount' })}
            <input
              type="number"
              step="0.01"
              min="0"
              value={method === 'exemption' ? 0 : amount}
              disabled={method === 'exemption'}
              onChange={e => setAmount(e.target.value)}
              style={{ width: 90, marginTop: 2, opacity: method === 'exemption' ? 0.5 : 1 }}
            />
          </label>
          <label style={{ fontSize: '.78rem', display: 'flex', flexDirection: 'column' }}>
            {t({ id: 'deposit.panel.method' })}
            <select value={method} onChange={e => setMethod(e.target.value)} style={{ marginTop: 2 }}>
              {METHODS.map(m => <option key={m} value={m}>{t({ id: `membership.method.${m}` })}</option>)}
            </select>
          </label>
          <button className="ab-button ab-button--mini" disabled={busy} onClick={collect}>
            {t({ id: 'deposit.panel.collectCta' })}
          </button>
        </div>
      ) : (
        <div style={{ marginTop: 6, color: 'var(--brand-muted)' }}>{t({ id: 'deposit.panel.noActiveRule' })}</div>
      )}

      {msg && <div style={{ marginTop: 4, fontSize: '.78rem', color: '#86efac' }}>{msg}</div>}
    </div>
  );
}
