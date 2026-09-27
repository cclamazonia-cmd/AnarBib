-- =========================================================================
-- B33 — les recherches empruntent leurs index trigramme
-- =========================================================================
-- Date     : 2026-09-27
-- Chantier : B33 (constat de B10 : AUDIT_performance_B10_2026-09-27.md §5,
--            grappes 2 et 4, « Surprises » 2 et 8)
--
-- LE CONSTAT. L'autocomplétion publique et deux recherches du catalogage
-- avaient leurs index trigramme, et la forme de leur requête leur en
-- interdisait l'usage (0 parcours depuis le 02/09) :
--   · api.search_catalog_v1 (177 ms en moyenne) : la branche
--     `OR EXISTS (SELECT … FROM unnest(v_tokens) … ~ …)` interdit tout
--     BitmapOr ; et `f_normalize_search(COALESCE(a.sort_name, ''))` n'est pas
--     l'expression de l'index ;
--   · search_authors_by_name (166 ms pour 1 500 autorités) et
--     search_publishers_by_name (85 ms pour 1 200 éditeurs) :
--     `similarity() >= 0.30` est une fonction, pas un opérateur, aucun index
--     ne la sert ; et `fn_normalize_name(sort_name)`, OU-é avec le nom
--     préféré, n'avait pas d'index ;
--   · fn_sync_publisher_id_on_publish (déclencheur de books et de book_drafts,
--     à chaque publication) cherche l'éditeur par `lower(name) = …`, et aucun
--     index ne la sert : parcours séquentiel de publishers.
--
-- LE GESTE. Les corps sont patchés depuis leur définition RÉELLE
-- (pg_get_functiondef, chaque ancre trouvée une fois et une seule, jamais
-- recopiés : DOC-MSG-1 ; banc et production au même md5) :
--   1. search_catalog_v1 : les jetons forment UN motif `(^|\s)(t1|t2|…)`, que
--      gin_trgm sait servir ; ils y entrent échappés ; le COALESCE sort du
--      WHERE (le nom préféré porte les mêmes branches dans le même OU, le
--      COALESCE ne changeait aucun résultat) ;
--   2. search_authors_by_name, search_publishers_by_name : `%`, au seuil 0.3
--      posé dans la fonction (idiome des fonctions de dédoublonnage), rend
--      exactement ce que rendait `similarity() >= 0.30` ;
--   3. trois index : fn_normalize_name(sort_name) sur authors,
--      fn_normalize_name(name) sur publishers (le GIN sur `name` brut, que
--      personne n'écrit, part dans la migration suivante), lower(name) sur
--      publishers pour le déclencheur de publication.
-- Les résultats ne changent pas, sauf pour un jeton porteur d'un
-- métacaractère d'expression régulière : il est désormais cherché tel quel
-- (« c++ », « [ » ou « ( » sans sa fermante levaient 2201B ; « . » valait
-- n'importe quel caractère).
--
-- Tenu par tests/sql/recherche_index_trigramme_tests.sql.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 0. L'outil : remplacer des ancres dans la définition réelle
-- -------------------------------------------------------------------------
-- Chaque ancre doit s'y trouver une fois et une seule ; la fonction garde son
-- propriétaire, SECURITY DEFINER, son search_path et ses droits (vérifié).
CREATE OR REPLACE FUNCTION pg_temp.b33_patcher(p_fn regprocedure, p_marque text, p_anc text[], p_new text[])
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  v_def text := pg_get_functiondef(p_fn);
  v_acl text := (SELECT proacl::text FROM pg_proc WHERE oid = p_fn);
  v_eol text;
  v_a   text;
  v_occ int;
BEGIN
  IF position(p_marque IN v_def) > 0 THEN
    RAISE NOTICE 'B33 : % est déjà réécrite (rejeu), sans effet.', p_fn;
    RETURN;
  END IF;
  -- Un corps enregistré en CRLF garde sa fin de ligne : les ancres, écrites
  -- en LF, prennent la sienne.
  v_eol := CASE WHEN position(E'\r\n' IN v_def) > 0 THEN E'\r\n' ELSE E'\n' END;
  FOR i IN 1 .. array_length(p_anc, 1) LOOP
    v_a := replace(p_anc[i], E'\n', v_eol);
    v_occ := (length(v_def) - length(replace(v_def, v_a, ''))) / length(v_a);
    IF v_occ <> 1 THEN
      RAISE EXCEPTION 'B33 : ancre % trouvée % fois dans % (1 attendue) — relire la définition réelle', i, v_occ, p_fn;
    END IF;
    v_def := replace(v_def, v_a, replace(p_new[i], E'\n', v_eol));
  END LOOP;
  EXECUTE v_def;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = p_fn) IS DISTINCT FROM v_acl THEN
    RAISE EXCEPTION 'B33 : les droits de % ont changé', p_fn;
  END IF;
END
$f$;

-- -------------------------------------------------------------------------
-- 1. api.search_catalog_v1 — un seul motif, jetons échappés, sans COALESCE
-- -------------------------------------------------------------------------
SELECT pg_temp.b33_patcher(
  'api.search_catalog_v1(text)'::regprocedure,
  'v_motif',
  ARRAY[
    -- a. la déclaration
    E'  v_is_member boolean;\n',
    -- b. le motif, calculé une fois
    E'  v_is_member := (\n',
    -- c. les alias
    E'        OR EXISTS (\n'
    || E'          SELECT 1 FROM unnest(v_tokens) AS tok \n'
    || E'          WHERE ana.alias_norm ~ (''(^|\\s)'' || tok)\n'
    || E'        )\n',
    -- d. les autorités
    E'      public.f_normalize_search(a.preferred_name) % v_q_norm\n'
    || E'      OR public.f_normalize_search(COALESCE(a.sort_name, '''')) % v_q_norm\n'
    || E'      OR public.f_normalize_search(a.preferred_name) LIKE v_q_norm || ''%''\n'
    || E'      OR public.f_normalize_search(COALESCE(a.sort_name, '''')) LIKE v_q_norm || ''%''\n'
    || E'      OR EXISTS (\n'
    || E'        SELECT 1 FROM unnest(v_tokens) AS tok \n'
    || E'        WHERE public.f_normalize_search(a.preferred_name) ~ (''(^|\\s)'' || tok)\n'
    || E'           OR public.f_normalize_search(COALESCE(a.sort_name, '''')) ~ (''(^|\\s)'' || tok)\n'
    || E'      )\n',
    -- e. les notices
    E'      OR EXISTS (\n'
    || E'        SELECT 1 FROM unnest(v_tokens) AS tok \n'
    || E'        WHERE public.f_normalize_search(m.titulo) ~ (''(^|\\s)'' || tok)\n'
    || E'      )\n'
  ],
  ARRAY[
    E'  v_is_member boolean;\n'
    || E'  v_motif text;\n',
    E'  -- B33 (27/09/2026) : chaque jeton est cherché tel quel (ses métacaractères\n'
    || E'  -- d''expression régulière sont échappés : « c++ » ou « [ » levaient 2201B),\n'
    || E'  -- et tous les jetons forment UN motif, que gin_trgm sait servir.\n'
    || E'  v_tokens := array(SELECT regexp_replace(t, ''([.^$*+?()\\[\\]{}|\\\\])'', ''\\\\\\1'', ''g'') FROM unnest(v_tokens) AS t);\n'
    || E'  v_motif := ''(^|\\s)('' || array_to_string(v_tokens, ''|'') || '')'';\n'
    || E'\n'
    || E'  v_is_member := (\n',
    E'        OR ana.alias_norm ~ v_motif\n',
    E'      public.f_normalize_search(a.preferred_name) % v_q_norm\n'
    || E'      OR public.f_normalize_search(a.sort_name) % v_q_norm\n'
    || E'      OR public.f_normalize_search(a.preferred_name) LIKE v_q_norm || ''%''\n'
    || E'      OR public.f_normalize_search(a.sort_name) LIKE v_q_norm || ''%''\n'
    || E'      OR public.f_normalize_search(a.preferred_name) ~ v_motif\n'
    || E'      OR public.f_normalize_search(a.sort_name) ~ v_motif\n',
    E'      OR public.f_normalize_search(m.titulo) ~ v_motif\n'
  ]
);

-- -------------------------------------------------------------------------
-- 2. search_authors_by_name — l'opérateur `%` au lieu de similarity() >= 0.30
-- -------------------------------------------------------------------------
SELECT pg_temp.b33_patcher(
  'public.search_authors_by_name(text, integer)'::regprocedure,
  'b.np % v_nq',
  ARRAY[
    E'  RETURN QUERY\n  WITH base AS (\n',
    E'            OR similarity(b.np, v_nq) >= 0.30\n'
    || E'            OR similarity(b.ns, v_nq) >= 0.30 )'
  ],
  ARRAY[
    E'  -- B33 (27/09/2026) : `%` au seuil 0.3 rend ce que rendait\n'
    || E'  -- `similarity() >= 0.30`, mais c''est un opérateur, que les index\n'
    || E'  -- trigramme de fn_normalize_name savent servir. Sans ce réglage, une\n'
    || E'  -- session ayant relevé pg_trgm.similarity_threshold ferait disparaître\n'
    || E'  -- des autorités sans que rien ne le signale.\n'
    || E'  PERFORM set_config(''pg_trgm.similarity_threshold'', ''0.3'', true);\n'
    || E'\n'
    || E'  RETURN QUERY\n  WITH base AS (\n',
    E'            OR b.np % v_nq\n'
    || E'            OR b.ns % v_nq )'
  ]
);

-- -------------------------------------------------------------------------
-- 3. search_publishers_by_name — même geste
-- -------------------------------------------------------------------------
SELECT pg_temp.b33_patcher(
  'public.search_publishers_by_name(text, integer)'::regprocedure,
  'fn_normalize_name(pub.name) % v_nq',
  ARRAY[
    E'  RETURN QUERY\n  WITH scored AS (\n',
    E'        OR similarity(public.fn_normalize_name(pub.name), v_nq) >= 0.30\n'
  ],
  ARRAY[
    E'  -- B33 (27/09/2026) : `%` au seuil 0.3 rend ce que rendait\n'
    || E'  -- `similarity() >= 0.30`, mais c''est un opérateur, que l''index\n'
    || E'  -- trigramme de fn_normalize_name(name) sait servir. Sans ce réglage, une\n'
    || E'  -- session ayant relevé pg_trgm.similarity_threshold ferait disparaître\n'
    || E'  -- des éditeurs sans que rien ne le signale.\n'
    || E'  PERFORM set_config(''pg_trgm.similarity_threshold'', ''0.3'', true);\n'
    || E'\n'
    || E'  RETURN QUERY\n  WITH scored AS (\n',
    E'        OR public.fn_normalize_name(pub.name) % v_nq\n'
  ]
);

-- -------------------------------------------------------------------------
-- 4. Les index que ces requêtes écrivent désormais
-- -------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS authors_sort_name_fn_normalize_name_trgm_idx
  ON public.authors
  USING gin (public.fn_normalize_name(sort_name) extensions.gin_trgm_ops);

COMMENT ON INDEX public.authors_sort_name_fn_normalize_name_trgm_idx IS
  'B33 · lu par search_authors_by_name (LIKE %…% et %, OU-és avec le nom préféré, que sert authors_fn_normalize_name_trgm_idx).';

CREATE INDEX IF NOT EXISTS publishers_fn_normalize_name_trgm_idx
  ON public.publishers
  USING gin (public.fn_normalize_name(name) extensions.gin_trgm_ops);

COMMENT ON INDEX public.publishers_fn_normalize_name_trgm_idx IS
  'B33 · lu par search_publishers_by_name (LIKE %…% et %). Remplace idx_publishers_name_trgm, sur le nom brut, que personne n''écrivait.';

CREATE INDEX IF NOT EXISTS publishers_lower_name_idx
  ON public.publishers (lower(name));

COMMENT ON INDEX public.publishers_lower_name_idx IS
  'B33 · lu par fn_sync_publisher_id_on_publish (déclencheur de books et de book_drafts) : lower(p.name) = lower(trim(NEW.editora)).';

-- -------------------------------------------------------------------------
-- 5. Garde de sortie
-- -------------------------------------------------------------------------
DO $sortie$
DECLARE
  v_src text;
  r record;
BEGIN
  SELECT prosrc INTO v_src FROM pg_proc WHERE oid = 'api.search_catalog_v1(text)'::regprocedure;
  IF position('OR EXISTS (' IN v_src) > 0
     OR position('f_normalize_search(a.sort_name) % v_q_norm' IN v_src) = 0
     OR (length(v_src) - length(replace(v_src, '~ v_motif', ''))) / length('~ v_motif') <> 4 THEN
    RAISE EXCEPTION 'B33 : search_catalog_v1 n''a pas la forme attendue (plus de OR EXISTS, quatre « ~ v_motif », sort_name sans COALESCE)';
  END IF;
  IF position('similarity(b.np, v_nq) >= 0.30' IN (SELECT prosrc FROM pg_proc WHERE oid = 'public.search_authors_by_name(text, integer)'::regprocedure)) > 0
     OR position('similarity(public.fn_normalize_name(pub.name), v_nq) >= 0.30' IN (SELECT prosrc FROM pg_proc WHERE oid = 'public.search_publishers_by_name(text, integer)'::regprocedure)) > 0 THEN
    RAISE EXCEPTION 'B33 : une recherche du catalogage filtre encore par similarity() >= 0.30';
  END IF;
  FOR r IN
    SELECT p.oid::regprocedure AS fn, p.prosecdef, p.proconfig
      FROM pg_proc p
     WHERE p.oid IN ('api.search_catalog_v1(text)'::regprocedure,
                     'public.search_authors_by_name(text, integer)'::regprocedure,
                     'public.search_publishers_by_name(text, integer)'::regprocedure)
  LOOP
    IF NOT r.prosecdef OR NOT EXISTS (SELECT 1 FROM unnest(r.proconfig) c WHERE c LIKE 'search_path=%') THEN
      RAISE EXCEPTION 'B33 : % n''est plus DEFINER, ou a perdu son search_path', r.fn;
    END IF;
  END LOOP;
  IF has_function_privilege('anon', 'public.search_authors_by_name(text, integer)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.search_publishers_by_name(text, integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'B33 : une recherche du catalogage est ouverte à anon';
  END IF;
  IF (SELECT count(*) FROM pg_index x JOIN pg_class i ON i.oid = x.indexrelid
       WHERE i.relname IN ('authors_sort_name_fn_normalize_name_trgm_idx',
                           'publishers_fn_normalize_name_trgm_idx',
                           'publishers_lower_name_idx')
         AND i.relnamespace = 'public'::regnamespace AND x.indisvalid) <> 3 THEN
    RAISE EXCEPTION 'B33 : les trois index attendus ne sont pas tous là';
  END IF;
END
$sortie$;

COMMIT;
