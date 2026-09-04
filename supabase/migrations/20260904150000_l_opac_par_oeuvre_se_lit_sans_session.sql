-- =====================================================================
-- AnarBib -- L'OPAC par oeuvre se lit sans session (correctif du lot 2)
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre
-- Depend  : 20260904130200
--
-- CE QUE LA PROD A MONTRE, DIX MINUTES APRES LE DEPLOIEMENT. Un visiteur non
-- connecte recevait « permission denied for view catalog_list_session_v1 »
-- (42501) et l'OPAC retombait sur le repli client. Les deux fonctions
-- ecrivaient les deux vues dans une meme requete (UNION ALL sous un filtre
-- constant) : le planificateur n'en PARCOURT qu'une, mais Postgres verifie le
-- droit de lecture de TOUTES les relations d'une requete a la planification.
-- Le banc et l'essai en prod tournaient en superuser : ils ne pouvaient pas
-- le voir. La suite opac_par_oeuvre_tests gagne un T8 sous SET LOCAL ROLE anon.
--
-- LA CORRECTION : plpgsql. Pour catalog_works_v1, la requete est un texte
-- dans lequel on substitue le nom de la vue et les colonnes de session avant
-- EXECUTE : seule la vue de la lectrice est nommee, donc verifiee. Pour
-- book_copies_by_library_v1, la lecture de la vue de session est dans une
-- branche IF que l'anon n'atteint jamais (plpgsql planifie une instruction
-- quand il l'execute). Memes signatures, memes resultats, memes grants.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION api.catalog_works_v1(
  p_filters jsonb DEFAULT '{}'::jsonb,
  p_sort    text  DEFAULT 'relevance',
  p_offset  integer DEFAULT 0,
  p_limit   integer DEFAULT 50,
  p_lang    text  DEFAULT 'pt-BR')
RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path = public, pg_catalog
AS $fn$
DECLARE
  v_auth boolean := (auth.uid() IS NOT NULL);
  v_view text;
  v_sess text;
  v_sql  text;
  v_out  jsonb;
BEGIN
  v_view := CASE WHEN v_auth THEN 'api.catalog_list_session_v1' ELSE 'api.catalog_list_anon_v1' END;
  v_sess := CASE WHEN v_auth
    THEN 'c.session_status_hint, c.session_available_count, c.session_has_holding'
    ELSE 'NULL::text AS session_status_hint, NULL::integer AS session_available_count, NULL::boolean AS session_has_holding' END;

  v_sql := $q$
WITH params AS (
  SELECT
    NULLIF(btrim($1->>'q'), '')          AS q,
    NULLIF(btrim($1->>'author'), '')     AS author,
    NULLIF(btrim($1->>'author_id'), '')  AS author_id,
    NULLIF(btrim($1->>'alpha'), '')      AS alpha,
    NULLIF(btrim($1->>'publisher'), '')  AS publisher,
    NULLIF(btrim($1->>'year'), '')       AS year_exact,
    NULLIF(btrim($1->>'year_from'), '')::int AS year_from,
    NULLIF(btrim($1->>'year_to'), '')::int   AS year_to,
    COALESCE((SELECT array_agg(x) FROM jsonb_array_elements_text(
       CASE WHEN jsonb_typeof($1->'libraries') = 'array' THEN $1->'libraries' ELSE '[]'::jsonb END) x),
       '{}'::text[])                      AS libraries,
    NULLIF(btrim($1->>'isbn'), '')       AS isbn,
    NULLIF(btrim($1->>'language'), '')   AS language,
    NULLIF(btrim($1->>'cdd'), '')        AS cdd,
    NULLIF(btrim($1->>'subjects'), '')   AS subjects_text,
    NULLIF(btrim($1->>'material'), '')   AS material,
    NULLIF(btrim($1->>'collection'), '') AS collection,
    NULLIF(btrim($1->>'place'), '')      AS place,
    NULLIF(btrim($1->>'subject'), '')    AS subject,
    NULLIF(btrim($1->>'availability'), '') AS availability,
    $6::boolean                          AS is_auth,
    COALESCE(NULLIF(btrim($5), ''), 'pt-BR') AS lang,
    COALESCE(NULLIF(btrim($2), ''), 'relevance') AS sort,
    GREATEST(COALESCE($3, 0), 0)         AS off,
    LEAST(GREATEST(COALESCE($4, 50), 1), 200) AS lim
),
ranked AS (
  SELECT s.book_id, row_number() OVER (ORDER BY s.rank DESC NULLS LAST, s.book_id) AS pos
  FROM params p, LATERAL api.catalog_search_ids_v1(p.q) s
  WHERE p.q IS NOT NULL
),
src AS (
  SELECT c.book_id, c.work_id, c.titulo, c.autor, c.author_id, c.ano, c.editora, c.created_at, c.bib_ref,
         c.global_available_count, c.holding_library_names_json, c.idioma, c.cdd, c.assuntos, c.isbn,
         c.tipo_material, c.colecao, c.local_publicacao, c.cover_object_path,
         __SESS__,
         to_jsonb(c) AS row_json
  FROM __VIEW__ c
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
)
$q$;
  v_sql := replace(replace(v_sql, '__VIEW__', v_view), '__SESS__', v_sess);
  EXECUTE v_sql INTO v_out USING p_filters, p_sort, p_offset, p_limit, p_lang, v_auth;
  RETURN v_out;
