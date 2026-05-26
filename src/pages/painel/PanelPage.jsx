import { useState, useEffect, useCallback, useMemo, Fragment } from 'react';
import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase, apiQuery, notifyEvent } from '@/lib/supabase';
import { resolveErrorKey } from '@/lib/apiErrors';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, Spinner, Skeleton, EmptyState } from '@/components/ui';
import NegotiationStateBadge from '@/components/reservation/NegotiationStateBadge';
import CountrySelect from '@/components/forms/CountrySelect';
import StateSelect from '@/components/forms/StateSelect';
import PhoneInput from '@/components/forms/PhoneInput';
import { getCountryMetadata } from '@/components/forms/countryData';
import { parseAddressText, formatAddressText } from '@/lib/addressFormat';
import { getCountryName } from '@/lib/countries';
import { formatSchedule } from '@/lib/scheduleFormat';
import Modal from '@/components/ui/Modal';
import { useToast } from '@/contexts/ToastContext';
import './PanelPage.css';
import { usePanelAvailability } from '@/hooks/usePanelAvailability';
import UserHeroBadge from '@/components/UserHeroBadge';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';

// ═══════════════════════════════════════════════════════════
// Workflow labels and stage lists are built inside the component using t()
function fmtD(d) { if (!d) return '—'; try { return new Date(d).toLocaleString(undefined, { dateStyle: 'short', timeStyle: 'short' }); } catch { return d; } }

