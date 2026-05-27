import { supabaseAdmin } from "../core/env.ts";
export async function getReservaDetalhes(id) {
  const { data, error } = await supabaseAdmin.from("v_reservas_detalhes").select("*").eq("reserva_id", id).maybeSingle();
  if (error) throw error;
  if (!data) throw new Error("Reserva não encontrada.");
  return data;
}
export async function getReservaV2Bundle(id) {
  const { data: reserva, error: e1 } = await supabaseAdmin.from("reservas_v2").select("id,user_id,library_id,created_at,updated_at,notes,status_global").eq("id", id).maybeSingle();
  if (e1) throw e1;
  if (!reserva) throw new Error("Reserva não encontrada.");
  const { data: profile, error: e2 } = await supabaseAdmin.from("profiles").select("id,email,first_name,last_name,phone,address,consent_email,preferred_language").eq("id", reserva.user_id).maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");
  const { data: items, error: e3 } = await supabaseAdmin.schema("api").from("reserva_itens_followup_ui").select("reserva_id,line_no,sub_id,bib_ref,autor,titulo,editora,ano,item_status,expires_at,cancelled_at,expired_at").eq("reserva_id", id).order("line_no", {
    ascending: true
  });
  if (e3) throw e3;
  return {
    reserva: reserva,
    profile: profile,
    items: items || []
  };
}
export async function getReservaWorkflowBundle(id, lineNos) {
  const { data: reserva, error: e1 } = await supabaseAdmin.from("reservas_v2").select("id,user_id,library_id,created_at,updated_at,notes,status_global").eq("id", id).maybeSingle();
  if (e1) throw e1;
  if (!reserva) throw new Error("Reserva não encontrada.");
  const { data: profile, error: e2 } = await supabaseAdmin.from("profiles").select("id,email,first_name,last_name,phone,address,consent_email,preferred_language").eq("id", reserva.user_id).maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");
  let q = supabaseAdmin.schema("api").from("reserva_itens_followup_ui").select("reserva_id,user_id,line_no,sub_id,bib_ref,autor,titulo,rotulo,item_status,workflow_stage_effective,workflow_note,pickup_scheduled_for,pickup_reply_status,pickup_reply_note,pickup_reply_at,pickup_proposed_by,negotiation_iteration_count").eq("reserva_id", id).order("line_no", {
    ascending: true
  });
  if (lineNos?.length) q = q.in("line_no", lineNos);
  const { data: items, error: e3 } = await q;
  if (e3) throw e3;
  return {
    reserva: reserva,
    profile: profile,
    items: (items || []).map((it)=>({
        line_no: Number(it.line_no || 0) || undefined,
        sub_id: String(it.sub_id || "").trim() || null,
        bib_ref: String(it.bib_ref || "").trim() || null,
        titulo: String(it.titulo || "").trim() || null,
        autor: String(it.autor || "").trim() || null,
        rotulo: String(it.rotulo || "").trim() || null,
        item_status: String(it.item_status || "").trim() || null,
        workflow_stage_effective: String(it.workflow_stage_effective || "").trim() || null,
        workflow_note: String(it.workflow_note || "").trim() || null,
        pickup_scheduled_for: String(it.pickup_scheduled_for || "").trim() || null,
        pickup_reply_status: String(it.pickup_reply_status || "").trim() || null,
        pickup_reply_note: String(it.pickup_reply_note || "").trim() || null,
        pickup_reply_at: String(it.pickup_reply_at || "").trim() || null,
        pickup_proposed_by: String(it.pickup_proposed_by || "").trim() || null,
        negotiation_iteration_count: typeof it.negotiation_iteration_count === 'number' ? it.negotiation_iteration_count : it.negotiation_iteration_count == null ? null : Number(it.negotiation_iteration_count) || 0
      }))
  };
}
// ---------------------------------------------------------------------------
// #153.D-1 (TR-3.3) — lecture du motif d'annulation biblio
// ---------------------------------------------------------------------------
// Le handler handleReservaV2StatusChange lisait le motif depuis reservas_v2.notes
// — colonne qui contient la note de *création* de la réservation, pas le motif
// d'annulation. Le motif réel est écrit par la RPC fn_v2_cancel_reserva_linhas_
// as_biblioteca dans reserva_item_workflow_v2.workflow_note, sur les lignes dont
// le workflow_stage est 'cancelada_biblioteca' (la RPC y met une valeur par
// défaut 'Cancelamento efetuado pela biblioteca.' si le motif saisi est vide —
// workflow_note n'est donc jamais NULL pour une annulation biblio).
// Une réservation a plusieurs lignes ; l'annulation biblio les passe toutes au
// même stage avec le même motif. On retourne le premier workflow_note non vide.
export async function getReservaCancelamentoBibliotecaMotivo(id) {
  const { data, error } = await supabaseAdmin.from("reserva_item_workflow_v2").select("workflow_note").eq("reserva_id", id).eq("workflow_stage", "cancelada_biblioteca").order("line_no", {
    ascending: true
  });
  if (error) throw error;
  for (const row of data || []){
    const note = String(row?.workflow_note || "").trim();
    if (note) return note;
  }
  return "";
}
// ---------------------------------------------------------------------------
// #153.D-1 (sous-tâche 4) — date d'échéance de l'emprunt issu d'une conversion
// ---------------------------------------------------------------------------
// L'événement reserva_convertida_em_emprestimo est émis au passage en
// 'retirada_efetivada' : l'emprunt et ses items emprestimo_itens_v2 existent
// alors déjà, avec reserva_id renseigné (lien réservation -> emprunt) et due_at.
// La date d'échéance effective est extended_until si une prorogation a eu lieu,
// sinon due_at (à la conversion extended_until est NULL, mais on applique la
// règle correcte par robustesse). On retourne la première ligne par line_no.
export async function getEmprestimoDueDateFromReserva(id) {
  const { data, error } = await supabaseAdmin.from("emprestimo_itens_v2").select("due_at,extended_until,line_no").eq("reserva_id", id).order("line_no", {
    ascending: true
  });
  if (error) throw error;
  for (const row of data || []){
    const due = String(row?.extended_until || row?.due_at || "").trim();
    if (due) return due;
  }
  return "";
}
