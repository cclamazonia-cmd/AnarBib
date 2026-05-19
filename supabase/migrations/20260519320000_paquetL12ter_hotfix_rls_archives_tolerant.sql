-- =========================================================================
-- Paquet L.12ter (hotfix du hotfix) — RLS archives, DO-block tolérant
-- =========================================================================
-- Date     : 2026-05-19
-- Chantier : hotfix du hotfix L.12bis
-- Auteur   : Xavier
--
-- CONTEXTE :
--   Le hotfix L.12bis a planté à l'application (Woodpecker, 19/05/2026)
--   avec ERROR: permission denied for table (SQLSTATE 42501).
--
--   Diagnostic : les 3 tables _archived_*_20260408 n'ont AUCUN GRANT SELECT
--   accordé à anon ni authenticated au niveau table-level. Donc la
--   tentative de SELECT dans le DO-block plante AVANT même que la policy
--   RLS soit évaluée.
--
--   La conclusion sécurité reste la même : anon et authenticated ne peuvent
--   rien lire. Mais le mécanisme de blocage est ici au niveau GRANT, pas RLS.
--
-- OBJECTIF :
--   Appliquer le même fix que L.12bis (ENABLE RLS + policy lock-down)
--   MAIS avec un DO-block qui accepte permission denied (42501) comme
--   succès, puisque c'est l'objectif visé.
--
-- LEÇON DOCTRINALE (à ajouter à la doctrine) :
--   Pour tester l'inaccessibilité d'une table en anon/authenticated dans
--   un DO-block, TOUJOURS encadrer le SELECT par un BEGIN/EXCEPTION qui
--   attrape SQLSTATE '42501' (permission denied) ET traite cela comme
--   un succès, parce que le blocage peut venir de GRANT ou de RLS, et
--   les deux sont des défenses légitimes.
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
-- 2. Policy lock-down explicite sur chaque table (ceinture en plus des
-- bretelles GRANT)
-- -------------------------------------------------------------------------

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
  'RLS activée + policy lock-down (USING false) par paquet L.12ter (19/05/2026). '
  'Pas de GRANT anon/authenticated (double verrou). Accessible uniquement via service_role.';

COMMENT ON TABLE public._archived_library_request_notification_events_20260408 IS
  'Archive gelée du 08/04/2026 — table inerte, 1 ligne historique. '
  'RLS activée + policy lock-down (USING false) par paquet L.12ter (19/05/2026). '
  'Pas de GRANT anon/authenticated (double verrou). Accessible uniquement via service_role.';

COMMENT ON TABLE public._archived_library_requests_20260408 IS
  'Archive gelée du 08/04/2026 — table inerte, 1 ligne historique. '
  'RLS activée + policy lock-down (USING false) par paquet L.12ter (19/05/2026). '
  'Pas de GRANT anon/authenticated (double verrou). Accessible uniquement via service_role.';

-- -------------------------------------------------------------------------
-- 4. DO-block de vérification TOLÉRANT aux deux mécanismes de blocage
--
-- Le SELECT en contexte anon/authenticated doit échouer pour une des deux
-- raisons légitimes :
--   (a) SQLSTATE 42501 : permission denied (pas de GRANT) → succès
--   (b) SELECT retourne 0 ligne (RLS bloque) → succès
-- Toute autre situation est une régression.
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
  v_anon_blocked boolean;
  v_auth_blocked boolean;
BEGIN
  -- ==== Test contexte anon ====
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{}';

  FOREACH v_table IN ARRAY v_tables LOOP
    v_anon_blocked := false;
    BEGIN
      EXECUTE format('SELECT count(*) FROM public.%I', v_table) INTO v_count;
      IF v_count = 0 THEN
        v_anon_blocked := true;  -- RLS bloque
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN
        v_anon_blocked := true;  -- GRANT bloque (42501)
    END;

    IF NOT v_anon_blocked THEN
      RAISE EXCEPTION 'Vérification échouée : anon peut lire des lignes dans %', v_table;
    END IF;
  END LOOP;

  RESET ROLE;

  -- ==== Test contexte authenticated ====
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';

  FOREACH v_table IN ARRAY v_tables LOOP
    v_auth_blocked := false;
    BEGIN
      EXECUTE format('SELECT count(*) FROM public.%I', v_table) INTO v_count;
      IF v_count = 0 THEN
        v_auth_blocked := true;
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN
        v_auth_blocked := true;
    END;

    IF NOT v_auth_blocked THEN
      RAISE EXCEPTION 'Vérification échouée : authenticated peut lire des lignes dans %', v_table;
    END IF;
  END LOOP;

  RESET ROLE;

  RAISE NOTICE 'Paquet L.12ter vérifications OK : anon et authenticated bloqués sur les 3 archives (par GRANT ou RLS)';
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
