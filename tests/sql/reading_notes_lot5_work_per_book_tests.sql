-- =====================================================================
-- AnarBib — Tests d'acceptation : UNE ŒUVRE PAR LIVRE (notes de lecture Lot 5)
-- Date : 2026-08-05 · Réf : migration 20260805090000_reading_notes_lot5_work_per_book.sql
--        Cadrage : docs/journal/cadrages/CADRAGE_notes_de_lecture_2026-08-01.md
--
-- Couvre le trigger trg_books_ensure_work (garantie work_id NOT NULL) :
--  - nouveau livre sans œuvre -> work_id auto, titre repris ;
--  - livre avec œuvre fournie (import/saisie) -> conservée, aucun doublon ;
--  - titre vide -> œuvre « (sans titre) » ;
--  - détachement (UPDATE work_id:=null) NON défait (trigger BEFORE INSERT only).
-- Superutilisateur (le trigger n'est pas conditionné par la RLS).
--   Bilan OK : 'READING-NOTES-LOT5 OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_book bigint; v_work bigint; v_book2 bigint; v_wid bigint; v_work3 bigint;
  v_title text; v_before int; v_after int;
BEGIN
  v_t := 'L1 nouveau livre sans œuvre -> work_id auto + titre repris';
  INSERT INTO public.books (titulo) VALUES ('Livre test Lot5 — A')
    RETURNING id, work_id INTO v_book, v_work;
  SELECT uniform_title INTO v_title FROM public.works WHERE id = v_work;
  IF v_work IS NOT NULL AND v_title = 'Livre test Lot5 — A' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' work='||coalesce(v_work::text,'∅')||' title='||coalesce(v_title,'∅')); END IF;

  v_t := 'L2 livre avec œuvre fournie -> conservée, pas de doublon';
  SELECT count(*) INTO v_before FROM public.works;
  INSERT INTO public.books (titulo, work_id) VALUES ('Livre test Lot5 — B', v_work)
    RETURNING id, work_id INTO v_book2, v_wid;
  SELECT count(*) INTO v_after FROM public.works;
  IF v_wid = v_work AND v_after = v_before THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' wid='||coalesce(v_wid::text,'∅')||' Δworks='||(v_after-v_before)); END IF;

  v_t := 'L3 titre vide/blanc -> œuvre « (sans titre) »';
  INSERT INTO public.books (titulo) VALUES ('   ') RETURNING work_id INTO v_work3;
  SELECT uniform_title INTO v_title FROM public.works WHERE id = v_work3;
  IF v_title = '(sans titre)' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' title='||coalesce(v_title,'∅')); END IF;

  v_t := 'L4 détachement (UPDATE work_id:=null) préservé (trigger INSERT-only)';
  UPDATE public.books SET work_id = NULL WHERE id = v_book;
  SELECT work_id INTO v_wid FROM public.books WHERE id = v_book;
  IF v_wid IS NULL THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' work_id='||coalesce(v_wid::text,'∅')); END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'READING-NOTES-LOT5 OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'READING-NOTES-LOT5 ECHEC : %/% OK, % échec(s) | %',
      v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || ');
  END IF;
END $$;
