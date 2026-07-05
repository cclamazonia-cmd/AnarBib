-- 20260705193042_notify_library_event_created.sql
-- Avis in-app « nouvel événement à la bibliothèque » (cloche + onglet « avisos »).
--
-- À la création d'un événement PUBLIC (public.library_events), fan-out d'une
-- notification vers tous les membres actifs de la biblio, sauf le créateur.
-- In-app uniquement (pas d'e-mail). Ne se déclenche pas pour les brouillons
-- (is_public = false) ni pour les éditions (INSERT seulement).
--
-- Modèle : api.fn_gazette_broadcast (fan-out user_notifications aux membres,
-- title/body = clés i18n ou littéral, link_type/link_id pour la navigation).

CREATE OR REPLACE FUNCTION "public"."tg_notify_library_event_created"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
DECLARE
  v_lib_name text;
BEGIN
  SELECT COALESCE(l.short_name, l.name) INTO v_lib_name
  FROM public.libraries l WHERE l.id = NEW.library_id;

  INSERT INTO public.user_notifications (
    user_id, library_id, category, title, body, link_type, link_id, is_read
  )
  SELECT DISTINCT
    m.user_id,
    NEW.library_id,
    'library_event',
    'notif.libraryEvent.created.title',      -- clé i18n, traduite au rendu
    NEW.title || COALESCE(' · ' || v_lib_name, ''),  -- littéral : titre · biblio
    'library_event',
    NEW.id::text,
    false
  FROM public.user_library_memberships m
  WHERE m.library_id = NEW.library_id
    AND m.status = 'active'
    AND m.user_id IS DISTINCT FROM NEW.created_by;

  RETURN NULL;
END;
$$;

ALTER FUNCTION "public"."tg_notify_library_event_created"() OWNER TO "postgres";
REVOKE ALL ON FUNCTION "public"."tg_notify_library_event_created"() FROM PUBLIC;

COMMENT ON FUNCTION "public"."tg_notify_library_event_created"() IS 'Fan-out d''un avis in-app « nouvel événement à la bibliothèque » aux membres actifs (sauf le créateur) à la création d''un événement public. Ajouté 2026-07-05.';

CREATE TRIGGER "trg_notify_library_event_created"
    AFTER INSERT ON "public"."library_events"
    FOR EACH ROW
    WHEN (NEW.is_public = true AND NEW.is_cancelled = false)
    EXECUTE FUNCTION "public"."tg_notify_library_event_created"();
