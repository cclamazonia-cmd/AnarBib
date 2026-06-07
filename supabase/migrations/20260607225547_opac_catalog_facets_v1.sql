-- ════════════════════════════════════════════════════════════════════════════
-- OPAC — RPC d'agrégation de facettes (catalogue de découverte)
-- Auteur  : Claude (Opus)
-- Session : Chantier OPAC etape 1 (socle CDD)
-- Date    : 2026-06-07 (UTC)
-- Registre: OPAC-F1 (RPC facettes), OPAC-AXIS1 (axe CDD), DOC-PERIM-1 (cloisonnement)
--
-- api.catalog_facets_v1(p_filters jsonb) -> jsonb
--   Renvoie, en UN appel, les compteurs des facettes de découverte :
--     { "cdd":   [{code, count}],            -- division Dewey a 3 chiffres
--       "decade":[{decade, count}],          -- decennie (ano -> 19x0/20x0)
--       "author":[{label, author_id, count}] -- top 15 auteur*rices (>= 2 livres)
--     }
--   Semantique « expand » : chaque facette applique TOUS les filtres actifs
--   SAUF le sien (permet d'elargir, pas seulement de surcontraindre).
--
-- Cloisonnement (DOC-PERIM-1 / INV-1) : agrege sur la vue PUBLIQUE
--   api.catalog_list_anon_v1. Choix v1 assume : le perimetre anonyme est un
--   sous-ensemble du perimetre connecte (anon ⊆ session) -> ne sur-divulgue
--   JAMAIS rien a personne. A l'echelle actuelle (1 biblio) anon = session.
--   Une variante session (perimetre du lecteur) sera ajoutee si les perimetres
--   divergent (multi-biblio). Note : assuntos data-blocked -> pas de facette
--   sujets en v1 (OPAC-AXIS1).
--
-- SECURITY INVOKER : lit la vue avec les droits de l'appelant (la vue porte
--   deja son propre cloisonnement). search_path fige. EXECUTE retire a PUBLIC,
--   accorde a anon + authenticated (catalogue public).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION api.catalog_facets_v1(p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_catalog
AS $function$
WITH params AS (
  SELECT
    NULLIF(btrim(p_filters->>'q'), '')          AS q,
    NULLIF(btrim(p_filters->>'author_id'), '')  AS author_id,
    NULLIF(btrim(p_filters->>'alpha'), '')      AS alpha,
    NULLIF(btrim(p_filters->>'publisher'), '')  AS publisher,
    NULLIF(btrim(p_filters->>'year_from'), '')::int AS year_from,
    NULLIF(btrim(p_filters->>'year_to'), '')::int   AS year_to,
    NULLIF(btrim(p_filters->>'library'), '')    AS library,
    NULLIF(btrim(p_filters->>'cdd'), '')        AS cdd,
    NULLIF(btrim(p_filters->>'language'), '')   AS language,
    NULLIF(btrim(p_filters->>'material'), '')   AS material,
    NULLIF(btrim(p_filters->>'collection'), '') AS collection,
    NULLIF(btrim(p_filters->>'place'), '')      AS place
),
src AS (
  SELECT
    c.cdd, c.author_chips, c.ano,
    -- predicat commun : tous les filtres SAUF les 3 dimensions de facette
    (
      (p.q IS NULL OR (c.titulo ILIKE '%'||p.q||'%' OR c.autor ILIKE '%'||p.q||'%'
        OR c.editora ILIKE '%'||p.q||'%' OR c.bib_ref ILIKE '%'||p.q||'%'
        OR c.cdd ILIKE '%'||p.q||'%' OR c.assuntos ILIKE '%'||p.q||'%'
        OR c.subtitulo ILIKE '%'||p.q||'%' OR c.isbn ILIKE '%'||p.q||'%'))
      AND (p.publisher IS NULL OR c.editora ILIKE '%'||p.publisher||'%')
      AND (p.library IS NULL OR c.library_slug = p.library)
      AND (p.material IS NULL OR c.tipo_material = p.material)
      AND (p.language IS NULL OR c.idioma ILIKE '%'||p.language||'%')
      AND (p.collection IS NULL OR c.colecao ILIKE '%'||p.collection||'%')
      AND (p.place IS NULL OR c.local_publicacao ILIKE '%'||p.place||'%')
    ) AS pc,
    -- predicat auteur (exclu de la facette auteur)
    ( (p.author_id IS NULL OR c.author_id::text = p.author_id)
      AND (p.alpha IS NULL OR c.autor ILIKE p.alpha||'%') ) AS pa,
    -- predicat annee (exclu de la facette decennie)
    ( (p.year_from IS NULL OR (c.ano ~ '^\d{4}$' AND c.ano::int >= p.year_from))
      AND (p.year_to IS NULL OR (c.ano ~ '^\d{4}$' AND c.ano::int <= p.year_to)) ) AS py,
    -- predicat cdd (exclu de la facette cdd)
    ( p.cdd IS NULL OR c.cdd ILIKE p.cdd||'%' ) AS pcd
  FROM api.catalog_list_anon_v1 c CROSS JOIN params p
)
SELECT jsonb_build_object(
  'cdd', COALESCE((SELECT jsonb_agg(x) FROM (
      SELECT left(cdd, 3) AS code, count(*)::int AS count
      FROM src
      WHERE pc AND pa AND py AND cdd IS NOT NULL AND btrim(cdd) <> ''
      GROUP BY left(cdd, 3) ORDER BY 2 DESC, 1 LIMIT 40) x), '[]'::jsonb),
  'decade', COALESCE((SELECT jsonb_agg(x) FROM (
      SELECT (left(ano, 3)||'0') AS decade, count(*)::int AS count
      FROM src
      WHERE pc AND pa AND pcd AND ano ~ '^\d{4}$'
      GROUP BY left(ano, 3) ORDER BY 1 DESC LIMIT 30) x), '[]'::jsonb),
  'author', COALESCE((SELECT jsonb_agg(x) FROM (
      SELECT ch->>'label' AS label, max(ch->>'author_id') AS author_id, count(*)::int AS count
      FROM src, jsonb_array_elements(
             CASE jsonb_typeof(author_chips) WHEN 'array' THEN author_chips ELSE '[]'::jsonb END
           ) ch
      WHERE pc AND pcd AND py AND ch->>'label' IS NOT NULL
      GROUP BY ch->>'label' HAVING count(*) >= 2 ORDER BY 3 DESC, 1 LIMIT 15) x), '[]'::jsonb)
);
$function$;

-- Doctrine : pas d'EXECUTE par PUBLIC ; catalogue public -> anon + authenticated.
REVOKE EXECUTE ON FUNCTION api.catalog_facets_v1(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.catalog_facets_v1(jsonb) TO anon, authenticated;
