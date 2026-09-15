-- =====================================================================
-- AnarBib — Tests d'acceptation : numerotation et rangement d'une
-- bibliotheque (E21) — serie de tombos et cote reglees depuis l'ecran,
-- cotes d'un lot en un geste, classes de rangement par table de rubriques
-- Date    : 2026-09-15  ·  Session : catalogage / ce qu'il faut pour publier
-- Ref     : migration 20260915201252_numerotation_et_rangement_d_une_bibliotheque
--
-- T1-T5 : la numerotation (qui, quoi, unique dans le reseau, figee apres
-- usage). T6-T9 : les cotes d'un lot (apercu sans ecriture, application dans
-- l'ordre, a la suite de l'existant, refus). T10-T12 : les rubriques (lues la
-- ou l'import les laisse, table -> classe, classe existante respectee).
-- T13 : les droits. Les refus sont confrontes au HINT reel.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'NUMEROTATION-RANGEMENT OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord  uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_reader uuid := '33333333-3333-3333-3333-333333333333';  -- reader BLMF (seed)
  v_other  uuid := '22222222-2222-2222-2222-222222222222';  -- sans role (seed)
  v_lib    uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_lib2   uuid;
  v_lot bigint; v_lot2 bigint;
  v_d1 bigint; v_d2 bigint; v_d3 bigint; v_d4 bigint; v_d5 bigint;
  v_res jsonb; v_hint text; v_n int; v_txt text;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-numerotation', 'Essai — Numerotation', false, 'private')
  RETURNING id INTO v_lib2;
  -- coord de BLMF aussi coordenador de lib2, pour T3 et T7 (deux series, meme personne)
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_coord, v_lib2, 'coordenador', 'active', false);
  -- BLMF sans serie ni cote au depart (le seed n'en pose pas ; on s'en assure)
  UPDATE public.libraries SET tombo_pattern = NULL, bib_ref_prefix = NULL, bib_ref_pad = NULL, bib_ref_auto = false WHERE id = v_lib;

  -- ── T1 : lire avant de regler ─────────────────────────────────────────
  v_t := 'T1 fn_library_numbering_get sans serie : next_tombo nul, tombo_frozen faux, la biblio nommee';
  BEGIN
    v_res := public.fn_library_numbering_get(v_lib);
    IF v_res->>'next_tombo' IS NULL AND (v_res->>'tombo_frozen')::boolean = false
       AND v_res->>'library_name' = 'BLMF (base de test)' AND (v_res->>'bib_ref_auto')::boolean = false
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_res::text,300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 : la coordination regle, et l'exemple suit ─────────────────────
  v_t := 'T2 la coordination regle la serie et la cote : next_tombo ESSAI-00001, next_bib_ref ESS-00001, JSON complet';
  BEGIN
    v_res := public.fn_library_numbering_set(v_lib, ' ESSAI- ', false, '', 5, 'ESS-', 5, true);
    IF v_res->>'next_tombo' = 'ESSAI-00001' AND v_res->>'next_bib_ref' = 'ESS-00001'
       AND (SELECT l.tombo_pattern FROM public.libraries l WHERE l.id = v_lib) = '{"pad": 5, "sep": "", "year": false, "prefix": "ESSAI-"}'::jsonb
       AND (SELECT l.bib_ref_prefix FROM public.libraries l WHERE l.id = v_lib) = 'ESS-'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_res::text,300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2b : avec millesime ──────────────────────────────────────────────
  v_t := 'T2b annee + separateur : next_tombo = ESSAI-<annee>.00001 (pas encore fige : aucun exemplaire)';
  BEGIN
    v_res := public.fn_library_numbering_set(v_lib, 'ESSAI-', true, '.', 5, 'ESS-', 5, true);
    IF v_res->>'next_tombo' = 'ESSAI-' || to_char(current_date, 'YYYY') || '.00001' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_res->>'next_tombo','NULL')); END IF;
    PERFORM public.fn_library_numbering_set(v_lib, 'ESSAI-', false, '', 5, 'ESS-', 5, true);
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 : unique dans le reseau ────────────────────────────────────────
  v_t := 'T3 un prefixe deja pris, ou qui en contient un autre, est refuse pour une autre biblio (prefix_taken) ; un autre passe';
  BEGIN
    v_txt := '';
    BEGIN PERFORM public.fn_library_numbering_set(v_lib2, 'essai-', false, '', 4, 'E2-', 4, true);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    BEGIN PERFORM public.fn_library_numbering_set(v_lib2, 'ESS', false, '', 4, 'E2-', 4, true);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    BEGIN PERFORM public.fn_library_numbering_set(v_lib2, 'ESSAI-X-', false, '', 4, 'E2-', 4, true);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    BEGIN PERFORM public.fn_library_numbering_set(v_lib2, 'AUTRE-', false, '', 4, 'ESS-', 4, true);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    v_res := public.fn_library_numbering_set(v_lib2, 'AUTRE-', false, '', 4, 'AUT-', 4, true);
    IF v_txt = 'error.numbering.prefix_taken;error.numbering.prefix_taken;error.numbering.prefix_taken;error.numbering.bibref_prefix_taken;'
       AND v_res->>'next_tombo' = 'AUTRE-0001'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt||' / '||coalesce(v_res->>'next_tombo','NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 : refus de forme ───────────────────────────────────────────────
  v_t := 'T4 prefixe vide, joker SQL, remplissage hors bornes : refuses';
  BEGIN
    v_txt := '';
    BEGIN PERFORM public.fn_library_numbering_set(v_lib, '  ', false, '', 5, 'ESS-', 5, true);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    BEGIN PERFORM public.fn_library_numbering_set(v_lib, 'ES_', false, '', 5, 'ESS-', 5, true);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    BEGIN PERFORM public.fn_library_numbering_set(v_lib, 'ESSAI-', false, '', 9, 'ESS-', 5, true);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    IF v_txt = 'error.numbering.prefix_required;error.numbering.prefix_chars;error.numbering.pad_range;' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 : figee des qu'un exemplaire l'a utilisee ──────────────────────
  v_t := 'T5 un exemplaire sous le prefixe fige prefixe/annee/separateur (frozen), le remplissage reste libre ; get dit tombo_frozen';
  BEGIN
    -- le seed pose un exemplaire BLMF : on lui donne un tombo de la serie
    UPDATE public.exemplares SET tombo = 'ESSAI-00001' WHERE id = (SELECT min(id) FROM public.exemplares WHERE library_id = v_lib);
    IF NOT FOUND THEN RAISE EXCEPTION 'pas d''exemplaire BLMF dans le seed'; END IF;
    v_txt := '';
    BEGIN PERFORM public.fn_library_numbering_set(v_lib, 'ESSAI2-', false, '', 5, 'ESS-', 5, true);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    BEGIN PERFORM public.fn_library_numbering_set(v_lib, 'ESSAI-', true, '', 5, 'ESS-', 5, true);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    v_res := public.fn_library_numbering_set(v_lib, 'ESSAI-', false, '', 6, 'ESS-', 5, true);
    IF v_txt = 'error.numbering.frozen;error.numbering.frozen;'
       AND (v_res->>'tombo_frozen')::boolean AND v_res->>'next_tombo' = 'ESSAI-000002' AND (v_res->>'exemplars_count')::int >= 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt||' / '||left(v_res::text,200)); END IF;
    PERFORM public.fn_library_numbering_set(v_lib, 'ESSAI-', false, '', 5, 'ESS-', 5, true);
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5b : qui regle ───────────────────────────────────────────────────
  v_t := 'T5b une lectrice ne regle pas la serie (coord_only) ; un compte sans role ne la lit pas (staff_only)';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_reader, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.fn_library_numbering_set(v_lib, 'ESSAI-', false, '', 5, 'ESS-', 5, true);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.fn_library_numbering_get(v_lib);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_txt = 'error.numbering.coord_only;error.numbering.staff_only;' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Jeu d'essai : un lot BLMF de quatre brouillons ────────────────────
  INSERT INTO public.catalog_batches (name, status) VALUES ('Essai — cotes', 'open') RETURNING id INTO v_lot;
  INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, owner_library_id, marc_json)
  VALUES ('Premier', v_lot, 'draft', 'livro', v_lib, '{"ingest":{"raw_payload":{"assunto_local":"Histoire"}}}'::jsonb) RETURNING id INTO v_d1;
  INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, owner_library_id, bib_ref, cdd, marc_json)
  VALUES ('Deja cote', v_lot, 'draft', 'livro', v_lib, 'ESS-00007', '335.83', '{"ingest":{"subjects":["Economie"]}}'::jsonb) RETURNING id INTO v_d2;
  INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, owner_library_id, marc_json)
  VALUES ('Troisieme', v_lot, 'ready', 'livro', v_lib, '{"ingest":{"raw_payload":{"assunto_local":"Economie"}}}'::jsonb) RETURNING id INTO v_d3;
  INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, owner_library_id)
  VALUES ('Sans rubrique', v_lot, 'draft', 'livro', v_lib) RETURNING id INTO v_d4;
  INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, owner_library_id)
  VALUES ('A la corbeille', v_lot, 'cancelled', 'livro', v_lib) RETURNING id INTO v_d5;

  -- ── T6 : apercu sans ecriture ─────────────────────────────────────────
  v_t := 'T6 apercu des cotes : 3 candidats, ESS-00008 a ESS-00010 (a la suite du brouillon ESS-00007), rien d''ecrit';
  BEGIN
    v_res := public.fn_batch_assign_bib_refs(v_lot);
    SELECT count(*) INTO v_n FROM public.book_drafts d WHERE d.batch_id = v_lot AND d.bib_ref IS NULL AND d.status <> 'cancelled';
    IF (v_res->>'candidates')::int = 3 AND v_res->>'first' = 'ESS-00008' AND v_res->>'last' = 'ESS-00010'
       AND (v_res->>'applied')::boolean = false AND v_n = 3 AND v_res->>'library_name' = 'BLMF (base de test)'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_res::text,300)||' restants='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 : application dans l'ordre du lot ──────────────────────────────
  v_t := 'T7 application : ESS-00008/9/10 dans l''ordre des brouillons, corbeille et brouillon deja cote intacts, trace dans les notes, second appel = 0';
  BEGIN
    v_res := public.fn_batch_assign_bib_refs(v_lot, true);
    IF (v_res->>'updated')::int = 3
       AND (SELECT d.bib_ref FROM public.book_drafts d WHERE d.id = v_d1) = 'ESS-00008'
       AND (SELECT d.bib_ref FROM public.book_drafts d WHERE d.id = v_d3) = 'ESS-00009'
       AND (SELECT d.bib_ref FROM public.book_drafts d WHERE d.id = v_d4) = 'ESS-00010'
       AND (SELECT d.bib_ref FROM public.book_drafts d WHERE d.id = v_d2) = 'ESS-00007'
       AND (SELECT d.bib_ref FROM public.book_drafts d WHERE d.id = v_d5) IS NULL
       AND (SELECT b.notes FROM public.catalog_batches b WHERE b.id = v_lot) LIKE '%3 cota(s) atribuida(s)%ESS-00008 a ESS-00010%'
       AND (public.fn_batch_assign_bib_refs(v_lot, true)->>'candidates')::int = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_res::text,300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 : refus des cotes ──────────────────────────────────────────────
  v_t := 'T8 refus : proprietaires melanges (mixed_owner), sans proprietaire (no_owner), sans convention (no_convention), lot ferme (not_open)';
  BEGIN
    INSERT INTO public.catalog_batches (name, status) VALUES ('Essai — cotes 2', 'open') RETURNING id INTO v_lot2;
    INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, owner_library_id) VALUES ('Mixte A', v_lot2, 'draft', 'livro', v_lib);
    INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, owner_library_id) VALUES ('Mixte B', v_lot2, 'draft', 'livro', v_lib2);
    v_txt := '';
    BEGIN PERFORM public.fn_batch_assign_bib_refs(v_lot2);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    UPDATE public.book_drafts SET owner_library_id = NULL WHERE batch_id = v_lot2;
    BEGIN PERFORM public.fn_batch_assign_bib_refs(v_lot2);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    UPDATE public.book_drafts SET owner_library_id = v_lib2 WHERE batch_id = v_lot2;
    UPDATE public.libraries SET bib_ref_auto = false WHERE id = v_lib2;
    BEGIN PERFORM public.fn_batch_assign_bib_refs(v_lot2);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    UPDATE public.libraries SET bib_ref_auto = true WHERE id = v_lib2;
    UPDATE public.catalog_batches SET status = 'closed' WHERE id = v_lot2;
    BEGIN PERFORM public.fn_batch_assign_bib_refs(v_lot2);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    UPDATE public.catalog_batches SET status = 'open' WHERE id = v_lot2;
    IF v_txt = 'error.bibref.batch.mixed_owner;error.bibref.batch.no_owner;error.bibref.batch.no_convention;error.bibref.batch.not_open;'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T9 : la serie se poursuit apres une notice publiee ────────────────
  v_t := 'T9 une notice publiee ESS-00042 fait repartir le lot 2 a ESS-00043';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Publiee', 'AUT-0042', 'livro');
    -- lot 2 appartient a lib2 (AUT-, pad 4)
    v_res := public.fn_batch_assign_bib_refs(v_lot2);
    IF v_res->>'first' = 'AUT-0043' AND (v_res->>'candidates')::int = 2 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_res::text,300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 : les rubriques, la ou l'import les laisse ────────────────────
  v_t := 'T10 fn_batch_rubrics : Economie (2, dont 1 sans classe), Histoire (1), sans rubrique (1), corbeille exclue';
  BEGIN
    IF (SELECT count(*) FROM public.fn_batch_rubrics(v_lot)) = 3
       AND (SELECT r.drafts FROM public.fn_batch_rubrics(v_lot) r WHERE r.rubric = 'Economie') = 2
       AND (SELECT r.without_class FROM public.fn_batch_rubrics(v_lot) r WHERE r.rubric = 'Economie') = 1
       AND (SELECT r.drafts FROM public.fn_batch_rubrics(v_lot) r WHERE r.rubric = 'Histoire') = 1
       AND (SELECT r.drafts FROM public.fn_batch_rubrics(v_lot) r WHERE r.rubric IS NULL) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||(SELECT string_agg(coalesce(r.rubric,'NULL')||'='||r.drafts||'/'||r.without_class, ', ') FROM public.fn_batch_rubrics(v_lot) r)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 : la table ecrit les classes, respecte l'existant ─────────────
  v_t := 'T11 application de la table : 2 classes ecrites, la classe existante gardee, 1 sans rubrique, trace ; puis overwrite';
  BEGIN
    v_res := public.fn_batch_apply_rubric_classes(v_lot, '{"Histoire":"HIS","Economie":"ECO"}'::jsonb);
    IF (v_res->>'updated')::int = 2 AND (v_res->>'skipped_has_class')::int = 1 AND (v_res->>'skipped_unmapped')::int = 1
       AND (SELECT d.cdd FROM public.book_drafts d WHERE d.id = v_d1) = 'HIS'
       AND (SELECT d.cdd FROM public.book_drafts d WHERE d.id = v_d3) = 'ECO'
       AND (SELECT d.cdd FROM public.book_drafts d WHERE d.id = v_d2) = '335.83'
       AND (SELECT d.cdd FROM public.book_drafts d WHERE d.id = v_d4) IS NULL
       AND (SELECT b.notes FROM public.catalog_batches b WHERE b.id = v_lot) LIKE '%Classe de arrumacao escrita em 2 rascunho(s)%'
    THEN
      v_res := public.fn_batch_apply_rubric_classes(v_lot, '{"Economie":"ECO"}'::jsonb, true);
      IF (v_res->>'updated')::int = 2 AND (SELECT d.cdd FROM public.book_drafts d WHERE d.id = v_d2) = 'ECO' THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : overwrite '||left(v_res::text,200)); END IF;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_res::text,300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T12 : une table qui n'est pas un objet ────────────────────────────
  v_t := 'T12 une table invalide est refusee (bad_map) et n''ecrit rien';
  BEGIN
    PERFORM public.fn_batch_apply_rubric_classes(v_lot, '["HIS"]'::jsonb);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.rubrics.batch.bad_map' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')); END IF;
  END;

  -- ── T13 : droits ──────────────────────────────────────────────────────
  v_t := 'T13 une lectrice ne numerote ni ne classe (staff_only) ; aucune fonction ouverte a anon ; le helper rubrique ferme a authenticated';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_reader, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.fn_batch_assign_bib_refs(v_lot);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    BEGIN PERFORM count(*) FROM public.fn_batch_rubrics(v_lot);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_txt = 'error.bibref.batch.staff_only;error.rubrics.batch.staff_only;'
       AND NOT has_function_privilege('anon', 'public.fn_library_numbering_set(uuid, text, boolean, text, integer, text, integer, boolean)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'public.fn_batch_assign_bib_refs(bigint, boolean)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'public.fn_batch_apply_rubric_classes(bigint, jsonb, boolean)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.fn_book_draft_rubric(bigint)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_batch_rubrics(bigint)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Bilan (RAISE = tout est annule) ─────────────────────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'NUMEROTATION-RANGEMENT OK : %/%', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'NUMEROTATION-RANGEMENT ECHEC : %/% — %', v_passed, v_passed + v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
