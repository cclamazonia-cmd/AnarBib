-- =========================================================================
-- Paquet doublons P2b — fusion de documents (merge_book)
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Doublons (spec-doublons-detection-fusion v0.1)
-- Auteur   : Xavier + Claude
--
-- DECISIONS (05/06)
--   Q-doc-A : conflit de holding (meme bibliotheque) -> FUSIONNER les holdings
--             (deplacer exemplaires vers le holding canonique, supprimer le
--             holding doublon).
--   Q-doc-B : circulation en cours (prets/reservations/PEB) -> REPOINTER vers
--             le canonique (pas de blocage).
--   Q-doc-C : wishlist -> repointer (dedupe) ; metadonnees du doublon -> jetees
--             (cascade ; le canonique fait foi).
--
-- SECURITE : les exemplaires ne sont JAMAIS supprimes (ils changent de holding
-- ou restent) -> les references circulation par item_id (consulta/emprestimo/
-- PEB, RESTRICT) restent valides. Avant de supprimer un holding doublon, on
-- repointe toutes les references holding_id vers le holding canonique.
-- Compteurs recalcules via fn_v2_recompute_holdings_availability.
--
-- DOCTRINE : SECURITY DEFINER + search_path + REVOKE PUBLIC + GRANT staff +
-- journalisation merge_log. Validation humaine cote UI.
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.merge_book(p_canonical_id bigint, p_duplicate_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_dup_titulo text;
  dh           record;
  v_ch_id      bigint;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  IF p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Canonico e duplicado identicos.';
  END IF;
  SELECT titulo INTO v_dup_titulo FROM public.books WHERE id = p_duplicate_id;
  IF v_dup_titulo IS NULL THEN
    RAISE EXCEPTION 'Duplicado % inexistente.', p_duplicate_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = p_canonical_id) THEN
    RAISE EXCEPTION 'Canonico % inexistente.', p_canonical_id;
  END IF;

  -- 1. Holdings : fusionner (meme bibliotheque) ou repointer.
  FOR dh IN SELECT * FROM public.book_holdings WHERE book_id = p_duplicate_id LOOP
    SELECT id INTO v_ch_id
      FROM public.book_holdings
      WHERE book_id = p_canonical_id AND library_id = dh.library_id
      LIMIT 1;

    IF v_ch_id IS NOT NULL THEN
      -- Fusion : tout ce qui pointe vers le holding doublon bascule sur le canonique.
      UPDATE public.exemplares               SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.emprestimo_itens_v2       SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.reserva_linhas_v2         SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.interlibrary_loan_items_v2 SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.consulta_linhas_v2        SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.exemplar_drafts           SET target_holding_id = v_ch_id WHERE target_holding_id = dh.id;
      DELETE FROM public.book_holdings WHERE id = dh.id;
    ELSE
      -- Repoint : le holding (avec ses exemplaires et refs) bascule sur le canonique.
      UPDATE public.book_holdings SET book_id = p_canonical_id WHERE id = dh.id;
    END IF;
  END LOOP;

  -- 2. Circulation au niveau livre : repoint book_id (caches/FK).
  UPDATE public.emprestimo_itens_v2        SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;
  UPDATE public.reserva_linhas_v2          SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;
  UPDATE public.interlibrary_loan_items_v2 SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;
  UPDATE public.consulta_linhas_v2         SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;

  -- 3. Ressources numeriques.
  UPDATE public.digital_assets SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;

  -- 4. Wishlist : dedupe (UNIQUE user_id,book_id) puis repoint.
  DELETE FROM public.user_wishlist w
    WHERE w.book_id = p_duplicate_id
      AND EXISTS (SELECT 1 FROM public.user_wishlist w2
                  WHERE w2.user_id = w.user_id AND w2.book_id = p_canonical_id);
  UPDATE public.user_wishlist SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;

  -- 5. Brouillons pointant vers le doublon.
  UPDATE public.book_drafts SET published_book_id = p_canonical_id WHERE published_book_id = p_duplicate_id;

  -- 6. Journaliser.
  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('book', p_canonical_id, p_duplicate_id,
          jsonb_build_object('duplicate_titulo', v_dup_titulo), auth.uid());

  -- 7. Supprimer le doublon (cascade : book_authors/contributors/catalog_context).
  DELETE FROM public.books WHERE id = p_duplicate_id;

  -- 8. Recalcul des compteurs de disponibilite du canonique.
  PERFORM public.fn_v2_recompute_holdings_availability(NULL, ARRAY[p_canonical_id]);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.merge_book(bigint, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.merge_book(bigint, bigint) TO authenticated;

COMMENT ON FUNCTION public.merge_book(bigint, bigint) IS
  'Fusionne le livre doublon dans le canonique (holdings/exemplaires, circulation, wishlist, journalise, supprime). Paquet doublons P2b du 05/06/2026.';

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback : DROP FUNCTION IF EXISTS public.merge_book(bigint, bigint);
-- =========================================================================
