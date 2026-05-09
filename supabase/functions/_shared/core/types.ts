// ═══════════════════════════════════════════════════════════
// types.ts — Types partagés des Edge Functions Supabase AnarBib
// ═══════════════════════════════════════════════════════════
// Ce fichier consolide les définitions de types utilisées par toutes les
// Edge Functions du projet (notify-event et autres). Il était implicitement
// référencé par 14 fichiers via `import type { ... } from "../core/types.ts"`
// mais n'existait pas dans le repo — Deno faisait du type-stripping en runtime
// et les types n'étaient jamais validés. Ce fichier répare cette dette
// technique latente.
//
// Convention : un seul export par interface/type, pas de namespace, pas de
// classes. Tout est `export interface` ou `export type`. Les structures sont
// reverse-engineerées depuis l'usage observé dans le codebase au moment de
// la création du fichier (2026-05-09).
//
// Si vous ajoutez un nouveau type partagé entre plusieurs Edge Functions,
// c'est ici qu'il vit. Si un type n'est utilisé que dans une seule Edge
// Function, gardez-le local au fichier où il est utilisé (don't pollute).
// ═══════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────
// Primitives JSON — types génériques pour payloads / réponses
// ─────────────────────────────────────────────────────────────
// JsonValue couvre tout ce qui est sérialisable JSON. JsonObject est un
// objet JSON {clé: valeur}, JsonArray un tableau de JsonValue.
// Utilisé par webhook.ts pour caster les retours des handlers Edge en
// objets sérialisables avant jsonResponse(). Ajouté chore 2026-05-09
// pour éliminer un import orphelin pointant vers un fichier qui n'existait pas.

export type JsonValue = string | number | boolean | null | JsonObject | JsonArray;
export interface JsonObject { [key: string]: JsonValue; }
export type JsonArray = JsonValue[];

// ─────────────────────────────────────────────────────────────
// Notification context — résolu depuis v_library_notification_context
// ─────────────────────────────────────────────────────────────
// Les valeurs nullable correspondent aux LEFT JOIN qui peuvent ne pas
// remonter de ligne (library sans profile, sans channel, etc.).
// Utilisé par : library-mail-routing, library-notification-context,
// policies, branding, layout, transport/email, et tous les domain/*.

export interface LibraryNotificationContext {
  // Identité de la biblio
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

  // Identité linguistique de la biblio (paquet 6.1, ajouté 2026-05-09)
  // BCP 47 short code : 'pt-BR' | 'fr' | 'es' | 'en' | 'it' | 'de' au paquet 6.
  // Validation côté UI uniquement, pas de CHECK constraint en DB pour
  // permettre l'ajout futur de nouvelles locales (eu, ca, oc, etc.).
  default_locale: string;
}

// ─────────────────────────────────────────────────────────────
// Mail routing résolu — produit par resolveMailRouting()
// ─────────────────────────────────────────────────────────────
// Représente l'état final de routage d'un mail après application de toutes
// les politiques (sender effectif, replyTo, logos, footer, désactivation).
// Utilisé par : library-mail-routing.

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

// ─────────────────────────────────────────────────────────────
// Mail primitives
// ─────────────────────────────────────────────────────────────
// Types pour la couche transport/rendu mail (Brevo, layout, etc.).

export interface EmailTarget {
  email: string;
  name?: string;
}

// Tableau de paires label/valeur affichées dans la table de détails
// du mail (cf. renderEmail dans layout.ts).
export type EmailDetails = Array<{ label: string; value: string }>;

// Résultat normalisé d'une tentative d'envoi de mail. ok=false avec
// skipped=true signifie qu'on a délibérément choisi de ne pas envoyer
// (canal désactivé, email invalide, etc.) — différent d'une vraie erreur
// avec ok=false et error renseigné.
export interface EmailSendResult {
  ok: boolean;
  label?: string;
  email?: string;
  skipped?: boolean;
  reason?: string;
  response?: string;
  error?: string;
}

// ─────────────────────────────────────────────────────────────
// Webhook payload — entrée des Edge Functions notify-*
// ─────────────────────────────────────────────────────────────
// Payload reçu en POST par notify-event/index.ts depuis les triggers DB
// ou des appels manuels. Les champs principaux sont event + record_id ;
// les autres dépendent de l'événement (line_nos pour résas, items pour
// workflow, user_email/user_name pour overrides, etc.).
//
// Utilise une signature index pour rester souple : les helpers
// getPayloadValue, normalizeLineNos, etc. gèrent le typage runtime.

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

// ─────────────────────────────────────────────────────────────
// Workflow item — payload structuré pour les events workflow réservation
// ─────────────────────────────────────────────────────────────
// Item de réservation enrichi des données workflow (stage, créneau, note).
// Utilisé soit côté payload entrant (override depuis trigger DB) soit côté
// data récupéré via getReservaWorkflowBundle.

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
