-- =====================================================================
-- AnarBib -- Les tomes vivent dans l'oeuvre (lot 4, OPAC par oeuvre)
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre  ·  decision 6 (Xavier, fin de journee)
-- Depend  : 20260904130000 (group_books_as_editions, fn_work_prune_if_empty),
--           20260904150000 (api.catalog_works_v1 dynamique)
--
-- LA REGLE. Un tome n'est pas une oeuvre : « Accion directa anarquista, tomo
-- III » est un volume de l'oeuvre-serie « Accion directa anarquista ». Le
-- 04/09 au matin, BTL avait mis quatre tomes dans une oeuvre et MLEG un tome
-- par oeuvre ; l'assistant de doublons les proposait comme doublons ou comme
-- oeuvres scindees sans jamais dire « ce sont des tomes ». Cent notices portent
-- un marqueur de volume dans leur titre, et books.volume n'avait jamais ete
-- rempli pour une monographie (le formulaire ne le montrait qu'aux periodiques).
--
-- CE QUE CE PAQUET POSE :
--   1. fn_volume_marker / fn_title_sans_volume / fn_volume_rank : lire un
--      marqueur de tome (vol. 2, Tomo III, volume 1, parte 2, t. IV…), le
--      retirer du titre, l'ordonner (romain ou arabe) ;
--   2. suggest_volume_groups : le balayage « meme auteur, meme titre sans le
--      marqueur, au moins un tome repere », hors periodiques, hors groupes
--      ecartes (volume_group_dismissals) ;
--   3. group_books_as_volumes : poser le numero de tome sur chaque notice et
--      les reunir dans une seule oeuvre (group_books_as_editions, qui supprime
--      les oeuvres quittees) ; dismiss_volume_group : « pas des tomes » ;
--   4. api.catalog_works_v1 : chaque edition porte son volume, les editions
--      d'une oeuvre se trient par tome, la ligne d'oeuvre compte ses volumes.
-- Fonctions DEFINER a garde staff, revoquees de PUBLIC/anon/authenticated puis
-- accordees a authenticated. Idempotent.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Lire un marqueur de tome
-- ---------------------------------------------------------------------
-- Rend le numero tel qu'ecrit ('III', '2'), ou NULL. Cherche dans le titre
-- puis le sous-titre. Les formes : vol. 2, volume 2, tomo III, tome 3,
-- t. IV, parte 2, livro 1, v. 2, et « volume 1 » colle a un deux-points.
CREATE OR REPLACE FUNCTION public.fn_volume_marker(p_text text)
RETURNS text
LANGUAGE sql IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT NULLIF(btrim(COALESCE(
    (regexp_match(COALESCE(p_text, ''), '\m(?:vol(?:ume)?|tomo|tome|parte|livro|t|v)\.?\s*[:\-]?\s*([0-9]{1,3}|[ivxlc]{1,6})\M', 'i'))[1],
    ''
  )), '');
$$;

-- Le titre sans son marqueur, normalise (accents replies, casse, ponctuation).
CREATE OR REPLACE FUNCTION public.fn_title_sans_volume(p_text text)
RETURNS text
LANGUAGE sql IMMUTABLE
SET search_path = public, pg_catalog
AS $$
  SELECT public.fn_normalize_name(
    regexp_replace(
      regexp_replace(COALESCE(p_text, ''), '\m(?:vol(?:ume)?|tomo|tome|parte|livro|t|v)\.?\s*[:\-]?\s*(?:[0-9]{1,3}|[ivxlc]{1,6})\M', ' ', 'gi'),
      '[\s:\-–—,.;]+$', '', 'g'));
$$;

-- Ordre d'un tome : 'III' -> 3, '2' -> 2, inconnu -> NULL.
CREATE OR REPLACE FUNCTION public.fn_volume_rank(p_vol text)
RETURNS integer
LANGUAGE plpgsql IMMUTABLE
SET search_path = pg_catalog
AS $$
DECLARE v text := upper(btrim(COALESCE(p_vol, ''))); i int; n int := 0; c char; val int; prev int := 0; m text;
BEGIN
  IF v = '' THEN RETURN NULL; END IF;
  m := (regexp_match(v, '^([0-9]{1,4})'))[1];
  IF m IS NOT NULL THEN RETURN m::int; END IF;
  IF v !~ '^[IVXLC]{1,7}$' THEN RETURN NULL; END IF;
  FOR i IN REVERSE length(v)..1 LOOP
    c := substr(v, i, 1);
    val := CASE c WHEN 'I' THEN 1 WHEN 'V' THEN 5 WHEN 'X' THEN 10 WHEN 'L' THEN 50 WHEN 'C' THEN 100 ELSE 0 END;
    IF val < prev THEN n := n - val; ELSE n := n + val; prev := val; END IF;
  END LOOP;
  RETURN n;
END;
$$;
GRANT EXECUTE ON FUNCTION public.fn_volume_marker(text), public.fn_title_sans_volume(text), public.fn_volume_rank(text) TO anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. La memoire des « pas des tomes », et le balayage
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.volume_group_dismissals (
  group_key   text PRIMARY KEY,
  reason      text,
  decided_by  uuid,
  decided_at  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.volume_group_dismissals IS
  'Groupes de notices ecartes par « ce ne sont pas des tomes d''une meme oeuvre » (cle = auteur + titre sans marqueur). Lot 4 OPAC par oeuvre.';
ALTER TABLE public.volume_group_dismissals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.volume_group_dismissals FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.volume_group_dismissals TO authenticated;
GRANT ALL    ON public.volume_group_dismissals TO service_role;
DROP POLICY IF EXISTS volume_group_dismissals_read_staff ON public.volume_group_dismissals;
CREATE POLICY volume_group_dismissals_read_staff ON public.volume_group_dismissals
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = (SELECT auth.uid()) AND m.role = ANY (ARRAY['librarian','coordenador']) AND m.status = 'active'));

