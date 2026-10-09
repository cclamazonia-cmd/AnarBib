-- ═══════════════════════════════════════════════════════════════════════
-- AnarBib — C17 (CAT-E21, 09/10/2026) : un numéro d'inventaire donné ne se
-- redonne jamais.
--   T1 deux exemplaires numérotés par fn_next_tombo : 001, 002 ; les deux au registre ;
--   T2 le dernier (002) supprimé : le prochain numéro est 003, pas 002 ;
--   T3 002 redonné à la main à un exemplaire neuf : refusé, P0001,
--      HINT error.catalog.tombo.deja_attribue ;
--   T4 un exemplaire présent changé vers 002 : refusé ; vers 010 : accepté
--      (010 au registre, le prochain est 011) ; revenu à son propre 001 : accepté ;
--   T5 le numéro d'un exemplaire PRÉSENT redonné : 23505 exemplares_unique_tombo
--      (le chemin de rejeu de publish_exemplar_draft reste le sien) ;
--   T6 le registre est fermé à anon et authenticated ; les déclencheurs aussi ;
--      fn_next_tombo garde ses droits (authenticated, service_role ; pas anon).
-- Tout se fait sous postgres (les déclencheurs sont DEFINER) ; la suite lève
-- toujours (OK ou ECHEC) : rien ne reste en base.
-- Mutant éprouvé : sans le déclencheur APRÈS (registre), T2 rougit.
-- ═══════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf text := to_char(clock_timestamp(), 'SSMS') || floor(random() * 1000)::int;
  v_lib uuid; v_book bigint; v_hold bigint;
  v_x1 bigint; v_x2 bigint; v_x3 bigint;
  v_t1 text; v_t2 text; v_t3 text; v_txt text; v_hint text; v_state text; v_cons text; v_b boolean; v_n int;
BEGIN
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, tombo_pattern)
  VALUES ('c17-' || v_suf, 'C17 (essai)', 'federated', 'full_sigb', true, 'public', jsonb_build_object('prefix', 'C17' || v_suf || '-', 'pad', 3, 'year', false))
  RETURNING id INTO v_lib;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C17 (essai)', 'C17-' || v_suf, 'livro') RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib) RETURNING id INTO v_hold;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 deux exemplaires numérotés par fn_next_tombo (001, 002), tous deux au registre';
  BEGIN
    v_t1 := public.fn_next_tombo(v_lib);
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
    VALUES ('C17-' || v_suf, v_t1, v_lib, v_hold, 'ambos', 'public') RETURNING id INTO v_x1;
    v_t2 := public.fn_next_tombo(v_lib);
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
    VALUES ('C17-' || v_suf, v_t2, v_lib, v_hold, 'ambos', 'public') RETURNING id INTO v_x2;
    SELECT count(*) INTO v_n FROM public.tombos_attribues t WHERE t.tombo IN (v_t1, v_t2) AND t.exemplar_id IN (v_x1, v_x2) AND t.library_id = v_lib AND t.source = 'exemplar';
    v_b := v_t1 = 'C17' || v_suf || '-001' AND v_t2 = 'C17' || v_suf || '-002' AND v_n = 2;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s, %s, registre %s', v_t1, v_t2, v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 le dernier exemplaire supprimé : le prochain numéro est 003, pas 002 (le numéro reste au registre)';
  BEGIN
    DELETE FROM public.exemplares WHERE id = v_x2;
    v_t3 := public.fn_next_tombo(v_lib);
    v_b := v_t3 = 'C17' || v_suf || '-003'
       AND EXISTS (SELECT 1 FROM public.tombos_attribues t WHERE t.tombo = v_t2 AND t.exemplar_id = v_x2);
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : prochain %s', v_t3)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 002 redonné à la main à un exemplaire neuf : refusé (P0001, HINT error.catalog.tombo.deja_attribue)';
  BEGIN
    BEGIN
      INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
      VALUES ('C17-' || v_suf, v_t2, v_lib, v_hold, 'ambos', 'public') RETURNING id INTO v_x3;
      v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_state := SQLSTATE; v_txt := 'refusé';
    END;
    v_b := v_txt = 'refusé' AND v_state = 'P0001' AND v_hint = 'error.catalog.tombo.deja_attribue'
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.tombo = v_t2);
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s %s', v_txt, v_state, v_hint)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 un exemplaire présent changé vers 002 : refusé ; vers 010 : accepté et au registre (prochain 011) ; revenu à son 001 : accepté';
  BEGIN
    BEGIN
      UPDATE public.exemplares SET tombo = v_t2 WHERE id = v_x1; v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := 'refusé'; END;
    UPDATE public.exemplares SET tombo = 'C17' || v_suf || '-010' WHERE id = v_x1;
    v_t3 := public.fn_next_tombo(v_lib);
    UPDATE public.exemplares SET tombo = v_t1 WHERE id = v_x1;
    v_b := v_txt = 'refusé' AND v_hint = 'error.catalog.tombo.deja_attribue'
       AND v_t3 = 'C17' || v_suf || '-011'
       AND EXISTS (SELECT 1 FROM public.tombos_attribues t WHERE t.tombo = 'C17' || v_suf || '-010' AND t.exemplar_id = v_x1)
       AND (SELECT tombo FROM public.exemplares WHERE id = v_x1) = v_t1;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s, prochain %s', v_txt, v_t3)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 le numéro d''un exemplaire PRÉSENT redonné : 23505 exemplares_unique_tombo, pas le refus du registre';
  BEGIN
    BEGIN
      INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
      VALUES ('C17-' || v_suf, v_t1, v_lib, v_hold, 'ambos', 'public');
      v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_cons = CONSTRAINT_NAME; v_state := SQLSTATE; v_txt := 'refusé';
    END;
    v_b := v_txt = 'refusé' AND v_state = '23505' AND v_cons = 'exemplares_unique_tombo';
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s %s', v_txt, v_state, v_cons)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 registre et déclencheurs fermés à anon et authenticated ; fn_next_tombo garde ses droits';
  BEGIN
    v_b := NOT has_table_privilege('anon', 'public.tombos_attribues', 'SELECT')
       AND NOT has_table_privilege('authenticated', 'public.tombos_attribues', 'SELECT')
       AND NOT has_table_privilege('authenticated', 'public.tombos_attribues', 'INSERT')
       AND has_table_privilege('service_role', 'public.tombos_attribues', 'SELECT')
       AND NOT has_function_privilege('authenticated', 'public.tg_exemplar_tombo_jamais_redonne()', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.tg_exemplar_tombo_au_registre()', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'public.fn_next_tombo(uuid)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_next_tombo(uuid)', 'EXECUTE')
       AND has_function_privilege('service_role', 'public.fn_next_tombo(uuid)', 'EXECUTE');
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'TOMBO-JAMAIS-REDONNE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'TOMBO-JAMAIS-REDONNE OK : %/%', v_passed, v_passed;
END $$;
