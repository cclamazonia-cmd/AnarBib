-- =====================================================================
-- AnarBib — Tests d'acceptation : les sujets d'une copie d'import posés
-- sur les notices (C27, private.fn_indexer_sujets_importes)
-- Date    : 2026-10-22
-- Ref     : migration 20261022203129_c27_les_notices_d_anarchief_indexees_par_leur_wiki
--
-- Données fictives (préfixe ZZC27-, matières zz-c27-*).
-- T1 une notice reçoit ses sujets dans l'ordre du wiki ; une forme sans
--    correspondance est ignorée
-- T2 deux formes du même sujet donnent une seule affectation
-- T3 une notice déjà indexée garde ses sujets ; les nouveaux viennent après
-- T4 le bilan compte notices et affectations ; rejouée, la fonction ne fait rien
-- T5 refus (22023) : correspondance vers une matière proposée ou absente,
--    préfixe vide — rien n'est écrit
-- T6 hors préfixe rien ne bouge ; aucune matière créée ; fermée au lectorat
--   Bilan OK : 'C27-SUJETS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';   -- blmf-test (seed)
  c_map constant jsonb := '{"Alpha": "zz-c27-a", "Alpha2": "zz-c27-a", "Beta": "zz-c27-b"}';
  v_a bigint; v_b bigint; v_p bigint;
  v_b1 bigint; v_b2 bigint; v_b3 bigint; v_hors bigint;
  v_res jsonb; v_res2 jsonb; v_l text; v_state text; v_subj int; v_bs int;
BEGIN
  INSERT INTO public.subjects (slug, status) VALUES ('zz-c27-a', 'ativo') RETURNING id INTO v_a;
  INSERT INTO public.subjects (slug, status) VALUES ('zz-c27-b', 'ativo') RETURNING id INTO v_b;
  INSERT INTO public.subjects (slug, status) VALUES ('zz-c27-p', 'proposto') RETURNING id INTO v_p;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id, marc_json)
  VALUES ('Notice un', 'ZZC27-1', 'livro', c_lib, '{"ingest": {"raw_payload": {"sujets": "Beta | Inconnu|Alpha"}}}') RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id, marc_json)
  VALUES ('Notice deux', 'ZZC27-2', 'livro', c_lib, '{"ingest": {"raw_payload": {"sujets": "Alpha2 | Alpha"}}}') RETURNING id INTO v_b2;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id, marc_json)
  VALUES ('Notice trois', 'ZZC27-3', 'livro', c_lib, '{"ingest": {"raw_payload": {"sujets": "Alpha | Beta"}}}') RETURNING id INTO v_b3;
  INSERT INTO public.book_subjects (book_id, subject_id, ord) VALUES (v_b3, v_b, 1);
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id, marc_json)
  VALUES ('Hors préfixe', 'AUTRE-ZZC27', 'livro', c_lib, '{"ingest": {"raw_payload": {"sujets": "Alpha"}}}') RETURNING id INTO v_hors;
  v_subj := (SELECT count(*) FROM public.subjects);

  -- T5 d'abord : un refus n'écrit rien
  v_t := 'T5 refus';
  BEGIN
    v_l := '';
    BEGIN PERFORM private.fn_indexer_sujets_importes('ZZC27-', '{"Alpha": "zz-c27-p"}'); v_l := v_l || 'proposée acceptée;';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; IF v_state <> '22023' THEN v_l := v_l || 'proposée:' || v_state || ';'; END IF; END;
    BEGIN PERFORM private.fn_indexer_sujets_importes('ZZC27-', '{"Alpha": "zz-c27-a", "Beta": "zz-c27-absente"}'); v_l := v_l || 'absente acceptée;';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; IF v_state <> '22023' THEN v_l := v_l || 'absente:' || v_state || ';'; END IF; END;
    BEGIN PERFORM private.fn_indexer_sujets_importes(' ', c_map); v_l := v_l || 'préfixe vide accepté;';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; IF v_state <> '22023' THEN v_l := v_l || 'préfixe:' || v_state || ';'; END IF; END;
    v_bs := (SELECT count(*) FROM public.book_subjects WHERE book_id IN (v_b1, v_b2, v_b3, v_hors));
    IF v_l = '' AND v_bs = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_l||' lignes='||v_bs); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_res := private.fn_indexer_sujets_importes('ZZC27-', c_map);

  v_t := 'T1 ordre du wiki, forme inconnue ignorée';
  BEGIN
    SELECT string_agg(s.slug || '@' || bs.ord, ',' ORDER BY bs.ord) INTO v_l
      FROM public.book_subjects bs JOIN public.subjects s ON s.id = bs.subject_id WHERE bs.book_id = v_b1;
    IF v_l = 'zz-c27-b@1,zz-c27-a@2' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_l,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T2 deux formes, une affectation';
  BEGIN
    SELECT string_agg(s.slug || '@' || bs.ord, ',' ORDER BY bs.ord) INTO v_l
      FROM public.book_subjects bs JOIN public.subjects s ON s.id = bs.subject_id WHERE bs.book_id = v_b2;
    IF v_l = 'zz-c27-a@1' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_l,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 l''existant gardé, le neuf après';
  BEGIN
    SELECT string_agg(s.slug || '@' || bs.ord, ',' ORDER BY bs.ord) INTO v_l
      FROM public.book_subjects bs JOIN public.subjects s ON s.id = bs.subject_id WHERE bs.book_id = v_b3;
    IF v_l = 'zz-c27-b@1,zz-c27-a@2' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_l,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T4 bilan, puis rejeu sans effet';
  BEGIN
    v_res2 := private.fn_indexer_sujets_importes('ZZC27-', c_map);
    IF v_res = '{"notices": 3, "affectations": 4}'::jsonb AND v_res2 = '{"notices": 0, "affectations": 0}'::jsonb
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res::text||' puis '||coalesce(v_res2::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T6 hors préfixe, aucune matière créée, droits';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.book_subjects WHERE book_id = v_hors)
       AND (SELECT count(*) FROM public.subjects) = v_subj
       AND NOT has_function_privilege('anon', 'private.fn_indexer_sujets_importes(text, jsonb)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'private.fn_indexer_sujets_importes(text, jsonb)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hors préfixe indexé, matière créée ou fonction ouverte'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'C27-SUJETS OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'C27-SUJETS ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
