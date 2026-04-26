import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { Button } from '@/components/ui';

const ANARBIB_LOGO = 'https://cclamazonia.noblogs.org/files/2026/03/AnarBib_logo.png';
const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
const STATES_BR = ['','AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'];
const GENDERS = [
  { value: '', label: 'Não informar' }, { value: 'feminino', label: 'Feminino' },
  { value: 'masculino', label: 'Masculino' }, { value: 'nao_binario', label: 'Não-binário' },
  { value: 'outro', label: 'Outro' },
];

export default function CriarContaPage() {
  const navigate = useNavigate();
  const [libraries, setLibraries] = useState([]);
  const [currentLib, setCurrentLib] = useState(null);
  const [form, setForm] = useState({
    library_slug: '', first_name: '', last_name: '', email: '', phone: '',
    gender: '', addr1: '', addr2: '', unit: '', cep: '', bairro: '',
    city: '', state: '', country: 'Brasil', acceptRules: false, consent: false,
  });
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [loading, setLoading] = useState(false);
  const [publicId, setPublicId] = useState('');

  useEffect(() => {
    (async () => {
      try {
        const { data: libs } = await supabase.from('libraries').select('id, slug, name');
        if (!libs?.length) return;
        const { data: commons } = await supabase.from('library_commons').select('library_id, logo_url, logo_file_key');
        const { data: regs } = await supabase.from('library_regulation_documents').select('library_id').eq('is_active', true);
        const regSet = new Set((regs || []).map(r => r.library_id));
        const commonsMap = {}; (commons || []).forEach(c => { commonsMap[c.library_id] = c; });
        setLibraries(libs.map(l => ({ ...l, logo_url: commonsMap[l.id]?.logo_url || null, logo_file_key: commonsMap[l.id]?.logo_file_key || null, has_regimento: regSet.has(l.id) })));
      } catch {}
    })();
  }, []);

  function set(k, v) { setForm(p => ({ ...p, [k]: v })); }
  function handleLibChange(slug) { set('library_slug', slug); set('acceptRules', false); setCurrentLib(libraries.find(l => l.slug === slug) || null); }
  function libLogo(lib) {
    if (!lib?.slug) return null;
    // 1. Explicit http URL
    if (lib.logo_url?.startsWith('http')) return lib.logo_url;
    // 2. Storage file key in library-ui-assets bucket
    if (lib.logo_file_key && !lib.logo_file_key.startsWith('.')) {
      const key = lib.logo_file_key.includes('/') ? lib.logo_file_key : `themes/${lib.logo_file_key}/logo-${lib.logo_file_key}.png`;
      return `${PROJECT_URL}/storage/v1/object/public/library-ui-assets/${key}`;
    }
    // 3. Fallback: convention themes/{slug}/logo-{slug}.png
    return `${PROJECT_URL}/storage/v1/object/public/library-ui-assets/themes/${lib.slug}/logo-${lib.slug}.png`;
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.first_name.trim() || !form.last_name.trim() || !form.email.trim() || !form.phone.trim()) { setMsg({ text: 'Preencha Nome, Sobrenome, E-mail e Telefone.', kind: 'error' }); return; }
    if (!form.consent) { setMsg({ text: 'Marque a confirmação de uso do e-mail.', kind: 'error' }); return; }
    if (currentLib?.has_regimento && !form.acceptRules) { setMsg({ text: 'Aceite o regimento da biblioteca.', kind: 'error' }); return; }
    setLoading(true); setMsg({ text: '', kind: '' }); setPublicId('');
    try {
      const noLib = !form.library_slug;
      const addr2 = [form.bairro.trim() && `Bairro: ${form.bairro.trim()}`, form.addr2.trim() && `Complemento: ${form.addr2.trim()}`].filter(Boolean).join(' | ');
      const { data, error } = await supabase.functions.invoke('register', { body: {
        email: form.email.trim(), first_name: form.first_name.trim(), last_name: form.last_name.trim(),
        phone: form.phone.trim(), gender: form.gender, address_1: form.addr1.trim(), address_2: addr2,
        address_unit: form.unit.trim(), cep: form.cep.trim(), city: form.city.trim(), state: form.state,
        country: form.country || 'Brasil', consent_email: true, accept_rules: currentLib?.has_regimento ? form.acceptRules : true,
        library_slug: noLib ? '' : form.library_slug, library_name: currentLib?.name || '',
        signup_without_library: noLib, anarbib_logo_url: ANARBIB_LOGO, preferred_login_identifier: 'public_id',
      }});
      if (error) { const m = data?.error || error.message || 'Erro.'; setMsg({ text: m.includes('already') || m.includes('já existe') ? 'Este e-mail já está cadastrado. Use Cadastro para entrar.' : m, kind: 'error' }); return; }
      if (data?.public_id) setPublicId(data.public_id);
      setMsg({ text: data?.email_usuaria_enviado === false
        ? (noLib ? 'Cadastro concluído, mas houve um problema ao enviar o e-mail. Entre em contato com a coordenação do AnarBib.' : 'Cadastro concluído, mas houve um problema ao enviar o e-mail. Entre em contato com a biblioteca.')
        : (noLib ? 'Cadastro enviado! Verifique seu e-mail (e Spam) para receber senha provisória, ID público e orientações para solicitar entrada de nova biblioteca.' : 'Cadastro enviado! Verifique seu e-mail (e Spam) para receber senha provisória e ID público. Depois, altere sua senha na Conta.'),
        kind: data?.email_usuaria_enviado === false ? 'warn' : 'ok' });
    } catch { setMsg({ text: 'Falha de rede. Tente novamente.', kind: 'error' }); }
    finally { setLoading(false); }
  }

  const fs = { width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem' };
  const ls = { display: 'block', fontSize: '.8rem', fontWeight: 600, marginBottom: 3, color: 'var(--brand-muted, #ccc)' };
  const hs = { fontSize: '.78rem', color: 'var(--brand-muted, #999)', marginTop: 4 };
  const req = <span style={{ color: '#f87171' }}>*</span>;
  const ll = libLogo(currentLib);

  return (
    <PageShell><Topbar />
      <div style={{ maxWidth: 720, margin: '0 auto', padding: '24px 16px' }}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 4, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>Criar conta</h1>
        <p style={{ color: 'var(--brand-muted)', marginBottom: 20, fontSize: '.9rem' }}>Abertura de conta (leitor/a/e)</p>

        {/* Bibliothèque selector */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 16 }}>
          <label style={ls}>Selecionar biblioteca de referência {req}</label>
          <select value={form.library_slug} onChange={e => handleLibChange(e.target.value)} style={fs}>
            <option value="">Selecione...</option>
            {libraries.map(l => <option key={l.slug} value={l.slug}>{l.name}</option>)}
            <option value="">Inscrição sem biblioteca (para solicitar entrada de uma nova)</option>
          </select>
          <div style={hs}>A biblioteca escolhida definirá a identidade visual do cadastro e o conteúdo do e-mail de boas-vindas.</div>
        </div>

        {/* Logos */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 16, margin: '16px 0', padding: 16 }}>
          <img src={ANARBIB_LOGO} alt="AnarBib" style={{ height: 64, objectFit: 'contain', filter: 'drop-shadow(0 4px 12px rgba(0,0,0,.4))' }} />
          {ll && (<><span style={{ fontSize: '1.5rem', color: 'var(--brand-muted, #888)', fontWeight: 300 }}>+</span>
            <img src={ll} alt={currentLib?.name || ''} style={{ height: 64, objectFit: 'contain', filter: 'drop-shadow(0 4px 12px rgba(0,0,0,.4))' }} /></>)}
        </div>

        {/* Security notice */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(29,78,216,.08)', border: '1px solid rgba(29,78,216,.2)', marginBottom: 16, fontSize: '.82rem', color: 'var(--brand-muted, #ccc)', lineHeight: 1.6 }}>
          <strong>Importante (segurança):</strong>
          <p style={{ margin: '4px 0' }}>A senha que você receberá por e-mail é <strong>provisória</strong>. No primeiro acesso, <strong>altere sua senha na Conta</strong>.</p>
          <p style={{ margin: '4px 0' }}>Seus acessos regulares serão feitos com seu <strong>ID público pessoal</strong>.</p>
          <p style={{ margin: '4px 0' }}>Se perder o acesso, use em <Link to="/cadastro" style={{ textDecoration: 'underline' }}>Cadastro</Link> o botão <strong>"Esqueci minha senha"</strong>.</p>
          <p style={{ margin: '4px 0' }}>Se não encontrar o e-mail, verifique "Spam/Lixo eletrônico".</p>
        </div>

        <p style={hs}>{req} Campo obrigatório. Campos de endereço são todos opcionais.</p>

        {msg.text && <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.85rem', marginBottom: 14, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : msg.kind === 'warn' ? 'rgba(180,83,9,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : msg.kind === 'warn' ? '#fbbf24' : '#f87171', border: `1px solid ${msg.kind === 'ok' ? 'rgba(21,128,61,.25)' : msg.kind === 'warn' ? 'rgba(180,83,9,.25)' : 'rgba(220,38,38,.25)'}` }}>{msg.text}</div>}

        {publicId && <div style={{ padding: 16, borderRadius: 10, background: 'rgba(21,128,61,.12)', border: '1px solid rgba(21,128,61,.3)', marginBottom: 16, textAlign: 'center' }}>
          <strong>Seu ID público</strong>
          <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '6px 0' }}>Guarde este identificador. Nos próximos acessos, você entrará com ele e sua senha.</div>
          <div style={{ fontSize: '1.4rem', fontWeight: 900, letterSpacing: '.05em', color: '#4ade80' }}>{publicId}</div>
        </div>}

        <form onSubmit={handleSubmit}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
            <div><label style={ls}>Nome {req}</label><input type="text" value={form.first_name} onChange={e => set('first_name', e.target.value)} required style={fs} autoComplete="given-name" /></div>
            <div><label style={ls}>Sobrenome {req}</label><input type="text" value={form.last_name} onChange={e => set('last_name', e.target.value)} required style={fs} autoComplete="family-name" /></div>
          </div>
          <div style={{ marginBottom: 12 }}><label style={ls}>E-mail {req}</label><input type="email" value={form.email} onChange={e => set('email', e.target.value)} required style={fs} autoComplete="email" /></div>
          <div style={{ marginBottom: 12 }}><label style={ls}>Telefone {req}</label><input type="tel" value={form.phone} onChange={e => set('phone', e.target.value)} placeholder="+55 (91) 1234-5678" required style={fs} autoComplete="tel" /></div>
          <div style={{ marginBottom: 16 }}><label style={ls}>Gênero</label><select value={form.gender} onChange={e => set('gender', e.target.value)} style={fs}>{GENDERS.map(g => <option key={g.value} value={g.value}>{g.label}</option>)}</select><div style={hs}>Campo opcional.</div></div>

          <h2 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: 10, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>Endereço</h2>
          <div style={{ marginBottom: 12 }}><label style={ls}>Endereço 1</label><input type="text" value={form.addr1} onChange={e => set('addr1', e.target.value)} style={fs} autoComplete="address-line1" /></div>
          <div style={{ marginBottom: 12 }}><label style={ls}>Complemento / referência</label><input type="text" value={form.addr2} onChange={e => set('addr2', e.target.value)} style={fs} /></div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12, marginBottom: 12 }}>
            <div><label style={ls}>Casa ou Ap. nº</label><input type="text" value={form.unit} onChange={e => set('unit', e.target.value)} style={fs} /></div>
            <div><label style={ls}>CEP</label><input type="text" value={form.cep} onChange={e => set('cep', e.target.value)} inputMode="numeric" style={fs} autoComplete="postal-code" /></div>
            <div><label style={ls}>Bairro</label><input type="text" value={form.bairro} onChange={e => set('bairro', e.target.value)} style={fs} /></div>
          </div>
          <div style={{ marginBottom: 12 }}><label style={ls}>Cidade</label><input type="text" value={form.city} onChange={e => set('city', e.target.value)} style={fs} autoComplete="address-level2" /></div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
            <div><label style={ls}>Estado</label><select value={form.state} onChange={e => set('state', e.target.value)} style={fs}>{STATES_BR.map(s => <option key={s} value={s}>{s || 'Selecione...'}</option>)}</select></div>
            <div><label style={ls}>País</label><input type="text" value={form.country} onChange={e => set('country', e.target.value)} style={fs} /></div>
          </div>

          <hr style={{ border: 'none', borderTop: '1px solid rgba(255,255,255,.1)', margin: '20px 0' }} />

          {currentLib?.has_regimento && (
            <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start', marginBottom: 12, fontSize: '.85rem', cursor: 'pointer' }}>
              <input type="checkbox" checked={form.acceptRules} onChange={e => set('acceptRules', e.target.checked)} style={{ marginTop: 3 }} />
              <span>Eu li e aceito o Regimento da Biblioteca (empréstimos, prazos, prorrogações e atrasos). {req}</span>
            </label>
          )}

          <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start', marginBottom: 16, fontSize: '.85rem', cursor: 'pointer' }}>
            <input type="checkbox" checked={form.consent} onChange={e => set('consent', e.target.checked)} required style={{ marginTop: 3 }} />
            <span>Eu aceito que meu e-mail seja usado para: {req} <strong>reservas</strong>, <strong>empréstimos</strong>, <strong>prorrogações</strong>, <strong>devoluções</strong> e <strong>avisos de atraso</strong>.</span>
          </label>

          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <Button variant="primary" type="submit" disabled={loading}>{loading ? 'Enviando…' : 'Enviar cadastro'}</Button>
            <Button variant="secondary" onClick={() => navigate(-1)}>Voltar</Button>
            <Link to="/cadastro" style={{ textDecoration: 'none' }}><Button variant="secondary">Já tenho conta → Entrar</Button></Link>
          </div>
        </form>
      </div>
    <Footer /></PageShell>
  );
}
