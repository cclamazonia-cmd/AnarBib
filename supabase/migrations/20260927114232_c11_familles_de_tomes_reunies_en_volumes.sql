-- =========================================================================
-- C11 — sept familles de tomes réunies en volumes, et Peirats rendu à la file
--        (27/09/2026)
-- =========================================================================
-- Réf. : backlog v34 C11 ; fiche docs/journal/arbitrages/ARBITRAGE_file_opac_par_oeuvre_2026-09-27.md ;
--        décisions de Xavier du 27/09 : « 1. Réunis en volumes. 2. Il faut reprendre Peirats. »
--
-- 1. Sept familles, une œuvre par tome jusqu'ici (verdicts « garder séparées »
--    posés dans l'assistant), rejoignent chacune une seule œuvre, le numéro de
--    tome en volume, sur le modèle de O Homem e a Terra (20260927112143) : le
--    regroupement suit pas à pas merge_works (notices, brouillons, pistes,
--    notes de lecture, auteur et notes de l'œuvre ; fn_work_prune_if_empty ;
--    expressions inutilisées ; fn_work_titles_reseed), sans en emprunter la
--    garde d'identité — en son propre nom. Les verdicts « garder séparées »
--    entre tomes partent avec les œuvres absorbées (ON DELETE CASCADE).
--    Chaque œuvre reprend le titre de l'ensemble, sans numéro, dans la langue
--    des volumes.
--
-- 2. Peirats, notices 1290 / 1291 : même édition (Buenos Aires, 2006), deux
--    libellés du même éditeur (« Anarres », « Libros de Anarres »). Depuis la
--    fusion des deux œuvres, l'assistant tient la paire pour deux éditions
--    distinctes d'une même œuvre et la masque — elle ne pouvait plus être
--    fusionnée. On aligne l'éditeur de 1291 sur 1290 : la paire revient dans
--    « À décider », où Xavier la fusionne (notice à garder : 1290, titre juste).
--    La fusion elle-même reste un geste de Xavier.
--
-- Garde : sur une base qui n'a pas ces notices (banc), rien n'est fait ; si
-- une partie seulement est là, refus.
-- =========================================================================

BEGIN;

DO $$
DECLARE
  v_familles jsonb := '[
    {"cible_livre": 1776, "titre": "Novísima Geografia Universal", "lang": "es",
     "tomes": [[1776,"1"],[1775,"2"],[1774,"3"],[1773,"4"],[1770,"5"],[1769,"6"]]},
    {"cible_livre": 2400, "titre": "Les Fils de la nuit", "lang": "fr",
     "tomes": [[2400,"1"],[2399,"2"]]},
    {"cible_livre": 2606, "titre": "La FORA en el movimiento obrero", "lang": "es",
     "tomes": [[2606,"1"],[2607,"2"],[170,null]]},
    {"cible_livre": 2630, "titre": "Minha Desilusão na Rússia", "lang": "pt-BR",
     "tomes": [[2630,"1"],[2631,"2"]]},
    {"cible_livre": 2616, "titre": "Living my Life", "lang": "en",
     "tomes": [[2616,"1"],[2617,"2"]]},
    {"cible_livre": 2522, "titre": "Bakunin - Obras Seletas", "lang": "pt-BR",
     "tomes": [[2522,"2"],[2523,"3"]]},
    {"cible_livre": 1060, "titre": "El Hombre y la Tierra", "lang": "es",
     "tomes": [[1060,"1"],[1056,"2"],[1055,"3"],[1059,"4"],[1054,"5"],[1053,"6"],[1057,null]]}
  ]'::jsonb;
  v_attendus text[][] := ARRAY[
    ['1776','Novísima Geografia Universal - 1'], ['1769','Novísima Geografia Universal - 6'],
    ['2400','Les fils de la nuit - 1'], ['2399','Les Fils de la Nuit - 2'],
    ['2606','La Fora em el Movimento Obrero/1'], ['2607','La Fora em el Movimento Obrero/2'], ['170','La Fora en el Movimento Obrero'],
    ['2630','Minha Desilusão na Rússia I'], ['2631','Minha Desilusão na Rússia II'],
    ['2616','Living my Life (volume one)'], ['2617','Living my Life (volume two)'],
    ['2522','Bakunin - Obras Seletas 2'], ['2523','Bakunin - Obras Seletas 3'],
    ['1060','El Hombre y la Tierra - Tomo 1'], ['1057','El Hombre y la Tierra'],
    ['1290','Los Anarquistas En La Crisis'], ['1291','Los anarquistas en la crisis']];
  f jsonb; t jsonb; i int; v_presents int := 0;
  v_cible bigint; v_src bigint; v_tgt public.works%rowtype; v_s public.works%rowtype;
