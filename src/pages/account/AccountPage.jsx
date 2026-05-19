import { useState, useEffect, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase, apiQuery } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { useAccountAvailability } from '@/hooks/useAccountAvailability';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, Spinner, Skeleton, EmptyState } from '@/components/ui';
import NegotiationStateBadge from '@/components/reservation/NegotiationStateBadge';
import CountrySelect from '@/components/forms/CountrySelect';
import StateSelect from '@/components/forms/StateSelect';
import PhoneInput from '@/components/forms/PhoneInput';
import { getCountryMetadata } from '@/components/forms/countryData';
import { parseAddressText, formatAddressText } from '@/lib/addressFormat';
import { formatSchedule } from '@/lib/scheduleFormat';
import { localizeError } from '@/lib/localizeError';
import DataExportButton from '@/components/account/DataExportButton';
import Modal from '@/components/ui/Modal';
import './AccountPage.css';

export default function AccountPage() {
  const { user, loading: authLoading } = useAuth();
  const { libraryName, librarySlug, libraryId } = useLibrary();
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
  const [reservations, setReservations] = useState([]);
  const [consultations, setConsultations] = useState([]);
  const [consultationsHistory, setConsultationsHistory] = useState([]);
  const [renewStatus, setRenewStatus] = useState({});
  const [loans, setLoans] = useState([]);
  const [history, setHistory] = useState([]);
  const [loanHistory, setLoanHistory] = useState([]);
  const [notifications, setNotifications] = useState([]);
  const [wishlist, setWishlist] = useState([]);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');
  const [msgIsError, setMsgIsError] = useState(false);
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

  // ── Chargement des données ───────────────────────────────

  const loadData = useCallback(async () => {
    if (authLoading || !user) return;
    setLoading(true);
    try {
      const [profileRes, reservRes, consultRes, consultHistRes, loansRes, renewStatusRes, histRes, loanHistRes, svcRes] = await Promise.all([
        supabase.from('profiles').select('*').eq('id', user.id).single(),
        apiQuery('my_reservations_active_v2'),
        apiQuery('my_consultas_active_v2'),
        apiQuery('my_consultas_history_v2'),
        apiQuery('emprestimo_itens_ui'),
        apiQuery('my_loans_renewal_status_v1'),
        apiQuery('my_reservations_history_v2'),
        apiQuery('my_loans_history_v1'),
        supabase.from('library_service_state').select('*'),
      ]);
      setProfile(profileRes.data);
      setReservations(reservRes.data || []);
      setConsultations(consultRes.data || []);
      setConsultationsHistory(consultHistRes.data || []);
      setLoans(loansRes.data || []);
      setRenewStatus(Object.fromEntries(
        (renewStatusRes.data || []).map(r => [r.emprestimo_id, r])
      ));
      setHistory(histRes.data || []);
      setLoanHistory(loanHistRes.data || []);
      // Service state for the user's library
      if (svcRes.data?.length) setServiceState(svcRes.data[0]);
      // Notifications and wishlist
      const { data: notifData } = await supabase.from('user_notifications').select('*').eq('user_id', user.id).order('created_at', { ascending: false }).limit(50);
      setNotifications(notifData || []);
      const { data: wishData } = await supabase.from('user_wishlist').select('*, books:book_id(id, titulo, autor, bib_ref, editora, ano)').eq('user_id', user.id).order('created_at', { ascending: false });
      setWishlist(wishData || []);
      // Cotisation : statut et historique pour la biblio active
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
      console.error('Account load error:', err);
    } finally {
      setLoading(false);
    }
  }, [user?.id, authLoading, libraryId]);

  useEffect(() => { loadData(); }, [loadData]);

  // ── Status do conta ───────────────────────────────────────
  useEffect(() => {
    if (authLoading || !user) return;
    (async () => {
      const { data } = await supabase.rpc('fn_my_account_status');
      if (data) setAccountStatus(data);
    })();
  }, [user?.id, authLoading]);

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
        address: addrText,
      }).eq('id', user.id);
      if (error) throw error;
      setMsg(t({ id: 'account.reserve.dataSaved' }));
      setMsgIsError(false);
    } catch (err) {
      setMsg(t({id:'common.errorPrefix'},{message:err.message}));
      setMsgIsError(true);
    } finally {
      setSaving(false);
    }
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
      setPwdMsg(t({ id: 'common.errorPrefix' }, { message: err.message }));
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

      // 7. Contrôle loanable vs consultation-only
      if (!isConsultation) {
        const nonLoanable = rows.filter(r => r.matched && r.session_loanable === false);
        if (nonLoanable.length) {
          setReserveMsg(t({id:'account.reserve.consultationOnlyHint'},{refs:nonLoanable.map(r => r.bib_ref || r.input_ref).join(', ')}));
          return;
        }
      } else {
        const loanableOnly = rows.filter(r => r.matched && r.session_loanable === true);
        if (loanableOnly.length) {
          setReserveMsg(t({id:'account.reserve.loanableOnlyHint'},{refs:loanableOnly.map(r => r.bib_ref || r.input_ref).join(', ')}));
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
      const msg = err.hint || err.message || String(err);
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
      const msg = err.hint || err.message || String(err);
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
      const msg = err.hint || err.message || String(err);
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
        alert(t({ id: 'common.errorPrefix' }, { message: error.message }));
        return;
      }
      setCancelTarget(null);
      await loadData();
    } catch (err) {
      console.error('cancel_consulta_as_reader exception:', err);
      alert(t({ id: 'common.errorPrefix' }, { message: err.message }));
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
        alert(t({ id: 'common.errorPrefix' }, { message: error.message }));
        return;
      }
      await loadData();
    } catch (err) {
      console.error('reply_consulta_schedule (confirm) exception:', err);
      alert(t({ id: 'common.errorPrefix' }, { message: err.message }));
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
        alert(t({ id: 'common.errorPrefix' }, { message: error.message }));
        return;
      }
      setRefuseTarget(null);
      await loadData();
    } catch (err) {
      console.error('reply_consulta_schedule (refuse) exception:', err);
      alert(t({ id: 'common.errorPrefix' }, { message: err.message }));
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

  const unreadCount = notifications.filter(n => !n.is_read).length;

  // Paquet E.4.2 (20/05/2026) : filtrage des onglets AccountPage par availability
  // selon profil de biblio (1 lecteur·rice = 1 biblio, cf. doctrine ancrage).
  const ALL_TABS = [
    { key: 'perfil', label: t({ id: 'account.tab.profile' }), hint: t({ id: 'account.tab.profile.hint' }) },
    { key: 'reservar', label: t({ id: 'account.tab.reservations' }), hint: t({ id: 'account.tab.reservations.hint' }) },
    { key: 'curso', label: t({ id: 'account.tab.loans' }), hint: t({ id: 'account.tab.loans.hint' }) },
    { key: 'historico', label: t({ id: 'account.tab.history' }), hint: t({ id: 'account.tab.history.hint' }) },
    { key: 'avisos', label: `${t({ id: 'account.tab.notifications' })}${unreadCount > 0 ? ` (${unreadCount})` : ''}`, hint: t({ id: 'account.tab.notifications.hint' }) },
    { key: 'desejos', label: `${t({ id: 'account.tab.wishlist' })} (${wishlist.length})`, hint: t({ id: 'account.tab.wishlist.hint' }) },
  ];
  const TABS = ALL_TABS.filter(t => availability[t.key] !== false);

  return (
    <PageShell>
      <Topbar />

      <Hero title={t({ id: 'account.title' })} subtitle={t({ id: 'account.subtitle' })}>
        <div className="ab-conta-chips">
          <Pill>{t({ id: 'account.chips.reader' }, { name: chips.user })}</Pill>
          <Pill>{t({ id: 'account.chips.library' }, { name: chips.library })}</Pill>
          {profile?.public_id && <Pill>{t({ id: 'account.chips.publicId' }, { id: chips.publicId })}</Pill>}
          <Pill>{t({ id: 'account.chips.since' }, { date: chips.created })}</Pill>
          {availability.chip_reservas && (<Pill variant={chips.reservas > 0 ? 'warn' : 'default'}>{t({ id: 'account.chips.reservations' }, { count: chips.reservas })}</Pill>)}
          {availability.chip_consultas && (<Pill variant={chips.consultas > 0 ? 'warn' : 'default'}>{t({ id: 'account.chips.consultations' }, { count: chips.consultas })}</Pill>)}
          {availability.chip_emprestimos && (<Pill variant={chips.emprestimos > 0 ? 'warn' : 'default'}>{t({ id: 'account.chips.loans' }, { count: chips.emprestimos })}</Pill>)}
        </div>

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

                <hr className="ab-conta-hr" />
                <h3 style={{ fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'address.title' })}</h3>
                <AddressForm addr={addr} onChange={updateAddress} />

                <div className="ab-conta-form-actions">
                  <Button type="submit" loading={saving}>{t({ id: 'common.save' })}</Button>
                  {msg && <span className={`ab-conta-msg ${msgIsError ? 'ab-conta-msg--error' : ''}`}>{msg}</span>}
                </div>
              </form>

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

                {/* Suppression du compte */}
                <div>
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
                      } catch (err) { alert(t({id:'common.errorPrefix'},{message:err.message})); setDeleting(false); }
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
            </div>
          )}

          {/* ═══ RESERVAS E CONSULTAS ═══ */}
          {activeTab === 'reservar' && (
            <div>
              <h2 className="ab-conta-section-title">{t({ id: 'account.reserve.title' })}</h2>
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
                <div className="ab-conta-items">
                  {reservations.map((r, i) => (
                    <ReservationCard
                      key={i}
                      r={r}
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
              <h2 className="ab-conta-section-title">{t({ id: 'account.loans.title' })}</h2>
              <p className="ab-conta-hint">{t({ id: 'account.loans.hint' })}</p>
              {loans.filter(l => l.item_status === 'aberto').length === 0 ? (
                <p className="ab-conta-empty">{t({ id: 'account.loans.empty' })}</p>
              ) : (
                <div className="ab-conta-items">
                  {loans.filter(l => l.item_status === 'aberto').map((l, i) => {
                    // Paquet 7 fix (10/05/2026) : utiliser extended_until si présent,
                    // sinon due_at. Sinon la date affichée ne reflète pas le renouvellement.
                    const effectiveDue = l.extended_until || l.due_at;
                    const due = effectiveDue ? new Date(effectiveDue + 'T00:00:00') : null;
                    const today = new Date(); today.setHours(0,0,0,0);
                    const daysLeft = due ? Math.ceil((due - today) / 86400000) : null;
                    const isOverdue = daysLeft !== null && daysLeft < 0;
                    const isSoon = daysLeft !== null && daysLeft >= 0 && daysLeft <= 3;
                    // Paquet 7 (10/05/2026) : compteur explicite + pré-évaluation
                    const renewalsUsed = l.renewals_used || 0;
                    const wasExtended = renewalsUsed > 0;
                    const renewInfo = renewStatus[l.emprestimo_id] || null;
                    // Paquet 8 (10/05/2026) : détection retour partiel calculée côté frontend
                    // à partir du tableau loans complet (groupBy emprestimo_id).
                    const sameLoanItems = loans.filter(x => x.emprestimo_id === l.emprestimo_id);
                    const hasReturned = sameLoanItems.some(x => x.item_status === 'devolvido');
                    const hasOpen = sameLoanItems.some(x => x.item_status === 'aberto');
                    const isPartialReturn = hasReturned && hasOpen;
                    return (
                      <div key={i} className={`ab-conta-item ${isOverdue ? 'ab-conta-item--overdue' : ''}`}
                        style={{ borderLeft: `3px solid ${isOverdue ? '#ef4444' : isSoon ? '#f59e0b' : 'rgba(255,255,255,.08)'}` }}>
                        <div className="ab-conta-item__main" style={{ flex: 1 }}>
                          <Link to={`/livro/${l.book_id}`} className="ab-conta-item__title">{l.titulo || l.bib_ref || '—'}</Link>
                          <span className="ab-conta-item__meta">{l.autor || '—'}</span>
                          <span className="ab-conta-item__meta">
                            ref: {l.bib_ref || '—'}
                            {l.emprestimo_created_at && <> · {t({id:'account.loans.checkout'})}: {new Date(l.emprestimo_created_at).toLocaleDateString()}</>}
                            {due && <> · {t({id:'account.loans.deadline'})}: <strong style={{ color: isOverdue ? '#ef4444' : isSoon ? '#f59e0b' : 'inherit' }}>{due.toLocaleDateString()}</strong></>}
                            {daysLeft !== null && (
                              isOverdue
                                ? <> · <strong style={{ color: '#ef4444' }}>{t({ id: 'account.loans.daysOverdue' }, { days: Math.abs(daysLeft) })}</strong></>
                                : <> · {t({ id: 'account.loans.daysLeft' }, { days: daysLeft })}</>
                            )}
                          </span>
                          {wasExtended && <span className="ab-conta-item__meta" style={{ color: '#60a5fa' }}>{t({ id: 'account.loans.renewedUntil' }, { date: new Date(l.extended_until + 'T00:00:00').toLocaleDateString() })}</span>}
                          {isPartialReturn && <span className="ab-conta-item__meta" style={{ color: '#f59e0b' }}>{t({ id: 'account.loans.partialReturnHint' })}</span>}
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                          {(() => {
                            // Paquet 7 : pré-désactivation + tooltip
                            // renewInfo vient de api.my_loans_renewal_status_v1 et porte
                            // can_renew (bool) + blocking_reason (text|null).
                            // Fallback ancien comportement si la vue n'a pas répondu.
                            const canRenew = renewInfo
                              ? renewInfo.can_renew
                              : (!wasExtended && !isOverdue);
                            const blockingReason = renewInfo ? renewInfo.blocking_reason : null;
                            const tooltipMsg = blockingReason
                              ? t(
                                  { id: 'account.renew.tooltipBlocked' },
                                  { reason: t({ id: `account.renew.${blockingReason}` }) }
                                )
                              : null;
                            // On n'affiche le bouton que si pas déjà étiqueté "renouvelé" ou "en retard"
                            // (les deux étiquettes spécialisées plus bas couvrent ces cas).
                            if (wasExtended || isOverdue) return null;
                            return (
                              <Button
                                variant="mini"
                                disabled={!canRenew}
                                title={tooltipMsg || undefined}
                                onClick={async () => {
                                  // Paquet 19 (10/05/2026) : utiliser le wrapper api.* au lieu de la fn DEFINER
                                  const { data, error } = await supabase.schema('api').rpc('renew_my_loan', { p_emprestimo_id: l.emprestimo_id });
                                  if (error) { alert(t({id:'common.errorPrefix'}, {message: localizeError(error, t)})); return; }
                                  if (data?.ok === false) {
                                    alert(t({ id: `account.renew.${data.reason}` }));
                                    return;
                                  }
                                  alert(t({ id: 'account.renew.renewed' }, { date: new Date(data.new_due_date).toLocaleDateString() }));
                                  loadData();
                                }}
                              >
                                {t({ id: 'account.loans.renew' })}
                              </Button>
                            );
                          })()}
                          {wasExtended && <span style={{ fontSize: '.72rem', color: '#60a5fa', fontWeight: 600 }}>{t({ id: 'account.loans.renewed' })}</span>}
                          {isOverdue && <span style={{ fontSize: '.72rem', color: '#ef4444', fontWeight: 600 }}>{t({ id: 'account.loans.overdue' })}</span>}
                          {isPartialReturn && <span style={{ fontSize: '.72rem', color: '#f59e0b', fontWeight: 600 }}>{t({ id: 'account.loans.partialReturn' })}</span>}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}

              {/* Empréstimos devolvidos recentemente */}
              {loans.filter(l => l.item_status === 'devolvido').length > 0 && (
                <div style={{ marginTop: 20 }}>
                  <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem' }}>{t({ id: 'account.loans.recentlyReturned' })}</h3>
                  <div className="ab-conta-items">
                    {loans.filter(l => l.item_status === 'devolvido').slice(0, 10).map((l, i) => (
                      <div key={i} className="ab-conta-item ab-conta-item--history" style={{ opacity: .7 }}>
                        <div className="ab-conta-item__main">
                          <Link to={`/livro/${l.book_id}`} className="ab-conta-item__title">{l.titulo || l.bib_ref || '—'}</Link>
                          <span className="ab-conta-item__meta">
                            ref: {l.bib_ref || '—'}
                            {l.emprestimo_created_at && <> · {t({id:'account.loans.checkout'})}: {new Date(l.emprestimo_created_at).toLocaleDateString()}</>}
                            {l.returned_at && <> · {t({id:'account.loans.returnedOn'})}: {new Date(l.returned_at).toLocaleDateString()}</>}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* ═══ HISTÓRICO ═══ */}
          {activeTab === 'historico' && (
            <div>
              <h2 className="ab-conta-section-title">{t({ id: 'account.history.title' })}</h2>
              <p className="ab-conta-hint">{t({ id: 'account.history.hint' })}</p>

              {/* Paquet 10 (10/05/2026) : section historique des emprunts */}
              <div style={{ marginTop: 16 }}>
                <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem' }}>{t({ id: 'account.history.loans.title' })}</h3>
                {loanHistory.length === 0 ? (
                  <p className="ab-conta-empty">{t({ id: 'account.history.loans.empty' })}</p>
                ) : (
                  <div className="ab-conta-items">
                    {loanHistory.map((lh, i) => (
                      <div key={`loan-${lh.emprestimo_id}`} className="ab-conta-item ab-conta-item--history" style={{ display: 'flex', gap: 10 }}>
                        <div className="ab-conta-item__main" style={{ flex: 1 }}>
                          {lh.book_id ? (
                            <Link to={`/livro/${lh.book_id}`} className="ab-conta-item__title">{lh.titulos || '—'}</Link>
                          ) : (
                            <span className="ab-conta-item__title">{lh.titulos || '—'}</span>
                          )}
                          {lh.autores && <span className="ab-conta-item__meta">{lh.autores}</span>}
                          <span className="ab-conta-item__meta">
                            {lh.items_count > 1 && <>{t({ id: 'account.history.loans.itemsCount' }, { count: lh.items_count })} · </>}
                            ref: {lh.bib_refs || '—'} · {lh.library_name || '—'}
                            {lh.emprestimo_created_at && <> · {t({id:'account.loans.checkout'})}: {new Date(lh.emprestimo_created_at).toLocaleDateString()}</>}
                            {lh.returned_at && <> · {t({id:'account.loans.returnedOn'})}: {new Date(lh.returned_at).toLocaleDateString()}</>}
                            {lh.renewals_used > 0 && <> · {t({ id: 'account.history.loans.renewalsUsed' }, { count: lh.renewals_used })}</>}
                          </span>
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                          <span style={{ fontSize: '.72rem', padding: '2px 8px', borderRadius: 4, fontWeight: 600, background: 'rgba(74,222,128,.12)', color: '#4ade80' }}>
                            {t({ id: 'account.history.loans.completed' })}
                          </span>
                          <button type="button" style={{ fontSize: '.7rem', color: 'var(--brand-muted)', background: 'none', border: 'none', cursor: 'pointer', padding: 0, textDecoration: 'underline' }}
                            onClick={() => { setLoanHistory(prev => prev.filter((_, idx) => idx !== i)); }}
                          >{t({ id: 'account.history.hide' })}</button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
              {/* Paquet 26 L4 (14/05/2026) : section historique des consultas */}
              <div style={{ marginTop: 24 }}>
                <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem' }}>{t({ id: 'account.history.consultations.title' })}</h3>
                {consultationsHistory.length === 0 ? (
                  <p className="ab-conta-empty">{t({ id: 'account.history.consultations.empty' })}</p>
                ) : (
                  <div className="ab-conta-items">
                    {consultationsHistory.map((c, i) => {
                      const stageKey = c.workflow_stage || c.status || '';
                      const stageLabel = stageKey ? t({ id: `consultation.stage.${stageKey.replace('-','_')}`, defaultMessage: stageKey }) : '—';
                      const isFinal = ['consultada','cancelada_leitor','cancelada_biblioteca','expirada'].includes(stageKey);
                      return (
                        <div key={`ch-${i}`} className="ab-conta-item ab-conta-item--history" style={{ display: 'flex', gap: 10 }}>
                          <div className="ab-conta-item__main" style={{ flex: 1 }}>
                            <Link to={`/livro/${c.book_id}`} className="ab-conta-item__title">{c.titulo || c.bib_ref || '—'}</Link>
                            <span className="ab-conta-item__meta">{c.autor || '—'}{c.editora && ` · ${c.editora}`}{c.ano && ` (${c.ano})`}</span>
                            <span className="ab-conta-item__meta">
                              ref: {c.bib_ref || '—'} · {c.library_name || '—'}
                              {c.requested_at && <> · {t({id:'account.history.consultations.requestedOn'})}: {new Date(c.requested_at).toLocaleDateString()}</>}
                              {c.consulted_at && <> · {t({id:'account.history.consultations.consultedOn'})}: {new Date(c.consulted_at).toLocaleDateString()}</>}
                              {c.cancelled_at && <> · {t({id:'account.history.cancelledOn'})}: {new Date(c.cancelled_at).toLocaleDateString()}</>}
                            </span>
                          </div>
                          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                            <span style={{ fontSize: '.72rem', padding: '2px 8px', borderRadius: 4, fontWeight: 600,
                              background: isFinal ? 'rgba(255,255,255,.05)' : 'rgba(251,191,36,.12)',
                              color: isFinal ? 'var(--brand-muted)' : '#fbbf24' }}>
                              {stageLabel}
                            </span>
                            <button type="button" style={{ fontSize: '.7rem', color: 'var(--brand-muted)', background: 'none', border: 'none', cursor: 'pointer', padding: 0, textDecoration: 'underline' }}
                              onClick={() => { setConsultationsHistory(prev => prev.filter((_, idx) => idx !== i)); }}
                            >{t({ id: 'account.history.hide' })}</button>
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
                {history.length === 0 ? (
                  <p className="ab-conta-empty">{t({ id: 'account.history.empty' })}</p>
                ) : (
                <div className="ab-conta-items">
                  {history.map((h, i) => {
                    const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
                    const coverUrl = h.cover_object_path ? `${PROJECT_URL}/storage/v1/object/public/covers/${h.cover_object_path}` : null;
                    const stageKey = h.workflow_stage_effective || h.status || '';
                    const stageLabel = stageKey ? t({ id: `reservation.stage.${stageKey.replace('-','_')}`, defaultMessage: stageKey }) : '—';
                    const isFinal = ['cancelada_leitor','cancelada_biblioteca','expirada','retirada_efetivada','liberada_para_circulacao','convertida_em_emprestimo'].includes(h.workflow_stage_effective || h.status);
                    return (
                      <div key={i} className="ab-conta-item ab-conta-item--history" style={{ display: 'flex', gap: 10 }}>
                        {coverUrl && <img src={coverUrl} alt="" style={{ width: 40, height: 56, objectFit: 'cover', borderRadius: 4, flexShrink: 0, background: 'rgba(0,0,0,.2)' }} onError={e => { e.target.style.display = 'none'; }} />}
                        <div className="ab-conta-item__main" style={{ flex: 1 }}>
                          <Link to={`/livro/${h.book_id}`} className="ab-conta-item__title">{h.titulo || h.bib_ref || '—'}</Link>
                          <span className="ab-conta-item__meta">{h.autor || '—'}{h.editora && ` · ${h.editora}`}{h.ano && ` (${h.ano})`}</span>
                          <span className="ab-conta-item__meta">
                            ref: {h.bib_ref || '—'} · {h.library_name || '—'}
                            {h.reserved_at && <> · {t({id:'account.history.reservedOn'})}: {new Date(h.reserved_at).toLocaleDateString()}</>}
                            {h.fulfilled_at && <> · {t({id:'account.history.fulfilledOn'})}: {new Date(h.fulfilled_at).toLocaleDateString()}</>}
                            {h.cancelled_at && <> · {t({id:'account.history.cancelledOn'})}: {new Date(h.cancelled_at).toLocaleDateString()}</>}
                          </span>
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                          <span style={{ fontSize: '.72rem', padding: '2px 8px', borderRadius: 4, fontWeight: 600,
                            background: isFinal ? 'rgba(255,255,255,.05)' : 'rgba(251,191,36,.12)',
                            color: isFinal ? 'var(--brand-muted)' : '#fbbf24' }}>
                            {stageLabel}
                          </span>
                          <Link to={`/livro/${h.book_id}`} style={{ fontSize: '.75rem', color: 'var(--brand-muted)' }}>{t({ id: 'account.history.seeAvailability' })}</Link>
                          <button type="button" style={{ fontSize: '.7rem', color: 'var(--brand-muted)', background: 'none', border: 'none', cursor: 'pointer', padding: 0, textDecoration: 'underline' }}
                            onClick={() => { setHistory(prev => prev.filter((_, idx) => idx !== i)); }}
                          >{t({ id: 'account.history.hide' })}</button>
                        </div>
                      </div>
                    );
                  })}
                </div>
                )}
              </div>
            </div>
          )}

          {/* ═══ AVISOS ═══ */}
          {activeTab === 'avisos' && (
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
                <h2 className="ab-conta-section-title" style={{ margin: 0 }}>{t({ id: 'account.notifications.title' })}</h2>
                {unreadCount > 0 && (
                  <Button variant="mini" onClick={async () => {
                    await supabase.rpc('fn_mark_notifications_read');
                    loadData();
                  }}>{t({ id: 'account.notifications.markAllRead' })}</Button>
                )}
              </div>
              <p className="ab-conta-hint">{t({ id: 'account.tab.notifications.hint' })}</p>
              {notifications.length === 0 ? (
                <p className="ab-conta-empty">{t({ id: 'account.notifications.empty' })}</p>
              ) : (
                <div className="ab-conta-items">
                  {notifications.map((n) => (
                    <div key={n.id} className="ab-conta-item" style={{
                      borderLeft: `3px solid ${n.is_read ? 'rgba(255,255,255,.06)' : n.category === 'alerta' ? '#f87171' : n.category === 'reserva' ? '#60a5fa' : n.category === 'emprestimo' ? '#fbbf24' : '#4ade80'}`,
                      opacity: n.is_read ? 0.6 : 1,
                    }}>
                      <div className="ab-conta-item__main" style={{ flex: 1 }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span className="ab-conta-item__title" style={{ cursor: 'default' }}>{(n.category || '').startsWith('rgpd_retention_') && n.title ? t({ id: n.title, defaultMessage: n.title }) : n.title}</span>
                          {!n.is_read && <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#60a5fa', flexShrink: 0 }} />}
                        </div>
                        {n.body && <span className="ab-conta-item__meta">{(n.category || '').startsWith('rgpd_retention_') ? t({ id: n.body, defaultMessage: n.body }) : n.body}</span>}
                        <span className="ab-conta-item__meta" style={{ fontSize: '.78rem' }}>
                          {new Date(n.created_at).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}
                          {n.category && <> · {n.category}</>}
                        </span>
                      </div>
                      <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                        {n.link_type === 'livro' && n.link_id && <Link to={`/livro/${n.link_id}`}><Button variant="mini">{t({ id: 'account.notifications.seeBook' })}</Button></Link>}
                        {!n.is_read && (
                          <Button variant="mini" onClick={async () => {
                            await supabase.rpc('fn_mark_notifications_read', { p_ids: [n.id] });
                            loadData();
                          }}>✓</Button>
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
                    return (
                      <div key={w.id} className="ab-conta-item" style={{ display: 'flex', gap: 10 }}>
                        <div className="ab-conta-item__main" style={{ flex: 1 }}>
                          <Link to={`/livro/${w.book_id}`} className="ab-conta-item__title">{b.titulo || '—'}</Link>
                          <span className="ab-conta-item__meta">{b.autor || '—'}{b.editora && ` · ${b.editora}`}{b.ano && ` (${b.ano})`}</span>
                          <span className="ab-conta-item__meta">ref: {b.bib_ref || '—'}{w.note && ` · ${w.note}`}</span>
                          <span className="ab-conta-item__meta" style={{ fontSize: '.78rem' }}>{t({id:'account.wishlist.addedOn2'},{date: new Date(w.created_at).toLocaleDateString()})}</span>
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                          <Link to={`/livro/${w.book_id}`}><Button variant="mini">{t({ id: 'account.wishlist.seeRecord' })}</Button></Link>
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
        </div>
      </div>

      <Footer />
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

// WORKFLOW_LABELS and PICKUP_REPLY_LABELS are now fully resolved via i18n keys (reservation.workflow.* and reservation.pickup.reply.*)

function fmtDate(d) {
  if (!d) return '';
  try { return new Date(d).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }); }
  catch { return String(d); }
}

// ═══════════════════════════════════════════════════════════
// ReservationCard — refondue paquet 4 (workflow réservation v2 négociation)
// PATCH 09/05/2026 paquet 5b : refactor sémantique v3.
// ═══════════════════════════════════════════════════════════
// Affiche une réservation avec actions contextuelles selon l'état de la
// négociation symétrique (champs pickup_proposed_by, negotiation_iteration_count).
//
// Sémantique v3 :
//   - retirada_a_combinar = stage de négociation active (forme verbale).
//     C'est ici que se déroulent toutes les propositions/contre-propositions.
//   - retirada_agendada = stage d'aboutissement, créneau verrouillé (forme
//     aboutie). Atteint uniquement par confirmation mutuelle. Plus de boutons
//     de négociation : juste un message "créneau confirmé, prêt à retirer
//     bientôt", en attendant la transition vers pronta_para_retirada.
//   - re-retirada_agendada = déprécié (matrice false partout, fossile pour
//     résas historiques).
//
// 4 états distincts gérés :
//
//   1. Stage = retirada_a_combinar ET pickup_proposed_by='biblio'
//      → la biblio a proposé un créneau, c'est au lecteur·rice de répondre
//      → 3 boutons : "Aceitar este horário", "Propor outro horário", "Cancelar"
//      → Le bouton "Propor outro horário" est masqué si compteur >= 3 OU si la
//        biblio a désactivé reservation_allow_reader_counter_proposal.
//
//   2. Stage = retirada_a_combinar ET pickup_proposed_by='leitor'
//      → le lecteur·rice a déjà contre-proposé, c'est à la biblio de répondre
//      → 2 boutons : "Modificar minha proposta" et "Cancelar"
//      → Compteur visible "iteração n/3" pour transparence.
//
//   3. Compteur saturé (negotiation_iteration_count >= 3) ET pickup_proposed_by='biblio'
//      → la négociation a atteint sa limite, redirection vers contact direct
//      → message d'aide + 1 seul bouton "Cancelar" (et "Aceitar este horário" reste,
//        car le lecteur peut toujours accepter même au-delà de 3 itérations).
//
//   4. Autres stages (solicitada, em_preparacao, retirada_agendada,
//      pronta_para_retirada, etc.) ou stage retirada_a_combinar avec
//      pickup_proposed_by=NULL (négociation close avant verrouillage)
//      → affichage standard, 1 seul bouton "Cancelar" si stage non terminal.
//      → retirada_agendada affiche un message "créneau verrouillé, livre
//        bientôt prêt à retirer".
//
// La carte intègre un panneau accordion qui se déplie quand le lecteur·rice
// clique sur "Propor outro horário". Le panneau contient un datetime-local
// pré-rempli avec le créneau actuel + un champ note + 2 boutons.
//
// Le composant <NegotiationStateBadge viewerRole="reader" /> du paquet 3B est
// réutilisé pour afficher l'état de négociation visuellement.
// ═══════════════════════════════════════════════════════════

function ReservationCard({
  r,
  onCancel,
  onConfirmPickup,
  onOpenCounterProposalForm,
  onCloseCounterProposalForm,
  onSubmitCounterProposal,
  negotiationForm,
  setNegotiationForm,
}) {
  const { formatMessage: t } = useIntl();

  const WORKFLOW_LABELS = {
    solicitada: t({ id: 'reservation.stage.solicitada' }),
    em_preparacao: t({ id: 'reservation.stage.em_preparacao' }),
    pronta_para_retirada: t({ id: 'reservation.stage.pronta_para_retirada' }),
    retirada_a_combinar: t({ id: 'reservation.stage.retirada_a_combinar' }),
    retirada_agendada: t({ id: 'reservation.stage.retirada_agendada' }),
    're-retirada_agendada': t({ id: 'reservation.stage.re_retirada_agendada' }),
    nao_retirada: t({ id: 'reservation.stage.nao_retirada' }),
    cancelada_leitor: t({ id: 'reservation.stage.cancelada_leitor' }),
    cancelada_biblioteca: t({ id: 'reservation.stage.cancelada_biblioteca' }),
    expirada: t({ id: 'reservation.stage.expirada' }),
  };

  const stage = String(r.workflow_stage_effective || r.status || '').trim();
  const stageLabel = WORKFLOW_LABELS[stage] || stage || '—';
  const proposedBy = r.pickup_proposed_by || null;
  const iterCount = r.negotiation_iteration_count ?? 0;
  const MAX_ITER = 3;

  // PATCH 09/05/2026 paquet 5b : refactor sémantique v3.
  // La négociation se déroule dans retirada_a_combinar (forme verbale),
  // plus dans retirada_agendada/re-retirada_agendada qui sont devenus
  // respectivement le stage d'aboutissement verrouillé et un fossile déprécié.
  const inNegotiationStage = stage === 'retirada_a_combinar';
  // PATCH paquet 5b : retirada_agendada = créneau verrouillé, post-négociation.
  // Pas de boutons négociation, juste un message d'orientation.
  const isLockedSlot = stage === 'retirada_agendada';
  const bibliotaProposed = inNegotiationStage && proposedBy === 'biblio';
  const leitorAlreadyProposed = inNegotiationStage && proposedBy === 'leitor';
  const counterMaxReached = iterCount >= MAX_ITER;
  // Le bouton "Propor outro horário" est désactivé/caché quand :
  //   - compteur saturé (limite atteinte)
  //   - le wrapper RPC le rejettera de toute façon avec un code d'erreur clair
  // Note : on n'affiche pas l'état "biblio a désactivé reservation_allow_reader_counter_proposal"
  // côté frontend en pré-vérification, parce que la vue UI ne l'expose pas.
  // Si l'utilisateur clique malgré tout, le wrapper RPC renvoie une erreur lisible.
  const canCounterPropose = bibliotaProposed && !counterMaxReached;

  // Annulation : possible tant que le stage n'est pas terminal
  const TERMINAL_STAGES = ['cancelada_leitor', 'cancelada_biblioteca', 'expirada', 'retirada_efetivada', 'liberada_para_circulacao', 'convertida_em_emprestimo'];
  const canCancel = !TERMINAL_STAGES.includes(stage) && !['cancelada_leitor', 'cancelada_biblioteca', 'expirada'].includes(r.status);

  // Form accordion ouvert pour cette ligne ?
  const isFormOpen = negotiationForm?.reservaId === r.reserva_id
                  && negotiationForm?.lineNo === r.line_no;

  return (
    <div className="ab-conta-item ab-conta-item--reservation">
      <div className="ab-conta-item__main">
        <Link to={`/livro/${r.book_id}`} className="ab-conta-item__title">
          {r.titulo || r.bib_ref || '—'}
        </Link>
        <span className="ab-conta-item__meta">
          ref: {r.bib_ref || '—'} · {r.rotulo || ''} · {r.library_name || ''}
        </span>
        <span className="ab-conta-item__status" data-stage={stage}>
          {stageLabel}
          {/* Badge négociation symétrique paquet 4 */}
          {inNegotiationStage && proposedBy && (
            <span style={{ marginLeft: 8 }}>
              <NegotiationStateBadge
                proposedBy={proposedBy}
                iterationCount={iterCount}
                stage={stage}
                viewerRole="reader"
              />
            </span>
          )}
        </span>

        {/* Próxima etapa (texte d'orientation) */}
        {stage === 'solicitada' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#60a5fa' }}>{t({ id: 'reservation.nextStep.solicitada' })}</span>}
        {stage === 'em_preparacao' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#60a5fa' }}>{t({ id: 'reservation.nextStep.em_preparacao' })}</span>}
        {stage === 'pronta_para_retirada' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#4ade80' }}>{t({ id: 'reservation.nextStep.pronta_para_retirada' })}</span>}
        {inNegotiationStage && bibliotaProposed && !counterMaxReached && (
          <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#fbbf24' }}>
            {t({ id: 'reservation.nextStep.bibliotaProposed' })}
          </span>
        )}
        {inNegotiationStage && leitorAlreadyProposed && (
          <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#fbbf24' }}>
            {t({ id: 'reservation.nextStep.leitorProposed' }, { count: iterCount, max: MAX_ITER })}
          </span>
        )}
        {/* PATCH 09/05/2026 paquet 5b : sémantique v3.
            retirada_agendada = créneau verrouillé après confirmation mutuelle,
            avant transition vers pronta_para_retirada. Message vert positif. */}
        {isLockedSlot && (
          <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#4ade80' }}>
            {t({ id: 'reservation.nextStep.retirada_agendada' })}
          </span>
        )}
        {stage === 'nao_retirada' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#f87171' }}>{t({ id: 'reservation.nextStep.nao_retirada' })}</span>}

        {/* Créneau proposé */}
        {r.pickup_scheduled_for && inNegotiationStage && (
          <span className="ab-conta-item__detail">
            {bibliotaProposed
              ? t({ id: 'reservation.pickup.proposedByLibrary' }, { date: fmtDate(r.pickup_scheduled_for) })
              : leitorAlreadyProposed
                ? t({ id: 'reservation.pickup.proposedByYou' }, { date: fmtDate(r.pickup_scheduled_for) })
                : t({ id: 'reservation.pickup.scheduled' }, { date: fmtDate(r.pickup_scheduled_for) })}
          </span>
        )}
        {r.pickup_scheduled_for && !inNegotiationStage && (
          <span className="ab-conta-item__detail">
            {t({ id: 'reservation.pickup.scheduled' }, { date: fmtDate(r.pickup_scheduled_for) })}
          </span>
        )}

        {/* Message spécifique : compteur saturé */}
        {counterMaxReached && bibliotaProposed && (
          <span className="ab-conta-item__detail" style={{ color: '#f87171', fontStyle: 'italic', marginTop: 6 }}>
            {t({ id: 'reservation.negotiation.maxIterationsReached' })}
          </span>
        )}

        {/* PATCH 09/05/2026 paquet 5d : workflow_note MASQUÉE côté lecteur.
            Cause : workflow_note contient des notes d'audit machine-parseables
            (ex: "[autoconf-by-reader] 2026-05-08T23:47:33Z — créneau verrouillé
            (retirada_agendada) après proposition biblio") rédigées en français
            et destinées au staff/debug, pas au lecteur·rice.

            Décision politique (option C ratifiée) : à terme, séparer le champ
            actuel en `audit_note` (interne, jamais affiché lecteur) et
            `reader_visible_note` (communication intentionnelle staff→lecteur).
            Ce refactor sera traité dans un paquet dédié. En attendant on masque
            purement et simplement workflow_note côté lecteur — c'est neutre :
            quand le refactor sera fait, on remplacera ce bloc par un affichage
            de `reader_visible_note`, sans perte de visibilité réelle pour le
            lecteur·rice (rien d'intentionnellement adressé n'est masqué). */}
      </div>

      {/* Actions selon l'état de négociation */}
      <div className="ab-conta-item__actions">
        {/* État 1 : biblio a proposé, le lecteur·rice peut répondre */}
        {bibliotaProposed && (
          <>
            <button className="ab-button ab-button--mini"
              onClick={() => onConfirmPickup(r.reserva_id, r.line_no)}>
              {t({ id: 'reservation.action.acceptThisSlot' })}
            </button>
            {canCounterPropose && (
              <button className="ab-button ab-button--secondary ab-button--mini"
                onClick={() => isFormOpen
                  ? onCloseCounterProposalForm()
                  : onOpenCounterProposalForm(r.reserva_id, r.line_no, r.pickup_scheduled_for)}>
                {isFormOpen
                  ? t({ id: 'reservation.action.closeForm' })
                  : t({ id: 'reservation.action.proposeOtherSlot' })}
              </button>
            )}
          </>
        )}

        {/* État 2 : le lecteur·rice a déjà contre-proposé, attend la biblio */}
        {leitorAlreadyProposed && (
          <button className="ab-button ab-button--secondary ab-button--mini"
            onClick={() => isFormOpen
              ? onCloseCounterProposalForm()
              : onOpenCounterProposalForm(r.reserva_id, r.line_no, r.pickup_scheduled_for)}>
            {isFormOpen
              ? t({ id: 'reservation.action.closeForm' })
              : t({ id: 'reservation.action.modifyMyProposal' })}
          </button>
        )}

        {/* Cancel : disponible dans tous les états non-terminaux */}
        {canCancel && (
          <button className="ab-button ab-button--mini ab-button--danger"
            onClick={() => onCancel(r.reserva_id)}>
            {t({ id: 'reservation.action.cancel' })}
          </button>
        )}
      </div>

      {/* Panneau accordion : mini-form de contre-proposition */}
      {isFormOpen && (
        <div className="ab-conta-item__counter-form" style={{
          gridColumn: '1 / -1',
          marginTop: 12,
          padding: '12px 14px',
          background: 'rgba(251,191,36,.08)',
          border: '1px solid rgba(251,191,36,.3)',
          borderRadius: 6,
          display: 'flex',
          flexDirection: 'column',
          gap: 10,
        }}>
          <div style={{ fontSize: '.92rem', fontWeight: 600 }}>
            {leitorAlreadyProposed
              ? t({ id: 'reservation.counterProposeForm.modifyTitle' })
              : t({ id: 'reservation.counterProposeForm.title' })}
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <label style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
              {t({ id: 'reservation.counterProposeForm.datetime' })}
            </label>
            <input
              type="datetime-local"
              value={negotiationForm.datetime}
              onChange={e => setNegotiationForm(prev => prev ? { ...prev, datetime: e.target.value } : prev)}
              className="ab-input"
              style={{ maxWidth: 250 }}
            />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <label style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
              {t({ id: 'reservation.counterProposeForm.note' })}
            </label>
            <input
              type="text"
              value={negotiationForm.note}
              onChange={e => setNegotiationForm(prev => prev ? { ...prev, note: e.target.value } : prev)}
              className="ab-input"
              placeholder={t({ id: 'reservation.counterProposeForm.notePlaceholder' })}
            />
          </div>

          <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
            <Button onClick={onSubmitCounterProposal}>
              {t({ id: 'reservation.counterProposeForm.submit' })}
            </Button>
            <Button variant="secondary" onClick={onCloseCounterProposalForm}>
              {t({ id: 'reservation.action.closeForm' })}
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

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
