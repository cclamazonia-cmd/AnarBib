import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import LibraryProfileBanner from '@/components/LibraryProfileBanner';
import TransitionsPanel from '@/components/TransitionsPanel';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import RetentionPolicySection from '@/components/library/RetentionPolicySection';
import LibraryVisualAssetsSection from '@/components/library/LibraryVisualAssetsSection';
import DocumentGovernanceSection from '@/components/library/DocumentGovernanceSection';
import PolicySetManager from '@/components/library/PolicySetManager';
import RegimeStateBox from '@/components/library/RegimeStateBox';
import WorkspaceInspectorModal from '@/components/library/WorkspaceInspectorModal';
import ExchangeProposalForm from '@/components/library/ExchangeProposalForm';
import ExchangeRequestsList from '@/components/library/ExchangeRequestsList';
import ExchangeFollowupPanel from '@/components/library/ExchangeFollowupPanel';
import LibraryContactProfileSection from '@/components/library/LibraryContactProfileSection';
import LibraryPublicContactSection from '@/components/library/LibraryPublicContactSection';
import LocaleSelector from '@/components/library/LocaleSelector';
import TeamPanel from '@/components/team/TeamPanel';
import LeitoresPanel from '@/components/biblioteca/LeitoresPanel';
import LibraryPartnershipsSection from '@/components/library/LibraryPartnershipsSection';
import PebHistorySection from '@/components/library/PebHistorySection';
import '@/components/team/TeamPanel.css';
import '../catalogacao/CatalogacaoPage.css';
import UserHeroBadge from '@/components/UserHeroBadge';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';

const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
// SERVICE_MODES built inside component with t() — was hardcoded pt-BR (audit 07/05/2026)
// TASK_PRIO   built inside component with t() — was hardcoded pt-BR (audit 07/05/2026)
// ILL_STATUS built inside component with t()
// TASK_STATUS built inside component with t()

// NOTIFICATION_FLAGS keys — labels resolved via t() inside the component
const NOTIFICATION_FLAG_KEYS = [
  'reservation_created', 'reservation_status', 'reservation_workflow', 'local_consultation',
  'loan_lifecycle', 'loan_reminders', 'loan_overdue', 'mid_loan_message',
  'profile_restriction', 'reading_recommendations', 'cotisation_payment_mail',
  'admin_copy_reservations', 'admin_copy_loans', 'tech_alerts', 'task_alerts',
];

