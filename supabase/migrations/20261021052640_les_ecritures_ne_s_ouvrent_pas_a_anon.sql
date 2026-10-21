-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — les fonctions d'écriture ne s'ouvrent pas à anon (21/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- 1. Des fonctions SECURITY INVOKER qui ÉCRIVENT — les tâches internes
--    (fn_task_*), la politique de rétention, l'ouverture d'un brouillon —
--    étaient exécutables par anon, par le grant hérité de PUBLIC et par les
--    privilèges par défaut du schéma public : contraire à DOC-OBJ-2. Elles ne
--    servent qu'à des écrans staff, toujours sous session ; seules la RLS et
--    leurs gardes internes fermaient la porte. EXECUTE est retiré à PUBLIC et à
--    anon, et rendu explicitement à authenticated et service_role.
--    Relevé en production le 21/10 : six fn_task_* + fn_set_retention_policy +
--    fn_touch_draft_opened. La sélection est faite ici par motif (INVOKER,
--    VOLATILE, exécutable par anon), pas par une liste : une signature changée
--    entre-temps reste couverte. (Le nom d'une tâche n'est pas écrit en toutes
--    lettres : src/tests/task-status-vocabulaire.test.js lit le corps de
--    fn_task_* dans « la dernière migration qui la nomme ».)
-- 2. public.fn_locale_from_idioma (IMMUTABLE, pure) : search_path figé
--    (avis function_search_path_mutable). Ses droits ne changent pas.
--
-- Tests : tests/sql/hygiene_search_path_et_initplan_tests.sql et
-- tests/sql/grants_herites_tests.sql (rejeu), vérification ci-dessous.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.ecritures_ouvertes_a_anon()
RETURNS SETOF regprocedure
LANGUAGE sql
AS $$
  SELECT p.oid::regprocedure
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND NOT p.prosecdef
     AND p.provolatile = 'v'
     AND (p.proname LIKE 'fn\_task\_%' OR p.proname IN ('fn_set_retention_policy', 'fn_touch_draft_opened'))
     AND has_function_privilege('anon', p.oid, 'EXECUTE');
$$;

DO $revoquer$
DECLARE
  f regprocedure;
  n int := 0;
BEGIN
  FOR f IN SELECT * FROM pg_temp.ecritures_ouvertes_a_anon() LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'fonctions d''écriture refermées à anon : %', n;
END $revoquer$;

DO $chemin$
BEGIN
  IF to_regprocedure('public.fn_locale_from_idioma(text)') IS NOT NULL THEN
    ALTER FUNCTION public.fn_locale_from_idioma(text) SET search_path = public, pg_catalog;
  END IF;
END $chemin$;

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verif$
DECLARE
  reste int;
BEGIN
  SELECT count(*) INTO reste FROM pg_temp.ecritures_ouvertes_a_anon();
  IF reste > 0 THEN
    RAISE EXCEPTION 'encore % fonction(s) d''écriture exécutable(s) par anon', reste;
  END IF;
  IF EXISTS (
       SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND NOT p.prosecdef AND p.provolatile = 'v'
          AND (p.proname LIKE 'fn\_task\_%' OR p.proname IN ('fn_set_retention_policy', 'fn_touch_draft_opened'))
          AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')) THEN
    RAISE EXCEPTION 'une fonction d''écriture n''est plus exécutable par authenticated';
  END IF;
  IF to_regprocedure('public.fn_locale_from_idioma(text)') IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM pg_proc WHERE oid = 'public.fn_locale_from_idioma(text)'::regprocedure
          AND array_to_string(proconfig, ',') LIKE 'search_path=%') THEN
    RAISE EXCEPTION 'fn_locale_from_idioma : search_path non figé';
  END IF;
END $verif$;

COMMIT;
