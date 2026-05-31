-- Chantier #CL.6 — Archivage par ligne des avis lecteur·rice (vue archives)
--
-- Sémantique α (décision du 31/05/2026) : archivage = simple masquage,
-- pas soft-delete. Une notification archivée disparaît de la vue active
-- mais reste en base, restaurable à tout moment par la lectrice. Pas de
-- rétention, pas de purge automatique. Si suppression définitive devient
-- nécessaire un jour, ce sera un acte séparé et conscient.
--
-- Ce que cette migration apporte :
--   1. Colonne archived_at timestamptz sur user_notifications
--   2. Index partiel pour optimiser la vue active (cas dominant)
--   3. RPC fn_archive_notification(p_notification_id) — action lectrice
--   4. RPC fn_unarchive_notification(p_notification_id) — action lectrice
--
-- Doctrine v2 (cf. CHANTIER_doctrine_creation_objets_securises_2026-05-12) :
--   - SECURITY DEFINER sur les RPC
--   - REVOKE FROM PUBLIC, anon, service_role
--   - GRANT TO authenticated uniquement
--   - SET search_path TO 'public'
--   - Vérification embarquée en fin de migration (DO + ASSERT)

-- ──────────────────────────────────────────────────────────────────────
-- 1. Colonne archived_at
-- ──────────────────────────────────────────────────────────────────────

ALTER TABLE public.user_notifications
  ADD COLUMN IF NOT EXISTS archived_at timestamptz;

COMMENT ON COLUMN public.user_notifications.archived_at IS
  'Chantier #CL.6 (31/05/2026). NULL = avis actif (vue par défaut). '
  'NOT NULL = avis archivé par la lectrice (masqué par défaut, accessible via toggle). '
  'L''archivage est un acte réversible — pas un soft-delete avec rétention.';

-- ──────────────────────────────────────────────────────────────────────
-- 2. Index partiel pour la vue active
-- ──────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_user_notifications_active
  ON public.user_notifications (user_id, created_at DESC)
  WHERE archived_at IS NULL;

-- ──────────────────────────────────────────────────────────────────────
-- 3. RPC fn_archive_notification — action lectrice (archive un avis)
-- ──────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_archive_notification(p_notification_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_rows int;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth required' USING HINT = 'fn_archive_notification: no authenticated user in context';
  END IF;

  UPDATE public.user_notifications
     SET archived_at = now()
   WHERE id = p_notification_id
     AND user_id = v_user_id
     AND archived_at IS NULL;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RAISE EXCEPTION 'notification % not found, not owned, or already archived for user %',
      p_notification_id, v_user_id
      USING HINT = 'fn_archive_notification: vérifier que la notification appartient à auth.uid() et n''est pas déjà archivée';
  END IF;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_archive_notification(bigint) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.fn_archive_notification(bigint) TO authenticated;

COMMENT ON FUNCTION public.fn_archive_notification(bigint) IS
  'Chantier #CL.6 (31/05/2026). Archive une notification appartenant à auth.uid(). '
  'SECURITY DEFINER + REVOKE/GRANT doctrine v2. Échoue si la notification n''existe pas, '
  'n''appartient pas à l''utilisateur courant, ou est déjà archivée.';

-- ──────────────────────────────────────────────────────────────────────
-- 4. RPC fn_unarchive_notification — action lectrice (restaure un avis)
-- ──────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_unarchive_notification(p_notification_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_rows int;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth required' USING HINT = 'fn_unarchive_notification: no authenticated user in context';
  END IF;

  UPDATE public.user_notifications
     SET archived_at = NULL
   WHERE id = p_notification_id
     AND user_id = v_user_id
     AND archived_at IS NOT NULL;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RAISE EXCEPTION 'notification % not found, not owned, or not archived for user %',
      p_notification_id, v_user_id
      USING HINT = 'fn_unarchive_notification: vérifier que la notification appartient à auth.uid() et est bien archivée';
  END IF;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_unarchive_notification(bigint) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.fn_unarchive_notification(bigint) TO authenticated;

COMMENT ON FUNCTION public.fn_unarchive_notification(bigint) IS
  'Chantier #CL.6 (31/05/2026). Restaure une notification archivée appartenant à auth.uid(). '
  'SECURITY DEFINER + REVOKE/GRANT doctrine v2. Échoue si la notification n''existe pas, '
  'n''appartient pas à l''utilisateur courant, ou n''est pas archivée.';

-- ──────────────────────────────────────────────────────────────────────
-- 5. Vérification embarquée
-- ──────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  ASSERT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_notifications'
      AND column_name = 'archived_at'
      AND data_type = 'timestamp with time zone'
  ), 'colonne archived_at manquante ou de type incorrect';

  ASSERT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'user_notifications'
      AND indexname = 'idx_user_notifications_active'
  ), 'index partiel idx_user_notifications_active non créé';

  ASSERT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_archive_notification'
  ), 'fn_archive_notification non créée';

  ASSERT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_unarchive_notification'
  ), 'fn_unarchive_notification non créée';

  -- Vérif des permissions : authenticated doit avoir EXECUTE sur les deux fonctions
  ASSERT (
    SELECT COUNT(*) FROM information_schema.routine_privileges
    WHERE routine_schema = 'public'
      AND routine_name IN ('fn_archive_notification', 'fn_unarchive_notification')
      AND grantee = 'authenticated'
      AND privilege_type = 'EXECUTE'
  ) = 2, 'permissions authenticated non posées sur les RPC';

  RAISE NOTICE 'OK : migration #CL.6 archivage notifications appliquée';
END $$;
