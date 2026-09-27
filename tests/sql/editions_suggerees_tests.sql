-- =====================================================================
-- AnarBib — Tests d'acceptation : la suggestion d'éditions répond
-- Date : 2026-09-27 · Migration 20260927194141_fusion_btl_tl_000880_dans_000881_et_suggestion_d_editions
--
-- POURQUOI. `suggest_editions_for_book` plantait à CHAQUE appel depuis sa
-- création (20/06/2026) : « column reference "book_id" is ambiguous » (42702),
-- la colonne de book_authors portant le nom d'une colonne de sortie. Aucun
-- test ne l'appelait : un chemin jamais exécuté n'est pas un chemin qui
-- marche. Relevé à l'écran par Xavier le 27/09 (« Erreur technique (42702) »).
--   Bilan OK : 'EDITIONS SUGGEREES OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_staff  constant uuid := '11111111-1111-1111-1111-111111111111';   -- coordenador blmf-test (seed)
  c_reader constant uuid := '33333333-3333-3333-3333-333333333333';   -- lectrice blmf-test (seed)
  v_reclus bigint; v_autre bigint;
  b_a bigint; b_b bigint; b_c bigint; b_d bigint;
  v_ids bigint[]; v_err text;
BEGIN
  INSERT INTO public.authors (preferred_name, sort_name) VALUES ('Élisée Reclus', 'Reclus, Élisée') RETURNING id INTO v_reclus;
  INSERT INTO public.authors (preferred_name, sort_name) VALUES ('Autre Personne', 'Personne, Autre') RETURNING id INTO v_autre;

  INSERT INTO public.books (titulo, bib_ref, tipo_material, ano) VALUES ('Da Escravidão nos Estados Unidos', 'TEST-ED-A', 'livro', '2010') RETURNING id INTO b_a;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, ano) VALUES ('Da escravidao nos Estados Unidos', 'TEST-ED-B', 'livro', '2011') RETURNING id INTO b_b;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('O homem e a terra', 'TEST-ED-C', 'livro') RETURNING id INTO b_c;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Da Escravidão nos Estados Unidos', 'TEST-ED-D', 'livro') RETURNING id INTO b_d;
  -- Deux notices du même titre et de la même autrice·eur, dans deux œuvres (une par notice
  -- à la création) : c'est exactement le cas que la suggestion doit rapprocher.
  INSERT INTO public.book_authors (book_id, author_id, role, ord) VALUES
    (b_a, v_reclus, 'autor', 1), (b_b, v_reclus, 'autor', 1), (b_c, v_reclus, 'autor', 1), (b_d, v_autre, 'autor', 1)
  ON CONFLICT DO NOTHING;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_staff, 'role', 'authenticated')::text, true);

  v_t := 'T1 la suggestion répond (plus de 42702) et propose l''autre notice du même titre et de la même autrice·eur';
  v_ids := NULL; v_err := NULL;
  BEGIN
    SELECT array_agg(book_id ORDER BY book_id) INTO v_ids FROM public.suggest_editions_for_book(b_a);
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM; END;
  IF v_err IS NULL AND v_ids = ARRAY[b_b] THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, v_ids::text, 'rien')); END IF;

  v_t := 'T2 ni un autre titre de la même autrice·eur, ni le même titre d''une autre personne';
  IF v_err IS NULL AND NOT (b_c = ANY (coalesce(v_ids, '{}'))) AND NOT (b_d = ANY (coalesce(v_ids, '{}'))) THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  v_t := 'T3 une notice sans autrice·eur principal·e : rien à proposer, sans erreur';
  v_ids := NULL; v_err := NULL;
  BEGIN
    SELECT array_agg(book_id) INTO v_ids FROM public.suggest_editions_for_book(
      (SELECT id FROM public.books WHERE bib_ref = 'TEST-CIRC-1'));
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM; END;
  IF v_err IS NULL AND v_ids IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, v_ids::text)); END IF;

  v_t := 'T4 une lectrice n''y a pas accès (42501)';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_reader, 'role', 'authenticated')::text, true);
  v_err := NULL;
  BEGIN PERFORM * FROM public.suggest_editions_for_book(b_a); EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE; END;
  IF v_err = '42501' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'accès rendu')); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'EDITIONS SUGGEREES ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed,
      array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'EDITIONS SUGGEREES OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
