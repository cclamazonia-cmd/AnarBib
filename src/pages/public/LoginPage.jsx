import { useState, useEffect, useRef } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { Turnstile } from '@marsidev/react-turnstile';
import { supabase } from '@/lib/supabase';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { Card, Input, Button } from '@/components/ui';

const TURNSTILE_SITE_KEY = import.meta.env.VITE_TURNSTILE_SITE_KEY;

export default function LoginPage() {
  const navigate = useNavigate();
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
  // ── Turnstile (anti-bot) ────────────────────────────────────
  // Token retourné par le widget Cloudflare Turnstile, à passer à l'Edge
  // Function login pour vérification serveur. Token usage unique : on reset
  // le widget après chaque tentative échouée.
  const [turnstileToken, setTurnstileToken] = useState('');
  const turnstileRef = useRef(null);

  useEffect(() => {
    const hash = window.location.hash;
    if (hash.includes('type=recovery') || hash.includes('access_token')) setView('recovery');
  }, []);

  async function handleLogin(e) {
    e.preventDefault();

    // Vérification client : le token Turnstile doit être présent.
    // Sécurité : la vraie vérification se fait côté Edge Function (le client
    // peut être manipulé), c'est juste un garde-fou UX.
    if (!turnstileToken) {
      setLoginMsg({ text: t({ id: 'auth.captchaRequired' }), kind: 'error' });
      return;
    }

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
        navigate('/conta');
        return;
      }

      // Cas inattendu : pas d'erreur ni de session
      setLoginMsg({ text: t({ id: 'auth.networkError' }), kind: 'error' });
    } catch {
      setLoginMsg({ text: t({ id: 'auth.networkError' }), kind: 'error' });
    } finally {
      setLoginLoading(false);
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
        <Card>
          <h1
            style={{
              fontSize: '1.5rem',
              fontWeight: 800,
              margin: '0 0 4px',
              fontFamily: 'var(--brand-font-body)',
              textTransform: 'none',
            }}
          >
            {t({ id: 'auth.login.title' })}
          </h1>
          <p style={{ color: 'var(--brand-muted)', margin: '0 0 20px', fontSize: '.9rem' }}>
            {t({ id: 'auth.login.subtitle' })}
          </p>

          <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
            <Button variant="secondary" onClick={() => navigate('/')}>
              {t({ id: 'auth.backToCatalog' })}
            </Button>
            <Link to="/criar-conta" style={{ textDecoration: 'none' }}>
              <Button variant="primary">{t({ id: 'auth.createAccount' })}</Button>
            </Link>
          </div>

          {view === 'login' && (
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
        </Card>
      </div>
      <Footer />
    </PageShell>
  );
}
