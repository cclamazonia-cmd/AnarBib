-- =====================================================================
-- AnarBib — Tests : correspondance entre bibliothèques, lot 1 (G19)
-- Date    : 2026-10-08
-- Ref     : 20261008195923_correspondance_entre_bibliotheques_lot_1
--           REGISTRE CORR-1 à CORR-6
--
-- Trois bibliothèques A, B, C ; une coordination de chacune (cA, cB, cC), une
-- bibliothécaire de A (lA), une administration du réseau sans bibliothèque
-- (nA). Les lectures passent sous `SET ROLE authenticated` + jeton simulé :
-- c'est la politique qui est éprouvée, pas le superutilisateur.
--
-- Couvre :
--   T1  cA ouvre un fil A → B : fil, deux participantes, premier message en
--       français, lu par cA ; cA le voit ;
--   T2  lA (bibliothécaire) ne peut pas ouvrir (not_coordinator, CORR-1) ;
--   T3  cC ne voit rien du fil A–B (fil, participantes, messages) et ne peut
--       pas y écrire (not_participant) ;
--   T4  cB voit le fil et répond sans donner de langue : celle de son profil
--       (pt-BR) ; last_message_at avance ; cA a un non-lu ;
--   T5  cB archive pour B seulement ; un message de A lève l'archivage ;
--   T6  cA marque lu : dernier message lu = le dernier du fil ;
--   T7  refus traduits : langue hors des dix, corps vide, corps trop long,
--       sujet vide, écrire à soi-même, destinataire inconnue ou inactive ;
--   T8  trente messages par 24 h, le trente et unième est refusé (53400) ;
--   T9  l'administration du réseau ne lit pas la correspondance (CORR-6) :
--       rien à lire, envoyer refusé, marquer lu refusé ;
--   T10 anon : aucune porte, aucune lecture ;
--   T11 structure : RLS sans FORCE, une permissive par table, index des clés
--       étrangères, CHECK des dix langues, aucun droit d'écriture pour
--       authenticated, aides internes fermées.
--   Bilan OK : 'CORRESPONDANCE-LOT1 OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_a  constant uuid := '6c190000-0000-4000-8000-0000000000a1';
  c_b  constant uuid := '6c190000-0000-4000-8000-0000000000b1';
  c_c  constant uuid := '6c190000-0000-4000-8000-0000000000c1';
  c_d  constant uuid := '6c190000-0000-4000-8000-0000000000d1';   -- inactive
  c_ca constant uuid := '6c190000-0000-4000-8000-000000000001';
  c_cb constant uuid := '6c190000-0000-4000-8000-000000000002';
  c_cc constant uuid := '6c190000-0000-4000-8000-000000000003';
  c_la constant uuid := '6c190000-0000-4000-8000-000000000004';
  c_na constant uuid := '6c190000-0000-4000-8000-000000000005';
  v_fil bigint; v_m1 bigint; v_m2 bigint; v_m3 bigint; v_n int; v_n2 int; v_n3 int; v_txt text; v_ts timestamptz; v_ts2 timestamptz; v_b boolean; v_i int;
  v_u uuid; v_e text; v_hint text;
