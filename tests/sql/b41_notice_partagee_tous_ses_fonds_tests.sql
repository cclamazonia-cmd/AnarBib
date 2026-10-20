-- =====================================================================
-- AnarBib — Tests d'acceptation : une notice partagée compte tous ses fonds
-- Date    : 2026-10-20
-- Ref     : migration 20261020193346_b41_une_notice_partagee_compte_tous_ses_fonds
--
-- Fixture : une notice détenue par BLMF (seed, 2 exemplaires publics) et par
-- une bibliothèque B posée ici (1 exemplaire public) ; une lectrice du seed.
-- T1 recompte complet (sans argument) : la notice vaut 3, comme avant.
-- T2 un prêt ouvert à BLMF, recompte du SEUL fonds de BLMF : la notice vaut
--    1 + 1 = 2 (avant B41 : 1, l'exemplaire de B oublié jusqu'à la nuit).
-- T3 une réservation active chez B, recompte du SEUL fonds de B : la notice
--    vaut 1 + 0 = 1 (avant : 0, « indisponible » alors que BLMF peut prêter).
-- T4 un fonds qui ne bouge pas garde son compte et sa date ; la notice
--    égale la disponibilité que montre sa page publique (somme des fonds).
-- T5 recompte d'une notice (p_book_ids) et recompte complet : même résultat.
-- T6 private.fn_h34_recompter_fonds_notes, deux fonds de la notice notés :
--    un seul appel, la notice vaut la somme.
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'B41-NOTICE-PARTAGEE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_lect uuid := '33333333-3333-3333-3333-333333333333';  -- lectrice BLMF (seed)
  v_lib  uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB uuid := gen_random_uuid();
  v_b bigint; v_hA bigint; v_hB bigint; v_eA1 bigint; v_eB bigint; v_emp bigint; v_resv bigint;
  v_n int; v_d timestamptz; v_x text;
BEGIN
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (v_libB, 'b41-tests-b', 'B41 Biblio B', true, 'public');
  INSERT INTO public.books (titulo, bib_ref) VALUES ('B41 notice partagée', 'B41-REF-1') RETURNING id INTO v_b;
  INSERT INTO public.book_holdings (book_id, library_id, loanable) VALUES (v_b, v_lib, true) RETURNING id INTO v_hA;
  INSERT INTO public.book_holdings (book_id, library_id, loanable) VALUES (v_b, v_libB, true) RETURNING id INTO v_hB;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy)
  VALUES ('B41-REF-1', 'B41A-1', v_lib, v_hA, 'ambos') RETURNING id INTO v_eA1;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy)
  VALUES ('B41-REF-1', 'B41A-2', v_lib, v_hA, 'ambos');
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy)
  VALUES ('B41-REF-1', 'B41B-1', v_libB, v_hB, 'ambos') RETURNING id INTO v_eB;

  v_t := 'T1 recompte complet : la notice vaut 3';
  BEGIN
    PERFORM public.fn_v2_recompute_holdings_availability();
    SELECT available_count INTO v_n FROM public.books WHERE id = v_b;
    IF v_n = 3 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_n::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T2 un prêt à BLMF, son seul fonds recompté : la notice vaut 2';
  BEGIN
    INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
    VALUES (v_lect, v_lib, 'aberto', current_date + 30) RETURNING id INTO v_emp;
    INSERT INTO public.emprestimo_itens_v2 (emprestimo_id, line_no, sub_id, book_id, item_id, holding_id, bib_ref, due_at)
    VALUES (v_emp, 1, v_emp || '.1', v_b, v_eA1, v_hA, 'B41-REF-1', current_date + 30);
    SELECT updated_at INTO v_d FROM public.book_holdings WHERE id = v_hB;
    PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_hA]);
    SELECT b.available_count || '|' || hA.available_count || '|' || hB.available_count INTO v_x
      FROM public.books b, public.book_holdings hA, public.book_holdings hB
     WHERE b.id = v_b AND hA.id = v_hA AND hB.id = v_hB;
    IF v_x = '2|1|1' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : notice|A|B = '||coalesce(v_x,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 une réservation chez B, son seul fonds recompté : la notice vaut 1';
  BEGIN
    INSERT INTO public.reservas_v2 (user_id, library_id, status_global) VALUES (v_lect, v_libB, 'ativa') RETURNING id INTO v_resv;
    INSERT INTO public.reserva_linhas_v2 (reserva_id, line_no, book_id, item_id, holding_id, bib_ref)
    VALUES (v_resv, 1, v_b, NULL, v_hB, 'B41-REF-1');
    PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_hB]);
    SELECT b.available_count || '|' || hA.available_count || '|' || hB.available_count INTO v_x
      FROM public.books b, public.book_holdings hA, public.book_holdings hB
     WHERE b.id = v_b AND hA.id = v_hA AND hB.id = v_hB;
    IF v_x = '1|1|0' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : notice|A|B = '||coalesce(v_x,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T4 le fonds non visé garde sa date ; la notice égale sa page publique';
  BEGIN
    SELECT updated_at INTO v_d FROM public.book_holdings WHERE id = v_hA;
    PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_hB]);
    IF (SELECT updated_at FROM public.book_holdings WHERE id = v_hA) IS DISTINCT FROM v_d THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : fonds A retouché');
    ELSIF (SELECT available_count FROM public.books WHERE id = v_b)
          IS DISTINCT FROM (SELECT available_count FROM public.v_book_detail_public_v2 WHERE id = v_b) THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : notice '||(SELECT available_count FROM public.books WHERE id = v_b)
        ||' ≠ page '||coalesce((SELECT available_count FROM public.v_book_detail_public_v2 WHERE id = v_b)::text, '∅'));
    ELSE v_passed := v_passed+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T5 par notice ou complet : même résultat';
  BEGIN
    UPDATE public.books SET available_count = 77 WHERE id = v_b;
    PERFORM public.fn_v2_recompute_holdings_availability(p_book_ids := ARRAY[v_b]);
    v_x := (SELECT available_count::text FROM public.books WHERE id = v_b);
    UPDATE public.books SET available_count = 77 WHERE id = v_b;
    PERFORM public.fn_v2_recompute_holdings_availability();
    v_x := v_x || '|' || (SELECT available_count::text FROM public.books WHERE id = v_b);
    IF v_x = '1|1' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_x,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T6 fn_h34_recompter_fonds_notes, deux fonds notés : la notice vaut la somme';
  DECLARE v_r int;
  BEGIN
    UPDATE public.book_holdings SET available_count = 50 WHERE id IN (v_hA, v_hB);
    UPDATE public.books SET available_count = 77 WHERE id = v_b;
    PERFORM set_config('anarbib.h34_fonds_notes', ',' || v_hB || ',' || v_hA || ',', true);
    PERFORM set_config('anarbib.h34_disponibilite_differee', 'on', true);
    v_r := private.fn_h34_recompter_fonds_notes();
    SELECT b.available_count || '|' || hA.available_count || '|' || hB.available_count INTO v_x
      FROM public.books b, public.book_holdings hA, public.book_holdings hB
     WHERE b.id = v_b AND hA.id = v_hA AND hB.id = v_hB;
    IF v_r = 2 AND v_x = '1|1|0' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rendu '||v_r||', notice|A|B = '||coalesce(v_x,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'B41-NOTICE-PARTAGEE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'B41-NOTICE-PARTAGEE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
