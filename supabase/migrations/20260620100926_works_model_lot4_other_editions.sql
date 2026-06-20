-- 20260620100926_works_model_lot4_other_editions.sql
-- ----------------------------------------------------------------------------
-- P4 Lot 4 — OPAC : autres éditions d'une même œuvre.
-- Calque api.similar_books : lit api.catalog_list_anon_v1 (surface publique,
-- security_invoker → respecte la visibilité du lecteur), filtre par books.work_id.
-- Public-only par design (comme similar_books) : aucune fuite réseau.
-- Session : Doublons d'autorité & i18n erreurs catalogue
-- ----------------------------------------------------------------------------

create or replace function api.book_other_editions(p_book_id bigint)
returns table(book_id bigint, titulo text, author_label text, ano text, editora text, cover_object_path text, bib_ref text)
language sql
stable
set search_path to 'public', 'pg_catalog'
as $function$
  select c.book_id, c.titulo, coalesce(c.author_display, c.autor), c.ano, c.editora, c.cover_object_path, c.bib_ref
  from api.catalog_list_anon_v1 c
  join public.books b on b.id = c.book_id
  where b.work_id is not null
    and b.work_id = (select work_id from public.books where id = p_book_id)
    and c.book_id <> p_book_id
  order by nullif(substring(c.ano from '\d{4}'), '')::int nulls last, c.titulo
$function$;

revoke all on function api.book_other_editions(bigint) from public;
grant execute on function api.book_other_editions(bigint) to anon, authenticated;

notify pgrst, 'reload schema';
