-- =====================================================================
-- AnarBib — Tests : une relation accordée se lit sans erreur
-- Date    : 2026-09-27  ·  Item B31
-- Ref     : 20260927184425_b31_une_relation_accordee_se_lit_sans_erreur
--
-- Un droit SELECT promet une lecture. Quand la lecture lève une erreur — une
-- policy qui appelle une fonction fermée au rôle, une vue security_invoker qui
-- lit une table que le rôle ne lit pas —, le droit ment : le client reçoit un
-- 42501 là où la doctrine promet une liste vide (table sous RLS) ou un refus
-- net (relation non accordée). Recensement du 27/09 en production : 13
-- relations dans ce cas pour anon, 10 pour un compte connecté sans adhésion.
--
-- Ce que la suite tient, pour TOUTE relation de public et api (tables, vues,
-- vues matérialisées) accordée en lecture au rôle :
--   T1 lue sous anon, elle ne lève aucune erreur ;
--   T2 lue sous un compte connecté SANS adhésion, non plus ;
--   T3 le détecteur mord (vue temporaire accordée qui lit une table fermée).
-- Liste fermée des exceptions assumées : VIDE. Une vue neuve naît accordée à
-- anon et authenticated (privilèges par défaut du schéma) : si elle lit ce
-- qu'ils ne lisent pas, lui retirer le droit dans la même migration.
--   Bilan OK : 'LECTURE-ACCORDEE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_n int; v_txt text;
BEGIN
  -- Lit chaque relation accordée au rôle (ou la seule relation p_oid) sous ce
  -- rôle et ces claims, et rend celles qui lèvent une erreur.
  CREATE FUNCTION pg_temp.b31_erreurs(p_role text, p_claims text, p_oid oid DEFAULT NULL)
  RETURNS TABLE(rel text, err text) LANGUAGE plpgsql AS $f$
  DECLARE r record; v int;
  BEGIN
    FOR r IN
      SELECT n.nspname AS sch, c.relname AS nom
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE c.relkind IN ('r', 'v', 'm', 'p')
         AND CASE WHEN p_oid IS NULL THEN n.nspname IN ('public', 'api') ELSE c.oid = p_oid END
         AND has_table_privilege(p_role, c.oid, 'SELECT')
       ORDER BY 1, 2
    LOOP
      BEGIN
        PERFORM set_config('request.jwt.claims', p_claims, true);
        EXECUTE format('SET LOCAL ROLE %I', p_role);
        EXECUTE format('SELECT count(*) FROM %I.%I', r.sch, r.nom) INTO v;
        EXECUTE 'RESET ROLE';
      EXCEPTION WHEN OTHERS THEN
        EXECUTE 'RESET ROLE';
        rel := r.sch || '.' || r.nom;
        err := SQLSTATE || ' ' || left(SQLERRM, 100);
        RETURN NEXT;
      END;
    END LOOP;
  END $f$;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 sous anon, aucune relation accordée ne lève d''erreur';
  BEGIN
    SELECT string_agg(rel || ' (' || err || ')', ' ; ' ORDER BY rel) INTO v_txt
      FROM pg_temp.b31_erreurs('anon', '{"role":"anon"}');
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt
      || ' — table : une policy qui rend zéro ligne à anon ; vue : REVOKE ALL … FROM anon'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 sous un compte connecté sans adhésion, aucune relation accordée ne lève d''erreur';
  BEGIN
    SELECT string_agg(rel || ' (' || err || ')', ' ; ' ORDER BY rel) INTO v_txt
      FROM pg_temp.b31_erreurs('authenticated', '{"sub":"b31b31b3-0000-4000-8000-000000000001","role":"authenticated"}');
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt
      || ' — une vue que authenticated ne peut pas lire ne lui est pas accordée ; une fonction appelée par une vue security_invoker doit lui être exécutable'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 le détecteur mord : une vue accordée qui lit une table fermée';
  BEGIN
    CREATE TEMP VIEW _b31_epreuve WITH (security_invoker = true) AS
      SELECT count(*) AS n FROM public.user_library_memberships;
    GRANT SELECT ON _b31_epreuve TO anon;
    SELECT count(*), string_agg(err, ' ; ') INTO v_n, v_txt
      FROM pg_temp.b31_erreurs('anon', '{"role":"anon"}', '_b31_epreuve'::regclass);
    DROP VIEW _b31_epreuve;
    IF v_n = 1 AND v_txt LIKE '42501%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : attendu une erreur 42501, lu ' || v_n || ' -> ' || coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'LECTURE-ACCORDEE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'LECTURE-ACCORDEE OK : %/%', v_passed, v_passed;
END $$;
