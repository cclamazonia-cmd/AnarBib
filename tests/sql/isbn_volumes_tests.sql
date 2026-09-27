-- =====================================================================
-- AnarBib — Tests d'acceptation : un ISBN d'ensemble est porté par chacun de
-- ses volumes
-- Date : 2026-09-27 · Migration 20260927164619_un_isbn_d_ensemble_est_porte_par_chacun_de_ses_volumes
--
-- POURQUOI. publish_book_draft refusait toute notice neuve dont l'ISBN existait
-- déjà (isbn_duplicado), en conseillant d'« ajouter un exemplaire à la notice
-- existante ». Or BTL-TL-000447 et BTL-TL-000448 sont les volumes 2 et 3 d'un
-- même ensemble, sous un seul ISBN : le volume 4, catalogué à la main, aurait
-- été refusé — et enregistré comme exemplaire du volume 2 sur ce conseil.
-- Leçon du 27/08 (serial_id) : tester les deux valeurs de chaque côté —
-- volume présent, volume absent, identique, différent.
--   Bilan OK : 'ISBN VOLUMES OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_staff uuid; v_lib uuid;
  v_draft bigint; v_book bigint; v_err text;
  c_isbn constant text := '84-87169-02-3';
  c_isbn_seul constant text := '978-2-296-03507-2';
BEGIN
  SELECT m.user_id, m.library_id INTO v_staff, v_lib
    FROM public.user_library_memberships m
   WHERE m.status = 'active' AND m.role IN ('librarian','coordenador')
   ORDER BY (m.role = 'coordenador') DESC
   LIMIT 1;
  IF v_staff IS NULL THEN
    RAISE EXCEPTION 'ISBN VOLUMES ECHEC : aucun membre staff dans le seed, la suite ne peut rien mesurer.';
  END IF;
  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_staff, 'role', 'authenticated')::text, true);

  -- Le banc part d'un seed : on s'assure qu'aucune notice ne porte déjà ces ISBN.
  UPDATE public.books SET isbn = NULL
   WHERE regexp_replace(upper(coalesce(isbn,'')), '[^0-9X]', '', 'g') IN ('8487169023', '9782296035072');

  -- ── Un ensemble : le volume 2 d'abord ─────────────────────────────
  v_t := 'T1 volume 2 : publié (aucune notice ne porte encore cet ISBN)';
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, isbn, volume, created_by)
  VALUES ('create', 'draft', 'TEST-VOL-2', 'La C.N.T. y la Revolución Española', 'livro', v_lib, c_isbn, '2', v_staff)
  RETURNING id INTO v_draft;
  BEGIN
    v_book := public.publish_book_draft(v_draft);
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  v_t := 'T2 volume 3, même ISBN : publié — un autre volume n''est pas un doublon';
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, isbn, volume, created_by)
  VALUES ('create', 'draft', 'TEST-VOL-3', 'La C.N.T. y la Revolución Española', 'livro', v_lib, c_isbn, '3', v_staff)
  RETURNING id INTO v_draft;
  BEGIN
    PERFORM public.publish_book_draft(v_draft);
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ── Ce qui reste un doublon ───────────────────────────────────────
  v_t := 'T3 même ISBN, SANS volume : refusé (isbn_duplicado), comme avant';
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, isbn, created_by)
  VALUES ('create', 'draft', 'TEST-VOL-SANS', 'La C.N.T. y la Revolución Española', 'livro', v_lib, c_isbn, v_staff)
  RETURNING id INTO v_draft;
  v_err := NULL;
  BEGIN PERFORM public.publish_book_draft(v_draft); EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err LIKE 'isbn_duplicado%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'accepté')); END IF;

  v_t := 'T4 même ISBN, MÊME volume (2) : refusé';
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, isbn, volume, created_by)
  VALUES ('create', 'draft', 'TEST-VOL-2BIS', 'La C.N.T. y la Revolución Española', 'livro', v_lib, c_isbn, '2', v_staff)
  RETURNING id INTO v_draft;
  v_err := NULL;
  BEGIN PERFORM public.publish_book_draft(v_draft); EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err LIKE 'isbn_duplicado%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'accepté')); END IF;

  v_t := 'T5 même volume écrit autrement (« 3 » entouré d''espaces) : refusé';
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, isbn, volume, created_by)
  VALUES ('create', 'draft', 'TEST-VOL-3BIS', 'La C.N.T. y la Revolución Española', 'livro', v_lib, c_isbn, ' 3 ', v_staff)
  RETURNING id INTO v_draft;
  v_err := NULL;
  BEGIN PERFORM public.publish_book_draft(v_draft); EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err LIKE 'isbn_duplicado%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'accepté')); END IF;

  v_t := 'T6 notice existante SANS volume, brouillon AVEC volume : refusé (on ne sait pas que c''est un ensemble)';
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, isbn, created_by)
  VALUES ('create', 'draft', 'TEST-SEUL-1', 'L''anarchisme aujourd''hui', 'livro', v_lib, c_isbn_seul, v_staff)
  RETURNING id INTO v_draft;
  PERFORM public.publish_book_draft(v_draft);
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, isbn, volume, created_by)
  VALUES ('create', 'draft', 'TEST-SEUL-2', 'L''anarchisme aujourd''hui', 'livro', v_lib, c_isbn_seul, '1', v_staff)
  RETURNING id INTO v_draft;
  v_err := NULL;
  BEGIN PERFORM public.publish_book_draft(v_draft); EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err LIKE 'isbn_duplicado%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'accepté')); END IF;

  -- ── Bilan (le RAISE annule toutes les fixtures) ────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ISBN VOLUMES OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'ISBN VOLUMES ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
