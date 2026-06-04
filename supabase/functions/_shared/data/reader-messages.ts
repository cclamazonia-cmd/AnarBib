// =============================================================================
// _shared/data/reader-messages.ts
// =============================================================================
// Bundle DB pour le handler reader-message (canal « ecrire a ma bibliotheque »).
// recordId = reader_library_messages.id (bigint), passe par le trigger DB
// trg_reader_message_dispatch via fn_dispatch_circulation_notify_event(
//   'reader_message_sent', NEW.id, {library_id, sender_id, direction}).
//
// Calque _shared/data/consultas.ts : meme client service-role (supabaseAdmin),
// meme pattern « enregistrement + profil expediteur » (PK = profiles.id).
// =============================================================================

import { supabaseAdmin } from "../core/env.ts";

export async function getReaderMessageBundle(messageId: number) {
  // 1. Le message
  const { data: message, error: e1 } = await supabaseAdmin
    .from("reader_library_messages")
    .select("id,library_id,sender_id,direction,subject,body,mail_status,created_at")
    .eq("id", messageId)
    .maybeSingle();
  if (e1) throw e1;
  if (!message) throw new Error("Mensagem não encontrada.");

  // 2. Profil de l'expediteur·rice (PK = profiles.id, calque consultas)
  const messageRec = message as Record<string, unknown>;
  const { data: profile, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,phone,address,consent_email,preferred_language")
    .eq("id", messageRec.sender_id as string)
    .maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");

  return {
    message: message as Record<string, unknown>,
    profile: profile as Record<string, unknown>
  };
}

// MAJ best-effort du statut mail. supabaseAdmin = service_role -> bypass RLS
// (la table n'accorde aucun UPDATE a authenticated, c'est voulu).
export async function markReaderMessageMailStatus(messageId: number, status: string) {
  const { error } = await supabaseAdmin
    .from("reader_library_messages")
    .update({ mail_status: status })
    .eq("id", messageId);
  if (error) console.warn(`markReaderMessageMailStatus(${messageId}, ${status}):`, error.message);
}