import { handleEmprestimoOld, handleReservaCriadaOld } from "../domain/legacy.ts";
import { handleEmprestimoDevolucaoEvent, handleEmprestimoV2, handleEmprestimoV2Reminder } from "../domain/emprestimos.ts";
import { handleProfileNotice } from "../domain/profiles.ts";
import { handleReservaCriadaV2, handleReservaPickupReplyEvent, handleReservaV2StatusChange, handleReservaV2WorkflowEvent } from "../domain/reservas.ts";
import { handleConsultaCriadaV2, handleConsultaV2LifecycleEvent, handleConsultaV2WorkflowEvent } from "../domain/consultas.ts";
import { handleTeamEvent } from "../domain/team.ts";
import { handleNetworkEvent } from "../domain/network.ts";
import { handleReaderMessageEvent } from "../domain/reader-message.ts";
import { handleRgpdPurgeWarning } from "../domain/rgpd.ts";
export async function dispatchNotifyEvent(event, recordId, payload) {
  // Events team.* (gouvernance biblio locale) - handler dedie, lit team_notification_outbox par recordId
  if (event.startsWith("team.")) return await handleTeamEvent(recordId);
  // Events network.* (gouvernance reseau transverse) - handler dedie, meme outbox que team.*
  if (event.startsWith("network.")) return await handleNetworkEvent(recordId);
  // Events reader_message* (recad libre lecteur -> sa biblio) - handler dedie, lit reader_library_messages par recordId
  if (event.startsWith("reader_message")) return await handleReaderMessageEvent(recordId);
  if (event === "reserva_criada") return await handleReservaCriadaOld(recordId);
  // TR-1 (#153.A) : 'emprestimo_prorrogado' retire de la branche legacy.
  // L'evenement n'est plus emis par la base : le seul emetteur de prorogation,
  // le trigger trg_notify_emprestimo_prorrogacao, emet 'emprestimo_v2_prorrogado'.
  // 'emprestimo_prorrogado' etait donc du code mort ici (et dans la branche v2).
  // Note : la branche legacy handleEmprestimoOld route encore emprestimo_criado,
  // emprestimo_devolvido, lembrete_devolucao_*, aviso_atraso_* — leur emission
  // n'a pas ete instruite ; voir la dette notee au dossier-cadre #153.
  if (event === "emprestimo_criado" || event === "emprestimo_devolvido" || event.startsWith("lembrete_devolucao_") || event.startsWith("aviso_atraso_")) return await handleEmprestimoOld(recordId, event);
  if (event === "reserva_v2_criada") return await handleReservaCriadaV2(recordId);
  if ([
    "reserva_v2_recusada",
    "reserva_v2_cancelada_staff",
    "reserva_v2_cancelada_reader",
    "reserva_cancelada_biblioteca",
    "reserva_cancelada_leitor",
    "reserva_expirada",
    "expirada",
    "reserva_convertida_em_emprestimo",
    "convertida_em_emprestimo"
  ].includes(event)) return await handleReservaV2StatusChange(recordId, event);
  if ([
    "em_preparacao",
    "reserva_em_preparacao",
    "reserva_retirada_a_combinar",
    "retirada_a_combinar",
    "reserva_retirada_agendada",
    "retirada_agendada",
    "reserva_retirada_reagendada",
    "retirada_reagendada",
    "reserva_pronta_para_retirada",
    "pronta_para_retirada",
    "reserva_nao_retirada",
    "retirada_nao_realizada",
    "retirada_no_show",
    "reserva_liberada_para_circulacao",
    "liberada_para_circulacao"
  ].includes(event)) return await handleReservaV2WorkflowEvent(recordId, event, payload);
  if ([
    "reserva_leitor_confirma_horario",
    "retirada_confirmada_leitor",
    "reserva_leitor_recusa_horario",
    "retirada_recusada_leitor"
  ].includes(event)) return await handleReservaPickupReplyEvent(recordId, event, payload);
  if ([
    "emprestimo_devolucao_agendada",
    "emprestimo_devolucao_cancelada",
    "emprestimo_devolucao_nao_realizada"
  ].includes(event)) return await handleEmprestimoDevolucaoEvent(recordId, event, payload);
  // TR-2 (#153.A) : payload transmis a handleEmprestimoV2 — la RPC de conversion
  // y place suppress_user_mail pour que le handler saute le mail lecteur·rice
  // (le mail admin, lui, reste emis). Auparavant payload n'etait pas transmis.
  // TR-1 (#153.A) : 'emprestimo_prorrogado' retire du tableau et la
  // normalisation ternaire associee supprimee — evenement plus jamais emis.
  if ([
    "emprestimo_v2_criado",
    "emprestimo_v2_prorrogado",
    "emprestimo_v2_devolvido",
    "emprestimo_v2_parcialmente_devolvido",
    "emprestimo_v2_devolvido_apos_parcial"
  ].includes(event)) return await handleEmprestimoV2(recordId, event, payload);
  if ([
    "lembrete_v2_devolucao_5d",
    "lembrete_v2_devolucao_3d",
    "lembrete_v2_devolucao_hoje",
    "aviso_v2_atraso_1d",
    "aviso_v2_atraso_7d",
    "aviso_v2_atraso_30d"
  ].includes(event)) return await handleEmprestimoV2Reminder(recordId, event);
  // ===== Consultas locais - paquet 26 =====================================
  if (event === "consulta_v2_criada") return await handleConsultaCriadaV2(recordId);
  if (["consulta_v2_realizada","consulta_v2_cancelada","consulta_v2_expirada"].includes(event)) return await handleConsultaV2LifecycleEvent(recordId, event, payload);
  if (["consulta_v2_em_preparacao","consulta_v2_agendada","consulta_v2_nao_compareceu","consulta_v2_resposta_creneau"].includes(event)) return await handleConsultaV2WorkflowEvent(recordId, event, payload);
  if (event === "profile_notice") return await handleProfileNotice(recordId);
  // ===== Préavis RGPD purge (Spec §7.1, 31/05/2026) ======================
  // Couvre rgpd_purge_warning_loans / _reservations / _consultations
  if (event.startsWith("rgpd_purge_warning_")) return await handleRgpdPurgeWarning(recordId, event);
  return null;
}
