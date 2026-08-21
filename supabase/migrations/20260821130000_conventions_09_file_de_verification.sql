-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 09 · La file de vérification gradue
-- Foyer : REGISTRE §37 `CONV` · outillage de l'Atelier autorités
--
-- ---------------------------------------------------------------------
-- POURQUOI. Le registre dit depuis le 20/08 que les trois tables de revue
-- sont « le plan de travail de l'Atelier autorités ». C'était une
-- doctrine sans porte : rien dans l'application ne lit `conv_backup`, et
-- le seul acces possible etait le SQL Editor.
--
-- Pire, et c'est ce qui rend la graduation necessaire plutot que
-- confortable : `conv_backup` est HORS du perimetre de la sauvegarde #BG2
-- (`anarbib-bg2.sh` fait `pg_dump --schema=public`). Des verdicts poses
-- la-dedans ne sont dans aucune sauvegarde. Un schema de snapshot est le
-- bon endroit pour figer un etat d'AVANT ; c'est le mauvais endroit pour
-- accumuler des decisions humaines.
--
-- Les trois tables `conv_backup.*` redeviennent donc ce qu'elles sont —
-- des instantanes, intouches. La file de travail vit desormais dans
-- `public`, sauvegardee, sous RLS.
--
-- ACCES. RLS avec politique de lecture staff EXPLICITE plutot qu'un
-- deny-all silencieux (la matrice du 23/06 existe justement pour eviter
-- d'ajouter des tables « RLS activee, 0 policy » que personne ne sait
-- plus qualifier). Aucune ecriture directe : les verdicts passent par une
-- RPC `api.*` SECURITY DEFINER gatee `fn_caller_is_staff()` (DOC-OBJ-2).
-- =====================================================================

begin;

create table if not exists public.catalog_review_queue (
  id              bigserial primary key,
  lot             text        not null,
  entity_kind     text        not null,
  entity_id       bigint      not null,
  contexte        text,
  avant           text        not null,
  apres_propose   text,
  decision        text        not null default 'a_revoir',
  valeur_retenue  text,
  note            text,
  decided_by      uuid        references auth.users(id) on delete set null,
  decided_at      timestamptz,
  applique_le     timestamptz,
  created_at      timestamptz not null default now(),
  constraint catalog_review_queue_lot_chk
    check (lot in ('titre_casse', 'autorite_casse', 'autorite_patronyme')),
  constraint catalog_review_queue_kind_chk
    check (entity_kind in ('book', 'author')),
  constraint catalog_review_queue_decision_chk
    check (decision in ('a_revoir', 'valide', 'ecarte', 'corrige')),
  -- « corrige » veut dire « la proposition etait fausse, voici la bonne » :
  -- sans valeur retenue, la decision ne dit rien d'applicable.
  constraint catalog_review_queue_corrige_chk
    check (decision <> 'corrige' or nullif(btrim(coalesce(valeur_retenue, '')), '') is not null),
  constraint catalog_review_queue_unique unique (lot, entity_id)
);

comment on table public.catalog_review_queue is
  'CONV §37 · file de verification des conventions catalographiques. Plan de '
  'travail de l''Atelier autorites. Graduee hors de conv_backup le 21/08 : les '
  'verdicts humains doivent etre SAUVEGARDES (conv_backup est hors #BG2). '
  'Lecture staff via RLS, ecriture uniquement via api.conv_revue_decide.';

comment on column public.catalog_review_queue.decision is
  'a_revoir | valide (appliquer la proposition) | ecarte (proposition fausse, '
  'ne rien faire) | corrige (proposition fausse, appliquer valeur_retenue).';
comment on column public.catalog_review_queue.applique_le is
  'Horodatage de l''ecriture effective dans public.books / public.authors. '
  'Distinct de decided_at : decider et appliquer sont deux gestes.';

create index if not exists catalog_review_queue_lot_idx
  on public.catalog_review_queue (lot, decision, id);

-- Toute table creee dans `public` herite des droits accordes en masse au role
-- `anon` (advisors 0028/0029, cf. les migrations `durcissement_grants_*`) :
-- 7 privileges, silencieusement. On revoque AVANT d'accorder, sinon la file de
-- verification serait lisible sans compte. Le bloc DO de fin le verifie.
revoke all on public.catalog_review_queue from public, anon;

