import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Footer } from '@/components/layout';
import '../catalogacao/CatalogacaoPage.css';

const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
const SERVICE_MODES = [
  { value: 'funcionamento_normal', label: 'Funcionamento normal' },
  { value: 'funcionamento_reduzido', label: 'Funcionamento reduzido' },
  { value: 'recesso', label: 'Em recesso' },
  { value: 'suspenso', label: 'Suspenso temporariamente' },
];
// ILL_STATUS built inside component with t()
// TASK_STATUS built inside component with t()
const TASK_PRIO = { alta:'Alta', normal:'Normal', baixa:'Baixa' };

// NOTIFICATION_FLAGS keys — labels resolved via t() inside the component
const NOTIFICATION_FLAG_KEYS = [
  'reservation_created', 'reservation_status', 'reservation_workflow', 'local_consultation',
  'loan_lifecycle', 'loan_reminders', 'loan_overdue', 'mid_loan_message',
  'profile_restriction', 'reading_recommendations',
  'admin_copy_reservations', 'admin_copy_loans', 'tech_alerts', 'task_alerts',
];

export default function BibliotecaPage() {
  const { user } = useAuth();
  const { libraryId, libraryName, role } = useLibrary();
  const { formatMessage: t } = useIntl();
  const roleLoaded = role !== null && role !== undefined;
  const isCoord = role === 'coordenador' || role === 'administrador';
  const isLibrarian = role === 'librarian' || isCoord;

  // FIX BUG #2: TASK_STATUS was referenced but never defined, causing ReferenceError
  // when calling generateReportText(). Built here via useMemo to localize labels.
  const TASK_STATUS = useMemo(() => ({
    pendente: t({ id: 'task.status.pendente' }),
    em_andamento: t({ id: 'task.status.em_andamento' }),
    concluida: t({ id: 'task.status.concluida' }),
    cancelada: t({ id: 'task.status.cancelada' }),
  }), [t]);

  const ALL_TABS = [
    { id: 'identity', label: t({ id: 'biblioteca.tab.identity' }), coordOnly: true },
    { id: 'comms', label: t({ id: 'biblioteca.tab.comms' }), coordOnly: true },
    { id: 'regulation', label: t({ id: 'biblioteca.tab.regulation' }), coordOnly: true },
    { id: 'documents', label: t({ id: 'biblioteca.tab.documents' }), coordOnly: true },
    { id: 'team', label: t({ id: 'biblioteca.tab.team' }) },
    { id: 'exchanges', label: t({ id: 'biblioteca.tab.exchanges' }), separator: true },
    { id: 'ill', label: t({ id: 'biblioteca.tab.ill' }) },
    { id: 'reports', label: t({ id: 'biblioteca.tab.reports' }) },
    { id: 'tasks', label: t({ id: 'biblioteca.tab.tasks' }) },
  ];
  // FIX BUG #4: rename loop variable to avoid shadowing `t` (formatMessage)
  const visibleTabs = ALL_TABS.filter(tb => !tb.coordOnly || isCoord);

  const [tab, setTab] = useState(isCoord ? 'identity' : 'team');
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [saving, setSaving] = useState(false);
  const regFileRef = useRef(null);

  // ── Dados ───────────────────────────────────────────────
  const [lib, setLib] = useState(null);
  const [commons, setCommons] = useState(null);
  const [serviceState, setServiceState] = useState(null);
  const [regDocs, setRegDocs] = useState([]);
  const [policySet, setPolicySet] = useState(null);
  const [policyRules, setPolicyRules] = useState([]);
  const [docGov, setDocGov] = useState(null);
  const [partners, setPartners] = useState([]);
  const [members, setMembers] = useState([]);
  const [illLoans, setIllLoans] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [stats, setStats] = useState({ books:0, authors:0, exemplars:0, readers:0, loansOpen:0 });
  const [mailChannel, setMailChannel] = useState(null);
  const [notifPolicy, setNotifPolicy] = useState(null);
  const [newTask, setNewTask] = useState({ title: '', description: '', priority: 'normal', owner: '' });
  const [allLibraries, setAllLibraries] = useState([]);
  const [illForm, setIllForm] = useState({ lender:'', borrower:'', status:'preparacao', contactName:'', contactEmail:'', startDate:'', dueDate:'', logisticsNote:'', meetingPoint:'' });
  const [illItems, setIllItems] = useState([]);
  const [illDocSearch, setIllDocSearch] = useState('');
  const [illDocResults, setIllDocResults] = useState([]);

  // ── Carregamento ────────────────────────────────────────
  const loadAll = useCallback(async () => {
    if (!libraryId) return;
    try {
      const [libR, commR, ssR, regR, psR, dgR, partR, memR, illR, taskR, mcR, npR] = await Promise.all([
        supabase.from('libraries').select('*').eq('id', libraryId).single(),
        supabase.from('library_commons').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_service_state').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_regulation_documents').select('*').eq('library_id', libraryId).order('created_at', { ascending: false }),
        supabase.from('library_circulation_policy_sets').select('*').eq('library_id', libraryId).eq('is_active', true).maybeSingle(),
        supabase.from('library_document_governance').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('catalog_partners').select('*').order('display_name'),
        supabase.from('user_library_memberships').select('*, profiles:user_id(email, first_name, last_name)').eq('library_id', libraryId).order('created_at'),
        supabase.from('interlibrary_loans_v2').select('*').or(`lender_library_id.eq.${libraryId},borrower_library_id.eq.${libraryId}`).order('created_at', { ascending: false }).limit(50),
        supabase.from('painel_internal_tasks').select('*').eq('library_id', libraryId).order('created_at', { ascending: false }).limit(50),
        supabase.from('library_mail_channels').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_notification_policies').select('*').eq('library_id', libraryId).maybeSingle(),
      ]);
      setLib(libR.data); setCommons(commR.data); setServiceState(ssR.data);
      setRegDocs(regR.data || []); setPolicySet(psR.data); setDocGov(dgR.data);
      setPartners(partR.data || []); setMembers(memR.data || []);
      setIllLoans(illR.data || []); setTasks(taskR.data || []);
      setMailChannel(mcR.data); setNotifPolicy(npR.data);
      // Load all libraries for ILL selects
      const { data: allLibs } = await supabase.from('libraries').select('id, slug, name, short_name').order('name');
      setAllLibraries(allLibs || []);
      if (psR.data?.id) {
        const { data: rules } = await supabase.from('library_circulation_policy_rules').select('*').eq('policy_set_id', psR.data.id).order('priority');
        setPolicyRules(rules || []);
      }
      const [bk, au, ex, rd, lo] = await Promise.all([
        supabase.from('books').select('id', { count: 'exact', head: true }),
        supabase.from('authors').select('id', { count: 'exact', head: true }),
        supabase.from('exemplares').select('id', { count: 'exact', head: true }).eq('library_id', libraryId),
        supabase.from('user_library_memberships').select('id', { count: 'exact', head: true }).eq('library_id', libraryId).eq('role', 'reader'),
        supabase.from('emprestimos_v2_items').select('id', { count: 'exact', head: true }).eq('item_status', 'aberto'),
      ]);
      setStats({ books:bk.count||0, authors:au.count||0, exemplars:ex.count||0, readers:rd.count||0, loansOpen:lo.count||0 });
    } catch (err) { console.warn('loadAll:', err); }
  }, [libraryId]);

  useEffect(() => { loadAll(); }, [loadAll]);

  // ── Save helpers ────────────────────────────────────────
  function setL(k,v){ setLib(p=>p?{...p,[k]:v}:p); }
  function setC(k,v){ setCommons(p=>p?{...p,[k]:v}:p); }
  function setSS(k,v){ setServiceState(p=>p?{...p,[k]:v}:p); }
  function setMC(k,v){ setMailChannel(p=>p?{...p,[k]:v}:p); }
  function setNP(k,v){ setNotifPolicy(p=>p?{...p,[k]:v}:p); }

  async function saveTable(table, data, filterCol = 'library_id') {
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.from(table).update(data).eq(filterCol, libraryId);
      if (error) throw error;
      setMsg({ text: 'Dados salvos com sucesso.', kind: 'ok' });
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function saveIdentity() {
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      await supabase.from('libraries').update({ name:lib.name, short_name:lib.short_name, city:lib.city, state:lib.state, country:lib.country }).eq('id', libraryId);
      if (commons) await supabase.from('library_commons').update({ display_name:commons.display_name, contact_email:commons.contact_email, reply_to_email:commons.reply_to_email, postal_address:commons.postal_address }).eq('library_id', libraryId);
      if (serviceState) await supabase.from('library_service_state').update({ service_mode:serviceState.service_mode, allows_new_loans:serviceState.allows_new_loans, allows_new_reservations:serviceState.allows_new_reservations, public_message:serviceState.public_message }).eq('library_id', libraryId);
      setMsg({ text: 'Dados salvos com sucesso.', kind: 'ok' });
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function saveComms() {
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      if (commons) await supabase.from('library_commons').update({ display_name:commons.display_name, contact_email:commons.contact_email, reply_to_email:commons.reply_to_email, email_delivery_mode:commons.email_delivery_mode }).eq('library_id', libraryId);
      if (mailChannel) await supabase.from('library_mail_channels').update({ admin_notification_email:mailChannel.admin_notification_email, weekly_report_email:mailChannel.weekly_report_email, severe_alert_email:mailChannel.severe_alert_email, delivery_mode:mailChannel.delivery_mode }).eq('library_id', libraryId);
      if (notifPolicy) {
        const flags = {}; NOTIFICATION_FLAG_KEYS.forEach(k => { flags[k + '_enabled'] = notifPolicy[k + '_enabled'] || false; });
        await supabase.from('library_notification_policies').update({ ...flags, updated_by: user?.id }).eq('library_id', libraryId);
      }
      setMsg({ text: t({ id: 'biblioteca.comms.savedOk' }), kind: 'ok' });
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  // ── Upload regimento ────────────────────────────────────
  async function uploadRegimento() {
    const file = regFileRef.current?.files?.[0];
    if (!file) { setMsg({ text: 'Selecione um arquivo PDF.', kind: 'error' }); return; }
    setSaving(true); setMsg({ text: t({id:'biblioteca.regulation.sending'}), kind: 'info' });
    try {
      const slug = lib?.slug || 'library';
      const path = `regimentos/${slug}/${Date.now()}-${file.name.replace(/[^a-zA-Z0-9._-]/g, '_')}`;
      const { error: upErr } = await supabase.storage.from('library-regimentos-public').upload(path, file, { upsert: true });
      if (upErr) throw upErr;
      // FIX A.1 BUG #6: deactivate any existing active regimento before
      // inserting the new one. There's a unique constraint
      // uq_library_regulation_documents_one_active_per_kind that allows only
      // one active document per kind per library.
      await supabase.from('library_regulation_documents')
        .update({ is_active: false })
        .eq('library_id', libraryId)
        .eq('doc_kind', 'regimento')
        .eq('is_active', true);
      // FIX BUG #3: 'publicado' is rejected by CHECK constraint; valid values are
      // 'draft_only', 'published', 'archived'. Was breaking the upload silently.
      const { error: insErr } = await supabase.from('library_regulation_documents').insert({
        library_id: libraryId, doc_kind: 'regimento', publication_status: 'published',
        is_active: true, storage_bucket: 'library-regimentos-public', storage_path_public: path,
        version_label: `Regimento ${new Date().toLocaleDateString('pt-BR')}`,
        created_by: user?.id,
      });
      if (insErr) throw insErr;
      setMsg({ text: 'Regimento enviado e publicado.', kind: 'ok' });
      regFileRef.current.value = '';
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  // ── Create task ─────────────────────────────────────────
  async function createTask() {
    if (!newTask.title.trim()) { setMsg({ text: t({ id: 'biblioteca.tasks.titleRequired' }), kind: 'error' }); return; }
    try {
      // FIX BUG #4: rename loop variable to avoid shadowing `t` (formatMessage)
      const tags = (newTask.tagsText || '').split(',').map(tag => tag.trim()).filter(Boolean);
      // FIX A.1 BUG #7: tags column is NOT NULL with default '{}'. Sending null
      // violates the constraint. Build payload conditionally so the DB applies
      // its default when no tags are provided.
      const insertPayload = {
        library_id: libraryId, title: newTask.title.trim(), description: newTask.description.trim() || null,
        priority: newTask.priority || 'normal', owner: newTask.owner.trim() || null,
        due_date: newTask.dueDate || null,
        status: 'pendente', created_by: user?.id,
      };
      if (tags.length > 0) insertPayload.tags = tags;
      const { error } = await supabase.from('painel_internal_tasks').insert(insertPayload);
      if (error) throw error;
      setNewTask({ title: '', description: '', priority: 'normal', owner: '', dueDate: '', tagsText: '' });
      setMsg({ text: 'Tarefa criada.', kind: 'ok' });
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
  }

  async function updateTaskStatus(taskId, status) {
    await supabase.from('painel_internal_tasks').update({ status, updated_by: user?.id }).eq('id', taskId);
    await loadAll();
  }

  // ── ILL: search documents for item adding ───────────────
  async function searchIllDocs() {
    if (!illDocSearch.trim()) return;
    const { data } = await supabase.from('books').select('id, titulo, autor, bib_ref').or(`titulo.ilike.%${illDocSearch.trim()}%,autor.ilike.%${illDocSearch.trim()}%,bib_ref.ilike.%${illDocSearch.trim()}%`).limit(10);
    setIllDocResults(data || []);
  }

  function addIllItem(book) {
    if (illItems.find(it => it.book_id === book.id)) return;
    setIllItems(prev => [...prev, { book_id: book.id, titulo: book.titulo, autor: book.autor, bib_ref: book.bib_ref }]);
  }

  function removeIllItem(bookId) { setIllItems(prev => prev.filter(it => it.book_id !== bookId)); }

  async function saveIll() {
    if (!illForm.lender || !illForm.borrower) { setMsg({ text: t({id:'biblioteca.ill.selectBoth'}), kind: 'error' }); return; }
    if (illForm.lender === illForm.borrower) { setMsg({ text: 'As bibliotecas emprestadora e tomadora devem ser diferentes.', kind: 'error' }); return; }
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      const { data: loan, error } = await supabase.from('interlibrary_loans_v2').insert({
        lender_library_id: illForm.lender, borrower_library_id: illForm.borrower, initiated_by_library_id: libraryId,
        status_global: illForm.status || 'preparacao', coordination_contact_name: illForm.contactName || null,
        coordination_contact_email: illForm.contactEmail || null, start_date: illForm.startDate || null,
        due_date: illForm.dueDate || null, notes: illForm.logisticsNote || null, meeting_point: illForm.meetingPoint || null,
        logistics_mode: 'a_combinar', created_by: user?.id,
      }).select().single();
      if (error) throw error;
      // Insert items
      if (illItems.length > 0 && loan) {
        const rows = illItems.map((it, i) => ({
          interlibrary_loan_id: loan.id, book_id: it.book_id, line_no: i + 1,
          titulo_cache: it.titulo, autor_cache: it.autor, bib_ref: it.bib_ref, item_status: 'reservado',
        }));
        await supabase.from('interlibrary_loan_items_v2').insert(rows);
      }
      setMsg({ text: `Empréstimo interbibliotecas #${loan.id} criado com ${illItems.length} item(ns).`, kind: 'ok' });
      setIllForm({ lender:'', borrower:'', status:'preparacao', contactName:'', contactEmail:'', startDate:'', dueDate:'', logisticsNote:'', meetingPoint:'' });
      setIllItems([]); setIllDocSearch(''); setIllDocResults([]);
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function updateIllStatus(loanId, newStatus) {
    await supabase.from('interlibrary_loans_v2').update({ status_global: newStatus, updated_by: user?.id }).eq('id', loanId);
    await loadAll();
  }

  async function deleteIll(loanId) {
    if (!confirm(`Descartar o empréstimo interbibliotecas #${loanId}? Esta ação é irreversível.`)) return;
    try {
      await supabase.from('interlibrary_loan_items_v2').delete().eq('interlibrary_loan_id', loanId);
      await supabase.from('interlibrary_loans_v2').delete().eq('id', loanId);
      setMsg({ text: `Empréstimo #${loanId} descartado.`, kind: 'ok' });
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
  }

  // ── Generate report text ────────────────────────────────
  function generateReportText() {
    const now = new Date().toLocaleDateString('pt-BR');
    const libName = lib?.name || libraryName;
    const lines = [
      `RELATÓRIO — ${libName}`, `Data: ${now}`, '',
      `Documentos no catálogo: ${stats.books}`, `Autoridades: ${stats.authors}`,
      `Exemplares locais: ${stats.exemplars}`, `Leitores inscritos: ${stats.readers}`,
      `Empréstimos em curso: ${stats.loansOpen}`,
      `Bibliotecários: ${members.filter(m => m.role === 'librarian').length}`, '',
      'EQUIPE:', ...members.map(m => {
        const p = m.profiles || {};
        return `  ${[p.first_name, p.last_name].filter(Boolean).join(' ') || p.email || '—'} — ${m.role === 'librarian' ? 'Bibliotecário(a)' : m.role === 'reader' ? 'Leitor(a)' : m.role}`;
      }), '',
      // FIX BUG #2 + #4: TASK_STATUS now defined; loop variable renamed to `tk`
      'TAREFAS INTERNAS:', ...(tasks.length ? tasks.map(tk => `  [${TASK_STATUS[tk.status] || tk.status}] ${tk.title} (${TASK_PRIO[tk.priority] || tk.priority})${tk.owner ? ` — ${tk.owner}` : ''}`) : ['  Nenhuma tarefa registrada.']),
    ];
    return lines.join('\n');
  }

  async function sendReport() {
    const email = commons?.contact_email;
    if (!email) { setMsg({ text: 'Nenhum e-mail de contato configurado para esta biblioteca.', kind: 'error' }); return; }
    const text = generateReportText();
    // Use mailto as fallback — a proper email send would use notify-event
    const subject = encodeURIComponent(`Relatório — ${lib?.name || libraryName} — ${new Date().toLocaleDateString('pt-BR')}`);
    const body = encodeURIComponent(text);
    window.open(`mailto:${email}?subject=${subject}&body=${body}`, '_blank');
    setMsg({ text: `E-mail de relatório preparado para ${email}. Verifique seu cliente de e-mail.`, kind: 'ok' });
  }

  // ── Task invite ─────────────────────────────────────────
  async function inviteToTask(taskId, email) {
    if (!email?.trim()) return;
    try {
      await supabase.from('painel_internal_task_invites').insert({
        task_id: taskId, library_id: libraryId, invite_email: email.trim(),
        invite_status: 'pendente', created_by: user?.id,
      });
      setMsg({ text: `Convite enviado para ${email.trim()}.`, kind: 'ok' });
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
  }

  // ── UI constants ────────────────────────────────────────
  async function saveRule() {
    if (!editingRule) return;
    setSaving(true);
    try {
      const { error } = await supabase.from('library_circulation_policy_rules').update({
        loan_days: editingRule.loan_days, renewal_days: editingRule.renewal_days,
        renewal_max_count: editingRule.renewal_max_count, quantity_max: editingRule.quantity_max,
        loan_allowed: editingRule.loan_allowed, renewable: editingRule.renewable,
        public_note: editingRule.public_note,
      }).eq('id', editingRule.id);
      if (error) throw error;
      setPolicyRules(prev => prev.map(r => r.id === editingRule.id ? editingRule : r));
      setEditingRule(null);
      setMsg({ text: t({id:'biblioteca.rules.saved'}), kind: 'ok' });
    } catch (e) { setMsg({ text: e.message, kind: 'error' }); }
    finally { setSaving(false); }
  }
  const fs = { width:'100%', padding:'10px 12px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', fontSize:'.9rem' };
  const ls = { display:'block', fontSize:'.85rem', fontWeight:600, marginBottom:3, color:'var(--brand-muted, #ccc)' };
  const bx = { padding:14, borderRadius:10, background:'rgba(255,255,255,.03)', border:'1px solid rgba(255,255,255,.08)', marginBottom:16 };
  const lr = (i) => ({ padding:'10px 12px', background:i%2===0?'rgba(0,0,0,.08)':'transparent', borderBottom:'1px solid rgba(255,255,255,.04)', display:'flex', justifyContent:'space-between', alignItems:'center', gap:8 });
  const lw = { border:'1px solid rgba(255,255,255,.06)', borderRadius:8, overflow:'hidden' };
  const logoUrl = commons?.logo_file_key ? `${PROJECT_URL}/storage/v1/object/public/library-ui-assets/${commons.logo_file_key.includes('/')?commons.logo_file_key:`themes/${commons.logo_file_key}/logo-${commons.logo_file_key}.png`}` : null;

  if (!libraryId) return (
    <PageShell><Topbar />
      <div className="catalogacao-wrap" style={{ maxWidth:800, margin:'0 auto', textAlign:'center', padding:'60px 24px' }}>
        <h1>{t({ id: 'biblioteca.title' })}</h1>
        <p style={{ color:'var(--brand-muted)', marginTop:12 }}>{t({ id: 'biblioteca.noLibrary' })}</p>
        <div style={{ marginTop:20, display:'flex', gap:10, justifyContent:'center' }}>
          <Link to="/painel"><button className="cat-btn primary">{t({ id: 'nav.panel' })}</button></Link>
          <Link to="/solicitar-biblioteca"><button className="cat-btn secondary">{t({ id: 'biblioteca.requestLibrary' })}</button></Link>
        </div>
      </div>
    <Footer /></PageShell>
  );

  if (!roleLoaded) return (
    <PageShell><Topbar />
      <div style={{ textAlign: 'center', padding: 60, color: 'var(--brand-muted)' }}>Carregando…</div>
    <Footer /></PageShell>
  );

  if (!isLibrarian) return (
    <PageShell><Topbar />
      <div className="catalogacao-wrap" style={{ maxWidth:800, margin:'0 auto', textAlign:'center', padding:'60px 24px' }}>
        <h1>{t({ id: 'biblioteca.title' })}</h1>
        <p style={{ color:'var(--brand-muted)', marginTop:12 }}>{t({ id: 'biblioteca.restricted' })}</p>
        <Link to="/painel"><button className="cat-btn primary" style={{ marginTop:16 }}>{t({ id: 'common.back' })}</button></Link>
      </div>
    <Footer /></PageShell>
  );

  return (
    <PageShell><Topbar />
      <div className="catalogacao-wrap" style={{ maxWidth:1100, margin:'0 auto' }}>

        <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:16, flexWrap:'wrap', gap:12 }}>
          <div style={{ display:'flex', gap:14, alignItems:'center' }}>
            {logoUrl && <img src={logoUrl} alt={libraryName} style={{ height:56, objectFit:'contain', filter:'drop-shadow(0 4px 12px rgba(0,0,0,.4))' }} />}
            <div><h1 style={{ margin:0 }}>{t({ id: 'biblioteca.title' })}</h1><p style={{ color:'var(--brand-muted)', fontSize:'.9rem', margin:'2px 0 0' }}>{lib?.name||libraryName}
              <span className={`cat-pill ${isCoord?'ok':'info'}`} style={{ marginLeft:8, fontSize:'.65rem' }}>{t({ id: isCoord ? 'roles.coordenador' : 'roles.librarian' })}</span>
            </p></div>
          </div>
          <div style={{ display:'flex', gap:8, flexWrap:'wrap' }}>
            <Link to="/painel" style={{ textDecoration:'none' }}><button className="cat-btn secondary">{t({ id: 'nav.panel' })}</button></Link>
            <Link to="/catalogacao" style={{ textDecoration:'none' }}><button className="cat-btn secondary">{t({ id: 'nav.catalogacao' })}</button></Link>
            <Link to="/importacoes" style={{ textDecoration:'none' }}><button className="cat-btn secondary">{t({ id: 'nav.importacoes' })}</button></Link>
          </div>
        </div>

        <div className="cat-statusbar" style={{ marginBottom:16 }}>
          {[[t({id:'catalog.stats.documents'}),stats.books],[t({id:'catalog.stats.authorities'}),stats.authors],[t({id:'catalog.stats.exemplars'}),stats.exemplars],[t({id:'catalog.stats.readers'}),stats.readers],[t({id:'catalog.stats.loans'}),stats.loansOpen]].map(([l,v])=>
            <div key={l} className="cat-stat"><span className="cat-stat-label">{l}</span><span className="cat-stat-value">{v}</span></div>
          )}
        </div>

        {msg.text && <div style={{ padding:'10px 14px', borderRadius:8, fontSize:'.9rem', marginBottom:14, background:msg.kind==='ok'?'rgba(21,128,61,.12)':msg.kind==='info'?'rgba(29,78,216,.1)':'rgba(220,38,38,.12)', color:msg.kind==='ok'?'#4ade80':msg.kind==='info'?'#60a5fa':'#f87171' }}>{msg.text}</div>}

        <div className="cat-tabs" style={{ marginBottom:18 }}>
          {/* FIX BUG #4: rename loop variable to avoid shadowing `t` */}
          {visibleTabs.map(tb => <button key={tb.id} className={`cat-tab-btn${tab===tb.id?' active':''}${tb.separator?' tab-separator':''}`} onClick={()=>setTab(tb.id)}>{tb.label}</button>)}
        </div>

        {/* ═══ 1. Identidade ═══════════════════════════ */}
        {tab==='identity' && lib && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.identity.title' })}</h3>
          <div className="cat-book-grid" style={{ marginBottom:16 }}>
            <div className="cat-field" style={{ gridColumn:'span 2' }}><label style={ls}>{t({ id: 'biblioteca.identity.name' })}</label><input type="text" value={lib.name||''} onChange={e=>setL('name',e.target.value)} style={fs} /></div>
            <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.shortName' })}</label><input type="text" value={lib.short_name||''} onChange={e=>setL('short_name',e.target.value)} style={fs} /></div>
            <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.city' })}</label><input type="text" value={lib.city||''} onChange={e=>setL('city',e.target.value)} style={fs} /></div>
            <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.state' })}</label><input type="text" value={lib.state||''} onChange={e=>setL('state',e.target.value)} style={fs} /></div>
            <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.country' })}</label><input type="text" value={lib.country||''} onChange={e=>setL('country',e.target.value)} style={fs} /></div>
          </div>
          {commons && <div className="cat-book-grid" style={{ marginBottom:16 }}>
            <div className="cat-field" style={{ gridColumn:'span 2' }}><label style={ls}>{t({ id: 'biblioteca.comms.displayName' })}</label><input type="text" value={commons.display_name||''} onChange={e=>setC('display_name',e.target.value)} style={fs} /></div>
            <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.contactEmail' })}</label><input type="email" value={commons.contact_email||''} onChange={e=>setC('contact_email',e.target.value)} style={fs} /></div>
            <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.replyEmail' })}</label><input type="email" value={commons.reply_to_email||''} onChange={e=>setC('reply_to_email',e.target.value)} style={fs} /></div>
            <div className="cat-field" style={{ gridColumn:'span 2' }}><label style={ls}>{t({ id: 'biblioteca.identity.postalAddress' })}</label><input type="text" value={commons.postal_address||''} onChange={e=>setC('postal_address',e.target.value)} style={fs} /></div>
          </div>}
          {serviceState && <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.identity.serviceState' })}</h4>
            <div className="cat-book-grid">
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.serviceMode' })}</label><select value={serviceState.service_mode||''} onChange={e=>setSS('service_mode',e.target.value)} style={fs}>{SERVICE_MODES.map(m=><option key={m.value} value={m.value}>{m.label}</option>)}</select></div>
              <div className="cat-field"><label style={{...ls,display:'flex',gap:8,alignItems:'center'}}><input type="checkbox" checked={serviceState.allows_new_loans||false} onChange={e=>setSS('allows_new_loans',e.target.checked)} /> Aceita novos empréstimos</label></div>
              <div className="cat-field"><label style={{...ls,display:'flex',gap:8,alignItems:'center'}}><input type="checkbox" checked={serviceState.allows_new_reservations||false} onChange={e=>setSS('allows_new_reservations',e.target.checked)} /> Aceita novas reservas</label></div>
              <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={ls}>{t({ id: 'biblioteca.identity.publicMessage' })}</label><textarea value={serviceState.public_message||''} onChange={e=>setSS('public_message',e.target.value)} rows={2} style={{...fs,resize:'vertical'}} placeholder="Mensagem exibida publicamente…" /></div>
            </div>
          </div>}
          <button className="cat-btn primary" onClick={saveIdentity} disabled={saving}>{saving?t({id:'common.saving'}):t({id:'biblioteca.identity.save'})}</button>
        </div>)}

        {/* ═══ 2. Comunicações ══════════════════════════ */}
        {tab==='comms' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.comms.title' })}</h3>
          {commons && <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.comms.emailIdentity' })}</h4>
            <div className="cat-book-grid">
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.displayName' })}</label><input type="text" value={commons.display_name||''} onChange={e=>setC('display_name',e.target.value)} style={fs} /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.sendEmail' })}</label><input type="email" value={commons.contact_email||''} onChange={e=>setC('contact_email',e.target.value)} style={fs} /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.replyEmail' })}</label><input type="email" value={commons.reply_to_email||''} onChange={e=>setC('reply_to_email',e.target.value)} style={fs} /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.sendMode' })}</label>
                <select value={commons.email_delivery_mode||'normal'} onChange={e=>setC('email_delivery_mode',e.target.value)} style={fs}>
                  <option value="normal">{t({ id: 'biblioteca.tasks.priority.normal' })}</option><option value="test_only">Somente teste</option><option value="disabled">Desativado</option>
                </select>
              </div>
            </div>
          </div>}
          {mailChannel && <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.comms.adminRecipients' })}</h4>
            <div className="cat-book-grid">
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.adminEmail' })}</label><input type="email" value={mailChannel.admin_notification_email||''} onChange={e=>setMC('admin_notification_email',e.target.value)} style={fs} placeholder="admin@biblioteca.org" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.weeklyEmail' })}</label><input type="email" value={mailChannel.weekly_report_email||''} onChange={e=>setMC('weekly_report_email',e.target.value)} style={fs} placeholder="equipe@biblioteca.org" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.alertEmail' })}</label><input type="email" value={mailChannel.severe_alert_email||''} onChange={e=>setMC('severe_alert_email',e.target.value)} style={fs} placeholder="urgente@biblioteca.org" /></div>
            </div>
          </div>}
          {notifPolicy && <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.comms.notifTypes' })}</h4>
            <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:6 }}>
              {NOTIFICATION_FLAG_KEYS.map(k => (
                <label key={k} style={{ display:'flex', gap:8, alignItems:'center', fontSize:'.88rem', cursor:'pointer', padding:'4px 0' }}>
                  <input type="checkbox" checked={notifPolicy[k+'_enabled']||false} onChange={e=>setNP(k+'_enabled',e.target.checked)} />
                  {t({ id: `notif.type.${k}`, defaultMessage: k.replace(/_/g, ' ') })}
                </label>
              ))}
            </div>
          </div>}
          <button className="cat-btn primary" onClick={saveComms} disabled={saving}>{saving?t({id:'common.saving'}):t({id:'biblioteca.comms.save'})}</button>
        </div>)}

        {/* ═══ 3. Regimento e circulação ════════════════ */}
        {tab==='regulation' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.regulation.title' })}</h3>
          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.regulation.docs' })}</h4>
            {regDocs.map(doc => (
              <div key={doc.id} style={{ padding:'8px 10px', borderRadius:6, background:'rgba(0,0,0,.15)', marginBottom:6, display:'flex', justifyContent:'space-between', alignItems:'center' }}>
                <div>
                  <div style={{ fontSize:'.9rem', fontWeight:600 }}>{doc.version_label||`Regimento #${doc.id}`}</div>
                  <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>{doc.doc_kind||'—'} · {doc.publication_status||'—'}{doc.is_active && <span className="cat-pill ok" style={{ marginLeft:6, fontSize:'.65rem' }}>Ativo</span>}</div>
                </div>
                {doc.storage_path_public && <a href={`${PROJECT_URL}/storage/v1/object/public/${doc.storage_bucket||'library-regimentos-public'}/${doc.storage_path_public}`} target="_blank" rel="noopener" className="cat-btn secondary" style={{ fontSize:'.82rem', padding:'5px 12px' }}>{t({ id: 'biblioteca.regulation.openPdf' })}</a>}
              </div>
            ))}
            <div style={{ marginTop:12, display:'flex', gap:8, alignItems:'center', flexWrap:'wrap' }}>
              <label style={{ display:'inline-block', padding:'8px 16px', borderRadius:8, background:'var(--brand-panel-bg)', border:'1px solid rgba(255,255,255,.15)', cursor:'pointer', fontSize:'.88rem', fontWeight:600 }}>
                Escolher PDF
                <input type="file" accept=".pdf,application/pdf" ref={regFileRef} style={{ display:'none' }} />
              </label>
              <button className="cat-btn primary" onClick={uploadRegimento} disabled={saving} style={{ fontSize:'.88rem' }}>{saving?'Enviando…':'Enviar novo regimento'}</button>
            </div>
          </div>
          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.regulation.rules' })}</h4>
            {!policySet && <div style={{ fontSize:'.88rem', color:'var(--brand-muted)' }}>{t({ id: 'biblioteca.regulation.noRules' })}</div>}
            {policySet && <div style={{ marginBottom:10, fontSize:'.88rem' }}><strong>{policySet.label||'Regras'}</strong>{policySet.scope_note && ` — ${policySet.scope_note}`}</div>}
{policyRules.length>0 && <div style={lw}>{policyRules.map((r,i)=>(
              <div key={r.id} style={{ padding:'10px 12px', background:i%2===0?'rgba(0,0,0,.08)':'transparent', borderBottom:'1px solid rgba(255,255,255,.04)' }}>
                {editingRule?.id===r.id ? (
                  <div className="cat-book-grid" style={{ gap:8 }}>
                    <div className="cat-field" style={{ gridColumn:'span 3' }}><strong style={{ fontSize:'.9rem' }}>{r.rule_label||`Regra #${r.id}`}</strong></div>
                    <div className="cat-field"><label style={ls}>{t({id:'biblioteca.rules.loanDays'})}</label><input type="number" value={editingRule.loan_days||''} onChange={e=>setEditingRule(p=>({...p,loan_days:Number(e.target.value)||null}))} style={fs} /></div>
                    <div className="cat-field"><label style={ls}>{t({id:'biblioteca.rules.renewalDays'})}</label><input type="number" value={editingRule.renewal_days||''} onChange={e=>setEditingRule(p=>({...p,renewal_days:Number(e.target.value)||null}))} style={fs} /></div>
                    <div className="cat-field"><label style={ls}>{t({id:'biblioteca.rules.renewalMax'})}</label><input type="number" value={editingRule.renewal_max_count||''} onChange={e=>setEditingRule(p=>({...p,renewal_max_count:Number(e.target.value)||null}))} style={fs} /></div>
                    <div className="cat-field"><label style={ls}>{t({id:'biblioteca.rules.maxItems'})}</label><input type="number" value={editingRule.quantity_max||''} onChange={e=>setEditingRule(p=>({...p,quantity_max:Number(e.target.value)||null}))} style={fs} /></div>
                    <div className="cat-field"><label style={{...ls,display:'flex',gap:6,alignItems:'center'}}><input type="checkbox" checked={editingRule.loan_allowed||false} onChange={e=>setEditingRule(p=>({...p,loan_allowed:e.target.checked}))} />{t({id:'biblioteca.rules.loanAllowed'})}</label></div>
                    <div className="cat-field"><label style={{...ls,display:'flex',gap:6,alignItems:'center'}}><input type="checkbox" checked={editingRule.renewable||false} onChange={e=>setEditingRule(p=>({...p,renewable:e.target.checked}))} />{t({id:'biblioteca.rules.renewable'})}</label></div>
                    <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={ls}>{t({id:'biblioteca.rules.publicNote'})}</label><input type="text" value={editingRule.public_note||''} onChange={e=>setEditingRule(p=>({...p,public_note:e.target.value}))} style={fs} /></div>
                    <div className="cat-field" style={{ gridColumn:'span 3', display:'flex', gap:8 }}>
                      <button className="cat-btn primary" onClick={saveRule} disabled={saving} style={{ fontSize:'.85rem' }}>{t({id:'biblioteca.rules.save'})}</button>
                      <button className="cat-btn secondary" onClick={()=>setEditingRule(null)} style={{ fontSize:'.85rem' }}>{t({id:'biblioteca.rules.cancel'})}</button>
                    </div>
                  </div>
                ) : (
                  <div style={{ display:'flex', justifyContent:'space-between', alignItems:'flex-start', gap:8 }}>
                    <div style={{ flex:1 }}>
                      <div style={{ fontSize:'.9rem', fontWeight:600 }}>{r.rule_label||`Regra #${r.id}`}</div>
                      <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                        {r.loan_allowed ? t({id:'biblioteca.regulation.loanAllowed'},{days:r.loan_days}) : t({id:'biblioteca.regulation.loanNotAllowed'})}
                        {r.renewable&&` · Renovável (${r.renewal_days}d, ${r.renewal_max_count}x)`}
                        {r.reservation_allowed&&' · Reserva'}{r.consultation_only&&' · Consulta'}
                        {r.public_note&&` · ${r.public_note}`}
                      </div>
                    </div>
                    <button className="cat-btn secondary" onClick={()=>setEditingRule({...r})} style={{ fontSize:'.78rem', padding:'4px 10px' }}>{t({id:'biblioteca.rules.edit'})}</button>
                  </div>
                )}
              </div>
            ))}</div>}
          </div>
        </div>)}

        {/* ═══ 4. Documentos e relações externas ═══════ */}
        {tab==='documents' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.documents.title' })}</h3>
          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.documents.partners' })}</h4>
            {partners.length===0 && <div style={{ fontSize:'.88rem', color:'var(--brand-muted)' }}>{t({ id: 'biblioteca.documents.noPartners' })}</div>}
            {partners.length>0 && <div style={lw}>{partners.map((p,i)=>(
              <div key={p.id} style={lr(i)}>
                <div><div style={{ fontSize:'.9rem', fontWeight:600 }}>{p.display_name||p.slug}</div><div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>{p.software_family||'—'} · {p.country_code||'—'}</div></div>
                <span className={`cat-pill ${p.is_active?'ok':'warn'}`} style={{ fontSize:'.7rem' }}>{p.is_active?'Ativa':'Inativa'}</span>
              </div>
            ))}</div>}
          </div>
        </div>)}

        {/* ═══ 5. Equipe ═══════════════════════════════ */}
        {tab==='team' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.team.title' })}</h3>
          <div style={lw}>
            {members.length===0 && <div style={{ padding:16, fontSize:'.88rem', color:'var(--brand-muted)' }}>{t({ id: 'biblioteca.team.noMembers' })}</div>}
            {members.map((m,i)=>{const p=m.profiles||{};return(
              <div key={m.user_id||i} style={lr(i)}>
                <div><div style={{ fontSize:'.9rem', fontWeight:600 }}>{[p.first_name,p.last_name].filter(Boolean).join(' ')||p.email||'(sem nome)'}</div><div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>{p.email||'—'}</div></div>
                <span className={`cat-pill ${m.role==='librarian'?'ok':m.role==='admin'?'info':'warn'}`} style={{ fontSize:'.7rem' }}>{t({id:'roles.'+m.role,defaultMessage:m.role})||'—'}</span>
              </div>
            );})}
          </div>
        </div>)}

        {/* ═══ 6. Trocas interbibliotecas ══════════════ */}
        {tab==='exchanges' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.exchanges.title' })}</h3>
          <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:14 }}>Propostas de troca definitiva de documentos entre bibliotecas da rede. Escolha documentos trocáveis, gere a proposta e acompanhe a resposta.</div>
          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.exchanges.prepare' })}</h4>
            <div className="cat-book-grid" style={{ marginBottom:10 }}>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.exchanges.partner' })}</label>
                <select style={fs}><option value="">{t({ id: 'biblioteca.exchanges.selectPartner' })}</option>{allLibraries.filter(l=>l.id!==libraryId).map(l=><option key={l.id} value={l.id}>{l.name} ({l.short_name})</option>)}</select>
              </div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.exchanges.localDoc' })}</label><input type="text" style={fs} placeholder="Buscar documento local para propor troca…" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.exchanges.wantedDoc' })}</label><input type="text" style={fs} placeholder="Buscar documento desejado…" /></div>
            </div>
            <div className="cat-book-grid" style={{ marginBottom:10 }}>
              <div className="cat-field" style={{ gridColumn:'span 2' }}><label style={ls}>{t({ id: 'biblioteca.exchanges.message' })}</label><textarea style={{...fs,resize:'vertical'}} rows={3} placeholder="A proposta fica registrada e pode abrir um e-mail pronto para envio ao contato responsável." /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.exchanges.note' })}</label><textarea style={{...fs,resize:'vertical'}} rows={3} placeholder="Ex.: exemplares em bom estado, troca no próximo plantão…" /></div>
            </div>
            <div style={{ display:'flex', gap:8 }}>
              <button className="cat-btn primary" style={{ fontSize:'.88rem' }} disabled>{t({ id: 'biblioteca.exchanges.register' })}</button>
              <button className="cat-btn secondary" style={{ fontSize:'.88rem' }} disabled>{t({ id: 'biblioteca.exchanges.openEmail' })}</button>
            </div>
            <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginTop:10, fontStyle:'italic' }}>As trocas interbibliotecas ainda estão em fase de implantação na rede. O formulário está pronto, mas o registro depende da criação da tabela de trocas no backend.</div>
          </div>
        </div>)}

        {/* ═══ 7. Empréstimos interbibliotecas ═════════ */}
        {tab==='ill' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.ill.title' })}</h3>
          <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:14 }}>Preparação e acompanhamento de empréstimos temporários entre bibliotecas, separados das trocas.</div>

          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.ill.prepare' })}</h4>
            <div className="cat-book-grid" style={{ marginBottom:10 }}>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.lender' })}</label>
                <select value={illForm.lender} onChange={e=>setIllForm(p=>({...p,lender:e.target.value}))} style={fs}>
                  <option value="">{t({ id: 'biblioteca.ill.select' })}</option>{allLibraries.map(l=><option key={l.id} value={l.id}>{l.name} ({l.short_name})</option>)}
                </select>
              </div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.borrower' })}</label>
                <select value={illForm.borrower} onChange={e=>setIllForm(p=>({...p,borrower:e.target.value}))} style={fs}>
                  <option value="">{t({ id: 'biblioteca.ill.select' })}</option>{allLibraries.map(l=><option key={l.id} value={l.id}>{l.name} ({l.short_name})</option>)}
                </select>
              </div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.status' })}</label>
                <select value={illForm.status} onChange={e=>setIllForm(p=>({...p,status:e.target.value}))} style={fs}>
                  <option value="preparacao">{t({ id: 'ill.status.preparacao' })}</option><option value="aguardando_saida">{t({ id: 'ill.status.aguardando_saida' })}</option>
                  <option value="emprestado">{t({ id: 'ill.status.emprestado' })}</option><option value="em_devolucao">{t({ id: 'ill.status.em_devolucao' })}</option>
                  <option value="devolvido">{t({ id: 'ill.status.devolvido' })}</option><option value="cancelado">{t({ id: 'ill.status.cancelado' })}</option>
                </select>
              </div>
            </div>

            <div style={{ ...bx, background:'rgba(0,0,0,.1)', marginBottom:12 }}>
              <h4 style={{ margin:'0 0 8px', fontSize:'.95rem' }}>{t({ id: 'biblioteca.ill.items' })}</h4>
              <div style={{ display:'flex', gap:8, marginBottom:8 }}>
                <input type="text" value={illDocSearch} onChange={e=>setIllDocSearch(e.target.value)} onKeyDown={e=>e.key==='Enter'&&searchIllDocs()} placeholder="Buscar documento por título, autor ou ref…" style={{...fs,flex:1}} />
                <button className="cat-btn secondary" onClick={searchIllDocs} style={{ fontSize:'.85rem', padding:'7px 14px', flexShrink:0 }}>{t({ id: 'common.search' })}</button>
              </div>
              {illDocResults.length>0 && <div style={{...lw,marginBottom:8,maxHeight:150,overflowY:'auto'}}>{illDocResults.map((d,i)=>(
                <div key={d.id} style={{...lr(i),cursor:'pointer'}} onClick={()=>addIllItem(d)}>
                  <div style={{ fontSize:'.88rem' }}><strong>{d.titulo}</strong> — {d.autor||'—'} · ref: {d.bib_ref||'—'}</div>
                  <button className="cat-btn secondary" style={{ fontSize:'.78rem', padding:'3px 8px' }} onClick={e=>{e.stopPropagation();addIllItem(d);}}>{t({ id: 'common.add' })}</button>
                </div>
              ))}</div>}
              {illItems.length===0 && <div style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>Nenhum exemplar incluído. Busque um documento acima e clique para adicionar.</div>}
              {illItems.length>0 && <div style={lw}>{illItems.map((it,i)=>(
                <div key={it.book_id} style={lr(i)}>
                  <div style={{ fontSize:'.88rem' }}><strong>{it.titulo}</strong> — {it.autor||'—'}</div>
                  <button className="cat-btn ghost" style={{ fontSize:'.78rem', padding:'3px 8px', color:'#f87171' }} onClick={()=>removeIllItem(it.book_id)}>{t({ id: 'common.remove' })}</button>
                </div>
              ))}</div>}
            </div>

            <div className="cat-book-grid" style={{ marginBottom:10 }}>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.contact' })}</label><input type="text" value={illForm.contactName} onChange={e=>setIllForm(p=>({...p,contactName:e.target.value}))} style={fs} placeholder="Nome da pessoa de referência" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.contactEmail' })}</label><input type="email" value={illForm.contactEmail} onChange={e=>setIllForm(p=>({...p,contactEmail:e.target.value}))} style={fs} placeholder="contato@biblioteca.org" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.meetingPoint' })}</label><input type="text" value={illForm.meetingPoint} onChange={e=>setIllForm(p=>({...p,meetingPoint:e.target.value}))} style={fs} placeholder="Retirada no plantão, envio postal…" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.startDate' })}</label><input type="date" value={illForm.startDate} onChange={e=>setIllForm(p=>({...p,startDate:e.target.value}))} style={fs} /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.dueDate' })}</label><input type="date" value={illForm.dueDate} onChange={e=>setIllForm(p=>({...p,dueDate:e.target.value}))} style={fs} /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.notes' })}</label><textarea value={illForm.logisticsNote} onChange={e=>setIllForm(p=>({...p,logisticsNote:e.target.value}))} rows={2} style={{...fs,resize:'vertical'}} placeholder="Embalagem, transporte, condições…" /></div>
            </div>
            <div style={{ display:'flex', gap:8 }}>
              <button className="cat-btn primary" onClick={saveIll} disabled={saving} style={{ fontSize:'.9rem' }}>{saving?t({id:'common.saving'}):t({id:'biblioteca.ill.save'})}</button>
              <button className="cat-btn ghost" onClick={()=>{setIllForm({lender:'',borrower:'',status:'preparacao',contactName:'',contactEmail:'',startDate:'',dueDate:'',logisticsNote:'',meetingPoint:''});setIllItems([]);}} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.ill.clear' })}</button>
            </div>
          </div>

          {/* Liste des empréstimos existants */}
          {illLoans.length>0 && (<div style={{ marginTop:16 }}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.ill.existing' })}</h4>
            <div style={lw}>{illLoans.map((loan,i)=>{
              const isLender = loan.lender_library_id===libraryId;
              const lenderLib = allLibraries.find(l=>l.id===loan.lender_library_id);
              const borrowerLib = allLibraries.find(l=>l.id===loan.borrower_library_id);
              return(<div key={loan.id} style={lr(i)}>
                <div style={{ flex:1 }}>
                  <div style={{ fontSize:'.9rem', fontWeight:600 }}>#{loan.id} — {isLender?'Emprestadora':'Tomadora'}</div>
                  <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                    {lenderLib?.short_name||'—'} → {borrowerLib?.short_name||'—'}
                    {loan.start_date&&` · saída: ${loan.start_date}`}{loan.due_date&&` · retorno: ${loan.due_date}`}
                    {loan.meeting_point&&` · ${loan.meeting_point}`}
                  </div>
                </div>
                <select value={loan.status_global||''} onChange={e=>updateIllStatus(loan.id,e.target.value)} style={{ fontSize:'.82rem', padding:'4px 8px', borderRadius:6, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4' }}>
                  <option value="preparacao">{t({ id: 'ill.status.preparacao' })}</option><option value="aguardando_saida">{t({ id: 'ill.status.aguardando_saida' })}</option>
                  <option value="emprestado">{t({ id: 'ill.status.emprestado' })}</option><option value="em_devolucao">{t({ id: 'ill.status.em_devolucao' })}</option>
                  <option value="devolvido">{t({ id: 'ill.status.devolvido' })}</option><option value="cancelado">{t({ id: 'ill.status.cancelado' })}</option>
                </select>
                <button className="cat-btn ghost" style={{ fontSize:'.78rem', padding:'4px 8px', color:'#f87171' }} onClick={()=>deleteIll(loan.id)}>{t({ id: 'common.discard' })}</button>
              </div>);
            })}</div>
          </div>)}
        </div>)}

        {/* ═══ 8. Relatórios e resumos ═════════════════ */}
        {tab==='reports' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.reports.title' })}</h3>
          <div style={bx}>
            <div className="cat-book-grid">
              {[{v:stats.books,l:t({id:'catalog.stats.documents'})},{v:stats.authors,l:t({id:'catalog.stats.authorities'})},{v:stats.exemplars,l:t({id:'catalog.stats.exemplars'})},{v:stats.readers,l:t({id:'catalog.stats.readers'})},{v:stats.loansOpen,l:t({id:'catalog.stats.loans'})},{v:members.filter(m=>m.role==='librarian').length,l:t({id:'catalog.stats.librarians'})}].map((s,i)=>(
                <div key={i} style={{ padding:14, borderRadius:8, background:'rgba(0,0,0,.15)', textAlign:'center' }}>
                  <div style={{ fontSize:'1.5rem', fontWeight:800 }}>{s.v}</div><div style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>{s.l}</div>
                </div>
              ))}
            </div>
          </div>

          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.reports.generate' })}</h4>
            <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:10 }}>
              Gera um resumo com indicadores, equipe e tarefas internas da biblioteca. O relatório pode ser copiado, salvo como texto ou enviado por e-mail.
            </div>
            <textarea value={generateReportText()} readOnly rows={12} style={{...fs, fontFamily:'monospace', fontSize:'.82rem', resize:'vertical', marginBottom:10}} />
            <div style={{ display:'flex', gap:8, flexWrap:'wrap' }}>
              <button className="cat-btn primary" onClick={()=>{ navigator.clipboard?.writeText(generateReportText()); setMsg({text:'Relatório copiado para a área de transferência.',kind:'ok'}); }} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.reports.copy' })}</button>
              <button className="cat-btn secondary" onClick={sendReport} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.reports.sendEmail' })}</button>
              <span style={{ fontSize:'.82rem', color:'var(--brand-muted)', alignSelf:'center' }}>Destinatário: {commons?.contact_email || '(não configurado)'}</span>
            </div>
          </div>
        </div>)}

        {/* ═══ 9. Tarefas internas ════════════════════ */}
        {tab==='tasks' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.tasks.title' })}</h3>
          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.tasks.new' })}</h4>
            <div className="cat-book-grid" style={{ marginBottom:10 }}>
              <div className="cat-field" style={{ gridColumn:'span 2' }}><label style={ls}>{t({ id: 'biblioteca.tasks.titleField' })}</label><input type="text" value={newTask.title} onChange={e=>setNewTask(p=>({...p,title:e.target.value}))} style={fs} placeholder="Ex.: Verificar exemplares do setor 2" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.priority' })}</label><select value={newTask.priority} onChange={e=>setNewTask(p=>({...p,priority:e.target.value}))} style={fs}><option value="baixa">{t({ id: 'biblioteca.tasks.priority.low' })}</option><option value="normal">{t({ id: 'biblioteca.tasks.priority.normal' })}</option><option value="alta">{t({ id: 'biblioteca.tasks.priority.high' })}</option></select></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.owner' })}</label><input type="text" value={newTask.owner} onChange={e=>setNewTask(p=>({...p,owner:e.target.value}))} style={fs} placeholder="Nome" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.dueDate' })}</label><input type="date" value={newTask.dueDate||''} onChange={e=>setNewTask(p=>({...p,dueDate:e.target.value}))} style={fs} /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.tags' })}</label><input type="text" value={newTask.tagsText||''} onChange={e=>setNewTask(p=>({...p,tagsText:e.target.value}))} style={fs} placeholder="catalogação, urgente, setor 2" /></div>
              <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={ls}>{t({ id: 'biblioteca.tasks.description' })}</label><textarea value={newTask.description} onChange={e=>setNewTask(p=>({...p,description:e.target.value}))} rows={2} style={{...fs,resize:'vertical'}} placeholder="Detalhes da tarefa…" /></div>
            </div>
            <button className="cat-btn primary" onClick={createTask} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.tasks.create' })}</button>
          </div>
          {/* FIX BUG #4: rename loop variable to avoid shadowing `t` (formatMessage) */}
          {tasks.length>0 && <div style={lw}>{tasks.map((tk,i)=>(
            <div key={tk.id} style={{ ...lr(i), flexDirection:'column', alignItems:'stretch', gap:6 }}>
              <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', gap:8 }}>
                <div style={{ flex:1 }}>
                  <div style={{ fontSize:'.9rem', fontWeight:600 }}>{tk.title||'(sem título)'}</div>
                  <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                    {tk.owner||'—'}{tk.due_date&&` · prazo: ${tk.due_date}`}
                    {tk.tags?.length>0&&` · ${tk.tags.join(', ')}`}
                  </div>
                  {tk.description && <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginTop:2 }}>{tk.description}</div>}
                </div>
                <div style={{ display:'flex', gap:4, flexShrink:0, alignItems:'center' }}>
                  <span className={`cat-pill ${tk.priority==='alta'?'danger':tk.priority==='baixa'?'info':'warn'}`} style={{ fontSize:'.65rem' }}>{TASK_PRIO[tk.priority]||tk.priority}</span>
                  <select value={tk.status} onChange={e=>updateTaskStatus(tk.id,e.target.value)} style={{ fontSize:'.82rem', padding:'4px 8px', borderRadius:6, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4' }}>
                    <option value="pendente">{t({ id: 'task.status.pendente' })}</option><option value="em_andamento">{t({ id: 'task.status.em_andamento' })}</option><option value="concluida">{t({ id: 'task.status.concluida' })}</option><option value="cancelada">{t({ id: 'task.status.cancelada' })}</option>
                  </select>
                  <button className="cat-btn ghost" style={{ fontSize:'.78rem', padding:'4px 8px', color:'#f87171' }} onClick={async()=>{if(!confirm('Descartar esta tarefa?'))return;await supabase.from('painel_internal_tasks').delete().eq('id',tk.id);await loadAll();}}>{t({ id: 'common.discard' })}</button>
                </div>
              </div>
              {/* Invite row */}
              <div style={{ display:'flex', gap:6, alignItems:'center' }}>
                <input type="email" placeholder="E-mail do(a) camarada a convidar…" style={{...fs, flex:1, padding:'6px 10px', fontSize:'.82rem'}}
                  onKeyDown={async e=>{if(e.key==='Enter'&&e.target.value.trim()){await inviteToTask(tk.id,e.target.value);e.target.value='';}}} />
                <button className="cat-btn secondary" style={{ fontSize:'.78rem', padding:'4px 10px', flexShrink:0 }}
                  onClick={async e=>{const inp=e.target.previousElementSibling;if(inp?.value?.trim()){await inviteToTask(tk.id,inp.value);inp.value='';}}}>{t({ id: 'biblioteca.tasks.invite' })}</button>
              </div>
            </div>
          ))}</div>}
        </div>)}

      </div>
    <Footer /></PageShell>
  );
}
