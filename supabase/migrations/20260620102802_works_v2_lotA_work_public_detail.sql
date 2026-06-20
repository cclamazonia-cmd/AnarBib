-- 20260620102802_works_v2_lotA_work_public_detail.sql
-- ----------------------------------------------------------------------------
-- P4 v2 Lot A — Page Œuvre OPAC : détail public d'une œuvre + ses éditions.
-- Calque la logique public-safe de api.book_other_editions : lit
-- api.catalog_list_anon_v1 (security_invoker → visibilité du lecteur) joint à
-- books par work_id. Renvoie NULL si l'œuvre n'a aucune édition publiquement
-- visible (anti-fuite + 404 côté front). Langue par édition (books.idioma).
-- Session : Doublons d'autorité & i18n erreurs catalogue
-- ----------------------------------------------------------------------------

create or replace function api.work_public_detail(p_work_id bigint)
returns jsonb
language sql
stable
set search_path to 'public', 'pg_catalog'
as $function$
  with eds as (
    select jsonb_agg(jsonb_build_object(
             'book_id', c.book_id, 'titulo', c.titulo, 'ano', c.ano, 'editora', c.editora,
             'idioma', b.idioma, 'cover_object_path', c.cover_object_path, 'bib_ref', c.bib_ref)
           order by nullif(substring(c.ano from '\d{4}'), '')::int nulls last, c.titulo) as arr,
           count(*) as n
    from api.catalog_list_anon_v1 c
    join public.books b on b.id = c.book_id
    where b.work_id = p_work_id
  )
  select case when (select n from eds) = 0 then null
    else jsonb_build_object(
      'id', w.id,
      'uniform_title', w.uniform_title,
      'primary_author_id', w.primary_author_id,
      'author_name', a.preferred_name,
      'editions', (select arr from eds)
    ) end
  from public.works w
  left join public.authors a on a.id = w.primary_author_id
  where w.id = p_work_id;
$function$;

revoke all on function api.work_public_detail(bigint) from public;
grant execute on function api.work_public_detail(bigint) to anon, authenticated;

notify pgrst, 'reload schema';
