-- 20260620083749_dedup_edition_aware_not_duplicate.sql
-- ----------------------------------------------------------------------------
-- Dédoublonnage de documents conscient de l'ÉDITION (P1 de l'audit catalogage
-- 2026-06-20). Constat : suggest_book_duplicates / suggest_draft_duplicates ne
-- comparaient que titre+auteur normalisés → trois éditions distinctes d'un même
-- classique (ISBN différents) se signalaient mutuellement, sans moyen d'étouffer
-- une paire jugée à tort.
--
-- P1a — éditions à ISBN distincts ≠ doublons : on exclut la branche « approx »
--       quand les deux ISBN normalisés sont non vides ET différents. (ISBN
--       identique reste un doublon certain.)
-- P1b — table d'arbitrage book_not_duplicate (paires ordonnées a<b) consultée par
--       les suggest_* pour masquer DÉFINITIVEMENT une paire « éditions distinctes »,
--       + RPC mark_books_not_duplicate (staff).
--
-- create or replace : corps repris à l'identique des fonctions live, seules les
-- clauses WHERE changent. SECURITY DEFINER + search_path conservés.
-- Session : Doublons d'autorité & i18n erreurs catalogue
-- ----------------------------------------------------------------------------

-- == P1b : table d'arbitrage ==
create table if not exists public.book_not_duplicate (
  book_id_a  bigint not null references public.books(id) on delete cascade,
  book_id_b  bigint not null references public.books(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (book_id_a, book_id_b),
  constraint book_not_duplicate_ordered check (book_id_a < book_id_b)
);

alter table public.book_not_duplicate enable row level security;
revoke all on table public.book_not_duplicate from public, anon;
grant select, insert, delete on table public.book_not_duplicate to authenticated;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='book_not_duplicate' and policyname='book_not_duplicate_staff_all') then
    create policy book_not_duplicate_staff_all on public.book_not_duplicate
      for all to authenticated
      using (exists (select 1 from public.user_library_memberships m
                     where m.user_id = auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active'))
      with check (exists (select 1 from public.user_library_memberships m
                     where m.user_id = auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active'));
  end if;
end $$;

-- RPC : marquer une paire « pas un doublon » (ordonne la paire, garde staff)
create or replace function public.mark_books_not_duplicate(p_a bigint, p_b bigint)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare v_lo bigint; v_hi bigint;
begin
  if not exists (select 1 from public.user_library_memberships m
                 where m.user_id = auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      using errcode='42501', hint='error.catalog.discard.forbidden';
  end if;
  if p_a is null or p_b is null or p_a = p_b then
    raise exception 'Par de documentos inválido.' using errcode='P0001', hint='error.catalog.notDuplicate.invalidPair';
  end if;
  if not exists (select 1 from public.books where id=p_a) or not exists (select 1 from public.books where id=p_b) then
    raise exception 'Documento inexistente.' using errcode='P0002', hint='error.catalog.notDuplicate.invalidPair';
  end if;
  v_lo := least(p_a, p_b); v_hi := greatest(p_a, p_b);
  insert into public.book_not_duplicate (book_id_a, book_id_b, created_by)
  values (v_lo, v_hi, auth.uid())
  on conflict (book_id_a, book_id_b) do nothing;
end;
$function$;

revoke all on function public.mark_books_not_duplicate(bigint,bigint) from public, anon;
grant execute on function public.mark_books_not_duplicate(bigint,bigint) to authenticated;

-- == P1a : suggest_book_duplicates conscient de l'édition + arbitrage ==
create or replace function public.suggest_book_duplicates(p_book_id bigint)
 returns table(book_id bigint, titulo text, autor text, ano text, editora text, isbn text, exemplares integer, match_kind text, score real)
 language plpgsql
 security definer
 set search_path to 'public', 'extensions', 'pg_catalog'
as $function$
declare
  v_isbn   text;
  v_title  text;
  v_author text;
begin
  if not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = auth.uid()
      and m.role = any (array['librarian'::text, 'coordenador'::text])
  ) then
    raise exception 'Acesso restrito ao staff de catalogacao.';
  end if;

  select regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g'),
         public.fn_normalize_name(b.titulo),
         public.fn_normalize_name(b.autor)
    into v_isbn, v_title, v_author
    from public.books b where b.id = p_book_id;

  if v_title is null then
    return;
  end if;

  return query
  with other as (
    select b.id, b.titulo, b.autor, b.ano, b.editora, b.isbn,
           regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g') as ni,
           public.fn_normalize_name(b.titulo) as nt,
           public.fn_normalize_name(b.autor) as na
    from public.books b
    where b.id <> p_book_id
  )
  select o.id, o.titulo, o.autor, o.ano, o.editora, o.isbn,
         (select coalesce(sum(h.exemplares_total), 0)::integer
            from public.book_holdings h where h.book_id = o.id),
         case when v_isbn <> '' and o.ni = v_isbn then 'isbn' else 'approx' end,
         case when v_isbn <> '' and o.ni = v_isbn then 1.0::real
              else similarity(o.nt, v_title)::real end
  from other o
  where not exists (
          select 1 from public.book_not_duplicate nd
          where nd.book_id_a = least(p_book_id, o.id) and nd.book_id_b = greatest(p_book_id, o.id))
    and ( (v_isbn <> '' and o.ni = v_isbn)
       or ( o.nt <> ''
            and similarity(o.nt, v_title) >= 0.5
            and (v_author = '' or o.na = '' or similarity(o.na, v_author) >= 0.4)
            -- P1a : éditions à ISBN distincts (tous deux renseignés) ≠ doublons
            and not (v_isbn <> '' and o.ni <> '' and o.ni <> v_isbn) ) )
  order by 9 desc, o.titulo
  limit 50;
end;
$function$;

revoke all on function public.suggest_book_duplicates(bigint) from public, anon;
grant execute on function public.suggest_book_duplicates(bigint) to authenticated;

-- == P1a : suggest_draft_duplicates conscient de l'édition + arbitrage (candidats publiés) ==
create or replace function api.suggest_draft_duplicates(p_draft_id bigint)
 returns table(candidate_id bigint, source text, titulo text, subtitulo text, autor text, ano text, editora text, isbn text, cdd text, colecao text, idioma text, tipo_material text, match_kind text, score real)
 language plpgsql
 stable security definer
 set search_path to 'public', 'extensions', 'pg_catalog'
as $function$
declare
  v_isbn   text;
  v_title  text;
  v_author text;
  v_lib    uuid;
  v_pub    bigint;
begin
  if not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = auth.uid()
      and m.role = any (array['librarian'::text, 'coordenador'::text])
  ) then
    raise exception 'Acesso restrito ao staff de catalogacao.';
  end if;

  select regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g'),
         public.fn_normalize_name(d.titulo),
         public.fn_normalize_name(d.autor),
         d.owner_library_id,
         d.published_book_id
    into v_isbn, v_title, v_author, v_lib, v_pub
    from public.book_drafts d
   where d.id = p_draft_id;

  if v_title is null then
    return;
  end if;

  return query
  with cand as (
    select d.id as cid, 'draft'::text as src,
           d.titulo, d.subtitulo, d.autor, d.ano, d.editora, d.isbn, d.cdd,
           d.colecao, d.idioma, d.tipo_material,
           regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g') as ni,
           public.fn_normalize_name(d.titulo) as nt,
           public.fn_normalize_name(d.autor)  as na
    from public.book_drafts d
    where d.status = 'draft'
      and d.id <> p_draft_id
      and (v_lib is null or d.owner_library_id = v_lib)
    union all
    select b.id, 'book'::text,
           b.titulo, b.subtitulo, b.autor, b.ano, b.editora, b.isbn, b.cdd,
           b.colecao, b.idioma, b.tipo_material,
           regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g'),
           public.fn_normalize_name(b.titulo),
           public.fn_normalize_name(b.autor)
    from public.books b
    where b.id is distinct from v_pub
  )
  select c.cid, c.src, c.titulo, c.subtitulo, c.autor, c.ano, c.editora, c.isbn,
         c.cdd, c.colecao, c.idioma, c.tipo_material,
         case when v_isbn <> '' and c.ni = v_isbn then 'isbn' else 'approx' end,
         case when v_isbn <> '' and c.ni = v_isbn then 1.0::real
              else similarity(c.nt, v_title)::real end
  from cand c
  where c.nt <> ''
    -- arbitrage book↔book quand le brouillon est rattaché à un livre publié
    and not ( c.src = 'book' and v_pub is not null and exists (
                select 1 from public.book_not_duplicate nd
                where nd.book_id_a = least(v_pub, c.cid) and nd.book_id_b = greatest(v_pub, c.cid)) )
    and ( (v_isbn <> '' and c.ni = v_isbn)
       or ( similarity(c.nt, v_title) >= 0.5
            and (v_author = '' or c.na = '' or similarity(c.na, v_author) >= 0.4)
            and not (v_isbn <> '' and c.ni <> '' and c.ni <> v_isbn) ) )
  order by 14 desc, c.src, c.titulo
  limit 50;
end;
$function$;

revoke all on function api.suggest_draft_duplicates(bigint) from public, anon;
grant execute on function api.suggest_draft_duplicates(bigint) to authenticated;

notify pgrst, 'reload schema';
