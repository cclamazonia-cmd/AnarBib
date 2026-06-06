-- =========================================================================
-- Paquet data — fusion des doublons de notices cross-bibliotheque (lot 2)
-- =========================================================================
-- Session  : Exemplaires & nettoyage catalogue
-- Auteur   : Xavier + Claude
-- Chantier : Nettoyage catalogue / notices partagees
--
-- CONTEXTE
-- --------
-- Suite du lot 1 (20260606203644). Ces 4 doublons cross-biblio etaient detectes
-- par le TEXTE d'auteur (meme titre + meme annee + meme auteur + editeur ~),
-- mais NON par le lien d'autorite (notices sans author_id) -> non traites au
-- lot 1. Liste VALIDEE par Xavier. Meme mecanique que le lot 1 (backfill des
-- champs vides du canonique + logique merge_book inlinee). 4 doublons -> 0.
-- =========================================================================

BEGIN;

DO $merge$
DECLARE
  rec  record;
  dh   record;
  v_canon bigint;
  v_dup   bigint;
  v_ch    bigint;
  v_n     int;
  v_deleted int := 0;
BEGIN
  IF (SELECT count(*) FROM public.books WHERE id IN (295,281,710,602)) <> 4 THEN
    RAISE EXCEPTION 'abort : la liste de doublons attendue (4) ne correspond plus a la base.';
  END IF;

  FOR rec IN SELECT * FROM (VALUES
    (2227::bigint, 295::bigint),
    (2299, 281),
    (2219, 710),
    (2345, 602)
  ) AS p(canon, dup)
  LOOP
    v_canon := rec.canon; v_dup := rec.dup;

    UPDATE public.books c SET
      cover_object_path = COALESCE(NULLIF(c.cover_object_path,''), d.cover_object_path),
      editora          = COALESCE(NULLIF(c.editora,''),          d.editora),
      cdd              = COALESCE(NULLIF(c.cdd,''),              d.cdd),
      isbn             = COALESCE(NULLIF(c.isbn,''),             d.isbn),
      issn             = COALESCE(NULLIF(c.issn,''),             d.issn),
      subtitulo        = COALESCE(NULLIF(c.subtitulo,''),        d.subtitulo),
      edicao           = COALESCE(NULLIF(c.edicao,''),           d.edicao),
      local_publicacao = COALESCE(NULLIF(c.local_publicacao,''), d.local_publicacao),
      idioma           = COALESCE(NULLIF(c.idioma,''),           d.idioma),
      paginas          = COALESCE(c.paginas,                     d.paginas),  -- integer
      notas            = COALESCE(NULLIF(c.notas,''),            d.notas),
      assuntos         = COALESCE(NULLIF(c.assuntos,''),         d.assuntos),
      colecao          = COALESCE(NULLIF(c.colecao,''),          d.colecao),
      tradutor         = COALESCE(NULLIF(c.tradutor,''),         d.tradutor),
      organizador      = COALESCE(NULLIF(c.organizador,''),      d.organizador),
      updated_at = now()
    FROM public.books d WHERE c.id = v_canon AND d.id = v_dup;

    FOR dh IN SELECT * FROM public.book_holdings WHERE book_id = v_dup LOOP
      SELECT id INTO v_ch FROM public.book_holdings
       WHERE book_id = v_canon AND library_id = dh.library_id LIMIT 1;
      IF v_ch IS NOT NULL THEN
        UPDATE public.exemplares                SET holding_id = v_ch WHERE holding_id = dh.id;
        UPDATE public.emprestimo_itens_v2        SET holding_id = v_ch WHERE holding_id = dh.id;
        UPDATE public.reserva_linhas_v2          SET holding_id = v_ch WHERE holding_id = dh.id;
        UPDATE public.interlibrary_loan_items_v2 SET holding_id = v_ch WHERE holding_id = dh.id;
        UPDATE public.consulta_linhas_v2         SET holding_id = v_ch WHERE holding_id = dh.id;
        UPDATE public.exemplar_drafts            SET target_holding_id = v_ch WHERE target_holding_id = dh.id;
        DELETE FROM public.book_holdings WHERE id = dh.id;
      ELSE
        UPDATE public.book_holdings SET book_id = v_canon WHERE id = dh.id;
      END IF;
    END LOOP;

    UPDATE public.emprestimo_itens_v2        SET book_id = v_canon WHERE book_id = v_dup;
    UPDATE public.reserva_linhas_v2          SET book_id = v_canon WHERE book_id = v_dup;
    UPDATE public.interlibrary_loan_items_v2 SET book_id = v_canon WHERE book_id = v_dup;
    UPDATE public.consulta_linhas_v2         SET book_id = v_canon WHERE book_id = v_dup;
    UPDATE public.digital_assets             SET book_id = v_canon WHERE book_id = v_dup;

    DELETE FROM public.user_wishlist w
     WHERE w.book_id = v_dup
       AND EXISTS (SELECT 1 FROM public.user_wishlist w2 WHERE w2.user_id = w.user_id AND w2.book_id = v_canon);
    UPDATE public.user_wishlist SET book_id = v_canon WHERE book_id = v_dup;

    UPDATE public.book_drafts SET published_book_id = v_canon WHERE published_book_id = v_dup;

    INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
    VALUES ('book', v_canon, v_dup, jsonb_build_object('via', 'migration_dedup_cross_biblio_lot2'), NULL);

    DELETE FROM public.books WHERE id = v_dup;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_deleted := v_deleted + v_n;
  END LOOP;

  IF v_deleted <> 4 THEN
    RAISE EXCEPTION 'dedup lot2 : % doublon(s) supprime(s) au lieu de 4', v_deleted;
  END IF;

  PERFORM public.fn_v2_recompute_holdings_availability(NULL, ARRAY[2227,2299,2219,2345]::bigint[]);

  RAISE NOTICE 'fusion cross-biblio lot2 OK : % doublons fusionnes', v_deleted;
END
$merge$;

COMMIT;

-- =========================================================================
-- Rollback : non automatique (tracabilite dans merge_log).
-- =========================================================================
