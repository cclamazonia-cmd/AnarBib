DROP FUNCTION IF EXISTS public.fn_ensure_library_theme(uuid);

CREATE FUNCTION public.fn_ensure_library_theme(p_library_id uuid)
RETURNS TABLE (
  out_library_slug   text,
  out_theme_slug     text,
  out_manifest_path  text,
  out_is_active      boolean,
  out_created        boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
DECLARE
  v_slug text;
  v_name text;
  v_existing public.library_themes%ROWTYPE;
  v_created boolean := false;
BEGIN
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
  FROM public.library_themes lt
  WHERE lt.library_slug = v_slug
  LIMIT 1;

  IF v_existing.id IS NULL THEN
    INSERT INTO public.library_themes
      (library_slug, library_name, theme_slug, manifest_path, is_active)
    VALUES
      (v_slug, v_name, v_slug, 'themes/' || v_slug || '/manifest.json', true);
    v_created := true;
  ELSE
    UPDATE public.library_themes lt
       SET library_name = v_name,
           updated_at = now()
     WHERE lt.id = v_existing.id
       AND COALESCE(lt.library_name, '') <> v_name;
  END IF;

  RETURN QUERY
    SELECT lt.library_slug, lt.theme_slug, lt.manifest_path, lt.is_active, v_created
    FROM public.library_themes lt
    WHERE lt.library_slug = v_slug;
END;
$func$;

GRANT EXECUTE ON FUNCTION public.fn_ensure_library_theme(uuid)
  TO authenticated;