-- #PN-2 — éviter le 404 sur themes/<slug>/manifest.json pour les bibliothèques
-- sans thème custom. Source de vérité = présence RÉELLE de l'objet manifeste
-- dans le bucket Storage 'library-ui-assets' (library_themes n'est qu'un
-- registre d'« éditeur ouvert », pas une preuve de manifeste).
--
-- Le frontend (LibraryContext) posera themeSlug = theme_slug || 'default' :
--   - theme_slug renseigné  -> useTheme(slug)    -> manifeste existe (200)
--   - theme_slug NULL        -> useTheme('default') -> default existe (200)
-- => plus aucune requête vers un manifeste inexistant, donc plus de 404.

BEGIN;

-- 1) Colonne (nullable). NULL = pas de thème custom -> default.
ALTER TABLE public.libraries ADD COLUMN IF NOT EXISTS theme_slug text;

COMMENT ON COLUMN public.libraries.theme_slug IS
  'Slug de theme custom si themes/<slug>/manifest.json existe dans le bucket library-ui-assets ; NULL = theme par defaut. Maintenu par api.fn_set_library_theme_active (upload/suppression du manifeste cote frontend).';

-- Le grant SELECT au niveau table couvre deja les nouvelles colonnes, mais on
-- ajoute un grant colonne defensif (idempotent) au cas ou des grants
-- colonne-par-colonne seraient en place.
GRANT SELECT (theme_slug) ON public.libraries TO anon, authenticated;

-- 2) Backfill AUTORITATIF depuis Storage (presence reelle du manifeste).
UPDATE public.libraries l
   SET theme_slug = lower(l.slug)
 WHERE EXISTS (
   SELECT 1 FROM storage.objects o
   WHERE o.bucket_id = 'library-ui-assets'
     AND o.name = 'themes/' || lower(l.slug) || '/manifest.json'
 );

-- 3) RPC de synchro, appelee par le frontend a l'upload/suppression du manifeste.
--    Garde staff identique a fn_ensure_library_theme (user_can_engage_library).
CREATE OR REPLACE FUNCTION api.fn_set_library_theme_active(p_library_id uuid, p_active boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.user_can_engage_library(p_library_id) THEN
    RAISE EXCEPTION 'not authorized for library %', p_library_id USING ERRCODE = '42501';
  END IF;

  UPDATE public.libraries
     SET theme_slug = CASE WHEN p_active THEN slug ELSE NULL END
   WHERE id = p_library_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.fn_set_library_theme_active(uuid, boolean) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.fn_set_library_theme_active(uuid, boolean) TO authenticated;

-- 4) Verification (auto-rollback si echec).
DO $verify$
DECLARE
  v_blmf text;
  v_test text;
BEGIN
  -- backfill : blmf a un manifeste -> theme_slug = 'blmf'
  SELECT theme_slug INTO v_blmf FROM public.libraries WHERE lower(slug) = 'blmf';
  IF v_blmf IS DISTINCT FROM 'blmf' THEN
    RAISE EXCEPTION 'PN-2 backfill: blmf.theme_slug attendu = blmf, obtenu = %', v_blmf;
  END IF;

  -- biblio sans manifeste -> theme_slug reste NULL
  SELECT theme_slug INTO v_test FROM public.libraries WHERE lower(slug) = 'blt-test-informal';
  IF v_test IS NOT NULL THEN
    RAISE EXCEPTION 'PN-2 backfill: blt-test-informal.theme_slug attendu = NULL, obtenu = %', v_test;
  END IF;

  -- REVOKE : anon ne doit pas pouvoir executer la RPC
  IF has_function_privilege('anon', 'api.fn_set_library_theme_active(uuid, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'PN-2: anon ne doit pas avoir EXECUTE sur api.fn_set_library_theme_active';
  END IF;
END;
$verify$;

COMMIT;
