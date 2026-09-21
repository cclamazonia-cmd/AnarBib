-- =============================================================================
-- Une instance restaurée retrouve ses crons (I26)
-- =============================================================================
-- Date     : 2026-09-21
-- Chantier : auto-hébergement (I2) / backlog v34 I26
-- Ref      : docs/journal/operations/NOTE_pins-images-remesures_2026-09-21.md §7
--
-- POURQUOI. Constaté le 21/09/2026 en restaurant un dump RÉEL de la production :
-- `supabase db dump` n'emporte pas le schéma `cron`. L'instance restaurée est
-- complète, elle répond, on s'y connecte — et elle porte ZÉRO job : ni rappel
-- d'échéance, ni moisson, ni gazette, ni expiration de cotisation, ni sonde de
-- santé. Et comme la sonde est elle-même un cron, c'est la seule instance qui
-- ne peut pas s'en apercevoir. `bootstrap.sh` finissait en vert.
--
-- POURQUOI UNE FONCTION, ET PAS SEULEMENT UNE MIGRATION. Une migration qui
-- replanifierait les jobs ne réglerait rien : sur une instance restaurée,
-- l'historique des migrations (restauré lui aussi depuis le 21/09) la déclare
-- « faite », elle ne se rejoue pas. C'est exactement ce qui arrive déjà aux
-- vingt migrations qui planifient ces jobs. Une FONCTION, elle, voyage dans le
-- dump avec le schéma : `restore.sh` n'a qu'à l'appeler. La migration la crée,
-- puis l'appelle — ce qui, en production, ne fait RIEN (voir plus bas).
--
-- D'OÙ VIENT LA LISTE. De la production, relevée le 21/09/2026 par
--     select jobname, schedule, command from cron.job order by jobname;
-- 38 jobs, tous actifs, tous sous le rôle `postgres`. Empreinte md5 de
-- « nom|horaire|commande » (tri "C", joints par un saut de ligne) :
--     bf25c87f0fed778494de7dd5eacdb307
-- Le bloc de vérification la recalcule : une conversion de fins de ligne ou une
-- retouche d'espace dans ce fichier fait échouer la migration au lieu de
-- planifier une commande légèrement différente de celle qui tourne.
--
-- LA QUESTION DES SECRETS (posée par I26) A SA RÉPONSE : aucune commande ne
-- porte de secret littéral ni d'URL en dur (mesuré en production : 0 sur 38).
-- Une seule lit un secret, `anarbib-health-probe`, et elle le lit AU MOMENT DE
-- L'EXÉCUTION dans `vault.decrypted_secrets`. La liste peut donc vivre au dépôt.
--
-- SANS EFFET LÀ OÙ TOUT EST EN PLACE. `fn_crons_replanifier()` ne touche qu'aux
-- jobs ABSENTS, DIFFÉRENTS (horaire ou commande) ou INACTIFS. En production, où
-- les 38 sont en place à l'identique, elle n'appelle pas une fois
-- `cron.schedule`. Elle ne retire jamais rien : un job inattendu est SIGNALÉ,
-- pas supprimé — retirer un cron est une décision, pas une réparation.
--
-- UNE SEULE LISTE QUI FAIT FOI, DEUX QUI SE SURVEILLENT (DOC-RECENS-1). La suite
-- `tests/sql/crons_planifies_tests.sql` garde sa liste de noms et d'horaires —
-- c'est « le point où le changement devient une décision ». Elle vérifie
-- désormais (T7) que cette liste est celle de la fonction, et (T8) que les
-- commandes de la fonction sont celles que le dépôt rejoué planifie. Qui ajoute
-- un cron par migration sans l'ajouter ici fait rougir la CI.
-- =============================================================================

begin;

