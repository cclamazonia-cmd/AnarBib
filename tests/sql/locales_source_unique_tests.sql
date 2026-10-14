-- =====================================================================
-- AnarBib — Tests : les locales ont une source en base (DOC-I18N-4)
-- Date    : 2026-10-13  ·  Chantier « locale ro », lot 1
-- Ref     : 20261013194812_les_locales_ont_une_source_en_base
--
-- T1 la source : dix codes dans l'ordre de l'app, IMMUTABLE, INVOKER, fermée
--    à anon, ouverte à authenticated et service_role.
-- T2 les huit contraintes la lisent, sans copie ; 'mul' et NULL gardés.
-- T3 sur chaque table (copie LIKE … INCLUDING CONSTRAINTS, écrite SOUS
--    authenticated) : une locale de la liste passe, 'xx' est refusé ; anon
--    est refusé par le droit sur la fonction, jamais par surprise.
-- T4 les huit fonctions la lisent, sans copie, et rendent la même liste.
-- T5 trois fonctions au comportement : correspondance, proposition d'œuvre,
--    pré-traduction (une locale inconnue est refusée ou ignorée).
-- Les écritures réelles sous politique sont jouées ailleurs :
-- correspondance_lot1_tests T14 (libraries.read_languages par la
-- coordination, déclencheur INVOKER), work_titles_tests T3/T5.
--   Bilan OK : 'LOCALES-SOURCE OK : N/N'
-- =====================================================================
BEGIN;
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_attendu constant text[] := ARRAY['pt-BR','fr','es','en','it','de','ca','eo','nl','el','ro'];   -- ro : 20261014192932
  r record; v_txt text; v_n int; v_b boolean; v_w bigint; v_e text;
