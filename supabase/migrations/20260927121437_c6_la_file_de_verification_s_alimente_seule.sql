-- ============================================================================
-- C6 §7.3 — la file de vérification s'alimente seule, chaque semaine
-- Foyer : spec-conventions-catalographiques §7.3 · REGISTRE §37 `CONV`
--
-- CE QUI EXISTAIT (mesuré en production le 27/09)
--   · les contrôles de la spec sont écrits depuis le 21/08
--     (`private.v_conv_controle_qualite`, neuf règles) — un instrument de
--     console, fermé au navigateur le 02/09 ;
--   · la file de l'Atelier (`catalog_review_queue`) a été semée deux fois, le
--     21/08 et le 03/09, par des migrations ; plus jamais depuis. Quatre
--     semeurs existent (`fn_conv_lot_*_seed`), idempotents par
--     `on conflict (lot, entity_id) do nothing` ; les titres n'en avaient pas
--     (semés une fois depuis un instantané de `conv_backup`).
--   · Écart mesuré entre les contrôles et la file : 13 signalements jamais vus,
--     tous des exercices de formation (`formacao-e1..e4`, notices
--     2740-2742 de `blmf-teste`, fausses exprès) ou des fiches à plusieurs
--     personnes (CONV-O8, que les semeurs laissent de côté exprès) — plus une
--     notice en capitales (T2), règle sans lot.
--
-- CE QUE FAIT CETTE MIGRATION
--   1. `public.fn_conv_lot_titre_casse_seed()` : le semeur manquant (T1 — mot-
--      outil capitalisé pour la langue du titre, proposition
--      `fn_conv_lower_stopwords`), qui écarte le bac à sable de formation ;
--   2. `private.fn_conv_file_alimenter()` : appelle les cinq semeurs, date les
--      notes des lignes nées de ce passage (« Contrôle du JJ/MM » au lieu de
--      « Audit 03/09 »), rend un compte par lot ;
--   3. le cron `anarbib-conv-file-alimenter`, lundi 05 h 10 UTC, et la liste
--      `private.fn_crons_attendus()` (I26 : un cron neuf remplace la liste) ;
--   4. un premier passage, ici même.
--
-- SIGNALER, JAMAIS BLOQUER (spec §7.1) : rien n'est corrigé, tout arrive dans
-- l'Atelier « à revoir ». Un verdict posé (validé, écarté, corrigé) n'est
-- JAMAIS reproposé : l'unicité (lot, entity_id) le garde — une fiche écartée
-- reste écartée même si elle change ensuite, c'est voulu (une personne a
-- tranché). Les lignes sont semées au nom de personne (`decided_by` nul).
--
-- Suite : tests/sql/conv_file_alimentee_tests.sql ; crons_planifies_tests.sql.
-- ============================================================================
begin;

-- ── 1 · Le semeur des titres ───────────────────────────────────────────────
create or replace function public.fn_conv_lot_titre_casse_seed()
returns bigint
language plpgsql
set search_path to 'public', 'pg_catalog'
as $function$
declare v_n bigint;
begin
  with faits as (
    insert into public.catalog_review_queue (lot, entity_kind, entity_id, contexte, avant, apres_propose, decision, note)
    select 'titre_casse', 'book', b.id, b.idioma, b.titulo,
           public.fn_conv_lower_stopwords(b.titulo, b.idioma),
           'a_revoir',
           'Audit 03/09 · mot-outil capitalisé pour la langue du titre (CONV-3). '
             || 'La proposition ne touche que les mots-outils, hors début ; noms propres et sigles restent.'
      from public.books b
     where b.idioma is not null
       and nullif(btrim(coalesce(b.titulo, '')), '') is not null
       and public.fn_conv_lower_stopwords(b.titulo, b.idioma) is distinct from b.titulo
       -- le bac à sable de formation porte des erreurs voulues
       and not exists (select 1 from public.libraries l
                        where l.id = b.owner_library_id and l.slug like '%-teste')
    on conflict (lot, entity_id) do nothing
    returning 1
  )
  select count(*) into v_n from faits;
  return v_n;
end;
$function$;

