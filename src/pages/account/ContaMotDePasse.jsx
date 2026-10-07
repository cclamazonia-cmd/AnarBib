import { useIntl } from 'react-intl';
import { Button } from '@/components/ui';

// ═══════════════════════════════════════════════════════════
// AnarBib — le changement de mot de passe (Lot 26.1a), dans l'onglet « Données personnelles » de Mon
// compte. Sorti d'AccountPage.jsx tel quel (E6, AccountPage lot 7,
// 07/10/2026), lignes déplacées par script : le geste (handleChangePassword) et ses états restent au parent.
// Les props portent les noms du parent. Garde : conta-decisions-sous-le-
// profil.test.js relit l'onglet en remettant ce fichier à sa place.
// ═══════════════════════════════════════════════════════════

export default function ContaMotDePasse({ pwdNew, setPwdNew, pwdConfirm, setPwdConfirm, pwdSaving, pwdMsg, pwdMsgIsError, handleChangePassword }) {
  const { formatMessage: t } = useIntl();
  return (
    <>
      <div style={{ marginTop: 32, padding: 20, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
        <h3 style={{ margin: '0 0 4px', fontSize: '1.05rem', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
          {t({ id: 'account.changePassword.title', defaultMessage: 'Mudar minha senha' })}
        </h3>
        <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 14 }}>
          {t({ id: 'account.changePassword.hint', defaultMessage: 'Defina uma nova senha de pelo menos 8 caracteres. A confirmação é obrigatória.' })}
        </div>
        <form onSubmit={handleChangePassword} className="ab-conta-form">
          <div className="ab-conta-grid2">
            <label>
              {t({ id: 'account.changePassword.newPassword', defaultMessage: 'Nova senha' })}
              <input
                type="password"
                value={pwdNew}
                onChange={e => setPwdNew(e.target.value)}
                autoComplete="new-password"
                minLength={8}
                required
              />
            </label>
            <label>
              {t({ id: 'account.changePassword.confirmPassword', defaultMessage: 'Confirmar nova senha' })}
              <input
                type="password"
                value={pwdConfirm}
                onChange={e => setPwdConfirm(e.target.value)}
                autoComplete="new-password"
                minLength={8}
                required
              />
            </label>
          </div>
          <div className="ab-conta-form-actions">
            <Button type="submit" loading={pwdSaving}>
              {t({ id: 'account.changePassword.submit', defaultMessage: 'Atualizar senha' })}
            </Button>
            {pwdMsg && (
              <span className={`ab-conta-msg ${pwdMsgIsError ? 'ab-conta-msg--error' : ''}`}>
                {pwdMsg}
              </span>
            )}
          </div>
        </form>
      </div>
    </>
  );
}