create or replace function private.fn_crons_attendus()
returns table (jobname text, schedule text, command text, active boolean)
language sql
immutable
set search_path to 'pg_temp'
as $fn$
  values
    ('anarbib-authority-resolve-due-daily', '45 3 * * *', $c$ SELECT api.fn_authority_resolve_due(); $c$, true),
    ('anarbib-catalog-audit-snapshot-purge', '17 4 * * *', $c$select public.fn_purge_audit_draft_snapshots();$c$, true),
    ('anarbib-circle-resolve-due-daily', '30 3 * * *', $c$ SELECT api.fn_circle_resolve_due(); $c$, true),
    ('anarbib-collective-removal-execute-daily', '15 3 * * *', $c$SELECT public.fn_cron_collective_removal_execute();$c$, true),
    ('anarbib-cooptation-reminders-daily', '25 9 * * *', $c$SELECT public.fn_cron_cooptation_send_reminders();$c$, true),
    ('anarbib-gazette-monthly-start', '0 6 15 * *', $c$select public.fn_gazette_build_call('start')$c$, true),
    ('anarbib-gazette-reconcile-tick', '*/5 * * * *', $c$select public.fn_gazette_build_call('tick')$c$, true),
    ('anarbib-gazette-translate-submissions', '*/10 * * * *', $c$select public.fn_gazette_translate_call()$c$, true),
    ('anarbib-health-probe', '*/5 * * * *', $c$
      select net.http_post(
        url := (private.fn_functions_base_url() || '/functions/v1/health-probe'),
        headers := jsonb_build_object(
          'content-type', 'application/json',
          'x-webhook-secret', (select decrypted_secret from vault.decrypted_secrets
                                where name = 'WEBHOOK_SECRET_HEALTH_PROBE')),
        body := '{}'::jsonb,
        timeout_milliseconds := 30000);
    $c$, true),
    ('anarbib-membership-expiry-daily', '40 6 * * *', $c$SELECT public.fn_cron_notify_membership_expiry();$c$, true),
    ('anarbib-notify-cross-library-digest-weekly', '30 8 * * 1', $c$SELECT public.fn_cron_notify_cross_library_digest();$c$, true),
    ('anarbib-notify-loan-cycle-daily', '15 9 * * *', $c$select public.fn_cron_notify_loan_cycle();$c$, true),
    ('anarbib-notify-network-weekly-report-weekly', '15 8 * * 1', $c$ select public.fn_cron_notify_network_weekly_report(); $c$, true),
    ('anarbib-notify-weekly-report-weekly', '0 8 * * 1', $c$ select * from public.fn_cron_notify_weekly_report_per_library(); $c$, true),
    ('anarbib-oai-harvest-weekly', '20 4 * * 2', $c$SELECT ingest.fn_cron_import_harvest_oai();$c$, true),
    ('anarbib-oai-resolve-expired-votes', '45 3 * * *', $c$SELECT public.fn_oai_resolve_expired_votes();$c$, true),
    ('anarbib-peb-detect-overdue-daily', '40 3 * * *', $c$ SELECT public.fn_cron_peb_detect_overdue(); $c$, true),
    ('anarbib-purge-invitations-expirees', '40 3 * * *', $c$SELECT public.fn_purge_library_request_invitations();$c$, true),
    ('anarbib-recompute-holdings-availability', '43 4 * * *', $c$SELECT public.fn_v2_recompute_holdings_availability();$c$, true),
    ('anarbib-rede-digest-weekly', '0 9 * * 1', $c$SELECT public.fn_rede_digest_call();$c$, true),
    ('anarbib-request-eval-digest', '17 8 * * *', $c$SELECT public.fn_cron_request_eval_digest();$c$, true),
    ('anarbib-reservation-detect-no-show', '15 * * * *', $c$ SELECT public.fn_detect_no_show_reservations(); $c$, true),
    ('anarbib-reservation-expire-negotiation', '25 * * * *', $c$ SELECT public.fn_expire_negotiation_timeout(); $c$, true),
    ('anarbib-reservation-expire-solicitada', '5 * * * *', $c$ SELECT public.fn_expire_solicitada_reservations(); $c$, true),
    ('anarbib-rgpd-notify-weekly', '0 2 * * 0', $c$ SELECT public.fn_notify_users_before_purge(); $c$, true),
    ('anarbib-rgpd-purge-weekly', '0 3 * * 0', $c$ SELECT public.fn_purge_expired_data(p_dry_run := false); $c$, true),
    ('anarbib-tasks-detect-stale-recurrence-daily', '50 3 * * *', $c$ SELECT public.fn_cron_tasks_detect_stale_recurrence(); $c$, true),
    ('anarbib-team-inactive-cleanup', '0 4 * * *', $c$SELECT public.fn_cron_team_inactive_cleanup();$c$, true),
    ('anarbib-team-invitations-expire', '20 3 * * *', $c$SELECT public.fn_team_expire_invitations()$c$, true),
    ('anarbib-team-invitations-remind', '35 9 * * *', $c$SELECT public.fn_team_invitation_remind()$c$, true),
    ('anarbib-team-pending-removal-complete', '0 * * * *', $c$SELECT public.fn_cron_team_pending_removal_complete();$c$, true),
    ('anarbib-work-titles-autofill', '*/10 * * * *', $c$select public.fn_work_titles_autofill_call()$c$, true),
    ('anarbib_execute_profile_proposals', '*/15 * * * *', $c$SELECT public.fn_execute_due_profile_proposals();$c$, true),
    ('anarbib_expire_profile_proposals', '0 3 * * *', $c$SELECT public.fn_expire_overdue_profile_proposals();$c$, true),
    ('gc-fonds-deposits', '30 4 * * *', $c$ SELECT ingest.fn_cron_gc_deposits(); $c$, true),
    ('reconcile-authority-dispatch', '*/5 * * * *', $c$ SELECT public.fn_cron_reconcile_authority_dispatch(); $c$, true),
    ('reconcile-task-dispatch', '*/5 * * * *', $c$ select public.fn_cron_reconcile_task_dispatch(); $c$, true),
    ('refresh-mv-books-catalog-list', '*/15 * * * *', $c$SELECT public.refresh_mv_books_catalog_list_v1();$c$, true)
$fn$;

