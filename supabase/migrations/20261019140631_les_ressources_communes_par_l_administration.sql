-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — les ressources communes s'écrivent par l'administration (19/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- RÈGLE POSÉE. Dans le bucket public library-ui-assets :
--   - themes/<slug>/… reste écrit par l'équipe qui engage la bibliothèque
--     (user_can_engage_library), comme avant ;
--   - tout le reste (manuals/, catalog/, fichiers à la racine) ne s'écrit plus
--     que par l'administration du réseau — ces ressources sont communes à
--     toutes les bibliothèques.
-- Relevé du 19/10 : aucun écran n'écrit hors de themes/ ; les 42 objets qui
-- s'y trouvent ont été versés à la clé de service (scripts), que ces
-- politiques ne concernent pas.
--
-- Politiques reprises de leur définition réelle de production (pg_policies,
-- 17/10), la seule condition « hors themes/ » remplacée. split_part plutôt que
-- storage.foldername : la même règle tient sur une image sans cette fonction.
-- Tests : tests/sql/ressources_communes_tests.sql.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

DO $storage$
BEGIN
  IF to_regclass('storage.objects') IS NULL THEN
    RAISE NOTICE 'storage.objects absent, politiques non posées';
    RETURN;
  END IF;

  DROP POLICY IF EXISTS "ui assets: scoped insert" ON storage.objects;
  DROP POLICY IF EXISTS "ui assets: scoped update" ON storage.objects;
  DROP POLICY IF EXISTS "ui assets: scoped delete" ON storage.objects;

  CREATE POLICY "ui assets: scoped insert" ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'library-ui-assets' AND (
      (split_part(objects.name, '/', 1) = 'themes' AND EXISTS (
         SELECT 1 FROM public.libraries l
          WHERE l.slug = split_part(objects.name, '/', 2) AND public.user_can_engage_library(l.id)))
      OR (SELECT public.fn_caller_is_network_admin())));

  CREATE POLICY "ui assets: scoped update" ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'library-ui-assets' AND (
      (split_part(objects.name, '/', 1) = 'themes' AND EXISTS (
         SELECT 1 FROM public.libraries l
          WHERE l.slug = split_part(objects.name, '/', 2) AND public.user_can_engage_library(l.id)))
      OR (SELECT public.fn_caller_is_network_admin())))
    WITH CHECK (bucket_id = 'library-ui-assets' AND (
      (split_part(objects.name, '/', 1) = 'themes' AND EXISTS (
         SELECT 1 FROM public.libraries l
          WHERE l.slug = split_part(objects.name, '/', 2) AND public.user_can_engage_library(l.id)))
      OR (SELECT public.fn_caller_is_network_admin())));

  CREATE POLICY "ui assets: scoped delete" ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'library-ui-assets' AND (
      (split_part(objects.name, '/', 1) = 'themes' AND EXISTS (
         SELECT 1 FROM public.libraries l
          WHERE l.slug = split_part(objects.name, '/', 2) AND public.user_can_engage_library(l.id)))
      OR (SELECT public.fn_caller_is_network_admin())));
  -- Pas de COMMENT ON POLICY : cf. 20261013182456 (refusé sur image auto-hébergée).
END $storage$;

DO $verif$
BEGIN
  IF to_regclass('storage.objects') IS NOT NULL AND EXISTS (
       SELECT 1 FROM pg_policies
        WHERE schemaname = 'storage' AND tablename = 'objects'
          AND policyname IN ('ui assets: scoped insert', 'ui assets: scoped update', 'ui assets: scoped delete')
          AND coalesce(with_check, qual) ILIKE '%IS DISTINCT FROM%') THEN
    RAISE EXCEPTION 'ressources communes : une politique laisse encore écrire hors de themes/';
  END IF;
END $verif$;

COMMIT;
