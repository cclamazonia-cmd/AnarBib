-- ════════════════════════════════════════════════════════════════════════════
-- Paquet 24c — RLS Storage pour library-ui-assets/themes/{library_slug}/
-- ════════════════════════════════════════════════════════════════════════════
--
-- Contexte :
--   - Bucket `library-ui-assets` est PUBLIC en lecture (storage.buckets.public=true).
--   - Aucune RLS d'écriture n'est définie pour ce bucket → uploads aujourd'hui
--     possibles uniquement via service_role (console Supabase).
--   - Le module UI "identité visuelle" de BibliotecaPage doit pouvoir uploader
--     les 5 fichiers d'un thème (manifest.json, logo.png, favicon.png, bg.webp,
--     logo.svg) dans `themes/{library_slug}/` pour la bibliothèque courante.
--
-- Modèle de référence :
--   Les policies existantes "Coordenadors can upload/update/delete privacy
--   sections" sur le bucket `library-privacy-public`. Différence : ce bucket-là
--   a la structure `{slug}/...` (slug niveau 1) alors que `library-ui-assets`
--   a la structure `themes/{slug}/...` (slug niveau 2).
--
-- Sécurité :
--   - Lecture publique : déjà couverte par le bucket public (aucune policy
--     SELECT nécessaire).
--   - Écriture : ouverte uniquement aux coordenadors/administradors via
--     user_can_engage_library(library_id), sur le path matchant exactement
--     `themes/{library_slug}/...` avec library_slug = slug de la biblio.
--   - Le path doit commencer par 'themes/' (vérifié via foldername[1]='themes')
--     pour ne pas autoriser l'écriture hors du dossier themes/.
--
-- Note : on ne touche pas aux fichiers existants `themes/maloca/` (nom de
--   sous-dossier sans library_slug correspondant) — la policy les laisse en
--   place mais empêche leur modification depuis l'UI tant qu'aucune library
--   n'a slug='maloca'.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── INSERT : autorisation d'upload ─────────────────────────────────────────
CREATE POLICY "Coordenadors can upload library ui assets"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'library-ui-assets'
    AND (storage.foldername(name))[1] = 'themes'
    AND EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(name))[2]
        AND user_can_engage_library(l.id)
    )
  );

-- ─── UPDATE : remplacement d'un fichier existant ────────────────────────────
CREATE POLICY "Coordenadors can update library ui assets"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'library-ui-assets'
    AND (storage.foldername(name))[1] = 'themes'
    AND EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(name))[2]
        AND user_can_engage_library(l.id)
    )
  );

-- ─── DELETE : suppression d'un asset ────────────────────────────────────────
CREATE POLICY "Coordenadors can delete library ui assets"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'library-ui-assets'
    AND (storage.foldername(name))[1] = 'themes'
    AND EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(name))[2]
        AND user_can_engage_library(l.id)
    )
  );

-- ─── Helper : enregistrement automatique dans library_themes ────────────────
-- Quand la coordenadora upload pour la première fois, on veut une entrée
-- library_themes correspondante. RPC SECURITY DEFINER appelée par le frontend
-- après le premier upload réussi.
CREATE OR REPLACE FUNCTION public.fn_ensure_library_theme(p_library_id uuid)
RETURNS TABLE (
  library_slug   text,
  theme_slug     text,
  manifest_path  text,
  is_active      boolean,
  created        boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_slug text;
  v_name text;
  v_existing public.library_themes%ROWTYPE;
  v_created boolean := false;
BEGIN
  -- Authorization gate
  IF NOT user_can_engage_library(p_library_id) THEN
    RAISE EXCEPTION 'not authorized for library %', p_library_id
      USING ERRCODE = '42501';
  END IF;

  SELECT l.slug, COALESCE(l.short_name, l.name)
    INTO v_slug, v_name
  FROM public.libraries l
  WHERE l.id = p_library_id;

  IF v_slug IS NULL THEN
    RAISE EXCEPTION 'library % not found or has no slug', p_library_id
      USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_existing
  FROM public.library_themes
  WHERE library_slug = v_slug
  LIMIT 1;

  IF v_existing.id IS NULL THEN
    INSERT INTO public.library_themes
      (library_slug, library_name, theme_slug, manifest_path, is_active)
    VALUES
      (v_slug, v_name, v_slug, 'themes/' || v_slug || '/manifest.json', true);
    v_created := true;
  ELSE
    -- Garder library_name à jour si la biblio a été renommée.
    UPDATE public.library_themes
       SET library_name = v_name,
           updated_at = now()
     WHERE id = v_existing.id
       AND COALESCE(library_name,'') <> v_name;
  END IF;

  RETURN QUERY
    SELECT t.library_slug, t.theme_slug, t.manifest_path, t.is_active, v_created
    FROM public.library_themes t
    WHERE t.library_slug = v_slug;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_ensure_library_theme(uuid)
  TO authenticated;

COMMENT ON FUNCTION public.fn_ensure_library_theme(uuid) IS
  'Paquet 24c — Garantit l''existence d''une ligne library_themes pour la biblio donnée. Appelée par le module visuel de BibliotecaPage après le premier upload réussi. Auth : user_can_engage_library.';
