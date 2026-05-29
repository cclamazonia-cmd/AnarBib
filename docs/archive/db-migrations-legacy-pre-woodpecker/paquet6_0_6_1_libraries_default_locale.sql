-- ═══════════════════════════════════════════════════════════
-- Paquet 6.0 + 6.1 — Identité linguistique de la biblio
-- ═══════════════════════════════════════════════════════════
-- Contexte : refonte mails workflow réservation v3. Pour adresser les mails
-- biblio dans la langue de la coordination locale (CIRA Lausanne en français,
-- biblios brésiliennes en pt-BR, etc.), la biblio doit avoir un attribut
-- "default_locale" stable.
--
-- Décision politique (session 2026-05-09) : la langue est un attribut
-- d'IDENTITÉ de la biblio, pas une préférence de notification. On la pose
-- donc sur la table `libraries` (et non `library_notification_policies`),
-- pour qu'elle soit réutilisable dans d'autres contextes futurs (page
-- publique de la biblio, exports, etc.).
--
-- Validation : pas de CHECK constraint, validation côté UI uniquement
-- (dropdown limité aux locales supportées). Permet d'ajouter facilement
-- de nouvelles locales (eu, ca, oc, ku, etc.) sans toucher au schéma.
--
-- Codes BCP 47 actuellement supportés : pt-BR, fr, es, en, it, de.
-- ═══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 6.0 — Ajouter libraries.default_locale
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS default_locale TEXT NOT NULL DEFAULT 'pt-BR';

COMMENT ON COLUMN public.libraries.default_locale IS
  'Langue par défaut de la biblio (BCP 47 short code). Détermine la langue
   des mails côté coordination, des notifications staff, et potentiellement
   d''autres contextes futurs (page publique, exports). Configurable depuis
   l''onglet Identité et fonctionnement → section Identité de BibliotecaPage.
   Valeurs supportées au paquet 6 : pt-BR, fr, es, en, it, de. Validation
   côté UI (dropdown), pas de CHECK constraint pour permettre l''ajout
   facile de nouvelles locales.';

-- ─────────────────────────────────────────────────────────────
-- 6.1 — Étendre la vue v_library_notification_context
-- ─────────────────────────────────────────────────────────────
-- La vue est multi-source (libraries + library_notification_profiles +
-- library_notification_policies + library_mail_channels + library_commons).
-- On ajoute l.default_locale en fin de liste SELECT (contrainte Postgres
-- CREATE OR REPLACE VIEW : pas de réordonnement possible — souvenir du
-- paquet 5c sur api.my_reservations_active_v2).

CREATE OR REPLACE VIEW public.v_library_notification_context AS
SELECT l.id AS library_id,
       l.slug,
       l.name AS library_name,
       l.short_name AS library_short_name,
       p.sender_display_name,
       p.reply_to_name,
       p.reply_to_email,
       p.signature_short,
       p.footer_local,
       p.use_library_name_as_sender,
       p.use_library_logo,
       p.sender_visible_email,
       pol.reservation_created_enabled,
       pol.reservation_status_enabled,
       pol.reservation_workflow_enabled,
       pol.local_consultation_enabled,
       pol.loan_lifecycle_enabled,
       pol.loan_reminders_enabled,
       pol.loan_overdue_enabled,
       pol.profile_restriction_enabled,
       pol.mid_loan_message_enabled,
       pol.reading_recommendations_enabled,
       pol.admin_copy_reservations_enabled,
       pol.admin_copy_loans_enabled,
       pol.tech_alerts_enabled,
       pol.task_alerts_enabled,
       ch.delivery_mode,
       ch.admin_notification_email,
       ch.weekly_report_email,
       ch.severe_alert_email,
       ch.transport_state,
       ch.transport_channel,
       ch.last_tested_at,
       ch.active AS channel_active,
       lc.logo_url,
       lc.logo_file_key,
       -- AJOUT paquet 6.1 (en fin pour CREATE OR REPLACE)
       l.default_locale
FROM libraries l
  LEFT JOIN library_notification_profiles p ON p.library_id = l.id
  LEFT JOIN library_notification_policies pol ON pol.library_id = l.id
  LEFT JOIN library_mail_channels ch ON ch.library_id = l.id
  LEFT JOIN library_commons lc ON lc.library_id = l.id;

COMMENT ON VIEW public.v_library_notification_context IS
  'Contexte de notification consolidé par biblio (multi-source).
   Paquet 6.1 (2026-05-09) : ajout default_locale depuis libraries pour
   alimenter la locale d''envoi des mails staff/admin.';

-- ═══════════════════════════════════════════════════════════
-- Requêtes d'acceptation à lancer après application
-- ═══════════════════════════════════════════════════════════
-- Q1 : libraries.default_locale existe et a 'pt-BR' partout
-- SELECT id, name, default_locale FROM public.libraries ORDER BY name;
-- Attendu : toutes les biblios avec default_locale = 'pt-BR'
--
-- Q2 : la vue expose la nouvelle colonne
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'v_library_notification_context'
--   AND column_name = 'default_locale';
-- Attendu : 1 ligne
--
-- Q3 : le contexte d'une biblio remonte bien default_locale
-- SELECT library_id, library_name, default_locale
-- FROM public.v_library_notification_context LIMIT 5;
-- Attendu : default_locale='pt-BR' partout (avant configuration manuelle)
-- ═══════════════════════════════════════════════════════════
