-- =========================================================================
-- Paquet L.12bis (hotfix) — Ré-activation RLS sur tables archivées
-- =========================================================================
-- Date     : 2026-05-19
-- Chantier : hotfix régression L.12
-- Auteur   : Xavier
--
-- CONTEXTE :
--   Le paquet L.12 (20260519300000) a désactivé la RLS sur 3 tables
--   _archived_*_20260408 pour éliminer 3 alertes INFO rls_enabled_no_policy.
--   Effet de bord constaté : Supabase a remplacé ces 3 INFO par 3 ERRORS
--   rls_disabled_in_public, ce qui est plus critique.
--
--   Le bon pattern pour une table archivée dans public.* est :
--     ENABLE RLS + policy explicite "USING (false)" qui bloque toute lecture.
--
-- OBJECTIF :
--   Restaurer la RLS sur les 3 tables et ajouter une policy lock-down
--   qui bloque explicitement toute lecture/écriture anon et authenticated.
--   service_role conserve l'accès (BYPASSRLS) pour audit ponctuel.
--
-- BÉNÉFICE LINTER :
--   -3 ERRORS rls_disabled_in_public + 0 alerte rls_enabled_no_policy
--   (la policy lock-down satisfait le linter).
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Ré-activer la RLS sur les 3 tables
-- -------------------------------------------------------------------------

ALTER TABLE public._archived_library_request_claims_20260408
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public._archived_library_request_notification_events_20260408
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public._archived_library_requests_20260408
  ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------
-- 2. Policy lock-down explicite sur chaque table
-- -------------------------------------------------------------------------
-- Pattern : FOR ALL (SELECT + INSERT + UPDATE + DELETE), USING (false) +
-- WITH CHECK (false) = aucune ligne visible, aucune écriture acceptée.
-- service_role bypass automatiquement la RLS (BYPASSRLS), donc reste
-- capable de lire pour audit ponctuel via Edge Function ou SQL Editor.

CREATE POLICY "archived_2026_04_08_lockdown"
  ON public._archived_library_request_claims_20260408
  FOR ALL
  TO anon, authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY "archived_2026_04_08_lockdown"
  ON public._archived_library_request_notification_events_20260408
  FOR ALL
  TO anon, authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY "archived_2026_04_08_lockdown"
  ON public._archived_library_requests_20260408
  FOR ALL
  TO anon, authenticated
  USING (false)
  WITH CHECK (false);

-- -------------------------------------------------------------------------
-- 3. COMMENT ON TABLE mis à jour
-- -------------------------------------------------------------------------

COMMENT ON TABLE public._archived_library_request_claims_20260408 IS
  'Archive gelée du 08/04/2026 — table inerte, 1 ligne historique. '
  'RLS activée + policy lock-down (USING false) par paquet L.12bis (19/05/2026). '
  'Accessible uniquement via service_role pour audit ponctuel.';

COMMENT ON TABLE public._archived_library_request_notification_events_20260408 IS
  'Archive gelée du 08/04/2026 — table inerte, 1 ligne historique. '
  'RLS activée + policy lock-down (USING false) par paquet L.12bis (19/05/2026). '
  'Accessible uniquement via service_role pour audit ponctuel.';

COMMENT ON TABLE public._archived_library_requests_20260408 IS
  'Archive gelée du 08/04/2026 — table inerte, 1 ligne historique. '
  'RLS activée + policy lock-down (USING false) par paquet L.12bis (19/05/2026). '
  'Accessible uniquement via service_role pour audit ponctuel.';

-- -------------------------------------------------------------------------
-- 4. DO-block de vérification : confirmer que anon et authenticated ne
-- peuvent rien lire dans ces tables
-- -------------------------------------------------------------------------

DO $$
DECLARE
  v_count int;
  v_table text;
  v_tables text[] := ARRAY[
    '_archived_library_request_claims_20260408',
    '_archived_library_request_notification_events_20260408',
    '_archived_library_requests_20260408'
  ];
BEGIN
  -- Test contexte anon
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{}';

  FOREACH v_table IN ARRAY v_tables LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', v_table) INTO v_count;
    IF v_count > 0 THEN
      RAISE EXCEPTION 'Vérification échouée : anon voit % lignes dans %, attendu 0', v_count, v_table;
    END IF;
  END LOOP;

  RESET ROLE;

  -- Test contexte authenticated
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';

  FOREACH v_table IN ARRAY v_tables LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', v_table) INTO v_count;
    IF v_count > 0 THEN
      RAISE EXCEPTION 'Vérification échouée : authenticated voit % lignes dans %, attendu 0', v_count, v_table;
    END IF;
  END LOOP;

  RESET ROLE;

  RAISE NOTICE 'Paquet L.12bis vérifications OK : 0 ligne visible anon/authenticated sur les 3 archives';
END $$;

COMMIT;

-- =========================================================================
-- Rollback en cas de régression :
-- =========================================================================
-- BEGIN;
--   DROP POLICY "archived_2026_04_08_lockdown" ON public._archived_library_request_claims_20260408;
--   DROP POLICY "archived_2026_04_08_lockdown" ON public._archived_library_request_notification_events_20260408;
--   DROP POLICY "archived_2026_04_08_lockdown" ON public._archived_library_requests_20260408;
--   ALTER TABLE public._archived_library_request_claims_20260408 DISABLE ROW LEVEL SECURITY;
--   ALTER TABLE public._archived_library_request_notification_events_20260408 DISABLE ROW LEVEL SECURITY;
--   ALTER TABLE public._archived_library_requests_20260408 DISABLE ROW LEVEL SECURITY;
-- COMMIT;
-- =========================================================================
