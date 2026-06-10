-- ════════════════════════════════════════════════════════════════════════════
-- Fix fuite de visibilité : la vue catalogue ANON exposait le réseau entier
-- Auteur  : Claude (Opus)
-- Session : Enrichissement données & backlog
-- Date    : 2026-06-10 (UTC)
--
-- PROBLÈME : api.catalog_list_anon_v1 (vue servie aux visiteurs NON connectés,
-- cf. CatalogPage.jsx : viewName = isAuth ? session : anon) lisait
-- mv_books_catalog_list_network_v1 (réseau complet, 2675 livres). Conséquence :
-- les livres de la BTL (Biblioteca Terra Livre), en visibility_level='network'
-- — donc réservée aux membres connectés (fn_library_visible_to_caller la cache
-- à l'anon, et le dropdown l'exclut) — étaient malgré tout AFFICHÉS au public.
--
-- Cette fuite avait été introduite le 2026-06-08 par
-- 20260608161818_fix_catalog_anon_view_source.sql, qui basculait la vue anon
-- sur la MV réseau pour aligner facettes et liste. Mais facettes
-- (api.catalog_facets_v1), similar_books et similar_authors lisent TOUTES
-- catalog_list_anon_v1 : les repointer ensemble sur la MV publique rétablit la
-- cohérence facettes/liste SANS exposer le réseau. La recherche
-- (api.search_catalog_v1) était déjà correcte (anon → MV publique, membre →
-- réseau via un filtre v_is_member).
--
-- FIX : repointer la vue anon sur mv_books_catalog_list_v1 (filtrée
-- visibility_level='public' → BLMF + MLEG uniquement). Colonnes identiques
-- entre les deux MV. Le catalogue public passe de 2675 à ~501 livres ; la BTL
-- redevient invisible aux visiteurs non connectés, conformément à son mode.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW api.catalog_list_anon_v1 WITH (security_invoker = true) AS
  SELECT book_id, bib_ref, autor, titulo, ano, editora, cdd, loanable, available_count,
         created_at, cover_object_path, subtitulo, edicao, local_publicacao, isbn, issn,
         idioma, tipo_material, colecao, assuntos, author_id, catalog_source, library_id,
         library_slug, library_name, biblioteca, has_online_reading, author_display,
         author_chips, exemplares_total, bibliotecas_count, global_available_count,
         global_exemplares_total, holding_library_names_json
    FROM mv_books_catalog_list_v1          -- ← fix : MV publique (was network_v1)
   WHERE COALESCE(exemplares_total, 0) > 0;
