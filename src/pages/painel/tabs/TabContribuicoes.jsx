import { Button, Pill, EmptyState } from '@/components/ui';
import { fmtD, TabHeader } from '../_shared';
import { formatPublicId } from '@/lib/publicId';

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
  loadMembershipOverview,
}) {
  return (
    <div>
      <TabHeader title={t({ id: 'panel.memberships.title' })} onRefresh={loadMembershipOverview} />
      <p className="ab-painel-memb-hint">
        {t({ id: 'panel.memberships.hint' })}
      </p>

      {/* Bandeau d'avertissement si aucune règle active */}
      {membershipRules.length === 0 && (
        <div className="ab-painel-memb-warn">
          <div className="ab-painel-memb-warn__title">
            ⚠ {t({ id: 'panel.memberships.noRulesWarning.title' })}
          </div>
          <div className="ab-painel-memb-warn__body">
            {t({ id: 'panel.memberships.noRulesWarning.body' })}{' '}
            <a href="/biblioteca">
              {t({ id: 'panel.memberships.noRulesWarning.link' })}
            </a>
          </div>
        </div>
      )}

      {/* Filtres */}
      <div className="ab-painel-memb-filters">
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
           
          >
            {f.label} ({getMembershipFilterCount(f.key)})
          </button>
        ))}
      </div>

      {/* Tableau */}
      {membershipOverview.length === 0 ? (
        <EmptyState message={t({ id: 'panel.memberships.empty' })} />
      ) : (
        <div className="ab-painel-memb-list">
          {membershipOverview
            .filter(m => membershipFilter === 'all' || m.dues_status === membershipFilter)
            .map((m, i) => {
              const status = fmtMembershipStatus(m.dues_status, m.days_until_expiry);
              return (
                <div key={m.user_id} className="ab-painel-memb-row">
                  <div className="ab-painel-memb-row__main">
                    <div className="ab-painel-memb-name">
                      {m.display_name}
                      {m.public_id && <span className="ab-painel-memb-pubid">· {formatPublicId(m.public_id)}</span>}
                      {m.is_restricted && <Pill variant="danger" style={{ marginLeft: 6, fontSize: '.65rem' }}>⛔</Pill>}
                    </div>
                    <div className="ab-painel-memb-meta">
                      {m.email}
                      {m.last_paid_at && <> · {t({ id: 'membership.payment.lastPaid' }, { date: fmtD(m.last_paid_at) })}</>}
                      {m.last_amount_paid > 0 && <> · {m.last_amount_paid} {m.last_currency}</>}
                    </div>
                  </div>
                  <div className="ab-painel-memb-actions">
                    <Pill variant={status.variant}>{status.label}</Pill>
                    {status.detail && <span className="ab-painel-memb-detail">{status.detail}</span>}
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
