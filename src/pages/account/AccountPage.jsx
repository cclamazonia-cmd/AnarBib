import { useState, useEffect, useCallback, useMemo, useRef, lazy, Suspense } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase, apiQuery, apiRpc } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { useAccountAvailability } from '@/hooks/useAccountAvailability';
import { useBookAvailability } from '@/hooks/useBookAvailability';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, Skeleton } from '@/components/ui';
import BookAvailability from '@/components/BookAvailability';
import CountrySelect from '@/components/forms/CountrySelect';
import StateSelect from '@/components/forms/StateSelect';
import PhoneInput from '@/components/forms/PhoneInput';
import { getCountryMetadata } from '@/components/forms/countryData';
import { parseAddressText, formatAddressText } from '@/lib/addressFormat';
import { formatSchedule } from '@/lib/scheduleFormat';
import { localizeError } from '@/lib/localizeError';
import DataExportButton from '@/components/account/DataExportButton';
import MyLibraryContactCard from '@/components/account/MyLibraryContactCard';
import Modal from '@/components/ui/Modal';
import UserHeroBadge from '@/components/UserHeroBadge';
import LibraryContextBanner from '@/components/LibraryContextBanner';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';
import './AccountPage.css';

// #REFACTOR 08/06 : carte-lecteur extraite en chunk LAZY -> sort qrcode + jspdf
// (~200 ko+) du bundle AccountPage. Chargée seulement au rendu de la section
// (biblios reader_cards_enabled, onglet profil).
const ReaderCardSection = lazy(() => import('@/components/account/ReaderCardSection'));
// #REFACTOR 08/06 (onglets lourds) : ReservationCard (~245 lignes) en chunk lazy,
// chargé seulement depuis l'onglet « reservar ».
const ReservationCard = lazy(() => import('@/components/account/ReservationCard'));
// MULTI P5a : onglet « mes biblios » (statut par appartenance) en chunk lazy.
const TabBiblios = lazy(() => import('@/pages/account/TabBiblios'));
import MyPartnershipsConsentSection from '@/components/account/MyPartnershipsConsentSection';

