-- 20260620105747_works_v2_lotC_backend_work_id_view.sql
-- ----------------------------------------------------------------------------
-- P4 v2 Lot C (backend) — expose books.work_id sur les vues catalogue, SANS
-- rebuild de MV (motif « fn scalaire + append à la vue », cf. catalog-opac-list-data-flow).
-- Permet au front (repli/facette « œuvre », étape suivante) de regrouper par work_id.
-- security_invoker=true PRÉSERVÉ. edition_count NON exposé ici (count public-safe
-- viendra avec le RPC collapsé du repli, pour éviter une sous-requête corrélée
-- sur la liste chaude).
-- Session : Doublons d'autorité & i18n erreurs catalogue
-- ----------------------------------------------------------------------------

create or replace function private.fn_book_work_id(p_book_id bigint)
returns bigint
language sql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
  select work_id from public.books where id = p_book_id
$function$;

-- == Vue anonyme : append work_id ==
create or replace view api.catalog_list_anon_v1
with (security_invoker = true) as
 SELECT book_id, bib_ref, autor, titulo, ano, editora, cdd, loanable, available_count, created_at,
        cover_object_path, subtitulo, edicao, local_publicacao, isbn, issn, idioma, tipo_material,
        colecao, assuntos, author_id, catalog_source, library_id, library_slug, library_name, biblioteca,
        has_online_reading, author_display, author_chips, exemplares_total, bibliotecas_count,
        global_available_count, global_exemplares_total, holding_library_names_json,
        private.fn_publisher_display(book_id) AS publisher_display,
        private.fn_book_work_id(book_id) AS work_id
   FROM private.fn_catalog_public_rows() fn_catalog_public_rows(book_id, bib_ref, autor, titulo, ano, editora, cdd, loanable, created_at, cover_object_path, subtitulo, edicao, local_publicacao, isbn, issn, idioma, tipo_material, colecao, assuntos, author_id, catalog_source, library_id, library_slug, library_name, biblioteca, has_online_reading, author_display, author_chips, exemplares_total, bibliotecas_count, global_available_count, global_exemplares_total, available_count, holding_library_names_json)
  WHERE COALESCE(exemplares_total, 0) > 0;

-- == Vue session : append work_id ==
create or replace view api.catalog_list_session_v1
with (security_invoker = true) as
 WITH session_ctx AS (
         SELECT msc.default_library_id FROM api.my_session_context msc LIMIT 1
        ), is_network_member AS (
         SELECT (EXISTS ( SELECT 1 FROM user_library_memberships ulm
                  WHERE ulm.user_id = auth.uid() AND ulm.status = 'active'::text)) AS is_member
        ), session_holdings AS (
         SELECT h.book_id, h.id AS holding_id, h.library_id, h.local_bib_ref,
            h.loanable AS holding_loanable,
            COALESCE(h.available_count, 0) AS available_count,
            COALESCE(h.exemplares_total, 0) AS exemplares_total
           FROM book_holdings h
          WHERE h.library_id = (( SELECT session_ctx.default_library_id FROM session_ctx))
        )
 SELECT m.book_id, m.bib_ref, m.autor, m.titulo, m.ano, m.editora, m.cdd, m.loanable, m.available_count,
    m.created_at, m.cover_object_path, m.subtitulo, m.edicao, m.local_publicacao, m.isbn, m.issn, m.idioma,
    m.tipo_material, m.colecao, m.assuntos, m.author_id, m.catalog_source, m.library_id, m.library_slug,
    m.library_name, m.biblioteca, m.has_online_reading, m.author_display, m.author_chips, m.exemplares_total,
    m.bibliotecas_count, m.global_available_count, m.global_exemplares_total, m.holding_library_names_json,
    sc.default_library_id AS session_library_id,
    ls.slug AS session_library_slug,
    ls.name AS session_library_name,
    COALESCE(sh.exemplares_total, 0) AS session_exemplares_total,
    sh.holding_id IS NOT NULL AS session_has_holding,
        CASE
            WHEN sc.default_library_id IS NULL THEN 'sem_biblioteca_de_sessao'::text
            WHEN sh.holding_id IS NULL THEN 'indisponivel_para_voce'::text
            WHEN COALESCE(sh.holding_loanable, m.loanable, true) IS FALSE THEN 'consultavel_no_local'::text
            ELSE 'no_acervo_da_sua_biblioteca'::text
        END AS session_status_hint,
    COALESCE(sh.available_count, 0) AS session_available_count,
    COALESCE(sh.holding_loanable, m.loanable, true) AS session_loanable,
    private.fn_publisher_display(m.book_id) AS publisher_display,
    private.fn_book_work_id(m.book_id) AS work_id
   FROM private.fn_catalog_network_rows() m(book_id, bib_ref, autor, titulo, ano, editora, cdd, loanable, created_at, cover_object_path, subtitulo, edicao, local_publicacao, isbn, issn, idioma, tipo_material, colecao, assuntos, author_id, catalog_source, library_id, library_slug, library_name, biblioteca, has_online_reading, author_display, author_chips, exemplares_total, bibliotecas_count, global_available_count, global_exemplares_total, available_count, holding_library_names_json)
     LEFT JOIN session_ctx sc ON true
     LEFT JOIN libraries ls ON ls.id = sc.default_library_id
     LEFT JOIN session_holdings sh ON sh.book_id = m.book_id
  WHERE ( SELECT is_network_member.is_member FROM is_network_member)
     OR (EXISTS ( SELECT 1 FROM book_holdings h2 JOIN libraries l2 ON l2.id = h2.library_id
                  WHERE h2.book_id = m.book_id AND l2.is_active = true AND l2.visibility_level = 'public'::text));

grant select on api.catalog_list_anon_v1 to anon, authenticated;
grant select on api.catalog_list_session_v1 to authenticated;

notify pgrst, 'reload schema';
