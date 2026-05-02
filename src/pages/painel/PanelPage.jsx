import { useState, useEffect, useCallback, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { supabase, apiQuery, notifyEvent } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, Spinner, EmptyState } from '@/components/ui';
import './PanelPage.css';

// ═══════════════════════════════════════════════════════════
// Workflow labels and stage lists are built inside the component using t()
function fmtD(d) { if (!d) return '—'; try { return new Date(d).toLocaleString(undefined, { dateStyle: 'short', timeStyle: 'short' }); } catch { return d; } }

// ═══════════════════════════════════════════════════════════

export default function PanelPage() {
  const { user } = useAuth();
  const { libraryId, libraryName, role } = useLibrary();
  const { formatMessage: t } = useIntl();
  const roleLoaded = role !== null && role !== undefined;
  const isLibrarian = role === 'librarian' || role === 'coordenador' || role === 'administrador';
  const isCoordOrAdmin = role === 'coordenador' || role === 'administrador';

  // i18n-aware workflow labels
  const WORKFLOW_LABELS = useMemo(() => ({
    solicitada: t({ id: 'reservation.stage.solicitada' }), em_preparacao: t({ id: 'reservation.stage.em_preparacao' }),
    pronta_para_retirada: t({ id: 'reservation.stage.pronta_para_retirada' }),
    retirada_a_combinar: t({ id: 'reservation.stage.pronta_para_retirada' }),
    retirada_agendada: t({ id: 'reservation.stage.retirada_agendada' }),
    're-retirada_agendada': t({ id: 'reservation.stage.retirada_agendada' }),
    nao_retirada: t({ id: 'reservation.stage.nao_retirada' }),
    liberada_para_circulacao: t({ id: 'reservation.stage.liberada_para_circulacao' }),
    retirada_efetivada: t({ id: 'reservation.stage.retirada_efetivada' }),
    cancelada_leitor: t({ id: 'reservation.stage.cancelada_leitor' }),
    cancelada_biblioteca: t({ id: 'reservation.stage.cancelada_biblioteca' }),
    expirada: t({ id: 'reservation.stage.expirada' }),
  }), [t]);
  const CONSULT_WORKFLOW = useMemo(() => ({
    solicitada: t({ id: 'reservation.stage.solicitada' }), em_preparacao: t({ id: 'reservation.stage.em_preparacao' }),
    consulta_agendada: t({ id: 'panel.workflow.scheduled' }), consulta_realizada: t({ id: 'panel.workflow.done' }),
    nao_compareceu: t({ id: 'panel.workflow.noShow' }),
    cancelada_leitor: t({ id: 'reservation.stage.cancelada_leitor' }),
    cancelada_biblioteca: t({ id: 'reservation.stage.cancelada_biblioteca' }),
    expirada: t({ id: 'panel.workflow.expired' }),
  }), [t]);
  const RES_STAGES = useMemo(() => [
    { value: 'em_preparacao', label: '1. ' + t({ id: 'reservation.stage.em_preparacao' }) },
    { value: 'pronta_para_retirada', label: '2. ' + t({ id: 'reservation.stage.pronta_para_retirada' }) },
    { value: 'retirada_a_combinar', label: '3. ' + t({ id: 'reservation.stage.pronta_para_retirada' }) },
    { value: 'retirada_agendada', label: '4. ' + t({ id: 'reservation.stage.retirada_agendada' }) },
    { value: 're-retirada_agendada', label: '4b. ' + t({ id: 'reservation.stage.retirada_agendada' }) },
    { value: 'nao_retirada', label: '5. ' + t({ id: 'reservation.stage.nao_retirada' }) },
    { value: 'liberada_para_circulacao', label: '6. ' + t({ id: 'reservation.stage.liberada_para_circulacao' }) },
  ], [t]);
  const [tab, setTab] = useState('trabalho-do-dia');
  const [loading, setLoading] = useState(true);
  const [reservations, setReservations] = useState([]);
  const [consultations, setConsultations] = useState([]);
  const [loans, setLoans] = useState([]);
  const [internalTasks, setInternalTasks] = useState([]);
  const [selectedRes, setSelectedRes] = useState(new Set());
  const [resStage, setResStage] = useState('');
  const [resNote, setResNote] = useState('');
  const [resSchedule, setResSchedule] = useState('');
  const [actionMsg, setActionMsg] = useState('');

  // Ações
  const [borrowerLookup, setBorrowerLookup] = useState('');
  const [loanRefs, setLoanRefs] = useState('');
  const [loanMsg, setLoanMsg] = useState('');
  const [returnId, setReturnId] = useState('');
  const [returnSubIds, setReturnSubIds] = useState('');
  const [returnMsg, setReturnMsg] = useState('');

  // Gerir leitor
  const [readerLookup, setReaderLookup] = useState('');
  const [readerProfile, setReaderProfile] = useState(null);
  const [readerMsg, setReaderMsg] = useState('');
  const [restrictReason, setRestrictReason] = useState('');

  // Cotisation (coordenador/administrador uniquement)
  const [membershipEnabled, setMembershipEnabled] = useState(false);
  const [membershipRules, setMembershipRules] = useState([]);
  const [membershipOverview, setMembershipOverview] = useState([]);
  const [membershipFilter, setMembershipFilter] = useState('all'); // all, up_to_date, expired, never_paid
  const [readerPayments, setReaderPayments] = useState([]);
  const [paymentModal, setPaymentModal] = useState(null); // null ou { user_id, display_name, ... }
  const [paymentDraft, setPaymentDraft] = useState(null);
  const [paymentMsg, setPaymentMsg] = useState('');
  const [paymentSaving, setPaymentSaving] = useState(false);

  // ── Load ──────────────────────────────────────────────

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [resR, conR, loanR] = await Promise.all([
        apiQuery('reserva_itens_followup_ui'),
        apiQuery('consulta_itens_followup_ui'),
        apiQuery('emprestimo_itens_painel_ui'),
      ]);
      setReservations(resR.data || []);
      setConsultations(conR.data || []);
      setLoans(loanR.data || []);
      // Load internal tasks
      if (libraryId) {
        const { data: tasksData } = await supabase.from('painel_internal_tasks').select('*').eq('library_id', libraryId).in('status', ['pendente', 'em_andamento']).order('priority').order('due_date').limit(50);
        setInternalTasks(tasksData || []);
      }
    } catch (e) { console.error('Painel load error:', e); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { loadData(); }, [loadData]);

  // ── Reservation workflow ──────────────────────────────

  async function applyResWorkflow() {
    if (!resStage) { setActionMsg(t({id:'panel.action.selectStep'})); return; }
    const items = [...selectedRes];
    if (!items.length) { setActionMsg(t({id:'panel.action.selectAtLeastOne'})); return; }
    setActionMsg(t({id:'panel.action.applying'}));
    try {
      for (const key of items) {
        const [rid, lno] = key.split('-').map(Number);
        await supabase.rpc('fn_v2_set_reserva_linhas_workflow', {
          p_reserva_id: rid, p_line_nos: [lno], p_workflow_stage: resStage,
          p_workflow_note: resNote || null,
          p_pickup_scheduled_for: resSchedule || null,
        });
      }
      setActionMsg(t({id:'panel.action.stepApplied'},{count:items.length}));
      // Notifier chaque réservation affectée
      for (const key of items) {
        const [rid] = key.split('-').map(Number);
        notifyEvent(resStage, rid, { line_nos: [Number(key.split('-')[1])] });
      }
      setSelectedRes(new Set());
      loadData();
    } catch (e) { setActionMsg(t({id:'common.errorPrefix'},{message:e.message})); }
  }

  async function cancelSelectedRes() {
    const items = [...selectedRes];
    if (!items.length) { setActionMsg(t({id:'panel.action.selectAtLeastOne'})); return; }
    setActionMsg(t({id:'panel.action.cancelling'}));
    try {
      for (const key of items) {
        const [rid, lno] = key.split('-').map(Number);
        await supabase.rpc('fn_v2_cancel_reserva_linhas_as_biblioteca', {
          p_reserva_id: rid, p_line_nos: [lno], p_notes: resNote || null,
        });
      }
      setActionMsg(t({id:'panel.action.reservationsCancelled'},{count:items.length}));
      for (const key of items) {
        const [rid] = key.split('-').map(Number);
        notifyEvent('reserva_cancelada_biblioteca', rid);
      }
      setSelectedRes(new Set());
      loadData();
    } catch (e) { setActionMsg(t({id:'common.errorPrefix'},{message:e.message})); }
  }

  async function confirmSelectedPickup() {
    const items = [...selectedRes];
    if (!items.length) { setActionMsg(t({id:'panel.action.selectAtLeastOne'})); return; }
    setActionMsg(t({id:'panel.action.confirmingPickup'}));
    try {
      for (const key of items) {
        const [rid, lno] = key.split('-').map(Number);
        await supabase.rpc('fn_v2_convert_reserva_linhas_to_emprestimo', {
          p_reserva_id: rid, p_line_nos: [lno],
        });
      }
      setActionMsg(t({id:'panel.action.pickupConfirmed'},{count:items.length}));
      for (const key of items) {
        const [rid] = key.split('-').map(Number);
        notifyEvent('reserva_convertida_em_emprestimo', rid);
      }
      setSelectedRes(new Set());
      loadData();
    } catch (e) { setActionMsg(t({id:'common.errorPrefix'},{message:e.message})); }
  }

  // ── Ações: saída e devolução ──────────────────────────

  async function registrarSaida() {
    const refs = loanRefs.split(/[,;\s]+/).map(r => r.trim()).filter(Boolean);
    if (!borrowerLookup.trim() || !refs.length) { setLoanMsg(t({ id: 'panel.loan.errorMissing' })); return; }
    setLoanMsg(t({id:'panel.loan.resolving'}));
    try {
      // Resolve borrower
      const lookupRes = await supabase.rpc('fn_painel_find_profile_by_lookup', { p_lookup: borrowerLookup.trim() });
      if (lookupRes.error) throw lookupRes.error;
      const borrower = Array.isArray(lookupRes.data) ? lookupRes.data[0] : lookupRes.data;
      if (!borrower?.id) { setLoanMsg(t({ id: 'panel.loan.readerNotFound' })); return; }

      // Resolve holdings
      const resolveRes = await supabase.rpc('fn_v2_resolve_catalog_refs_for_current_user', { p_refs: refs });
      if (resolveRes.error) throw resolveRes.error;
      const holdingIds = (resolveRes.data || []).filter(r => r.matched && Number(r.session_holding_id) > 0).map(r => Number(r.session_holding_id));
      if (!holdingIds.length) { setLoanMsg(t({ id: 'panel.loan.noValidRefs' })); return; }

      setLoanMsg(t({id:'panel.loan.registering'}));
      const { error } = await supabase.rpc('fn_v2_create_emprestimo_by_holdings', {
        p_user_id: borrower.id, p_holding_ids: holdingIds,
      });
      if (error) throw error;
      setLoanMsg(`Saída registrada: ${refs.length} livro(s) para ${borrower.first_name || borrower.email}.`);
      // Le record_id retourné par la RPC est l'emprestimo_id — on ne l'a pas ici,
      // mais on peut utiliser un reload + notify asynchrone via les données rechargées
      // Pour l'instant on notifie avec un ID fictif que le backend résoudra
      notifyEvent('emprestimo_v2_criado', 0, { user_id: borrower.id, holding_ids: holdingIds });
      setBorrowerLookup(''); setLoanRefs('');
      loadData();
    } catch (e) { setLoanMsg(t({id:'common.errorPrefix'},{message:e.message})); }
  }

  async function registrarDevolucaoTotal() {
    const id = parseInt(returnId);
    if (!id) { setReturnMsg(t({id:'panel.loan.enterLoanId'})); return; }
    setReturnMsg(t({id:'panel.loan.returning'}));
    try {
      const { error } = await supabase.rpc('fn_v2_return_emprestimo_total', { p_emprestimo_id: id });
      if (error) throw error;
      setReturnMsg(t({id:'panel.return.totalRegistered'},{id}));
      notifyEvent('emprestimo_v2_devolvido', id);
      setReturnId('');
      loadData();
    } catch (e) { setReturnMsg(t({id:'common.errorPrefix'},{message:e.message})); }
  }

  async function registrarDevolucaoParcial() {
    const subIds = returnSubIds.split(/[,;\s]+/).map(s => s.trim()).filter(Boolean);
    if (!subIds.length) { setReturnMsg(t({id:'panel.loan.enterSubIds'})); return; }
    setReturnMsg(t({id:'panel.loan.returning'}));
    try {
      for (const subId of subIds) {
        const [empId, lineNo] = subId.split('.').map(Number);
        if (!empId || !lineNo) continue;
        await supabase.rpc('fn_v2_return_emprestimo_itens', {
          p_emprestimo_id: empId, p_line_nos: [lineNo],
        });
      }
      setReturnMsg(t({id:'panel.return.partialRegistered'},{ids:subIds.join(', ')}));
      setReturnSubIds('');
      loadData();
    } catch (e) { setReturnMsg(t({id:'common.errorPrefix'},{message:e.message})); }
  }

  // ── Empréstimo actions ─────────────────────────────────

  async function extendLoan(empId) {
    try {
      const { error } = await supabase.rpc('fn_v2_extend_emprestimo_once', { p_emprestimo_id: empId });
      if (error) throw error;
      loadData();
    } catch (e) { alert(`Erro ao prorrogar: ${e.message}`); }
  }

  async function returnLoanItem(empId, lineNos) {
    try {
      const { error } = await supabase.rpc('fn_v2_return_emprestimo_linhas', {
        p_emprestimo_id: empId, p_line_nos: lineNos,
      });
      if (error) throw error;
      loadData();
    } catch (e) { alert(t({id:'common.errorPrefix'},{message:e.message})); }
  }

  // ── Consultation workflow ─────────────────────────────

  async function setConsultaWorkflow(consultaId, lineNo, stage, note) {
    try {
      const { error } = await supabase.rpc('fn_v2_set_consulta_linhas_workflow', {
        p_consulta_id: consultaId, p_line_nos: [lineNo],
        p_workflow_stage: stage, p_workflow_note: note || null,
      });
      if (error) throw error;
      loadData();
    } catch (e) { alert(t({id:'common.errorPrefix'},{message:e.message})); }
  }

  // ── Task builder for trabalho do dia ──────────────────

  function buildDailyTasks() {
    const tasks = [];
    const today = new Date().toISOString().slice(0, 10);

    activeRes.forEach(r => {
      const stage = r.workflow_stage_effective || '';
      const pickupDay = r.pickup_scheduled_for ? new Date(r.pickup_scheduled_for).toISOString().slice(0, 10) : '';

      if (['retirada_agendada', 're-retirada_agendada'].includes(stage) && pickupDay === today) {
        tasks.push({ priority: 'alta', bucket: 'hoje', kind: stage === 're-retirada_agendada' ? t({id:'panel.task.rescheduledToday'}) : t({id:'panel.task.scheduledToday'}), label: `${r.user_name || r.user_email || '?'} · ${r.titulo}`, detail: t({id:'panel.task.detail.pickup'}) + ': ' + fmtD(r.pickup_scheduled_for), actionType: 'reserva', reserva_id: r.reserva_id });
      }
      if (stage === 'solicitada') {
        tasks.push({ priority: 'media', bucket: 'atencao', kind: t({id:'panel.task.newReservation'}), label: `${r.user_name || r.user_email || '?'} · ${r.titulo}`, detail: `${t({id:'panel.task.detail.ref'})}: ${r.bib_ref} · ${t({id:'panel.task.detail.created'})}: ${fmtD(r.reserva_created_at)}`, actionType: 'reserva', reserva_id: r.reserva_id });
      }
      if (stage === 'pronta_para_retirada') {
        tasks.push({ priority: 'media', bucket: 'atencao', kind: t({id:'panel.task.readyForPickup'}), label: `${r.user_name || r.user_email || '?'} · ${r.titulo}`, detail: `${t({id:'panel.task.detail.validity'})}: ${fmtD(r.expires_at)}`, actionType: 'reserva', reserva_id: r.reserva_id });
      }
      if (String(r.pickup_reply_status || '') === 'recusado_leitor') {
        tasks.push({ priority: 'alta', bucket: 'atencao', kind: t({id:'panel.task.readerRefused'}), label: `${r.user_name || r.user_email || '?'} · ${r.titulo}`, detail: r.pickup_reply_note || t({id:'panel.task.detail.reschedule'}), actionType: 'reserva', reserva_id: r.reserva_id });
      }
      if (stage === 'nao_retirada') {
        tasks.push({ priority: 'alta', bucket: 'atencao', kind: t({id:'panel.task.notPickedUp'}), label: `${r.user_name || r.user_email || '?'} · ${r.titulo}`, detail: r.workflow_note || t({id:'panel.task.detail.check'}), actionType: 'reserva', reserva_id: r.reserva_id });
      }
    });

    overdueLoans.forEach(l => {
      const effectiveDue = l.extended_until || l.due_at;
      const due = effectiveDue ? new Date(effectiveDue) : null;
      const diff = due ? Math.ceil((new Date() - due) / 86400000) : 0;
      tasks.push({ priority: 'alta', bucket: 'atencao', kind: t({id:'panel.task.overdueItem'}), label: `${l.user_name || l.user_email || '?'} · ${l.titulo}`, detail: t({id:'panel.task.detail.deadline'}) + ': ' + fmtD(effectiveDue) + ' · ' + t({id:'panel.task.detail.daysOverdue'},{days:diff}) + ' · ' + l.sub_id, actionType: 'emprestimo', emprestimo_id: l.emprestimo_id });
    });

    activeLoans.filter(l => {
      const effectiveDue = l.extended_until || l.due_at;
      return effectiveDue && new Date(effectiveDue).toISOString().slice(0, 10) === today;
    }).forEach(l => {
      const effectiveDue = l.extended_until || l.due_at;
      tasks.push({ priority: 'media', bucket: 'hoje', kind: t({id:'panel.task.dueTodayItem'}), label: `${l.user_name || l.user_email || '?'} · ${l.titulo}`, detail: `${t({id:'panel.task.detail.deadline'})}: ${fmtD(effectiveDue)} · ${l.sub_id}`, actionType: 'emprestimo', emprestimo_id: l.emprestimo_id });
    });

    consultations.filter(c => c.workflow_stage_effective === 'solicitada').forEach(c => {
      tasks.push({ priority: 'media', bucket: 'atencao', kind: t({id:'panel.task.consultToProcess'}), label: `${c.user_name || c.user_email || '?'} · ${c.titulo}`, detail: `${t({id:'panel.task.detail.ref'})}: ${c.bib_ref}`, actionType: 'consulta', consulta_id: c.consulta_id });
    });

    // Internal tasks from biblioteca
    internalTasks.forEach(tk => {
      const dueDay = tk.due_date || '';
      const isOverdue = dueDay && dueDay < today;
      const isDueToday = dueDay === today;
      const priLabel = tk.priority === 'alta' ? t({id:'panel.task.priority.high'}) : tk.priority === 'baixa' ? t({id:'panel.task.priority.low'}) : t({id:'panel.task.priority.normal'});
      const statusLabel = tk.status === 'em_andamento' ? t({id:'task.status.em_andamento'}) : t({id:'task.status.pendente'});
      tasks.push({
        priority: isOverdue || tk.priority === 'alta' ? 'alta' : 'media',
        bucket: isDueToday ? 'hoje' : isOverdue ? 'atencao' : 'acompanhamento',
        kind: `${t({id:'panel.summary.internalTasks'})} (${priLabel})`,
        label: tk.title || '—',
        detail: `${statusLabel}${tk.owner ? ` · ${tk.owner}` : ''}${dueDay ? ` · ${t({id:'panel.task.detail.prazo'})}: ${dueDay}` : ''}${isOverdue ? ` · ${t({id:'panel.task.detail.overdue'})}` : ''}`,
        actionType: 'tarefa', task_id: tk.id,
      });
    });

    return tasks.sort((a, b) => (a.priority === 'alta' ? 0 : 1) - (b.priority === 'alta' ? 0 : 1));
  }

  // ── Gerir leitor ─────────────────────────────────────

  async function searchReader() {
    if (!readerLookup.trim()) { setReaderMsg(t({id:'panel.loan.errorMissing'})); return; }
    setReaderMsg(t({id:'common.searching'}));
    try {
      const { data, error } = await supabase.rpc('fn_painel_find_profile_by_lookup', { p_lookup: readerLookup.trim() });
      if (error) throw error;
      const p = Array.isArray(data) ? data[0] : data;
      if (!p) { setReaderMsg(t({id:'panel.reader.notFound'})); setReaderProfile(null); return; }
      setReaderProfile(p);
      setReaderMsg('');
      // Charger l'historique de cotisation pour ce lecteur
      if (membershipEnabled && (isCoordOrAdmin)) {
        const { data: payments } = await supabase.rpc('fn_list_membership_payments_for_user', { p_user_id: p.id });
        setReaderPayments(payments || []);
      } else {
        setReaderPayments([]);
      }
    } catch (e) { setReaderMsg(t({id:'common.errorPrefix'}, {message: e.message})); setReaderProfile(null); }
  }

  // ── Cotisation ───────────────────────────────────────

  // Chargement de la config et des règles de cotisation
  const loadMembershipConfig = useCallback(async () => {
    if (!libraryId || !isCoordOrAdmin) return;
    try {
      const [{ data: libRow }, { data: rules }] = await Promise.all([
        supabase.from('libraries').select('membership_enabled').eq('id', libraryId).single(),
        supabase.from('library_membership_rules').select('*').eq('library_id', libraryId).eq('is_active', true).order('display_order'),
      ]);
      setMembershipEnabled(!!libRow?.membership_enabled);
      setMembershipRules(rules || []);
    } catch (e) { console.warn('loadMembershipConfig:', e); }
  }, [libraryId, isCoordOrAdmin]);

  // Chargement de l'aperçu global (tableau Contribuições)
  const loadMembershipOverview = useCallback(async () => {
    if (!libraryId || !isCoordOrAdmin) return;
    try {
      const { data, error } = await supabase
        .from('v_membership_overview_panel')
        .select('*')
        .eq('library_id', libraryId)
        .order('display_name', { ascending: true });
      if (error) throw error;
      setMembershipOverview(data || []);
    } catch (e) { console.warn('loadMembershipOverview:', e); }
  }, [libraryId, isCoordOrAdmin]);

  useEffect(() => { loadMembershipConfig(); }, [loadMembershipConfig]);
  useEffect(() => { if (tab === 'contribuicoes') loadMembershipOverview(); }, [tab, loadMembershipOverview]);

  // Ouvrir le modal de paiement
  function openPaymentModal(target) {
    if (membershipRules.length === 0) {
      setPaymentMsg(t({ id: 'membership.payment.noRulesAvailable' }));
      return;
    }
    const firstRule = membershipRules[0];
    setPaymentModal(target);
    setPaymentDraft({
      user_id: target.user_id,
      rule_id: firstRule.id,
      amount_paid: firstRule.amount_suggested ?? firstRule.amount_min ?? 0,
      payment_method: 'cash',
      paid_at: new Date().toISOString().slice(0, 10), // YYYY-MM-DD
      notes: '',
    });
    setPaymentMsg('');
  }

  function closePaymentModal() {
    setPaymentModal(null);
    setPaymentDraft(null);
    setPaymentMsg('');
  }

  // Quand on change de règle, pré-remplir le montant
  function onPaymentRuleChange(newRuleId) {
    const rule = membershipRules.find(r => r.id === newRuleId);
    setPaymentDraft(p => ({
      ...p,
      rule_id: newRuleId,
      amount_paid: rule?.amount_suggested ?? rule?.amount_min ?? 0,
    }));
  }

  async function submitPayment() {
    if (!paymentDraft) return;
    setPaymentSaving(true);
    setPaymentMsg('');
    try {
      const { data, error } = await supabase.rpc('fn_record_membership_payment', {
        p_user_id: paymentDraft.user_id,
        p_rule_id: paymentDraft.rule_id,
        p_amount_paid: Number(paymentDraft.amount_paid) || 0,
        p_payment_method: paymentDraft.payment_method,
        p_paid_at: new Date(paymentDraft.paid_at + 'T12:00:00Z').toISOString(),
        p_notes: paymentDraft.notes?.trim() || null,
      });
      if (error) throw error;
      const result = Array.isArray(data) ? data[0] : data;
      setPaymentMsg(t({ id: 'membership.payment.recorded' }, { from: result.valid_from, until: result.valid_until || '∞' }));
      // Refresh des données affichées
      await loadMembershipOverview();
      if (readerProfile && readerProfile.id === paymentDraft.user_id) {
        const { data: payments } = await supabase.rpc('fn_list_membership_payments_for_user', { p_user_id: readerProfile.id });
        setReaderPayments(payments || []);
      }
      // Fermer le modal après 1s pour que le user voie le message
      setTimeout(() => closePaymentModal(), 1500);
    } catch (e) {
      setPaymentMsg(t({ id: 'common.errorPrefix' }, { message: e.message }));
    } finally {
      setPaymentSaving(false);
    }
  }

  function fmtMembershipStatus(status, days) {
    if (status === 'up_to_date') {
      if (days != null && days <= 30) return { label: t({ id: 'membership.status.upToDate' }), variant: 'warn', detail: t({ id: 'membership.daysUntilExpiry.plural' }, { days }) };
      return { label: t({ id: 'membership.status.upToDate' }), variant: 'ok', detail: null };
    }
    if (status === 'expired') return { label: t({ id: 'membership.status.expired' }), variant: 'danger', detail: null };
    if (status === 'never_paid') return { label: t({ id: 'membership.status.neverPaid' }), variant: 'warn', detail: null };
    if (status === 'lifetime') return { label: t({ id: 'membership.status.lifetime' }), variant: 'ok', detail: null };
    return { label: t({ id: 'membership.status.notApplicable' }), variant: 'default', detail: null };
  }

  function getMembershipFilterCount(filter) {
    if (filter === 'all') return membershipOverview.length;
    return membershipOverview.filter(m => m.dues_status === filter).length;
  }

  // ── Toggle selection ─────────────────────────────────

  function toggleRes(key) {
    setSelectedRes(prev => { const n = new Set(prev); n.has(key) ? n.delete(key) : n.add(key); return n; });
  }
  function toggleAllRes() {
    if (selectedRes.size === reservations.length) setSelectedRes(new Set());
    else setSelectedRes(new Set(reservations.map(r => `${r.reserva_id}-${r.line_no}`)));
  }

  // ── Render ───────────────────────────────────────────

  // FIX BUG #1: Each tab now has a distinct hint key (was duplicating label).
  const TABS = [
    { key: 'trabalho-do-dia', label: t({ id: 'panel.tab.dailyWork' }), hint: t({ id: 'panel.tab.dailyWork.hint' }) },
    { key: 'acoes', label: t({ id: 'panel.tab.actions' }), hint: t({ id: 'panel.tab.actions.hint' }) },
    { key: 'reservas', label: t({ id: 'panel.tab.reservations' }), hint: t({ id: 'panel.tab.reservations.hint' }) },
    { key: 'consultas-locais', label: t({ id: 'panel.tab.consultations' }), hint: t({ id: 'panel.tab.consultations.hint' }) },
    { key: 'emprestimos-livro', label: t({ id: 'panel.tab.loans' }), hint: t({ id: 'panel.tab.loans.hint' }) },
    { key: 'emprestimos-lote', label: t({ id: 'panel.loan.grouped' }), hint: t({ id: 'panel.tab.grouped.hint' }) },
    { key: 'leitor', label: t({ id: 'panel.tab.reader' }), hint: t({ id: 'panel.tab.reader.hint' }) },
    ...(isCoordOrAdmin && membershipEnabled ? [
      { key: 'contribuicoes', label: t({ id: 'panel.tab.memberships' }), hint: t({ id: 'panel.tab.memberships.hint' }) },
    ] : []),
  ];

  const activeRes = reservations.filter(r => !['cancelada_leitor','cancelada_biblioteca','expirada','retirada_efetivada','liberada_para_circulacao'].includes(r.item_status));
  const activeLoans = loans.filter(l => l.item_status === 'aberto');
  const overdueLoans = activeLoans.filter(l => {
    const effectiveDue = l.extended_until || l.due_at;
    return effectiveDue && new Date(effectiveDue) < new Date();
  });

  if (!roleLoaded) return <PageShell><Topbar /><div style={{ textAlign: 'center', padding: 60 }}><Spinner size={32} /></div></PageShell>;

  if (!isLibrarian) return (
    <PageShell><Topbar />
      <div style={{ maxWidth: 600, margin: '0 auto', textAlign: 'center', padding: '60px 24px' }}>
        <h1 style={{ fontSize: '1.4rem', fontWeight: 800 }}>{t({ id: 'panel.title' })}</h1>
        <p style={{ color: 'var(--brand-muted)', marginTop: 12 }}>{t({ id: 'panel.restricted' })}</p>
        <Link to="/conta" style={{ textDecoration: 'none' }}><button style={{ marginTop: 16, padding: '10px 20px', borderRadius: 8, fontSize: '.9rem', fontWeight: 600, background: 'var(--brand-color-primary, #7a0b14)', color: '#fff', border: 'none', cursor: 'pointer' }}>{t({ id: 'panel.myAccount' })}</button></Link>
      </div>
    </PageShell>
  );

  if (loading) return <PageShell><Topbar /><div style={{ textAlign: 'center', padding: 60 }}><Spinner size={32} /></div></PageShell>;

  return (
    <PageShell>
      <Topbar />
      <Hero title={t({ id: 'panel.title' })} subtitle={libraryName || t({ id: 'panel.subtitle' })}
        actions={
          <>
            <Link to="/catalogacao" style={{ textDecoration: 'none' }}>
              <Button variant="primary">{t({ id: 'nav.catalogacao' })}</Button>
            </Link>
            {(role === 'coordenador' || role === 'administrador') && (
              <Link to="/importacoes" style={{ textDecoration: 'none' }}>
                <Button variant="secondary">{t({ id: 'nav.importacoes' })}</Button>
              </Link>
            )}
            <Link to="/biblioteca" style={{ textDecoration: 'none' }}>
              <Button variant="secondary">{t({ id: 'nav.library' })}</Button>
            </Link>
            {role === 'administrador' && (
              <Link to="/rede" style={{ textDecoration: 'none' }}>
                <Button variant="secondary">{t({ id: 'nav.network' })}</Button>
              </Link>
            )}
          </>
        }
      >
        <div className="ab-painel-chips">
          <Pill variant={activeRes.length > 0 ? 'warn' : 'default'}>{t({ id: 'panel.reservations.active' }, { count: activeRes.length })}</Pill>
          <Pill>{t({ id: 'panel.consultations.active' }, { count: consultations.filter(c => c.item_status === 'ativa').length })}</Pill>
          <Pill variant={overdueLoans.length > 0 ? 'bad' : 'default'}>{t({ id: 'panel.loan.openLoans' }, { count: activeLoans.length, overdue: overdueLoans.length })}</Pill>
          <Button variant="secondary" onClick={loadData}>{t({ id: 'common.refresh' })}</Button>
        </div>
      </Hero>

      <div className="ab-painel-card">
        <nav className="ab-painel-tabs" role="tablist">
          {TABS.map(t => (
            <button key={t.key} className={`ab-painel-tab ${tab === t.key ? 'active' : ''}`}
              onClick={() => setTab(t.key)} role="tab">
              {t.label}
              <span className="ab-painel-tab__hint">{t.hint}</span>
            </button>
          ))}
        </nav>

        <div className="ab-painel-panel">

          {/* ═══ TRABALHO DO DIA ═══ */}
          {tab === 'trabalho-do-dia' && (() => {
            const tasks = buildDailyTasks();
            const hoje = tasks.filter(t => t.bucket === 'hoje');
            const atencao = tasks.filter(t => t.bucket === 'atencao');
            const acomp = tasks.filter(t => t.bucket === 'acompanhamento');
            return (
            <div>
              <h2 className="ab-painel-h2">{t({ id: 'panel.tab.dailyWork.hint' })}</h2>
              <div className="ab-painel-summary-grid">
                <SummaryCard label="Hoje" count={hoje.length} variant="warn" />
                <SummaryCard label={t({id:'panel.summary.attention'})} count={atencao.length} variant="bad" />
                <SummaryCard label={t({ id: 'panel.summary.pendingReservations' })} count={activeRes.filter(r => r.workflow_stage_effective === 'solicitada').length} variant="warn" />
                <SummaryCard label={t({ id: 'panel.summary.overdueLoans' })} count={overdueLoans.length} variant="bad" />
                <SummaryCard label={t({ id: 'panel.summary.pendingConsultations' })} count={consultations.filter(c => c.workflow_stage_effective === 'solicitada').length} variant="warn" />
                <SummaryCard label={t({ id: 'panel.summary.internalTasks' })} count={internalTasks.length} variant={internalTasks.some(t => t.priority === 'alta') ? 'bad' : 'warn'} />
              </div>

              {tasks.length === 0 ? (
                <p className="ab-painel-hint">{t({ id: 'panel.noAutoTasks' })}</p>
              ) : (
                <>
                  {hoje.length > 0 && <TaskBucket title={t({ id: 'panel.summary.today' })} tasks={hoje} setTab={setTab} onTaskAction={loadData} />}
                  {atencao.length > 0 && <TaskBucket title={t({ id: 'panel.summary.attention' })} tasks={atencao} setTab={setTab} onTaskAction={loadData} />}
                  {acomp.length > 0 && <TaskBucket title={t({ id: 'panel.summary.monitoring' })} tasks={acomp} setTab={setTab} onTaskAction={loadData} />}
                </>
              )}

              {/* ── Tarefas internas — sempre visível ──── */}
              <div style={{ marginTop: 20, padding: 16, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
                  <h3 className="ab-painel-h3" style={{ margin: 0 }}>{t({ id: 'panel.tasks.title' })} ({internalTasks.length})</h3>
                  <a href="/biblioteca" style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>{t({ id: 'panel.tasks.manage' })}</a>
                </div>
                {internalTasks.length === 0 ? (
                  <p style={{ fontSize: '.88rem', color: 'var(--brand-muted)', margin: 0 }}>
                    {t({ id: 'panel.tasks.empty' })}{' '}
                    {t({ id: 'panel.tasks.emptyHint' }, {
                      libraryLink: <a href="/biblioteca" style={{ color: 'var(--brand-text)' }}>{t({ id: 'nav.library' })}</a>,
                    })}
                  </p>
                ) : (
                  <div style={{ border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, overflow: 'hidden' }}>
                    {internalTasks.map((tk, i) => {
                      const isOverdue = tk.due_date && tk.due_date < new Date().toISOString().slice(0, 10);
                      return (
                        <div key={tk.id} style={{ padding: '10px 12px', background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent', borderBottom: '1px solid rgba(255,255,255,.04)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                          <div style={{ flex: 1 }}>
                            <div style={{ fontSize: '.9rem', fontWeight: 600 }}>
                              {tk.title || '—'}
                              {isOverdue && <span style={{ color: '#f87171', fontWeight: 700, marginLeft: 8, fontSize: '.78rem' }}>{t({ id: 'panel.overdue' })}</span>}
                            </div>
                            <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
                              {tk.status === 'em_andamento' ? t({id:'task.status.em_andamento'}) : t({id:'task.status.pendente'})}
                              {tk.owner && ` · ${tk.owner}`}
                              {tk.due_date && ` · ${t({id:'panel.task.detail.prazo'})}: ${tk.due_date}`}
                              {tk.tags?.length > 0 && ` · ${tk.tags.join(', ')}`}
                            </div>
                          </div>
                          <div style={{ display: 'flex', gap: 4, flexShrink: 0, alignItems: 'center' }}>
                            <span style={{ fontSize: '.7rem', padding: '2px 8px', borderRadius: 4, fontWeight: 700, background: tk.priority === 'alta' ? 'rgba(220,38,38,.18)' : tk.priority === 'baixa' ? 'rgba(29,78,216,.18)' : 'rgba(180,83,9,.18)', color: tk.priority === 'alta' ? '#f87171' : tk.priority === 'baixa' ? '#60a5fa' : '#fbbf24' }}>
                              {tk.priority === 'alta' ? t({id:'panel.task.priority.high'}) : tk.priority === 'baixa' ? t({id:'panel.task.priority.low'}) : t({id:'panel.task.priority.normal'})}
                            </span>
                            <select value={tk.status} style={{ fontSize: '.82rem', padding: '4px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4' }}
                              onChange={async e => {
                                await supabase.from('painel_internal_tasks').update({ status: e.target.value }).eq('id', tk.id);
                                loadData();
                              }}>
                              <option value="pendente">{t({ id: 'task.status.pendente' })}</option>
                              <option value="em_andamento">{t({ id: 'task.status.em_andamento' })}</option>
                              <option value="concluida">{t({ id: 'task.status.concluida' })}</option>
                              <option value="cancelada">{t({ id: 'task.status.cancelada' })}</option>
                            </select>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>
            );
          })()}

          {/* ═══ AÇÕES ═══ */}
          {tab === 'acoes' && (
            <div className="ab-painel-acoes-grid">
              <div className="ab-painel-acoes-card">
                <h2 className="ab-painel-h2">{t({ id: 'panel.loan.register' })}</h2>
                <p className="ab-painel-hint">{t({ id: 'panel.loan.refsHint' })}</p>
                <label>{t({ id: 'panel.loan.borrowerLabel' })}
                  <input type="text" value={borrowerLookup} onChange={e => setBorrowerLookup(e.target.value)} placeholder={t({ id: 'panel.loan.borrowerPlaceholder' })} className="ab-painel-input" />
                </label>
                <label>{t({ id: 'panel.loan.refsLabel' })}
                  <input type="text" value={loanRefs} onChange={e => setLoanRefs(e.target.value)} placeholder={t({ id: 'panel.loan.refsPlaceholder' })} className="ab-painel-input" />
                </label>
                <Button onClick={registrarSaida}>{t({ id: 'panel.loan.register' })}</Button>
                {loanMsg && <p className="ab-painel-msg">{loanMsg}</p>}
              </div>
              <div className="ab-painel-acoes-card">
                <h2 className="ab-painel-h2">{t({ id: 'panel.loan.return' })}</h2>
                <label>{t({ id: 'panel.loan.returnFullLabel' })}
                  <input type="text" value={returnId} onChange={e => setReturnId(e.target.value)} placeholder={t({id:"panel.loan.returnTotalPh"})} className="ab-painel-input" />
                </label>
                <Button variant="secondary" onClick={registrarDevolucaoTotal}>{t({ id: 'panel.loan.returnFull' })}</Button>
                <hr className="ab-painel-hr" />
                <label>{t({ id: 'panel.loan.returnPartialLabel' })}
                  <input type="text" value={returnSubIds} onChange={e => setReturnSubIds(e.target.value)} placeholder={t({id:"panel.loan.returnPartialPh"})} className="ab-painel-input" />
                </label>
                <Button variant="secondary" onClick={registrarDevolucaoParcial}>{t({ id: 'panel.loan.returnPartial' })}</Button>
                {returnMsg && <p className="ab-painel-msg">{returnMsg}</p>}
              </div>
            </div>
          )}

          {/* ═══ RESERVAS ATIVAS ═══ */}
          {tab === 'reservas' && (
            <div>
              <div className="ab-painel-res-toolbar">
                <Button onClick={confirmSelectedPickup}>{t({ id: 'panel.reservations.confirmPickup' }, { count: selectedRes.size })}</Button>
                <Button variant="secondary" onClick={() => cancelSelectedRes()}>{t({ id: 'common.cancel' })} ({selectedRes.size})</Button>
                <Button variant="secondary" onClick={loadData}>{t({ id: 'common.refresh' })}</Button>
              </div>
              <div className="ab-painel-res-workflow">
                <input type="text" value={resNote} onChange={e => setResNote(e.target.value)} placeholder={t({id:"panel.loan.notePh"})} className="ab-painel-input" />
                <input type="datetime-local" value={resSchedule} onChange={e => setResSchedule(e.target.value)} className="ab-painel-input" />
                <select value={resStage} onChange={e => setResStage(e.target.value)} className="ab-painel-input">
                  <option value="">{t({ id: 'panel.reservations.selectStage' })}</option>
                  {RES_STAGES.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
                </select>
                <Button variant="secondary" onClick={applyResWorkflow}>{t({ id: 'panel.reservations.applyStep' })}</Button>
              </div>
              {actionMsg && <p className="ab-painel-msg">{actionMsg}</p>}
              <div className="ab-painel-table-wrap">
                <table className="ab-painel-table">
                  <thead>
                    <tr>
                      <th><input type="checkbox" checked={selectedRes.size === reservations.length && reservations.length > 0} onChange={toggleAllRes} /></th>
                      <th>Sub-ID</th><th>{t({id:'panel.table.reader'})}</th><th>{t({id:'panel.table.book'})}</th><th>Ref</th><th>{t({id:'panel.table.label'})}</th><th>{t({id:'panel.table.step'})}</th><th>{t({id:'panel.table.pickup'})}</th><th>{t({id:'panel.table.validity'})}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {reservations.map((r, i) => {
                      const key = `${r.reserva_id}-${r.line_no}`;
                      return (
                        <tr key={i} className={selectedRes.has(key) ? 'selected' : ''}>
                          <td><input type="checkbox" checked={selectedRes.has(key)} onChange={() => toggleRes(key)} /></td>
                          <td>{r.sub_id}</td>
                          <td>{r.user_name || r.user_email || r.user_id?.slice(0,8)}</td>
                          <td><Link to={`/livro/${r.book_id}`}>{r.titulo || '—'}</Link></td>
                          <td>{r.bib_ref}</td>
                          <td>{r.rotulo || '—'}</td>
                          <td><span className="ab-painel-stage" data-stage={r.workflow_stage_effective}>{WORKFLOW_LABELS[r.workflow_stage_effective] || r.item_status || '—'}</span></td>
                          <td>{fmtD(r.pickup_scheduled_for)}</td>
                          <td>{fmtD(r.expires_at)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* ═══ CONSULTAS LOCAIS ═══ */}
          {tab === 'consultas-locais' && (
            <div>
              <h2 className="ab-painel-h2">{t({ id: 'panel.tab.consultations' })}</h2>
              <div className="ab-painel-table-wrap">
                <table className="ab-painel-table">
                  <thead><tr><th>Sub-ID</th><th>{t({id:'panel.table.reader'})}</th><th>{t({id:'panel.table.book'})}</th><th>Ref</th><th>{t({id:'panel.table.step'})}</th><th>{t({ id: 'panel.loan.scheduling' })}</th><th>{t({id:'panel.table.actions'})}</th></tr></thead>
                  <tbody>
                    {consultations.map((c, i) => (
                      <tr key={i}>
                        <td>{c.sub_id}</td>
                        <td>{c.user_name || c.user_email || '—'}</td>
                        <td><Link to={`/livro/${c.book_id}`}>{c.titulo || '—'}</Link></td>
                        <td>{c.bib_ref}</td>
                        <td><span className="ab-painel-stage" data-stage={c.workflow_stage_effective}>{CONSULT_WORKFLOW[c.workflow_stage_effective] || c.item_status || '—'}</span></td>
                        <td>{fmtD(c.consultation_scheduled_for)}</td>
                        <td className="ab-painel-actions-cell">
                          {c.workflow_stage_effective === 'solicitada' && (
                            <button className="ab-button ab-button--mini" onClick={() => setConsultaWorkflow(c.consulta_id, c.line_no, 'em_preparacao')}>{t({id:'panel.table.prepare'})}</button>
                          )}
                          {c.workflow_stage_effective === 'em_preparacao' && (
                            <button className="ab-button ab-button--mini" onClick={() => setConsultaWorkflow(c.consulta_id, c.line_no, 'consulta_agendada')}>{t({ id: 'panel.loan.schedule' })}</button>
                          )}
                          {c.workflow_stage_effective === 'consulta_agendada' && (
                            <button className="ab-button ab-button--mini" onClick={() => setConsultaWorkflow(c.consulta_id, c.line_no, 'consulta_realizada')}>{t({id:'panel.table.completed'})}</button>
                          )}
                          {!['consulta_realizada','cancelada_leitor','cancelada_biblioteca','expirada'].includes(c.workflow_stage_effective) && (
                            <button className="ab-button ab-button--mini ab-button--danger" onClick={() => setConsultaWorkflow(c.consulta_id, c.line_no, 'cancelada_biblioteca', 'Cancelada pelo painel.')}>{t({ id: 'common.cancel' })}</button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* ═══ EMPRÉSTIMOS POR LIVRO ═══ */}
          {tab === 'emprestimos-livro' && (
            <div>
              <h2 className="ab-painel-h2">{t({ id: 'panel.tab.loans' })}</h2>
              <div className="ab-painel-table-wrap">
                <table className="ab-painel-table">
                  <thead><tr><th>Sub-ID</th><th>{t({id:'panel.table.reader'})}</th><th>{t({id:'panel.table.book'})}</th><th>Ref</th><th>{t({id:'panel.table.label'})}</th><th>{t({id:'panel.table.exit'})}</th><th>{t({id:'panel.table.deadline'})}</th><th>{t({id:'panel.table.extended'})}</th><th>{t({id:'panel.table.status'})}</th><th>{t({id:'panel.table.actions'})}</th></tr></thead>
                  <tbody>
                    {loans.map((l, i) => (
                      <tr key={i} className={l.item_status === 'aberto' && l.due_at && new Date(l.due_at) < new Date() ? 'overdue' : ''}>
                        <td>{l.sub_id}</td>
                        <td>{l.user_name || l.user_email || '—'}</td>
                        <td><Link to={`/livro/${l.book_id}`}>{l.titulo || '—'}</Link></td>
                        <td>{l.bib_ref}</td>
                        <td>{l.rotulo || '—'}</td>
                        <td>{fmtD(l.emprestimo_created_at)}</td>
                        <td>{fmtD(l.due_at)}</td>
                        <td>{l.extended_until ? fmtD(l.extended_until) : '—'}</td>
                        <td><span className={`ab-painel-loan-status ab-painel-loan-status--${l.item_status}`}>{l.item_status === 'aberto' ? t({ id: 'panel.loan.status.open' }) : t({ id: 'panel.loan.status.returned' })}</span></td>
                        <td className="ab-painel-actions-cell">
                          {l.item_status === 'aberto' && (
                            <>
                              <button className="ab-button ab-button--mini" onClick={() => returnLoanItem(l.emprestimo_id, [l.line_no])}>{t({ id: 'panel.loan.return.btn' })}</button>
                              {!l.extended_once && !l.extended_until && (
                                <button className="ab-button ab-button--secondary ab-button--mini" onClick={() => extendLoan(l.emprestimo_id)}>{t({id:'panel.table.extend'})}</button>
                              )}
                            </>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* ═══ EMPRÉSTIMOS AGRUPADOS ═══ */}
          {tab === 'emprestimos-lote' && (
            <div>
              <h2 className="ab-painel-h2">{t({ id: 'panel.loan.grouped' })}</h2>
              {(() => {
                const grouped = {};
                loans.forEach(l => {
                  if (!grouped[l.emprestimo_id]) grouped[l.emprestimo_id] = { ...l, items: [] };
                  grouped[l.emprestimo_id].items.push(l);
                });
                return Object.values(grouped).map((g, i) => (
                  <div key={i} className="ab-painel-lote">
                    <div className="ab-painel-lote__head">
                      <strong>#{g.emprestimo_id}</strong> · {g.user_name || g.user_email} · {g.items.length} {t({id:'panel.loan.items'},{count:g.items.length})} · {t({id:'panel.task.detail.deadline'})}: {fmtD(g.due_at)} · {g.emprestimo_status}
                    </div>
                    <div className="ab-painel-lote__items">
                      {g.items.map((l, j) => (
                        <div key={j} className="ab-painel-lote__item">
                          {l.sub_id} · <Link to={`/livro/${l.book_id}`}>{l.titulo || l.bib_ref}</Link> · {l.item_status === 'aberto' ? t({id:'panel.loan.inProgress'}) : t({id:'panel.loan.returned'})}
                        </div>
                      ))}
                    </div>
                  </div>
                ));
              })()}
            </div>
          )}

          {/* ═══ GERIR LEITOR ═══ */}
          {tab === 'leitor' && (
            <div>
              <h2 className="ab-painel-h2">{t({id:'panel.reader.manage'})}</h2>
              <div className="ab-painel-reader-search">
                <input type="text" value={readerLookup} onChange={e => setReaderLookup(e.target.value)}
                  placeholder={t({id:'panel.reader.searchPlaceholderFull'})} className="ab-painel-input"
                  onKeyDown={e => e.key === 'Enter' && searchReader()} />
                <Button onClick={searchReader}>{t({ id: 'common.search' })}</Button>
              </div>
              {readerMsg && <p className="ab-painel-msg">{readerMsg}</p>}
              {readerProfile && (
                <div className="ab-painel-reader-card">
                  <h3>{readerProfile.first_name} {readerProfile.last_name}</h3>
                  <p>{t({id:'panel.reader.email'})}: {readerProfile.email} · {t({id:'panel.reader.id'})}: {readerProfile.public_id} · {t({id:'panel.reader.gender'})}: {readerProfile.gender ? t({id:`gender.${readerProfile.gender}`, defaultMessage: readerProfile.gender}) : '—'}</p>
                  <p>{t({id:'panel.reader.registered'})}: {fmtD(readerProfile.created_at)} · {t({id:'panel.reader.restricted'})}: {readerProfile.is_restricted ? t({id:'panel.reader.yes'}) : t({id:'panel.reader.no'})} · {t({id:'panel.reader.passwordPending'})}: {readerProfile.must_change_password ? t({id:'panel.reader.yes'}) : t({id:'panel.reader.no'})}</p>

                  {/* Restriction status */}
                  <div style={{ margin: '10px 0', padding: '8px 12px', borderRadius: 8, background: readerProfile.is_restricted ? 'rgba(220,38,38,.15)' : 'rgba(74,222,128,.1)', border: readerProfile.is_restricted ? '1px solid rgba(220,38,38,.3)' : '1px solid rgba(74,222,128,.2)' }}>
                    <span style={{ fontWeight: 600, fontSize: '.85rem' }}>
                      {readerProfile.is_restricted
                        ? t({id:'panel.reader.restricted.yes'}, { reason: readerProfile.restricted_reason || '—' })
                        : t({id:'panel.reader.restricted.no'})}
                    </span>
                  </div>

                  {/* Address display */}
                  {readerProfile.address && (() => {
                    let a = null;
                    try { a = typeof readerProfile.address === 'object' ? readerProfile.address : JSON.parse(readerProfile.address); } catch { /* not JSON */ }
                    if (a && typeof a === 'object' && (a.line1 || a.city)) {
                      return (
                        <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', margin: '6px 0' }}>
                          {a.line1 && <span>{t({id:'panel.reader.address'})}: {a.line1}</span>}
                          {a.unit && <span> · {t({id:'panel.reader.unit'})}: {a.unit}</span>}
                          {a.postal_code && <span> · {t({id:'panel.reader.postalCode'})}: {a.postal_code}</span>}
                          {a.district && <span> · {t({id:'panel.reader.district'})}: {a.district}</span>}
                          {a.city && <span> · {t({id:'panel.reader.city'})}: {a.city}</span>}
                          {a.state_region && <span> · {t({id:'panel.reader.state'})}: {a.state_region}</span>}
                          {a.country && <span> · {t({id:'panel.reader.country'})}: {a.country}</span>}
                        </div>
                      );
                    }
                    // Fallback: plain text address
                    return (
                      <p style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', margin: '6px 0', whiteSpace: 'pre-line' }}>
                        {String(readerProfile.address).replace(/\\n/g, '\n')}
                      </p>
                    );
                  })()}

                  {/* ── Edit profile form ── */}
                  <details style={{ marginTop: 12 }}>
                    <summary style={{ cursor: 'pointer', fontWeight: 600, fontSize: '.9rem' }}>{t({id:'panel.reader.editProfile'})}</summary>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginTop: 8 }}>
                      <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.firstName'})}
                        <input type="text" className="ab-painel-input" value={readerProfile.first_name || ''} onChange={e => setReaderProfile(p => ({...p, first_name: e.target.value}))} />
                      </label>
                      <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.lastName'})}
                        <input type="text" className="ab-painel-input" value={readerProfile.last_name || ''} onChange={e => setReaderProfile(p => ({...p, last_name: e.target.value}))} />
                      </label>
                      <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.emailRef'})}
                        <input type="email" className="ab-painel-input" value={readerProfile.email || ''} onChange={e => setReaderProfile(p => ({...p, email: e.target.value}))} />
                      </label>
                      <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.phone'})}
                        <input type="tel" className="ab-painel-input" value={readerProfile.phone || ''} onChange={e => setReaderProfile(p => ({...p, phone: e.target.value}))} />
                      </label>
                      <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.gender'})}
                        <select className="ab-painel-input" value={readerProfile.gender || ''} onChange={e => setReaderProfile(p => ({...p, gender: e.target.value}))}>
                          <option value="">—</option>
                          <option value="feminino">{t({id:'account.profile.gender.fem'})}</option>
                          <option value="masculino">{t({id:'account.profile.gender.masc'})}</option>
                          <option value="neutro">{t({id:'account.profile.gender.neutral'})}</option>
                          <option value="outro">{t({id:'account.profile.gender.other'})}</option>
                        </select>
                      </label>
                    </div>

                    {/* ── Address fields ── */}
                    <h4 style={{ margin: '12px 0 6px', fontSize: '.88rem', fontWeight: 600 }}>{t({id:'panel.reader.addressField'})}</h4>
                    {(() => {
                      let addr = {};
                      try { addr = typeof readerProfile.address === 'object' && readerProfile.address ? readerProfile.address : JSON.parse(readerProfile.address || '{}'); } catch { addr = { line1: readerProfile.address || '' }; }
                      const setAddr = (field, val) => setReaderProfile(p => {
                        let cur = {};
                        try { cur = typeof p.address === 'object' && p.address ? p.address : JSON.parse(p.address || '{}'); } catch { cur = { line1: p.address || '' }; }
                        return {...p, address: JSON.stringify({...cur, [field]: val})};
                      });
                      return (
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                          <label style={{ fontSize: '.82rem', gridColumn: 'span 2' }}>{t({id:'panel.reader.addressLine1'})}
                            <input type="text" className="ab-painel-input" value={addr.line1 || ''} onChange={e => setAddr('line1', e.target.value)} />
                          </label>
                          <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.addressUnit'})}
                            <input type="text" className="ab-painel-input" value={addr.unit || ''} onChange={e => setAddr('unit', e.target.value)} />
                          </label>
                          <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.addressPostal'})}
                            <input type="text" className="ab-painel-input" value={addr.postal_code || ''} onChange={e => setAddr('postal_code', e.target.value)} />
                          </label>
                          <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.addressDistrict'})}
                            <input type="text" className="ab-painel-input" value={addr.district || ''} onChange={e => setAddr('district', e.target.value)} />
                          </label>
                          <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.addressCity'})}
                            <input type="text" className="ab-painel-input" value={addr.city || ''} onChange={e => setAddr('city', e.target.value)} />
                          </label>
                          <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.addressState'})}
                            <input type="text" className="ab-painel-input" value={addr.state_region || ''} onChange={e => setAddr('state_region', e.target.value)} />
                          </label>
                          <label style={{ fontSize: '.82rem' }}>{t({id:'panel.reader.addressCountry'})}
                            <input type="text" className="ab-painel-input" value={addr.country || ''} onChange={e => setAddr('country', e.target.value)} />
                          </label>
                        </div>
                      );
                    })()}

                    <Button style={{ marginTop: 8 }} onClick={async () => {
                      try {
                        const updateData = {
                          first_name: readerProfile.first_name, last_name: readerProfile.last_name,
                          phone: readerProfile.phone, gender: readerProfile.gender,
                          email: readerProfile.email,
                          address: typeof readerProfile.address === 'string' ? readerProfile.address : JSON.stringify(readerProfile.address),
                        };
                        const { error } = await supabase.from('profiles').update(updateData).eq('id', readerProfile.id);
                        if (error) throw error;
                        setReaderMsg(t({id:'panel.reader.profileSaved'}));
                      } catch (err) { setReaderMsg(t({id:'common.errorPrefix'}, {message: err.message})); }
                    }}>{t({id:'panel.reader.saveProfile'})}</Button>
                  </details>

                  {/* ── Restrict / Unrestrict ── */}
                  <div style={{ marginTop: 12, padding: '10px 12px', borderRadius: 8, background: 'rgba(0,0,0,.15)' }}>
                    {readerProfile.is_restricted ? (
                      <Button variant="secondary" onClick={async () => {
                        if (!confirm(t({id:'panel.reader.unrestrictConfirm'}))) return;
                        try {
                          await supabase.from('profiles').update({ is_restricted: false, restricted_reason: null }).eq('id', readerProfile.id);
                          setReaderProfile(p => ({...p, is_restricted: false, restricted_reason: null}));
                          setReaderMsg(t({id:'common.dataSaved'}));
                        } catch (err) { setReaderMsg(t({id:'common.errorPrefix'}, {message: err.message})); }
                      }}>{t({id:'panel.reader.unrestrictAction'})}</Button>
                    ) : (
                      <div>
                        <input type="text" className="ab-painel-input" placeholder={t({id:'panel.reader.restrictReasonPlaceholder'})}
                          value={restrictReason || ''} onChange={e => setRestrictReason(e.target.value)} style={{ marginBottom: 6, width: '100%' }} />
                        <Button variant="secondary" onClick={async () => {
                          if (!restrictReason?.trim()) return;
                          if (!confirm(t({id:'panel.reader.restrictConfirm'}))) return;
                          try {
                            await supabase.from('profiles').update({ is_restricted: true, restricted_reason: restrictReason.trim() }).eq('id', readerProfile.id);
                            setReaderProfile(p => ({...p, is_restricted: true, restricted_reason: restrictReason.trim()}));
                            setRestrictReason('');
                            setReaderMsg(t({id:'common.dataSaved'}));
                          } catch (err) { setReaderMsg(t({id:'common.errorPrefix'}, {message: err.message})); }
                        }}>{t({id:'panel.reader.restrictAction'})}</Button>
                      </div>
                    )}
                  </div>

                  {/* ── Histórico de contribuições (cotisation) ── */}
                  {isCoordOrAdmin && membershipEnabled && (
                    <div style={{ marginTop: 16, padding: 12, borderRadius: 8, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8, gap: 8, flexWrap: 'wrap' }}>
                        <h4 style={{ margin: 0, fontSize: '.95rem', fontWeight: 700 }}>{t({ id: 'membership.payment.historyTitle' })}</h4>
                        <Button onClick={() => openPaymentModal({
                          user_id: readerProfile.id,
                          display_name: `${readerProfile.first_name || ''} ${readerProfile.last_name || ''}`.trim() || readerProfile.email,
                        })} disabled={membershipRules.length === 0} title={membershipRules.length === 0 ? t({ id: 'panel.memberships.noRulesWarning.title' }) : undefined}>
                          + {t({ id: 'membership.action.recordPayment' })}
                        </Button>
                      </div>
                      {readerPayments.length === 0 ? (
                        <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', padding: '8px 0' }}>
                          {t({ id: 'membership.payment.noPayments' })}
                        </div>
                      ) : (
                        <div style={{ borderRadius: 8, overflow: 'hidden', border: '1px solid rgba(255,255,255,.06)' }}>
                          {readerPayments.map((p, i) => (
                            <div key={p.id} style={{ padding: '10px 12px', background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent', borderBottom: i < readerPayments.length - 1 ? '1px solid rgba(255,255,255,.04)' : 'none' }}>
                              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8, flexWrap: 'wrap' }}>
                                <div style={{ flex: 1, minWidth: 200 }}>
                                  <div style={{ fontSize: '.9rem', fontWeight: 600 }}>
                                    {p.amount_paid > 0
                                      ? `${p.amount_paid} ${p.currency}`
                                      : t({ id: `membership.method.${p.payment_method}` })}
                                    <span style={{ fontWeight: 400, color: 'var(--brand-muted)', marginLeft: 8 }}>
                                      · {t({ id: `membership.method.${p.payment_method}` })}
                                    </span>
                                  </div>
                                  <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginTop: 2 }}>
                                    {p.rule_name && <>{p.rule_name} · </>}
                                    {t({ id: 'membership.payment.paidOn' }, { date: fmtD(p.paid_at) })}
                                    {p.valid_until && <> · {t({ id: 'membership.validUntil' }, { date: p.valid_until })}</>}
                                  </div>
                                  {p.notes && (
                                    <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)', marginTop: 3, fontStyle: 'italic' }}>{p.notes}</div>
                                  )}
                                  {p.recorded_by_name && (
                                    <div style={{ fontSize: '.74rem', color: 'var(--brand-muted)', marginTop: 2 }}>
                                      {t({ id: 'membership.payment.recordedBy' }, { name: p.recorded_by_name })}
                                    </div>
                                  )}
                                </div>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* ═══ Onglet Contribuições (admin coord) ═══════════════ */}
          {tab === 'contribuicoes' && isCoordOrAdmin && (
            <div>
              <h2 className="ab-painel-h2">{t({ id: 'panel.memberships.title' })}</h2>
              <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem', marginBottom: 12 }}>
                {t({ id: 'panel.memberships.hint' })}
              </p>

              {/* Bandeau d'avertissement si aucune règle active */}
              {membershipRules.length === 0 && (
                <div style={{ padding: '12px 14px', borderRadius: 8, marginBottom: 14, background: 'rgba(251,146,60,.1)', border: '1px solid rgba(251,146,60,.3)', color: '#fdba74' }}>
                  <div style={{ fontWeight: 600, fontSize: '.9rem', marginBottom: 4 }}>
                    ⚠ {t({ id: 'panel.memberships.noRulesWarning.title' })}
                  </div>
                  <div style={{ fontSize: '.85rem' }}>
                    {t({ id: 'panel.memberships.noRulesWarning.body' })}{' '}
                    <a href="/biblioteca" style={{ color: '#fdba74', textDecoration: 'underline', fontWeight: 600 }}>
                      {t({ id: 'panel.memberships.noRulesWarning.link' })}
                    </a>
                  </div>
                </div>
              )}

              {/* Filtres */}
              <div style={{ display: 'flex', gap: 6, marginBottom: 14, flexWrap: 'wrap' }}>
                {[
                  { key: 'all', label: t({ id: 'panel.memberships.filter.all' }) },
                  { key: 'up_to_date', label: t({ id: 'membership.status.upToDate' }) },
                  { key: 'expired', label: t({ id: 'membership.status.expired' }) },
                  { key: 'never_paid', label: t({ id: 'membership.status.neverPaid' }) },
                ].map(f => (
                  <button
                    key={f.key}
                    onClick={() => setMembershipFilter(f.key)}
                    className={`ab-button ab-button--mini ${membershipFilter === f.key ? '' : 'ab-button--ghost'}`}
                    style={{ fontSize: '.8rem' }}
                  >
                    {f.label} ({getMembershipFilterCount(f.key)})
                  </button>
                ))}
              </div>

              {/* Tableau */}
              {membershipOverview.length === 0 ? (
                <EmptyState message={t({ id: 'panel.memberships.empty' })} />
              ) : (
                <div style={{ borderRadius: 8, overflow: 'hidden', border: '1px solid rgba(255,255,255,.08)' }}>
                  {membershipOverview
                    .filter(m => membershipFilter === 'all' || m.dues_status === membershipFilter)
                    .map((m, i) => {
                      const status = fmtMembershipStatus(m.dues_status, m.days_until_expiry);
                      return (
                        <div key={m.user_id} style={{ padding: '10px 12px', background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent', borderBottom: '1px solid rgba(255,255,255,.04)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
                          <div style={{ flex: 1, minWidth: 220 }}>
                            <div style={{ fontSize: '.9rem', fontWeight: 600 }}>
                              {m.display_name}
                              {m.public_id && <span style={{ fontWeight: 400, color: 'var(--brand-muted)', marginLeft: 6 }}>· {m.public_id}</span>}
                              {m.is_restricted && <Pill variant="danger" style={{ marginLeft: 6, fontSize: '.65rem' }}>⛔</Pill>}
                            </div>
                            <div style={{ fontSize: '.8rem', color: 'var(--brand-muted)', marginTop: 2 }}>
                              {m.email}
                              {m.last_paid_at && <> · {t({ id: 'membership.payment.lastPaid' }, { date: fmtD(m.last_paid_at) })}</>}
                              {m.last_amount_paid > 0 && <> · {m.last_amount_paid} {m.last_currency}</>}
                            </div>
                          </div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                            <Pill variant={status.variant}>{status.label}</Pill>
                            {status.detail && <span style={{ fontSize: '.78rem', color: 'var(--brand-muted)' }}>{status.detail}</span>}
                            <Button onClick={() => openPaymentModal({ user_id: m.user_id, display_name: m.display_name })} disabled={membershipRules.length === 0}>
                              + {t({ id: 'membership.action.recordPayment' })}
                            </Button>
                          </div>
                        </div>
                      );
                    })}
                </div>
              )}
            </div>
          )}

          {/* ═══ Modal d'enregistrement de paiement ═══════════════ */}
          {paymentModal && paymentDraft && (
            <div onClick={closePaymentModal} style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.6)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
              <div onClick={e => e.stopPropagation()} style={{ background: 'var(--brand-bg, #1a1a1a)', borderRadius: 12, padding: 20, maxWidth: 500, width: '100%', border: '1px solid rgba(255,255,255,.1)', maxHeight: '90vh', overflow: 'auto' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                  <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 700 }}>{t({ id: 'membership.payment.modalTitle' })}</h3>
                  <button onClick={closePaymentModal} style={{ background: 'none', border: 'none', color: 'var(--brand-muted)', fontSize: '1.4rem', cursor: 'pointer', padding: 0, lineHeight: 1 }}>×</button>
                </div>
                <div style={{ fontSize: '.88rem', color: 'var(--brand-muted)', marginBottom: 12 }}>
                  {t({ id: 'membership.payment.forReader' }, { name: paymentModal.display_name })}
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  <label style={{ fontSize: '.85rem', fontWeight: 600 }}>
                    {t({ id: 'membership.payment.rule' })}
                    <select
                      value={paymentDraft.rule_id || ''}
                      onChange={e => onPaymentRuleChange(e.target.value)}
                      className="ab-painel-input"
                      style={{ marginTop: 4 }}
                    >
                      {membershipRules.map(r => (
                        <option key={r.id} value={r.id}>
                          {r.name} — {r.amount_min > 0 ? `${r.amount_min} ${r.currency} min` : t({ id: 'membership.rule.freePrice' })}
                        </option>
                      ))}
                    </select>
                  </label>

                  <label style={{ fontSize: '.85rem', fontWeight: 600 }}>
                    {t({ id: 'membership.payment.amount' })}
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={paymentDraft.amount_paid}
                      onChange={e => setPaymentDraft(p => ({ ...p, amount_paid: e.target.value }))}
                      className="ab-painel-input"
                      style={{ marginTop: 4 }}
                    />
                  </label>

                  <label style={{ fontSize: '.85rem', fontWeight: 600 }}>
                    {t({ id: 'membership.payment.method' })}
                    <select
                      value={paymentDraft.payment_method}
                      onChange={e => setPaymentDraft(p => ({ ...p, payment_method: e.target.value }))}
                      className="ab-painel-input"
                      style={{ marginTop: 4 }}
                    >
                      <option value="cash">{t({ id: 'membership.method.cash' })}</option>
                      <option value="transfer">{t({ id: 'membership.method.transfer' })}</option>
                      <option value="card">{t({ id: 'membership.method.card' })}</option>
                      <option value="check">{t({ id: 'membership.method.check' })}</option>
                      <option value="in_kind">{t({ id: 'membership.method.in_kind' })}</option>
                      <option value="exemption">{t({ id: 'membership.method.exemption' })}</option>
                      <option value="other">{t({ id: 'membership.method.other' })}</option>
                    </select>
                  </label>

                  <label style={{ fontSize: '.85rem', fontWeight: 600 }}>
                    {t({ id: 'membership.payment.paidAt' })}
                    <input
                      type="date"
                      value={paymentDraft.paid_at}
                      onChange={e => setPaymentDraft(p => ({ ...p, paid_at: e.target.value }))}
                      className="ab-painel-input"
                      style={{ marginTop: 4 }}
                    />
                  </label>

                  <label style={{ fontSize: '.85rem', fontWeight: 600 }}>
                    {t({ id: 'membership.payment.notes' })}
                    <textarea
                      rows={2}
                      value={paymentDraft.notes || ''}
                      onChange={e => setPaymentDraft(p => ({ ...p, notes: e.target.value }))}
                      className="ab-painel-input"
                      placeholder={t({ id: 'membership.payment.notesPlaceholder' })}
                      style={{ marginTop: 4, fontFamily: 'inherit', resize: 'vertical' }}
                    />
                  </label>

                  {paymentMsg && (
                    <div style={{ padding: '8px 12px', borderRadius: 6, fontSize: '.85rem', background: paymentMsg.startsWith('Erro') || paymentMsg.includes('error') ? 'rgba(220,38,38,.1)' : 'rgba(74,222,128,.1)', color: paymentMsg.startsWith('Erro') || paymentMsg.includes('error') ? '#f87171' : '#4ade80' }}>
                      {paymentMsg}
                    </div>
                  )}

                  <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                    <Button onClick={submitPayment} disabled={paymentSaving}>
                      {paymentSaving ? t({ id: 'common.saving' }) : t({ id: 'membership.payment.submit' })}
                    </Button>
                    <Button variant="secondary" onClick={closePaymentModal} disabled={paymentSaving}>
                      {t({ id: 'common.cancel' })}
                    </Button>
                  </div>
                </div>
              </div>
            </div>
          )}

        </div>
      </div>
      <Footer />
    </PageShell>
  );
}

function SummaryCard({ label, count, variant = 'default' }) {
  return (
    <div className={`ab-painel-summary ab-painel-summary--${variant}`}>
      <span className="ab-painel-summary__count">{count}</span>
      <span className="ab-painel-summary__label">{label}</span>
    </div>
  );
}

function TaskBucket({ title, tasks, setTab, onTaskAction }) {
  const { formatMessage: t } = useIntl();
  return (
    <div className="ab-painel-task-bucket">
      <h3 className="ab-painel-h3">{title} ({tasks.length})</h3>
      <div className="ab-painel-items">
        {tasks.map((tk, i) => (
          <div key={i} className={`ab-painel-item ${tk.priority === 'alta' ? 'ab-painel-item--overdue' : ''}`}>
            <div>
              <span className="ab-painel-item__title">{tk.kind}</span>
              <span className="ab-painel-item__meta">{tk.label}</span>
              <span className="ab-painel-item__meta">{tk.detail}</span>
            </div>
            <div className="ab-painel-item__btn-row">
              <span className={`ab-painel-task-priority ab-painel-task-priority--${tk.priority}`}>
                {tk.priority === 'alta' ? t({id:'panel.task.priority.high'}) : t({id:'panel.task.priority.normal'})}
              </span>
              {tk.actionType === 'reserva' && (
                <button className="ab-button ab-button--mini" onClick={() => setTab('reservas')}>{t({ id: 'panel.openReservations' })}</button>
              )}
              {tk.actionType === 'emprestimo' && (
                <button className="ab-button ab-button--mini" onClick={() => setTab('emprestimos-livro')}>{t({ id: 'panel.openLoans' })}</button>
              )}
              {tk.actionType === 'consulta' && (
                <button className="ab-button ab-button--mini" onClick={() => setTab('consultas-locais')}>{t({ id: 'panel.openConsultations' })}</button>
              )}
              {tk.actionType === 'tarefa' && (
                <select style={{ fontSize:'.78rem', padding:'3px 6px', borderRadius:6, border:'1px solid rgba(255,255,255,.15)', background:'rgba(0,0,0,.3)', color:'#f4f4f4' }}
                  defaultValue="" onChange={async e => {
                    if (!e.target.value) return;
                    await supabase.from('painel_internal_tasks').update({ status: e.target.value }).eq('id', tk.task_id);
                    if (onTaskAction) onTaskAction();
                    e.target.value = '';
                  }}>
                  <option value="">{t({ id: 'panel.tasks.advance' })}</option>
                  <option value="em_andamento">{t({ id: 'task.status.em_andamento' })}</option>
                  <option value="concluida">{t({ id: 'task.status.concluida' })}</option>
                  <option value="cancelada">{t({ id: 'task.status.cancelada' })}</option>
                </select>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
