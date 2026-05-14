// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// types.ts â€” Types partagÃ©s des Edge Functions Supabase AnarBib
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Ce fichier consolide les dÃ©finitions de types utilisÃ©es par toutes les
// Edge Functions du projet (notify-event et autres). Il Ã©tait implicitement
// rÃ©fÃ©rencÃ© par 14 fichiers via `import type { ... } from "../core/types.ts"`
// mais n'existait pas dans le repo â€” Deno faisait du type-stripping en runtime
// et les types n'Ã©taient jamais validÃ©s. Ce fichier rÃ©pare cette dette
// technique latente.
//
// Convention : un seul export par interface/type, pas de namespace, pas de
// classes. Tout est `export interface` ou `export type`. Les structures sont
// reverse-engineerÃ©es depuis l'usage observÃ© dans le codebase au moment de
// la crÃ©ation du fichier (2026-05-09).
//
// Si vous ajoutez un nouveau type partagÃ© entre plusieurs Edge Functions,
// c'est ici qu'il vit. Si un type n'est utilisÃ© que dans une seule Edge
// Function, gardez-le local au fichier oÃ¹ il est utilisÃ© (don't pollute).
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Primitives JSON â€” types gÃ©nÃ©riques pour payloads / rÃ©ponses
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// JsonValue couvre tout ce qui est sÃ©rialisable JSON. JsonObject est un
// objet JSON {clÃ©: valeur}, JsonArray un tableau de JsonValue.
// UtilisÃ© par webhook.ts pour caster les retours des handlers Edge en
// objets sÃ©rialisables avant jsonResponse(). AjoutÃ© chore 2026-05-09
// pour Ã©liminer un import orphelin pointant vers un fichier qui n'existait pas.

export type JsonValue = string | number | boolean | null | JsonObject | JsonArray;
export interface JsonObject { [key: string]: JsonValue; }
export type JsonArray = JsonValue[];

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Notification context â€” rÃ©solu depuis v_library_notification_context
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Les valeurs nullable correspondent aux LEFT JOIN qui peuvent ne pas
// remonter de ligne (library sans profile, sans channel, etc.).
// UtilisÃ© par : library-mail-routing, library-notification-context,
// policies, branding, layout, transport/email, et tous les domain/*.

export interface LibraryNotificationContext {
  // IdentitÃ© de la biblio
  library_id: string | null;
  slug: string | null;
  library_name: string;
  library_short_name: string;

  // Profil d'envoi (sender, signature, footer)
  sender_display_name: string | null;
  reply_to_name: string | null;
  reply_to_email: string | null;
  signature_short: string | null;
  footer_local: string | null;
  use_library_name_as_sender: boolean;
  use_library_logo: boolean;
  logo_url: string | null;
  logo_file_key: string | null;
  sender_visible_email: string | null;

  // Politiques d'activation des familles de mails
  reservation_created_enabled: boolean;
  reservation_status_enabled: boolean;
  reservation_workflow_enabled: boolean;
  local_consultation_enabled: boolean;
  consulta_mail_criada_enabled: boolean;
  consulta_mail_agendada_enabled: boolean;
  consulta_mail_resposta_creneau_enabled: boolean;
  consulta_mail_realizada_enabled: boolean;
  consulta_mail_cancelada_enabled: boolean;
  consulta_mail_expirada_enabled: boolean;
  admin_copy_consultas_enabled: boolean;
  loan_lifecycle_enabled: boolean;
  loan_reminders_enabled: boolean;
  loan_overdue_enabled: boolean;
  profile_restriction_enabled: boolean;
  mid_loan_message_enabled: boolean;
  reading_recommendations_enabled: boolean;
  admin_copy_reservations_enabled: boolean;
  admin_copy_loans_enabled: boolean;
  tech_alerts_enabled: boolean;
  task_alerts_enabled: boolean;

  // Canal de transport mail
  delivery_mode: string;
  admin_notification_email: string | null;
  weekly_report_email: string | null;
  severe_alert_email: string | null;
  transport_state: string | null;
  transport_channel: string;
  last_tested_at: string | null;
  channel_active: boolean;

