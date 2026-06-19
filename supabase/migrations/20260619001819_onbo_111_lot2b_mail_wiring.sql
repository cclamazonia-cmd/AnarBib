-- =========================================================================
-- #111 — Lot 2b : notifications e-mail de l'échange (câblage DB)
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : Onboarding biblioteca (#111) ; CADRAGE_111_… §4.3
-- Auteur    : AnarBib · Session : Audit 360 — morceaux rouges (ONBO-Q13 + #111)
--
-- POURQUOI
--   Notifier par e-mail les nouveaux messages et invitations d'échange (Lot 2a),
--   en réutilisant la machinerie outbox + EF notify-library-request. Deux nouveaux
--   event_type : 'library_request_message' et 'library_request_invitation'. Branchés
--   par TRIGGERS DÉFENSIFS sur les tables Lot 2a (pas de redéfinition des RPC).
--   L'extension de l'EF (rendu pt-BR de ces 2 events) accompagne ce lot (déployée
--   par la CI). Les e-mails onboarding restent pt-BR (l'EF n'est pas localisée).
--
-- DOCTRINE : enqueue défensif (warning, jamais bloquant — comme tg_library_requests_notify),
-- SECURITY DEFINER search_path fixé, REVOKE complet des trigger functions, NOTIFY pgrst.
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1) Élargit l'allowlist d'event_type de fn_enqueue_library_request_notification
--    (corps repris à l'identique du baseline + 2 nouveaux types).
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "public"."fn_enqueue_library_request_notification"("p_request_id" "uuid", "p_event_type" "text", "p_event_key" "text" DEFAULT NULL::"text", "p_triggered_by_user_id" "uuid" DEFAULT "auth"."uid"()) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'extensions', 'vault'
    AS $$
declare
  v_secret text;
  v_effective_key text;
  v_queue_row_id bigint;
  v_pg_request_id bigint;
  v_url text := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/notify-library-request';
begin
  if p_request_id is null then
    raise exception 'request_id ausente para notificação de solicitação.'
      using errcode = '23514';
  end if;

  if p_event_type not in (
    'library_request_created',
    'library_request_in_analysis',
    'library_request_more_info',
    'library_request_approved',
    'library_request_refused',
    'library_request_message',       -- #111 Lot 2b
    'library_request_invitation'     -- #111 Lot 2b
  ) then
    raise exception 'Tipo de evento inválido para solicitação institucional: %', p_event_type
      using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.library_requests lr
    where lr.id = p_request_id
  ) then
    raise exception 'Solicitação institucional não encontrada para notificação.'
      using errcode = 'P0002';
  end if;

  v_effective_key := nullif(btrim(coalesce(p_event_key, '')), '');
  if v_effective_key is null then
    v_effective_key := p_event_type;
  end if;

  insert into public.library_request_notification_events (
    request_id,
    event_type,
    event_key,
    request_status_snapshot,
    review_notes_snapshot,
    triggered_by_user_id
  )
  select
    lr.id,
    p_event_type,
    v_effective_key,
    lr.request_status,
    lr.review_notes,
    p_triggered_by_user_id
  from public.library_requests lr
  where lr.id = p_request_id
  on conflict (request_id, event_key) do nothing
  returning id into v_queue_row_id;

  if v_queue_row_id is null then
    return null;
  end if;

  select ds.decrypted_secret
    into v_secret
  from vault.decrypted_secrets ds
  where ds.name = 'WEBHOOK_SECRET_NOTIFY_LIBRARY_REQUEST'
  order by ds.created_at desc
  limit 1;

  if coalesce(v_secret, '') = '' then
    raise exception 'Secret WEBHOOK_SECRET_NOTIFY_LIBRARY_REQUEST introuvable dans vault.decrypted_secrets.';
  end if;

  v_pg_request_id := net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    body := jsonb_build_object(
      'request_id', p_request_id,
      'event_type', p_event_type
    ),
    timeout_milliseconds := 60000
  );

  update public.library_request_notification_events
     set pgnet_request_id = v_pg_request_id
   where id = v_queue_row_id;

  return v_pg_request_id;
