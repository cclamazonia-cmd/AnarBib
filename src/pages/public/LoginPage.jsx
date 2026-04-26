import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { Card, Input, Button } from '@/components/ui';

export default function LoginPage() {
  const { formatMessage: t } = useIntl();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleLogin(e) {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      // Résoudre l'email si c'est un identifiant (public_id, etc.)
      let loginEmail = email.trim();
      if (!loginEmail.includes('@')) {
        const { data, error: rpcError } = await supabase.rpc('resolve_login_email', {
          p_identifier: loginEmail,
        });
        // rpc retourne un tableau de lignes { email, public_id, user_id }
        const resolved = Array.isArray(data) ? data[0]?.email : data?.email;
        if (resolved) {
          loginEmail = resolved;
        } else {
          throw new Error('Identificador não encontrado. Use seu e-mail ou código de usuário.');
        }
      }

      const { error: authError } = await supabase.auth.signInWithPassword({
        email: loginEmail,
        password,
      });

      if (authError) throw authError;
      navigate('/conta');
    } catch (err) {
      setError(err.message || 'Erro ao entrar.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <PageShell>
      <Topbar />

      <div style={{ maxWidth: 440, margin: '40px auto' }}>
        <Card>
          <h1 style={{ margin: '0 0 20px', fontSize: '1.3rem' }}>
            {t({ id: 'auth.login.title' })}
          </h1>

          <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <Input
              label={t({ id: 'auth.login.email' })}
              type="text"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="username"
              required
            />
            <Input
              label={t({ id: 'auth.login.password' })}
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />

            {error && (
              <p style={{ color: 'var(--color-bad)', fontSize: '0.9rem', margin: 0 }}>
                {error}
              </p>
            )}

            <Button type="submit" loading={loading}>
              {t({ id: 'auth.login.submit' })}
            </Button>
          </form>

          <div style={{ marginTop: 16, fontSize: '0.9rem', color: 'var(--brand-muted)', display: 'flex', gap: 16, flexWrap: 'wrap' }}>
            <Link to="/criar-conta">{t({ id: 'nav.register' })}</Link>
            <Link to="/cadastro">Esqueci minha senha</Link>
            <Link to="/solicitar-biblioteca">Solicitar biblioteca</Link>
          </div>
        </Card>
      </div>

      <Footer />
    </PageShell>
  );
}
