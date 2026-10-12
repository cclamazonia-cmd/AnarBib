// AnarBib — Panneau, la modale d'enregistrement d'un paiement de cotisation
// (E6, lot C, 12/10/2026). JSX déplacé tel quel depuis PanelPage.jsx ; l'état
// et les gestes viennent de usePanelLeitor, étalés en props. Rend null tant
// qu'aucun paiement n'est en cours de saisie.
import { Button } from '@/components/ui';

export default function PaymentModal({ t, paymentModal, paymentDraft, setPaymentDraft, membershipRules, onPaymentRuleChange, paymentMsg, paymentMsgIsError, paymentSaving, submitPayment, closePaymentModal }) {
  if (!paymentModal || !paymentDraft) return null;
  return (
    <div onClick={closePaymentModal} style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.6)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
      <div onClick={e => e.stopPropagation()} style={{ background: 'var(--brand-bg, #1a1a1a)', borderRadius: 12, padding: 20, maxWidth: 500, width: '100%', border: '1px solid rgba(255,255,255,.1)', maxHeight: '90vh', overflow: 'auto' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12, flexWrap: 'wrap', gap: 6 }}>
          <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 700 }}>{t({ id: 'membership.payment.modalTitle' })}</h3>
          <button onClick={closePaymentModal} style={{ background: 'none', border: 'none', color: 'var(--brand-muted)', fontSize: '1.4rem', cursor: 'pointer', padding: 0, lineHeight: 1 }}>×</button>
        </div>
        <div style={{ fontSize: '.88rem', color: 'var(--brand-muted)', marginBottom: 12 }}>
          {t({ id: 'membership.payment.forReader' }, { name: paymentModal.display_name })}
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <label style={{ fontSize: '.85rem', fontWeight: 600 }}>
            {t({ id: 'membership.payment.rule' })}
            <select
              value={paymentDraft.rule_id || ''}
              onChange={e => onPaymentRuleChange(e.target.value)}
              className="ab-painel-input"
              style={{ marginTop: 4 }}
            >
              {membershipRules.map(r => (
                <option key={r.id} value={r.id}>
                  {r.name} — {r.amount_min > 0 ? t({id:'membership.rule.minAmount'}, {amount: r.amount_min, currency: r.currency}) : t({ id: 'membership.rule.freePrice' })}
                </option>
              ))}
            </select>
          </label>

          <label style={{ fontSize: '.85rem', fontWeight: 600 }}>
            {t({ id: 'membership.payment.amount' })}
            <input
              type="number"
              step="0.01"
              min="0"
              value={paymentDraft.amount_paid}
              onChange={e => setPaymentDraft(p => ({ ...p, amount_paid: e.target.value }))}
              disabled={paymentDraft.payment_method === 'exemption'}
              className="ab-painel-input"
              style={{ marginTop: 4, opacity: paymentDraft.payment_method === 'exemption' ? 0.5 : 1 }}
            />
          </label>

          <label style={{ fontSize: '.85rem', fontWeight: 600 }}>
            {t({ id: 'membership.payment.method' })}
            <select
              value={paymentDraft.payment_method}
              onChange={e => { const m = e.target.value; setPaymentDraft(p => ({ ...p, payment_method: m, amount_paid: m === 'exemption' ? 0 : p.amount_paid })); }}
              className="ab-painel-input"
              style={{ marginTop: 4 }}
            >
              <option value="cash">{t({ id: 'membership.method.cash' })}</option>
              <option value="transfer">{t({ id: 'membership.method.transfer' })}</option>
              <option value="card">{t({ id: 'membership.method.card' })}</option>
              <option value="check">{t({ id: 'membership.method.check' })}</option>
              <option value="in_kind">{t({ id: 'membership.method.in_kind' })}</option>
              <option value="exemption">{t({ id: 'membership.method.exemption' })}</option>
              <option value="other">{t({ id: 'membership.method.other' })}</option>
            </select>
          </label>

          <label style={{ fontSize: '.85rem', fontWeight: 600 }}>
            {t({ id: 'membership.payment.paidAt' })}
            <input
              type="date"
              value={paymentDraft.paid_at}
              onChange={e => setPaymentDraft(p => ({ ...p, paid_at: e.target.value }))}
              className="ab-painel-input"
              style={{ marginTop: 4 }}
            />
          </label>

          <label style={{ fontSize: '.85rem', fontWeight: 600 }}>
            {t({ id: 'membership.payment.notes' })}
            <textarea
              rows={2}
              value={paymentDraft.notes || ''}
              onChange={e => setPaymentDraft(p => ({ ...p, notes: e.target.value }))}
              className="ab-painel-input"
              placeholder={t({ id: 'membership.payment.notesPlaceholder' })}
              style={{ marginTop: 4, fontFamily: 'inherit', resize: 'vertical' }}
            />
          </label>

          {paymentMsg && (
            <div style={{ padding: '8px 12px', borderRadius: 6, fontSize: '.85rem', background: paymentMsgIsError ? 'rgba(220,38,38,.1)' : 'rgba(74,222,128,.1)', color: paymentMsgIsError ? '#f87171' : '#4ade80' }}>
              {paymentMsg}
            </div>
          )}

          <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
            <Button onClick={submitPayment} disabled={paymentSaving}>
              {paymentSaving ? t({ id: 'common.saving' }) : t({ id: 'membership.payment.submit' })}
            </Button>
            <Button variant="secondary" onClick={closePaymentModal} disabled={paymentSaving}>
              {t({ id: 'common.cancel' })}
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
