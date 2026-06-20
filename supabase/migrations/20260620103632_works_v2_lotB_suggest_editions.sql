-- 20260620103632_works_v2_lotB_suggest_editions.sql
-- ----------------------------------------------------------------------------
-- P4 v2 Lot B — Auto-regroupement : suggérer les éditions d'une même œuvre.
-- Trouve les notices du MÊME auteur·rice principal·e dont le titre est PROCHE
-- (similarity trigramme, seuil bas 0.35) et qui ne sont pas déjà dans la même
-- œuvre que p_book_id. Indépendant du seuil de doublon : capte les titres voisins
-- ratés par le backfill exact (ex. « La Anarquía » vs « Anarquía »).
-- Gardée staff. Le regroupement effectif passe par group_books_as_editions (Lot 2).
-- Session : Doublons d'autorité & i18n erreurs catalogue
-- ----------------------------------------------------------------------------

create or replace function public.suggest_editions_for_book(p_book_id bigint)
returns table(book_id bigint, titulo text, ano text, editora text, isbn text, work_id bigint, score real)
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_catalog'
as $function$
declare v_title text; v_author bigint; v_work bigint;
begin
  if not exists (select 1 from public.user_library_memberships m
                 where m.user_id = auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      using errcode='42501', hint='error.catalog.discard.forbidden';
  end if;

  select public.fn_normalize_name(b.titulo), b.work_id into v_title, v_work from public.books b where b.id = p_book_id;
  if v_title is null or v_title = '' then return; end if;
  select author_id into v_author from public.book_authors where book_id = p_book_id and role='autor' order by ord limit 1;
  if v_author is null then return; end if; -- besoin d'un auteur·rice principal·e pour regrouper

  return query
  select b.id, b.titulo, b.ano, b.editora, b.isbn, b.work_id,
         similarity(public.fn_normalize_name(b.titulo), v_title)::real
  from public.books b
  where b.id <> p_book_id
    and exists (select 1 from public.book_authors ba
                where ba.book_id = b.id and ba.role='autor' and ba.author_id = v_author)
    -- pas déjà dans la même œuvre que la notice courante
    and not (v_work is not null and b.work_id is not null and b.work_id = v_work)
    and similarity(public.fn_normalize_name(b.titulo), v_title) >= 0.35
  order by 7 desc, b.titulo
  limit 30;
end;
$function$;

revoke all on function public.suggest_editions_for_book(bigint) from public, anon;
grant execute on function public.suggest_editions_for_book(bigint) to authenticated;

notify pgrst, 'reload schema';
