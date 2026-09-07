-- =============================================================================
-- La page Œuvre dit le tome — et range les tomes dans l'ordre
-- Date : 2026-09-07 · Backlog v34 E18 · retour Xavier sur /obra/133
-- -----------------------------------------------------------------------------
-- Le défaut. « L'Homme et la Terre » (Élisée Reclus, œuvre 133) affichait six
-- « éditions » strictement identiques à l'écran — « 1905 · Librairie
-- Universelle · Français » six fois, dans l'ordre VI, V, IV, I, III, II. Les
-- données étaient pourtant justes : les six notices portent `volume` = I à VI
-- et le sous-titre « Tome N ». C'est `api.work_public_detail` qui ne servait
-- pas le tome (book_id, titulo, ano, editora, idioma, couverture, cote — pas
-- `volume`) et triait par année puis titre : six clés égales, ordre arbitraire.
-- La liste du catalogue, elle, sert déjà `volume` par édition et le front y
-- pose un badge « Tome N » (`catalog.works.volumeLabel`, dix locales) : la page
-- Œuvre était la seule surface à l'ignorer.
--
-- Le remède. Repris de `pg_get_functiondef` lu en production le 07/09 (la
-- définition de `20260904130100` n'avait pas bougé depuis), avec deux
-- changements et rien d'autre : `volume` (vide → NULL) dans chaque objet
-- d'édition, et le tri « année, puis rang du tome (`fn_volume_rank` : romain
-- ou arabe), puis titre ». Mêmes grants (CREATE OR REPLACE les conserve ;
-- `work_titles_tests` T-anon vérifie qu'anon exécute toujours).
-- Fonctionnel gardé par `tests/sql/oeuvre_tomes_page_tests.sql`.
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
      'editions', COALESCE((SELECT arr FROM flat), '[]'::jsonb),
      'expressions', COALESCE((SELECT arr FROM expr), '[]'::jsonb)
    ) END
  FROM public.works w
  LEFT JOIN public.authors a ON a.id = w.primary_author_id
  WHERE w.id = p_work_id;
$function$;

COMMENT ON FUNCTION api.work_public_detail(bigint, text) IS
  'Page Œuvre publique : titres par langue, éditions (à plat et par expression/langue). Chaque édition porte volume (tome, NULL si vide) ; tri année → rang du tome (fn_volume_rank) → titre. 07/09/2026.';

-- Garde structurelle : le tome est servi et trié.
DO $$
DECLARE v_src text;
BEGIN
  SELECT prosrc INTO v_src FROM pg_proc WHERE oid = 'api.work_public_detail(bigint,text)'::regprocedure;
  IF v_src NOT LIKE '%''volume'', r.volume%' OR v_src NOT LIKE '%public.fn_volume_rank(r.volume)%' THEN
    RAISE EXCEPTION 'E18 : api.work_public_detail doit servir volume et trier par fn_volume_rank';
  END IF;
  IF NOT has_function_privilege('anon', 'api.work_public_detail(bigint,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'E18 : anon doit pouvoir lire la page Œuvre (grant perdu ?)';
  END IF;
  RAISE NOTICE 'E18 OK : la page Œuvre sert le tome et trie les tomes.';
END $$;
