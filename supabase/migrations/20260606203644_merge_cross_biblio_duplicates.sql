-- =========================================================================
-- Paquet data — fusion des doublons de notices cross-bibliotheque (lot 1)
-- =========================================================================
-- Session  : Exemplaires & nettoyage catalogue
-- Auteur   : Xavier + Claude
-- Chantier : Nettoyage catalogue / notices partagees
--
-- CONTEXTE
-- --------
-- 13 oeuvres existaient en DOUBLE : une notice par bibliotheque (meme titre +
-- meme annee + meme autorite d'auteur), au lieu d'UNE notice partagee a deux
-- holdings. Souvent la notice BLMF porte la cover, la BTL est un import plus
-- pauvre. On fusionne dans le canonique (celui qui a la cover / le plus complet)
-- en preservant les holdings + exemplaires + circulation des deux biblios.
--
-- Liste VALIDEE par Xavier (cle titre+annee+autorite). 14 doublons -> 13
-- canoniques (Os Sindicatos operarios... a 2 doublons).
--
-- merge_book() ne peut pas tourner en migration (garde auth.uid()) : on inline
-- sa logique (re-point holdings/exemplaires/circulation, dedup wishlist,
-- repoint drafts, log, suppression) + un backfill prealable des champs vides
-- du canonique depuis le doublon (cover, editora, cdd, isbn, etc.).
-- Transaction : tout ou rien. Garde : exactement 14 doublons supprimes.
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
  -- Garde : les 14 doublons attendus sont bien presents.
  IF (SELECT count(*) FROM public.books WHERE id IN
        (228,208,334,323,684,520,849,1411,1148,1816,1750,1663,1669,2093)) <> 14 THEN
    RAISE EXCEPTION 'abort : la liste de doublons attendue (14) ne correspond plus a la base.';
  END IF;

  FOR rec IN SELECT * FROM (VALUES
    (2284::bigint, 228::bigint),
    (2286, 208),
    (2281, 334),
    (2296, 323),
    (2325, 684),
    (2317, 520),
    (2441, 849),
    (2287, 1411),
    (2434, 1148),
    (2447, 1816),
    (2335, 1750),
    (2311, 1663),
    (2311, 1669),
    (2332, 2093)
  ) AS p(canon, dup)
  LOOP
    v_canon := rec.canon; v_dup := rec.dup;

    -- Backfill : ne remplit QUE les champs vides du canonique depuis le doublon.
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
      paginas          = COALESCE(NULLIF(c.paginas,''),          d.paginas),
      notas            = COALESCE(NULLIF(c.notas,''),            d.notas),
      assuntos         = COALESCE(NULLIF(c.assuntos,''),         d.assuntos),
      colecao          = COALESCE(NULLIF(c.colecao,''),          d.colecao),
      tradutor         = COALESCE(NULLIF(c.tradutor,''),         d.tradutor),
      organizador      = COALESCE(NULLIF(c.organizador,''),      d.organizador),
      updated_at = now()
    FROM public.books d WHERE c.id = v_canon AND d.id = v_dup;

    -- 1. Holdings : fusionner (meme biblio) ou repointer vers le canonique.
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

    -- 2. Circulation au niveau livre.
    UPDATE public.emprestimo_itens_v2        SET book_id = v_canon WHERE book_id = v_dup;
    UPDATE public.reserva_linhas_v2          SET book_id = v_canon WHERE book_id = v_dup;
    UPDATE public.interlibrary_loan_items_v2 SET book_id = v_canon WHERE book_id = v_dup;
    UPDATE public.consulta_linhas_v2         SET book_id = v_canon WHERE book_id = v_dup;

    -- 3. Ressources numeriques.
    UPDATE public.digital_assets SET book_id = v_canon WHERE book_id = v_dup;

    -- 4. Wishlist : dedup (UNIQUE user_id,book_id) puis repoint.
    DELETE FROM public.user_wishlist w
     WHERE w.book_id = v_dup
       AND EXISTS (SELECT 1 FROM public.user_wishlist w2 WHERE w2.user_id = w.user_id AND w2.book_id = v_canon);
    UPDATE public.user_wishlist SET book_id = v_canon WHERE book_id = v_dup;

    -- 5. Brouillons pointant vers le doublon.
    UPDATE public.book_drafts SET published_book_id = v_canon WHERE published_book_id = v_dup;

    -- 6. Journal.
    INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
    VALUES ('book', v_canon, v_dup,
            jsonb_build_object('via', 'migration_dedup_cross_biblio'), NULL);

    -- 7. Supprimer le doublon (cascade : book_authors/contributors/catalog_context).
    DELETE FROM public.books WHERE id = v_dup;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_deleted := v_deleted + v_n;
  END LOOP;

  IF v_deleted <> 14 THEN
    RAISE EXCEPTION 'dedup : % doublon(s) supprime(s) au lieu de 14', v_deleted;
  END IF;

  -- 8. Recalcul des compteurs de disponibilite des canoniques.
  PERFORM public.fn_v2_recompute_holdings_availability(
    NULL, ARRAY[2284,2286,2281,2296,2325,2317,2441,2287,2434,2447,2335,2311,2332]::bigint[]);

  RAISE NOTICE 'fusion cross-biblio OK : % doublons fusionnes dans 13 canoniques', v_deleted;
END
$merge$;

COMMIT;

-- =========================================================================
-- Rollback : non automatique (doublons supprimes volontairement ; tracabilite
-- dans merge_log). Restauration via sauvegarde si besoin.
-- =========================================================================