comment on function private.fn_crons_attendus() is
  'Les crons que cette instance doit porter : nom, horaire, commande, actif. Relevés en production le 21/09/2026 (38 jobs, empreinte bf25c87f…). Lue par private.fn_crons_replanifier() et par tests/sql/crons_planifies_tests.sql (T7, T8). Tout cron ajouté, retiré ou décalé par une migration se reporte ICI dans la même migration.';

create or replace function private.fn_crons_replanifier()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_temp'
as $fn$
declare
  r            record;
  v_planifies  text[] := '{}';
  v_en_place   integer := 0;
  v_inattendus text[];
  v_jobid      bigint;
begin
  if to_regclass('cron.job') is null
     or to_regprocedure('cron.schedule(text,text,text)') is null then
    return jsonb_build_object(
      'ok', false,
      'pourquoi', 'pg_cron absent : créer l''extension avant (bootstrap.sh le fait à son étape 2 bis), puis rappeler cette fonction');
  end if;

  for r in
    select a.jobname, a.schedule, a.command, a.active,
           j.jobid, j.schedule as j_schedule, j.command as j_command, j.active as j_active
      from private.fn_crons_attendus() a
      left join cron.job j on j.jobname::text = a.jobname
     order by a.jobname
  loop
    if r.jobid is not null
       and r.j_schedule = r.schedule
       and r.j_command  = r.command
       and r.j_active is not distinct from r.active then
      v_en_place := v_en_place + 1;
      continue;
    end if;

    -- cron.schedule remplace un job de même nom sans changer son jobid. SECURITY
    -- DEFINER : le job appartient au propriétaire de cette fonction (postgres,
    -- comme en production), quel que soit le rôle qui restaure.
    v_jobid := cron.schedule(r.jobname, r.schedule, r.command);
    -- Replanifier ne réactive pas forcément un job désactivé : on le dit.
    perform cron.alter_job(v_jobid, active := r.active);
    v_planifies := v_planifies || r.jobname;
  end loop;

  select coalesce(array_agg(j.jobname::text order by j.jobname::text), '{}')
    into v_inattendus
    from cron.job j
   where j.jobname is not null
     and not exists (select 1 from private.fn_crons_attendus() a where a.jobname = j.jobname::text);

  return jsonb_build_object(
    'ok', true,
    'attendus', (select count(*) from private.fn_crons_attendus()),
    'deja_en_place', v_en_place,
    'planifies', to_jsonb(v_planifies),
    'inattendus_laisses_en_place', to_jsonb(v_inattendus));
end $fn$;

comment on function private.fn_crons_replanifier() is
  'Remet en place les crons de private.fn_crons_attendus() : ne touche qu''aux jobs absents, différents ou inactifs — sans effet là où tout est en place (la production). Ne retire jamais rien : un job inattendu est signalé dans le bilan. Appelée par deploy/scripts/restore.sh après une restauration, parce que supabase db dump n''emporte pas cron.job (I26, 21/09/2026). Idempotente.';

revoke all on function private.fn_crons_attendus()    from public, anon, authenticated;
revoke all on function private.fn_crons_replanifier() from public, anon, authenticated;

-- Appel + vérification : porte sur ce que CETTE migration fait (DOC-DEPLOY-4).
do $verif$
declare
  v_md5   text;
  v_bilan jsonb;
  v_n     integer;
begin
  select md5(string_agg(jobname || '|' || schedule || '|' || command, E'\n' order by jobname collate "C")), count(*)
    into v_md5, v_n
    from private.fn_crons_attendus();
  if v_n <> 38 or v_md5 <> 'bf25c87f0fed778494de7dd5eacdb307' then
    raise exception 'crons attendus : % jobs, empreinte % — ce fichier a été altéré (fins de ligne ? espaces ?) : attendu 38 et bf25c87f0fed778494de7dd5eacdb307.', v_n, v_md5;
  end if;

  v_bilan := private.fn_crons_replanifier();
  raise notice 'fn_crons_replanifier : %', v_bilan;

  if (v_bilan ->> 'ok')::boolean then
    select count(*) into v_n
      from private.fn_crons_attendus() a
      join cron.job j on j.jobname::text = a.jobname
     where j.schedule = a.schedule and j.command = a.command and j.active is not distinct from a.active;
    if v_n <> 38 then
      raise exception 'crons : % jobs conformes sur 38 après replanification.', v_n;
    end if;
    -- Second appel : plus rien à faire, sinon la fonction n'est pas idempotente.
    if jsonb_array_length(private.fn_crons_replanifier() -> 'planifies') <> 0 then
      raise exception 'crons : un second appel replanifie encore — la fonction n''est pas idempotente.';
    end if;
  end if;

  if has_function_privilege('anon', 'private.fn_crons_replanifier()', 'execute')
     or has_function_privilege('authenticated', 'private.fn_crons_replanifier()', 'execute') then
    raise exception 'crons : fn_crons_replanifier est restée ouverte à anon ou authenticated.';
  end if;
end $verif$;

commit;
