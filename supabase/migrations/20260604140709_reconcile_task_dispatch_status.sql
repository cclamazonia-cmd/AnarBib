-- =============================================================================
-- Reconciliation du statut de dispatch des outbox de taches internes
-- =============================================================================
-- Probleme : dispatch_task_notification_outbox / dispatch_task_invitation_outbox
-- posent dispatch_status='sent' juste apres net.http_post (asynchrone) sans
-- jamais relire l'issue HTTP. Un 401/500/timeout renvoye plus tard dans
-- net._http_response restait masque sous 'sent'. C'est ce qui avait masque le
-- 401 d'authentification de notify-internal-task (06/2026).
--
-- Fix (minimal, SANS toucher les dispatchers ni le chemin chaud) :
--   un cron relit net._http_response par request_id et
--     - rabat les faux 'sent' (non-2xx / status null / timeout) -> 'failed'
--       (+ last_error), avec miroir sur painel_internal_task_invites ;
--     - estampille reconciled_at sur les 2xx confirmes.
--
-- Semantique resultante (sans nouvel etat ; CHECK inchange queued/sent/failed/skipped) :
--   'sent' + reconciled_at NON NUL  = livraison confirmee (2xx) ;
--   'sent' + reconciled_at NUL      = tire, pas encore confirme (fenetre transitoire) ;
--   'failed'                        = echec HTTP confirme (last_error renseigne).
--
-- Limite connue : une ligne 'sent' dont la reponse pg_net n'arrive jamais / est
-- purgee avant le passage du cron reste 'sent' non reconciliee (best-effort).
-- Le cron tourne toutes les 5 min ; les reponses pg_net persistent plusieurs
-- heures, donc le cas est rare.
-- =============================================================================

-- 1) Marqueur d'idempotence de la reconciliation (additif, non destructif)
alter table public.painel_internal_task_notification_outbox
  add column if not exists reconciled_at timestamptz;

alter table public.painel_internal_task_invitation_outbox
  add column if not exists reconciled_at timestamptz;

-- 2) Fonction de reconciliation (privee, appelee par cron)
create or replace function public.fn_cron_reconcile_task_dispatch(p_limit integer default 500)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_notif_failed integer := 0;
  v_notif_ok     integer := 0;
  v_inv_failed   integer := 0;
  v_inv_ok       integer := 0;
begin
  -- --- OUTBOX NOTIFICATIONS : echecs (non-2xx, status null, timeout) -> failed
  update public.painel_internal_task_notification_outbox o
     set dispatch_status = 'failed',
         last_error = left('HTTP ' || coalesce(r.status_code::text, '(sem status)')
                      || case when r.timed_out then ' [timeout]' else '' end
                      || ' :: ' || coalesce(nullif(btrim(r.content), ''), r.error_msg, ''), 500),
         reconciled_at = now(),
         updated_at = now()
    from net._http_response r
   where r.id = o.request_id
     and o.dispatch_status = 'sent'
     and o.request_id is not null
     and o.reconciled_at is null
     and (r.status_code is null or r.status_code < 200 or r.status_code >= 300);
  get diagnostics v_notif_failed = row_count;

  -- --- OUTBOX NOTIFICATIONS : 2xx confirmes -> estampille reconciled_at
  update public.painel_internal_task_notification_outbox o
     set reconciled_at = now(),
         updated_at = now()
    from net._http_response r
   where r.id = o.request_id
     and o.dispatch_status = 'sent'
     and o.request_id is not null
     and o.reconciled_at is null
     and r.status_code between 200 and 299;
  get diagnostics v_notif_ok = row_count;

  -- --- OUTBOX INVITATIONS : echecs -> failed, avec miroir sur la table invites
  with failed as (
    update public.painel_internal_task_invitation_outbox o
       set dispatch_status = 'failed',
           last_error = left('HTTP ' || coalesce(r.status_code::text, '(sem status)')
                        || case when r.timed_out then ' [timeout]' else '' end
                        || ' :: ' || coalesce(nullif(btrim(r.content), ''), r.error_msg, ''), 500),
           reconciled_at = now(),
           updated_at = now()
      from net._http_response r
     where r.id = o.request_id
       and o.dispatch_status = 'sent'
       and o.request_id is not null
       and o.reconciled_at is null
       and (r.status_code is null or r.status_code < 200 or r.status_code >= 300)
    returning o.invite_id, o.last_error
  ),
  mirror as (
    update public.painel_internal_task_invites i
       set invite_status = 'failed',
           last_error = failed.last_error,
           updated_at = now()
      from failed
     where i.id = failed.invite_id
       and i.invite_status = 'sent'
    returning 1
  )
  select count(*) into v_inv_failed from failed;

  -- --- OUTBOX INVITATIONS : 2xx confirmes -> estampille reconciled_at
  update public.painel_internal_task_invitation_outbox o
     set reconciled_at = now(),
         updated_at = now()
    from net._http_response r
   where r.id = o.request_id
     and o.dispatch_status = 'sent'
     and o.request_id is not null
     and o.reconciled_at is null
     and r.status_code between 200 and 299;
  get diagnostics v_inv_ok = row_count;

  return jsonb_build_object(
    'ok', true,
    'notif_failed', v_notif_failed,
    'notif_confirmed', v_notif_ok,
    'invite_failed', v_inv_failed,
    'invite_confirmed', v_inv_ok
  );
end;
$function$;

-- 3) Verrouillage des droits (fonction privee : appelee uniquement par le cron / definer)
revoke all on function public.fn_cron_reconcile_task_dispatch(integer)
  from public, anon, authenticated, service_role;

-- 4) Planification cron : toutes les 5 minutes (upsert par nom de job)
select cron.schedule(
  'reconcile-task-dispatch',
  '*/5 * * * *',
  $$ select public.fn_cron_reconcile_task_dispatch(); $$
);