-- Un groupe = meme auteur principal (premier autor lie, sinon la transcription
-- normalisee) + meme titre sans marqueur ; au moins deux notices ; au moins un
-- marqueur ou un volume deja pose ; pas de periodique. Une ligne par notice.
CREATE OR REPLACE FUNCTION public.suggest_volume_groups(p_max integer DEFAULT 200)
RETURNS TABLE(
  group_key text, author_name text, base_title text, members integer, works integer,
  book_id bigint, bib_ref text, titulo text, subtitulo text, ano text, editora text,
  libraries text, work_id bigint, volume text, volume_guess text, volume_rank integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  RETURN QUERY
  WITH b AS (
    SELECT bk.id, bk.bib_ref, bk.titulo, bk.subtitulo, bk.ano, bk.editora, bk.work_id, bk.volume,
           COALESCE(
             (SELECT 'a:' || ba.author_id::text FROM public.book_authors ba
               WHERE ba.book_id = bk.id AND ba.role = 'autor' AND ba.author_id IS NOT NULL ORDER BY ba.ord LIMIT 1),
             'n:' || public.fn_normalize_name(COALESCE(bk.autor, ''))) AS akey,
           COALESCE(NULLIF(btrim(bk.volume), ''), public.fn_volume_marker(bk.titulo), public.fn_volume_marker(bk.subtitulo)) AS vguess,
           public.fn_title_sans_volume(bk.titulo) AS tkey
      FROM public.books bk
     WHERE bk.serial_id IS NULL
       AND COALESCE(bk.tipo_material, 'livro') NOT IN ('periodico', 'boletim', 'revista')
       AND NULLIF(btrim(bk.titulo), '') IS NOT NULL
  ),
  g AS (
    SELECT b.akey || '|' || b.tkey AS gkey, count(*)::int AS n, count(DISTINCT b.work_id)::int AS nw,
           bool_or(b.vguess IS NOT NULL) AS has_marker
      FROM b
     WHERE length(b.tkey) >= 4
     GROUP BY b.akey || '|' || b.tkey
    HAVING count(*) >= 2 AND bool_or(b.vguess IS NOT NULL)
  ),
  kept AS (
    SELECT g.* FROM g
     WHERE NOT EXISTS (SELECT 1 FROM public.volume_group_dismissals d WHERE d.group_key = g.gkey)
     ORDER BY g.nw DESC, g.n DESC, g.gkey
     LIMIT GREATEST(COALESCE(p_max, 200), 1)
  )
  SELECT k.gkey,
         COALESCE((SELECT a.preferred_name FROM public.authors a WHERE 'a:' || a.id::text = b.akey), b.akey),
         b.tkey, k.n, k.nw,
         b.id, b.bib_ref, b.titulo, b.subtitulo, b.ano, b.editora,
         (SELECT string_agg(DISTINCT COALESCE(l.short_name, l.name), ', ' ORDER BY COALESCE(l.short_name, l.name))
            FROM public.book_holdings h JOIN public.libraries l ON l.id = h.library_id WHERE h.book_id = b.id),
         b.work_id, b.volume, b.vguess, public.fn_volume_rank(b.vguess)
    FROM kept k
    JOIN b ON b.akey || '|' || b.tkey = k.gkey
   ORDER BY k.nw DESC, k.n DESC, k.gkey, public.fn_volume_rank(b.vguess) NULLS LAST, b.id;
END;
$$;
COMMENT ON FUNCTION public.suggest_volume_groups(integer) IS
  'Groupes de notices qui sont probablement les tomes d''une meme oeuvre (meme auteur, meme titre sans marqueur de volume). Balayage servi a l''assistant de doublons, onglet Volumes. Lot 4.';
REVOKE EXECUTE ON FUNCTION public.suggest_volume_groups(integer) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.suggest_volume_groups(integer) TO authenticated;

-- ---------------------------------------------------------------------
-- 3. Les gestes
-- ---------------------------------------------------------------------
-- p_items : [{"book_id": 368, "volume": "III"}, …]. Pose le numero de tome sur
-- chaque notice (vide = inchange), puis reunit toutes les notices dans une
-- seule oeuvre (la plus petite deja presente, sinon une neuve depuis la plus
-- ancienne). Les oeuvres quittees et vides disparaissent.
CREATE OR REPLACE FUNCTION public.group_books_as_volumes(p_items jsonb)
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE v_ids bigint[]; v_work bigint; r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  IF jsonb_typeof(COALESCE(p_items, 'null'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'Selecione ao menos dois documentos.' USING ERRCODE = 'P0001', HINT = 'error.catalog.work.needTwo';
  END IF;
  SELECT array_agg(DISTINCT (e->>'book_id')::bigint) INTO v_ids
    FROM jsonb_array_elements(p_items) e WHERE (e->>'book_id') ~ '^[0-9]+$';
  IF v_ids IS NULL OR cardinality(v_ids) < 2 THEN
    RAISE EXCEPTION 'Selecione ao menos dois documentos.' USING ERRCODE = 'P0001', HINT = 'error.catalog.work.needTwo';
  END IF;
  FOR r IN SELECT (e->>'book_id')::bigint AS id, NULLIF(btrim(e->>'volume'), '') AS vol
             FROM jsonb_array_elements(p_items) e WHERE (e->>'book_id') ~ '^[0-9]+$' LOOP
    IF r.vol IS NOT NULL THEN
      UPDATE public.books SET volume = left(r.vol, 20) WHERE id = r.id;
    END IF;
  END LOOP;
  v_work := public.group_books_as_editions(v_ids);
  RETURN v_work;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.group_books_as_volumes(jsonb) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.group_books_as_volumes(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.dismiss_volume_group(p_group_key text, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  IF NULLIF(btrim(COALESCE(p_group_key, '')), '') IS NULL THEN RETURN; END IF;
  INSERT INTO public.volume_group_dismissals (group_key, reason, decided_by)
  VALUES (p_group_key, NULLIF(btrim(p_reason), ''), auth.uid())
  ON CONFLICT (group_key) DO UPDATE SET reason = COALESCE(EXCLUDED.reason, public.volume_group_dismissals.reason),
                                        decided_by = EXCLUDED.decided_by, decided_at = now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.dismiss_volume_group(text, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.dismiss_volume_group(text, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 4. L'OPAC : chaque edition porte son tome, les tomes se trient
-- ---------------------------------------------------------------------
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
  SELECT s.*, r.pos, COALESCE(s.work_id, -s.book_id) AS gkey,
         NULLIF(btrim(bk.volume), '') AS volume, public.fn_volume_rank(bk.volume) AS vrank
  FROM src s
  CROSS JOIN params p
  LEFT JOIN ranked r ON r.book_id = s.book_id
  LEFT JOIN public.books bk ON bk.id = s.book_id
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
         count(DISTINCT f.volume)::int                    AS volume_count,
         min(f.pos)                                       AS best_pos,
         min(NULLIF(substring(f.ano FROM '\d{4}'), '')::int) AS year_min,
         max(NULLIF(substring(f.ano FROM '\d{4}'), '')::int) AS year_max,
         max(f.created_at)                                AS newest,
         bool_or(COALESCE(f.global_available_count, 0) > 0) AS any_available,
         bool_or(f.session_status_hint = 'no_acervo_da_sua_biblioteca' AND COALESCE(f.session_available_count, 0) > 0) AS session_available,
         bool_or(f.session_status_hint IN ('no_acervo_da_sua_biblioteca', 'consultavel_no_local')) AS session_holding,
         (array_agg(f.book_id ORDER BY f.pos NULLS LAST, f.vrank NULLS LAST,
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
         jsonb_agg(f.row_json || jsonb_build_object('_pos', f.pos, 'volume', f.volume)
                   ORDER BY f.vrank NULLS LAST, NULLIF(substring(f.ano FROM '\d{4}'), '')::int DESC NULLS LAST, f.book_id) AS editions,
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
              'volume_count',  pg.volume_count,
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

-- ---------------------------------------------------------------------
-- 5. Garde-fous
-- ---------------------------------------------------------------------
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.suggest_volume_groups(integer)',
    'public.group_books_as_volumes(jsonb)',
    'public.dismiss_volume_group(text,text)'
  ] LOOP
    IF has_function_privilege('anon', f, 'EXECUTE') THEN
      RAISE EXCEPTION 'Garde-fou : % reste executable par anon', f;
    END IF;
  END LOOP;
  IF has_table_privilege('anon', 'public.volume_group_dismissals', 'SELECT') THEN
    RAISE EXCEPTION 'Garde-fou : volume_group_dismissals ne se lit pas sans session';
  END IF;
  IF NOT has_function_privilege('anon', 'api.catalog_works_v1(jsonb,text,integer,integer,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou : catalog_works_v1 doit rester publique';
  END IF;
END $$;

COMMIT;
