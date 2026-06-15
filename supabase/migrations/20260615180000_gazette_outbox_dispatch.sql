-- supabase/migrations/20260615180000_gazette_outbox_dispatch.sql
-- Étape A du branchement e-mail Gazette : dispatch des events de l'outbox
-- gazette_submission_notification_outbox vers l'Edge Function notify-event,
-- en répliquant À L'IDENTIQUE le dispatcher canonique des autres outbox
-- (public.fn_team_outbox_dispatch_trigger). Additif, non destructif.
-- Les deux events câblés : gazette.contribution.received, gazette.draft.ready_for_review.

-- 1) Autoriser le statut 'skipped' (fan-out vide), aligné sur les autres outbox
--    (le handler le pose quand il n'y a aucun destinataire). Drop du CHECK inline
--    anonyme posé par 20260615064958, puis re-création nommée.
do $$
declare c text;
begin
  select conname into c from pg_constraint
   where conrelid = 'public.gazette_submission_notification_outbox'::regclass
     and contype = 'c'
     and pg_get_constraintdef(oid) ilike '%status%';
  if c is not null then
    execute format('alter table public.gazette_submission_notification_outbox drop constraint %I', c);
  end if;
end $$;
alter table public.gazette_submission_notification_outbox
  add constraint gazette_submission_outbox_status_check
  check (status in ('queued','sent','failed','skipped'));

-- 2) Dispatcher : réplique exacte de fn_team_outbox_dispatch_trigger (table gazette).
--    POST {event, record_id} → notify-event, en-tête x-webhook-secret depuis le Vault.
--    Le statut final (sent/failed/skipped) est posé par le handler EF ; ici on ne
--    fait que déclencher l'appel et mémoriser pg_net_request_id (pour le reconcile).
create or replace function public.fn_gazette_outbox_dispatch_trigger()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_url text;
  v_secret text;
  v_request_id bigint;
  v_outbox_payload jsonb;
begin
  v_url := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/notify-event';

  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'WEBHOOK_SECRET_NOTIFY_EVENT';

  if v_secret is null or v_secret = '' then
    update public.gazette_submission_notification_outbox
       set status = 'failed',
           last_error = 'WEBHOOK_SECRET_NOTIFY_EVENT vide ou introuvable dans vault',
           attempts = attempts + 1
     where id = NEW.id;
    return NEW;
  end if;

  v_outbox_payload := jsonb_build_object('event', NEW.event, 'record_id', NEW.id);

  begin
    select net.http_post(
      url := v_url,
      body := v_outbox_payload,
      headers := jsonb_build_object(
        'content-type', 'application/json',
        'x-webhook-secret', v_secret
      )
    ) into v_request_id;

    update public.gazette_submission_notification_outbox
       set pg_net_request_id = v_request_id,
           attempts = attempts + 1
     where id = NEW.id;

  exception
    when others then
      update public.gazette_submission_notification_outbox
         set status = 'failed',
             last_error = SQLERRM,
             attempts = attempts + 1
       where id = NEW.id;
  end;

  return NEW;
end;
$function$;

-- 3) Trigger AFTER INSERT FOR EACH ROW (idempotent).
drop trigger if exists trg_gazette_outbox_dispatch on public.gazette_submission_notification_outbox;
create trigger trg_gazette_outbox_dispatch
  after insert on public.gazette_submission_notification_outbox
  for each row execute function public.fn_gazette_outbox_dispatch_trigger();
