// Onglet « Profil » de Mon compte — sorti d'AccountPage.jsx tel quel (E6,
// 23/10/2026), avec le formulaire d'adresse international qu'il est seul à
// monter. Composant « à sac de props » : la page garde tout l'état et les
// actions (enregistrer, effacer la mention déclarée, mot de passe), l'onglet
// les reçoit et ne fait qu'afficher. Garde : src/tests/conta-perfil-modales-montes.test.js.
import { lazy, Suspense } from 'react';
import { useIntl } from 'react-intl';
import { Button } from '@/components/ui';
import CountrySelect from '@/components/forms/CountrySelect';
import StateSelect from '@/components/forms/StateSelect';
import PhoneInput from '@/components/forms/PhoneInput';
import { getCountryMetadata } from '@/components/forms/countryData';
import MyLibraryContactCard from '@/components/account/MyLibraryContactCard';
import ContaDecisions from '@/pages/account/ContaDecisions';
import ContaMotDePasse from '@/pages/account/ContaMotDePasse';
import ContaDoubleFacteur from '@/pages/account/ContaDoubleFacteur';
import ContaCotisation from '@/pages/account/ContaCotisation';
import ContaDepot from '@/pages/account/ContaDepot';
import ContaSuppression from '@/pages/account/ContaSuppression';

// #REFACTOR 08/06 : carte-lecteur en chunk LAZY -> sort qrcode + jspdf (~200 ko+)
// du bundle. Chargée seulement au rendu de la section (reader_cards_enabled).
const ReaderCardSection = lazy(() => import('@/components/account/ReaderCardSection'));