-- Scenario B du gabarit : table metier privee, lecture filtree par RLS.
grant select on public.catalog_review_queue to authenticated;
grant all    on public.catalog_review_queue to service_role;
grant usage, select on sequence public.catalog_review_queue_id_seq to service_role;

alter table public.catalog_review_queue enable row level security;

drop policy if exists catalog_review_queue_select_staff on public.catalog_review_queue;
create policy catalog_review_queue_select_staff
  on public.catalog_review_queue
  for select
  to authenticated
  using (public.fn_caller_is_staff());

-- ---------------------------------------------------------------------
-- Alimentation depuis les trois instantanes. Idempotente.
-- ---------------------------------------------------------------------
insert into public.catalog_review_queue (lot, entity_kind, entity_id, contexte, avant, apres_propose, note)
select 'titre_casse', 'book', t.id, t.idioma, t.avant, t.apres, null
  from conv_backup.titres_a_revoir_20260820 t
on conflict (lot, entity_id) do nothing;

insert into public.catalog_review_queue (lot, entity_kind, entity_id, contexte, avant, apres_propose, note)
select 'autorite_casse', 'author', c.id, null, c.avant, c.apres_propose,
       -- Les pieges connus sont dits ici, pour que la personne qui tranche
       -- n'ait pas a les redecouvrir une par une.
       case
         when c.avant ~ '''' then 'initcap() casse les apostrophes : O''Brien, Dell''Umbria, Sant''Ana'
         when c.avant ~ '\yY\y' then 'composé en « y » : la copule reste minuscule (Ferrer y Guardia)'
         when c.avant ~ '\y(Van|Von|De|Della|Di|Du|Des|Le|La|Mc|Mac)\y' then 'particule : la règle dépend de la langue du nom (CONV-6)'
         else 'patronyme en plusieurs mots — vérifier le découpage'
       end
  from conv_backup.autorites_casse_a_revoir_20260820 c
 where c.applique_le is null
on conflict (lot, entity_id) do nothing;

insert into public.catalog_review_queue (lot, entity_kind, entity_id, contexte, avant, apres_propose, note)
select 'autorite_patronyme', 'author', p.id, p.country, p.avant, p.apres_propose,
       -- Le verdict de l'audit est porte comme un AVIS, pas comme une decision :
       -- 3 faux positifs sur 22 dans l'echantillon audite (14 %).
       'avis de l''audit du 20/08 : ' || p.verdict
         || coalesce(' — ' || p.note, '')
  from conv_backup.autorites_patronyme_a_revoir_20260820 p
on conflict (lot, entity_id) do nothing;

-- ---------------------------------------------------------------------
-- Lecture — resume par lot
-- ---------------------------------------------------------------------
create or replace function api.conv_revue_resume()
returns table (lot text, a_revoir bigint, valide bigint, ecarte bigint, corrige bigint, applique bigint)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
begin
  if not public.fn_caller_is_staff() then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;

  return query
    select q.lot,
           count(*) filter (where q.decision = 'a_revoir'),
           count(*) filter (where q.decision = 'valide'),
           count(*) filter (where q.decision = 'ecarte'),
           count(*) filter (where q.decision = 'corrige'),
           count(*) filter (where q.applique_le is not null)
      from public.catalog_review_queue q
     group by q.lot
     order by q.lot;
end;
$function$;

comment on function api.conv_revue_resume() is
  'CONV §37 · compteurs de la file de verification, par lot. Staff uniquement.';

-- ---------------------------------------------------------------------
-- Lecture — une page de file
-- ---------------------------------------------------------------------
create or replace function api.conv_revue_list(
  p_lot      text,
  p_decision text default 'a_revoir',
  p_max      int  default 50,
  p_offset   int  default 0
)
returns table (id bigint, entity_kind text, entity_id bigint, contexte text,
               avant text, apres_propose text, decision text,
               valeur_retenue text, note text, applique_le timestamptz)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
begin
  if not public.fn_caller_is_staff() then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;

  return query
    select q.id, q.entity_kind, q.entity_id, q.contexte, q.avant, q.apres_propose,
           q.decision, q.valeur_retenue, q.note, q.applique_le
      from public.catalog_review_queue q
     where q.lot = p_lot
       and (p_decision is null or q.decision = p_decision)
     order by q.avant, q.id
     limit greatest(1, least(coalesce(p_max, 50), 200))
    offset greatest(0, coalesce(p_offset, 0));
end;
$function$;

comment on function api.conv_revue_list(text, text, int, int) is
  'CONV §37 · une page de la file de verification. Staff uniquement. '
  'Plafonnee a 200 lignes : on relit, on ne moissonne pas.';

-- ---------------------------------------------------------------------
-- Ecriture — poser un verdict
-- ---------------------------------------------------------------------
create or replace function api.conv_revue_decide(
  p_id       bigint,
  p_decision text,
  p_valeur   text default null,
  p_note     text default null
)
returns public.catalog_review_queue
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_row public.catalog_review_queue;
begin
  if not public.fn_caller_is_staff() then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;

  if p_decision not in ('a_revoir', 'valide', 'ecarte', 'corrige') then
    raise exception 'Decisão inválida: %', p_decision using errcode = '22023';
  end if;

  -- « corrige » sans valeur n'est pas une decision, c'est une hesitation.
  if p_decision = 'corrige' and nullif(btrim(coalesce(p_valeur, '')), '') is null then
    raise exception 'Uma correção exige o valor retido.'
      using errcode = '22023', hint = 'error.conv.review.valueRequired';
  end if;

  -- Une ligne DEJA APPLIQUEE ne se re-decide pas : la donnee est ecrite,
  -- revenir dessus demande une migration, pas un clic.
  update public.catalog_review_queue q
     set decision       = p_decision,
         valeur_retenue = case when p_decision = 'corrige' then btrim(p_valeur) else null end,
         note           = coalesce(nullif(btrim(coalesce(p_note, '')), ''), q.note),
         decided_by     = auth.uid(),
         decided_at     = now()
   where q.id = p_id
     and q.applique_le is null
  returning * into v_row;

  if v_row.id is null then
    raise exception 'Linha inexistente ou já aplicada.'
      using errcode = 'P0002', hint = 'error.conv.review.notPending';
  end if;

  return v_row;
end;
$function$;

comment on function api.conv_revue_decide(bigint, text, text, text) is
  'CONV §37 · pose un verdict humain sur une ligne de la file. Staff uniquement. '
  'Refuse de re-decider une ligne deja appliquee : revenir sur une donnee ecrite '
  'demande une migration, pas un clic.';

revoke all on function api.conv_revue_resume()                       from public, anon;
revoke all on function api.conv_revue_list(text, text, int, int)     from public, anon;
revoke all on function api.conv_revue_decide(bigint, text, text, text) from public, anon;
grant execute on function api.conv_revue_resume()                       to authenticated;
grant execute on function api.conv_revue_list(text, text, int, int)     to authenticated;
grant execute on function api.conv_revue_decide(bigint, text, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- Vérification
-- ---------------------------------------------------------------------
do $$
declare
  n_file    bigint;
  n_fuite   bigint;
  n_policy  bigint;
begin
  select count(*) into n_file from public.catalog_review_queue;

  -- Invariants STRUCTURELS : ils bloquent.
  select count(*) into n_fuite
    from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'catalog_review_queue'
     and grantee = 'anon';
  if n_fuite > 0 then
    raise exception 'CONV/09 — la file est lisible par anon (% grant) : abandon.', n_fuite;
  end if;

  select count(*) into n_policy from pg_policies
   where schemaname = 'public' and tablename = 'catalog_review_queue';
  if n_policy = 0 then
    raise exception 'CONV/09 — RLS activee sans aucune policy : table deny-all '
                    'non qualifiee, ce que la matrice du 23/06 proscrit.';
  end if;

  raise notice 'CONV/09 — file de verification en place : % ligne(s), % policy. '
               'conv_backup redevient un instantane.', n_file, n_policy;
end $$;

commit;