export default function BibliotecaPage() {
  const { user } = useAuth();
  const { libraryId, libraryName, role, governance_mode } = useLibrary();
  const { formatMessage: t, locale } = useIntl();
  // i18n titres/descriptions de taches-types et taches : jsonb {locale: texte}
  // herite du catalogue. Repli locale courante -> pt-BR -> 1re cle -> texte simple.
  const localizedText = (obj, fallback) => {
    if (obj && typeof obj === 'object') {
      const v = obj[locale] || obj['pt-BR'] || Object.values(obj).find(x => x && String(x).trim());
      if (v && String(v).trim()) return v;
    }
    return fallback || '';
  };
  useDocumentTitle(t({ id: 'pageTitle.biblioteca' }));
  const roleLoaded = role !== null && role !== undefined;
  const isCoord = role === 'coordenador' || role === 'administrador';
  const isLibrarian = role === 'librarian' || isCoord;

  // SERVICE_MODES localized via t() — was hardcoded pt-BR before audit 07/05/2026.
  const SERVICE_MODES = useMemo(() => ([
    { value: 'funcionamento_normal',   label: t({ id: 'rede.serviceMode.funcionamento_normal' }) },
    { value: 'funcionamento_reduzido', label: t({ id: 'rede.serviceMode.funcionamento_reduzido' }) },
    { value: 'recesso',                label: t({ id: 'rede.serviceMode.recesso' }) },
    { value: 'suspenso',               label: t({ id: 'rede.serviceMode.suspenso' }) },
  ]), [t]);

  // TASK_PRIO localized via t() — was hardcoded pt-BR before audit 07/05/2026.
  const TASK_PRIO = useMemo(() => ({
    alta:   t({ id: 'biblioteca.tasks.priority.alta' }),
    normal: t({ id: 'biblioteca.tasks.priority.normal' }),
    baixa:  t({ id: 'biblioteca.tasks.priority.baixa' }),
  }), [t]);

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
    { id: 'privacy', label: t({ id: 'biblioteca.tab.privacy' }) },
    { id: 'documents', label: t({ id: 'biblioteca.tab.documents' }), coordOnly: true },
    // Paquet E.5 refactor (20/05/2026) : transitions de profil (gouvernance politique)
    { id: 'transicoes', label: t({ id: 'biblioteca.tab.transitions' }), coordOnly: true, governance_only: true },
    { id: 'team', label: t({ id: 'biblioteca.tab.team' }) },
    { id: 'leitores', label: t({ id: 'biblioteca.tab.leitores' }) },
    { id: 'exchanges', label: t({ id: 'biblioteca.tab.exchanges' }), separator: true },
    { id: 'ill', label: t({ id: 'biblioteca.tab.ill' }) },
    { id: 'reports', label: t({ id: 'biblioteca.tab.reports' }) },
    { id: 'tasks', label: t({ id: 'biblioteca.tab.tasks' }) },
  ];
  // FIX BUG #4: rename loop variable to avoid shadowing `t` (formatMessage)
  // Paquet E.5 refactor (20/05/2026) : filtrer aussi par governance_mode
  // pour l'onglet transicoes (visible si staff_roles ou full_governance).
  const hasStructuredGovernance = governance_mode === 'staff_roles' || governance_mode === 'full_governance';
  const visibleTabs = ALL_TABS.filter(tb => {
    if (tb.coordOnly && !isCoord) return false;
    if (tb.governance_only && !hasStructuredGovernance) return false;
    return true;
  });

  const [tab, setTab] = useState(isCoord ? 'identity' : 'team');
  const [wsInspectorOpen, setWsInspectorOpen] = useState(false);
  const [refreshState, setRefreshState] = useState('idle');
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [saving, setSaving] = useState(false);
  const regFileRef = useRef(null);

  // ── Dados ───────────────────────────────────────────────
  const [lib, setLib] = useState(null);
  // Paquet G refactor (20/05/2026) : profile_template_chosen pour decider de
  // l'affichage du LibraryProfileBanner. Charge en parallele des autres datas.
  const [profileTemplateChosen, setProfileTemplateChosen] = useState(undefined);
  useEffect(() => {
    if (!libraryId) { setProfileTemplateChosen(undefined); return; }
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase
          .from('libraries')
          .select('profile_template_chosen')
          .eq('id', libraryId)
          .maybeSingle();
        if (!cancelled) setProfileTemplateChosen(data?.profile_template_chosen ?? null);
      } catch (e) {
        if (!cancelled) setProfileTemplateChosen(null);
      }
    })();
    return () => { cancelled = true; };
  }, [libraryId]);
  const [commons, setCommons] = useState(null);
  const [serviceState, setServiceState] = useState(null);
  const [regDocs, setRegDocs] = useState([]);
  const [docGov, setDocGov] = useState(null);
  // members reste chargé : utilisé par generateReportText() même si l'onglet team
  // affiche désormais <TeamPanel /> qui charge ses propres données.
  const [members, setMembers] = useState([]);
  const [illLoans, setIllLoans] = useState([]);
  const [exchanges, setExchanges] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [stats, setStats] = useState({ books:0, authors:0, exemplars:0, readers:0, loansOpen:0, loansOverdue:0, loansCreated7d:0, loansReturned7d:0, loansCreated30d:0, reservationsActive:0, reservations30d:0, consultationsActive:0, trocasActive:0, librariansActive:0, topBooks:[] });
  const [mailChannel, setMailChannel] = useState(null);
  const [notifPolicy, setNotifPolicy] = useState(null);
  // Cotisation (membership)
  const [membershipRules, setMembershipRules] = useState([]);
  const [editingMembershipRule, setEditingMembershipRule] = useState(null); // null = aucun, 'new' = nouveau, ou {id,...} pour édition
  const [newTask, setNewTask] = useState({ title: '', description: '', priority: 'normal', owner: '' });
  // Chantier #TASKS etape 6 (24/05/2026) : sous-onglets de l'onglet « Tarefas
  // internas ». Paquet 1 ne remplit que 'lista' (vue par echeance + drapeau
  // stale) ; 'modelos' et 'catalogo' sont des placeholders, remplis aux
  // paquets 2 et 3.
  const [tasksSubtab, setTasksSubtab] = useState('lista');
  // Chantier #TASKS etape 6 paquet 2 (24/05/2026) : tâches-types locales.
  // templates = liste chargee depuis painel_recurring_task_rules.
  // editingTemplate = null (aucun) | 'new' (creation) | {id,...} (edition).
  // instantiateFor = id du modele dont le mini-formulaire d'echeance est
  // ouvert (un seul a la fois), null sinon. instantiateDate = sa date.
  const [templates, setTemplates] = useState([]);
  const [editingTemplate, setEditingTemplate] = useState(null);
  const [instantiateFor, setInstantiateFor] = useState(null);
  const [instantiateDate, setInstantiateDate] = useState('');
  // Chantier #TASKS etape 6 paquet 3 (24/05/2026) : catalogue de suggestions.
  // suggestions = painel_task_suggestion_catalog (global, lecture seule).
  // Le texte des suggestions vit dans la donnee (title_i18n/description_i18n
  // jsonb 8 langues) ; seule l'ossature du sous-onglet a des cles i18n.
  const [suggestions, setSuggestions] = useState([]);
  const [allLibraries, setAllLibraries] = useState([]);
  const [illForm, setIllForm] = useState({ lender:'', borrower:'', status:'preparacao', contactName:'', contactEmail:'', startDate:'', dueDate:'', logisticsNote:'', meetingPoint:'', logisticsMode:'' });
  const [illItems, setIllItems] = useState([]);
  const [illDocSearch, setIllDocSearch] = useState('');
  const [illDocResults, setIllDocResults] = useState([]);
  // #ILL-partial — exemplaires des prêts DÉJÀ enregistrés (distinct de illItems,
  // qui est le panier du formulaire de création). Dictionnaire { loanId: [items] }.
  const [illItemsByLoan, setIllItemsByLoan] = useState({});
  // Prêts dont le bloc d'exemplaires est déplié (Set d'ids).
  const [illExpanded, setIllExpanded] = useState(() => new Set());
  // Pointages de retour en cours de saisie, par prêt :
  // { [loanId]: { [itemRowId]: { checked: bool, status: 'devolvido'|... } } }
  const [illReturnDraft, setIllReturnDraft] = useState({});
  // Feedback LOCAL au bloc de pointage, par prêt (option B) :
  // { [loanId]: { busy: bool, msg: string|null, kind: 'ok'|'error'|null } }
  const [illReturnFeedback, setIllReturnFeedback] = useState({});
  // EA-12 phase 2 (dette 2) : bibliotheques eligibles au PEB.
  // Regle alignee sur fn_peb_authorized : federee + circulation active + active.
  const pebEligibleLibraries = allLibraries.filter(l =>
    l.network_mode === 'federated'
    && l.circulation_mode && l.circulation_mode !== 'off'
    && l.is_active !== false
  );

  // ── Carregamento ────────────────────────────────────────
  const loadAll = useCallback(async () => {
    if (!libraryId) return;
    try {
      const [libR, commR, ssR, regR, psR, dgR, memR, illR, exR, taskR, mcR, npR, mrR, tplR, sugR] = await Promise.all([
        supabase.from('libraries').select('*').eq('id', libraryId).single(),
        supabase.from('library_commons').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_service_state').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_regulation_documents').select('*').eq('library_id', libraryId).order('created_at', { ascending: false }),
        supabase.from('library_circulation_policy_sets').select('*').eq('library_id', libraryId).eq('is_active', true).maybeSingle(),
        supabase.from('library_document_governance').select('*').eq('library_id', libraryId).maybeSingle(),
        // Chantier « Partenaires de correspondance » 24/05/2026 : le fetch
        // catalog_partners a ete retire d'ici. L'editeur LibraryPartnershipsSection
        // (onglet documents) charge desormais lui-meme catalog_partners et la vue
        // api.library_partnerships_ui. Le state `partners` de la page est supprime.
        supabase.from('user_library_memberships').select('*, profiles:user_id(email, first_name, last_name)').eq('library_id', libraryId).order('created_at'),
        // #ILL-archive (25/05/2026) : la file active exclut les PEB archivés.
        // Les PEB archivés sont consultables dans l'onglet Rapports via le
        // composant PebHistorySection (vue api.peb_history_v1).
        supabase.from('interlibrary_loans_v2').select('*').or(`lender_library_id.eq.${libraryId},borrower_library_id.eq.${libraryId}`).is('archived_at', null).order('created_at', { ascending: false }).limit(50),
        // #EA-11 : trocas (intercâmbios) impliquant la bibliothèque (requérante
        // ou cible), pour la section Trocas du compte-rendu. Lecture simple
        // protégée par la RLS (doctrine RPC v3 : from() autorisé en lecture).
        supabase.from('document_permission_requests').select('id, requester_library_id, target_library_id, status, created_at, decided_at, object_ref').eq('object_type', 'interlibrary_exchange').or(`requester_library_id.eq.${libraryId},target_library_id.eq.${libraryId}`).order('created_at', { ascending: false }).limit(200),
        supabase.from('painel_internal_tasks').select('*').eq('library_id', libraryId).order('created_at', { ascending: false }).limit(50),
        supabase.from('library_mail_channels').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_notification_policies').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_membership_rules').select('*').eq('library_id', libraryId).order('display_order', { ascending: true }).order('created_at', { ascending: true }),
        // Chantier #TASKS etape 6 paquet 2 : tâches-types. Lecture simple
        // protegee par la RLS painel_recurring_task_rules_select (doctrine
        // RPC v3 : from() autorise pour les lectures protegees par RLS).
        supabase.from('painel_recurring_task_rules').select('*').eq('library_id', libraryId).order('created_at', { ascending: false }),
        // Chantier #TASKS etape 6 paquet 3 : catalogue de suggestions. Table
        // globale (sans library_id), lecture seule reservee au staff par la
        // RLS painel_task_suggestion_catalog_select_staff.
        supabase.from('painel_task_suggestion_catalog').select('*').eq('is_active', true).order('display_order', { ascending: true }),
      ]);
      setLib(libR.data); setCommons(commR.data); setServiceState(ssR.data);
      setRegDocs(regR.data || []); setDocGov(dgR.data);
      setMembers(memR.data || []);
      setIllLoans(illR.data || []); setExchanges(exR.data || []); setTasks(taskR.data || []);
      setTemplates(tplR.data || []);
      setSuggestions(sugR.data || []);
      // #ILL-partial — charge les exemplaires de tous les prêts affichés,
      // regroupés par prêt. Lecture simple protégée par la RLS
      // interlibrary_loan_items_v2_select (doctrine RPC v3 : from() autorisé
      // pour les lectures protégées par RLS).
      const loanIds = (illR.data || []).map(l => l.id);
      if (loanIds.length > 0) {
        const { data: itemsData } = await supabase
          .from('interlibrary_loan_items_v2')
          .select('*')
          .in('interlibrary_loan_id', loanIds)
          .order('line_no', { ascending: true });
        const byLoan = {};
        for (const it of (itemsData || [])) {
          (byLoan[it.interlibrary_loan_id] ||= []).push(it);
        }
        setIllItemsByLoan(byLoan);
      } else {
        setIllItemsByLoan({});
      }
      setMailChannel(mcR.data); setNotifPolicy(npR.data);
      setMembershipRules(mrR.data || []);
      // Load all libraries for ILL selects
      const { data: allLibs } = await supabase.from('libraries').select('id, slug, name, short_name, network_mode, circulation_mode, is_active').order('name');
      setAllLibraries(allLibs || []);
      const [au, circStats] = await Promise.all([
        supabase.from('authors').select('id', { count: 'exact', head: true }),
        supabase.schema('api').from('library_circulation_stats').select('*').eq('library_id', libraryId).maybeSingle(),
      ]);
      const cs = circStats.data || {};
      setStats({
        // DOCUMENTOS = holdings de cette biblio (scope par library_id via la vue).
        // Anciennement count(*) sur books sans filtre -> comptait tout le reseau (bug).
        books: cs.holdings_count || 0, authors: au.count || 0,
        exemplars: cs.exemplars_count || 0, readers: cs.readers_active || 0,
        loansOpen: cs.loans_open || 0, loansOverdue: cs.loans_overdue || 0,
        loansCreated7d: cs.loans_created_7d || 0, loansReturned7d: cs.loans_returned_7d || 0,
        loansCreated30d: cs.loans_created_30d || 0,
        reservationsActive: cs.reservations_active || 0, reservations30d: cs.reservations_30d || 0,
        consultationsActive: cs.consultations_active || 0,
        trocasActive: cs.trocas_active || 0,
        librariansActive: cs.librarians_active || 0,
        topBooks: cs.top_books_90d || [],
      });
    } catch (err) { console.warn('loadAll:', err); }
  }, [libraryId]);

  useEffect(() => { loadAll(); }, [loadAll]);

  // Correctif EA-02 : recharge avec feedback visuel (busy -> done -> idle).
  const handleRefresh = useCallback(async () => {
    if (refreshState === 'busy') return;
    setRefreshState('busy');
    try {
      await loadAll();
      setRefreshState('done');
      setTimeout(() => setRefreshState('idle'), 2000);
    } catch {
      setRefreshState('idle');
    }
  }, [loadAll, refreshState]);

  // ── Save helpers ────────────────────────────────────────
  function setL(k,v){ setLib(p=>p?{...p,[k]:v}:p); }
  function setC(k,v){ setCommons(p=>p?{...p,[k]:v}:p); }
  function setSS(k,v){ setServiceState(p=>p?{...p,[k]:v}:p); }
  function setMC(k,v){ setMailChannel(p=>p?{...p,[k]:v}:p); }

  // Helper i18n : pour les seeds système (system_seed_key non-NULL), tente de
  // traduire via i18n applicative ; sinon retombe sur le texte stocké en base.
  // Usage : seedT(rule, 'rule_label', 'rule.label') → cherche
  // `circulation.systemRule.{key}.label` ; si pas trouvée, retourne rule.rule_label.
  function seedT(entity, fallbackField, i18nSubKey) {
    if (entity?.system_seed_key) {
      const fullKey = `circulation.${i18nSubKey.startsWith('set.') ? 'systemSet' : 'systemRule'}.${entity.system_seed_key}.${i18nSubKey.split('.').pop()}`;
      const translated = t({ id: fullKey, defaultMessage: '__MISSING__' });
      if (translated !== '__MISSING__') return translated;
    }
    return entity?.[fallbackField];
  }
  function setNP(k,v){ setNotifPolicy(p=>p?{...p,[k]:v}:p); }

  async function saveTable(table, data, filterCol = 'library_id') {
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.from(table).update(data).eq(filterCol, libraryId);
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.msg.saved' }), kind: 'ok' });
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function saveIdentity() {
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      // PATCH 09/05/2026 paquet 6.3 : default_locale ajouté à l'update.
      // C'est l'identité linguistique de la biblio, configurable depuis le
      // sélecteur ajouté dans la grille identité (champ après country).
      await supabase.from('libraries').update({ name:lib.name, short_name:lib.short_name, city:lib.city, state:lib.state, country:lib.country, default_locale:lib.default_locale||'pt-BR', reader_cards_enabled:lib.reader_cards_enabled===true }).eq('id', libraryId);
      if (commons) await supabase.from('library_commons').update({ display_name:commons.display_name, contact_email:commons.contact_email, reply_to_email:commons.reply_to_email, postal_address:commons.postal_address }).eq('library_id', libraryId);
      if (serviceState) await supabase.from('library_service_state').update({ service_mode:serviceState.service_mode, allows_new_loans:serviceState.allows_new_loans, allows_new_reservations:serviceState.allows_new_reservations, public_message:serviceState.public_message }).eq('library_id', libraryId);
      setMsg({ text: t({ id: 'biblioteca.msg.saved' }), kind: 'ok' });
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function saveComms() {
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      if (commons) await supabase.from('library_commons').update({ display_name:commons.display_name, contact_email:commons.contact_email, reply_to_email:commons.reply_to_email, email_delivery_mode:commons.email_delivery_mode }).eq('library_id', libraryId);
      if (mailChannel) await supabase.from('library_mail_channels').update({ admin_notification_email:mailChannel.admin_notification_email, weekly_report_email:mailChannel.weekly_report_email, severe_alert_email:mailChannel.severe_alert_email, delivery_mode:mailChannel.delivery_mode }).eq('library_id', libraryId);
      if (notifPolicy) {
        // PATCH 08/05/2026 paquet 3A : sauvegarde aussi les 2 paramètres de
        // négociation symétrique (toggle + timeout). Validation timeout côté
        // frontend (la DB a aussi un CHECK 7..60 en défense en profondeur).
        const timeoutDays = Number(notifPolicy.reservation_negotiation_timeout_days);
        if (Number.isFinite(timeoutDays) && (timeoutDays < 7 || timeoutDays > 60)) {
          throw new Error(t({ id: 'biblioteca.reservation.timeoutDays.outOfRange' }));
        }
        const flags = {}; NOTIFICATION_FLAG_KEYS.forEach(k => { flags[k + '_enabled'] = notifPolicy[k + '_enabled'] || false; });
        await supabase.from('library_notification_policies').update({
          ...flags,
          reservation_allow_reader_counter_proposal: notifPolicy.reservation_allow_reader_counter_proposal ?? true,
          reservation_negotiation_timeout_days: Number.isFinite(timeoutDays) ? timeoutDays : 21,
          updated_by: user?.id
        }).eq('library_id', libraryId);
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
        version_label: t({ id: 'biblioteca.regulation.versionPrefix' }, { date: new Date().toLocaleDateString(locale) }),
        created_by: user?.id,
      });
      if (insErr) throw insErr;
      setMsg({ text: t({ id: 'biblioteca.regulation.published' }), kind: 'ok' });
      regFileRef.current.value = '';
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  // ── Create task ─────────────────────────────────────────
  async function createTask() {
    if (!newTask.title.trim()) { setMsg({ text: t({ id: 'biblioteca.tasks.titleRequired' }), kind: 'error' }); return; }
    try {
      // EA-15 (21/05/2026) : bascule sur fn_task_create (RPC).
      // Les defaults backend ('pendente' pour status, '{}' pour tags) sont
      // appliques cote RPC si les params sont absents ou vides.
      const tags = (newTask.tagsText || '').split(',').map(tag => tag.trim()).filter(Boolean);
      const { error } = await supabase.rpc('fn_task_create', {
        p_library_id: libraryId,
        p_title: newTask.title.trim(),
        p_description: newTask.description.trim() || null,
        p_priority: newTask.priority || 'media',
        p_owner: newTask.owner.trim() || null,
        p_due_date: newTask.dueDate || null,
        p_tags: tags,
      });
      if (error) throw error;
      setNewTask({ title: '', description: '', priority: 'media', owner: '', dueDate: '', tagsText: '' });
      setMsg({ text: t({ id: 'biblioteca.tasks.created' }), kind: 'ok' });
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
  }

  async function updateTaskStatus(taskId, status) {
    // EA-15 (21/05/2026) : bascule sur fn_task_update_status (RPC).
    try {
      const { error } = await supabase.rpc('fn_task_update_status', {
        p_task_id: taskId,
        p_new_status: status,
      });
      if (error) throw error;
      await loadAll();
    } catch (err) {
      setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' });
    }
  }

  // ── Tâches-types : CRUD + instanciation (chantier #TASKS p2) ─────────
  // Toutes les ecritures passent par les RPC fn_recurring_task_rule_*
  // (doctrine RPC v3 : RPC obligatoire pour les ecritures avec validation
  // metier). La distinction recurrent / ponctuel est portee par un champ
  // `recurrent` (bool) dans le formulaire ; cote RPC, un modele recurrent
  // exige interval_count + interval_unit, un ponctuel les laisse NULL.

  // Ouvre le formulaire en mode creation, avec des valeurs par defaut.
  function startNewTemplate() {
    setEditingTemplate({
      id: 'new', template_title: '', template_description: '',
      template_priority: 'media', tagsText: '', label: '',
      recurrent: false, interval_count: 1, interval_unit: 'semana',
      is_active: true,
    });
    setMsg({ text: '', kind: '' });
  }

  // Ouvre le formulaire en mode edition pour un modele existant.
  function startEditTemplate(tpl) {
    setEditingTemplate({
      id: tpl.id,
      template_title: tpl.template_title || '',
      template_description: tpl.template_description || '',
      template_priority: tpl.template_priority || 'media',
      tagsText: (tpl.template_tags || []).join(', '),
      label: tpl.label || '',
      recurrent: tpl.interval_count != null && tpl.interval_unit != null,
      interval_count: tpl.interval_count || 1,
      interval_unit: tpl.interval_unit || 'semana',
      is_active: tpl.is_active !== false,
    });
    setMsg({ text: '', kind: '' });
  }

  function cancelEditTemplate() { setEditingTemplate(null); }

  async function saveTemplate() {
    if (!editingTemplate) return;
    const e = editingTemplate;
    if (!e.template_title.trim()) {
      setMsg({ text: t({ id: 'biblioteca.templates.titleRequired' }), kind: 'error' });
      return;
    }
    const tags = (e.tagsText || '').split(',').map(s => s.trim()).filter(Boolean);
    // Modele ponctuel => cadence NULL ; recurrent => les deux champs.
    const intervalCount = e.recurrent ? Number(e.interval_count) || null : null;
    const intervalUnit  = e.recurrent ? e.interval_unit : null;
    setSaving(true);
    try {
      if (e.id === 'new') {
        const { error } = await supabase.rpc('fn_recurring_task_rule_create', {
          p_library_id: libraryId,
          p_template_title: e.template_title.trim(),
          p_template_description: e.template_description.trim() || null,
          p_template_priority: e.template_priority || 'media',
          p_template_tags: tags,
          p_label: e.label.trim() || null,
          p_interval_count: intervalCount,
          p_interval_unit: intervalUnit,
        });
        if (error) throw error;
        setMsg({ text: t({ id: 'biblioteca.templates.created' }), kind: 'ok' });
      } else {
        const { error } = await supabase.rpc('fn_recurring_task_rule_update', {
          p_template_id: e.id,
          p_template_title: e.template_title.trim(),
          p_template_description: e.template_description.trim() || null,
          p_template_priority: e.template_priority || 'media',
          p_template_tags: tags,
          p_label: e.label.trim() || null,
          p_interval_count: intervalCount,
          p_interval_unit: intervalUnit,
          p_is_active: e.is_active,
        });
        if (error) throw error;
        setMsg({ text: t({ id: 'biblioteca.templates.saved' }), kind: 'ok' });
      }
      setEditingTemplate(null);
      await loadAll();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  async function deleteTemplate(tpl) {
    if (!confirm(t({ id: 'biblioteca.templates.deleteConfirm' }, { title: tpl.template_title || '—' }))) return;
    setSaving(true);
    try {
      const { error } = await supabase.rpc('fn_recurring_task_rule_delete', { p_template_id: tpl.id });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.templates.deleted' }), kind: 'ok' });
      await loadAll();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // Instancie une tache depuis un modele. p_due_date optionnel : si vide,
  // la tache nait sans echeance (seau « Sem prazo »). Pour un modele
  // recurrent, fournir une date donne le point de depart de la serie.
  async function instantiateTemplate(templateId, dueDate) {
    try {
      const { error } = await supabase.rpc('fn_task_instantiate_template', {
        p_template_id: templateId,
        p_due_date: dueDate || null,
      });
      if (error) throw error;
      setInstantiateFor(null);
      setInstantiateDate('');
      setMsg({ text: t({ id: 'biblioteca.templates.instantiated' }), kind: 'ok' });
      await loadAll();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    }
  }

  // Adopte une suggestion du catalogue : la RPC fn_task_adopt_suggestion copie
  // la suggestion en tache-type locale (painel_recurring_task_rules). On passe
  // la locale courante pour que le titre/description copies soient dans la
  // langue de l'interface ; le backend retombe sur pt-BR si la cle manque.
  async function adoptSuggestion(code) {
    try {
      const { error } = await supabase.rpc('fn_task_adopt_suggestion', {
        p_suggestion_code: code,
        p_library_id: libraryId,
        p_locale: locale || 'pt-BR',
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.catalog.adopted' }), kind: 'ok' });
      await loadAll();
      // La tache-type bascule dans le sous-onglet « modeles » et disparait du
      // catalogue ; on y amene directement l'utilisateur·rice.
      setTasksSubtab('modelos');
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    }
  }

  // ── ILL: search documents for item adding ───────────────
  async function searchIllDocs() {
    if (!illDocSearch.trim()) return;
    // #ILL-search-scope + #ILL-availability : la recherche exige la
    // bibliotheque prêteuse (fn_peb_search_exemplares filtre sur elle et
    // sur la disponibilite). Sans prêteuse choisie, on ne cherche pas.
    if (!illForm.lender) {
      setMsg({ text: t({ id: 'biblioteca.ill.pickLenderFirst' }), kind: 'error' });
      return;
    }
    // EA-12 phase 2 (dette 4) - correctif : la recherche passe par la RPC
    // fn_peb_search_exemplares (exemplares -> book_holdings -> books).
    const { data, error } = await supabase.rpc('fn_peb_search_exemplares', {
      p_query: illDocSearch.trim(),
      p_lender_library_id: illForm.lender,
    });
    if (error) {
      setIllDocResults([]);
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: error.message }), kind: 'error' });
      return;
    }
    setIllDocResults(data || []);
  }

  // EA-12 phase 2 (dette 4) : un item PEB est un EXEMPLAIRE physique precis.
  // On stocke item_id (= exemplar_id), holding_id et book_id, tous exiges
  // ou utilises par fn_peb_create_loan_with_items. La cle d'unicite est
  // l'exemplaire (item_id) : deux exemplaires d'un meme titre sont distincts.
  function addIllItem(ex) {
    if (illItems.find(it => it.item_id === ex.exemplar_id)) return;
    setIllItems(prev => [...prev, {
      item_id: ex.exemplar_id,
      holding_id: ex.holding_id,
      book_id: ex.book_id,
      bib_ref: ex.bib_ref,
      titulo: ex.titulo,
      autor: ex.autor,
      tombo: ex.tombo,
    }]);
  }

  function removeIllItem(itemId) { setIllItems(prev => prev.filter(it => it.item_id !== itemId)); }

  async function saveIll() {
    if (!illForm.lender || !illForm.borrower) { setMsg({ text: t({id:'biblioteca.ill.selectBoth'}), kind: 'error' }); return; }
    if (illForm.lender === illForm.borrower) { setMsg({ text: t({id:'biblioteca.ill.differentLibraries'}), kind: 'error' }); return; }
    // #ILL-front — champs obligatoires : contact de coordination, e-mail
    // valide, au moins un exemplaire, mode logistique choisi.
    if (!illForm.contactName.trim()) { setMsg({ text: t({id:'biblioteca.ill.contactRequired'}), kind: 'error' }); return; }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(illForm.contactEmail.trim())) { setMsg({ text: t({id:'biblioteca.ill.contactEmailInvalid'}), kind: 'error' }); return; }
    if (illItems.length === 0) { setMsg({ text: t({id:'biblioteca.ill.itemsRequired'}), kind: 'error' }); return; }
    if (!illForm.logisticsMode) { setMsg({ text: t({id:'biblioteca.ill.logisticsModeRequired'}), kind: 'error' }); return; }
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      // EA-12 phase 1 (21/05/2026) : bascule sur fn_peb_create_loan_with_items
      // pour atomicite loan+items et securite RLS heritee. La RPC valide
      // automatiquement user_can_manage_library + fn_peb_authorized.
      const payload_loan = {
        lender_library_id: illForm.lender,
        borrower_library_id: illForm.borrower,
        initiated_by_library_id: libraryId,
        status_global: illForm.status || 'preparacao',
        coordination_contact_name: illForm.contactName || null,
        coordination_contact_email: illForm.contactEmail || null,
        start_date: illForm.startDate || null,
        due_date: illForm.dueDate || null,
        notes: illForm.logisticsNote || null,
        // meeting_point n'a de sens que pour les modes de remise physique.
        meeting_point: (illForm.logisticsMode === 'entrega_em_maos'
                        || illForm.logisticsMode === 'transporte_militante')
                       ? (illForm.meetingPoint || null) : null,
        // #ILL-logistics : mode choisi par l'utilisateur·rice.
        logistics_mode: illForm.logisticsMode,
      };
      // EA-12 phase 2 (dette 4) : holding_id et item_id viennent desormais
      // reellement de l'exemplaire choisi (etaient undefined avant le patch).
      const payload_items = illItems.map((it, i) => ({
        line_no: i + 1,
        holding_id: it.holding_id,
        item_id: it.item_id,
        book_id: it.book_id || null,
        bib_ref: it.bib_ref,
        titulo_cache: it.titulo,
        autor_cache: it.autor,
        item_status: 'reservado_para_saida',
      }));
      const { data, error } = await supabase.rpc('fn_peb_create_loan_with_items', {
        p_loan: payload_loan,
        p_items: payload_items,
      });
      if (error) throw error;
      const newLoan = data?.loan;
      const newItems = data?.items || [];
      setMsg({ text: t({id:'biblioteca.ill.created'},{id:newLoan?.id,count:newItems.length}), kind: 'ok' });
      setIllForm({ lender:'', borrower:'', status:'preparacao', contactName:'', contactEmail:'', startDate:'', dueDate:'', logisticsNote:'', meetingPoint:'', logisticsMode:'' });
      setIllItems([]); setIllDocSearch(''); setIllDocResults([]);
      await loadAll();
    } catch (err) {
      // EA-12 phase 2 (dette 3) : un rejet RLS / fn_peb_authorized renvoie
      // un message Postgres technique. On le traduit en message clair :
      // le PEB exige que les deux bibliotheques soient federees.
      const raw = String(err?.message || '');
      const isAuthz = /row-level security|fn_peb_authorized|violates row-level|permission denied/i.test(raw);
      setMsg({
        text: isAuthz
          ? t({ id: 'biblioteca.ill.notAuthorized' })
          : t({ id: 'common.errorPrefix' }, { message: raw }),
        kind: 'error',
      });
    }
    finally { setSaving(false); }
  }

  async function updateIllStatus(loanId, newStatus) {
    // EA-12 phase 1 (21/05/2026) : bascule sur fn_peb_update_status (RPC).
    try {
      const { error } = await supabase.rpc('fn_peb_update_status', {
        p_loan_id: loanId,
        p_new_status: newStatus,
      });
      if (error) throw error;
      await loadAll();
    } catch (err) {
      setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' });
    }
  }

  // ── #ILL-partial : pointage du retour des exemplaires ─────
  // Statuts de prêt où le pointage d'un retour a un sens (aligné sur le
  // garde-fou de phase du trigger trg_peb_consolidate_loan_status).
  const ILL_RETURN_PHASES = ['emprestado', 'em_devolucao', 'atrasado', 'parcialmente_devolvido'];
  // Un exemplaire est « réglé » s'il a atteint une issue de retour.
  const ILL_ITEM_SETTLED = ['devolvido', 'perdido', 'danificado', 'cancelado'];

  function toggleIllExpanded(loanId) {
    setIllExpanded(prev => {
      const next = new Set(prev);
      next.has(loanId) ? next.delete(loanId) : next.add(loanId);
      return next;
    });
  }

  // Met à jour le brouillon de pointage d'un exemplaire (case cochée / statut).
  function setIllReturnField(loanId, itemRowId, field, value) {
    setIllReturnDraft(prev => {
      const loanDraft = { ...(prev[loanId] || {}) };
      const itemDraft = { ...(loanDraft[itemRowId] || { checked: false, status: 'devolvido' }) };
      itemDraft[field] = value;
      loanDraft[itemRowId] = itemDraft;
      return { ...prev, [loanId]: loanDraft };
    });
  }

  // Envoie le lot d'exemplaires cochés à la RPC fn_peb_update_item_status.
  // Feedback LOCAL au bloc (option B) : message + état occupé propres au prêt.
  async function submitIllItemReturn(loanId) {
    const loanDraft = illReturnDraft[loanId] || {};
    const p_items = Object.entries(loanDraft)
      .filter(([, d]) => d.checked)
      .map(([itemRowId, d]) => ({ id: Number(itemRowId), new_status: d.status }));
    if (p_items.length === 0) {
      setIllReturnFeedback(prev => ({ ...prev, [loanId]: {
        busy: false, kind: 'error',
        msg: t({ id: 'biblioteca.ill.return.nothingSelected' }),
      }}));
      return;
    }
    // État occupé : le bouton se désactive et affiche « Validation… ».
    setIllReturnFeedback(prev => ({ ...prev, [loanId]: { busy: true, msg: null, kind: null }}));
    try {
      const { data, error } = await supabase.rpc('fn_peb_update_item_status', {
        p_loan_id: loanId,
        p_items,
      });
      if (error) throw error;
      // La RPC renvoie { loan, items } : on lit le nouveau statut du prêt
      // pour le nommer dans le message de confirmation.
      const newStatus = data?.loan?.status_global || '';
      const statusLabel = newStatus
        ? t({ id: `ill.status.${newStatus}` })
        : '';
      setIllReturnDraft(prev => { const n = { ...prev }; delete n[loanId]; return n; });
      await loadAll();
      // Message de résultat : nombre traité + nouveau statut du prêt.
      setIllReturnFeedback(prev => ({ ...prev, [loanId]: {
        busy: false, kind: 'ok',
        msg: t({ id: 'biblioteca.ill.return.done' },
                { count: p_items.length, status: statusLabel }),
      }}));
    } catch (err) {
      setIllReturnFeedback(prev => ({ ...prev, [loanId]: {
        busy: false, kind: 'error',
        msg: t({ id: 'common.errorPrefix' }, { message: err.message }),
      }}));
    }
  }

  async function deleteIll(loanId) {
    if (!confirm(t({id:'biblioteca.ill.discardConfirm'},{id:loanId}))) return;
    try {
      // EA-12 phase 1 (21/05/2026) : bascule sur fn_peb_delete_loan (atomique).
      const { error } = await supabase.rpc('fn_peb_delete_loan', {
        p_loan_id: loanId,
      });
      if (error) throw error;
      setMsg({ text: t({id:'biblioteca.ill.discarded'},{id:loanId}), kind: 'ok' });
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
  }

  // #ILL-archive (25/05/2026) : archivage manuel d'un PEB terminé. Le PEB
  // sort de la file active et devient consultable dans l'onglet Rapports.
  // RPC fn_peb_archive_loan — réservée au staff, vérifie le statut terminal.
  async function archiveIllLoan(loanId) {
    if (!confirm(t({id:'biblioteca.ill.archiveConfirm'},{id:loanId}))) return;
    try {
      const { error } = await supabase.rpc('fn_peb_archive_loan', {
        p_loan_id: loanId,
      });
      if (error) throw error;
      setMsg({ text: t({id:'biblioteca.ill.archived'},{id:loanId}), kind: 'ok' });
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
  }

  // ── Generate report text ────────────────────────────────
  function generateReportText() {
    const now = new Date().toLocaleDateString();
    const libName = lib?.name || libraryName;
    const lines = [
      t({id:'biblioteca.report.headerLine'},{lib:libName}),
      t({id:'biblioteca.report.dateLine'},{date:now}),
      '',
      t({id:'biblioteca.report.docsInCatalog'},{count:stats.books}),
      t({id:'biblioteca.report.authorities'},{count:stats.authors}),
      t({id:'biblioteca.report.localExemplars'},{count:stats.exemplars}),
      t({id:'biblioteca.report.registeredReaders'},{count:stats.readers}),
      t({id:'biblioteca.report.openLoans'},{count:stats.loansOpen}),
      t({id:'biblioteca.report.reservationsActive'},{count:stats.reservationsActive}),
      t({id:'biblioteca.report.consultationsActive'},{count:stats.consultationsActive}),
      t({id:'biblioteca.report.librarians'},{count:members.filter(m => m.role === 'librarian').length}),
      '',
      t({id:'biblioteca.report.team'}) + ':',
      ...members.map(m => {
        const p = m.profiles || {};
        const personName = [p.first_name, p.last_name].filter(Boolean).join(' ') || p.email || '—';
        const roleLabel = (m.role === 'librarian' || m.role === 'reader' || m.role === 'coordenador' || m.role === 'administrador')
          ? t({id:`roles.${m.role}`})
          : m.role;
        return `  ${personName} — ${roleLabel}`;
      }),
      '',
      t({id:'biblioteca.report.tasks'}) + ':',
      ...(tasks.length ? tasks.map(tk => `  [${TASK_STATUS[tk.status] || tk.status}] ${tk.title} (${TASK_PRIO[tk.priority] || tk.priority})${tk.owner ? ` — ${tk.owner}` : ''}`) : ['  ' + t({id:'biblioteca.report.noTasksRegistered'})]),
      // #ILL-reports volet A : section PEB du compte-rendu. Chiffres dérivés
      // de illLoans (la file active exclut déjà les PEB archivés), puis liste
      // des PEB EN COURS uniquement (ni devolvido ni cancelado), avec le sens
      // du prêt, le partenaire et les titres des exemplaires.
      ...(() => {
        const ILL_TERMINAL = ['devolvido', 'cancelado'];
        const ongoing = illLoans.filter(l => !ILL_TERMINAL.includes(l.status_global));
        const overdue = illLoans.filter(l => l.status_global === 'atrasado');
        const terminalPending = illLoans.filter(l => ILL_TERMINAL.includes(l.status_global));
        const out = [
          '',
          t({id:'biblioteca.report.illSection'}) + ':',
          '  ' + t({id:'biblioteca.report.illOngoing'}, {count: ongoing.length}),
          '  ' + t({id:'biblioteca.report.illOverdue'}, {count: overdue.length}),
          '  ' + t({id:'biblioteca.report.illTerminalPending'}, {count: terminalPending.length}),
        ];
        if (ongoing.length) {
          out.push('  ' + t({id:'biblioteca.report.illOngoingList'}) + ':');
          for (const loan of ongoing) {
            const isLender = loan.lender_library_id === libraryId;
            const partnerId = isLender ? loan.borrower_library_id : loan.lender_library_id;
            const partnerLib = allLibraries.find(l => l.id === partnerId);
            const partnerName = partnerLib?.short_name || partnerLib?.name || '—';
            const sens = isLender
              ? t({id:'biblioteca.report.illLendTo'}, {partner: partnerName})
              : t({id:'biblioteca.report.illBorrowFrom'}, {partner: partnerName});
            const statusLabel = t({id:`ill.status.${loan.status_global}`});
            out.push(`    #${loan.id} — ${sens} — ${statusLabel}`);
            // titres des exemplaires : illItemsByLoan est chargé dans le meme
            // loadAll() que illLoans, donc toujours synchrone ici.
            const items = illItemsByLoan[loan.id] || [];
            if (items.length) {
              const titles = items
                .map(it => it.titulo_cache || it.bib_ref || '—')
                .join(' ; ');
              out.push(`      ${titles}`);
            }
          }
        }
        return out;
      })(),
      // #EA-11 : section Trocas du compte-rendu. Trois chiffres dérivés de
      // exchanges (trocas impliquant la bibliothèque, requérante ou cible) :
      // propostas (créées sur 7 jours), aceitas (acceptées sur 7 jours) et en
      // cours (acceptées dont la phase d'exécution n'est ni completed ni
      // cancelled — phase manquante/illisible = en cours).
      ...(() => {
        const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        const proposed = exchanges.filter(e => new Date(e.created_at) >= sevenDaysAgo).length;
        const accepted = exchanges.filter(e => e.status === 'accepted' && e.decided_at && new Date(e.decided_at) >= sevenDaysAgo).length;
        const ongoing = exchanges.filter(e => e.status === 'accepted' && (() => {
          try {
            const o = JSON.parse(e.object_ref || 'null');
            const ph = o && o.execution_followup && o.execution_followup.phase;
            return !['completed', 'cancelled'].includes(ph);
          } catch {
            return true;
          }
        })()).length;
        return [
          '',
          t({id:'biblioteca.report.exchangesSection'}) + ':',
          '  ' + t({id:'biblioteca.report.exchangesProposed'}, {count: proposed}),
          '  ' + t({id:'biblioteca.report.exchangesAccepted'}, {count: accepted}),
          '  ' + t({id:'biblioteca.report.exchangesOngoing'}, {count: ongoing}),
        ];
      })(),
    ];
    return lines.join('\n');
  }

  async function sendReport() {
    // EA-13 (etape 8) : envoi SERVEUR du rapport hebdomadaire via l'Edge Function
    // notify-weekly-report (Resend), debloque par la cloture de #110. Remplace le
    // placeholder mailto: historique. Destinataire resolu cote EF sur
    // weekly_report_email ; autorisation gardee par la RPC (staff de la biblio).
    const email = mailChannel?.weekly_report_email?.trim();
    if (!email) { setMsg({ text: t({id:'biblioteca.report.noWeeklyEmail'}), kind: 'error' }); return; }
    try {
      const { error } = await supabase.rpc('fn_send_weekly_report_now', { p_library_id: libraryId });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.report.sent' }, { email }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    }
  }

  // ── Task invite ─────────────────────────────────────────
  async function inviteToTask(taskId, email) {
    if (!email?.trim()) return;
    try {
      // EA-15 (21/05/2026) : bascule sur fn_task_invite (RPC intelligente).
      // La RPC ajoute l'email aux tags de la task, et le trigger
      // tg_sync_task_invites_from_task cree l'invite proprement.
      // Idempotente (si email deja dans tags, ne fait rien).
      const { error } = await supabase.rpc('fn_task_invite', {
        p_task_id: taskId,
        p_invite_email: email.trim(),
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.tasks.inviteSent' }, { email: email.trim() }), kind: 'ok' });
      await loadAll();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
  }

  // ── Cotisation (membership) ──────────────────────────
  async function toggleMembershipEnabled(next) {
    setSaving(true);
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.from('libraries').update({ membership_enabled: next }).eq('id', libraryId);
      if (error) throw error;
      setLib(prev => prev ? { ...prev, membership_enabled: next } : prev);
      setMsg({ text: t({ id: next ? 'membership.config.msg.enabledOn' : 'membership.config.msg.enabledOff' }), kind: 'ok' });
    } catch (e) { setMsg({ text: e.message, kind: 'error' }); }
    finally { setSaving(false); }
  }

  function startEditMembershipRule(rule) {
    setEditingMembershipRule({ ...rule, amount_suggested: rule.amount_suggested ?? '' });
    setMsg({ text: '', kind: '' });
  }

  function startNewMembershipRule() {
    setEditingMembershipRule({
      id: 'new',
      name: '',
      description: '',
      amount_min: 0,
      amount_suggested: '',
      currency: 'EUR',
      period_type: 'annual',
      period_anchor: 'rolling',
      is_required: true,
      is_active: true,
      display_order: membershipRules.length * 10,
    });
    setMsg({ text: '', kind: '' });
  }

  function cancelMembershipRule() {
    setEditingMembershipRule(null);
  }

  async function saveMembershipRule() {
    if (!editingMembershipRule) return;
    const r = editingMembershipRule;
    if (!r.name?.trim()) {
      setMsg({ text: t({ id: 'membership.config.rule.namePlaceholder' }), kind: 'error' });
      return;
    }
    if (Number(r.amount_min) < 0) {
      setMsg({ text: t({ id: 'membership.config.msg.minRequired' }), kind: 'error' });
      return;
    }
    setSaving(true);
    try {
      const payload = {
        library_id: libraryId,
        name: r.name.trim(),
        description: r.description?.trim() || null,
        amount_min: Number(r.amount_min) || 0,
        amount_suggested: r.amount_suggested === '' || r.amount_suggested === null
          ? null
          : Number(r.amount_suggested),
        currency: (r.currency || 'EUR').toUpperCase(),
        period_type: r.period_type,
        period_anchor: r.period_anchor,
        is_required: !!r.is_required,
        is_active: !!r.is_active,
        display_order: r.display_order ?? 0,
      };
      if (r.id === 'new') {
        const { data, error } = await supabase.from('library_membership_rules').insert(payload).select().single();
        if (error) throw error;
        setMembershipRules(prev => [...prev, data]);
        setMsg({ text: t({ id: 'membership.config.msg.created' }), kind: 'ok' });
      } else {
        const { data, error } = await supabase.from('library_membership_rules').update(payload).eq('id', r.id).select().single();
        if (error) throw error;
        setMembershipRules(prev => prev.map(x => x.id === r.id ? data : x));
        setMsg({ text: t({ id: 'membership.config.msg.saved' }), kind: 'ok' });
      }
      setEditingMembershipRule(null);
    } catch (e) { setMsg({ text: e.message, kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function toggleMembershipRuleActive(rule) {
    const willDeactivate = rule.is_active;
    if (willDeactivate && !confirm(t({ id: 'membership.config.action.deactivateConfirm' }))) return;
    setSaving(true);
    try {
      const { data, error } = await supabase.from('library_membership_rules')
        .update({ is_active: !rule.is_active }).eq('id', rule.id).select().single();
      if (error) throw error;
      setMembershipRules(prev => prev.map(x => x.id === rule.id ? data : x));
      setMsg({
        text: t({ id: willDeactivate ? 'membership.config.msg.deactivated' : 'membership.config.msg.reactivated' }),
        kind: 'ok',
      });
    } catch (e) { setMsg({ text: e.message, kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function deleteMembershipRule(rule) {
    // Confirm fort à 2 niveaux : avertissement + saisie du nom de la règle
    if (!confirm(t({ id: 'membership.config.action.deleteConfirm' }, { name: rule.name }))) return;
    const typed = prompt(t({ id: 'membership.config.action.deleteConfirmTyped' }, { name: rule.name }));
    if (typed !== rule.name) {
      if (typed !== null) setMsg({ text: t({ id: 'membership.config.action.deleteCancelled' }), kind: 'info' });
      return;
    }
    setSaving(true);
    try {
      const { error } = await supabase.from('library_membership_rules').delete().eq('id', rule.id);
      if (error) throw error;
      setMembershipRules(prev => prev.filter(x => x.id !== rule.id));
      setMsg({ text: t({ id: 'membership.config.msg.deleted' }), kind: 'ok' });
    } catch (e) { setMsg({ text: e.message, kind: 'error' }); }
    finally { setSaving(false); }
  }

  // Chantier #TASKS etape 6 paquet 1 (24/05/2026) : regroupement des taches
  // par echeance pour la vue « Lista ». Quatre seaux : en retard, aujourd'hui,
  // a venir, sans echeance. Les taches terminees (concluida) ou annulees
  // (cancelada) sont ecartees de la vue par echeance — elles n'appellent plus
  // d'action. due_date est de type date (pas timestamp) : comparaison de
  // chaines YYYY-MM-DD suffit et evite tout decalage de fuseau.
  const tasksByBucket = useMemo(() => {
    const today = new Date().toISOString().slice(0, 10);
    const buckets = { atrasada: [], hoje: [], futura: [], sem_prazo: [] };
    for (const tk of tasks) {
      if (tk.status === 'concluida' || tk.status === 'cancelada') continue;
      if (!tk.due_date) { buckets.sem_prazo.push(tk); continue; }
      if (tk.due_date < today) buckets.atrasada.push(tk);
      else if (tk.due_date === today) buckets.hoje.push(tk);
      else buckets.futura.push(tk);
    }
    // Tri intra-seau par due_date croissante (les sans-echeance gardent
    // l'ordre de chargement, created_at desc).
    const byDue = (a, b) => (a.due_date || '').localeCompare(b.due_date || '');
    buckets.atrasada.sort(byDue);
    buckets.hoje.sort(byDue);
    buckets.futura.sort(byDue);
    return buckets;
  }, [tasks]);

  // Taches deja closes (concluida/cancelada), affichees a part en bas de la
  // vue Lista pour ne pas encombrer les seaux d'echeance.
  const closedTasks = useMemo(
    () => tasks.filter(tk => tk.status === 'concluida' || tk.status === 'cancelada'),
    [tasks],
  );

  const fs = { width:'100%', padding:'10px 12px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', fontSize:'.9rem' };
  const ls = { display:'block', fontSize:'.85rem', fontWeight:600, marginBottom:3, color:'var(--brand-muted, #ccc)' };
  const bx = { padding:14, borderRadius:10, background:'rgba(255,255,255,.03)', border:'1px solid rgba(255,255,255,.08)', marginBottom:16 };
  const lr = (i) => ({ padding:'10px 12px', background:i%2===0?'rgba(0,0,0,.08)':'transparent', borderBottom:'1px solid rgba(255,255,255,.04)', display:'flex', justifyContent:'space-between', alignItems:'center', gap:8 });
  const lw = { border:'1px solid rgba(255,255,255,.06)', borderRadius:8, overflow:'hidden' };
  const logoUrl = commons?.logo_file_key ? `${PROJECT_URL}/storage/v1/object/public/library-ui-assets/${commons.logo_file_key.includes('/')?commons.logo_file_key:`themes/${commons.logo_file_key}/logo-${commons.logo_file_key}.png`}` : null;

  if (!libraryId) return (
    <PageShell><Topbar />
      <Hero title={t({ id: 'biblioteca.title' })} subtitle={t({ id: 'biblioteca.noLibrary' })} />
      <div className="catalogacao-wrap" style={{ maxWidth:800, margin:'0 auto', textAlign:'center', padding:'40px 24px' }}>
        <div style={{ display:'flex', gap:10, justifyContent:'center' }}>
          <Link to="/solicitar-biblioteca"><button className="cat-btn secondary">{t({ id: 'biblioteca.requestLibrary' })}</button></Link>
        </div>
      </div>
    <Footer /></PageShell>
  );

  if (!roleLoaded) return (
    <PageShell><Topbar />
      <div style={{ textAlign: 'center', padding: 60, color: 'var(--brand-muted)' }}>{t({id:'common.loading'})}</div>
    <Footer /></PageShell>
  );

  if (!isLibrarian) return (
    <PageShell><Topbar />
      <Hero title={t({ id: 'biblioteca.title' })} subtitle={t({ id: 'biblioteca.restricted' })} />
    <Footer /></PageShell>
  );

  return (
    <PageShell><Topbar />

      <Hero title={t({ id: 'biblioteca.title' })} subtitle={lib?.name || libraryName}>
        <UserHeroBadge />
        <HeroDocumentationActions />
      </Hero>

      <div className="catalogacao-wrap" style={{ maxWidth:1100, margin:'0 auto' }}>

        <div className="cat-statusbar" style={{ marginBottom:16 }}>
          {[[t({id:'catalog.stats.documents'}),stats.books],[t({id:'catalog.stats.authorities'}),stats.authors],[t({id:'catalog.stats.exemplars'}),stats.exemplars],[t({id:'catalog.stats.readers'}),stats.readers],[t({id:'catalog.stats.loans'}),stats.loansOpen]].map(([l,v])=>
            <div key={l} className="cat-stat"><span className="cat-stat-label">{l}</span><span className="cat-stat-value">{v}</span></div>
          )}
        </div>

        {/* Paquet G refactor (20/05/2026) : bandeau informatif pour biblios sans
            profile_template_chosen choisi consciemment. Place sur Biblioteca
            (lieu de la deliberation politique) plutot que Painel (operationnel). */}
        {profileTemplateChosen !== undefined && (
          <LibraryProfileBanner
            profileTemplateChosen={profileTemplateChosen}
            role={role}
          />
        )}

        {msg.text && <div style={{ padding:'10px 14px', borderRadius:8, fontSize:'.9rem', marginBottom:14, background:msg.kind==='ok'?'rgba(21,128,61,.12)':msg.kind==='info'?'rgba(29,78,216,.1)':'rgba(220,38,38,.12)', color:msg.kind==='ok'?'#4ade80':msg.kind==='info'?'#60a5fa':'#f87171' }}>{msg.text}</div>}

        <div className="cat-tabs" style={{ marginBottom:18 }}>
          {/* FIX BUG #4: rename loop variable to avoid shadowing `t` */}
          {visibleTabs.map(tb => <button key={tb.id} className={`cat-tab-btn${tab===tb.id?' active':''}${tb.separator?' tab-separator':''}`} onClick={()=>setTab(tb.id)}>{tb.label}</button>)}
          {/* EA-02 (21/05/2026) : bouton Atualizar global. Recharge loadAll(). */}
          <button className="cat-btn secondary" onClick={handleRefresh} disabled={refreshState==='busy'} title={t({ id: 'biblioteca.refresh.hint' })} style={{ marginLeft:'auto', fontSize:'.8rem', padding:'4px 10px' }}>{t({ id: refreshState==='busy' ? 'biblioteca.refresh.busy' : refreshState==='done' ? 'biblioteca.refresh.done' : 'biblioteca.refresh.label' })}</button>
        </div>

        <div className="cat-panel active">

        {/* Paquet E.5 refactor (20/05/2026) : onglet transitions de profil */}
        {tab==='transicoes' && (
          <TransitionsPanel libraryId={libraryId} role={role} />
        )}

        {/* ═══ 1. Identidade ═══════════════════════════ */}
        {tab==='identity' && lib && (<div>
          <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:12 }}>
            <h3 style={{ margin:0 }}>{t({ id: 'biblioteca.identity.title' })}</h3>
            {/* EA-01 (21/05/2026) : ouvre la modale d'inspection de la config brute. */}
            <button className="cat-btn secondary" onClick={()=>setWsInspectorOpen(true)} style={{ fontSize:'.8rem', padding:'4px 10px' }}>{t({ id: 'biblioteca.workspaceInspector.openButton' })}</button>
          </div>
          <WorkspaceInspectorModal libraryId={libraryId} open={wsInspectorOpen} onClose={()=>setWsInspectorOpen(false)} />
          <div className="cat-book-grid" style={{ marginBottom:16 }}>
            <div className="cat-field" style={{ gridColumn:'span 2' }}><label style={ls}>{t({ id: 'biblioteca.identity.name' })}</label><input type="text" value={lib.name||''} onChange={e=>setL('name',e.target.value)} style={fs} /></div>
            <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.shortName' })}</label><input type="text" value={lib.short_name||''} onChange={e=>setL('short_name',e.target.value)} style={fs} /></div>
            <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.city' })}</label><input type="text" value={lib.city||''} onChange={e=>setL('city',e.target.value)} style={fs} /></div>
            <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.state' })}</label><input type="text" value={lib.state||''} onChange={e=>setL('state',e.target.value)} style={fs} /></div>
            <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.country' })}</label><input type="text" value={lib.country||''} onChange={e=>setL('country',e.target.value)} style={fs} /></div>
            {/* PATCH 09/05/2026 paquet 6.3 : sélecteur de la langue d'identité.
                La langue est un attribut d'identité (pas une préférence de
                notification), positionnée juste après les coordonnées géographiques.
                Pas de drapeaux ni de codes d'État dans l'affichage (cohérence
                anarchiste, cf. décision politique session 2026-05-09). */}
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.identity.defaultLocale' })}</label>
              <LocaleSelector value={lib.default_locale} onChange={loc=>setL('default_locale',loc)} style={fs} />
            </div>
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
              <div className="cat-field"><label style={{...ls,display:'flex',gap:8,alignItems:'center'}}><input type="checkbox" checked={serviceState.allows_new_loans||false} onChange={e=>setSS('allows_new_loans',e.target.checked)} /> {t({id:'biblioteca.identity.allowsLoans'})}</label></div>
              <div className="cat-field"><label style={{...ls,display:'flex',gap:8,alignItems:'center'}}><input type="checkbox" checked={serviceState.allows_new_reservations||false} onChange={e=>setSS('allows_new_reservations',e.target.checked)} /> {t({id:'biblioteca.identity.allowsReservations'})}</label></div>
              <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={{...ls,display:'flex',gap:8,alignItems:'flex-start'}}><input type="checkbox" checked={lib.reader_cards_enabled||false} onChange={e=>setL('reader_cards_enabled',e.target.checked)} style={{marginTop:3}} /> <span><span>{t({id:'biblioteca.identity.readerCards'})}</span><br/><span style={{fontSize:'.8rem',color:'var(--brand-muted)',fontWeight:400}}>{t({id:'biblioteca.identity.readerCards.hint'})}</span></span></label></div>
              <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={ls}>{t({ id: 'biblioteca.identity.publicMessage' })}</label><textarea value={serviceState.public_message||''} onChange={e=>setSS('public_message',e.target.value)} rows={2} style={{...fs,resize:'vertical'}} placeholder={t({id:'biblioteca.identity.publicMessagePlaceholder'})} /></div>
            </div>
          </div>}
          <LibraryVisualAssetsSection
            libraryId={libraryId}
            librarySlug={lib.slug}
            libraryName={lib.short_name || lib.name}
            canEdit={isCoord}
          />
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
                  <option value="normal">{t({ id: 'biblioteca.comms.sendMode.normal' })}</option><option value="test_only">{t({ id: 'biblioteca.comms.sendMode.test_only' })}</option><option value="disabled">{t({ id: 'biblioteca.comms.sendMode.disabled' })}</option>
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
          {/* EA-20 : editeur du profil de contact de la biblioteca
              (library_contact_profiles), dans le composant separe
              LibraryContactProfileSection. */}
          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.contactProfile.title' })}</h4>
            <LibraryContactProfileSection libraryId={libraryId} canEdit={isCoord} />
          </div>
          {/* Vitrine publique de contact (chantier carte ma bibliotheque, etape 2) :
              coordonnees que la biblio choisit de montrer a SES lecteur-rices,
              distinct du contact confidentiel ci-dessus. Composant auto-encadre. */}
          <LibraryPublicContactSection libraryId={libraryId} canEdit={isCoord} />
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
          {/* PATCH 08/05/2026 paquet 3A : politique de négociation symétrique
              des créneaux de retrait. Toggle pour autoriser/refuser les
              contre-propositions de leitor(o/a/e)s + champ timeout (7..60 j,
              padrão 21 j). Sauvegardés via saveComms() vers library_notification_policies. */}
          {notifPolicy && <div style={bx}>
            <h4 style={{ margin:'0 0 6px' }}>{t({ id: 'biblioteca.reservation.title' })}</h4>
            <p style={{ fontSize:'.85rem', color:'var(--brand-muted)', margin:'0 0 14px' }}>
              {t({ id: 'biblioteca.reservation.subtitle' })}
            </p>

            <label style={{ display:'flex', gap:10, alignItems:'flex-start', cursor:'pointer', padding:'4px 0' }}>
              <input
                type="checkbox"
                checked={notifPolicy.reservation_allow_reader_counter_proposal ?? true}
                onChange={e => setNP('reservation_allow_reader_counter_proposal', e.target.checked)}
                style={{ marginTop:3 }}
              />
              <span style={{ flex:1 }}>
                <span style={{ fontSize:'.92rem', fontWeight:600 }}>
                  {t({ id: 'biblioteca.reservation.allowCounterProposal' })}
                </span>
                <span style={{ display:'block', fontSize:'.82rem', color:'var(--brand-muted)', marginTop:3 }}>
                  {t({ id: 'biblioteca.reservation.allowCounterProposal.hint' })}
                </span>
              </span>
            </label>

            <div className="cat-field" style={{ marginTop:14, maxWidth:280 }}>
              <label style={ls}>{t({ id: 'biblioteca.reservation.timeoutDays' })}</label>
              <input
                type="number"
                min={7}
                max={60}
                step={1}
                value={notifPolicy.reservation_negotiation_timeout_days ?? 21}
                onChange={e => {
                  const n = parseInt(e.target.value, 10);
                  setNP('reservation_negotiation_timeout_days', Number.isFinite(n) ? n : '');
                }}
                style={fs}
              />
              <span style={{ display:'block', fontSize:'.82rem', color:'var(--brand-muted)', marginTop:5 }}>
                {t({ id: 'biblioteca.reservation.timeoutDays.hint' })}
              </span>
            </div>
          </div>}
          <button className="cat-btn primary" onClick={saveComms} disabled={saving}>{saving?t({id:'common.saving'}):t({id:'biblioteca.comms.save'})}</button>
        </div>)}

        {/* ═══ 3. Regimento e circulação ════════════════ */}
        {tab==='regulation' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.regulation.title' })}</h3>
          {/* EA-06 (21/05/2026) : encart de lecture du regime.
              Diagnostic synthetique du croisement jeu actif x texte actif. */}
          <RegimeStateBox libraryId={libraryId} regulationDocs={regDocs} />
          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.regulation.docs' })}</h4>
            {regDocs.map(doc => (
              <div key={doc.id} style={{ padding:'8px 10px', borderRadius:6, background:'rgba(0,0,0,.15)', marginBottom:6, display:'flex', justifyContent:'space-between', alignItems:'center' }}>
                <div>
                  <div style={{ fontSize:'.9rem', fontWeight:600 }}>{doc.version_label||t({ id: 'biblioteca.regulation.versionFallback' }, { id: doc.id })}</div>
                  <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                    {doc.doc_kind ? t({ id: `biblioteca.regulation.docKind.${doc.doc_kind}`, defaultMessage: doc.doc_kind }) : '—'}
                    {' · '}
                    {doc.publication_status ? t({ id: `biblioteca.regulation.pubStatus.${doc.publication_status}`, defaultMessage: doc.publication_status }) : '—'}
                    {doc.is_active && <> · <span className="cat-pill ok" style={{ fontSize:'.65rem' }}>{t({ id: 'common.active' })}</span></>}
                  </div>
                </div>
                {doc.storage_path_public && <a href={`${PROJECT_URL}/storage/v1/object/public/${doc.storage_bucket||'library-regimentos-public'}/${doc.storage_path_public}`} target="_blank" rel="noopener" className="cat-btn secondary" style={{ fontSize:'.82rem', padding:'5px 12px' }}>{t({ id: 'biblioteca.regulation.openPdf' })}</a>}
              </div>
            ))}
            <div style={{ marginTop:12, display:'flex', gap:8, alignItems:'center', flexWrap:'wrap' }}>
              <label style={{ display:'inline-block', padding:'8px 16px', borderRadius:8, background:'var(--brand-panel-bg)', border:'1px solid rgba(255,255,255,.15)', cursor:'pointer', fontSize:'.88rem', fontWeight:600 }}>
                {t({ id: 'biblioteca.regulation.choosePdf' })}
                <input type="file" accept=".pdf,application/pdf" ref={regFileRef} style={{ display:'none' }} />
              </label>
              <button className="cat-btn primary" onClick={uploadRegimento} disabled={saving} style={{ fontSize:'.88rem' }}>
                {saving ? t({ id: 'biblioteca.regulation.uploading' }) : t({ id: 'biblioteca.regulation.uploadNew' })}
              </button>
            </div>
          </div>
          {/* EA-05 (21/05/2026) : gestionnaire de jeux de regles de circulation.
              Remplace l'editeur inline mono-jeu par PolicySetManager, qui
              gere tous les jeux (draft/active/archived) + leurs regles via RPC. */}
          <PolicySetManager
            libraryId={libraryId}
            canEdit={isCoord}
            regulationDocs={regDocs}
            seedT={seedT}
          />

          {/* ─── Cotisation associative ────────────────── */}
          <div style={bx}>
            <h4 style={{ margin:'0 0 6px' }}>{t({ id: 'membership.config.title' })}</h4>
            <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:12 }}>{t({ id: 'membership.config.hint' })}</div>

            {/* Toggle d'activation du système */}
            <div style={{ display:'flex', alignItems:'center', gap:10, padding:'10px 12px', borderRadius:8, background:'rgba(0,0,0,.15)', marginBottom:12 }}>
              <input
                type="checkbox"
                id="membership_enabled_toggle"
                checked={!!lib?.membership_enabled}
                onChange={e => toggleMembershipEnabled(e.target.checked)}
                disabled={saving}
              />
              <label htmlFor="membership_enabled_toggle" style={{ flex:1, cursor:'pointer' }}>
                <div style={{ fontWeight:600, fontSize:'.9rem' }}>{t({ id: 'membership.config.enabled' })}</div>
                <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                  {lib?.membership_enabled
                    ? t({ id: 'membership.config.enabledHint' })
                    : t({ id: 'membership.config.disabledHint' })}
                </div>
              </label>
            </div>

            {/* Liste des règles + édition inline */}
            <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:8 }}>
              <strong style={{ fontSize:'.9rem' }}>{t({ id: 'membership.config.rules.title' })}</strong>
              {!editingMembershipRule && (
                <button className="cat-btn secondary" onClick={startNewMembershipRule} style={{ fontSize:'.82rem', padding:'5px 12px' }}>
                  + {t({ id: 'membership.config.rules.add' })}
                </button>
              )}
            </div>

            {membershipRules.length === 0 && !editingMembershipRule && (
              <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', padding:'10px 0' }}>
                {t({ id: 'membership.config.rules.empty' })}
              </div>
            )}

            {/* Éditeur (nouvelle règle ou édition) */}
            {editingMembershipRule && (
              <div style={{ ...bx, background:'rgba(0,120,255,.06)', borderColor:'rgba(0,120,255,.25)', marginBottom:12 }}>
                <div className="cat-book-grid" style={{ gap:8 }}>
                  <div className="cat-field" style={{ gridColumn:'span 3' }}>
                    <label style={ls}>{t({ id: 'membership.config.rule.name' })} *</label>
                    <input
                      type="text"
                      value={editingMembershipRule.name || ''}
                      placeholder={t({ id: 'membership.config.rule.namePlaceholder' })}
                      onChange={e => setEditingMembershipRule(p => ({ ...p, name: e.target.value }))}
                      style={fs}
                    />
                  </div>
                  <div className="cat-field" style={{ gridColumn:'span 3' }}>
                    <label style={ls}>{t({ id: 'membership.config.rule.description' })}</label>
                    <input
                      type="text"
                      value={editingMembershipRule.description || ''}
                      placeholder={t({ id: 'membership.config.rule.descriptionPlaceholder' })}
                      onChange={e => setEditingMembershipRule(p => ({ ...p, description: e.target.value }))}
                      style={fs}
                    />
                  </div>
                  <div className="cat-field">
                    <label style={ls}>{t({ id: 'membership.config.rule.amountMin' })}</label>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={editingMembershipRule.amount_min ?? 0}
                      onChange={e => setEditingMembershipRule(p => ({ ...p, amount_min: e.target.value }))}
                      style={fs}
                    />
                  </div>
                  <div className="cat-field">
                    <label style={ls}>{t({ id: 'membership.config.rule.amountSuggested' })}</label>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={editingMembershipRule.amount_suggested ?? ''}
                      onChange={e => setEditingMembershipRule(p => ({ ...p, amount_suggested: e.target.value }))}
                      style={fs}
                    />
                  </div>
                  <div className="cat-field">
                    <label style={ls}>{t({ id: 'membership.config.rule.currency' })}</label>
                    <input
                      type="text"
                      maxLength={3}
                      value={editingMembershipRule.currency || 'EUR'}
                      onChange={e => setEditingMembershipRule(p => ({ ...p, currency: e.target.value.toUpperCase() }))}
                      style={fs}
                    />
                  </div>
                  <div className="cat-field">
                    <label style={ls}>{t({ id: 'membership.config.rule.periodType' })}</label>
                    <select
                      value={editingMembershipRule.period_type || 'annual'}
                      onChange={e => setEditingMembershipRule(p => ({ ...p, period_type: e.target.value }))}
                      style={fs}
                    >
                      <option value="annual">{t({ id: 'membership.period.annual' })}</option>
                      <option value="quarterly">{t({ id: 'membership.period.quarterly' })}</option>
                      <option value="monthly">{t({ id: 'membership.period.monthly' })}</option>
                      <option value="lifetime">{t({ id: 'membership.period.lifetime' })}</option>
                      <option value="none">{t({ id: 'membership.period.none' })}</option>
                    </select>
                  </div>
                  <div className="cat-field" style={{ gridColumn:'span 2' }}>
                    <label style={ls}>{t({ id: 'membership.config.rule.periodAnchor' })}</label>
                    <select
                      value={editingMembershipRule.period_anchor || 'rolling'}
                      onChange={e => setEditingMembershipRule(p => ({ ...p, period_anchor: e.target.value }))}
                      disabled={['lifetime','none'].includes(editingMembershipRule.period_type)}
                      style={fs}
                    >
                      <option value="rolling">{t({ id: 'membership.config.rule.periodAnchor.rolling' })}</option>
                      <option value="calendar">{t({ id: 'membership.config.rule.periodAnchor.calendar' })}</option>
                    </select>
                  </div>
                  <div className="cat-field" style={{ gridColumn:'span 3' }}>
                    <label style={{ ...ls, display:'flex', gap:8, alignItems:'flex-start', cursor:'pointer' }}>
                      <input
                        type="checkbox"
                        checked={!!editingMembershipRule.is_required}
                        onChange={e => setEditingMembershipRule(p => ({ ...p, is_required: e.target.checked }))}
                        style={{ marginTop:3 }}
                      />
                      <span>
                        <span style={{ fontWeight:600 }}>{t({ id: 'membership.config.rule.isRequired' })}</span>
                        <br />
                        <span style={{ fontSize:'.78rem', fontWeight:400, color:'var(--brand-muted)' }}>
                          {t({ id: 'membership.config.rule.isRequiredHint' })}
                        </span>
                      </span>
                    </label>
                  </div>
                  <div className="cat-field" style={{ gridColumn:'span 3' }}>
                    <label style={{ ...ls, display:'flex', gap:6, alignItems:'center', cursor:'pointer' }}>
                      <input
                        type="checkbox"
                        checked={editingMembershipRule.is_active !== false}
                        onChange={e => setEditingMembershipRule(p => ({ ...p, is_active: e.target.checked }))}
                      />
                      {t({ id: 'membership.config.rule.isActive' })}
                    </label>
                  </div>
                  <div className="cat-field" style={{ gridColumn:'span 3', display:'flex', gap:8, marginTop:6 }}>
                    <button className="cat-btn primary" onClick={saveMembershipRule} disabled={saving} style={{ fontSize:'.85rem' }}>
                      {t({ id: 'membership.config.action.save' })}
                    </button>
                    <button className="cat-btn secondary" onClick={cancelMembershipRule} style={{ fontSize:'.85rem' }}>
                      {t({ id: 'membership.config.action.cancel' })}
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* Liste des règles existantes (lecture seule) */}
            {membershipRules.length > 0 && (
              <div style={lw}>
                {membershipRules.map((r, i) => (
                  <div key={r.id} style={{ padding:'10px 12px', background:i%2===0?'rgba(0,0,0,.08)':'transparent', borderBottom:'1px solid rgba(255,255,255,.04)', opacity: r.is_active ? 1 : 0.55 }}>
                    <div style={{ display:'flex', justifyContent:'space-between', alignItems:'flex-start', gap:8 }}>
                      <div style={{ flex:1 }}>
                        <div style={{ fontSize:'.9rem', fontWeight:600, display:'flex', alignItems:'center', gap:6 }}>
                          {r.name}
                          {!r.is_active && <span className="cat-pill" style={{ fontSize:'.65rem', padding:'1px 6px', background:'rgba(255,255,255,.1)' }}>{t({ id: 'biblioteca.rules.inactive' })}</span>}
                          {r.is_required && r.is_active && <span className="cat-pill warn" style={{ fontSize:'.65rem', padding:'1px 6px' }}>{t({ id: 'membership.rule.required' })}</span>}
                        </div>
                        <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginTop:2 }}>
                          {r.amount_min > 0
                            ? t({ id: 'membership.rule.minimumAmount' }, { amount: r.amount_min, currency: r.currency })
                            : t({ id: 'membership.rule.freePrice' })}
                          {r.amount_suggested && r.amount_suggested !== r.amount_min &&
                            ` · ${t({ id: 'membership.rule.suggestedAmount' }, { amount: r.amount_suggested, currency: r.currency })}`}
                          {' · '}{t({ id: `membership.period.${r.period_type}` })}
                          {!['lifetime','none'].includes(r.period_type) &&
                            ` (${t({ id: `membership.config.rule.periodAnchor.${r.period_anchor}` })})`}
                        </div>
                        {r.description && (
                          <div style={{ fontSize:'.78rem', color:'var(--brand-muted)', marginTop:3, fontStyle:'italic' }}>
                            {r.description}
                          </div>
                        )}
                      </div>
                      {!editingMembershipRule && (
                        <div style={{ display:'flex', gap:6 }}>
                          <button className="cat-btn secondary" onClick={() => startEditMembershipRule(r)} style={{ fontSize:'.78rem', padding:'4px 10px' }}>
                            {t({ id: 'membership.config.action.edit' })}
                          </button>
                          <button
                            className="cat-btn ghost"
                            onClick={() => toggleMembershipRuleActive(r)}
                            style={{ fontSize:'.78rem', padding:'4px 10px', color: r.is_active ? '#f87171' : '#86efac' }}
                          >
                            {t({ id: r.is_active ? 'membership.config.action.deactivate' : 'membership.config.action.reactivate' })}
                          </button>
                          <button
                            className="cat-btn ghost"
                            onClick={() => deleteMembershipRule(r)}
                            style={{ fontSize:'.78rem', padding:'4px 10px', color:'#dc2626', borderColor:'rgba(220,38,38,.4)' }}
                            title={t({ id: 'membership.config.action.deleteHint' })}
                          >
                            {t({ id: 'membership.config.action.delete' })}
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>)}

        {/* ═══ 4. Documentos e relações externas ═══════ */}
        {tab==='documents' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.documents.title' })}</h3>
          {/* EA-08 (21/05/2026) : editeur de gouvernance documentale.
              Restaure la fonctionnalite du HTML d'origine. Doctrine :
              gouvernance documentale = attribut local par biblioteca. */}
          <DocumentGovernanceSection libraryId={libraryId} canEdit={isCoord} />
          {/* Chantier « Partenaires de correspondance » etape 3 (24/05/2026) :
              remplace l'ancienne liste globale en lecture seule de
              catalog_partners par l'editeur LibraryPartnershipsSection.
              Chaque biblioteca choisit desormais ses propres partenaires
              (bibliotheques federees ou collectifs catalogue). Reserve au
              staff de coordination (canEdit=isCoord, l'onglet est coordOnly).
              Spec : docs/journal/chantiers/CHANTIER_partenaires_correspondance_2026-05-24. */}
          <LibraryPartnershipsSection
            libraryId={libraryId}
            canEdit={isCoord}
            allLibraries={allLibraries}
          />
        </div>)}

        {/* ═══ 4b. Confidentialité — Phase 4a RGPD ═══════ */}
        {tab==='privacy' && (
          <RetentionPolicySection libraryId={libraryId} canEdit={isCoord} />
        )}

        {/* ═══ 5. Equipe ═══════════════════════════════ */}
        {/* Phase A 07/05/2026 : remplacement de la liste lecture seule par
            <TeamPanel /> qui affiche aussi les status (suspended,
            pending_removal, inactive) et préparera la Phase B (actions
            via les RPCs fn_team_*). Le state `members` reste chargé dans
            loadAll() car generateReportText() le consomme. */}
        {tab==='team' && (
          <div>
            <h3 style={{ marginBottom: 12 }}>{t({ id: 'biblioteca.team.title' })}</h3>
            <TeamPanel scope="library" libraryId={libraryId} />
          </div>
        )}

        {/* ═══ 5bis. Leitoras·es ═══════════════════════ */}
        {/* Phase B2bis 11/05/2026 : onglet distinct des lectrices et lecteurs
            de la biblio, avec promotion → librarian via la RPC
            fn_team_promote_to_librarian (déclenche l'event militant). */}
        {tab==='leitores' && (
          <LeitoresPanel libraryId={libraryId} />
        )}

        {/* ═══ 6. Trocas interbibliotecas ══════════════ */}
        {tab==='exchanges' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.exchanges.title' })}</h3>
          <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:14 }}>{t({id:'biblioteca.exchanges.hint'})}</div>
          {/* EA-11 paquet 1 : formulaire de proposition de troca, dans le
              composant separe ExchangeProposalForm. Le bloc maquette inerte
              (boutons disabled, implementationPending) a ete remplace. */}
          <ExchangeProposalForm libraryId={libraryId} allLibraries={allLibraries} t={t} />
          {/* EA-11 paquet 3 : liste, filtres et decision des propositions
              de troca, dans le composant separe ExchangeRequestsList. */}
          <ExchangeRequestsList libraryId={libraryId} allLibraries={allLibraries} t={t} />
          {/* EA-11 paquet 4 : suivi des trocas acceptees, dans le
              composant separe ExchangeFollowupPanel. */}
          <ExchangeFollowupPanel libraryId={libraryId} allLibraries={allLibraries} t={t} />
        </div>)}

        {/* ═══ 7. Empréstimos interbibliotecas ═════════ */}
        {tab==='ill' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.ill.title' })}</h3>
          <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:14 }}>{t({id:'biblioteca.ill.hint'})}</div>

          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.ill.prepare' })}</h4>
            <div className="cat-book-grid" style={{ marginBottom:10 }}>
              {/* EA-12 phase 2 (dette 2) : seules les bibliotheques eligibles
                  au PEB sont proposees - federees, circulation active, actives.
                  C'est la regle de fn_peb_authorized, appliquee des le dropdown. */}
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.lender' })}</label>
                <select value={illForm.lender} onChange={e=>{
                  const v = e.target.value;
                  setIllForm(p=>({...p,lender:v}));
                  // #ILL-search-scope : changer de prêteuse invalide le panier
                  // (les exemplaires appartenaient a l'ancienne prêteuse) et
                  // les resultats de recherche. On purge les deux.
                  setIllItems([]);
                  setIllDocResults([]);
                  setIllDocSearch('');
                }} style={fs}>
                  <option value="">{t({ id: 'biblioteca.ill.select' })}</option>{pebEligibleLibraries.map(l=><option key={l.id} value={l.id}>{l.name} ({l.short_name})</option>)}
                </select>
              </div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.borrower' })}</label>
                <select value={illForm.borrower} onChange={e=>setIllForm(p=>({...p,borrower:e.target.value}))} style={fs}>
                  <option value="">{t({ id: 'biblioteca.ill.select' })}</option>{pebEligibleLibraries.map(l=><option key={l.id} value={l.id}>{l.name} ({l.short_name})</option>)}
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
              <h4 style={{ margin:'0 0 8px', fontSize:'.95rem' }}>{t({ id: 'biblioteca.ill.items' })} *</h4>
              {/* #ILL-search-scope : la recherche d'exemplaires exige qu'une
                  bibliotheque prêteuse soit choisie (la recherche est filtree
                  sur ses fonds disponibles). Tant qu'aucune n'est selectionnee,
                  champ et bouton desactives, avec une invite. */}
              {!illForm.lender && (
                <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', fontStyle:'italic', marginBottom:8 }}>
                  {t({ id: 'biblioteca.ill.pickLenderFirst' })}
                </div>
              )}
              <div style={{ display:'flex', gap:8, marginBottom:8 }}>
                <input type="text" value={illDocSearch} disabled={!illForm.lender}
                  onChange={e=>setIllDocSearch(e.target.value)}
                  onKeyDown={e=>e.key==='Enter'&&searchIllDocs()}
                  placeholder={t({ id: 'biblioteca.ill.fullSearchPlaceholder' })}
                  style={{...fs,flex:1,opacity:illForm.lender?1:0.5}} />
                <button className="cat-btn secondary" onClick={searchIllDocs}
                  disabled={!illForm.lender}
                  style={{ fontSize:'.85rem', padding:'7px 14px', flexShrink:0, opacity:illForm.lender?1:0.5 }}>
                  {t({ id: 'common.search' })}
                </button>
              </div>
              {/* Finition UX PEB : la ligne entiere ajoute l'exemplaire au clic
                  (le bouton « Adicionar » faisait doublon, retire). Le survol
                  signale que la ligne est cliquable. */}
              {illDocResults.length>0 && <div style={{...lw,marginBottom:8,maxHeight:150,overflowY:'auto'}}>{illDocResults.map((d,i)=>(
                <div key={d.exemplar_id}
                  style={{...lr(i),cursor:'pointer'}}
                  title={t({ id: 'biblioteca.ill.clickToAdd' })}
                  onClick={()=>addIllItem(d)}
                  onMouseEnter={e=>{e.currentTarget.style.background='rgba(255,255,255,.06)';}}
                  onMouseLeave={e=>{e.currentTarget.style.background='';}}>
                  <div style={{ fontSize:'.88rem' }}><strong>{d.titulo}</strong> — {d.autor||'—'} · {t({ id: 'biblioteca.ill.tombo' })}: {d.tombo||'—'}</div>
                  <span aria-hidden="true" style={{ fontSize:'.78rem', color:'var(--brand-muted)' }}>+</span>
                </div>
              ))}</div>}
              {illItems.length===0 && <div style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>{t({id:'biblioteca.ill.emptyItems'})}</div>}
              {illItems.length>0 && <div style={lw}>{illItems.map((it,i)=>(
                <div key={it.item_id} style={lr(i)}>
                  <div style={{ fontSize:'.88rem' }}><strong>{it.titulo}</strong> — {it.autor||'—'} · {t({ id: 'biblioteca.ill.tombo' })}: {it.tombo||'—'}</div>
                  <button className="cat-btn ghost" style={{ fontSize:'.78rem', padding:'3px 8px', color:'#f87171' }} onClick={()=>removeIllItem(it.item_id)}>{t({ id: 'common.remove' })}</button>
                </div>
              ))}</div>}
            </div>

            {/* Finition UX PEB : le PEB est bidirectionnel, le libelle des
                champs de contact ne peut pas dire « preteuse » ou « emprunteuse ».
                Cette phrase leve l'ambiguite : c'est le contact de SA biblio. */}
            <div style={{ fontSize:'.8rem', color:'var(--brand-muted)', marginBottom:8 }}>
              {t({ id: 'biblioteca.ill.coordinationHelp' })}
            </div>
            <div className="cat-book-grid" style={{ marginBottom:10 }}>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.contact' })} *</label><input type="text" value={illForm.contactName} onChange={e=>setIllForm(p=>({...p,contactName:e.target.value}))} style={fs} placeholder={t({ id: 'biblioteca.ill.contactNamePlaceholder' })} /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.contactEmail' })} *</label><input type="email" value={illForm.contactEmail} onChange={e=>setIllForm(p=>({...p,contactEmail:e.target.value}))} style={fs} placeholder="contato@biblioteca.org" /></div>
              {/* #ILL-logistics : mode de transmission des documents. */}
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.logisticsMode' })} *</label>
                <select value={illForm.logisticsMode} onChange={e=>setIllForm(p=>({...p,logisticsMode:e.target.value}))} style={fs}>
                  <option value="">{t({ id: 'biblioteca.ill.select' })}</option>
                  <option value="envio_postal">{t({ id: 'ill.logistics.envio_postal' })}</option>
                  <option value="entrega_em_maos">{t({ id: 'ill.logistics.entrega_em_maos' })}</option>
                  <option value="transporte_militante">{t({ id: 'ill.logistics.transporte_militante' })}</option>
                  <option value="a_combinar">{t({ id: 'ill.logistics.a_combinar' })}</option>
                </select>
              </div>
              {/* meeting_point : seulement pour les modes de remise physique
                  (remise en main propre, portage militant). */}
              {(illForm.logisticsMode === 'entrega_em_maos' || illForm.logisticsMode === 'transporte_militante') && (
                <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.meetingPoint' })}</label><input type="text" value={illForm.meetingPoint} onChange={e=>setIllForm(p=>({...p,meetingPoint:e.target.value}))} style={fs} placeholder={t({ id: 'biblioteca.ill.pickupPlaceholder' })} /></div>
              )}
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.startDate' })}</label><input type="date" value={illForm.startDate} onChange={e=>setIllForm(p=>({...p,startDate:e.target.value}))} style={fs} /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.dueDate' })}</label><input type="date" value={illForm.dueDate} onChange={e=>setIllForm(p=>({...p,dueDate:e.target.value}))} style={fs} /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.notes' })}</label><textarea value={illForm.logisticsNote} onChange={e=>setIllForm(p=>({...p,logisticsNote:e.target.value}))} rows={2} style={{...fs,resize:'vertical'}} placeholder={t({ id: 'biblioteca.ill.packagingPlaceholder' })} /></div>
            </div>
            <div style={{ display:'flex', gap:8 }}>
              <button className="cat-btn primary" onClick={saveIll} disabled={saving} style={{ fontSize:'.9rem' }}>{saving?t({id:'common.saving'}):t({id:'biblioteca.ill.save'})}</button>
              <button className="cat-btn ghost" onClick={()=>{setIllForm({lender:'',borrower:'',status:'preparacao',contactName:'',contactEmail:'',startDate:'',dueDate:'',logisticsNote:'',meetingPoint:'',logisticsMode:''});setIllItems([]);}} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.ill.clear' })}</button>
            </div>
          </div>

          {/* Liste des empréstimos existants */}
          {illLoans.length>0 && (<div style={{ marginTop:16 }}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.ill.existing' })}</h4>
            <div style={lw}>{illLoans.map((loan,i)=>{
              const isLender = loan.lender_library_id===libraryId;
              const lenderLib = allLibraries.find(l=>l.id===loan.lender_library_id);
              const borrowerLib = allLibraries.find(l=>l.id===loan.borrower_library_id);
              // #ILL-partial — exemplaires de ce prêt, état déplié, phase de retour.
              const items = illItemsByLoan[loan.id] || [];
              const expanded = illExpanded.has(loan.id);
              const inReturnPhase = ILL_RETURN_PHASES.includes(loan.status_global);
              // status_global déduit (parcialmente_devolvido, devolvido) : le
              // <select> l'affiche mais ne permet pas de le choisir à la main.
              const statusIsDerived = loan.status_global==='parcialmente_devolvido' || loan.status_global==='devolvido';
              const loanDraft = illReturnDraft[loan.id] || {};
              // #ILL-archive — un PEB terminé (devolvido/cancelado) est archivable.
              // Garde-fou visuel : s'il est terminé depuis plus de 30 jours, on
              // le signale (closed_at approché par returned_at, sinon updated_at).
              const isTerminal = loan.status_global==='devolvido' || loan.status_global==='cancelado';
              const closedAt = loan.returned_at || loan.updated_at;
              const staleForArchive = isTerminal && closedAt &&
                (Date.now() - new Date(closedAt).getTime()) > 30*24*60*60*1000;
              return(<div key={loan.id} style={{ borderBottom:'1px solid rgba(255,255,255,.04)' }}>
                <div style={{ ...lr(i), borderBottom:'none' }}>
                <div style={{ flex:1 }}>
                  <div style={{ fontSize:'.9rem', fontWeight:600 }}>
                    {items.length>0 && (
                      <button onClick={()=>toggleIllExpanded(loan.id)} className="cat-btn ghost"
                        style={{ fontSize:'.78rem', padding:'0 6px', marginRight:6 }}>
                        {expanded?'▾':'▸'} {t({ id:'biblioteca.ill.itemsCount' },{count:items.length})}
                      </button>
                    )}
                    #{loan.id} — {isLender?t({ id: 'biblioteca.ill.lender' }):t({ id: 'biblioteca.ill.borrower' })}
                    {/* #ILL-archive — garde-fou visuel : PEB terminé depuis longtemps */}
                    {staleForArchive && (
                      <span style={{ marginLeft:8, fontSize:'.7rem', fontWeight:600, padding:'2px 7px',
                        borderRadius:10, background:'rgba(251,191,36,.16)', color:'#fbbf24' }}>
                        {t({ id: 'biblioteca.ill.staleForArchive' })}
                      </span>
                    )}
                  </div>
                  <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                    {lenderLib?.short_name||'—'} → {borrowerLib?.short_name||'—'}
                    {loan.start_date&&` · ${t({ id: 'biblioteca.ill.startDateLabel' })}: ${loan.start_date}`}{loan.due_date&&` · ${t({ id: 'biblioteca.ill.dueDateLabel' })}: ${loan.due_date}`}
                    {loan.meeting_point&&` · ${loan.meeting_point}`}
                  </div>
                </div>
                <select value={loan.status_global||''} disabled={statusIsDerived}
                  onChange={e=>updateIllStatus(loan.id,e.target.value)}
                  style={{ fontSize:'.82rem', padding:'4px 8px', borderRadius:6, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', opacity:statusIsDerived?0.6:1 }}>
                  <option value="preparacao">{t({ id: 'ill.status.preparacao' })}</option><option value="aguardando_saida">{t({ id: 'ill.status.aguardando_saida' })}</option>
                  <option value="emprestado">{t({ id: 'ill.status.emprestado' })}</option><option value="em_devolucao">{t({ id: 'ill.status.em_devolucao' })}</option>
                  {/* #ILL-partial — affiché pour ne pas casser le select quand le
                      statut est déduit ; non sélectionnable (select disabled). */}
                  <option value="parcialmente_devolvido">{t({ id: 'ill.status.parcialmente_devolvido' })}</option>
                  <option value="devolvido">{t({ id: 'ill.status.devolvido' })}</option><option value="cancelado">{t({ id: 'ill.status.cancelado' })}</option>
                </select>
                {/* #ILL-archive — bouton d'archivage, seulement sur un PEB terminé */}
                {isTerminal && (
                  <button className="cat-btn ghost" style={{ fontSize:'.78rem', padding:'4px 8px' }}
                    onClick={()=>archiveIllLoan(loan.id)}>
                    {t({ id: 'biblioteca.ill.archive' })}
                  </button>
                )}
                {/* #ILL-archive — descartar (suppression définitive) n'a de
                    sens que sur un PEB non terminal (créé par erreur, jamais
                    sorti). Sur un PEB terminé, le bon geste est arquivar :
                    on masque descartar pour éviter la suppression accidentelle
                    d'un prêt qui a réellement eu lieu. */}
                {!isTerminal && (
                  <button className="cat-btn ghost" style={{ fontSize:'.78rem', padding:'4px 8px', color:'#f87171' }} onClick={()=>deleteIll(loan.id)}>{t({ id: 'common.discard' })}</button>
                )}
                </div>
                {/* #ILL-partial — bloc dépliable : exemplaires + pointage du retour */}
                {expanded && items.length>0 && (
                  <div style={{ padding:'4px 12px 12px 28px', background:'rgba(0,0,0,.12)' }}>
                    {items.map(it=>{
                      const settled = ILL_ITEM_SETTLED.includes(it.item_status);
                      const draft = loanDraft[it.id] || { checked:false, status: settled?it.item_status:'devolvido' };
                      const ref = [it.titulo_cache, it.autor_cache].filter(Boolean).join(' — ') || it.bib_ref || '—';
                      return(<div key={it.id} style={{ display:'flex', alignItems:'center', gap:8, padding:'5px 0', fontSize:'.82rem', borderBottom:'1px solid rgba(255,255,255,.03)' }}>
                        <input type="checkbox" checked={!!draft.checked} disabled={!inReturnPhase}
                          onChange={e=>setIllReturnField(loan.id, it.id, 'checked', e.target.checked)} />
                        <span style={{ flex:1 }}>
                          {ref}{it.rotulo_cache?` (${it.rotulo_cache})`:''}
                          <span style={{ color:'var(--brand-muted)', marginLeft:6 }}>
                            · {t({ id:`ill.itemStatus.${it.item_status}` })}
                          </span>
                        </span>
                        {/* corrigeables : un select de statut de retour pour chaque
                            exemplaire (réglé ou non — la RPC autorise la correction) */}
                        <select value={draft.status} disabled={!inReturnPhase}
                          onChange={e=>setIllReturnField(loan.id, it.id, 'status', e.target.value)}
                          style={{ fontSize:'.78rem', padding:'2px 6px', borderRadius:5, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4' }}>
                          <option value="devolvido">{t({ id:'ill.itemStatus.devolvido' })}</option>
                          <option value="perdido">{t({ id:'ill.itemStatus.perdido' })}</option>
                          <option value="danificado">{t({ id:'ill.itemStatus.danificado' })}</option>
                          <option value="cancelado">{t({ id:'ill.itemStatus.cancelado' })}</option>
                        </select>
                      </div>);
                    })}
                    {inReturnPhase ? (
                      <>
                        <button className="cat-btn"
                          disabled={illReturnFeedback[loan.id]?.busy}
                          style={{ fontSize:'.8rem', padding:'5px 12px', marginTop:8,
                                   opacity: illReturnFeedback[loan.id]?.busy ? 0.6 : 1 }}
                          onClick={()=>submitIllItemReturn(loan.id)}>
                          {illReturnFeedback[loan.id]?.busy
                            ? t({ id:'biblioteca.ill.return.submitting' })
                            : t({ id:'biblioteca.ill.return.submit' })}
                        </button>
                        {/* Message de résultat LOCAL, juste sous le bouton (option B). */}
                        {illReturnFeedback[loan.id]?.msg && (
                          <div style={{ fontSize:'.8rem', marginTop:6, padding:'5px 9px',
                                        borderRadius:6,
                                        background: illReturnFeedback[loan.id].kind==='ok'
                                          ? 'rgba(74,222,128,.12)' : 'rgba(248,113,113,.12)',
                                        color: illReturnFeedback[loan.id].kind==='ok'
                                          ? '#4ade80' : '#f87171' }}>
                            {illReturnFeedback[loan.id].msg}
                          </div>
                        )}
                      </>
                    ) : (
                      <div style={{ fontSize:'.78rem', color:'var(--brand-muted)', marginTop:8, fontStyle:'italic' }}>
                        {t({ id:'biblioteca.ill.return.notInPhase' })}
                      </div>
                    )}
                  </div>
                )}
              </div>);
            })}</div>
          </div>)}
        </div>)}

        {/* ═══ 8. Relatórios e resumos ═════════════════ */}
        {tab==='reports' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.reports.title' })}</h3>
          <div style={bx}>
            <div className="cat-book-grid">
              {[{v:stats.books,l:t({id:'catalog.stats.documents'})},{v:stats.authors,l:t({id:'catalog.stats.authorities'})},{v:stats.exemplars,l:t({id:'catalog.stats.exemplars'})},{v:stats.readers,l:t({id:'biblioteca.stats.readersActive'})},{v:stats.loansOpen,l:t({id:'biblioteca.stats.loansOpen'})},{v:stats.loansOverdue,l:t({id:'biblioteca.stats.loansOverdue'}),warn:stats.loansOverdue>0},{v:stats.loansCreated7d,l:t({id:'biblioteca.stats.loansCreated7d'})},{v:stats.loansReturned7d,l:t({id:'biblioteca.stats.loansReturned7d'})},{v:stats.reservationsActive,l:t({id:'biblioteca.stats.reservationsActive'})},{v:stats.consultationsActive,l:t({id:'biblioteca.stats.consultationsActive'})},{v:stats.trocasActive,l:t({id:'biblioteca.stats.trocasActive'})},{v:stats.librariansActive,l:t({id:'biblioteca.stats.librariansActive'})}].map((s,i)=>(
                <div key={i} style={{ padding:14, borderRadius:8, background:s.warn?'rgba(220,38,38,.15)':'rgba(0,0,0,.15)', textAlign:'center', border:s.warn?'1px solid rgba(220,38,38,.4)':'none' }}>
                  <div style={{ fontSize:'1.5rem', fontWeight:800 }}>{s.v}</div><div style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>{s.l}</div>
                </div>
              ))}
            </div>
          </div>

          {stats.topBooks && stats.topBooks.length > 0 && (
            <div style={bx}>
              <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.reports.topBooks90d' })}</h4>
              <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:10 }}>
                {t({ id: 'biblioteca.reports.topBooks90dHint' })}
              </div>
              <div style={{ display:'flex', flexDirection:'column', gap:6 }}>
                {stats.topBooks.map((b, i) => (
                  <div key={i} style={{ display:'flex', justifyContent:'space-between', gap:12, padding:'8px 12px', borderRadius:6, background:'rgba(0,0,0,.12)' }}>
                    <div style={{ flex:1, minWidth:0 }}>
                      <div style={{ fontSize:'.92rem', fontWeight:600, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{b.titulo || t({ id: 'common.untitled' })}</div>
                      <div style={{ fontSize:'.78rem', color:'var(--brand-muted)', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{b.autor || t({ id: 'common.unknownAuthor' })}</div>
                    </div>
                    <div style={{ fontSize:'.92rem', fontWeight:700, alignSelf:'center', whiteSpace:'nowrap' }}>{t({ id: 'biblioteca.reports.topBooks.loanCount' }, { count: b.cnt })}</div>
                  </div>
                ))}
              </div>
            </div>
          )}
          {/* #ILL-archive (25/05/2026) : consultation des PEB archivés.
              Composant dédié, lit la vue api.peb_history_v1, permet de
              désarchiver. Réservé au staff (l'onglet Rapports l'est déjà).
              #ILL-reports volet B : onChange=loadAll pour que la file active
              se rafraîchisse quand un PEB est désarchivé. */}
          <PebHistorySection libraryId={libraryId} allLibraries={allLibraries} onChange={loadAll} />
          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.reports.generate' })}</h4>
            <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:10 }}>
              {t({ id: 'biblioteca.reports.generateHint' })}
            </div>
            <textarea value={generateReportText()} readOnly rows={12} style={{...fs, fontFamily:'monospace', fontSize:'.82rem', resize:'vertical', marginBottom:10}} />
            <div style={{ display:'flex', gap:8, flexWrap:'wrap' }}>
              <button className="cat-btn primary" onClick={()=>{ navigator.clipboard?.writeText(generateReportText()); setMsg({text:t({id:'biblioteca.report.copiedToast'}),kind:'ok'}); }} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.reports.copy' })}</button>
              <button className="cat-btn secondary" onClick={sendReport} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.reports.sendEmail' })}</button>
              <span style={{ fontSize:'.82rem', color:'var(--brand-muted)', alignSelf:'center' }}>{t({ id: 'biblioteca.tasks.recipient' })} {mailChannel?.weekly_report_email || t({ id: 'common.notConfigured' })}</span>
            </div>
          </div>
        </div>)}

        {/* ═══ 9. Tarefas internas ════════════════════ */}
        {/* Chantier #TASKS etape 6 (24/05/2026) : onglet refondu en trois
            sous-onglets. Paquet 1 livre « Lista » (vue par echeance + drapeau
            de recurrence en retard). « Modelos » et « Catalogo » sont des
            placeholders, remplis aux paquets 2 et 3. */}
        {tab==='tasks' && (() => {
          // Rendu d'une ligne de tache. Closure pour reutilisation dans chaque
          // seau d'echeance et dans la liste des taches closes. Le markup et
          // le comportement (select de statut, suppression, invitation) sont
          // identiques a l'ancienne liste plate ; on ajoute seulement deux
          // marqueurs : drapeau « recurrence en retard » (recurrence_stale_
          // flagged_at) et badge « serie » (recurrence_rule_id non nul).
          const renderTaskRow = (tk, i) => {
            const isStale = !!tk.recurrence_stale_flagged_at;
            const isRecurring = !!tk.recurrence_rule_id;
            const tkTitle = localizedText(tk.title_i18n, tk.title);
            const tkDesc = localizedText(tk.description_i18n, tk.description);
            return (
            <div key={tk.id} style={{ ...lr(i), flexDirection:'column', alignItems:'stretch', gap:6 }}>
              <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', gap:8 }}>
                <div style={{ flex:1 }}>
                  <div style={{ fontSize:'.9rem', fontWeight:600, display:'flex', alignItems:'center', gap:6, flexWrap:'wrap' }}>
                    {tkTitle||t({ id: 'common.noTitle' })}
                    {isRecurring && (
                      <span className="cat-pill info" style={{ fontSize:'.62rem', padding:'1px 6px' }}
                        title={t({ id: 'biblioteca.tasks.recurring.hint' })}>
                        {t({ id: 'biblioteca.tasks.recurring.badge' })}
                      </span>
                    )}
                    {isStale && (
                      <span className="cat-pill danger" style={{ fontSize:'.62rem', padding:'1px 6px' }}
                        title={t({ id: 'biblioteca.tasks.staleRecurrence.hint' })}>
                        {t({ id: 'biblioteca.tasks.staleRecurrence.badge' })}
                      </span>
                    )}
                  </div>
                  <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                    {tk.owner||'—'}{tk.due_date&&` · ${t({ id: 'biblioteca.tasks.deadlineLabel' })}: ${tk.due_date}`}
                    {tk.tags?.length>0&&` · ${tk.tags.join(', ')}`}
                  </div>
                  {tkDesc && <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginTop:2 }}>{tkDesc}</div>}
                </div>
                <div style={{ display:'flex', gap:4, flexShrink:0, alignItems:'center' }}>
                  <span className={`cat-pill ${tk.priority==='alta'?'danger':tk.priority==='baixa'?'info':'warn'}`} style={{ fontSize:'.65rem' }}>{TASK_PRIO[tk.priority]||tk.priority}</span>
                  <select value={tk.status} onChange={e=>updateTaskStatus(tk.id,e.target.value)} style={{ fontSize:'.82rem', padding:'4px 8px', borderRadius:6, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4' }}>
                    <option value="pendente">{t({ id: 'task.status.pendente' })}</option><option value="em_andamento">{t({ id: 'task.status.em_andamento' })}</option><option value="concluida">{t({ id: 'task.status.concluida' })}</option><option value="cancelada">{t({ id: 'task.status.cancelada' })}</option>
                  </select>
                  <button className="cat-btn ghost" style={{ fontSize:'.78rem', padding:'4px 8px', color:'#f87171' }} onClick={async()=>{if(!confirm(t({ id: 'biblioteca.tasks.discardConfirm' })))return;try{const{error}=await supabase.rpc('fn_task_delete',{p_task_id:tk.id});if(error)throw error;await loadAll();}catch(err){setMsg({text:t({id:'common.errorPrefix'},{message:err.message}),kind:'error'});}}}>{t({ id: 'common.discard' })}</button>
                </div>
              </div>
              {/* Invite row */}
              <div style={{ display:'flex', gap:6, alignItems:'center' }}>
                <input type="email" placeholder={t({ id: 'biblioteca.tasks.invitePlaceholder' })} style={{...fs, flex:1, padding:'6px 10px', fontSize:'.82rem'}}
                  onKeyDown={async e=>{if(e.key==='Enter'&&e.target.value.trim()){await inviteToTask(tk.id,e.target.value);e.target.value='';}}} />
                <button className="cat-btn secondary" style={{ fontSize:'.78rem', padding:'4px 10px', flexShrink:0 }}
                  onClick={async e=>{const inp=e.target.previousElementSibling;if(inp?.value?.trim()){await inviteToTask(tk.id,inp.value);inp.value='';}}}>{t({ id: 'biblioteca.tasks.invite' })}</button>
              </div>
            </div>
            );
          };

          // Rendu d'un seau d'echeance : titre + compteur + lignes. Masque si
          // vide (sauf le bloc « sans echeance » qui reste utile a montrer).
          const renderBucket = (key, labelId, accent) => {
            const list = tasksByBucket[key];
            if (!list.length) return null;
            return (
              <div style={{ marginBottom:14 }}>
                <h4 style={{ margin:'0 0 8px', fontSize:'.92rem', color:accent }}>
                  {t({ id: labelId })} ({list.length})
                </h4>
                <div style={lw}>{list.map((tk,i)=>renderTaskRow(tk,i))}</div>
              </div>
            );
          };

          const hasActiveTasks = (
            tasksByBucket.atrasada.length
            + tasksByBucket.hoje.length
            + tasksByBucket.futura.length
            + tasksByBucket.sem_prazo.length
          ) > 0;

          return (
          <div>
            <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.tasks.title' })}</h3>

            {/* Sous-onglets internes : Lista / Modelos / Catalogo. Reutilise
                la classe cat-tab-btn pour rester coherent avec la page. */}
            <div className="cat-tabs" style={{ marginBottom:16 }}>
              <button className={`cat-tab-btn${tasksSubtab==='lista'?' active':''}`} onClick={()=>setTasksSubtab('lista')}>{t({ id: 'biblioteca.tasks.subtab.list' })}</button>
              <button className={`cat-tab-btn${tasksSubtab==='modelos'?' active':''}`} onClick={()=>setTasksSubtab('modelos')}>{t({ id: 'biblioteca.tasks.subtab.templates' })}</button>
              <button className={`cat-tab-btn${tasksSubtab==='catalogo'?' active':''}`} onClick={()=>setTasksSubtab('catalogo')}>{t({ id: 'biblioteca.tasks.subtab.catalog' })}</button>
            </div>

            {/* ── Sous-onglet LISTA ── */}
            {tasksSubtab==='lista' && (<div>
              <div style={bx}>
                <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.tasks.new' })}</h4>
                <div className="cat-book-grid" style={{ marginBottom:10 }}>
                  <div className="cat-field" style={{ gridColumn:'span 2' }}><label style={ls}>{t({ id: 'biblioteca.tasks.titleField' })}</label><input type="text" value={newTask.title} onChange={e=>setNewTask(p=>({...p,title:e.target.value}))} style={fs} placeholder={t({ id: 'biblioteca.tasks.titlePlaceholder' })} /></div>
                  <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.priority' })}</label><select value={newTask.priority} onChange={e=>setNewTask(p=>({...p,priority:e.target.value}))} style={fs}><option value="baixa">{t({ id: 'biblioteca.tasks.priority.low' })}</option><option value="normal">{t({ id: 'biblioteca.tasks.priority.normal' })}</option><option value="alta">{t({ id: 'biblioteca.tasks.priority.high' })}</option></select></div>
                  <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.owner' })}</label><input type="text" value={newTask.owner} onChange={e=>setNewTask(p=>({...p,owner:e.target.value}))} style={fs} placeholder={t({ id: 'biblioteca.tasks.ownerPlaceholder' })} /></div>
                  <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.dueDate' })}</label><input type="date" value={newTask.dueDate||''} onChange={e=>setNewTask(p=>({...p,dueDate:e.target.value}))} style={fs} /></div>
                  <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.tags' })}</label><input type="text" value={newTask.tagsText||''} onChange={e=>setNewTask(p=>({...p,tagsText:e.target.value}))} style={fs} placeholder={t({ id: 'biblioteca.tasks.tagsPlaceholder' })} /></div>
                  <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={ls}>{t({ id: 'biblioteca.tasks.description' })}</label><textarea value={newTask.description} onChange={e=>setNewTask(p=>({...p,description:e.target.value}))} rows={2} style={{...fs,resize:'vertical'}} placeholder={t({ id: 'biblioteca.tasks.descPlaceholder' })} /></div>
                </div>
                <button className="cat-btn primary" onClick={createTask} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.tasks.create' })}</button>
              </div>

              {/* Vue par echeance. Quatre seaux ordonnes du plus urgent au
                  moins urgent. Le bloc « sans echeance » ferme la marche. */}
              {!hasActiveTasks && (
                <div style={{ fontSize:'.88rem', color:'var(--brand-muted)', fontStyle:'italic', padding:'8px 2px' }}>
                  {t({ id: 'biblioteca.tasks.empty' })}
                </div>
              )}
              {renderBucket('atrasada', 'biblioteca.tasks.bucket.overdue', '#f87171')}
              {renderBucket('hoje', 'biblioteca.tasks.bucket.today', '#fbbf24')}
              {renderBucket('futura', 'biblioteca.tasks.bucket.upcoming', 'var(--brand-text)')}
              {renderBucket('sem_prazo', 'biblioteca.tasks.bucket.undated', 'var(--brand-muted)')}

              {/* Taches closes (concluida / cancelada), repliees sous un
                  separateur discret pour ne pas encombrer les seaux actifs. */}
              {closedTasks.length>0 && (
                <details style={{ marginTop:10 }}>
                  <summary style={{ cursor:'pointer', fontSize:'.85rem', color:'var(--brand-muted)' }}>
                    {t({ id: 'biblioteca.tasks.closed.toggle' }, { count: closedTasks.length })}
                  </summary>
                  <div style={{ ...lw, marginTop:8, opacity:.7 }}>
                    {closedTasks.map((tk,i)=>renderTaskRow(tk,i))}
                  </div>
                </details>
              )}
            </div>)}

            {/* ── Sous-onglet MODELOS (chantier #TASKS p2) ── */}
            {tasksSubtab==='modelos' && (<div>
              <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:12 }}>
                {t({ id: 'biblioteca.templates.hint' })}
              </div>

              {/* Bouton « Nouveau modèle » — masque tant qu'un formulaire est ouvert */}
              {!editingTemplate && (
                <button className="cat-btn primary" onClick={startNewTemplate} style={{ fontSize:'.88rem', marginBottom:12 }}>
                  {t({ id: 'biblioteca.templates.new' })}
                </button>
              )}

              {/* Formulaire créer / éditer */}
              {editingTemplate && (
                <div style={bx}>
                  <h4 style={{ margin:'0 0 10px' }}>
                    {editingTemplate.id==='new'
                      ? t({ id: 'biblioteca.templates.new' })
                      : t({ id: 'biblioteca.templates.edit' })}
                  </h4>
                  <div className="cat-book-grid" style={{ marginBottom:10 }}>
                    <div className="cat-field" style={{ gridColumn:'span 2' }}>
                      <label style={ls}>{t({ id: 'biblioteca.templates.titleField' })}</label>
                      <input type="text" value={editingTemplate.template_title}
                        onChange={e=>setEditingTemplate(p=>({...p,template_title:e.target.value}))}
                        style={fs} placeholder={t({ id: 'biblioteca.templates.titlePlaceholder' })} />
                    </div>
                    <div className="cat-field">
                      <label style={ls}>{t({ id: 'biblioteca.tasks.priority' })}</label>
                      <select value={editingTemplate.template_priority}
                        onChange={e=>setEditingTemplate(p=>({...p,template_priority:e.target.value}))} style={fs}>
                        <option value="baixa">{t({ id: 'biblioteca.tasks.priority.low' })}</option>
                        <option value="media">{t({ id: 'biblioteca.tasks.priority.normal' })}</option>
                        <option value="alta">{t({ id: 'biblioteca.tasks.priority.high' })}</option>
                      </select>
                    </div>
                    <div className="cat-field">
                      <label style={ls}>{t({ id: 'biblioteca.templates.label' })}</label>
                      <input type="text" value={editingTemplate.label}
                        onChange={e=>setEditingTemplate(p=>({...p,label:e.target.value}))}
                        style={fs} placeholder={t({ id: 'biblioteca.templates.labelPlaceholder' })} />
                    </div>
                    <div className="cat-field">
                      <label style={ls}>{t({ id: 'biblioteca.tasks.tags' })}</label>
                      <input type="text" value={editingTemplate.tagsText}
                        onChange={e=>setEditingTemplate(p=>({...p,tagsText:e.target.value}))}
                        style={fs} placeholder={t({ id: 'biblioteca.tasks.tagsPlaceholder' })} />
                    </div>
                    <div className="cat-field" style={{ gridColumn:'span 3' }}>
                      <label style={ls}>{t({ id: 'biblioteca.tasks.description' })}</label>
                      <textarea value={editingTemplate.template_description}
                        onChange={e=>setEditingTemplate(p=>({...p,template_description:e.target.value}))}
                        rows={2} style={{...fs,resize:'vertical'}}
                        placeholder={t({ id: 'biblioteca.tasks.descPlaceholder' })} />
                    </div>
                  </div>

                  {/* Bascule récurrent / ponctuel + cadence */}
                  <div style={{ padding:10, borderRadius:8, background:'rgba(0,0,0,.12)', marginBottom:10 }}>
                    <label style={{ display:'flex', gap:8, alignItems:'center', fontSize:'.88rem', cursor:'pointer' }}>
                      <input type="checkbox" checked={editingTemplate.recurrent}
                        onChange={e=>setEditingTemplate(p=>({...p,recurrent:e.target.checked}))} />
                      {t({ id: 'biblioteca.templates.recurrentToggle' })}
                    </label>
                    {editingTemplate.recurrent ? (
                      <div style={{ display:'flex', gap:8, alignItems:'center', marginTop:8, flexWrap:'wrap' }}>
                        <span style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>
                          {t({ id: 'biblioteca.templates.cadencePrefix' })}
                        </span>
                        <input type="number" min={1} value={editingTemplate.interval_count}
                          onChange={e=>setEditingTemplate(p=>({...p,interval_count:e.target.value}))}
                          style={{...fs, width:80}} />
                        <select value={editingTemplate.interval_unit}
                          onChange={e=>setEditingTemplate(p=>({...p,interval_unit:e.target.value}))}
                          style={{...fs, width:'auto'}}>
                          <option value="dia">{t({ id: 'biblioteca.templates.unit.dia' })}</option>
                          <option value="semana">{t({ id: 'biblioteca.templates.unit.semana' })}</option>
                          <option value="mes">{t({ id: 'biblioteca.templates.unit.mes' })}</option>
                        </select>
                      </div>
                    ) : (
                      <div style={{ fontSize:'.8rem', color:'var(--brand-muted)', fontStyle:'italic', marginTop:6 }}>
                        {t({ id: 'biblioteca.templates.punctualHint' })}
                      </div>
                    )}
                  </div>

                  {/* Actif / inactif — seulement en édition */}
                  {editingTemplate.id!=='new' && (
                    <label style={{ display:'flex', gap:8, alignItems:'center', fontSize:'.88rem', cursor:'pointer', marginBottom:10 }}>
                      <input type="checkbox" checked={editingTemplate.is_active}
                        onChange={e=>setEditingTemplate(p=>({...p,is_active:e.target.checked}))} />
                      {t({ id: 'biblioteca.templates.activeToggle' })}
                    </label>
                  )}

                  <div style={{ display:'flex', gap:8 }}>
                    <button className="cat-btn primary" onClick={saveTemplate} disabled={saving} style={{ fontSize:'.88rem' }}>
                      {saving ? t({ id: 'common.saving' }) : t({ id: 'common.save' })}
                    </button>
                    <button className="cat-btn secondary" onClick={cancelEditTemplate} disabled={saving} style={{ fontSize:'.88rem' }}>
                      {t({ id: 'common.cancel' })}
                    </button>
                  </div>
                </div>
              )}

              {/* Liste des modèles */}
              {templates.length===0 && !editingTemplate && (
                <div style={{ fontSize:'.88rem', color:'var(--brand-muted)', fontStyle:'italic', padding:'8px 2px' }}>
                  {t({ id: 'biblioteca.templates.empty' })}
                </div>
              )}
              {templates.length>0 && (
                <div style={lw}>
                  {templates.map((tpl,i)=>{
                    const isRecurrent = tpl.interval_count!=null && tpl.interval_unit!=null;
                    return (
                    <div key={tpl.id} style={{ ...lr(i), flexDirection:'column', alignItems:'stretch', gap:6 }}>
                      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', gap:8 }}>
                        <div style={{ flex:1 }}>
                          <div style={{ fontSize:'.9rem', fontWeight:600, display:'flex', alignItems:'center', gap:6, flexWrap:'wrap' }}>
                            {localizedText(tpl.title_i18n, tpl.template_title) || t({ id: 'common.noTitle' })}
                            {!tpl.is_active && (
                              <span className="cat-pill" style={{ fontSize:'.62rem', padding:'1px 6px', background:'rgba(255,255,255,.1)' }}>
                                {t({ id: 'biblioteca.rules.inactive' })}
                              </span>
                            )}
                            <span className={`cat-pill ${isRecurrent?'info':''}`} style={{ fontSize:'.62rem', padding:'1px 6px' }}>
                              {isRecurrent
                                ? t({ id: 'biblioteca.templates.cadenceBadge' }, { count: tpl.interval_count, unit: t({ id: `biblioteca.templates.unit.${tpl.interval_unit}` }) })
                                : t({ id: 'biblioteca.templates.punctualBadge' })}
                            </span>
                          </div>
                          <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                            {tpl.label || '—'}
                            {tpl.template_tags?.length>0 && ` · ${tpl.template_tags.join(', ')}`}
                          </div>
                          {localizedText(tpl.description_i18n, tpl.template_description) && (
                            <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginTop:2 }}>
                              {localizedText(tpl.description_i18n, tpl.template_description)}
                            </div>
                          )}
                        </div>
                        <div style={{ display:'flex', gap:4, flexShrink:0, alignItems:'center' }}>
                          <span className={`cat-pill ${tpl.template_priority==='alta'?'danger':tpl.template_priority==='baixa'?'info':'warn'}`} style={{ fontSize:'.65rem' }}>
                            {TASK_PRIO[tpl.template_priority]||tpl.template_priority}
                          </span>
                          <button className="cat-btn secondary" onClick={()=>{ setInstantiateFor(instantiateFor===tpl.id?null:tpl.id); setInstantiateDate(''); }}
                            disabled={!!editingTemplate} style={{ fontSize:'.78rem', padding:'4px 10px' }}>
                            {t({ id: 'biblioteca.templates.instantiate' })}
                          </button>
                          <button className="cat-btn secondary" onClick={()=>startEditTemplate(tpl)}
                            disabled={!!editingTemplate} style={{ fontSize:'.78rem', padding:'4px 10px' }}>
                            {t({ id: 'membership.config.action.edit' })}
                          </button>
                          <button className="cat-btn ghost" onClick={()=>deleteTemplate(tpl)}
                            disabled={!!editingTemplate} style={{ fontSize:'.78rem', padding:'4px 8px', color:'#f87171' }}>
                            {t({ id: 'common.discard' })}
                          </button>
                        </div>
                      </div>
                      {/* Mini-formulaire d'instanciation : champ date optionnel */}
                      {instantiateFor===tpl.id && (
                        <div style={{ display:'flex', gap:8, alignItems:'center', flexWrap:'wrap', padding:'8px 10px', borderRadius:8, background:'rgba(251,191,36,.08)' }}>
                          <span style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                            {t({ id: 'biblioteca.templates.instantiateDateLabel' })}
                          </span>
                          <input type="date" value={instantiateDate}
                            onChange={e=>setInstantiateDate(e.target.value)}
                            style={{...fs, width:'auto'}} />
                          <button className="cat-btn primary" onClick={()=>instantiateTemplate(tpl.id, instantiateDate)}
                            style={{ fontSize:'.8rem', padding:'4px 10px' }}>
                            {t({ id: 'biblioteca.templates.instantiateConfirm' })}
                          </button>
                          <span style={{ fontSize:'.75rem', color:'var(--brand-muted)', fontStyle:'italic' }}>
                            {isRecurrent
                              ? t({ id: 'biblioteca.templates.instantiateRecurrentHint' })
                              : t({ id: 'biblioteca.templates.instantiateDateHint' })}
                          </span>
                        </div>
                      )}
                    </div>
                    );
                  })}
                </div>
              )}
            </div>)}

            {/* ── Sous-onglet CATALOGO (chantier #TASKS p3) ── */}
            {tasksSubtab==='catalogo' && (() => {
              // Le texte des suggestions vient de la donnee (jsonb 8 langues).
              // Helper de lecture localisee avec repli sur pt-BR puis 1re cle.
              const i18nField = (obj) => {
                if (!obj) return '';
                return obj[locale] || obj['pt-BR'] || Object.values(obj)[0] || '';
              };
              // Regroupement par categorie, ordre = display_order (deja trie
              // au chargement). On conserve l'ordre d'apparition des categories.
              // Masquer les suggestions deja adoptees en tache-type (lien via
              // adopted_from_suggestion_code). Supprimer le modele les fait
              // reapparaitre. Le backfill par titre (migration) couvre l'historique.
              const adoptedCodes = new Set((templates || []).map(tp => tp.adopted_from_suggestion_code).filter(Boolean));
              const availableSuggestions = suggestions.filter(s => !adoptedCodes.has(s.code));
              const byCategory = [];
              const seen = new Map();
              for (const s of availableSuggestions) {
                if (!seen.has(s.category)) {
                  const grp = { category: s.category, items: [] };
                  seen.set(s.category, grp);
                  byCategory.push(grp);
                }
                seen.get(s.category).items.push(s);
              }
              return (
              <div>
                <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:12 }}>
                  {t({ id: 'biblioteca.catalog.hint' })}
                </div>
                {availableSuggestions.length===0 && (
                  <div style={{ fontSize:'.88rem', color:'var(--brand-muted)', fontStyle:'italic', padding:'8px 2px' }}>
                    {t({ id: 'biblioteca.catalog.empty' })}
                  </div>
                )}
                {byCategory.map(grp => (
                  <div key={grp.category} style={{ marginBottom:16 }}>
                    <h4 style={{ margin:'0 0 8px', fontSize:'.92rem' }}>
                      {t({ id: `biblioteca.catalog.category.${grp.category}`, defaultMessage: grp.category })}
                    </h4>
                    <div style={lw}>
                      {grp.items.map((s,i)=>{
                        const isRecurrent = s.suggested_interval_count!=null && s.suggested_interval_unit!=null;
                        return (
                        <div key={s.id} style={{ ...lr(i), alignItems:'flex-start', gap:10 }}>
                          <div style={{ flex:1, minWidth:0 }}>
                            <div style={{ fontSize:'.9rem', fontWeight:600, display:'flex', alignItems:'center', gap:6, flexWrap:'wrap' }}>
                              {i18nField(s.title_i18n)}
                              <span className={`cat-pill ${isRecurrent?'info':''}`} style={{ fontSize:'.62rem', padding:'1px 6px' }}>
                                {isRecurrent
                                  ? t({ id: 'biblioteca.templates.cadenceBadge' }, { count: s.suggested_interval_count, unit: t({ id: `biblioteca.templates.unit.${s.suggested_interval_unit}` }) })
                                  : t({ id: 'biblioteca.templates.punctualBadge' })}
                              </span>
                            </div>
                            <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginTop:2 }}>
                              {i18nField(s.description_i18n)}
                            </div>
                          </div>
                          <button className="cat-btn secondary" onClick={()=>adoptSuggestion(s.code)}
                            style={{ fontSize:'.78rem', padding:'4px 10px', flexShrink:0 }}>
                            {t({ id: 'biblioteca.catalog.adopt' })}
                          </button>
                        </div>
                        );
                      })}
                    </div>
                  </div>
                ))}
              </div>
              );
            })()}
          </div>
          );
        })()}
        </div>

      </div>
    <Footer /></PageShell>
  );
}
