import { useState, useEffect, useCallback, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import TeamPanel from '@/components/team/TeamPanel';
import '@/components/team/TeamPanel.css';
import AdminsPanel from '@/components/rede/AdminsPanel';
import '../catalogacao/CatalogacaoPage.css';

const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
// REQ_STATUS built inside component with t()
// ROLE_LABELS built inside component with t()
// SERVICE_LABELS built inside component with t() — was hardcoded pt-BR (audit 07/05/2026)

export default function RedePage() {
  const { user } = useAuth();
  const { role } = useLibrary();
  const { formatMessage: t, locale } = useIntl();
  useDocumentTitle(t({ id: 'pageTitle.network' }));

  const SERVICE_LABELS = useMemo(() => ({
    funcionamento_normal:    t({ id: 'rede.serviceMode.funcionamento_normal' }),
    funcionamento_reduzido:  t({ id: 'rede.serviceMode.funcionamento_reduzido' }),
    recesso:                 t({ id: 'rede.serviceMode.recesso' }),
    suspenso:                t({ id: 'rede.serviceMode.suspenso' }),
  }), [t]);

  const REQ_STATUS = useMemo(() => ({
    pendente: t({id:'request.status.pendente'}), em_analise: t({id:'request.status.em_analise'}),
    aprovada: t({id:'request.status.aprovada'}), recusada: t({id:'request.status.recusada'}),
    cancelada: t({id:'request.status.cancelada'}),
  }), [t]);
  const ROLE_LABELS = useMemo(() => ({
    reader: t({id:'roles.reader'}), librarian: t({id:'roles.librarian'}),
    coordenador: t({id:'roles.coordenador'}), administrador: t({id:'roles.administrador'}),
  }), [t]);
  const TABS = useMemo(() => ([
    { id: 'overview', label: t({ id: 'rede.tab.overview' }) },
    { id: 'requests', label: t({ id: 'rede.requests.label' }) },
    { id: 'libraries', label: t({ id: 'rede.tab.libraries' }) },
    { id: 'members', label: t({ id: 'rede.tab.members' }) },
    { id: 'admins', label: t({ id: 'rede.tab.admins' }) },
  ]), [t]);
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
  // allMembers reste chargé : utilisé par l'onglet "admins" (filtre des
  // administradores, addAdmin, removeAdmin). L'onglet "members" affiche
  // désormais <TeamPanel /> qui charge ses propres données.
  const [allMembers, setAllMembers] = useState([]);
  const [newAdminEmail, setNewAdminEmail] = useState('');

  // ── Load ────────────────────────────────────────────────
  const loadAll = useCallback(async () => {
    setLoading(true);
    try {
      // 1. Libraries with details
      const { data: libs } = await supabase.from('libraries').select('id, name, slug, short_name, city, state, country, is_active, created_at').order('name');
      const { data: commons } = await supabase.from('library_commons').select('library_id, display_name, contact_email, logo_file_key');
      const { data: svcStates } = await supabase.from('library_service_state').select('library_id, service_mode, allows_new_loans, allows_new_reservations, public_message');

      // Per-library counts — bascule sur la vue canonique api.library_circulation_stats
      // (même source que BibliotecaPage onglet Rapports). Garantit cohérence
      // cross-pages et règle le bug du filtre status_global mal formé.
      // 1 requête par biblio au lieu de 7.
      const enriched = await Promise.all((libs || []).map(async lib => {
        const commRow = (commons || []).find(c => c.library_id === lib.id);
        const svcRow = (svcStates || []).find(s => s.library_id === lib.id);
        const { data: cs } = await supabase
          .schema('api').from('library_circulation_stats')
          .select('*').eq('library_id', lib.id).maybeSingle();
        const s = cs || {};
        return {
          ...lib, ...commRow, ...svcRow,
          readers: s.readers_active || 0,
          staff: s.librarians_active || 0,
          exemplars: s.exemplars_count || 0,
          loansOpen: s.loans_open || 0,
          loansOverdue: s.loans_overdue || 0,
          resActive: s.reservations_active || 0,
        };
      }));
      setLibCards(enriched);

      // 2. Global stats
      // Personnes distinctes (user_id) : une même personne membre de N biblios
      // ne compte qu'une fois ; on ne tient compte que des memberships status='active'.
      // Une personne ayant plusieurs rôles compte dans la catégorie la plus haute :
      // staff prime sur reader.
      const { data: activeMembers } = await supabase
        .from('user_library_memberships')
        .select('user_id, role')
        .eq('status', 'active');
      const userTopRole = new Map();
      const roleRank = { reader: 1, librarian: 2, coordenador: 3, administrador: 4 };
      (activeMembers || []).forEach(m => {
        const prev = userTopRole.get(m.user_id) || 0;
        const cur = roleRank[m.role] || 0;
        if (cur > prev) userTopRole.set(m.user_id, cur);
      });
      let distinctReaders = 0, distinctStaff = 0;
      for (const rank of userTopRole.values()) {
        if (rank === 1) distinctReaders += 1;
        else if (rank >= 2) distinctStaff += 1;
      }
      const totals = enriched.reduce((a, l) => ({
        libraries: a.libraries + 1,
        exemplars: a.exemplars + l.exemplars,
        loansOpen: a.loansOpen + l.loansOpen,
        loansOverdue: a.loansOverdue + (l.loansOverdue || 0),
        resActive: a.resActive + l.resActive,
      }), { libraries:0, exemplars:0, loansOpen:0, loansOverdue:0, resActive:0 });
      const [bk, au] = await Promise.all([
        supabase.from('books').select('id', { count:'exact', head:true }),
        supabase.from('authors').select('id', { count:'exact', head:true }),
      ]);
      setGlobalStats({
        ...totals,
        readers: distinctReaders,
        staff: distinctStaff,
        books: bk.count||0,
        authors: au.count||0,
      });

      // 3. Requests
      const { data: reqData } = await supabase.from('library_requests').select('*').order('created_at', { ascending: false });
      setRequests(reqData || []);

      // 4. All members (filtré sur status='active' — exclut pending_removal,
      // removed, inactive, suspended introduits par la spec gouvernance)
      const { data: memData } = await supabase.from('user_library_memberships')
        .select('user_id, role, status, library_id, is_primary, created_at, libraries(name, slug), profiles:user_id(email, first_name, last_name)')
        .eq('status', 'active')
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

  // ATTENTION : changeUserRole fait un UPDATE direct sur user_library_memberships.role
  // ce qui court-circuite les RPCs fn_team_* du Lot 5 (pas d'audit, pas d'event
  // outbox, pas de mail militant aux concerné·es). Conservée temporairement
  // pour l'onglet "admins" qui n'a pas encore migré. À refondre en Phase B
  // de gouvernance avec les RPCs propres.
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
    if (!newAdminEmail.trim()) { setMsg({ text: t({ id: 'rede.admins.emailRequired' }), kind: 'error' }); return; }
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
      <Hero title={t({ id: 'rede.title' })} subtitle={t({ id: 'rede.restricted' })} />
    <Footer /></PageShell>
  );

  const admins = allMembers.filter(m => m.role === 'administrador');
  const filteredReqs = reqFilter ? requests.filter(r => r.request_status === reqFilter) : requests;

  return (
    <PageShell><Topbar />

      <Hero title={t({ id: 'rede.title' })} subtitle={t({ id: 'rede.subtitle' })}>
        <div className="ab-hero__content" style={{ marginTop: 8 }}>
          <span className="cat-pill danger">{t({ id: 'roles.administrador' })}</span>
        </div>
        <div className="ab-hero__actions">
          <button className="cat-btn secondary" onClick={loadAll} disabled={loading}>
            {loading ? t({ id: 'rede.refreshing' }) : t({ id: 'rede.refresh' })}
          </button>
        </div>
      </Hero>

      <div className="catalogacao-wrap" style={{ maxWidth:1200, margin:'0 auto' }}>

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
                        <span className={`cat-pill ${lib.is_active?'ok':'warn'}`} style={{ marginLeft:6, fontSize:'.6rem' }}>{lib.is_active?t({ id: 'rede.libraryActive' }):t({ id: 'rede.libraryInactive' })}</span>
                      </div>
                    </div>
                  </div>
                  <div style={{ display:'flex', gap:6, marginBottom:8, flexWrap:'wrap' }}>
                    <span className={`cat-pill ${lib.service_mode==='funcionamento_normal'?'ok':'warn'}`} style={{ fontSize:'.68rem' }}>{SERVICE_LABELS[lib.service_mode]||lib.service_mode}</span>
                    {lib.allows_new_loans && <span className="cat-pill ok" style={{ fontSize:'.68rem' }}>{t({ id: 'rede.allowsLoans' })}</span>}
                    {lib.allows_new_reservations && <span className="cat-pill ok" style={{ fontSize:'.68rem' }}>{t({ id: 'rede.allowsReservations' })}</span>}
                    {!lib.allows_new_loans && <span className="cat-pill danger" style={{ fontSize:'.68rem' }}>{t({ id: 'rede.noLoans' })}</span>}
                  </div>
                  <div style={{ display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:4, marginBottom:8 }}>
                    {statCell(lib.readers, t({id:'rede.stats.readers'}))}
                    {statCell(lib.staff, t({id:'rede.stats.staff'}))}
                    {statCell(lib.exemplars, t({id:'rede.stats.exemplars'}))}
                    {statCell(lib.loansOpen, t({id:'rede.overview.loansOpenShort'}), lib.loansOpen > 0)}
                  </div>
                  <div style={{ fontSize:'.78rem', color:'var(--brand-muted)' }}>
                    {lib.contact_email && <span>✉ {lib.contact_email}</span>}
                    {lib.created_at && <span style={{ marginLeft:8 }}>{t({ id: 'rede.since' }, { date: new Date(lib.created_at).toLocaleDateString(locale) })}</span>}
                  </div>
                </div>
              );
            })}
          </div>
        </div>)}

        {/* ═══ 2. SOLICITAÇÕES ═════════════════════════ */}
        {tab==='requests' && (<div>
          <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:12 }}>
            <h3 style={{ margin:0 }}>{t({ id: 'rede.requests.label' })} ({requests.length})</h3>
            <select value={reqFilter} onChange={e=>setReqFilter(e.target.value)} style={{...fs, width:'auto'}}>
              <option value="">{t({ id: 'common.all' })}</option>
              {Object.entries(REQ_STATUS).map(([k,v])=><option key={k} value={k}>{v}</option>)}
            </select>
          </div>

          <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:16 }}>
            <div style={lw}>
              {filteredReqs.length===0 && <div style={{ padding:16, fontSize:'.88rem', color:'var(--brand-muted)' }}>{t({id:'common.empty'})}</div>}
              {filteredReqs.map((r,i) => (
                <div key={r.id} style={{...lr(i), cursor:'pointer', background: selectedReq?.id===r.id?'rgba(29,78,216,.12)':lr(i).background}} onClick={()=>{setSelectedReq(r);setReviewNote(r.review_notes||'');}}>
                  <div style={{ flex:1 }}>
                    <div style={{ fontSize:'.9rem', fontWeight:600 }}>{r.library_name || t({ id: 'common.noName' })}</div>
                    <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>{r.city||'—'}{r.state_region&&`, ${r.state_region}`} · {new Date(r.created_at).toLocaleDateString(locale)}</div>
                  </div>
                  <span className={`cat-pill ${r.request_status==='aprovada'?'ok':r.request_status==='recusada'?'danger':r.request_status==='em_analise'?'info':'warn'}`} style={{ fontSize:'.7rem' }}>
                    {REQ_STATUS[r.request_status]||r.request_status}
                  </span>
                </div>
              ))}
            </div>
            <div>
              {!selectedReq && <div style={bx}><p style={{ fontSize:'.88rem', color:'var(--brand-muted)', margin:0 }}>{t({ id: 'rede.requests.selectPrompt' })}</p></div>}
              {selectedReq && (
                <div style={bx}>
                  <h4 style={{ margin:'0 0 10px' }}>{selectedReq.library_name}</h4>
                  <div style={{ fontSize:'.85rem', lineHeight:1.7, marginBottom:12 }}>
                    {[[t({id:'rede.requests.shortName'}),selectedReq.library_short_name],[t({id:'rede.requests.city'}),`${selectedReq.city||'—'}${selectedReq.state_region?`, ${selectedReq.state_region}`:''}${selectedReq.country?` — ${selectedReq.country}`:''}`],
                      [t({id:'rede.requests.email'}),selectedReq.library_email],[t({id:'rede.requests.phone'}),selectedReq.library_phone],[t({id:'rede.requests.address'}),selectedReq.library_address],
                      [t({id:'rede.requests.contactLabel'}),`${selectedReq.contact_name||'—'} (${selectedReq.contact_role||'—'}) · ${selectedReq.contact_email||'—'}`],
                      [t({id:'rede.requests.stage'}),selectedReq.project_stage],[t({id:'rede.requests.firstManager'}),selectedReq.first_manager_intent],
                    ].map(([k,v])=> v && <div key={k}><strong>{k}:</strong> {v}</div>)}
                    {selectedReq.summary && <div style={{ marginTop:6 }}><strong>{t({id:'rede.requests.summary'})}:</strong><br/>{selectedReq.summary}</div>}
                    {selectedReq.needs && <div style={{ marginTop:6 }}><strong>{t({id:'rede.requests.needs'})}:</strong><br/>{selectedReq.needs}</div>}
                    {selectedReq.collection_profile && <div style={{ marginTop:6 }}><strong>{t({id:'rede.requests.collectionProfile'})}:</strong><br/>{selectedReq.collection_profile}</div>}
                    {selectedReq.public_profile && <div style={{ marginTop:6 }}><strong>{t({id:'rede.requests.publicProfile'})}:</strong><br/>{selectedReq.public_profile}</div>}
                  </div>
                  <label style={ls}>{t({ id: 'rede.requests.reviewNote' })}</label>
                  <textarea value={reviewNote} onChange={e=>setReviewNote(e.target.value)} rows={3} style={{...fs,resize:'vertical',marginBottom:10}} placeholder={t({ id: 'rede.requests.reviewPlaceholder' })} />
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
          <h3 style={{ marginBottom:12 }}>{t({ id: 'rede.libraries.panoramaTitle' }, { count: libCards.length })}</h3>
          <div style={lw}>
            <div style={{ display:'grid', gridTemplateColumns:'2.5fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr .8fr', gap:0, padding:'8px 12px', fontSize:'.75rem', fontWeight:700, color:'var(--brand-muted)', borderBottom:'1px solid rgba(255,255,255,.08)' }}>
              <div>{t({ id: 'nav.library' })}</div><div style={{ textAlign:'center' }}>{t({ id: 'rede.th.service' })}</div><div style={{ textAlign:'center' }}>{t({ id: 'rede.stats.readers' })}</div><div style={{ textAlign:'center' }}>{t({ id: 'rede.stats.staff' })}</div><div style={{ textAlign:'center' }}>{t({ id: 'rede.stats.exemplars' })}</div><div style={{ textAlign:'center' }}>{t({ id: 'rede.overview.loansOpenShort' })}</div><div style={{ textAlign:'center' }}>{t({ id: 'rede.overview.loansOverdueShort' })}</div><div style={{ textAlign:'center' }}>{t({ id: 'rede.overview.reservationsActiveShort' })}</div><div style={{ textAlign:'center' }}>{t({ id: 'common.actions' })}</div>
            </div>
            {libCards.map((lib,i) => (
              <div key={lib.id} style={{ display:'grid', gridTemplateColumns:'2.5fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr .8fr', gap:0, padding:'10px 12px', background:i%2===0?'rgba(0,0,0,.08)':'transparent', borderBottom:'1px solid rgba(255,255,255,.04)', alignItems:'center' }}>
                <div>
                  <div style={{ fontSize:'.9rem', fontWeight:600 }}>{lib.name} <span className={`cat-pill ${lib.is_active?'ok':'warn'}`} style={{ fontSize:'.6rem' }}>{lib.is_active?t({ id: 'rede.libraryActive' }):t({ id: 'rede.libraryInactive' })}</span></div>
                  <div style={{ fontSize:'.78rem', color:'var(--brand-muted)' }}>{lib.slug} · {lib.city||'—'} · {lib.contact_email||'—'}</div>
                </div>
                <div style={{ textAlign:'center' }}><span className={`cat-pill ${lib.service_mode==='funcionamento_normal'?'ok':'warn'}`} style={{ fontSize:'.65rem' }}>{SERVICE_LABELS[lib.service_mode]||'—'}</span></div>
                <div style={{ textAlign:'center', fontSize:'.9rem', fontWeight:700 }}>{lib.readers}</div>
                <div style={{ textAlign:'center', fontSize:'.9rem', fontWeight:700 }}>{lib.staff}</div>
                <div style={{ textAlign:'center', fontSize:'.9rem', fontWeight:700 }}>{lib.exemplars}</div>
                <div style={{ textAlign:'center', fontSize:'.9rem', fontWeight:700, color: lib.loansOpen>0?'#fbbf24':'inherit' }}>{lib.loansOpen}</div>
                <div style={{ textAlign:'center', fontSize:'.9rem', fontWeight:700, color: lib.loansOverdue>0?'#f87171':'inherit' }}>{lib.loansOverdue||0}</div>
                <div style={{ textAlign:'center', fontSize:'.9rem', fontWeight:700, color: lib.resActive>0?'#60a5fa':'inherit' }}>{lib.resActive}</div>
                <div style={{ textAlign:'center' }}>
                  <button className="cat-btn ghost" style={{ fontSize:'.75rem', padding:'3px 8px', color: lib.is_active?'#f87171':'#4ade80' }} onClick={()=>toggleLibraryActive(lib.id, lib.is_active)}>
                    {lib.is_active ? t({ id: 'rede.deactivate' }) : t({ id: 'rede.reactivate' })}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>)}

        {/* ═══ 4. MEMBROS DA REDE ═════════════════════ */}
        {/* Phase A 07/05/2026 : remplacement de la liste éditable (qui faisait
            UPDATE direct sur user_library_memberships.role et court-circuitait
            les RPCs gouvernance fn_team_*) par <TeamPanel /> en lecture seule.
            Phase B recâblera les actions sur les RPCs propres. */}
        {tab === 'members' && (
          <div>
            <h3 style={{ marginBottom: 12 }}>{t({ id: 'rede.tab.members' })}</h3>
            <TeamPanel scope="network" />
          </div>
        )}

        {/* ═══ 5. ADMINISTRADORES ═════════════════════ */}
        {/* ═══ 5. ADMINISTRADORES (Phase B2) ══════════════════ */}
        {/* Phase B2 (07/05/2026) : refonte complète de l'onglet admins.
            L'ancien code (addAdmin/removeAdmin via UPDATE direct) est
            remplacé par <AdminsPanel /> qui utilise les RPCs fn_team_*
            (promote_to_administrador, self_demote depuis admin avec
            garde-fou last admin).
            La fonction changeUserRole() reste dans ce fichier mais
            n'est plus appelée nulle part — à supprimer en cleanup futur. */}
        {tab === 'admins' && (
          <AdminsPanel />
        )}

      </div>
    <Footer /></PageShell>
  );
}
