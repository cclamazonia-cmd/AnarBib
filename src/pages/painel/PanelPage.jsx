import { useState, useEffect, useCallback, useMemo, Fragment, lazy, Suspense } from 'react';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase, apiQuery } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { decodeSystemNote } from '@/lib/systemNotes';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, Spinner, Skeleton } from '@/components/ui';
import { parseAddressText } from '@/lib/addressFormat';
import Modal from '@/components/ui/Modal';
import { useToast } from '@/contexts/ToastContext';
import './PanelPage.css';
import { usePanelAvailability } from '@/hooks/usePanelAvailability';
import UserHeroBadge from '@/components/UserHeroBadge';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';
import PanelOnboarding from '@/components/painel/PanelOnboarding';
import { fmtD, useSort } from './_shared';
import TabTrabalhoDoDia from './tabs/TabTrabalhoDoDia';
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

// ═══════════════════════════════════════════════════════════
// Workflow labels and stage lists are built inside the component using t()
// ═══════════════════════════════════════════════════════════

export default function PanelPage() {
  const { user } = useAuth();
  const { libraryId, libraryName, role, circulation_mode, membership_enabled, isNetworkAdmin } = useLibrary();
  const availability = usePanelAvailability();
  const { formatMessage: t, locale } = useIntl();
  const { notifyError } = useToast();
  useDocumentTitle(t({ id: 'pageTitle.panel' }));
  const roleLoaded = role !== null && role !== undefined;
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
  const [selectedRes, setSelectedRes] = useState(new Set());

  // === Onglet Historique (#143.2) =============================
  // Pills cochables multi-selection pour filtrer par type d'item.
  // Initialise au type le plus utilise (dynamique selon les comptes).
  const [historyTypes, setHistoryTypes] = useState(null);

  const dominantHistoryType = useMemo(() => {
    const counts = {
      reservas: (reservations || []).filter(r => ['cancelada_leitor','cancelada_biblioteca','convertida_em_emprestimo','expirada','liberada_para_circulacao'].includes(r.item_status)).length,
      consultas: (consultations || []).filter(c => ['cancelada_biblioteca','cancelada_leitor','consultada','expirada'].includes(c.item_status)).length,
      emprestimos: (loans || []).filter(l => l.status_global === 'encerrado').length,
    };
    if (counts.consultas >= counts.reservas && counts.consultas >= counts.emprestimos) return 'consultas';
    if (counts.reservas >= counts.emprestimos) return 'reservas';
    return 'emprestimos';
  }, [reservations, consultations, loans]);

  useEffect(() => {
    if (historyTypes === null && dominantHistoryType) {
      setHistoryTypes(new Set([dominantHistoryType]));
    }
  }, [dominantHistoryType, historyTypes]);

  const toggleHistoryType = (type) => {
    setHistoryTypes(prev => {
      const next = new Set(prev || []);
      if (next.has(type)) next.delete(type);
      else next.add(type);
      return next;
    });
  };

  // Donnees historiques (chargees a la demande, paginees par 50)
  const [historyData, setHistoryData] = useState({ reservas: [], consultas: [], emprestimos: [] });
  const [historyOffsets, setHistoryOffsets] = useState({ reservas: 0, consultas: 0, emprestimos: 0 });
  const [historyHasMore, setHistoryHasMore] = useState({ reservas: true, consultas: true, emprestimos: true });
  const [historyLoading, setHistoryLoading] = useState({ reservas: false, consultas: false, emprestimos: false });

  // EA-11 (29/05/2026) : taille de page configurable par l'utilisateur·rice
  // (selecteur 25/50/100 cote TabHistorico). State au niveau PanelPage parce
  // que loadHistorySection en a besoin et que le handler de changement doit
  // pouvoir reset historyData/Offsets/HasMore pour relancer le chargement.
  const [historyPageSize, setHistoryPageSize] = useState(50);
  const HISTORY_VIEW_NAMES = {
    reservas: 'painel_reservations_history_v1',
    consultas: 'painel_consultas_history_v1',
    emprestimos: 'painel_loans_history_v1'
  };

  const changeHistoryPageSize = useCallback((newSize) => {
    setHistoryPageSize(newSize);
    // Reset complet : on relance le chargement de la 1ere page a la nouvelle
    // taille. Le useEffect d'auto-load detecte historyData[type].length === 0
    // et appelle loadHistorySection si type est dans historyTypes.
    setHistoryData({ reservas: [], consultas: [], emprestimos: [] });
    setHistoryOffsets({ reservas: 0, consultas: 0, emprestimos: 0 });
    setHistoryHasMore({ reservas: true, consultas: true, emprestimos: true });
  }, []);

  const loadHistorySection = useCallback(async (type, append = false) => {
    if (historyLoading[type]) return;
    setHistoryLoading(prev => ({ ...prev, [type]: true }));
    
    const offset = append ? historyOffsets[type] : 0;
    const viewName = HISTORY_VIEW_NAMES[type];
    
    try {
      const { data, error } = await supabase
        .schema('api').from(viewName)
        .select('*')
        .range(offset, offset + historyPageSize - 1);
      
      if (error) {
        console.error(`load ${type} history error:`, error);
        setHistoryLoading(prev => ({ ...prev, [type]: false }));
        return;
      }
      
      const items = data || [];
      const hasMore = items.length === historyPageSize;
      
      setHistoryData(prev => ({
        ...prev,
        [type]: append ? [...prev[type], ...items] : items
      }));
      setHistoryOffsets(prev => ({ ...prev, [type]: offset + items.length }));
      setHistoryHasMore(prev => ({ ...prev, [type]: hasMore }));
    } catch (err) {
      console.error(`load ${type} history exception:`, err);
    } finally {
      setHistoryLoading(prev => ({ ...prev, [type]: false }));
    }
  }, [historyLoading, historyOffsets, historyPageSize]);

  // Auto-load des sections cochees a l'ouverture de l'onglet
  useEffect(() => {
    if (tab !== 'historico' || !historyTypes) return;
    for (const type of ['reservas', 'consultas', 'emprestimos']) {
      if (historyTypes.has(type) && historyData[type].length === 0 && historyHasMore[type] && !historyLoading[type]) {
        loadHistorySection(type, false);
      }
    }
  }, [tab, historyTypes, historyData, historyHasMore, historyLoading, loadHistorySection]);
  // === Fin onglet Historique ==================================
  // Audit UX 25/05/2026 (P3) : filtre par etape de workflow pour les onglets
  // Reservations et Consultations. 'all' = toutes les etapes. Modele :
  // membershipFilter de l'onglet Contribuicoes.
  // E.2 (OT-1, 28/05/2026) : refresh par onglet — Histórico ne dépend pas de
  // loadData global, il a sa propre logique loadHistorySection par type.
  // On rappelle loadHistorySection(type, false) pour chaque type actif.
  const refreshHistorico = useCallback(() => {
    const types = historyTypes || new Set();
    types.forEach(type => loadHistorySection(type, false));
  }, [historyTypes, loadHistorySection]);

  const [resStageFilter, setResStageFilter] = useState('all');
  const [conStageFilter, setConStageFilter] = useState('all');
  // EA-08 (chantier B, 27/05/2026) : tri et filtre sur l'onglet Empréstimos
  // (initialement emprestimos-lote, désormais fusionné en emprestimos via E.3/EA-07).
  // Aligne l'experience avec les trois autres onglets-objet. Valeurs canoniques
  // de emprestimo_status derivees de fn_v2_refresh_emprestimo_status_global
  // (dump du 27/05) : aberto, parcialmente_devolvido, encerrado. L'onglet
  // n'affichant que les actifs, 'encerrado' n'apparait jamais.
  const [loteStatusFilter, setLoteStatusFilter] = useState('all');
  const [loteSortKey, setLoteSortKey] = useState('due_at_asc');
  // E.3 / EA-07 (29/05/2026) : onglet Empréstimos fusionné. Les lignes
  // d'emprunt sont dépliables, le set contient les emprestimo_id ouverts.
  const [expandedLoans, setExpandedLoans] = useState(() => new Set());
  const toggleExpandedLoan = useCallback((empId) => {
    setExpandedLoans(prev => {
      const next = new Set(prev);
      if (next.has(empId)) next.delete(empId);
      else next.add(empId);
      return next;
    });
  }, []);
  const [resStage, setResStage] = useState('');
  const [resNote, setResNote] = useState('');
  const [resSchedule, setResSchedule] = useState('');
  const [actionMsg, setActionMsg] = useState('');
  // Paquet 27.A.4 (5.B) : modal Agender consulta avec date+heure+note.
  const [scheduleTarget, setScheduleTarget] = useState(null);
  const [scheduleForm, setScheduleForm] = useState({ date: '', startsAt: '', endsAt: '', note: '' });
  const [scheduling, setScheduling] = useState(false);
  const [scheduleError, setScheduleError] = useState('');

  // PATCH 08/05/2026 paquet 3B : state pour le formulaire accordion de
  // contre-proposition staff. Un seul form ouvert à la fois (la ligne
  // qui matche reservaId+lineNo). null = aucune ligne en mode édition.
  // Champs datetime et note pré-remplis depuis le créneau actuel quand on
  // ouvre le form, mais éditables librement par le staff.
  const [negotiationForm, setNegotiationForm] = useState(null);
  // Forme attendue : { reservaId, lineNo, datetime: 'YYYY-MM-DDTHH:MM', note: '' }

  // Ações
  const [borrowerLookup, setBorrowerLookup] = useState('');
  const [loanRefs, setLoanRefs] = useState('');
  // Paquet 16 v2 (10/05/2026) : preview echeance + guard double-clic
  const [loanPreview, setLoanPreview] = useState(null);
  const [loanBusy, setLoanBusy] = useState(false);
  const [loanMsg, setLoanMsg] = useState('');
  const [returnId, setReturnId] = useState('');
  const [returnSubIds, setReturnSubIds] = useState('');
  const [returnMsg, setReturnMsg] = useState('');
  // EA-03 (29/05/2026) : prévisualisation symétrique de la sortie d'emprunt
  // pour les retours total et partiel. 2 phases (preview puis confirmation)
  // avec clé de cohérence : la preview est invalidée dès que l'input change.
  // Calcul de preview entièrement côté front à partir de `loans` (déjà chargé) :
  // pas de RPC supplémentaire.
  const [returnTotalPreview, setReturnTotalPreview] = useState(null);
  const [returnPartialPreview, setReturnPartialPreview] = useState(null);

  // Gerir leitor
  const [readerLookup, setReaderLookup] = useState('');
  const [readerProfile, setReaderProfile] = useState(null);
  const [readerMsg, setReaderMsg] = useState('');
  // CARD-LOCAL-1 : méta de correspondance (identité locale, biblio d'origine si repli)
  const [readerMatchInfo, setReaderMatchInfo] = useState(null);
  // State local du formulaire d'édition d'adresse, séparé de readerProfile.address
  // pour éviter la boucle parse→format→parse à chaque frappe (qui mangeait les
  // espaces de fin via .trim() dans parseAddressText). Initialisé/réinitialisé
  // depuis readerProfile.address quand celui-ci change (cf. useEffect ci-dessous).
  const [editAddrState, setEditAddrState] = useState({
    line1: '', line2: '', unit: '', postal_code: '',
    district: '', city: '', state_region: '', country: ''
  });
  // Feedback du clic « Enregistrer le profil », affiché DANS le formulaire
  // d'édition (à côté du bouton) et non plus dans la zone globale qui
  // se trouve hors viewport quand le formulaire est déplié.
  const [editProfileMsg, setEditProfileMsg] = useState('');
  const [restrictReason, setRestrictReason] = useState('');
  // EA-10 (chantier D) : etat de restriction (local membership + global profile)
  const [restrictionState, setRestrictionState] = useState(null);
  const [restrictBusy, setRestrictBusy] = useState(false);
  const [freezeReason, setFreezeReason] = useState('');

  // Cotisation (coordenador/administrador uniquement)
  // E.0 (paquet profils 19/05) : membership_enabled vient du LibraryContext.
  // Alias local conserve pour minimiser les modifications dans le reste du fichier.
  const membershipEnabled = membership_enabled;
  const setMembershipEnabled = () => {}; // no-op (source de verite = contexte)
  const [membershipRules, setMembershipRules] = useState([]);
  const [membershipOverview, setMembershipOverview] = useState([]);
  const [membershipFilter, setMembershipFilter] = useState('all'); // all, up_to_date, expired, never_paid
  const [readerPayments, setReaderPayments] = useState([]);
  const [paymentModal, setPaymentModal] = useState(null); // null ou { user_id, display_name, ... }
  const [paymentDraft, setPaymentDraft] = useState(null);
  // PATCH 07/05/2026 audit i18n : flag séparé pour la coloration erreur/succès
  // (l'ancienne détection paymentMsg.startsWith('Erro') ne marchait qu'en pt-BR/fr)
  const [paymentMsg, setPaymentMsg] = useState('');
  const [paymentMsgIsError, setPaymentMsgIsError] = useState(false);
  const [paymentSaving, setPaymentSaving] = useState(false);

  // ── Synchronisation editAddrState ↔ readerProfile.address ──
  // Quand on charge un·e nouveau·lle lecteur·rice, on (ré)initialise le state
  // local d'édition d'adresse en parsant readerProfile.address. Et on remet
  // à zéro le message de feedback local.
  useEffect(() => {
    if (readerProfile?.address !== undefined) {
      setEditAddrState(parseAddressText(readerProfile.address));
    } else {
      setEditAddrState({
        line1: '', line2: '', unit: '', postal_code: '',
        district: '', city: '', state_region: '', country: ''
      });
    }
    setEditProfileMsg('');
  }, [readerProfile?.id]);

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
      const { data: tasksData } = await supabase.from('painel_internal_tasks').select('*').eq('library_id', libraryId).in('status', ['pendente', 'em_andamento']).order('priority').order('due_date').limit(50);
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

  // ── Reservation workflow ──────────────────────────────

  // PATCH 07/05/2026 : migration de fn_v2_set_reserva_linhas_workflow vers les
  // wrappers api.advance_reservation et api.mark_no_show (phase 2 spec).
  // Le wrapper valide la matrice de transitions (saut illégal rejeté) et le rôle.
  // La cible 'retirada_no_show' / 'nao_retirada' passe par le raccourci dédié.
  // Le notifyEvent manuel est supprimé : le trigger DB s'en charge.

  async function applyResWorkflow() {
    if (!resStage) { setActionMsg(t({id:'panel.action.selectStep'})); return; }
    const items = [...selectedRes];
    if (!items.length) { setActionMsg(t({id:'panel.action.selectAtLeastOne'})); return; }
    setActionMsg(t({id:'panel.action.applying'}));
    try {
      const isNoShow = (resStage === 'retirada_no_show' || resStage === 'nao_retirada');
      for (const key of items) {
        const [rid, lno] = key.split('-').map(Number);
        let error;
        if (isNoShow) {
          ({ error } = await supabase.schema('api').rpc('mark_no_show', {
            p_reserva_id: rid, p_line_no: lno,
          }));
        } else {
          // Construction des options jsonb pour advance_reservation
          const opts = {};
          if (resNote) opts.note = resNote;
          if (resSchedule) opts.pickup_scheduled_for = resSchedule;
          ({ error } = await supabase.schema('api').rpc('advance_reservation', {
            p_reserva_id: rid, p_line_no: lno,
            p_target_stage: resStage,
            p_options: opts,
          }));
        }
        if (error) throw error;
      }
      setActionMsg(t({id:'panel.action.stepApplied'},{count:items.length}));
      setSelectedRes(new Set());
      loadReservas();
    } catch (e) {
      // L'API peut renvoyer transition_not_allowed, pickup_scheduled_for_required,
      // target_stage_has_dedicated_rpc, etc. localizeError traduit le code.
      setActionMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.error.consultaWorkflow')}));
    }
  }

  async function cancelSelectedRes() {
    const items = [...selectedRes];
    if (!items.length) { setActionMsg(t({id:'panel.action.selectAtLeastOne'})); return; }
    // PATCH 07/05/2026 : migration vers api.cancel_reservation_as_library.
    // - Réservé aux coordenadores (coordenador_required si librarian)
    // - Raison obligatoire ≥ 5 chars si stage avancé (retirada_agendada,
    //   re-retirada_agendada, retirada_a_combinar, pronta_para_retirada).
    //   Le wrapper renvoie reason_required_min_5_chars sinon.
    // Le trigger DB cascade ensuite vers liberada_para_circulacao avec
    // final_reason='cancelled_by_library'.
    setActionMsg(t({id:'panel.action.cancelling'}));
    try {
      for (const key of items) {
        const [rid, lno] = key.split('-').map(Number);
        const { error } = await supabase.schema('api').rpc('cancel_reservation_as_library', {
          p_reserva_id: rid, p_line_no: lno,
          p_reason: resNote || null,
        });
        if (error) throw error;
      }
      setActionMsg(t({id:'panel.action.reservationsCancelled'},{count:items.length}));
      setSelectedRes(new Set());
      loadReservas();
    } catch (e) {
      setActionMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.apiError.generic')}));
    }
  }

  async function confirmSelectedPickup() {
    const items = [...selectedRes];
    if (!items.length) { setActionMsg(t({id:'panel.action.selectAtLeastOne'})); return; }
    // PATCH 07/05/2026 : migration vers api.confirm_pickup_v1 (phase 2 spec).
    // Restriction stricte : workflow_stage doit être pronta_para_retirada
    // (le wrapper rejette pickup_only_from_pronta_para_retirada sinon).
    // Conversion atomique réserve → emprunt. Retourne le loan_id (bigint).
    // Le notifyEvent manuel est supprimé : trigger DB s'en charge.
    // PATCH v2 07/05/2026 : affichage des loan_ids retournés pour confirmation visuelle
    // immédiate au staff (preuve technique synchrone que la conversion a réussi,
    // indépendamment de la livraison du mail).
    setActionMsg(t({id:'panel.action.confirmingPickup'}));
    try {
      const loanIds = [];
      for (const key of items) {
        const [rid, lno] = key.split('-').map(Number);
        const { data, error } = await supabase.schema('api').rpc('confirm_pickup_v1', {
          p_reserva_id: rid, p_line_no: lno,
          p_loan_options: {},
        });
        if (error) throw error;
        if (data) loanIds.push(data);
      }
      setActionMsg(
        loanIds.length
          ? t({id:'panel.action.pickupConfirmedWithIds'}, { count: loanIds.length, loanIds: loanIds.join(', #') })
          : t({id:'panel.action.pickupConfirmed'}, { count: items.length })
      );
      setSelectedRes(new Set());
      loadReservas();
      loadLoans();
    } catch (e) {
      setActionMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.apiError.generic')}));
    }
  }

  // ── Negociação simétrica de creneau (paquet 3B) ───────
  // PATCH 08/05/2026 : 3 handlers pour la négociation symétrique côté staff.
  // Tous routés via supabase.schema('api').rpc(...) — JAMAIS via la syntaxe
  // foireuse rpc(name, params, { schema: 'api' }) qui appelle silencieusement
  // public.* à la place.

  // Handler 1 : staff confirme le créneau contre-proposé par le lecteur·rice
  // → api.fn_confirm_pickup_slot_as_library (paquet 2 bis)
  // Précondition côté DB : pickup_proposed_by = 'leitor'.
  // Effet : transition vers pronta_para_retirada, pickup_proposed_by = NULL.
  async function confirmReaderSlot(rid, lno) {
    setActionMsg(t({id:'panel.action.confirmingReaderSlot'}));
    try {
      const { error } = await supabase.schema('api').rpc('fn_confirm_pickup_slot_as_library', {
        p_reserva_id: rid,
        p_line_no: lno,
      });
      if (error) throw error;
      setActionMsg(t({id:'panel.action.readerSlotConfirmed'}));
      // Si le form de contre-proposition était ouvert sur cette ligne, on le ferme
      if (negotiationForm?.reservaId === rid && negotiationForm?.lineNo === lno) {
        setNegotiationForm(null);
      }
      loadReservas();
    } catch (e) {
      setActionMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.apiError.generic')}));
    }
  }

  // Handler 2 : ouvre le form accordion de contre-proposition pour une ligne
  // donnée. Pré-remplit avec le créneau actuel converti en format
  // datetime-local (YYYY-MM-DDTHH:MM) et une note vide.
  function openCounterProposalForm(rid, lno, currentSlot) {
    let prefilled = '';
    if (currentSlot) {
      try {
        const d = new Date(currentSlot);
        // toLocaleString avec format ISO-like pour datetime-local input
        // (datetime-local attend "YYYY-MM-DDTHH:MM" en heure locale)
        const pad = (n) => String(n).padStart(2, '0');
        prefilled = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
      } catch { /* fallback string vide */ }
    }
    setNegotiationForm({ reservaId: rid, lineNo: lno, datetime: prefilled, note: '' });
  }

  // Handler 3 : envoie la contre-proposition staff (depuis le form ouvert)
  // → api.fn_propose_pickup_slot_as_library (paquet 2)
  // PATCH 09/05/2026 paquet 5b : sémantique v3.
  // La RPC accepte aussi bien une première proposition (depuis solicitada
  // ou em_preparacao) qu'une re-proposition (depuis retirada_a_combinar avec
  // pickup_proposed_by='leitor'). Cible toujours retirada_a_combinar.
  async function submitCounterProposal() {
    if (!negotiationForm) return;
    if (!negotiationForm.datetime) {
      setActionMsg(t({id:'panel.action.counterProposalDatetimeRequired'}));
      return;
    }
    setActionMsg(t({id:'panel.action.sendingCounterProposal'}));
    try {
      // datetime-local renvoie une string en heure LOCALE sans timezone.
      // On la convertit en ISO via new Date(...) qui interprète en local.
      const isoDatetime = new Date(negotiationForm.datetime).toISOString();
      const { error } = await supabase.schema('api').rpc('fn_propose_pickup_slot_as_library', {
        p_reserva_id: negotiationForm.reservaId,
        p_line_no: negotiationForm.lineNo,
        p_pickup_at: isoDatetime,
        p_note: negotiationForm.note?.trim() || null,
      });
      if (error) throw error;
      setActionMsg(t({id:'panel.action.counterProposalSent'}));
      setNegotiationForm(null);
      loadReservas();
    } catch (e) {
      setActionMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.apiError.generic')}));
    }
  }

  // Handler 4 : annulation par staff avec motif (réutilise le wrapper existant
  // api.cancel_reservation_as_library, qui exige une raison ≥ 5 chars si stage
  // avancé). Prompt minimal — UX modale future possible.
  async function cancelWithReason(rid, lno) {
    const reason = window.prompt(t({id:'panel.reservations.action.cancelReason.prompt'}));
    if (!reason || reason.trim().length < 5) {
      // Annulation par l'utilisateur ou raison trop courte (la DB rejetterait sinon)
      return;
    }
    setActionMsg(t({id:'panel.action.cancelling'}));
    try {
      const { error } = await supabase.schema('api').rpc('cancel_reservation_as_library', {
        p_reserva_id: rid,
        p_line_no: lno,
        p_reason: reason.trim(),
      });
      if (error) throw error;
      setActionMsg(t({id:'panel.action.reservationsCancelled'},{count: 1}));
      if (negotiationForm?.reservaId === rid && negotiationForm?.lineNo === lno) {
        setNegotiationForm(null);
      }
      loadReservas();
    } catch (e) {
      setActionMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.apiError.generic')}));
    }
  }

  // ── Ações: saída e devolução ──────────────────────────

  async function registrarSaida() {
    // Paquet 16 v2 (10/05/2026) : 2 phases (preview puis confirmation) + guard double-clic
    // Paquet 19 (10/05/2026) : utilise api.create_loan_at_counter au lieu de fn_v2_create_emprestimo_by_holdings
    if (loanBusy) return;
    const refs = loanRefs.split(/[,;\s]+/).map(r => r.trim()).filter(Boolean);
    if (!borrowerLookup.trim() || !refs.length) { setLoanMsg(t({ id: 'panel.loan.errorMissing' })); return; }

    // ════════════════════════════════════════════════════
    // PHASE 2 : confirmation - on a deja une preview valide
    // ════════════════════════════════════════════════════
    if (loanPreview && loanPreview.refsKey === refs.join('|') && loanPreview.borrowerKey === borrowerLookup.trim()) {
      setLoanBusy(true);
      setLoanMsg(t({id:'panel.loan.registering'}));
      try {
        const { error } = await supabase.schema('api').rpc('create_loan_at_counter', {
          p_user_id: loanPreview.borrowerId, p_holding_ids: loanPreview.holdingIds,
        });
        if (error) throw error;
        setLoanMsg(t({ id: 'panel.loan.exitRegistered' }, { count: refs.length, name: loanPreview.borrowerName }));
        // Paquet 9 (10/05/2026) : notifyEvent manuel supprimé. Le trigger DB
        // trg_notify_emprestimo_criado (header AFTER INSERT) s'en charge.
        setBorrowerLookup(''); setLoanRefs('');
        setLoanPreview(null);
        loadLoans();
      } catch (e) { setLoanMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.loan.errorMissing')})); }
      finally { setLoanBusy(false); }
      return;
    }

    // ════════════════════════════════════════════════════
    // PHASE 1 : preview - resoudre borrower + holdings + projection
    // ════════════════════════════════════════════════════
    setLoanBusy(true);
    setLoanMsg(t({id:'panel.loan.resolving'}));
    try {
      // Resolve borrower — CARD-LOCAL : même résolution que « gerir leitor·a »
      // (fn_painel_search_reader), qui accepte aussi l'identité locale (n°
      // lecteur·rice) en plus de l'UUID / ID public / e-mail, scopée à la biblio
      // courante avec repli « toutes mes biblios ». Renvoie { profile, … }.
      const lookupRes = await supabase.rpc('fn_painel_search_reader', { p_lookup: borrowerLookup.trim(), p_library_id: libraryId });
      if (lookupRes.error) throw lookupRes.error;
      const lookupData = Array.isArray(lookupRes.data) ? lookupRes.data[0] : lookupRes.data;
      const borrower = lookupData?.profile || null;
      if (!borrower?.id) { setLoanMsg(t({ id: 'panel.loan.readerNotFound' })); return; }

      // Resolve holdings
      const resolveRes = await supabase.rpc('fn_v2_resolve_catalog_refs_for_current_user', { p_refs: refs });
      if (resolveRes.error) throw resolveRes.error;
      const holdingIds = (resolveRes.data || []).filter(r => r.matched && Number(r.session_holding_id) > 0).map(r => Number(r.session_holding_id));
      if (!holdingIds.length) { setLoanMsg(t({ id: 'panel.loan.noValidRefs' })); return; }

      // Get loan projection (paquet 16)
      const bookIds = (resolveRes.data || []).filter(r => r.matched && Number(r.book_id) > 0).map(r => Number(r.book_id));
      const projectionRes = await supabase.schema('api').rpc('get_batch_loan_projection', {
        p_library_id: libraryId,
        p_user_id: borrower.id,
        p_book_ids: bookIds,
        p_holding_ids: holdingIds,
        p_quantity: holdingIds.length,
        p_as_of_date: new Date().toISOString().slice(0, 10),
      });
      if (projectionRes.error) throw projectionRes.error;
      const proj = Array.isArray(projectionRes.data) ? projectionRes.data[0] : projectionRes.data;

      // Stocker la preview
      setLoanPreview({
        borrowerId: borrower.id,
        borrowerName: borrower.first_name || borrower.email,
        borrowerKey: borrowerLookup.trim(),
        holdingIds,
        refsKey: refs.join('|'),
        dueDate: proj?.due_date,
        ruleLabel: proj?.rule_label,
        loanAllowed: proj?.loan_allowed !== false,
      });

      if (proj?.loan_allowed === false) {
        setLoanMsg(t({id:'panel.loan.preview.notAllowed'}, { rule: proj.rule_label || '' }));
      } else {
        setLoanMsg(t({id:'panel.loan.preview.confirm'}, {
          name: borrower.first_name || borrower.email,
          count: holdingIds.length,
          dueDate: fmtD(proj?.due_date) || '—',
          rule: proj?.rule_label || '—',
        }));
      }
    } catch (e) { setLoanMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.loan.errorMissing')})); }
    finally { setLoanBusy(false); }
  }

  // Paquet 16 v2 : annuler la preview pour reprendre la saisie
  function cancelLoanPreview() {
    setLoanPreview(null);
    setLoanMsg('');
  }

  async function registrarDevolucaoTotal() {
    const id = parseInt(returnId);
    if (!id) { setReturnMsg(t({id:'panel.loan.enterLoanId'})); return; }

    // ════════════════════════════════════════════════════
    // PHASE 2 : confirmation - preview valide et cohérente
    // ════════════════════════════════════════════════════
    if (returnTotalPreview && returnTotalPreview.id === id) {
      setReturnMsg(t({id:'panel.loan.returning'}));
      try {
        // Paquet 19 : utiliser le wrapper api.* au lieu de la fn DEFINER
        const { error } = await supabase.schema('api').rpc('return_loan_total', { p_emprestimo_id: id });
        if (error) throw error;
        setReturnMsg(t({id:'panel.return.totalRegistered'},{id}));
        // Paquet 9 (10/05/2026) : notifyEvent manuel supprimé. Le trigger DB
        // (via fn_v2_refresh_emprestimo_status_global) dispatch déjà l'event
        // approprié selon la transition (devolvido OU devolvido_apos_parcial).
        setReturnId('');
        setReturnTotalPreview(null);
        loadLoans();
      } catch (e) { setReturnMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.error.loanReturn')})); }
      return;
    }

    // ════════════════════════════════════════════════════
    // PHASE 1 : preview - vérifier emprunt + lister items à clore
    // ════════════════════════════════════════════════════
    // EA-03 (29/05/2026) : on cherche l'emprunt dans `loans` (et non
    // `activeLoans`) pour pouvoir distinguer "inconnu" (jamais existé / archivé)
    // de "déjà totalement clôturé" (tous items à 'devolvido' mais encore dans
    // le scope chargé). Si aucun item ouvert à clore, on rejette.
    const matchingItems = loans.filter(l => l.emprestimo_id === id);
    if (!matchingItems.length) {
      setReturnMsg(t({id:'panel.return.total.notFound'},{id}));
      return;
    }
    const openItems = matchingItems.filter(l => l.item_status === 'aberto');
    if (!openItems.length) {
      setReturnMsg(t({id:'panel.return.total.alreadyClosed'},{id}));
      return;
    }
    const borrowerName = matchingItems[0].user_name
      || matchingItems[0].user_email
      || matchingItems[0].user_public_id
      || '?';
    setReturnTotalPreview({
      id,
      borrowerName,
      itemCount: openItems.length,
    });
    setReturnMsg(t({id:'panel.return.total.preview.confirm'}, {
      id,
      borrower: borrowerName,
      count: openItems.length,
    }));
  }

  async function registrarDevolucaoParcial() {
    const subIds = returnSubIds.split(/[,;\s]+/).map(s => s.trim()).filter(Boolean);
    if (!subIds.length) { setReturnMsg(t({id:'panel.loan.enterSubIds'})); return; }

    // Clé de cohérence : chaîne canonique des sub_ids (triée pour être
    // insensible à l'ordre de saisie).
    const subIdsKey = subIds.slice().sort().join('|');

    // ════════════════════════════════════════════════════
    // PHASE 2 : confirmation - preview valide et cohérente
    // ════════════════════════════════════════════════════
    if (returnPartialPreview && returnPartialPreview.subIdsKey === subIdsKey) {
      setReturnMsg(t({id:'panel.loan.returning'}));
      // BUG-retour-partiel-faux-succès (28/05/2026) : on conserve la
      // défense en profondeur (filets backend + check data === 0) même
      // si la preview a déjà filtré les cas mal formés / inapplicables.
      // Cas couvert : un item passe en 'devolvido' entre la preview et
      // la confirmation (course condition rare mais possible).
      const rejected = [];
      const ok = [];
      for (const item of returnPartialPreview.okCandidates) {
        try {
          const { data, error } = await supabase.schema('api').rpc('return_loan_partial', {
            p_emprestimo_id: item.empId, p_line_nos: [item.lineNo],
          });
          if (error) throw error;
          if (data === 0 || data === null) {
            rejected.push(item.sub_id);
          } else {
            ok.push(item.sub_id);
          }
        } catch (e) {
          rejected.push(item.sub_id);
        }
      }
      // Message consolidé reprenant les 3 catégories (pre-preview + post-RPC).
      const parts = [];
      if (ok.length) {
        parts.push(t({id:'panel.return.partialRegistered'},{ids: ok.join(', ')}));
      }
      if (returnPartialPreview.malformed.length) {
        parts.push(t({id:'panel.return.malformedSubIds'},{ids: returnPartialPreview.malformed.join(', ')}));
      }
      const allRejected = [
        ...returnPartialPreview.preRejected.map(r => r.sub_id),
        ...rejected,
      ];
      if (allRejected.length) {
        parts.push(t({id:'panel.return.rejectedSubIds'},{ids: allRejected.join(', ')}));
      }
      setReturnMsg(parts.join(' · '));
      if (ok.length) {
        setReturnSubIds('');
        setReturnPartialPreview(null);
        loadLoans();
      }
      return;
    }

    // ════════════════════════════════════════════════════
    // PHASE 1 : preview - catégoriser les sub_ids
    // ════════════════════════════════════════════════════
    // EA-03 (29/05/2026) : tri front en 3 catégories AVANT exécution :
    //   - malformed : parsing échoué (book_id au lieu de sub_id, etc.)
    //   - preRejected : sub_id valide mais item inconnu ou déjà rendu
    //   - okCandidates : sub_id valide ET item ouvert → à rendre
    // Le même tri était fait après-coup côté front depuis le fix d'hier
    // soir ; maintenant on l'expose en preview pour que l'utilisateur·rice
    // puisse vérifier avant de confirmer.
    const malformed = [];
    const preRejected = [];
    const okCandidates = [];
    for (const subId of subIds) {
      const [empId, lineNo] = subId.split('.').map(Number);
      if (!empId || !lineNo) { malformed.push(subId); continue; }
      const item = loans.find(l => l.emprestimo_id === empId && l.line_no === lineNo);
      if (!item) {
        preRejected.push({ sub_id: subId, reason: 'unknown' });
      } else if (item.item_status !== 'aberto') {
        preRejected.push({ sub_id: subId, reason: 'alreadyReturned' });
      } else {
        okCandidates.push({
          sub_id: subId,
          empId,
          lineNo,
          titulo: item.titulo || item.bib_ref || '—',
        });
      }
    }

    // Si rien à rendre : message d'erreur immédiat sans pré-loader de preview.
    if (!okCandidates.length) {
      const parts = [];
      if (malformed.length) {
        parts.push(t({id:'panel.return.malformedSubIds'},{ids: malformed.join(', ')}));
      }
      if (preRejected.length) {
        parts.push(t({id:'panel.return.rejectedSubIds'},{ids: preRejected.map(r => r.sub_id).join(', ')}));
      }
      setReturnMsg(parts.join(' · '));
      return;
    }

    // Au moins un ok candidate : on stocke la preview et on demande confirmation.
    setReturnPartialPreview({
      subIdsKey,
      okCandidates,
      malformed,
      preRejected,
    });
    const parts = [
      t({id:'panel.return.partial.preview.confirm'}, {
        count: okCandidates.length,
        ids: okCandidates.map(c => c.sub_id).join(', '),
      }),
    ];
    if (malformed.length) {
      parts.push(t({id:'panel.return.partial.preview.malformed'}, { count: malformed.length }));
    }
    if (preRejected.length) {
      parts.push(t({id:'panel.return.partial.preview.rejected'}, { count: preRejected.length }));
    }
    setReturnMsg(parts.join(' · '));
  }

  // EA-03 (29/05/2026) : annulation symétrique de cancelLoanPreview, pour
  // les deux flux de retour. Reset le state preview + efface le message.
  function cancelReturnTotalPreview() {
    setReturnTotalPreview(null);
    setReturnMsg('');
  }
  function cancelReturnPartialPreview() {
    setReturnPartialPreview(null);
    setReturnMsg('');
  }

  // ── Empréstimo actions ─────────────────────────────────

  async function extendLoan(empId) {
    try {
      // Paquet 19 : utiliser le wrapper api.* au lieu de la fn DEFINER
      const { error } = await supabase.schema('api').rpc('extend_loan_as_library', { p_emprestimo_id: empId });
      if (error) throw error;
      loadLoans();
    } catch (e) {
      notifyError(localizeError(e, t, 'panel.loan.extendError'), e);
    }
  }

  async function returnLoanItem(empId, lineNos) {
    try {
      // Paquet 19 : utiliser le wrapper api.* au lieu de la fn DEFINER
      const { error } = await supabase.schema('api').rpc('return_loan_partial', {
        p_emprestimo_id: empId, p_line_nos: lineNos,
      });
      if (error) throw error;
      loadLoans();
    } catch (e) { notifyError(localizeError(e, t, 'panel.error.loanReturn'), e); }
  }

  async function extendLoanItem(empId, lineNo) {
    try {
      // Granularité Phase 4 : extension PAR ITEM via wrapper api.* (non-DEFINER).
      const { error } = await supabase.schema('api').rpc('extend_loan_item_as_library', {
        p_emprestimo_id: empId, p_line_no: lineNo,
      });
      if (error) throw error;
      loadLoans();
    } catch (e) {
      notifyError(localizeError(e, t, 'panel.loan.extendError'), e);
    }
  }

  // ── Consultation workflow ─────────────────────────────

  // Paquet 27.A.3 (5.A) : migration vers wrapper api.advance_consulta (SECURITY INVOKER).
  // scheduleParams optionnel : { startsAt, endsAt, timezone } pour stage 'consulta_agendada'.
  async function setConsultaWorkflow(consultaId, lineNo, stage, note, scheduleParams) {
    try {
      const params = {
        p_consulta_id: consultaId,
        p_line_nos: [lineNo],
        p_target_stage: stage,
        p_workflow_note: note || null,
      };
      if (scheduleParams) {
        params.p_consultation_starts_at = scheduleParams.startsAt || null;
        params.p_consultation_ends_at = scheduleParams.endsAt || null;
        params.p_consultation_timezone = scheduleParams.timezone || null;
      }
      const { error } = await supabase.schema('api').rpc('advance_consulta', params);
      if (error) throw error;
      loadConsultas();
    } catch (e) { notifyError(localizeError(e, t, 'panel.error.consultaWorkflow'), e); }
  }

  // Paquet 27.A.4 (5.B) : modal de proposition de creneau pour consulta agendada.
  function openScheduleModal(consulta) {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const yyyy = tomorrow.getFullYear();
    const mm = String(tomorrow.getMonth() + 1).padStart(2, '0');
    const dd = String(tomorrow.getDate()).padStart(2, '0');
    setScheduleTarget(consulta);
    setScheduleForm({ date: `${yyyy}-${mm}-${dd}`, startsAt: '14:00', endsAt: '15:00', note: '' });
    setScheduleError('');
  }

  function closeScheduleModal() {
    if (scheduling) return;
    setScheduleTarget(null);
    setScheduleError('');
  }

  // ═══════════════════════════════════════════════════════════
  // B6 (15/05/2026) : modal d'annulation biblio avec note obligatoire
  // Fix spec consultas v2.1 §6.2 / §8.1
  // ═══════════════════════════════════════════════════════════
  const [cancelTarget, setCancelTarget] = useState(null);
  const [cancelForm, setCancelForm] = useState({ note: '' });
  const [cancelError, setCancelError] = useState('');
  const [cancelling, setCancelling] = useState(false);

  function openCancelModal(consulta) {
    setCancelTarget(consulta);
    setCancelForm({ note: '' });
    setCancelError('');
  }

  function closeCancelModal() {
    if (cancelling) return;
    setCancelTarget(null);
    setCancelError('');
  }

  async function handleCancelSubmit() {
    if (!cancelTarget) return;
    const note = cancelForm.note.trim();
    setCancelError('');
    if (note.length < 5) {
      setCancelError(t({ id: 'panel.consultation.cancel.errorNoteTooShort' }));
      return;
    }
    if (note.length > 300) {
      setCancelError(t({ id: 'panel.consultation.cancel.errorNoteTooLong' }));
      return;
    }
    setCancelling(true);
    try {
      await setConsultaWorkflow(
        cancelTarget.consulta_id,
        cancelTarget.line_no,
        'cancelada_biblioteca',
        note
      );
      setCancelTarget(null);
      setCancelForm({ note: '' });
    } catch (err) {
      const msg = err?.message || '';
      if (msg.includes('cancel_note_required')) {
        setCancelError(t({ id: 'panel.consultation.cancel.errorBackend' }));
      } else {
        setCancelError(localizeError(err, t, 'panel.consultation.cancel.errorGeneric'));
      }
    } finally {
      setCancelling(false);
    }
  }

  async function handleScheduleSubmit() {
    if (!scheduleTarget) return;
    const { date, startsAt, endsAt, note } = scheduleForm;
    setScheduleError('');
    if (!date || !startsAt || !endsAt) {
      setScheduleError(t({ id: 'panel.consultation.schedule.errorRequired' }));
      return;
    }
    const todayStr = new Date().toISOString().slice(0, 10);
    if (date < todayStr) {
      setScheduleError(t({ id: 'panel.consultation.schedule.errorPastDate' }));
      return;
    }
    if (endsAt && endsAt <= startsAt) {
      setScheduleError(t({ id: 'panel.consultation.schedule.errorEndBeforeStart' }));
      return;
    }
    if (note && note.length > 300) {
      setScheduleError(t({ id: 'panel.consultation.schedule.errorNoteTooLong' }));
      return;
    }
    const startsIso = new Date(`${date}T${startsAt}:00`).toISOString();
    const endsIso = endsAt ? new Date(`${date}T${endsAt}:00`).toISOString() : null;
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || null;
    setScheduling(true);
    try {
      await setConsultaWorkflow(
        scheduleTarget.consulta_id,
        scheduleTarget.line_no,
        'consulta_agendada',
        note || null,
        { startsAt: startsIso, endsAt: endsIso, timezone: tz }
      );
      setScheduleTarget(null);
    } finally {
      setScheduling(false);
    }
  }

  // ── Task builder for trabalho do dia ──────────────────

  function buildDailyTasks() {
    const tasks = [];
    const today = new Date().toISOString().slice(0, 10);

    activeRes.forEach(r => {
      const stage = r.workflow_stage_effective || '';
      const pickupDay = r.pickup_scheduled_for ? new Date(r.pickup_scheduled_for).toISOString().slice(0, 10) : '';

      // PATCH 09/05/2026 paquet 5b : refactor sémantique v3.
      // retirada_agendada = créneau verrouillé : si pickupDay = aujourd'hui,
      // c'est un retrait prévu aujourd'hui → tâche prioritaire bucket 'hoje'.
      // re-retirada_agendada conservé en filet pour résas historiques fossiles.
      if (['retirada_agendada', 're-retirada_agendada'].includes(stage) && pickupDay === today) {
        tasks.push({ priority: 'alta', bucket: 'hoje', kind: t({id:'panel.task.scheduledToday'}), label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`, detail: t({id:'panel.task.detail.pickup'}) + ': ' + fmtD(r.pickup_scheduled_for), actionType: 'reserva', reserva_id: r.reserva_id });
      }
      if (stage === 'solicitada') {
        tasks.push({ priority: 'media', bucket: 'atencao', kind: t({id:'panel.task.newReservation'}), label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`, detail: `${t({id:'panel.task.detail.ref'})}: ${r.bib_ref} · ${t({id:'panel.task.detail.created'})}: ${fmtD(r.reserva_created_at)}`, actionType: 'reserva', reserva_id: r.reserva_id });
      }
      if (stage === 'pronta_para_retirada') {
        tasks.push({ priority: 'media', bucket: 'atencao', kind: t({id:'panel.task.readyForPickup'}), label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`, detail: `${t({id:'panel.task.detail.validity'})}: ${fmtD(r.expires_at)}`, actionType: 'reserva', reserva_id: r.reserva_id });
      }
      if (String(r.pickup_reply_status || '') === 'recusado_leitor') {
        tasks.push({ priority: 'alta', bucket: 'atencao', kind: t({id:'panel.task.readerRefused'}), label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`, detail: r.pickup_reply_note || t({id:'panel.task.detail.reschedule'}), actionType: 'reserva', reserva_id: r.reserva_id });
      }
      // PATCH 08/05/2026 paquet 3B : tâche prioritaire "Leitor(a/e) contra-propôs"
      // déclenchée quand pickup_proposed_by = 'leitor' (= le lecteur a renvoyé
      // une contre-proposition que le staff doit traiter rapidement).
      // Priorité haute : la balle est dans le camp staff, action requise.
      // PATCH 09/05/2026 paquet 5b : refactor sémantique v3.
      // La négociation se déroule désormais dans retirada_a_combinar (forme
      // verbale = action en cours), plus dans retirada_agendada/re-retirada_agendada.
      if (r.pickup_proposed_by === 'leitor' && stage === 'retirada_a_combinar') {
        const iter = r.negotiation_iteration_count ?? 0;
        tasks.push({
          priority: 'alta',
          bucket: 'atencao',
          kind: t({id:'panel.task.readerCounterProposed'}),
          label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`,
          detail: t({id:'panel.task.detail.proposedSlot'}) + ': ' + fmtD(r.pickup_scheduled_for)
                  + ' · ' + t({id:'panel.task.detail.iteration'}, { count: iter, max: 3 }),
          actionType: 'reserva',
          reserva_id: r.reserva_id,
        });
      }
      if (stage === 'nao_retirada') {
        tasks.push({ priority: 'alta', bucket: 'atencao', kind: t({id:'panel.task.notPickedUp'}), label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`, detail: decodeSystemNote(r.workflow_note, t) || t({id:'panel.task.detail.check'}), actionType: 'reserva', reserva_id: r.reserva_id });
      }
      // PATCH 09/05/2026 paquet 4 (approche A) : rendre visible le stage
      // retirada_a_combinar dans Trabalho do dia. Sinon ces résas restent
      // invisibles côté staff et le travail d'agendamento est oublié.
      // Priorité moyenne : action attendue mais sans urgence comme un
      // contra-proposta. Bucket atencao pour cohérence avec les autres
      // « il y a quelque chose à faire ».
      if (stage === 'retirada_a_combinar') {
        tasks.push({
          priority: 'media',
          bucket: 'atencao',
          kind: t({id:'panel.task.toScheduleWithReader'}),
          label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`,
          detail: decodeSystemNote(r.workflow_note, t) || t({id:'panel.task.detail.scheduleHint'}),
          actionType: 'reserva',
          reserva_id: r.reserva_id,
        });
      }
    });

    overdueLoans.forEach(l => {
      const effectiveDue = l.extended_until || l.due_at;
      const due = effectiveDue ? new Date(effectiveDue) : null;
      const diff = due ? Math.ceil((new Date() - due) / 86400000) : 0;
      tasks.push({ priority: 'alta', bucket: 'atencao', kind: t({id:'panel.task.overdueItem'}), label: `${l.user_name || l.user_email || l.user_public_id || '?'} · ${l.titulo}`, detail: t({id:'panel.task.detail.deadline'}) + ': ' + fmtD(effectiveDue) + ' · ' + t({id:'panel.task.detail.daysOverdue'},{days:diff}) + ' · ' + l.sub_id, actionType: 'emprestimo', emprestimo_id: l.emprestimo_id });
    });

    activeLoans.filter(l => {
      const effectiveDue = l.extended_until || l.due_at;
      return effectiveDue && new Date(effectiveDue).toISOString().slice(0, 10) === today;
    }).forEach(l => {
      const effectiveDue = l.extended_until || l.due_at;
      tasks.push({ priority: 'media', bucket: 'hoje', kind: t({id:'panel.task.dueTodayItem'}), label: `${l.user_name || l.user_email || l.user_public_id || '?'} · ${l.titulo}`, detail: `${t({id:'panel.task.detail.deadline'})}: ${fmtD(effectiveDue)} · ${l.sub_id}`, actionType: 'emprestimo', emprestimo_id: l.emprestimo_id });
    });

    consultations.filter(c => c.workflow_stage_effective === 'solicitada').forEach(c => {
      tasks.push({ priority: 'media', bucket: 'atencao', kind: t({id:'panel.task.consultToProcess'}), label: `${c.user_name || c.user_email || c.user_public_id || '?'} · ${c.titulo}`, detail: `${t({id:'panel.task.detail.ref'})}: ${c.bib_ref}`, actionType: 'consulta', consulta_id: c.consulta_id });
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
      // CARD-LOCAL-1 : recherche par UUID / e-mail / identité locale, scopée à la
      // biblio courante avec repli « toutes mes biblios » (biblio d'origine signalée).
      const { data, error } = await supabase.rpc('fn_painel_search_reader', { p_lookup: readerLookup.trim(), p_library_id: libraryId });
      if (error) throw error;
      const res = Array.isArray(data) ? data[0] : data;
      const p = res?.profile || null;
      if (!p) { setReaderMsg(t({id:'panel.reader.notFound'})); setReaderProfile(null); setReaderMatchInfo(null); return; }
      setReaderProfile(p);
      setReaderMatchInfo(res ? {
        matchedVia: res.matched_via || null,
        matchedLibraryId: res.matched_library_id || null,
        matchedLibraryName: res.matched_library_name || null,
        localIdentity: res.local_identity || null,
        membershipStatus: res.membership_status || null, // Suite 7
        isFallback: !!res.is_fallback,
      } : null);
      setReaderMsg('');
      // EA-10 : charger l'etat de restriction (local + global)
      try {
        const { data: rs } = await supabase.schema('api').rpc('get_member_restriction', { p_user_id: p.id, p_library_id: libraryId });
        setRestrictionState(rs?.ok ? rs : null);
      } catch { setRestrictionState(null); }
      // Charger l'historique de cotisation pour ce lecteur (tout staff peut gérer
      // les cotisations au quotidien — décision gouvernance 10/06, sauf gel global).
      if (membershipEnabled && isLibrarian) {
        const { data: payments } = await supabase.rpc('fn_list_membership_payments_for_user', { p_user_id: p.id });
        setReaderPayments(payments || []);
      } else {
        setReaderPayments([]);
      }
    } catch (e) { setReaderMsg(t({id:'common.errorPrefix'}, {message: localizeError(e, t)})); setReaderProfile(null); setReaderMatchInfo(null); }
  }

  // ── Cotisation ───────────────────────────────────────

  // Chargement de la config et des règles de cotisation
  const loadMembershipConfig = useCallback(async () => {
    if (!libraryId || !isLibrarian) return;
    try {
      // E.0 (paquet profils 19/05) : membership_enabled est deja expose par le
      // LibraryContext. Plus de SELECT redondant ici. On charge uniquement les regles.
      const { data: rules } = await supabase
        .from('library_membership_rules')
        .select('*')
        .eq('library_id', libraryId)
        .eq('is_active', true)
        .order('display_order');
      setMembershipRules(rules || []);
    } catch (e) { console.warn('loadMembershipConfig:', e); }
  }, [libraryId, isLibrarian]);

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

  // Ouvrir le modal de paiement
  function openPaymentModal(target) {
    if (membershipRules.length === 0) {
      setPaymentMsg(t({ id: 'membership.payment.noRulesAvailable' }));
      setPaymentMsgIsError(true);
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
    setPaymentMsgIsError(false);
  }

  function closePaymentModal() {
    setPaymentModal(null);
    setPaymentDraft(null);
    setPaymentMsg('');
    setPaymentMsgIsError(false);
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
    setPaymentMsgIsError(false);
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
      setPaymentMsgIsError(false);
      // Refresh des données affichées
      await loadMembershipOverview();
      if (readerProfile && readerProfile.id === paymentDraft.user_id) {
        const { data: payments } = await supabase.rpc('fn_list_membership_payments_for_user', { p_user_id: readerProfile.id });
        setReaderPayments(payments || []);
      }
      // Fermer le modal après 1s pour que le user voie le message
      setTimeout(() => closePaymentModal(), 1500);
    } catch (e) {
      setPaymentMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(e, t) }));
      setPaymentMsgIsError(true);
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
    // Audit UX 25/05/2026 (P1) : la selection « tout » porte sur les
    // reservations ACTIVES affichees, pas sur le tableau brut.
    if (selectedRes.size === activeRes.length) setSelectedRes(new Set());
    else setSelectedRes(new Set(activeRes.map(r => `${r.reserva_id}-${r.line_no}`)));
  }

  // ── Render ───────────────────────────────────────────

  // FIX BUG #1: Each tab now has a distinct hint key (was duplicating label).
  // Paquet E.2 (19/05/2026) : filtrage des onglets par availability selon profil de biblio.
  // ALL_TABS est l'array complet ; TABS est filtre via le hook usePanelAvailability
  // qui consomme circulation_mode et membership_enabled du LibraryContext.
  // Le check role (isCoordOrAdmin) sur 'contribuicoes' reste explicit : c'est un
  // check de role utilisateur orthogonal au profil de la biblio.
  const ALL_TABS = [
    { key: 'trabalho-do-dia', label: t({ id: 'panel.tab.dailyWork' }), hint: t({ id: 'panel.tab.dailyWork.hint' }) },
    { key: 'acoes', label: t({ id: 'panel.tab.actions' }), hint: t({ id: 'panel.tab.actions.hint' }) },
    { key: 'reservas', label: t({ id: 'panel.tab.reservations' }), hint: t({ id: 'panel.tab.reservations.hint' }) },
    { key: 'consultas-locais', label: t({ id: 'panel.tab.consultations' }), hint: t({ id: 'panel.tab.consultations.hint' }) },
    { key: 'emprestimos', label: t({ id: 'panel.tab.loans' }), hint: t({ id: 'panel.tab.loans.hint' }) },
    { key: 'leitor', label: t({ id: 'panel.tab.reader' }), hint: t({ id: 'panel.tab.reader.hint' }) },
    { key: 'historico', label: t({ id: 'panel.tab.history' }), hint: t({ id: 'panel.tab.history.hint' }) },
    ...(isCoordOrAdmin ? [
      { key: 'contribuicoes', label: t({ id: 'panel.tab.memberships' }), hint: t({ id: 'panel.tab.memberships.hint' }) },
    ] : []),
    // MULTI P5 (volet staff) : validation des inscriptions (librarian/coordenador).
    ...(isLibrarian ? [
      { key: 'validacoes', label: `${t({ id: 'panel.tab.validations' })}${pendingValidCount > 0 ? ` (${pendingValidCount})` : ''}`, hint: t({ id: 'panel.tab.validations.hint' }) },
    ] : []),
    // MOBILE P4 : récolement (inventaire par scan). Staff de terrain uniquement.
    ...(canRecolement ? [
      { key: 'recolement', label: t({ id: 'panel.tab.recolement' }), hint: t({ id: 'panel.tab.recolement.hint' }) },
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
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(170px, 1fr))', gap: 12, padding: '0 0 16px' }}>
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
        <nav className="ab-painel-tabs" role="tablist">
          {TABS.map(t => (
            <Fragment key={t.key}>
              <button className={`ab-painel-tab ${tab === t.key ? 'active' : ''}`}
                data-painel-tab={t.key}
                onClick={() => setTab(t.key)} role="tab">
                {t.label}
                <span className="ab-painel-tab__hint">{t.hint}</span>
              </button>
              {/* EA-01 : Trabalho do dia = vue d'ensemble ; le reste = vues de detail */}
              {t.key === 'trabalho-do-dia' && <span className="ab-painel-tab-divider" aria-hidden="true" />}
            </Fragment>
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

          </Suspense>

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
                          {r.name} — {r.amount_min > 0 ? t({id:'membership.rule.minAmount'}, {amount: r.amount_min, currency: r.currency}) : t({ id: 'membership.rule.freePrice' })}
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
                    <div style={{ padding: '8px 12px', borderRadius: 6, fontSize: '.85rem', background: paymentMsgIsError ? 'rgba(220,38,38,.1)' : 'rgba(74,222,128,.1)', color: paymentMsgIsError ? '#f87171' : '#4ade80' }}>
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

      {/* ONBO-Q4 : prise en main du Painel (coach-marks + check-list + canal humain) */}
      <PanelOnboarding
        availability={availability}
        circulationMode={circulation_mode}
        libraryId={libraryId}
        onNavigate={setTab}
      />

      <Footer />
          {/* Paquet 27.A.4 (5.B) : modal de proposition de creneau pour consulta */}
      <Modal
        isOpen={!!scheduleTarget}
        onClose={closeScheduleModal}
        title={t({ id: 'panel.consultation.schedule.title' })}
        size="medium"
      >
        <div className="ab-modal__body">
          {scheduleTarget && (
            <>
              <p style={{ marginBottom: 8 }}>
                <strong>{t({ id: 'panel.consultation.schedule.subtitle' })} :</strong>{' '}
                {scheduleTarget.user_name || scheduleTarget.user_email || scheduleTarget.user_public_id || '?'}
              </p>
              <p style={{ marginBottom: 16, fontStyle: 'italic', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.schedule.book' })} : {scheduleTarget.titulo || scheduleTarget.bib_ref || '?'}
              </p>
            </>
          )}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.schedule.dateLabel' })}
              </span>
              <input type="date" value={scheduleForm.date} onChange={(e) => setScheduleForm(f => ({ ...f, date: e.target.value }))} className="ab-input" disabled={scheduling} />
            </label>
            <div style={{ display: 'flex', gap: 12 }}>
              <label style={{ display: 'flex', flexDirection: 'column', gap: 4, flex: 1 }}>
                <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                  {t({ id: 'panel.consultation.schedule.startsAtLabel' })}
                </span>
                <input type="time" value={scheduleForm.startsAt} onChange={(e) => setScheduleForm(f => ({ ...f, startsAt: e.target.value }))} className="ab-input" disabled={scheduling} />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: 4, flex: 1 }}>
                <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                  {t({ id: 'panel.consultation.schedule.endsAtLabel' })}
                </span>
                <input type="time" value={scheduleForm.endsAt} onChange={(e) => setScheduleForm(f => ({ ...f, endsAt: e.target.value }))} className="ab-input" disabled={scheduling} />
              </label>
            </div>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.schedule.noteLabel' })}
              </span>
              <textarea value={scheduleForm.note} onChange={(e) => setScheduleForm(f => ({ ...f, note: e.target.value }))} placeholder={t({ id: 'panel.consultation.schedule.notePlaceholder' })} className="ab-input" rows={3} maxLength={300} disabled={scheduling} />
              <span style={{ fontSize: '.75rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.schedule.noteHint' })} ({scheduleForm.note.length}/300)
              </span>
            </label>
            <p style={{ fontSize: '.75rem', color: 'var(--brand-muted)', marginTop: 4 }}>
              {t({ id: 'panel.consultation.schedule.timezoneHint' }, { tz: Intl.DateTimeFormat().resolvedOptions().timeZone })}
            </p>
            {scheduleError && (
              <p style={{ color: 'var(--brand-danger, #c62828)', fontSize: '.9rem', margin: 0 }}>{scheduleError}</p>
            )}
          </div>
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={closeScheduleModal} disabled={scheduling}>
            {t({ id: 'panel.consultation.schedule.cancelButton' })}
          </Button>
          <Button onClick={handleScheduleSubmit} disabled={scheduling}>
            {scheduling ? t({ id: 'panel.consultation.schedule.submitting' }) : t({ id: 'panel.consultation.schedule.submitButton' })}
          </Button>
        </div>
      </Modal>

      {/* B6 (15/05/2026) : modal d'annulation biblio avec note obligatoire */}
      <Modal
        isOpen={!!cancelTarget}
        onClose={closeCancelModal}
        title={t({ id: 'panel.consultation.cancel.title' })}
        size="medium"
      >
        <div className="ab-modal__body">
          {cancelTarget && (
            <>
              <p style={{ marginBottom: 8 }}>
                <strong>{t({ id: 'panel.consultation.cancel.subtitle' })} :</strong>{' '}
                {cancelTarget.user_name || cancelTarget.user_email || cancelTarget.user_public_id || '?'}
              </p>
              <p style={{ marginBottom: 16, fontStyle: 'italic', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.cancel.book' })} : {cancelTarget.titulo || cancelTarget.bib_ref || '?'}
              </p>
            </>
          )}
          <p style={{ marginBottom: 12, fontSize: '.9rem' }}>
            {t({ id: 'panel.consultation.cancel.description' })}
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.cancel.noteLabel' })}
              </span>
              <textarea
                value={cancelForm.note}
                onChange={(e) => setCancelForm({ note: e.target.value })}
                placeholder={t({ id: 'panel.consultation.cancel.notePlaceholder' })}
                className="ab-input"
                rows={4}
                maxLength={300}
                disabled={cancelling}
              />
              <span style={{ fontSize: '.75rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.cancel.noteHint' })} ({cancelForm.note.length}/300, min 5)
              </span>
            </label>
            {cancelError && (
              <p style={{ color: 'var(--brand-danger, #c62828)', fontSize: '.9rem', margin: 0 }}>{cancelError}</p>
            )}
          </div>
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={closeCancelModal} disabled={cancelling}>
            {t({ id: 'panel.consultation.cancel.backButton' })}
          </Button>
          <Button onClick={handleCancelSubmit} disabled={cancelling || cancelForm.note.trim().length < 5}>
            {cancelling ? t({ id: 'panel.consultation.cancel.submitting' }) : t({ id: 'panel.consultation.cancel.confirmButton' })}
          </Button>
        </div>
      </Modal>
    </PageShell>
  );
}
