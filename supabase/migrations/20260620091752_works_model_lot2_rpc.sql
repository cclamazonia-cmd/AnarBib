-- 20260620091752_works_model_lot2_rpc.sql
-- ----------------------------------------------------------------------------
-- P4 Lot 2 — RPC de gestion des œuvres (non destructives, gardées staff).
-- Cf. CADRAGE_modele_oeuvre_editions_2026-06-20.md. Socle = Lot 1 (20260620090724).
--
--   create_work_from_book(p_book_id)         -> crée l'œuvre depuis la notice + rattache (idempotent)
--   assign_book_to_work(p_book_id, p_work_id) -> rattache une notice à une œuvre
--   detach_book_from_work(p_book_id)          -> détache
--   group_books_as_editions(p_book_ids[])     -> regroupe ≥2 notices sous UNE œuvre commune
--
-- NON destructif : on ne fusionne jamais de notice ici. La « fusion sur certitude »
-- (ISBN identique = même édition) reste l'action explicite merge_book, proposée sur
-- les correspondances ISBN-100 % du dédoublonnage.
-- Gardées staff (librarian/coordenador) ; hint forbidden = error.catalog.discard.forbidden.
-- Session : Doublons d'autorité & i18n erreurs catalogue
-- ----------------------------------------------------------------------------

create or replace function public.create_work_from_book(p_book_id bigint)
returns bigint language plpgsql security definer set search_path to 'public', 'pg_temp'
as $function$
declare v_work bigint; v_title text; v_author bigint;
begin
  if not exists (select 1 from public.user_library_memberships m
                 where m.user_id=auth.uid() and m.role=any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      using errcode='42501', hint='error.catalog.discard.forbidden'; end if;
  select work_id, titulo into v_work, v_title from public.books where id=p_book_id;
  if not found then raise exception 'Documento inexistente.' using errcode='P0002', hint='error.catalog.work.notFound'; end if;
  if v_work is not null then return v_work; end if; -- déjà rattaché : idempotent
  select author_id into v_author from public.book_authors where book_id=p_book_id and role='autor' order by ord limit 1;
  insert into public.works (uniform_title, sort_title, primary_author_id, created_by)
  values (coalesce(nullif(v_title,''), '(sans titre)'), public.fn_normalize_name(v_title), v_author, auth.uid())
  returning id into v_work;
  update public.books set work_id=v_work where id=p_book_id;
  return v_work;
end;
$function$;

create or replace function public.assign_book_to_work(p_book_id bigint, p_work_id bigint)
returns void language plpgsql security definer set search_path to 'public', 'pg_temp'
as $function$
begin
  if not exists (select 1 from public.user_library_memberships m
                 where m.user_id=auth.uid() and m.role=any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      using errcode='42501', hint='error.catalog.discard.forbidden'; end if;
  if not exists (select 1 from public.books where id=p_book_id) then
    raise exception 'Documento inexistente.' using errcode='P0002', hint='error.catalog.work.notFound'; end if;
  if not exists (select 1 from public.works where id=p_work_id) then
    raise exception 'Obra inexistente.' using errcode='P0002', hint='error.catalog.work.notFound'; end if;
  update public.books set work_id=p_work_id where id=p_book_id;
end;
$function$;

create or replace function public.detach_book_from_work(p_book_id bigint)
returns void language plpgsql security definer set search_path to 'public', 'pg_temp'
as $function$
begin
  if not exists (select 1 from public.user_library_memberships m
                 where m.user_id=auth.uid() and m.role=any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      using errcode='42501', hint='error.catalog.discard.forbidden'; end if;
  update public.books set work_id=null where id=p_book_id;
end;
$function$;

-- Regroupe ≥2 notices sous UNE œuvre commune. Œuvre cible = la plus petite œuvre
-- déjà présente dans la sélection, sinon une nouvelle créée depuis l'édition la
-- plus ancienne. Renvoie l'id de l'œuvre. Idempotent (réassigne au même work).
create or replace function public.group_books_as_editions(p_book_ids bigint[])
returns bigint language plpgsql security definer set search_path to 'public', 'pg_temp'
as $function$
declare v_work bigint; v_oldest bigint; v_title text; v_author bigint; v_n int;
begin
  if not exists (select 1 from public.user_library_memberships m
                 where m.user_id=auth.uid() and m.role=any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      using errcode='42501', hint='error.catalog.discard.forbidden'; end if;
  select count(*) into v_n from public.books where id = any(p_book_ids);
  if v_n < 2 then
    raise exception 'Selecione ao menos dois documentos.' using errcode='P0001', hint='error.catalog.work.needTwo'; end if;

  -- œuvre cible : la plus petite œuvre déjà présente dans la sélection
  select min(work_id) into v_work from public.books where id = any(p_book_ids) and work_id is not null;
  if v_work is null then
    -- aucune œuvre existante : créer depuis l'édition la plus ancienne
    select id, titulo into v_oldest, v_title from public.books where id = any(p_book_ids)
      order by nullif(substring(ano from '\d{4}'), '')::int nulls last, id limit 1;
    select author_id into v_author from public.book_authors where book_id=v_oldest and role='autor' order by ord limit 1;
    insert into public.works (uniform_title, sort_title, primary_author_id, created_by)
    values (coalesce(nullif(v_title,''), '(sans titre)'), public.fn_normalize_name(v_title), v_author, auth.uid())
    returning id into v_work;
  end if;

  update public.books set work_id=v_work where id = any(p_book_ids);
  return v_work;
end;
$function$;

revoke all on function public.create_work_from_book(bigint)        from public, anon;
revoke all on function public.assign_book_to_work(bigint,bigint)   from public, anon;
revoke all on function public.detach_book_from_work(bigint)        from public, anon;
revoke all on function public.group_books_as_editions(bigint[])    from public, anon;
grant execute on function public.create_work_from_book(bigint)        to authenticated;
grant execute on function public.assign_book_to_work(bigint,bigint)   to authenticated;
grant execute on function public.detach_book_from_work(bigint)        to authenticated;
grant execute on function public.group_books_as_editions(bigint[])    to authenticated;

notify pgrst, 'reload schema';
