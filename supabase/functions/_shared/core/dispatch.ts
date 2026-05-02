import type { NotifyPayload } from "./types.ts";
import { handleEmprestimoOld, handleReservaCriadaOld } from "../domain/legacy.ts";
import { handleEmprestimoDevolucaoEvent, handleEmprestimoV2, handleEmprestimoV2Reminder } from "../domain/emprestimos.ts";
import { handleProfileNotice } from "../domain/profiles.ts";
import { handleReservaCriadaV2, handleReservaPickupReplyEvent, handleReservaV2StatusChange, handleReservaV2WorkflowEvent } from "../domain/reservas.ts";

export async function dispatchNotifyEvent(event: string, recordId: number, payload?: NotifyPayload | null): Promise<Record<string, unknown> | null> {
  if (event === "reserva_criada") return await handleReservaCriadaOld(recordId);
  if (event === "emprestimo_criado" || event === "emprestimo_prorrogado" || event === "emprestimo_devolvido" || event.startsWith("lembrete_devolucao_") || event.startsWith("aviso_atraso_")) return await handleEmprestimoOld(recordId, event);
  if (event === "reserva_v2_criada") return await handleReservaCriadaV2(recordId);
  if (["reserva_v2_recusada","reserva_v2_cancelada_staff","reserva_v2_cancelada_reader","reserva_cancelada_biblioteca","reserva_cancelada_leitor","reserva_expirada","expirada","reserva_convertida_em_emprestimo","convertida_em_emprestimo"].includes(event)) return await handleReservaV2StatusChange(recordId, event);
  if (["reserva_retirada_a_combinar","retirada_a_combinar","reserva_retirada_agendada","retirada_agendada","reserva_retirada_reagendada","retirada_reagendada","reserva_pronta_para_retirada","pronta_para_retirada","reserva_nao_retirada","retirada_nao_realizada","retirada_no_show","reserva_liberada_para_circulacao","liberada_para_circulacao"].includes(event)) return await handleReservaV2WorkflowEvent(recordId, event, payload);
  if (["reserva_leitor_confirma_horario","retirada_confirmada_leitor","reserva_leitor_recusa_horario","retirada_recusada_leitor"].includes(event)) return await handleReservaPickupReplyEvent(recordId, event, payload);
  if (["emprestimo_devolucao_agendada","emprestimo_devolucao_cancelada","emprestimo_devolucao_nao_realizada"].includes(event)) return await handleEmprestimoDevolucaoEvent(recordId, event, payload);
  if (["emprestimo_v2_criado","emprestimo_v2_prorrogado","emprestimo_prorrogado","emprestimo_v2_devolvido"].includes(event)) return await handleEmprestimoV2(recordId, event === "emprestimo_prorrogado" ? "emprestimo_v2_prorrogado" : event);
  if (["lembrete_v2_devolucao_5d","lembrete_v2_devolucao_3d","lembrete_v2_devolucao_hoje","aviso_v2_atraso_1d","aviso_v2_atraso_7d","aviso_v2_atraso_30d"].includes(event)) return await handleEmprestimoV2Reminder(recordId, event);
  if (event === "profile_notice") return await handleProfileNotice(recordId);
  return null;
}
