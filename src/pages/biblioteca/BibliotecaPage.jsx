import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase, apiRpc, SUPABASE_URL } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import LibraryContextBanner from '@/components/LibraryContextBanner';
import LibraryProfileBanner from '@/components/LibraryProfileBanner';
import TransitionsPanel from '@/components/TransitionsPanel';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import AppIcon from '@/components/ui/AppIcon';
import RetentionPolicySection from '@/components/library/RetentionPolicySection';
import ReadingNotesModeration from '@/components/biblioteca/ReadingNotesModeration';
import LibraryVisualAssetsSection from '@/components/library/LibraryVisualAssetsSection';
import DocumentGovernanceSection from '@/components/library/DocumentGovernanceSection';
import LibraryDigitalPolicySection from '@/components/library/LibraryDigitalPolicySection';
import PolicySetManager from '@/components/library/PolicySetManager';
import RegimeStateBox from '@/components/library/RegimeStateBox';
import WorkspaceInspectorModal from '@/components/library/WorkspaceInspectorModal';
import ExchangeProposalForm from '@/components/library/ExchangeProposalForm';
import ExchangeRequestsList from '@/components/library/ExchangeRequestsList';
import ExchangeFollowupPanel from '@/components/library/ExchangeFollowupPanel';
import LibraryContactProfileSection from '@/components/library/LibraryContactProfileSection';
import LibraryPublicContactSection from '@/components/library/LibraryPublicContactSection';
import LocaleSelector from '@/components/library/LocaleSelector';
import LibraryNumberingSection from '@/components/library/LibraryNumberingSection'; /* E21 : serie de tombos et cote (15/09/2026) */
import TeamPanel from '@/components/team/TeamPanel';
import LeitoresPanel from '@/components/biblioteca/LeitoresPanel';
import EventosPanel from '@/components/biblioteca/EventosPanel';
import LibraryPartnershipsSection from '@/components/library/LibraryPartnershipsSection';
import StabilizedPartnershipsSection from '@/components/library/StabilizedPartnershipsSection';
import ExternalDepositPartnerSection from '@/components/library/ExternalDepositPartnerSection';
import PebHistorySection from '@/components/library/PebHistorySection';
import IllSection from './IllSection';
import TasksSection from './TasksSection';
import MembershipSection from './MembershipSection';
import DepositSection from './DepositSection';
import CorrespondanceSection from './CorrespondanceSection'; /* G19 lot 2 : l'onglet Correspondance (08/10/2026) */
import ReadLanguagesField from './ReadLanguagesField'; /* G19 lot 4 : les langues que l'équipe lit */
import { fs, ls, bx } from './styles';
import FinanceReportsSection from '@/components/biblioteca/FinanceReportsSection';
import '@/components/team/TeamPanel.css';
import '../catalogacao/CatalogacaoPage.css';
import UserHeroBadge from '@/components/UserHeroBadge';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';
import { TASK_STATES, taskStatusLabel } from '@/lib/taskStatus';
// SERVICE_MODES built inside component with t() — was hardcoded pt-BR (audit 07/05/2026)
// TASK_PRIO   built inside component with t() — was hardcoded pt-BR (audit 07/05/2026)
// ILL_STATUS built inside component with t()
// TASK_STATUS built inside component with t()

// NOTIFICATION_FLAGS keys — labels resolved via t() inside the component
const NOTIFICATION_FLAG_KEYS = [
  'reservation_created', 'reservation_status', 'reservation_workflow', 'local_consultation',
  'loan_lifecycle', 'loan_reminders', 'loan_overdue',
  'profile_restriction', 'cotisation_payment_mail',
  'admin_copy_reservations', 'admin_copy_loans', 'tech_alerts', 'task_alerts',
];

// Perf (12/06/2026) : onglets dont l'affichage consomme les groupes de donnees
// « lourds » (membres, PEB, intercambios, taches). Leur 1re visite declenche
// loadHeavy() ; les autres onglets se contentent du noyau charge au montage.
const HEAVY_TABS = ['ill', 'exchanges', 'tasks', 'reports'];