BEGIN
  FOR i IN 1..array_length(v_attendus, 1) LOOP
    IF EXISTS (SELECT 1 FROM public.books WHERE id = v_attendus[i][1]::bigint AND titulo LIKE v_attendus[i][2] || '%') THEN
      v_presents := v_presents + 1;
    END IF;
  END LOOP;
  IF v_presents = 0 THEN
    RAISE NOTICE 'C11 familles : notices du relevé absentes (banc) — rien à appliquer.';
    RETURN;
  END IF;
  IF v_presents < array_length(v_attendus, 1) THEN
    RAISE EXCEPTION 'C11 familles : % notices sur % retrouvées telles que relevées — refus.', v_presents, array_length(v_attendus, 1);
  END IF;

  -- 1. Les familles de tomes
  FOR f IN SELECT * FROM jsonb_array_elements(v_familles) LOOP
    SELECT work_id INTO v_cible FROM public.books WHERE id = (f->>'cible_livre')::bigint;
    IF v_cible IS NULL THEN RAISE EXCEPTION 'C11 familles : la notice % n''a pas d''œuvre', f->>'cible_livre'; END IF;
    FOR t IN SELECT * FROM jsonb_array_elements(f->'tomes') LOOP
      SELECT work_id INTO v_src FROM public.books WHERE id = (t->>0)::bigint;
      IF v_src IS NOT NULL AND v_src <> v_cible THEN
        SELECT * INTO v_tgt FROM public.works WHERE id = v_cible;
        SELECT * INTO v_s   FROM public.works WHERE id = v_src;
        -- comme merge_works : les titres manuels de la source survivent si la cible n'en a pas
        INSERT INTO public.work_titles (work_id, lang, title, source, needs_review)
        SELECT v_cible, wt.lang, wt.title, 'manual', false FROM public.work_titles wt WHERE wt.work_id = v_src AND wt.source = 'manual'
        ON CONFLICT (work_id, lang) DO NOTHING;
        UPDATE public.books              SET work_id = v_cible WHERE work_id = v_src;
        UPDATE public.book_drafts        SET work_id = v_cible WHERE work_id = v_src;
        UPDATE public.audio_tracks       SET work_id = v_cible WHERE work_id = v_src;
        UPDATE public.book_reading_notes SET work_id = v_cible WHERE work_id = v_src;
        UPDATE public.works
           SET primary_author_id = COALESCE(v_tgt.primary_author_id, v_s.primary_author_id),
               notes = CASE WHEN NULLIF(v_s.notes, '') IS NULL THEN v_tgt.notes
                            WHEN NULLIF(v_tgt.notes, '') IS NULL THEN v_s.notes
                            ELSE v_tgt.notes || E'\n' || v_s.notes END,
               updated_at = now()
         WHERE id = v_cible;
        PERFORM public.fn_work_prune_if_empty(v_src);
      END IF;
      IF t->>1 IS NOT NULL THEN
        UPDATE public.books SET volume = t->>1 WHERE id = (t->>0)::bigint AND volume IS DISTINCT FROM t->>1;
      END IF;
    END LOOP;
    DELETE FROM public.work_expressions we
     WHERE we.work_id = v_cible AND NOT EXISTS (SELECT 1 FROM public.books b WHERE b.expression_id = we.id);
    PERFORM public.fn_work_titles_reseed(v_cible);
    UPDATE public.works SET uniform_title = f->>'titre', sort_title = public.fn_normalize_name(f->>'titre'), updated_at = now()
     WHERE id = v_cible;
    INSERT INTO public.work_titles (work_id, lang, title, source, needs_review)
    VALUES (v_cible, f->>'lang', f->>'titre', 'manual', false)
    ON CONFLICT (work_id, lang) DO UPDATE SET title = EXCLUDED.title, source = 'manual', source_book_id = NULL,
                                              needs_review = false, updated_at = now();

    -- Vérification de la famille
    IF (SELECT count(DISTINCT b.work_id) FROM jsonb_array_elements(f->'tomes') x JOIN public.books b ON b.id = (x->>0)::bigint) <> 1 THEN
      RAISE EXCEPTION 'C11 familles : « % » n''est pas réunie en une seule œuvre', f->>'titre';
    END IF;
  END LOOP;

  -- 2. Peirats : un seul libellé d'éditeur, la paire revient dans « À décider »
  UPDATE public.books SET editora = 'Anarres' WHERE id = 1291 AND editora = 'Libros de Anarres';
  IF public.fn_editions_distinctes(
       (SELECT isbn FROM public.books WHERE id = 1290), (SELECT isbn FROM public.books WHERE id = 1291),
       (SELECT ano FROM public.books WHERE id = 1290), (SELECT ano FROM public.books WHERE id = 1291),
       (SELECT editora FROM public.books WHERE id = 1290), (SELECT editora FROM public.books WHERE id = 1291),
       (SELECT edicao FROM public.books WHERE id = 1290), (SELECT edicao FROM public.books WHERE id = 1291)) THEN
    RAISE EXCEPTION 'C11 familles : les deux notices Peirats restent des éditions distinctes';
  END IF;

  RAISE NOTICE 'C11 familles : sept familles réunies en volumes ; Peirats rendu à « À décider ».';
END $$;

COMMIT;