export default function TabPerfil(p) {
  const { formatMessage: t } = useIntl();
  const {
    addr, availability, clearingDeclared, declaredMsg, declaredMsgIsError, deleteConfirm, deleting,
    deposits, handleChangePassword, handleClearDeclaredField, handleSaveProfile, lettreConsent,
    lettreMsg, lettreSaving, libraryName, membership, membershipPayments, membershipRules, msg,
    msgIsError, navigate, notifPrefs, notifPrefsMsg, notifPrefsSaving, profile, pwdConfirm, pwdMsg,
    pwdMsgIsError, pwdNew, pwdSaving, regimentoUrl, saveBloc, saving, setDeleteConfirm, setDeleting,
    setLettreConsent, setLettreMsg, setLettreSaving, setNotifPrefs, setNotifPrefsMsg,
    setNotifPrefsSaving, setPwdConfirm, setPwdNew, updateAddress, updateProfile,
  } = p;
  return (
            <div>
              <div>
              <h2 className="ab-conta-section-title">{t({ id: 'account.profile.title' })}</h2>
              <p className="ab-conta-hint">{t({ id: 'account.profile.hint' })}</p>

              <form onSubmit={handleSaveProfile} data-bloc="perfil" className="ab-conta-form">
                <div className="ab-conta-grid2">
                  <label>{t({ id: 'account.profile.firstName' })} <input type="text" value={profile.first_name || ''} onChange={e => updateProfile('first_name', e.target.value)} required /></label>
                  <label>{t({ id: 'account.profile.lastName' })} <input type="text" value={profile.last_name || ''} onChange={e => updateProfile('last_name', e.target.value)} /></label>
                </div>
                <label>{t({ id: 'account.profile.phone' })}
                  <PhoneInput
                    value={profile.phone || ''}
                    onChange={(v) => updateProfile('phone', v || '')}
                  />
                </label>
                <label>{t({ id: 'account.profile.gender' })}
                  <select value={profile.gender || ''} onChange={e => updateProfile('gender', e.target.value)}>
                    <option value="">—</option>
                    <option value="feminino">{t({ id: 'account.profile.gender.fem' })}</option>
                    <option value="masculino">{t({ id: 'account.profile.gender.masc' })}</option>
                    <option value="neutro">{t({ id: 'account.profile.gender.neutral' })}</option>
                    <option value="outro">{t({ id: 'account.profile.gender.other' })}</option>
                  </select>
                </label>
                <label>{t({ id: 'account.profile.org' })} <input type="text" value={profile.affiliation_org || ''} maxLength={200} onChange={e => updateProfile('affiliation_org', e.target.value)} /></label>

                <div className="ab-conta-form-actions">
                  <Button type="submit" loading={saving && saveBloc === 'perfil'} disabled={saving}>{t({ id: 'common.save' })}</Button>
                  {msg && saveBloc === 'perfil' && <span role="status" className={`ab-conta-msg ${msgIsError ? 'ab-conta-msg--error' : ''}`}>{msg}</span>}
                </div>
              </form>
              </div>

              {/* ── E19 — Ce que la page demande de décider, juste sous le profil : export,
                  notifications, lettre, côte à côte (une colonne sous 900 px). La suppression
                  du compte reste seule, tout en bas. ─────────────────────────────────── */}
              <ContaDecisions
                notifPrefs={notifPrefs} setNotifPrefs={setNotifPrefs}
                notifPrefsSaving={notifPrefsSaving} setNotifPrefsSaving={setNotifPrefsSaving}
                notifPrefsMsg={notifPrefsMsg} setNotifPrefsMsg={setNotifPrefsMsg}
                lettreConsent={lettreConsent} setLettreConsent={setLettreConsent}
                lettreSaving={lettreSaving} setLettreSaving={setLettreSaving}
                lettreMsg={lettreMsg} setLettreMsg={setLettreMsg}
              />

              {/* ── Ma bibliothèque (E19, 24/09/2026, décision de Xavier) : la carte vivait dans une colonne
                  à droite du profil ; plus haute que le formulaire, elle poussait les trois décisions sous
                  la ligne de flottaison d'un portable. Elle vient désormais après elles. ── */}
              <div className="ab-conta-bibliotheque">
                <MyLibraryContactCard />
              </div>

              {/* ── Adresse — second formulaire (E19, 21/09/2026) : sortie du formulaire du profil pour
                  que les trois décisions ci-dessus se voient sans défiler. Même enregistrement que le
                  profil (handleSaveProfile écrit les deux) : aucun des deux boutons ne perd de saisie. ── */}
              <form onSubmit={handleSaveProfile} data-bloc="adresse" className="ab-conta-form ab-conta-adresse">
                <h3 style={{ fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'address.title' })}</h3>
                <AddressForm addr={addr} onChange={updateAddress} />

                <div className="ab-conta-form-actions">
                  <Button type="submit" loading={saving && saveBloc === 'adresse'} disabled={saving}>{t({ id: 'common.save' })}</Button>
                  {msg && saveBloc === 'adresse' && <span role="status" className={`ab-conta-msg ${msgIsError ? 'ab-conta-msg--error' : ''}`}>{msg}</span>}
                </div>
              </form>

              {/* ── Paquet 7 criar-conta — Encadré privacy : biblio mentionnée ──── */}
              {profile.signup_intent_metadata?.library_name_mentioned && (
                <div className="ab-conta-notice" style={{ marginTop: 24 }}>
                  <strong>{t({ id: 'account.declared.title' })}</strong>
                  <p style={{ margin: '0 0 8px' }}>
                    {t({ id: 'account.declared.libLabel' })}{' '}
                    <em>{profile.signup_intent_metadata.library_name_mentioned}</em>
                  </p>
                  <p className="ab-conta-hint" style={{ margin: '0 0 10px' }}>
                    {t({ id: 'account.declared.hint' })}
                  </p>
                  {/* Decision C — l'encadré annonçait une lecture par la
                      coordination sans dire qu'elle dépend d'un consentement.
                      On affiche donc l'état réel des deux cases plutôt qu'une
                      promesse générale. Le bouton ci-dessous reste le seul
                      retrait possible : effacer la mention retire tout. */}
                  <p className="ab-conta-hint" style={{ margin: '0 0 10px' }}>
                    {t({ id: profile.signup_intent_metadata?.mention_contact_consent
                      ? 'account.declared.consent.contactYes'
                      : 'account.declared.consent.contactNo' })}
                    {' '}
                    {profile.signup_intent_metadata?.mention_contact_consent && t({
                      id: profile.signup_intent_metadata?.mention_attribution_consent
                        ? 'account.declared.consent.attributionYes'
                        : 'account.declared.consent.attributionNo' })}
                  </p>
                  <Button
                    type="button"
                    variant="danger"
                    loading={clearingDeclared}
                    onClick={handleClearDeclaredField}
                  >
                    {t({ id: 'account.declared.deleteBtn' })}
                  </Button>
                  {declaredMsg && (
                    <span className={`ab-conta-msg ${declaredMsgIsError ? 'ab-conta-msg--error' : ''}`} style={{ marginLeft: 12 }}>
                      {declaredMsg}
                    </span>
                  )}
                </div>
              )}

              {/* ── Lot 26.1a — Changement de mot de passe ────────── */}
              <ContaMotDePasse pwdNew={pwdNew} setPwdNew={setPwdNew} pwdConfirm={pwdConfirm} setPwdConfirm={setPwdConfirm} pwdSaving={pwdSaving} pwdMsg={pwdMsg} pwdMsgIsError={pwdMsgIsError} handleChangePassword={handleChangePassword} />

              {/* ── B42 — Double authentification (TOTP), juste sous le mot de passe ── */}
              <ContaDoubleFacteur />

              {/* ── Cotisation associative ─────────────── */}
              {/* Paquet E.4.5 : ajoute le check availability.cotisacoes (depend de
                  circulation_mode et membership_enabled de la biblio) */}
              <ContaCotisation availability={availability} membership={membership} membershipRules={membershipRules} membershipPayments={membershipPayments} libraryName={libraryName} regimentoUrl={regimentoUrl} />

              {/* ── Dépôt de garantie (DEPOT §8) ───────────
                  Masqué si la lectrice n'a aucun dépôt (défaut). */}
              <ContaDepot deposits={deposits} />

              {/* ── Carte-lecteur (lazy : sort qrcode + jspdf du bundle) ── */}
              {availability.reader_card && (
                <Suspense fallback={null}>
                  <ReaderCardSection />
                </Suspense>
              )}

              {/* ── Suppression du compte — zone destructive isolee tout en bas (deplacee depuis la section RGPD, 04/06/2026) ── */}
              <ContaSuppression deleteConfirm={deleteConfirm} setDeleteConfirm={setDeleteConfirm} deleting={deleting} setDeleting={setDeleting} navigate={navigate} />
            </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Formulaire d'adresse international
// ───────────────────────────────────────────────────────────
// Utilise les composants partagés CountrySelect / StateSelect
// du dossier @/components/forms, qui gèrent :
//   - liste complète des pays via i18n-iso-countries (localisée)
//   - listes fermées d'états/provinces pour BR/FR/ES/IT/DE/AR/MX/CH
//   - labels via getCountryMetadata (clés i18n par pays)
//
// Les valeurs internes sont des codes ISO :
//   - addr.country : ISO 3166-1 alpha-2 (ex: 'BR', 'FR')
//   - addr.state_region : ISO 3166-2 si pays a une liste fermée,
//                         sinon texte libre
// ═══════════════════════════════════════════════════════════

function AddressForm({ addr, onChange }) {
  const { formatMessage: t } = useIntl();
  const country = addr.country || '';
  const meta = getCountryMetadata(country);

  return (
    <>
      <label>{t({ id: 'address.country' })}
        <CountrySelect
          value={country}
          onChange={(v) => {
            // Reset de l'état si le pays change (sinon code ISO 3166-2 incohérent)
            onChange('country', v);
            if (v !== country) onChange('state_region', '');
          }}
        />
      </label>

      <label>{t({ id: 'address.line1' })}
        <input
          type="text"
          value={addr.line1 || ''}
          onChange={e => onChange('line1', e.target.value)}
          placeholder={t({ id: 'address.line1.placeholder' })}
        />
      </label>
      <label>{t({ id: 'address.line2' })}
        <input
          type="text"
          value={addr.line2 || ''}
          onChange={e => onChange('line2', e.target.value)}
          placeholder={t({ id: 'address.line2.placeholder' })}
        />
      </label>

      <div className="ab-conta-grid3">
        <label>{t({ id: 'address.unit' })}
          <input
            type="text"
            value={addr.unit || ''}
            onChange={e => onChange('unit', e.target.value)}
            placeholder={t({ id: 'address.unit.placeholder' })}
          />
        </label>
        <label>{t({ id: meta.postalCodeLabel })}
          <input
            type="text"
            value={addr.postal_code || ''}
            onChange={e => onChange('postal_code', e.target.value)}
          />
        </label>
        <label>{t({ id: 'address.district' })}
          <input
            type="text"
            value={addr.district || ''}
            onChange={e => onChange('district', e.target.value)}
          />
        </label>
        <label>{t({ id: 'address.city' })}
          <input
            type="text"
            value={addr.city || ''}
            onChange={e => onChange('city', e.target.value)}
          />
        </label>
      </div>

      <label>{t({ id: meta.stateLabel })}
        <StateSelect
          countryCode={country}
          value={addr.state_region || ''}
          onChange={(v) => onChange('state_region', v)}
        />
      </label>
    </>
  );
}
