-- ════════════════════════════════════════════════════════════════════════════
-- Fix : la vue catalogue public pointe vers la MV réseau (pas mono-biblio)
-- Auteur  : Claude (Opus)
-- Session : Nettoyage BTL & maintenance
-- Date    : 2026-06-08 16:18 UTC
--
-- Constat : api.catalog_list_anon_v1 lisait mv_books_catalog_list_v1
-- (237 livres, mono-bibliothèque) au lieu de mv_books_catalog_list_network_v1
-- (2412 livres, réseau complet). Conséquence : les facettes du catalogue
-- (auteurs, CDD, décennies, sujets) affichaient des compteurs basés sur un
-- sous-ensemble de 237 livres, alors que la liste de résultats montrait
-- le réseau entier → incohérence visible (ex. "RECLUS, Élisée 5" dans le
-- chip auteur mais 52 résultats affichés).
--
-- Fix : pointer la vue vers la MV réseau. Les colonnes sont identiques.
-- Le filtre exemplares_total > 0 est conservé.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW api.catalog_list_anon_v1 WITH (security_invoker = true) AS
  SELECT book_id, bib_ref, autor, titulo, ano, editora, cdd, loanable, available_count,
         created_at, cover_object_path, subtitulo, edicao, local_publicacao, isbn, issn,
         idioma, tipo_material, colecao, assuntos, author_id, catalog_source, library_id,
         library_slug, library_name, biblioteca, has_online_reading, author_display,
         author_chips, exemplares_total, bibliotecas_count, global_available_count,
         global_exemplares_total, holding_library_names_json
    FROM mv_books_catalog_list_network_v1          -- ← was: mv_books_catalog_list_v1
   WHERE COALESCE(exemplares_total, 0) > 0;
