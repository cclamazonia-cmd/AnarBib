-- =====================================================================
-- AnarBib — Tests d'acceptation : la page Œuvre dit le tome (E18)
-- Date    : 2026-09-07  ·  retour Xavier sur /obra/133 (L'Homme et la Terre)
-- Ref     : migration 20260907220000_la_page_oeuvre_dit_le_tome
--
-- Pourquoi cette suite existe : six tomes d'une même édition s'affichaient
-- comme six éditions identiques, dans l'ordre des identifiants. Les notices
-- portaient bien `volume` ; la RPC ne le servait pas et triait par année puis
-- titre — six clés égales. La suite crée trois tomes insérés DANS LE
-- DÉSORDRE (III, I, II) avec la même année : seul un tri par rang de tome
-- peut les remettre dans l'ordre, l'ordre des identifiants ne le fait pas.
--
--   T1 chaque édition porte son `volume`
--   T2 les tomes sortent I, II, III (à plat)
--   T3 même ordre et même `volume` dans le groupe par langue (expressions)
--   T4 une édition sans tome garde `volume` NULL et passe devant par l'année
--   T5 anon peut toujours exécuter la RPC (grant conservé par le REPLACE)
--
--   Bilan OK : 'OEUVRE-TOMES OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := '{}'; v_t text;
  v_lib uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_author bigint; v_w bigint; v_b3 bigint; v_b1 bigint; v_b2 bigint; v_b0 bigint;
  v_res jsonb; v_eds jsonb;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = v_lib) THEN
    RAISE EXCEPTION 'OEUVRE-TOMES : la bibliotheque du seed est absente';
  END IF;
  UPDATE public.libraries SET is_active = true, visibility_level = 'public' WHERE id = v_lib;

  -- ── Fixtures : trois tomes dans le désordre + une édition sans tome, plus ancienne
  INSERT INTO public.authors (preferred_name) VALUES ('ZZRECLUS, Élisée') RETURNING id INTO v_author;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id)
  VALUES ('Zztomes homme et terre', 'zztomes homme et terre', v_author) RETURNING id INTO v_w;
  INSERT INTO public.books (titulo, subtitulo, volume, autor, idioma, ano, editora, work_id)
  VALUES ('Zztomes homme et terre', 'Tome III', 'III', 'ZZRECLUS, Élisée', 'fr', '1905', 'Librairie Zz', v_w) RETURNING id INTO v_b3;
  INSERT INTO public.books (titulo, subtitulo, volume, autor, idioma, ano, editora, work_id)
  VALUES ('Zztomes homme et terre', 'Tome I', 'I', 'ZZRECLUS, Élisée', 'fr', '1905', 'Librairie Zz', v_w) RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, subtitulo, volume, autor, idioma, ano, editora, work_id)
  VALUES ('Zztomes homme et terre', 'Tome II', 'II', 'ZZRECLUS, Élisée', 'fr', '1905', 'Librairie Zz', v_w) RETURNING id INTO v_b2;
  INSERT INTO public.books (titulo, volume, autor, idioma, ano, editora, work_id)
  VALUES ('Zztomes homme et terre', '  ', 'ZZRECLUS, Élisée', 'fr', '1899', 'Librairie Zz', v_w) RETURNING id INTO v_b0;
  INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
  VALUES (v_b3, v_lib, false, 1, 1), (v_b1, v_lib, false, 1, 1), (v_b2, v_lib, false, 1, 1), (v_b0, v_lib, false, 1, 1);
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  PERFORM set_config('request.jwt.claims', NULL, true);

  v_res := api.work_public_detail(v_w, 'fr');
  v_eds := v_res->'editions';

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 chaque tome porte son volume';
  IF jsonb_array_length(v_eds) = 4
     AND (SELECT count(*) FROM jsonb_array_elements(v_eds) e WHERE e->>'volume' IN ('I','II','III')) = 3 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_eds::text, '∅')); END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 les tomes sortent I, II, III bien qu''insérés III, I, II';
  IF (v_eds->1->>'book_id')::bigint = v_b1 AND (v_eds->2->>'book_id')::bigint = v_b2 AND (v_eds->3->>'book_id')::bigint = v_b3 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ordre ' || coalesce(v_eds->1->>'volume','∅') || ',' || coalesce(v_eds->2->>'volume','∅') || ',' || coalesce(v_eds->3->>'volume','∅')); END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 même ordre et même volume dans le groupe par langue';
  IF jsonb_array_length(v_res->'expressions') = 1
     AND v_res->'expressions'->0->'editions'->1->>'volume' = 'I'
     AND v_res->'expressions'->0->'editions'->2->>'volume' = 'II'
     AND v_res->'expressions'->0->'editions'->3->>'volume' = 'III' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce((v_res->'expressions')::text, '∅')); END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 l''édition sans tome (volume vide → NULL) passe devant par l''année';
  IF (v_eds->0->>'book_id')::bigint = v_b0 AND (v_eds->0->'volume') = 'null'::jsonb THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce((v_eds->0)::text, '∅')); END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 anon exécute toujours la RPC';
  IF has_function_privilege('anon', 'api.work_public_detail(bigint,text)', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- ─── Bilan (le RAISE annule les fixtures) ─────────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'OEUVRE-TOMES OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'OEUVRE-TOMES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
