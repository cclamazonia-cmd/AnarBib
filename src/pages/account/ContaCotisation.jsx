import { useIntl } from 'react-intl';

// ═══════════════════════════════════════════════════════════
// AnarBib — la cotisation associative (Paquet E.4.5), en lecture seule, dans l'onglet « Données personnelles » de Mon
// compte. Sorti d'AccountPage.jsx tel quel (E6, AccountPage lot 7,
// 07/10/2026), lignes déplacées par script : statut, dernier paiement, règles, lien vers le règlement et historique ; les données restent au parent, qui les charge.
// Les props portent les noms du parent. Garde : conta-decisions-sous-le-
// profil.test.js relit l'onglet en remettant ce fichier à sa place.
// ═══════════════════════════════════════════════════════════

export default function ContaCotisation({ availability, membership, membershipRules, membershipPayments, libraryName, regimentoUrl }) {
  const { formatMessage: t } = useIntl();
  return (
    <>
      {availability.cotisacoes && (membership || membershipRules.length > 0) && (() => {
        const status = membership?.dues_status || 'not_applicable';
        const statusVariant = status === 'up_to_date' ? 'ok' : status === 'expired' ? 'danger' : status === 'never_paid' ? 'warn' : status === 'lifetime' ? 'ok' : 'default';
        const statusColor = statusVariant === 'ok' ? '#4ade80' : statusVariant === 'danger' ? '#f87171' : statusVariant === 'warn' ? '#fbbf24' : 'var(--brand-muted)';
        const lastPayment = membershipPayments[0]; // tri DESC
        const fmtD = d => d ? new Date(d).toLocaleDateString() : '—';
        return (
          <div style={{ marginTop: 32, padding: 20, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
            <h3 style={{ margin: '0 0 4px', fontSize: '1.05rem', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
              {t({ id: 'membership.config.title' })}
            </h3>
            <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 14 }}>
              {t({ id: 'membership.account.hint' }, { library: libraryName })}
            </div>

            {/* Statut principal */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16, flexWrap: 'wrap' }}>
              <span style={{ display: 'inline-block', padding: '4px 12px', borderRadius: 999, fontSize: '.85rem', fontWeight: 700, color: statusColor, background: `${statusColor}1a`, border: `1px solid ${statusColor}55` }}>
                {t({ id: `membership.status.${status === 'up_to_date' ? 'upToDate' : status === 'never_paid' ? 'neverPaid' : status === 'not_applicable' ? 'notApplicable' : status}` })}
              </span>
              {membership?.last_valid_until && status !== 'lifetime' && (
                <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                  {t({ id: 'membership.validUntil' }, { date: fmtD(membership.last_valid_until) })}
                  {membership.days_until_expiry != null && membership.days_until_expiry >= 0 && (
                    <> · {t({ id: 'membership.daysUntilExpiry.plural' }, { days: membership.days_until_expiry })}</>
                  )}
                </span>
              )}
            </div>

            {/* Dernier paiement */}
            {lastPayment && (
              <div style={{ marginBottom: 14 }}>
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', textTransform: 'uppercase', letterSpacing: '.04em', marginBottom: 4 }}>
                  {t({ id: 'membership.account.lastPayment' })}
                </div>
                <div style={{ fontSize: '.9rem' }}>
                  {lastPayment.amount_paid > 0
                    ? <strong>{lastPayment.amount_paid} {lastPayment.currency}</strong>
                    : <em>{t({ id: `membership.method.${lastPayment.payment_method}` })}</em>}
                  <span style={{ color: 'var(--brand-muted)', marginLeft: 8 }}>
                    · {t({ id: `membership.method.${lastPayment.payment_method}` })} · {t({ id: 'membership.payment.paidOn' }, { date: fmtD(lastPayment.paid_at) })}
                  </span>
                </div>
                {lastPayment.notes && (
                  <div style={{ fontSize: '.8rem', color: 'var(--brand-muted)', marginTop: 3, fontStyle: 'italic' }}>{lastPayment.notes}</div>
                )}
              </div>
            )}

            {/* Règles applicables (info) */}
            {membershipRules.length > 0 && (
              <div style={{ marginBottom: 14 }}>
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', textTransform: 'uppercase', letterSpacing: '.04em', marginBottom: 6 }}>
                  {t({ id: 'membership.account.applicableRules' })}
                </div>
                {membershipRules.map(r => (
                  <div key={r.id} style={{ fontSize: '.85rem', padding: '6px 10px', borderRadius: 6, background: 'rgba(0,0,0,.15)', marginBottom: 4 }}>
                    <strong>{r.name}</strong>
                    {r.amount_min > 0 && <span style={{ color: 'var(--brand-muted)' }}> · {t({ id: 'membership.rule.minimumAmount' }, { amount: r.amount_min, currency: r.currency })}</span>}
                    {r.amount_suggested && r.amount_suggested !== r.amount_min && (
                      <span style={{ color: 'var(--brand-muted)' }}> · {t({ id: 'membership.rule.suggestedAmount' }, { amount: r.amount_suggested, currency: r.currency })}</span>
                    )}
                    {r.is_required && <span style={{ marginLeft: 6, fontSize: '.7rem', padding: '1px 6px', borderRadius: 4, background: 'rgba(251,191,36,.15)', color: '#fbbf24' }}>{t({ id: 'membership.rule.required' })}</span>}
                  </div>
                ))}
              </div>
            )}

            {/* Lien vers le règlement et message d'orientation */}
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, alignItems: 'center', fontSize: '.82rem', color: 'var(--brand-muted)' }}>
              <span>{t({ id: 'membership.account.howToPay' })}</span>
              {regimentoUrl && (
                <a href={regimentoUrl} target="_blank" rel="noopener noreferrer" style={{ color: '#60a5fa', textDecoration: 'underline' }}>
                  {t({ id: 'membership.account.openRegulation' })}
                </a>
              )}
            </div>

            {/* Historique complet (si plusieurs paiements) */}
            {membershipPayments.length > 1 && (
              <details style={{ marginTop: 14 }}>
                <summary style={{ cursor: 'pointer', fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                  {t({ id: 'membership.account.fullHistory' }, { count: membershipPayments.length })}
                </summary>
                <div style={{ marginTop: 8, borderRadius: 6, overflow: 'hidden', border: '1px solid rgba(255,255,255,.06)' }}>
                  {membershipPayments.map((p, i) => (
                    <div key={p.id} style={{ padding: '8px 12px', fontSize: '.82rem', background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent', borderBottom: i < membershipPayments.length - 1 ? '1px solid rgba(255,255,255,.04)' : 'none' }}>
                      <div>
                        {p.amount_paid > 0 ? `${p.amount_paid} ${p.currency}` : t({ id: `membership.method.${p.payment_method}` })}
                        <span style={{ color: 'var(--brand-muted)', marginLeft: 8 }}>
                          · {t({ id: 'membership.payment.paidOn' }, { date: fmtD(p.paid_at) })}
                          {p.valid_until && <> · {t({ id: 'membership.validUntil' }, { date: fmtD(p.valid_until) })}</>}
                        </span>
                      </div>
                      {p.notes && <div style={{ fontStyle: 'italic', color: 'var(--brand-muted)', marginTop: 2 }}>{p.notes}</div>}
                    </div>
                  ))}
                </div>
              </details>
            )}
          </div>
        );
      })()}
    </>
  );
}
