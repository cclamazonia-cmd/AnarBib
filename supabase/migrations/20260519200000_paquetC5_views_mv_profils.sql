-- ============================================================================
-- Paquet C.5 — Vues et MV (network_overview + mv_books_catalog_list_network_v1)
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.3
-- Dependance : paquetC2_helpers_modes_profils.sql (helpers profils)
--
-- Objectif : filtrer les compteurs reseau et le catalogue federe par
-- network_mode <> 'isolated' et catalog_mode = 'network_published'.
--
-- 2 OBJETS PATCHES :
--
--   1. api.network_overview : ajouter filtre network_mode <> 'isolated' aux
--      sous-requetes libraries_active et aux compteurs derives. Coherence
--      doctrine §2.5 : biblio isolated ne contribue pas aux statistiques reseau.
--
--   2. public.mv_books_catalog_list_network_v1 : ajouter filtres
--      catalog_mode = 'network_published' AND network_mode <> 'isolated'
--      au CTE holdings_with_lib. Doctrine spec §9.3 : seules les biblios
--      qui ont explicitement publie leur catalogue apparaissent dans le
--      listing reseau.
--
-- Note 1 : api.libraries_public_v1 utilise deja fn_library_visible_to_caller(id)
-- qui inclut le filtre isolated (etendu en C.2). Rien a patcher.
--
-- Note 2 : la vue api.catalog_list_session_v1 depend de la MV. Elle doit
-- etre supprimee et recree dans la meme transaction (identique a l'originale).
--
-- Note 3 : 12 index sur la MV doivent etre recrees apres DROP/CREATE.
--
-- Risque : eleve (DROP MV CASCADE casse la vue dependante). Mitigation :
-- transaction unique BEGIN/COMMIT pour atomicite, recreation immediate
-- de la vue dependante avec definition identique.
-- ============================================================================

BEGIN;

-- ===========================================================================
-- A. api.network_overview — filtre network_mode <> 'isolated'
-- ===========================================================================
-- Patch : ajouter AND network_mode <> 'isolated' aux compteurs sur libraries.
-- Pour books/authors/exemplares/circulation_stats : ces tables sont jointes
-- aux libraries via leur library_id, mais leur filtrage par network_mode
-- demanderait des JOINs supplementaires. On filtre uniquement libraries_active
-- ici pour minimiser le risque. Les autres compteurs restent globaux SIGB.

DROP VIEW IF EXISTS api.network_overview;
CREATE VIEW api.network_overview
WITH (security_invoker = true)
AS
 SELECT ( SELECT count(*) AS count
           FROM network_administrators
          WHERE network_administrators.status = 'active'::text) AS network_admins_active,
    ( SELECT count(*) AS count
           FROM network_administrator_cooptation_proposals
          WHERE network_administrator_cooptation_proposals.status = 'open'::text) AS open_cooptation_proposals,
    ( SELECT count(*) AS count
           FROM libraries
          WHERE libraries.is_active = true
            AND libraries.network_mode <> 'isolated') AS libraries_active,
    ( SELECT count(*) AS count
           FROM books) AS books_total,
    ( SELECT count(*) AS count
           FROM authors) AS authors_total,
    ( SELECT count(*) AS count
           FROM exemplares) AS exemplars_total,
    ( SELECT COALESCE(sum(library_circulation_stats.loans_open), 0::numeric) AS "coalesce"
           FROM api.library_circulation_stats) AS loans_open_total,
    ( SELECT COALESCE(sum(library_circulation_stats.loans_overdue), 0::numeric) AS "coalesce"
           FROM api.library_circulation_stats) AS loans_overdue_total,
    ( SELECT COALESCE(sum(library_circulation_stats.reservations_active), 0::numeric) AS "coalesce"
           FROM api.library_circulation_stats) AS reservations_active_total;

-- ===========================================================================
-- B. mv_books_catalog_list_network_v1 — filtre catalog_mode + isolated
-- ===========================================================================

-- B.1. DROP de la vue dependante
DROP VIEW IF EXISTS api.catalog_list_session_v1;

-- B.2. DROP de la MV (CASCADE pour supprimer les 12 index)
DROP MATERIALIZED VIEW IF EXISTS public.mv_books_catalog_list_network_v1 CASCADE;

-- B.3. CREATE de la MV avec filtres ajoutes
CREATE MATERIALIZED VIEW public.mv_books_catalog_list_network_v1 AS
 WITH first_author AS (
         SELECT DISTINCT ON (ba.book_id) ba.book_id,
            ba.author_id
           FROM book_authors ba
          WHERE ba.author_id IS NOT NULL
          ORDER BY ba.book_id, ba.ord, ba.author_id
        ), digital_flags AS (
         SELECT r.book_id,
            bool_or(r.resource_type = 'pdf_restrito'::text AND r.usage_type = 'leitura_online'::text AND r.access_scope = 'conta_ativa'::text AND r.status = 'active'::text AND COALESCE(r.is_active, false) = true) AS has_online_reading
           FROM book_digital_resources r
          GROUP BY r.book_id
        ), holdings_with_lib AS (
         SELECT h.book_id,
            h.library_id,
            h.exemplares_total,
            h.available_count,
            l.slug AS library_slug,
            l.name AS library_name,
            l.short_name
           FROM book_holdings h
             JOIN libraries l ON l.id = h.library_id
          WHERE l.is_active = true
            AND (l.visibility_level = ANY (ARRAY['public'::text, 'network'::text]))
            -- ============================================================
            -- PAQUET C.5 — filtres profils d'adoption
            -- ============================================================
            AND l.catalog_mode = 'network_published'
            AND l.network_mode <> 'isolated'
        ), holdings_summary AS (
         SELECT holdings_with_lib.book_id,
            count(*)::integer AS bibliotecas_count,
            COALESCE(sum(holdings_with_lib.exemplares_total), 0::bigint)::integer AS exemplares_total,
            COALESCE(sum(holdings_with_lib.available_count), 0::bigint)::integer AS global_available_count,
                CASE
                    WHEN count(*) = 1 THEN (array_agg(holdings_with_lib.library_id))[1]
                    ELSE NULL::uuid
                END AS single_library_id,
                CASE
                    WHEN count(*) = 1 THEN (array_agg(holdings_with_lib.library_slug))[1]
                    ELSE NULL::text
                END AS single_library_slug,
                CASE
                    WHEN count(*) = 1 THEN (array_agg(holdings_with_lib.library_name))[1]
                    ELSE NULL::text
                END AS single_library_name
           FROM holdings_with_lib
          GROUP BY holdings_with_lib.book_id
        ), holding_library_names AS (
         SELECT holdings_with_lib.book_id,
            jsonb_agg(COALESCE(holdings_with_lib.short_name, holdings_with_lib.library_name, holdings_with_lib.library_slug) ORDER BY holdings_with_lib.library_name) AS holding_library_names_json
           FROM holdings_with_lib
          GROUP BY holdings_with_lib.book_id
        )
 SELECT b.id AS book_id,
    b.bib_ref,
    b.autor,
    b.titulo,
    b.ano,
    b.editora,
    b.cdd,
    COALESCE(b.loanable, true) AS loanable,
    b.created_at,
    b.cover_object_path,
    b.subtitulo,
    b.edicao,
    b.local_publicacao,
    b.isbn,
    b.issn,
    b.idioma,
    b.tipo_material,
    b.colecao,
    b.assuntos,
    fa.author_id,
    b.catalog_source,
    hs.single_library_id AS library_id,
    hs.single_library_slug AS library_slug,
    hs.single_library_name AS library_name,
        CASE
            WHEN hs.bibliotecas_count = 1 THEN hs.single_library_name
            WHEN hs.bibliotecas_count > 1 THEN hs.bibliotecas_count::text || ' bibliotecas'::text
            ELSE NULL::text
        END AS biblioteca,
    COALESCE(df.has_online_reading, false) AS has_online_reading,
    COALESCE(c.author_display, b.autor) AS author_display,
    COALESCE(c.author_chips, '[]'::jsonb) AS author_chips,
    COALESCE(hs.exemplares_total, 0) AS exemplares_total,
    COALESCE(hs.bibliotecas_count, 0) AS bibliotecas_count,
    COALESCE(hs.global_available_count, 0) AS global_available_count,
    COALESCE(hs.exemplares_total, 0) AS global_exemplares_total,
    COALESCE(hs.global_available_count, 0) AS available_count,
    COALESCE(hln.holding_library_names_json, '[]'::jsonb) AS holding_library_names_json
   FROM books b
     LEFT JOIN first_author fa ON fa.book_id = b.id
     LEFT JOIN v_book_authors_canonical c ON c.book_id = b.id
     LEFT JOIN holdings_summary hs ON hs.book_id = b.id
     LEFT JOIN holding_library_names hln ON hln.book_id = b.id
     LEFT JOIN digital_flags df ON df.book_id = b.id
  WHERE hs.book_id IS NOT NULL;

-- B.4. Recreation des 12 index
CREATE UNIQUE INDEX mv_books_catalog_list_network_v1_book_id_uidx ON public.mv_books_catalog_list_network_v1 USING btree (book_id);
CREATE INDEX mv_books_catalog_list_network_v1_ano_idx ON public.mv_books_catalog_list_network_v1 USING btree (ano);
CREATE INDEX mv_books_catalog_list_network_v1_autor_idx ON public.mv_books_catalog_list_network_v1 USING btree (autor);
CREATE INDEX mv_books_catalog_list_network_v1_autor_norm_trgm_idx ON public.mv_books_catalog_list_network_v1 USING gin (f_normalize_search(autor) gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_network_v1_autor_trgm_idx ON public.mv_books_catalog_list_network_v1 USING gin (autor gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_network_v1_created_at_idx ON public.mv_books_catalog_list_network_v1 USING btree (created_at DESC);
CREATE INDEX mv_books_catalog_list_network_v1_editora_trgm_idx ON public.mv_books_catalog_list_network_v1 USING gin (editora gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_network_v1_library_slug_idx ON public.mv_books_catalog_list_network_v1 USING btree (library_slug) WHERE (library_slug IS NOT NULL);
CREATE INDEX mv_books_catalog_list_network_v1_tipo_material_idx ON public.mv_books_catalog_list_network_v1 USING btree (tipo_material);
CREATE INDEX mv_books_catalog_list_network_v1_titulo_idx ON public.mv_books_catalog_list_network_v1 USING btree (titulo);
CREATE INDEX mv_books_catalog_list_network_v1_titulo_norm_trgm_idx ON public.mv_books_catalog_list_network_v1 USING gin (f_normalize_search(titulo) gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_network_v1_titulo_trgm_idx ON public.mv_books_catalog_list_network_v1 USING gin (titulo gin_trgm_ops);

-- B.5. Recreation de la vue dependante api.catalog_list_session_v1
CREATE VIEW api.catalog_list_session_v1
WITH (security_invoker = true)
AS
 WITH session_ctx AS (
         SELECT msc.default_library_id
           FROM api.my_session_context msc
         LIMIT 1
        ), is_network_member AS (
         SELECT (EXISTS ( SELECT 1
                   FROM user_library_memberships ulm
                  WHERE ulm.user_id = auth.uid() AND ulm.status = 'active'::text)) AS is_member
        ), session_holdings AS (
         SELECT h.book_id,
            h.id AS holding_id,
            h.library_id,
            h.local_bib_ref,
            h.loanable AS holding_loanable,
            COALESCE(h.available_count, 0) AS available_count,
            COALESCE(h.exemplares_total, 0) AS exemplares_total
           FROM book_holdings h
          WHERE h.library_id = (( SELECT session_ctx.default_library_id
                   FROM session_ctx))
        )
 SELECT m.book_id,
    m.bib_ref,
    m.autor,
    m.titulo,
    m.ano,
    m.editora,
    m.cdd,
    m.loanable,
    m.available_count,
    m.created_at,
    m.cover_object_path,
    m.subtitulo,
    m.edicao,
    m.local_publicacao,
    m.isbn,
    m.issn,
    m.idioma,
    m.tipo_material,
    m.colecao,
    m.assuntos,
    m.author_id,
    m.catalog_source,
    m.library_id,
    m.library_slug,
    m.library_name,
    m.biblioteca,
    m.has_online_reading,
    m.author_display,
    m.author_chips,
    m.exemplares_total,
    m.bibliotecas_count,
    m.global_available_count,
    m.global_exemplares_total,
    m.holding_library_names_json,
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
    COALESCE(sh.holding_loanable, m.loanable, true) AS session_loanable
   FROM mv_books_catalog_list_network_v1 m
     LEFT JOIN session_ctx sc ON true
     LEFT JOIN libraries ls ON ls.id = sc.default_library_id
     LEFT JOIN session_holdings sh ON sh.book_id = m.book_id
  WHERE ( SELECT is_network_member.is_member
           FROM is_network_member) OR (EXISTS ( SELECT 1
           FROM book_holdings h2
             JOIN libraries l2 ON l2.id = h2.library_id
          WHERE h2.book_id = m.book_id AND l2.is_active = true AND l2.visibility_level = 'public'::text));

-- ---------------------------------------------------------------------------
-- DO block de verification fail-fast
-- ---------------------------------------------------------------------------
DO $verif$
DECLARE
  v_count int;
  v_mv_rows int;
BEGIN
  -- a. network_overview existe et filtre isolated
  SELECT count(*) INTO v_count
    FROM pg_views WHERE schemaname = 'api' AND viewname = 'network_overview'
      AND definition LIKE '%network_mode <> ''isolated''%';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a : network_overview ne filtre pas isolated';
  END IF;

  -- b. MV existe et filtre catalog_mode
  SELECT count(*) INTO v_count
    FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'mv_books_catalog_list_network_v1'
      AND definition LIKE '%catalog_mode = ''network_published''%';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_b : MV ne filtre pas catalog_mode';
  END IF;

  -- c. 12 index sur la MV
  SELECT count(*) INTO v_count FROM pg_indexes
   WHERE schemaname = 'public' AND tablename = 'mv_books_catalog_list_network_v1';
  IF v_count <> 12 THEN
    RAISE EXCEPTION 'VERIF_FAIL_c : %/12 index recrees sur la MV', v_count;
  END IF;

  -- d. Vue dependante recreee
  SELECT count(*) INTO v_count
    FROM pg_views WHERE schemaname = 'api' AND viewname = 'catalog_list_session_v1';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_d : api.catalog_list_session_v1 absente apres recreation';
  END IF;

  RAISE NOTICE 'Paquet C.5 — Verification OK : network_overview + MV + vue dependante patchees';
END
$verif$;

COMMIT;

-- ============================================================================
-- Apres COMMIT : REFRESH initial de la MV pour qu'elle contienne des donnees
-- (CREATE MATERIALIZED VIEW WITH DATA est le defaut, donc deja peuplee, mais
-- on rafraichit explicitement pour valider).
-- ============================================================================
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;
