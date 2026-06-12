import { useState, useEffect } from 'react';
import { Button } from '@/components/ui';
import PhoneInput from '@/components/forms/PhoneInput';
import CountrySelect from '@/components/forms/CountrySelect';
import StateSelect from '@/components/forms/StateSelect';
import { getCountryMetadata } from '@/components/forms/countryData';
import { getCountryName } from '@/lib/countries';
import { parseAddressText, formatAddressText } from '@/lib/addressFormat';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { fmtD } from '../_shared';
import WriteToReaderBox from './WriteToReaderBox';
import ResolveCardBox from './ResolveCardBox';

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
  isLibrarian,
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
  readerMatchInfo,
  // handlers
  searchReader,
  openPaymentModal,
}) {
  // ── §21 PARTNER — transparence inter-biblios (Zone 21) ──────────────────
  // Autres appartenances de la lectrice : minimal par défaut (compte sans
  // identité), enrichi (nom + restriction) uniquement sous partenariat actif
  // ∧ droit transparence ∧ consentement. Auto-suffisant : la garde et le
  // filtrage sont faits par la RPC SECURITY DEFINER fn_painel_reader_other_memberships.
  const [otherMemberships, setOtherMemberships] = useState(null);
  const readerId = readerProfile?.id;
  useEffect(() => {
    let cancelled = false;
    if (!readerId || !libraryId) { setOtherMemberships(null); return; }
    (async () => {
      try {
        const { data, error } = await supabase.rpc('fn_painel_reader_other_memberships', {
          p_user_id: readerId, p_viewer_library_id: libraryId,
        });
        if (!cancelled) setOtherMemberships(error ? [] : (data || []));
      } catch { if (!cancelled) setOtherMemberships([]); }
    })();
    return () => { cancelled = true; };
  }, [readerId, libraryId]);

  return (
    <div>
      <h2 className="ab-painel-h2">{t({id:'panel.reader.manage'})}</h2>
      <div className="ab-painel-reader-search">
        <input type="text" value={readerLookup} onChange={e => setReaderLookup(e.target.value)}
          placeholder={t({id:'panel.reader.searchPlaceholderFull'})} className="ab-painel-input"
          onKeyDown={e => e.key === 'Enter' && searchReader()} />
        <Button onClick={searchReader}>{t({ id: 'common.search' })}</Button>
      </div>
      <p className="ab-painel-hint">{t({id:'panel.reader.searchHintIdentity'})}</p>
      <ResolveCardBox t={t} libraryId={libraryId} onResolved={(r) => setReaderLookup(r.public_id)} />
      {readerMsg && <p className="ab-painel-msg">{readerMsg}</p>}
      {readerProfile && readerMatchInfo?.isFallback && readerMatchInfo?.matchedLibraryName && (
        <p className="ab-painel-freeze-warn">
          {t({id:'panel.reader.foundInOtherLibrary'}, {library: readerMatchInfo.matchedLibraryName})}
        </p>
      )}
      {readerProfile && (
        <div className="ab-painel-reader-card">
          <h3>{readerProfile.first_name} {readerProfile.last_name}</h3>
          {readerMatchInfo?.localIdentity && (
            <p className="ab-painel-reader-identity">{t({id:'panel.reader.localIdentity'})}: <strong>{readerMatchInfo.localIdentity}</strong></p>
          )}
          <p>{t({id:'panel.reader.email'})}: {readerProfile.email} · {t({id:'panel.reader.id'})}: {readerProfile.public_id} · {t({id:'panel.reader.gender'})}: {readerProfile.gender ? t({id:`gender.${readerProfile.gender}`, defaultMessage: t({ id: 'panel.stage.unknown' })}) : '—'}</p>
          <p>{t({id:'panel.reader.registered'})}: {fmtD(readerProfile.created_at)} · {t({id:'panel.reader.restricted'})}: {readerProfile.is_restricted ? t({id:'panel.reader.yes'}) : t({id:'panel.reader.no'})} · {t({id:'panel.reader.passwordPending'})}: {readerProfile.must_change_password ? t({id:'panel.reader.yes'}) : t({id:'panel.reader.no'})}</p>

          {/* EA-10 : indicateur visuel du gel GLOBAL (detail dans le bloc dedie plus bas) */}
          {readerProfile.is_restricted && (
            <div className="ab-painel-frozen-badge">
              <span className="ab-painel-frozen-badge__text">
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
                <p className="ab-painel-addr-raw">
                  {String(readerProfile.address).replace(/\\n/g, '\n')}
                </p>
              );
            }
            // Affichage structuré : pays et état affichés dans la locale active
            const countryDisplay = a.country ? getCountryName(a.country, locale) : '';
            return (
              <div className="ab-painel-addr-display">
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

          {/* ── §21 PARTNER : transparence inter-biblios (autres appartenances) ── */}
          {Array.isArray(otherMemberships) && otherMemberships.length > 0 && (() => {
            const enriched = otherMemberships.filter(m => m.enriched);
            const minimalCount = otherMemberships.filter(m => !m.enriched).length;
            return (
              <div className="ab-painel-restrict-box">
                <div className="ab-painel-restrict-title">
                  {t({ id: 'panel.reader.otherMemberships.title' })}
                </div>
                {enriched.map(m => (
                  <p key={m.library_id} className="ab-painel-restrict-active">
                    {m.library_name}
                    {m.is_restricted && (
                      <span className="ab-painel-restrict-reason"> · {t({ id: 'panel.reader.otherMemberships.restricted' })}</span>
                    )}
                  </p>
                ))}
                {minimalCount > 0 && (
                  <p className="ab-painel-restrict-reason">
                    {t({ id: 'panel.reader.otherMemberships.minimal' }, { count: minimalCount })}
                  </p>
                )}
                <p className="ab-painel-freeze-warn">{t({ id: 'panel.reader.otherMemberships.hint' })}</p>
              </div>
            );
          })()}

          {/* ── Edit profile form ── */}
          <WriteToReaderBox t={t} libraryId={libraryId} reader={readerProfile} />

          <details className="ab-painel-edit-profile">
            <summary className="ab-painel-edit-summary">{t({id:'panel.reader.editProfile'})}</summary>
            <div className="ab-painel-field-grid ab-painel-field-grid--mt">
              <label>{t({id:'panel.reader.firstName'})}
                <input type="text" className="ab-painel-input" value={readerProfile.first_name || ''} onChange={e => setReaderProfile(p => ({...p, first_name: e.target.value}))} />
              </label>
              <label>{t({id:'panel.reader.lastName'})}
                <input type="text" className="ab-painel-input" value={readerProfile.last_name || ''} onChange={e => setReaderProfile(p => ({...p, last_name: e.target.value}))} />
              </label>
              <label>{t({id:'panel.reader.emailRef'})}
                <input type="email" className="ab-painel-input" value={readerProfile.email || ''} onChange={e => setReaderProfile(p => ({...p, email: e.target.value}))} />
              </label>
              <label>{t({id:'panel.reader.phone'})}
                <PhoneInput
                  value={readerProfile.phone || ''}
                  onChange={(v) => setReaderProfile(p => ({...p, phone: v || ''}))}
                />
              </label>
              <label>{t({id:'panel.reader.gender'})}
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
            <h4 className="ab-painel-addr-title">{t({id:'address.title'})}</h4>
            {(() => {
              const meta = getCountryMetadata(editAddrState.country);
              const setAddrField = (field, val) => setEditAddrState(prev => {
                const updated = { ...prev, [field]: val };
                // Reset state si le pays change (le code ISO 3166-2 deviendrait incohérent)
                if (field === 'country' && val !== prev.country) updated.state_region = '';
                return updated;
              });
              return (
                <div className="ab-painel-field-grid">
                  <label className="ab-painel-field--span2">{t({id:'address.country'})}
                    <CountrySelect
                      value={editAddrState.country}
                      onChange={(v) => setAddrField('country', v)}
                    />
                  </label>
                  <label className="ab-painel-field--span2">{t({id:'address.line1'})}
                    <input type="text" className="ab-painel-input" value={editAddrState.line1 || ''} onChange={e => setAddrField('line1', e.target.value)} placeholder={t({id:'address.line1.placeholder'})} />
                  </label>
                  <label className="ab-painel-field--span2">{t({id:'address.line2'})}
                    <input type="text" className="ab-painel-input" value={editAddrState.line2 || ''} onChange={e => setAddrField('line2', e.target.value)} placeholder={t({id:'address.line2.placeholder'})} />
                  </label>
                  <label>{t({id:'address.unit'})}
                    <input type="text" className="ab-painel-input" value={editAddrState.unit || ''} onChange={e => setAddrField('unit', e.target.value)} placeholder={t({id:'address.unit.placeholder'})} />
                  </label>
                  <label>{t({id:meta.postalCodeLabel})}
                    <input type="text" className="ab-painel-input" value={editAddrState.postal_code || ''} onChange={e => setAddrField('postal_code', e.target.value)} />
                  </label>
                  <label>{t({id:'address.district'})}
                    <input type="text" className="ab-painel-input" value={editAddrState.district || ''} onChange={e => setAddrField('district', e.target.value)} />
                  </label>
                  <label>{t({id:'address.city'})}
                    <input type="text" className="ab-painel-input" value={editAddrState.city || ''} onChange={e => setAddrField('city', e.target.value)} />
                  </label>
                  <label className="ab-painel-field--span2">{t({id:meta.stateLabel})}
                    <StateSelect
                      countryCode={editAddrState.country}
                      value={editAddrState.state_region || ''}
                      onChange={(v) => setAddrField('state_region', v)}
                    />
                  </label>
                </div>
              );
            })()}

            <div className="ab-painel-edit-actions">
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
                  setEditProfileMsg(t({id:'common.errorPrefix'}, {message: localizeError(err, t)}));
                }
              }}>{t({id:'panel.reader.saveProfile'})}</Button>
              {editProfileMsg && (
                <span className="ab-painel-edit-msg">
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
              <div className="ab-painel-restrict-box">
                <div className="ab-painel-restrict-title">
                  {t({ id: 'panel.reader.restrict.localTitle' }, { library: libraryName })}
                </div>
                {loc?.is_restricted ? (
                  <div>
                    <p className="ab-painel-restrict-active">
                      {t({ id: 'panel.reader.restrict.localActive' }, { who: loc.by_name || '—', when: fmtDate(loc.at) })}
                      {loc.reason && <><br/><span className="ab-painel-restrict-reason">{t({ id: 'panel.reader.restrict.reasonLabel' }, { reason: loc.reason })}</span></>}
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
                    <input type="text" className="ab-painel-input ab-painel-restrict-input" placeholder={t({id:'panel.reader.restrictReasonPlaceholder'})}
                      value={restrictReason || ''} onChange={e => setRestrictReason(e.target.value)} />
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
              <div className="ab-painel-freeze-box">
                <div className="ab-painel-freeze-title">
                  {t({ id: 'panel.reader.freeze.title' })}
                </div>
                <p className="ab-painel-freeze-warn">{t({ id: 'panel.reader.freeze.scopeWarning' })}</p>
                {glob?.is_restricted ? (
                  <div>
                    <p className="ab-painel-restrict-active">
                      {t({ id: 'panel.reader.freeze.active' }, { who: glob.by_name || '—', when: fmtDate(glob.since) })}
                      {glob.reason && <><br/><span className="ab-painel-restrict-reason">{t({ id: 'panel.reader.restrict.reasonLabel' }, { reason: glob.reason })}</span></>}
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
                    <input type="text" className="ab-painel-input ab-painel-restrict-input" placeholder={t({id:'panel.reader.freezeReasonPlaceholder'})}
                      value={freezeReason || ''} onChange={e => setFreezeReason(e.target.value)} />
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
          {/* Tout staff (librarian inclus) gère les cotisations au quotidien. */}
          {isLibrarian && membershipEnabled && (
            <div className="ab-painel-pay-box">
              <div className="ab-painel-pay-head">
                <h4 className="ab-painel-pay-title">{t({ id: 'membership.payment.historyTitle' })}</h4>
                <Button onClick={() => openPaymentModal({
                  user_id: readerProfile.id,
                  display_name: `${readerProfile.first_name || ''} ${readerProfile.last_name || ''}`.trim() || readerProfile.email,
                })} disabled={membershipRules.length === 0} title={membershipRules.length === 0 ? t({ id: 'panel.memberships.noRulesWarning.title' }) : undefined}>
                  + {t({ id: 'membership.action.recordPayment' })}
                </Button>
              </div>
              {readerPayments.length === 0 ? (
                <div className="ab-painel-pay-empty">
                  {t({ id: 'membership.payment.noPayments' })}
                </div>
              ) : (
                <div className="ab-painel-pay-list">
                  {readerPayments.map((p, i) => (
                    <div key={p.id} className="ab-painel-pay-row">
                      <div className="ab-painel-pay-row__inner">
                        <div className="ab-painel-pay-row__main">
                          <div className="ab-painel-pay-amount">
                            {p.amount_paid > 0
                              ? `${p.amount_paid} ${p.currency}`
                              : t({ id: `membership.method.${p.payment_method}` })}
                            <span className="ab-painel-pay-method">
                              · {t({ id: `membership.method.${p.payment_method}` })}
                            </span>
                          </div>
                          <div className="ab-painel-pay-meta">
                            {p.rule_name && <>{p.rule_name} · </>}
                            {t({ id: 'membership.payment.paidOn' }, { date: fmtD(p.paid_at) })}
                            {p.valid_until && <> · {t({ id: 'membership.validUntil' }, { date: p.valid_until })}</>}
                          </div>
                          {p.notes && (
                            <div className="ab-painel-pay-notes">{p.notes}</div>
                          )}
                          {p.recorded_by_name && (
                            <div className="ab-painel-pay-recorder">
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