// ── ContaTabHeader (chantier #CL — recommandation B, refresh par onglet, 31/05/2026) ───
// Header standard pour les onglets de la page Conta qui méritent un bouton refresh.
// Pattern inspiré de TabHeader dans src/pages/painel/_shared.jsx (paquet E.2 du 28/05),
// mais avec les classes CSS de Conta (ab-conta-section-title) plutôt que celles de
// Painel (ab-painel-h2). Composant local — pas de promotion en src/components/ui/
// pour l'instant, à arbitrer dans une future session de rangement si le pattern
// se généralise.
//
// Props :
//   - title       (string)   : libellé de l'onglet
//   - onRefresh   (function) : callback de rechargement (typiquement loadData)
//   - actions     (node)     : slot optionnel pour boutons supplémentaires à droite
//                              (ex. "Marquer tout comme lu" sur l'onglet avisos)
function ContaTabHeader({ title, onRefresh, actions }) {
  const { formatMessage: t } = useIntl();
  const [busy, setBusy] = useState(false);
  const handleClick = async () => {
    if (busy) return;
    setBusy(true);
    try { await onRefresh(); }
    finally {
      // Délai mini 400ms pour que le feedback visuel soit perceptible
      // même quand l'appel est ultra-rapide (cf. TabHeader Painel).
      setTimeout(() => setBusy(false), 400);
    }
  };
  const label = t({ id: 'common.refresh' });
  return (
    <div style={{
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: 10,
      gap: 8,
    }}>
      <h2 className="ab-conta-section-title" style={{ margin: 0 }}>{title}</h2>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexShrink: 0 }}>
        {actions}
        {onRefresh && (
          <button
            type="button"
            className="ab-button ab-button--secondary ab-button--mini"
            onClick={handleClick}
            disabled={busy}
            title={label}
            style={busy ? { opacity: 0.5, cursor: 'wait' } : undefined}
          >
            ↻ {busy ? `${label}…` : label}
          </button>
        )}
      </div>
    </div>
  );
}

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
  const [deleting, setDeleting] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState('');
  const [regimentoUrl, setRegimentoUrl] = useState(null);
  const [accountStatus, setAccountStatus] = useState(null);

  const [activeTab, setActiveTab] = useState('perfil');
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
  const [notifPrefs, setNotifPrefs] = useState({ disable_reserva_pronta: false, disable_consulta_pronta: false, disable_rede_news: false });
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
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');
  const [msgIsError, setMsgIsError] = useState(false);
  // #REFACTOR 08/06 : états card* déplacés dans ReaderCardSection (composant lazy).
  const [reserveRef, setReserveRef] = useState('');
  const [reserveMsg, setReserveMsg] = useState('');
  // Paquet 27.A.2 : modal annulation consulta
  const [cancelTarget, setCancelTarget] = useState(null);
  const [cancelling, setCancelling] = useState(false);
  // Paquet 27.A.5 (4.3) : reply au creneau propose par la biblio.
  const [refuseTarget, setRefuseTarget] = useState(null);
  const [refuseNote, setRefuseNote] = useState('');
  const [refuseError, setRefuseError] = useState('');
  const [replying, setReplying] = useState(false);
  const [serviceState, setServiceState] = useState(null);
  // Cotisation
  const [membership, setMembership] = useState(null); // ligne v_active_memberships
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
      // #CL.7 — préférences de notification (affichées dans l'onglet perfil -> noyau)
      const { data: prefsData } = await supabase.rpc('fn_get_my_notification_preferences');
      if (Array.isArray(prefsData) && prefsData.length > 0) {
        setNotifPrefs({
          disable_reserva_pronta: !!prefsData[0].disable_reserva_pronta,
          disable_consulta_pronta: !!prefsData[0].disable_consulta_pronta,
          disable_rede_news: !!prefsData[0].disable_rede_news,
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
        setRegimentoUrl(`https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/${data.storage_bucket || 'library-regimentos-public'}/${data.storage_path_public}`);
      }
    })();
  }, [libraryId]);

  // ── Sauvegarde du profil ─────────────────────────────────

  async function handleSaveProfile(e) {
    e.preventDefault();
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
    if (!pwdNew || pwdNew.length < 8) {
      setPwdMsg(t({ id: 'account.changePassword.error.tooShort', defaultMessage: 'A nova senha deve ter pelo menos 8 caracteres.' }));
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

  // ── Réservation — avec toutes les validations métier ────

  async function handleReserve(mode) {
    const isConsultation = mode === 'consult';
    const refs = reserveRef.split(/[,;\s]+/).map(r => r.trim()).filter(Boolean);

    // 1. Service state de la bibliothèque
    const svcMode = serviceState?.service_mode || 'funcionamento_normal';
    const allowsRes = serviceState?.allows_new_reservations !== false;
    const consultationsClosed = !allowsRes || svcMode === 'pausada';
    const reservationsClosed = consultationsClosed || svcMode === 'somente_consulta';

    if (!isConsultation && reservationsClosed) {
      setReserveMsg(t({ id: 'account.reserve.loansClosed' }));
      return;
    }
    if (isConsultation && consultationsClosed) {
      setReserveMsg(t({ id: 'account.reserve.consultsClosed' }));
      return;
    }

    // 2. Profil restreint
    if (profile?.is_restricted) {
      setReserveMsg(t({ id: 'account.reserve.restricted' }));
      return;
    }

    // 3. Refs vides / max 5
    if (!refs.length) {
      setReserveMsg(isConsultation ? t({ id: 'account.reserve.pasteHintConsult' }) : t({ id: 'account.reserve.pasteHintLoan' }));
      return;
    }
    if (refs.length > 5) {
      setReserveMsg(isConsultation ? t({ id: 'account.reserve.maxConsult' }) : t({ id: 'account.reserve.maxLoan' }));
      return;
    }

    // 4. Doublon de réservation active
    if (!isConsultation) {
      const activeBibRefs = new Set(reservations.map(r => String(r.bib_ref || '').trim().toLowerCase()).filter(Boolean));
      const alreadyReserved = refs.filter(r => activeBibRefs.has(r.trim().toLowerCase()));
      if (alreadyReserved.length) {
        setReserveMsg(alreadyReserved.length === 1
          ? t({id:'account.reserve.alreadyReserved'},{refs:alreadyReserved[0]})
          : t({id:'account.reserve.alreadyReservedPlural'},{refs:alreadyReserved.join(', ')}));
        return;
      }
    }

    // 5. Emprunt actif sur le même livre
    if (!isConsultation) {
      const activeLoanRefs = new Set(loans.filter(l => l.item_status === 'aberto').map(l => String(l.bib_ref || '').trim().toLowerCase()).filter(Boolean));
      const alreadyLoaned = refs.filter(r => activeLoanRefs.has(r.trim().toLowerCase()));
      if (alreadyLoaned.length) {
        setReserveMsg(alreadyLoaned.length === 1
          ? t({id:'account.reserve.alreadyLoaned'},{refs:alreadyLoaned[0]})
          : t({id:'account.reserve.alreadyLoanedPlural'},{refs:alreadyLoaned.join(', ')}));
        return;
      }
    }

    setReserveMsg(t({ id: 'account.reserve.resolving' }));
    try {
      // 6. Résolution bib_ref → holding_id
      const resolveRes = await supabase.rpc('fn_v2_resolve_catalog_refs_for_current_user', { p_refs: refs });
      if (resolveRes.error) throw resolveRes.error;

      const rows = Array.isArray(resolveRes.data) ? resolveRes.data : [];
      if (!rows.length) { setReserveMsg(t({ id: 'account.reserve.notFound' })); return; }

      const holdingIds = rows.filter(r => r.matched === true && Number(r.session_holding_id) > 0).map(r => Number(r.session_holding_id));
      if (!holdingIds.length) { setReserveMsg(rows[0]?.message || t({ id: 'account.reserve.refNotFound' })); return; }

      // 7. Contrôle loanable vs consultation-only.
      //    Relation asymétrique (#consulta-loanable, 24/05/2026) :
      //    - un ouvrage en consultation seule (loanable=false) ne peut PAS
      //      être emprunté -> la branche emprunt refuse ces références ;
      //    - un ouvrage empruntable PEUT être consulté sur place -> la
      //      branche consultation n'applique AUCUN filtre loanable.
      //    Tout ouvrage en circulation est consultable, qu'il soit
      //    empruntable ou non.
      if (!isConsultation) {
        const nonLoanable = rows.filter(r => r.matched && r.session_loanable === false);
        if (nonLoanable.length) {
          setReserveMsg(t({id:'account.reserve.consultationOnlyHint'},{refs:nonLoanable.map(r => r.bib_ref || r.input_ref).join(', ')}));
          return;
        }
      }

      // 8. Créer la réservation ou consultation
      setReserveMsg(isConsultation ? t({ id: 'account.reserve.creatingConsult' }) : t({ id: 'account.reserve.creatingLoan' }));
      // Paquet 27.A.1 (14/05/2026) : migration consulta vers wrapper api.* SECURITY INVOKER.
      // Le call reservation reste sur l'ancienne fn DEFINER (autre chantier).
      let error;
      if (isConsultation) {
        ({ error } = await supabase.schema('api').rpc('create_consulta_local', {
          p_user_id: user.id,
          p_holding_ids: holdingIds,
          p_notes: t({ id: 'account.reserve.noteConsult' }),
        }));
      } else {
        ({ error } = await supabase.rpc('fn_v2_create_reserva_by_holdings', {
          p_user_id: user.id,
          p_holding_ids: holdingIds,
          p_notes: t({ id: 'account.reserve.noteLoan' }),
        }));
      }
      if (error) throw error;

      setReserveMsg(isConsultation
        ? t({id:'account.reserve.consultationRegistered'},{count:refs.length})
        : t({id:'account.reserve.loanRegistered'},{count:refs.length}));
      // PATCH 07/05/2026 : suppression du notifyEvent manuel de création.
      // Le trigger DB trg_notify_reserva_workflow_change émet automatiquement
      // 'reserva_v2_criada' à l'INSERT du workflow_stage 'solicitada'
      // (cf. phase 4 spec workflow réservation).
      setReserveRef('');
      loadData();
    } catch (err) {
      setReserveMsg(t({id:'common.errorPrefix'},{message:localizeError(err, t)}));
    }
  }

  // ── Annulation ───────────────────────────────────────────
  // PATCH 07/05/2026 : migration de fn_v2_cancel_reserva_linhas_as_leitor
  // vers le wrapper api.cancel_my_reservation (phase 2 spec workflow réservation).
  // Comportement : annulation tout-ou-rien sur toutes les lignes (cf. spec section 6).
  // Le trigger DB trg_notify_reserva_workflow_change émet automatiquement l'event
  // de notification — plus besoin du notifyEvent manuel (qui faisait double emploi).

  async function cancelReservation(reservaId) {
    try {
      // PATCH 08/05/2026 paquet 4 : fix bug syntaxe foireuse rpc(name, params,
      // { schema: 'api' }) qui était silencieusement ignorée par supabase-js v2
      // et appelait public.cancel_my_reservation (inexistant) au lieu de api.*.
      // Migration vers le bon pattern supabase.schema('api').rpc(...).
      const { error } = await supabase.schema('api').rpc('cancel_my_reservation', {
        p_reserva_id: reservaId,
      });
      if (error) throw error;
      loadData();
    } catch (err) {
      // L'API peut renvoyer cancel_blocked_by_stage si une ligne est en stage avancé.
      // Le hint Postgres explique ce qui bloque.
      const msg = localizeError(err, t);
      alert(t({id:'account.reserve.cancelError'},{message: msg}));
    }
  }

  // ── Négociation symétrique de créneau (paquet 4) ───────
  // PATCH 08/05/2026 paquet 4 : remplacement de l'ancien handlePickupReply
  // (qui utilisait la syntaxe foireuse rpc(name, params, { schema: 'api' })
  // silencieusement ignorée par supabase-js v2 et qui appelait public.* à la
  // place de api.*) par 3 handlers conformes à la sémantique symétrique :
  //
  //   - handleConfirmPickup        → api.fn_confirm_pickup_slot_as_reader
  //   - handleSubmitCounterProposal → api.fn_propose_pickup_slot_as_reader
  //   - cancelReservation existant → api.cancel_my_reservation
  //
  // Tous routés via supabase.schema('api').rpc(...) — c'est le seul chemin
  // qui marche avec supabase-js v2.
  //
  // Le bouton "Refuser sec" legacy a été retiré (décision Q1 paquet 4) :
  // dans le modèle symétrique, on confirme, on contre-propose ou on annule.
  // Pas de "non sec" sans alternative constructive.

  // State du mini-form de contre-proposition lecteur (panneau accordion).
  // null = aucune carte n'est en mode édition.
  // { reservaId, lineNo, datetime: 'YYYY-MM-DDTHH:MM', note: '' } sinon.
  const [negotiationForm, setNegotiationForm] = useState(null);

  // Handler 1 : le lecteur·rice confirme le créneau proposé par la biblio
  // → api.fn_confirm_pickup_slot_as_reader (paquet 2 bis)
  // Précondition côté DB : pickup_proposed_by = 'biblio'.
  // Effet : transition vers pronta_para_retirada, pickup_proposed_by = NULL.
  async function handleConfirmPickup(reservaId, lineNo) {
    try {
      const { error } = await supabase.schema('api').rpc('fn_confirm_pickup_slot_as_reader', {
        p_reserva_id: reservaId,
        p_line_no: lineNo,
      });
      if (error) throw error;
      // Si le form de contre-proposition était ouvert sur cette ligne, on le ferme
      if (negotiationForm?.reservaId === reservaId && negotiationForm?.lineNo === lineNo) {
        setNegotiationForm(null);
      }
      loadData();
    } catch (err) {
      const msg = localizeError(err, t);
      alert(t({ id: 'common.errorPrefix' }, { message: msg }));
    }
  }

  // Handler 2 : ouvre le form accordion de contre-proposition pour une ligne
  // donnée. Pré-remplit avec le créneau actuel converti en format datetime-local.
  function openCounterProposalForm(reservaId, lineNo, currentSlot) {
    let prefilled = '';
    if (currentSlot) {
      try {
        const d = new Date(currentSlot);
        const pad = (n) => String(n).padStart(2, '0');
        prefilled = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
      } catch { /* fallback string vide */ }
    }
    setNegotiationForm({ reservaId, lineNo, datetime: prefilled, note: '' });
  }

  // Handler 3 : envoie la contre-proposition lecteur (depuis le form ouvert)
  // → api.fn_propose_pickup_slot_as_reader (paquet 2)
  // Vérifications côté DB :
  //   - reservation_allow_reader_counter_proposal = true (sinon code d'erreur)
  //   - negotiation_iteration_count < 3 (sinon code d'erreur)
  //   - pickup_proposed_by = 'biblio' (sinon stage non applicable)
  async function handleSubmitCounterProposal() {
    if (!negotiationForm) return;
    if (!negotiationForm.datetime) {
      alert(t({ id: 'reservation.counterProposeForm.datetimeRequired' }));
      return;
    }
    try {
      // datetime-local renvoie une string en heure LOCALE sans timezone.
      // On la convertit en ISO via new Date(...) qui interprète en local.
      const isoDatetime = new Date(negotiationForm.datetime).toISOString();
      const { error } = await supabase.schema('api').rpc('fn_propose_pickup_slot_as_reader', {
        p_reserva_id: negotiationForm.reservaId,
        p_line_no: negotiationForm.lineNo,
        p_pickup_at: isoDatetime,
        p_note: negotiationForm.note?.trim() || null,
      });
      if (error) throw error;
      setNegotiationForm(null);
      loadData();
    } catch (err) {
      const msg = localizeError(err, t);
      alert(t({ id: 'common.errorPrefix' }, { message: msg }));
    }
  }

  // ── Rendu ────────────────────────────────────────────────

  // PATCH 03/05/2026 : skeleton UI au lieu de Spinner centré.
  // L'ancien comportement renvoyait juste <Spinner/> pendant loading,
  // ce qui faisait que le hero (titre, sous-titre, structure) n'était
  // pas affiché. Résultat : LCP médiocre, écran vide perçu.
  // Maintenant on affiche le hero avec son titre/sous-titre traduits
  // (ne dépendent pas des données), des skeletons à la place des pills,
  // et une zone de chargement structurée pour le contenu de l'onglet.
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

  const handleDismissConsultaCancelled = async (c) => {
    if (!c?.consulta_id) return;
    try {
      const { error } = await supabase.schema('api').rpc('dismiss_consulta_cancelled', {
        p_consulta_id: c.consulta_id,
        p_line_nos: [c.line_no || 1],
        p_note: null
      });
      if (error) {
        console.error('dismiss_consulta_cancelled error:', error);
        return;
      }
      await loadData();
    } catch (err) {
      console.error('dismiss_consulta_cancelled exception:', err);
    }
  };

  // Paquet 27.A.2 : annulation d'une consulta active par le lecteur.
  const handleCancelConsulta = async () => {
    if (!cancelTarget?.consulta_id) return;
    setCancelling(true);
    try {
      const { error } = await supabase.schema('api').rpc('cancel_consulta_as_reader', {
        p_consulta_id: cancelTarget.consulta_id,
        p_line_nos: [cancelTarget.line_no || 1],
      });
      if (error) {
        console.error('cancel_consulta_as_reader error:', error);
        alert(t({ id: 'common.errorPrefix' }, { message: localizeError(error, t) }));
        return;
      }
      setCancelTarget(null);
      await loadData();
    } catch (err) {
      console.error('cancel_consulta_as_reader exception:', err);
      alert(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
    } finally {
      setCancelling(false);
    }
  };

  // Paquet 27.A.5 (4.3) : confirmation directe du creneau propose.
  const handleConfirmSchedule = async (c) => {
    if (!c?.consulta_id || replying) return;
    setReplying(true);
    try {
      const { error } = await supabase.schema('api').rpc('reply_consulta_schedule', {
        p_consulta_id: c.consulta_id,
        p_line_nos: [c.line_no || 1],
        p_reply: 'confirmado_leitor',
        p_note: null,
      });
      if (error) {
        console.error('reply_consulta_schedule (confirm) error:', error);
        alert(t({ id: 'common.errorPrefix' }, { message: localizeError(error, t) }));
        return;
      }
      await loadData();
    } catch (err) {
      console.error('reply_consulta_schedule (confirm) exception:', err);
      alert(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
    } finally {
      setReplying(false);
    }
  };

  // Paquet 27.A.5 (4.3) : ouvrir le modal de refus (note obligatoire).
  const openRefuseModal = (c) => {
    setRefuseTarget(c);
    setRefuseNote('');
    setRefuseError('');
  };

  const closeRefuseModal = () => {
    if (replying) return;
    setRefuseTarget(null);
    setRefuseNote('');
    setRefuseError('');
  };

  const handleRefuseSchedule = async () => {
    if (!refuseTarget?.consulta_id || replying) return;
    setRefuseError('');
    if (!refuseNote || refuseNote.trim().length < 1) {
      setRefuseError(t({ id: 'account.consultations.refuseModal.errorNoteRequired' }));
      return;
    }
    setReplying(true);
    try {
      const { error } = await supabase.schema('api').rpc('reply_consulta_schedule', {
        p_consulta_id: refuseTarget.consulta_id,
        p_line_nos: [refuseTarget.line_no || 1],
        p_reply: 'recusado_leitor',
        p_note: refuseNote.trim(),
      });
      if (error) {
        console.error('reply_consulta_schedule (refuse) error:', error);
        alert(t({ id: 'common.errorPrefix' }, { message: localizeError(error, t) }));
        return;
      }
      setRefuseTarget(null);
      await loadData();
    } catch (err) {
      console.error('reply_consulta_schedule (refuse) exception:', err);
      alert(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
    } finally {
      setReplying(false);
    }
  };



  const addr = parseAddressText(profile?.address);
  const chips = {
    user: profile ? `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || user.email : '—',
    library: libraryName || '—',
    publicId: profile?.public_id || '—',
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

  // Paquet E.4.2 (20/05/2026) : filtrage des onglets AccountPage par availability
  // selon profil de biblio (1 lecteur·rice = 1 biblio, cf. doctrine ancrage).
  const ALL_TABS = [
    { key: 'perfil', label: t({ id: 'account.tab.profile' }), hint: t({ id: 'account.tab.profile.hint' }) },
    { key: 'reservar', label: t({ id: 'account.tab.reservations' }), hint: t({ id: 'account.tab.reservations.hint' }) },
    { key: 'curso', label: t({ id: 'account.tab.loans' }), hint: t({ id: 'account.tab.loans.hint' }) },
    { key: 'historico', label: t({ id: 'account.tab.history' }), hint: t({ id: 'account.tab.history.hint' }) },
    { key: 'avisos', label: `${t({ id: 'account.tab.notifications' })}${unreadCount > 0 ? ` (${unreadCount})` : ''}`, hint: t({ id: 'account.tab.notifications.hint' }) },
    { key: 'desejos', label: `${t({ id: 'account.tab.wishlist' })} (${wishlist.length})`, hint: t({ id: 'account.tab.wishlist.hint' }) },
    { key: 'biblios', label: t({ id: 'account.tab.libraries' }), hint: t({ id: 'account.tab.libraries.hint' }) },
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
  const renderLibTag = (libraryId) => {
    if (!multiLib || !libraryId) return null;
    const lib = libMap[libraryId];
    if (!lib) return null;
    const txt = lib.short_name || lib.name || '';
    const inner = <span style={{ fontSize: '.72rem', color: 'var(--brand-muted)', whiteSpace: 'nowrap' }}>📍 {txt}</span>;
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
          const icon = s === 'active' ? '✓' : s === 'restricted' ? '⛔' : s === 'attention' ? '⚠' : 'ℹ';
          // Lot 26.1b — Si le bandeau est "incomplete" et que l'usager n'a
          // pas de bibliotheque rattachee (cas typique du parcours
          // signup-sans-biblio interrompu), on ajoute un CTA jaune cliquable
          // vers /solicitar-biblioteca pour qu'il finalise sa demande.
          const incompleteDueToNoLib = s === 'incomplete' && !libraryId;
          return (
            <div style={{ marginTop: 10, padding: '10px 16px', borderRadius: 8, display: 'flex', alignItems: 'center', gap: 12, background: bgColor, border: `1px solid ${borderColor}` }}>
              <span style={{ fontSize: '1.3rem' }}>{icon}</span>
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
            <span style={{ fontSize: '1.6rem', lineHeight: 1 }}>📄</span>
            <div style={{ flex: 1, minWidth: 200 }}>
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

      {/* Tabs */}
      <div className="ab-conta-card">
        <nav className="ab-conta-tabs" role="tablist">
          {TABS.map(tab => (
            <button key={tab.key} className={`ab-conta-tab ${activeTab === tab.key ? 'active' : ''}`}
              onClick={() => setActiveTab(tab.key)} role="tab" aria-selected={activeTab === tab.key}>
              {tab.label}
              <span className="ab-conta-tab__hint">{tab.hint}</span>
            </button>
          ))}
        </nav>

        <div className="ab-conta-panel">

          {/* ═══ PERFIL ═══ */}
          {activeTab === 'perfil' && profile && (
            <div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 24, alignItems: 'flex-start' }}>
              <div style={{ flex: '1 1 380px', minWidth: 0 }}>
              <h2 className="ab-conta-section-title">{t({ id: 'account.profile.title' })}</h2>
              <p className="ab-conta-hint">{t({ id: 'account.profile.hint' })}</p>

              <form onSubmit={handleSaveProfile} className="ab-conta-form">
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

                <hr className="ab-conta-hr" />
                <h3 style={{ fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'address.title' })}</h3>
                <AddressForm addr={addr} onChange={updateAddress} />

                <div className="ab-conta-form-actions">
                  <Button type="submit" loading={saving}>{t({ id: 'common.save' })}</Button>
                  {msg && <span className={`ab-conta-msg ${msgIsError ? 'ab-conta-msg--error' : ''}`}>{msg}</span>}
                </div>
              </form>
              </div>
              <aside style={{ flex: '1 1 280px', minWidth: 0, maxWidth: 360 }}>
                <MyLibraryContactCard />
              </aside>
              </div>

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
              <div style={{ marginTop: 32, padding: 20, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
                <h3 style={{ margin: '0 0 4px', fontSize: '1.05rem', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
                  {t({ id: 'account.changePassword.title', defaultMessage: 'Mudar minha senha' })}
                </h3>
                <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 14 }}>
                  {t({ id: 'account.changePassword.hint', defaultMessage: 'Defina uma nova senha de pelo menos 8 caracteres. A confirmação é obrigatória.' })}
                </div>
                <form onSubmit={handleChangePassword} className="ab-conta-form">
                  <div className="ab-conta-grid2">
                    <label>
                      {t({ id: 'account.changePassword.newPassword', defaultMessage: 'Nova senha' })}
                      <input
                        type="password"
                        value={pwdNew}
                        onChange={e => setPwdNew(e.target.value)}
                        autoComplete="new-password"
                        minLength={8}
                        required
                      />
                    </label>
                    <label>
                      {t({ id: 'account.changePassword.confirmPassword', defaultMessage: 'Confirmar nova senha' })}
                      <input
                        type="password"
                        value={pwdConfirm}
                        onChange={e => setPwdConfirm(e.target.value)}
                        autoComplete="new-password"
                        minLength={8}
                        required
                      />
                    </label>
                  </div>
                  <div className="ab-conta-form-actions">
                    <Button type="submit" loading={pwdSaving}>
                      {t({ id: 'account.changePassword.submit', defaultMessage: 'Atualizar senha' })}
                    </Button>
                    {pwdMsg && (
                      <span className={`ab-conta-msg ${pwdMsgIsError ? 'ab-conta-msg--error' : ''}`}>
                        {pwdMsg}
                      </span>
                    )}
                  </div>
                </form>
              </div>

              {/* ── Cotisation associative ─────────────── */}
              {/* Paquet E.4.5 : ajoute le check availability.cotisacoes (depend de
                  circulation_mode et membership_enabled de la biblio) */}
              {availability.cotisacoes && (membership || membershipRules.length > 0) && (() => {
                const status = membership?.dues_status || 'not_applicable';
                const statusVariant = status === 'up_to_date' ? 'ok' : status === 'expired' ? 'danger' : status === 'never_paid' ? 'warn' : status === 'lifetime' ? 'ok' : 'default';
                const statusColor = statusVariant === 'ok' ? '#4ade80' : statusVariant === 'danger' ? '#f87171' : statusVariant === 'warn' ? '#fbbf24' : 'var(--brand-muted)';
                const lastPayment = membershipPayments[0]; // tri DESC
                const fmtD = d => d ? new Date(d).toLocaleDateString() : '—';
                return (
                  <div style={{ marginTop: 32, padding: 20, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
                    <h3 style={{ margin: '0 0 4px', fontSize: '1.05rem', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
                      {t({ id: 'membership.config.title' })}
                    </h3>
                    <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 14 }}>
                      {t({ id: 'membership.account.hint' }, { library: libraryName })}
                    </div>

                    {/* Statut principal */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16, flexWrap: 'wrap' }}>
                      <span style={{ display: 'inline-block', padding: '4px 12px', borderRadius: 999, fontSize: '.85rem', fontWeight: 700, color: statusColor, background: `${statusColor}1a`, border: `1px solid ${statusColor}55` }}>
                        {t({ id: `membership.status.${status === 'up_to_date' ? 'upToDate' : status === 'never_paid' ? 'neverPaid' : status === 'not_applicable' ? 'notApplicable' : status}` })}
                      </span>
                      {membership?.last_valid_until && status !== 'lifetime' && (
                        <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                          {t({ id: 'membership.validUntil' }, { date: fmtD(membership.last_valid_until) })}
                          {membership.days_until_expiry != null && membership.days_until_expiry >= 0 && (
                            <> · {t({ id: 'membership.daysUntilExpiry.plural' }, { days: membership.days_until_expiry })}</>
                          )}
                        </span>
                      )}
                    </div>

                    {/* Dernier paiement */}
                    {lastPayment && (
                      <div style={{ marginBottom: 14 }}>
                        <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', textTransform: 'uppercase', letterSpacing: '.04em', marginBottom: 4 }}>
                          {t({ id: 'membership.account.lastPayment' })}
                        </div>
                        <div style={{ fontSize: '.9rem' }}>
                          {lastPayment.amount_paid > 0
                            ? <strong>{lastPayment.amount_paid} {lastPayment.currency}</strong>
                            : <em>{t({ id: `membership.method.${lastPayment.payment_method}` })}</em>}
                          <span style={{ color: 'var(--brand-muted)', marginLeft: 8 }}>
                            · {t({ id: `membership.method.${lastPayment.payment_method}` })} · {t({ id: 'membership.payment.paidOn' }, { date: fmtD(lastPayment.paid_at) })}
                          </span>
                        </div>
                        {lastPayment.notes && (
                          <div style={{ fontSize: '.8rem', color: 'var(--brand-muted)', marginTop: 3, fontStyle: 'italic' }}>{lastPayment.notes}</div>
                        )}
                      </div>
                    )}

                    {/* Règles applicables (info) */}
                    {membershipRules.length > 0 && (
                      <div style={{ marginBottom: 14 }}>
                        <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', textTransform: 'uppercase', letterSpacing: '.04em', marginBottom: 6 }}>
                          {t({ id: 'membership.account.applicableRules' })}
                        </div>
                        {membershipRules.map(r => (
                          <div key={r.id} style={{ fontSize: '.85rem', padding: '6px 10px', borderRadius: 6, background: 'rgba(0,0,0,.15)', marginBottom: 4 }}>
                            <strong>{r.name}</strong>
                            {r.amount_min > 0 && <span style={{ color: 'var(--brand-muted)' }}> · {t({ id: 'membership.rule.minimumAmount' }, { amount: r.amount_min, currency: r.currency })}</span>}
                            {r.amount_suggested && r.amount_suggested !== r.amount_min && (
                              <span style={{ color: 'var(--brand-muted)' }}> · {t({ id: 'membership.rule.suggestedAmount' }, { amount: r.amount_suggested, currency: r.currency })}</span>
                            )}
                            {r.is_required && <span style={{ marginLeft: 6, fontSize: '.7rem', padding: '1px 6px', borderRadius: 4, background: 'rgba(251,191,36,.15)', color: '#fbbf24' }}>{t({ id: 'membership.rule.required' })}</span>}
                          </div>
                        ))}
                      </div>
                    )}

                    {/* Lien vers le règlement et message d'orientation */}
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, alignItems: 'center', fontSize: '.82rem', color: 'var(--brand-muted)' }}>
                      <span>{t({ id: 'membership.account.howToPay' })}</span>
                      {regimentoUrl && (
                        <a href={regimentoUrl} target="_blank" rel="noopener noreferrer" style={{ color: '#60a5fa', textDecoration: 'underline' }}>
                          {t({ id: 'membership.account.openRegulation' })}
                        </a>
                      )}
                    </div>

                    {/* Historique complet (si plusieurs paiements) */}
                    {membershipPayments.length > 1 && (
                      <details style={{ marginTop: 14 }}>
                        <summary style={{ cursor: 'pointer', fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                          {t({ id: 'membership.account.fullHistory' }, { count: membershipPayments.length })}
                        </summary>
                        <div style={{ marginTop: 8, borderRadius: 6, overflow: 'hidden', border: '1px solid rgba(255,255,255,.06)' }}>
                          {membershipPayments.map((p, i) => (
                            <div key={p.id} style={{ padding: '8px 12px', fontSize: '.82rem', background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent', borderBottom: i < membershipPayments.length - 1 ? '1px solid rgba(255,255,255,.04)' : 'none' }}>
                              <div>
                                {p.amount_paid > 0 ? `${p.amount_paid} ${p.currency}` : t({ id: `membership.method.${p.payment_method}` })}
                                <span style={{ color: 'var(--brand-muted)', marginLeft: 8 }}>
                                  · {t({ id: 'membership.payment.paidOn' }, { date: fmtD(p.paid_at) })}
                                  {p.valid_until && <> · {t({ id: 'membership.validUntil' }, { date: fmtD(p.valid_until) })}</>}
                                </span>
                              </div>
                              {p.notes && <div style={{ fontStyle: 'italic', color: 'var(--brand-muted)', marginTop: 2 }}>{p.notes}</div>}
                            </div>
                          ))}
                        </div>
                      </details>
                    )}
                  </div>
                );
              })()}

              {/* ── Carte-lecteur (lazy : sort qrcode + jspdf du bundle) ── */}
              {availability.reader_card && (
                <Suspense fallback={null}>
                  <ReaderCardSection />
                </Suspense>
              )}

              {/* ── Direitos RGPD/LGPD ─────────────────── */}
              <div style={{ marginTop: 40, padding: 22, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
                <h3 style={{ margin: '0 0 4px', fontSize: '1.05rem', color: 'var(--brand-fg, #f4f4f4)', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
                  {t({ id: 'account.rgpd.title' })}
                </h3>
                <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)', margin: '0 0 18px' }}>
                  {t({ id: 'account.rgpd.subtitle' })}
                </p>

                {/* Export des données */}
                <div style={{ marginBottom: 20, paddingBottom: 18, borderBottom: '1px solid rgba(255,255,255,.06)' }}>
                  <h4 style={{ margin: '0 0 6px', fontSize: '.95rem', fontWeight: 700, color: 'var(--brand-fg, #f4f4f4)', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
                    {t({ id: 'account.export.title' })}
                  </h4>
                  <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)', margin: '0 0 10px' }}>
                    {t({ id: 'account.export.description' })}
                  </p>
                  <DataExportButton />
                </div>
              </div>

              {/* #CL.7 — Préférences de notification (31/05/2026) */}
              {/* Cf. docs/specs/spec-notifications-lecteur.md §5. Position 1 :    */}
              {/* la lectrice peut réduire ce que la biblio envoie, pas l'inverse.*/}
              <div style={{ marginTop: 24, padding: 16, background: 'rgba(96,165,250,.05)', borderRadius: 8, border: '1px solid rgba(96,165,250,.15)' }}>
                <h3 className="ab-conta-section-title" style={{ fontSize: '1rem', marginTop: 0, marginBottom: 8 }}>
                  {t({ id: 'account.notifPrefs.title' })}
                </h3>
                <p className="ab-conta-hint" style={{ marginTop: 0, marginBottom: 12 }}>
                  {t({ id: 'account.notifPrefs.intro' })}
                </p>

                <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 12 }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={notifPrefs.disable_reserva_pronta}
                      onChange={(e) => setNotifPrefs(p => ({ ...p, disable_reserva_pronta: e.target.checked }))}
                    />
                    <span>{t({ id: 'account.notifPrefs.disableReservaPronta' })}</span>
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={notifPrefs.disable_consulta_pronta}
                      onChange={(e) => setNotifPrefs(p => ({ ...p, disable_consulta_pronta: e.target.checked }))}
                    />
                    <span>{t({ id: 'account.notifPrefs.disableConsultaPronta' })}</span>
                  </label>
                  {/* Phase 1 actus réseau : un seul toggle gouverne Lettre/Gazette/cercles */}
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={notifPrefs.disable_rede_news}
                      onChange={(e) => setNotifPrefs(p => ({ ...p, disable_rede_news: e.target.checked }))}
                    />
                    <span>{t({ id: 'account.notifPrefs.disableRedeNews' })}</span>
                  </label>
                </div>

                <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
                  <Button
                    variant="secondary"
                    onClick={async () => {
                      setNotifPrefsSaving(true);
                      setNotifPrefsMsg('');
                      try {
                        const { error } = await supabase.rpc('fn_set_my_notification_preferences', {
                          p_disable_reserva_pronta: notifPrefs.disable_reserva_pronta,
                          p_disable_consulta_pronta: notifPrefs.disable_consulta_pronta,
                          p_disable_rede_news: notifPrefs.disable_rede_news,
                        });
                        if (error) throw error;
                        setNotifPrefsMsg(t({ id: 'account.notifPrefs.saved' }));
                      } catch (err) {
                        setNotifPrefsMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
                      } finally {
                        setNotifPrefsSaving(false);
                      }
                    }}
                    disabled={notifPrefsSaving}
                  >
                    {notifPrefsSaving ? t({ id: 'common.saving' }) : t({ id: 'common.save' })}
                  </Button>
                  {notifPrefsMsg && (
                    <span className="ab-conta-msg" style={{ fontSize: '.85rem' }}>{notifPrefsMsg}</span>
                  )}
                </div>

                <p className="ab-conta-hint" style={{ marginTop: 12, marginBottom: 0, fontSize: '.78rem', fontStyle: 'italic' }}>
                  {t({ id: 'account.notifPrefs.alwaysActive' })}
                </p>
              </div>

              {/* Lettre de la fédération — abonnement opt-in (Lot 2, GAZ-5). Double opt-in :
                  cocher déclenche un e-mail de confirmation ; rien n'est envoyé sans le clic de validation. */}
              <div style={{ marginTop: 24, padding: 16, background: 'rgba(207,31,39,.05)', borderRadius: 8, border: '1px solid rgba(207,31,39,.15)' }}>
                <h3 className="ab-conta-section-title" style={{ fontSize: '1rem', marginTop: 0, marginBottom: 8 }}>
                  {t({ id: 'account.lettre.title' })}
                </h3>
                <p className="ab-conta-hint" style={{ marginTop: 0, marginBottom: 12 }}>
                  {t({ id: 'account.lettre.intro' })}
                </p>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: lettreSaving ? 'wait' : 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={lettreConsent.consent_lettre || lettreConsent.pending}
                    disabled={lettreSaving}
                    onChange={async (e) => {
                      const want = e.target.checked;
                      setLettreSaving(true);
                      setLettreMsg('');
                      try {
                        if (want) {
                          const { data, error } = await apiRpc('fn_lettre_request_optin');
                          if (error) throw error;
                          if (data === 'already_subscribed') {
                            setLettreConsent({ consent_lettre: true, pending: false });
                          } else {
                            setLettreConsent((c) => ({ ...c, pending: true }));
                            setLettreMsg(t({ id: 'account.lettre.confirmationSent' }));
                          }
                        } else {
                          const { error } = await apiRpc('fn_lettre_cancel');
                          if (error) throw error;
                          setLettreConsent({ consent_lettre: false, pending: false });
                          setLettreMsg(t({ id: 'account.lettre.unsubscribed' }));
                        }
                      } catch (err) {
                        setLettreMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
                      } finally {
                        setLettreSaving(false);
                      }
                    }}
                  />
                  <span>{t({ id: 'account.lettre.toggle' })}</span>
                </label>
                {lettreConsent.pending && (
                  <p className="ab-conta-hint" style={{ marginTop: 10, marginBottom: 0, fontSize: '.82rem' }}>
                    {t({ id: 'account.lettre.pending' })}
                  </p>
                )}
                {lettreConsent.consent_lettre && !lettreConsent.pending && (
                  <p className="ab-conta-hint" style={{ marginTop: 10, marginBottom: 0, fontSize: '.82rem' }}>
                    {t({ id: 'account.lettre.subscribed' })}
                  </p>
                )}
                {lettreMsg && (
                  <p className="ab-conta-msg" style={{ marginTop: 10, marginBottom: 0, fontSize: '.85rem' }}>{lettreMsg}</p>
                )}
                <p className="ab-conta-hint" style={{ marginTop: 12, marginBottom: 0, fontSize: '.78rem', fontStyle: 'italic' }}>
                  {t({ id: 'account.lettre.note' })}
                </p>
              </div>

              {/* ── Suppression du compte — zone destructive isolee tout en bas (deplacee depuis la section RGPD, 04/06/2026) ── */}
              <div style={{ marginTop: 40, padding: 22, borderRadius: 10, background: 'rgba(220,38,38,.04)', border: '1px solid rgba(220,38,38,.15)' }}>
                  <h4 style={{ margin: '0 0 6px', fontSize: '.95rem', fontWeight: 700, color: '#f87171', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'account.deleteAccount.title' })}</h4>
                  <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)', margin: '0 0 12px' }}>{t({ id: 'account.deleteAccount.warning' })}</p>
                  <div style={{ marginBottom: 10 }}>
                    <label style={{ fontSize: '.85rem', fontWeight: 600, display: 'block', marginBottom: 4, color: 'var(--brand-muted)' }}>
                      {t({ id: 'account.deleteAccount.confirmLabel' })}
                    </label>
                    <input type="text" value={deleteConfirm} onChange={e => setDeleteConfirm(e.target.value)}
                      placeholder={t({ id: 'account.deleteAccount.confirmText' })} style={{ width: 200, padding: '8px 12px', borderRadius: 8, border: '1px solid rgba(220,38,38,.3)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.9rem' }} />
                  </div>
                  <button
                    disabled={deleteConfirm !== t({ id: 'account.deleteAccount.confirmText' }) || deleting}
                    onClick={async () => {
                      if (deleteConfirm !== t({ id: 'account.deleteAccount.confirmText' })) return;
                      if (!confirm(t({ id: 'account.deleteAccount.confirmDialog' }))) return;
                      setDeleting(true);
                      try {
                        const { data, error } = await supabase.rpc('fn_delete_my_account');
                        if (error) throw error;
                        if (data?.ok === false) { alert(data.error || t({ id: 'account.reserve.deleteError' })); setDeleting(false); return; }
                        await supabase.auth.signOut();
                        sessionStorage.removeItem('anarbib.libraryContext');
                        navigate('/');
                      } catch (err) { alert(t({id:'common.errorPrefix'},{message:localizeError(err, t)})); setDeleting(false); }
                    }}
                    style={{
                      padding: '10px 20px', borderRadius: 8, fontSize: '.9rem', fontWeight: 700, cursor: deleteConfirm === t({ id: 'account.deleteAccount.confirmText' }) ? 'pointer' : 'not-allowed',
                      background: deleteConfirm === t({ id: 'account.deleteAccount.confirmText' }) ? 'rgba(220,38,38,.8)' : 'rgba(220,38,38,.2)',
                      color: deleteConfirm === t({ id: 'account.deleteAccount.confirmText' }) ? '#fff' : 'rgba(255,255,255,.4)',
                      border: '1px solid rgba(220,38,38,.4)', transition: 'all .15s',
                    }}>
                    {deleting ? t({ id: 'account.deleteAccount.deleting' }) : t({ id: 'account.deleteAccount.button' })}
                  </button>
              </div>
            </div>
          )}

          {/* ═══ RESERVAS E CONSULTAS ═══ */}
          {activeTab === 'reservar' && (
            <div>
              <ContaTabHeader title={t({ id: 'account.reserve.title' })} onRefresh={() => loadData({ silent: true })} />
              <p className="ab-conta-hint">
                No catálogo, copie a referência e cole aqui. Use <strong>{t({ id: 'account.reserve.loan' })}</strong> para materiais emprestáveis
                ou <strong>{t({ id: 'account.reserve.consult' })}</strong> para periódicos e materiais consultáveis.
              </p>

              <div className="ab-conta-reserve-form">
                <input type="text" value={reserveRef} onChange={e => setReserveRef(e.target.value)}
                  placeholder={t({ id: 'account.reserve.placeholder' })} className="ab-input" />
                <Button variant="secondary" onClick={() => handleReserve('reserve')}>{t({ id: 'account.reserve.loan' })}</Button>
                <Button variant="secondary" onClick={() => handleReserve('consult')}>{t({ id: 'account.reserve.consult' })}</Button>
              </div>
              {reserveMsg && <p className="ab-conta-msg">{reserveMsg}</p>}

              <h3 className="ab-conta-subsection">{t({ id: 'account.reservations.active' })}</h3>
              {reservations.length === 0 ? (
                <p className="ab-conta-empty">{t({ id: 'account.reservations.empty' })}</p>
              ) : (
                <Suspense fallback={null}>
                <div className="ab-conta-items">
                  {reservations.map((r, i) => (
                    <ReservationCard
                      key={i}
                      r={r}
                      libTag={renderLibTag(r.library_id)}
                      sameTitleSignal={renderSameTitleSignal(r.titulo)}
                      onCancel={cancelReservation}
                      onConfirmPickup={handleConfirmPickup}
                      onOpenCounterProposalForm={openCounterProposalForm}
                      onCloseCounterProposalForm={() => setNegotiationForm(null)}
                      onSubmitCounterProposal={handleSubmitCounterProposal}
                      negotiationForm={negotiationForm}
                      setNegotiationForm={setNegotiationForm}
                      loadData={loadData}
                    />
                  ))}
                </div>
                </Suspense>
              )}

              {/* Paquet 27.A.5 (4.3) : creneau propose par la biblio, en attente de reponse */}
              {consultations.filter(c => c.workflow_stage_effective === 'consulta_agendada' && !c.schedule_reply_status).length > 0 && (
                <>
                  <h3 className="ab-conta-subsection" style={{ marginTop: 0 }}>
                    {t({ id: 'account.consultations.scheduleProposed.title' })}
                  </h3>
                  <p className="ab-conta-hint">{t({ id: 'account.consultations.scheduleProposed.hint' })}</p>
                  <div className="ab-conta-items">
                    {consultations.filter(c => c.workflow_stage_effective === 'consulta_agendada' && !c.schedule_reply_status).map((c, i) => (
                      <div key={`prop-${i}`} className="ab-conta-item" style={{ borderLeft: '3px solid #2563eb' }}>
                        <div className="ab-conta-item__main">
                          <Link to={`/livro/${c.book_id}`} className="ab-conta-item__title">{c.titulo || c.bib_ref || ''}</Link>
                          <span className="ab-conta-item__meta">ref: {c.bib_ref || ''}</span>
                          <p style={{ margin: '8px 0 0', fontWeight: 600 }}>
                            {t({ id: 'account.consultations.scheduleProposed.dateLabel' })} : {formatSchedule(c)}
                          </p>
                          {c.workflow_note && (
                            <p style={{ margin: '4px 0 0', fontStyle: 'italic', color: 'var(--brand-muted)' }}>
                              {t({ id: 'account.consultations.scheduleProposed.noteLabel' })} : {c.workflow_note}
                            </p>
                          )}
                        </div>
                        <div className="ab-conta-item__actions" style={{ display: 'flex', gap: 8 }}>
                          <Button onClick={() => handleConfirmSchedule(c)} disabled={replying}>
                            {t({ id: 'account.consultations.scheduleProposed.confirmButton' })}
                          </Button>
                          <Button variant="secondary" onClick={() => openRefuseModal(c)} disabled={replying}>
                            {t({ id: 'account.consultations.scheduleProposed.refuseButton' })}
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                </>
              )}

              <h3 className="ab-conta-subsection">{t({ id: 'account.consultations.active' })}</h3>
              {consultations.filter(c => c.status === 'ativa').length === 0 ? (
                <p className="ab-conta-empty">{t({ id: 'account.consultations.empty' })}</p>
              ) : (
                <div className="ab-conta-items">
                  {consultations.filter(c => c.status === 'ativa').map((c, i) => (
                    <div key={`act-${i}`} className="ab-conta-item">
                      <div className="ab-conta-item__main">
                        <Link to={`/livro/${c.book_id}`} className="ab-conta-item__title">{c.titulo || c.bib_ref || '—'}</Link>
                        <span className="ab-conta-item__meta">ref: {c.bib_ref || '—'} · {c.workflow_stage || c.status || '—'}</span>
                        {c.workflow_stage_effective === 'consulta_agendada' && c.schedule_reply_status === 'confirmado_leitor' && (
                          <p style={{ margin: '4px 0 0', color: '#15803d', fontWeight: 600 }}>
                            ✓ {t({ id: 'account.consultations.scheduleConfirmed.badge' }, { date: formatSchedule(c) })}
                          </p>
                        )}
                      </div>
                      <div className="ab-conta-item__actions">
                        <Button variant="secondary" onClick={() => setCancelTarget(c)}>
                          {t({ id: 'account.consultations.cancelButton' })}
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {consultations.filter(c => c.status === 'cancelada_biblioteca').length > 0 && (
                <>
                  <h3 className="ab-conta-subsection" style={{ marginTop: 24 }}>
                    {t({ id: 'account.consultations.cancelledByLibrary' })}
                  </h3>
                  <p className="ab-conta-hint">{t({ id: 'account.consultations.cancelledByLibraryHint' })}</p>
                  <div className="ab-conta-items">
                    {consultations.filter(c => c.status === 'cancelada_biblioteca').map((c, i) => (
                      <div key={`cnx-${i}`} className="ab-conta-item" style={{ borderLeft: '3px solid #f59e0b' }}>
                        <div className="ab-conta-item__main">
                          <Link to={`/livro/${c.book_id}`} className="ab-conta-item__title">{c.titulo || c.bib_ref || '—'}</Link>
                          <span className="ab-conta-item__meta">
                            ref: {c.bib_ref || '—'}
                            {c.cancelled_at && <> · {new Date(c.cancelled_at).toLocaleDateString()}</>}
                          </span>
                        </div>
                        <div className="ab-conta-item__actions">
                          <Button variant="secondary" onClick={() => handleDismissConsultaCancelled(c)}>
                            {t({ id: 'account.consultations.dismissButton' })}
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                </>
              )}
            </div>
          )}

          {/* ═══ EMPRÉSTIMOS EM CURSO ═══ */}
          {activeTab === 'curso' && (
            <div>
              <ContaTabHeader title={t({ id: 'account.loans.title' })} onRefresh={() => loadData({ silent: true })} />
              <p className="ab-conta-hint">{t({ id: 'account.loans.hint' })}</p>
              {(() => {
                // Refonte conta curso (29/05/2026, parité painel) : items ouverts
                // GROUPÉS par emprunt — en-tête humain (date · n livres · échéance la
                // plus proche) + « Renovar tudo », puis lignes par item avec « Renovar ».
                // Les emprunts clôturés vivent dans l'onglet Histórico (groupés via
                // my_loans_history_v1) ; on ne duplique plus « Devolvidos recentemente ».
                const openItems = loans.filter(l => l.item_status === 'aberto');
                if (openItems.length === 0) {
                  return <p className="ab-conta-empty">{t({ id: 'account.loans.empty' })}</p>;
                }
                const order = [];
                const groups = {};
                openItems.forEach(l => {
                  if (!groups[l.emprestimo_id]) { groups[l.emprestimo_id] = []; order.push(l.emprestimo_id); }
                  groups[l.emprestimo_id].push(l);
                });
                const today = new Date(); today.setHours(0, 0, 0, 0);
                return (
                  <div className="ab-conta-loan-groups" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                    {order.map(empId => {
                      const items = groups[empId];
                      const checkout = items[0].emprestimo_created_at;
                      // Échéance la plus proche parmi les items ouverts (peut diverger
                      // après renouvellement par item).
                      const dueDates = items.map(it => it.extended_until || it.due_at).filter(Boolean).sort();
                      const soonest = dueDates[0] ? new Date(dueDates[0] + 'T00:00:00') : null;
                      const soonestOverdue = soonest && soonest < today;
                      const groupCanRenewAny = items.some(it => renewStatus[it.sub_id]?.can_renew);
                      const showRenewAll = items.length >= 2;
                      return (
                        <div key={empId} className="ab-conta-loan-group" style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden' }}>
                          <div className="ab-conta-loan-group__head" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8, padding: '10px 14px', background: 'rgba(255,255,255,.03)' }}>
                            <div style={{ fontWeight: 600, fontSize: '.92rem' }}>
                              {checkout && <>{t({ id: 'account.loans.group.checkedOutOn' }, { date: new Date(checkout).toLocaleDateString() })}</>}
                              {' · '}{t({ id: 'account.loans.group.bookCount' }, { count: items.length })}
                              {soonest && <>{' · '}<span style={{ color: soonestOverdue ? '#ef4444' : 'inherit' }}>{t({ id: 'account.loans.group.dueBy' }, { date: soonest.toLocaleDateString() })}</span></>}
                              {(() => { const tag = renderLibTag(items[0].library_id); return tag ? <>{' · '}{tag}</> : null; })()}
                            </div>
                            {showRenewAll && (
                              <Button
                                variant="mini"
                                disabled={!groupCanRenewAny}
                                title={!groupCanRenewAny ? t({ id: 'account.renew.tooltipBlocked' }, { reason: t({ id: 'account.renew.not_renewable' }) }) : undefined}
                                onClick={async () => {
                                  const { data, error } = await supabase.schema('api').rpc('renew_my_loan', { p_emprestimo_id: empId });
                                  if (error) { alert(t({ id: 'common.errorPrefix' }, { message: localizeError(error, t) })); return; }
                                  if (data?.ok === false) { alert(t({ id: `account.renew.${data.reason}` })); return; }
                                  alert(t({ id: 'account.renew.renewed' }, { date: new Date(data.new_due_date).toLocaleDateString() }));
                                  loadData();
                                }}
                              >
                                {t({ id: 'account.loans.renewAll' })}
                              </Button>
                            )}
                          </div>
                          <div className="ab-conta-loan-group__items">
                            {items.map((l, i) => {
                              const effectiveDue = l.extended_until || l.due_at;
                              const due = effectiveDue ? new Date(effectiveDue + 'T00:00:00') : null;
                              const daysLeft = due ? Math.ceil((due - today) / 86400000) : null;
                              const isOverdue = daysLeft !== null && daysLeft < 0;
                              const isSoon = daysLeft !== null && daysLeft >= 0 && daysLeft <= 3;
                              const renewInfo = renewStatus[l.sub_id] || null;
                              const renewalsUsed = renewInfo ? (renewInfo.renewals_used || 0) : 0;
                              const wasExtended = renewalsUsed > 0;
                              const canRenew = renewInfo ? renewInfo.can_renew : (!wasExtended && !isOverdue);
                              const blockingReason = renewInfo ? renewInfo.blocking_reason : null;
                              const tooltipMsg = blockingReason
                                ? t({ id: 'account.renew.tooltipBlocked' }, { reason: t({ id: `account.renew.${blockingReason}` }) })
                                : null;
                              return (
                                <div key={i} className={`ab-conta-item ${isOverdue ? 'ab-conta-item--overdue' : ''}`}
                                  style={{ borderLeft: `3px solid ${isOverdue ? '#ef4444' : isSoon ? '#f59e0b' : 'transparent'}` }}>
                                  <div className="ab-conta-item__main" style={{ flex: 1 }}>
                                    <Link to={`/livro/${l.book_id}`} className="ab-conta-item__title">{l.titulo || l.bib_ref || '—'}</Link>
                                    <span className="ab-conta-item__meta">{l.autor || '—'}</span>
                                    <span className="ab-conta-item__meta">
                                      ref: {l.bib_ref || '—'}
                                      {due && <> · {t({ id: 'account.loans.deadline' })}: <strong style={{ color: isOverdue ? '#ef4444' : isSoon ? '#f59e0b' : 'inherit' }}>{due.toLocaleDateString()}</strong></>}
                                      {daysLeft !== null && (isOverdue
                                        ? <> · <strong style={{ color: '#ef4444' }}>{t({ id: 'account.loans.daysOverdue' }, { days: Math.abs(daysLeft) })}</strong></>
                                        : <> · {t({ id: 'account.loans.daysLeft' }, { days: daysLeft })}</>)}
                                    </span>
                                    {wasExtended && <span className="ab-conta-item__meta" style={{ color: '#60a5fa' }}>{t({ id: 'account.loans.renewedUntil' }, { date: new Date(l.extended_until + 'T00:00:00').toLocaleDateString() })}</span>}
                                    {renderSameTitleSignal(l.titulo)}
                                  </div>
                                  <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                                    {!(isOverdue || (wasExtended && !canRenew)) && (
                                      <Button
                                        variant="mini"
                                        disabled={!canRenew}
                                        title={tooltipMsg || undefined}
                                        onClick={async () => {
                                          const { data, error } = await supabase.schema('api').rpc('renew_my_loan_item', { p_emprestimo_id: l.emprestimo_id, p_line_no: l.line_no });
                                          if (error) { alert(t({ id: 'common.errorPrefix' }, { message: localizeError(error, t) })); return; }
                                          if (data?.ok === false) { alert(t({ id: `account.renew.${data.reason}` })); return; }
                                          alert(t({ id: 'account.renew.renewed' }, { date: new Date(data.new_due_date).toLocaleDateString() }));
                                          loadData();
                                        }}
                                      >
                                        {t({ id: 'account.loans.renew' })}
                                      </Button>
                                    )}
                                    {wasExtended && <span style={{ fontSize: '.72rem', color: '#60a5fa', fontWeight: 600 }}>{t({ id: 'account.loans.renewed' })}</span>}
                                    {isOverdue && <span style={{ fontSize: '.72rem', color: '#ef4444', fontWeight: 600 }}>{t({ id: 'account.loans.overdue' })}</span>}
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                );
              })()}
            </div>
          )}

          {/* ═══ HISTÓRICO ═══ */}
          {activeTab === 'historico' && (() => {
            const hiddenCount =
              loanHistory.filter(x => x.is_hidden_by_user).length +
              consultationsHistory.filter(x => x.is_hidden_by_user).length +
              history.filter(x => x.is_hidden_by_user).length;
            const visLoans = loanHistory.filter(x => showHiddenHistory || !x.is_hidden_by_user);
            const visConsult = consultationsHistory.filter(x => showHiddenHistory || !x.is_hidden_by_user);
            const visResas = history.filter(x => showHiddenHistory || !x.is_hidden_by_user);
            return (
            <div>
              <ContaTabHeader title={t({ id: 'account.history.title' })} onRefresh={() => loadData({ silent: true })} />
              <p className="ab-conta-hint">{t({ id: 'account.history.hint' })}</p>

              {/* #CL.8 D.6 — bandeau pédagogique permanent (politique de conservation) */}
              <div style={{ marginTop: 8, marginBottom: 8, padding: 12, background: 'rgba(96,165,250,.05)', borderRadius: 8, border: '1px solid rgba(96,165,250,.15)', fontSize: '.82rem', color: 'var(--brand-muted)' }}>
                <strong style={{ color: 'inherit' }}>{t({ id: 'account.retention.banner.title' })}</strong>{' '}
                {t({ id: 'account.retention.banner.body' })}
              </div>

              {hiddenCount > 0 && (
                <button type="button" style={{ ...histLinkBtn, marginBottom: 8 }}
                  onClick={() => setShowHiddenHistory(v => !v)}>
                  {showHiddenHistory
                    ? t({ id: 'account.history.hideHiddenToggle' })
                    : t({ id: 'account.history.showHiddenToggle' }, { count: hiddenCount })}
                </button>
              )}

              {/* Paquet 10 (10/05/2026) : section historique des emprunts */}
              <div style={{ marginTop: 16 }}>
                <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem' }}>{t({ id: 'account.history.loans.title' })}</h3>
                {visLoans.length === 0 ? (
                  <p className="ab-conta-empty">{t({ id: 'account.history.loans.empty' })}</p>
                ) : (
                  <div className="ab-conta-items">
                    {visLoans.map((lh) => (
                      <div key={`loan-${lh.emprestimo_id}`} className="ab-conta-item ab-conta-item--history" style={{ display: 'flex', gap: 10, opacity: lh.is_hidden_by_user ? 0.55 : 1 }}>
                        <div className="ab-conta-item__main" style={{ flex: 1 }}>
                          {lh.book_id ? (
                            <Link to={`/livro/${lh.book_id}`} className="ab-conta-item__title">{lh.titulos || '\u2014'}</Link>
                          ) : (
                            <span className="ab-conta-item__title">{lh.titulos || '\u2014'}</span>
                          )}
                          {lh.autores && <span className="ab-conta-item__meta">{lh.autores}</span>}
                          <span className="ab-conta-item__meta">
                            {lh.items_count > 1 && <>{t({ id: 'account.history.loans.itemsCount' }, { count: lh.items_count })} \u00b7 </>}
                            ref: {lh.bib_refs || '\u2014'} \u00b7 {lh.library_name || '\u2014'}
                            {lh.emprestimo_created_at && <> \u00b7 {t({id:'account.loans.checkout'})}: {new Date(lh.emprestimo_created_at).toLocaleDateString()}</>}
                            {lh.returned_at && <> \u00b7 {t({id:'account.loans.returnedOn'})}: {new Date(lh.returned_at).toLocaleDateString()}</>}
                            {lh.renewals_used > 0 && <> \u00b7 {t({ id: 'account.history.loans.renewalsUsed' }, { count: lh.renewals_used })}</>}
                          </span>
                          {lh.book_id && availabilityMap.get(Number(lh.book_id)) && (
                            <span className="ab-conta-item__meta" style={{ marginTop: 4 }}>
                              <BookAvailability availability={availabilityMap.get(Number(lh.book_id))} variant="inline" />
                            </span>
                          )}
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                          <span style={{ fontSize: '.72rem', padding: '2px 8px', borderRadius: 4, fontWeight: 600, background: 'rgba(74,222,128,.12)', color: '#4ade80' }}>
                            {t({ id: 'account.history.loans.completed' })}
                          </span>
                          {renderHistActions('loans', lh.emprestimo_id, lh.titulos || '\u2014', lh.is_hidden_by_user)}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
              {/* Paquet 26 L4 (14/05/2026) : section historique des consultas */}
              <div style={{ marginTop: 24 }}>
                <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem' }}>{t({ id: 'account.history.consultations.title' })}</h3>
                {visConsult.length === 0 ? (
                  <p className="ab-conta-empty">{t({ id: 'account.history.consultations.empty' })}</p>
                ) : (
                  <div className="ab-conta-items">
                    {visConsult.map((c, i) => {
                      const stageKey = c.workflow_stage || c.status || '';
                      const stageLabel = stageKey ? t({ id: `consultation.stage.${stageKey.replace('-','_')}`, defaultMessage: stageKey }) : '\u2014';
                      const isFinal = ['consultada','cancelada_leitor','cancelada_biblioteca','expirada'].includes(stageKey);
                      return (
                        <div key={`ch-${c.consulta_item_id ?? i}`} className="ab-conta-item ab-conta-item--history" style={{ display: 'flex', gap: 10, opacity: c.is_hidden_by_user ? 0.55 : 1 }}>
                          <div className="ab-conta-item__main" style={{ flex: 1 }}>
                            <Link to={`/livro/${c.book_id}`} className="ab-conta-item__title">{c.titulo || c.bib_ref || '\u2014'}</Link>
                            <span className="ab-conta-item__meta">{c.autor || '\u2014'}{c.editora && ` \u00b7 ${c.editora}`}{c.ano && ` (${c.ano})`}</span>
                            <span className="ab-conta-item__meta">
                              ref: {c.bib_ref || '\u2014'} \u00b7 {c.library_name || '\u2014'}
                              {c.requested_at && <> \u00b7 {t({id:'account.history.consultations.requestedOn'})}: {new Date(c.requested_at).toLocaleDateString()}</>}
                              {c.consulted_at && <> \u00b7 {t({id:'account.history.consultations.consultedOn'})}: {new Date(c.consulted_at).toLocaleDateString()}</>}
                              {c.cancelled_at && <> \u00b7 {t({id:'account.history.cancelledOn'})}: {new Date(c.cancelled_at).toLocaleDateString()}</>}
                            </span>
                          </div>
                          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                            <span style={{ fontSize: '.72rem', padding: '2px 8px', borderRadius: 4, fontWeight: 600,
                              background: isFinal ? 'rgba(255,255,255,.05)' : 'rgba(251,191,36,.12)',
                              color: isFinal ? 'var(--brand-muted)' : '#fbbf24' }}>
                              {stageLabel}
                            </span>
                            {renderHistActions('consultations', c.consulta_item_id, c.titulo || c.bib_ref || '\u2014', c.is_hidden_by_user)}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>

              {/* Section historique des reservations (preexistante) */}
              <div style={{ marginTop: 24 }}>
                <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem' }}>{t({ id: 'account.history.reservations.title' })}</h3>
                {visResas.length === 0 ? (
                  <p className="ab-conta-empty">{t({ id: 'account.history.empty' })}</p>
                ) : (
                <div className="ab-conta-items">
                  {visResas.map((h, i) => {
                    const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
                    const coverUrl = h.cover_object_path ? `${PROJECT_URL}/storage/v1/object/public/covers/${h.cover_object_path}` : null;
                    const stageKey = h.workflow_stage_effective || h.status || '';
                    const stageLabel = stageKey ? t({ id: `reservation.stage.${stageKey.replace('-','_')}`, defaultMessage: stageKey }) : '\u2014';
                    const isFinal = ['cancelada_leitor','cancelada_biblioteca','expirada','retirada_efetivada','liberada_para_circulacao','convertida_em_emprestimo'].includes(h.workflow_stage_effective || h.status);
                    return (
                      <div key={`res-${h.reserva_item_id ?? i}`} className="ab-conta-item ab-conta-item--history" style={{ display: 'flex', gap: 10, opacity: h.is_hidden_by_user ? 0.55 : 1 }}>
                        {coverUrl && <img src={coverUrl} alt="" loading="lazy" style={{ width: 40, height: 56, objectFit: 'cover', borderRadius: 4, flexShrink: 0, background: 'rgba(0,0,0,.2)' }} onError={e => { e.target.style.display = 'none'; }} />}
                        <div className="ab-conta-item__main" style={{ flex: 1 }}>
                          <Link to={`/livro/${h.book_id}`} className="ab-conta-item__title">{h.titulo || h.bib_ref || '\u2014'}</Link>
                          <span className="ab-conta-item__meta">{h.autor || '\u2014'}{h.editora && ` \u00b7 ${h.editora}`}{h.ano && ` (${h.ano})`}</span>
                          <span className="ab-conta-item__meta">
                            ref: {h.bib_ref || '\u2014'} \u00b7 {h.library_name || '\u2014'}
                            {h.reserved_at && <> \u00b7 {t({id:'account.history.reservedOn'})}: {new Date(h.reserved_at).toLocaleDateString()}</>}
                            {h.fulfilled_at && <> \u00b7 {t({id:'account.history.fulfilledOn'})}: {new Date(h.fulfilled_at).toLocaleDateString()}</>}
                            {h.cancelled_at && <> \u00b7 {t({id:'account.history.cancelledOn'})}: {new Date(h.cancelled_at).toLocaleDateString()}</>}
                          </span>
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                          <span style={{ fontSize: '.72rem', padding: '2px 8px', borderRadius: 4, fontWeight: 600,
                            background: isFinal ? 'rgba(255,255,255,.05)' : 'rgba(251,191,36,.12)',
                            color: isFinal ? 'var(--brand-muted)' : '#fbbf24' }}>
                            {stageLabel}
                          </span>
                          <Link to={`/livro/${h.book_id}`} style={{ fontSize: '.75rem', color: 'var(--brand-muted)' }}>{t({ id: 'account.history.seeAvailability' })}</Link>
                          {renderHistActions('reservations', h.reserva_item_id, h.titulo || h.bib_ref || '\u2014', h.is_hidden_by_user)}
                        </div>
                      </div>
                    );
                  })}
                </div>
                )}
              </div>
              {/* #CL.8 D.7 — préférences de conservation prospective (par domaine) */}
              {libraryId && (
              <div style={{ marginTop: 24, padding: 16, background: 'rgba(96,165,250,.05)', borderRadius: 8, border: '1px solid rgba(96,165,250,.15)' }}>
                <h3 className="ab-conta-section-title" style={{ fontSize: '1rem', marginTop: 0, marginBottom: 8 }}>
                  {t({ id: 'account.retentionPrefs.title' })}
                </h3>
                <p className="ab-conta-hint" style={{ marginTop: 0, marginBottom: 12 }}>
                  {t({ id: 'account.retentionPrefs.intro' }, { library: libraryName })}
                </p>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 12 }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                    <input type="checkbox" checked={retentionPrefs.loans}
                      onChange={(e) => setRetentionPrefs(p => ({ ...p, loans: e.target.checked }))} />
                    <span>{t({ id: 'account.retentionPrefs.disableLoans' })}</span>
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                    <input type="checkbox" checked={retentionPrefs.reservations}
                      onChange={(e) => setRetentionPrefs(p => ({ ...p, reservations: e.target.checked }))} />
                    <span>{t({ id: 'account.retentionPrefs.disableReservations' })}</span>
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                    <input type="checkbox" checked={retentionPrefs.consultations}
                      onChange={(e) => setRetentionPrefs(p => ({ ...p, consultations: e.target.checked }))} />
                    <span>{t({ id: 'account.retentionPrefs.disableConsultations' })}</span>
                  </label>
                </div>
                <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
                  <Button variant="secondary" onClick={handleSaveRetentionPrefs} disabled={retentionSaving}>
                    {retentionSaving ? t({ id: 'common.saving' }) : t({ id: 'common.save' })}
                  </Button>
                  {retentionMsg && <span className="ab-conta-msg" style={{ fontSize: '.85rem' }}>{retentionMsg}</span>}
                </div>
                <p className="ab-conta-hint" style={{ marginTop: 12, marginBottom: 0, fontSize: '.78rem', fontStyle: 'italic' }}>
                  {t({ id: 'account.retentionPrefs.note' })}
                </p>
              </div>
              )}
              {/* #CL.8 C.5 — suppression de masse rétroactive par domaine (D.7) */}
              {libraryId && ['loans','reservations','consultations'].some(d => countFor(d) > 0) && (
              <div style={{ marginTop: 16, padding: 16, background: 'rgba(248,113,113,.05)', borderRadius: 8, border: '1px solid rgba(248,113,113,.2)' }}>
                <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem', marginTop: 0, marginBottom: 8, color: '#f87171' }}>
                  {t({ id: 'account.history.deleteAll.sectionTitle' })}
                </h3>
                <p className="ab-conta-hint" style={{ marginTop: 0, marginBottom: 12 }}>
                  {t({ id: 'account.history.deleteAll.sectionHint' })}
                </p>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  {['loans','reservations','consultations'].map(domain => {
                    const cnt = countFor(domain);
                    if (cnt === 0) return null;
                    return (
                      <Button key={domain} variant="danger" onClick={() => { setDeleteAllConfirmText(''); setDeleteAllTarget({ domain }); }}>
                        {t({ id: 'account.history.deleteAll.button' }, { domain: t({ id: `account.history.deleteAll.domain.${domain}` }), count: cnt })}
                      </Button>
                    );
                  })}
                </div>
              </div>
              )}
            </div>
            );
          })()}

          {/* ═══ AVISOS ═══ */}
          {activeTab === 'avisos' && (
            <div>
              <ContaTabHeader
                title={t({ id: 'account.notifications.title' })}
                onRefresh={() => loadData({ silent: true })}
                actions={(
                  <>
                    {/* #CL.6 — toggle vue active / archives */}
                    <Button variant="mini" onClick={() => setNotifViewMode(m => m === 'active' ? 'archived' : 'active')}>
                      {notifViewMode === 'active'
                        ? t({ id: 'account.notifications.showArchives' })
                        : t({ id: 'account.notifications.backToActive' })}
                    </Button>
                    {/* "Marquer tout comme lu" : actifs uniquement, et seulement
                        s'il y a effectivement des non-lus à marquer */}
                    {notifViewMode === 'active' && unreadCount > 0 && (
                      <Button variant="mini" onClick={async () => {
                        await supabase.rpc('fn_mark_notifications_read');
                        loadData({ silent: true });
                      }}>{t({ id: 'account.notifications.markAllRead' })}</Button>
                    )}
                  </>
                )}
              />
              <p className="ab-conta-hint">{t({ id: 'account.tab.notifications.hint' })}</p>
              {visibleNotifications.length === 0 ? (
                <p className="ab-conta-empty">{
                  notifViewMode === 'active'
                    ? t({ id: 'account.notifications.empty' })
                    : t({ id: 'account.notifications.archivesEmpty' })
                }</p>
              ) : (
                <div className="ab-conta-items">
                  {visibleNotifications.map((n) => (
                    <div key={n.id} className="ab-conta-item" style={{
                      borderLeft: `3px solid ${n.is_read ? 'rgba(255,255,255,.06)' : n.category === 'alerta' ? '#f87171' : n.category === 'reserva' ? '#60a5fa' : n.category === 'emprestimo' ? '#fbbf24' : '#4ade80'}`,
                      opacity: n.is_read ? 0.6 : 1,
                    }}>
                      <div className="ab-conta-item__main" style={{ flex: 1 }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span className="ab-conta-item__title" style={{ cursor: 'default' }}>{/^(rgpd_retention_|rede_)/.test(n.category || '') && n.title ? t({ id: n.title, defaultMessage: n.title }) : n.title}</span>
                          {!n.is_read && <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#60a5fa', flexShrink: 0 }} />}
                        </div>
                        {n.body && <span className="ab-conta-item__meta">{/^(rgpd_retention_|rede_)/.test(n.category || '') ? t({ id: n.body, defaultMessage: n.body }) : n.body}</span>}
                        <span className="ab-conta-item__meta" style={{ fontSize: '.78rem' }}>
                          {new Date(n.created_at).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}
                          {n.category && <> · {n.category}</>}
                        </span>
                      </div>
                      <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                        {n.link_type === 'livro' && n.link_id && <Link to={`/livro/${n.link_id}`}><Button variant="mini">{t({ id: 'account.notifications.seeBook' })}</Button></Link>}
                        {(n.link_type || '').startsWith('rede_') && <Link to={n.link_type === 'rede_gazette' ? '/federacao/gazeta' : n.link_type === 'rede_circulo' ? '/federacao/circulos' : '/federacao/carta'}><Button variant="mini">{t({ id: 'account.notifications.openNetwork' })}</Button></Link>}
                        {!n.is_read && (
                          <Button variant="mini" onClick={async () => {
                            await supabase.rpc('fn_mark_notifications_read', { p_ids: [n.id] });
                            loadData({ silent: true });
                          }}>✓</Button>
                        )}
                        {/* #CL.6 — archiver (vue active) ou restaurer (vue archives) */}
                        {notifViewMode === 'active' ? (
                          <Button variant="mini" onClick={async () => {
                            const { error } = await supabase.rpc('fn_archive_notification', { p_notification_id: n.id });
                            if (!error) loadData({ silent: true });
                          }} title={t({ id: 'account.notifications.archive' })}>📥</Button>
                        ) : (
                          <Button variant="mini" onClick={async () => {
                            const { error } = await supabase.rpc('fn_unarchive_notification', { p_notification_id: n.id });
                            if (!error) loadData({ silent: true });
                          }} title={t({ id: 'account.notifications.unarchive' })}>↩</Button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* ═══ LISTA DE DESEJOS ═══ */}
          {activeTab === 'desejos' && (
            <div>
              <h2 className="ab-conta-section-title">{t({ id: 'account.wishlist.title' })}</h2>
              <p className="ab-conta-hint">{t({ id: 'account.tab.wishlist.hint' })}</p>
              {wishlist.length === 0 ? (
                <p className="ab-conta-empty">{t({ id: 'account.wishlist.empty' })}</p>
              ) : (
                <div className="ab-conta-items">
                  {wishlist.map((w) => {
                    const b = w.books || {};
                    const wAvail = w.book_id ? availabilityMap.get(Number(w.book_id)) : null;
                    const canReserveFromWishlist =
                      wAvail?.session_holding_id &&
                      wAvail?.session_loanable &&
                      (wAvail?.session_available_count || 0) > 0;
                    return (
                      <div key={w.id} className="ab-conta-item" style={{ display: 'flex', gap: 10 }}>
                        <div className="ab-conta-item__main" style={{ flex: 1 }}>
                          <Link to={`/livro/${w.book_id}`} className="ab-conta-item__title">{b.titulo || '—'}</Link>
                          <span className="ab-conta-item__meta">{b.autor || '—'}{b.editora && ` · ${b.editora}`}{b.ano && ` (${b.ano})`}</span>
                          <span className="ab-conta-item__meta">ref: {b.bib_ref || '—'}{w.note && ` · ${w.note}`}</span>
                          <span className="ab-conta-item__meta" style={{ fontSize: '.78rem' }}>{t({id:'account.wishlist.addedOn2'},{date: new Date(w.created_at).toLocaleDateString()})}</span>
                          {/* #CL.9 — dispo courante du livre dans la biblio par défaut (31/05/2026) */}
                          {wAvail && (
                            <span className="ab-conta-item__meta" style={{ marginTop: 4 }}>
                              <BookAvailability availability={wAvail} variant="compact" />
                            </span>
                          )}
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                          <Link to={`/livro/${w.book_id}`}><Button variant="mini">{t({ id: 'account.wishlist.seeRecord' })}</Button></Link>
                          {/* #CL.9 — réserver depuis la wishlist quand le livre est dispo et prêtable (31/05/2026) */}
                          {canReserveFromWishlist && (
                            <Button variant="mini" onClick={async () => {
                              const { error } = await supabase.rpc('fn_v2_create_reserva_by_holdings', {
                                p_user_id: user.id,
                                p_holding_ids: [wAvail.session_holding_id],
                              });
                              if (!error) loadData();
                            }}>{t({ id: 'account.wishlist.reserveNow' })}</Button>
                          )}
                          <Button variant="mini" onClick={async () => {
                            await supabase.from('user_wishlist').delete().eq('id', w.id);
                            loadData();
                          }} style={{ color: '#f87171' }}>{t({ id: 'common.remove' })}</Button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* ═══ MES BIBLIOS (MULTI P5a) ═══ */}
          {activeTab === 'biblios' && (
            <Suspense fallback={<p className="ab-conta-hint">{t({ id: 'common.loading' })}</p>}>
              <TabBiblios />
              {/* §21 PARTNER P6b : consentement de la lectrice à la transparence */}
              <MyPartnershipsConsentSection />
            </Suspense>
          )}
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
// module lazy src/components/account/ReservationCard.jsx (import lazy en tête).

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
