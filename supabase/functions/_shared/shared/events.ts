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
// F1 (01/10/2026) : seuls les noms que trg_notify_reserva_workflow_change émet.
// 'retirada_no_show' reste le nom INTERNE du stage de non-venue (valeur ici,
// clé de SF_MAP plus bas), pas un événement.
const WE_MAP = {
  em_preparacao: "em_preparacao",
  retirada_a_combinar: "retirada_a_combinar",
  retirada_agendada: "retirada_agendada",
  pronta_para_retirada: "pronta_para_retirada",
  reserva_nao_retirada: "retirada_no_show",
  liberada_para_circulacao: "liberada_para_circulacao"
};
export function normalizeReservaWorkflowEvent(e) {
  return WE_MAP[String(e || "").trim()] || "";
}
const SC_MAP = {
  reserva_cancelada_biblioteca: "reserva_cancelada_biblioteca",
  reserva_cancelada_leitor: "reserva_cancelada_leitor",
  reserva_expirada: "reserva_expirada",
  reserva_convertida_em_emprestimo: "reserva_convertida_em_emprestimo"
};
export function normalizeReservaStatusChangeEvent(e) {
  return SC_MAP[String(e || "").trim()] || String(e || "").trim();
}
const SF_MAP = {
  retirada_a_combinar: "retirada_a_combinar",
  retirada_agendada: "retirada_agendada",
  pronta_para_retirada: "pronta_para_retirada",
  retirada_no_show: "nao_retirada",
  liberada_para_circulacao: "liberada_para_circulacao"
};
export function workflowStageFromEvent(e) {
  return SF_MAP[normalizeReservaWorkflowEvent(e)] || "";
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
  consulta_v2_resposta_creneau: "resposta_creneau",
  consulta_v2_em_preparacao: "em_preparacao",
  consulta_v2_nao_compareceu: "nao_compareceu"
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