end;
$$;

-- -------------------------------------------------------------------------
-- 2) Trigger : nouveau message → notification (défensif)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "public"."tg_library_request_message_notify"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  BEGIN
    PERFORM public.fn_enqueue_library_request_notification(
      p_request_id := NEW.request_id,
      p_event_type := 'library_request_message',
      p_event_key := 'message:' || NEW.id::text,
      p_triggered_by_user_id := NEW.author_id
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'library_request_message notify enqueue failed: %', SQLERRM;
  END;
  RETURN NEW;
END;
$$;
ALTER FUNCTION "public"."tg_library_request_message_notify"() OWNER TO "postgres";
REVOKE ALL ON FUNCTION "public"."tg_library_request_message_notify"() FROM PUBLIC;
REVOKE ALL ON FUNCTION "public"."tg_library_request_message_notify"() FROM "anon";
REVOKE ALL ON FUNCTION "public"."tg_library_request_message_notify"() FROM "authenticated";
GRANT ALL ON FUNCTION "public"."tg_library_request_message_notify"() TO "service_role";

DROP TRIGGER IF EXISTS "trg_library_request_message_notify" ON "public"."library_request_messages";
CREATE TRIGGER "trg_library_request_message_notify"
  AFTER INSERT ON "public"."library_request_messages"
  FOR EACH ROW EXECUTE FUNCTION "public"."tg_library_request_message_notify"();

-- -------------------------------------------------------------------------
-- 3) Trigger : invitation proposée / répondue → notification (défensif)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "public"."tg_library_request_invitation_notify"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
BEGIN
  -- INSERT = proposition ; UPDATE de statut vers accepted/declined = réponse.
  IF TG_OP = 'INSERT'
     OR (TG_OP = 'UPDATE' AND NEW.status IN ('accepted','declined') AND NEW.status IS DISTINCT FROM OLD.status) THEN
    BEGIN
      PERFORM public.fn_enqueue_library_request_notification(
        p_request_id := NEW.request_id,
        p_event_type := 'library_request_invitation',
        p_event_key := 'invitation:' || NEW.id::text || ':' || NEW.status,
        p_triggered_by_user_id := coalesce(auth.uid(), NEW.initiated_by)
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'library_request_invitation notify enqueue failed: %', SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$$;
ALTER FUNCTION "public"."tg_library_request_invitation_notify"() OWNER TO "postgres";
REVOKE ALL ON FUNCTION "public"."tg_library_request_invitation_notify"() FROM PUBLIC;
REVOKE ALL ON FUNCTION "public"."tg_library_request_invitation_notify"() FROM "anon";
REVOKE ALL ON FUNCTION "public"."tg_library_request_invitation_notify"() FROM "authenticated";
GRANT ALL ON FUNCTION "public"."tg_library_request_invitation_notify"() TO "service_role";

DROP TRIGGER IF EXISTS "trg_library_request_invitation_notify" ON "public"."library_request_invitations";
CREATE TRIGGER "trg_library_request_invitation_notify"
  AFTER INSERT OR UPDATE OF "status" ON "public"."library_request_invitations"
  FOR EACH ROW EXECUTE FUNCTION "public"."tg_library_request_invitation_notify"();

-- -------------------------------------------------------------------------
-- 4) Test-fumée inline (introspection — pas de mail réel en CI : vault absent).
-- -------------------------------------------------------------------------
DO $smoke$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_enqueue_library_request_notification'::regproc);
  IF position('library_request_message' in v_def) = 0 OR position('library_request_invitation' in v_def) = 0 THEN
    RAISE EXCEPTION '#111 L2b SMOKE ECHEC : allowlist enqueue non élargie';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_library_request_message_notify' AND NOT tgisinternal)
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_library_request_invitation_notify' AND NOT tgisinternal) THEN
    RAISE EXCEPTION '#111 L2b SMOKE ECHEC : triggers de notification absents';
  END IF;
  RAISE NOTICE '#111 L2b SMOKE OK : allowlist + triggers en place.';
END;
$smoke$;

NOTIFY pgrst, 'reload schema';
