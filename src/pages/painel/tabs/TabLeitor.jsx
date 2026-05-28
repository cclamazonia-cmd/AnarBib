import { Button } from '@/components/ui';
import PhoneInput from '@/components/forms/PhoneInput';
import CountrySelect from '@/components/forms/CountrySelect';
import StateSelect from '@/components/forms/StateSelect';
import { getCountryMetadata } from '@/components/forms/countryData';
import { getCountryName } from '@/lib/countries';
import { parseAddressText, formatAddressText } from '@/lib/addressFormat';
import { supabase } from '@/lib/supabase';
import { fmtD } from '../_shared';

// ═══════════════════════════════════════════════════════════
// TabLeitor — onglet « Gérer lecteur·rice » (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Extrait de PanelPage.jsx (bloc tab === 'leitor'). Le plus riche en
// logique : recherche, édition de profil + adresse, restriction LOCALE
// (membership) et gel GLOBAL (profile, admin réseau) — code EA-10 —,
// historique de cotisations. Présentational : tout l'état et les
// handlers restent dans PanelPage, passés en props. Iso-comportement.
// ═══════════════════════════════════════════════════════════
export default function TabLeitor({
  t,
  locale,
  libraryId,
  libraryName,
  isNetworkAdmin,
  isCoordOrAdmin,
  membershipEnabled,
  // état
  readerLookup, setReaderLookup,
  readerProfile, setReaderProfile,
  readerMsg, setReaderMsg,
  editAddrState, setEditAddrState,
  editProfileMsg, setEditProfileMsg,
  restrictReason, setRestrictReason,
  restrictionState, setRestrictionState,
  restrictBusy, setRestrictBusy,
  freezeReason, setFreezeReason,
  readerPayments,
  membershipRules,
  // handlers
  searchReader,
  openPaymentModal,
}) {
  return (
    <div>
      <h2 className="ab-painel-h2">{t({id:'panel.reader.manage'})}</h2>
      <div className="ab-painel-reader-search">
        <input type="text" value={readerLookup} onChange={e => setReaderLookup(e.target.value)}
          placeholder={t({id:'panel.reader.searchPlaceholderFull'})} className="ab-painel-input"
          onKeyDown={e => e.key === 'Enter' && searchReader()} />
        <Button onClick={searchReader}>{t({ id: 'common.search' })}</Button>
      </div>
      {readerMsg && <p className="ab-painel-msg">{readerMsg}</p>}
      {readerProfile && (
        <div className="ab-painel-reader-card">
          <h3>{readerProfile.first_name} {readerProfile.last_name}</h3>
          <p>{t({id:'panel.reader.email'})}: {readerProfile.email} · {t({id:'panel.reader.id'})}: {readerProfile.public_id} · {t({id:'panel.reader.gender'})}: {readerProfile.gender ? t({id:`gender.${readerProfile.gender}`, defaultMessage: t({ id: 'panel.stage.unknown' })}) : '—'}</p>
          <p>{t({id:'panel.reader.registered'})}: {fmtD(readerProfile.created_at)} · {t({id:'panel.reader.restricted'})}: {readerProfile.is_restricted ? t({id:'panel.reader.yes'}) : t({id:'panel.reader.no'})} · {t({id:'panel.reader.passwordPending'})}: {readerProfile.must_change_password ? t({id:'panel.reader.yes'}) : t({id:'panel.reader.no'})}</p>

          {/* EA-10 : indicateur visuel du gel GLOBAL (detail dans le bloc dedie plus bas) */}
          {readerProfile.is_restricted && (
            <div style={{ margin: '10px 0', padding: '8px 12px', borderRadius: 8, background: 'rgba(220,38,38,.15)', border: '1px solid rgba(220,38,38,.3)' }}>
              <span style={{ fontWeight: 600, fontSize: '.85rem' }}>
                {t({id:'panel.reader.globalFrozenBadge'}, { reason: readerProfile.restricted_reason || '—' })}
              </span>
            </div>
          )}

          {/* Address display — uses parseAddressText to support all legacy formats */}
          {readerProfile.address && (() => {
            const a = parseAddressText(readerProfile.address);
            if (!a.line1 && !a.city && !a.country) {
              // Pas d'adresse exploitable : fallback texte brut
              return (
                <p style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', margin: '6px 0', whiteSpace: 'pre-line' }}>
                  {String(readerProfile.address).replace(/\\n/g, '\n')}
                </p>
              );
            }
            // Affichage structuré : pays et état affichés dans la locale active
            const countryDisplay = a.country ? getCountryName(a.country, locale) : '';
            return (
              <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', margin: '6px 0' }}>
                {a.line1 && <span>{t({id:'address.line1'})}: {a.line1}</span>}
                {a.line2 && <span> · {t({id:'address.line2'})}: {a.line2}</span>}
                {a.unit && <span> · {t({id:'address.unit'})}: {a.unit}</span>}
                {a.postal_code && <span> · {t({id:'address.postalCode.generic'})}: {a.postal_code}</span>}
                {a.district && <span> · {t({id:'address.district'})}: {a.district}</span>}
                {a.city && <span> · {t({id:'address.city'})}: {a.city}</span>}
                {a.state_region && <span> · {t({id:'address.state.generic'})}: {a.state_region}</span>}
                {countryDisplay && <span> · {t({id:'address.country'})}: {countryDisplay}</span>}
              </div>
            );
          })()}

          {/* ── Edit profile form ── */}
          <details className="ab-painel-edit-profile" style={{ marginTop: 12 }}>
            <summary style={{ cursor: 'pointer', fontWeight: 600, fontSize: '.9rem' }}>{t({id:'panel.reader.editProfile'})}</summary>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginTop: 8 }}>
              <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.firstName'})}
                <input type="text" className="ab-painel-input" value={readerProfile.first_name || ''} onChange={e => setReaderProfile(p => ({...p, first_name: e.target.value}))} />
              </label>
              <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.lastName'})}
                <input type="text" className="ab-painel-input" value={readerProfile.last_name || ''} onChange={e => setReaderProfile(p => ({...p, last_name: e.target.value}))} />
              </label>
              <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.emailRef'})}
                <input type="email" className="ab-painel-input" value={readerProfile.email || ''} onChange={e => setReaderProfile(p => ({...p, email: e.target.value}))} />
              </label>
              <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.phone'})}
                <PhoneInput
                  value={readerProfile.phone || ''}
                  onChange={(v) => setReaderProfile(p => ({...p, phone: v || ''}))}
                />
              </label>
              <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.gender'})}
                <select className="ab-painel-input" value={readerProfile.gender || ''} onChange={e => setReaderProfile(p => ({...p, gender: e.target.value}))}>
                  <option value="">—</option>
                  <option value="feminino">{t({id:'account.profile.gender.fem'})}</option>
                  <option value="masculino">{t({id:'account.profile.gender.masc'})}</option>
                  <option value="neutro">{t({id:'account.profile.gender.neutral'})}</option>
                  <option value="outro">{t({id:'account.profile.gender.other'})}</option>
                </select>
              </label>
            </div>

            {/* ── Address fields ── Uses shared CountrySelect/StateSelect components.
                State local (editAddrState) pour l'édition, sérialisation au format
                canonique multi-ligne avec [XX] uniquement au moment de la sauvegarde
                (cf. addressFormat.js). Évite la boucle parse→format→parse à chaque
                frappe qui causait des bugs de saisie (espaces mangés par .trim()). */}
            <h4 style={{ margin: '12px 0 6px', fontSize: '.88rem', fontWeight: 600 }}>{t({id:'address.title'})}</h4>
            {(() => {
              const meta = getCountryMetadata(editAddrState.country);
              const setAddrField = (field, val) => setEditAddrState(prev => {
                const updated = { ...prev, [field]: val };
                // Reset state si le pays change (le code ISO 3166-2 deviendrait incohérent)
                if (field === 'country' && val !== prev.country) updated.state_region = '';
                return updated;
              });
              return (
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                  <label style={{ fontSize: '.82rem', gridColumn: 'span 2' }}>{t({id:'address.country'})}
                    <CountrySelect
                      value={editAddrState.country}
                      onChange={(v) => setAddrField('country', v)}
                    />
                  </label>
                  <label style={{ fontSize: '.82rem', gridColumn: 'span 2' }}>{t({id:'address.line1'})}
                    <input type="text" className="ab-painel-input" value={editAddrState.line1 || ''} onChange={e => setAddrField('line1', e.target.value)} placeholder={t({id:'address.line1.placeholder'})} />
                  </label>
                  <label style={{ fontSize: '.82rem', gridColumn: 'span 2' }}>{t({id:'address.line2'})}
                    <input type="text" className="ab-painel-input" value={editAddrState.line2 || ''} onChange={e => setAddrField('line2', e.target.value)} placeholder={t({id:'address.line2.placeholder'})} />
                  </label>
                  <label style={{ fontSize: '.82rem' }}>{t({id:'address.unit'})}
                    <input type="text" className="ab-painel-input" value={editAddrState.unit || ''} onChange={e => setAddrField('unit', e.target.value)} placeholder={t({id:'address.unit.placeholder'})} />
                  </label>
                  <label style={{ fontSize: '.82rem' }}>{t({id:meta.postalCodeLabel})}
                    <input type="text" className="ab-painel-input" value={editAddrState.postal_code || ''} onChange={e => setAddrField('postal_code', e.target.value)} />
                  </label>
                  <label style={{ fontSize: '.82rem' }}>{t({id:'address.district'})}
                    <input type="text" className="ab-painel-input" value={editAddrState.district || ''} onChange={e => setAddrField('district', e.target.value)} />
                  </label>
                  <label style={{ fontSize: '.82rem' }}>{t({id:'address.city'})}
                    <input type="text" className="ab-painel-input" value={editAddrState.city || ''} onChange={e => setAddrField('city', e.target.value)} />
                  </label>
                  <label style={{ fontSize: '.82rem', gridColumn: 'span 2' }}>{t({id:meta.stateLabel})}
                    <StateSelect
                      countryCode={editAddrState.country}
                      value={editAddrState.state_region || ''}
                      onChange={(v) => setAddrField('state_region', v)}
                    />
                  </label>
                </div>
              );
            })()}

            <div style={{ marginTop: 10, display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
              <Button onClick={async () => {
                setEditProfileMsg('');
                try {
                  // Sérialisation de editAddrState en texte canonique au moment de la sauvegarde.
                  const updateData = {
                    first_name: readerProfile.first_name, last_name: readerProfile.last_name,
                    phone: readerProfile.phone, gender: readerProfile.gender,
                    email: readerProfile.email,
                    address: formatAddressText(editAddrState, locale),
                  };
                  const { error } = await supabase.from('profiles').update(updateData).eq('id', readerProfile.id);
                  if (error) throw error;
                  // On synchronise readerProfile.address aussi pour que la zone d'affichage
                  // au-dessus se mette à jour sans nécessiter un reload de la page.
                  setReaderProfile(p => ({ ...p, address: formatAddressText(editAddrState, locale) }));
                  setEditProfileMsg(t({id:'panel.reader.profileSaved'}));
                } catch (err) {
                  setEditProfileMsg(t({id:'common.errorPrefix'}, {message: err.message}));
                }
              }}>{t({id:'panel.reader.saveProfile'})}</Button>
              {editProfileMsg && (
                <span style={{ fontSize: '.85rem', color: 'var(--brand-text)', fontWeight: 600 }}>
                  {editProfileMsg}
                </span>
              )}
            </div>
          </details>

          {/* ── EA-10 (chantier D) : Restriction LOCALE (membership) ── */}
          {(() => {
            const loc = restrictionState?.local;
            const glob = restrictionState?.global;
            const fmtDate = d => d ? new Date(d).toLocaleDateString() : '—';
            const reloadRestriction = async () => {
              try {
                const { data: rs } = await supabase.schema('api').rpc('get_member_restriction', { p_user_id: readerProfile.id, p_library_id: libraryId });
                setRestrictionState(rs?.ok ? rs : null);
              } catch { /* garder l'etat */ }
            };
            const handleErr = (data, err) => {
              const reason = err ? 'unknown' : (data?.reason || 'unknown');
              setReaderMsg(t({ id: `panel.reader.restrict.error.${reason}`, defaultMessage: t({id:'panel.reader.restrict.error.unknown'}) }));
            };
            return (
              <div style={{ marginTop: 12, padding: '10px 12px', borderRadius: 8, background: 'rgba(0,0,0,.15)' }}>
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted)', textTransform: 'uppercase', letterSpacing: '.04em', marginBottom: 8 }}>
                  {t({ id: 'panel.reader.restrict.localTitle' }, { library: libraryName })}
                </div>
                {loc?.is_restricted ? (
                  <div>
                    <p style={{ margin: '0 0 8px', fontSize: '.85rem' }}>
                      {t({ id: 'panel.reader.restrict.localActive' }, { who: loc.by_name || '—', when: fmtDate(loc.at) })}
                      {loc.reason && <><br/><span style={{ color: 'var(--brand-muted)' }}>{t({ id: 'panel.reader.restrict.reasonLabel' }, { reason: loc.reason })}</span></>}
                    </p>
                    <Button variant="secondary" disabled={restrictBusy} onClick={async () => {
                      if (!confirm(t({id:'panel.reader.unrestrictConfirm'}))) return;
                      setRestrictBusy(true);
                      try {
                        const { data, error } = await supabase.schema('api').rpc('unrestrict_member', { p_user_id: readerProfile.id, p_library_id: libraryId });
                        if (error || !data?.ok) { handleErr(data, error); return; }
                        await reloadRestriction(); setReaderMsg(t({id:'common.dataSaved'}));
                      } finally { setRestrictBusy(false); }
                    }}>{t({id:'panel.reader.unrestrictAction'})}</Button>
                  </div>
                ) : (
                  <div>
                    <input type="text" className="ab-painel-input" placeholder={t({id:'panel.reader.restrictReasonPlaceholder'})}
                      value={restrictReason || ''} onChange={e => setRestrictReason(e.target.value)} style={{ marginBottom: 6, width: '100%' }} />
                    <Button variant="secondary" disabled={restrictBusy} onClick={async () => {
                      if (!restrictReason?.trim()) return;
                      if (!confirm(t({id:'panel.reader.restrictConfirm'}))) return;
                      setRestrictBusy(true);
                      try {
                        const { data, error } = await supabase.schema('api').rpc('restrict_member', { p_user_id: readerProfile.id, p_library_id: libraryId, p_reason: restrictReason.trim() });
                        if (error || !data?.ok) { handleErr(data, error); return; }
                        setRestrictReason(''); await reloadRestriction(); setReaderMsg(t({id:'common.dataSaved'}));
                      } finally { setRestrictBusy(false); }
                    }}>{t({id:'panel.reader.restrictAction'})}</Button>
                  </div>
                )}
              </div>
            );
          })()}

          {/* ── EA-10 : Gel GLOBAL (profile) ─ admin reseau seulement, bloc distinct ── */}
          {isNetworkAdmin && (() => {
            const glob = restrictionState?.global;
            const fmtDate = d => d ? new Date(d).toLocaleDateString() : '—';
            const reloadRestriction = async () => {
              try {
                const { data: rs } = await supabase.schema('api').rpc('get_member_restriction', { p_user_id: readerProfile.id, p_library_id: libraryId });
                setRestrictionState(rs?.ok ? rs : null);
              } catch { /* garder */ }
            };
            const handleErr = (data, err) => {
              const reason = err ? 'unknown' : (data?.reason || 'unknown');
              setReaderMsg(t({ id: `panel.reader.freeze.error.${reason}`, defaultMessage: t({id:'panel.reader.restrict.error.unknown'}) }));
            };
            return (
              <div style={{ marginTop: 12, padding: '10px 12px', borderRadius: 8, background: 'rgba(220,38,38,.10)', border: '1px solid rgba(220,38,38,.35)' }}>
                <div style={{ fontSize: '.8rem', color: '#f87171', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '.04em', marginBottom: 4 }}>
                  {t({ id: 'panel.reader.freeze.title' })}
                </div>
                <p style={{ margin: '0 0 8px', fontSize: '.8rem', color: 'var(--brand-muted)' }}>{t({ id: 'panel.reader.freeze.scopeWarning' })}</p>
                {glob?.is_restricted ? (
                  <div>
                    <p style={{ margin: '0 0 8px', fontSize: '.85rem' }}>
                      {t({ id: 'panel.reader.freeze.active' }, { who: glob.by_name || '—', when: fmtDate(glob.since) })}
                      {glob.reason && <><br/><span style={{ color: 'var(--brand-muted)' }}>{t({ id: 'panel.reader.restrict.reasonLabel' }, { reason: glob.reason })}</span></>}
                    </p>
                    <Button variant="secondary" disabled={restrictBusy} onClick={async () => {
                      if (!confirm(t({id:'panel.reader.unfreezeConfirm'}))) return;
                      setRestrictBusy(true);
                      try {
                        const { data, error } = await supabase.schema('api').rpc('unfreeze_account', { p_user_id: readerProfile.id });
                        if (error || !data?.ok) { handleErr(data, error); return; }
                        await reloadRestriction(); setReaderMsg(t({id:'common.dataSaved'}));
                      } finally { setRestrictBusy(false); }
                    }}>{t({id:'panel.reader.unfreezeAction'})}</Button>
                  </div>
                ) : (
                  <div>
                    <input type="text" className="ab-painel-input" placeholder={t({id:'panel.reader.freezeReasonPlaceholder'})}
                      value={freezeReason || ''} onChange={e => setFreezeReason(e.target.value)} style={{ marginBottom: 6, width: '100%' }} />
                    <Button variant="secondary" disabled={restrictBusy} onClick={async () => {
                      if (!freezeReason?.trim()) return;
                      if (!confirm(t({id:'panel.reader.freezeConfirm'}))) return;
                      setRestrictBusy(true);
                      try {
                        const { data, error } = await supabase.schema('api').rpc('freeze_account', { p_user_id: readerProfile.id, p_reason: freezeReason.trim() });
                        if (error || !data?.ok) { handleErr(data, error); return; }
                        setFreezeReason(''); await reloadRestriction(); setReaderMsg(t({id:'common.dataSaved'}));
                      } finally { setRestrictBusy(false); }
                    }}>{t({id:'panel.reader.freezeAction'})}</Button>
                  </div>
                )}
              </div>
            );
          })()}

          {/* ── Histórico de contribuições (cotisation) ── */}
          {isCoordOrAdmin && membershipEnabled && (
            <div style={{ marginTop: 16, padding: 12, borderRadius: 8, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8, gap: 8, flexWrap: 'wrap' }}>
                <h4 style={{ margin: 0, fontSize: '.95rem', fontWeight: 700 }}>{t({ id: 'membership.payment.historyTitle' })}</h4>
                <Button onClick={() => openPaymentModal({
                  user_id: readerProfile.id,
                  display_name: `${readerProfile.first_name || ''} ${readerProfile.last_name || ''}`.trim() || readerProfile.email,
                })} disabled={membershipRules.length === 0} title={membershipRules.length === 0 ? t({ id: 'panel.memberships.noRulesWarning.title' }) : undefined}>
                  + {t({ id: 'membership.action.recordPayment' })}
                </Button>
              </div>
              {readerPayments.length === 0 ? (
                <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', padding: '8px 0' }}>
                  {t({ id: 'membership.payment.noPayments' })}
                </div>
              ) : (
                <div style={{ borderRadius: 8, overflow: 'hidden', border: '1px solid rgba(255,255,255,.06)' }}>
                  {readerPayments.map((p, i) => (
                    <div key={p.id} style={{ padding: '10px 12px', background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent', borderBottom: i < readerPayments.length - 1 ? '1px solid rgba(255,255,255,.04)' : 'none' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8, flexWrap: 'wrap' }}>
                        <div style={{ flex: 1, minWidth: 200 }}>
                          <div style={{ fontSize: '.9rem', fontWeight: 600 }}>
                            {p.amount_paid > 0
                              ? `${p.amount_paid} ${p.currency}`
                              : t({ id: `membership.method.${p.payment_method}` })}
                            <span style={{ fontWeight: 400, color: 'var(--brand-muted)', marginLeft: 8 }}>
                              · {t({ id: `membership.method.${p.payment_method}` })}
                            </span>
                          </div>
                          <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginTop: 2 }}>
                            {p.rule_name && <>{p.rule_name} · </>}
                            {t({ id: 'membership.payment.paidOn' }, { date: fmtD(p.paid_at) })}
                            {p.valid_until && <> · {t({ id: 'membership.validUntil' }, { date: p.valid_until })}</>}
                          </div>
                          {p.notes && (
                            <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)', marginTop: 3, fontStyle: 'italic' }}>{p.notes}</div>
                          )}
                          {p.recorded_by_name && (
                            <div style={{ fontSize: '.74rem', color: 'var(--brand-muted)', marginTop: 2 }}>
                              {t({ id: 'membership.payment.recordedBy' }, { name: p.recorded_by_name })}
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
