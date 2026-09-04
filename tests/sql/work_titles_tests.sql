-- =====================================================================
-- AnarBib — Tests : les oeuvres ont un titre par langue (lot 3)
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre
-- Ref     : 20260904130100 (work_titles, fn_work_display_title, reseed par
--           trigger, set_work_title, fn_work_titles_pending / _autofill_apply,
--           cron anarbib-work-titles-autofill, merge_works et les titres)
--
-- Trois sources dans l'ordre manual > edition > auto, et un affichage qui
-- retombe sur le titre uniforme. T1..T4 le semis et la saisie ; T5 la
-- pre-traduction (ne recouvre jamais ce qui existe) ; T6 la fusion ; T7 le
-- cron et les grants.
--   Bilan OK : 'WORK-TITLES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_staff uuid := '11111111-1111-1111-1111-111111111111';
  v_author bigint; v_w1 bigint; v_w2 bigint; v_b1 bigint; v_b2 bigint; v_b3 bigint;
  v_n int; v_txt text; v_txt2 text; v_src text; v_rev boolean;
BEGIN
  -- ── Fixtures ──────────────────────────────────────────────────────
  INSERT INTO public.authors (preferred_name) VALUES ('ZZKROPOTKIN, Piotr') RETURNING id INTO v_author;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id)
  VALUES ('Zzapoio mutuo', 'zzapoio mutuo', v_author) RETURNING id INTO v_w1;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzapoio mútuo', 'ZZKROPOTKIN, Piotr', 'pt-BR', '2009', v_w1) RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzel apoyo mutuo', 'ZZKROPOTKIN, Piotr', 'es', '1989', v_w1) RETURNING id INTO v_b2;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 le trigger seme un titre d''edition par langue';
  BEGIN
    SELECT count(*) INTO v_n FROM public.work_titles WHERE work_id = v_w1 AND source = 'edition';
    SELECT title INTO v_txt FROM public.work_titles WHERE work_id = v_w1 AND lang = 'es';
    IF v_n = 2 AND v_txt = 'Zzel apoyo mutuo' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' lignes, es='||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 le titre affiche suit la locale et retombe sur le titre uniforme';
  BEGIN
    IF public.fn_work_display_title(v_w1, 'es') = 'Zzel apoyo mutuo'
       AND public.fn_work_display_title(v_w1, 'pt-BR') = 'Zzapoio mútuo'
       AND public.fn_work_display_title(v_w1, 'fr') = 'Zzapoio mutuo'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : es='||public.fn_work_display_title(v_w1,'es')||' fr='||public.fn_work_display_title(v_w1,'fr')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staff, 'role', 'authenticated')::text, true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 set_work_title pose un titre manuel, le vide le retire';
  BEGIN
    PERFORM public.set_work_title(v_w1, 'fr', '  Zzl''entraide  ');
    v_txt := public.fn_work_display_title(v_w1, 'fr');
    PERFORM public.set_work_title(v_w1, 'fr', '   ');
    v_txt2 := public.fn_work_display_title(v_w1, 'fr');
    IF v_txt = 'Zzl''entraide' AND v_txt2 = 'Zzapoio mutuo' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt||' / '||v_txt2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 corriger la notice corrige le titre d''edition, jamais un titre manuel';
  BEGIN
    PERFORM public.set_work_title(v_w1, 'es', 'Zzla ayuda mutua');
    UPDATE public.books SET titulo = 'Zzel apoyo mutuo (corrigido)' WHERE id = v_b2;
    UPDATE public.books SET titulo = 'Zzapoio mútuo (corrigido)' WHERE id = v_b1;
    SELECT title, source INTO v_txt, v_src FROM public.work_titles WHERE work_id = v_w1 AND lang = 'es';
    SELECT title INTO v_txt2 FROM public.work_titles WHERE work_id = v_w1 AND lang = 'pt-BR';
    IF v_txt = 'Zzla ayuda mutua' AND v_src = 'manual' AND v_txt2 = 'Zzapoio mútuo (corrigido)' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : es='||coalesce(v_txt,'NULL')||'/'||coalesce(v_src,'NULL')||' pt='||coalesce(v_txt2,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 la pre-traduction remplit les locales manquantes sans recouvrir, puis se tait';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.fn_work_titles_pending(1000) p WHERE p.work_id = v_w1 AND 'fr' = ANY(p.missing) AND NOT ('es' = ANY(p.missing))) THEN
      RAISE EXCEPTION 'l''oeuvre n''est pas en attente comme attendu';
    END IF;
    v_n := public.fn_work_titles_autofill_apply(v_w1, '{"fr": "Zzl''entraide (auto)", "es": "Zzne doit pas passer", "xx": "Zzlocale inconnue"}'::jsonb, NULL);
    SELECT title, source, needs_review INTO v_txt, v_src, v_rev FROM public.work_titles WHERE work_id = v_w1 AND lang = 'fr';
    SELECT title INTO v_txt2 FROM public.work_titles WHERE work_id = v_w1 AND lang = 'es';
    IF v_n = 1 AND v_txt = 'Zzl''entraide (auto)' AND v_src = 'auto' AND v_rev
       AND v_txt2 = 'Zzla ayuda mutua'
       AND NOT EXISTS (SELECT 1 FROM public.work_titles WHERE work_id = v_w1 AND lang = 'xx')
       AND NOT EXISTS (SELECT 1 FROM public.fn_work_titles_pending(1000) p WHERE p.work_id = v_w1)
       AND (SELECT titles_autofill_at FROM public.works WHERE id = v_w1) IS NOT NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : n='||v_n||' fr='||coalesce(v_txt,'NULL')||'/'||coalesce(v_src,'NULL')||' es='||coalesce(v_txt2,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5b une vraie edition remplace un titre auto ; un titre manuel reste';
  BEGIN
    INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzl''entraide, un facteur de l''evolution', 'ZZKROPOTKIN, Piotr', 'fr', '1979', v_w1) RETURNING id INTO v_b3;
    SELECT title, source INTO v_txt, v_src FROM public.work_titles WHERE work_id = v_w1 AND lang = 'fr';
    IF v_txt = 'Zzl''entraide, un facteur de l''evolution' AND v_src = 'edition' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : fr='||coalesce(v_txt,'NULL')||'/'||coalesce(v_src,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 merge_works emporte les titres manuels de la source';
  BEGIN
    INSERT INTO public.works (uniform_title, sort_title, primary_author_id) VALUES ('Zzmutual aid', 'zzmutual aid', v_author) RETURNING id INTO v_w2;
    PERFORM public.set_work_title(v_w2, 'de', 'Zzgegenseitige Hilfe');
    PERFORM public.set_work_title(v_w2, 'es', 'Zzne doit pas ecraser le manuel de la cible');
    PERFORM public.merge_works(v_w2, v_w1);
    SELECT title INTO v_txt FROM public.work_titles WHERE work_id = v_w1 AND lang = 'de';
    SELECT title INTO v_txt2 FROM public.work_titles WHERE work_id = v_w1 AND lang = 'es';
    IF v_txt = 'Zzgegenseitige Hilfe' AND v_txt2 = 'Zzla ayuda mutua' AND NOT EXISTS (SELECT 1 FROM public.works WHERE id = v_w2)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : de='||coalesce(v_txt,'NULL')||' es='||coalesce(v_txt2,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  PERFORM set_config('request.jwt.claims', NULL, true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 cron planifie ; anon lit les titres mais n''ecrit rien ; l''autofill est au service';
  BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anarbib-work-titles-autofill')
       AND has_table_privilege('anon', 'public.work_titles', 'SELECT')
       AND NOT has_table_privilege('anon', 'public.work_titles', 'INSERT')
       AND NOT has_function_privilege('anon', 'public.set_work_title(bigint,text,text)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.fn_work_titles_autofill_apply(bigint,jsonb,text)', 'EXECUTE')
       AND has_function_privilege('service_role', 'public.fn_work_titles_pending(integer)', 'EXECUTE')
       AND has_function_privilege('anon', 'api.work_public_detail(bigint,text)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : cron ou grants'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Nettoyage ─────────────────────────────────────────────────────
  DELETE FROM public.books WHERE id IN (v_b1, v_b2, v_b3);
  DELETE FROM public.works WHERE primary_author_id = v_author;
  DELETE FROM public.authors WHERE id = v_author;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'WORK-TITLES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE NOTICE 'WORK-TITLES OK : %/%', v_passed, v_passed + v_failed;
END $$;
