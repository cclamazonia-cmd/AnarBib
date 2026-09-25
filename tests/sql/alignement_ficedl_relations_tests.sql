-- =====================================================================
-- AnarBib — Tests : les cinq relations SKOS d'un alignement FICEDL (H9)
-- Date    : 2026-09-25
-- Réf     : supabase/migrations/20260925084523_h9_les_cinq_relations_skos_ouvertes.sql
--           src/tests/skos-relations-h9.test.js (le rendu : page-sujet, Turtle, JSON-LD)
--
-- CE QUE CETTE SUITE PROUVE.
--   Une coordination pose un alignement broad, narrow ou related ; la valeur
--   est gardée telle quelle et sort telle quelle dans api.thesaurus_export_v1
--   (clé `match`, que skosExport.js traduit) ; reposer un alignement change sa
--   relation ; une relation hors domaine ou nulle est refusée ; qui n'est pas
--   coordination est refusé ; anon n'exécute pas.
-- CE QU'ELLE NE PROUVE PAS.
--   Le rendu SKOS lui-même (skos:broadMatch…) : c'est le banc vitest.
--
-- Convention : bilan « ALIGNEMENT-RELATIONS OK : N/N » puis ROLLBACK.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  ok int := 0; total int := 6;
  v_admin uuid := '11111111-1111-1111-1111-111111111111';  -- compte du seed, fait admin réseau ici
  v_autre uuid := gen_random_uuid();
  v_sujet bigint;
  v_mots text[];
  v_n int; v_types text;
BEGIN
  SELECT array_agg(mot_id ORDER BY mot_id) INTO v_mots
    FROM (SELECT mot_id FROM public.ficedl_thesaurus_terms WHERE facet::text LIKE '%sujets%' ORDER BY mot_id LIMIT 3) s;
  IF coalesce(array_length(v_mots, 1), 0) < 3 THEN
    RAISE EXCEPTION 'ALIGNEMENT-RELATIONS ECHEC : moins de trois descripteurs « sujets » au banc';
  END IF;
  INSERT INTO public.subjects (slug, label_i18n, status)
  VALUES ('h9-essai-relations', '{"fr": "essai H9"}'::jsonb, 'ativo') RETURNING id INTO v_sujet;
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;

  -- T1 : la coordination pose broad, narrow, related
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  PERFORM api.fn_subject_add_ficedl_match(v_sujet, v_mots[1], 'broad');
  PERFORM api.fn_subject_add_ficedl_match(v_sujet, v_mots[2], 'narrow');
  PERFORM api.fn_subject_add_ficedl_match(v_sujet, v_mots[3], 'related');
  SELECT string_agg(match_type, ',' ORDER BY mot_id) INTO v_types FROM public.subject_ficedl_links WHERE subject_id = v_sujet;
  IF v_types = 'broad,narrow,related' THEN ok := ok + 1; ELSE RAISE WARNING 'T1 : relations gardées = %', v_types; END IF;

  -- T2 : l'export rend la relation telle quelle (skosExport la traduit)
  SELECT string_agg(fl->>'match', ',' ORDER BY fl->>'match') INTO v_types
    FROM jsonb_array_elements(api.thesaurus_export_v1()->'concepts') c,
         jsonb_array_elements(c->'ficedl') fl
   WHERE c->>'slug' = 'h9-essai-relations';
  IF v_types = 'broad,narrow,related' THEN ok := ok + 1; ELSE RAISE WARNING 'T2 : export = %', v_types; END IF;

  -- T3 : reposer un alignement change sa relation
  PERFORM api.fn_subject_add_ficedl_match(v_sujet, v_mots[1], 'exact');
  SELECT count(*) INTO v_n FROM public.subject_ficedl_links WHERE subject_id = v_sujet AND mot_id = v_mots[1] AND match_type = 'exact';
  IF v_n = 1 THEN ok := ok + 1; ELSE RAISE WARNING 'T3 : relation non remplacée'; END IF;

  -- T4 : hors domaine ou nulle, refusée
  v_n := 0;
  BEGIN PERFORM api.fn_subject_add_ficedl_match(v_sujet, v_mots[2], 'broader');
  EXCEPTION WHEN check_violation THEN v_n := v_n + 1; END;
  BEGIN PERFORM api.fn_subject_add_ficedl_match(v_sujet, v_mots[2], NULL);
  EXCEPTION WHEN check_violation THEN v_n := v_n + 1; END;
  IF v_n = 2 THEN ok := ok + 1; ELSE RAISE WARNING 'T4 : % refus sur 2', v_n; END IF;

  -- T5 : qui n'est pas coordination est refusé
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_autre, 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM api.fn_subject_add_ficedl_match(v_sujet, v_mots[2], 'related');
    RAISE WARNING 'T5 : un compte ordinaire a posé un alignement';
  EXCEPTION WHEN insufficient_privilege THEN ok := ok + 1;
  END;

  -- T6 : anon n'exécute pas
  IF NOT has_function_privilege('anon', 'api.fn_subject_add_ficedl_match(bigint, text, text)', 'EXECUTE') THEN ok := ok + 1;
  ELSE RAISE WARNING 'T6 : ouverte à anon'; END IF;

  IF ok = total THEN
    RAISE NOTICE 'ALIGNEMENT-RELATIONS OK : %/% tests passés — broad/narrow/related posés et exportés tels quels, relation remplacée, hors domaine refusé, coordination seule', ok, total;
  ELSE
    RAISE EXCEPTION 'ALIGNEMENT-RELATIONS ECHEC : %/% tests passés', ok, total;
  END IF;
END $$;

ROLLBACK;