  // IdentitÃ© linguistique de la biblio (paquet 6.1, ajoutÃ© 2026-05-09)
  // BCP 47 short code : 'pt-BR' | 'fr' | 'es' | 'en' | 'it' | 'de' au paquet 6.
  // Validation cÃ´tÃ© UI uniquement, pas de CHECK constraint en DB pour
  // permettre l'ajout futur de nouvelles locales (eu, ca, oc, etc.).
  default_locale: string;
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Mail routing rÃ©solu â€” produit par resolveMailRouting()
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ReprÃ©sente l'Ã©tat final de routage d'un mail aprÃ¨s application de toutes
// les politiques (sender effectif, replyTo, logos, footer, dÃ©sactivation).
// UtilisÃ© par : library-mail-routing.

export interface ResolvedMailRouting {
  brandName: string;
  subjectTag: string;
  senderName: string;
  senderEmail: string;
  replyToName: string | null;
  replyToEmail: string | null;
  logoUrl: string;
  networkLogoUrl: string;
  libraryLogoUrl: string;
  footerText: string;
  footerHtml: string;
  adminEmail: string | null;
  adminName: string | null;
  deliveryMode: string;
  channelActive: boolean;
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Mail primitives
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Types pour la couche transport/rendu mail (Brevo, layout, etc.).

export interface EmailTarget {
  email: string;
  name?: string;
}

// Tableau de paires label/valeur affichÃ©es dans la table de dÃ©tails
// du mail (cf. renderEmail dans layout.ts).
export type EmailDetails = Array<{ label: string; value: string }>;

// RÃ©sultat normalisÃ© d'une tentative d'envoi de mail. ok=false avec
// skipped=true signifie qu'on a dÃ©libÃ©rÃ©ment choisi de ne pas envoyer
// (canal dÃ©sactivÃ©, email invalide, etc.) â€” diffÃ©rent d'une vraie erreur
// avec ok=false et error renseignÃ©.
export interface EmailSendResult {
  ok: boolean;
  label?: string;
  email?: string;
  skipped?: boolean;
  reason?: string;
  response?: string;
  error?: string;
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Webhook payload â€” entrÃ©e des Edge Functions notify-*
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Payload reÃ§u en POST par notify-event/index.ts depuis les triggers DB
// ou des appels manuels. Les champs principaux sont event + record_id ;
// les autres dÃ©pendent de l'Ã©vÃ©nement (line_nos pour rÃ©sas, items pour
// workflow, user_email/user_name pour overrides, etc.).
//
// Utilise une signature index pour rester souple : les helpers
// getPayloadValue, normalizeLineNos, etc. gÃ¨rent le typage runtime.

export interface NotifyPayload {
  event?: string;
  record_id?: number;
  manual_test?: boolean;
  line_nos?: number[] | string[] | string;
  items?: ReservaWorkflowItem[];
  user_email?: string;
  user_name?: string;
  workflow_note?: string;
  pickup_scheduled_for?: string;
  timezone?: string;
  [key: string]: unknown;
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Workflow item â€” payload structurÃ© pour les events workflow rÃ©servation
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Item de rÃ©servation enrichi des donnÃ©es workflow (stage, crÃ©neau, note).
// UtilisÃ© soit cÃ´tÃ© payload entrant (override depuis trigger DB) soit cÃ´tÃ©
// data rÃ©cupÃ©rÃ© via getReservaWorkflowBundle.

export interface ReservaWorkflowItem {
  line_no?: number;
  sub_id?: string | null;
  bib_ref?: string | null;
  titulo?: string | null;
  autor?: string | null;
  workflow_stage?: string | null;
  workflow_note?: string | null;
  pickup_scheduled_for?: string | null;
  pickup_reply_status?: string | null;
  pickup_reply_note?: string | null;
  pickup_reply_at?: string | null;
  pickup_proposed_by?: string | null;
  negotiation_iteration_count?: number | null;
  [key: string]: unknown;
}
