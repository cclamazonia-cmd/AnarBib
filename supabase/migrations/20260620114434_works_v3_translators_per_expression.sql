-- 20260620114434_works_v3_translators_per_expression.sql
-- ----------------------------------------------------------------------------
-- P4 v3 — Traducteur·rice par Expression (FRBR). DÉRIVÉ des contributeurs liés
-- (book_contributors role='tradutor', author_id) des éditions de l'expression —
-- PAS de colonne sur work_expressions (évite la duplication/dérive : la source de
-- vérité reste le lien contributeur↔autorité). work_public_detail expose
-- `translators` par expression ; vide aujourd'hui (aucun traducteur lié), s'allume
-- dès qu'un·e traducteur·rice est rattaché·e à une autorité dans le catalogage.
-- Session : Doublons d'autorité & i18n erreurs catalogue
-- ----------------------------------------------------------------------------

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
  trans as (
    select r.expression_id as eid,
           jsonb_agg(distinct jsonb_build_object('author_id', a2.id, 'name', a2.preferred_name)) tr
    from rows r
    join public.book_contributors bc on bc.book_id = r.book_id and bc.role = 'tradutor' and bc.author_id is not null
    join public.authors a2 on a2.id = bc.author_id
    group by r.expression_id
  ),
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
            order by nullif(substring(r.ano from '\d{4}'), '')::int nulls last, r.titulo),
          'translators', coalesce((select tr from trans where trans.eid = r.expression_id), '[]'::jsonb)) as e
      from rows r left join public.work_expressions we on we.id = r.expression_id
      group by r.expression_id, coalesce(we.lang, '')
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
