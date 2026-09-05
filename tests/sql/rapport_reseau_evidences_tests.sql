-- =====================================================================
-- AnarBib — Tests d'acceptation : ce que le rapport general du 05/09
-- montrait encore, et ce qui le corrige
-- Date    : 2026-09-05  ·  Session : conventions / autorites
-- Ref     : migration 20260905160000_rapport_reseau_evidences_du_05_09
--
-- Pourquoi cette suite existe : CONV-8 avait retire les contributeurs
-- « AA. VV. » et garde la transcription ; le rapport lisait la transcription
-- et proposait de « creer l'autorite ». Deux ecrans, deux lectures. T1 et
-- T2 tiennent le predicat unique et la vue qui le lit. T3 garde la fusion
-- de variantes : elle refuse une fixture de formation (test de NON-ACTION)
-- et, quand elle agit, la forme retiree survit en forme variante. T4 garde
-- que le rapport d'incoherences compare ce que le trigger derive (tous les
-- roles lies). T5 garde que le rapport de revision n'a plus de table
-- temporaire ET s'execute. T6 : rien n'est ouvert a l'application.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'RAPPORT-RESEAU-EVIDENCES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans role (seed) -> admin reseau ici
  v_b1 bigint; v_b2 bigint; v_b3 bigint;
  v_a1 bigint; v_a2 bigint; v_fix bigint; v_org bigint;
  v_lot bigint; v_draft bigint;
  v_n int; v_rep jsonb; v_def text; v_ok boolean;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');

  -- ── Jeu d'essai ──
  INSERT INTO public.books (bib_ref, titulo, autor, tipo_material) VALUES ('ESSAI-RR-1', 'I Nuovi Padroni', 'AA. VV.', 'livro') RETURNING id INTO v_b1;
  INSERT INTO public.books (bib_ref, titulo, autor, tipo_material) VALUES ('ESSAI-RR-2', 'La Conquête du pain', 'Kropotkine, Piotr Essai', 'livro') RETURNING id INTO v_b2;
  INSERT INTO public.books (bib_ref, titulo, autor, tipo_material) VALUES ('ESSAI-RR-3', 'Crônica', 'Lopes, Milton Essai', 'livro') RETURNING id INTO v_b3;
  -- v_b4 : une personne en transcription, AUCUN contributeur lie (c'est la seule
  -- situation que la vue des non-resolus regarde : author_books_public vide)
  INSERT INTO public.books (bib_ref, titulo, autor, tipo_material) VALUES ('ESSAI-RR-4', 'Paroles d''un révolté', 'Kropotkine, Piotr Essai', 'livro');

  INSERT INTO public.authors (preferred_name, sort_name) VALUES ('Jean-Marie Essai', 'Essai, Jean-Marie') RETURNING id INTO v_a1;
  INSERT INTO public.authors (preferred_name, sort_name) VALUES ('Juan Maria Essai', 'Essai, Juan Maria') RETURNING id INTO v_a2;
  INSERT INTO public.authors (preferred_name, sort_name, source_label) VALUES ('Fixture Essai', 'Essai, Fixture', 'formacao-e9') RETURNING id INTO v_fix;
  INSERT INTO public.authors (preferred_name, sort_name, authority_type) VALUES ('Federação Essai', 'Federação Essai', 'collective') RETURNING id INTO v_org;

  -- v_b2 : contributeur lie a la variante v_a2 ; v_b3 : un auteur + une organisation liee
  INSERT INTO public.book_contributors (book_id, author_id, name, role, position, is_primary) VALUES (v_b2, v_a2, 'Essai, Juan Maria', 'autor', 1, true);
  INSERT INTO public.book_contributors (book_id, author_id, name, role, position, is_primary) VALUES (v_b3, v_a1, 'Essai, Jean-Marie', 'autor', 1, true);
  INSERT INTO public.book_contributors (book_id, author_id, name, role, position, is_primary) VALUES (v_b3, v_org, 'Federação Essai', 'organizacao', 2, false);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 le predicat CONV-8 : auteurs divers, anonymes, « ?? » oui ; une collectivite nommee, une personne non';
  BEGIN
    IF public.fn_conv_est_non_agent('AA. VV.') AND public.fn_conv_est_non_agent('Vários Autores')
       AND public.fn_conv_est_non_agent('Anônimo') AND public.fn_conv_est_non_agent('identificado, Não')
       AND public.fn_conv_est_non_agent('??') AND public.fn_conv_est_non_agent('Collectif')
       AND NOT public.fn_conv_est_non_agent('Coletivo Libertário de Oposição Sindical')
       AND NOT public.fn_conv_est_non_agent('Kropotkine, Piotr')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : reponses inattendues'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 la vue des non-resolus ignore « AA. VV. » et garde une personne sans fiche';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.v_author_alias_worklist w WHERE w.autor = 'AA. VV.')
       AND EXISTS (SELECT 1 FROM public.v_author_alias_worklist w WHERE w.autor = 'Kropotkine, Piotr Essai')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 la fusion de variantes refuse une fixture (non-action) et, sinon, deplace le contributeur et garde la forme';
  BEGIN
    v_ok := public.fn_conv_fusionner_variante(v_a1, v_fix, 'essai');
    IF v_ok OR NOT EXISTS (SELECT 1 FROM public.authors WHERE id = v_fix) THEN
      RAISE EXCEPTION 'la fixture a ete fusionnee';
    END IF;
    v_ok := public.fn_conv_fusionner_variante(v_a1, v_a2, 'essai variante');
    IF NOT v_ok THEN RAISE EXCEPTION 'fusion refusee'; END IF;
    IF EXISTS (SELECT 1 FROM public.authors WHERE id = v_a2) THEN RAISE EXCEPTION 'doublon encore la'; END IF;
    IF (SELECT author_id FROM public.book_contributors WHERE book_id = v_b2) <> v_a1 THEN RAISE EXCEPTION 'contributeur non deplace'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.book_authors WHERE book_id = v_b2 AND author_id = v_a1) THEN RAISE EXCEPTION 'book_authors non derive'; END IF;
    IF NOT (SELECT coalesce(variant_forms, '[]'::jsonb) @> '[{"form": "Essai, Juan Maria"}]'::jsonb FROM public.authors WHERE id = v_a1) THEN RAISE EXCEPTION 'forme variante perdue'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.merge_log WHERE entity_type = 'author' AND canonical_id = v_a1 AND duplicate_id = v_a2) THEN RAISE EXCEPTION 'merge_log muet'; END IF;
    v_passed := v_passed+1;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 le rapport d''incoherences ne signale pas un livre dont l''organisation liee est derivee';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM api.report_incoherences_auteurs() r WHERE r.book_id = v_b3;
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : signale '||v_n||' fois'); END IF;
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 le rapport de revision n''a plus de table temporaire, s''execute, et compte les entrees au titre';
  BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'fn_batch_review_report';
    IF position('create temp table' IN lower(v_def)) > 0 THEN RAISE EXCEPTION 'table temporaire encore la'; END IF;
    INSERT INTO public.catalog_batches (name, status) VALUES ('Essai — rapport', 'open') RETURNING id INTO v_lot;
    INSERT INTO public.book_drafts (titulo, autor, batch_id, status, tipo_material, bib_ref, ano)
    VALUES ('Antologia anarchica', 'AA. VV.', v_lot, 'draft', 'livro', 'ESSAI-RR-D1', '1990') RETURNING id INTO v_draft;
    INSERT INTO public.book_draft_contributors (draft_id, name, role, is_primary) VALUES (v_draft, 'Anônimo', 'autor', true);
    v_rep := public.fn_batch_review_report(v_lot);
    IF (v_rep->'batch'->>'title_entries')::int = 1
       AND EXISTS (SELECT 1 FROM jsonb_array_elements(v_rep->'conventions') c WHERE c->>'rule' = 'contrib_non_agent' AND (c->>'count')::int = 1)
       AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_rep->'conventions') c WHERE c->>'rule' = 'autor_unstructured')
       AND (v_rep->'authorities'->>'unlinked_count')::int = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_rep::text, 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 la fusion n''est pas executable depuis l''application, rien n''est ouvert a anon';
  BEGIN
    IF has_function_privilege('authenticated', 'public.fn_conv_fusionner_variante(bigint,bigint,text)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.fn_conv_fusionner_variante(bigint,bigint,text)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.fn_batch_review_report(bigint)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.fn_batch_live_drafts(bigint)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.fn_batch_live_drafts(bigint)', 'EXECUTE')
    THEN v_failed := v_failed+1; v_failures := v_failures||(v_t);
    ELSE v_passed := v_passed+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'RAPPORT-RESEAU-EVIDENCES OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'RAPPORT-RESEAU-EVIDENCES ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
