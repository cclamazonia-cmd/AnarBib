import { Button, Pill, EmptyState } from '@/components/ui';
import { fmtD } from '../_shared';

// ═══════════════════════════════════════════════════════════
// TabContribuicoes — onglet « Contribuições / Cotisations » (E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Extrait de PanelPage.jsx (bloc tab === 'contribuicoes').
// La garde isCoordOrAdmin reste côté PanelPage (au niveau du tab===).
// Les modales (paiement, schedule, cancel) restent rendues dans
// PanelPage : openPaymentModal est passé en prop, mais la modale
// elle-même n'est PAS dans ce composant. Iso-comportement strict.
// ═══════════════════════════════════════════════════════════
export default function TabContribuicoes({
  t,
  membershipRules,
  membershipFilter, setMembershipFilter,
  membershipOverview,
  getMembershipFilterCount,
  fmtMembershipStatus,
  openPaymentModal,
}) {
  return (
    <div>
      <h2 className="ab-painel-h2">{t({ id: 'panel.memberships.title' })}</h2>
      <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem', marginBottom: 12 }}>
        {t({ id: 'panel.memberships.hint' })}
      </p>

      {/* Bandeau d'avertissement si aucune règle active */}
      {membershipRules.length === 0 && (
        <div style={{ padding: '12px 14px', borderRadius: 8, marginBottom: 14, background: 'rgba(251,146,60,.1)', border: '1px solid rgba(251,146,60,.3)', color: '#fdba74' }}>
          <div style={{ fontWeight: 600, fontSize: '.9rem', marginBottom: 4 }}>
            ⚠ {t({ id: 'panel.memberships.noRulesWarning.title' })}
          </div>
          <div style={{ fontSize: '.85rem' }}>
            {t({ id: 'panel.memberships.noRulesWarning.body' })}{' '}
            <a href="/biblioteca" style={{ color: '#fdba74', textDecoration: 'underline', fontWeight: 600 }}>
              {t({ id: 'panel.memberships.noRulesWarning.link' })}
            </a>
          </div>
        </div>
      )}

      {/* Filtres */}
      <div style={{ display: 'flex', gap: 6, marginBottom: 14, flexWrap: 'wrap' }}>
        {[
          { key: 'all', label: t({ id: 'panel.memberships.filter.all' }) },
          { key: 'up_to_date', label: t({ id: 'membership.status.upToDate' }) },
          { key: 'expired', label: t({ id: 'membership.status.expired' }) },
          { key: 'never_paid', label: t({ id: 'membership.status.neverPaid' }) },
        ].map(f => (
          <button
            key={f.key}
            onClick={() => setMembershipFilter(f.key)}
            className={`ab-button ab-button--mini ${membershipFilter === f.key ? '' : 'ab-button--ghost'}`}
            style={{ fontSize: '.8rem' }}
          >
            {f.label} ({getMembershipFilterCount(f.key)})
          </button>
        ))}
      </div>

      {/* Tableau */}
      {membershipOverview.length === 0 ? (
        <EmptyState message={t({ id: 'panel.memberships.empty' })} />
      ) : (
        <div style={{ borderRadius: 8, overflow: 'hidden', border: '1px solid rgba(255,255,255,.08)' }}>
          {membershipOverview
            .filter(m => membershipFilter === 'all' || m.dues_status === membershipFilter)
            .map((m, i) => {
              const status = fmtMembershipStatus(m.dues_status, m.days_until_expiry);
              return (
                <div key={m.user_id} style={{ padding: '10px 12px', background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent', borderBottom: '1px solid rgba(255,255,255,.04)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
                  <div style={{ flex: 1, minWidth: 220 }}>
                    <div style={{ fontSize: '.9rem', fontWeight: 600 }}>
                      {m.display_name}
                      {m.public_id && <span style={{ fontWeight: 400, color: 'var(--brand-muted)', marginLeft: 6 }}>· {m.public_id}</span>}
                      {m.is_restricted && <Pill variant="danger" style={{ marginLeft: 6, fontSize: '.65rem' }}>⛔</Pill>}
                    </div>
                    <div style={{ fontSize: '.8rem', color: 'var(--brand-muted)', marginTop: 2 }}>
                      {m.email}
                      {m.last_paid_at && <> · {t({ id: 'membership.payment.lastPaid' }, { date: fmtD(m.last_paid_at) })}</>}
                      {m.last_amount_paid > 0 && <> · {m.last_amount_paid} {m.last_currency}</>}
                    </div>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                    <Pill variant={status.variant}>{status.label}</Pill>
                    {status.detail && <span style={{ fontSize: '.78rem', color: 'var(--brand-muted)' }}>{status.detail}</span>}
                    <Button onClick={() => openPaymentModal({ user_id: m.user_id, display_name: m.display_name })} disabled={membershipRules.length === 0}>
                      + {t({ id: 'membership.action.recordPayment' })}
                    </Button>
                  </div>
                </div>
              );
            })}
        </div>
      )}
    </div>
  );
}
