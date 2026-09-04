-- =====================================================================
-- AnarBib -- L'OPAC se lit par oeuvre (lot 2, OPAC par oeuvre)
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre  ·  decisions Xavier du 04/09
-- Depend  : 20260904130100 (fn_work_display_title, work_titles)
--
-- LE CONSTAT. La liste plate de l'OPAC montrait sept fois « Desobediencia
-- civil » sous des editions differentes, et chaque bibliotheque entrante
-- ajoute les siennes. Le bouton « Regrouper les editions » du lot C repliait
-- cote client les 100 lignes chargees : une oeuvre a cheval sur deux pages
-- apparaissait deux fois, et le tri restait celui des editions.
--
-- LA DECISION (1 du 04/09) : regroupement par oeuvre ACTIF par defaut, bouton
-- pour revenir a la liste plate. Donc regroupement COTE SERVEUR :
--
--   api.catalog_works_v1(p_filters, p_sort, p_offset, p_limit, p_lang)
--     Les memes filtres que la liste plate (cf. src/lib/catalogFilters.js et
--     api.catalog_facets_v1), la recherche libre par api.catalog_search_ids_v1
--     (accents replies, pertinence), puis UNE ligne par oeuvre : titre affiche
--     dans la locale de la lectrice (fn_work_display_title), nombre d'editions,
--     bornes d'annees, disponibilite agregee, et les editions completes
--     (memes colonnes que la vue, pour que la ligne d'edition du front reste
--     celle d'aujourd'hui). Une notice sans oeuvre forme son propre groupe.
--     Tri au niveau oeuvre ; pagination au niveau oeuvre ; total = oeuvres.
--     Vue anon ou session selon auth.uid() -- deux branches UNION ALL sous un
--     filtre constant, le planificateur n'en parcourt qu'une (one-time filter).
--
--   api.book_copies_by_library_v1(p_book_id)
--     Le second « + » : les exemplaires d'une edition, bibliotheque par
--     bibliotheque, avec la disponibilite. Doctrine A1/A2/A3 conservee cote
--     serveur : pour un visiteur non connecte, ni compte disponible ni
--     pretabilite -- seulement le nombre d'exemplaires et la bibliotheque.
--
-- Fonctions SECURITY INVOKER (elles lisent des vues security_invoker qui
-- portent deja la visibilite), accordees a anon et authenticated comme
-- catalog_facets_v1. Idempotent.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION api.catalog_works_v1(
  p_filters jsonb DEFAULT '{}'::jsonb,
  p_sort    text  DEFAULT 'relevance',
  p_offset  integer DEFAULT 0,
  p_limit   integer DEFAULT 50,
  p_lang    text  DEFAULT 'pt-BR')
