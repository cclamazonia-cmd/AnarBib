-- 20260620090724_works_model_lot1.sql
-- ----------------------------------------------------------------------------
-- P4 Lot 1 — Modèle Œuvre / Éditions (FRBR-léger), socle.
-- Cf. docs/journal/cadrages/CADRAGE_modele_oeuvre_editions_2026-06-20.md
--
-- Ajoute la maille ŒUVRE au-dessus des notices (manifestations). Backfill NON
-- destructif : regroupe les éditions multiples (titre normalisé + auteur·rice
-- principal·e, ≥2 notices) sous une œuvre ; mono-éditions laissées work_id NULL.
-- Intégrations critiques dans la même migration :
--   - merge_author : repoint de works.primary_author_id (7e FK vers authors) ;
--   - suggest_book_duplicates / suggest_draft_duplicates : exclusion des notices
--     de MÊME work_id (= éditions, jamais doublons).
-- Backfill idempotent (ne traite que les notices encore work_id IS NULL).
-- Session : Doublons d'autorité & i18n erreurs catalogue
-- ----------------------------------------------------------------------------

-- == 1. Table works (autorité d'œuvre légère) ==
create table if not exists public.works (
  id                bigint generated always as identity primary key,
  uniform_title     text not null,
  sort_title        text,
  primary_author_id bigint references public.authors(id) on delete set null,
  notes             text,
  created_by        uuid references auth.users(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

alter table public.works enable row level security;
revoke all on table public.works from public, anon;
grant select on table public.works to anon, authenticated;            -- lecture OPAC
grant insert, update, delete on table public.works to authenticated;  -- écriture gardée par RLS

do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='works' and policyname='works_read_all') then
    create policy works_read_all on public.works for select to anon, authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='works' and policyname='works_write_staff') then
    create policy works_write_staff on public.works for all to authenticated
      using (exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian','coordenador']) and m.status='active'))
      with check (exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian','coordenador']) and m.status='active'));
  end if;
end $$;

-- == 2. books.work_id ==
alter table public.books add column if not exists work_id bigint references public.works(id) on delete set null;
create index if not exists idx_books_work_id on public.books(work_id);

-- == 3. Backfill non destructif : 1 œuvre par groupe ≥2 éditions (idempotent) ==
do $backfill$
declare g record; v_work_id bigint;
begin
  for g in
    select public.fn_normalize_name(b.titulo) as nt, p.author_id,
           (array_agg(b.titulo order by nullif(substring(b.ano from '\d{4}'), '')::int nulls last, b.id))[1] as uniform_title,
           array_agg(b.id) as ids
    from public.books b
    join (select ba.book_id, min(ba.author_id) as author_id
            from public.book_authors ba where ba.role='autor' group by ba.book_id) p
      on p.book_id = b.id
    where coalesce(b.titulo,'') <> ''
      and p.author_id is not null
      and b.work_id is null
    group by public.fn_normalize_name(b.titulo), p.author_id
    having count(*) > 1
  loop
    insert into public.works (uniform_title, sort_title, primary_author_id)
    values (g.uniform_title, public.fn_normalize_name(g.uniform_title), g.author_id)
    returning id into v_work_id;
    update public.books set work_id = v_work_id where id = any(g.ids);
  end loop;
end
$backfill$;

-- == 4. merge_author : + repoint works.primary_author_id (7e FK) ==
create or replace function public.merge_author(p_canonical_id bigint, p_duplicate_id bigint)
 returns void language plpgsql security definer set search_path to 'public', 'pg_catalog'
as $function$
declare v_dup_name text;
begin
  if not exists (select 1 from public.user_library_memberships m
                 where m.user_id=auth.uid() and m.role=any(array['librarian'::text,'coordenador'::text])) then
    raise exception 'Acesso restrito ao staff de catalogacao.'; end if;
  if p_canonical_id = p_duplicate_id then raise exception 'Canonico e duplicado identicos.'; end if;
  select preferred_name into v_dup_name from public.authors where id=p_duplicate_id;
  if v_dup_name is null then raise exception 'Duplicado % inexistente.', p_duplicate_id; end if;
  if not exists (select 1 from public.authors where id=p_canonical_id) then raise exception 'Canonico % inexistente.', p_canonical_id; end if;

  update public.book_contributors set author_id=p_canonical_id where author_id=p_duplicate_id;
  insert into public.book_authors (book_id, author_id, role, ord)
    select book_id, p_canonical_id, role, ord from public.book_authors where author_id=p_duplicate_id
    on conflict (book_id, author_id, role, ord) do nothing;
  delete from public.book_authors where author_id=p_duplicate_id;
  update public.author_translations t set author_id=p_canonical_id
    where t.author_id=p_duplicate_id and not exists (select 1 from public.author_translations c where c.author_id=p_canonical_id and c.lang=t.lang);
  update public.author_name_aliases set author_id=p_canonical_id where author_id=p_duplicate_id;
  update public.author_drafts set published_author_id=p_canonical_id where published_author_id=p_duplicate_id;
  update public.book_draft_contributors set author_id=p_canonical_id where author_id=p_duplicate_id;
  -- 5d. Œuvres dont l'autorité principale est le doublon : repoint (P4, 7e FK).
  update public.works set primary_author_id=p_canonical_id where primary_author_id=p_duplicate_id;

  insert into public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  values ('author', p_canonical_id, p_duplicate_id, jsonb_build_object('duplicate_preferred_name', v_dup_name), auth.uid());

  delete from public.authors where id=p_duplicate_id;
end;
$function$;

-- == 5. suggest_book_duplicates : + exclusion des notices de MÊME œuvre ==
create or replace function public.suggest_book_duplicates(p_book_id bigint)
 returns table(book_id bigint, titulo text, autor text, ano text, editora text, isbn text, exemplares integer, match_kind text, score real)
 language plpgsql security definer set search_path to 'public','extensions','pg_catalog'
as $function$
declare v_isbn text; v_title text; v_author text; v_work bigint;
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian'::text,'coordenador'::text])) then
    raise exception 'Acesso restrito ao staff de catalogacao.'; end if;
  select regexp_replace(upper(coalesce(b.isbn,'')),'[^0-9X]','','g'), public.fn_normalize_name(b.titulo), public.fn_normalize_name(b.autor), b.work_id
    into v_isbn, v_title, v_author, v_work from public.books b where b.id=p_book_id;
  if v_title is null then return; end if;
  return query
  with other as (
    select b.id,b.titulo,b.autor,b.ano,b.editora,b.isbn,b.work_id,
           regexp_replace(upper(coalesce(b.isbn,'')),'[^0-9X]','','g') as ni,
           public.fn_normalize_name(b.titulo) as nt, public.fn_normalize_name(b.autor) as na
    from public.books b where b.id<>p_book_id)
  select o.id,o.titulo,o.autor,o.ano,o.editora,o.isbn,
         (select coalesce(sum(h.exemplares_total),0)::integer from public.book_holdings h where h.book_id=o.id),
         case when v_isbn<>'' and o.ni=v_isbn then 'isbn' else 'approx' end,
         case when v_isbn<>'' and o.ni=v_isbn then 1.0::real else similarity(o.nt,v_title)::real end
  from other o
  where not exists (select 1 from public.book_not_duplicate nd where nd.book_id_a=least(p_book_id,o.id) and nd.book_id_b=greatest(p_book_id,o.id))
    -- P4 : même œuvre = éditions, jamais doublons
    and not (v_work is not null and o.work_id = v_work)
    and ( (v_isbn<>'' and o.ni=v_isbn)
       or ( o.nt<>'' and similarity(o.nt,v_title)>=0.5 and (v_author='' or o.na='' or similarity(o.na,v_author)>=0.4)
            and not (v_isbn<>'' and o.ni<>'' and o.ni<>v_isbn) ) )
  order by 9 desc, o.titulo limit 50;
end;
$function$;

-- == 6. suggest_draft_duplicates : + exclusion des notices de MÊME œuvre que le livre publié ==
create or replace function api.suggest_draft_duplicates(p_draft_id bigint)
 returns table(candidate_id bigint, source text, titulo text, subtitulo text, autor text, ano text, editora text, isbn text, cdd text, colecao text, idioma text, tipo_material text, match_kind text, score real)
 language plpgsql stable security definer set search_path to 'public','extensions','pg_catalog'
as $function$
declare v_isbn text; v_title text; v_author text; v_lib uuid; v_pub bigint; v_work bigint;
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian'::text,'coordenador'::text])) then
    raise exception 'Acesso restrito ao staff de catalogacao.'; end if;
  select regexp_replace(upper(coalesce(d.isbn,'')),'[^0-9X]','','g'), public.fn_normalize_name(d.titulo), public.fn_normalize_name(d.autor), d.owner_library_id, d.published_book_id
    into v_isbn, v_title, v_author, v_lib, v_pub from public.book_drafts d where d.id=p_draft_id;
  if v_title is null then return; end if;
  select work_id into v_work from public.books where id = v_pub;
  return query
  with cand as (
    select d.id as cid,'draft'::text as src,d.titulo,d.subtitulo,d.autor,d.ano,d.editora,d.isbn,d.cdd,d.colecao,d.idioma,d.tipo_material,
           null::bigint as cwork,
           regexp_replace(upper(coalesce(d.isbn,'')),'[^0-9X]','','g') as ni, public.fn_normalize_name(d.titulo) as nt, public.fn_normalize_name(d.autor) as na
    from public.book_drafts d where d.status='draft' and d.id<>p_draft_id and (v_lib is null or d.owner_library_id=v_lib)
    union all
    select b.id,'book'::text,b.titulo,b.subtitulo,b.autor,b.ano,b.editora,b.isbn,b.cdd,b.colecao,b.idioma,b.tipo_material,
           b.work_id,
           regexp_replace(upper(coalesce(b.isbn,'')),'[^0-9X]','','g'), public.fn_normalize_name(b.titulo), public.fn_normalize_name(b.autor)
    from public.books b where b.id is distinct from v_pub)
  select c.cid,c.src,c.titulo,c.subtitulo,c.autor,c.ano,c.editora,c.isbn,c.cdd,c.colecao,c.idioma,c.tipo_material,
         case when v_isbn<>'' and c.ni=v_isbn then 'isbn' else 'approx' end,
         case when v_isbn<>'' and c.ni=v_isbn then 1.0::real else similarity(c.nt,v_title)::real end
  from cand c
  where c.nt<>''
    and not ( c.src='book' and v_pub is not null and exists (select 1 from public.book_not_duplicate nd where nd.book_id_a=least(v_pub,c.cid) and nd.book_id_b=greatest(v_pub,c.cid)) )
    -- P4 : candidat publié de la même œuvre que le livre du brouillon = édition, pas doublon
    and not ( c.src='book' and v_work is not null and c.cwork = v_work )
    and ( (v_isbn<>'' and c.ni=v_isbn)
       or ( similarity(c.nt,v_title)>=0.5 and (v_author='' or c.na='' or similarity(c.na,v_author)>=0.4)
            and not (v_isbn<>'' and c.ni<>'' and c.ni<>v_isbn) ) )
  order by 14 desc, c.src, c.titulo limit 50;
end;
$function$;

revoke all on function public.suggest_book_duplicates(bigint) from public, anon;
grant execute on function public.suggest_book_duplicates(bigint) to authenticated;
revoke all on function api.suggest_draft_duplicates(bigint) from public, anon;
grant execute on function api.suggest_draft_duplicates(bigint) to authenticated;

notify pgrst, 'reload schema';