BEGIN
  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 la source : onze codes dans l''ordre de l''app (ro en onzième), IMMUTABLE, INVOKER, droits';
  BEGIN
    SELECT p.provolatile = 'i' AND NOT p.prosecdef AND p.proconfig IS NOT NULL INTO v_b
      FROM pg_proc p WHERE p.oid = 'public.fn_supported_locales()'::regprocedure;
    IF public.fn_supported_locales() = c_attendu AND v_b
       AND NOT has_function_privilege('anon', 'public.fn_supported_locales()', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_supported_locales()', 'EXECUTE')
       AND has_function_privilege('service_role', 'public.fn_supported_locales()', 'EXECUTE')
    THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || public.fn_supported_locales()::text || ' attributs ' || coalesce(v_b::text, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 les huit contraintes lisent la source, sans copie ; mul et NULL gardés';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_constraint c
     WHERE c.contype = 'c' AND pg_get_constraintdef(c.oid) ~ 'fn_supported_locales\(\)'
       AND (c.conrelid::regclass::text, c.conname) IN (
         ('author_translations', 'author_translations_lang_check'),
         ('gazette_issue_locales', 'gazette_issue_locales_locale_check'),
         ('gazette_sources', 'gazette_sources_locale_check'),
         ('gazette_submissions', 'gazette_submissions_locale_check'),
         ('lettre_issue_locales', 'lettre_issue_locales_locale_check'),
         ('libraries', 'libraries_read_languages_check'),
         ('library_messages', 'library_messages_lang_check'),
         ('work_titles', 'work_titles_lang_check'));
    SELECT string_agg(conname, ', ') INTO v_txt FROM pg_constraint
     WHERE contype = 'c' AND pg_get_constraintdef(oid) ~ '''(pt-BR|eo)''';
    IF v_n = 8 AND v_txt IS NULL
       AND pg_get_constraintdef((SELECT oid FROM pg_constraint WHERE conname = 'gazette_sources_locale_check')) ~ '''mul'''
       AND pg_get_constraintdef((SELECT oid FROM pg_constraint WHERE conname = 'gazette_submissions_locale_check')) ~ 'IS NULL'
    THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s/8, copies : %s', v_n, coalesce(v_txt, 'aucune'))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- T3 : une copie de chaque table garde ses contraintes CHECK ; on n'y garde
  -- que la colonne éprouvée obligatoire, et on écrit sous authenticated.
  FOR r IN SELECT * FROM (VALUES
      ('author_translations', 'lang', '''el''', '''xx'''),
      ('gazette_issue_locales', 'locale', '''el''', '''xx'''),
      ('gazette_sources', 'locale', '''mul''', '''xx'''),
      ('gazette_submissions', 'locale', '''nl''', '''xx'''),
      ('lettre_issue_locales', 'locale', '''eo''', '''xx'''),
      ('libraries', 'read_languages', 'ARRAY[''ca'',''pt-BR'']', 'ARRAY[''fr'',''xx'']'),
      ('library_messages', 'lang', '''ca''', '''xx'''),
      ('work_titles', 'lang', '''pt-BR''', '''xx''')) AS t(tbl, col, ok, ko)
  LOOP
    v_t := format('T3 %s.%s : %s passe, %s refusé, sous authenticated', r.tbl, r.col, r.ok, r.ko);
    BEGIN
      -- Sans les défauts : un nextval() demanderait à authenticated un droit
      -- sur la séquence, sans rapport avec ce qu'on éprouve.
      EXECUTE format('CREATE TEMP TABLE _loc_%s (LIKE public.%I INCLUDING CONSTRAINTS)', r.tbl, r.tbl);
      FOR v_e IN SELECT a.attname FROM pg_attribute a
                  WHERE a.attrelid = format('pg_temp._loc_%s', r.tbl)::regclass AND a.attnum > 0 AND NOT a.attisdropped
                    AND a.attnotnull AND a.attname <> r.col LOOP
        EXECUTE format('ALTER TABLE pg_temp._loc_%s ALTER COLUMN %I DROP NOT NULL', r.tbl, v_e);
      END LOOP;
      EXECUTE format('GRANT INSERT ON pg_temp._loc_%s TO authenticated, anon', r.tbl);
      SET LOCAL ROLE authenticated;
      PERFORM set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
      EXECUTE format('INSERT INTO pg_temp._loc_%s (%I) VALUES (%s)', r.tbl, r.col, r.ok);
      v_txt := 'ok:passé';
      BEGIN
        EXECUTE format('INSERT INTO pg_temp._loc_%s (%I) VALUES (%s)', r.tbl, r.col, r.ko);
        v_txt := v_txt || ' ko:passé';
      EXCEPTION WHEN check_violation THEN v_txt := v_txt || ' ko:refusé'; END;
      RESET ROLE;
      SET LOCAL ROLE anon;
      BEGIN
        EXECUTE format('INSERT INTO pg_temp._loc_%s (%I) VALUES (%s)', r.tbl, r.col, r.ok);
        v_txt := v_txt || ' anon:passé';
      EXCEPTION WHEN insufficient_privilege THEN v_txt := v_txt || ' anon:refusé'; END;
      RESET ROLE;
      PERFORM set_config('request.jwt.claims', NULL, true);
      EXECUTE format('DROP TABLE pg_temp._loc_%s', r.tbl);
      IF v_txt = 'ok:passé ko:refusé anon:refusé' THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
    EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  END LOOP;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 les huit fonctions lisent la source, sans copie de la liste';
  BEGIN
    SELECT count(*), string_agg(p.proname, ', ') FILTER (WHERE p.prosrc ~ '''eo''' OR p.prosrc !~ 'fn_supported_locales\(\)')
      INTO v_n, v_txt
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE (n.nspname, p.proname) IN (
       ('api', 'fn_lettre_set_locale'), ('api', 'fn_work_title_validate'),
       ('public', 'fn_correspondance_langue'), ('public', 'fn_work_proposal_check'),
       ('public', 'fn_work_titles_autofill_apply'), ('public', 'fn_work_titles_pending'),
       ('public', 'set_work_title'), ('public', 'tg_libraries_read_languages_normaliser'));
    IF v_n = 8 AND v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s/8, copies : %s', v_n, coalesce(v_txt, 'aucune'))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 au comportement : correspondance, proposition d''œuvre, pré-traduction';
  BEGIN
    INSERT INTO public.works (uniform_title, sort_title) VALUES ('Zzlocales source', 'zzlocales source') RETURNING id INTO v_w;
    v_txt := public.fn_correspondance_langue('el', NULL);
    BEGIN PERFORM public.fn_correspondance_langue('xx', NULL); v_txt := v_txt || ' xx:passé';
    EXCEPTION WHEN invalid_parameter_value THEN v_txt := v_txt || ' xx:refusé'; END;
    PERFORM public.fn_work_proposal_check('titre', v_w, NULL, '{"lang": "eo", "title": "Zzla titolo"}'::jsonb);
    BEGIN PERFORM public.fn_work_proposal_check('titre', v_w, NULL, '{"lang": "xx", "title": "Zz"}'::jsonb); v_txt := v_txt || ' prop:passé';
    EXCEPTION WHEN OTHERS THEN v_txt := v_txt || CASE WHEN SQLERRM = 'bad_lang' THEN ' prop:refusé' ELSE ' prop:' || SQLERRM END; END;
    v_n := public.fn_work_titles_autofill_apply(v_w, '{"el": "Zzτίτλος", "xx": "Zzinconnue"}'::jsonb, NULL);
    SELECT string_agg(lang, ',' ORDER BY lang) INTO v_e FROM public.work_titles WHERE work_id = v_w AND source = 'auto';
    DELETE FROM public.works WHERE id = v_w;
    IF v_txt = 'el xx:refusé prop:refusé' AND v_n = 1 AND v_e = 'el' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s, autofill %s (%s)', v_txt, v_n, coalesce(v_e, '-'))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'LOCALES-SOURCE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE NOTICE 'LOCALES-SOURCE OK : %/%', v_passed, v_passed + v_failed;
END $$;
ROLLBACK;
