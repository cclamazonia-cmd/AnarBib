-- supabase/migrations/20260616174840_lettre_optin_dispatch.sql
-- Lot 2 (paquet 2c) — Dispatch e-mail de l'outbox Lettre vers l'EF notify-event.
-- Réplique À L'IDENTIQUE le dispatcher canonique (fn_gazette_outbox_dispatch_trigger)
-- pour public.lettre_notification_outbox. Ajoute les colonnes de suivi pg_net.
-- POST {event, record_id} → notify-event (handler domain/lettre.ts). Idempotent.

-- 1) Colonnes de suivi attendues par le dispatcher (alignées sur les autres outbox).
alter table public.lettre_notification_outbox
  add column if not exists attempts int not null default 0,
  add column if not exists pg_net_request_id bigint;

-- 2) Dispatcher : réplique de fn_gazette_outbox_dispatch_trigger (table lettre).
create or replace function public.fn_lettre_outbox_dispatch_trigger()
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
    update public.lettre_notification_outbox
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

    update public.lettre_notification_outbox
       set pg_net_request_id = v_request_id,
           attempts = attempts + 1
     where id = NEW.id;

  exception
    when others then
      update public.lettre_notification_outbox
         set status = 'failed',
             last_error = SQLERRM,
             attempts = attempts + 1
       where id = NEW.id;
  end;

  return NEW;
end;
$function$;

-- 3) Trigger AFTER INSERT FOR EACH ROW (idempotent).
drop trigger if exists trg_lettre_outbox_dispatch on public.lettre_notification_outbox;
create trigger trg_lettre_outbox_dispatch
  after insert on public.lettre_notification_outbox
  for each row execute function public.fn_lettre_outbox_dispatch_trigger();

notify pgrst, 'reload schema';