RETURNS jsonb
LANGUAGE sql STABLE
SET search_path = public, pg_catalog
AS $$
WITH params AS (
  SELECT
    NULLIF(btrim(p_filters->>'q'), '')          AS q,
    NULLIF(btrim(p_filters->>'author'), '')     AS author,
    NULLIF(btrim(p_filters->>'author_id'), '')  AS author_id,
    NULLIF(btrim(p_filters->>'alpha'), '')      AS alpha,
    NULLIF(btrim(p_filters->>'publisher'), '')  AS publisher,
    NULLIF(btrim(p_filters->>'year'), '')       AS year_exact,
    NULLIF(btrim(p_filters->>'year_from'), '')::int AS year_from,
    NULLIF(btrim(p_filters->>'year_to'), '')::int   AS year_to,
    COALESCE((SELECT array_agg(x) FROM jsonb_array_elements_text(
       CASE WHEN jsonb_typeof(p_filters->'libraries') = 'array' THEN p_filters->'libraries' ELSE '[]'::jsonb END) x),
       '{}'::text[])                             AS libraries,
    NULLIF(btrim(p_filters->>'isbn'), '')       AS isbn,
    NULLIF(btrim(p_filters->>'language'), '')   AS language,
    NULLIF(btrim(p_filters->>'cdd'), '')        AS cdd,
    NULLIF(btrim(p_filters->>'subjects'), '')   AS subjects_text,
    NULLIF(btrim(p_filters->>'material'), '')   AS material,
    NULLIF(btrim(p_filters->>'collection'), '') AS collection,
    NULLIF(btrim(p_filters->>'place'), '')      AS place,
    NULLIF(btrim(p_filters->>'subject'), '')    AS subject,
    NULLIF(btrim(p_filters->>'availability'), '') AS availability,
    (auth.uid() IS NOT NULL)                    AS is_auth,
    COALESCE(NULLIF(btrim(p_lang), ''), 'pt-BR') AS lang,
    COALESCE(NULLIF(btrim(p_sort), ''), 'relevance') AS sort,
    GREATEST(COALESCE(p_offset, 0), 0)          AS off,
    LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200) AS lim
),
-- Recherche libre : accents replies, tous les termes requis, pertinence (<= 500 notices).
ranked AS (
  SELECT s.book_id, row_number() OVER (ORDER BY s.rank DESC NULLS LAST, s.book_id) AS pos
  FROM params p, LATERAL api.catalog_search_ids_v1(p.q) s
  WHERE p.q IS NOT NULL
),
-- La vue de la lectrice : anon ou session. Un seul des deux SELECT s'execute.
src AS (
  SELECT c.book_id, c.work_id, c.titulo, c.autor, c.author_id, c.ano, c.editora, c.created_at, c.bib_ref,
         c.global_available_count, c.holding_library_names_json, c.idioma, c.cdd, c.assuntos, c.isbn,
         c.tipo_material, c.colecao, c.local_publicacao, c.cover_object_path,
         NULL::text AS session_status_hint, NULL::integer AS session_available_count, NULL::boolean AS session_has_holding,
         to_jsonb(c) AS row_json
  FROM api.catalog_list_anon_v1 c
  WHERE auth.uid() IS NULL
  UNION ALL
  SELECT c.book_id, c.work_id, c.titulo, c.autor, c.author_id, c.ano, c.editora, c.created_at, c.bib_ref,
         c.global_available_count, c.holding_library_names_json, c.idioma, c.cdd, c.assuntos, c.isbn,
         c.tipo_material, c.colecao, c.local_publicacao, c.cover_object_path,
         c.session_status_hint, c.session_available_count, c.session_has_holding,
         to_jsonb(c) AS row_json
  FROM api.catalog_list_session_v1 c
  WHERE auth.uid() IS NOT NULL
),
filtered AS (
  SELECT s.*, r.pos, COALESCE(s.work_id, -s.book_id) AS gkey
  FROM src s
  CROSS JOIN params p
  LEFT JOIN ranked r ON r.book_id = s.book_id
  WHERE (p.q IS NULL OR r.book_id IS NOT NULL)
    AND (CASE WHEN p.alpha IS NOT NULL     THEN s.autor ILIKE p.alpha || '%'
              WHEN p.author_id IS NOT NULL THEN s.author_id::text = p.author_id
              WHEN p.author IS NOT NULL    THEN s.autor ILIKE '%' || p.author || '%'
              ELSE true END)
    AND (p.publisher IS NULL OR s.editora ILIKE '%' || p.publisher || '%')
    AND (p.year_exact IS NULL OR s.ano = p.year_exact)
    AND (p.year_from IS NULL OR (s.ano ~ '^\d{4}$' AND s.ano::int >= p.year_from))
    AND (p.year_to IS NULL   OR (s.ano ~ '^\d{4}$' AND s.ano::int <= p.year_to))
    AND (cardinality(p.libraries) = 0 OR EXISTS (
           SELECT 1 FROM jsonb_array_elements_text(
             CASE WHEN jsonb_typeof(s.holding_library_names_json) = 'array' THEN s.holding_library_names_json ELSE '[]'::jsonb END) n
           WHERE n = ANY (p.libraries)))
    AND (p.isbn IS NULL OR s.isbn ILIKE '%' || p.isbn || '%')
    AND (p.language IS NULL OR CASE WHEN p.language ~ '^[a-z]{2}(-[A-Z]{2})?$'
                                    THEN s.idioma = p.language
                                    ELSE s.idioma ILIKE '%' || p.language || '%' END)
    AND (p.cdd IS NULL OR s.cdd ILIKE p.cdd || '%')
    AND (p.subjects_text IS NULL OR s.assuntos ILIKE '%' || p.subjects_text || '%')
    AND (p.material IS NULL OR s.tipo_material = p.material)
    AND (p.collection IS NULL OR s.colecao ILIKE '%' || p.collection || '%')
    AND (p.place IS NULL OR s.local_publicacao ILIKE '%' || p.place || '%')
    AND (p.subject IS NULL OR EXISTS (
           SELECT 1 FROM public.book_subjects bs JOIN public.subjects sj ON sj.id = bs.subject_id
           WHERE bs.book_id = s.book_id AND sj.slug = p.subject))
    -- Doctrine A1/A2/A3 : aucun critere de disponibilite pour l'anon.
    AND (NOT p.is_auth OR p.availability IS NULL OR CASE p.availability
           WHEN 'available'        THEN s.session_status_hint = 'no_acervo_da_sua_biblioteca' AND COALESCE(s.session_available_count, 0) > 0
           WHEN 'consult'          THEN s.session_status_hint = 'consultavel_no_local'
           WHEN 'unavailable_user' THEN s.session_status_hint = 'indisponivel_para_voce'
           WHEN 'unavailable_now'  THEN s.session_status_hint = 'no_acervo_da_sua_biblioteca' AND COALESCE(s.session_available_count, 0) = 0
           WHEN 'unavailable_other' THEN s.session_has_holding IS FALSE
           WHEN 'check'            THEN COALESCE(s.session_status_hint, 'sem_biblioteca_de_sessao') = 'sem_biblioteca_de_sessao'
           ELSE true END)
),
groups AS (
  SELECT f.gkey,
         max(f.work_id)                                   AS work_id,
         count(*)::int                                    AS edition_count,
         min(f.pos)                                       AS best_pos,
         min(NULLIF(substring(f.ano FROM '\d{4}'), '')::int) AS year_min,
         max(NULLIF(substring(f.ano FROM '\d{4}'), '')::int) AS year_max,
         max(f.created_at)                                AS newest,
         bool_or(COALESCE(f.global_available_count, 0) > 0) AS any_available,
         bool_or(f.session_status_hint = 'no_acervo_da_sua_biblioteca' AND COALESCE(f.session_available_count, 0) > 0) AS session_available,
         bool_or(f.session_status_hint IN ('no_acervo_da_sua_biblioteca', 'consultavel_no_local')) AS session_holding,
         (array_agg(f.book_id ORDER BY f.pos NULLS LAST,
                    NULLIF(substring(f.ano FROM '\d{4}'), '')::int DESC NULLS LAST, f.book_id))[1] AS rep_book_id
  FROM filtered f
  GROUP BY f.gkey
),
titled AS (
  SELECT g.*,
         CASE WHEN g.work_id IS NULL THEN f.titulo
              ELSE public.fn_work_display_title(g.work_id, (SELECT lang FROM params)) END AS display_title,
         f.autor AS rep_autor, f.editora AS rep_editora, f.bib_ref AS rep_bib_ref
  FROM groups g
  JOIN filtered f ON f.book_id = g.rep_book_id
),
ordered AS (
  SELECT t.*, count(*) OVER () AS total,
         row_number() OVER (ORDER BY
           CASE WHEN p.sort = 'relevance' AND p.q IS NOT NULL THEN t.best_pos END ASC NULLS LAST,
           CASE WHEN p.sort = 'status' THEN (CASE WHEN t.session_available THEN 0 WHEN t.session_holding THEN 1 WHEN t.any_available THEN 2 ELSE 3 END) END ASC,
           CASE WHEN p.sort = 'ano.desc'        THEN t.year_max END DESC NULLS LAST,
           CASE WHEN p.sort = 'created_at.desc' THEN t.newest   END DESC NULLS LAST,
           CASE WHEN p.sort = 'autor.asc'       THEN t.rep_autor   END ASC NULLS LAST,
           CASE WHEN p.sort = 'editora.asc'     THEN t.rep_editora END ASC NULLS LAST,
           CASE WHEN p.sort = 'bib_ref.asc'     THEN t.rep_bib_ref END ASC NULLS LAST,
           t.display_title ASC, t.gkey) AS ord
  FROM titled t CROSS JOIN params p
),
page AS (
  SELECT o.* FROM ordered o CROSS JOIN params p
  WHERE o.ord > p.off AND o.ord <= p.off + p.lim
),
page_editions AS (
  SELECT f.gkey,
         jsonb_agg(f.row_json || jsonb_build_object('_pos', f.pos)
                   ORDER BY NULLIF(substring(f.ano FROM '\d{4}'), '')::int DESC NULLS LAST, f.book_id) AS editions,
         (SELECT jsonb_agg(DISTINCT n ORDER BY n) FROM filtered f2,
            jsonb_array_elements_text(CASE WHEN jsonb_typeof(f2.holding_library_names_json) = 'array' THEN f2.holding_library_names_json ELSE '[]'::jsonb END) n
           WHERE f2.gkey = f.gkey) AS library_names
  FROM filtered f
  WHERE f.gkey IN (SELECT gkey FROM page)
  GROUP BY f.gkey
)
SELECT jsonb_build_object(
  'total',  COALESCE((SELECT max(total) FROM page), 0),
  'offset', (SELECT off FROM params),
  'limit',  (SELECT lim FROM params),
  'works',  COALESCE((
     SELECT jsonb_agg(jsonb_build_object(
              'key',           pg.gkey,
              'work_id',       pg.work_id,
              'display_title', pg.display_title,
              'edition_count', pg.edition_count,
              'year_min',      pg.year_min,
              'year_max',      pg.year_max,
              'rep_book_id',   pg.rep_book_id,
              'any_available', pg.any_available,
              'session_available', pg.session_available,
              'library_names', COALESCE(pe.library_names, '[]'::jsonb),
              'editions',      COALESCE(pe.editions, '[]'::jsonb))
            ORDER BY pg.ord)
     FROM page pg LEFT JOIN page_editions pe ON pe.gkey = pg.gkey), '[]'::jsonb)
);
$$;
COMMENT ON FUNCTION api.catalog_works_v1(jsonb, text, integer, integer, text) IS
  'OPAC par oeuvre : memes filtres que la liste plate, une ligne par oeuvre (titre dans la locale, editions '
  'imbriquees), tri et pagination au niveau oeuvre. Vue anon ou session selon auth.uid(). Lot 2, 04/09/2026.';
