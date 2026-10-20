import { useState, useEffect, useCallback, useMemo, lazy, Suspense } from 'react';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase, apiQuery } from '@/lib/supabase';

import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import LibraryContextBanner from '@/components/LibraryContextBanner';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { useParams } from 'react-router-dom';
import { Button, Pill, Spinner, Skeleton } from '@/components/ui';
import AppIcon from '@/components/ui/AppIcon';
import { useToast } from '@/contexts/ToastContext';
import './PanelPage.css';
import { usePanelAvailability } from '@/hooks/usePanelAvailability';
import UserHeroBadge from '@/components/UserHeroBadge';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';
import PanelOnboarding from '@/components/painel/PanelOnboarding';
import { useSort } from './_shared';
import TabTrabalhoDoDia from './tabs/TabTrabalhoDoDia';
import { usePanelHistorico } from './hooks/usePanelHistorico';
import { usePanelEmprestimos } from './hooks/usePanelEmprestimos';
import { construireTachesDuJour } from './dailyTasks';
import { usePanelReservas } from './hooks/usePanelReservas';
import { usePanelAcoes } from './hooks/usePanelAcoes';
import { usePanelConsultas } from './hooks/usePanelConsultas';
import { usePanelLeitor } from './hooks/usePanelLeitor';
import ConsultaModals from './ConsultaModals';
import PaymentModal from './PaymentModal';
// #115 : code-split - les onglets de detail sont charges a la demande (lazy).
const TabEmprestimos     = lazy(() => import('./tabs/TabEmprestimos'));
const TabConsultasLocais = lazy(() => import('./tabs/TabConsultasLocais'));
const TabAcoes           = lazy(() => import('./tabs/TabAcoes'));
const TabReservas        = lazy(() => import('./tabs/TabReservas'));
const TabLeitor          = lazy(() => import('./tabs/TabLeitor'));
const TabHistorico       = lazy(() => import('./tabs/TabHistorico'));
const TabContribuicoes   = lazy(() => import('./tabs/TabContribuicoes'));
// MULTI P5 (volet staff) : validation des inscriptions pending_validation.
const TabValidacoes      = lazy(() => import('./tabs/TabValidacoes'));
const TabRecolement      = lazy(() => import('./tabs/TabRecolement'));
// Capas (27/09/2026) : photographier les couvertures qui manquent, livre en main.
const TabCapas           = lazy(() => import('./tabs/TabCapas'));

// ═══════════════════════════════════════════════════════════
// Workflow labels and stage lists are built inside the component using t()
// ═══════════════════════════════════════════════════════════

