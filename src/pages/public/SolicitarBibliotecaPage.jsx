import { useState, useEffect, useMemo } from 'react';
import { useNavigate, Link, useSearchParams } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { Button } from '@/components/ui';

// PATCH 12/05/2026 paquet 24a — i18n complète de la page.
// PATCH 12/05/2026 paquet 24b — remplacement sémantique de "Cadastro" par "Login"
// (les liens pointaient déjà vers la route de connexion ; seul le libellé était trompeur).

export default function SolicitarBibliotecaPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { user, profile, refreshProfile } = useAuth();
  const { formatMessage: t } = useIntl();
  useDocumentTitle(t({ id: 'pageTitle.libraryRequest' }));

  // Paquet 25.8 — Claim token depuis l'URL (?claim=<token>).
  // Quand un usager s'est inscrit "sem biblioteca" via /criar-conta, le mail
  // de bienvenue contient un CTA vers /solicitar-biblioteca?claim=<token>.
  // Le token est valide 14 jours et lié à son compte (email_snapshot).
  // À la soumission du formulaire on appellera fn_submit_library_request_via_claim
  // qui consommera atomiquement le claim et créera la library_request.
  const claimToken = searchParams.get('claim') || '';

  // claimContext stocke le résultat de fn_get_library_request_claim_context :
  //  - null     : pas encore vérifié (init) ou pas de claim dans l'URL
  //  - 'valid'  : le claim existe, n'est pas expiré, n'est pas consommé
  //  - 'invalid': le claim est inconnu, expiré, ou déjà consommé
  // Quand claimContext === 'valid', on garde aussi claimEmailSnapshot pour
  // afficher à l'usager à quel mail le claim était attaché.
  const [claimContext, setClaimContext] = useState(claimToken ? 'checking' : null);
  const [claimEmailSnapshot, setClaimEmailSnapshot] = useState('');

  // Paquet 25.11 — Construire l'URL "Se connecter" en preservant le claim
  // (et le path complet) via ?next=, pour que l'usager qui clique "Se connecter"
  // depuis le bandeau "tu dois te connecter" revienne ici APRES login +
  // force-change, et non pas sur /conta. Empeche l'utilisateur de perdre le fil
  // du parcours signup-sans-biblio.
  // - Sans claim : on pointe vers /login?next=/solicitar-biblioteca
  // - Avec claim : on pointe vers /login?next=/solicitar-biblioteca?claim=<token>
  const loginHref = (() => {
    const pathWithClaim = claimToken
      ? `/solicitar-biblioteca?claim=${encodeURIComponent(claimToken)}`
      : `/solicitar-biblioteca`;
    return `/login?next=${encodeURIComponent(pathWithClaim)}`;
  })();

  // Garde paquet 25.5 : si l'usager est connecté avec un mot de passe provisoire
  // (must_change_password = true OU password_changed_at = null), il doit
  // d'abord finir l'activation de son compte (force-change sur /login) avant
  // de pouvoir soumettre une demande de bibliothèque.
  //
  // Note : profile est chargé en arrière-plan par AuthContext (option β), donc
  // il peut être null pendant ~100-200ms après le login. On affiche dans ce cas
  // un état neutre (pas de garde affichée tant que profile n'est pas chargé),
  // au pire l'usager soumet et le backend rejettera (mais en pratique le profile
  // est presque toujours là quand l'usager arrive sur cette page).
  const mustChangePassword =
    user &&
    profile &&
    (profile.must_change_password === true || profile.password_changed_at == null);

  // Listes déroulantes localisées via t() — étaient hardcodées pt-BR avant paquet 24a.
  const PROJECT_STAGES = useMemo(() => ([
    { value: '',                 label: t({ id: 'solicitar.projectStage.placeholder' }) },
    { value: 'em_funcionamento', label: t({ id: 'solicitar.projectStage.em_funcionamento' }) },
    { value: 'em_montagem',      label: t({ id: 'solicitar.projectStage.em_montagem' }) },
    { value: 'em_planejamento',  label: t({ id: 'solicitar.projectStage.em_planejamento' }) },
    { value: 'reativacao',       label: t({ id: 'solicitar.projectStage.reativacao' }) },
  ]), [t]);

  const FIRST_MANAGER_OPTIONS = useMemo(() => ([
    { value: 'sim',       label: t({ id: 'solicitar.firstManager.sim' }) },
    { value: 'nao',       label: t({ id: 'solicitar.firstManager.nao' }) },
    { value: 'a_definir', label: t({ id: 'solicitar.firstManager.a_definir' }) },
  ]), [t]);

  const [form, setForm] = useState({
    libraryName: '', libraryShortName: '', city: '', state: '', country: 'Brasil',
    libraryEmail: '', libraryPhone: '', libraryAddress: '',
    projectStage: '', contactName: '', contactRole: '', contactEmail: '', contactPhone: '',
    firstManager: 'sim', summary: '', publicProfile: '', collectionProfile: '', needs: '',
    confirmReal: false, confirmContact: false,
  });
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [summaryData, setSummaryData] = useState(null);

  // Pre-fill contact email + name from logged user (paquet 25.9).
  // - email depuis user.email (toujours present si connecte)
  // - name depuis profile.first_name + profile.last_name si profile charge
  // useEffect dependant de user ET profile : se redeclenche quand profile arrive
  // (AuthContext le charge en setTimeout 0, donc avec un petit delai).
  useEffect(() => {
    if (!user) return;
    setForm(prev => {
      const next = { ...prev };
      // Email : si vide ou egal a une ancienne valeur, mettre user.email
      if (user.email && !prev.contactEmail) {
        next.contactEmail = user.email;
      }
      // Nom : composer first_name + last_name depuis profile si dispo
      if (profile && !prev.contactName) {
        const fullName = [profile.first_name, profile.last_name]
          .filter(s => s && String(s).trim().length > 0)
          .join(' ')
          .trim();
        if (fullName) {
          next.contactName = fullName;
        }
      }
      return next;
    });
  }, [user, profile]); // eslint-disable-line react-hooks/exhaustive-deps

  // Paquet 25.11bis — Force le rechargement du profile au mount de la page.
  // CONTEXTE DU BUG : apres le force-change de mot de passe sur /login, l'usager
  // est redirige ici via ?next=. Le DB est a jour (must_change_password=false)
  // mais le state React de AuthContext n'est pas rafraichi automatiquement
  // (USER_UPDATED est ignore par AuthContext pour eviter les cascades, cf.
  // commit 25.2). Resultat : `profile.must_change_password` reste a true en
  // memoire pendant quelques secondes, et la garde rouge "Defina sua senha"
  // s'affiche a tort. Le bandeau disparait au prochain focus (visibilitychange
  // redeclenche le profile load via onAuthStateChange).
  // FIX : on appelle refreshProfile() au mount pour forcer la donnee fraiche
  // immediatement, evitant le flash de garde rouge.
  useEffect(() => {
    if (typeof refreshProfile === 'function') {
      refreshProfile().catch(err => {
        console.warn('[SolicitarBiblioteca] refreshProfile au mount a echoue:', err);
      });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // mount uniquement

  // Paquet 25.8 — Validation du claim token au mount.
  // Si l'URL contient ?claim=<token>, on appelle fn_get_library_request_claim_context
  // pour vérifier qu'il est valide (existe, non expiré, non consommé). La RPC
  // retourne 0 ligne si le claim est invalide → on bascule en mode 'invalid'.
  // Si valide, on garde l'email_snapshot pour afficher à l'usager à quel
  // compte le claim était attaché.
  useEffect(() => {
    if (!claimToken) return; // pas de claim dans l'URL, rien à faire
    let cancelled = false;
    (async () => {
      try {
        const { data, error } = await supabase.rpc('fn_get_library_request_claim_context', {
          p_claim_token: claimToken,
        });
        if (cancelled) return;
        if (error) {
          // Erreur côté API (problème réseau, RPC manquante…) : on considère
          // le claim comme invalide plutôt que de bloquer l'usager indéfiniment.
          setClaimContext('invalid');
          return;
        }
        // RPC retourne TABLE → data est un array (souvent 1 ligne ou 0)
        const row = Array.isArray(data) ? data[0] : data;
        if (row && row.is_valid === true) {
          setClaimContext('valid');
          setClaimEmailSnapshot(row.email_snapshot || '');
        } else {
          setClaimContext('invalid');
        }
      } catch {
        if (!cancelled) setClaimContext('invalid');
      }
    })();
    return () => { cancelled = true; };
  }, [claimToken]);

  function set(k, v) { setForm(p => ({ ...p, [k]: v })); }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.libraryName.trim() || !form.city.trim() || !form.country.trim()) {
      setMsg({ text: t({ id: 'solicitar.error.requiredNameCityCountry' }), kind: 'error' }); return;
    }
    if (!form.libraryEmail.trim()) {
      setMsg({ text: t({ id: 'solicitar.error.requiredLibraryEmail' }), kind: 'error' }); return;
    }
    if (!form.projectStage) {
      setMsg({ text: t({ id: 'solicitar.error.requiredProjectStage' }), kind: 'error' }); return;
    }
    if (!form.contactName.trim() || !form.contactEmail.trim()) {
      setMsg({ text: t({ id: 'solicitar.error.requiredContact' }), kind: 'error' }); return;
    }
    if (!form.summary.trim()) {
      setMsg({ text: t({ id: 'solicitar.error.requiredSummary' }), kind: 'error' }); return;
    }
    if (!form.confirmReal || !form.confirmContact) {
      setMsg({ text: t({ id: 'solicitar.error.requiredConfirms' }), kind: 'error' }); return;
    }
    if (!user) {
      setMsg({ text: t({ id: 'solicitar.error.notLoggedIn' }), kind: 'error' }); return;
    }
    // Garde paquet 25.5 défensive : refuser la soumission si l'usager n'a pas
    // encore finalisé son activation de compte (changement du mot de passe
    // provisoire). En pratique le rendu bloque déjà l'accès au formulaire,
    // mais cette garde est une ceinture additionnelle en cas de bypass.
    if (mustChangePassword) {
      setMsg({ text: t({ id: 'solicitar.gate.passwordRequired.error' }), kind: 'error' }); return;
    }

    setLoading(true); setMsg({ text: '', kind: '' });

    try {
      let data;
      let error;

      // Paquet 25.8 — Branche claim vs branche classique.
      // Si l'usager arrive depuis un mail "inscription sans biblio" et que
      // son claim est valide, on appelle la RPC dédiée qui crée la
      // library_request ET consomme le claim atomiquement (transaction DB).
      // Sinon (usager d'une biblio existante qui veut demander une nouvelle
      // biblio, ou claim invalide/absent), on garde l'INSERT direct historique.
      if (claimContext === 'valid' && claimToken) {
        const rpcRes = await supabase.rpc('fn_submit_library_request_via_claim', {
          p_claim_token: claimToken,
          p_library_name: form.libraryName.trim(),
          p_library_short_name: form.libraryShortName.trim() || null,
          p_city: form.city.trim(),
          p_state_region: form.state.trim() || null,
          p_country: form.country.trim() || 'Brasil',
          p_library_email: form.libraryEmail.trim(),
          p_library_phone: form.libraryPhone.trim() || null,
          p_library_address: form.libraryAddress.trim() || null,
          p_project_stage: form.projectStage,
          p_contact_name: form.contactName.trim(),
          p_contact_email: form.contactEmail.trim(),
          p_contact_phone: form.contactPhone.trim() || null,
          p_contact_role: form.contactRole.trim() || null,
          p_first_manager_intent: form.firstManager,
          p_summary: form.summary.trim(),
          p_public_profile: form.publicProfile.trim() || null,
          p_collection_profile: form.collectionProfile.trim() || null,
          p_needs: form.needs.trim() || null,
          p_confirm_real: true,
          p_confirm_contact: true,
        });
        // RPC retourne library_requests (le record cree) sous data
        data = rpcRes.data;
        error = rpcRes.error;
      } else {
        const payload = {
          submitted_by_user_id: user.id,
          submitted_by_email_snapshot: user.email || form.contactEmail,
          request_status: 'pendente',
          library_name: form.libraryName.trim(),
          library_short_name: form.libraryShortName.trim() || null,
          city: form.city.trim(),
          state_region: form.state.trim() || null,
          country: form.country.trim(),
          library_email: form.libraryEmail.trim(),
          library_phone: form.libraryPhone.trim() || null,
          library_address: form.libraryAddress.trim() || null,
          project_stage: form.projectStage,
          contact_name: form.contactName.trim(),
          contact_email: form.contactEmail.trim(),
          contact_phone: form.contactPhone.trim() || null,
          contact_role: form.contactRole.trim() || null,
          first_manager_intent: form.firstManager,
          summary: form.summary.trim(),
          public_profile: form.publicProfile.trim() || null,
          collection_profile: form.collectionProfile.trim() || null,
          needs: form.needs.trim() || null,
          confirm_real: true,
          confirm_contact: true,
        };
        const ins = await supabase.from('library_requests').insert(payload).select().single();
        data = ins.data;
        error = ins.error;
      }

      if (error) throw error;

      // Try to send notification
      try {
        await supabase.functions.invoke('notify-library-request', { body: { request_id: data.id, event: 'new_request' } });
      } catch {}

      setSubmitted(true);
      setSummaryData(data);
      setMsg({ text: t({ id: 'solicitar.success.registered' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'solicitar.error.generic' }, { msg: err.message }), kind: 'error' });
    } finally { setLoading(false); }
  }

  const fs = { width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem' };
  const ls = { display: 'block', fontSize: '.8rem', fontWeight: 600, marginBottom: 3, color: 'var(--brand-muted, #ccc)' };
  const hs = { fontSize: '.78rem', color: 'var(--brand-muted, #999)', marginTop: 4 };
  const req = <span style={{ color: '#f87171' }}>*</span>;

  return (
    <PageShell><Topbar />
      <div style={{ maxWidth: 720, margin: '0 auto', padding: '24px 16px' }}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 4, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
          {t({ id: 'solicitar.page.title' })}
        </h1>
        <p style={{ color: 'var(--brand-muted)', marginBottom: 16, fontSize: '.9rem' }}>
          {t({ id: 'solicitar.page.subtitle' })}
        </p>

        {/* How it works */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(29,78,216,.08)', border: '1px solid rgba(29,78,216,.2)', marginBottom: 16, fontSize: '.82rem', color: 'var(--brand-muted, #ccc)', lineHeight: 1.6 }}>
          <strong>{t({ id: 'solicitar.howItWorks.label' })}</strong> {t({ id: 'solicitar.howItWorks.body' })}
        </div>

        {/* Paquet 25.8 — Bandeau "claim valide" : l'usager arrive depuis un
            mail d'inscription sans biblio, son claim token est validé. */}
        {claimContext === 'valid' && (
          <div style={{ padding: 14, borderRadius: 10, background: 'rgba(21,128,61,.08)', border: '1px solid rgba(21,128,61,.25)', marginBottom: 16 }}>
            <strong style={{ fontSize: '.92rem', display: 'block', marginBottom: 6, color: '#4ade80' }}>
              {t({ id: 'solicitar.claim.valid.title' })}
            </strong>
            <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #ccc)', lineHeight: 1.6 }}>
              {t({ id: 'solicitar.claim.valid.body' }, { email: claimEmailSnapshot })}
            </div>
          </div>
        )}

        {/* Paquet 25.8 — Bandeau "claim invalide" : token expiré, déjà
            consommé, ou inconnu. On informe sans bloquer : l'usager
            connecté peut quand même soumettre (mode classique). */}
        {claimContext === 'invalid' && (
          <div style={{ padding: 14, borderRadius: 10, background: 'rgba(185,0,31,.10)', border: '1px solid rgba(185,0,31,.30)', marginBottom: 16 }}>
            <strong style={{ fontSize: '.92rem', display: 'block', marginBottom: 6, color: '#f87171' }}>
              {t({ id: 'solicitar.claim.invalid.title' })}
            </strong>
            <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #ccc)', lineHeight: 1.6 }}>
              {t({ id: 'solicitar.claim.invalid.body' })}
            </div>
          </div>
        )}

        {/* Before sending — paquet 24b : "Cadastro" → "Login"
            Paquet 25.11 : le lien preserve le claim courant via ?next=.
            Paquet 25.11bis : masque quand mustChangePassword est actif, car
            la garde rouge en dessous fait deja la consigne avec un bouton.
            Paquet 25.11quater : masque AUSSI quand on va afficher la grande
            bannière d'action "Conecte-se" plus bas (cas !user && claim valide)
            pour ne pas faire doublon. */}
        {!mustChangePassword && !(!user && claimContext === 'valid') && (
          <div style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 16, fontSize: '.82rem', color: 'var(--brand-muted, #ccc)' }}>
            <strong>{t({ id: 'solicitar.beforeSending.label' })}</strong>{' '}
            {t({ id: 'solicitar.beforeSending.body' }, {
              loginLink: chunks => <Link to={loginHref} style={{ textDecoration: 'underline' }}>{chunks}</Link>,
            })}
          </div>
        )}

        {/* Paquet 25.11quater — Bandeau proeminent "Conecte-se à sua conta"
            quand l'usager arrive avec un claim valide mais n'est pas connecte.
            C'est le cas le plus frequent : usager qui clique le CTA du mail,
            tombe ici via /login?next=... mais sa session n'est pas encore
            etablie (premier acces, autre navigateur, etc.). On lui propose un
            gros bouton "Entrar e continuar" plutot que de noyer la consigne
            dans un texte muted.
            Cas alternatif : !user && pas de claim → on rend le petit bandeau
            rouge legacy "notLoggedIn.notice" (texte avec liens login + criar
            conta), parce que c'est un cas plus rare et plus ambigu. */}
        {!user && claimContext === 'valid' && (
          <div style={{
            padding: '20px 22px',
            borderRadius: 12,
            background: 'rgba(185, 0, 31, 0.14)',
            border: '1px solid rgba(185, 0, 31, 0.40)',
            marginBottom: 18,
          }}>
            <h2 style={{
              fontSize: '1.05rem', fontWeight: 800, marginBottom: 8,
              color: '#fca5a5',
              fontFamily: 'var(--brand-font-body)', textTransform: 'none',
            }}>
              {t({ id: 'solicitar.connectGate.title', defaultMessage: 'Conecte-se à sua conta para continuar' })}
            </h2>
            <p style={{
              fontSize: '.92rem', color: 'var(--brand-muted, #d4d4d4)',
              marginBottom: 14, lineHeight: 1.55,
            }}>
              {t({ id: 'solicitar.connectGate.body' }, {
                email: claimEmailSnapshot || t({ id: 'solicitar.connectGate.thisAccount', defaultMessage: 'sua conta AnarBib' }),
              })}
            </p>
            <Button variant="primary" onClick={() => navigate(loginHref)}>
              {t({ id: 'solicitar.connectGate.cta', defaultMessage: 'Entrar e continuar' })}
            </Button>
          </div>
        )}

        {/* Cas alternatif : !user mais sans claim (ou claim invalide).
            On garde l'ancien bandeau rouge discret avec ses deux liens
            (entrar + criar conta) — pas de gros bouton car le scenario est
            ambigu et le contact prealable d'un compte n'est pas garanti. */}
        {!user && claimContext !== 'valid' && (
          <div style={{ padding: 14, borderRadius: 10, background: 'rgba(220,38,38,.1)', border: '1px solid rgba(220,38,38,.2)', marginBottom: 16, fontSize: '.85rem', color: '#f87171' }}>
            {t({ id: 'solicitar.notLoggedIn.notice' }, {
              loginLink:   chunks => <Link to={loginHref}     style={{ textDecoration: 'underline' }}>{chunks}</Link>,
              createLink:  chunks => <Link to="/criar-conta"  style={{ textDecoration: 'underline' }}>{chunks}</Link>,
            })}
          </div>
        )}

        {/* Paquet 25.5 — Garde must_change_password : l'usager est connecté
            mais doit encore changer son mot de passe provisoire. On lui
            propose un retour vers /login qui basculera en view force-change.
            Paquet 25.11 — Le bouton utilise loginHref pour preserver le claim
            via ?next=, sinon apres le force-change l'usager est redirige sur
            /conta et perd le fil du parcours signup-sans-biblio. */}
        {mustChangePassword && (
          <div style={{ padding: 16, borderRadius: 10, background: 'rgba(185, 0, 31, 0.12)', border: '1px solid rgba(185, 0, 31, 0.35)', marginBottom: 16 }}>
            <h2 style={{ fontSize: '1rem', fontWeight: 800, marginBottom: 8, color: '#f87171', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
              {t({ id: 'solicitar.gate.passwordRequired.title' })}
            </h2>
            <p style={{ fontSize: '.88rem', color: 'var(--brand-muted, #ccc)', marginBottom: 12, lineHeight: 1.6 }}>
              {t({ id: 'solicitar.gate.passwordRequired.body' })}
            </p>
            <Button variant="primary" onClick={() => navigate(loginHref)}>
              {t({ id: 'solicitar.gate.passwordRequired.cta' })}
            </Button>
          </div>
        )}

        {msg.text && <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.85rem', marginBottom: 14, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : '#f87171', border: `1px solid ${msg.kind === 'ok' ? 'rgba(21,128,61,.25)' : 'rgba(220,38,38,.25)'}` }}>{msg.text}</div>}

        {/* Summary after submission */}
        {submitted && summaryData && (
          <div style={{ padding: 16, borderRadius: 10, background: 'rgba(21,128,61,.08)', border: '1px solid rgba(21,128,61,.2)', marginBottom: 20 }}>
            <h2 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: 8, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'solicitar.success.title' })}</h2>
            <p style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginBottom: 8 }}>{t({ id: 'solicitar.success.helper' })}</p>
            <div style={{ fontSize: '.82rem', lineHeight: 1.6 }}>
              <div><strong>{t({ id: 'solicitar.success.libraryLabel' })}</strong> {summaryData.library_name}</div>
              <div><strong>{t({ id: 'solicitar.success.cityLabel' })}</strong> {summaryData.city}{summaryData.state_region ? `, ${summaryData.state_region}` : ''} — {summaryData.country}</div>
              <div><strong>{t({ id: 'solicitar.success.contactLabel' })}</strong> {summaryData.contact_name} ({summaryData.contact_email})</div>
              <div><strong>{t({ id: 'solicitar.success.statusLabel' })}</strong> {summaryData.request_status}</div>
              <div><strong>{t({ id: 'solicitar.success.idLabel' })}</strong> {summaryData.id}</div>
            </div>
          </div>
        )}

        {/* Form — caché si mustChangePassword (paquet 25.5) */}
        {!submitted && !mustChangePassword && (
          <form onSubmit={handleSubmit}>
            <p style={hs}>{req} {t({ id: 'solicitar.requiredFieldHint' })}</p>

            <h2 style={{ fontSize: '1rem', fontWeight: 700, margin: '16px 0 10px', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'solicitar.section.library' })}</h2>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div><label style={ls}>{t({ id: 'solicitar.field.libraryName' })} {req}</label><input type="text" value={form.libraryName} onChange={e => set('libraryName', e.target.value)} required style={fs} /></div>
              <div><label style={ls}>{t({ id: 'solicitar.field.libraryShortName' })}</label><input type="text" value={form.libraryShortName} onChange={e => set('libraryShortName', e.target.value)} style={fs} /></div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div><label style={ls}>{t({ id: 'solicitar.field.city' })} {req}</label><input type="text" value={form.city} onChange={e => set('city', e.target.value)} required style={fs} /></div>
              <div><label style={ls}>{t({ id: 'solicitar.field.state' })}</label><input type="text" value={form.state} onChange={e => set('state', e.target.value)} style={fs} /></div>
              <div><label style={ls}>{t({ id: 'solicitar.field.country' })} {req}</label><input type="text" value={form.country} onChange={e => set('country', e.target.value)} required style={fs} /></div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div><label style={ls}>{t({ id: 'solicitar.field.libraryEmail' })} {req}</label><input type="email" value={form.libraryEmail} onChange={e => set('libraryEmail', e.target.value)} required style={fs} /></div>
              <div><label style={ls}>{t({ id: 'solicitar.field.libraryPhone' })}</label><input type="text" value={form.libraryPhone} onChange={e => set('libraryPhone', e.target.value)} style={fs} /></div>
            </div>
            <div style={{ marginBottom: 12 }}><label style={ls}>{t({ id: 'solicitar.field.libraryAddress' })}</label><textarea value={form.libraryAddress} onChange={e => set('libraryAddress', e.target.value)} style={{ ...fs, resize: 'vertical', minHeight: 60 }} /></div>
            <div style={{ marginBottom: 16 }}>
              <label style={ls}>{t({ id: 'solicitar.field.projectStage' })} {req}</label>
              <select value={form.projectStage} onChange={e => set('projectStage', e.target.value)} required style={fs}>
                {PROJECT_STAGES.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
              </select>
            </div>

            <h2 style={{ fontSize: '1rem', fontWeight: 700, margin: '16px 0 10px', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'solicitar.section.contact' })}</h2>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div><label style={ls}>{t({ id: 'solicitar.field.contactName' })} {req}</label><input type="text" value={form.contactName} onChange={e => set('contactName', e.target.value)} required style={fs} /></div>
              <div><label style={ls}>{t({ id: 'solicitar.field.contactRole' })}</label><input type="text" value={form.contactRole} onChange={e => set('contactRole', e.target.value)} style={fs} /></div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div>
                <label style={ls}>{t({ id: 'solicitar.field.contactEmail' })} {req}</label>
                {/* Paquet 25.9 : en mode claim valide, le contactEmail est verrouille
                    sur l'email du compte (= email_snapshot du claim). Cela garantit
                    que le mail de la demande = mail du coordinateur certifie par le
                    flow d'inscription. */}
                <input
                  type="email"
                  value={form.contactEmail}
                  onChange={e => set('contactEmail', e.target.value)}
                  required
                  readOnly={claimContext === 'valid'}
                  style={{
                    ...fs,
                    ...(claimContext === 'valid' ? { opacity: 0.7, cursor: 'not-allowed', background: 'rgba(0,0,0,.45)' } : {}),
                  }}
                  title={claimContext === 'valid' ? t({ id: 'solicitar.field.contactEmail.lockedHint' }) : undefined}
                />
                {claimContext === 'valid' && (
                  <div style={hs}>{t({ id: 'solicitar.field.contactEmail.lockedHint' })}</div>
                )}
              </div>
              <div><label style={ls}>{t({ id: 'solicitar.field.contactPhone' })}</label><input type="text" value={form.contactPhone} onChange={e => set('contactPhone', e.target.value)} style={fs} /></div>
            </div>
            <div style={{ marginBottom: 16 }}>
              <label style={ls}>{t({ id: 'solicitar.field.firstManager' })}</label>
              <select value={form.firstManager} onChange={e => set('firstManager', e.target.value)} style={fs}>
                {FIRST_MANAGER_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
              </select>
            </div>

            <h2 style={{ fontSize: '1rem', fontWeight: 700, margin: '16px 0 10px', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'solicitar.section.presentation' })}</h2>
            <div style={{ marginBottom: 12 }}><label style={ls}>{t({ id: 'solicitar.field.summary' })} {req}</label><textarea value={form.summary} onChange={e => set('summary', e.target.value)} required style={{ ...fs, resize: 'vertical', minHeight: 80 }} /></div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div><label style={ls}>{t({ id: 'solicitar.field.publicProfile' })}</label><input type="text" value={form.publicProfile} onChange={e => set('publicProfile', e.target.value)} style={fs} /></div>
              <div><label style={ls}>{t({ id: 'solicitar.field.collectionProfile' })}</label><input type="text" value={form.collectionProfile} onChange={e => set('collectionProfile', e.target.value)} style={fs} /></div>
            </div>
            <div style={{ marginBottom: 16 }}><label style={ls}>{t({ id: 'solicitar.field.needs' })}</label><textarea value={form.needs} onChange={e => set('needs', e.target.value)} style={{ ...fs, resize: 'vertical', minHeight: 60 }} /></div>

            <hr style={{ border: 'none', borderTop: '1px solid rgba(255,255,255,.1)', margin: '20px 0' }} />

            <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start', marginBottom: 12, fontSize: '.85rem', cursor: 'pointer' }}>
              <input type="checkbox" checked={form.confirmReal} onChange={e => set('confirmReal', e.target.checked)} style={{ marginTop: 3 }} />
              <span>{t({ id: 'solicitar.confirm.real' })} {req}</span>
            </label>
            <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start', marginBottom: 16, fontSize: '.85rem', cursor: 'pointer' }}>
              <input type="checkbox" checked={form.confirmContact} onChange={e => set('confirmContact', e.target.checked)} style={{ marginTop: 3 }} />
              <span>{t({ id: 'solicitar.confirm.contact' })} {req}</span>
            </label>

            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              <Button variant="primary" type="submit" disabled={loading || !user}>{loading ? t({ id: 'solicitar.submit.sending' }) : t({ id: 'solicitar.submit.send' })}</Button>
              <Button variant="secondary" onClick={() => navigate(-1)}>{t({ id: 'common.back' })}</Button>
            </div>
          </form>
        )}
      </div>
    <Footer /></PageShell>
  );
}
