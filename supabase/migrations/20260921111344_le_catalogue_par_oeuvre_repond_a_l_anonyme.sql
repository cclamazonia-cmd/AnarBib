-- =============================================================================
-- Le catalogue par œuvre répond au visiteur anonyme
-- Date : 2026-09-21 · item B27 (P1) · constaté le 20/09 en vérifiant E17
-- -----------------------------------------------------------------------------
-- `api.catalog_works_v1` dépassait les 3 s du rôle `anon` (`authenticated` : 8 s).
-- Treize appels anonymes sur treize finissaient en `57014 canceling statement
-- due to statement timeout` ; le front retombait EN SILENCE sur la liste à plat,
-- et le regroupement par œuvre — le chantier de septembre — ne servait à aucun
-- visiteur non connecté. Rien à l'écran : une panne que le repli masquait.
--
-- Mesuré en production le 21/09, sous `set local role anon`, page par défaut
-- du front (`{}`, 'relevance', 0, 50, 'fr') :
--
--   page demandée   temps        blocs temporaires lus
--   1 œuvre         2 106 ms     1 362
--   50 œuvres       3 533 ms     579 758   (~4,4 Go)
--   200 œuvres      27 311 ms    9 126 308 (~70 Go)
--
-- La vue seule rend ses 2 651 lignes en 5 ms : le volume n'y est pour rien.
-- Deux coûts distincts, tous deux dans la requête :
--
--   1. UN COÛT QUADRATIQUE. `page_editions` calculait `library_names` par une
--      sous-requête corrélée qui relisait TOUT le CTE `filtered` pour CHAQUE
--      groupe de la page — et `filtered` traînait `row_json`, la ligne entière
--      de la vue en jsonb, pour les 2 651 notices. Cinquante groupes × 2 651
--      lignes grasses = 4,4 Go de fichiers temporaires.
--   2. UN PLANCHER DE 1,3 s. `fn_work_display_title` était appelée une fois PAR
--      ŒUVRE DU CATALOGUE (2 449 appels, 1 311 ms mesurés à part) : le tri par
--      défaut porte sur le titre affiché, il le faut donc pour tous les groupes.
--      La fonction porte un `SET search_path`, elle ne peut pas être fondue dans
--      la requête : trois sous-requêtes planifiées 2 449 fois.
--
-- Trois gestes, et aucun changement de résultat :
--
--   a. `src` ne porte plus `row_json` : la ligne entière de la vue n'est relue
--      que pour les éditions de la page (`page_editions` rejoint la vue sur
--      `book_id`, unique dans les deux vues — 2 651 lignes, 2 651 distincts) ;
--   b. le titre affiché se calcule en UN passage (`titres_livres`, `titres`),
--      avec la même cascade que `public.fn_work_display_title` : `work_titles`
--      dans la langue, sinon le titre de la plus ancienne édition dans cette
--      langue, sinon `works.uniform_title`. Équivalence vérifiée sur les 2 449
--      œuvres × 10 locales : 24 490 comparaisons, 0 différence. La fonction
--      reste : la page Œuvre (`api.work_public_detail`) l'appelle, pour UNE
--      œuvre à la fois — c'est son bon usage ;
--   c. `page_rows` isole les lignes de la page ; éditions (`page_editions`) et
--      bibliothèques (`page_libs`) se lisent sur elles seules.
--
-- Résultat, même appel, même rôle : **513 ms**, plus aucun fichier temporaire,
-- et un jsonb ÉGAL à celui de l'ancienne définition (`=` sur le jsonb entier).
--
-- Ce qui ne change pas, exprès : la requête reste DYNAMIQUE (`EXECUTE`), avec
-- une seule des deux vues nommée à la fois. Une RPC invoker qui nomme les deux
-- vues rend `42501` à `anon` — les droits se vérifient à la planification sur
-- toute relation citée. `__VIEW__` apparaît maintenant deux fois dans la
-- requête ; `replace()` remplace toutes les occurrences.
--
-- Repris de la définition RÉELLE : le corps du dépôt (20260904170000) et celui
-- de la production ont la même empreinte (md5 be8fb247…, 9 435 caractères),
-- et le nouveau corps en est dérivé par six modifications comptées. Signature,
-- volatilité, `search_path` et droits inchangés (`CREATE OR REPLACE` garde
-- l'ACL ; la RPC reste ouverte à `anon`, cf. `opac_par_oeuvre_tests` T7).
-- Gardé par `catalogue_par_oeuvre_cout_tests`.
--
-- Ce que cette migration ne fait PAS : le front retombe toujours en silence
-- (troisième « fini quand » de B27), et le coût restant vient de la vue
-- (`fn_library_visible_to_caller` évaluée par détention).
-- =============================================================================

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
         __SESS__
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
titres_livres AS (
  -- le titre de la plus ancienne edition de l'oeuvre dans la langue demandee :
  -- un seul passage sur books, au lieu d'une sous-requete par oeuvre
  SELECT DISTINCT ON (b.work_id) b.work_id, b.titulo
  FROM public.books b CROSS JOIN params p
  WHERE b.work_id IS NOT NULL AND public.fn_locale_from_idioma(b.idioma) = p.lang
  ORDER BY b.work_id, NULLIF(substring(b.ano FROM '\d{4}'), '')::int NULLS LAST, b.id
),
titres AS (
  -- meme cascade que public.fn_work_display_title, ecrite en jointures :
  -- work_titles dans la langue, sinon titres_livres, sinon works.uniform_title
  SELECT w.id AS work_id, COALESCE(wt.title, tl.titulo, w.uniform_title) AS display_title
  FROM public.works w
  CROSS JOIN params p
  LEFT JOIN public.work_titles wt ON wt.work_id = w.id AND wt.lang = p.lang
  LEFT JOIN titres_livres tl ON tl.work_id = w.id
  WHERE w.id IN (SELECT g0.work_id FROM groups g0 WHERE g0.work_id IS NOT NULL)
),
titled AS (
  SELECT g.*,
         CASE WHEN g.work_id IS NULL THEN f.titulo ELSE tt.display_title END AS display_title,
         f.autor AS rep_autor, f.editora AS rep_editora, f.bib_ref AS rep_bib_ref
  FROM groups g
  JOIN filtered f ON f.book_id = g.rep_book_id
  LEFT JOIN titres tt ON tt.work_id = g.work_id
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
page_rows AS (
  -- les seules lignes de la page (une cinquantaine d'oeuvres), pas tout le catalogue
  SELECT f.gkey, f.book_id, f.pos, f.volume, f.vrank, f.ano, f.holding_library_names_json
  FROM filtered f
  WHERE f.gkey IN (SELECT gkey FROM page)
),
page_editions AS (
  -- la ligne entiere de la vue n'est relue que pour les editions de la page
  SELECT pr.gkey,
         jsonb_agg(to_jsonb(c) || jsonb_build_object('_pos', pr.pos, 'volume', pr.volume)
                   ORDER BY pr.vrank NULLS LAST, NULLIF(substring(pr.ano FROM '\d{4}'), '')::int DESC NULLS LAST, pr.book_id) AS editions
  FROM page_rows pr
  JOIN __VIEW__ c ON c.book_id = pr.book_id
  GROUP BY pr.gkey
),
page_libs AS (
  SELECT pr.gkey, jsonb_agg(DISTINCT n ORDER BY n) AS library_names
  FROM page_rows pr,
       jsonb_array_elements_text(CASE WHEN jsonb_typeof(pr.holding_library_names_json) = 'array' THEN pr.holding_library_names_json ELSE '[]'::jsonb END) n
  GROUP BY pr.gkey
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
              'library_names', COALESCE(pl.library_names, '[]'::jsonb),
              'editions',      COALESCE(pe.editions, '[]'::jsonb))
            ORDER BY pg.ord)
     FROM page pg
     LEFT JOIN page_editions pe ON pe.gkey = pg.gkey
     LEFT JOIN page_libs pl ON pl.gkey = pg.gkey), '[]'::jsonb)
)
$q$;
  v_sql := replace(replace(v_sql, '__VIEW__', v_view), '__SESS__', v_sess);
  EXECUTE v_sql INTO v_out USING p_filters, p_sort, p_offset, p_limit, p_lang, v_auth;
  RETURN v_out;
END;
$fn$;
