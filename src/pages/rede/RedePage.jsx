import { useState, useEffect, useCallback, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Footer } from '@/components/layout';
import '../catalogacao/CatalogacaoPage.css';

const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
// REQ_STATUS built inside component with t()
// ROLE_LABELS built inside component with t()
const SERVICE_LABELS = { funcionamento_normal:'Normal', funcionamento_reduzido:'Reduzido', recesso:'Em recesso', suspenso:'Suspenso' };

const TABS = [
  { id: 'overview', label: 'Resumo da rede' },
  { id: 'requests', label: t({ id: 'rede.requests.label' }) },
  { id: 'libraries', label: 'Bibliotecas' },
  { id: 'members', label: 'Membros da rede' },
  { id: 'admins', label: 'Administradores' },
];

export default function RedePage() {
  const { user } = useAuth();
  const { role } = useLibrary();
  const { formatMessage: t } = useIntl();

  const REQ_STATUS = useMemo(() => ({
    pendente: t({id:'request.status.pendente'}), em_analise: t({id:'request.status.em_analise'}),
    aprovada: t({id:'request.status.aprovada'}), recusada: t({id:'request.status.recusada'}),
    cancelada: t({id:'request.status.cancelada'}),
  }), [t]);
  const ROLE_LABELS = useMemo(() => ({
    reader: t({id:'roles.reader'}), librarian: t({id:'roles.librarian'}),
    coordenador: t({id:'roles.coordenador'}), administrador: t({id:'roles.administrador'}),
  }), [t]);
  const roleLoaded = role !== null && role !== undefined;
  const isAdmin = role === 'administrador';

  const [tab, setTab] = useState('overview');
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [loading, setLoading] = useState(false);

  // ── Data ────────────────────────────────────────────────
  const [globalStats, setGlobalStats] = useState(null);
  const [libCards, setLibCards] = useState([]);
  const [requests, setRequests] = useState([]);
  const [reqFilter, setReqFilter] = useState('');
  const [selectedReq, setSelectedReq] = useState(null);
  const [reviewNote, setReviewNote] = useState('');
  const [allMembers, setAllMembers] = useState([]);
  const [memberFilter, setMemberFilter] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [newAdminEmail, setNewAdminEmail] = useState('');

  // ── Load ────────────────────────────────────────────────
  const loadAll = useCallback(async () => {
    setLoading(true);
    try {
      // 1. Libraries with details
      const { data: libs } = await supabase.from('libraries').select('id, name, slug, short_name, city, state, country, is_active, created_at').order('name');
      const { data: commons } = await supabase.from('library_commons').select('library_id, display_name, contact_email, logo_file_key');
      const { data: svcStates } = await supabase.from('library_service_state').select('library_id, service_mode, allows_new_loans, allows_new_reservations, public_message');

      // Per-library counts
      const enriched = await Promise.all((libs || []).map(async lib => {
        const commRow = (commons || []).find(c => c.library_id === lib.id);
        const svcRow = (svcStates || []).find(s => s.library_id === lib.id);
        const [rdrs, staff, exs, loansOpen, loansTotal, resActive, resTotal] = await Promise.all([
          supabase.from('user_library_memberships').select('id', { count:'exact', head:true }).eq('library_id', lib.id).eq('role', 'reader'),
          supabase.from('user_library_memberships').select('id', { count:'exact', head:true }).eq('library_id', lib.id).in('role', ['librarian','coordenador','administrador']),
          supabase.from('exemplares').select('id', { count:'exact', head:true }).eq('library_id', lib.id),
          supabase.from('emprestimos_v2').select('id', { count:'exact', head:true }).eq('library_id', lib.id).or('status_global.is.null,status_global.neq.devolvido'),
          supabase.from('emprestimos_v2').select('id', { count:'exact', head:true }).eq('library_id', lib.id),
          supabase.from('reservas_v2').select('id', { count:'exact', head:true }).eq('library_id', lib.id).not('status_global', 'in', '(cancelada,concluida,expirada)'),
          supabase.from('reservas_v2').select('id', { count:'exact', head:true }).eq('library_id', lib.id),
        ]);
        return {
          ...lib, ...commRow, ...svcRow,
          readers: rdrs.count||0, staff: staff.count||0, exemplars: exs.count||0,
          loansOpen: loansOpen.count||0, loansTotal: loansTotal.count||0,
          resActive: resActive.count||0, resTotal: resTotal.count||0,
        };
      }));
      setLibCards(enriched);

      // 2. Global stats
      const totals = enriched.reduce((a, l) => ({
        libraries: a.libraries + 1, readers: a.readers + l.readers, staff: a.staff + l.staff,
        exemplars: a.exemplars + l.exemplars, loansOpen: a.loansOpen + l.loansOpen, resActive: a.resActive + l.resActive,
      }), { libraries:0, readers:0, staff:0, exemplars:0, loansOpen:0, resActive:0 });
      const [bk, au] = await Promise.all([
        supabase.from('books').select('id', { count:'exact', head:true }),
        supabase.from('authors').select('id', { count:'exact', head:true }),
      ]);
      setGlobalStats({ ...totals, books: bk.count||0, authors: au.count||0 });

      // 3. Requests
      const { data: reqData } = await supabase.from('library_requests').select('*').order('created_at', { ascending: false });
      setRequests(reqData || []);

      // 4. All members
      const { data: memData } = await supabase.from('user_library_memberships')
        .select('user_id, role, status, library_id, is_primary, created_at, libraries(name, slug), profiles:user_id(email, first_name, last_name)')
        .order('role');
      setAllMembers(memData || []);

    } catch (err) { console.warn('RedePage loadAll:', err); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { if (isAdmin) loadAll(); }, [isAdmin, loadAll]);

  // ── Actions ─────────────────────────────────────────────
  async function updateRequestStatus(reqId, newStatus) {
    try {
      await supabase.from('library_requests').update({
        request_status: newStatus, review_notes: reviewNote || null,
        reviewed_at: new Date().toISOString(), reviewed_by_user_id: user?.id,
      }).eq('id', reqId);
      setMsg({ text: t({id:'common.dataSaved'}), kind: 'ok' });
      setSelectedReq(null); setReviewNote('');
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
  }

  async function changeUserRole(userId, libraryId, newRole) {
    try {
      await supabase.from('user_library_memberships').update({ role: newRole }).eq('user_id', userId).eq('library_id', libraryId);
      setMsg({ text: t({id:'common.dataSaved'}), kind: 'ok' });
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
  }

  async function toggleLibraryActive(libId, currentState) {
    if (!confirm(currentState ? t({ id: 'rede.deactivateConfirm' }) : t({ id: 'rede.reactivateConfirm' }))) return;
    try {
      await supabase.from('libraries').update({ is_active: !currentState }).eq('id', libId);
      setMsg({ text: currentState ? t({id:'biblioteca.deactivated'}) : t({id:'biblioteca.reactivated'}), kind: 'ok' });
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
  }

  async function addAdmin() {
    if (!newAdminEmail.trim()) { setMsg({ text: 'Informe o e-mail.', kind: 'error' }); return; }
    const member = allMembers.find(m => m.profiles?.email?.toLowerCase() === newAdminEmail.trim().toLowerCase());
    if (!member) { setMsg({ text: t({ id: 'rede.admins.userNotFound' }), kind: 'error' }); return; }
    await changeUserRole(member.user_id, member.library_id, 'administrador');
    setNewAdminEmail('');
  }

  async function removeAdmin(userId, libraryId) {
    if (!confirm(t({ id: 'rede.admins.removeConfirm' }))) return;
    await changeUserRole(userId, libraryId, 'coordenador');
  }

  // ── Styles ──────────────────────────────────────────────
  const fs = { width:'100%', padding:'10px 12px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', fontSize:'.9rem' };
  const ls = { display:'block', fontSize:'.85rem', fontWeight:600, marginBottom:3, color:'var(--brand-muted, #ccc)' };
  const bx = { padding:14, borderRadius:10, background:'rgba(255,255,255,.03)', border:'1px solid rgba(255,255,255,.08)', marginBottom:16 };
  const lr = (i) => ({ padding:'10px 12px', background:i%2===0?'rgba(0,0,0,.08)':'transparent', borderBottom:'1px solid rgba(255,255,255,.04)', display:'flex', justifyContent:'space-between', alignItems:'center', gap:8 });
  const lw = { border:'1px solid rgba(255,255,255,.06)', borderRadius:8, overflow:'hidden' };
  const statCell = (v, l, warn) => (
    <div style={{ textAlign:'center', padding:'8px 4px', borderRadius:6, background: warn ? 'rgba(220,38,38,.08)' : 'rgba(0,0,0,.15)' }}>
      <div style={{ fontSize:'1.2rem', fontWeight:800, color: warn ? '#f87171' : 'inherit' }}>{v}</div>
      <div style={{ fontSize:'.7rem', color:'var(--brand-muted)' }}>{l}</div>
    </div>
  );

  // ── Guards ──────────────────────────────────────────────
  if (!roleLoaded) return <PageShell><Topbar /><div style={{ textAlign:'center', padding:60, color:'var(--brand-muted)' }}>{t({id:'common.loading'})}</div><Footer /></PageShell>;
  if (!isAdmin) return (
    <PageShell><Topbar />
      <div className="catalogacao-wrap" style={{ maxWidth:800, margin:'0 auto', textAlign:'center', padding:'60px 24px' }}>
        <h1>{t({ id: 'rede.title' })}</h1>
        <p style={{ color:'var(--brand-muted)', marginTop:12 }}>{t({ id: 'rede.restricted' })}</p>
        <Link to="/painel"><button className="cat-btn primary" style={{ marginTop:16 }}>{t({ id: 'common.back' })}</button></Link>
      </div>
    <Footer /></PageShell>
  );

  const admins = allMembers.filter(m => m.role === 'administrador');
  const filteredReqs = reqFilter ? requests.filter(r => r.request_status === reqFilter) : requests;
  const filteredMembers = allMembers.filter(m => {
    if (roleFilter && m.role !== roleFilter) return false;
    if (!memberFilter) return true;
    const s = memberFilter.toLowerCase();
    return (m.profiles?.email||'').toLowerCase().includes(s) || (m.profiles?.first_name||'').toLowerCase().includes(s) || (m.profiles?.last_name||'').toLowerCase().includes(s) || (m.libraries?.name||'').toLowerCase().includes(s);
  });
  const roleCounts = allMembers.reduce((a, m) => { a[m.role] = (a[m.role]||0) + 1; return a; }, {});

  return (
    <PageShell><Topbar />
      <div className="catalogacao-wrap" style={{ maxWidth:1200, margin:'0 auto' }}>

        <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:16, flexWrap:'wrap', gap:12 }}>
          <div>
            <h1 style={{ margin:0 }}>{t({ id: 'rede.title' })}</h1>
            <p style={{ color:'var(--brand-muted)', fontSize:'.9rem', margin:'2px 0 0' }}>
              Coordenação da rede AnarBib
              <span className="cat-pill danger" style={{ marginLeft:8, fontSize:'.65rem' }}>Administrador(a)</span>
            </p>
          </div>
          <div style={{ display:'flex', gap:8, flexWrap:'wrap' }}>
            <Link to="/painel" style={{ textDecoration:'none' }}><button className="cat-btn secondary">{t({ id: 'nav.panel' })}</button></Link>
            <Link to="/biblioteca" style={{ textDecoration:'none' }}><button className="cat-btn secondary">{t({ id: 'nav.library' })}</button></Link>
            <Link to="/importacoes" style={{ textDecoration:'none' }}><button className="cat-btn secondary">{t({ id: 'nav.importacoes' })}</button></Link>
            <button className="cat-btn secondary" onClick={loadAll} disabled={loading}>{loading ? 'Atualizando…' : 'Atualizar dados'}</button>
          </div>
        </div>

        {msg.text && <div style={{ padding:'10px 14px', borderRadius:8, fontSize:'.9rem', marginBottom:14, background:msg.kind==='ok'?'rgba(21,128,61,.12)':'rgba(220,38,38,.12)', color:msg.kind==='ok'?'#4ade80':'#f87171' }}>{msg.text}</div>}

        <div className="cat-tabs" style={{ marginBottom:18 }}>
          {TABS.map(t => <button key={t.id} className={`cat-tab-btn${tab===t.id?' active':''}`} onClick={()=>setTab(t.id)}>{t.label}{t.id==='requests'&&requests.filter(r=>r.request_status==='pendente').length>0?` (${requests.filter(r=>r.request_status==='pendente').length})`:''}</button>)}
        </div>

        {/* ═══ 1. RESUMO DA REDE ═══════════════════════ */}
        {tab==='overview' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'rede.overview.title' })}</h3>
          {globalStats && (
            <div className="cat-statusbar" style={{ marginBottom:18 }}>
              {[[t({id:'rede.stats.libraries'}),globalStats.libraries],[t({id:'rede.stats.documents'}),globalStats.books],[t({id:'rede.stats.authorities'}),globalStats.authors],
                [t({id:'rede.stats.exemplars'}),globalStats.exemplars],[t({id:'rede.stats.staff'}),globalStats.staff],[t({id:'rede.stats.readers'}),globalStats.readers],
                [t({id:'rede.overview.loansOpen'}),globalStats.loansOpen],[t({id:'rede.overview.reservationsActive'}),globalStats.resActive],
              ].map(([l,v]) => <div key={l} className="cat-stat"><span className="cat-stat-label">{l}</span><span className="cat-stat-value">{v}</span></div>)}
            </div>
          )}

          <div style={{ display:'grid', gridTemplateColumns:'repeat(auto-fill, minmax(320px, 1fr))', gap:14 }}>
            {libCards.map(lib => {
              const logoUrl = lib.logo_file_key ? `${PROJECT_URL}/storage/v1/object/public/library-ui-assets/${lib.logo_file_key.includes('/')?lib.logo_file_key:`themes/${lib.logo_file_key}/logo-${lib.logo_file_key}.png`}` : null;
              const hasAlerts = lib.loansOpen > 0 || lib.resActive > 0 || lib.service_mode !== 'funcionamento_normal';
              return (
                <div key={lib.id} style={{ padding:16, borderRadius:10, background:'rgba(255,255,255,.03)', border:`1px solid ${hasAlerts?'rgba(251,191,36,.2)':'rgba(255,255,255,.08)'}` }}>
                  <div style={{ display:'flex', gap:10, alignItems:'center', marginBottom:10 }}>
                    {logoUrl && <img src={logoUrl} alt="" style={{ height:36, objectFit:'contain', filter:'drop-shadow(0 2px 6px rgba(0,0,0,.4))' }} />}
                    <div style={{ flex:1 }}>
                      <div style={{ fontSize:'1rem', fontWeight:700 }}>{lib.name}</div>
                      <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                        {lib.slug} · {lib.city||'—'}{lib.state&&`, ${lib.state}`}
                        <span className={`cat-pill ${lib.is_active?'ok':'warn'}`} style={{ marginLeft:6, fontSize:'.6rem' }}>{lib.is_active?'Ativa':'Inativa'}</span>
                      </div>
                    </div>
                  </div>
                  <div style={{ display:'flex', gap:6, marginBottom:8, flexWrap:'wrap' }}>
                    <span className={`cat-pill ${lib.service_mode==='funcionamento_normal'?'ok':'warn'}`} style={{ fontSize:'.68rem' }}>{SERVICE_LABELS[lib.service_mode]||lib.service_mode}</span>
                    {lib.allows_new_loans && <span className="cat-pill ok" style={{ fontSize:'.68rem' }}>Empréstimos</span>}
                    {lib.allows_new_reservations && <span className="cat-pill ok" style={{ fontSize:'.68rem' }}>Reservas</span>}
                    {!lib.allows_new_loans && <span className="cat-pill danger" style={{ fontSize:'.68rem' }}>Sem empréstimos</span>}
                  </div>
                  <div style={{ display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:4, marginBottom:8 }}>
                    {statCell(lib.readers, t({id:'rede.stats.readers'}))}
                    {statCell(lib.staff, 'Equipe')}
                    {statCell(lib.exemplars, 'Exemplares')}
                    {statCell(lib.loansOpen, 'Emp. abertos', lib.loansOpen > 0)}
                  </div>
                  <div style={{ fontSize:'.78rem', color:'var(--brand-muted)' }}>
                    {lib.contact_email && <span>✉ {lib.contact_email}</span>}
                    {lib.created_at && <span style={{ marginLeft:8 }}>Desde {new Date(lib.created_at).toLocaleDateString('pt-BR')}</span>}
                  </div>
                </div>
              );
            })}
          </div>
        </div>)}

        {/* ═══ 2. SOLICITAÇÕES ═════════════════════════ */}
        {tab==='requests' && (<div>
          <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:12 }}>
            <h3 style={{ margin:0 }}>Solicitações ({requests.length})</h3>
            <select value={reqFilter} onChange={e=>setReqFilter(e.target.value)} style={{...fs, width:'auto'}}>
              <option value="">Todas</option>
              {Object.entries(REQ_STATUS).map(([k,v])=><option key={k} value={k}>{v}</option>)}
            </select>
          </div>

          <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:16 }}>
            <div style={lw}>
              {filteredReqs.length===0 && <div style={{ padding:16, fontSize:'.88rem', color:'var(--brand-muted)' }}>{t({id:'common.empty'})}</div>}
              {filteredReqs.map((r,i) => (
                <div key={r.id} style={{...lr(i), cursor:'pointer', background: selectedReq?.id===r.id?'rgba(29,78,216,.12)':lr(i).background}} onClick={()=>{setSelectedReq(r);setReviewNote(r.review_notes||'');}}>
                  <div style={{ flex:1 }}>
                    <div style={{ fontSize:'.9rem', fontWeight:600 }}>{r.library_name || '(sem nome)'}</div>
                    <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>{r.city||'—'}{r.state_region&&`, ${r.state_region}`} · {new Date(r.created_at).toLocaleDateString('pt-BR')}</div>
                  </div>
                  <span className={`cat-pill ${r.request_status==='aprovada'?'ok':r.request_status==='recusada'?'danger':r.request_status==='em_analise'?'info':'warn'}`} style={{ fontSize:'.7rem' }}>
                    {REQ_STATUS[r.request_status]||r.request_status}
                  </span>
                </div>
              ))}
            </div>
            <div>
              {!selectedReq && <div style={bx}><p style={{ fontSize:'.88rem', color:'var(--brand-muted)', margin:0 }}>Selecione uma solicitação para ver os detalhes e tomar uma decisão.</p></div>}
              {selectedReq && (
                <div style={bx}>
                  <h4 style={{ margin:'0 0 10px' }}>{selectedReq.library_name}</h4>
                  <div style={{ fontSize:'.85rem', lineHeight:1.7, marginBottom:12 }}>
                    {[['Nome curto',selectedReq.library_short_name],['Cidade',`${selectedReq.city||'—'}${selectedReq.state_region?`, ${selectedReq.state_region}`:''}${selectedReq.country?` — ${selectedReq.country}`:''}`],
                      [t({id:'rede.requests.email'}),selectedReq.library_email],[t({id:'rede.requests.phone'}),selectedReq.library_phone],[t({id:'rede.requests.address'}),selectedReq.library_address],
                      ['Contato',`${selectedReq.contact_name||'—'} (${selectedReq.contact_role||'—'}) · ${selectedReq.contact_email||'—'}`],
                      [t({id:'rede.requests.stage'}),selectedReq.project_stage],[t({id:'rede.requests.firstManager'}),selectedReq.first_manager_intent],
                    ].map(([k,v])=> v && <div key={k}><strong>{k}:</strong> {v}</div>)}
                    {selectedReq.summary && <div style={{ marginTop:6 }}><strong>Apresentação:</strong><br/>{selectedReq.summary}</div>}
                    {selectedReq.needs && <div style={{ marginTop:6 }}><strong>Necessidades:</strong><br/>{selectedReq.needs}</div>}
                    {selectedReq.collection_profile && <div style={{ marginTop:6 }}><strong>Perfil do acervo:</strong><br/>{selectedReq.collection_profile}</div>}
                    {selectedReq.public_profile && <div style={{ marginTop:6 }}><strong>Perfil público:</strong><br/>{selectedReq.public_profile}</div>}
                  </div>
                  <label style={ls}>Nota de revisão</label>
                  <textarea value={reviewNote} onChange={e=>setReviewNote(e.target.value)} rows={3} style={{...fs,resize:'vertical',marginBottom:10}} placeholder="Observações, pedido de complemento, motivo de recusa…" />
                  <div style={{ display:'flex', gap:6, flexWrap:'wrap' }}>
                    <button className="cat-btn secondary" onClick={()=>updateRequestStatus(selectedReq.id,'em_analise')}>{t({ id: 'rede.requests.inReview' })}</button>
                    <button className="cat-btn primary" onClick={()=>updateRequestStatus(selectedReq.id,'aprovada')}>{t({ id: 'rede.requests.approve' })}</button>
                    <button className="cat-btn ghost" style={{ color:'#f87171' }} onClick={()=>updateRequestStatus(selectedReq.id,'recusada')}>{t({ id: 'rede.requests.refuse' })}</button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>)}

        {/* ═══ 3. BIBLIOTECAS ═════════════════════════ */}
        {tab==='libraries' && (<div>
          <h3 style={{ marginBottom:12 }}>Panorama das bibliotecas ({libCards.length})</h3>
          <div style={lw}>
            <div style={{ display:'grid', gridTemplateColumns:'2.5fr 1fr 1fr 1fr 1fr 1fr 1fr .8fr', gap:0, padding:'8px 12px', fontSize:'.75rem', fontWeight:700, color:'var(--brand-muted)', borderBottom:'1px solid rgba(255,255,255,.08)' }}>
              <div>{t({ id: 'nav.library' })}</div><div style={{ textAlign:'center' }}>Serviço</div><div style={{ textAlign:'center' }}>Leitores</div><div style={{ textAlign:'center' }}>Equipe</div><div style={{ textAlign:'center' }}>Exemplares</div><div style={{ textAlign:'center' }}>Emp. abertos</div><div style={{ textAlign:'center' }}>Res. ativas</div><div style={{ textAlign:'center' }}>Ações</div>
            </div>
            {libCards.map((lib,i) => (
              <div key={lib.id} style={{ display:'grid', gridTemplateColumns:'2.5fr 1fr 1fr 1fr 1fr 1fr 1fr .8fr', gap:0, padding:'10px 12px', background:i%2===0?'rgba(0,0,0,.08)':'transparent', borderBottom:'1px solid rgba(255,255,255,.04)', alignItems:'center' }}>
                <div>
                  <div style={{ fontSize:'.9rem', fontWeight:600 }}>{lib.name} <span className={`cat-pill ${lib.is_active?'ok':'warn'}`} style={{ fontSize:'.6rem' }}>{lib.is_active?'Ativa':'Inativa'}</span></div>
                  <div style={{ fontSize:'.78rem', color:'var(--brand-muted)' }}>{lib.slug} · {lib.city||'—'} · {lib.contact_email||'—'}</div>
                </div>
                <div style={{ textAlign:'center' }}><span className={`cat-pill ${lib.service_mode==='funcionamento_normal'?'ok':'warn'}`} style={{ fontSize:'.65rem' }}>{SERVICE_LABELS[lib.service_mode]||'—'}</span></div>
                <div style={{ textAlign:'center', fontSize:'.9rem', fontWeight:700 }}>{lib.readers}</div>
                <div style={{ textAlign:'center', fontSize:'.9rem', fontWeight:700 }}>{lib.staff}</div>
                <div style={{ textAlign:'center', fontSize:'.9rem', fontWeight:700 }}>{lib.exemplars}</div>
                <div style={{ textAlign:'center', fontSize:'.9rem', fontWeight:700, color: lib.loansOpen>0?'#fbbf24':'inherit' }}>{lib.loansOpen}</div>
                <div style={{ textAlign:'center', fontSize:'.9rem', fontWeight:700, color: lib.resActive>0?'#60a5fa':'inherit' }}>{lib.resActive}</div>
                <div style={{ textAlign:'center' }}>
                  <button className="cat-btn ghost" style={{ fontSize:'.75rem', padding:'3px 8px', color: lib.is_active?'#f87171':'#4ade80' }} onClick={()=>toggleLibraryActive(lib.id, lib.is_active)}>
                    {lib.is_active ? 'Desativar' : 'Reativar'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>)}

        {/* ═══ 4. MEMBROS DA REDE ═════════════════════ */}
        {tab==='members' && (<div>
          <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:12, flexWrap:'wrap', gap:8 }}>
            <h3 style={{ margin:0 }}>Membros da rede ({allMembers.length})</h3>
            <div style={{ display:'flex', gap:8, alignItems:'center', flexWrap:'wrap' }}>
              <input type="text" value={memberFilter} onChange={e=>setMemberFilter(e.target.value)} placeholder="Buscar nome, e-mail, biblioteca…" style={{...fs, width:240}} />
              <select value={roleFilter} onChange={e=>setRoleFilter(e.target.value)} style={{...fs, width:'auto'}}>
                <option value="">{t({id:'rede.members.allRoles'})}</option>
                {Object.entries(ROLE_LABELS).map(([k,v])=><option key={k} value={k}>{v} ({roleCounts[k]||0})</option>)}
              </select>
            </div>
          </div>

          <div style={{ display:'flex', gap:10, marginBottom:12, flexWrap:'wrap' }}>
            {Object.entries(ROLE_LABELS).map(([k,v]) => (
              <div key={k} style={{ padding:'6px 14px', borderRadius:8, background:'rgba(0,0,0,.15)', textAlign:'center', cursor:'pointer', border: roleFilter===k?'1px solid rgba(255,255,255,.2)':'1px solid transparent' }} onClick={()=>setRoleFilter(roleFilter===k?'':k)}>
                <div style={{ fontSize:'1.1rem', fontWeight:800 }}>{roleCounts[k]||0}</div>
                <div style={{ fontSize:'.72rem', color:'var(--brand-muted)' }}>{v}</div>
              </div>
            ))}
          </div>

          <div style={lw}>
            {filteredMembers.length===0 && <div style={{ padding:16, fontSize:'.88rem', color:'var(--brand-muted)' }}>Nenhum membro encontrado.</div>}
            {filteredMembers.map((m,i) => {
              const p = m.profiles || {};
              return (
                <div key={`${m.user_id}-${m.library_id}`} style={lr(i)}>
                  <div style={{ flex:1 }}>
                    <div style={{ fontSize:'.9rem', fontWeight:600 }}>{[p.first_name,p.last_name].filter(Boolean).join(' ')||p.email||'(sem nome)'}</div>
                    <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                      {p.email||'—'} · {m.libraries?.name||'—'}
                      {m.created_at && ` · desde ${new Date(m.created_at).toLocaleDateString('pt-BR')}`}
                    </div>
                  </div>
                  <select value={m.role} onChange={e=>changeUserRole(m.user_id,m.library_id,e.target.value)}
                    style={{ fontSize:'.82rem', padding:'4px 8px', borderRadius:6, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4' }}>
                    {Object.entries(ROLE_LABELS).map(([k,v])=><option key={k} value={k}>{v}</option>)}
                  </select>
                </div>
              );
            })}
          </div>
        </div>)}

        {/* ═══ 5. ADMINISTRADORES ═════════════════════ */}
        {tab==='admins' && (<div>
          <h3 style={{ marginBottom:12 }}>Administradores da rede ({admins.length})</h3>
          <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:14 }}>
            Os administradores têm acesso total ao painel de rede, à gestão dos membros e podem promover outros administradores. Este privilégio deve ser reservado a muito poucas pessoas de confiança da rede.
          </div>

          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>Promover um(a) camarada a administrador(a)</h4>
            <div style={{ display:'flex', gap:8, marginBottom:8 }}>
              <input type="email" value={newAdminEmail} onChange={e=>setNewAdminEmail(e.target.value)} onKeyDown={e=>e.key==='Enter'&&addAdmin()} placeholder="E-mail do(a) camarada a promover…" style={{...fs, flex:1}} />
              <button className="cat-btn primary" onClick={addAdmin} style={{ flexShrink:0 }}>{t({ id: 'rede.admins.promoteButton' })}</button>
            </div>
            <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>O usuário já deve ter uma conta ativa e um vínculo com uma biblioteca na rede.</div>
          </div>

          <div style={lw}>
            {admins.length===0 && <div style={{ padding:16, fontSize:'.88rem', color:'var(--brand-muted)' }}>Nenhum administrador encontrado.</div>}
            {admins.map((m,i) => {
              const p = m.profiles || {};
              const isSelf = m.user_id === user?.id;
              return (
                <div key={`${m.user_id}-${m.library_id}`} style={lr(i)}>
                  <div style={{ flex:1 }}>
                    <div style={{ fontSize:'.9rem', fontWeight:600 }}>
                      {[p.first_name,p.last_name].filter(Boolean).join(' ')||p.email||'(sem nome)'}
                      {isSelf && <span style={{ fontSize:'.78rem', color:'var(--brand-muted)', marginLeft:8 }}>(você)</span>}
                    </div>
                    <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                      {p.email||'—'} · {m.libraries?.name||'—'}
                      {m.created_at && ` · membro desde ${new Date(m.created_at).toLocaleDateString('pt-BR')}`}
                    </div>
                  </div>
                  {!isSelf && (
                    <button className="cat-btn ghost" style={{ fontSize:'.82rem', padding:'5px 12px', color:'#f87171' }} onClick={()=>removeAdmin(m.user_id,m.library_id)}>{t({ id: 'rede.admins.removeButton' })}</button>
                  )}
                </div>
              );
            })}
          </div>
        </div>)}

      </div>
    <Footer /></PageShell>
  );
}