export default function BibliotecaPage() {
  const { user } = useAuth();
  const { libraryId, libraryName, role, governance_mode, patchLibrary, libraryResolved } = useLibrary();
  const { formatMessage: t, locale } = useIntl();
  useDocumentTitle(t({ id: 'pageTitle.biblioteca' }));
  // Rôle connu, OU résolution finie sans rôle (compte sans bibliothèque) :
  // sinon un tel compte chargeait sans fin (05/10/2026).
  const roleLoaded = (role !== null && role !== undefined) || libraryResolved;
  const isCoord = role === 'coordenador' || role === 'administrador';
  const isLibrarian = role === 'librarian' || isCoord;

  // SERVICE_MODES localized via t() — was hardcoded pt-BR before audit 07/05/2026.
  // Valeurs alignées sur le CHECK library_service_state_service_mode_check
  // (funcionamento_normal | somente_consulta | pausada). Les anciennes valeurs
  // (funcionamento_reduzido/recesso/suspenso) violaient le CHECK → 23514 au save.
  const SERVICE_MODES = useMemo(() => ([
    { value: 'funcionamento_normal', label: t({ id: 'rede.serviceMode.funcionamento_normal' }) },
    { value: 'somente_consulta',     label: t({ id: 'rede.serviceMode.somente_consulta' }) },
    { value: 'pausada',              label: t({ id: 'rede.serviceMode.pausada' }) },
  ]), [t]);

  // TASK_PRIO localized via t() — was hardcoded pt-BR before audit 07/05/2026.
  const TASK_PRIO = useMemo(() => ({
    alta:   t({ id: 'biblioteca.tasks.priority.alta' }),
    // `media` est la valeur de la base (CHECK des modèles, défaut des tâches) ; `normal`
    // n'a jamais existé qu'à l'écran — gardé pour une ligne saisie avant le 29/09/2026.
    media:  t({ id: 'biblioteca.tasks.priority.normal' }),
    normal: t({ id: 'biblioteca.tasks.priority.normal' }),
    baixa:  t({ id: 'biblioteca.tasks.priority.baixa' }),
  }), [t]);

  // FIX BUG #2: TASK_STATUS was referenced but never defined, causing ReferenceError
  // when calling generateReportText(). Built here via useMemo to localize labels.
  // Les sept états de la base (src/lib/taskStatus.js), plus `pendente` pour une ligne
  // d'avant la contrainte du 31/08 : le rapport ne doit jamais imprimer un code brut.
  const TASK_STATUS = useMemo(
    () => Object.fromEntries([...TASK_STATES, 'pendente'].map(s => [s, taskStatusLabel(t, s)])),
    [t],
  );

  // Barre de pastilles partagee `.ab-tabbar` (src/styles/tabbar.css), commune a
  // toutes les pages a onglets. `separator` marque le debut d'un groupe (ecart
  // AVANT la pastille : ici, tout ce qui regarde hors de la biblio).
  const ALL_TABS = [
    { id: 'identity', icon: '🏛️', label: t({ id: 'biblioteca.tab.identity' }), coordOnly: true },
    { id: 'comms', icon: '📣', label: t({ id: 'biblioteca.tab.comms' }), coordOnly: true },
    { id: 'regulation', icon: 'scrollText', label: t({ id: 'biblioteca.tab.regulation' }), coordOnly: true },
    { id: 'privacy', icon: '🔒', label: t({ id: 'biblioteca.tab.privacy' }) },
    { id: 'documents', icon: '📄', label: t({ id: 'biblioteca.tab.documents' }), coordOnly: true },
    // Paquet E.5 refactor (20/05/2026) : transitions de profil (gouvernance politique)
    { id: 'transicoes', icon: '🔄', label: t({ id: 'biblioteca.tab.transitions' }), coordOnly: true, governance_only: true },
    { id: 'team', icon: '👥', label: t({ id: 'biblioteca.tab.team' }) },
    { id: 'leitores', icon: '👤', label: t({ id: 'biblioteca.tab.leitores' }) },
    { id: 'eventos', icon: '🗓️', label: t({ id: 'biblioteca.tab.events' }), coordOnly: true },
    { id: 'exchanges', icon: '🔀', label: t({ id: 'biblioteca.tab.exchanges' }), separator: true },
    { id: 'correspondance', icon: 'mail', label: t({ id: 'biblioteca.tab.correspondance' }), coordOnly: true },
    { id: 'ill', icon: '🚚', label: t({ id: 'biblioteca.tab.ill' }) },
    { id: 'reports', icon: '📊', label: t({ id: 'biblioteca.tab.reports' }) },
    { id: 'notas', icon: '✍️', label: t({ id: 'biblioteca.tab.readingNotes' }) },
    { id: 'tasks', icon: '📋', label: t({ id: 'biblioteca.tab.tasks' }) },
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
  // #tab=<id> ouvre l'onglet demande (liens profonds : documentation, cloche,
  // page « Je veux… ») — meme convention que Catalogage et Reseau (05/09/2026).
  useEffect(() => {
    const wanted = window.location.hash.replace('#tab=', '');
    if (wanted && visibleTabs.some(tb => tb.id === wanted)) setTab(wanted);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visibleTabs.length]);
  const [wsInspectorOpen, setWsInspectorOpen] = useState(false);
  const [refreshState, setRefreshState] = useState('idle');
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [saving, setSaving] = useState(false);
  const regFileRef = useRef(null);
  // CARD-LOCAL-2/N5 : « dernier identifiant attribué » dérivé (hint config, coord).
  const [lastAssignedIdentity, setLastAssignedIdentity] = useState(null);
  useEffect(() => {
    if (tab !== 'identity' || !isCoord || !libraryId) return;
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase.schema('api').rpc('get_last_assigned_reader_identity', { p_library_id: libraryId });
        if (!cancelled) setLastAssignedIdentity(data ?? null);
      } catch { if (!cancelled) setLastAssignedIdentity(null); }
    })();
    return () => { cancelled = true; };
  }, [tab, isCoord, libraryId]);

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
  const [openingHours, setOpeningHours] = useState({ slots: [], public_note: '' });
  const [fichePublic, setFichePublic] = useState({ contact_is_public: false, hours_is_public: false });
  const [fpSaving, setFpSaving] = useState('');
  const [ohSaving, setOhSaving] = useState(false);
  const [ohMsg, setOhMsg] = useState('');
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
  // Dépôt de garantie (DEPOT-1/6) — opt-in par biblio, calque des cotisations.
  const [depositRules, setDepositRules] = useState([]);
  const [templates, setTemplates] = useState([]);
  // Chantier #TASKS etape 6 paquet 3 (24/05/2026) : catalogue de suggestions.
  // suggestions = painel_task_suggestion_catalog (global, lecture seule).
  // Le texte des suggestions vit dans la donnee (title_i18n/description_i18n
  // jsonb 8 langues) ; seule l'ossature du sous-onglet a des cles i18n.
  const [suggestions, setSuggestions] = useState([]);
  const [allLibraries, setAllLibraries] = useState([]);
  // #ILL-partial — exemplaires des prêts DÉJÀ enregistrés (distinct de illItems,
  // qui est le panier du formulaire de création). Dictionnaire { loanId: [items] }.
  const [illItemsByLoan, setIllItemsByLoan] = useState({});
  // EA-12 phase 2 (dette 2) : bibliotheques eligibles au PEB.
  // Regle alignee sur fn_peb_authorized : federee + circulation active + active.
  const pebEligibleLibraries = allLibraries.filter(l =>
    l.network_mode === 'federated'
    && l.circulation_mode && l.circulation_mode !== 'off'
    && l.is_active !== false
  );

  // ── Carregamento ────────────────────────────────────────
  // Perf (12/06/2026) : le montage ne charge plus que le « noyau » -- config
  // legere mono-ligne + bandeau KPI (stats) + allLibraries (selects PEB /
  // onglets documents-exchanges), commun a tous les onglets. Les groupes lourds
  // (membres, PEB+items, intercambios, taches/modeles/suggestions) ne sont
  // charges qu'a la 1re visite d'un onglet consommateur (cf. HEAVY_TABS), via
  // loadHeavy(). Avant, loadAll tirait ~24 requetes au montage, pour tous les
  // onglets a la fois. Le fetch library_circulation_policy_sets a ete retire :
  // il etait charge puis jamais utilise (RegimeStateBox charge le sien).
  const heavyLoadedRef = useRef(false);

  const loadCore = useCallback(async () => {
    if (!libraryId) return;
    try {
      const [libR, commR, ssR, regR, dgR, mcR, npR, mrR, ohR, pcR] = await Promise.all([
        supabase.from('libraries').select('*').eq('id', libraryId).single(),
        supabase.from('library_commons').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_service_state').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_regulation_documents').select('*').eq('library_id', libraryId).order('created_at', { ascending: false }),
        supabase.from('library_document_governance').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_mail_channels').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_notification_policies').select('*').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_membership_rules').select('*').eq('library_id', libraryId).order('display_order', { ascending: true }).order('created_at', { ascending: true }),
        supabase.from('library_opening_hours').select('slots,public_note,is_public').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_public_contact').select('is_public').eq('library_id', libraryId).maybeSingle(),
      ]);
      setLib(libR.data); setCommons(commR.data); setServiceState(ssR.data);
      setOpeningHours({ slots: Array.isArray(ohR.data?.slots) ? ohR.data.slots : [], public_note: ohR.data?.public_note || '' });
      setFichePublic({ contact_is_public: !!pcR.data?.is_public, hours_is_public: !!ohR.data?.is_public });
      setRegDocs(regR.data || []); setDocGov(dgR.data);
      // CEINTURE-CANAL (30/08/2026) : `|| {}` et non `null`. Le bloc du canal est
      // le SEUL endroit ou l on coupe les envois d une biblio ; conditionner son
      // affichage a l existence de la ligne rendait le reglage inatteignable
      // pour toute biblio qui n en avait pas (CIRA Marseille au 30/08). Une
      // migration pose desormais l invariant cote base (trigger sur libraries),
      // ceci en est la ceinture : l ecran fabrique les defauts et la RPC
      // upsert_library_mail_channel cree la ligne a la premiere sauvegarde.
      setMailChannel(mcR.data || {}); setNotifPolicy(npR.data);
      setMembershipRules(mrR.data || []);
      // Règles de dépôt de garantie (DEPOT-6) — co-chargées avec les cotisations.
      const { data: drData } = await supabase.from('library_deposit_rules')
        .select('*').eq('library_id', libraryId)
        .order('display_order', { ascending: true }).order('created_at', { ascending: true });
      setDepositRules(drData || []);
      // allLibraries : selects PEB + onglets documents/exchanges + rapport.
      const { data: allLibs } = await supabase.from('libraries').select('id, slug, name, short_name, network_mode, circulation_mode, is_active, default_locale, read_languages').order('name');
      setAllLibraries(allLibs || []);
      // Stats KPI : bandeau toujours visible au-dessus des onglets -> noyau.
      const [au, circStats] = await Promise.all([
        supabase.from('authors').select('id', { count: 'exact', head: true }),
        supabase.schema('api').from('library_circulation_stats').select('*').eq('library_id', libraryId).maybeSingle(),
      ]);
      const cs = circStats.data || {};
      setStats({
        // DOCUMENTOS = holdings de cette biblio (scope par library_id via la vue).
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
    } catch (err) { console.warn('loadCore:', err); }
  }, [libraryId]);

  const loadHeavy = useCallback(async () => {
    if (!libraryId) return;
    try {
      const [memR, illR, exR, taskR, tplR, sugR] = await Promise.all([
        supabase.from('user_library_memberships').select('*, profiles:user_id(email, first_name, last_name)').eq('library_id', libraryId).order('created_at'),
        // #ILL-archive : la file active exclut les PEB archives (onglet Rapports
        // -> PebHistorySection, vue api.peb_history_v1).
        supabase.from('interlibrary_loans_v2').select('*').or(`lender_library_id.eq.${libraryId},borrower_library_id.eq.${libraryId}`).is('archived_at', null).order('created_at', { ascending: false }).limit(50),
        // #EA-11 : trocas (intercambios) impliquant la bibliotheque.
        supabase.from('document_permission_requests').select('id, requester_library_id, target_library_id, status, created_at, decided_at, object_ref').eq('object_type', 'interlibrary_exchange').or(`requester_library_id.eq.${libraryId},target_library_id.eq.${libraryId}`).order('created_at', { ascending: false }).limit(200),
        supabase.from('painel_internal_tasks').select('*').eq('library_id', libraryId).order('created_at', { ascending: false }).limit(50),
        supabase.from('painel_recurring_task_rules').select('*').eq('library_id', libraryId).order('created_at', { ascending: false }),
        supabase.from('painel_task_suggestion_catalog').select('*').eq('is_active', true).order('display_order', { ascending: true }),
      ]);
      setMembers(memR.data || []);
      setIllLoans(illR.data || []); setExchanges(exR.data || []); setTasks(taskR.data || []);
      setTemplates(tplR.data || []);
      setSuggestions(sugR.data || []);
      // #ILL-partial — exemplaires des prets affiches, regroupes par pret.
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
      heavyLoadedRef.current = true;
    } catch (err) { console.warn('loadHeavy:', err); }
  }, [libraryId]);

  // loadAll = rechargement complet (saves, refresh manuel, generateReportText).
  const loadAll = useCallback(async () => {
    await loadCore();
    await loadHeavy();
  }, [loadCore, loadHeavy]);

  // Montage : noyau seulement (paint rapide de l'onglet par defaut).
  useEffect(() => { loadCore(); }, [loadCore]);

  // Changement de bibliotheque active : le cache lourd redevient invalide.
  useEffect(() => { heavyLoadedRef.current = false; }, [libraryId]);

  // Chargement paresseux des groupes lourds a la 1re visite d'un onglet
  // consommateur (idempotent via heavyLoadedRef).
  useEffect(() => {
    if (HEAVY_TABS.includes(tab) && !heavyLoadedRef.current) { loadHeavy(); }
  }, [tab, libraryId, loadHeavy]);

  // Correctif EA-02 : recharge avec feedback visuel (busy -> done -> idle).
  // Recharge le noyau ; le lourd uniquement s'il a deja ete charge.
  const handleRefresh = useCallback(async () => {
    if (refreshState === 'busy') return;
    setRefreshState('busy');
    try {
      await loadCore();
      if (heavyLoadedRef.current) await loadHeavy();
      setRefreshState('done');
      setTimeout(() => setRefreshState('idle'), 2000);
    } catch {
      setRefreshState('idle');
    }
  }, [loadCore, loadHeavy, refreshState]);

  // ── Save helpers ────────────────────────────────────────
  function setL(k,v){ setLib(p=>p?{...p,[k]:v}:p); }
  function setC(k,v){ setCommons(p=>p?{...p,[k]:v}:p); }
  function setSS(k,v){ setServiceState(p=>p?{...p,[k]:v}:p); }
  function setMC(k,v){ setMailChannel(p=>p?{...p,[k]:v}:p); }

  // ── Horaires/permanences hebdomadaires ──────────────────
  // day ISO 1..7 (lundi=1) ; le 2024-01-01 est un lundi → base de calcul Intl.
  const dayName = useCallback((d) => {
    try { return new Intl.DateTimeFormat(locale, { weekday: 'long' }).format(new Date(2024, 0, Number(d) || 1)); }
    catch { return String(d); }
  }, [locale]);
  // PUBLIB-OPTIN-1/2 (#PUB3) : bascule d'une section en public (coordenador), via RPC.
  async function toggleFiche(which, value){
    setFpSaving(which);
    try {
      const fn = which === 'contact' ? 'fn_set_library_contact_public' : 'fn_set_library_hours_public';
      const { error } = await apiRpc(fn, { p_library_id: libraryId, p_is_public: value });
      if (error) throw error;
      setFichePublic(p => ({ ...p, [which === 'contact' ? 'contact_is_public' : 'hours_is_public']: value }));
    } catch { /* silencieux : l'état ne bascule pas si l'RPC échoue */ }
    finally { setFpSaving(''); }
  }
  function addSlot(){ setOpeningHours(p => ({ ...p, slots: [...p.slots, { day:1, start:'18:00', end:'20:00', label:'' }] })); setOhMsg(''); }
  function updateSlot(i,k,v){ setOpeningHours(p => ({ ...p, slots: p.slots.map((s,j)=> j===i ? { ...s, [k]: v } : s) })); setOhMsg(''); }
  function removeSlot(i){ setOpeningHours(p => ({ ...p, slots: p.slots.filter((_,j)=> j!==i) })); setOhMsg(''); }
  async function saveHours(){
    setOhSaving(true); setOhMsg('');
    try {
      const clean = (openingHours.slots || [])
        .filter(s => s && s.start && s.end)
        .map(s => ({ day: Number(s.day) || 1, start: String(s.start), end: String(s.end), label: (s.label || '').trim() || undefined }));
      const { error } = await apiRpc('fn_upsert_library_opening_hours', { p_library_id: libraryId, p_slots: clean, p_public_note: openingHours.public_note || null });
      if (error) throw error;
      setOpeningHours(p => ({ ...p, slots: clean.map(s => ({ ...s, label: s.label || '' })) }));
      setOhMsg(t({ id: 'biblioteca.msg.saved' }));
    } catch (e) {
      setOhMsg(localizeError(e, t));
    } finally {
      setOhSaving(false);
    }
  }

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
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function saveIdentity() {
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      // PATCH 09/05/2026 paquet 6.3 : default_locale ajouté à l'update.
      // C'est l'identité linguistique de la biblio, configurable depuis le
      // sélecteur ajouté dans la grille identité (champ après country).
      const { error: libErr } = await supabase.from('libraries').update({ name:lib.name, short_name:lib.short_name, city:lib.city, state:lib.state, country:lib.country, default_locale:lib.default_locale||'pt-BR', read_languages:Array.isArray(lib.read_languages)?lib.read_languages:[], reader_cards_enabled:lib.reader_cards_enabled===true, reader_identity_model:lib.reader_identity_model||'free_number', reader_validation_mode:lib.reader_validation_mode||'presential', accepts_public_signup:lib.accepts_public_signup===true }).eq('id', libraryId);
      // 29/09/2026 : un refus de la base ne disait rien (« enregistré » quand même) ;
      // et la carte-lecteur, que « Mon compte » lit dans le contexte de session,
      // ne s'y voyait qu'après un rechargement.
      if (libErr) throw libErr;
      patchLibrary(libraryId, { reader_cards_enabled: lib.reader_cards_enabled === true });
      if (commons) await supabase.from('library_commons').update({ display_name:commons.display_name, contact_email:commons.contact_email, reply_to_email:commons.reply_to_email, postal_address:commons.postal_address }).eq('library_id', libraryId);
      if (serviceState) await supabase.from('library_service_state').update({ service_mode:serviceState.service_mode, allows_new_loans:serviceState.allows_new_loans, allows_new_reservations:serviceState.allows_new_reservations, public_message:serviceState.public_message, reading_notes_enabled:serviceState.reading_notes_enabled }).eq('library_id', libraryId);
      setMsg({ text: t({ id: 'biblioteca.msg.saved' }), kind: 'ok' });
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  async function saveComms() {
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      // INTERRUPTEUR-UNIQUE (30/08/2026) : `email_delivery_mode` (library_commons)
      // n'etait applique NULLE PART — ni par les fonctions notify-*, ni par register.
      // L'ecran affichait donc un selecteur « Modo de envio » qui ne coupait rien,
      // juste au-dessus des vrais champs du canal. Il est retire ; le seul
      // commutateur est desormais celui de library_mail_channels (`active` pour
      // couper, `delivery_mode` pour le transport), honore par transportDisabledReason
      // dans _shared/context/library-mail-routing.ts.
      if (commons) await supabase.from('library_commons').update({ display_name:commons.display_name, contact_email:commons.contact_email, reply_to_email:commons.reply_to_email }).eq('library_id', libraryId);
      // La RPC remplace la ligne ENTIERE : on lui repasse les champs que cet
      // ecran n edite pas (transport_state, transport_channel, last_tested_at),
      // sans quoi une sauvegarde des adresses effacerait le resultat du dernier
      // test de transport.
      if (mailChannel) {
        const { error: mcErr } = await supabase.rpc('upsert_library_mail_channel', {
          p_library_id: libraryId,
          p_channel: {
            delivery_mode: mailChannel.delivery_mode || 'platform_shared',
            admin_notification_email: mailChannel.admin_notification_email || null,
            weekly_report_email: mailChannel.weekly_report_email || null,
            severe_alert_email: mailChannel.severe_alert_email || null,
            transport_state: mailChannel.transport_state || 'not_tested',
            transport_channel: mailChannel.transport_channel || null,
            last_tested_at: mailChannel.last_tested_at || null,
            active: mailChannel.active !== false,
          },
        });
        if (mcErr) throw mcErr;
      }
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
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' }); }
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
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  // ── Retrait d'un règlement périmé ────────────────────────
  // Archivage réversible par défaut ; suppression dure réservée aux brouillons
  // jamais publiés (côté RPC). Jamais le règlement actif ni un doc référencé.
  async function removeRegimento(doc) {
    const isDraft = doc.publication_status === 'draft_only' && !doc.is_active;
    const label = doc.version_label || String(doc.id);
    const confirmMsg = isDraft
      ? t({ id: 'biblioteca.regulation.removeConfirmDelete' }, { label })
      : t({ id: 'biblioteca.regulation.removeConfirmArchive' }, { label });
    if (!window.confirm(confirmMsg)) return;
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      const { data, error } = await supabase.rpc('remove_library_regulation_document', { p_document_id: doc.id });
      if (error) throw error;
      if (data?.action === 'deleted' && Array.isArray(data.storage_paths) && data.storage_paths.length) {
        // Suppression best-effort du PDF (le fichier peut déjà être absent).
        try { await supabase.storage.from(data.storage_bucket || 'library-regimentos-public').remove(data.storage_paths); } catch { /* no-op */ }
      }
      setMsg({ text: t({ id: data?.action === 'deleted' ? 'biblioteca.regulation.deleted' : 'biblioteca.regulation.archived' }), kind: 'ok' });
      await loadAll();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setSaving(false); }
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
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  const logoUrl = commons?.logo_file_key ? `${SUPABASE_URL}/storage/v1/object/public/library-ui-assets/${commons.logo_file_key.includes('/')?commons.logo_file_key:`themes/${commons.logo_file_key}/logo-${commons.logo_file_key}.png`}` : null;

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

        {/* Décision du 01/09/2026 : le sélecteur de bibliothèque vivait UNIQUEMENT
            sur /conta, c'est-à-dire sur le profil de lectrice — alors que c'est
            ici qu'on a besoin d'en changer. Il ne s'affiche qu'à partir de deux
            appartenances, et sa source reste les appartenances : aucun droit
            n'est élargi, le contrôle est simplement posé là où il sert.
            Les bibliothécaires atteignent cette page (seuls certains onglets
            sont coordOnly), le sélecteur leur est donc accessible aussi. */}
        <LibraryContextBanner />

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

        <div className="ab-tabbar" style={{ marginBottom:18 }}>
          {/* FIX BUG #4: rename loop variable to avoid shadowing `t` */}
          {visibleTabs.map(tb => (
            <button key={tb.id} className={`ab-tabbar__tab${tb.separator?' ab-tabbar__tab--group':''}${tab===tb.id?' active':''}`}
              onClick={()=>setTab(tb.id)} aria-current={tab===tb.id ? 'page' : undefined}>
              <AppIcon className="ab-tabbar__icon" name={tb.icon} size="1em" />
              {tb.label}
            </button>
          ))}
          {/* EA-02 (21/05/2026) : bouton Atualizar global. Recharge loadAll().
              `ab-tabbar__aside` : ce n'est pas un onglet — pousse a droite sur
              ecran large, pleine largeur dans la grille mobile. */}
          <button className="cat-btn secondary ab-tabbar__aside" onClick={handleRefresh} disabled={refreshState==='busy'} title={t({ id: 'biblioteca.refresh.hint' })} style={{ fontSize:'.8rem', padding:'4px 10px' }}>{t({ id: refreshState==='busy' ? 'biblioteca.refresh.busy' : refreshState==='done' ? 'biblioteca.refresh.done' : 'biblioteca.refresh.label' })}</button>
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
            <ReadLanguagesField value={lib.read_languages} onChange={v=>setL('read_languages',v)} />
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
              <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={{...ls,display:'flex',gap:8,alignItems:'flex-start'}}><input type="checkbox" checked={serviceState.reading_notes_enabled||false} onChange={e=>setSS('reading_notes_enabled',e.target.checked)} style={{marginTop:3}} /> <span><span>{t({id:'biblioteca.identity.readingNotes'})}</span><br/><span style={{fontSize:'.8rem',color:'var(--brand-muted)',fontWeight:400}}>{t({id:'biblioteca.identity.readingNotes.hint'})}</span></span></label></div>
              <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={{...ls,display:'flex',gap:8,alignItems:'flex-start'}}><input type="checkbox" checked={lib.reader_cards_enabled||false} onChange={e=>setL('reader_cards_enabled',e.target.checked)} style={{marginTop:3}} /> <span><span>{t({id:'biblioteca.identity.readerCards'})}</span><br/><span style={{fontSize:'.8rem',color:'var(--brand-muted)',fontWeight:400}}>{t({id:'biblioteca.identity.readerCards.hint'})}</span></span></label></div>
              <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={ls}>{t({ id: 'biblioteca.identity.publicMessage' })}</label><textarea value={serviceState.public_message||''} onChange={e=>setSS('public_message',e.target.value)} rows={2} style={{...fs,resize:'vertical'}} placeholder={t({id:'biblioteca.identity.publicMessagePlaceholder'})} /></div>
            </div>
          </div>}
          {/* E21 (15/09/2026) : la serie de numeros d'inventaire et la cote se reglent ici, plus en SQL */}
          <LibraryNumberingSection libraryId={libraryId} canEdit={isCoord} />
          {/* OPENING-HOURS — horaires/permanences hebdomadaires (migration 20260617004224) */}
          <div style={bx}>
            <h4 style={{ margin:'0 0 4px' }}>{t({ id: 'biblioteca.openingHours.title' })}</h4>
            <p style={{ margin:'0 0 12px', fontSize:'.8rem', color:'var(--brand-muted)' }}>{t({ id: 'biblioteca.openingHours.hint' })}</p>
            {openingHours.slots.length === 0 ? (
              <p style={{ margin:'0 0 12px', fontSize:'.85rem', color:'var(--brand-muted)', fontStyle:'italic' }}>{t({ id: 'biblioteca.openingHours.empty' })}</p>
            ) : (
              <div style={{ display:'flex', flexDirection:'column', gap:10, marginBottom:12 }}>
                {openingHours.slots.map((s,i) => (
                  <div key={i} style={{ display:'flex', flexWrap:'wrap', gap:8, alignItems:'flex-end', padding:'10px 12px', background:'rgba(0,0,0,.12)', borderRadius:8, border:'1px solid rgba(255,255,255,.06)' }}>
                    <div style={{ minWidth:'min(130px, 100%)' }}>
                      <select value={s.day||1} onChange={e=>updateSlot(i,'day',Number(e.target.value))} style={fs}>
                        {[1,2,3,4,5,6,7].map(d => <option key={d} value={d}>{dayName(d)}</option>)}
                      </select>
                    </div>
                    <div style={{ width:110 }}>
                      <label style={{...ls,fontSize:'.72rem',marginBottom:2}}>{t({ id: 'biblioteca.openingHours.start' })}</label>
                      <input type="time" value={s.start||''} onChange={e=>updateSlot(i,'start',e.target.value)} style={fs} />
                    </div>
                    <div style={{ width:110 }}>
                      <label style={{...ls,fontSize:'.72rem',marginBottom:2}}>{t({ id: 'biblioteca.openingHours.end' })}</label>
                      <input type="time" value={s.end||''} onChange={e=>updateSlot(i,'end',e.target.value)} style={fs} />
                    </div>
                    <div style={{ flex:'1 1 160px', minWidth:'min(140px, 100%)' }}>
                      <input type="text" value={s.label||''} onChange={e=>updateSlot(i,'label',e.target.value)} style={fs} placeholder={t({ id: 'biblioteca.openingHours.labelPlaceholder' })} maxLength={80} />
                    </div>
                    <button type="button" onClick={()=>removeSlot(i)} style={{ padding:'10px 12px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', cursor:'pointer', lineHeight:1 }} aria-label={t({ id: 'common.remove' })}>×</button>
                  </div>
                ))}
              </div>
            )}
            <button type="button" onClick={addSlot} style={{ padding:'8px 14px', borderRadius:8, border:'1px solid rgba(255,255,255,.18)', background:'rgba(255,255,255,.05)', color:'#f4f4f4', cursor:'pointer', fontSize:'.85rem', marginBottom:14 }}>{t({ id: 'biblioteca.openingHours.addSlot' })}</button>
            <div className="cat-field" style={{ marginBottom:12 }}>
              <label style={ls}>{t({ id: 'biblioteca.openingHours.note' })}</label>
              <textarea value={openingHours.public_note||''} onChange={e=>{ setOpeningHours(p=>({...p,public_note:e.target.value})); setOhMsg(''); }} rows={2} style={{...fs,resize:'vertical'}} placeholder={t({ id: 'biblioteca.openingHours.notePlaceholder' })} maxLength={300} />
            </div>
            <div style={{ display:'flex', gap:12, alignItems:'center' }}>
              <button type="button" className="ab-button" onClick={saveHours} disabled={ohSaving}>{t({ id: 'common.save' })}</button>
              {ohMsg && <span style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>{ohMsg}</span>}
            </div>
          </div>
          {/* FICHE-PUBLIQUE (#PUB3) — opt-in niveau 2 : ce qui apparaît sur /bibliotecas/:slug */}
          <div style={bx}>
            <h4 style={{ margin:'0 0 4px' }}>{t({ id: 'biblioteca.publicFiche.title' })}</h4>
            <p style={{ margin:'0 0 4px', fontSize:'.8rem', color:'var(--brand-muted)' }}>{t({ id: 'biblioteca.publicFiche.hint' })}</p>
            <p style={{ margin:'0 0 12px', fontSize:'.78rem', color:'var(--brand-muted)', fontStyle:'italic' }}>{t({ id: 'biblioteca.publicFiche.requiresPublic' })}</p>
            <label style={{ display:'flex', gap:8, alignItems:'center', marginBottom:8, cursor: fpSaving==='contact'?'wait':'pointer' }}>
              <input type="checkbox" checked={fichePublic.contact_is_public} disabled={fpSaving==='contact'} onChange={e=>toggleFiche('contact', e.target.checked)} />
              <span>{t({ id: 'biblioteca.publicFiche.contactToggle' })}</span>
            </label>
            <label style={{ display:'flex', gap:8, alignItems:'center', marginBottom:12, cursor: fpSaving==='hours'?'wait':'pointer' }}>
              <input type="checkbox" checked={fichePublic.hours_is_public} disabled={fpSaving==='hours'} onChange={e=>toggleFiche('hours', e.target.checked)} />
              <span>{t({ id: 'biblioteca.publicFiche.hoursToggle' })}</span>
            </label>
            <p style={{ margin:0, fontSize:'.78rem', color:'var(--brand-muted)' }}>⚠ {t({ id: 'biblioteca.publicFiche.collective' })}</p>
          </div>
          {/* CARD-LOCAL-2/3 (N5) — modèle d'identité lecteur·rice + mode de validation */}
          <div style={bx}>
            <h4 style={{ margin:'0 0 4px' }}>{t({ id: 'biblioteca.readerIdentity.title' })}</h4>
            <p style={{ margin:'0 0 10px', fontSize:'.8rem', color:'var(--brand-muted)' }}>{t({ id: 'biblioteca.readerIdentity.hint' })}</p>
            <div className="cat-book-grid">
              <div className="cat-field">
                <label style={ls}>{t({ id: 'biblioteca.readerIdentity.model' })}</label>
                <select value={lib.reader_identity_model||'free_number'} onChange={e=>setL('reader_identity_model',e.target.value)} style={fs}>
                  <option value="free_number">{t({id:'biblioteca.readerIdentity.model.free_number'})}</option>
                  <option value="sequenced_number">{t({id:'biblioteca.readerIdentity.model.sequenced_number'})}</option>
                  <option value="name">{t({id:'biblioteca.readerIdentity.model.name'})}</option>
                  <option value="none">{t({id:'biblioteca.readerIdentity.model.none'})}</option>
                </select>
              </div>
              <div className="cat-field">
                <label style={ls}>{t({ id: 'biblioteca.readerIdentity.mode' })}</label>
                <select value={lib.reader_validation_mode||'presential'} onChange={e=>setL('reader_validation_mode',e.target.value)} style={fs}>
                  <option value="presential">{t({id:'biblioteca.readerIdentity.mode.presential'})}</option>
                  <option value="remote">{t({id:'biblioteca.readerIdentity.mode.remote'})}</option>
                  <option value="none">{t({id:'biblioteca.readerIdentity.mode.none'})}</option>
                </select>
              </div>
              {/* #LIB-SIGNUP-UI — interrupteur d'ouverture des inscriptions publiques (accepts_public_signup) */}
              <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={{...ls,display:'flex',gap:8,alignItems:'flex-start'}}><input type="checkbox" checked={lib.accepts_public_signup||false} onChange={e=>setL('accepts_public_signup',e.target.checked)} style={{marginTop:3}} /> <span><span>{t({id:'biblioteca.readerIdentity.publicSignup'})}</span><br/><span style={{fontSize:'.8rem',color:'var(--brand-muted)',fontWeight:400}}>{t({id:'biblioteca.readerIdentity.publicSignup.hint'})}</span></span></label></div>
              {lastAssignedIdentity != null && lastAssignedIdentity !== '' && (
                <div className="cat-field" style={{ gridColumn:'span 3' }}>
                  <span style={{ fontSize:'.8rem', color:'var(--brand-muted)' }}>{t({ id: 'biblioteca.readerIdentity.lastAssigned' }, { value: lastAssignedIdentity })}</span>
                </div>
              )}
            </div>
          </div>
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
            </div>
          </div>}
          {mailChannel && <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.comms.adminRecipients' })}</h4>
            <div className="cat-book-grid">
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.adminEmail' })}</label><input type="email" value={mailChannel.admin_notification_email||''} onChange={e=>setMC('admin_notification_email',e.target.value)} style={fs} placeholder="admin@biblioteca.org" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.weeklyEmail' })}</label><input type="email" value={mailChannel.weekly_report_email||''} onChange={e=>setMC('weekly_report_email',e.target.value)} style={fs} placeholder="equipe@biblioteca.org" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.alertEmail' })}</label><input type="email" value={mailChannel.severe_alert_email||''} onChange={e=>setMC('severe_alert_email',e.target.value)} style={fs} placeholder="urgente@biblioteca.org" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.transport' })}</label>
                <select value={mailChannel.delivery_mode||'platform_shared'} onChange={e=>setMC('delivery_mode',e.target.value)} style={fs}>
                  <option value="platform_shared">{t({ id: 'biblioteca.comms.transport.platform_shared' })}</option>
                  <option value="platform_shared_local_reply">{t({ id: 'biblioteca.comms.transport.platform_shared_local_reply' })}</option>
                  <option value="library_own_transport">{t({ id: 'biblioteca.comms.transport.library_own_transport' })}</option>
                </select>
              </div>
              <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={{...ls,display:'flex',gap:8,alignItems:'flex-start'}}><input type="checkbox" checked={mailChannel.active!==false} onChange={e=>setMC('active',e.target.checked)} style={{marginTop:3}} /> <span><span>{t({id:'biblioteca.comms.channelActive'})}</span><br/><span style={{fontSize:'.8rem',color:'var(--brand-muted)',fontWeight:400}}>{t({id:'biblioteca.comms.channelActive.hint'})}</span></span></label></div>
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
            <div style={{ display:'grid', gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr)', gap:6 }}>
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
            {regDocs.filter(doc => !doc.archived_at).map(doc => (
              <div key={doc.id} style={{ padding:'8px 10px', borderRadius:6, background:'rgba(0,0,0,.15)', marginBottom:6, display:'flex', justifyContent:'space-between', alignItems:'center', gap:8 }}>
                <div>
                  <div style={{ fontSize:'.9rem', fontWeight:600 }}>{doc.version_label||t({ id: 'biblioteca.regulation.versionFallback' }, { id: doc.id })}</div>
                  <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                    {doc.doc_kind ? t({ id: `biblioteca.regulation.docKind.${doc.doc_kind}`, defaultMessage: doc.doc_kind }) : '—'}
                    {' · '}
                    {doc.publication_status ? t({ id: `biblioteca.regulation.pubStatus.${doc.publication_status}`, defaultMessage: doc.publication_status }) : '—'}
                    {doc.is_active && <> · <span className="cat-pill ok" style={{ fontSize:'.65rem' }}>{t({ id: 'common.active' })}</span></>}
                  </div>
                </div>
                <div style={{ display:'flex', gap:8, alignItems:'center', flexShrink:0 }}>
                  {doc.storage_path_public && <a href={`${SUPABASE_URL}/storage/v1/object/public/${doc.storage_bucket||'library-regimentos-public'}/${doc.storage_path_public}`} target="_blank" rel="noopener" className="cat-btn secondary" style={{ fontSize:'.82rem', padding:'5px 12px' }}>{t({ id: 'biblioteca.regulation.openPdf' })}</a>}
                  {isCoord && !doc.is_active && (
                    <button type="button" className="cat-btn secondary" disabled={saving}
                      onClick={() => removeRegimento(doc)}
                      title={t({ id: 'biblioteca.regulation.removeHint' })}
                      style={{ fontSize:'.82rem', padding:'5px 12px', color:'var(--danger, #e06666)' }}>
                      {t({ id: 'biblioteca.regulation.remove' })}
                    </button>
                  )}
                </div>
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

          {/* ─── Cotisation associative (E6 lot 3 : MembershipSection) ─── */}
          <MembershipSection libraryId={libraryId} lib={lib} setLib={setLib}
            rules={membershipRules} setRules={setMembershipRules} setMsg={setMsg} />

          {/* ─── Dépôt de garantie (DEPOT-1/6 ; E6 lot 3 : DepositSection) ───
              Opt-in strict par biblio : OFF par défaut → rien n'apparaît
              au comptoir / dans /conta / dans les rapports. */}
          <DepositSection libraryId={libraryId} lib={lib} setLib={setLib}
            rules={depositRules} setRules={setDepositRules} setMsg={setMsg} />
        </div>)}

        {/* ═══ 4. Documentos e relações externas ═══════ */}
        {tab==='documents' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.documents.title' })}</h3>
          {/* EA-08 (21/05/2026) : editeur de gouvernance documentale.
              Restaure la fonctionnalite du HTML d'origine. Doctrine :
              gouvernance documentale = attribut local par biblioteca. */}
          <DocumentGovernanceSection libraryId={libraryId} canEdit={isCoord} />
          {/* 05/10/2026 : lecture publique d'œuvres sous droits — choix de la coordination (20261005092916) */}
          <LibraryDigitalPolicySection libraryId={libraryId} canEdit={isCoord} />
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
          {/* Inc. B2 : enregistrer un partenaire EXTERNE de dépôt (ex. CIRA
              Marseille) -> crée l'entité catalog_partners + la source de dépôt
              liée, qui apparaît ensuite à l'import. Remplace le « + » texte-libre
              cassé de la page Import. Spec : docs/journal/cadrages/
              CADRAGE_partenaire_import_unification_2026-06-11.md */}
          <ExternalDepositPartnerSection
            libraryId={libraryId}
            canEdit={isCoord}
          />
          {/* §21 PARTNER P5b : console des partenariats STABILISÉS (cycle de vie +
              droits réciproques), au-dessus de l'annuaire déclaratif ci-dessus. */}
          <StabilizedPartnershipsSection
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
            de la biblio. GOUV-13 (01/09/2026) : l'accueil dans l'équipe s'y
            PROPOSE via le circuit d'invitation (fn_team_propose_invitation,
            p_role='librarian') — la promotion directe est condamnée. */}
        {tab==='leitores' && (
          <LeitoresPanel libraryId={libraryId} />
        )}

        {/* ═══ 5ter. Événements ════════════════════════ */}
        {/* Événements organisés par la biblio (lectures publiques, débats…),
            présentés côté lecteur dans /conta. Réservé au coordinateur
            (coordOnly). Ajouté 2026-07-05. */}
        {tab==='eventos' && (
          <EventosPanel libraryId={libraryId} />
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

        {/* ═══ 7. Empréstimos interbibliotecas (E6 lot 1 : IllSection) ═══ */}
        {tab==='ill' && (
          <IllSection libraryId={libraryId} illLoans={illLoans} illItemsByLoan={illItemsByLoan}
            allLibraries={allLibraries} pebEligibleLibraries={pebEligibleLibraries} isCoord={isCoord}
            setMsg={setMsg} onChanged={loadAll} />
        )}

        {/* ═══ 8. Relatórios e resumos ═════════════════ */}
        {tab==='reports' && (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.reports.title' })}</h3>
          <div style={bx}>
            <div className="cat-book-grid">
              {[{v:stats.books,l:t({id:'catalog.stats.documents'})},{v:stats.authors,l:t({id:'catalog.stats.authorities'})},{v:stats.exemplars,l:t({id:'catalog.stats.exemplars'})},{v:stats.readers,l:t({id:'biblioteca.stats.readersActive'})},{v:stats.loansOpen,l:t({id:'biblioteca.stats.loansOpen'})},{v:stats.loansOverdue,l:t({id:'biblioteca.stats.loansOverdue'}),warn:stats.loansOverdue>0},{v:stats.loansCreated7d,l:t({id:'biblioteca.stats.loansCreated7d'})},{v:stats.loansCreated30d,l:t({id:'biblioteca.stats.loansCreated30d'})},{v:stats.loansReturned7d,l:t({id:'biblioteca.stats.loansReturned7d'})},{v:stats.reservationsActive,l:t({id:'biblioteca.stats.reservationsActive'})},{v:stats.consultationsActive,l:t({id:'biblioteca.stats.consultationsActive'})},{v:stats.trocasActive,l:t({id:'biblioteca.stats.trocasActive'})},{v:stats.librariansActive,l:t({id:'biblioteca.stats.librariansActive'})}].map((s,i)=>(
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

          {/* Suivi financier exportable (cotisations + dépôts de garantie, DEPOT-9).
              Chaque sous-section ne s'affiche que si le système est actif. */}
          <FinanceReportsSection
            libraryId={libraryId}
            membershipEnabled={!!lib?.membership_enabled}
            depositEnabled={!!lib?.deposit_enabled}
            members={members}
          />
        </div>)}

        {/* ═══ Notes de lecture — modération (Lot 3) ═══ */}
        {tab==='notas' && <ReadingNotesModeration libraryId={libraryId} />}

        {/* ═══ 9. Tarefas internas (E6 lot 2 : TasksSection) ═══ */}
        {tab==='correspondance' && isCoord && (
          <CorrespondanceSection libraryId={libraryId} allLibraries={allLibraries} setMsg={setMsg} />
        )}
        {tab==='tasks' && (
          <TasksSection libraryId={libraryId} tasks={tasks} templates={templates} suggestions={suggestions}
            taskPrio={TASK_PRIO} setMsg={setMsg} onChanged={loadAll} />
        )}
        </div>

      </div>
    <Footer /></PageShell>
  );
}
