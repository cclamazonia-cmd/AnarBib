-- =====================================================================
-- AnarBib — Tests d'acceptation : l'atelier s'ouvre aux oeuvres
-- Date    : 2026-09-05  ·  Session : atelier / oeuvres
-- Ref     : migration 20260905220000_l_atelier_s_ouvre_aux_oeuvres
--
-- Pourquoi cette suite existe : le moteur de l'atelier (proposition,
-- objection, consentement, application) n'avait jamais ete emprunte pour une
-- oeuvre. La suite EMPRUNTE chaque type — titre, fusion, rattachement,
-- scission, tomes — avec le JWT d'un·e contributeur·rice puis du staff, et
-- verifie l'effet sur books / works / work_titles, pas seulement le statut.
--
-- T2 tient la decision du 05/09 : un·e contributeur·rice SANS bibliotheque
-- propose mais n'objecte pas ; rattache·e a une bibliotheque concernee, il ou
-- elle objecte. T7 est une serie de NON-ACTIONS : les mauvais payloads sont
-- refuses avant toute ecriture.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'ATELIER-OEUVRES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord   uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_libre   uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans role (seed) -> contributeur SANS biblio
  v_leitora uuid := '33333333-3333-3333-3333-333333333333';  -- reader BLMF actif (seed) -> contributrice RATTACHEE
  v_lib     uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  b1 bigint; b2 bigint; b3 bigint; b4 bigint; b5 bigint;
  w1 bigint; w2 bigint; w3 bigint; w4 bigint; w5 bigint;
  v_prop uuid; v_prop2 uuid; v_res text; v_hint text; v_n int; v_status text; v_title text;
