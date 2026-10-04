-- =========================================================================
-- Les suggestions de la recherche rapide lisent le titre de l'œuvre (E27)
-- =========================================================================
-- Date     : 2026-10-04
-- Chantier : recherche du catalogue — suite de E26 (20261001190729)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : Recherche catalogue — auteur·rice et titres d'œuvre
--
-- LE CONSTAT (01/10, à l'écran, item E27). Depuis E26, la grille du catalogue
-- trouve une œuvre par son titre d'œuvre (work_titles, toutes langues) :
-- « Vivre ma vie » rend l'œuvre 2101 (Living my Life). La barre de recherche
-- rapide, elle, passe par api.search_catalog_v1 (UnifiedSearchCombobox), qui
-- ne compare que le titre de l'édition : elle suggérait seulement le livre
-- d'Armand (« vivre ? », « vie quotidienne »). La barre contredisait la grille
-- juste en dessous.
--
-- LES GESTES.
--   1. Un index trigramme sur f_normalize_search(work_titles.title), écrit
--      comme ceux de B33 (un index ne sert que si la requête écrit exactement
--      son expression). Sans lui, normaliser les 3 818 titres à chaque frappe
--      coûtait ~470 ms (mesuré en production le 04/10) ; avec lui, la
--      suggestion reste au coût d'avant (« anarquia » 112 → ~120 ms, « Vivre
--      ma Vie » 44 → 40 ms).
--   2. api.search_catalog_v1 reçoit une branche `work_title_candidates` : un
--      titre d'œuvre qui répond à la requête (préfixe ou jetons — pas la
--      proximité %, qui doublait le coût des mots fréquents sans rien
--      apporter ici) suggère les éditions de l'œuvre, une ligne par édition,
--      au meilleur titre, et rien pour une édition déjà suggérée par son
--      propre titre. Le libellé dit les deux : « Living my Life (Vivre ma
--      vie) ». Le score et le filtre « préfixe d'abord » sont ceux des livres :
--      les deux branches passent par books_scored. Visibilité inchangée : les
--      éditions viennent des deux mêmes vues matérialisées, selon l'adhésion.
--      Réécriture CHIRURGICALE (deux ancres, une occurrence chacune, fins de
--      ligne de la définition réelle — CRLF — respectées, comme B33), gardée
--      par le md5 du corps en production au 04/10.
-- Garde : tests/sql/recherche_index_trigramme_tests.sql T9.
-- =========================================================================

BEGIN;

DO $entree$
DECLARE v_md5 text;
BEGIN
  SELECT md5(prosrc) INTO v_md5 FROM pg_proc WHERE oid = 'api.search_catalog_v1(text)'::regprocedure;
  IF v_md5 IS DISTINCT FROM '63050e28aea6bbadecf514e8612dc08e' THEN
    RAISE EXCEPTION 'E27 : api.search_catalog_v1 n''est pas la version du 04/10 (md5 %) — relire sa définition réelle avant de la réécrire', v_md5;
  END IF;
END
$entree$;

-- ── 1. L'index des titres d'œuvre ─────────────────────────────────────────
CREATE INDEX IF NOT EXISTS work_titles_title_norm_trgm_idx
  ON public.work_titles USING gin (public.f_normalize_search(title) extensions.gin_trgm_ops);

COMMENT ON INDEX public.work_titles_title_norm_trgm_idx IS
  'Sert api.search_catalog_v1 (branche work_title_candidates : LIKE et ~ sur f_normalize_search(title)). Migration 20261004211159 (E27).';

