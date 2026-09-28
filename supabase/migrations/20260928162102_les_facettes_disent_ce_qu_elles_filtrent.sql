-- =========================================================================
-- Les facettes du catalogue disent au planificateur ce qu'elles filtrent
-- =========================================================================
-- Date     : 2026-09-28
-- Chantier : suite de B32 (AUDIT_catalogue_grande_echelle_B32_2026-09-28.md, §7)
--
-- LE CONSTAT. api.catalog_facets_v1 — les compteurs de facettes de l'OPAC
-- (CDD, décennies, auteur·rices, sujets), un appel par changement de filtre —
-- avait la forme de catalog_works_v1 avant B32 : une CTE `params` en CROSS
-- JOIN et treize prédicats « p.x IS NULL OR c.col … » que le planificateur ne
-- sait pas estimer (p vient d'une CTE : il ne sait rien de p.x). Devant les
-- vraies lignes de la vue matérialisée (B32 a retiré l'enveloppe), c'est le
-- même terrain qui a fait basculer la page par œuvre en boucles imbriquées.
-- Ici rien de lourd n'est joint et la fonction tient (0,3 à 0,65 s à 100 000
-- notices) ; on la met dans la même forme AVANT qu'elle grossisse.
--
-- LE GESTE. La fonction devient PL/pgSQL et assemble ses cinq prédicats
-- (commun, auteur·rice, années, CDD, sujet) à partir des filtres PRÉSENTS,
-- chaque clause mot pour mot celle d'avant — une clause absente valait
-- `true`. Même normalisation des filtres (la CTE `params` reste), même
-- sémantique « expand » (chaque facette ignore son propre filtre), mêmes
-- quatre agrégats, même JSON. Garde d'entrée sur le md5 de la définition
-- réelle dont ce texte est parti.
-- =========================================================================

BEGIN;

DO $entree$
DECLARE v_md5 text;
BEGIN
  SELECT md5(p.prosrc) INTO v_md5 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_facets_v1';
  IF v_md5 IS DISTINCT FROM '6adc17fdcb42119ec48c1778ec3dd71b' THEN
    RAISE EXCEPTION 'facettes : api.catalog_facets_v1 n''est pas la version du 28/09 (md5 %) — relire sa définition réelle avant de la réécrire', v_md5;
  END IF;
END
$entree$;

CREATE OR REPLACE FUNCTION api.catalog_facets_v1(p_filters jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_sql text;
  v_out jsonb;
  -- les cinq prédicats, assemblés des filtres présents (la présence est jugée
  -- comme la CTE params normalise : NULLIF(btrim(…), ''))
  v_pc   text := 'true';   -- commun à toutes les facettes
  v_pa   text := 'true';   -- auteur·rice (ignoré par la facette auteur·rices)
  v_py   text := 'true';   -- années (ignoré par la facette décennies)
  v_pcd  text := 'true';   -- CDD (ignoré par la facette CDD)
  v_psub text := 'true';   -- sujet (ignoré par la facette sujets)
BEGIN
  IF NULLIF(btrim(p_filters->>'q'), '') IS NOT NULL THEN
    v_pc := v_pc || $w$ AND (c.titulo ILIKE '%'||p.q||'%' OR c.autor ILIKE '%'||p.q||'%'
        OR c.editora ILIKE '%'||p.q||'%' OR c.bib_ref ILIKE '%'||p.q||'%'
        OR c.cdd ILIKE '%'||p.q||'%' OR c.assuntos ILIKE '%'||p.q||'%'
        OR c.subtitulo ILIKE '%'||p.q||'%' OR c.isbn ILIKE '%'||p.q||'%')$w$;
  END IF;
  IF NULLIF(btrim(p_filters->>'publisher'), '') IS NOT NULL THEN v_pc := v_pc || $w$ AND c.editora ILIKE '%'||p.publisher||'%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'library'), '') IS NOT NULL THEN v_pc := v_pc || ' AND c.library_slug = p.library'; END IF;
  IF NULLIF(btrim(p_filters->>'material'), '') IS NOT NULL THEN v_pc := v_pc || ' AND c.tipo_material = p.material'; END IF;
  IF NULLIF(btrim(p_filters->>'language'), '') IS NOT NULL THEN v_pc := v_pc || $w$ AND c.idioma ILIKE '%'||p.language||'%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'collection'), '') IS NOT NULL THEN v_pc := v_pc || $w$ AND c.colecao ILIKE '%'||p.collection||'%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'place'), '') IS NOT NULL THEN v_pc := v_pc || $w$ AND c.local_publicacao ILIKE '%'||p.place||'%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'author_id'), '') IS NOT NULL THEN v_pa := v_pa || ' AND c.author_id::text = p.author_id'; END IF;
  IF NULLIF(btrim(p_filters->>'alpha'), '') IS NOT NULL THEN v_pa := v_pa || $w$ AND c.autor ILIKE p.alpha||'%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'year_from'), '') IS NOT NULL THEN v_py := v_py || $w$ AND (c.ano ~ '^\d{4}$' AND c.ano::int >= p.year_from)$w$; END IF;
  IF NULLIF(btrim(p_filters->>'year_to'), '') IS NOT NULL THEN v_py := v_py || $w$ AND (c.ano ~ '^\d{4}$' AND c.ano::int <= p.year_to)$w$; END IF;
  IF NULLIF(btrim(p_filters->>'cdd'), '') IS NOT NULL THEN v_pcd := v_pcd || $w$ AND c.cdd ILIKE p.cdd||'%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'subject'), '') IS NOT NULL THEN
    v_psub := v_psub || $w$ AND EXISTS (
        SELECT 1 FROM public.book_subjects bs JOIN public.subjects s ON s.id = bs.subject_id
        WHERE bs.book_id = c.book_id AND s.slug = p.subject)$w$;
  END IF;

  v_sql := $q$
