import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { Button } from '@/components/ui';

export default function CadastroPage() {
  const navigate = useNavigate();
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

  useEffect(() => {
    const hash = window.location.hash;
    if (hash.includes('type=recovery') || hash.includes('access_token')) setView('recovery');
  }, []);

  async function handleLogin(e) {
    e.preventDefault(); setLoginLoading(true); setLoginMsg({ text: '', kind: '' });
    try {
      let email = loginId.trim();
      if (!email.includes('@')) { try { const { data } = await supabase.rpc('resolve_login_email', { p_identifier: email }); const r = Array.isArray(data) ? data[0]?.email : data?.email; if (r) email = r; } catch {} }
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) { const r = (error.message || '').toLowerCase(); setLoginMsg({ text: r.includes('invalid login') || r.includes('invalid_credentials') ? 'E-mail ou senha incorretos.' : r.includes('not confirmed') ? 'E-mail ainda não confirmado.' : error.message, kind: 'error' }); return; }
      navigate('/conta');
    } catch { setLoginMsg({ text: 'Falha de rede.', kind: 'error' }); }
    finally { setLoginLoading(false); }
  }

  async function handleForgot(e) {
    e.preventDefault(); if (!forgotEmail.trim()) { setForgotMsg({ text: 'Informe o e-mail.', kind: 'error' }); return; }
    setForgotLoading(true); setForgotMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(forgotEmail.trim(), { redirectTo: `${window.location.origin}/cadastro` });
      setForgotMsg(error ? { text: error.message, kind: 'error' } : { text: 'Link de redefinição enviado! Verifique seu e-mail (e Spam/Lixo eletrônico).', kind: 'ok' });
    } catch { setForgotMsg({ text: 'Falha de rede.', kind: 'error' }); }
    finally { setForgotLoading(false); }
  }

  async function handleReset(e) {
    e.preventDefault();
    if (newPw.length < 6) { setResetMsg({ text: 'A senha deve ter ao menos 6 caracteres.', kind: 'error' }); return; }
    if (newPw !== newPw2) { setResetMsg({ text: 'As senhas não coincidem.', kind: 'error' }); return; }
    setResetLoading(true); setResetMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.auth.updateUser({ password: newPw });
      if (error) { const r = (error.message || '').toLowerCase(); setResetMsg({ text: r.includes('same') || r.includes('different') ? 'Escolha uma senha diferente da anterior.' : r.includes('expired') ? 'Link expirado. Peça novo link em "Esqueci minha senha".' : error.message, kind: 'error' }); return; }
      setResetMsg({ text: 'Senha redefinida com sucesso! Você já pode entrar.', kind: 'ok' });
      setTimeout(() => setView('login'), 2000);
    } catch { setResetMsg({ text: 'Falha de rede.', kind: 'error' }); }
    finally { setResetLoading(false); }
  }

  const fs = { width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem' };
  const ls = { display: 'block', fontSize: '.82rem', fontWeight: 600, marginBottom: 4, color: 'var(--brand-muted, #ccc)' };
  const ms = (k) => ({ padding: '10px 14px', borderRadius: 8, fontSize: '.85rem', marginBottom: 14, background: k === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: k === 'ok' ? '#4ade80' : '#f87171', border: `1px solid ${k === 'ok' ? 'rgba(21,128,61,.25)' : 'rgba(220,38,38,.25)'}` });

  return (
    <PageShell><Topbar />
      <div style={{ maxWidth: 480, margin: '0 auto', padding: '24px 16px' }}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 4, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>Cadastro</h1>
        <p style={{ color: 'var(--brand-muted)', marginBottom: 20, fontSize: '.9rem' }}>Entrar · Esqueci minha senha · Redefinir senha</p>

        <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
          <Button variant="secondary" onClick={() => navigate('/')}>Voltar ao catálogo</Button>
          <Link to="/criar-conta" style={{ textDecoration: 'none' }}><Button variant="primary">Criar conta</Button></Link>
        </div>

        {view === 'login' && (<div>
          <form onSubmit={handleLogin}>
            <div style={{ marginBottom: 12 }}><label style={ls}>ID público</label>
              <input type="text" value={loginId} onChange={e => setLoginId(e.target.value)} placeholder="Seu ID público (ex.: leit.0042) ou e-mail" required style={fs} autoComplete="username" /></div>
            <div style={{ marginBottom: 14 }}><label style={ls}>Senha</label>
              <input type={showPw ? 'text' : 'password'} value={password} onChange={e => setPassword(e.target.value)} required style={fs} autoComplete="current-password" /></div>
            <div style={{ display: 'flex', gap: 8, marginBottom: 14 }}>
              <Button variant="primary" type="submit" disabled={loginLoading}>{loginLoading ? 'Entrando…' : 'Entrar'}</Button>
              <Button variant="secondary" onClick={() => setShowPw(!showPw)}>{showPw ? 'Esconder senha' : 'Mostrar senha'}</Button>
            </div>
            {loginMsg.text && <div style={ms(loginMsg.kind)}>{loginMsg.text}</div>}
          </form>

          {/* ── Esqueci minha senha ────────────────────── */}
          <div style={{ padding: 14, borderRadius: 10, background: 'rgba(180,83,9,.06)', border: '1px solid rgba(180,83,9,.18)', marginTop: 20 }}>
            <strong style={{ fontSize: '.92rem' }}>Esqueceu a senha?</strong>
            <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '6px 0' }}>
              Envie um link para redefinir sua senha. O link chegará no e-mail cadastrado. Verifique também a pasta Spam/Lixo eletrônico.
            </div>
            <form onSubmit={handleForgot}>
              <div style={{ marginBottom: 10 }}><label style={ls}>E-mail da conta</label>
                <input type="email" value={forgotEmail} onChange={e => setForgotEmail(e.target.value)} required style={fs} autoComplete="email" /></div>
              <Button variant="secondary" type="submit" disabled={forgotLoading}>{forgotLoading ? 'Enviando…' : 'Esqueci minha senha'}</Button>
              {forgotMsg.text && <div style={{ ...ms(forgotMsg.kind), marginTop: 10 }}>{forgotMsg.text}</div>}
            </form>
          </div>
        </div>)}

        {view === 'recovery' && (<div>
          <div style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 16 }}>
            <strong>Redefinir senha</strong>
            <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '6px 0' }}>Escolha uma nova senha para sua conta.</div>
          </div>
          <form onSubmit={handleReset}>
            <div style={{ marginBottom: 12 }}><label style={ls}>Nova senha</label>
              <input type={showPw ? 'text' : 'password'} value={newPw} onChange={e => setNewPw(e.target.value)} required style={fs} autoComplete="new-password" /></div>
            <div style={{ marginBottom: 14 }}><label style={ls}>Confirmar nova senha</label>
              <input type={showPw ? 'text' : 'password'} value={newPw2} onChange={e => setNewPw2(e.target.value)} required style={fs} autoComplete="new-password" /></div>
            <div style={{ display: 'flex', gap: 8 }}>
              <Button variant="primary" type="submit" disabled={resetLoading}>{resetLoading ? 'Salvando…' : 'Salvar nova senha'}</Button>
              <Button variant="secondary" onClick={() => setShowPw(!showPw)}>{showPw ? 'Esconder' : 'Mostrar senha'}</Button>
            </div>
            {resetMsg.text && <div style={{ ...ms(resetMsg.kind), marginTop: 14 }}>{resetMsg.text}</div>}
          </form>
        </div>)}
      </div>
    <Footer /></PageShell>
  );
}
