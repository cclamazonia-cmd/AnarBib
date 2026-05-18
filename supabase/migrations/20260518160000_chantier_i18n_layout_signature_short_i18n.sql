-- ============================================================================
-- 20260518150000_chantier_i18n_layout_signature_short_i18n.sql
-- Chantier i18n layout mail générique — étape 2D (18/05/2026)
-- ============================================================================
--
-- Objet : ajouter la colonne `signature_short_i18n jsonb` à
-- `library_notification_profiles` pour permettre aux biblios de stocker
-- leur signature de fin de mail en plusieurs langues. La colonne existante
-- `signature_short text` est conservée pour rétrocompat (fallback si pas
-- d'entrée pour la locale demandée dans le jsonb).
--
-- Architecture σ2 (additive) validée 18/05/2026 :
--   - Lecture côté code : préférer signature_short_i18n.{locale} si défini,
--     sinon fallback sur signature_short text.
--   - Migration douce : pas de breaking change pour les pages frontend qui
--     éditent signature_short aujourd'hui.
--
-- Backfill : pour les biblios existantes qui ont une `signature_short`
-- non NULL, on initialise signature_short_i18n avec {"pt-BR": <valeur>}
-- (cohérent avec default_locale='pt-BR' historique de BLMF/BTL).
--
-- Doctrine création objets backend v2 :
--   - Pas de nouvelle fonction (juste ALTER + UPDATE + REPLACE VIEW)
--   - Vue : security_invoker = true explicite (doctrine #19/Template 3)
--   - Pas de RLS spécifique sur la colonne (héritée de la table parente)
-- ============================================================================

BEGIN;

-- ===== 1. Ajout colonne =====================================================

ALTER TABLE public.library_notification_profiles
  ADD COLUMN IF NOT EXISTS signature_short_i18n jsonb DEFAULT NULL;

COMMENT ON COLUMN public.library_notification_profiles.signature_short_i18n IS
  'Signature de fin de mail traduite par locale. Format : {"pt-BR": "Equipe da BLMF", "fr": "L''équipe de la BLMF", ...}. Si NULL ou si locale absente du JSON, fallback sur signature_short (text). Chantier i18n layout mail générique, 18/05/2026.';

-- ===== 2. Backfill pour biblios existantes ==================================
-- Pour chaque biblio qui a une signature_short non NULL, on initialise
-- signature_short_i18n avec {"<default_locale>": <signature_short>}.

UPDATE public.library_notification_profiles p
SET signature_short_i18n = jsonb_build_object(
    COALESCE(
      (SELECT l.default_locale FROM public.libraries l WHERE l.id = p.library_id),
      'pt-BR'
    ),
    p.signature_short
  )
WHERE p.signature_short IS NOT NULL
  AND p.signature_short_i18n IS NULL;

-- ===== 3. Mise à jour de la vue v_library_notification_context ==============
-- Ajout de signature_short_i18n dans la projection. La vue est explicitement
-- créée avec security_invoker = true (doctrine #19/Template 3 : toute nouvelle
-- vue doit avoir security_invoker = true pour que les RLS de la table parent
-- soient appliquées au caller, pas au propriétaire de la vue).

DROP VIEW IF EXISTS public.v_library_notification_context CASCADE;

CREATE VIEW public.v_library_notification_context
  WITH (security_invoker = true)
  AS
  SELECT
    l.id AS library_id,
    l.slug,
    l.name AS library_name,
    l.short_name AS library_short_name,
    p.sender_display_name,
    p.reply_to_name,
    p.reply_to_email,
    p.signature_short,
    p.signature_short_i18n,                  -- ← NOUVELLE COLONNE
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
    l.default_locale
  FROM public.libraries l
    LEFT JOIN public.library_notification_profiles p ON p.library_id = l.id
    LEFT JOIN public.library_notification_policies pol ON pol.library_id = l.id
    LEFT JOIN public.library_mail_channels ch ON ch.library_id = l.id
    LEFT JOIN public.library_commons lc ON lc.library_id = l.id;

-- Permissions sur la vue (héritage RLS via security_invoker de la table parent)
GRANT SELECT ON public.v_library_notification_context TO authenticated;

COMMENT ON VIEW public.v_library_notification_context IS
  'Contexte consolidé pour le rendu des notifications mail (sender, signature, policies, channels, theme, locale). v0.2 (18/05/2026) : ajout de signature_short_i18n pour signature multilingue par biblio.';

-- ===== 4. DO block de vérif =================================================

DO $$
DECLARE
  v_count_total INT;
  v_count_backfilled INT;
  v_blmf_i18n jsonb;
  v_blmf_default_locale text;
BEGIN
  -- Vérif 1 : colonne ajoutée
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='library_notification_profiles'
      AND column_name='signature_short_i18n'
  ) THEN
    RAISE EXCEPTION 'Colonne signature_short_i18n non créée';
  END IF;

  -- Vérif 2 : backfill effectif
  SELECT COUNT(*) INTO v_count_total
    FROM public.library_notification_profiles
    WHERE signature_short IS NOT NULL;
  SELECT COUNT(*) INTO v_count_backfilled
    FROM public.library_notification_profiles
    WHERE signature_short IS NOT NULL
      AND signature_short_i18n IS NOT NULL;

  IF v_count_total <> v_count_backfilled THEN
    RAISE EXCEPTION 'Backfill incomplet : % biblios avec signature_short, % avec signature_short_i18n',
      v_count_total, v_count_backfilled;
  END IF;

  -- Vérif 3 : BLMF a bien sa signature pt-BR dans le jsonb
  SELECT p.signature_short_i18n, l.default_locale
    INTO v_blmf_i18n, v_blmf_default_locale
    FROM public.library_notification_profiles p
    JOIN public.libraries l ON l.id = p.library_id
    WHERE l.slug = 'blmf';

  IF v_blmf_i18n IS NULL THEN
    RAISE EXCEPTION 'BLMF : signature_short_i18n NULL après backfill';
  END IF;

  IF NOT (v_blmf_i18n ? v_blmf_default_locale) THEN
    RAISE EXCEPTION 'BLMF : signature_short_i18n manque la cle "%"', v_blmf_default_locale;
  END IF;

  -- Vérif 4 : vue exposant la nouvelle colonne
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='v_library_notification_context'
      AND column_name='signature_short_i18n'
  ) THEN
    RAISE EXCEPTION 'Vue v_library_notification_context : colonne signature_short_i18n absente';
  END IF;

  RAISE NOTICE 'OK : % biblios backfillees, BLMF i18n=%', v_count_backfilled, v_blmf_i18n::text;
END $$;

COMMIT;
