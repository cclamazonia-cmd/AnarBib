// AnarBib — Panneau, onglet Consultations (E6, lot C, 12/10/2026).
// Déplacé tel quel depuis PanelPage.jsx : l'état des deux modales (planifier,
// annuler avec motif) et les gestes — api.advance_consulta par
// setConsultaWorkflow, qui recharge les consultations et signale par le toast
// (ou relève, pour que la modale montre le message précis du serveur).
import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { assertRpcOk } from '@/lib/rpcStatus.js';

export function usePanelConsultas({ t, loadConsultas, notifyError }) {
  // Paquet 27.A.4 (5.B) : modal Agender consulta avec date+heure+note.
  const [scheduleTarget, setScheduleTarget] = useState(null);
  const [scheduleForm, setScheduleForm] = useState({ date: '', startsAt: '', endsAt: '', note: '' });
  const [scheduling, setScheduling] = useState(false);
  const [scheduleError, setScheduleError] = useState('');

  // ── Consultation workflow ─────────────────────────────

  // Paquet 27.A.3 (5.A) : migration vers wrapper api.advance_consulta (SECURITY INVOKER).
  // scheduleParams optionnel : { startsAt, endsAt, timezone } pour stage 'consulta_agendada'.
  async function setConsultaWorkflow(consultaId, lineNo, stage, note, scheduleParams, opts = {}) {
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
      const { data: rpcData, error } = await supabase.schema('api').rpc('advance_consulta', params);
      if (error) throw error;
      assertRpcOk(rpcData);
      loadConsultas();
    } catch (e) {
      // opts.rethrow : laisse l'appelant (modal de planification) afficher inline
      // le message précis du backend (fenêtre, durée, heures pleines, capacité…)
      // au lieu d'un toast générique.
      if (opts.rethrow) throw e;
      notifyError(localizeError(e, t, 'panel.error.consultaWorkflow'), e);
    }
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
        { startsAt: startsIso, endsAt: endsIso, timezone: tz },
        { rethrow: true }
      );
      setScheduleTarget(null);
    } catch (e) {
      // Surface le message précis du backend (hors fenêtre, durée 1–4h, heures
      // pleines/demies, capacité…) au lieu du toast générique. localizeError sans
      // fallback : les messages délibérés (P0001) passent, le jargon est masqué.
      setScheduleError(localizeError(e, t));
    } finally {
      setScheduling(false);
    }
  }

  return { setConsultaWorkflow, openScheduleModal, openCancelModal,
    scheduleTarget, scheduleForm, setScheduleForm, scheduling, scheduleError, closeScheduleModal, handleScheduleSubmit, cancelTarget, cancelForm, setCancelForm, cancelling, cancelError, closeCancelModal, handleCancelSubmit };
}