GRANT EXECUTE ON FUNCTION api.catalog_works_v1(jsonb, text, integer, integer, text) TO anon, authenticated;

-- ---------------------------------------------------------------------
-- Les exemplaires d'une edition, bibliotheque par bibliotheque
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.book_copies_by_library_v1(p_book_id bigint)
RETURNS jsonb
LANGUAGE sql STABLE
SET search_path = public, pg_catalog
AS $$
  WITH sess AS (
    SELECT c.session_library_slug, c.session_status_hint, c.session_available_count
    FROM api.catalog_list_session_v1 c
    WHERE auth.uid() IS NOT NULL AND c.book_id = p_book_id
    LIMIT 1
  )
  SELECT jsonb_build_object(
    'book_id', p_book_id,
    'is_auth', (auth.uid() IS NOT NULL),
    'libraries', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'library_slug',     h->>'library_slug',
               'short_name',       h->>'short_name',
               'library_name',     h->>'library_name',
               'city',             h->>'city',
               'local_bib_ref',    h->>'local_bib_ref',
               'exemplares_total', (h->>'exemplares_total')::int,
               -- Doctrine A1/A2/A3 : rien de plus pour un visiteur non connecte.
               'available_count',  CASE WHEN auth.uid() IS NULL THEN NULL ELSE (h->>'available_count')::int END,
               'loanable',         CASE WHEN auth.uid() IS NULL THEN NULL ELSE (h->>'loanable')::boolean END,
               'earliest_due_back_at', CASE WHEN auth.uid() IS NULL THEN NULL ELSE h->'earliest_due_back_at' END,
               'is_session_library', (s.session_library_slug IS NOT NULL AND s.session_library_slug = (h->>'library_slug')),
               'session_status_hint', CASE WHEN s.session_library_slug = (h->>'library_slug') THEN s.session_status_hint END,
               'session_available_count', CASE WHEN s.session_library_slug = (h->>'library_slug') THEN s.session_available_count END)
             ORDER BY h->>'library_name')
      FROM public.v_book_detail_public_v2 d
      CROSS JOIN LATERAL jsonb_array_elements(
        CASE WHEN jsonb_typeof(d.holding_libraries_json) = 'array' THEN d.holding_libraries_json ELSE '[]'::jsonb END) h
      LEFT JOIN sess s ON true
      WHERE d.book_id = p_book_id), '[]'::jsonb)
  );
$$;
COMMENT ON FUNCTION api.book_copies_by_library_v1(bigint) IS
  'Exemplaires d''une edition par bibliotheque, avec disponibilite pour une lectrice connectee ; '
  'un visiteur non connecte ne voit que le nombre d''exemplaires (doctrine A1/A2/A3). Lot 2, 04/09/2026.';
GRANT EXECUTE ON FUNCTION api.book_copies_by_library_v1(bigint) TO anon, authenticated;

DO $$
BEGIN
  IF NOT has_function_privilege('anon', 'api.catalog_works_v1(jsonb,text,integer,integer,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou : catalog_works_v1 doit rester publique (OPAC)';
  END IF;
  IF NOT has_function_privilege('anon', 'api.book_copies_by_library_v1(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou : book_copies_by_library_v1 doit rester publique (OPAC)';
  END IF;
END $$;

COMMIT;
