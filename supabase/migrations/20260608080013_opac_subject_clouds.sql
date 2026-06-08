-- ════════════════════════════════════════════════════════════════════════════
-- OPAC étape 2 — Autorité matière — Paquet 3 : nuages de sujets (#OPAC8 / #AUT2)
-- Auteur  : Claude (Opus)
-- Session : Etape 2 autorite matiere (P3 nuages)
-- Date    : 2026-06-08 (UTC)
-- Registre: OPAC-AGG1 (agregation mutualisee), OPAC-ATL1
--
-- Mutualisation (D4) :
--  - api.catalog_facets_v1 renvoie desormais aussi 'subjects' (agrege
--    book_subjects sur le perimetre filtre courant ; semantique « expand » :
--    le nuage exclut son propre filtre 'subject') + accepte un filtre 'subject'
--    (slug) qui restreint les AUTRES facettes (CDD/auteur/decennie).
--  - api.author_subjects_v1(author_id) : nuage de sujets de la bibliographie.
--
-- Note : book_subjects se remplit au catalogage (P2) ; les nuages sont donc
-- vides au depart et se peuplent a l'usage.
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
    NULLIF(btrim(p_filters->>'place'), '')      AS place,
    NULLIF(btrim(p_filters->>'subject'), '')    AS subject
),
src AS (
  SELECT
    c.book_id, c.cdd, c.author_chips, c.ano,
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
    ( (p.author_id IS NULL OR c.author_id::text = p.author_id)
      AND (p.alpha IS NULL OR c.autor ILIKE p.alpha||'%') ) AS pa,
    ( (p.year_from IS NULL OR (c.ano ~ '^\d{4}$' AND c.ano::int >= p.year_from))
      AND (p.year_to IS NULL OR (c.ano ~ '^\d{4}$' AND c.ano::int <= p.year_to)) ) AS py,
    ( p.cdd IS NULL OR c.cdd ILIKE p.cdd||'%' ) AS pcd,
    -- predicat sujet (exclu de la facette sujets)
    ( p.subject IS NULL OR EXISTS (
        SELECT 1 FROM public.book_subjects bs JOIN public.subjects s ON s.id = bs.subject_id
        WHERE bs.book_id = c.book_id AND s.slug = p.subject) ) AS psub
  FROM api.catalog_list_anon_v1 c CROSS JOIN params p
)
SELECT jsonb_build_object(
  'cdd', COALESCE((SELECT jsonb_agg(x) FROM (
      SELECT left(cdd, 3) AS code, count(*)::int AS count
      FROM src WHERE pc AND pa AND py AND psub AND cdd IS NOT NULL AND btrim(cdd) <> ''
      GROUP BY left(cdd, 3) ORDER BY 2 DESC, 1 LIMIT 40) x), '[]'::jsonb),
  'decade', COALESCE((SELECT jsonb_agg(x) FROM (
      SELECT (left(ano, 3)||'0') AS decade, count(*)::int AS count
      FROM src WHERE pc AND pa AND pcd AND psub AND ano ~ '^\d{4}$'
      GROUP BY left(ano, 3) ORDER BY 1 DESC LIMIT 30) x), '[]'::jsonb),
  'author', COALESCE((SELECT jsonb_agg(x) FROM (
      SELECT ch->>'label' AS label, max(ch->>'author_id') AS author_id, count(*)::int AS count
      FROM src, jsonb_array_elements(
             CASE jsonb_typeof(author_chips) WHEN 'array' THEN author_chips ELSE '[]'::jsonb END) ch
      WHERE pc AND pcd AND py AND psub AND ch->>'label' IS NOT NULL
      GROUP BY ch->>'label' HAVING count(*) >= 2 ORDER BY 3 DESC, 1 LIMIT 15) x), '[]'::jsonb),
  'subjects', COALESCE((SELECT jsonb_agg(x) FROM (
      SELECT s.id AS subject_id, s.slug, s.label_i18n, count(*)::int AS count
      FROM src
      JOIN public.book_subjects bs ON bs.book_id = src.book_id
      JOIN public.subjects s ON s.id = bs.subject_id
      WHERE src.pc AND src.pa AND src.py AND src.pcd   -- exclut psub (expand)
      GROUP BY s.id, s.slug, s.label_i18n
      ORDER BY count(*) DESC, (s.label_i18n->>'pt-BR') LIMIT 20) x), '[]'::jsonb)
);
$function$;

-- ── #AUT2 — nuage de sujets de la bibliographie d'une autorite ──────────────
CREATE OR REPLACE FUNCTION api.author_subjects_v1(p_author_id bigint)
RETURNS TABLE (subject_id bigint, slug text, label_i18n jsonb, count integer)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_catalog
AS $function$
  SELECT s.id, s.slug, s.label_i18n, count(*)::int
  FROM public.author_books_public abp
  JOIN public.book_subjects bs ON bs.book_id = abp.book_id
  JOIN public.subjects s ON s.id = bs.subject_id
  WHERE abp.author_id = p_author_id
  GROUP BY s.id, s.slug, s.label_i18n
  ORDER BY count(*) DESC, (s.label_i18n->>'pt-BR')
  LIMIT 20;
$function$;
REVOKE EXECUTE ON FUNCTION api.author_subjects_v1(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.author_subjects_v1(bigint) TO anon, authenticated;
