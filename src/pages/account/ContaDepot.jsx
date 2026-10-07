import { useIntl } from 'react-intl';

// ═══════════════════════════════════════════════════════════
// AnarBib — le dépôt de garantie (DEPOT §8), en lecture seule, dans l'onglet « Données personnelles » de Mon
// compte. Sorti d'AccountPage.jsx tel quel (E6, AccountPage lot 7,
// 07/10/2026), lignes déplacées par script : masqué sans dépôt ; la liste reste au parent, qui la charge.
// Les props portent les noms du parent. Garde : conta-decisions-sous-le-
// profil.test.js relit l'onglet en remettant ce fichier à sa place.
// ═══════════════════════════════════════════════════════════

export default function ContaDepot({ deposits }) {
  const { formatMessage: t } = useIntl();
  return (
    <>
      {deposits.length > 0 && (
        <div style={{ marginTop: 32, padding: 20, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
          <h3 style={{ margin: '0 0 4px', fontSize: '1.05rem', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
            {t({ id: 'deposit.account.title' })}
          </h3>
          <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 14 }}>
            {t({ id: 'deposit.account.hint' })}
          </div>
          {deposits.map(d => {
            const isHeld = d.status === 'detenu';
            const color = isHeld ? '#fbbf24' : d.status === 'rembourse' ? '#4ade80' : 'var(--brand-muted)';
            return (
              <div key={d.deposit_id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 12px', borderRadius: 6, background: 'rgba(0,0,0,.15)', marginBottom: 6, flexWrap: 'wrap' }}>
                <strong>{d.amount} {d.currency}</strong>
                <span style={{ padding: '2px 10px', borderRadius: 999, fontSize: '.78rem', fontWeight: 700, color, background: `${color}1a`, border: `1px solid ${color}55` }}>
                  {t({ id: `deposit.status.${d.status}` })}
                </span>
                <span style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
                  #{d.emprestimo_id}
                  {d.collected_at && <> · {new Date(d.collected_at).toLocaleDateString()}</>}
                </span>
              </div>
            );
          })}
        </div>
      )}
    </>
  );
}
