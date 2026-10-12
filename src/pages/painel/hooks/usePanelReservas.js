// AnarBib — Panneau, onglet Réservations (E6, lot B, 12/10/2026).
// Déplacé tel quel depuis PanelPage.jsx : la sélection, le menu d'étape, le
// message d'action, le formulaire de contre-proposition et les sept gestes
// du personnel (api.advance_reservation, mark_no_show, confirm_pickup_v1,
// cancel_reservation_as_library, fn_confirm_pickup_slot_as_library,
// fn_propose_pickup_slot_as_library). Le crochet rappelle loadReservas /
// loadLoans et lit activeRes pour « tout sélectionner ».
import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

export function usePanelReservas({ t, activeRes, loadReservas, loadLoans }) {
  const [selectedRes, setSelectedRes] = useState(new Set());
  const [resStage, setResStage] = useState('');
  const [resNote, setResNote] = useState('');
  const [resSchedule, setResSchedule] = useState('');
  const [actionMsg, setActionMsg] = useState('');
  // PATCH 08/05/2026 paquet 3B : state pour le formulaire accordion de
  // contre-proposition staff. Un seul form ouvert à la fois (la ligne
  // qui matche reservaId+lineNo). null = aucune ligne en mode édition.
  // Champs datetime et note pré-remplis depuis le créneau actuel quand on
  // ouvre le form, mais éditables librement par le staff.
  const [negotiationForm, setNegotiationForm] = useState(null);
  // Forme attendue : { reservaId, lineNo, datetime: 'YYYY-MM-DDTHH:MM', note: '' }

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

  return { selectedRes, resStage, setResStage, resNote, setResNote, resSchedule, setResSchedule, actionMsg,
    negotiationForm, setNegotiationForm, applyResWorkflow, cancelSelectedRes, confirmSelectedPickup,
    confirmReaderSlot, openCounterProposalForm, submitCounterProposal, cancelWithReason, toggleRes, toggleAllRes };
}