BEGIN
  -- ── Fixtures ──
  INSERT INTO public.libraries (id, slug, name, visibility_level, catalog_mode, network_mode, is_active, default_locale) VALUES
    (c_a, 'corr-a', 'Biblio A (correspondance)', 'public', 'network_published', 'federated', true, 'fr'),
    (c_b, 'corr-b', 'Biblio B (correspondance)', 'public', 'network_published', 'federated', true, 'pt-BR'),
    (c_c, 'corr-c', 'Biblio C (correspondance)', 'public', 'network_published', 'federated', true, 'es'),
    (c_d, 'corr-d', 'Biblio D (inactive)',       'public', 'network_published', 'federated', false, 'fr')
  ON CONFLICT (id) DO NOTHING;
  FOR v_u, v_e IN SELECT * FROM (VALUES (c_ca, 'ca'), (c_cb, 'cb'), (c_cc, 'cc'), (c_la, 'la'), (c_na, 'na')) AS t(u, e) LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000000', v_u, 'authenticated', 'authenticated', v_e || '.corr@anarbib.local',
            now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
    VALUES (v_u, v_e || '.corr@anarbib.local', upper(v_e), 'Corr', CASE WHEN v_u = c_cb THEN 'pt-BR' ELSE 'fr' END)
    ON CONFLICT (id) DO NOTHING;
  END LOOP;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status) VALUES
    (c_ca, c_a, 'coordenador', 'active'), (c_cb, c_b, 'coordenador', 'active'),
    (c_cc, c_c, 'coordenador', 'active'), (c_la, c_a, 'librarian', 'active');
  INSERT INTO public.network_administrators (user_id, status) VALUES (c_na, 'active') ON CONFLICT DO NOTHING;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 cA ouvre un fil A → B : fil, deux participantes, premier message, lu, visible';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_ca, 'role', 'authenticated')::text, true);
    v_fil := api.fn_correspondance_ouvrir(c_a, c_b, 'Un échange de doubles ?', 'Bonjour, avez-vous des doubles de Reclus ?', 'fr');
    SELECT count(*) INTO v_n FROM public.library_conversations WHERE id = v_fil;                       -- sous la politique
    SELECT count(*) INTO v_n2 FROM public.library_conversation_participants WHERE conversation_id = v_fil;
    SELECT count(*), max(id) INTO v_n3, v_m1 FROM public.library_messages WHERE conversation_id = v_fil AND lang = 'fr' AND library_id = c_a AND author_id = c_ca;
    SELECT last_read_message_id INTO v_i FROM public.library_conversation_reads WHERE conversation_id = v_fil AND user_id = c_ca;
    RESET ROLE;
    IF v_n = 1 AND v_n2 = 2 AND v_n3 = 1 AND v_i = v_m1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : fil %s, participantes %s, messages %s, lu %s/%s', v_n, v_n2, v_n3, v_i, v_m1)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 une bibliothécaire ne peut pas ouvrir un fil (CORR-1)';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_la, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM api.fn_correspondance_ouvrir(c_a, c_b, 'Essai', 'Corps', 'fr');
      v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := SQLSTATE || ' ' || coalesce(v_hint, ''); END;
    RESET ROLE;
    IF v_txt = '42501 error.correspondance.not_coordinator' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 cC ne voit rien du fil A–B et ne peut pas y écrire';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_cc, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n  FROM public.library_conversations WHERE id = v_fil;
    SELECT count(*) INTO v_n2 FROM public.library_conversation_participants WHERE conversation_id = v_fil;
    SELECT count(*) INTO v_n3 FROM public.library_messages WHERE conversation_id = v_fil;
    BEGIN
      PERFORM api.fn_correspondance_envoyer(v_fil, c_c, 'Je m''invite', 'es');
      v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := SQLSTATE || ' ' || coalesce(v_hint, ''); END;
    RESET ROLE;
    IF v_n = 0 AND v_n2 = 0 AND v_n3 = 0 AND v_txt = '42501 error.correspondance.not_participant' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s/%s/%s, envoi %s', v_n, v_n2, v_n3, v_txt)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 cB voit le fil et répond dans la langue de son profil ; le fil porte la date du message ; cA a un non-lu';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_cb, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM public.library_conversations WHERE id = v_fil;
    v_m2 := api.fn_correspondance_envoyer(v_fil, c_b, 'Sim, temos dois exemplares.', NULL);
    SELECT lang INTO v_txt FROM public.library_messages WHERE id = v_m2;
    -- now() ne bouge pas dans une transaction : le fil porte la date du dernier message
    SELECT c.last_message_at = m.created_at INTO v_b FROM public.library_conversations c JOIN public.library_messages m ON m.id = v_m2 WHERE c.id = v_fil;
    RESET ROLE;
    SELECT last_read_message_id INTO v_i FROM public.library_conversation_reads WHERE conversation_id = v_fil AND user_id = c_ca;
    IF v_n = 1 AND v_txt = 'pt-BR' AND v_b AND v_i < v_m2 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : vu %s, lang %s, date du fil = message %s, lu %s < %s', v_n, v_txt, v_b, v_i, v_m2)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 cB archive pour B seulement ; un message de A lève l''archivage';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_cb, 'role', 'authenticated')::text, true);
    PERFORM api.fn_correspondance_archiver(v_fil, c_b, true);
    RESET ROLE;
    SELECT count(*) INTO v_n FROM public.library_conversation_participants WHERE conversation_id = v_fil AND archived_at IS NOT NULL AND library_id = c_b;
    SELECT count(*) INTO v_n2 FROM public.library_conversation_participants WHERE conversation_id = v_fil AND archived_at IS NOT NULL;
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_ca, 'role', 'authenticated')::text, true);
    v_m3 := api.fn_correspondance_envoyer(v_fil, c_a, 'Parfait, je passe vous voir.', 'fr');
    RESET ROLE;
    SELECT count(*) INTO v_n3 FROM public.library_conversation_participants WHERE conversation_id = v_fil AND archived_at IS NOT NULL;
    IF v_n = 1 AND v_n2 = 1 AND v_n3 = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : B archivé %s, archivés %s, après message %s', v_n, v_n2, v_n3)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 cB marque lu : dernier message lu = le dernier du fil';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_cb, 'role', 'authenticated')::text, true);
    v_i := api.fn_correspondance_lue(v_fil);
    SELECT last_read_message_id INTO v_n FROM public.library_conversation_reads WHERE conversation_id = v_fil AND user_id = c_cb;
    SELECT count(*) INTO v_n2 FROM public.library_conversation_reads WHERE conversation_id = v_fil;   -- la politique : ses lignes seulement
    RESET ROLE;
    IF v_i = v_m3 AND v_n = v_m3 AND v_n2 = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : rendu %s, lu %s, dernier %s, lignes vues %s', v_i, v_n, v_m3, v_n2)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 refus traduits : langue, corps vide, trop long, sujet, soi-même, destinataire inconnue ou inactive';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_ca, 'role', 'authenticated')::text, true);
    v_txt := '';
    BEGIN PERFORM api.fn_correspondance_envoyer(v_fil, c_a, 'x', 'xx'); v_txt := v_txt || 'lang:passé ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(nullif(v_hint, ''), SQLSTATE) || ' '; END;
    BEGIN PERFORM api.fn_correspondance_envoyer(v_fil, c_a, '   ', 'fr'); v_txt := v_txt || 'vide:passé ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(nullif(v_hint, ''), SQLSTATE) || ' '; END;
    BEGIN PERFORM api.fn_correspondance_envoyer(v_fil, c_a, repeat('a', 4001), 'fr'); v_txt := v_txt || 'long:passé ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(nullif(v_hint, ''), SQLSTATE) || ' '; END;
    BEGIN PERFORM api.fn_correspondance_ouvrir(c_a, c_b, '  ', 'Corps', 'fr'); v_txt := v_txt || 'sujet:passé ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(nullif(v_hint, ''), SQLSTATE) || ' '; END;
    BEGIN PERFORM api.fn_correspondance_ouvrir(c_a, c_a, 'Sujet', 'Corps', 'fr'); v_txt := v_txt || 'soi:passé ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(nullif(v_hint, ''), SQLSTATE) || ' '; END;
    BEGIN PERFORM api.fn_correspondance_ouvrir(c_a, '6c190000-0000-4000-8000-0000000000ff', 'Sujet', 'Corps', 'fr'); v_txt := v_txt || 'inconnue:passé ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(nullif(v_hint, ''), SQLSTATE) || ' '; END;
    BEGIN PERFORM api.fn_correspondance_ouvrir(c_a, c_d, 'Sujet', 'Corps', 'fr'); v_txt := v_txt || 'inactive:passé ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(nullif(v_hint, ''), SQLSTATE) || ' '; END;
    RESET ROLE;
    IF v_txt = 'error.correspondance.lang_invalid error.correspondance.empty_body error.correspondance.body_too_long '
             || 'error.correspondance.subject_required error.correspondance.same_library error.correspondance.library_not_found error.correspondance.library_not_found ' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 trente messages par 24 h : le trente et unième est refusé';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_ca, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM public.library_messages WHERE author_id = c_ca AND created_at > now() - interval '24 hours';
    FOR v_i IN 1 .. (30 - v_n) LOOP
      PERFORM api.fn_correspondance_envoyer(v_fil, c_a, 'message ' || v_i, 'fr');
    END LOOP;
    BEGIN
      PERFORM api.fn_correspondance_envoyer(v_fil, c_a, 'un de trop', 'fr');
      v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := SQLSTATE || ' ' || coalesce(v_hint, ''); END;
    RESET ROLE;
    SELECT count(*) INTO v_n2 FROM public.library_messages WHERE author_id = c_ca;
    IF v_txt = '53400 error.correspondance.rate_limited' AND v_n2 = 30 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s, %s messages', v_txt, v_n2)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 l''administration du réseau ne lit pas la correspondance (CORR-6)';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_na, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM public.library_conversations;
    SELECT count(*) INTO v_n2 FROM public.library_messages;
    v_txt := '';
    BEGIN PERFORM api.fn_correspondance_envoyer(v_fil, c_a, 'admin', 'fr'); v_txt := v_txt || 'envoi:passé ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(nullif(v_hint, ''), SQLSTATE) || ' '; END;
    BEGIN PERFORM api.fn_correspondance_lue(v_fil); v_txt := v_txt || 'lue:passé ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(nullif(v_hint, ''), SQLSTATE) || ' '; END;
    RESET ROLE;
    IF v_n = 0 AND v_n2 = 0 AND v_txt = 'error.correspondance.not_coordinator error.correspondance.not_participant ' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : fils %s, messages %s, %s', v_n, v_n2, v_txt)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T10 anon : aucune porte, aucune lecture';
  BEGIN
    v_b := NOT has_function_privilege('anon', 'api.fn_correspondance_ouvrir(uuid, uuid, text, text, text)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'api.fn_correspondance_envoyer(bigint, uuid, text, text)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'api.fn_correspondance_archiver(bigint, uuid, boolean)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'api.fn_correspondance_lue(bigint)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'public.fn_correspondance_lit(bigint)', 'EXECUTE')
       AND NOT has_table_privilege('anon', 'public.library_conversations', 'SELECT')
       AND NOT has_table_privilege('anon', 'public.library_messages', 'SELECT')
       AND NOT has_table_privilege('anon', 'public.library_conversation_participants', 'SELECT')
       AND NOT has_table_privilege('anon', 'public.library_conversation_reads', 'SELECT');
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : une porte ou une lecture ouverte à anon'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T11 structure : RLS sans FORCE, une permissive par table, index des FK, CHECK des langues, pas d''écriture pour authenticated, aides fermées';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relname IN ('library_conversations', 'library_conversation_participants', 'library_messages', 'library_conversation_reads')
       AND c.relrowsecurity AND NOT c.relforcerowsecurity;
    SELECT count(*) INTO v_n2 FROM pg_policies WHERE schemaname = 'public'
       AND tablename IN ('library_conversations', 'library_conversation_participants', 'library_messages', 'library_conversation_reads');
    SELECT count(*) INTO v_n3 FROM pg_indexes WHERE schemaname = 'public' AND indexname IN (
      'library_conversations_created_by_idx', 'library_conversation_participants_library_idx', 'library_messages_conversation_idx',
      'library_messages_library_idx', 'library_messages_author_idx', 'library_conversation_reads_user_idx');
    v_b := v_n = 4 AND v_n2 = 4 AND v_n3 = 6
       AND EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'library_messages_lang_check' AND pg_get_constraintdef(oid) LIKE '%''eo''%')
       AND NOT has_table_privilege('authenticated', 'public.library_messages', 'INSERT')
       AND NOT has_table_privilege('authenticated', 'public.library_messages', 'UPDATE')
       AND NOT has_table_privilege('authenticated', 'public.library_messages', 'DELETE')
       AND NOT has_table_privilege('authenticated', 'public.library_conversations', 'INSERT')
       AND NOT has_function_privilege('authenticated', 'public.fn_correspondance_coordonne(uuid)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.fn_correspondance_poser_message(bigint, uuid, text, text)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.fn_correspondance_langue(text, uuid)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'api.fn_correspondance_ouvrir(uuid, uuid, text, text, text)', 'EXECUTE');
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : rls %s/4, politiques %s/4, index %s/6', v_n, v_n2, v_n3)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'CORRESPONDANCE-LOT1 ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'CORRESPONDANCE-LOT1 OK : %/%', v_passed, v_passed;
END $$;
