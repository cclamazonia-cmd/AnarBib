-- =============================================================================
-- La page Œuvre compte les éditions, pas les tomes
-- Date : 2026-09-07 · suite de E18 · retour Xavier : « c'est pas six éditions,
--        c'est six tomes d'une seule et même édition »
-- -----------------------------------------------------------------------------
-- Après 20260907220000, la page Œuvre montrait bien « Tome I … VI », mais son
-- en-tête disait toujours « 6 édition(s) » : le front comptait les notices.
-- La liste du catalogue, elle, sait déjà compter les tomes
-- (`api.catalog_works_v1` : `volume_count = count(DISTINCT volume)`) et dit
-- « 6 volumes » quand tous les tomes sont là. La page Œuvre reçoit les deux
-- nombres et laisse le front composer « 1 édition · 6 volumes ».
--
-- Règle de comptage des éditions : une notice SANS tome est une édition ;
-- les notices AVEC tome d'une même (année, éditeur, langue) sont UNE édition.
-- Six tomes de 1905 chez Librairie Universelle = 1 édition, 6 volumes.
-- Deux tirages distincts sans tome = 2 éditions, 0 volume (rien ne change
-- pour eux). Repris de la définition posée par 20260907220000 (relue en
-- production) ; seules les deux clés `edition_count` et `volume_count` sont
-- ajoutées. Grants conservés. Gardé par `oeuvre_tomes_page_tests` T6-T7.
-- =============================================================================

CREATE OR REPLACE FUNCTION api.work_public_detail(p_work_id bigint, p_lang text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  WITH rows AS (
    SELECT c.book_id, c.titulo, c.ano, c.editora, b.idioma, c.cover_object_path, c.bib_ref, b.expression_id,
           NULLIF(btrim(b.volume), '') AS volume
    FROM api.catalog_list_anon_v1 c
    JOIN public.books b ON b.id = c.book_id
    WHERE b.work_id = p_work_id
  ),
  eds AS (SELECT count(*) n FROM rows),
  counts AS (
    SELECT
      (SELECT count(*) FROM rows WHERE volume IS NULL)::int
      + (SELECT count(*) FROM (SELECT DISTINCT ano, editora, idioma FROM rows WHERE volume IS NOT NULL) k)::int AS edition_count,
      (SELECT count(DISTINCT volume) FROM rows WHERE volume IS NOT NULL)::int AS volume_count
  ),
  trans AS (
    SELECT r.expression_id AS eid,
           jsonb_agg(DISTINCT jsonb_build_object('author_id', a2.id, 'name', a2.preferred_name)) tr
    FROM rows r
    JOIN public.book_contributors bc ON bc.book_id = r.book_id AND bc.role = 'tradutor' AND bc.author_id IS NOT NULL
    JOIN public.authors a2 ON a2.id = bc.author_id
    GROUP BY r.expression_id
  ),
  flat AS (
    SELECT jsonb_agg(jsonb_build_object('book_id', r.book_id, 'titulo', r.titulo, 'ano', r.ano, 'editora', r.editora, 'idioma', r.idioma, 'cover_object_path', r.cover_object_path, 'bib_ref', r.bib_ref, 'volume', r.volume)
           ORDER BY NULLIF(substring(r.ano FROM '\d{4}'), '')::int NULLS LAST,
                    public.fn_volume_rank(r.volume) NULLS LAST, r.volume NULLS LAST, r.titulo) arr
    FROM rows r
  ),
  expr AS (
    SELECT jsonb_agg(g.e ORDER BY g.lang) arr FROM (
      SELECT COALESCE(we.lang, '') AS lang,
        jsonb_build_object('lang', COALESCE(we.lang, ''),
          'editions', jsonb_agg(jsonb_build_object('book_id', r.book_id, 'titulo', r.titulo, 'ano', r.ano, 'editora', r.editora, 'idioma', r.idioma, 'cover_object_path', r.cover_object_path, 'bib_ref', r.bib_ref, 'volume', r.volume)
            ORDER BY NULLIF(substring(r.ano FROM '\d{4}'), '')::int NULLS LAST,
                     public.fn_volume_rank(r.volume) NULLS LAST, r.volume NULLS LAST, r.titulo),
          'translators', COALESCE((SELECT tr FROM trans WHERE trans.eid = r.expression_id), '[]'::jsonb)) AS e
      FROM rows r LEFT JOIN public.work_expressions we ON we.id = r.expression_id
      GROUP BY r.expression_id, COALESCE(we.lang, '')
    ) g
  ),
  titles AS (
    SELECT COALESCE(jsonb_object_agg(t.lang, jsonb_build_object('title', t.title, 'source', t.source, 'needs_review', t.needs_review)), '{}'::jsonb) obj
    FROM public.work_titles t WHERE t.work_id = p_work_id
  )
  SELECT CASE WHEN (SELECT n FROM eds) = 0 THEN NULL
    ELSE jsonb_build_object(
      'id', w.id, 'uniform_title', w.uniform_title,
      'display_title', public.fn_work_display_title(w.id, COALESCE(NULLIF(p_lang, ''), 'pt-BR')),
      'titles', (SELECT obj FROM titles),
      'primary_author_id', w.primary_author_id, 'author_name', a.preferred_name,
      'edition_count', (SELECT edition_count FROM counts),
      'volume_count', (SELECT volume_count FROM counts),
      'editions', COALESCE((SELECT arr FROM flat), '[]'::jsonb),
      'expressions', COALESCE((SELECT arr FROM expr), '[]'::jsonb)
    ) END
  FROM public.works w
  LEFT JOIN public.authors a ON a.id = w.primary_author_id
  WHERE w.id = p_work_id;
$function$;

COMMENT ON FUNCTION api.work_public_detail(bigint, text) IS
  'Page Œuvre publique : titres par langue, éditions (à plat et par expression/langue), chaque édition avec volume (tome), tri année → rang du tome → titre ; edition_count (une notice sans tome = 1, les tomes d''une même année/éditeur/langue = 1) et volume_count (tomes distincts). 07/09/2026.';

DO $$
DECLARE v_src text;
BEGIN
  SELECT prosrc INTO v_src FROM pg_proc WHERE oid = 'api.work_public_detail(bigint,text)'::regprocedure;
  IF v_src NOT LIKE '%''edition_count''%' OR v_src NOT LIKE '%''volume_count''%' OR v_src NOT LIKE '%public.fn_volume_rank(r.volume)%' THEN
    RAISE EXCEPTION 'E18 : api.work_public_detail doit servir edition_count, volume_count et le tri par tome';
  END IF;
  IF NOT has_function_privilege('anon', 'api.work_public_detail(bigint,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'E18 : anon doit pouvoir lire la page Œuvre';
  END IF;
  RAISE NOTICE 'E18 OK : la page Œuvre compte les éditions et les tomes séparément.';
END $$;
