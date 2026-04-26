import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { Button } from '@/components/ui';

const PROJECT_STAGES = [
  { value: '', label: 'Selecione...' },
  { value: 'em_funcionamento', label: 'Em funcionamento (já empresta livros)' },
  { value: 'em_montagem', label: 'Em montagem (acervo em construção)' },
  { value: 'em_planejamento', label: 'Em planejamento (ideia em estruturação)' },
  { value: 'reativacao', label: 'Reativação (parou e quer recomeçar)' },
];

const FIRST_MANAGER_OPTIONS = [
  { value: 'sim', label: 'Sim, essa pessoa será o primeiro perfil responsável' },
  { value: 'nao', label: 'Não, a pessoa é apenas o contato inicial' },
  { value: 'a_definir', label: 'A definir depois com a coordenação' },
];

export default function SolicitarBibliotecaPage() {
  const navigate = useNavigate();
  const { user } = useAuth();
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

  // Pre-fill contact email from logged user
  useEffect(() => {
    if (user?.email && !form.contactEmail) {
      setForm(prev => ({ ...prev, contactEmail: user.email }));
    }
  }, [user]);

  function set(k, v) { setForm(p => ({ ...p, [k]: v })); }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.libraryName.trim() || !form.city.trim() || !form.country.trim()) { setMsg({ text: 'Preencha o nome da biblioteca, cidade e país.', kind: 'error' }); return; }
    if (!form.libraryEmail.trim()) { setMsg({ text: 'Informe o e-mail principal da biblioteca.', kind: 'error' }); return; }
    if (!form.projectStage) { setMsg({ text: 'Selecione a situação atual da iniciativa.', kind: 'error' }); return; }
    if (!form.contactName.trim() || !form.contactEmail.trim()) { setMsg({ text: 'Informe nome e e-mail da pessoa responsável.', kind: 'error' }); return; }
    if (!form.summary.trim()) { setMsg({ text: 'Escreva uma breve apresentação da biblioteca ou coletivo.', kind: 'error' }); return; }
    if (!form.confirmReal || !form.confirmContact) { setMsg({ text: 'Marque as duas confirmações obrigatórias.', kind: 'error' }); return; }
    if (!user) { setMsg({ text: 'Faça login antes de enviar a solicitação. Crie uma conta em Cadastro se ainda não tem.', kind: 'error' }); return; }

    setLoading(true); setMsg({ text: '', kind: '' });

    try {
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

      const { data, error } = await supabase.from('library_requests').insert(payload).select().single();
      if (error) throw error;

      // Try to send notification
      try {
        await supabase.functions.invoke('notify-library-request', { body: { request_id: data.id, event: 'new_request' } });
      } catch {}

      setSubmitted(true);
      setSummaryData(data);
      setMsg({ text: 'Solicitação institucional registrada com sucesso! A coordenação da rede analisará as informações.', kind: 'ok' });
    } catch (err) {
      setMsg({ text: `Erro: ${err.message}`, kind: 'error' });
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
          Solicitar entrada de biblioteca
        </h1>
        <p style={{ color: 'var(--brand-muted)', marginBottom: 16, fontSize: '.9rem' }}>
          Solicitação institucional de uma biblioteca ou coletivo para entrar na rede AnarBib.
        </p>

        {/* Notice */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(29,78,216,.08)', border: '1px solid rgba(29,78,216,.2)', marginBottom: 16, fontSize: '.82rem', color: 'var(--brand-muted, #ccc)', lineHeight: 1.6 }}>
          <strong>Como funciona:</strong> primeiro, a pessoa cria uma conta comum no AnarBib. Depois, envia esta solicitação institucional. A coordenação da rede analisa as informações antes de liberar acesso às áreas de gestão bibliotecária.
        </div>

        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 16, fontSize: '.82rem', color: 'var(--brand-muted, #ccc)' }}>
          <strong>Antes de enviar:</strong> entre primeiro na sua conta em <Link to="/cadastro" style={{ textDecoration: 'underline' }}>Cadastro</Link>. O envio registrará um pedido institucional real, em status <strong>pendente</strong>, para análise da coordenação.
        </div>

        {!user && (
          <div style={{ padding: 14, borderRadius: 10, background: 'rgba(220,38,38,.1)', border: '1px solid rgba(220,38,38,.2)', marginBottom: 16, fontSize: '.85rem', color: '#f87171' }}>
            Você precisa estar logado para enviar esta solicitação. <Link to="/cadastro" style={{ textDecoration: 'underline' }}>Entrar</Link> ou <Link to="/criar-conta" style={{ textDecoration: 'underline' }}>Criar conta</Link>.
          </div>
        )}

        {msg.text && <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.85rem', marginBottom: 14, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : '#f87171', border: `1px solid ${msg.kind === 'ok' ? 'rgba(21,128,61,.25)' : 'rgba(220,38,38,.25)'}` }}>{msg.text}</div>}

        {/* Summary after submission */}
        {submitted && summaryData && (
          <div style={{ padding: 16, borderRadius: 10, background: 'rgba(21,128,61,.08)', border: '1px solid rgba(21,128,61,.2)', marginBottom: 20 }}>
            <h2 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: 8, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>Solicitação enviada</h2>
            <p style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginBottom: 8 }}>O pedido institucional foi registrado. Guarde as informações abaixo.</p>
            <div style={{ fontSize: '.82rem', lineHeight: 1.6 }}>
              <div><strong>Biblioteca:</strong> {summaryData.library_name}</div>
              <div><strong>Cidade:</strong> {summaryData.city}{summaryData.state_region ? `, ${summaryData.state_region}` : ''} — {summaryData.country}</div>
              <div><strong>Contato:</strong> {summaryData.contact_name} ({summaryData.contact_email})</div>
              <div><strong>Status:</strong> {summaryData.request_status}</div>
              <div><strong>ID:</strong> {summaryData.id}</div>
            </div>
          </div>
        )}

        {/* Form */}
        {!submitted && (
          <form onSubmit={handleSubmit}>
            <p style={hs}>{req} Campo obrigatório</p>

            <h2 style={{ fontSize: '1rem', fontWeight: 700, margin: '16px 0 10px', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>Dados da biblioteca</h2>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div><label style={ls}>Nome da biblioteca {req}</label><input type="text" value={form.libraryName} onChange={e => set('libraryName', e.target.value)} required style={fs} /></div>
              <div><label style={ls}>Sigla / nome curto</label><input type="text" value={form.libraryShortName} onChange={e => set('libraryShortName', e.target.value)} style={fs} /></div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div><label style={ls}>Cidade {req}</label><input type="text" value={form.city} onChange={e => set('city', e.target.value)} required style={fs} /></div>
              <div><label style={ls}>Estado / região</label><input type="text" value={form.state} onChange={e => set('state', e.target.value)} style={fs} /></div>
              <div><label style={ls}>País {req}</label><input type="text" value={form.country} onChange={e => set('country', e.target.value)} required style={fs} /></div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div><label style={ls}>E-mail principal da biblioteca {req}</label><input type="email" value={form.libraryEmail} onChange={e => set('libraryEmail', e.target.value)} required style={fs} /></div>
              <div><label style={ls}>Telefone / WhatsApp</label><input type="text" value={form.libraryPhone} onChange={e => set('libraryPhone', e.target.value)} style={fs} /></div>
            </div>
            <div style={{ marginBottom: 12 }}><label style={ls}>Endereço ou referência de localização</label><textarea value={form.libraryAddress} onChange={e => set('libraryAddress', e.target.value)} style={{ ...fs, resize: 'vertical', minHeight: 60 }} /></div>
            <div style={{ marginBottom: 16 }}>
              <label style={ls}>Situação atual da iniciativa {req}</label>
              <select value={form.projectStage} onChange={e => set('projectStage', e.target.value)} required style={fs}>
                {PROJECT_STAGES.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
              </select>
            </div>

            <h2 style={{ fontSize: '1rem', fontWeight: 700, margin: '16px 0 10px', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>Pessoa responsável pelo primeiro contato</h2>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div><label style={ls}>Nome completo {req}</label><input type="text" value={form.contactName} onChange={e => set('contactName', e.target.value)} required style={fs} /></div>
              <div><label style={ls}>Função no coletivo / na biblioteca</label><input type="text" value={form.contactRole} onChange={e => set('contactRole', e.target.value)} style={fs} /></div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div><label style={ls}>E-mail da pessoa responsável {req}</label><input type="email" value={form.contactEmail} onChange={e => set('contactEmail', e.target.value)} required style={fs} /></div>
              <div><label style={ls}>Telefone / WhatsApp</label><input type="text" value={form.contactPhone} onChange={e => set('contactPhone', e.target.value)} style={fs} /></div>
            </div>
            <div style={{ marginBottom: 16 }}>
              <label style={ls}>Esta pessoa será o primeiro perfil responsável pela biblioteca?</label>
              <select value={form.firstManager} onChange={e => set('firstManager', e.target.value)} style={fs}>
                {FIRST_MANAGER_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
              </select>
            </div>

            <h2 style={{ fontSize: '1rem', fontWeight: 700, margin: '16px 0 10px', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>Apresentação da iniciativa</h2>
            <div style={{ marginBottom: 12 }}><label style={ls}>Breve apresentação da biblioteca ou coletivo {req}</label><textarea value={form.summary} onChange={e => set('summary', e.target.value)} required style={{ ...fs, resize: 'vertical', minHeight: 80 }} /></div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
              <div><label style={ls}>Público principal atendido</label><input type="text" value={form.publicProfile} onChange={e => set('publicProfile', e.target.value)} style={fs} /></div>
              <div><label style={ls}>Tipo principal de acervo</label><input type="text" value={form.collectionProfile} onChange={e => set('collectionProfile', e.target.value)} style={fs} /></div>
            </div>
            <div style={{ marginBottom: 16 }}><label style={ls}>Observações ou necessidades iniciais</label><textarea value={form.needs} onChange={e => set('needs', e.target.value)} style={{ ...fs, resize: 'vertical', minHeight: 60 }} /></div>

            <hr style={{ border: 'none', borderTop: '1px solid rgba(255,255,255,.1)', margin: '20px 0' }} />

            <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start', marginBottom: 12, fontSize: '.85rem', cursor: 'pointer' }}>
              <input type="checkbox" checked={form.confirmReal} onChange={e => set('confirmReal', e.target.checked)} style={{ marginTop: 3 }} />
              <span>Confirmo que esta solicitação representa uma biblioteca, coletivo ou iniciativa real. {req}</span>
            </label>
            <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start', marginBottom: 16, fontSize: '.85rem', cursor: 'pointer' }}>
              <input type="checkbox" checked={form.confirmContact} onChange={e => set('confirmContact', e.target.checked)} style={{ marginTop: 3 }} />
              <span>Confirmo que os dados informados podem ser usados para contato sobre a entrada na rede AnarBib. {req}</span>
            </label>

            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              <Button variant="primary" type="submit" disabled={loading || !user}>{loading ? 'Enviando…' : 'Enviar solicitação'}</Button>
              <Button variant="secondary" onClick={() => navigate(-1)}>Voltar</Button>
            </div>
          </form>
        )}
      </div>
    <Footer /></PageShell>
  );
}