END;
$fn$;
GRANT EXECUTE ON FUNCTION api.catalog_works_v1(jsonb, text, integer, integer, text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION api.book_copies_by_library_v1(p_book_id bigint)
RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path = public, pg_catalog
AS $fn$
DECLARE
  v_auth boolean := (auth.uid() IS NOT NULL);
  v_slug text; v_hint text; v_avail integer;
  v_out jsonb;
BEGIN
  IF v_auth THEN
    -- Branche jamais atteinte par l'anon : la vue de session n'est verifiee que pour une lectrice.
    SELECT c.session_library_slug, c.session_status_hint, c.session_available_count
      INTO v_slug, v_hint, v_avail
      FROM api.catalog_list_session_v1 c
     WHERE c.book_id = p_book_id
     LIMIT 1;
  END IF;

  SELECT jsonb_build_object(
    'book_id', p_book_id,
    'is_auth', v_auth,
    'libraries', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'library_slug',     h->>'library_slug',
               'short_name',       h->>'short_name',
               'library_name',     h->>'library_name',
               'city',             h->>'city',
               'local_bib_ref',    h->>'local_bib_ref',
               'exemplares_total', (h->>'exemplares_total')::int,
               -- Doctrine A1/A2/A3 : rien de plus pour un visiteur non connecte.
               'available_count',  CASE WHEN v_auth THEN (h->>'available_count')::int END,
               'loanable',         CASE WHEN v_auth THEN (h->>'loanable')::boolean END,
               'earliest_due_back_at', CASE WHEN v_auth THEN h->'earliest_due_back_at' END,
               'is_session_library', (v_slug IS NOT NULL AND v_slug = (h->>'library_slug')),
               'session_status_hint', CASE WHEN v_slug = (h->>'library_slug') THEN v_hint END,
               'session_available_count', CASE WHEN v_slug = (h->>'library_slug') THEN v_avail END)
             ORDER BY h->>'library_name')
      FROM public.v_book_detail_public_v2 d
      CROSS JOIN LATERAL jsonb_array_elements(
        CASE WHEN jsonb_typeof(d.holding_libraries_json) = 'array' THEN d.holding_libraries_json ELSE '[]'::jsonb END) h
      WHERE d.book_id = p_book_id), '[]'::jsonb))
  INTO v_out;
  RETURN v_out;
END;
$fn$;
GRANT EXECUTE ON FUNCTION api.book_copies_by_library_v1(bigint) TO anon, authenticated;

DO $$
BEGIN
  IF NOT has_function_privilege('anon', 'api.catalog_works_v1(jsonb,text,integer,integer,text)', 'EXECUTE')
  OR NOT has_function_privilege('anon', 'api.book_copies_by_library_v1(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou : les deux RPC de l''OPAC par oeuvre doivent rester publiques';
  END IF;
END $$;

COMMIT;
