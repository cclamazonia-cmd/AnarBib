-- 20260620113134_works_v3_expressions.sql
-- ----------------------------------------------------------------------------
-- P4 v3 — Couche FRBR Expression (langue/version) : Œuvre → Expression → Manifestation.
-- Décision : on construit l'entité maintenant (même sur peu d'occurrences), consommée
-- par le regroupement par langue de la page Œuvre. `expression_id` est dérivé de
-- (work_id, langue) et maintenu par trigger → les RPC de regroupement existantes
-- (group_books_as_editions, assign_book_to_work…) le mettent à jour automatiquement.
-- Session : Doublons d'autorité & i18n erreurs catalogue
-- ----------------------------------------------------------------------------

-- == 1. Table work_expressions (une expression = une langue d'une œuvre) ==
create table if not exists public.work_expressions (
  id         bigint generated always as identity primary key,
  work_id    bigint not null references public.works(id) on delete cascade,
  lang       text not null default '',       -- langue normalisée (lower/trim) ; '' = non précisée
  created_at timestamptz not null default now(),
  unique (work_id, lang)
);

alter table public.work_expressions enable row level security;
revoke all on table public.work_expressions from public, anon;
grant select on table public.work_expressions to anon, authenticated;
grant insert, update, delete on table public.work_expressions to authenticated;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='work_expressions' and policyname='work_expressions_read_all') then
    create policy work_expressions_read_all on public.work_expressions for select to anon, authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='work_expressions' and policyname='work_expressions_write_staff') then
    create policy work_expressions_write_staff on public.work_expressions for all to authenticated
      using (exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian','coordenador']) and m.status='active'))
      with check (exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian','coordenador']) and m.status='active'));
  end if;
end $$;

-- == 2. books.expression_id ==
alter table public.books add column if not exists expression_id bigint references public.work_expressions(id) on delete set null;
create index if not exists idx_books_expression_id on public.books(expression_id);

-- == 3. Backfill explicite (avant le trigger) ==
insert into public.work_expressions (work_id, lang)
  select distinct b.work_id, coalesce(lower(btrim(b.idioma)), '')
  from public.books b where b.work_id is not null
  on conflict (work_id, lang) do nothing;
update public.books b set expression_id = e.id
  from public.work_expressions e
  where b.work_id is not null and e.work_id = b.work_id and e.lang = coalesce(lower(btrim(b.idioma)), '');

-- == 4. Trigger de maintenance : dérive expression_id de (work_id, idioma) ==
create or replace function public.fn_sync_book_expression()
returns trigger language plpgsql security definer set search_path to 'public', 'pg_temp'
as $function$
declare v_lang text; v_expr bigint;
begin
  if NEW.work_id is null then
    NEW.expression_id := null;
    return NEW;
  end if;
  v_lang := coalesce(lower(btrim(NEW.idioma)), '');
  insert into public.work_expressions (work_id, lang) values (NEW.work_id, v_lang)
    on conflict (work_id, lang) do update set lang = excluded.lang
    returning id into v_expr;
  NEW.expression_id := v_expr;
  return NEW;
end;
$function$;

drop trigger if exists trg_sync_book_expression on public.books;
create trigger trg_sync_book_expression
  before insert or update of work_id, idioma on public.books
  for each row execute function public.fn_sync_book_expression();

-- == 5. work_public_detail : + expressions (regroupement par langue) ==
create or replace function api.work_public_detail(p_work_id bigint)
returns jsonb language sql stable set search_path to 'public', 'pg_catalog'
as $function$
  with rows as (
    select c.book_id, c.titulo, c.ano, c.editora, b.idioma, c.cover_object_path, c.bib_ref, b.expression_id
    from api.catalog_list_anon_v1 c
    join public.books b on b.id = c.book_id
    where b.work_id = p_work_id
  ),
  eds as (select count(*) n from rows),
  flat as (
    select jsonb_agg(jsonb_build_object('book_id', r.book_id, 'titulo', r.titulo, 'ano', r.ano, 'editora', r.editora, 'idioma', r.idioma, 'cover_object_path', r.cover_object_path, 'bib_ref', r.bib_ref)
           order by nullif(substring(r.ano from '\d{4}'), '')::int nulls last, r.titulo) arr
    from rows r
  ),
  expr as (
    select jsonb_agg(g.e order by g.lang) arr from (
      select coalesce(we.lang, '') as lang,
             jsonb_build_object('lang', coalesce(we.lang, ''),
               'editions', jsonb_agg(jsonb_build_object('book_id', r.book_id, 'titulo', r.titulo, 'ano', r.ano, 'editora', r.editora, 'idioma', r.idioma, 'cover_object_path', r.cover_object_path, 'bib_ref', r.bib_ref)
                 order by nullif(substring(r.ano from '\d{4}'), '')::int nulls last, r.titulo)) as e
      from rows r left join public.work_expressions we on we.id = r.expression_id
      group by coalesce(we.lang, '')
    ) g
  )
  select case when (select n from eds) = 0 then null
    else jsonb_build_object(
      'id', w.id, 'uniform_title', w.uniform_title,
      'primary_author_id', w.primary_author_id, 'author_name', a.preferred_name,
      'editions', coalesce((select arr from flat), '[]'::jsonb),
      'expressions', coalesce((select arr from expr), '[]'::jsonb)
    ) end
  from public.works w
  left join public.authors a on a.id = w.primary_author_id
  where w.id = p_work_id;
$function$;

revoke all on function api.work_public_detail(bigint) from public;
grant execute on function api.work_public_detail(bigint) to anon, authenticated;

notify pgrst, 'reload schema';
