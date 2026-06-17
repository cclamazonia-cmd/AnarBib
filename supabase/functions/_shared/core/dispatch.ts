import { handleEmprestimoOld, handleReservaCriadaOld } from "../domain/legacy.ts";
import { handleEmprestimoDevolucaoEvent, handleEmprestimoV2, handleEmprestimoV2Reminder } from "../domain/emprestimos.ts";
import { handleReservaCriadaV2, handleReservaPickupReplyEvent, handleReservaV2StatusChange, handleReservaV2WorkflowEvent } from "../domain/reservas.ts";
import { handleConsultaCriadaV2, handleConsultaV2LifecycleEvent, handleConsultaV2WorkflowEvent } from "../domain/consultas.ts";
import { handleTeamEvent } from "../domain/team.ts";
import { handleNetworkEvent } from "../domain/network.ts";
import { handleReaderMessageEvent, handleLibraryMessageEvent } from "../domain/reader-message.ts";
import { handleRgpdPurgeWarning } from "../domain/rgpd.ts";
import { handleCotisationPayment, handleValidationConfirmed, handleMembershipValidationRequested, handleReaderIdentityAssigned } from "../domain/membership.ts";
import { handleMembershipRestriction } from "../domain/membership-restriction.ts";
import { handlePartnershipLifecycle, handleTransparenceEnabled, handleConfigExpanded } from "../domain/partnership.ts";
import { handleAuthorityEvent } from "../domain/authority.ts";
import { handleGazetteEvent } from "../domain/gazette.ts";
import { handleLettreEvent } from "../domain/lettre.ts";
import { handleEntraideRequestCircle } from "../domain/entraide.ts";
import { handleAssembleiaEvent } from "../domain/assembleia.ts";
export async function dispatchNotifyEvent(event, recordId, payload) {
  // Events team.* (gouvernance biblio locale) - handler dedie, lit team_notification_outbox par recordId
  if (event.startsWith("team.")) return await handleTeamEvent(recordId);
  // Events network.assembleia.* (AG du reseau, P3) - handler dedie, AVANT le network.* generique.
  if (event.startsWith("network.assembleia.")) return await handleAssembleiaEvent(recordId);
  // Events network.* (gouvernance reseau transverse) - handler dedie, meme outbox que team.*
  if (event.startsWith("network.")) return await handleNetworkEvent(recordId);
  // Events authority.* (atelier autorites, sous-paquet 1b) - handler dedie, lit
  // authority_proposal_notification_outbox par recordId ; fan-out (biblios
  // utilisatrices + admins reseau + proposeur) selon l'event.
  if (event.startsWith("authority.")) return await handleAuthorityEvent(recordId);
  // Events gazette.* (notifications Gazette) - handler dedie, lit
  // gazette_submission_notification_outbox par recordId. contribution.received
  // -> fede@anarbib.org ; draft.ready_for_review -> network_staff (fan-out).
  if (event.startsWith("gazette.")) return await handleGazetteEvent(recordId);
  // Events lettre.* (Lettre de la fédération, opt-in) - handler dédié, lit
  // lettre_notification_outbox par recordId. optin.confirm -> e-mail de confirmation 1-clic.
  if (event.startsWith("lettre.")) return await handleLettreEvent(recordId);
  // Events reader_message* (recad libre lecteur -> sa biblio) - handler dedie, lit reader_library_messages par recordId
  if (event.startsWith("reader_message")) return await handleReaderMessageEvent(recordId);
  // Events library_message* (reciproque biblio -> lecteur) - meme handler-famille, lit reader_library_messages par recordId
  if (event.startsWith("library_message")) return await handleLibraryMessageEvent(recordId);
  // #NOTIFY-Painel-acts famille 1 : reçu de paiement de cotisation (payload-based,
  // record_id factice). Le handler lit membership_payments par payment_id.
  if (event === "cotisation_payment_recorded") return await handleCotisationPayment(payload);
  // MULTI P4b : inscription validée par le staff -> e-mail de confirmation à la
  // lectrice (CTA /conta). Payload-based, lit user_library_memberships par uuid.
  if (event === "validation_confirmed") return await handleValidationConfirmed(payload);
  // CARD-LOCAL-N4 : identité locale attribuée/éditée hors validation -> e-mail de
  // réconciliation à la lectrice + copie biblio. Payload-based, lit la membership par uuid.
  if (event === "reader_identity_assigned") return await handleReaderIdentityAssigned(payload);
  // VALID-C3 : nouvelle demande d'inscription -> alerte la biblio (CTA /painel)
  // qu'un compte attend validation. Payload-based, lit la membership par uuid.
  if (event === "membership_validation_requested") return await handleMembershipValidationRequested(payload);
  // #NOTIFY-Painel-acts famille 2 : restriction locale + gel global (et levées).
  // Mail membre obligatoire + copie staff (profile_restriction_enabled). Payload-based.
  if ([
    "member_restricted_local",
    "member_unrestricted_local",
    "member_frozen_global",
    "member_unfrozen_global"
  ].includes(event)) return await handleMembershipRestriction(event, payload);
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
  // R.NOTIF-PA / Décision A (08/06/2026) : route 'profile_notice' + handler
  // handleProfileNotice retirés — handler mort (lisait profile_notice_queue,
  // table inexistante ; aucun émetteur). La restriction/gel sera (re)câblée
  // sur le pattern moderne (events member_restricted_*/member_frozen_*),
  // réutilisant les clés i18n prof.* conservées dans mail-strings.ts.
  // ===== Préavis RGPD purge (Spec §7.1, 31/05/2026) ======================
  // Couvre rgpd_purge_warning_loans / _reservations / _consultations
  if (event.startsWith("rgpd_purge_warning_")) return await handleRgpdPurgeWarning(recordId, event);
  // §21 PARTNER NOTIF-1 : cycle de vie partenariat → coordenador (payload-based, uuid).
  if (["partnership_proposed","partnership_accepted","partnership_refused","partnership_broken"].includes(event)) return await handlePartnershipLifecycle(event, payload);
  // §21 PARTNER NOTIF-2 : transparence activée → fan-out lectrices communes (consentement).
  if (event === "partnership_transparence_enabled") return await handleTransparenceEnabled(payload);
  // §21 PARTNER NOTIF-3 : config élargie → re-sollicitation des consentements stale.
  if (event === "partnership_config_expanded") return await handleConfigExpanded(payload);
  // Entraide : appel routé vers un cercle → notif aux membres du cercle (payload-based,
  // record_id factice ; lit circle_id/subject/author dans le payload).
  if (event === "entraide_request_circle") return await handleEntraideRequestCircle(payload);
  return null;
}
