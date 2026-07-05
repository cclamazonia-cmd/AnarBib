-- 20260705194619_library_events_notif_prefs_and_deferred.sql
-- Deux évolutions des avis d'événements de bibliothèque :
--  (1) opt-out lecteur `disable_library_events` (préférence de notification) ;
--  (3) publication différée : notifier au passage brouillon -> public, une
--      seule fois, via library_events.notified_at + trigger INSERT OR UPDATE.
-- (La feature 2 « deep-link vers l'onglet Événements » est purement front.)

-- ── (1) Préférence opt-out lecteur ───────────────────────────────────────
ALTER TABLE public.user_notification_preferences
  ADD COLUMN IF NOT EXISTS disable_library_events boolean NOT NULL DEFAULT false;

-- fn_get : DROP+CREATE (ajouter une colonne au RETURNS TABLE change le type de
-- retour, interdit par CREATE OR REPLACE).
DROP FUNCTION IF EXISTS public.fn_get_my_notification_preferences();
CREATE FUNCTION public.fn_get_my_notification_preferences()
 RETURNS TABLE(disable_reserva_pronta boolean, disable_consulta_pronta boolean, disable_rede_news boolean, disable_library_events boolean)
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth required'
      USING HINT = 'fn_get_my_notification_preferences: no authenticated user';
  END IF;
  RETURN QUERY
  SELECT
    COALESCE(p.disable_reserva_pronta, false),
    COALESCE(p.disable_consulta_pronta, false),
    COALESCE(p.disable_rede_news, false),
    COALESCE(p.disable_library_events, false)
  FROM (SELECT v_user_id AS uid) u
  LEFT JOIN public.user_notification_preferences p ON p.user_id = u.uid;
END;
$function$;
ALTER FUNCTION public.fn_get_my_notification_preferences() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_get_my_notification_preferences() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_get_my_notification_preferences() TO authenticated, service_role;

-- fn_set : DROP l'ancienne (3 args) puis CREATE avec le 4e param (DEFAULT false
-- pour rester compatible avec un front encore en cache appelant 3 params).
DROP FUNCTION IF EXISTS public.fn_set_my_notification_preferences(boolean, boolean, boolean);
CREATE FUNCTION public.fn_set_my_notification_preferences(
  p_disable_reserva_pronta boolean,
  p_disable_consulta_pronta boolean,
  p_disable_rede_news boolean DEFAULT false,
  p_disable_library_events boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth required'
      USING HINT = 'fn_set_my_notification_preferences: no authenticated user';
  END IF;
  INSERT INTO public.user_notification_preferences (
    user_id, disable_reserva_pronta, disable_consulta_pronta, disable_rede_news, disable_library_events, updated_at
  )
  VALUES (
    v_user_id,
    COALESCE(p_disable_reserva_pronta, false),
    COALESCE(p_disable_consulta_pronta, false),
    COALESCE(p_disable_rede_news, false),
    COALESCE(p_disable_library_events, false),
    now()
  )
  ON CONFLICT (user_id) DO UPDATE
    SET disable_reserva_pronta  = EXCLUDED.disable_reserva_pronta,
        disable_consulta_pronta = EXCLUDED.disable_consulta_pronta,
        disable_rede_news       = EXCLUDED.disable_rede_news,
        disable_library_events  = EXCLUDED.disable_library_events,
        updated_at              = now();
END;
$function$;
ALTER FUNCTION public.fn_set_my_notification_preferences(boolean, boolean, boolean, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_set_my_notification_preferences(boolean, boolean, boolean, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_set_my_notification_preferences(boolean, boolean, boolean, boolean) TO authenticated, service_role;

-- ── (3) Publication différée : notif une seule fois ──────────────────────
ALTER TABLE public.library_events
  ADD COLUMN IF NOT EXISTS notified_at timestamp with time zone;
COMMENT ON COLUMN public.library_events.notified_at IS 'Horodatage du fan-out de l''avis « nouvel événement » (une seule fois, à la 1re publication). NULL = pas encore notifié. Ajouté 2026-07-05.';

-- Fonction trigger : gate opt-out (disable_library_events) + stamp notified_at.
CREATE OR REPLACE FUNCTION public.tg_notify_library_event_created() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
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
    'notif.libraryEvent.created.title',
    NEW.title || COALESCE(' · ' || v_lib_name, ''),
    'library_event',
    NEW.id::text,
    false
  FROM public.user_library_memberships m
  LEFT JOIN public.user_notification_preferences np ON np.user_id = m.user_id
  WHERE m.library_id = NEW.library_id
    AND m.status = 'active'
    AND m.user_id IS DISTINCT FROM NEW.created_by
    AND COALESCE(np.disable_library_events, false) = false;

  -- Marque l'événement comme notifié (le WHEN du trigger empêche la récursion :
  -- à ce ré-UPDATE, NEW.notified_at IS NOT NULL -> WHEN faux -> pas de re-fan-out).
  UPDATE public.library_events SET notified_at = now() WHERE id = NEW.id;

  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.tg_notify_library_event_created() IS 'Fan-out d''un avis in-app « nouvel événement à la bibliothèque » aux membres actifs (sauf le créateur, hors opt-out disable_library_events) à la 1re publication d''un événement public. Idempotent via library_events.notified_at. MàJ 2026-07-05.';

-- Trigger : INSERT OR UPDATE, une seule fois (notified_at IS NULL).
DROP TRIGGER IF EXISTS trg_notify_library_event_created ON public.library_events;
CREATE TRIGGER trg_notify_library_event_created
  AFTER INSERT OR UPDATE ON public.library_events
  FOR EACH ROW
  WHEN (NEW.is_public = true AND NEW.is_cancelled = false AND NEW.notified_at IS NULL)
  EXECUTE FUNCTION public.tg_notify_library_event_created();
