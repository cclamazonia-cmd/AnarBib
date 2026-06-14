// ============================================================================
// ContributorAccountPage — conta allégée pour les comptes CONTRIBUTEUR
// ============================================================================
// Profil bénévole du réseau (network_contributors, sans bibliothèque) : pas de
// prêts / réservations / cotisations. Quatre sections (cf. cadrage) :
//   1. Contribuer       → liens atelier + catalogue (cœur de l'usage)
//   2. Mes contributions→ mes propositions (authority_proposals, RLS ap_read)
//   3. Mon statut       → network_contributors + bascule consentement e-mail
//   4. Profil & sécurité→ identité, mot de passe, export RGPD
// Rendue par ContaRouter quand l'utilisateur·rice est contributeur·rice pur·e
// (ligne network_contributors active + aucune bibliothèque). Réutilise les
// styles ab-conta-* de l'AccountPage.
// ============================================================================
import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { Button } from '@/components/ui';
import PhoneInput from '@/components/forms/PhoneInput';
import { localizeError } from '@/lib/localizeError';
import DataExportButton from '@/components/account/DataExportButton';
import './AccountPage.css';

// Couleur du statut d'une proposition.
const STATUS_COLOR = {
  open: 'var(--brand-muted)',
  contested: '#fbbf24',
  resolved_consent: '#4ade80',
  applied: '#4ade80',
  refused: '#f87171',
  withdrawn: 'var(--brand-muted)',
};