BEGIN
  -- Deux contributeur·rices du reseau : l'un·e sans bibliotheque, l'autre lectrice a BLMF.
  INSERT INTO public.network_contributors (user_id, status) VALUES (v_libre, 'active'), (v_leitora, 'active');

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ── Jeu d'essai : cinq livres, cinq oeuvres (trigger fn_books_ensure_work), tous detenus par BLMF ──
  INSERT INTO public.books (bib_ref, titulo, tipo_material, idioma, ano) VALUES ('ESSAI-AO-1', 'A Conquista do Pão', 'livro', 'pt', '1975') RETURNING id, work_id INTO b1, w1;
  INSERT INTO public.books (bib_ref, titulo, tipo_material, idioma, ano) VALUES ('ESSAI-AO-2', 'La Conquête du pain', 'livro', 'fr', '1892') RETURNING id, work_id INTO b2, w2;
  INSERT INTO public.books (bib_ref, titulo, tipo_material, idioma, ano) VALUES ('ESSAI-AO-3', 'The Conquest of Bread', 'livro', 'en', '1906') RETURNING id, work_id INTO b3, w3;
  INSERT INTO public.books (bib_ref, titulo, tipo_material, idioma, ano) VALUES ('ESSAI-AO-4', 'Memórias — tomo 1', 'livro', 'pt', '1980') RETURNING id, work_id INTO b4, w4;
  INSERT INTO public.books (bib_ref, titulo, tipo_material, idioma, ano) VALUES ('ESSAI-AO-5', 'Memórias — tomo 2', 'livro', 'pt', '1981') RETURNING id, work_id INTO b5, w5;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (b1, v_lib), (b2, v_lib), (b3, v_lib), (b4, v_lib), (b5, v_lib);
  IF w1 IS NULL OR w2 IS NULL OR w3 IS NULL OR w4 IS NULL OR w5 IS NULL THEN
    RAISE EXCEPTION 'jeu d''essai : le trigger n''a pas cree les oeuvres';
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 un·e contributeur·rice sans bibliotheque propose un TITRE (7 jours)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libre, 'role', 'authenticated')::text, true);
    v_prop := api.fn_authority_propose('titre', 'work', w1, NULL, '{"lang":"fr","title":"La Conquête du pain"}'::jsonb, 'Titre français de l''oeuvre, édition Stock 1892.');
    SELECT status INTO v_status FROM public.authority_proposals WHERE id = v_prop;
    IF v_status = 'open' AND (SELECT deadline FROM public.authority_proposals WHERE id = v_prop) BETWEEN now() + interval '6 days' AND now() + interval '8 days'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : status='||coalesce(v_status,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 sans bibliotheque on n''objecte pas ; rattachee a BLMF (lectrice), on objecte — et la proposition est refusee (une seule biblio detient)';
  BEGIN
    BEGIN
      PERFORM api.fn_authority_object(v_prop, v_lib, 'Je ne suis rattache a aucune bibliotheque, je ne devrais pas pouvoir.');
      RAISE EXCEPTION 'objection acceptee sans bibliotheque';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint <> 'atelier.error.notCoordenador' THEN RAISE EXCEPTION 'mauvais refus : % / %', SQLERRM, coalesce(v_hint,'NULL'); END IF;
    END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_leitora, 'role', 'authenticated')::text, true);
    v_res := api.fn_authority_object(v_prop, v_lib, 'Le titre français courant est « La Conquête du pain », déjà en place : proposition inutile.');
    IF v_res = 'refused' AND (SELECT status FROM public.authority_proposals WHERE id = v_prop) = 'refused'
       AND EXISTS (SELECT 1 FROM public.authority_proposal_objections o WHERE o.proposal_id = v_prop AND o.objecting_by = v_leitora AND o.objecting_library_id = v_lib)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : res='||coalesce(v_res,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 FUSION : consentement a l''echeance, application par le staff, l''edition change d''oeuvre, l''oeuvre vide disparait';
  BEGIN
    v_prop := api.fn_authority_propose('fusion', 'work', w2, w1, '{}'::jsonb, 'Même œuvre de Kropotkine, deux langues.');
    UPDATE public.authority_proposals SET deadline = now() - interval '1 hour' WHERE id = v_prop;
    v_n := api.fn_authority_resolve_due();
    IF (SELECT status FROM public.authority_proposals WHERE id = v_prop) <> 'resolved_consent' THEN RAISE EXCEPTION 'pas de consentement a l''echeance'; END IF;
    v_res := api.fn_authority_apply(v_prop);
    IF v_res = 'applied'
       AND (SELECT work_id FROM public.books WHERE id = b2) = w1
       AND NOT EXISTS (SELECT 1 FROM public.works WHERE id = w2)
       AND EXISTS (SELECT 1 FROM public.work_titles WHERE work_id = w1 AND lang = 'fr' AND source = 'edition')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : res='||coalesce(v_res,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 RATTACHEMENT : une edition rejoint l''oeuvre, son ancienne oeuvre vide disparait';
  BEGIN
    v_prop := api.fn_authority_propose('rattachement', 'work', w1, NULL, jsonb_build_object('book_id', b3), 'Traduction anglaise de la même œuvre.');
    UPDATE public.authority_proposals SET deadline = now() - interval '1 hour' WHERE id = v_prop;
    PERFORM api.fn_authority_resolve_due();
    v_res := api.fn_authority_apply(v_prop);
    IF v_res = 'applied' AND (SELECT work_id FROM public.books WHERE id = b3) = w1 AND NOT EXISTS (SELECT 1 FROM public.works WHERE id = w3)
       AND (SELECT count(*) FROM public.books WHERE work_id = w1) = 3
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : res='||coalesce(v_res,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 SCISSION : deux parts deviennent deux oeuvres neuves, l''oeuvre d''origine garde le reste';
  BEGIN
    v_prop := api.fn_authority_propose('scission', 'work', w1, NULL,
      jsonb_build_object('parts', jsonb_build_array(
        jsonb_build_object('uniform_title', 'Essai — texte A', 'book_ids', jsonb_build_array(b1)),
        jsonb_build_object('uniform_title', 'Essai — texte B', 'book_ids', jsonb_build_array(b2)))),
      'Deux textes distincts réunis à tort.');
    UPDATE public.authority_proposals SET deadline = now() - interval '1 hour' WHERE id = v_prop;
    PERFORM api.fn_authority_resolve_due();
    v_res := api.fn_authority_apply(v_prop);
    IF v_res = 'applied'
       AND (SELECT uniform_title FROM public.works w WHERE w.id = (SELECT work_id FROM public.books WHERE id = b1)) = 'Essai — texte A'
       AND (SELECT uniform_title FROM public.works w WHERE w.id = (SELECT work_id FROM public.books WHERE id = b2)) = 'Essai — texte B'
       AND (SELECT work_id FROM public.books WHERE id = b3) = w1
       AND EXISTS (SELECT 1 FROM public.works WHERE id = w1)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : res='||coalesce(v_res,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 TOMES : deux oeuvres deviennent les tomes d''une serie, qui prend le titre de serie';
  BEGIN
    v_prop := api.fn_authority_propose('tomes', 'work', w4, NULL, jsonb_build_object('work_ids', jsonb_build_array(w5), 'series_title', 'Memórias'), 'Tomes 1 et 2 des mêmes mémoires.');
    UPDATE public.authority_proposals SET deadline = now() - interval '1 hour' WHERE id = v_prop;
    PERFORM api.fn_authority_resolve_due();
    v_res := api.fn_authority_apply(v_prop);
    IF v_res = 'applied'
       AND (SELECT work_id FROM public.books WHERE id = b5) = w4
       AND NOT EXISTS (SELECT 1 FROM public.works WHERE id = w5)
       AND (SELECT uniform_title FROM public.works WHERE id = w4) = 'Memórias'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : res='||coalesce(v_res,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 les mauvais payloads sont refuses avant toute ecriture (non-action)';
  BEGIN
    SELECT count(*) INTO v_n FROM public.authority_proposals;
    BEGIN PERFORM api.fn_authority_propose('titre', 'work', w1, NULL, '{"lang":"xx","title":"?"}'::jsonb, 'langue inconnue'); RAISE EXCEPTION 'langue inconnue acceptee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; IF v_hint <> 'atelier.error.workLang' THEN RAISE EXCEPTION 'titre: %', SQLERRM; END IF; END;
    BEGIN PERFORM api.fn_authority_propose('fusion', 'work', w1, w1, '{}'::jsonb, 'avec soi-meme'); RAISE EXCEPTION 'fusion avec soi-meme acceptee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; IF v_hint <> 'atelier.error.workMergeTarget' THEN RAISE EXCEPTION 'fusion: %', SQLERRM; END IF; END;
    BEGIN PERFORM api.fn_authority_propose('rattachement', 'work', w1, NULL, jsonb_build_object('book_id', b3), 'deja dedans'); RAISE EXCEPTION 'rattachement inutile accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; IF v_hint <> 'atelier.error.workBookSame' THEN RAISE EXCEPTION 'rattachement: %', SQLERRM; END IF; END;
    BEGIN PERFORM api.fn_authority_propose('tomes', 'work', w4, NULL, jsonb_build_object('work_ids', jsonb_build_array(w4)), 'lui-meme'); RAISE EXCEPTION 'tome = serie accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; IF v_hint <> 'atelier.error.workTomes' THEN RAISE EXCEPTION 'tomes: %', SQLERRM; END IF; END;
    BEGIN PERFORM api.fn_authority_propose('edition', 'work', w1, NULL, '{}'::jsonb, 'type des autorites'); RAISE EXCEPTION 'type des autorites accepte sur une oeuvre';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; IF v_hint <> 'atelier.error.workKind' THEN RAISE EXCEPTION 'kind: %', SQLERRM; END IF; END;
    IF (SELECT count(*) FROM public.authority_proposals) = v_n THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : une proposition a ete ecrite malgre le refus'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 la file « corrige-moi » liste un titre auto, le staff le valide, il sort de la file';
  BEGIN
    INSERT INTO public.work_titles (work_id, lang, title, source, needs_review) VALUES (w4, 'fr', 'Mémoires', 'auto', true)
    ON CONFLICT (work_id, lang) DO UPDATE SET title = 'Mémoires', source = 'auto', needs_review = true;
    SELECT count(*) INTO v_n FROM api.fn_work_titles_review_list('fr', 50) l WHERE l.work_id = w4;
    IF v_n <> 1 THEN RAISE EXCEPTION 'file : % ligne(s) pour w4', v_n; END IF;
    PERFORM api.fn_work_title_validate(w4, 'fr', 'Mémoires (tomes 1 et 2)');
    SELECT title INTO v_title FROM public.work_titles WHERE work_id = w4 AND lang = 'fr';
    IF v_title = 'Mémoires (tomes 1 et 2)'
       AND (SELECT needs_review FROM public.work_titles WHERE work_id = w4 AND lang = 'fr') = false
       AND (SELECT source FROM public.work_titles WHERE work_id = w4 AND lang = 'fr') = 'manual'
       AND NOT EXISTS (SELECT 1 FROM api.fn_work_titles_review_list('fr', 50) l WHERE l.work_id = w4)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : titre='||coalesce(v_title,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 la liste de l''atelier nomme les oeuvres, un·e contributeur·rice la lit';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libre, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM api.fn_authority_list() l WHERE l.target_kind = 'work' AND l.target_label IS NOT NULL;
    IF v_n >= 4 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s) nommee(s)'); END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T10 les fonctions internes ne sont pas executables depuis l''application ; les RPC restent fermees a anon';
  BEGIN
    IF has_function_privilege('authenticated', 'public.fn_work_proposal_apply(uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.fn_work_proposal_check(text,bigint,bigint,jsonb)', 'EXECUTE')
       OR has_function_privilege('anon', 'api.fn_work_titles_review_list(text,integer)', 'EXECUTE')
       OR has_function_privilege('anon', 'api.fn_work_title_validate(bigint,text,text)', 'EXECUTE')
    THEN v_failed := v_failed+1; v_failures := v_failures||(v_t);
    ELSE v_passed := v_passed+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ATELIER-OEUVRES OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'ATELIER-OEUVRES ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
