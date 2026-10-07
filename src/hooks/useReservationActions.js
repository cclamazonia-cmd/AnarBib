import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { assertRpcOk } from '../lib/rpcStatus.js';

// ═══════════════════════════════════════════════════════════
// AnarBib — les gestes de réservation et de consultation de Mon compte (E6,
// AccountPage lot 8, 07/10/2026). Sortis d'AccountPage.jsx tels quels, lignes
// déplacées par script : réserver par référence (avec ses validations métier),
// annuler, confirmer ou contre-proposer un créneau de retrait, confirmer ou
// refuser un créneau de consultation, annuler une consultation, effacer une
// annulation. Les neuf états qui n'appartiennent qu'à ces gestes (référence
// saisie, message, cibles des modales, note de refus, sabliers, contre-
// proposition ouverte) viennent avec eux ; la page garde les données (profil,
// état du service, réservations, emprunts) et le rechargement, qu'elle passe
// en entrée. La page appelle ce hook après loadData et avant tout retour
// anticipé. Les noms sont ceux de la page.
// ═══════════════════════════════════════════════════════════

export function useReservationActions({ user, profile, serviceState, reservations, loans, loadData }) {
  const { formatMessage: t } = useIntl();
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
      // DETTE B15 LEVÉE (31/08/2026). Le `let error` partagé ne retenait que
      // l'erreur : la charge utile des deux branches était jetée à la
      // destructuration, donc le `ok` de create_consulta_local était
      // INATTEIGNABLE. Lier `data` à côté suffisait — la fonction n'avait pas
      // besoin d'être restructurée.
      // Ce que ça corrige, exactement : vérifié en base le 31/08,
      // api.create_consulta_local rend `{ok:true, consulta_id}` et LÈVE sur
      // refus. Aucune panne vivante ici, donc ; c'est une garde de CONTRAT —
      // le jour où la fonction rendra `ok:false`, l'écran ne dira plus
      // « consultation enregistrée » à quelqu'un dont rien n'a été créé.
      // `assertRpcOk` ne fait rien quand la charge utile n'a pas de `ok`, donc
      // la branche réservation la traverse sans bruit.
      let data, error;
      if (isConsultation) {
        ({ data, error } = await supabase.schema('api').rpc('create_consulta_local', {
          p_user_id: user.id,
          p_holding_ids: holdingIds,
          p_notes: '@@note:account.reserve.noteConsult', // Route B : code système (décodé à l'affichage)
        }));
      } else {
        ({ data, error } = await supabase.rpc('fn_v2_create_reserva_by_holdings', {
          p_user_id: user.id,
          p_holding_ids: holdingIds,
          p_notes: '@@note:account.reserve.noteLoan', // Route B : code système (décodé à l'affichage)
        }));
      }
      if (error) throw error;
      assertRpcOk(data);

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

  const handleDismissConsultaCancelled = async (c) => {
    if (!c?.consulta_id) return;
    try {
      const { data: rpcData, error } = await supabase.schema('api').rpc('dismiss_consulta_cancelled', {
        p_consulta_id: c.consulta_id,
        p_line_nos: [c.line_no || 1],
        p_note: null
      });
      if (error) {
        console.error('dismiss_consulta_cancelled error:', error);
        return;
      }
      assertRpcOk(rpcData);
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
      const { data: rpcData, error } = await supabase.schema('api').rpc('cancel_consulta_as_reader', {
        p_consulta_id: cancelTarget.consulta_id,
        p_line_nos: [cancelTarget.line_no || 1],
      });
      if (error) {
        console.error('cancel_consulta_as_reader error:', error);
        alert(t({ id: 'common.errorPrefix' }, { message: localizeError(error, t) }));
        return;
      }
      assertRpcOk(rpcData);
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
      const { data: rpcData, error } = await supabase.schema('api').rpc('reply_consulta_schedule', {
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
      assertRpcOk(rpcData);
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
      const { data: rpcData, error } = await supabase.schema('api').rpc('reply_consulta_schedule', {
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
      assertRpcOk(rpcData);
      setRefuseTarget(null);
      await loadData();
    } catch (err) {
      console.error('reply_consulta_schedule (refuse) exception:', err);
      alert(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
    } finally {
      setReplying(false);
    }
  };

  return {
    reserveRef, setReserveRef, reserveMsg, setReserveMsg, cancelTarget, setCancelTarget,
    cancelling, setCancelling, refuseTarget, setRefuseTarget, refuseNote, setRefuseNote,
    refuseError, setRefuseError, replying, setReplying, negotiationForm, setNegotiationForm,
    handleReserve, cancelReservation, handleConfirmPickup, openCounterProposalForm,
    handleSubmitCounterProposal, handleDismissConsultaCancelled, handleCancelConsulta,
    handleConfirmSchedule, openRefuseModal, closeRefuseModal, handleRefuseSchedule,
  };
}
