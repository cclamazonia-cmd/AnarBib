import { getPayloadValue } from "./payload.ts";
const WF_LABELS = {
  solicitada: "Reserva recebida",
  em_preparacao: "Livro em preparação",
  retirada_a_combinar: "Retirada a combinar",
  retirada_agendada: "Retirada agendada",
  "re-retirada_agendada": "Retirada reagendada",
  pronta_para_retirada: "Livro pronto para retirada",
  retirada_efetivada: "Retirada efetuada",
  cancelada_leitor: "Cancelada pelo leitor",
  cancelada_biblioteca: "Cancelada pela biblioteca",
  nao_retirada: "Retirada não realizada",
  liberada_para_circulacao: "Item devolvido à circulação",
  expirada: "Reserva expirada"
};
export function workflowStageLabel(s) {
  const v = String(s || "").trim();
  return WF_LABELS[v] || v;
}
export function pickupReplyLabel(s) {
  const v = String(s || "").trim();
  if (v === "confirmado_leitor") return "Horário confirmado pelo leitor";
  if (v === "recusado_leitor") return "Leitor não pode nesse horário";
  return "";
}
const WE_MAP = {
  em_preparacao: "em_preparacao",
  reserva_em_preparacao: "em_preparacao",
  reserva_retirada_a_combinar: "retirada_a_combinar",
  retirada_a_combinar: "retirada_a_combinar",
  reserva_retirada_agendada: "retirada_agendada",
  retirada_agendada: "retirada_agendada",
  reserva_retirada_reagendada: "retirada_reagendada",
  retirada_reagendada: "retirada_reagendada",
  reserva_pronta_para_retirada: "pronta_para_retirada",
  pronta_para_retirada: "pronta_para_retirada",
  reserva_nao_retirada: "retirada_no_show",
  retirada_nao_realizada: "retirada_no_show",
  retirada_no_show: "retirada_no_show",
  reserva_liberada_para_circulacao: "liberada_para_circulacao",
  liberada_para_circulacao: "liberada_para_circulacao"
};
export function normalizeReservaWorkflowEvent(e) {
  return WE_MAP[String(e || "").trim()] || "";
}
export function normalizeReservaPickupReplyEvent(e) {
  const s = String(e || "").trim();
  if (s === "reserva_leitor_confirma_horario" || s === "retirada_confirmada_leitor") return "retirada_confirmada_leitor";
  if (s === "reserva_leitor_recusa_horario" || s === "retirada_recusada_leitor") return "retirada_recusada_leitor";
  return "";
}
const SC_MAP = {
  reserva_v2_cancelada_staff: "reserva_cancelada_biblioteca",
  reserva_cancelada_biblioteca: "reserva_cancelada_biblioteca",
  reserva_v2_cancelada_reader: "reserva_cancelada_leitor",
  reserva_cancelada_leitor: "reserva_cancelada_leitor",
  reserva_expirada: "reserva_expirada",
  expirada: "reserva_expirada",
  reserva_convertida_em_emprestimo: "reserva_convertida_em_emprestimo",
  convertida_em_emprestimo: "reserva_convertida_em_emprestimo"
};
export function normalizeReservaStatusChangeEvent(e) {
  return SC_MAP[String(e || "").trim()] || String(e || "").trim();
}
const SF_MAP = {
  retirada_a_combinar: "retirada_a_combinar",
  retirada_agendada: "retirada_agendada",
  retirada_reagendada: "re-retirada_agendada",
  pronta_para_retirada: "pronta_para_retirada",
  retirada_no_show: "nao_retirada",
  liberada_para_circulacao: "liberada_para_circulacao"
};
export function workflowStageFromEvent(e) {
  return SF_MAP[normalizeReservaWorkflowEvent(e)] || "";
}
export function actorRoleFromPayload(p) {
  const r = String(getPayloadValue(p, "actor_role") || p?.actor_role || "").trim().toLowerCase();
  if ([
    "biblioteca",
    "staff",
    "librarian",
    "admin"
  ].includes(r)) return "biblioteca";
  if ([
    "leitor",
    "reader",
    "usuario",
    "usuário",
    "user"
  ].includes(r)) return "leitor";
  return null;
}
export function actionKindFromPayload(p) {
  const r = String(getPayloadValue(p, "action_kind") || "").trim().toLowerCase();
  if (r === "reagendamento") return "reagendamento";
  if (r === "agendamento_inicial") return "agendamento_inicial";
  return null;
}

// ===== Consulta stage labels (pt-BR) =========================================

const CON_LIFECYCLE_LABELS: Record<string, string> = {
  ativa: "Consulta solicitada",
  consultada: "Consulta realizada",
  cancelada_leitor: "Cancelada pelo leitor",
  cancelada_biblioteca: "Cancelada pela biblioteca",
  expirada: "Consulta expirada"
};

const CON_WORKFLOW_LABELS: Record<string, string> = {
  solicitada: "Consulta solicitada",
  em_preparacao: "Consulta em preparação",
  consulta_agendada: "Horário agendado",
  consulta_realizada: "Consulta realizada",
  nao_compareceu: "Não compareceu",
  cancelada_leitor: "Cancelada pelo leitor",
  cancelada_biblioteca: "Cancelada pela biblioteca",
  expirada: "Expirada"
};

export function consultaLifecycleLabel(s: string): string {
  const v = String(s || "").trim();
  return CON_LIFECYCLE_LABELS[v] || v;
}

export function consultaWorkflowLabel(s: string): string {
  const v = String(s || "").trim();
  return CON_WORKFLOW_LABELS[v] || v;
}

export function consultaScheduleReplyLabel(s: string): string {
  const v = String(s || "").trim();
  if (v === "confirmado_leitor") return "Horário confirmado pelo leitor";
  if (v === "recusado_leitor") return "Leitor não pode nesse horário";
  return "";
}

// ===== Consulta lifecycle event normalization ================================

const CON_LC_MAP: Record<string, string> = {
  consulta_v2_criada: "consulta_v2_criada",
  consulta_v2_realizada: "consulta_v2_realizada",
  consulta_v2_cancelada: "consulta_v2_cancelada",
  consulta_v2_expirada: "consulta_v2_expirada"
};

export function normalizeConsultaLifecycleEvent(e: string): string {
  return CON_LC_MAP[String(e || "").trim()] || "";
}

// ===== Consulta workflow event normalization =================================

const CON_WE_MAP: Record<string, string> = {
  consulta_v2_agendada: "consulta_agendada",
  consulta_v2_resposta_creneau: "resposta_creneau"
};

export function normalizeConsultaWorkflowEvent(e: string): string {
  return CON_WE_MAP[String(e || "").trim()] || "";
}

// ===== Helpers payload =======================================================

export function consultaCancelledByFromPayload(p: NotifyPayload | null | undefined): string | null {
  const v = String(getPayloadValue(p, "cancelled_by") || "").trim().toLowerCase();
  if (v === "leitor" || v === "reader") return "leitor";
  if (v === "biblioteca" || v === "biblio" || v === "library" || v === "staff") return "biblioteca";
  return null;
}

export function consultaScheduleReplyFromPayload(p: NotifyPayload | null | undefined): string | null {
  const v = String(getPayloadValue(p, "schedule_reply_status") || "").trim();
  if (v === "confirmado_leitor" || v === "recusado_leitor") return v;
  return null;
}