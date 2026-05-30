import { Button } from '@/components/ui';

// ═══════════════════════════════════════════════════════════
// TabAcoes — onglet « Actions » (comptoir) (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Extrait de PanelPage.jsx (bloc tab === 'acoes').
// Présentational : tout l'état et les handlers du comptoir
// (enregistrement de départ, retours total/partiel) restent dans
// PanelPage, passés ici en props. Iso-comportement strict.
//
// NOTE : c'est ici que vit le bug « faux succès de retour partiel »
// (registrarDevolucaoParcial) — à corriger en passe dédiée post-E.1.
// ═══════════════════════════════════════════════════════════
export default function TabAcoes({
  t,
  borrowerLookup, setBorrowerLookup,
  loanRefs, setLoanRefs,
  loanPreview, setLoanPreview,
  loanBusy,
  loanMsg,
  returnId, setReturnId,
  returnSubIds, setReturnSubIds,
  returnMsg,
  registrarSaida,
  cancelLoanPreview,
  registrarDevolucaoTotal,
  registrarDevolucaoParcial,
  returnTotalPreview,
  setReturnTotalPreview,
  returnPartialPreview,
  setReturnPartialPreview,
  cancelReturnTotalPreview,
  cancelReturnPartialPreview,
}) {
  return (
    <div className="ab-painel-acoes-grid">
      <div className="ab-painel-acoes-card">
        <h2 className="ab-painel-h2">{t({ id: 'panel.loan.register' })}</h2>
        <p className="ab-painel-hint">{t({ id: 'panel.loan.refsHint' })}</p>
        <label>{t({ id: 'panel.loan.borrowerLabel' })}
          <input type="text" value={borrowerLookup} onChange={e => { setBorrowerLookup(e.target.value); if (loanPreview) setLoanPreview(null); }} placeholder={t({ id: 'panel.loan.borrowerPlaceholder' })} className="ab-painel-input" />
        </label>
        <label>{t({ id: 'panel.loan.refsLabel' })}
          <input type="text" value={loanRefs} onChange={e => { setLoanRefs(e.target.value); if (loanPreview) setLoanPreview(null); }} placeholder={t({ id: 'panel.loan.refsPlaceholder' })} className="ab-painel-input" />
        </label>
        <div className="ab-painel-btn-row">
          <Button onClick={registrarSaida} disabled={loanBusy || (loanPreview && loanPreview.loanAllowed === false)}>
            {loanBusy
              ? '…'
              : loanPreview
                ? t({ id: 'panel.loan.confirmRegister' })
                : t({ id: 'panel.loan.register' })}
          </Button>
          {loanPreview && !loanBusy && (
            <Button variant="secondary" onClick={cancelLoanPreview}>
              {t({ id: 'panel.loan.cancelPreview' })}
            </Button>
          )}
        </div>
        {loanMsg && <p className="ab-painel-msg">{loanMsg}</p>}
      </div>
      <div className="ab-painel-acoes-card">
        <h2 className="ab-painel-h2">{t({ id: 'panel.loan.return' })}</h2>
        <label>{t({ id: 'panel.loan.returnFullLabel' })}
          <input type="text" value={returnId} onChange={e => { setReturnId(e.target.value); if (returnTotalPreview) setReturnTotalPreview(null); }} placeholder={t({id:"panel.loan.returnTotalPh"})} className="ab-painel-input" />
        </label>
        {/* EA-03 (29/05/2026) : bouton avec libellé selon état preview, + bouton "Annuler" quand preview active */}
        <div className="ab-painel-btn-row ab-painel-btn-row--tight">
          <Button variant="secondary" onClick={registrarDevolucaoTotal}>
            {returnTotalPreview
              ? t({ id: 'panel.return.confirmReturn' })
              : t({ id: 'panel.loan.returnFull' })}
          </Button>
          {returnTotalPreview && (
            <Button variant="secondary" onClick={cancelReturnTotalPreview}>
              {t({ id: 'panel.return.cancelPreview' })}
            </Button>
          )}
        </div>
        <hr className="ab-painel-hr" />
        <label>{t({ id: 'panel.loan.returnPartialLabel' })}
          <input type="text" value={returnSubIds} onChange={e => { setReturnSubIds(e.target.value); if (returnPartialPreview) setReturnPartialPreview(null); }} placeholder={t({id:"panel.loan.returnPartialPh"})} className="ab-painel-input" />
        </label>
        <div className="ab-painel-btn-row ab-painel-btn-row--tight">
          <Button variant="secondary" onClick={registrarDevolucaoParcial}>
            {returnPartialPreview
              ? t({ id: 'panel.return.confirmReturn' })
              : t({ id: 'panel.loan.returnPartial' })}
          </Button>
          {returnPartialPreview && (
            <Button variant="secondary" onClick={cancelReturnPartialPreview}>
              {t({ id: 'panel.return.cancelPreview' })}
            </Button>
          )}
        </div>
        {returnMsg && <p className="ab-painel-msg">{returnMsg}</p>}
      </div>
    </div>
  );
}
