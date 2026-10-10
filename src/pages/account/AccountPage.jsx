import { useState, useEffect, useCallback, useMemo, useRef, lazy, Suspense } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase, apiQuery, apiRpc, SUPABASE_URL } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { useAccountAvailability } from '@/hooks/useAccountAvailability';
import { useBookAvailability } from '@/hooks/useBookAvailability';
import { useReservationActions } from '@/hooks/useReservationActions';
import ServiceIndisponible from '@/components/ServiceIndisponible';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, Skeleton } from '@/components/ui';
import AppIcon from '@/components/ui/AppIcon';
import CountrySelect from '@/components/forms/CountrySelect';
import StateSelect from '@/components/forms/StateSelect';
import PhoneInput from '@/components/forms/PhoneInput';
import { getCountryMetadata } from '@/components/forms/countryData';
import { parseAddressText, formatAddressText } from '@/lib/addressFormat';
import { localizeError } from '@/lib/localizeError';
import { isPasswordPolicyOk } from '@/lib/passwordPolicy';
import MyLibraryContactCard from '@/components/account/MyLibraryContactCard';
import MinhaSolicitacaoPanel from '@/components/account/MinhaSolicitacaoPanel';
import Modal from '@/components/ui/Modal';
import UserHeroBadge from '@/components/UserHeroBadge';
import LibraryContextBanner from '@/components/LibraryContextBanner';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';
import ReaderTutorialsCard from '@/components/account/ReaderTutorialsCard';
import './AccountPage.css';

// #REFACTOR 08/06 : carte-lecteur extraite en chunk LAZY -> sort qrcode + jspdf
// (~200 ko+) du bundle AccountPage. Chargée seulement au rendu de la section
// (biblios reader_cards_enabled, onglet profil).
const ReaderCardSection = lazy(() => import('@/components/account/ReaderCardSection'));
import TabHistorico from '@/pages/account/TabHistorico';
import TabAvisos from '@/pages/account/TabAvisos';
import TabDesejos from '@/pages/account/TabDesejos';
import TabNotas from '@/pages/account/TabNotas';
import TabCurso from '@/pages/account/TabCurso';
import TabReservar from '@/pages/account/TabReservar';
import ContaDecisions from '@/pages/account/ContaDecisions';
import ContaMotDePasse from '@/pages/account/ContaMotDePasse';
import ContaCotisation from '@/pages/account/ContaCotisation';
import ContaDepot from '@/pages/account/ContaDepot';
import ContaSuppression from '@/pages/account/ContaSuppression';
// MULTI P5a : onglet « mes biblios » (statut par appartenance) en chunk lazy.
const TabBiblios = lazy(() => import('@/pages/account/TabBiblios'));
// Onglet « Événements » (agenda des biblios de la lectrice) en chunk lazy.
const TabEventos = lazy(() => import('@/pages/account/TabEventos'));
import MyPartnershipsConsentSection from '@/components/account/MyPartnershipsConsentSection';
import { formatPublicId } from '@/lib/publicId';

// Onglet dont les données (historiques terminés + prefs de rétention) sont
// chargées en lazy (loadHeavy) à la 1re visite, pas au montage. Cf. loadCore/loadHeavy.
const HEAVY_TABS = ['historico'];

