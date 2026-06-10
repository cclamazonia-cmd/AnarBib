-- ════════════════════════════════════════════════════════════════════════════
-- Perf RLS : wrapper auth.uid() en (select auth.uid()) — advisor auth_rls_initplan
-- Auteur  : Claude (Opus)
-- Session : Enrichissement données & backlog
-- Date    : 2026-06-10 (UTC)
--
-- Corrige les 64 warnings performance `auth_rls_initplan` (schéma public).
-- Postgres ré-évalue `auth.uid()` PAR LIGNE dans une policy ; enveloppé en
-- `(select auth.uid())`, l'optimiseur l'évalue UNE seule fois (initplan).
--
-- Transformation à ÉQUIVALENCE FONCTIONNELLE garantie : `(select auth.uid())`
-- renvoie exactement la même valeur que `auth.uid()`. Seule la perf change.
-- Vérifié avant écriture : pour les 64 policies, déwrapper la nouvelle
-- expression redonne mot pour mot l'ancienne (aucun changement de logique),
-- et un dry-run (ALTER des 64 puis ROLLBACK) s'est exécuté sans erreur.
--
-- Les 64 policies n'utilisent QUE `auth.uid()` (zéro auth.jwt()/role()/email(),
-- zéro current_setting()). Le bloc ci-dessous applique le même wrap, de façon
-- IDEMPOTENTE (déwrappe d'abord pour éviter tout double `(select ...)`).
-- ════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  r record;
  v_count int := 0;
BEGIN
  FOR r IN
    SELECT format('ALTER POLICY %I ON %I.%I%s%s',
      policyname, schemaname, tablename,
      CASE WHEN qual IS NOT NULL THEN ' USING (' ||
        regexp_replace(
          regexp_replace(qual, '\(\s*select\s+auth\.uid\(\)\s*\)', 'auth.uid()', 'gi'),
          'auth\.uid\(\)', '(select auth.uid())', 'g') || ')' ELSE '' END,
      CASE WHEN with_check IS NOT NULL THEN ' WITH CHECK (' ||
        regexp_replace(
          regexp_replace(with_check, '\(\s*select\s+auth\.uid\(\)\s*\)', 'auth.uid()', 'gi'),
          'auth\.uid\(\)', '(select auth.uid())', 'g') || ')' ELSE '' END
    ) AS stmt
    FROM pg_policies
    WHERE schemaname = 'public'
      AND ( qual ~ 'auth\.uid\(\)' OR with_check ~ 'auth\.uid\(\)' )
  LOOP
    EXECUTE r.stmt;
    v_count := v_count + 1;
  END LOOP;
  RAISE NOTICE 'auth_rls_initplan: % policies wrapped (select auth.uid())', v_count;
END $$;
