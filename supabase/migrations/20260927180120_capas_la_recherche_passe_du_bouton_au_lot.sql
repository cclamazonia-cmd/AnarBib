-- ============================================================================
-- CAPAS · la recherche de couvertures passe du bouton au lot
-- Foyer : spec-module-capas · chantier capas du 27/09/2026 (troisième point
-- de l'analyse : « passer du bouton au lot »)
--
-- CE QUI EXISTAIT (mesuré en production le 27/09)
--   · 2 384 notices « livro » sans capa (BTL 2 096, MLEG 251, BLMF 47, bac à
--     sable 5), dont 266 portent un ISBN ;
--   · une seule façon d'en chercher une : ouvrir la notice, « Chercher une
--     capa », choisir, enregistrer, publier — notice par notice ;
--   · rendement mesuré le même jour : ISBN exact 85 sur 267 ; sans ISBN,
--     « même éditeur, même année » ~11 %, « à vérifier » ~17 %.
--
-- CE QUE FAIT CETTE MIGRATION
--   1. `public.cover_proposals` : une ligne par notice cherchée — les
--      candidates trouvées (adresses, source, édition, voie, niveau), le bilan
--      des sources, le statut, la décision d'une personne ;
--   2. deux RPC pour l'Edge Function `cover-batch` (service_role seulement) :
--      `fn_capas_lot_a_chercher(n)`, `fn_capas_lot_enregistrer(...)` ;
--   3. le cron `anarbib-capas-lot`, toutes les 10 minutes, qui range d'abord
--      les propositions devenues sans objet puis n'appelle la fonction que s'il
--      reste à chercher ; la liste `private.fn_crons_attendus()` (I26) ;
--   4. l'écran de revue (api, staff) : résumé, liste, accepter, écarter,
--      rouvrir.
--
-- RIEN N'EST POSÉ SANS UNE PERSONNE. Le lot propose ; la capa n'entre dans
-- `books` que par `api.capas_revue_accepter`, geste d'un membre du staff d'une
-- bibliothèque qui possède ou détient la notice (ou de l'administration du
-- réseau) — le périmètre où `create_book_draft_from_book` laisse déjà reprendre
-- une notice. Une proposition écartée n'est jamais reproposée par le lot.
--
-- ÉGARDS POUR LES SOURCES. 24 notices au plus par passage, deux à la fois,
-- toutes les 10 minutes : le stock est parcouru en une vingtaine d'heures. Une
-- recherche sans résultat se refait après 90 jours (les sources grandissent),
-- une recherche en panne le lendemain — jamais tout de suite : une notice qui
-- ferait tomber une source ne doit pas boucler en tête de file.
--
-- Suites : tests/sql/capas_lot_tests.sql ; crons_planifies_tests.sql.
-- ============================================================================
begin;

-- ── 1 · Les propositions ───────────────────────────────────────────────────
create table if not exists public.cover_proposals (
  book_id     bigint      primary key references public.books(id) on delete cascade,
  statut      text        not null default 'a_revoir',
  candidates  jsonb       not null default '[]'::jsonb,
  sources     jsonb       not null default '[]'::jsonb,
  cherche_le  timestamptz not null default now(),
  recherches  integer     not null default 1,
  retenue     jsonb,
  decided_by  uuid        references auth.users(id) on delete set null,
  decided_at  timestamptz,
  created_at  timestamptz not null default now(),
  constraint cover_proposals_statut_chk
    check (statut in ('a_revoir', 'sans_resultat', 'en_panne', 'acceptee', 'ecartee', 'perimee')),
  constraint cover_proposals_candidates_chk
    check (jsonb_typeof(candidates) = 'array' and jsonb_typeof(sources) = 'array'),
  -- une proposition à revoir montre au moins une candidate
  constraint cover_proposals_a_revoir_chk
    check (statut <> 'a_revoir' or jsonb_array_length(candidates) > 0),
  -- « acceptée » dit laquelle, et elle seule le dit
  constraint cover_proposals_retenue_chk
    check ((statut = 'acceptee') = (retenue is not null))
);

create index if not exists cover_proposals_decided_by_idx on public.cover_proposals (decided_by);

comment on table public.cover_proposals is
  'Capas en lot (27/09/2026) · une ligne par notice cherchée par cover-batch : les candidates '
  '(adresses seulement — les aperçus se rapatrient à l''affichage), le bilan des sources, le '
  'statut, la décision. Écriture : fn_capas_lot_enregistrer (le lot) et api.capas_revue_* '
  '(l''écran de revue) ; aucune lecture directe.';
comment on column public.cover_proposals.statut is
  'a_revoir (au moins une candidate, une personne décide) | sans_resultat (sources muettes, '
  'recherché de nouveau après 90 jours) | en_panne (une source a échoué et rien trouvé, le '
  'lendemain) | acceptee | ecartee (jamais reproposée) | perimee (la notice a reçu une capa '
  'par un autre chemin).';
comment on column public.cover_proposals.retenue is
  'La candidate acceptée, telle que proposée : provenance de la capa posée dans books.';

alter table public.cover_proposals enable row level security;
revoke all on public.cover_proposals from public, anon, authenticated;
grant all on public.cover_proposals to service_role;

-- ── 2 · Le lot : quoi chercher, où ranger ──────────────────────────────────
create or replace function public.fn_capas_lot_a_chercher(p_limit integer default 24)
returns table (book_id bigint, isbn text, titulo text, autor text, idioma text)
language sql
stable
set search_path to 'public', 'pg_catalog'
as $function$
  select b.id, nullif(btrim(coalesce(b.isbn, '')), ''), b.titulo, b.autor, b.idioma
    from public.books b
    left join public.cover_proposals p on p.book_id = b.id
   where b.tipo_material = 'livro'
     and nullif(btrim(coalesce(b.cover_object_path, '')), '') is null
     and nullif(btrim(coalesce(b.titulo, '')), '') is not null
     -- le bac à sable de formation porte des notices fausses exprès
     and not exists (select 1 from public.libraries l
                      where l.id = b.owner_library_id and l.slug like '%-teste')
     and (p.book_id is null
          or (p.statut = 'sans_resultat' and p.cherche_le < now() - interval '90 days')
          or (p.statut in ('en_panne', 'perimee') and p.cherche_le < now() - interval '1 day'))
   order by (p.book_id is not null),
            (nullif(regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g'), '') is null),
            b.id
   limit greatest(1, least(coalesce(p_limit, 24), 100));
$function$;

comment on function public.fn_capas_lot_a_chercher(integer) is
  'Capas en lot · les notices à chercher : jamais cherchées d''abord (à ISBN en tête), puis '
  'les recherches à refaire. Edge Function cover-batch et cron seulement.';

create or replace function public.fn_capas_lot_enregistrer(p_book_id bigint, p_candidates jsonb, p_sources jsonb)
returns text
language plpgsql
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_candidates jsonb;
  v_sources    jsonb := case when jsonb_typeof(p_sources) = 'array' then p_sources else '[]'::jsonb end;
  v_statut     text;
  v_ecrit      text;
begin
  if not exists (select 1 from public.books where id = p_book_id) then
    return 'absente';
  end if;

  -- On ne garde que ce que l'écran sait montrer, sans les aperçus : une data:
  -- URI n'a rien à faire en base, et une adresse non https ne s'affichera pas.
  select coalesce(jsonb_agg(c - 'thumbnailData' order by o), '[]'::jsonb) into v_candidates
    from jsonb_array_elements(case when jsonb_typeof(p_candidates) = 'array'
                                   then p_candidates else '[]'::jsonb end) with ordinality as t(c, o)
   where jsonb_typeof(c) = 'object'
     and coalesce(c->>'fullUrl', '') ~ '^https://'
     and coalesce(c->>'thumbnailUrl', '') ~ '^https://';

  v_statut := case
    when jsonb_array_length(v_candidates) > 0 then 'a_revoir'
    -- rien trouvé, mais une source n'a pas répondu : elle avait peut-être la capa
    when exists (select 1 from jsonb_array_elements(v_sources) s
                  where jsonb_typeof(s) = 'object'
                    and coalesce(s->>'skipped', 'false') <> 'true'
                    and s->>'ok' = 'false') then 'en_panne'
    else 'sans_resultat'
  end;

  insert into public.cover_proposals as p (book_id, statut, candidates, sources, cherche_le, recherches)
  values (p_book_id, v_statut, v_candidates, v_sources, now(), 1)
  on conflict on constraint cover_proposals_pkey do update
     set statut = excluded.statut, candidates = excluded.candidates, sources = excluded.sources,
         cherche_le = now(), recherches = p.recherches + 1
   -- une proposition en attente ou tranchée par une personne n'est pas écrasée
   where p.statut in ('sans_resultat', 'en_panne', 'perimee')
  returning p.statut into v_ecrit;

  return coalesce(v_ecrit, 'inchange');
end;
$function$;

comment on function public.fn_capas_lot_enregistrer(bigint, jsonb, jsonb) is
  'Capas en lot · range le résultat d''une recherche : a_revoir, sans_resultat ou en_panne. '
  'N''écrase jamais une proposition en attente ni une décision. Edge Function cover-batch seulement.';

revoke all on function public.fn_capas_lot_a_chercher(integer) from public, anon, authenticated;
revoke all on function public.fn_capas_lot_enregistrer(bigint, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.fn_capas_lot_a_chercher(integer) to service_role;
grant execute on function public.fn_capas_lot_enregistrer(bigint, jsonb, jsonb) to service_role;

-- ── 3 · Le cron ────────────────────────────────────────────────────────────
-- Même domaine de confiance que la gazette et les titres d'œuvre : le secret
-- partagé des crons (vault `gazette_cron_secret`, EF `GAZETTE_CRON_SECRET`).
create or replace function public.fn_capas_lot_call()
returns void
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_catalog'
as $function$
declare
  v_secret text;
begin
  -- Une proposition dont la notice a reçu une capa par un autre chemin (le
  -- formulaire) n'attend plus personne.
  update public.cover_proposals p
     set statut = 'perimee'
    from public.books b
   where b.id = p.book_id
     and p.statut = 'a_revoir'
     and nullif(btrim(coalesce(b.cover_object_path, '')), '') is not null;

  if not exists (select 1 from public.fn_capas_lot_a_chercher(1)) then
    return;
  end if;

  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'gazette_cron_secret';
  perform net.http_post(
    url                  := private.fn_functions_base_url() || '/functions/v1/cover-batch',
    headers              := jsonb_build_object('Content-Type', 'application/json',
                                               'X-Cron-Secret', coalesce(v_secret, '')),
    body                 := '{}'::jsonb,
    -- un passage dure jusqu'à ~2 minutes : ne pas le déclarer mort avant
    timeout_milliseconds := 150000);
end;
$function$;

comment on function public.fn_capas_lot_call() is
  'Capas en lot · cron anarbib-capas-lot : range les propositions sans objet, puis appelle '
  'l''Edge Function cover-batch s''il reste des notices à chercher.';

revoke all on function public.fn_capas_lot_call() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname = 'anarbib-capas-lot';
select cron.schedule('anarbib-capas-lot', '7-59/10 * * * *', $c$select public.fn_capas_lot_call()$c$);

create or replace function private.fn_crons_attendus()
returns table (jobname text, schedule text, command text, active boolean)
language sql
immutable
set search_path to 'pg_temp'
as $fn$
  values
    ('anarbib-authority-resolve-due-daily', '45 3 * * *', $c$ SELECT api.fn_authority_resolve_due(); $c$, true),
    ('anarbib-capas-lot', '7-59/10 * * * *', $c$select public.fn_capas_lot_call()$c$, true),
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

-- ── 4 · L'écran de revue ───────────────────────────────────────────────────
-- Le périmètre d'une personne : les notices que possède ou détient l'une de
-- ses bibliothèques (staff : librarian, coordenador), toutes pour
-- l'administration du réseau. Calculé une fois par appel par l'appelant, puis
-- passé ici : fn_caller_staff_library_ids() par ligne coûterait un appel par
-- notice.
create or replace function public.fn_capas_dans_le_perimetre(p_book_id bigint, p_owner uuid, p_ids uuid[], p_admin boolean)
returns boolean
language sql
stable
set search_path to 'public', 'pg_catalog'
as $function$
  select coalesce(p_admin, false)
      or p_owner = any (coalesce(p_ids, '{}'::uuid[]))
      or exists (select 1 from public.book_holdings h
                  where h.book_id = p_book_id and h.library_id = any (coalesce(p_ids, '{}'::uuid[])));
$function$;

revoke all on function public.fn_capas_dans_le_perimetre(bigint, uuid, uuid[], boolean) from public, anon, authenticated;

create or replace function api.capas_revue_resume()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_admin boolean := public.fn_caller_is_network_admin();
  v_ids   uuid[]  := public.fn_caller_staff_library_ids();
  v       jsonb;
begin
  if not v_admin and cardinality(v_ids) = 0 then
    raise exception 'Acesso restrito ao staff de catalogacao.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;

  select jsonb_build_object(
           'a_revoir',      count(*) filter (where p.statut = 'a_revoir' and x.sans_capa),
           'a_chercher',    count(*) filter (where p.book_id is null and x.sans_capa and x.cherchable),
           'sans_resultat', count(*) filter (where p.statut = 'sans_resultat' and x.sans_capa),
           'en_panne',      count(*) filter (where p.statut = 'en_panne' and x.sans_capa),
           'acceptee',      count(*) filter (where p.statut = 'acceptee'),
           'ecartee',       count(*) filter (where p.statut = 'ecartee'))
    into v
    from (select b.id,
                 nullif(btrim(coalesce(b.cover_object_path, '')), '') is null as sans_capa,
                 nullif(btrim(coalesce(b.titulo, '')), '') is not null
                   and not exists (select 1 from public.libraries l
                                    where l.id = b.owner_library_id and l.slug like '%-teste') as cherchable
            from public.books b
           where b.tipo_material = 'livro'
             and public.fn_capas_dans_le_perimetre(b.id, b.owner_library_id, v_ids, v_admin)) x
    left join public.cover_proposals p on p.book_id = x.id;

  return v;
end;
$function$;

create or replace function api.capas_revue_liste(p_limite integer default 10, p_decalage integer default 0)
returns table (book_id bigint, bib_ref text, titulo text, subtitulo text, autor text, editora text,
               ano text, volume text, isbn text, idioma text, candidates jsonb, cherche_le timestamptz)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
#variable_conflict use_column
declare
  v_admin boolean := public.fn_caller_is_network_admin();
  v_ids   uuid[]  := public.fn_caller_staff_library_ids();
begin
  if not v_admin and cardinality(v_ids) = 0 then
    raise exception 'Acesso restrito ao staff de catalogacao.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;

  return query
    select b.id, b.bib_ref, b.titulo, b.subtitulo, b.autor, b.editora, b.ano, b.volume, b.isbn, b.idioma,
           p.candidates, p.cherche_le
      from public.cover_proposals p
      join public.books b on b.id = p.book_id
     where p.statut = 'a_revoir'
       and nullif(btrim(coalesce(b.cover_object_path, '')), '') is null
       and public.fn_capas_dans_le_perimetre(b.id, b.owner_library_id, v_ids, v_admin)
     -- l'ISBN d'abord, puis l'édition trouvée par le titre, la couverture d'œuvre en dernier
     order by (p.candidates->0->>'voie' is distinct from 'isbn'),
              (p.candidates->0->>'niveau' is not distinct from 'oeuvre'),
              p.book_id
     limit least(greatest(coalesce(p_limite, 10), 1), 50)
    offset greatest(coalesce(p_decalage, 0), 0);
end;
$function$;

create or replace function api.capas_revue_accepter(p_book_id bigint, p_full_url text, p_object_path text)
returns text
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_admin boolean := public.fn_caller_is_network_admin();
  v_ids   uuid[]  := public.fn_caller_staff_library_ids();
  v_book  public.books%rowtype;
  v_prop  public.cover_proposals%rowtype;
  v_cand  jsonb;
begin
  if not v_admin and cardinality(v_ids) = 0 then
    raise exception 'Acesso restrito ao staff de catalogacao.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;

  select * into v_book from public.books where id = p_book_id for update;
  if not found or not public.fn_capas_dans_le_perimetre(v_book.id, v_book.owner_library_id, v_ids, v_admin) then
    raise exception 'capa_hors_perimetre' using errcode = '42501', hint = 'error.capas.hors_perimetre';
  end if;

  select * into v_prop from public.cover_proposals where book_id = p_book_id for update;
  if not found or v_prop.statut <> 'a_revoir' then
    raise exception 'capa_proposition_close' using hint = 'error.capas.proposition_close';
  end if;

  -- La provenance et la licence viennent de la PROPOSITION, pas du navigateur.
  select c into v_cand
    from jsonb_array_elements(v_prop.candidates) c
   where c->>'fullUrl' = p_full_url
   limit 1;
  if v_cand is null then
    raise exception 'capa_candidate_inconnue' using hint = 'error.capas.candidate_inconnue';
  end if;

  -- Le fichier est rangé dans le dossier de CETTE notice (clé = bib_ref, comme
  -- cover_lookup la nettoie), sous un nom que l'Edge Function donne.
  if coalesce(p_object_path, '') !~ '^books/[A-Za-z0-9_-]{1,120}/(front|capa-[a-z0-9]{1,20})\.(jpg|png|webp|gif)$'
     or split_part(p_object_path, '/', 2) <> left(regexp_replace(coalesce(v_book.bib_ref, ''), '[^A-Za-z0-9_-]', '_', 'g'), 120) then
    raise exception 'capa_chemin_invalide' using hint = 'error.capas.chemin_invalide';
  end if;

  -- Une capa posée entre-temps par un autre chemin n'est jamais remplacée ici.
  if nullif(btrim(coalesce(v_book.cover_object_path, '')), '') is not null then
    update public.cover_proposals set statut = 'perimee' where book_id = p_book_id;
    return 'perimee';
  end if;

  update public.books
     set cover_object_path = p_object_path,
         cover_source      = nullif(v_cand->>'source', ''),
         cover_license     = nullif(v_cand->>'license', ''),
         updated_at        = now(),
         updated_by        = auth.uid()
   where id = p_book_id;

  update public.cover_proposals
     set statut = 'acceptee', retenue = v_cand, decided_by = auth.uid(), decided_at = now()
   where book_id = p_book_id;

  return 'acceptee';
end;
$function$;

create or replace function api.capas_revue_ecarter(p_book_id bigint)
returns text
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_admin boolean := public.fn_caller_is_network_admin();
  v_ids   uuid[]  := public.fn_caller_staff_library_ids();
  v_owner uuid;
begin
  if not v_admin and cardinality(v_ids) = 0 then
    raise exception 'Acesso restrito ao staff de catalogacao.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;
  select owner_library_id into v_owner from public.books where id = p_book_id;
  if not found or not public.fn_capas_dans_le_perimetre(p_book_id, v_owner, v_ids, v_admin) then
    raise exception 'capa_hors_perimetre' using errcode = '42501', hint = 'error.capas.hors_perimetre';
  end if;

  update public.cover_proposals
     set statut = 'ecartee', decided_by = auth.uid(), decided_at = now()
   where book_id = p_book_id and statut = 'a_revoir';
  if not found then
    raise exception 'capa_proposition_close' using hint = 'error.capas.proposition_close';
  end if;
  return 'ecartee';
end;
$function$;

-- Le repentir d'un clic : « Aucune ne convient » se défait depuis l'écran.
-- Une capa ACCEPTÉE, elle, se change par le formulaire de la notice.
create or replace function api.capas_revue_rouvrir(p_book_id bigint)
returns text
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_admin boolean := public.fn_caller_is_network_admin();
  v_ids   uuid[]  := public.fn_caller_staff_library_ids();
  v_owner uuid;
begin
  if not v_admin and cardinality(v_ids) = 0 then
    raise exception 'Acesso restrito ao staff de catalogacao.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;
  select owner_library_id into v_owner from public.books where id = p_book_id;
  if not found or not public.fn_capas_dans_le_perimetre(p_book_id, v_owner, v_ids, v_admin) then
    raise exception 'capa_hors_perimetre' using errcode = '42501', hint = 'error.capas.hors_perimetre';
  end if;

  update public.cover_proposals
     set statut = 'a_revoir', decided_by = null, decided_at = null
   where book_id = p_book_id and statut = 'ecartee';
  if not found then
    raise exception 'capa_proposition_close' using hint = 'error.capas.proposition_close';
  end if;
  return 'a_revoir';
end;
$function$;

comment on function api.capas_revue_resume() is
  'Capas en lot · compteurs de l''écran de revue, dans le périmètre de l''appelant·e (staff).';
comment on function api.capas_revue_liste(integer, integer) is
  'Capas en lot · propositions à revoir du périmètre de l''appelant·e, ISBN d''abord.';
comment on function api.capas_revue_accepter(bigint, text, text) is
  'Capas en lot · pose la capa choisie (déjà rangée dans le bucket covers par cover_lookup) ; '
  'provenance et licence lues dans la proposition. Rend acceptee, ou perimee si une capa a été '
  'posée entre-temps (rien n''est alors remplacé).';
comment on function api.capas_revue_ecarter(bigint) is
  'Capas en lot · « aucune ne convient » : la proposition n''est plus jamais reproposée par le lot.';
comment on function api.capas_revue_rouvrir(bigint) is
  'Capas en lot · défait un écartement.';

revoke all on function api.capas_revue_resume() from public, anon;
revoke all on function api.capas_revue_liste(integer, integer) from public, anon;
revoke all on function api.capas_revue_accepter(bigint, text, text) from public, anon;
revoke all on function api.capas_revue_ecarter(bigint) from public, anon;
revoke all on function api.capas_revue_rouvrir(bigint) from public, anon;
grant execute on function api.capas_revue_resume() to authenticated;
grant execute on function api.capas_revue_liste(integer, integer) to authenticated;
grant execute on function api.capas_revue_accepter(bigint, text, text) to authenticated;
grant execute on function api.capas_revue_ecarter(bigint) to authenticated;
grant execute on function api.capas_revue_rouvrir(bigint) to authenticated;

-- ── 5 · Vérification ───────────────────────────────────────────────────────
do $$
declare
  v_f text;
begin
  if (select count(*) from private.fn_crons_attendus()) <> 41 then
    raise exception 'capas en lot : fn_crons_attendus doit porter 41 jobs';
  end if;
  if not exists (select 1 from cron.job where jobname = 'anarbib-capas-lot'
                  and schedule = '7-59/10 * * * *' and active) then
    raise exception 'capas en lot : cron absent ou inactif';
  end if;

  -- rien du lot ni du cron n'est ouvert au lectorat
  foreach v_f in array array[
    'public.fn_capas_lot_a_chercher(integer)',
    'public.fn_capas_lot_enregistrer(bigint, jsonb, jsonb)',
    'public.fn_capas_lot_call()',
    'public.fn_capas_dans_le_perimetre(bigint, uuid, uuid[], boolean)'] loop
    if has_function_privilege('anon', v_f, 'EXECUTE') or has_function_privilege('authenticated', v_f, 'EXECUTE') then
      raise exception 'capas en lot : % ouverte au lectorat', v_f;
    end if;
  end loop;
  -- l'écran de revue : authenticated (le corps garde le staff), jamais anon
  foreach v_f in array array[
    'api.capas_revue_resume()',
    'api.capas_revue_liste(integer, integer)',
    'api.capas_revue_accepter(bigint, text, text)',
    'api.capas_revue_ecarter(bigint)',
    'api.capas_revue_rouvrir(bigint)'] loop
    if has_function_privilege('anon', v_f, 'EXECUTE') or not has_function_privilege('authenticated', v_f, 'EXECUTE') then
      raise exception 'capas en lot : droits inattendus sur %', v_f;
    end if;
  end loop;
  if has_table_privilege('authenticated', 'public.cover_proposals', 'SELECT')
     or has_table_privilege('anon', 'public.cover_proposals', 'SELECT')
     or has_table_privilege('authenticated', 'public.cover_proposals', 'INSERT') then
    raise exception 'capas en lot : la table des propositions est lisible ou écrivable en direct';
  end if;
end $$;

commit;