WITH params AS (
  SELECT
    NULLIF(btrim($1->>'q'), '')          AS q,
    NULLIF(btrim($1->>'author_id'), '')  AS author_id,
    NULLIF(btrim($1->>'alpha'), '')      AS alpha,
    NULLIF(btrim($1->>'publisher'), '')  AS publisher,
    NULLIF(btrim($1->>'year_from'), '')::int AS year_from,
    NULLIF(btrim($1->>'year_to'), '')::int   AS year_to,
    NULLIF(btrim($1->>'library'), '')    AS library,
    NULLIF(btrim($1->>'cdd'), '')        AS cdd,
    NULLIF(btrim($1->>'language'), '')   AS language,
    NULLIF(btrim($1->>'material'), '')   AS material,
    NULLIF(btrim($1->>'collection'), '') AS collection,
    NULLIF(btrim($1->>'place'), '')      AS place,
    NULLIF(btrim($1->>'subject'), '')    AS subject
),
src AS (
  SELECT
    c.book_id, c.cdd, c.author_chips, c.ano,
    (__PC__) AS pc,
    (__PA__) AS pa,
    (__PY__) AS py,
    (__PCD__) AS pcd,
    -- predicat sujet (exclu de la facette sujets)
    (__PSUB__) AS psub
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
)
$q$;
  v_sql := replace(replace(replace(replace(replace(v_sql, '__PC__', v_pc), '__PA__', v_pa), '__PY__', v_py), '__PCD__', v_pcd), '__PSUB__', v_psub);
  EXECUTE v_sql INTO v_out USING p_filters;
  RETURN v_out;
END;
$function$;

COMMENT ON FUNCTION api.catalog_facets_v1(jsonb) IS
  'Compteurs de facettes de l''OPAC (CDD, décennies, auteur·rices, sujets) pour un jeu de filtres, chaque facette ignorant son propre filtre (« expand »). Depuis le 28/09/2026, les prédicats sont assemblés des filtres présents : le planificateur voit ce qu''il filtre.';

DO $sortie$
DECLARE v_src text;
BEGIN
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_facets_v1';
  IF v_src !~ '__PC__' OR v_src ~ 'p\.publisher IS NULL OR' THEN
    RAISE EXCEPTION 'facettes : catalog_facets_v1 n''assemble pas ses prédicats';
  END IF;
  IF NOT has_function_privilege('anon', 'api.catalog_facets_v1(jsonb)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'api.catalog_facets_v1(jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'facettes : catalog_facets_v1 a perdu ses droits (CREATE OR REPLACE les garde ; vérifier)';
  END IF;
END
$sortie$;

COMMIT;
