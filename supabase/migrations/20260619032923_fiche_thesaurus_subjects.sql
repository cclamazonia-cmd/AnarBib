-- =========================================================================
-- Fiche livre : surfacer les sujets du THÉSAURUS (book_subjects), pas seulement
-- l'ancien champ texte libre books.assuntos
-- =========================================================================
-- Date     : 2026-06-19
-- Chantier : Sujets thésaurus absents de la fiche livre
-- Auteur   : Claude (assistant·e)
-- Session  : Sujets thésaurus sur la fiche livre
-- Branche  : feat-fiche-thesaurus-subjects (hors worktree partagé)
--
-- Problème : la vue v_book_detail_public_v2 (lue par la fiche livre) exposait
-- uniquement b.assuntos (champ texte libre legacy, rempli pour ~60 livres), et
-- ne joignait JAMAIS le thésaurus matière (book_subjects -> subjects, ~1145
-- livres). Résultat : les sujets indexés via le picker n'apparaissaient pas sur
-- la fiche. Trou d'intégration (la découverte par sujet, elle, utilise déjà le
-- thésaurus), pas un masquage voulu.
--
-- Correctif : on ajoute une colonne subjects_json (agrégat des sujets du
-- thésaurus, libellés multilingues + slug pour le lien de découverte), FILTRÉE
-- aux sujets status='ativo' (on n'expose pas les 'proposto' en attente de
-- validation par la coordination, par cohérence avec la découverte). La vue
-- reste security_invoker ; book_subjects/subjects ont des policies
-- *_select_public (qual=true, anon+authenticated) -> lecture publique OK.
--
-- Front : la fiche (BookPage) affiche subjects_json en puces cliquables ->
-- /catalogo?subject=<slug> (même mécanique que les puces de l'AuthorPage), avec
-- repli sur l'ancien champ assuntos si aucun sujet thésaurus.
--
-- CREATE OR REPLACE VIEW : subjects_json est ajoutée EN FIN de liste (contrainte
-- d'append des colonnes). Définition de la vue reproduite à l'identique pour le
-- reste.
-- =========================================================================

BEGIN;

CREATE OR REPLACE VIEW public.v_book_detail_public_v2
WITH (security_invoker = true) AS
 WITH first_author AS (
         SELECT DISTINCT ON (ba.book_id) ba.book_id,
            ba.author_id
           FROM book_authors ba
          WHERE ba.author_id IS NOT NULL
          ORDER BY ba.book_id, ba.ord, ba.author_id
        ), authors_json_by_book AS (
         SELECT abp.book_id,
            jsonb_agg(jsonb_build_object('author_id', abp.author_id, 'display_name', COALESCE(abp.author_name, abp.sort_name, abp.preferred_name), 'preferred_name', abp.preferred_name, 'sort_name', abp.sort_name, 'role', abp.role, 'ord', abp.ord) ORDER BY abp.ord, abp.author_id) AS authors_json
           FROM author_books_public abp
          GROUP BY abp.book_id
        ), digital_flags AS (
         SELECT r.book_id,
            bool_or(r.resource_type = 'pdf_restrito'::text AND r.usage_type = 'leitura_online'::text AND r.access_scope = 'conta_ativa'::text AND r.status = 'active'::text AND COALESCE(r.is_active, false) = true) AS has_online_reading
           FROM book_digital_resources r
          GROUP BY r.book_id
        ), book_subjects_agg AS (
         SELECT bs.book_id,
            jsonb_agg(jsonb_build_object('subject_id', s.id, 'slug', s.slug, 'label_i18n', s.label_i18n) ORDER BY bs.ord, s.id) AS subjects_json
           FROM book_subjects bs
             JOIN subjects s ON s.id = bs.subject_id
          WHERE s.status = 'ativo'::text
          GROUP BY bs.book_id
        ), holdings_source AS (
         SELECT h.id AS holding_id,
            h.book_id,
            b1.bib_ref AS book_bib_ref,
            COALESCE(NULLIF(TRIM(BOTH FROM h.local_bib_ref), ''::text), b1.bib_ref) AS local_bib_ref,
            h.library_id,
            l.slug AS library_slug,
            l.name AS library_name,
            l.short_name,
            l.city,
            l.state,
            COALESCE(h.loanable, b1.loanable, true) AS holding_loanable,
            COALESCE(h.exemplares_total, 0) AS holding_exemplares_total,
            COALESCE(h.available_count, 0) AS holding_available_count
           FROM book_holdings h
             JOIN books b1 ON b1.id = h.book_id
             JOIN libraries l ON l.id = h.library_id
        ), exemplares_by_holding AS (
         SELECT e.holding_id,
            count(*)::integer AS exemplares_total_real,
            jsonb_agg(e.tombo ORDER BY e.tombo) FILTER (WHERE NULLIF(TRIM(BOTH FROM COALESCE(e.tombo, ''::text)), ''::text) IS NOT NULL) AS tombos_json
           FROM exemplares e
          WHERE e.holding_id IS NOT NULL
          GROUP BY e.holding_id
        ), earliest_due_by_book AS (
         SELECT ei.book_id,
            min(COALESCE(ei.extended_until, ei.due_at)) AS earliest_due_back_at
           FROM emprestimo_itens_v2 ei
          WHERE ei.item_status = 'aberto'::text
          GROUP BY ei.book_id
        ), earliest_due_by_holding AS (
         SELECT ei.book_id,
            e.holding_id,
            min(COALESCE(ei.extended_until, ei.due_at)) AS earliest_due_back_at
           FROM emprestimo_itens_v2 ei
             JOIN exemplares e ON e.id = ei.item_id
          WHERE ei.item_status = 'aberto'::text AND e.holding_id IS NOT NULL
          GROUP BY ei.book_id, e.holding_id
        ), holdings_enriched AS (
         SELECT hs.holding_id,
            hs.book_id,
            hs.book_bib_ref,
            hs.local_bib_ref,
            hs.library_id,
            hs.library_slug,
            hs.library_name,
            hs.short_name,
            hs.city,
            hs.state,
            hs.holding_loanable,
            COALESCE(hs.holding_exemplares_total, exh.exemplares_total_real, 0) AS holding_exemplares_total,
            hs.holding_available_count,
            COALESCE(exh.tombos_json, '[]'::jsonb) AS tombos_json,
            edh.earliest_due_back_at AS holding_earliest_due_back_at
           FROM holdings_source hs
             LEFT JOIN exemplares_by_holding exh ON exh.holding_id = hs.holding_id
             LEFT JOIN earliest_due_by_holding edh ON edh.holding_id = hs.holding_id
        ), holdings_rollup_by_book AS (
         SELECT he.book_id,
            COALESCE(sum(he.holding_exemplares_total), 0::bigint)::integer AS exemplares_total,
            count(*)::integer AS bibliotecas_count,
            COALESCE(sum(he.holding_available_count), 0::bigint)::integer AS global_available_count,
            jsonb_agg(jsonb_build_object('holding_id', he.holding_id, 'library_id', he.library_id, 'library_slug', he.library_slug, 'library_name', he.library_name, 'short_name', he.short_name, 'city', he.city, 'state', he.state, 'local_bib_ref', he.local_bib_ref, 'loanable', he.holding_loanable, 'available_count', he.holding_available_count, 'exemplares_total', he.holding_exemplares_total, 'tombos_json', he.tombos_json, 'earliest_due_back_at', he.holding_earliest_due_back_at) ORDER BY he.library_name, he.library_slug, he.holding_id) AS holding_libraries_json
           FROM holdings_enriched he
          GROUP BY he.book_id
        ), single_library AS (
         SELECT he.book_id,
            he.library_id,
            he.library_slug,
            he.library_name
           FROM holdings_enriched he
             JOIN ( SELECT holdings_enriched.book_id
                   FROM holdings_enriched
                  GROUP BY holdings_enriched.book_id
                 HAVING count(*) = 1) one ON one.book_id = he.book_id
        ), tombos_all AS (
         SELECT x.book_id,
            jsonb_agg(x.tombo ORDER BY x.tombo) AS tombos_json
           FROM ( SELECT he.book_id,
                    jsonb_array_elements_text(he.tombos_json) AS tombo
                   FROM holdings_enriched he) x
          GROUP BY x.book_id
        )
 SELECT b.id,
    b.id AS book_id,
    b.bib_ref,
    b.autor,
    b.titulo,
    b.ano,
    b.editora,
    b.cdd,
    COALESCE(b.loanable, true) AS loanable,
    COALESCE(hr.global_available_count, 0) AS available_count,
    b.created_at,
    b.cover_object_path,
    b.subtitulo,
    b.edicao,
    b.local_publicacao,
    b.isbn,
    b.issn,
    b.idioma,
    b.paginas,
    b.notas,
    b.tipo_material,
    b.autores_secundarios,
    b.colecao,
    b.volume,
    b.assuntos,
    b.tradutor,
    b.organizador,
    fa.author_id,
    b.catalog_source,
        CASE
            WHEN hr.bibliotecas_count = 1 THEN sl.library_id
            ELSE NULL::uuid
        END AS library_id,
        CASE
            WHEN hr.bibliotecas_count = 1 THEN sl.library_slug
            ELSE NULL::text
        END AS library_slug,
        CASE
            WHEN hr.bibliotecas_count = 1 THEN sl.library_name
            ELSE NULL::text
        END AS library_name,
        CASE
            WHEN hr.bibliotecas_count = 1 THEN sl.library_name
            WHEN hr.bibliotecas_count > 1 THEN hr.bibliotecas_count::text || ' bibliotecas'::text
            ELSE NULL::text
        END AS biblioteca,
    COALESCE(df.has_online_reading, false) AS has_online_reading,
    COALESCE(c.author_display, b.autor) AS author_display,
    COALESCE(c.author_chips, '[]'::jsonb) AS author_chips,
    COALESCE(aj.authors_json, '[]'::jsonb) AS authors_json,
    COALESCE(hr.exemplares_total, 0) AS exemplares_total,
    COALESCE(hr.bibliotecas_count, 0) AS bibliotecas_count,
    COALESCE(hr.holding_libraries_json, '[]'::jsonb) AS holding_libraries_json,
    COALESCE(ta.tombos_json, '[]'::jsonb) AS tombos_json,
    COALESCE(hr.global_available_count, 0) AS global_available_count,
    COALESCE(b.available_count, 0) AS legacy_available_count_global,
    COALESCE(hr.exemplares_total, 0) AS global_exemplares_total,
    edb.earliest_due_back_at,
    b.distribuidora,
    b.gravadora,
    COALESCE(bsa.subjects_json, '[]'::jsonb) AS subjects_json
   FROM books b
     LEFT JOIN first_author fa ON fa.book_id = b.id
     LEFT JOIN v_book_authors_canonical c ON c.book_id = b.id
     LEFT JOIN authors_json_by_book aj ON aj.book_id = b.id
     LEFT JOIN holdings_rollup_by_book hr ON hr.book_id = b.id
     LEFT JOIN single_library sl ON sl.book_id = b.id
     LEFT JOIN tombos_all ta ON ta.book_id = b.id
     LEFT JOIN digital_flags df ON df.book_id = b.id
     LEFT JOIN earliest_due_by_book edb ON edb.book_id = b.id
     LEFT JOIN book_subjects_agg bsa ON bsa.book_id = b.id;

COMMIT;