-- ── 2. La branche des titres d'œuvre ──────────────────────────────────────
DO $e27$
DECLARE
  v_def text; v_eol text; v_n int; i int;
  v_anc text[] := ARRAY[
    '    FROM book_candidates bc',
    '  books_scored AS ('
  ];
  v_new text[] := ARRAY[
    '    FROM (SELECT * FROM book_candidates UNION ALL SELECT * FROM work_title_candidates) bc',
    $n$  work_title_candidates AS (
    -- E27 (04/10/2026) : un titre d'œuvre (work_titles, toutes langues) suggère
    -- aussi les éditions de l'œuvre — le titre que le catalogue affiche est
    -- suggéré. Une ligne par édition, au meilleur titre ; rien si l'édition
    -- est déjà suggérée par son propre titre. Le libellé dit les deux.
    SELECT DISTINCT ON (m.book_id)
      m.book_id,
      m.titulo || ' (' || wt.title || ')' AS titulo,
      m.author_display,
      m.library_name,
      (
        SELECT count(*)::int
        FROM unnest(v_tokens) AS tok
        WHERE public.f_normalize_search(wt.title) ~ ('(^|\s)' || tok)
      ) AS tokens_matched,
      similarity(public.f_normalize_search(wt.title), v_q_norm) AS sim,
      public.f_normalize_search(wt.title) LIKE v_q_norm || '%' AS prefix_full
    FROM public.work_titles wt
    JOIN public.books b ON b.work_id = wt.work_id
    JOIN (
      SELECT book_id, titulo, author_display, library_name
        FROM public.mv_books_catalog_list_v1
        WHERE NOT v_is_member
      UNION ALL
      SELECT book_id, titulo, author_display, library_name
        FROM public.mv_books_catalog_list_network_v1
        WHERE v_is_member
    ) m ON m.book_id = b.id
    WHERE (
        public.f_normalize_search(wt.title) LIKE v_q_norm || '%'
        OR public.f_normalize_search(wt.title) ~ v_motif
      )
      -- une édition que son propre titre fait déjà suggérer (même filtre que
      -- books_scored) ; une candidate faible, écartée ensuite, ne bloque pas
      AND NOT EXISTS (SELECT 1 FROM book_candidates bc0
                       WHERE bc0.book_id = m.book_id
                         AND (bc0.prefix_full OR bc0.tokens_matched = v_token_count OR bc0.sim >= 0.3))
    ORDER BY m.book_id,
      (public.f_normalize_search(wt.title) LIKE v_q_norm || '%') DESC,
      similarity(public.f_normalize_search(wt.title), v_q_norm) DESC
  ),
  books_scored AS ($n$
  ];
BEGIN
  SELECT pg_get_functiondef('api.search_catalog_v1(text)'::regprocedure) INTO v_def;
  v_eol := CASE WHEN strpos(v_def, E'\r\n') > 0 THEN E'\r\n' ELSE E'\n' END;
  FOR i IN 1 .. array_length(v_anc, 1) LOOP
    v_n := (length(v_def) - length(replace(v_def, v_anc[i], ''))) / length(v_anc[i]);
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'E27 : ancre % (« % ») trouvée % fois dans api.search_catalog_v1, une attendue', i, v_anc[i], v_n;
    END IF;
    v_def := replace(v_def, v_anc[i], replace(v_new[i], E'\n', v_eol));
  END LOOP;
  EXECUTE v_def;
END
$e27$;

-- ── Vérification : ce que la migration fait, et rien de plus ───────────────
DO $verif$
DECLARE v_src text;
BEGIN
  SELECT prosrc INTO v_src FROM pg_proc WHERE oid = 'api.search_catalog_v1(text)'::regprocedure;
  IF v_src NOT LIKE '%work_title_candidates AS (%'
     OR v_src NOT LIKE '%UNION ALL SELECT * FROM work_title_candidates) bc%'
     OR (length(v_src) - length(replace(v_src, '~ v_motif', ''))) / length('~ v_motif') <> 5 THEN
    RAISE EXCEPTION 'E27 : api.search_catalog_v1 n''a pas la forme attendue';
  END IF;
  IF NOT (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = 'api.search_catalog_v1(text)'::regprocedure) THEN
    RAISE EXCEPTION 'E27 : api.search_catalog_v1 doit rester SECURITY DEFINER (les index trigramme ne servent pas sous RLS)';
  END IF;
  -- Le cas du signalement, sur les données réelles quand elles sont là.
  IF EXISTS (SELECT 1 FROM public.work_titles WHERE work_id = 2101 AND lang = 'fr' AND title = 'Vivre ma vie')
     AND EXISTS (SELECT 1 FROM public.mv_books_catalog_list_v1 m JOIN public.books b ON b.id = m.book_id WHERE b.work_id = 2101) THEN
    IF NOT EXISTS (SELECT 1 FROM api.search_catalog_v1('Vivre ma Vie') s
                    JOIN public.books b ON b.id = s.id
                   WHERE s.kind = 'book' AND b.work_id = 2101) THEN
      RAISE EXCEPTION 'E27 : « Vivre ma Vie » ne suggère pas l''œuvre 2101';
    END IF;
  END IF;
END
$verif$;

COMMIT;
