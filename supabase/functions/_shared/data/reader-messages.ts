// =============================================================================
// _shared/data/reader-messages.ts
// =============================================================================
// Bundles DB pour les handlers du canal « messages lecteur <-> biblio ».
// recordId = reader_library_messages.id (bigint), passe par les triggers DB
// via fn_dispatch_circulation_notify_event(event, NEW.id, extra).
//
//   - getReaderMessageBundle   : direction=reader  -> message + profil EXPEDITEUR
//   - getLibraryMessageBundle  : direction=library -> message + profil DESTINATAIRE
//
// Calque _shared/data/consultas.ts : meme client service-role (supabaseAdmin),
// PK = profiles.id.
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

// Variante reciproque (direction=library) : on charge le·a DESTINATAIRE
// (recipient_id) au lieu de l'expediteur, pour lui adresser le mail.
export async function getLibraryMessageBundle(messageId: number) {
  const { data: message, error: e1 } = await supabaseAdmin
    .from("reader_library_messages")
    .select("id,library_id,sender_id,recipient_id,direction,subject,body,mail_status,created_at")
    .eq("id", messageId)
    .maybeSingle();
  if (e1) throw e1;
  if (!message) throw new Error("Mensagem não encontrada.");

  const messageRec = message as Record<string, unknown>;
  const { data: profile, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,phone,address,consent_email,preferred_language")
    .eq("id", messageRec.recipient_id as string)
    .maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Destinatário não encontrado.");

  return {
    message: message as Record<string, unknown>,
    recipient: profile as Record<string, unknown>
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
