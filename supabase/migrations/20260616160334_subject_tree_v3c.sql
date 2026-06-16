-- ============================================================================
-- Thésaurus v3-C : navigation hiérarchique OPAC — vue arbre des sujets
-- ----------------------------------------------------------------------------
-- Auteur  : AnarBib
-- Session : Fédération — Communs & Entraide
-- Date    : 2026-06-16 (UTC)
--
-- Expose l'arbre des sujets ativo (id, slug, label_i18n, parent_id, notation)
-- avec un COMPTE DE LIVRES public par sujet. Le compte est calculé sur
-- api.catalog_list_anon_v1 (la vue catalogue déjà filtrée à la visibilité
-- publique — même source que les facettes catalog_facets_v1) : aucun risque de
-- fuite des livres réseau BTL (visibility_level='network').
--
-- SECURITY INVOKER (défaut) comme catalog_facets_v1 : anon lit déjà
-- catalog_list_anon_v1 + subjects + book_subjects. Lecture publique.
-- La hiérarchie broader/narrower est portée par subjects.parent_id ; le
-- frontend reconstruit l'arbre. Le rattachement associatif « voir aussi »
-- (skos:related) est porté par la v3-A (api.subject_related_v1).
-- ============================================================================

CREATE OR REPLACE FUNCTION api.subject_tree_v1()
RETURNS TABLE(id bigint, slug text, label_i18n jsonb, parent_id bigint, notation text, book_count int)
LANGUAGE sql STABLE SET search_path TO 'public','pg_catalog'
AS $function$
  SELECT s.id, s.slug, s.label_i18n, s.parent_id, s.notation,
         COALESCE(bc.cnt, 0)::int AS book_count
  FROM public.subjects s
  LEFT JOIN (
    SELECT bs.subject_id, count(DISTINCT c.book_id) AS cnt
    FROM api.catalog_list_anon_v1 c
    JOIN public.book_subjects bs ON bs.book_id = c.book_id
    GROUP BY bs.subject_id
  ) bc ON bc.subject_id = s.id
  WHERE s.status = 'ativo'
  ORDER BY (s.label_i18n->>'pt-BR');
$function$;

REVOKE EXECUTE ON FUNCTION api.subject_tree_v1() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.subject_tree_v1() TO anon, authenticated;