function PanelPageInner() {
  const { user } = useAuth();
  const { libraryId, libraryName, role, circulation_mode, membership_enabled, isNetworkAdmin, libraryResolved } = useLibrary();
  const availability = usePanelAvailability();
  const { formatMessage: t, locale } = useIntl();
  const { notifyError } = useToast();
  useDocumentTitle(t({ id: 'pageTitle.panel' }));
  // Rôle connu, OU résolution finie sans rôle (compte sans bibliothèque) :
  // sinon un tel compte chargeait sans fin (05/10/2026).
  const roleLoaded = (role !== null && role !== undefined) || libraryResolved;
  const isLibrarian = role === 'librarian' || role === 'coordenador' || role === 'administrador';
  const isCoordOrAdmin = role === 'coordenador' || role === 'administrador';
  // Récolement (MOBILE P4) : aligné EXACTEMENT sur fn_recolement_is_staff côté
  // serveur (librarian/coordenador, PAS administrador) pour ne pas afficher un
  // onglet que la RPC rejetterait.
  const canRecolement = role === 'librarian' || role === 'coordenador';

  // i18n-aware workflow labels
  // PATCH EA-13 (27/05/2026) : exhaustivité garantie sur reservas.
  // Valeurs couvertes (CHECK reserva_linhas_v2_item_status_chk + workflow_stage) :
  //   item_status : ativa | convertida_em_emprestimo | cancelada_leitor |
  //                 cancelada_biblioteca | expirada | liberada_para_circulacao
  //   workflow_stage : solicitada | em_preparacao | retirada_a_combinar |
  //                 retirada_agendada | re-retirada_agendada (fossile) |
  //                 pronta_para_retirada | retirada_efetivada |
  //                 retirada_no_show | nao_retirada (alias) |
  //                 liberada_para_circulacao | cancelada_* | expirada
  // Toute affleurance non couverte tombe sur panel.stage.unknown (fallback i18n).
  const WORKFLOW_LABELS = useMemo(() => ({
    solicitada: t({ id: 'reservation.stage.solicitada' }), em_preparacao: t({ id: 'reservation.stage.em_preparacao' }),
    pronta_para_retirada: t({ id: 'reservation.stage.pronta_para_retirada' }),
    // PATCH 07/05/2026 : 3 bugs i18n pré-existants corrigés (clés mal pointées)
    retirada_a_combinar: t({ id: 'reservation.stage.retirada_a_combinar' }),
    retirada_agendada: t({ id: 'reservation.stage.retirada_agendada' }),
    're-retirada_agendada': t({ id: 'reservation.stage.re_retirada_agendada' }),
    nao_retirada: t({ id: 'reservation.stage.nao_retirada' }),
    // PATCH 07/05/2026 : retirada_no_show est le nom canonique (phase 1 spec).
    // 'nao_retirada' reste comme alias historique pour les anciennes données.
    retirada_no_show: t({ id: 'reservation.stage.retirada_no_show' }),
    liberada_para_circulacao: t({ id: 'reservation.stage.liberada_para_circulacao' }),
    retirada_efetivada: t({ id: 'reservation.stage.retirada_efetivada' }),
    cancelada_leitor: t({ id: 'reservation.stage.cancelada_leitor' }),
    cancelada_biblioteca: t({ id: 'reservation.stage.cancelada_biblioteca' }),
    expirada: t({ id: 'reservation.stage.expirada' }),
    // PATCH EA-13 (27/05/2026) : couverture des valeurs item_status susceptibles
    // d'affleurer via le fallback historique (cf. lignes 1706, 1852, 2856).
    ativa: t({ id: 'reservation.stage.ativa' }),
    convertida_em_emprestimo: t({ id: 'reservation.stage.convertida_em_emprestimo' }),
  }), [t]);
  // PATCH EA-13 (27/05/2026) : exhaustivité garantie sur consultas.
  // Valeurs couvertes (CHECK consulta_linhas_v2_item_status_chk + workflow_stage) :
  //   item_status : ativa | consultada | cancelada_leitor |
  //                 cancelada_biblioteca | expirada
  //   workflow_stage : solicitada | em_preparacao | consulta_agendada |
  //                 consulta_realizada | nao_compareceu | cancelada_* | expirada
  const CONSULT_WORKFLOW = useMemo(() => ({
    solicitada: t({ id: 'reservation.stage.solicitada' }), em_preparacao: t({ id: 'reservation.stage.em_preparacao' }),
    consulta_agendada: t({ id: 'panel.workflow.scheduled' }), consulta_realizada: t({ id: 'panel.workflow.done' }),
    nao_compareceu: t({ id: 'panel.workflow.noShow' }),
    cancelada_leitor: t({ id: 'reservation.stage.cancelada_leitor' }),
    cancelada_biblioteca: t({ id: 'reservation.stage.cancelada_biblioteca' }),
    expirada: t({ id: 'panel.workflow.expired' }),
    // PATCH EA-13 (27/05/2026) : couverture des valeurs item_status susceptibles
    // d'affleurer via le fallback historique (cf. lignes 1852, 2856).
    ativa: t({ id: 'consultation.stage.ativa' }),
    consultada: t({ id: 'consultation.stage.consultada' }),
  }), [t]);
  // PATCH EA-13 (27/05/2026) : dico pour emprestimos.status_global (alias
  // emprestimo_status dans les vues api.emprestimo_itens_*_ui).
  // Valeurs observées en base : aberto, devolvido, encerrado.
  // parcialmente_devolvido ajouté par sécurité (clé i18n présente sur 8 langues).
  // Tout autre valeur tombera sur panel.stage.unknown via le fallback du JSX.
  const EMPRESTIMO_STATUS_LABELS = useMemo(() => ({
    aberto: t({ id: 'panel.loan.status.aberto' }),
    devolvido: t({ id: 'panel.loan.status.devolvido' }),
    encerrado: t({ id: 'panel.loan.status.encerrado' }),
    parcialmente_devolvido: t({ id: 'panel.loan.status.parcialmente_devolvido' }),
  }), [t]);
  // PATCH 07/05/2026 : renumérotation alignée sur spec section 4.
  // Le grisage des transitions illégales est calculé en runtime via canTransition()
  // ci-dessous (réplication JS de fn_check_workflow_transition).
  const RES_STAGES = useMemo(() => [
    { value: 'em_preparacao',        label: '1. '  + t({ id: 'reservation.stage.em_preparacao' }) },
    { value: 'retirada_a_combinar',  label: '2. '  + t({ id: 'reservation.stage.retirada_a_combinar' }) },
    { value: 'pronta_para_retirada', label: '3. '  + t({ id: 'reservation.stage.pronta_para_retirada' }) },
    { value: 'retirada_no_show',     label: '4. '  + t({ id: 'reservation.stage.nao_retirada' }) },
    // PATCH 09/05/2026 paquet 5b : refactor sémantique v3.
    // 'retirada_agendada' n'est plus une cible directe accessible depuis le menu :
    //   c'est le stage d'aboutissement verrouillé, atteint uniquement par
    //   confirmation mutuelle via les boutons "Confirmar e bloquear horário".
    //   Le staff doit passer par 'retirada_a_combinar' qui ouvre la négociation.
    // 're-retirada_agendada' est déprécié (matrice false partout, fossile pour
    //   résas historiques).
    // 'retirada_efetivada' (retrait effectif) : passe par le bouton dédié
    //   "Confirmar retirada" → api.confirm_pickup_v1 (conversion atomique en emprunt)
    // 'liberada_para_circulacao' : transition automatique du trigger DB après
    //   no-show ou cancel biblio. Ne JAMAIS afficher comme action staff manuelle.
  ], [t]);
  // PATCH 07/05/2026 : Réplication JS de fn_check_workflow_transition (DB)
  // pour griser les options du menu RES_STAGES qui ne sont pas autorisées
  // depuis le stage actuel d'une réservation, pour le rôle staff courant.
  // Spec section 4 : matrice de transitions.
  //
  // PATCH 09/05/2026 paquet 5b : refactor sémantique v3.
  // - retirada_a_combinar = stage central de négociation (forme verbale).
  // - retirada_agendada = stage d'aboutissement verrouillé, atteint UNIQUEMENT
  //   via fn_confirm_pickup_slot_as_* (boutons inline). Aucun chemin direct
  //   depuis solicitada/em_preparacao/retirada_a_combinar via advance_reservation.
  // - re-retirada_agendada = déprécié, false partout (fossile historique).
  //
  // ⚠️ Cette fonction DOIT rester synchrone avec la fonction DB
  //   public.fn_check_workflow_transition. En cas de changement de matrice côté DB,
  //   répliquer ici. Le helper DB reste la source de vérité (validé en runtime
  //   par les wrappers api.*) ; le grisage UI est purement informatif.
  const canTransition = useCallback((fromStage, toStage, actorRole) => {
    // Normalisation alias historique
    const f = fromStage === 'nao_retirada' ? 'retirada_no_show' : fromStage;
    const tg = toStage === 'nao_retirada' ? 'retirada_no_show' : toStage;
    if (!f || !tg || !actorRole) return false;

    // États terminaux : aucune transition humaine sortante
    const TERMINAL = new Set([
      'retirada_efetivada', 'cancelada_leitor', 'cancelada_biblioteca',
      'expirada', 'liberada_para_circulacao', 'retirada_no_show',
    ]);
    if (TERMINAL.has(f)) return false;

    // Lecteur : annulation à tout moment avant retirada_efetivada.
    // re-retirada_agendada conservé dans l'ensemble pour compatibilité résas
    // historiques (matrice DB v3 : annulable mais pas de transition sortante
    // vers d'autres stages).
    if (actorRole === 'lecteur') {
      const ANNULABLE = new Set([
        'solicitada', 'em_preparacao', 'retirada_agendada',
        'retirada_a_combinar', 're-retirada_agendada', 'pronta_para_retirada',
      ]);
      return tg === 'cancelada_leitor' && ANNULABLE.has(f);
    }

    // Coordenador : annulation biblio à toute étape non-terminale
    if (actorRole === 'coordenador' && tg === 'cancelada_biblioteca') {
      const NON_TERMINAL = new Set([
        'solicitada', 'em_preparacao', 'retirada_agendada',
        'retirada_a_combinar', 're-retirada_agendada', 'pronta_para_retirada',
      ]);
      if (NON_TERMINAL.has(f)) return true;
    }

    // System (cron, trigger) : transitions automatiques.
    // PATCH paquet 5a : retirada_agendada retiré du périmètre no-show automatique
    // (créneau verrouillé = pas de timeout négociation, géré séparément).
    // re-retirada_agendada conservé pour compatibilité résas historiques.
    if (actorRole === 'system') {
      if (tg === 'expirada' && f === 'solicitada') return true;
      if (tg === 'retirada_no_show' && ['pronta_para_retirada', 'retirada_agendada', 're-retirada_agendada'].includes(f)) return true;
      return false;
    }

    // Librarian/coordenador : transitions opérationnelles
    if (actorRole !== 'librarian' && actorRole !== 'coordenador') return false;

    // Matrice v3 : retirada_agendada n'est plus une cible advance_reservation.
    // Atteint uniquement via fn_confirm_pickup_slot_as_* depuis retirada_a_combinar.
    // re-retirada_agendada : false partout (déprécié, plus aucune transition).
    const TRANSITIONS = {
      solicitada:              ['em_preparacao', 'retirada_a_combinar'],
      em_preparacao:           ['retirada_a_combinar'],
      retirada_a_combinar:     ['pronta_para_retirada'],
      retirada_agendada:       ['pronta_para_retirada'],
      're-retirada_agendada':  [],
      pronta_para_retirada:    ['retirada_efetivada', 'retirada_no_show'],
    };
    const allowed = TRANSITIONS[f] || [];
    return allowed.includes(tg);
  }, []);

  // Mapping rôle frontend → actor_role attendu par la matrice DB
  // Note : isCoordOrAdmin couvre 'coordenador' ET 'administrador' qui ont les
  // mêmes capacités côté workflow réservation (cf. spec et helper DB).
  const actorRole = useMemo(() => {
    if (isCoordOrAdmin) return 'coordenador';
    if (isLibrarian) return 'librarian';
    return null;
  }, [isCoordOrAdmin, isLibrarian]);

  const [tab, setTab] = useState('trabalho-do-dia');
  // /painel/:tab existait dans le routeur sans etre lu : l'onglet demande
  // s'ouvre desormais (liens profonds — documentation, cloche, « Je veux… »).
  const { tab: routeTab } = useParams();
  useEffect(() => {
    if (routeTab && ['trabalho-do-dia', 'acoes', 'reservas', 'consultas-locais', 'emprestimos',
      'leitor', 'historico', 'contribuicoes', 'validacoes', 'recolement', 'capas'].includes(routeTab)) {
      setTab(routeTab);
    }
  }, [routeTab]);
  const [pendingValidCount, setPendingValidCount] = useState(0); // VALID-C4 : compteur « comptes en attente »
  const [loading, setLoading] = useState(true);
  const [reservations, setReservations] = useState([]);
  const [consultations, setConsultations] = useState([]);
  const [loans, setLoans] = useState([]);
  // Granularité Phase 4 (29/05/2026) : statut de renouvellement PAR ITEM (staff),
  // indexé par sub_id. Voir api.staff_loans_renewal_status_by_item_v1.
  const [renewStatusByItem, setRenewStatusByItem] = useState({});
  // Paquet 18 (10/05/2026) : tri par colonnes pour les 3 tableaux principaux.
  // Audit UX 25/05/2026 (P1) : les appels useSort sont deplaces plus bas,
  // apres la definition des listes ACTIVES, pour porter sur celles-ci.
  const [internalTasks, setInternalTasks] = useState([]);

  const { historyTypes, historyData, historyHasMore, historyLoading, toggleHistoryType,
    loadHistorySection, refreshHistorico, historyPageSize, changeHistoryPageSize }
    = usePanelHistorico({ tab, reservations, consultations, loans });
  // Audit UX 25/05/2026 (P3) : filtre par etape de workflow pour les onglets
  // Reservations et Consultations. 'all' = toutes les etapes. Modele :
  // membershipFilter de l'onglet Contribuicoes.

  const [resStageFilter, setResStageFilter] = useState('all');
  const [conStageFilter, setConStageFilter] = useState('all');
  // Fuseau horaire de la bibliothèque : la planification de consultation se fait
  // en heure-biblio (cohérent avec la validation backend fn_validate_consulta_
  // schedule_window). Chargé une fois depuis library_service_state pour l'afficher
  // dans le hint du modal. Cf. migration 20260624161959.
  const [consultationTz, setConsultationTz] = useState(null);
  useEffect(() => {
    if (!libraryId) { setConsultationTz(null); return; }
    let cancelled = false;
    (async () => {
      const { data } = await supabase
        .from('library_service_state')
        .select('consultation_timezone')
        .eq('library_id', libraryId)
        .maybeSingle();
      if (!cancelled) setConsultationTz(data?.consultation_timezone || null);
    })();
    return () => { cancelled = true; };
  }, [libraryId]);
  // #tz (01/08) : fuseau d'affichage des horaires de resa/consultation cote painel,
  // avec repli America/Belem tant que consultationTz n'est pas charge (evite un
  // affichage transitoire en fuseau navigateur). Passe aux onglets + tableau de bord.
  const displayTz = consultationTz || 'America/Belem';

  // Cotisation (coordenador/administrador uniquement)
  // E.0 (paquet profils 19/05) : membership_enabled vient du LibraryContext.
  // Alias local conserve pour minimiser les modifications dans le reste du fichier.
  const membershipEnabled = membership_enabled;
  // E6 lot C : « Gérer un·e lecteur·rice » et la cotisation (recherche, restriction,
  // règles, aperçu, paiement) vivent dans usePanelLeitor ; la modale de paiement dans PaymentModal.
  const leitor = usePanelLeitor({ t, libraryId, isLibrarian, isCoordOrAdmin, membershipEnabled, tab });
  const { readerLookup, setReaderLookup, readerProfile, setReaderProfile, readerMatchInfo, readerMsg, setReaderMsg,
    editAddrState, setEditAddrState, editProfileMsg, setEditProfileMsg, restrictReason, setRestrictReason, restrictionState,
    setRestrictionState, restrictBusy, setRestrictBusy, freezeReason, setFreezeReason, readerPayments, membershipRules, searchReader,
    openPaymentModal, membershipFilter, setMembershipFilter, membershipOverview, getMembershipFilterCount, fmtMembershipStatus,
    loadMembershipOverview } = leitor; // la modale de paiement lit le reste dans {...leitor}

  // ── Load ──────────────────────────────────────────────

  const loadReservas = useCallback(async () => {
    try {
      const r = await apiQuery('reserva_itens_followup_ui');
      setReservations(r.data || []);
    } catch (e) { console.error('Painel reservas reload error:', e); }
  }, []);

  const loadConsultas = useCallback(async () => {
    try {
      const r = await apiQuery('consulta_itens_followup_ui');
      setConsultations(r.data || []);
    } catch (e) { console.error('Painel consultas reload error:', e); }
  }, []);

  const loadLoans = useCallback(async () => {
    try {
      const [loanR, renewItemR] = await Promise.all([
        apiQuery('emprestimo_itens_painel_ui'),
        apiQuery('staff_loans_renewal_status_by_item_v1'),
      ]);
      setLoans(loanR.data || []);
      // Granularite Phase 4 : indexer le statut de renouvellement par sub_id.
      setRenewStatusByItem(Object.fromEntries(
        (renewItemR.data || []).map(r => [r.sub_id, r])
      ));
    } catch (e) { console.error('Painel loans reload error:', e); }
  }, []);

  const loadTasks = useCallback(async () => {
    if (!libraryId) return;
    try {
      // ETATS-VIVANTS (31/08/2026, item F6). Le filtre ne connaissait que
      // 'pendente' et 'em_andamento' — deux etats sur les sept que le cycle de
      // vie compte. Une tache passee en 'bloqueada' DISPARAISSAIT donc de
      // l'ecran, sans que personne ne sache ou elle etait allee : pas un defaut
      // d'affichage, une tache perdue. 'pendente' n'existe plus (la colonne a
      // desormais une CHECK et vaut 'aberta' par defaut) ; les quatre etats
      // vivants sont retenus, les trois etats de sortie — concluida, cancelada,
      // arquivada — restent hors du tableau de bord, ce qui est leur place.
      const { data: tasksData } = await supabase.from('painel_internal_tasks').select('*').eq('library_id', libraryId).in('status', ['aberta', 'a_fazer', 'em_andamento', 'bloqueada']).order('priority').order('due_date').limit(50);
      setInternalTasks(tasksData || []);
    } catch (e) { console.error('Painel tasks reload error:', e); }
  }, [libraryId]);

  // E.5 - orchestrateur de recharge complete : montage initial + bouton Recarregar global.
  // Les actions ciblees appellent directement loadReservas / loadConsultas / loadLoans.
  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      await Promise.all([loadReservas(), loadConsultas(), loadLoans(), loadTasks()]);
    } finally { setLoading(false); }
  }, [loadReservas, loadConsultas, loadLoans, loadTasks]);

  useEffect(() => { loadData(); }, [loadData]);

  // E6 lot B : la sortie et le retour au comptoir (deux phases, aperçu puis
  // confirmation) vivent dans usePanelAcoes ; le crochet lit loans et rappelle loadLoans.
  const { borrowerLookup, setBorrowerLookup, loanRefs, setLoanRefs, loanPreview, setLoanPreview, loanBusy, loanMsg,
    returnId, setReturnId, returnSubIds, setReturnSubIds, returnMsg, registrarSaida, cancelLoanPreview,
    registrarDevolucaoTotal, registrarDevolucaoParcial, returnTotalPreview, setReturnTotalPreview,
    returnPartialPreview, setReturnPartialPreview, cancelReturnTotalPreview, cancelReturnPartialPreview }
    = usePanelAcoes({ t, libraryId, loans, loadLoans });

  const { loteStatusFilter, setLoteStatusFilter, loteSortKey, setLoteSortKey, expandedLoans,
    toggleExpandedLoan, extendLoan, returnLoanItem, extendLoanItem }
    = usePanelEmprestimos({ t, loadLoans, notifyError });

  // E6 lot C : le parcours des consultations (étape, planification, annulation
  // avec motif) vit dans usePanelConsultas ; ses deux modales dans ConsultaModals.
  const consultas = usePanelConsultas({ t, loadConsultas, notifyError });
  const { setConsultaWorkflow, openScheduleModal, openCancelModal } = consultas;

  // VALID-C4 — compteur des inscriptions en attente (badge d'onglet Validações).
  // Rafraîchi au changement d'onglet (donc après une validation dans l'onglet).
  useEffect(() => {
    if (!isLibrarian || !libraryId) { setPendingValidCount(0); return; }
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase.schema('api').rpc('list_pending_validations', { p_library_id: libraryId });
        if (!cancelled) setPendingValidCount(Array.isArray(data) ? data.length : 0);
      } catch { if (!cancelled) setPendingValidCount(0); }
    })();
    return () => { cancelled = true; };
  }, [isLibrarian, libraryId, tab]);

  // ── Render ───────────────────────────────────────────

  // FIX BUG #1: Each tab now has a distinct hint key (was duplicating label).
  // Paquet E.2 (19/05/2026) : filtrage des onglets par availability selon profil de biblio.
  // ALL_TABS est l'array complet ; TABS est filtre via le hook usePanelAvailability
  // qui consomme circulation_mode et membership_enabled du LibraryContext.
  // Le check role (isCoordOrAdmin) sur 'contribuicoes' reste explicit : c'est un
  // check de role utilisateur orthogonal au profil de la biblio.
  // Forme des onglets (28/08/2026) : barre de pastilles `.ab-tabbar`
  // (src/styles/tabbar.css), même refonte que la page « Mon compte ». `icon`
  // sert de repère visuel, `count` sort le décompte du libellé (pastille rendue
  // seulement s'il y a quelque chose à compter, `alert` pour ce qui appelle une
  // action), et `hint` n'est plus affiché sous le libellé — il redisait le
  // sous-titre du panneau juste en dessous — mais devient l'infobulle et le nom
  // accessible du bouton.
  const ALL_TABS = [
    { key: 'trabalho-do-dia', icon: 'target', label: t({ id: 'panel.tab.dailyWork' }), hint: t({ id: 'panel.tab.dailyWork.hint' }) },
    // `group` ouvre le bloc des vues de detail : « Travail du jour » est la vue
    // d'ensemble, tout ce qui suit est consulte au besoin (EA-01).
    { key: 'acoes', icon: 'zap', label: t({ id: 'panel.tab.actions' }), hint: t({ id: 'panel.tab.actions.hint' }), group: true },
    { key: 'reservas', icon: 'pin', label: t({ id: 'panel.tab.reservations' }), hint: t({ id: 'panel.tab.reservations.hint' }) },
    { key: 'consultas-locais', icon: 'book', label: t({ id: 'panel.tab.consultations' }), hint: t({ id: 'panel.tab.consultations.hint' }) },
    { key: 'emprestimos', icon: 'library', label: t({ id: 'panel.tab.loans' }), hint: t({ id: 'panel.tab.loans.hint' }) },
    { key: 'leitor', icon: 'user', label: t({ id: 'panel.tab.reader' }), hint: t({ id: 'panel.tab.reader.hint' }) },
    { key: 'historico', icon: 'history', label: t({ id: 'panel.tab.history' }), hint: t({ id: 'panel.tab.history.hint' }) },
    ...(isCoordOrAdmin ? [
      { key: 'contribuicoes', icon: 'ticket', label: t({ id: 'panel.tab.memberships' }), hint: t({ id: 'panel.tab.memberships.hint' }) },
    ] : []),
    // MULTI P5 (volet staff) : validation des inscriptions (librarian/coordenador).
    ...(isLibrarian ? [
      { key: 'validacoes', icon: 'check', label: t({ id: 'panel.tab.validations' }), hint: t({ id: 'panel.tab.validations.hint' }), count: pendingValidCount, alert: true },
    ] : []),
    // MOBILE P4 : récolement (inventaire par scan). Staff de terrain uniquement.
    ...(canRecolement ? [
      { key: 'recolement', icon: 'search', label: t({ id: 'panel.tab.recolement' }), hint: t({ id: 'panel.tab.recolement.hint' }) },
      // Capas (27/09/2026) : même staff de terrain que le récolement, même geste — le livre en main.
      { key: 'capas', icon: 'image', label: t({ id: 'panel.tab.capas' }), hint: t({ id: 'panel.tab.capas.hint' }) },
    ] : []),
  ];
  const TABS = ALL_TABS.filter(t => availability[t.key] !== false);

  // Paquet E.3 (19/05/2026) : garde-fou bascule auto si onglet actif devient indisponible.
  // Cas couverts :
  //   - changement de biblio en cours de session (?library= dans URL)
  //   - vote de transition profil execute pendant qu'un staff a le panel ouvert
  // Le re-direct se fait vers 'trabalho-do-dia' qui est toujours disponible.
  useEffect(() => {
    if (availability[tab] === false) {
      setTab('trabalho-do-dia');
    }
  }, [tab, availability]);

  // Paquet 9 (10/05/2026) : fix bug compteur "Réservations actives" du hero.
  // L'ancienne denylist excluait cancelada_leitor/cancelada_biblioteca/expirada/
  // retirada_efetivada/liberada_para_circulacao mais oubliait
  // 'convertida_em_emprestimo' (ajouté au CHECK quand le flow réservation→emprunt
  // a été câblé). Résultat : les résas converties en emprunts comptaient comme
  // actives. On bascule sur une allowlist pour être robuste aux ajouts futurs.
  // Valeurs possibles selon le CHECK constraint sur reserva_linhas_v2 :
  // 'ativa' (seule active), 'convertida_em_emprestimo', 'cancelada_leitor',
  // 'cancelada_biblioteca', 'expirada', 'liberada_para_circulacao'.
  // EA-04 (chantier B, 27/05/2026) : defense en profondeur du filtre actif.
  // Exclut les lignes dont workflow_stage est terminal mais dont item_status
  // n'a pas (encore) ete propage par un trigger. Liste fermee, derivee de la
  // doctrine item_status / workflow_stage du Grand Livre Blanc v16 chapitre 0
  // et des matrices fn_check_workflow_transition (reservations) /
  // fn_check_consulta_transition (consultations). Les emprunts n'ont pas de
  // workflow_stage distinct, EA-04 ne s'applique pas a eux.
  const TERMINAL_RES_STAGES = ['retirada_no_show', 'emprestimo_emitido'];
  const TERMINAL_CON_STAGES = ['consulta_no_show', 'consulta_realizada'];
  const activeRes = reservations.filter(r =>
    r.item_status === 'ativa'
    && !TERMINAL_RES_STAGES.includes(r.workflow_stage_effective)
  );
  const activeLoans = loans.filter(l => l.item_status === 'aberto');
  // Audit UX 25/05/2026 (P1) : les vues *_followup_ui renvoient l'actif ET
  // le cloture. Les onglets operationnels ne doivent montrer que l'actionnable ;
  // l'historique vit dans l'onglet dedie (vues painel_*_history_v1).
  // Correctif 26/05/2026 : filtrer sur la SEULE valeur active de item_status,
  // symetrique de activeRes / activeLoans. La version initiale testait item_status
  // contre une liste de workflow_stage ('consulta_realizada'...) — or item_status
  // d'une consulta ne vaut que 'ativa' | 'consultada' | 'cancelada_leitor' |
  // 'cancelada_biblioteca' | 'expirada' (CHECK consulta_linhas_v2_item_status_chk).
  // 'consulta_realizada' est un stage, pas un statut : les consultas faites
  // (item_status='consultada') passaient donc a tort dans la file active.
  const activeConsultations = consultations.filter(c =>
    c.item_status === 'ativa'
    && !TERMINAL_CON_STAGES.includes(c.workflow_stage_effective)
  );
  // Audit UX 25/05/2026 (P3) : filtre par etape applique AVANT le tri.
  // 'all' = pas de filtre. Tri par colonnes via SortHeader (ex-paquet 18).
  const stageFilteredRes = useMemo(
    () => resStageFilter === 'all'
      ? activeRes
      : activeRes.filter(r => (r.workflow_stage_effective || r.item_status) === resStageFilter),
    [activeRes, resStageFilter]
  );
  const stageFilteredCon = useMemo(
    () => conStageFilter === 'all'
      ? activeConsultations
      : activeConsultations.filter(c => (c.workflow_stage_effective || c.item_status) === conStageFilter),
    [activeConsultations, conStageFilter]
  );
  const sortRes = useSort(stageFilteredRes);
  const sortCon = useSort(stageFilteredCon);
  const sortLoans = useSort(activeLoans);
  // E6 lot B : la sélection, le menu d'étape et les gestes sur les réservations
  // vivent dans usePanelReservas ; le crochet lit activeRes (« tout sélectionner »).
  const { selectedRes, resStage, setResStage, resNote, setResNote, resSchedule, setResSchedule, actionMsg,
    negotiationForm, setNegotiationForm, applyResWorkflow, cancelSelectedRes, confirmSelectedPickup,
    confirmReaderSlot, openCounterProposalForm, submitCounterProposal, cancelWithReason, toggleRes, toggleAllRes }
    = usePanelReservas({ t, activeRes, loadReservas, loadLoans });
  // P3 : comptage des items actifs par etape, pour les pills de filtre.
  const resStageCounts = useMemo(() => {
    const m = new Map();
    activeRes.forEach(r => {
      const s = r.workflow_stage_effective || r.item_status || '—';
      m.set(s, (m.get(s) || 0) + 1);
    });
    return m;
  }, [activeRes]);
  const conStageCounts = useMemo(() => {
    const m = new Map();
    activeConsultations.forEach(c => {
      const s = c.workflow_stage_effective || c.item_status || '—';
      m.set(s, (m.get(s) || 0) + 1);
    });
    return m;
  }, [activeConsultations]);
  const overdueLoans = activeLoans.filter(l => {
    const effectiveDue = l.extended_until || l.due_at;
    return effectiveDue && new Date(effectiveDue) < new Date();
  });
  // Paquet 19 v3 (11/05/2026) : distinction emprunts (groupes) vs items pour le hero
  const activeLoanGroups = new Set(activeLoans.map(l => l.emprestimo_id)).size;
  // E6 lot A : la construction vit dans dailyTasks.js ; l'onglet et le compteur
  // du bandeau appellent cette enveloppe sans argument, comme avant.
  const buildDailyTasks = () => construireTachesDuJour({ t, displayTz, activeRes, overdueLoans, activeLoans, consultations, internalTasks });

  // EA-01 niveau 2 (refonte Hero B.3, 29/05/2026) :
  // Compteur saillant dans le Hero pointant vers Trabalho do dia. Compte
  // uniquement les items des buckets hoje + atencao (actions à faire),
  // pas acompanhamento (suivi sans urgence immédiate). Réutilise la même
  // source de vérité que TabTrabalhoDoDia (buildDailyTasks) pour garantir
  // la cohérence des chiffres entre Hero et onglet.
  // NOTE: placé ICI (après les déclarations activeRes/activeLoans/overdueLoans)
  // et non juste après buildDailyTasks() : le hoisting d'une function
  // declaration permettrait l'appel, mais les const dans le tableau de deps
  // sont soumises à la Temporal Dead Zone et lèvent ReferenceError si
  // référencées avant leur initialisation.
  const dailyActionCount = useMemo(() => {
    try {
      const tasks = buildDailyTasks();
      return tasks.filter(tk => tk.bucket === 'hoje' || tk.bucket === 'atencao').length;
    } catch {
      return 0;
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeRes, consultations, overdueLoans, activeLoans, internalTasks]);

  // PATCH 03/05/2026 : skeleton UI au lieu de Spinner.
  // Pendant le chargement du rôle, on ne sait pas encore si on est librarian+
  // ou simple reader (qui sera redirigé). On rend une structure neutre :
  // Topbar + zone hero placeholder + zone contenu placeholder. Évite l'écran
  // vide perçu pendant que la requête de rôle est en cours.
  if (!roleLoaded) {
    return (
      <PageShell>
        <Topbar />
        <Hero title={t({ id: 'panel.title' })} subtitle={t({ id: 'panel.subtitle' })}>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <Skeleton w={140} h={28} style={{ borderRadius: 14 }} />
            <Skeleton w={120} h={28} style={{ borderRadius: 14 }} />
          </div>
        </Hero>
        <div style={{ padding: 24 }}>
          <Skeleton lines={3} />
        </div>
      </PageShell>
    );
  }

  if (!isLibrarian) return (
    <PageShell><Topbar />
      <div style={{ maxWidth: 600, margin: '0 auto', textAlign: 'center', padding: '60px 24px' }}>
        <h1 style={{ fontSize: '1.4rem', fontWeight: 800 }}>{t({ id: 'panel.title' })}</h1>
        <p style={{ color: 'var(--brand-muted)', marginTop: 12 }}>{t({ id: 'panel.restricted' })}</p>
      </div>
    </PageShell>
  );

  // PATCH 03/05/2026 : skeleton UI au lieu de Spinner.
  // À ce stade roleLoaded=true et isLibrarian=true, donc on peut afficher
  // le hero complet avec son titre + nom de biblio. On affiche skeletons
  // sur les pills compteurs (réservations actives, etc.) et sur la zone
  // de contenu qui charge. Hero reste en rouge intense, pas affecté.
  if (loading) {
    return (
      <PageShell>
        <Topbar />
        <Hero title={t({ id: 'panel.title' })} subtitle={libraryName || t({ id: 'panel.subtitle' })}>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 8 }}>
            <Skeleton w={170} h={28} style={{ borderRadius: 14 }} />
            <Skeleton w={170} h={28} style={{ borderRadius: 14 }} />
            <Skeleton w={200} h={28} style={{ borderRadius: 14 }} />
            <Skeleton w={110} h={28} style={{ borderRadius: 14 }} />
          </div>
        </Hero>
        {/* Onglets en skeleton */}
        <div style={{ display: 'flex', gap: 12, padding: '16px 0', justifyContent: 'center', flexWrap: 'wrap' }}>
          <Skeleton w={120} h={42} style={{ borderRadius: 8 }} />
          <Skeleton w={100} h={42} style={{ borderRadius: 8 }} />
          <Skeleton w={130} h={42} style={{ borderRadius: 8 }} />
          <Skeleton w={170} h={42} style={{ borderRadius: 8 }} />
          <Skeleton w={110} h={42} style={{ borderRadius: 8 }} />
          <Skeleton w={140} h={42} style={{ borderRadius: 8 }} />
          <Skeleton w={150} h={42} style={{ borderRadius: 8 }} />
        </div>
        {/* Stats cards en skeleton (Synthèse opérationnelle) */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(min(170px, 100%), 1fr))', gap: 12, padding: '0 0 16px' }}>
          {[1, 2, 3, 4, 5, 6].map(i => (
            <div key={i} style={{ padding: 16, borderRadius: 8, border: '1px solid rgba(255,255,255,.08)', background: 'rgba(12,12,12,.4)', textAlign: 'center' }}>
              <Skeleton w={40} h={32} style={{ margin: '0 auto 8px' }} />
              <Skeleton w={100} h={14} style={{ margin: '0 auto' }} />
            </div>
          ))}
        </div>
      </PageShell>
    );
  }

  return (
    <PageShell>
      <Topbar />
      <LibraryContextBanner />
      <Hero title={t({ id: 'panel.title' })} subtitle={libraryName || t({ id: 'panel.subtitle' })}>
        {/* EA-01 niveau 2 (refonte Hero B.3, 29/05/2026) :
            ligne saillante "N items demandent action → Voir la synthèse",
            masquée quand on est déjà sur l'onglet Trabalho do dia.
            NOTE: styles inline en attendant E.4 / OT-2 (chartage centralisé). */}
        {tab !== 'trabalho-do-dia' && (
          <div style={{
            marginTop: 12,
            marginBottom: 4,
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            flexWrap: 'wrap',
          }}>
            {dailyActionCount > 0 ? (
              <button
                type="button"
                onClick={() => setTab('trabalho-do-dia')}
                style={{
                  background: 'rgba(251, 191, 36, 0.15)',
                  border: '1px solid rgba(251, 191, 36, 0.4)',
                  borderRadius: 8,
                  padding: '6px 14px',
                  color: '#fbbf24',
                  cursor: 'pointer',
                  fontSize: '.95rem',
                  fontWeight: 600,
                  fontFamily: 'inherit',
                }}
              >
                {t({ id: 'panel.hero.dailyWorkLink' }, { count: dailyActionCount })}
              </button>
            ) : (
              <button
                type="button"
                onClick={() => setTab('trabalho-do-dia')}
                style={{
                  background: 'rgba(74, 222, 128, 0.12)',
                  border: '1px solid rgba(74, 222, 128, 0.35)',
                  borderRadius: 8,
                  padding: '6px 14px',
                  color: 'rgba(74, 222, 128, 0.95)',
                  cursor: 'pointer',
                  fontSize: '.92rem',
                  fontWeight: 500,
                  fontFamily: 'inherit',
                }}
              >
                ✓ {t({ id: 'panel.hero.allClear' })}
              </button>
            )}
          </div>
        )}
        <UserHeroBadge />
        <HeroDocumentationActions
          extraActions={
            <>
              <Pill variant={activeRes.length > 0 ? 'warn' : 'default'}>{t({ id: 'panel.reservations.active' }, { count: activeRes.length })}</Pill>
              <Pill>{t({ id: 'panel.consultations.active' }, { count: activeConsultations.length })}</Pill>
              <Pill variant={overdueLoans.length > 0 ? 'bad' : 'default'}>{t({ id: 'panel.loan.openLoans' }, { count: activeLoanGroups, items: activeLoans.length, overdue: overdueLoans.length })}</Pill>
              <Button variant="secondary" onClick={loadData}>{t({ id: 'common.refresh' })}</Button>
            </>
          }
        />
      </Hero>

      <div className="ab-painel-card">
        <nav className="ab-tabbar" role="tablist">
          {TABS.map(t => (
            <button key={t.key} className={`ab-tabbar__tab ${t.group ? 'ab-tabbar__tab--group ' : ''}${tab === t.key ? 'active' : ''}`}
              data-painel-tab={t.key}
              onClick={() => setTab(t.key)} role="tab" aria-selected={tab === t.key}
              /* Le hint n'est plus affiché sous le libellé : il devient l'infobulle
                 et le nom accessible du bouton. */
              title={t.hint} aria-label={`${t.label} — ${t.hint}`}>
              <AppIcon className="ab-tabbar__icon" name={t.icon} size="1em" />
              {t.label}
              {t.count > 0 && (
                <span className={`ab-tabbar__badge${t.alert ? ' ab-tabbar__badge--alert' : ''}`}>{t.count}</span>
              )}
            </button>
          ))}
        </nav>

        <div className="ab-painel-panel">

          <Suspense fallback={<div className="ab-painel-tab-loading"><Spinner /></div>}>

          {/* ═══ TRABALHO DO DIA ═══ */}
          {tab === 'trabalho-do-dia' && (
            <TabTrabalhoDoDia
              t={t}
              buildDailyTasks={buildDailyTasks}
              activeRes={activeRes}
              overdueLoans={overdueLoans}
              consultations={consultations}
              internalTasks={internalTasks}
              setTab={setTab}
              loadData={loadData}
              pendingValidCount={pendingValidCount}
              isLibrarian={isLibrarian}
            />
          )}

          {/* ═══ AÇÕES ═══ */}
          {tab === 'acoes' && (
            <TabAcoes
              t={t}
              borrowerLookup={borrowerLookup}
              setBorrowerLookup={setBorrowerLookup}
              loanRefs={loanRefs}
              setLoanRefs={setLoanRefs}
              loanPreview={loanPreview}
              setLoanPreview={setLoanPreview}
              loanBusy={loanBusy}
              loanMsg={loanMsg}
              returnId={returnId}
              setReturnId={setReturnId}
              returnSubIds={returnSubIds}
              setReturnSubIds={setReturnSubIds}
              returnMsg={returnMsg}
              registrarSaida={registrarSaida}
              cancelLoanPreview={cancelLoanPreview}
              registrarDevolucaoTotal={registrarDevolucaoTotal}
              registrarDevolucaoParcial={registrarDevolucaoParcial}
              returnTotalPreview={returnTotalPreview}
              setReturnTotalPreview={setReturnTotalPreview}
              returnPartialPreview={returnPartialPreview}
              setReturnPartialPreview={setReturnPartialPreview}
              cancelReturnTotalPreview={cancelReturnTotalPreview}
              cancelReturnPartialPreview={cancelReturnPartialPreview}
            />
          )}

          {/* ═══ RESERVAS ATIVAS ═══ */}
          {tab === 'reservas' && (
            <TabReservas
              t={t}
              consultationTz={displayTz}
              reservations={reservations}
              activeRes={activeRes}
              sortRes={sortRes}
              selectedRes={selectedRes}
              resNote={resNote}
              setResNote={setResNote}
              resSchedule={resSchedule}
              setResSchedule={setResSchedule}
              resStage={resStage}
              setResStage={setResStage}
              resStageCounts={resStageCounts}
              resStageFilter={resStageFilter}
              setResStageFilter={setResStageFilter}
              actionMsg={actionMsg}
              negotiationForm={negotiationForm}
              setNegotiationForm={setNegotiationForm}
              RES_STAGES={RES_STAGES}
              WORKFLOW_LABELS={WORKFLOW_LABELS}
              actorRole={actorRole}
              canTransition={canTransition}
              confirmSelectedPickup={confirmSelectedPickup}
              cancelSelectedRes={cancelSelectedRes}
              loadData={loadReservas}
              applyResWorkflow={applyResWorkflow}
              toggleAllRes={toggleAllRes}
              toggleRes={toggleRes}
              confirmReaderSlot={confirmReaderSlot}
              openCounterProposalForm={openCounterProposalForm}
              cancelWithReason={cancelWithReason}
              submitCounterProposal={submitCounterProposal}
            />
          )}

          {/* ═══ CONSULTAS LOCAIS ═══ */}
          {tab === 'consultas-locais' && (
            <TabConsultasLocais
              t={t}
              consultationTz={displayTz}
              sortCon={sortCon}
              conStageCounts={conStageCounts}
              conStageFilter={conStageFilter}
              setConStageFilter={setConStageFilter}
              CONSULT_WORKFLOW={CONSULT_WORKFLOW}
              setConsultaWorkflow={setConsultaWorkflow}
              openScheduleModal={openScheduleModal}
              openCancelModal={openCancelModal}
              loadData={loadConsultas}
            />
          )}

          {/* ═══ EMPRÉSTIMOS (fusionnés — E.3/EA-07, 29/05/2026) ═══ */}
          {tab === 'emprestimos' && (
            <TabEmprestimos
              t={t}
              activeLoans={activeLoans}
              loans={loans}
              loteStatusFilter={loteStatusFilter}
              setLoteStatusFilter={setLoteStatusFilter}
              loteSortKey={loteSortKey}
              setLoteSortKey={setLoteSortKey}
              EMPRESTIMO_STATUS_LABELS={EMPRESTIMO_STATUS_LABELS}
              expandedLoans={expandedLoans}
              toggleExpandedLoan={toggleExpandedLoan}
              extendLoan={extendLoan}
              returnLoanItem={returnLoanItem}
              extendLoanItem={extendLoanItem}
              renewStatusByItem={renewStatusByItem}
              loadData={loadLoans}
            />
          )}

          {/* ═══ GERIR LEITOR ═══ */}
          {tab === 'leitor' && (
            <TabLeitor
              t={t}
              locale={locale}
              libraryId={libraryId}
              libraryName={libraryName}
              isNetworkAdmin={isNetworkAdmin}
              isLibrarian={isLibrarian}
              membershipEnabled={membershipEnabled}
              readerLookup={readerLookup}
              setReaderLookup={setReaderLookup}
              readerProfile={readerProfile}
              setReaderProfile={setReaderProfile}
              readerMatchInfo={readerMatchInfo}
              readerMsg={readerMsg}
              setReaderMsg={setReaderMsg}
              editAddrState={editAddrState}
              setEditAddrState={setEditAddrState}
              editProfileMsg={editProfileMsg}
              setEditProfileMsg={setEditProfileMsg}
              restrictReason={restrictReason}
              setRestrictReason={setRestrictReason}
              restrictionState={restrictionState}
              setRestrictionState={setRestrictionState}
              restrictBusy={restrictBusy}
              setRestrictBusy={setRestrictBusy}
              freezeReason={freezeReason}
              setFreezeReason={setFreezeReason}
              readerPayments={readerPayments}
              membershipRules={membershipRules}
              searchReader={searchReader}
              openPaymentModal={openPaymentModal}
            />
          )}

          {/* ═══ Onglet Contribuições (admin coord) ═══════════════ */}
          {tab === 'historico' && (
            <TabHistorico
              t={t}
              historyTypes={historyTypes}
              historyData={historyData}
              historyHasMore={historyHasMore}
              historyLoading={historyLoading}
              toggleHistoryType={toggleHistoryType}
              loadHistorySection={loadHistorySection}
              refreshHistorico={refreshHistorico}
              historyPageSize={historyPageSize}
              changeHistoryPageSize={changeHistoryPageSize}
            />
          )}

          {tab === 'contribuicoes' && isCoordOrAdmin && (
            <TabContribuicoes
              t={t}
              membershipRules={membershipRules}
              membershipFilter={membershipFilter}
              setMembershipFilter={setMembershipFilter}
              membershipOverview={membershipOverview}
              getMembershipFilterCount={getMembershipFilterCount}
              fmtMembershipStatus={fmtMembershipStatus}
              openPaymentModal={openPaymentModal}
              loadMembershipOverview={loadMembershipOverview}
            />
          )}

          {tab === 'validacoes' && isLibrarian && (
            <TabValidacoes libraryId={libraryId} />
          )}

          {/* ═══ Récolement (inventaire par scan, MOBILE P4) ═══════ */}
          {tab === 'recolement' && canRecolement && (
            <TabRecolement t={t} locale={locale} libraryId={libraryId} libraryName={libraryName} />
          )}

          {/* ═══ Capas (photographier les couvertures, 27/09/2026) ═══ */}
          {tab === 'capas' && canRecolement && (
            <TabCapas t={t} libraryId={libraryId} isNetworkAdmin={isNetworkAdmin} />
          )}

          </Suspense>

          <PaymentModal t={t} {...leitor} />
        </div>
      </div>

      {/* ONBO-Q4 : prise en main du Painel (coach-marks + check-list + canal humain) */}
      <PanelOnboarding
        availability={availability}
        circulationMode={circulation_mode}
        libraryId={libraryId}
        onNavigate={setTab}
      />

      <Footer />
      <ConsultaModals t={t} consultationTz={consultationTz} {...consultas} />
    </PageShell>
  );
}

// ────────────────────────────────────────────────────────────
// Remontage au changement de bibliothèque (01/09/2026)
//
// Le sélecteur est désormais monté sur cette page. Or le panneau garde ses
// opérations en cours dans des useState ordinaires — borrowerLookup, loanRefs,
// loanPreview, returnId — et rien ne les remettait à zéro : seuls le fuseau
// horaire et la liste des tâches réagissaient à `libraryId`. Un emprunt
// composé pour la biblio A aurait donc survécu à une bascule vers B, et serait
// parti avec le library_id de B au moment de valider.
//
// Ce `key` règle le problème par construction plutôt que par vigilance : React
// démonte et remonte tout le panneau à chaque changement, donc aucun état
// d'opération ne peut traverser une bascule. Ne pas le retirer sans retirer
// aussi le sélecteur ci-dessus.
// ────────────────────────────────────────────────────────────
export default function PanelPage() {
  const { libraryId } = useLibrary();
  return <PanelPageInner key={libraryId || 'sans-biblio'} />;
}
