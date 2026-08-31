-- =====================================================================
-- AnarBib -- Dix-sept doublons inter-bibliotheques fusionnes
-- Date    : 2026-08-31  ·  Chantier doublons
-- Depend  : 20260831150000 (le raffinement P4 qui les a rendus visibles)
--
-- Ces 17 paires sont le motif exact du cas 2335/2641 (« O Anarquismo na
-- Escola, no Teatro, na Poesia ») : la MEME edition (annee identique,
-- editeur identique, titre identique a la ponctuation pres, aucun ISBN ni
-- mention d'edition qui les separe) cataloguee deux fois parce que deux
-- bibliotheques ont saisi chacune leur fiche au lieu de rattacher leur
-- exemplaire. Le backfill d'oeuvres du 20/06 les avait groupees sous la
-- meme oeuvre, ce qui les masquait a l'arbitrage (cf. migration 150000).
--
-- CHOIX DU CANONIQUE : la fiche BLMF quand elle existe (catalogage manuel,
-- le plus riche), sinon la plus ancienne. Les champs bibliographiques que le
-- canonique n'avait pas sont repris du doublon avant sa suppression, ses
-- sujets aussi. Les holdings et exemplaires du doublon basculent sur le
-- canonique : AUCUNE bibliotheque ne perd sa detention (la fusion du
-- 2026-06-06, hors depot, avait perdu des exemplaires BTL -- reparee par
-- 20260831151000 ; celle-ci suit les etapes de public.merge_book, completees
-- des tables apparues depuis : book_subjects, audio_tracks,
-- ill_digital_shares, ingest.partner_catalog_staging_rows).
--
-- IDEMPOTENT ET SUR EN CI : chaque paire est verifiee (les deux fiches
-- existent, meme oeuvre, meme annee, editeurs concordants) ; toute paire qui
-- ne verifie pas est SAUTEE avec un avertissement, jamais fusionnee de force.
-- Sur une base vide (banc d'essai), tout est saute.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  -- [canonique, doublon]
  pairs bigint[][] := ARRAY[
    [231,2461],   -- A Anarquia, sua Filosofia, seu Ideal (BTL / MLEG, 2001 Imaginario)
    [2433,227],   -- A Boa Educacao (BLMF / BTL, 2007 Imaginario)
    [2230,2477],  -- A Imprensa operaria no Brasil 1880-1920 (BLMF / MLEG, 1978 Vozes)
    [258,2480],   -- A Nova Aurora Libertaria (BTL / MLEG, 1992 Achiame)
    [2261,2508],  -- Anarquistas, imigrantes e o movimento operario (BLMF / MLEG, 1979 Paz e Terra)
    [585,2511],   -- Antologia do Socialismo Libertario (BTL / MLEG, 1979 Mundo Livre)
    [2259,493],   -- Bakunin (BLMF / BTL, 1988 Papirus)
    [2324,657],   -- Burocracia e autogestao (BLMF / BTL, 1981 Brasiliense)
    [841,2540],   -- Cronica dos Primeiros Anarquistas no RJ (BTL / MLEG, 2004 Achiame)
    [1398,2589],  -- Historia del Movimiento Makhnovista (BTL / MLEG, 2008 Tupac)
    [1795,2636],  -- Nem patria, nem patrao (BTL / MLEG, 2002 Unesp)
    [2347,1787],  -- Notas e comentarios historico-sociais (BLMF / BTL, 1998 CC&P)
    [2335,2641],  -- O Anarquismo na Escola, no Teatro, na Poesia (BLMF+BTL / MLEG, 1992 Achiame)
    [2326,2639],  -- O Anarquismo no Banco dos Reus (BLMF / MLEG, 1993 VJR)
    [2278,1853],  -- Problemas e Possibilidades do Anarquismo (BLMF / BTL, 2011 Faisca)
    [2100,2697],  -- Servico Militar Obrigatorio Para Mulher? (BTL / MLEG, 1999 Opusculo)
    [49,2711]     -- Ultimos tempos de accao sindical livre (BTL / MLEG, 1989 Antigona)
  ];
  v_can bigint; v_dup bigint;
  can_row public.books%rowtype;
  dup_row public.books%rowtype;
  dh      record;
  v_ch_id bigint;
  v_done  bigint[] := '{}';
  i int;
BEGIN
  FOR i IN 1 .. array_length(pairs, 1) LOOP
    v_can := pairs[i][1];
    v_dup := pairs[i][2];

    SELECT * INTO can_row FROM public.books WHERE id = v_can;
    IF NOT FOUND THEN
      RAISE NOTICE 'Paire (%,%) sautee : canonique absent.', v_can, v_dup; CONTINUE;
    END IF;
    SELECT * INTO dup_row FROM public.books WHERE id = v_dup;
    IF NOT FOUND THEN
      RAISE NOTICE 'Paire (%,%) sautee : doublon absent (deja fusionne ?).', v_can, v_dup; CONTINUE;
    END IF;

    -- Garde-fous : la paire doit toujours etre ce qu'elle etait au constat.
    IF can_row.work_id IS NULL OR dup_row.work_id IS DISTINCT FROM can_row.work_id THEN
      RAISE WARNING 'Paire (%,%) sautee : plus la meme oeuvre.', v_can, v_dup; CONTINUE;
    END IF;
    IF public.fn_editions_distinctes(can_row.isbn, dup_row.isbn, can_row.ano, dup_row.ano,
                                     can_row.editora, dup_row.editora, can_row.edicao, dup_row.edicao) THEN
      RAISE WARNING 'Paire (%,%) sautee : les editions sont devenues distinguables.', v_can, v_dup; CONTINUE;
    END IF;
    IF EXISTS (SELECT 1 FROM public.book_not_duplicate nd
               WHERE nd.book_id_a = least(v_can, v_dup) AND nd.book_id_b = greatest(v_can, v_dup)) THEN
      RAISE NOTICE 'Paire (%,%) sautee : arbitree « pas un doublon ».', v_can, v_dup; CONTINUE;
    END IF;

    -- 0. Enrichissement : le canonique reprend ce qui lui manquait.
    UPDATE public.books c SET
      subtitulo           = coalesce(nullif(btrim(coalesce(c.subtitulo,'')),''), dup_row.subtitulo),
      isbn                = coalesce(nullif(btrim(coalesce(c.isbn,'')),''), dup_row.isbn),
      issn                = coalesce(nullif(btrim(coalesce(c.issn,'')),''), dup_row.issn),
      cdd                 = coalesce(nullif(btrim(coalesce(c.cdd,'')),''), dup_row.cdd),
      paginas             = coalesce(c.paginas, dup_row.paginas),
      idioma              = coalesce(nullif(btrim(coalesce(c.idioma,'')),''), dup_row.idioma),
      local_publicacao    = coalesce(nullif(btrim(coalesce(c.local_publicacao,'')),''), dup_row.local_publicacao),
      edicao              = coalesce(nullif(btrim(coalesce(c.edicao,'')),''), dup_row.edicao),
      colecao             = coalesce(nullif(btrim(coalesce(c.colecao,'')),''), dup_row.colecao),
      assuntos            = coalesce(nullif(btrim(coalesce(c.assuntos,'')),''), dup_row.assuntos),
      tradutor            = coalesce(nullif(btrim(coalesce(c.tradutor,'')),''), dup_row.tradutor),
      organizador         = coalesce(nullif(btrim(coalesce(c.organizador,'')),''), dup_row.organizador),
      autores_secundarios = coalesce(nullif(btrim(coalesce(c.autores_secundarios,'')),''), dup_row.autores_secundarios),
      distribuidora       = coalesce(nullif(btrim(coalesce(c.distribuidora,'')),''), dup_row.distribuidora),
      cover_object_path   = coalesce(c.cover_object_path, dup_row.cover_object_path),
      cover_source        = CASE WHEN c.cover_object_path IS NULL THEN coalesce(dup_row.cover_source, c.cover_source) ELSE c.cover_source END,
      cover_license       = CASE WHEN c.cover_object_path IS NULL THEN coalesce(dup_row.cover_license, c.cover_license) ELSE c.cover_license END,
      updated_at          = now()
    WHERE c.id = v_can;

    INSERT INTO public.book_subjects (book_id, subject_id)
    SELECT v_can, bs.subject_id FROM public.book_subjects bs
    WHERE bs.book_id = v_dup
    ON CONFLICT (book_id, subject_id) DO NOTHING;

    -- 1. Holdings : fusionner (meme bibliotheque) ou repointer (etapes de merge_book).
    FOR dh IN SELECT * FROM public.book_holdings WHERE book_id = v_dup LOOP
      SELECT id INTO v_ch_id
        FROM public.book_holdings
        WHERE book_id = v_can AND library_id = dh.library_id
        LIMIT 1;

      IF v_ch_id IS NOT NULL THEN
        UPDATE public.exemplares                 SET holding_id = v_ch_id WHERE holding_id = dh.id;
        UPDATE public.emprestimo_itens_v2        SET holding_id = v_ch_id WHERE holding_id = dh.id;
        UPDATE public.reserva_linhas_v2          SET holding_id = v_ch_id WHERE holding_id = dh.id;
        UPDATE public.interlibrary_loan_items_v2 SET holding_id = v_ch_id WHERE holding_id = dh.id;
        UPDATE public.consulta_linhas_v2         SET holding_id = v_ch_id WHERE holding_id = dh.id;
        UPDATE public.exemplar_drafts            SET target_holding_id = v_ch_id WHERE target_holding_id = dh.id;
        DELETE FROM public.book_holdings WHERE id = dh.id;
      ELSE
        UPDATE public.book_holdings SET book_id = v_can WHERE id = dh.id;
      END IF;
    END LOOP;

    -- 2. Circulation au niveau livre.
    UPDATE public.emprestimo_itens_v2        SET book_id = v_can WHERE book_id = v_dup;
    UPDATE public.reserva_linhas_v2          SET book_id = v_can WHERE book_id = v_dup;
    UPDATE public.interlibrary_loan_items_v2 SET book_id = v_can WHERE book_id = v_dup;
    UPDATE public.consulta_linhas_v2         SET book_id = v_can WHERE book_id = v_dup;

    -- 3. Ressources numeriques et rattachements apparus depuis merge_book.
    UPDATE public.digital_assets      SET book_id = v_can WHERE book_id = v_dup;
    UPDATE public.audio_tracks        SET book_id = v_can WHERE book_id = v_dup;
    UPDATE public.ill_digital_shares  SET book_id = v_can WHERE book_id = v_dup;
    UPDATE ingest.partner_catalog_staging_rows SET proposed_book_id = v_can WHERE proposed_book_id = v_dup;

    -- 4. Wishlist : dedupe puis repoint.
    DELETE FROM public.user_wishlist w
      WHERE w.book_id = v_dup
        AND EXISTS (SELECT 1 FROM public.user_wishlist w2
                    WHERE w2.user_id = w.user_id AND w2.book_id = v_can);
    UPDATE public.user_wishlist SET book_id = v_can WHERE book_id = v_dup;

    -- 5. Brouillons pointant vers le doublon.
    UPDATE public.book_drafts SET published_book_id = v_can WHERE published_book_id = v_dup;

    -- 6. Journaliser.
    INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
    VALUES ('book', v_can, v_dup,
            jsonb_build_object('via', 'migration_fusion_meme_edition_20260831',
                               'duplicate_titulo', dup_row.titulo,
                               'duplicate_bib_ref', dup_row.bib_ref),
            NULL);

    -- 7. Supprimer le doublon (cascades : book_authors/contributors/
    --    catalog_context/subjects restants, signalements).
    DELETE FROM public.books WHERE id = v_dup;

    v_done := v_done || v_can;
  END LOOP;

  -- 8. Recalcul des compteurs de disponibilite des canoniques touches.
  IF array_length(v_done, 1) IS NOT NULL THEN
    PERFORM public.fn_v2_recompute_holdings_availability(NULL, v_done);
  END IF;
  RAISE NOTICE 'Fusions effectuees : % / %', coalesce(array_length(v_done,1),0), array_length(pairs,1);
END $$;

COMMIT;
