-- =====================================================================
-- AnarBib -- C18 : œuvres scindées par langue, arbitrées le 05/10/2026
-- Date     : 2026-10-05  ·  Item C18 (backlog v34)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : Recherche catalogue — auteur·rice et titres d'œuvre
--
-- CONSTAT (01/10 puis 05/10, lecture seule) : un titre « auto » d'une œuvre
-- était le titre réel d'une autre œuvre du même auteur·rice. Surtout des
-- traductions d'une même œuvre rangées sous deux ou trois fiches. Dossier
-- soumis à Xavier le 05/10 ; il a validé les huit réunions (A) et les
-- propositions (B). Cette migration APPLIQUE ses décisions, rien d'autre :
-- aucune fusion n'est décidée par script.
--
-- CE QUI EST FAIT
--   A. Huit réunions d'œuvres entières (gestes de merge_works, sans sa garde
--      auth.uid(), inopérante en migration — comme 20260904095317) :
--        1084 → 1     Kropotkine, La Grande Révolution (+ l'éd. italienne ;
--                     la notice 2209 reçoit sa langue, « it », avant)
--        2381 → 19    Kropotkine, La Conquête du pain
--        396  → 79    Kropotkine, L'Entraide
--        386  → 115   Kropotkine, Autour d'une vie
--        873  → 48    Gori, La Anarquía ante los tribunales
--        2428 → 99    Safón, Le Rationalisme combattant
--        2484 → 74    Horowitz, The Anarchists / Los Anarquistas
--        268, 1203 → 1387  Reclus, L'Évolution, la Révolution et l'Idéal
--                     anarchique (sur l'œuvre de langue originale)
--   B9. Reclus, L'Homme et la Terre : les six tomes Maucci (es) rejoignent
--      les six tomes de 1905 (œuvre 133). Restent à part, avec une note, et
--      leurs titres « auto » remplacés par leur titre propre (comme 1163) :
--      1131 (FCE 1986, un volume — une sélection, à confirmer sur l'exemplaire)
--      et 880 (volumes thématiques Imaginário 2010-2011, des extraits).
--   B12. La notice 143 (La Moral Anarquista y otros escritos, 2008) quitte
--      le texte seul (1366) pour le recueil (2064).
--
-- CE QUI N'EST PAS FAIT
--   - Tolstoï 28 / 1297 : recueil ou texte seul ? Il faut le sommaire de
--     l'édition Madre Tierra 1991. Reste dans C18.
--   - Nettlau 2036 / 196 : proposé « distinctes » le 05/10, puis retenu —
--     les titres de 2036 (A Short History of Anarchism, Histoire de
--     l'anarchie) sont ceux des traductions de La Anarquía a través de los
--     tiempos, et l'éd. Hedra pourrait l'être aussi. Reste dans C18.
--   - Notices en double (assistant de doublons, pas les œuvres) : 2601/1195
--     (Júcar 1978), 143/138 (Anarres 2008).
--
-- IDEMPOTENT ET SÛR EN CI : chaque geste est gardé par l'état constaté le
-- 05/10 ; un geste dont l'état a changé est SAUTÉ avec un avertissement.
-- Sur une base vide (banc d'essai), tout est sauté.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  -- [œuvre source, œuvre cible]
  merges bigint[][] := ARRAY[
    [1084, 1], [2381, 19], [396, 79], [386, 115], [873, 48],
    [2428, 99], [2484, 74], [268, 1387], [1203, 1387]
  ];
  -- [notice, œuvre source, œuvre cible]
  moves bigint[][] := ARRAY[
    [1053, 1131, 133], [1054, 1131, 133], [1055, 1131, 133],
    [1056, 1131, 133], [1059, 1131, 133], [1060, 1131, 133],
    [143, 1366, 2064]
  ];
  targets bigint[] := ARRAY[1, 19, 79, 115, 48, 99, 74, 1387, 133, 2064, 1131, 1366];
  i int; v_src bigint; v_tgt bigint; v_srcrow public.works%rowtype;
  n_merged int := 0; n_moved int := 0; n_expr int := 0; n_titles int := 0;
  v_report text := '';
BEGIN
  -- Garde banc d'essai : sans la notice pivot (L'Homme et la Terre, tome I, 1905), ce n'est pas la prod.
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = 1215 AND work_id = 133) THEN
    RAISE NOTICE 'C18 : base sans les données du constat, rien à faire.';
    RETURN;
  END IF;

  -- 0. Langue manquante, AVANT le déplacement (l'expression FRBR naît de NEW.idioma)
  UPDATE public.books SET idioma = 'it' WHERE id = 2209 AND work_id = 1084 AND idioma IS NULL;

  -- A. Réunions d'œuvres entières
  FOR i IN 1 .. array_length(merges, 1) LOOP
    v_src := merges[i][1]; v_tgt := merges[i][2];
    SELECT * INTO v_srcrow FROM public.works WHERE id = v_src;
    IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM public.works WHERE id = v_tgt) THEN
      v_report := v_report || format(' [réunion sautée : %s → %s]', v_src, v_tgt);
      CONTINUE;
    END IF;
    -- titres saisis à la main sur la source : survivent si la cible n'en a pas
    INSERT INTO public.work_titles (work_id, lang, title, source, needs_review)
    SELECT v_tgt, t.lang, t.title, 'manual', false
      FROM public.work_titles t WHERE t.work_id = v_src AND t.source = 'manual'
    ON CONFLICT (work_id, lang) DO UPDATE
       SET title = EXCLUDED.title, source = 'manual', source_book_id = NULL, needs_review = false, updated_at = now()
     WHERE public.work_titles.source <> 'manual';
    UPDATE public.books              SET work_id = v_tgt WHERE work_id = v_src;
    UPDATE public.book_drafts        SET work_id = v_tgt WHERE work_id = v_src;
    UPDATE public.audio_tracks       SET work_id = v_tgt WHERE work_id = v_src;
    UPDATE public.book_reading_notes SET work_id = v_tgt WHERE work_id = v_src;
    UPDATE public.works w
       SET primary_author_id = COALESCE(w.primary_author_id, v_srcrow.primary_author_id),
           notes = CASE WHEN NULLIF(v_srcrow.notes, '') IS NULL THEN w.notes
                        WHEN NULLIF(w.notes, '') IS NULL THEN v_srcrow.notes
                        ELSE w.notes || E'\n' || v_srcrow.notes END,
           updated_at = now()
     WHERE w.id = v_tgt;
    IF public.fn_work_prune_if_empty(v_src) THEN n_merged := n_merged + 1;
    ELSE v_report := v_report || format(' [œuvre %s non vide après réunion]', v_src);
    END IF;
  END LOOP;

  -- B9 / B12. Déplacements de notices, gardés par l'œuvre source constatée
  FOR i IN 1 .. array_length(moves, 1) LOOP
    UPDATE public.books SET work_id = moves[i][3]
     WHERE id = moves[i][1] AND work_id = moves[i][2]
       AND EXISTS (SELECT 1 FROM public.works WHERE id = moves[i][3]);
    IF FOUND THEN n_moved := n_moved + 1;
    ELSE v_report := v_report || format(' [déplacement sauté : notice %s (%s → %s)]', moves[i][1], moves[i][2], moves[i][3]);
    END IF;
  END LOOP;

  -- Expressions FRBR orphelines sur les œuvres touchées
  DELETE FROM public.work_expressions we
   WHERE we.work_id = ANY(targets)
     AND NOT EXISTS (SELECT 1 FROM public.books b WHERE b.expression_id = we.id);
  GET DIAGNOSTICS n_expr = ROW_COUNT;
  FOR i IN 1 .. array_length(targets, 1) LOOP
    PERFORM public.fn_work_titles_reseed(targets[i]);
  END LOOP;

  -- B9. Le titre espagnol de 133 : le semis prendrait celui d'une notice Maucci,
  -- « El Hombre y la Tierra - Tomo 6 » ; l'œuvre s'appelle sans numéro de tome
  -- (titre déjà saisi à la main sur 1131 avant le déplacement).
  INSERT INTO public.work_titles (work_id, lang, title, source, needs_review)
  VALUES (133, 'es', 'El Hombre y la Tierra', 'manual', false)
  ON CONFLICT (work_id, lang) DO UPDATE
     SET title = EXCLUDED.title, source = 'manual', source_book_id = NULL, needs_review = false, updated_at = now()
   WHERE public.work_titles.source <> 'manual';

  -- B9. Les deux éditions partielles gardent leur titre propre partout (comme 1163),
  -- seulement si la notice attendue est bien seule sur son œuvre.
  IF (SELECT array_agg(id ORDER BY id) FROM public.books WHERE work_id = 1131) = ARRAY[1057::bigint] THEN
    UPDATE public.work_titles SET title = 'El Hombre y la Tierra', source = 'manual', needs_review = false,
           source_book_id = NULL, updated_at = now()
     WHERE work_id = 1131 AND source = 'auto';
    GET DIAGNOSTICS i = ROW_COUNT; n_titles := n_titles + i;
    UPDATE public.works SET notes = concat_ws(E'\n', NULLIF(btrim(notes), ''),
             'Edição FCE de 1986 em um volume: seleção de L''Homme et la Terre (Élisée Reclus), a confirmar no exemplar. '
             || 'O texto integral, em seis tomos (fr 1905, es Maucci), está na obra 133. Obra mantida distinta (C18, decisão de 05/10/2026).'),
           updated_at = now()
     WHERE id = 1131 AND coalesce(notes, '') NOT LIKE '%(C18,%';
  ELSE
    v_report := v_report || ' [œuvre 1131 : notice FCE pas seule, titres et note sautés]';
  END IF;
  IF EXISTS (SELECT 1 FROM public.books WHERE work_id = 880)
     AND NOT EXISTS (SELECT 1 FROM public.books WHERE work_id = 880 AND editora NOT ILIKE '%Imagin%rio%') THEN
    UPDATE public.work_titles SET title = 'O Homem e a Terra', source = 'manual', needs_review = false,
           source_book_id = NULL, updated_at = now()
     WHERE work_id = 880 AND source = 'auto';
    GET DIAGNOSTICS i = ROW_COUNT; n_titles := n_titles + i;
    UPDATE public.works SET notes = concat_ws(E'\n', NULLIF(btrim(notes), ''),
             'Volumes temáticos da Editora Imaginário (2010-2011): extratos de L''Homme et la Terre (Élisée Reclus). '
             || 'O texto integral, em seis tomos, está na obra 133. Obra mantida distinta (C18, decisão de 05/10/2026).'),
           updated_at = now()
     WHERE id = 880 AND coalesce(notes, '') NOT LIKE '%(C18,%';
  ELSE
    v_report := v_report || ' [œuvre 880 : contenu inattendu, titres et note sautés]';
  END IF;

  RAISE NOTICE 'C18 : % réunions, % déplacements, % expressions purgées, % titres auto remplacés.%',
    n_merged, n_moved, n_expr, n_titles, v_report;

  -- Vérification : en prod, tout doit avoir été fait.
  IF n_merged <> 9 OR n_moved <> 7 THEN
    RAISE EXCEPTION 'C18 : % réunions sur 9, % déplacements sur 7 —%', n_merged, n_moved, v_report;
  END IF;
  IF EXISTS (SELECT 1 FROM public.works WHERE id = ANY(ARRAY[1084, 2381, 396, 386, 873, 2428, 2484, 268, 1203]::bigint[])) THEN
    RAISE EXCEPTION 'C18 : une œuvre source subsiste';
  END IF;
  IF (SELECT idioma FROM public.books WHERE id = 2209) IS DISTINCT FROM 'it' THEN
    RAISE EXCEPTION 'C18 : la notice 2209 n''a pas reçu sa langue';
  END IF;
END $$;

COMMIT;