// ═══════════════════════════════════════════════════════════
// UserDisplay — composant interne (paquet 5f)
// ───────────────────────────────────────────────────────────
// Affiche un·e lecteur·rice dans une cellule de tableau ou un item de
// liste : nom complet sur la ligne principale, code public_id (ex:
// U0000030) en sous-titre discret en dessous.
//
// Cascade de fallback pour la ligne principale :
//   user_name → user_email → fragment d'UUID (8 premiers chars)
//
// Le sous-titre public_id n'est affiché que si :
//   - user_public_id est dispo (sinon rien à montrer en sous-titre)
//   - ET la ligne principale n'est PAS déjà l'UUID (sinon redondance)
//
// Cohérent avec le pattern existant emprestimo_itens_painel_ui qui
// expose user_public_id depuis le paquet 5e.
// ═══════════════════════════════════════════════════════════
function UserDisplay({ name, email, publicId, userId, fallback = '—' }) {
  const main = name || email || (userId ? userId.slice(0, 8) : fallback);
  const showSub = publicId && (name || email);
  return (
    <div className="ab-painel-user-display">
      <span>{main}</span>
      {showSub && <span className="ab-painel-user-display__sub">{publicId}</span>}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// useSort — hook pour tri ascendant/descendant sur un tableau (paquet 18)
// ───────────────────────────────────────────────────────────
// Usage :
//   const { sortedItems, sortKey, sortDir, toggleSort } = useSort(items);
//   <SortHeader sortKey="due_at" current={sortKey} dir={sortDir} onClick={toggleSort}>Échéance</SortHeader>
//   ... sortedItems.map(...)
//
// toggleSort(key) : null → asc → desc → null (cycle 3 etats).
// Si null, l'ordre original est preserve.
// ═══════════════════════════════════════════════════════════
function useSort(items) {
  const [sortKey, setSortKey] = useState(null);
  const [sortDir, setSortDir] = useState(null);

  const toggleSort = (key) => {
    if (sortKey !== key) { setSortKey(key); setSortDir('asc'); return; }
    if (sortDir === 'asc') { setSortDir('desc'); return; }
    if (sortDir === 'desc') { setSortKey(null); setSortDir(null); return; }
  };

  const sortedItems = useMemo(() => {
    if (!sortKey || !sortDir) return items;
    const arr = [...items];
    arr.sort((a, b) => {
      const va = a?.[sortKey], vb = b?.[sortKey];
      // null/undefined toujours en bas
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;
      // dates ISO (heuristique : string commencant par YYYY-)
      const isaDate = typeof va === 'string' && /^\d{4}-\d{2}-\d{2}/.test(va);
      const isbDate = typeof vb === 'string' && /^\d{4}-\d{2}-\d{2}/.test(vb);
      if (isaDate && isbDate) {
        const cmp = new Date(va).getTime() - new Date(vb).getTime();
        return sortDir === 'asc' ? cmp : -cmp;
      }
      // nombres (y compris strings purement numeriques)
      const na = Number(va), nb = Number(vb);
      if (!Number.isNaN(na) && !Number.isNaN(nb) && typeof va !== 'object' && typeof vb !== 'object') {
        const cmp = na - nb;
        if (cmp !== 0) return sortDir === 'asc' ? cmp : -cmp;
      }
      // fallback : comparaison string
      const sa = String(va), sb = String(vb);
      const cmp = sa.localeCompare(sb, undefined, { numeric: true, sensitivity: 'base' });
      return sortDir === 'asc' ? cmp : -cmp;
    });
    return arr;
  }, [items, sortKey, sortDir]);

  return { sortedItems, sortKey, sortDir, toggleSort };
}

// ═══════════════════════════════════════════════════════════
// SortHeader — composant <th> cliquable avec fleche (paquet 18)
// ═══════════════════════════════════════════════════════════
function SortHeader({ sortKey, current, dir, onClick, children }) {
  const isActive = current === sortKey;
  const arrow = isActive ? (dir === 'asc' ? ' ↑' : ' ↓') : '';
  return (
    <th onClick={() => onClick(sortKey)} style={{ cursor: 'pointer', userSelect: 'none' }} title="Cliquer pour trier">
      {children}{arrow}
    </th>
  );
}

// ═══════════════════════════════════════════════════════════

export default function PanelPage() {
  const { user } = useAuth();
  const { libraryId, libraryName, role, circulation_mode, membership_enabled } = useLibrary();
  const availability = usePanelAvailability();
  const { formatMessage: t, locale } = useIntl();
  const { notifyError } = useToast();
  useDocumentTitle(t({ id: 'pageTitle.panel' }));
  const roleLoaded = role !== null && role !== undefined;
  const isLibrarian = role === 'librarian' || role === 'coordenador' || role === 'administrador';
  const isCoordOrAdmin = role === 'coordenador' || role === 'administrador';

  // i18n-aware workflow labels
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
    retirada_no_show: t({ id: 'reservation.stage.nao_retirada' }),
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
  const [loading, setLoading] = useState(true);
  const [reservations, setReservations] = useState([]);
  const [consultations, setConsultations] = useState([]);
  const [loans, setLoans] = useState([]);
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

  const HISTORY_PAGE_SIZE = 50;
  const HISTORY_VIEW_NAMES = {
    reservas: 'painel_reservations_history_v1',
    consultas: 'painel_consultas_history_v1',
    emprestimos: 'painel_loans_history_v1'
  };

  const loadHistorySection = useCallback(async (type, append = false) => {
    if (historyLoading[type]) return;
    setHistoryLoading(prev => ({ ...prev, [type]: true }));
    
    const offset = append ? historyOffsets[type] : 0;
    const viewName = HISTORY_VIEW_NAMES[type];
    
    try {
      const { data, error } = await supabase
        .schema('api').from(viewName)
        .select('*')
        .range(offset, offset + HISTORY_PAGE_SIZE - 1);
      
      if (error) {
        console.error(`load ${type} history error:`, error);
        setHistoryLoading(prev => ({ ...prev, [type]: false }));
        return;
      }
      
      const items = data || [];
      const hasMore = items.length === HISTORY_PAGE_SIZE;
      
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
  }, [historyLoading, historyOffsets]);

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
  const [resStageFilter, setResStageFilter] = useState('all');
  const [conStageFilter, setConStageFilter] = useState('all');
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

  // Gerir leitor
  const [readerLookup, setReaderLookup] = useState('');
  const [readerProfile, setReaderProfile] = useState(null);
  const [readerMsg, setReaderMsg] = useState('');
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
      loadData();
    } catch (e) {
      // L'API peut renvoyer transition_not_allowed, pickup_scheduled_for_required,
      // target_stage_has_dedicated_rpc, etc. resolveErrorKey traduit le code.
      setActionMsg(t({id:'common.errorPrefix'},{message: t({id: resolveErrorKey(e, 'panel.error.consultaWorkflow')})}));
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
      loadData();
    } catch (e) {
      setActionMsg(t({id:'common.errorPrefix'},{message: t({id: resolveErrorKey(e, 'panel.apiError.generic')})}));
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
      loadData();
    } catch (e) {
      setActionMsg(t({id:'common.errorPrefix'},{message: t({id: resolveErrorKey(e, 'panel.apiError.generic')})}));
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
      loadData();
    } catch (e) {
      setActionMsg(t({id:'common.errorPrefix'},{message: t({id: resolveErrorKey(e, 'panel.apiError.generic')})}));
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
      loadData();
    } catch (e) {
      setActionMsg(t({id:'common.errorPrefix'},{message: t({id: resolveErrorKey(e, 'panel.apiError.generic')})}));
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
      loadData();
    } catch (e) {
      setActionMsg(t({id:'common.errorPrefix'},{message: t({id: resolveErrorKey(e, 'panel.apiError.generic')})}));
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
        loadData();
      } catch (e) { setLoanMsg(t({id:'common.errorPrefix'},{message: t({id: resolveErrorKey(e, 'panel.loan.errorMissing')})})); }
      finally { setLoanBusy(false); }
      return;
    }

    // ════════════════════════════════════════════════════
    // PHASE 1 : preview - resoudre borrower + holdings + projection
    // ════════════════════════════════════════════════════
    setLoanBusy(true);
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
    } catch (e) { setLoanMsg(t({id:'common.errorPrefix'},{message: t({id: resolveErrorKey(e, 'panel.loan.errorMissing')})})); }
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
      loadData();
    } catch (e) { setReturnMsg(t({id:'common.errorPrefix'},{message: t({id: resolveErrorKey(e, 'panel.error.loanReturn')})})); }
  }

  async function registrarDevolucaoParcial() {
    const subIds = returnSubIds.split(/[,;\s]+/).map(s => s.trim()).filter(Boolean);
    if (!subIds.length) { setReturnMsg(t({id:'panel.loan.enterSubIds'})); return; }
    setReturnMsg(t({id:'panel.loan.returning'}));
    try {
      for (const subId of subIds) {
        const [empId, lineNo] = subId.split('.').map(Number);
        if (!empId || !lineNo) continue;
        // Paquet 19 : utiliser le wrapper api.* (et fix : fn_v2_return_emprestimo_itens n'existe pas, c'etait fn_v2_return_emprestimo_linhas)
        await supabase.schema('api').rpc('return_loan_partial', {
          p_emprestimo_id: empId, p_line_nos: [lineNo],
        });
      }
      setReturnMsg(t({id:'panel.return.partialRegistered'},{ids:subIds.join(', ')}));
      setReturnSubIds('');
      loadData();
    } catch (e) { setReturnMsg(t({id:'common.errorPrefix'},{message: t({id: resolveErrorKey(e, 'panel.error.loanReturn')})})); }
  }

  // ── Empréstimo actions ─────────────────────────────────

  async function extendLoan(empId) {
    try {
      // Paquet 19 : utiliser le wrapper api.* au lieu de la fn DEFINER
      const { error } = await supabase.schema('api').rpc('extend_loan_as_library', { p_emprestimo_id: empId });
      if (error) throw error;
      loadData();
    } catch (e) {
      notifyError(t({ id: resolveErrorKey(e, 'panel.loan.extendError') }), e);
    }
  }

  async function returnLoanItem(empId, lineNos) {
    try {
      // Paquet 19 : utiliser le wrapper api.* au lieu de la fn DEFINER
      const { error } = await supabase.schema('api').rpc('return_loan_partial', {
        p_emprestimo_id: empId, p_line_nos: lineNos,
      });
      if (error) throw error;
      loadData();
    } catch (e) { notifyError(t({ id: resolveErrorKey(e, 'panel.error.loanReturn') }), e); }
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
      loadData();
    } catch (e) { notifyError(t({ id: resolveErrorKey(e, 'panel.error.consultaWorkflow') }), e); }
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
        setCancelError(msg || t({ id: 'panel.consultation.cancel.errorGeneric' }));
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
        tasks.push({ priority: 'alta', bucket: 'atencao', kind: t({id:'panel.task.notPickedUp'}), label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`, detail: r.workflow_note || t({id:'panel.task.detail.check'}), actionType: 'reserva', reserva_id: r.reserva_id });
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
          detail: r.workflow_note || t({id:'panel.task.detail.scheduleHint'}),
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
      setPaymentMsg(t({ id: 'common.errorPrefix' }, { message: e.message }));
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
    { key: 'emprestimos-livro', label: t({ id: 'panel.tab.loans' }), hint: t({ id: 'panel.tab.loans.hint' }) },
    { key: 'emprestimos-lote', label: t({ id: 'panel.loan.grouped' }), hint: t({ id: 'panel.tab.grouped.hint' }) },
    { key: 'leitor', label: t({ id: 'panel.tab.reader' }), hint: t({ id: 'panel.tab.reader.hint' }) },
    { key: 'historico', label: t({ id: 'panel.tab.history' }), hint: t({ id: 'panel.tab.history.hint' }) },
    ...(isCoordOrAdmin ? [
      { key: 'contribuicoes', label: t({ id: 'panel.tab.memberships' }), hint: t({ id: 'panel.tab.memberships.hint' }) },
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
  const activeRes = reservations.filter(r => r.item_status === 'ativa');
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
  const activeConsultations = consultations.filter(c => c.item_status === 'ativa');
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
        <UserHeroBadge />
        <HeroDocumentationActions
          extraActions={
            <>
              <Pill variant={activeRes.length > 0 ? 'warn' : 'default'}>{t({ id: 'panel.reservations.active' }, { count: activeRes.length })}</Pill>
              <Pill>{t({ id: 'panel.consultations.active' }, { count: consultations.filter(c => c.item_status === 'ativa').length })}</Pill>
              <Pill variant={overdueLoans.length > 0 ? 'bad' : 'default'}>{t({ id: 'panel.loan.openLoans' }, { count: activeLoanGroups, items: activeLoans.length, overdue: overdueLoans.length })}</Pill>
              <Button variant="secondary" onClick={loadData}>{t({ id: 'common.refresh' })}</Button>
            </>
          }
        />
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
                <SummaryCard label={t({id:'panel.summary.today'})} count={hoje.length} variant="warn" />
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
                                // Chantier #TASKS : router par fn_task_update_status (RPC)
                                // au lieu d'un update() direct. Le update() court-circuitait
                                // la regeneration des taches recurrentes a l'achevement.
                                try {
                                  const { error } = await supabase.rpc('fn_task_update_status', {
                                    p_task_id: tk.id, p_new_status: e.target.value,
                                  });
                                  if (error) throw error;
                                  loadData();
                                } catch (err) {
                                  notifyError(t({ id: resolveErrorKey(err, 'panel.error.taskStatus') }), err);
                                }
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
                  <input type="text" value={borrowerLookup} onChange={e => { setBorrowerLookup(e.target.value); if (loanPreview) setLoanPreview(null); }} placeholder={t({ id: 'panel.loan.borrowerPlaceholder' })} className="ab-painel-input" />
                </label>
                <label>{t({ id: 'panel.loan.refsLabel' })}
                  <input type="text" value={loanRefs} onChange={e => { setLoanRefs(e.target.value); if (loanPreview) setLoanPreview(null); }} placeholder={t({ id: 'panel.loan.refsPlaceholder' })} className="ab-painel-input" />
                </label>
                <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                  <Button onClick={registrarSaida} disabled={loanBusy || (loanPreview && loanPreview.loanAllowed === false)}>
                    {loanBusy
                      ? '…'
                      : loanPreview
                        ? t({ id: 'panel.loan.confirmRegister' })
                        : t({ id: 'panel.loan.register' })}
                  </Button>
                  {loanPreview && !loanBusy && (
                    <Button variant="secondary" onClick={cancelLoanPreview}>
                      {t({ id: 'panel.loan.cancelPreview' })}
                    </Button>
                  )}
                </div>
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
                {/* PATCH 07/05/2026 : grisage des transitions illégales depuis le(s) stage(s) sélectionné(s).
                    - Calcul de l'intersection des transitions valides pour toutes les lignes sélectionnées
                    - Si sélection vide : toutes options actives (mode exploratoire)
                    - Si une option n'est valide pour aucune des lignes : disabled + title explicatif */}
                <select value={resStage} onChange={e => setResStage(e.target.value)} className="ab-painel-input">
                  <option value="">{t({ id: 'panel.reservations.selectStage' })}</option>
                  {(() => {
                    const selectedStages = [...selectedRes]
                      .map(key => {
                        const [rid, lno] = key.split('-').map(Number);
                        const row = reservations.find(r => r.reserva_id === rid && r.line_no === lno);
                        return row?.workflow_stage_effective || row?.item_status || null;
                      })
                      .filter(Boolean);
                    return RES_STAGES.map(s => {
                      // Mode exploratoire : pas de sélection, tout est actif
                      if (!selectedStages.length) {
                        return <option key={s.value} value={s.value}>{s.label}</option>;
                      }
                      // Sinon, transition autorisée pour TOUTES les lignes sélectionnées (intersection)
                      const allValid = selectedStages.every(from => canTransition(from, s.value, actorRole));
                      const distinctStages = [...new Set(selectedStages)];
                      const stageList = distinctStages
                        .map(st => WORKFLOW_LABELS[st] || st)
                        .join(', ');
                      const reasonHint = allValid
                        ? undefined
                        : t({ id: 'panel.reservations.transitionBlocked' }, { stages: stageList });
                      return (
                        <option
                          key={s.value}
                          value={s.value}
                          disabled={!allValid}
                          title={reasonHint}
                          style={!allValid ? { color: '#888' } : undefined}
                        >
                          {allValid ? s.label : `${s.label} ✗`}
                        </option>
                      );
                    });
                  })()}
                </select>
                <Button variant="secondary" onClick={applyResWorkflow}>{t({ id: 'panel.reservations.applyStep' })}</Button>
              </div>
              {/* PATCH 07/05/2026 : aide UX pour clarifier les actions hors menu */}
              <p className="ab-painel-help" style={{ fontSize: '0.85em', color: '#888', marginTop: '4px' }}>
                {t({ id: 'panel.reservations.menuHelp' })}
              </p>
              <StageFilterBar
                counts={resStageCounts}
                current={resStageFilter}
                onSelect={setResStageFilter}
                labels={WORKFLOW_LABELS}
                allLabel={t({ id: 'panel.stageFilter.all' })}
              />
              {actionMsg && <p className="ab-painel-msg">{actionMsg}</p>}
              {sortRes.sortedItems.length === 0 ? (
                <EmptyState message={t({
                  id: resStageFilter === 'all'
                    ? 'panel.reservations.empty'
                    : 'panel.reservations.emptyStage'
                })} />
              ) : (
              <div className="ab-painel-table-wrap">
                <table className="ab-painel-table">
                  <thead>
                    <tr>
                      <th><input type="checkbox" checked={selectedRes.size === activeRes.length && activeRes.length > 0} onChange={toggleAllRes} /></th>
                      <SortHeader sortKey="sub_id" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.subId'})}</SortHeader>
                      <SortHeader sortKey="user_name" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.reader'})}</SortHeader>
                      <SortHeader sortKey="titulo" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.book'})}</SortHeader>
                      <SortHeader sortKey="bib_ref" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.ref'})}</SortHeader>
                      <SortHeader sortKey="rotulo" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.label'})}</SortHeader>
                      <SortHeader sortKey="workflow_stage_effective" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.step'})}</SortHeader>
                      <SortHeader sortKey="pickup_scheduled_for" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.pickup'})}</SortHeader>
                      <SortHeader sortKey="expires_at" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.validity'})}</SortHeader>
                      <SortHeader sortKey="pickup_proposed_by" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.negotiation'})}</SortHeader>
                      <th>{t({id:'panel.table.actions'})}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {sortRes.sortedItems.map((r, i) => {
                      const key = `${r.reserva_id}-${r.line_no}`;
                      // PATCH 08/05/2026 paquet 3B : ligne accordion ouverte si on
                      // est en train de contre-proposer pour cette ligne précisément
                      const isFormOpen = negotiationForm?.reservaId === r.reserva_id
                                      && negotiationForm?.lineNo === r.line_no;
                      // Détermine si les actions inline sont disponibles : seulement
                      // quand le lecteur·rice a contre-proposé (= staff a la balle).
                      // PATCH 09/05/2026 paquet 5b : refactor sémantique v3.
                      // La négociation se déroule désormais dans retirada_a_combinar.
                      const showStaffActions = r.pickup_proposed_by === 'leitor'
                                            && r.workflow_stage_effective === 'retirada_a_combinar';
                      // Indicateur "esperando resposta" quand notre biblio a déjà proposé
                      const isWaitingReader = r.pickup_proposed_by === 'biblio'
                                           && r.workflow_stage_effective === 'retirada_a_combinar';
                      return (
                        <Fragment key={i}>
                          <tr className={selectedRes.has(key) ? 'selected' : ''}>
                            <td><input type="checkbox" checked={selectedRes.has(key)} onChange={() => toggleRes(key)} /></td>
                            <td>{r.sub_id}</td>
                            <td>
                              <UserDisplay
                                name={r.user_name}
                                email={r.user_email}
                                publicId={r.user_public_id}
                                userId={r.user_id}
                              />
                            </td>
                            <td><Link to={`/livro/${r.book_id}`}>{r.titulo || '—'}</Link></td>
                            <td>{r.bib_ref}</td>
                            <td>{r.rotulo || '—'}</td>
                            <td><span className="ab-painel-stage" data-stage={r.workflow_stage_effective}>{WORKFLOW_LABELS[r.workflow_stage_effective] || r.item_status || '—'}</span></td>
                            <td>{fmtD(r.pickup_scheduled_for)}</td>
                            <td>{fmtD(r.expires_at)}</td>
                            {/* Colonne Negociação : badge d'état */}
                            <td>
                              <NegotiationStateBadge
                                proposedBy={r.pickup_proposed_by}
                                iterationCount={r.negotiation_iteration_count}
                                stage={r.workflow_stage_effective}
                                viewerRole="staff"
                              />
                            </td>
                            {/* Colonne Ações : 3 boutons inline si lecteur·rice a contre-proposé,
                                texte simple si on attend, rien sinon */}
                            <td className="ab-painel-actions-cell">
                              {showStaffActions && (
                                <div style={{ display:'flex', gap:6, flexWrap:'wrap' }}>
                                  <button
                                    className="ab-button ab-button--mini"
                                    onClick={() => confirmReaderSlot(r.reserva_id, r.line_no)}
                                    title={t({id:'panel.reservations.action.confirmReaderSlot.tooltip'})}
                                  >
                                    {t({id:'panel.reservations.action.confirmReaderSlot'})}
                                  </button>
                                  <button
                                    className="ab-button ab-button--secondary ab-button--mini"
                                    onClick={() => isFormOpen
                                      ? setNegotiationForm(null)
                                      : openCounterProposalForm(r.reserva_id, r.line_no, r.pickup_scheduled_for)}
                                    title={t({id:'panel.reservations.action.counterProposeSlot.tooltip'})}
                                  >
                                    {isFormOpen
                                      ? t({id:'panel.reservations.counterProposeForm.cancelForm'})
                                      : t({id:'panel.reservations.action.counterProposeSlot'})}
                                  </button>
                                  <button
                                    className="ab-button ab-button--mini ab-button--danger"
                                    onClick={() => cancelWithReason(r.reserva_id, r.line_no)}
                                    title={t({id:'panel.reservations.action.cancelWithReason.tooltip'})}
                                  >
                                    {t({id:'panel.reservations.action.cancelWithReason'})}
                                  </button>
                                </div>
                              )}
                              {!showStaffActions && isWaitingReader && (
                                <span style={{ fontSize:'.8rem', color:'var(--brand-muted)', fontStyle:'italic' }}>
                                  {t({id:'panel.reservations.negotiation.waitingReaderInline'})}
                                </span>
                              )}
                            </td>
                          </tr>
                          {/* PATCH 08/05/2026 paquet 3B : ligne accordion contenant le mini-form
                              de contre-proposition. Utilise colSpan=11 pour couvrir toutes les
                              colonnes (1 checkbox + 8 colonnes data + negotiation + actions). */}
                          {isFormOpen && (
                            <tr className="ab-painel-counter-form-row">
                              <td colSpan={11} style={{ padding:'12px 16px', background:'rgba(251,191,36,.08)', borderTop:'2px solid rgba(251,191,36,.4)' }}>
                                <div style={{ display:'flex', gap:12, flexWrap:'wrap', alignItems:'flex-end' }}>
                                  <div style={{ display:'flex', flexDirection:'column', gap:4, minWidth:200 }}>
                                    <label style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                                      {t({id:'panel.reservations.counterProposeForm.datetime'})}
                                    </label>
                                    <input
                                      type="datetime-local"
                                      value={negotiationForm.datetime}
                                      onChange={e => setNegotiationForm(prev => prev ? { ...prev, datetime: e.target.value } : prev)}
                                      className="ab-painel-input"
                                    />
                                  </div>
                                  <div style={{ display:'flex', flexDirection:'column', gap:4, flex:1, minWidth:240 }}>
                                    <label style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                                      {t({id:'panel.reservations.counterProposeForm.note'})}
                                    </label>
                                    <input
                                      type="text"
                                      value={negotiationForm.note}
                                      onChange={e => setNegotiationForm(prev => prev ? { ...prev, note: e.target.value } : prev)}
                                      className="ab-painel-input"
                                      placeholder={t({id:'panel.reservations.counterProposeForm.notePlaceholder'})}
                                    />
                                  </div>
                                  <div style={{ display:'flex', gap:6 }}>
                                    <Button onClick={submitCounterProposal}>
                                      {t({id:'panel.reservations.counterProposeForm.submit'})}
                                    </Button>
                                    <Button variant="secondary" onClick={() => setNegotiationForm(null)}>
                                      {t({id:'panel.reservations.counterProposeForm.cancelForm'})}
                                    </Button>
                                  </div>
                                </div>
                              </td>
                            </tr>
                          )}
                        </Fragment>
                      );
                    })}
                  </tbody>
                </table>
              </div>
              )}
            </div>
          )}

          {/* ═══ CONSULTAS LOCAIS ═══ */}
          {tab === 'consultas-locais' && (
            <div>
              <h2 className="ab-painel-h2">{t({ id: 'panel.tab.consultations' })}</h2>
              <StageFilterBar
                counts={conStageCounts}
                current={conStageFilter}
                onSelect={setConStageFilter}
                labels={CONSULT_WORKFLOW}
                allLabel={t({ id: 'panel.stageFilter.all' })}
              />
              {sortCon.sortedItems.length === 0 ? (
                <EmptyState message={t({
                  id: conStageFilter === 'all'
                    ? 'panel.consultations.empty'
                    : 'panel.consultations.emptyStage'
                })} />
              ) : (
              <div className="ab-painel-table-wrap">
                <table className="ab-painel-table">
                  <thead><tr>
                    <SortHeader sortKey="sub_id" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({id:'panel.table.subId'})}</SortHeader>
                    <SortHeader sortKey="user_name" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({id:'panel.table.reader'})}</SortHeader>
                    <SortHeader sortKey="titulo" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({id:'panel.table.book'})}</SortHeader>
                    <SortHeader sortKey="bib_ref" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({id:'panel.table.ref'})}</SortHeader>
                    <SortHeader sortKey="workflow_stage_effective" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({id:'panel.table.step'})}</SortHeader>
                    <SortHeader sortKey="consultation_scheduled_for" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({ id: 'panel.loan.scheduling' })}</SortHeader>
                    <th>{t({id:'panel.table.actions'})}</th>
                  </tr></thead>
                  <tbody>
                    {sortCon.sortedItems.map((c, i) => (
                      <tr key={i}>
                        <td>{c.sub_id}</td>
                        <td>
                          <UserDisplay
                            name={c.user_name}
                            email={c.user_email}
                            publicId={c.user_public_id}
                            userId={c.user_id}
                          />
                        </td>
                        <td><Link to={`/livro/${c.book_id}`}>{c.titulo || '—'}</Link></td>
                        <td>{c.bib_ref}</td>
                        <td><span className="ab-painel-stage" data-stage={c.workflow_stage_effective}>{CONSULT_WORKFLOW[c.workflow_stage_effective] || c.item_status || '—'}</span></td>
                        <td>
                          {c.consultation_starts_at ? (
                            <>
                              <div>{formatSchedule(c)}</div>
                              {c.workflow_stage_effective === 'consulta_agendada' && c.schedule_reply_status === 'confirmado_leitor' && (
                                <span style={{ color: '#15803d', fontSize: '.85rem', fontWeight: 600 }}>
                                  ✓ {t({ id: 'panel.consultation.replyStatus.confirmed' })}
                                </span>
                              )}
                              {c.workflow_stage_effective === 'consulta_agendada' && c.schedule_reply_status === 'recusado_leitor' && (
                                <div>
                                  <span style={{ color: '#c2410c', fontSize: '.85rem', fontWeight: 600 }}>
                                    ✗ {t({ id: 'panel.consultation.replyStatus.refused' })}
                                  </span>
                                  {c.schedule_reply_note && (
                                    <div style={{ fontSize: '.75rem', fontStyle: 'italic', color: 'var(--brand-muted)', marginTop: 2 }}>
                                      {t({ id: 'panel.consultation.refuseReason' })} {c.schedule_reply_note}
                                    </div>
                                  )}
                                </div>
                              )}
                              {c.workflow_stage_effective === 'consulta_agendada' && !c.schedule_reply_status && (
                                <span style={{ color: 'var(--brand-muted)', fontSize: '.85rem' }}>
                                  ⏳ {t({ id: 'panel.consultation.replyStatus.pending' })}
                                </span>
                              )}
                            </>
                          ) : fmtD(c.consultation_scheduled_for)}
                        </td>
                        <td className="ab-painel-actions-cell">
                          {c.workflow_stage_effective === 'solicitada' && (
                            <button className="ab-button ab-button--mini" onClick={() => setConsultaWorkflow(c.consulta_id, c.line_no, 'em_preparacao')}>{t({id:'panel.table.prepare'})}</button>
                          )}
                          {c.workflow_stage_effective === 'em_preparacao' && (
                            <button className="ab-button ab-button--mini" onClick={() => openScheduleModal(c)}>{t({ id: 'panel.loan.schedule' })}</button>
                          )}
                          {c.workflow_stage_effective === 'consulta_agendada' && c.schedule_reply_status === 'recusado_leitor' && (
                            <button className="ab-button ab-button--mini" onClick={() => openScheduleModal(c)}>{t({ id: 'panel.consultation.action.proposeAnother' })}</button>
                          )}
                          {c.workflow_stage_effective === 'consulta_agendada' && c.consultation_starts_at && new Date(c.consultation_starts_at) < new Date() && c.schedule_reply_status !== 'recusado_leitor' && (
                            <button className="ab-button ab-button--mini ab-button--danger" onClick={() => {
                              if (window.confirm(t({ id: 'panel.consultation.noShowConfirm' }))) {
                                setConsultaWorkflow(c.consulta_id, c.line_no, 'nao_compareceu', t({ id: 'panel.consultation.noShowReason' }));
                              }
                            }}>{t({ id: 'panel.consultation.action.markNoShow' })}</button>
                          )}
                          {c.workflow_stage_effective === 'consulta_agendada' && c.schedule_reply_status !== 'recusado_leitor' && (
                            <button className="ab-button ab-button--mini" onClick={() => setConsultaWorkflow(c.consulta_id, c.line_no, 'consulta_realizada')}>{t({id:'panel.table.completed'})}</button>
                          )}
                          {!['consulta_realizada','cancelada_leitor','cancelada_biblioteca','expirada'].includes(c.workflow_stage_effective) && (
                            <button className="ab-button ab-button--mini ab-button--danger" onClick={() => openCancelModal(c)}>{t({ id: 'common.cancel' })}</button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              )}
            </div>
          )}

          {/* ═══ EMPRÉSTIMOS POR LIVRO ═══ */}
          {tab === 'emprestimos-livro' && (
            <div>
              <h2 className="ab-painel-h2">{t({ id: 'panel.tab.loans' })}</h2>
              {sortLoans.sortedItems.length === 0 ? (
                <EmptyState message={t({ id: 'panel.loans.empty' })} />
              ) : (
              <div className="ab-painel-table-wrap">
                <table className="ab-painel-table">
                  <thead><tr>
                    <SortHeader sortKey="sub_id" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.subId'})}</SortHeader>
                    <SortHeader sortKey="user_name" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.reader'})}</SortHeader>
                    <SortHeader sortKey="titulo" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.book'})}</SortHeader>
                    <SortHeader sortKey="bib_ref" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.ref'})}</SortHeader>
                    <SortHeader sortKey="rotulo" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.label'})}</SortHeader>
                    <SortHeader sortKey="emprestimo_created_at" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.exit'})}</SortHeader>
                    <SortHeader sortKey="due_at" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.deadline'})}</SortHeader>
                    <SortHeader sortKey="extended_until" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.extended'})}</SortHeader>
                    <SortHeader sortKey="item_status" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.status'})}</SortHeader>
                    <th>{t({id:'panel.table.actions'})}</th>
                  </tr></thead>
                  <tbody>
                    {sortLoans.sortedItems.map((l, i) => (
                      <tr key={i} className={l.item_status === 'aberto' && l.due_at && new Date(l.due_at) < new Date() ? 'overdue' : ''}>
                        <td>{l.sub_id}</td>
                        <td>
                          <UserDisplay
                            name={l.user_name}
                            email={l.user_email}
                            publicId={l.user_public_id}
                            userId={l.user_id}
                          />
                        </td>
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
              )}
            </div>
          )}

          {/* ═══ EMPRÉSTIMOS AGRUPADOS ═══ */}
          {tab === 'emprestimos-lote' && (
            <div>
              <h2 className="ab-painel-h2">{t({ id: 'panel.loan.grouped' })}</h2>
              {(() => {
                const grouped = {};
                // Audit UX 25/05/2026 (P1) : ne grouper que les emprunts ayant
                // au moins un item ouvert. Les emprunts entierement clotures
                // vont dans l'onglet Historique.
                activeLoans.forEach(l => {
                  if (!grouped[l.emprestimo_id]) grouped[l.emprestimo_id] = { ...l, items: [] };
                  grouped[l.emprestimo_id].items.push(l);
                });
                const groups = Object.values(grouped);
                if (groups.length === 0) {
                  return <EmptyState message={t({ id: 'panel.loanGrouped.empty' })} />;
                }
                return groups.map((g, i) => {
                  // Paquet 19 v2 (11/05/2026) : bouton Prorrogar disponible si emprunt ouvert
                  // et non deja prolonge. Meme logique que le tableau Empruntes standard.
                  const canExtend = g.emprestimo_status === 'aberto'
                    && !g.extended_once
                    && !g.extended_until;
                  // Paquet 19 v3 (11/05/2026) : bouton Restituer tout disponible si au
                  // moins un item est encore ouvert dans l'emprunt
                  const hasOpenItem = g.items.some(it => it.item_status === 'aberto');
                  return (
                  <div key={i} className="ab-painel-lote">
                    <div className="ab-painel-lote__head" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8 }}>
                      <div>
                        <strong>#{g.emprestimo_id}</strong> · {g.user_name || g.user_email || g.user_public_id || '—'} · {g.items.length} {t({id:'panel.loan.items'},{count:g.items.length})} · {t({id:'panel.task.detail.deadline'})}: {fmtD(g.due_at)} · {g.emprestimo_status}
                      </div>
                      <div style={{ display: 'flex', gap: 6 }}>
                        {hasOpenItem && (
                          <button className="ab-button ab-button--mini" onClick={async () => {
                            try {
                              const { error } = await supabase.schema('api').rpc('return_loan_total', { p_emprestimo_id: g.emprestimo_id });
                              if (error) throw error;
                              loadData();
                            } catch (e) { notifyError(t({ id: resolveErrorKey(e, 'panel.error.loanReturn') }), e); }
                          }}>
                            {t({id:'panel.loan.returnFull'})}
                          </button>
                        )}
                        {canExtend && (
                          <button className="ab-button ab-button--secondary ab-button--mini" onClick={() => extendLoan(g.emprestimo_id)}>
                            {t({id:'panel.table.extend'})}
                          </button>
                        )}
                      </div>
                    </div>
                    <div className="ab-painel-lote__items">
                      {g.items.map((l, j) => (
                        <div key={j} className="ab-painel-lote__item">
                          {l.sub_id} · <Link to={`/livro/${l.book_id}`}>{l.titulo || l.bib_ref}</Link> · {l.item_status === 'aberto' ? t({id:'panel.loan.inProgress'}) : t({id:'panel.loan.returned'})}
                        </div>
                      ))}
                    </div>
                  </div>
                  );
                });
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

                  {/* Address display — uses parseAddressText to support all legacy formats */}
                  {readerProfile.address && (() => {
                    const a = parseAddressText(readerProfile.address);
                    if (!a.line1 && !a.city && !a.country) {
                      // Pas d'adresse exploitable : fallback texte brut
                      return (
                        <p style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', margin: '6px 0', whiteSpace: 'pre-line' }}>
                          {String(readerProfile.address).replace(/\\n/g, '\n')}
                        </p>
                      );
                    }
                    // Affichage structuré : pays et état affichés dans la locale active
                    const countryDisplay = a.country ? getCountryName(a.country, locale) : '';
                    return (
                      <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', margin: '6px 0' }}>
                        {a.line1 && <span>{t({id:'address.line1'})}: {a.line1}</span>}
                        {a.line2 && <span> · {t({id:'address.line2'})}: {a.line2}</span>}
                        {a.unit && <span> · {t({id:'address.unit'})}: {a.unit}</span>}
                        {a.postal_code && <span> · {t({id:'address.postalCode.generic'})}: {a.postal_code}</span>}
                        {a.district && <span> · {t({id:'address.district'})}: {a.district}</span>}
                        {a.city && <span> · {t({id:'address.city'})}: {a.city}</span>}
                        {a.state_region && <span> · {t({id:'address.state.generic'})}: {a.state_region}</span>}
                        {countryDisplay && <span> · {t({id:'address.country'})}: {countryDisplay}</span>}
                      </div>
                    );
                  })()}

                  {/* ── Edit profile form ── */}
                  <details className="ab-painel-edit-profile" style={{ marginTop: 12 }}>
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
                        <PhoneInput
                          value={readerProfile.phone || ''}
                          onChange={(v) => setReaderProfile(p => ({...p, phone: v || ''}))}
                        />
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

                    {/* ── Address fields ── Uses shared CountrySelect/StateSelect components.
                        State local (editAddrState) pour l'édition, sérialisation au format
                        canonique multi-ligne avec [XX] uniquement au moment de la sauvegarde
                        (cf. addressFormat.js). Évite la boucle parse→format→parse à chaque
                        frappe qui causait des bugs de saisie (espaces mangés par .trim()). */}
                    <h4 style={{ margin: '12px 0 6px', fontSize: '.88rem', fontWeight: 600 }}>{t({id:'address.title'})}</h4>
                    {(() => {
                      const meta = getCountryMetadata(editAddrState.country);
                      const setAddrField = (field, val) => setEditAddrState(prev => {
                        const updated = { ...prev, [field]: val };
                        // Reset state si le pays change (le code ISO 3166-2 deviendrait incohérent)
                        if (field === 'country' && val !== prev.country) updated.state_region = '';
                        return updated;
                      });
                      return (
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                          <label style={{ fontSize: '.82rem', gridColumn: 'span 2' }}>{t({id:'address.country'})}
                            <CountrySelect
                              value={editAddrState.country}
                              onChange={(v) => setAddrField('country', v)}
                            />
                          </label>
                          <label style={{ fontSize: '.82rem', gridColumn: 'span 2' }}>{t({id:'address.line1'})}
                            <input type="text" className="ab-painel-input" value={editAddrState.line1 || ''} onChange={e => setAddrField('line1', e.target.value)} placeholder={t({id:'address.line1.placeholder'})} />
                          </label>
                          <label style={{ fontSize: '.82rem', gridColumn: 'span 2' }}>{t({id:'address.line2'})}
                            <input type="text" className="ab-painel-input" value={editAddrState.line2 || ''} onChange={e => setAddrField('line2', e.target.value)} placeholder={t({id:'address.line2.placeholder'})} />
                          </label>
                          <label style={{ fontSize: '.82rem' }}>{t({id:'address.unit'})}
                            <input type="text" className="ab-painel-input" value={editAddrState.unit || ''} onChange={e => setAddrField('unit', e.target.value)} placeholder={t({id:'address.unit.placeholder'})} />
                          </label>
                          <label style={{ fontSize: '.82rem' }}>{t({id:meta.postalCodeLabel})}
                            <input type="text" className="ab-painel-input" value={editAddrState.postal_code || ''} onChange={e => setAddrField('postal_code', e.target.value)} />
                          </label>
                          <label style={{ fontSize: '.82rem' }}>{t({id:'address.district'})}
                            <input type="text" className="ab-painel-input" value={editAddrState.district || ''} onChange={e => setAddrField('district', e.target.value)} />
                          </label>
                          <label style={{ fontSize: '.82rem' }}>{t({id:'address.city'})}
                            <input type="text" className="ab-painel-input" value={editAddrState.city || ''} onChange={e => setAddrField('city', e.target.value)} />
                          </label>
                          <label style={{ fontSize: '.82rem', gridColumn: 'span 2' }}>{t({id:meta.stateLabel})}
                            <StateSelect
                              countryCode={editAddrState.country}
                              value={editAddrState.state_region || ''}
                              onChange={(v) => setAddrField('state_region', v)}
                            />
                          </label>
                        </div>
                      );
                    })()}

                    <div style={{ marginTop: 10, display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
                      <Button onClick={async () => {
                        setEditProfileMsg('');
                        try {
                          // Sérialisation de editAddrState en texte canonique au moment de la sauvegarde.
                          const updateData = {
                            first_name: readerProfile.first_name, last_name: readerProfile.last_name,
                            phone: readerProfile.phone, gender: readerProfile.gender,
                            email: readerProfile.email,
                            address: formatAddressText(editAddrState, locale),
                          };
                          const { error } = await supabase.from('profiles').update(updateData).eq('id', readerProfile.id);
                          if (error) throw error;
                          // On synchronise readerProfile.address aussi pour que la zone d'affichage
                          // au-dessus se mette à jour sans nécessiter un reload de la page.
                          setReaderProfile(p => ({ ...p, address: formatAddressText(editAddrState, locale) }));
                          setEditProfileMsg(t({id:'panel.reader.profileSaved'}));
                        } catch (err) {
                          setEditProfileMsg(t({id:'common.errorPrefix'}, {message: err.message}));
                        }
                      }}>{t({id:'panel.reader.saveProfile'})}</Button>
                      {editProfileMsg && (
                        <span style={{ fontSize: '.85rem', color: 'var(--brand-text)', fontWeight: 600 }}>
                          {editProfileMsg}
                        </span>
                      )}
                    </div>
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
          {tab === 'historico' && (
            <div>
              <h2 className="ab-painel-h2">{t({ id: 'panel.history.title' })}</h2>
              <p className="ab-painel-hint">{t({ id: 'panel.history.subtitle' })}</p>

              <div className="ab-painel-history-filters">
                {['reservas', 'consultas', 'emprestimos'].map(type => (
                  <button
                    key={type}
                    type="button"
                    className={`ab-painel-history-pill ${(historyTypes || new Set()).has(type) ? 'active' : ''}`}
                    onClick={() => toggleHistoryType(type)}
                    aria-pressed={(historyTypes || new Set()).has(type)}
                  >
                    {t({ id: `panel.history.filter.${type}` })}
                  </button>
                ))}
              </div>

              {(historyTypes || new Set()).size === 0 ? (
                <p className="ab-painel-hint">{t({ id: 'panel.history.noFilter' })}</p>
              ) : (
                <div className="ab-painel-history-list">

                  {/* Section Reservations */}
                  {(historyTypes || new Set()).has('reservas') && (
                    <details className="ab-painel-history-section">
                      <summary className="ab-painel-history-section__summary">
                        <span className="ab-painel-history-section__title">{t({ id: 'panel.history.section.reservations' })}</span>
                        <span className="ab-painel-history-section__count">
                          {t({ id: 'panel.history.itemsCount' }, { count: historyData.reservas.length })}
                        </span>
                      </summary>
                      <div className="ab-painel-history-section__body">
                        {historyLoading.reservas && historyData.reservas.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'common.loading' })}</p>
                        ) : historyData.reservas.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'panel.history.section.empty' })}</p>
                        ) : (
                          <>
                            <div className="ab-painel-table-wrap">
                              <table className="ab-painel-history-table">
                                <thead>
                                  <tr>
                                    <th>{t({ id: 'panel.history.col.title' })}</th>
                                    <th>{t({ id: 'panel.history.col.status' })}</th>
                                    <th>{t({ id: 'panel.history.col.reader' })}</th>
                                    <th>{t({ id: 'panel.history.col.requested' })}</th>
                                    <th>{t({ id: 'panel.history.col.closed' })}</th>
                                    <th>{t({ id: 'panel.history.col.motif' })}</th>
                                  </tr>
                                </thead>
                                <tbody>
                                  {historyData.reservas.map((r, i) => (
                                    <tr key={`hr-${r.reserva_item_id || r.reserva_id + '-' + r.line_no || i}`}>
                                      <td data-label={t({ id: 'panel.history.col.title' })}>
                                        <div className="truncate">{r.titulo || r.bib_ref || '—'}</div>
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.status' })}>
                                        {t({ id: `reservation.stage.${r.item_status}`, defaultMessage: r.item_status })}
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.reader' })}>
                                        {r.user_name || r.user_email || r.user_public_id || '—'}
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.requested' })}>
                                        {r.requested_at ? new Date(r.requested_at).toLocaleDateString() : '—'}
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.closed' })}>
                                        {r.closed_at ? new Date(r.closed_at).toLocaleDateString() : '—'}
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.motif' })} className="cell-motif">
                                        {r.workflow_note || '—'}
                                      </td>
                                    </tr>
                                  ))}
                                </tbody>
                              </table>
                            </div>
                            {historyHasMore.reservas && (
                              <div className="ab-painel-history-loadmore">
                                <button type="button"
                                  onClick={() => loadHistorySection('reservas', true)}
                                  disabled={historyLoading.reservas}>
                                  {historyLoading.reservas ? '...' : t({ id: 'panel.history.loadMore' })}
                                </button>
                              </div>
                            )}
                          </>
                        )}
                      </div>
                    </details>
                  )}

                  {/* Section Consultas */}
                  {(historyTypes || new Set()).has('consultas') && (
                    <details className="ab-painel-history-section">
                      <summary className="ab-painel-history-section__summary">
                        <span className="ab-painel-history-section__title">{t({ id: 'panel.history.section.consultas' })}</span>
                        <span className="ab-painel-history-section__count">
                          {t({ id: 'panel.history.itemsCount' }, { count: historyData.consultas.length })}
                        </span>
                      </summary>
                      <div className="ab-painel-history-section__body">
                        {historyLoading.consultas && historyData.consultas.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'common.loading' })}</p>
                        ) : historyData.consultas.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'panel.history.section.empty' })}</p>
                        ) : (
                          <>
                            <div className="ab-painel-table-wrap">
                              <table className="ab-painel-history-table">
                                <thead>
                                  <tr>
                                    <th>{t({ id: 'panel.history.col.title' })}</th>
                                    <th>{t({ id: 'panel.history.col.status' })}</th>
                                    <th>{t({ id: 'panel.history.col.reader' })}</th>
                                    <th>{t({ id: 'panel.history.col.scheduled' })}</th>
                                    <th>{t({ id: 'panel.history.col.closed' })}</th>
                                    <th>{t({ id: 'panel.history.col.motif' })}</th>
                                  </tr>
                                </thead>
                                <tbody>
                                  {historyData.consultas.map((c, i) => {
                                    const motif = c.schedule_reply_note || c.workflow_note;
                                    return (
                                      <tr key={`hc-${c.consulta_item_id || c.consulta_id + '-' + c.line_no || i}`}>
                                        <td data-label={t({ id: 'panel.history.col.title' })}>
                                          <div className="truncate">{c.titulo || c.bib_ref || '—'}</div>
                                        </td>
                                        <td data-label={t({ id: 'panel.history.col.status' })}>
                                          {t({ id: `consultation.stage.${c.item_status}`, defaultMessage: c.item_status })}
                                        </td>
                                        <td data-label={t({ id: 'panel.history.col.reader' })}>
                                          {c.user_name || c.user_email || c.user_public_id || '—'}
                                        </td>
                                        <td data-label={t({ id: 'panel.history.col.scheduled' })}>
                                          {c.scheduled_for ? new Date(c.scheduled_for).toLocaleDateString() : '—'}
                                        </td>
                                        <td data-label={t({ id: 'panel.history.col.closed' })}>
                                          {c.closed_at ? new Date(c.closed_at).toLocaleDateString() : '—'}
                                        </td>
                                        <td data-label={t({ id: 'panel.history.col.motif' })} className="cell-motif">
                                          {motif || '—'}
                                        </td>
                                      </tr>
                                    );
                                  })}
                                </tbody>
                              </table>
                            </div>
                            {historyHasMore.consultas && (
                              <div className="ab-painel-history-loadmore">
                                <button type="button"
                                  onClick={() => loadHistorySection('consultas', true)}
                                  disabled={historyLoading.consultas}>
                                  {historyLoading.consultas ? '...' : t({ id: 'panel.history.loadMore' })}
                                </button>
                              </div>
                            )}
                          </>
                        )}
                      </div>
                    </details>
                  )}

                  {/* Section Emprestimos */}
                  {(historyTypes || new Set()).has('emprestimos') && (
                    <details className="ab-painel-history-section">
                      <summary className="ab-painel-history-section__summary">
                        <span className="ab-painel-history-section__title">{t({ id: 'panel.history.section.emprestimos' })}</span>
                        <span className="ab-painel-history-section__count">
                          {t({ id: 'panel.history.itemsCount' }, { count: historyData.emprestimos.length })}
                        </span>
                      </summary>
                      <div className="ab-painel-history-section__body">
                        {historyLoading.emprestimos && historyData.emprestimos.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'common.loading' })}</p>
                        ) : historyData.emprestimos.length === 0 ? (
                          <p className="ab-painel-hint">{t({ id: 'panel.history.section.empty' })}</p>
                        ) : (
                          <>
                            <div className="ab-painel-table-wrap">
                              <table className="ab-painel-history-table">
                                <thead>
                                  <tr>
                                    <th>{t({ id: 'panel.history.col.items' })}</th>
                                    <th>{t({ id: 'panel.history.col.type' })}</th>
                                    <th>{t({ id: 'panel.history.col.reader' })}</th>
                                    <th>{t({ id: 'panel.history.col.returned' })}</th>
                                  </tr>
                                </thead>
                                <tbody>
                                  {historyData.emprestimos.map((e, i) => (
                                    <tr key={`he-${e.emprestimo_id || i}`}>
                                      <td data-label={t({ id: 'panel.history.col.items' })}>
                                        <div className="truncate" title={e.titulos || ''}>
                                          {e.titulos || e.bib_refs || '—'}
                                        </div>
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.type' })}>
                                        <span className="ab-painel-history-typepill" data-type={e.loan_type}>
                                          {t({ id: `panel.history.type.${e.loan_type}`, defaultMessage: e.loan_type })}
                                          {e.items_count > 1 && ` (${e.items_count})`}
                                        </span>
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.reader' })}>
                                        {e.user_name || e.user_email || e.user_public_id || '—'}
                                      </td>
                                      <td data-label={t({ id: 'panel.history.col.returned' })}>
                                        {e.returned_at ? new Date(e.returned_at).toLocaleDateString() : '—'}
                                      </td>
                                    </tr>
                                  ))}
                                </tbody>
                              </table>
                            </div>
                            {historyHasMore.emprestimos && (
                              <div className="ab-painel-history-loadmore">
                                <button type="button"
                                  onClick={() => loadHistorySection('emprestimos', true)}
                                  disabled={historyLoading.emprestimos}>
                                  {historyLoading.emprestimos ? '...' : t({ id: 'panel.history.loadMore' })}
                                </button>
                              </div>
                            )}
                          </>
                        )}
                      </div>
                    </details>
                  )}

                </div>
              )}
            </div>
          )}

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

// Audit UX 25/05/2026 (P3) : rangee de pills de filtre par etape de workflow.
// Modele visuel : .ab-painel-history-pill (onglet Historique). Logique
// compteur : membershipFilter (onglet Contribuicoes).
function StageFilterBar({ counts, current, onSelect, labels, allLabel }) {
  const total = [...counts.values()].reduce((a, b) => a + b, 0);
  return (
    <div className="ab-painel-stage-filter">
      <button
        type="button"
        className={`ab-painel-stage-pill ${current === 'all' ? 'active' : ''}`}
        onClick={() => onSelect('all')}
        aria-pressed={current === 'all'}
      >
        {allLabel} ({total})
      </button>
      {[...counts.entries()].map(([stage, n]) => (
        <button
          key={stage}
          type="button"
          className={`ab-painel-stage-pill ${current === stage ? 'active' : ''}`}
          onClick={() => onSelect(stage)}
          aria-pressed={current === stage}
        >
          {(labels && labels[stage]) || stage} ({n})
        </button>
      ))}
    </div>
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
  const { notifyError } = useToast();
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
                    // Chantier #TASKS : router par fn_task_update_status (RPC)
                    // au lieu d'un update() direct, sinon la regeneration des
                    // taches recurrentes ne se declenche jamais a l'achevement.
                    const newStatus = e.target.value;
                    e.target.value = '';
                    try {
                      const { error } = await supabase.rpc('fn_task_update_status', {
                        p_task_id: tk.task_id, p_new_status: newStatus,
                      });
                      if (error) throw error;
                      if (onTaskAction) onTaskAction();
                    } catch (err) {
                      notifyError(t({ id: resolveErrorKey(err, 'panel.error.taskStatus') }), err);
                    }
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
