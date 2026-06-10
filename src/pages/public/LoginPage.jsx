import { useState, useEffect, useRef } from 'react';
import { useNavigate, Link, useSearchParams } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { Turnstile } from '@marsidev/react-turnstile';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { Card, Input, Button, Spinner } from '@/components/ui';

const TURNSTILE_SITE_KEY = import.meta.env.VITE_TURNSTILE_SITE_KEY;

// Paquet 25.6 — destination apres login / force-change.
// Lit ?next=<url> depuis la query string et n'accepte QUE des URLs internes
// (commence par '/' mais pas par '//' qui serait un protocol-relative).
// Empeche les open redirects vers des sites externes. Si next est absent
// ou invalide, fallback sur /conta (comportement par defaut).
function getSafeNextUrl(searchParams) {
  const raw = searchParams.get('next');
  if (!raw) return '/conta';
  // Tests stricts : doit commencer par '/' simple, pas '//' ni '/\'
  if (raw.length < 2) return '/conta';
  if (raw[0] !== '/') return '/conta';
  if (raw[1] === '/' || raw[1] === '\\') return '/conta';
  // Pas de saut de ligne, pas de caracteres de controle (volontaire :
  // c'est le but de cette fonction - rejeter les URLs avec injection
  // de caracteres de controle).
  // eslint-disable-next-line no-control-regex
  if (/[\x00-\x1f\x7f]/.test(raw)) return '/conta';
  return raw;
}

