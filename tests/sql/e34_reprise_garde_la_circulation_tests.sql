-- =====================================================================
-- AnarBib — Tests : la reprise d'une notice garde sa circulation (E34)
-- Date    : 2026-10-08
-- Ref     : 20261008172304_la_reprise_d_une_notice_garde_sa_circulation
--
-- Le défaut : « Éditer » (create_book_draft_from_book) ne recopiait pas
-- circulation_default ; le brouillon naissait 'emprestavel' et, publié tel
-- quel, le déclencheur fn_propagate_circulation_default_on_publish rendait
-- empruntable une notice en consultation sur place.
--
-- Couvre, sous le jeton d'une coordination de la bibliothèque de la notice :
--   T1 la reprise d'une notice en consultation naît 'consulta', loanable false ;
--   T2 publiée telle qu'elle naît, la notice reste en consultation, non
--      empruntable (le cas qui basculait) ;
--   T3 'ambos' : reprise puis publication, la notice reste 'ambos', loanable ;
--   T4 'emprestavel' : idem, chemin heureux d'avant (la valeur par défaut
--      cachait le défaut : il faut tester les DEUX valeurs, leçon du 27/08) ;
--   T5 garde pour les colonnes à venir : toute colonne commune à books et
--      book_drafts est recopiée par la reprise (b.<colonne>), hors les sept
--      exceptions voulues — une colonne neuve oubliée au troisième endroit
--      rougit ici avant de perdre des données.
--   Bilan OK : 'E34 OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib   constant uuid := '6e340000-0000-4000-8000-0000000000b1';
  c_coord constant uuid := '6e340000-0000-4000-8000-000000000001';
  v_consulta bigint; v_ambos bigint; v_emprestavel bigint;
  v_d bigint; v_circ text; v_loan boolean; v_src text; v_manquantes text[];
BEGIN
  -- ── Fixtures ──
  INSERT INTO public.libraries (id, slug, name, visibility_level, catalog_mode, network_mode, is_active)
  VALUES (c_lib, 'e34-reprise', 'Biblio de la reprise (test E34)', 'public', 'network_published', 'federated', true)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', c_coord, 'authenticated', 'authenticated', 'e34.coord@anarbib.local',
          now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (c_coord, 'e34.coord@anarbib.local', 'Coord', 'Reprise', 'fr') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (c_coord, c_lib, 'coordenador', 'active');

  -- Trois notices de la bibliothèque, une par circulation.
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, owner_library_id, circulation_default, loanable)
  VALUES ('Consulta sur place E34', 'Autor E34', 'E34-CONSULTA', 'livro', c_lib, 'consulta', false)
  RETURNING id INTO v_consulta;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, owner_library_id, circulation_default, loanable)
  VALUES ('Ambos E34', 'Autor E34', 'E34-AMBOS', 'livro', c_lib, 'ambos', true)
  RETURNING id INTO v_ambos;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, owner_library_id, circulation_default, loanable)
  VALUES ('Emprestavel E34', 'Autor E34', 'E34-EMPRESTAVEL', 'livro', c_lib, 'emprestavel', true)
  RETURNING id INTO v_emprestavel;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_coord, 'role', 'authenticated')::text, true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 la reprise d''une notice en consultation naît ''consulta'', non empruntable';
  BEGIN
    v_d := public.create_book_draft_from_book(v_consulta, NULL);
    SELECT circulation_default, loanable INTO v_circ, v_loan FROM public.book_drafts WHERE id = v_d;
    IF v_circ = 'consulta' AND v_loan = false THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : brouillon ' || coalesce(v_circ, '∅') || ' / loanable ' || coalesce(v_loan::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 publiée telle qu''elle naît, la notice reste en consulta, non empruntable';
  BEGIN
    PERFORM public.publish_book_draft(v_d);
    SELECT circulation_default, loanable INTO v_circ, v_loan FROM public.books WHERE id = v_consulta;
    IF v_circ = 'consulta' AND v_loan = false THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : notice ' || coalesce(v_circ, '∅') || ' / loanable ' || coalesce(v_loan::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 ''ambos'' : reprise puis publication, la notice reste ''ambos'', empruntable';
  BEGIN
    v_d := public.create_book_draft_from_book(v_ambos, NULL);
    SELECT circulation_default INTO v_circ FROM public.book_drafts WHERE id = v_d;
    IF v_circ <> 'ambos' THEN RAISE EXCEPTION 'brouillon %', coalesce(v_circ, '∅'); END IF;
    PERFORM public.publish_book_draft(v_d);
    SELECT circulation_default, loanable INTO v_circ, v_loan FROM public.books WHERE id = v_ambos;
    IF v_circ = 'ambos' AND v_loan = true THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : notice ' || coalesce(v_circ, '∅') || ' / loanable ' || coalesce(v_loan::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 ''emprestavel'' : reprise puis publication, inchangé (chemin heureux)';
  BEGIN
    v_d := public.create_book_draft_from_book(v_emprestavel, NULL);
    PERFORM public.publish_book_draft(v_d);
    SELECT circulation_default, loanable INTO v_circ, v_loan FROM public.books WHERE id = v_emprestavel;
    IF v_circ = 'emprestavel' AND v_loan = true THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : notice ' || coalesce(v_circ, '∅') || ' / loanable ' || coalesce(v_loan::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  PERFORM set_config('request.jwt.claims', '', true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 toute colonne commune à books et book_drafts est recopiée par la reprise';
  BEGIN
    SELECT p.prosrc INTO v_src FROM pg_proc p
     WHERE p.oid = 'public.create_book_draft_from_book(bigint, bigint)'::regprocedure;
    SELECT coalesce(array_agg(b.column_name ORDER BY b.column_name), '{}') INTO v_manquantes
      FROM information_schema.columns b
      JOIN information_schema.columns d
        ON d.table_schema = 'public' AND d.table_name = 'book_drafts' AND d.column_name = b.column_name
     WHERE b.table_schema = 'public' AND b.table_name = 'books'
       -- posées par la reprise ; work_id en coalesce à la publication ;
       -- publisher_id déduit d'editora par déclencheur (en-tête de la migration)
       AND b.column_name NOT IN ('id', 'created_at', 'updated_at', 'created_by', 'updated_by', 'work_id', 'publisher_id')
       AND v_src !~ ('\mb\.' || b.column_name || '\M');
    IF cardinality(v_manquantes) = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : non recopiées ' || array_to_string(v_manquantes, ',')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'E34 ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'E34 OK : %/%', v_passed, v_passed;
END $$;
