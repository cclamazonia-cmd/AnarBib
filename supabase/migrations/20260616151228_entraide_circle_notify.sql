-- ════════════════════════════════════════════════════════════════════════════
-- Entraide — notification au cercle (sans toucher au dispatcher)
-- Session : Fédération — Communs & Entraide
-- Cadrage : docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15.md (§7-8)
--
-- Quand un appel est créé ROUTÉ vers un cercle (circle_id non null), on émet un
-- event payload-based (record_id factice = 1, comme les notifs partenariat) ; le
-- handler edge-function `entraide_request_circle` (domain/entraide.ts) résout les
-- membres du cercle → leur staff → e-mail dans leur langue. Le dispatcher
-- fn_dispatch_notify_event est INCHANGÉ (il transmet event + payload).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_entraide_notify_circle_on_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NEW.circle_id IS NOT NULL THEN
    PERFORM public.fn_dispatch_notify_event('entraide_request_circle', 1, jsonb_build_object(
      'request_id',     NEW.id::text,
      'circle_id',      NEW.circle_id::text,
      'subject',        NEW.subject,
      'author_user_id', NEW.author_user_id::text
    ));
  END IF;
  RETURN NULL;
END $function$;
REVOKE EXECUTE ON FUNCTION public.fn_entraide_notify_circle_on_insert() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_entraide_notify_circle ON public.entraide_help_requests;
CREATE TRIGGER trg_entraide_notify_circle
  AFTER INSERT ON public.entraide_help_requests
  FOR EACH ROW EXECUTE FUNCTION public.fn_entraide_notify_circle_on_insert();

NOTIFY pgrst, 'reload schema';