export default function LoginPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const reason = searchParams.get('reason');
  // Destination apres login reussi (paquet 25.6).
  // Capturee une seule fois au mount du composant. Si l'usager change d'URL
  // pendant le flow login (peu probable), on garde la destination initiale.
  const nextUrl = getSafeNextUrl(searchParams);
  // Profile + session via AuthContext (paquet 25.6 fix deadlock + zombie session).
  // Au lieu de fetcher profiles depuis handleLogin (double requete qui creait
  // un deadlock supabase-js sporadique), on attend que AuthContext charge tout
  // via son setTimeout 0, puis on decide de la redirection dans un useEffect
  // en reaction a (user, profile).
  //
  // Avantage supplementaire : si l'usager arrive sur /login deja connecte
  // (session zombie en localStorage, refresh accidentel, etc.), le useEffect
  // detectera la session et redirigera immediatement sans qu'il ait besoin de
  // re-saisir ses credentials.
  const { user, profile, loading: authLoading } = useAuth();
  // #LOGIN-FIX H1 (restauré 10/06) : on attend que la biblio ET son thème soient
  // résolus avant de naviguer, pour une transition unique (jamais la page
  // connectée sur l'ancien fond). themeReady résout en ~160ms (manifest depuis le
  // Storage), PAS 14s — la mesure "404 lents" qui avait fait retirer ce gate
  // (f0e8aac) testait la mauvaise URL (origin Pages au lieu du bucket storage).
  const { libraryLoading, themeReady } = useLibrary();
  // (pendingLoginRedirect retire au v4 : la decision est prise directement
  // par le useEffect qui reagit a (user, profile, authLoading), pas besoin
  // d'un flag intermediaire.)
  const { formatMessage: t } = useIntl();
  useDocumentTitle(t({ id: 'pageTitle.login' }));
  const [view, setView] = useState('login');
  const [showPw, setShowPw] = useState(false);
  const [loginId, setLoginId] = useState('');
  const [password, setPassword] = useState('');
  const [loginMsg, setLoginMsg] = useState({ text: '', kind: '' });
  const [loginLoading, setLoginLoading] = useState(false);
  const [forgotEmail, setForgotEmail] = useState('');
  const [forgotMsg, setForgotMsg] = useState({ text: '', kind: '' });
  const [forgotLoading, setForgotLoading] = useState(false);
  const [newPw, setNewPw] = useState('');
  const [newPw2, setNewPw2] = useState('');
  const [resetMsg, setResetMsg] = useState({ text: '', kind: '' });
  const [resetLoading, setResetLoading] = useState(false);
  // États dédiés au flow "force-change" (premier login avec mdp provisoire).
  // On réutilise newPw / newPw2 / showPw qui sont génériques, mais on isole
  // le message et le loading pour ne pas interférer avec le flow recovery.
  const [forceChangeMsg, setForceChangeMsg] = useState({ text: '', kind: '' });
  const [forceChangeLoading, setForceChangeLoading] = useState(false);
  // ── Turnstile (anti-bot) ────────────────────────────────────
  // Token retourné par le widget Cloudflare Turnstile, à passer à l'Edge
  // Function login pour vérification serveur. Token usage unique : on reset
  // le widget après chaque tentative échouée.
  const [turnstileToken, setTurnstileToken] = useState('');
  const turnstileRef = useRef(null);

  // ── Sas connexion (fix "entre-deux") ────────────────────────
  // Quand l'usager est deja authentifie (login frais OU session zombie) et
  // qu'on est encore dans la vue 'login', une redirection est imminente : le
  // useEffect ci-dessous va soit basculer en force-change, soit navigate(next).
  // Tant que la biblio + le theme ne sont pas resolus (#LOGIN-FIX H1), la
  // navigation est retenue. Pendant cette fenetre, la Topbar affiche deja les
  // liens staff + "Sair" (elle lit `user` immediatement) : montrer le
  // formulaire de login EN MEME TEMPS cree l'"entre-deux" incoherent signale.
  // On remplace donc le formulaire par un panneau de transition (spinner).
  //
  // Deux declencheurs de la transition :
  //  1. `redirecting` : session deja active (login frais propage via
  //     onAuthStateChange, OU session zombie au boot). On attend la resolution
  //     profil/biblio avant navigate.
  //  2. `loginLoading` : soumission du formulaire EN VOL (appel EF `login`).
  //     Des le clic sur Entrar, on bascule sur le spinner — sinon le formulaire
  //     resterait visible pendant tout l'aller-retour reseau (~800ms : Turnstile
  //     + rate-limit + signInWithPassword), ce que l'usager percevait comme un
  //     formulaire qui "traine" avant la bascule. En cas d'ECHEC (mauvais mdp),
  //     loginLoading repasse a false -> le formulaire revient avec le message
  //     d'erreur (chemin minoritaire, acceptable).
  const redirecting = !authLoading && !!user && view === 'login';
  const transitioningToApp = view === 'login' && (redirecting || loginLoading);

  // Garde-fou : si la transition reste bloquee trop longtemps (echec de
  // chargement du profil, reseau coupe, EF qui pend), on rebascule sur le
  // formulaire pour ne pas laisser l'usager sur un spinner infini. Sur navigate
  // reussi, le composant est demonte et le timer nettoye avant de se declencher.
  const [transitionTimedOut, setTransitionTimedOut] = useState(false);
  useEffect(() => {
    if (!transitioningToApp) {
      setTransitionTimedOut(false);
      return;
    }
    const id = setTimeout(() => {
      console.log('[LOGIN-DEBUG] transitionTimedOut FIRED (9s) — le formulaire va resurgir');
      setTransitionTimedOut(true);
    }, 9000);
    return () => clearTimeout(id);
  }, [transitioningToApp]);

  const showTransition = transitioningToApp && !transitionTimedOut;

  useEffect(() => {
    const hash = window.location.hash;
    if (hash.includes('type=recovery') || hash.includes('access_token')) setView('recovery');
  }, []);

  // Bascule auto vers la destination (paquet 25.6).
  //
  // Se declenche dans deux cas :
  // 1) Login frais : handleLogin a appele setSession, AuthContext a charge
  //    user + profile via setTimeout 0, ce useEffect detecte et redirige.
  // 2) Session zombie : l'usager arrive sur /login alors qu'il a deja une
  //    session valide en localStorage (refresh accidentel, retour navigation
  //    par exemple). Pas la peine de lui demander de se reconnecter.
  //
  // Conditions :
  //  - authLoading === false : AuthContext a fini d'initialiser
  //  - user truthy : session active
  //  - profile chargé : on peut decider entre force-change et navigate
  //  - view === 'login' : on ne casse pas un flow recovery ou force-change
  //    en cours (par exemple si l'usager change son mdp sur recovery,
  //    il faut le laisser finir, pas le rediriger en cours de route)
  useEffect(() => {
    // [LOGIN-DEBUG] temporaire (à retirer) — trace quelle condition bloque la
    // redirection post-login. Filtrer la console sur "LOGIN-DEBUG".
    console.log('[LOGIN-DEBUG] redirect ' + JSON.stringify({
      authLoading, user: !!user, profile: !!profile, view,
      must: profile?.must_change_password === true, libraryLoading, themeReady,
    }));
    if (authLoading) return;
    if (!user) return;
    if (!profile) return;
    if (view !== 'login') return;
    // Decision :
    if (profile.must_change_password === true) {
      setView('force-change');
      setLoginLoading(false);
      return;
    }
    // #LOGIN-FIX H1 (restauré) : ne naviguer que lorsque la biblio ET le thème
    // sont résolus, pour révéler /conta directement sur le bon fond (pas de
    // cascade de fonds AnarBib -> biblio). themeReady résout en ~160ms (manifest
    // Storage), donc aucun risque de hang ici (contrairement à ce que f0e8aac
    // supposait sur une mesure 404 erronée).
    if (libraryLoading || !themeReady) return;
    navigate(nextUrl);
  }, [authLoading, user, profile, view, navigate, nextUrl, libraryLoading, themeReady]);

  async function handleLogin(e) {
    e.preventDefault();

    // Vérification client : le token Turnstile doit être présent.
    // Sécurité : la vraie vérification se fait côté Edge Function (le client
    // peut être manipulé), c'est juste un garde-fou UX.
    if (!turnstileToken) {
      setLoginMsg({ text: t({ id: 'auth.captchaRequired' }), kind: 'error' });
      return;
    }

    // Flag local : si setSession a reussi, on NE clear PAS loginLoading dans
    // le finally (le bouton reste en spinner jusqu'a ce que le useEffect prenne
    // la decision de bascule, garantissant que l'usager ne re-clique pas
    // pendant la latence d'AuthContext.loadProfile ~100-200ms).
    let sessionWasSet = false;

    setLoginLoading(true);
    setLoginMsg({ text: '', kind: '' });
    try {
      let email = loginId.trim();
      if (!email.includes('@')) {
        try {
          const { data } = await supabase.rpc('resolve_login_email', { p_identifier: email });
          const r = Array.isArray(data) ? data[0]?.email : data?.email;
          if (r) email = r;
        } catch {}
      }

      // Appel à l'Edge Function login (vs signInWithPassword direct).
      // L'Edge Function applique : vérif Turnstile + rate limit IP/email
      // + signInWithPassword serveur, puis renvoie la session.
      const { data, error: invokeError } = await supabase.functions.invoke('login', {
        body: { email, password, turnstile_token: turnstileToken },
      });

      // Reset du widget Turnstile dans tous les cas (token usage unique)
      turnstileRef.current?.reset();
      setTurnstileToken('');

      // Erreur réseau ou erreur côté Edge Function (status 4xx/5xx)
      if (invokeError) {
        // Tenter d'extraire un message structuré { error: "..." }
        let msg = t({ id: 'auth.networkError' });
        try {
          const ctx = invokeError.context;
          if (ctx) {
            const body = await ctx.json?.();
            if (body?.error) msg = body.error;
          }
        } catch {}
        setLoginMsg({ text: msg, kind: 'error' });
        return;
      }

      // Erreur logique retournée explicitement par l'Edge Function
      if (data?.error) {
        setLoginMsg({ text: data.error, kind: 'error' });
        return;
      }

      // Synchroniser la session côté supabase-js (stockage localStorage etc.)
      if (data?.session) {
        const { error: setErr } = await supabase.auth.setSession({
          access_token: data.session.access_token,
          refresh_token: data.session.refresh_token,
        });
        if (setErr) throw setErr;
        sessionWasSet = true;

        // Paquet 25.6 v4 : on NE FAIT RIEN d'autre ici.
        // AuthContext va detecter SIGNED_IN, charger user + profile en
        // setTimeout 0, et le useEffect en haut du composant fera la
        // bascule (force-change ou navigate(nextUrl)) automatiquement.
        // Le bouton Entrar reste en loading car on n'a pas clear loginLoading :
        // c'est le useEffect qui clear quand il decide (ou bien le finally
        // dans le cas d'erreur).
        return;
      }

      // Cas inattendu : pas d'erreur ni de session
      setLoginMsg({ text: t({ id: 'auth.networkError' }), kind: 'error' });
    } catch {
      setLoginMsg({ text: t({ id: 'auth.networkError' }), kind: 'error' });
    } finally {
      // Si setSession a reussi, on laisse loginLoading a true : le bouton
      // Entrar reste en spinner jusqu'a ce que le useEffect prenne la
      // decision (force-change ou navigate). Sinon (erreur ou cas inattendu)
      // on libere immediatement.
      if (!sessionWasSet) {
        setLoginLoading(false);
      }
    }
  }

  async function handleForgot(e) {
    e.preventDefault();
    if (!forgotEmail.trim()) {
      setForgotMsg({ text: t({ id: 'auth.forgotEmailRequired' }), kind: 'error' });
      return;
    }
    setForgotLoading(true);
    setForgotMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(forgotEmail.trim(), {
        redirectTo: `${window.location.origin}/login`,
      });
      setForgotMsg(
        error
          ? { text: error.message, kind: 'error' }
          : { text: t({ id: 'auth.forgotSent' }), kind: 'ok' }
      );
    } catch {
      setForgotMsg({ text: t({ id: 'auth.networkError' }), kind: 'error' });
    } finally {
      setForgotLoading(false);
    }
  }

  async function handleReset(e) {
    e.preventDefault();
    if (newPw.length < 6) {
      setResetMsg({ text: t({ id: 'auth.resetMin6' }), kind: 'error' });
      return;
    }
    if (newPw !== newPw2) {
      setResetMsg({ text: t({ id: 'auth.resetMismatch' }), kind: 'error' });
      return;
    }
    setResetLoading(true);
    setResetMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.auth.updateUser({ password: newPw });
      if (error) {
        const r = (error.message || '').toLowerCase();
        setResetMsg({
          text:
            r.includes('same') || r.includes('different')
              ? t({ id: 'auth.resetSamePassword' })
              : r.includes('expired')
              ? t({ id: 'auth.resetExpired' })
              : error.message,
          kind: 'error',
        });
        return;
      }
      setResetMsg({ text: t({ id: 'auth.resetSuccess' }), kind: 'ok' });
      setTimeout(() => setView('login'), 2000);
    } catch {
      setResetMsg({ text: t({ id: 'auth.networkError' }), kind: 'error' });
    } finally {
      setResetLoading(false);
    }
  }

  // ── handleForceChange ──────────────────────────────────────────────────
  // Premier login avec mot de passe provisoire (must_change_password = true).
  // L'usager est obligé de définir un nouveau mdp avant d'accéder à l'app.
  //
  // Différences avec handleReset (mode recovery) :
  // 1. Après updateUser, on UPDATE profiles SET must_change_password = false,
  //    password_changed_at = now() pour lever la garde.
  // 2. En cas de succès, on navigate('/conta') directement au lieu de
  //    revenir à la vue login (l'usager est déjà connecté).
  //
  // RLS profiles_update_own (id = auth.uid()) permet cet UPDATE depuis le
  // frontend. Cf. discussion paquet 25.3 : option A choisie.
  async function handleForceChange(e) {
    e.preventDefault();
    if (newPw.length < 6) {
      setForceChangeMsg({ text: t({ id: 'auth.resetMin6' }), kind: 'error' });
      return;
    }
    if (newPw !== newPw2) {
      setForceChangeMsg({ text: t({ id: 'auth.resetMismatch' }), kind: 'error' });
      return;
    }
    setForceChangeLoading(true);
    setForceChangeMsg({ text: '', kind: '' });
    try {
      // 1) Update du mdp côté auth.users via Supabase Auth
      const { error: authError } = await supabase.auth.updateUser({ password: newPw });
      if (authError) {
        const r = (authError.message || '').toLowerCase();
        setForceChangeMsg({
          text:
            r.includes('same') || r.includes('different')
              ? t({ id: 'auth.resetSamePassword' })
              : authError.message,
          kind: 'error',
        });
        return;
      }

      // 2) Clear must_change_password + set password_changed_at sur profiles
      // RLS profiles_update_own autorise cet update (id = auth.uid())
      const { data: sessionData } = await supabase.auth.getSession();
      const userId = sessionData?.session?.user?.id;
      if (userId) {
        const { error: profError } = await supabase
          .from('profiles')
          .update({
            must_change_password: false,
            password_changed_at: new Date().toISOString(),
          })
          .eq('id', userId);
        if (profError) {
          // Le mdp est bien changé côté auth, mais la garde reste active.
          // Au prochain login, l'usager re-tombera sur ce formulaire.
          // On informe sans bloquer : l'usager est dans un état dégradé
          // mais récupérable.
          console.warn('[force-change] profiles update failed:', profError);
          setForceChangeMsg({
            text: t({ id: 'auth.forceChange.warningProfile' }),
            kind: 'error',
          });
          // On laisse l'usager passer quand même : son mdp est valide.
          setTimeout(() => navigate(nextUrl), 2000);
          return;
        }
      }

      // 3) Tout OK : navigate vers la destination (paquet 25.6).
      // nextUrl = ?next=<url> dans la query si specifie, sinon /conta par defaut.
      setForceChangeMsg({ text: t({ id: 'auth.forceChange.success' }), kind: 'ok' });
      setTimeout(() => navigate(nextUrl), 1200);
    } catch {
      setForceChangeMsg({ text: t({ id: 'auth.networkError' }), kind: 'error' });
    } finally {
      setForceChangeLoading(false);
    }
  }

  const ms = (k) => ({
    padding: '10px 14px',
    borderRadius: 8,
    fontSize: '.85rem',
    marginBottom: 14,
    background: k === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)',
    color: k === 'ok' ? '#4ade80' : '#f87171',
    border: `1px solid ${k === 'ok' ? 'rgba(21,128,61,.25)' : 'rgba(220,38,38,.25)'}`,
  });

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 480, margin: '40px auto', padding: '0 16px' }}>
        {reason === 'idle' && (
          <div
            role="alert"
            style={{
              marginBottom: 16,
              padding: '12px 16px',
              borderRadius: 8,
              background: 'rgba(185, 0, 31, 0.08)',
              border: '1px solid rgba(185, 0, 31, 0.3)',
              color: 'var(--brand-fg, #e8e2d6)',
              fontSize: '.9rem',
            }}
          >
            {t({ id: 'login.reason.idle' })}
          </div>
        )}
        <Card>
          {!showTransition && (
            <>
              <h1
                style={{
                  fontSize: '1.5rem',
                  fontWeight: 800,
                  margin: '0 0 4px',
                  fontFamily: 'var(--brand-font-body)',
                  textTransform: 'none',
                }}
              >
                {view === 'force-change'
                  ? t({ id: 'auth.forceChange.pageTitle' })
                  : t({ id: 'auth.login.title' })}
              </h1>
              <p style={{ color: 'var(--brand-muted)', margin: '0 0 20px', fontSize: '.9rem' }}>
                {view === 'force-change'
                  ? t({ id: 'auth.forceChange.pageSubtitle' })
                  : t({ id: 'auth.login.subtitle' })}
              </p>
            </>
          )}

          {/* Panneau de transition : affiche un spinner pendant que la
              redirection post-login se prepare (profil + biblio + theme),
              au lieu du formulaire — supprime l'"entre-deux" avec la Topbar
              deja connectee. */}
          {view === 'login' && showTransition && (
            <div
              style={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 14,
                padding: '28px 0',
              }}
            >
              <Spinner size={32} />
              <span style={{ color: 'var(--brand-muted)', fontSize: '.9rem' }}>
                {t({ id: 'auth.loggingIn' })}
              </span>
            </div>
          )}

          {view !== 'force-change' && !showTransition && (
            <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
              <Button variant="secondary" onClick={() => navigate('/')}>
                {t({ id: 'auth.backToCatalog' })}
              </Button>
              <Link to="/criar-conta" style={{ textDecoration: 'none' }}>
                <Button variant="primary">{t({ id: 'auth.createAccount' })}</Button>
              </Link>
            </div>
          )}

          {view === 'login' && !showTransition && (
            <div>
              <form
                onSubmit={handleLogin}
                style={{ display: 'flex', flexDirection: 'column', gap: 14 }}
              >
                <Input
                  label={t({ id: 'auth.publicId' })}
                  type="text"
                  value={loginId}
                  onChange={(e) => setLoginId(e.target.value)}
                  placeholder={t({ id: 'auth.publicIdPh' })}
                  autoComplete="username"
                  required
                />
                <Input
                  label={t({ id: 'auth.password' })}
                  type={showPw ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                  required
                />
                {/* Widget Cloudflare Turnstile (anti-bot).
                    Toujours visible, mode managed (Cloudflare décide quand
                    interagir). Token usage unique : reset après chaque
                    tentative échouée dans handleLogin. */}
                {TURNSTILE_SITE_KEY && (
                  <div style={{ display: 'flex', justifyContent: 'center', margin: '4px 0' }}>
                    <Turnstile
                      ref={turnstileRef}
                      siteKey={TURNSTILE_SITE_KEY}
                      onSuccess={(token) => setTurnstileToken(token)}
                      onError={() => setTurnstileToken('')}
                      onExpire={() => setTurnstileToken('')}
                      options={{ theme: 'dark' }}
                    />
                  </div>
                )}
                <div style={{ display: 'flex', gap: 8 }}>
                  <Button variant="primary" type="submit" loading={loginLoading}>
                    {loginLoading ? t({ id: 'auth.loggingIn' }) : t({ id: 'auth.login' })}
                  </Button>
                  <Button
                    variant="secondary"
                    type="button"
                    onClick={() => setShowPw(!showPw)}
                  >
                    {showPw ? t({ id: 'auth.hidePassword' }) : t({ id: 'auth.showPassword' })}
                  </Button>
                </div>
                {loginMsg.text && <div style={ms(loginMsg.kind)}>{loginMsg.text}</div>}
              </form>

              <div
                style={{
                  padding: 14,
                  borderRadius: 10,
                  background: 'rgba(180,83,9,.06)',
                  border: '1px solid rgba(180,83,9,.18)',
                  marginTop: 20,
                }}
              >
                <strong style={{ fontSize: '.92rem' }}>{t({ id: 'auth.forgotTitle' })}</strong>
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '6px 0' }}>
                  {t({ id: 'auth.forgotHint' })}
                </div>
                <form
                  onSubmit={handleForgot}
                  style={{ display: 'flex', flexDirection: 'column', gap: 10 }}
                >
                  <Input
                    label={t({ id: 'auth.forgotEmail' })}
                    type="email"
                    value={forgotEmail}
                    onChange={(e) => setForgotEmail(e.target.value)}
                    autoComplete="email"
                    required
                  />
                  <div>
                    <Button variant="secondary" type="submit" loading={forgotLoading}>
                      {forgotLoading
                        ? t({ id: 'auth.forgotSending' })
                        : t({ id: 'auth.forgotButton' })}
                    </Button>
                  </div>
                  {forgotMsg.text && <div style={ms(forgotMsg.kind)}>{forgotMsg.text}</div>}
                </form>
              </div>
            </div>
          )}

          {view === 'recovery' && (
            <div>
              <div
                style={{
                  padding: 14,
                  borderRadius: 10,
                  background: 'rgba(255,255,255,.03)',
                  border: '1px solid rgba(255,255,255,.08)',
                  marginBottom: 16,
                }}
              >
                <strong>{t({ id: 'auth.resetTitle' })}</strong>
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '6px 0' }}>
                  {t({ id: 'auth.resetHint' })}
                </div>
              </div>
              <form
                onSubmit={handleReset}
                style={{ display: 'flex', flexDirection: 'column', gap: 14 }}
              >
                <Input
                  label={t({ id: 'auth.newPassword' })}
                  type={showPw ? 'text' : 'password'}
                  value={newPw}
                  onChange={(e) => setNewPw(e.target.value)}
                  autoComplete="new-password"
                  required
                />
                <Input
                  label={t({ id: 'auth.confirmPassword' })}
                  type={showPw ? 'text' : 'password'}
                  value={newPw2}
                  onChange={(e) => setNewPw2(e.target.value)}
                  autoComplete="new-password"
                  required
                />
                <div style={{ display: 'flex', gap: 8 }}>
                  <Button variant="primary" type="submit" loading={resetLoading}>
                    {resetLoading ? t({ id: 'auth.resetSaving' }) : t({ id: 'auth.resetSave' })}
                  </Button>
                  <Button
                    variant="secondary"
                    type="button"
                    onClick={() => setShowPw(!showPw)}
                  >
                    {showPw ? t({ id: 'auth.hidePassword' }) : t({ id: 'auth.showPassword' })}
                  </Button>
                </div>
                {resetMsg.text && <div style={ms(resetMsg.kind)}>{resetMsg.text}</div>}
              </form>
            </div>
          )}

          {view === 'force-change' && (
            <div>
              <div
                style={{
                  padding: 14,
                  borderRadius: 10,
                  background: 'rgba(185, 0, 31, 0.08)',
                  border: '1px solid rgba(185, 0, 31, 0.3)',
                  marginBottom: 16,
                }}
              >
                <strong>{t({ id: 'auth.forceChange.title' })}</strong>
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '6px 0' }}>
                  {t({ id: 'auth.forceChange.body' })}
                </div>
              </div>
              <form
                onSubmit={handleForceChange}
                style={{ display: 'flex', flexDirection: 'column', gap: 14 }}
              >
                <Input
                  label={t({ id: 'auth.newPassword' })}
                  type={showPw ? 'text' : 'password'}
                  value={newPw}
                  onChange={(e) => setNewPw(e.target.value)}
                  autoComplete="new-password"
                  required
                />
                <Input
                  label={t({ id: 'auth.confirmPassword' })}
                  type={showPw ? 'text' : 'password'}
                  value={newPw2}
                  onChange={(e) => setNewPw2(e.target.value)}
                  autoComplete="new-password"
                  required
                />
                <div style={{ display: 'flex', gap: 8 }}>
                  <Button variant="primary" type="submit" loading={forceChangeLoading}>
                    {forceChangeLoading
                      ? t({ id: 'auth.forceChange.saving' })
                      : t({ id: 'auth.forceChange.save' })}
                  </Button>
                  <Button
                    variant="secondary"
                    type="button"
                    onClick={() => setShowPw(!showPw)}
                  >
                    {showPw ? t({ id: 'auth.hidePassword' }) : t({ id: 'auth.showPassword' })}
                  </Button>
                </div>
                {forceChangeMsg.text && <div style={ms(forceChangeMsg.kind)}>{forceChangeMsg.text}</div>}
              </form>
            </div>
          )}
        </Card>
      </div>
      <Footer />
    </PageShell>
  );
}