comment on function public.fn_conv_lot_titre_casse_seed() is
  'C6 §7.3 · sème le lot titre_casse (règle T1). Idempotent. Console et cron seulement.';

revoke all on function public.fn_conv_lot_titre_casse_seed() from public, anon, authenticated;
grant execute on function public.fn_conv_lot_titre_casse_seed() to service_role;

-- ── 2 · L'alimentation ─────────────────────────────────────────────────────
create or replace function private.fn_conv_file_alimenter()
returns jsonb
language plpgsql
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v jsonb;
  v_date text := to_char(now() at time zone 'America/Belem', 'DD/MM');
begin
  v := jsonb_build_object(
    'titre_casse',           public.fn_conv_lot_titre_casse_seed(),
    'autorite_casse',        public.fn_conv_lot_autorite_casse_seed(),
    'autorite_forme',        public.fn_conv_lot_autorite_forme_seed(),
    'autorite_collectivite', public.fn_conv_lot_autorite_collectivite_seed(),
    'autor_sans_autorite',   public.fn_conv_lot_autor_sans_autorite_seed());

  -- Les semeurs écrivent « Audit 03/09 » : vrai pour le premier semis, faux
  -- pour une ligne née aujourd'hui. `now()` est l'heure de la transaction :
  -- ce sont exactement les lignes de ce passage.
  update public.catalog_review_queue q
     set note = 'Contrôle du ' || v_date || ' · '
                || coalesce(nullif(regexp_replace(coalesce(q.note, ''), '^(Audit|Contrôle du) \d\d/\d\d · ', ''), ''),
                            'repéré par le contrôle hebdomadaire des conventions (spec §7.3).')
   where q.created_at = now()
     and q.decision = 'a_revoir';

  return v;
end;
$function$;

comment on function private.fn_conv_file_alimenter() is
  'C6 §7.3 · passage hebdomadaire des cinq semeurs de la file de vérification '
  '(cron anarbib-conv-file-alimenter). Rend {lot: lignes ajoutées}. Ne corrige rien.';

revoke all on function private.fn_conv_file_alimenter() from public, anon, authenticated;

-- ── 3 · Le cron, et la liste des crons attendus (I26) ──────────────────────
select cron.unschedule(jobid) from cron.job where jobname = 'anarbib-conv-file-alimenter';
select cron.schedule('anarbib-conv-file-alimenter', '10 5 * * 1', $c$select private.fn_conv_file_alimenter();$c$);

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
    ('anarbib-conv-file-alimenter', '10 5 * * 1', $c$select private.fn_conv_file_alimenter();$c$, true),
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
    ('anarbib-notify-outbox-retry', '*/15 * * * *', $c$select private.fn_outbox_rejouer();$c$, true),
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

-- ── 4 · Premier passage, et vérification ───────────────────────────────────
do $$
declare v jsonb;
begin
  v := private.fn_conv_file_alimenter();
  raise notice 'C6 §7.3 — premier passage : %', v;

  if (select count(*) from private.fn_crons_attendus()) <> 40 then
    raise exception 'C6 §7.3 : fn_crons_attendus doit porter 40 jobs';
  end if;
  if not exists (select 1 from cron.job where jobname = 'anarbib-conv-file-alimenter'
                  and schedule = '10 5 * * 1' and active) then
    raise exception 'C6 §7.3 : cron absent ou inactif';
  end if;
  if has_function_privilege('authenticated', 'private.fn_conv_file_alimenter()', 'EXECUTE')
     or has_function_privilege('anon', 'private.fn_conv_file_alimenter()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_lot_titre_casse_seed()', 'EXECUTE')
     or has_function_privilege('anon', 'public.fn_conv_lot_titre_casse_seed()', 'EXECUTE') then
    raise exception 'C6 §7.3 : droits inattendus';
  end if;
  -- le bac à sable de formation n'entre pas dans la file des titres
  if exists (select 1 from public.catalog_review_queue q
               join public.books b on b.id = q.entity_id
               join public.libraries l on l.id = b.owner_library_id
              where q.lot = 'titre_casse' and q.created_at = now() and l.slug like '%-teste') then
    raise exception 'C6 §7.3 : une notice du bac à sable a été semée';
  end if;
end $$;

commit;