export default function AccountPage() {
  const { user, loading: authLoading } = useAuth();
  const { libraryName, libraryId } = useLibrary();
  const availability = useAccountAvailability();

  const { formatMessage: t, locale } = useIntl();
  useDocumentTitle(t({ id: 'pageTitle.account' }));
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [deleting, setDeleting] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState('');
  const [regimentoUrl, setRegimentoUrl] = useState(null);
  const [accountStatus, setAccountStatus] = useState(null);

  const [activeTab, setActiveTab] = useState(() => searchParams.get('tab') || 'perfil');
  // Deep-link : ?tab=<clé> (ex. clic sur un avis « nouvel événement » -> eventos).
  // Ne se déclenche qu'au changement du paramètre, donc n'écrase pas un clic manuel
  // ultérieur (searchParams inchangé => effet non rejoué). Le garde-fou availability
  // ci-dessous ramène à 'perfil' si l'onglet visé est indisponible.
  useEffect(() => {
    const wanted = searchParams.get('tab');
    if (wanted) setActiveTab(wanted);
  }, [searchParams]);
  // Paquet E.4.6 (20/05/2026) : garde-fou bascule auto si onglet actif devient
  // indisponible (changement de biblio ou transition profil pendant session).
  // Re-direct vers 'perfil' qui est toujours disponible. Place ICI pour que
  // les hooks soient toujours appeles dans le meme ordre.
  useEffect(() => {
    if (availability[activeTab] === false) {
      setActiveTab('perfil');
    }
  }, [activeTab, availability]);
  const [loading, setLoading] = useState(true);
  const [profile, setProfile] = useState(null);
  // Paquet 7 criar-conta — état de l'encadré privacy (suppression du champ déclaratif)
  const [clearingDeclared, setClearingDeclared] = useState(false);
  const [declaredMsg, setDeclaredMsg] = useState('');
  const [declaredMsgIsError, setDeclaredMsgIsError] = useState(false);
  const [reservations, setReservations] = useState([]);
  const [consultations, setConsultations] = useState([]);
  const [consultationsHistory, setConsultationsHistory] = useState([]);
  const [renewStatus, setRenewStatus] = useState({});
  const [loans, setLoans] = useState([]);
  // #CL.10 (MULTI) — map library_id -> biblio (nom/slug), résolue côté client
  // pour tagguer chaque ligne de circulation par sa biblio d'origine.
  const [libMap, setLibMap] = useState({});
  // #tz (01/08) : { library_id -> fuseau IANA } via fn_library_timezones (SECURITY
  // DEFINER : la table library_service_state est staff-only en RLS). Sert a afficher
  // creneaux de consultation + heures de retrait dans le fuseau de CHAQUE biblio
  // (une resa peut viser une autre biblio que celle de session), pas du navigateur.
  const [tzMap, setTzMap] = useState({});
  const [history, setHistory] = useState([]);
  const [loanHistory, setLoanHistory] = useState([]);
  // #CL.8 — rétention historique lectrice (masquage persistant + suppression)
  const [showHiddenHistory, setShowHiddenHistory] = useState(false);
  const [deleteHistoryTarget, setDeleteHistoryTarget] = useState(null);
  // #CL.8 C.5 — suppression de masse par domaine (mot de confirmation)
  const [deleteAllTarget, setDeleteAllTarget] = useState(null);
  const [deleteAllConfirmText, setDeleteAllConfirmText] = useState('');
  const [deleteAllBusy, setDeleteAllBusy] = useState(false);
  const [notifications, setNotifications] = useState([]);
  // #CL.6 (31/05/2026) — Vue active / archives. Filtre frontend sur la même
  // source 'notifications' (single requête, jusqu'à 100 notifs). Le compteur
  // unreadCount est toujours calculé sur les actives, indépendamment du mode.
  const [notifViewMode, setNotifViewMode] = useState('active');
  // #CL.7 (31/05/2026) — Préférences de notification lectrice.
  // Position 1 (souveraineté biblio + réduction lectrice) ; cf. spec-notifications-lecteur.md.
  // Chargées via fn_get_my_notification_preferences au montage, sauvées via fn_set_my_notification_preferences.
  const [notifPrefs, setNotifPrefs] = useState({ disable_reserva_pronta: false, disable_consulta_pronta: false, disable_rede_news: false, disable_library_events: false });
  const [notifPrefsSaving, setNotifPrefsSaving] = useState(false);
  const [notifPrefsMsg, setNotifPrefsMsg] = useState('');
  // Lettre de la fédération — abonnement opt-in (Lot 2, REGISTRE §29 GAZ-5). Double opt-in.
  const [lettreConsent, setLettreConsent] = useState({ consent_lettre: false, pending: false });
  const [lettreSaving, setLettreSaving] = useState(false);
  const [lettreMsg, setLettreMsg] = useState('');
  // #CL.8 — préférences de rétention prospective (par domaine, pour la biblio active)
  const [retentionPrefs, setRetentionPrefs] = useState({ loans: false, reservations: false, consultations: false });
  const [retentionSaving, setRetentionSaving] = useState(false);
  const [retentionMsg, setRetentionMsg] = useState('');
  const [wishlist, setWishlist] = useState([]);
  // #notes-lecture (Lot 2) — mes notes de lecture (toutes œuvres confondues).
  const [myReadingNotes, setMyReadingNotes] = useState([]);
  const [editNoteId, setEditNoteId] = useState(null);
  const [editNoteBody, setEditNoteBody] = useState('');
  const [noteMsg, setNoteMsg] = useState({ text: '', kind: '' });
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');
  // E19 : le profil et l'adresse ont chacun leur bouton Enregistrer (même geste, même écriture) ;
  // le message et le sablier s'affichent sous celui qu'on a cliqué.
  const [saveBloc, setSaveBloc] = useState('perfil');
  const [msgIsError, setMsgIsError] = useState(false);
  // #REFACTOR 08/06 : états card* déplacés dans ReaderCardSection (composant lazy).
  const [serviceState, setServiceState] = useState(null);
  // Cotisation
  const [membership, setMembership] = useState(null); // ligne v_active_memberships
  const [deposits, setDeposits] = useState([]); // dépôts de garantie (api.fn_my_deposits_status)
  const [membershipPayments, setMembershipPayments] = useState([]); // historique propre paiements
  const [membershipRules, setMembershipRules] = useState([]); // règles actives (juste pour info)

  // Lot 26.1a — Changement de mot de passe a la demande de l'usager.
  // States dedies pour ne pas mixer avec le formulaire profil (saving/msg).
  // Indépendant du flow recovery dans LoginPage. Utilise la session active
  // comme preuve d'identite (Supabase Auth standard).
  const [pwdNew, setPwdNew] = useState('');
  const [pwdConfirm, setPwdConfirm] = useState('');
  const [pwdSaving, setPwdSaving] = useState(false);
  const [pwdMsg, setPwdMsg] = useState('');
  const [pwdMsgIsError, setPwdMsgIsError] = useState(false);

  // ── Disponibilité des livres (chantier #CL.1 + #CL.9, 31/05/2026) ───
  // Collecte de tous les book_id distincts présents dans les sources de
  // données chargées par loadData, pour interroger la dispo en un seul
  // appel groupé via le hook useBookAvailability.
  //
  // Sources couvertes :
  //  - loanHistory : emprunts passés (historique #CL.1)
  //  - history     : réservations passées (historique #CL.1, deuxième volet)
  //  - wishlist    : liste d'envies (#CL.9)
  //  - loans       : emprunts en cours (utile pour signaler si un livre
  //                  est de nouveau dispo malgré qu'on l'ait encore)
  //
  // Doctrine α (décision validation par-appartenance du 30/05/2026) : la
  // dispo retournée est celle de la biblio courante de la lectrice, pas
  // celle de la biblio d'origine de l'emprunt/réservation historique. Pour
  // les comptes multi-biblios c'est intentionnel.
  const bookIdsForAvailability = useMemo(() => {
    const ids = new Set();
    for (const item of loanHistory) {
      if (item?.book_id != null) ids.add(Number(item.book_id));
    }
    for (const item of history) {
      if (item?.book_id != null) ids.add(Number(item.book_id));
    }
    for (const item of wishlist) {
      if (item?.book_id != null) ids.add(Number(item.book_id));
    }
    for (const item of loans) {
      if (item?.book_id != null) ids.add(Number(item.book_id));
    }
    return Array.from(ids);
  }, [loanHistory, history, wishlist, loans]);

  const { availabilityMap } = useBookAvailability(bookIdsForAvailability);


  // ── Chargement des données ───────────────────────────────

  // ── Carregamento (perf 12/06/2026, miroir BibliotecaPage) ───────────────
  // Le montage ne charge plus que le « noyau » (loadCore) : profil, circulation
  // active (réservations/consultas/emprunts + statut de renouvellement), service
  // state, statut de compte, notifications + wishlist (leurs compteurs sont dans
  // les libellés d'onglets, toujours visibles), préférences de notif et cotisation
  // — tout ce que l'en-tête (chips, bandeaux) et l'onglet par défaut « perfil »
  // affichent. Les HISTORIQUES (emprunts/réservations/consultas terminés) + les
  // préférences de rétention ne sont tirés (loadHeavy) qu'à la 1re visite de
  // l'onglet « historico » (cf. HEAVY_TABS), idempotent via heavyLoadedRef.
  // Avant : ~25 endpoints au montage, pour tous les onglets à la fois.
  const heavyLoadedRef = useRef(false);

  // Mode 'silent' (chantier #CL — recommandation B, 31/05/2026) : appelé depuis
  // le bouton refresh des onglets via ContaTabHeader. On ne met PAS
  // setLoading(true), pour ne pas faire disparaître l'affichage actuel
  // (skeletons full-page) ; le feedback visuel du clic est porté par l'état
  // 'busy' interne au ContaTabHeader.
  const loadCore = useCallback(async (opts = {}) => {
    if (authLoading || !user) return;
    if (!opts.silent) setLoading(true);
    try {
      const [profileRes, reservRes, consultRes, loansRes, renewStatusRes, svcRes, statusRes] = await Promise.all([
        supabase.from('profiles').select('*').eq('id', user.id).single(),
        apiQuery('my_reservations_active_v2'),
        apiQuery('my_consultas_active_v2'),
        apiQuery('emprestimo_itens_ui'),
        apiQuery('my_loans_renewal_status_by_item_v1'),
        supabase.from('library_service_state').select('*'),
        supabase.rpc('fn_my_account_status'),
      ]);
      setProfile(profileRes.data);
      setReservations(reservRes.data || []);
      setConsultations(consultRes.data || []);
      setLoans(loansRes.data || []);
      setRenewStatus(Object.fromEntries(
        (renewStatusRes.data || []).map(r => [r.sub_id, r])
      ));
      // Service state for the user's library
      if (svcRes.data?.length) setServiceState(svcRes.data[0]);
      // Account status (déplacé du useEffect indépendant 29/05/2026 — bug fix
      // désynchronisation du cache : le useEffect ne se redéclenchait qu'au
      // changement de user?.id, le banner restait figé après ajout d'emprunts)
      if (statusRes?.data) setAccountStatus(statusRes.data);
      // Notifications + wishlist : leurs compteurs sont affichés dans les
      // libellés d'onglets (toujours visibles) -> noyau.
      const { data: notifData } = await supabase.from('user_notifications').select('*').eq('user_id', user.id).order('created_at', { ascending: false }).limit(100);
      setNotifications(notifData || []);
      const { data: wishData } = await supabase.from('user_wishlist').select('*, books:book_id(id, titulo, autor, bib_ref, editora, ano)').eq('user_id', user.id).order('created_at', { ascending: false });
      setWishlist(wishData || []);
      // #notes-lecture (Lot 2) — mes notes de lecture (compteur dans l'onglet).
      const { data: rnData } = await supabase.from('book_reading_notes')
        .select('id, work_id, body, language, status, edited, created_at, works:work_id(id, uniform_title)')
        .eq('author_user_id', user.id).order('created_at', { ascending: false });
      setMyReadingNotes(rnData || []);
      // #CL.7 — préférences de notification (affichées dans l'onglet perfil -> noyau)
      const { data: prefsData } = await supabase.rpc('fn_get_my_notification_preferences');
      if (Array.isArray(prefsData) && prefsData.length > 0) {
        setNotifPrefs({
          disable_reserva_pronta: !!prefsData[0].disable_reserva_pronta,
          disable_consulta_pronta: !!prefsData[0].disable_consulta_pronta,
          disable_rede_news: !!prefsData[0].disable_rede_news,
          disable_library_events: !!prefsData[0].disable_library_events,
        });
      }
      // Lettre de la fédération — état d'abonnement (opt-in, Lot 2)
      const { data: lettreData } = await apiRpc('fn_get_my_lettre_consent');
      if (Array.isArray(lettreData) && lettreData.length > 0) {
        setLettreConsent({
          consent_lettre: !!lettreData[0].consent_lettre,
          pending: !!lettreData[0].pending,
        });
      }
      // Cotisation : statut et historique pour la biblio active (onglet perfil -> noyau)
      if (libraryId) {
        const [{ data: memData }, { data: rulesData }, { data: payData }] = await Promise.all([
          supabase.from('v_active_memberships').select('*').eq('user_id', user.id).eq('library_id', libraryId).maybeSingle(),
          supabase.from('library_membership_rules').select('id, name, amount_min, amount_suggested, currency, period_type, is_required').eq('library_id', libraryId).eq('is_active', true).order('display_order'),
          supabase.from('membership_payments').select('id, amount_paid, currency, paid_at, valid_from, valid_until, payment_method, notes, rule_id').eq('user_id', user.id).eq('library_id', libraryId).order('paid_at', { ascending: false }),
        ]);
        setMembership(memData);
        setMembershipRules(rulesData || []);
        setMembershipPayments(payData || []);
      }
      // Dépôts de garantie de la lectrice (toutes biblios confondues) — DEPOT §8.
      // Section masquée si la lectrice n'en a aucun (cas de la quasi-totalité).
      const { data: depData } = await apiRpc('fn_my_deposits_status');
      setDeposits(depData || []);
    } catch (err) {
      console.error('Account loadCore error:', err);
    } finally {
      if (!opts.silent) setLoading(false);
    }
  }, [user?.id, authLoading, libraryId]);

  // loadHeavy : historiques (emprunts/réservations/consultas terminés) + prefs de
  // rétention. Consommés UNIQUEMENT par l'onglet « historico ». Ne touche pas
  // setLoading (chargement de fond). Marque heavyLoadedRef à la fin.
  const loadHeavy = useCallback(async () => {
    if (authLoading || !user) return;
    try {
      const [consultHistRes, histRes, loanHistRes] = await Promise.all([
        apiQuery('my_consultas_history_v2'),
        apiQuery('my_reservations_history_v2'),
        apiQuery('my_loans_history_v1'),
      ]);
      setConsultationsHistory(consultHistRes.data || []);
      setHistory(histRes.data || []);
      setLoanHistory(loanHistRes.data || []);
      // #CL.8 — préférences de rétention prospective (filtrées sur la biblio active)
      const { data: retData } = await supabase.rpc('fn_get_my_retention_preferences');
      if (Array.isArray(retData) && libraryId) {
        const forLib = retData.filter(r => r.library_id === libraryId);
        setRetentionPrefs({
          loans: !!forLib.find(r => r.domain === 'loans')?.disable_retention,
          reservations: !!forLib.find(r => r.domain === 'reservations')?.disable_retention,
          consultations: !!forLib.find(r => r.domain === 'consultations')?.disable_retention,
        });
      }
      heavyLoadedRef.current = true;
    } catch (err) {
      console.error('Account loadHeavy error:', err);
    }
  }, [user?.id, authLoading, libraryId]);

  // loadData = rechargement complet (mutations, refresh manuel). Garde la
  // sémantique 'silent'. Le lourd n'est rechargé que s'il a déjà été chargé.
  const loadData = useCallback(async (opts = {}) => {
    await loadCore(opts);
    if (heavyLoadedRef.current) await loadHeavy();
  }, [loadCore, loadHeavy]);

  // E6 lot 8 (07/10/2026) : les gestes de réservation et de consultation, et
  // les états qui n'appartiennent qu'à eux, vivent dans useReservationActions
  // (src/hooks). Appelé ici — après loadData, qu'il reçoit, et avant tout retour
  // anticipé — pour que l'ordre des hooks ne change pas d'un rendu à l'autre.
  const {
    reserveRef, setReserveRef, reserveMsg, cancelTarget, setCancelTarget, cancelling, refuseTarget,
    refuseNote, setRefuseNote, refuseError, replying, negotiationForm, setNegotiationForm,
    handleReserve, cancelReservation, handleConfirmPickup, openCounterProposalForm,
    handleSubmitCounterProposal, handleDismissConsultaCancelled, handleCancelConsulta,
    handleConfirmSchedule, openRefuseModal, closeRefuseModal, handleRefuseSchedule
  } = useReservationActions({ user, profile, serviceState, reservations, loans, loadData });

  // E33 (07/10/2026) : sans délai côté client, un premier chargement peut
  // pendre sans fin (panne de la base du 07/10) et le squelette avec lui. Au-delà
  // de douze secondes, on dit que le service est indisponible.
  const [attenteLongue, setAttenteLongue] = useState(false);
  useEffect(() => {
    if (!loading) { setAttenteLongue(false); return undefined; }
    const id = setTimeout(() => setAttenteLongue(true), 12000);
    return () => clearTimeout(id);
  }, [loading]);

  // Montage : noyau seulement (paint rapide de l'onglet par défaut « perfil »).
  useEffect(() => { loadCore(); }, [loadCore]);

  // Changement de biblio active : le cache lourd redevient invalide.
  useEffect(() => { heavyLoadedRef.current = false; }, [libraryId]);

  // Chargement paresseux de l'historique à la 1re visite de l'onglet consommateur
  // (idempotent via heavyLoadedRef).
  useEffect(() => {
    if (HEAVY_TABS.includes(activeTab) && !heavyLoadedRef.current) { loadHeavy(); }
  }, [activeTab, libraryId, loadHeavy]);

  // #CL.10 — résout les biblios (nom/slug) des library_id présents dans la
  // circulation active, pour les tags par ligne. RLS libraries_public_read.
  useEffect(() => {
    const ids = new Set();
    for (const l of loans) if (l.library_id) ids.add(l.library_id);
    for (const r of reservations) if (r.library_id) ids.add(r.library_id);
    if (ids.size === 0) return;
    let cancelled = false;
    (async () => {
      const { data } = await supabase
        .from('libraries')
        .select('id, name, short_name, slug')
        .in('id', Array.from(ids));
      if (!cancelled && Array.isArray(data)) {
        const m = {};
        for (const lib of data) m[lib.id] = lib;
        setLibMap(m);
      }
    })();
    return () => { cancelled = true; };
  }, [loans, reservations]);

  // #tz (01/08) : charge une fois la table library_id -> fuseau (peu de biblios).
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await supabase.rpc('fn_library_timezones');
      if (!cancelled && Array.isArray(data)) {
        const m = {};
        for (const row of data) if (row.library_id) m[row.library_id] = row.consultation_timezone;
        setTzMap(m);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  // ── #CL.8 — masquage / restauration / suppression de l'historique ───────────
  // Le masquage est persistant (fn_hide_history_item), réversible (fn_unhide),
  // distinct de la suppression physique irréversible (fn_delete_history_item).
  // Granularité option A : loans = racine (emprestimo_id), réservations/consultas
  // = ligne (reserva_item_id / consulta_item_id).
  const histSetter = (domain) =>
    domain === 'loans' ? setLoanHistory
    : domain === 'reservations' ? setHistory
    : setConsultationsHistory;
  const histIdField = (domain) =>
    domain === 'loans' ? 'emprestimo_id'
    : domain === 'reservations' ? 'reserva_item_id'
    : 'consulta_item_id';

  const handleHideHistoryItem = async (domain, recordId) => {
    try {
      const { error } = await supabase.rpc('fn_hide_history_item', { p_domain: domain, p_record_id: recordId });
      if (error) throw error;
      const f = histIdField(domain);
      histSetter(domain)(prev => prev.map(it => it[f] === recordId ? { ...it, is_hidden_by_user: true } : it));
    } catch (err) {
      setMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
      setMsgIsError(true);
    }
  };

  const handleUnhideHistoryItem = async (domain, recordId) => {
    try {
      const { error } = await supabase.rpc('fn_unhide_history_item', { p_domain: domain, p_record_id: recordId });
      if (error) throw error;
      const f = histIdField(domain);
      histSetter(domain)(prev => prev.map(it => it[f] === recordId ? { ...it, is_hidden_by_user: false } : it));
    } catch (err) {
      setMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
      setMsgIsError(true);
    }
  };

  const handleDeleteHistoryItem = async () => {
    if (!deleteHistoryTarget) return;
    const { domain, recordId } = deleteHistoryTarget;
    try {
      const { error } = await supabase.rpc('fn_delete_history_item', { p_domain: domain, p_record_id: recordId });
      if (error) throw error;
      const f = histIdField(domain);
      histSetter(domain)(prev => prev.filter(it => it[f] !== recordId));
      setDeleteHistoryTarget(null);
    } catch (err) {
      setMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
      setMsgIsError(true);
      setDeleteHistoryTarget(null);
    }
  };

  // #CL.8 C.4 — sauvegarde des préférences de rétention prospective (3 domaines)
  const handleSaveRetentionPrefs = async () => {
    if (!libraryId) return;
    setRetentionSaving(true);
    setRetentionMsg('');
    try {
      for (const domain of ['loans', 'reservations', 'consultations']) {
        const { error } = await supabase.rpc('fn_set_my_retention_preference', {
          p_library_id: libraryId, p_domain: domain, p_disable: retentionPrefs[domain],
        });
        if (error) throw error;
      }
      setRetentionMsg(t({ id: 'account.retentionPrefs.saved' }));
    } catch (err) {
      setRetentionMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
    } finally {
      setRetentionSaving(false);
    }
  };

  // #CL.8 C.5 — nombre de lignes terminales par domaine pour la biblio active
  const countFor = (domain) => {
    const list = domain === 'loans' ? loanHistory : domain === 'reservations' ? history : consultationsHistory;
    return list.filter(it => it.library_id === libraryId).length;
  };
  // #CL.8 C.5 — purge rétroactive de tout l'historique d'un domaine pour la biblio active
  const handleDeleteAllHistory = async () => {
    if (!deleteAllTarget || !libraryId) return;
    const { domain } = deleteAllTarget;
    setDeleteAllBusy(true);
    try {
      const { error } = await supabase.rpc('fn_delete_all_my_history', { p_library_id: libraryId, p_domain: domain });
      if (error) throw error;
      histSetter(domain)(prev => prev.filter(it => it.library_id !== libraryId));
      setDeleteAllTarget(null);
      setDeleteAllConfirmText('');
      setMsg(t({ id: 'account.history.deleteAll.done' }));
      setMsgIsError(false);
    } catch (err) {
      setMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
      setMsgIsError(true);
    } finally {
      setDeleteAllBusy(false);
    }
  };

  // Style commun des boutons-liens d'action sur une ligne d'historique
  const histLinkBtn = { fontSize: '.7rem', background: 'none', border: 'none', cursor: 'pointer', padding: 0, textDecoration: 'underline', color: 'var(--brand-muted)' };
  // Bloc d'actions réutilisable (masquer/restaurer + supprimer + badge masqué)
  const renderHistActions = (domain, recordId, label, isHidden) => (
    <>
      {isHidden && (
        <span style={{ fontSize: '.68rem', padding: '1px 6px', borderRadius: 4, background: 'rgba(255,255,255,.06)', color: 'var(--brand-muted)' }}>
          {t({ id: 'account.history.hiddenBadge' })}
        </span>
      )}
      <button type="button" style={histLinkBtn}
        onClick={() => isHidden ? handleUnhideHistoryItem(domain, recordId) : handleHideHistoryItem(domain, recordId)}>
        {t({ id: isHidden ? 'account.history.unhide' : 'account.history.hide' })}
      </button>
      <button type="button" style={{ ...histLinkBtn, color: '#f87171' }}
        onClick={() => setDeleteHistoryTarget({ domain, recordId, label })}>
        {t({ id: 'account.history.delete' })}
      </button>
    </>
  );

  // ── Regimento da biblioteca ───────────────────────────────
  useEffect(() => {
    if (!libraryId) return;
    (async () => {
      const { data } = await supabase.from('library_regulation_documents')
        .select('storage_bucket, storage_path_public')
        .eq('library_id', libraryId).eq('is_active', true).eq('publication_status', 'published')
        .order('created_at', { ascending: false }).limit(1).maybeSingle();
      if (data?.storage_path_public) {
        setRegimentoUrl(`${SUPABASE_URL}/storage/v1/object/public/${data.storage_bucket || 'library-regimentos-public'}/${data.storage_path_public}`);
      }
    })();
  }, [libraryId]);

  // ── Sauvegarde du profil ─────────────────────────────────

  async function handleSaveProfile(e) {
    e.preventDefault();
    setSaveBloc(e.currentTarget?.dataset?.bloc === 'adresse' ? 'adresse' : 'perfil');
    setSaving(true);
    setMsg('');
    setMsgIsError(false);
    try {
      const addr = typeof profile.address === 'object' ? (profile.address || {}) : parseAddressText(profile.address);
      const addrText = formatAddressText(addr, locale);

      const { error } = await supabase.from('profiles').update({
        first_name: profile.first_name,
        last_name: profile.last_name,
        phone: profile.phone,
        gender: profile.gender,
        affiliation_org: profile.affiliation_org,
        address: addrText,
      }).eq('id', user.id);
      if (error) throw error;
      setMsg(t({ id: 'account.reserve.dataSaved' }));
      setMsgIsError(false);
    } catch (err) {
      setMsg(t({id:'common.errorPrefix'},{message:localizeError(err, t)}));
      setMsgIsError(true);
    } finally {
      setSaving(false);
    }
  }

  // Paquet 7 criar-conta — suppression du champ déclaratif library_name_mentioned.
  // Appelle la RPC api.fn_clear_my_signup_metadata_field (sans argument,
  // SECURITY DEFINER, scopée à auth.uid()). En cas de succès, retire la clé
  // du state local profile pour que l'encadré disparaisse immédiatement.
  async function handleClearDeclaredField() {
    setClearingDeclared(true);
    setDeclaredMsg('');
    const { error } = await supabase.schema('api').rpc('fn_clear_my_signup_metadata_field');
    setClearingDeclared(false);
    if (error) {
      setDeclaredMsgIsError(true);
      setDeclaredMsg(t({ id: 'account.declared.deleteError' }));
      return;
    }
    setProfile(p => {
      const meta = { ...(p.signup_intent_metadata || {}) };
      delete meta.library_name_mentioned;
      return { ...p, signup_intent_metadata: meta };
    });
    setDeclaredMsgIsError(false);
    setDeclaredMsg(t({ id: 'account.declared.deleted' }));
  }

  // Lot 26.1a — Changement de mot de passe a la demande de l'usager.
  // Indépendant du flow recovery (LoginPage). Utilise supabase.auth.updateUser
  // qui s'appuie sur la session active. Pas besoin de saisir le mot de passe
  // courant : Supabase considere la session authentifiee comme preuve.
  // Validation cote frontend : >= 8 caracteres et confirmation == nouveau.
  async function handleChangePassword(e) {
    e.preventDefault();
    setPwdMsg('');
    setPwdMsgIsError(false);
    if (!isPasswordPolicyOk(pwdNew)) {
      setPwdMsg(t({ id: 'auth.passwordPolicy' }));
      setPwdMsgIsError(true);
      return;
    }
    if (pwdNew !== pwdConfirm) {
      setPwdMsg(t({ id: 'account.changePassword.error.mismatch', defaultMessage: 'A confirmação não corresponde à nova senha.' }));
      setPwdMsgIsError(true);
      return;
    }
    setPwdSaving(true);
    try {
      const { error } = await supabase.auth.updateUser({ password: pwdNew });
      if (error) throw error;
      // Aussi mettre a jour password_changed_at et must_change_password dans
      // profiles pour la coherence avec le flow recovery dans LoginPage.
      await supabase.from('profiles').update({
        password_changed_at: new Date().toISOString(),
        must_change_password: false,
      }).eq('id', user.id);
      setPwdMsg(t({ id: 'account.changePassword.success', defaultMessage: 'Senha atualizada com sucesso.' }));
      setPwdMsgIsError(false);
      setPwdNew('');
      setPwdConfirm('');
    } catch (err) {
      setPwdMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
      setPwdMsgIsError(true);
    } finally {
      setPwdSaving(false);
    }
  }

  function updateProfile(key, value) {
    setProfile(p => ({ ...p, [key]: value }));
  }
  // L'adresse est parsée depuis le texte brut au chargement,
  // puis maintenue comme objet structuré pendant l'édition
  function updateAddress(key, value) {
    setProfile(p => {
      const currentAddr = typeof p?.address === 'object' ? p.address : parseAddressText(p?.address);
      return { ...p, address: { ...currentAddr, [key]: value } };
    });
  }

  // ── Rendu ────────────────────────────────────────────────

  // PATCH 03/05/2026 : skeleton UI au lieu de Spinner centré.
  // L'ancien comportement renvoyait juste <Spinner/> pendant loading,
  // ce qui faisait que le hero (titre, sous-titre, structure) n'était
  // pas affiché. Résultat : LCP médiocre, écran vide perçu.
  // Maintenant on affiche le hero avec son titre/sous-titre traduits
  // (ne dépendent pas des données), des skeletons à la place des pills,
  // et une zone de chargement structurée pour le contenu de l'onglet.
  if (loading && attenteLongue) {
    return (
      <PageShell>
        <Topbar />
        <ServiceIndisponible onRetry={() => window.location.reload()} />
      </PageShell>
    );
  }
  if (loading) {
    return (
      <PageShell>
        <Topbar />
        <Hero title={t({ id: 'account.title' })} subtitle={t({ id: 'account.subtitle' })}>
          <div className="ab-conta-chips">
            <Skeleton w={180} h={28} style={{ borderRadius: 14 }} />
            <Skeleton w={120} h={28} style={{ borderRadius: 14 }} />
            <Skeleton w={140} h={28} style={{ borderRadius: 14 }} />
            <Skeleton w={160} h={28} style={{ borderRadius: 14 }} />
            <Skeleton w={150} h={28} style={{ borderRadius: 14 }} />
            <Skeleton w={150} h={28} style={{ borderRadius: 14 }} />
            <Skeleton w={130} h={28} style={{ borderRadius: 14 }} />
          </div>
        </Hero>
        <div className="ab-conta-tabs" style={{ display: 'flex', gap: 12, padding: '16px 0', justifyContent: 'center', flexWrap: 'wrap' }}>
          <Skeleton w={100} h={36} style={{ borderRadius: 8 }} />
          <Skeleton w={130} h={36} style={{ borderRadius: 8 }} />
          <Skeleton w={120} h={36} style={{ borderRadius: 8 }} />
          <Skeleton w={110} h={36} style={{ borderRadius: 8 }} />
          <Skeleton w={100} h={36} style={{ borderRadius: 8 }} />
          <Skeleton w={140} h={36} style={{ borderRadius: 8 }} />
        </div>
        <div className="ab-conta-card" style={{ padding: 24 }}>
          <Skeleton h={28} w="40%" style={{ marginBottom: 16 }} />
          <Skeleton lines={4} />
        </div>
      </PageShell>
    );
  }

  const addr = parseAddressText(profile?.address);
  const chips = {
    user: profile ? `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || user.email : '—',
    library: libraryName || '—',
    publicId: formatPublicId(profile?.public_id) || '—',
    created: profile?.created_at ? new Date(profile.created_at).toLocaleDateString() : '—',
    reservas: reservations.length,
    consultas: consultations.filter(c => c.status === 'ativa').length,
    emprestimos: loans.filter(l => l.item_status === 'aberto').length,
  };

  // #CL.6 — Compteur des non-lus calculé UNIQUEMENT sur les notifications
  // actives (non archivées). Le label de l'onglet et le bouton "Marquer tout
  // comme lu" reflètent toujours l'état de la pile active, indépendamment
  // du mode courant (active / archived).
  const unreadCount = notifications.filter(n => !n.is_read && !n.archived_at).length;
  // Notifications visibles selon le mode courant.
  const visibleNotifications = notifications.filter(n =>
    notifViewMode === 'active' ? !n.archived_at : !!n.archived_at
  );
  // Les notifications récentes (reserva, consulta, rede, rgpd…) stockent une CLÉ
  // i18n (ex. « notif.reserva.prontaParaRetirada.title ») à traduire au rendu ;
  // les anciennes stockent du texte littéral. On traduit donc tout ce qui a la
  // forme d'une clé (points, sans espace), avec repli sur la valeur brute pour
  // le littéral — sinon la clé brute s'affiche (bug onglet Avisos).
  const tNotifText = (s) => (s && /^[\w.]+$/.test(s) && s.includes('.')) ? t({ id: s, defaultMessage: s }) : s;

  // Paquet E.4.2 (20/05/2026) : filtrage des onglets AccountPage par availability
  // selon profil de biblio (1 lecteur·rice = 1 biblio, cf. doctrine ancrage).
  //
  // Forme des onglets (28/08/2026) : barre de pastilles `.ab-tabbar`
  // (src/styles/tabbar.css). Chaque onglet porte
  //   - `icon`  : repère visuel pour retrouver un onglet sans lire les 9 libellés ;
  //   - `label` : le libellé seul, SANS « (0) » collé — le décompte est sorti…
  //   - `count` : …ici, rendu en pastille et seulement s'il y a quelque chose à
  //               compter (`alert` = ce qui appelle une action, les avis non lus) ;
  //   - `hint`  : plus affiché sous le libellé (il redit le sous-titre du panneau
  //               juste en dessous) mais conservé en infobulle + nom accessible.
  const ALL_TABS = [
    { key: 'perfil', icon: 'user', label: t({ id: 'account.tab.profile' }), hint: t({ id: 'account.tab.profile.hint' }) },
    { key: 'reservar', icon: 'pin', label: t({ id: 'account.tab.reservations' }), hint: t({ id: 'account.tab.reservations.hint' }) },
    { key: 'curso', icon: 'library', label: t({ id: 'account.tab.loans' }), hint: t({ id: 'account.tab.loans.hint' }) },
    { key: 'historico', icon: 'history', label: t({ id: 'account.tab.history' }), hint: t({ id: 'account.tab.history.hint' }) },
    { key: 'avisos', icon: 'bell', label: t({ id: 'account.tab.notifications' }), hint: t({ id: 'account.tab.notifications.hint' }), count: unreadCount, alert: true },
    { key: 'desejos', icon: 'star', label: t({ id: 'account.tab.wishlist' }), hint: t({ id: 'account.tab.wishlist.hint' }), count: wishlist.length },
    { key: 'notas', icon: 'penLine', label: t({ id: 'account.tab.readingNotes' }), hint: t({ id: 'account.tab.readingNotes.hint' }), count: myReadingNotes.length },
    { key: 'biblios', icon: 'landmark', label: t({ id: 'account.tab.libraries' }), hint: t({ id: 'account.tab.libraries.hint' }) },
    { key: 'eventos', icon: 'calendar', label: t({ id: 'account.tab.events' }), hint: t({ id: 'account.tab.events.hint' }) },
  ];
  const TABS = ALL_TABS.filter(t => availability[t.key] !== false);

  // #CL.10 (MULTI) — lecture agrégée : la circulation (fn_my_account_status) est
  // déjà cross-biblio (chaque ligne porte library_id). On taggue chaque ligne par
  // sa biblio d'origine UNIQUEMENT si la circulation s'étale sur >= 2 biblios
  // (sinon bruit pour les lectrices mono-biblio), et on signale un même titre
  // présent dans 2 biblios distinctes (match par titre normalisé).
  const circLibIds = new Set();
  for (const l of loans) if (l.library_id) circLibIds.add(l.library_id);
  for (const r of reservations) if (r.library_id) circLibIds.add(r.library_id);
  const multiLib = circLibIds.size >= 2;
  const crossLibTitles = (() => {
    const byTitle = new Map();
    const add = (titulo, lib) => {
      const k = String(titulo || '').trim().toLowerCase();
      if (!k || !lib) return;
      if (!byTitle.has(k)) byTitle.set(k, new Set());
      byTitle.get(k).add(lib);
    };
    for (const l of loans) add(l.titulo, l.library_id);
    for (const r of reservations) add(r.titulo, r.library_id);
    const s = new Set();
    for (const [k, libs] of byTitle) if (libs.size >= 2) s.add(k);
    return s;
  })();
  const isCrossLibTitle = (titulo) => crossLibTitles.has(String(titulo || '').trim().toLowerCase());
  // #notes-lecture (Lot 2) — édition / suppression de mes notes depuis le compte.
  async function saveReadingNote(id) {
    const body = editNoteBody.trim();
    if (!body) return;
    setSaving(true); setNoteMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.from('book_reading_notes').update({ body }).eq('id', id);
      if (error) throw error;
      setEditNoteId(null); setEditNoteBody('');
      setMyReadingNotes(prev => prev.map(n => n.id === id ? { ...n, body, edited: true } : n));
      setNoteMsg({ text: t({ id: 'readingNotes.msg.updated' }), kind: 'ok' });
    } catch (err) {
      setNoteMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setSaving(false); }
  }
  async function deleteReadingNote(id) {
    if (!window.confirm(t({ id: 'readingNotes.confirm.delete' }))) return;
    setSaving(true); setNoteMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.from('book_reading_notes').delete().eq('id', id);
      if (error) throw error;
      setMyReadingNotes(prev => prev.filter(n => n.id !== id));
      setNoteMsg({ text: t({ id: 'readingNotes.msg.deleted' }), kind: 'ok' });
    } catch (err) {
      setNoteMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setSaving(false); }
  }

  const renderLibTag = (libraryId) => {
    if (!multiLib || !libraryId) return null;
    const lib = libMap[libraryId];
    if (!lib) return null;
    const txt = lib.short_name || lib.name || '';
    const inner = <span style={{ fontSize: '.72rem', color: 'var(--brand-muted)', whiteSpace: 'nowrap', display: 'inline-flex', alignItems: 'center', gap: 4 }}><AppIcon name="map" size={12} />{txt}</span>;
    return lib.slug
      ? <Link to={`/catalogo/${lib.slug}`} title={lib.name || txt} style={{ textDecoration: 'none' }}>{inner}</Link>
      : inner;
  };
  const renderSameTitleSignal = (titulo) => isCrossLibTitle(titulo)
    ? <span className="ab-conta-item__meta" style={{ color: '#a78bfa' }}>⇄ {t({ id: 'account.circ.sameTitleSignal' })}</span>
    : null;

  // #REFACTOR 08/06 : composeCardCanvas + generateReaderCard (et qrcode/jspdf)
  // déplacés dans le composant lazy ReaderCardSection.

  return (
    <PageShell>
      <Topbar />

      <Hero title={t({ id: 'account.title' })} subtitle={t({ id: 'account.subtitle' })}>
        <UserHeroBadge accountStatus={accountStatus?.status} />
        <HeroDocumentationActions
          extraActions={
            <>
              {availability.chip_reservas && (<Pill variant={chips.reservas > 0 ? 'warn' : 'default'}>{t({ id: 'account.chips.reservations' }, { count: chips.reservas })}</Pill>)}
              {availability.chip_consultas && (<Pill variant={chips.consultas > 0 ? 'warn' : 'default'}>{t({ id: 'account.chips.consultations' }, { count: chips.consultas })}</Pill>)}
              {availability.chip_emprestimos && (<Pill variant={chips.emprestimos > 0 ? 'warn' : 'default'}>{t({ id: 'account.chips.loans' }, { count: chips.emprestimos })}</Pill>)}
            </>
          }
        />

        {/* ── Bandeau état du compte ────────────────── */}
        {accountStatus && (() => {
          const s = accountStatus.status;
          const statusLabel = t({ id: `account.status.${s}`, defaultMessage: s });
          const roleLabel = t({ id: `roles.${accountStatus.role}`, defaultMessage: accountStatus.role });
          const bgColor = s === 'active' ? 'rgba(21,128,61,.08)' : s === 'restricted' ? 'rgba(220,38,38,.1)' : s === 'attention' ? 'rgba(251,191,36,.1)' : 'rgba(29,78,216,.08)';
          const borderColor = s === 'active' ? 'rgba(21,128,61,.2)' : s === 'restricted' ? 'rgba(220,38,38,.2)' : s === 'attention' ? 'rgba(251,191,36,.2)' : 'rgba(29,78,216,.15)';
          const textColor = s === 'active' ? '#4ade80' : s === 'restricted' ? '#f87171' : s === 'attention' ? '#fbbf24' : '#60a5fa';
          const icon = s === 'active' ? 'check' : s === 'restricted' ? 'ban' : s === 'attention' ? 'warning' : 'info';
          // Lot 26.1b — Si le bandeau est "incomplete" et que l'usager n'a
          // pas de bibliotheque rattachee (cas typique du parcours
          // signup-sans-biblio interrompu), on ajoute un CTA jaune cliquable
          // vers /solicitar-biblioteca pour qu'il finalise sa demande.
          const incompleteDueToNoLib = s === 'incomplete' && !libraryId;
          return (
            <div style={{ marginTop: 10, padding: '10px 16px', borderRadius: 8, display: 'flex', alignItems: 'center', gap: 12, background: bgColor, border: `1px solid ${borderColor}` }}>
              <AppIcon name={icon} size={22} />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '.9rem', fontWeight: 700, color: textColor }}>
                  {statusLabel} — {roleLabel}
                </div>
                {accountStatus.alerts?.filter(a => a.level !== 'info').map((a, i) => (
                  <div key={i} style={{ fontSize: '.85rem', color: a.level === 'danger' ? '#f87171' : '#fbbf24', marginTop: 2 }}>
                    {a.message_key ? t({ id: a.message_key }, { count: a.count, reason: a.reason, days: a.days }) : a.message}
                    {a.decided_by && (
                      <span style={{ display: 'block', fontWeight: 400, opacity: .85, marginTop: 1 }}>
                        {t({ id: 'account.alert.decidedBy' }, { name: a.decided_by })}
                      </span>
                    )}
                  </div>
                ))}
                {accountStatus.alerts?.filter(a => a.level === 'info').length > 0 && (
                  <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginTop: 2 }}>
                    {accountStatus.alerts.filter(a => a.level === 'info').map(a =>
                      a.message_key ? t({ id: a.message_key }, { count: a.count, days: a.days }) : a.message
                    ).join(' · ')}
                  </div>
                )}
                {incompleteDueToNoLib && (
                  <div style={{ marginTop: 8 }}>
                    <Link
                      to="/solicitar-biblioteca"
                      style={{
                        display: 'inline-block',
                        padding: '6px 12px',
                        borderRadius: 6,
                        background: 'rgba(251,191,36,.15)',
                        border: '1px solid rgba(251,191,36,.4)',
                        color: '#fbbf24',
                        fontSize: '.85rem',
                        fontWeight: 700,
                        textDecoration: 'none',
                      }}
                    >
                      → {t({ id: 'account.alert.incomplete.cta', defaultMessage: 'Solicitar inscrição da biblioteca' })}
                    </Link>
                  </div>
                )}
              </div>
            </div>
          );
        })()}

        {/* #111 Lot 3b — « Ma demande » (auto-masqué si aucune demande d'adhésion) */}
        <MinhaSolicitacaoPanel />

        {serviceState && (() => {
          const mode = serviceState.service_mode || 'funcionamento_normal';
          const modeLabel = mode === 'funcionamento_normal' ? t({id:'account.service.normal'})
            : mode === 'somente_consulta' ? t({id:'account.service.consultOnly'})
            : mode === 'pausada' ? t({id:'account.service.paused'}) : mode;
          const closed = serviceState.allows_new_reservations === false || mode === 'pausada';
          const resOnly = !closed && mode === 'somente_consulta';
          if (mode === 'funcionamento_normal' && serviceState.allows_new_reservations !== false) return null;
          return (
            <div className="ab-conta-notice" style={{ marginTop: 8 }}>
              <strong>{t({id:'account.service.label'}, {mode: modeLabel})}</strong>
              {serviceState.public_message && <span> — {serviceState.public_message}</span>}
              {closed && <div style={{ fontSize: '.86rem', marginTop: 4 }}>{t({id:'account.service.closedMsg'})}</div>}
              {resOnly && <div style={{ fontSize: '.86rem', marginTop: 4 }}>{t({id:'account.service.consultOnlyMsg'})}</div>}
            </div>
          );
        })()}

        {/* ── Bouton règlement de la bibliothèque ────── */}
        {regimentoUrl && (
          <div style={{ marginTop: 12, padding: '12px 16px', borderRadius: 8, background: 'rgba(255,255,255,.04)', border: '1px solid rgba(255,255,255,.1)', display: 'flex', alignItems: 'center', gap: 14, flexWrap: 'wrap' }}>
            <AppIcon name="document" size={24} />
            <div style={{ flex: 1, minWidth: 'min(200px, 100%)' }}>
              <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #ccc)', lineHeight: 1.4 }}>
                {t({ id: 'account.regimento.hint' })}
              </div>
            </div>
            <a href={regimentoUrl} target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'none' }}>
              <Button variant="secondary">{t({ id: 'account.regimento.button' })}</Button>
            </a>
          </div>
        )}
      </Hero>

      {/* MULTI P5b — bandeau de contexte « biblio courante » (≥2 appartenances) */}
      <LibraryContextBanner />

      <ReaderTutorialsCard />

      {/* Tabs */}
      <div className="ab-conta-card">
        <nav className="ab-tabbar" role="tablist">
          {TABS.map(tab => (
            <button key={tab.key} className={`ab-tabbar__tab ${activeTab === tab.key ? 'active' : ''}`}
              onClick={() => setActiveTab(tab.key)} role="tab" aria-selected={activeTab === tab.key}
              /* Le hint n'est plus affiché sous le libellé : il devient l'infobulle
                 et le nom accessible du bouton, pour que ni la souris ni un
                 lecteur d'écran ne perdent l'explication. */
              title={tab.hint} aria-label={`${tab.label} — ${tab.hint}`}>
              <AppIcon className="ab-tabbar__icon" name={tab.icon} size="1em" />
              {tab.label}
              {tab.count > 0 && (
                <span className={`ab-tabbar__badge${tab.alert ? ' ab-tabbar__badge--alert' : ''}`}>{tab.count}</span>
              )}
            </button>
          ))}
        </nav>

        <div className="ab-conta-panel">
          {/* E33 (07/10/2026) : une personne connectée a toujours une ligne de profil ;
              un profil nul après chargement, c'est la base qui n'a pas répondu. */}
          {!profile && <ServiceIndisponible compact onRetry={() => loadData()} />}
          <ErrorBoundary>

          {/* ═══ PERFIL ═══ */}
          {activeTab === 'perfil' && profile && (
            <div>
              <div>
              <h2 className="ab-conta-section-title">{t({ id: 'account.profile.title' })}</h2>
              <p className="ab-conta-hint">{t({ id: 'account.profile.hint' })}</p>

              <form onSubmit={handleSaveProfile} data-bloc="perfil" className="ab-conta-form">
                <div className="ab-conta-grid2">
                  <label>{t({ id: 'account.profile.firstName' })} <input type="text" value={profile.first_name || ''} onChange={e => updateProfile('first_name', e.target.value)} required /></label>
                  <label>{t({ id: 'account.profile.lastName' })} <input type="text" value={profile.last_name || ''} onChange={e => updateProfile('last_name', e.target.value)} required /></label>
                </div>
                <label>{t({ id: 'account.profile.phone' })}
                  <PhoneInput
                    value={profile.phone || ''}
                    onChange={(v) => updateProfile('phone', v || '')}
                  />
                </label>
                <label>{t({ id: 'account.profile.gender' })}
                  <select value={profile.gender || ''} onChange={e => updateProfile('gender', e.target.value)}>
                    <option value="">—</option>
                    <option value="feminino">{t({ id: 'account.profile.gender.fem' })}</option>
                    <option value="masculino">{t({ id: 'account.profile.gender.masc' })}</option>
                    <option value="neutro">{t({ id: 'account.profile.gender.neutral' })}</option>
                    <option value="outro">{t({ id: 'account.profile.gender.other' })}</option>
                  </select>
                </label>
                <label>{t({ id: 'account.profile.org' })} <input type="text" value={profile.affiliation_org || ''} maxLength={200} onChange={e => updateProfile('affiliation_org', e.target.value)} /></label>

                <div className="ab-conta-form-actions">
                  <Button type="submit" loading={saving && saveBloc === 'perfil'} disabled={saving}>{t({ id: 'common.save' })}</Button>
                  {msg && saveBloc === 'perfil' && <span role="status" className={`ab-conta-msg ${msgIsError ? 'ab-conta-msg--error' : ''}`}>{msg}</span>}
                </div>
              </form>
              </div>

              {/* ── E19 — Ce que la page demande de décider, juste sous le profil : export,
                  notifications, lettre, côte à côte (une colonne sous 900 px). La suppression
                  du compte reste seule, tout en bas. ─────────────────────────────────── */}
              <ContaDecisions
                notifPrefs={notifPrefs} setNotifPrefs={setNotifPrefs}
                notifPrefsSaving={notifPrefsSaving} setNotifPrefsSaving={setNotifPrefsSaving}
                notifPrefsMsg={notifPrefsMsg} setNotifPrefsMsg={setNotifPrefsMsg}
                lettreConsent={lettreConsent} setLettreConsent={setLettreConsent}
                lettreSaving={lettreSaving} setLettreSaving={setLettreSaving}
                lettreMsg={lettreMsg} setLettreMsg={setLettreMsg}
              />

              {/* ── Ma bibliothèque (E19, 24/09/2026, décision de Xavier) : la carte vivait dans une colonne
                  à droite du profil ; plus haute que le formulaire, elle poussait les trois décisions sous
                  la ligne de flottaison d'un portable. Elle vient désormais après elles. ── */}
              <div className="ab-conta-bibliotheque">
                <MyLibraryContactCard />
              </div>

              {/* ── Adresse — second formulaire (E19, 21/09/2026) : sortie du formulaire du profil pour
                  que les trois décisions ci-dessus se voient sans défiler. Même enregistrement que le
                  profil (handleSaveProfile écrit les deux) : aucun des deux boutons ne perd de saisie. ── */}
              <form onSubmit={handleSaveProfile} data-bloc="adresse" className="ab-conta-form ab-conta-adresse">
                <h3 style={{ fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'address.title' })}</h3>
                <AddressForm addr={addr} onChange={updateAddress} />

                <div className="ab-conta-form-actions">
                  <Button type="submit" loading={saving && saveBloc === 'adresse'} disabled={saving}>{t({ id: 'common.save' })}</Button>
                  {msg && saveBloc === 'adresse' && <span role="status" className={`ab-conta-msg ${msgIsError ? 'ab-conta-msg--error' : ''}`}>{msg}</span>}
                </div>
              </form>

              {/* ── Paquet 7 criar-conta — Encadré privacy : biblio mentionnée ──── */}
              {profile.signup_intent_metadata?.library_name_mentioned && (
                <div className="ab-conta-notice" style={{ marginTop: 24 }}>
                  <strong>{t({ id: 'account.declared.title' })}</strong>
                  <p style={{ margin: '0 0 8px' }}>
                    {t({ id: 'account.declared.libLabel' })}{' '}
                    <em>{profile.signup_intent_metadata.library_name_mentioned}</em>
                  </p>
                  <p className="ab-conta-hint" style={{ margin: '0 0 10px' }}>
                    {t({ id: 'account.declared.hint' })}
                  </p>
                  {/* Decision C — l'encadré annonçait une lecture par la
                      coordination sans dire qu'elle dépend d'un consentement.
                      On affiche donc l'état réel des deux cases plutôt qu'une
                      promesse générale. Le bouton ci-dessous reste le seul
                      retrait possible : effacer la mention retire tout. */}
                  <p className="ab-conta-hint" style={{ margin: '0 0 10px' }}>
                    {t({ id: profile.signup_intent_metadata?.mention_contact_consent
                      ? 'account.declared.consent.contactYes'
                      : 'account.declared.consent.contactNo' })}
                    {' '}
                    {profile.signup_intent_metadata?.mention_contact_consent && t({
                      id: profile.signup_intent_metadata?.mention_attribution_consent
                        ? 'account.declared.consent.attributionYes'
                        : 'account.declared.consent.attributionNo' })}
                  </p>
                  <Button
                    type="button"
                    variant="danger"
                    loading={clearingDeclared}
                    onClick={handleClearDeclaredField}
                  >
                    {t({ id: 'account.declared.deleteBtn' })}
                  </Button>
                  {declaredMsg && (
                    <span className={`ab-conta-msg ${declaredMsgIsError ? 'ab-conta-msg--error' : ''}`} style={{ marginLeft: 12 }}>
                      {declaredMsg}
                    </span>
                  )}
                </div>
              )}

              {/* ── Lot 26.1a — Changement de mot de passe ────────── */}
              <ContaMotDePasse pwdNew={pwdNew} setPwdNew={setPwdNew} pwdConfirm={pwdConfirm} setPwdConfirm={setPwdConfirm} pwdSaving={pwdSaving} pwdMsg={pwdMsg} pwdMsgIsError={pwdMsgIsError} handleChangePassword={handleChangePassword} />

              {/* ── Cotisation associative ─────────────── */}
              {/* Paquet E.4.5 : ajoute le check availability.cotisacoes (depend de
                  circulation_mode et membership_enabled de la biblio) */}
              <ContaCotisation availability={availability} membership={membership} membershipRules={membershipRules} membershipPayments={membershipPayments} libraryName={libraryName} regimentoUrl={regimentoUrl} />

              {/* ── Dépôt de garantie (DEPOT §8) ───────────
                  Masqué si la lectrice n'a aucun dépôt (défaut). */}
              <ContaDepot deposits={deposits} />

              {/* ── Carte-lecteur (lazy : sort qrcode + jspdf du bundle) ── */}
              {availability.reader_card && (
                <Suspense fallback={null}>
                  <ReaderCardSection />
                </Suspense>
              )}

              {/* ── Suppression du compte — zone destructive isolee tout en bas (deplacee depuis la section RGPD, 04/06/2026) ── */}
              <ContaSuppression deleteConfirm={deleteConfirm} setDeleteConfirm={setDeleteConfirm} deleting={deleting} setDeleting={setDeleting} navigate={navigate} />
            </div>
          )}

          {/* ═══ RESERVAS E CONSULTAS ═══ */}
          {activeTab === 'reservar' && (
            <TabReservar
              reserveRef={reserveRef} setReserveRef={setReserveRef} handleReserve={handleReserve} reserveMsg={reserveMsg}
              reservations={reservations} consultations={consultations} tzMap={tzMap} loadData={loadData}
              renderLibTag={renderLibTag} renderSameTitleSignal={renderSameTitleSignal}
              cancelReservation={cancelReservation} handleConfirmPickup={handleConfirmPickup}
              openCounterProposalForm={openCounterProposalForm} handleSubmitCounterProposal={handleSubmitCounterProposal}
              negotiationForm={negotiationForm} setNegotiationForm={setNegotiationForm}
              handleConfirmSchedule={handleConfirmSchedule} replying={replying} openRefuseModal={openRefuseModal}
              setCancelTarget={setCancelTarget} handleDismissConsultaCancelled={handleDismissConsultaCancelled}
            />
          )}

          {/* ═══ EMPRÉSTIMOS EM CURSO ═══ */}
          {activeTab === 'curso' && (
            <TabCurso
              loans={loans} renewStatus={renewStatus} loadData={loadData}
              renderLibTag={renderLibTag} renderSameTitleSignal={renderSameTitleSignal}
            />
          )}

          {/* ═══ HISTÓRICO ═══ */}
          {activeTab === 'historico' && (
            <TabHistorico
              loanHistory={loanHistory} consultationsHistory={consultationsHistory} history={history}
              showHiddenHistory={showHiddenHistory} setShowHiddenHistory={setShowHiddenHistory}
              renderHistActions={renderHistActions} histLinkBtn={histLinkBtn}
              retentionPrefs={retentionPrefs} setRetentionPrefs={setRetentionPrefs}
              handleSaveRetentionPrefs={handleSaveRetentionPrefs} retentionSaving={retentionSaving} retentionMsg={retentionMsg}
              setDeleteAllTarget={setDeleteAllTarget} setDeleteAllConfirmText={setDeleteAllConfirmText}
              loadData={loadData} availabilityMap={availabilityMap} countFor={countFor}
            />
          )}

          {/* ═══ AVISOS ═══ */}
          {activeTab === 'avisos' && (
            <TabAvisos
              notifViewMode={notifViewMode} setNotifViewMode={setNotifViewMode} unreadCount={unreadCount}
              visibleNotifications={visibleNotifications} tNotifText={tNotifText} loadData={loadData}
            />
          )}

          {/* ═══ LISTA DE DESEJOS ═══ */}
          {activeTab === 'desejos' && (
            <TabDesejos wishlist={wishlist} availabilityMap={availabilityMap} user={user} loadData={loadData} />
          )}

          {/* ═══ MES NOTES DE LECTURE (Lot 2) ═══ */}
          {activeTab === 'notas' && (
            <TabNotas
              myReadingNotes={myReadingNotes} noteMsg={noteMsg} saving={saving}
              editNoteId={editNoteId} setEditNoteId={setEditNoteId} editNoteBody={editNoteBody} setEditNoteBody={setEditNoteBody}
              saveReadingNote={saveReadingNote} deleteReadingNote={deleteReadingNote}
            />
          )}

          {/* ═══ MES BIBLIOS (MULTI P5a) ═══ */}
          {activeTab === 'biblios' && (
            <Suspense fallback={<p className="ab-conta-hint">{t({ id: 'common.loading' })}</p>}>
              <TabBiblios />
              {/* §21 PARTNER P6b : consentement de la lectrice à la transparence */}
              <MyPartnershipsConsentSection />
            </Suspense>
          )}

          {/* ═══ ÉVÉNEMENTS (agenda des biblios de la lectrice) ═══ */}
          {activeTab === 'eventos' && (
            <Suspense fallback={<p className="ab-conta-hint">{t({ id: 'common.loading' })}</p>}>
              <TabEventos />
            </Suspense>
          )}
          </ErrorBoundary>
        </div>
      </div>

      <Footer />
          <Modal
        isOpen={!!deleteAllTarget}
        onClose={() => { if (!deleteAllBusy) { setDeleteAllTarget(null); setDeleteAllConfirmText(''); } }}
        title={t({ id: 'account.history.deleteAll.title' })}
        size="small"
      >
        <div className="ab-modal__body">
          {deleteAllTarget && (
            <p>{t({ id: 'account.history.deleteAll.body' }, { domain: t({ id: `account.history.deleteAll.domain.${deleteAllTarget.domain}` }), library: libraryName })}</p>
          )}
          <p style={{ marginTop: 8, color: '#f87171', fontSize: '.85rem' }}>
            {t({ id: 'account.history.deleteAll.irreversible' })}
          </p>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 4, marginTop: 12 }}>
            <span style={{ fontSize: '.85rem' }}>
              {t({ id: 'account.history.deleteAll.typeToConfirm' }, { word: t({ id: 'account.history.deleteAll.confirmWord' }) })}
            </span>
            <input
              type="text"
              className="ab-input"
              value={deleteAllConfirmText}
              onChange={(e) => setDeleteAllConfirmText(e.target.value)}
              disabled={deleteAllBusy}
              autoFocus
            />
          </label>
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={() => { setDeleteAllTarget(null); setDeleteAllConfirmText(''); }} disabled={deleteAllBusy}>
            {t({ id: 'common.cancel' })}
          </Button>
          <Button
            variant="danger"
            onClick={handleDeleteAllHistory}
            disabled={deleteAllBusy || deleteAllConfirmText.trim().toUpperCase() !== t({ id: 'account.history.deleteAll.confirmWord' }).toUpperCase()}
          >
            {deleteAllBusy ? t({ id: 'common.loading' }) : t({ id: 'account.history.deleteAll.confirmButton' })}
          </Button>
        </div>
      </Modal>
          <Modal
        isOpen={!!deleteHistoryTarget}
        onClose={() => setDeleteHistoryTarget(null)}
        title={t({ id: 'account.history.delete.confirmTitle' })}
        size="small"
      >
        <div className="ab-modal__body">
          <p>{t({ id: 'account.history.delete.confirmBody' })}</p>
          {deleteHistoryTarget?.label && (
            <p style={{ marginTop: 12, fontStyle: 'italic', color: 'var(--brand-muted)' }}>
              {deleteHistoryTarget.label}
            </p>
          )}
          <p style={{ marginTop: 12, color: '#f87171', fontSize: '.85rem' }}>
            {t({ id: 'account.history.delete.irreversible' })}
          </p>
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={() => setDeleteHistoryTarget(null)}>
            {t({ id: 'common.cancel' })}
          </Button>
          <Button variant="danger" onClick={handleDeleteHistoryItem}>
            {t({ id: 'account.history.delete.confirm' })}
          </Button>
        </div>
      </Modal>
          <Modal
        isOpen={!!cancelTarget}
        onClose={() => !cancelling && setCancelTarget(null)}
        title={t({ id: 'account.consultations.cancelConfirmTitle' })}
        size="small"
      >
        <div className="ab-modal__body">
          <p>{t({ id: 'account.consultations.cancelConfirm' })}</p>
          {cancelTarget && (cancelTarget.titulo || cancelTarget.bib_ref) && (
            <p style={{ marginTop: 12, fontStyle: 'italic', color: 'var(--brand-muted)' }}>
              {cancelTarget.titulo || cancelTarget.bib_ref}
            </p>
          )}
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={() => setCancelTarget(null)} disabled={cancelling}>
            {t({ id: 'common.cancel' })}
          </Button>
          <Button onClick={handleCancelConsulta} disabled={cancelling}>
            {cancelling ? t({ id: 'common.loading' }) : t({ id: 'account.consultations.cancelButton' })}
          </Button>
        </div>
      </Modal>
          {/* Paquet 27.A.5 (4.3) : modal de refus du creneau (note obligatoire) */}
      <Modal
        isOpen={!!refuseTarget}
        onClose={closeRefuseModal}
        title={t({ id: 'account.consultations.refuseModal.title' })}
        size="small"
      >
        <div className="ab-modal__body">
          {refuseTarget && (
            <p style={{ marginBottom: 12, fontStyle: 'italic', color: 'var(--brand-muted)' }}>
              {refuseTarget.titulo || refuseTarget.bib_ref}
            </p>
          )}
          <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <span style={{ fontSize: '.85rem' }}>
              {t({ id: 'account.consultations.refuseModal.noteLabel' })}
            </span>
            <textarea
              value={refuseNote}
              onChange={(e) => setRefuseNote(e.target.value)}
              placeholder={t({ id: 'account.consultations.refuseModal.notePlaceholder' })}
              className="ab-input"
              rows={3}
              maxLength={300}
              disabled={replying}
              autoFocus
            />
            <span style={{ fontSize: '.75rem', color: 'var(--brand-muted)' }}>
              ({refuseNote.length}/300)
            </span>
          </label>
          {refuseError && (
            <p style={{ color: 'var(--brand-danger, #c62828)', fontSize: '.9rem', marginTop: 8 }}>
              {refuseError}
            </p>
          )}
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={closeRefuseModal} disabled={replying}>
            {t({ id: 'common.cancel' })}
          </Button>
          <Button onClick={handleRefuseSchedule} disabled={replying}>
            {replying ? t({ id: 'common.loading' }) : t({ id: 'account.consultations.scheduleProposed.refuseButton' })}
          </Button>
        </div>
      </Modal>
    </PageShell>
  );
}

// ═══════════════════════════════════════════════════════════
// Carte réservation avec actions workflow
// ═══════════════════════════════════════════════════════════

// #REFACTOR 08/06 (onglets lourds) : fmtDate + ReservationCard déplacés dans le
// module lazy src/components/account/ReservationCard.jsx (import lazy dans
// TabReservar.jsx depuis le 07/10/2026, E6 lot 5).

// (ReservationCard vit désormais dans src/components/account/ReservationCard.jsx)

// ═══════════════════════════════════════════════════════════
// Formulaire d'adresse international
// ───────────────────────────────────────────────────────────
// Utilise les composants partagés CountrySelect / StateSelect
// du dossier @/components/forms, qui gèrent :
//   - liste complète des pays via i18n-iso-countries (localisée)
//   - listes fermées d'états/provinces pour BR/FR/ES/IT/DE/AR/MX/CH
//   - labels via getCountryMetadata (clés i18n par pays)
//
// Les valeurs internes sont des codes ISO :
//   - addr.country : ISO 3166-1 alpha-2 (ex: 'BR', 'FR')
//   - addr.state_region : ISO 3166-2 si pays a une liste fermée,
//                         sinon texte libre
// ═══════════════════════════════════════════════════════════

function AddressForm({ addr, onChange }) {
  const { formatMessage: t } = useIntl();
  const country = addr.country || '';
  const meta = getCountryMetadata(country);

  return (
    <>
      <label>{t({ id: 'address.country' })}
        <CountrySelect
          value={country}
          onChange={(v) => {
            // Reset de l'état si le pays change (sinon code ISO 3166-2 incohérent)
            onChange('country', v);
            if (v !== country) onChange('state_region', '');
          }}
        />
      </label>

      <label>{t({ id: 'address.line1' })}
        <input
          type="text"
          value={addr.line1 || ''}
          onChange={e => onChange('line1', e.target.value)}
          placeholder={t({ id: 'address.line1.placeholder' })}
        />
      </label>
      <label>{t({ id: 'address.line2' })}
        <input
          type="text"
          value={addr.line2 || ''}
          onChange={e => onChange('line2', e.target.value)}
          placeholder={t({ id: 'address.line2.placeholder' })}
        />
      </label>

      <div className="ab-conta-grid3">
        <label>{t({ id: 'address.unit' })}
          <input
            type="text"
            value={addr.unit || ''}
            onChange={e => onChange('unit', e.target.value)}
            placeholder={t({ id: 'address.unit.placeholder' })}
          />
        </label>
        <label>{t({ id: meta.postalCodeLabel })}
          <input
            type="text"
            value={addr.postal_code || ''}
            onChange={e => onChange('postal_code', e.target.value)}
          />
        </label>
        <label>{t({ id: 'address.district' })}
          <input
            type="text"
            value={addr.district || ''}
            onChange={e => onChange('district', e.target.value)}
          />
        </label>
        <label>{t({ id: 'address.city' })}
          <input
            type="text"
            value={addr.city || ''}
            onChange={e => onChange('city', e.target.value)}
          />
        </label>
      </div>

      <label>{t({ id: meta.stateLabel })}
        <StateSelect
          countryCode={country}
          value={addr.state_region || ''}
          onChange={(v) => onChange('state_region', v)}
        />
      </label>
    </>
  );
}