export default function ContributorAccountPage({ nc }) {
  const { formatMessage } = useIntl();
  const t = (d, v) => formatMessage(d, v);
  const { user } = useAuth();
  useDocumentTitle(t({ id: 'contributor.conta.pageTitle', defaultMessage: 'Mon compte contributeur' }));

  const [form, setForm] = useState({ first_name: '', last_name: '', email: '', phone: '', affiliation_org: '' });
  const [profMsg, setProfMsg] = useState(''); const [profErr, setProfErr] = useState(false); const [profSaving, setProfSaving] = useState(false);
  const [pwdNew, setPwdNew] = useState(''); const [pwdConfirm, setPwdConfirm] = useState('');
  const [pwdMsg, setPwdMsg] = useState(''); const [pwdErr, setPwdErr] = useState(false); const [pwdSaving, setPwdSaving] = useState(false);
  const [consent, setConsent] = useState(false); const [consentSaving, setConsentSaving] = useState(false);
  const [proposals, setProposals] = useState(null);

  // Charge le profil (identité + consentement) dans le formulaire.
  useEffect(() => {
    if (!user) return;
    let alive = true;
    supabase.from('profiles')
      .select('first_name,last_name,email,phone,affiliation_org,consent_email')
      .eq('id', user.id).maybeSingle()
      .then(({ data }) => {
        if (!alive || !data) return;
        setForm({
          first_name: data.first_name || '', last_name: data.last_name || '',
          email: data.email || '', phone: data.phone || '', affiliation_org: data.affiliation_org || '',
        });
        setConsent(data.consent_email === true);
      });
    return () => { alive = false; };
  }, [user]);

  // Charge mes propositions (RLS ap_read autorise un·e contributeur·rice).
  useEffect(() => {
    if (!user) return;
    let alive = true;
    supabase.from('authority_proposals')
      .select('id,kind,target_kind,target_id,merge_into_id,status,deadline,created_at')
      .eq('proposed_by', user.id).order('created_at', { ascending: false })
      .then(({ data }) => { if (alive) setProposals(data || []); });
    return () => { alive = false; };
  }, [user]);

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  async function saveProfile(e) {
    e.preventDefault();
    setProfMsg(''); setProfErr(false); setProfSaving(true);
    try {
      const { error } = await supabase.from('profiles').update({
        first_name: form.first_name, last_name: form.last_name,
        phone: form.phone, affiliation_org: form.affiliation_org,
      }).eq('id', user.id);
      if (error) throw error;
      setProfMsg(t({ id: 'account.reserve.dataSaved', defaultMessage: 'Données enregistrées.' }));
    } catch (err) { setProfMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) })); setProfErr(true); }
    finally { setProfSaving(false); }
  }

  async function changePassword(e) {
    e.preventDefault();
    setPwdMsg(''); setPwdErr(false);
    if (!pwdNew || pwdNew.length < 8) { setPwdMsg(t({ id: 'account.changePassword.error.tooShort' })); setPwdErr(true); return; }
    if (pwdNew !== pwdConfirm) { setPwdMsg(t({ id: 'account.changePassword.error.mismatch' })); setPwdErr(true); return; }
    setPwdSaving(true);
    try {
      const { error } = await supabase.auth.updateUser({ password: pwdNew });
      if (error) throw error;
      await supabase.from('profiles').update({ password_changed_at: new Date().toISOString(), must_change_password: false }).eq('id', user.id);
      setPwdMsg(t({ id: 'account.changePassword.success' })); setPwdErr(false); setPwdNew(''); setPwdConfirm('');
    } catch (err) { setPwdMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) })); setPwdErr(true); }
    finally { setPwdSaving(false); }
  }

  async function toggleConsent() {
    const next = !consent;
    setConsentSaving(true); setConsent(next);
    try {
      const { error } = await supabase.from('profiles')
        .update({ consent_email: next, consent_email_at: next ? new Date().toISOString() : null })
        .eq('id', user.id);
      if (error) throw error;
    } catch { setConsent(!next); /* rollback visuel */ }
    finally { setConsentSaving(false); }
  }

  const fmtDate = (d) => d ? new Date(d).toLocaleDateString() : '—';

  return (
    <PageShell><Topbar />
      <div style={{ maxWidth: 860, margin: '0 auto', padding: '24px 16px' }}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 4, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
          {t({ id: 'contributor.conta.title', defaultMessage: 'Mon espace contributeur·rice' })}
        </h1>
        <p style={{ color: 'var(--brand-muted)', marginBottom: 20, fontSize: '.9rem' }}>
          {t({ id: 'contributor.conta.subtitle', defaultMessage: 'Bénévole du réseau AnarBib — tu aides à améliorer le corpus partagé.' })}
        </p>

        <div className="ab-conta-card">
          <div className="ab-conta-panel">

            {/* ═══ 1. Contribuer ═══ */}
            <h2 className="ab-conta-section-title">{t({ id: 'contributor.conta.actions.title', defaultMessage: 'Contribuer' })}</h2>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, marginBottom: 6 }}>
              <Link to="/atelier-autoridades" style={{ textDecoration: 'none' }}>
                <Button variant="primary">{t({ id: 'contributor.conta.actions.atelier', defaultMessage: "Ouvrir l'atelier de contribution" })}</Button>
              </Link>
              <Link to="/catalogo" style={{ textDecoration: 'none' }}>
                <Button variant="secondary">{t({ id: 'contributor.conta.actions.catalog', defaultMessage: 'Explorer le catalogue' })}</Button>
              </Link>
            </div>
            <p className="ab-conta-hint">{t({ id: 'contributor.conta.actions.hint', defaultMessage: "Propose des fusions, corrections et traductions sur les autorités ; ou parcours le catalogue partagé." })}</p>

            <hr className="ab-conta-hr" />

            {/* ═══ 2. Mes contributions ═══ */}
            <h2 className="ab-conta-section-title">{t({ id: 'contributor.conta.proposals.title', defaultMessage: 'Mes contributions' })}</h2>
            {proposals === null ? (
              <p className="ab-conta-hint">{t({ id: 'common.loading', defaultMessage: 'Chargement…' })}</p>
            ) : proposals.length === 0 ? (
              <p className="ab-conta-hint">{t({ id: 'contributor.conta.proposals.empty', defaultMessage: "Tu n'as pas encore fait de proposition." })}</p>
            ) : (
              <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 8 }}>
                {proposals.map(p => (
                  <li key={p.id} style={{ padding: '10px 14px', borderRadius: 8, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center', justifyContent: 'space-between' }}>
                    <span style={{ fontSize: '.9rem' }}>
                      {t({ id: `contributor.conta.kind.${p.kind}`, defaultMessage: p.kind })}
                      {' · '}
                      {t({ id: `contributor.conta.targetKind.${p.target_kind}`, defaultMessage: p.target_kind })}
                      {p.target_id ? ` #${p.target_id}` : ''}
                      <span style={{ color: 'var(--brand-muted)', marginLeft: 8, fontSize: '.8rem' }}>{fmtDate(p.created_at)}</span>
                    </span>
                    <span style={{ fontSize: '.78rem', fontWeight: 700, color: STATUS_COLOR[p.status] || 'var(--brand-muted)' }}>
                      {t({ id: `contributor.conta.status.${p.status}`, defaultMessage: p.status })}
                    </span>
                  </li>
                ))}
              </ul>
            )}

            <hr className="ab-conta-hr" />

            {/* ═══ 3. Mon statut + notifications ═══ */}
            <h2 className="ab-conta-section-title">{t({ id: 'contributor.conta.statut.title', defaultMessage: 'Mon statut' })}</h2>
            <p style={{ margin: '0 0 6px' }}>
              <span style={{ fontWeight: 700, color: nc?.status === 'active' ? '#4ade80' : 'var(--brand-muted)' }}>
                {nc?.status === 'active'
                  ? t({ id: 'contributor.conta.statut.active', defaultMessage: 'Contributeur·rice actif·ve' })
                  : t({ id: 'contributor.conta.statut.inactive', defaultMessage: 'Compte contributeur·rice' })}
              </span>
              {nc?.joined_at && (
                <span style={{ color: 'var(--brand-muted)', marginLeft: 8, fontSize: '.85rem' }}>
                  {t({ id: 'contributor.conta.statut.since', defaultMessage: 'membre depuis le {date}' }, { date: fmtDate(nc.joined_at) })}
                </span>
              )}
            </p>
            <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: '.85rem', cursor: 'pointer', marginTop: 8 }}>
              <input type="checkbox" checked={consent} disabled={consentSaving} onChange={toggleConsent} />
              <span>{t({ id: 'contributor.conta.notif.consent', defaultMessage: 'Recevoir les communications par e-mail du réseau AnarBib (facultatif)' })}</span>
            </label>

            <hr className="ab-conta-hr" />

            {/* ═══ 4. Profil & sécurité ═══ */}
            <h2 className="ab-conta-section-title">{t({ id: 'account.profile.title', defaultMessage: 'Profil' })}</h2>
            <form onSubmit={saveProfile} className="ab-conta-form">
              <div className="ab-conta-grid2">
                <label>{t({ id: 'account.profile.firstName' })} <input type="text" value={form.first_name} onChange={e => set('first_name', e.target.value)} required /></label>
                <label>{t({ id: 'account.profile.lastName' })} <input type="text" value={form.last_name} onChange={e => set('last_name', e.target.value)} required /></label>
              </div>
              <label>{t({ id: 'contributor.conta.profile.email', defaultMessage: 'E-mail' })} <input type="email" value={form.email} disabled readOnly /></label>
              <label>{t({ id: 'account.profile.phone' })}
                <PhoneInput value={form.phone || ''} onChange={(v) => set('phone', v || '')} />
              </label>
              <label>{t({ id: 'account.profile.org' })} <input type="text" value={form.affiliation_org} maxLength={200} onChange={e => set('affiliation_org', e.target.value)} /></label>
              <div className="ab-conta-form-actions">
                <Button type="submit" loading={profSaving}>{t({ id: 'contributor.conta.profile.save', defaultMessage: 'Enregistrer' })}</Button>
                {profMsg && <span className={`ab-conta-msg ${profErr ? 'ab-conta-msg--error' : ''}`}>{profMsg}</span>}
              </div>
            </form>

            {/* Changement de mot de passe */}
            <div style={{ marginTop: 28, padding: 20, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
              <h3 style={{ margin: '0 0 4px', fontSize: '1.05rem', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
                {t({ id: 'account.changePassword.title' })}
              </h3>
              <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 14 }}>{t({ id: 'account.changePassword.hint' })}</div>
              <form onSubmit={changePassword} className="ab-conta-form">
                <div className="ab-conta-grid2">
                  <label>{t({ id: 'account.changePassword.newPassword' })}
                    <input type="password" value={pwdNew} onChange={e => setPwdNew(e.target.value)} autoComplete="new-password" minLength={8} required />
                  </label>
                  <label>{t({ id: 'account.changePassword.confirmPassword' })}
                    <input type="password" value={pwdConfirm} onChange={e => setPwdConfirm(e.target.value)} autoComplete="new-password" minLength={8} required />
                  </label>
                </div>
                <div className="ab-conta-form-actions">
                  <Button type="submit" loading={pwdSaving}>{t({ id: 'account.changePassword.submit' })}</Button>
                  {pwdMsg && <span className={`ab-conta-msg ${pwdErr ? 'ab-conta-msg--error' : ''}`}>{pwdMsg}</span>}
                </div>
              </form>
            </div>

            {/* Mes données (RGPD) */}
            <div style={{ marginTop: 20 }}>
              <h3 style={{ margin: '0 0 8px', fontSize: '1.05rem', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
                {t({ id: 'contributor.conta.privacy.title', defaultMessage: 'Mes données' })}
              </h3>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, alignItems: 'center' }}>
                <DataExportButton />
                <Link to="/privacidade" style={{ color: 'var(--brand-accent, #c44)', fontSize: '.85rem' }}>
                  {t({ id: 'contributor.conta.privacy.link', defaultMessage: 'Politique de confidentialité' })}
                </Link>
              </div>
            </div>

          </div>
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
