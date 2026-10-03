-- =====================================================================
-- AnarBib — Tests d'acceptation : une reprise jamais enregistrée s'oublie
-- Date    : 2026-10-03
-- Ref     : migration 20261003202521_une_reprise_non_enregistree_s_oublie
-- Session : Reprises vierges & confirmation d'enregistrement
--
-- Une suite DO-block tient dans UNE transaction : now() n'y bouge pas. Pour
-- jouer « plus tard » (un autre appel PostgREST), on recule created_at sous la
-- garde anarbib.skip_touch_updated_at — le geste qui n'altère pas le drapeau.
--
-- T1  naissance : les trois RPC de reprise posent retake_untouched ; une
--     notice écrite depuis l'écran (rôle authenticated) ne naît jamais vierge,
--     même en action = 'update'.
-- T2  ouvrir n'est pas modifier : fn_touch_draft_opened garde le drapeau.
-- T3  la première écriture le retire ; l'écran ne peut pas le réarmer.
-- T4  écrire un sujet de la notice, c'est modifier la notice.
-- T5  discard_untouched_retake : oublie la reprise vierge de son autrice, sans
--     entrée au journal ni corbeille ; refuse (false, sans erreur) celle
--     d'autrui, une reprise enregistrée, une notice qui porte un exemplaire.
-- T6  filet : fn_purge_untouched_retakes oublie les reprises vierges de plus
--     de 24 h, pas les récentes, pas les enregistrées ; le job cron est planifié.
-- T7  droits : discard ouverte à authenticated seulement ; purge fermée au front.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'REPRISES-VIERGES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coordA uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_libA   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_autre uuid;
  v_book bigint; v_author bigint; v_ex bigint; v_subject bigint;
  v_rb bigint; v_ra bigint; v_rx bigint; v_rb2 bigint; v_rb3 bigint; v_ra2 bigint;
  v_old bigint; v_recent bigint; v_saved bigint;
  v_id bigint; v_n int; v_ok boolean; v_ok2 boolean; v_txt text; v_audit int;
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'rv-autre-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id INTO v_autre;
  INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_autre, 'Essai', 'RV') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_autre, v_libA, 'librarian', 'active', true);

  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('RV Livre publie', 'RV-1', 'livro', v_libA) RETURNING id INTO v_book;
  INSERT INTO public.authors (preferred_name) VALUES ('RV Autorite publiee') RETURNING id INTO v_author;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, circulation_policy)
  VALUES ('RV-1', 'RV-TOMBO-1', v_libA, 'emprestavel') RETURNING id INTO v_ex;
  INSERT INTO public.subjects (slug) VALUES ('rv-sujet-essai') RETURNING id INTO v_subject;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  v_rb := public.create_book_draft_from_book(v_book, NULL);
  v_ra := public.create_author_draft_from_author(v_author, NULL);
  v_rx := public.create_exemplar_draft_from_exemplar(v_ex, NULL);

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 naissance : les reprises seulement';
  BEGIN
    v_txt := '';
    IF NOT (SELECT retake_untouched FROM public.book_drafts     WHERE id = v_rb) THEN v_txt := v_txt || 'notice '; END IF;
    IF NOT (SELECT retake_untouched FROM public.author_drafts   WHERE id = v_ra) THEN v_txt := v_txt || 'autorite '; END IF;
    IF NOT (SELECT retake_untouched FROM public.exemplar_drafts WHERE id = v_rx) THEN v_txt := v_txt || 'exemplaire '; END IF;
    -- L'écran : INSERT direct sous authenticated, action 'update', drapeau demandé.
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, action, published_book_id, retake_untouched)
    VALUES ('RV Saisie ecran', 'livro', v_libA, v_coordA, 'draft', 'update', v_book, true) RETURNING id INTO v_id;
    EXECUTE 'RESET ROLE';
    IF (SELECT retake_untouched FROM public.book_drafts WHERE id = v_id) THEN v_txt := v_txt || 'saisie-ecran-vierge '; END IF;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
    VALUES ('RV Creation', 'livro', v_libA, v_coordA, 'draft') RETURNING id INTO v_id;
    IF (SELECT retake_untouched FROM public.book_drafts WHERE id = v_id) THEN v_txt := v_txt || 'creation-vierge '; END IF;
    IF v_txt = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- « Plus tard » : les trois reprises datent d'une minute.
  PERFORM set_config('anarbib.skip_touch_updated_at', 'on', true);
  UPDATE public.book_drafts     SET created_at = created_at - interval '1 minute' WHERE id = v_rb;
  UPDATE public.author_drafts   SET created_at = created_at - interval '1 minute' WHERE id = v_ra;
  UPDATE public.exemplar_drafts SET created_at = created_at - interval '1 minute' WHERE id = v_rx;
  PERFORM set_config('anarbib.skip_touch_updated_at', '', true);

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 ouvrir n''est pas modifier';
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_touch_draft_opened('book', v_rb);
    PERFORM public.fn_touch_draft_opened('author', v_ra);
    PERFORM public.fn_touch_draft_opened('exemplar', v_rx);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('anarbib.skip_touch_updated_at', '', true);
    IF (SELECT retake_untouched AND last_opened_at IS NOT NULL FROM public.book_drafts WHERE id = v_rb)
       AND (SELECT retake_untouched FROM public.author_drafts WHERE id = v_ra)
       AND (SELECT retake_untouched FROM public.exemplar_drafts WHERE id = v_rx)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : drapeau perdu a l''ouverture'); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 la premiere ecriture le retire, l''ecran ne le rearme pas';
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.author_drafts SET notes = 'RV enregistre' WHERE id = v_ra;
    UPDATE public.author_drafts SET retake_untouched = true WHERE id = v_ra;
    EXECUTE 'RESET ROLE';
    IF NOT (SELECT retake_untouched FROM public.author_drafts WHERE id = v_ra)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : autorite enregistree encore vierge'); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 un sujet ecrit modifie la notice';
  BEGIN
    v_rb2 := public.create_book_draft_from_book(v_book, NULL);
    PERFORM set_config('anarbib.skip_touch_updated_at', 'on', true);
    UPDATE public.book_drafts SET created_at = created_at - interval '1 minute' WHERE id = v_rb2;
    PERFORM set_config('anarbib.skip_touch_updated_at', '', true);
    v_ok := (SELECT retake_untouched FROM public.book_drafts WHERE id = v_rb2);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.book_draft_subjects (book_draft_id, subject_id) VALUES (v_rb2, v_subject);
    EXECUTE 'RESET ROLE';
    IF v_ok AND NOT (SELECT retake_untouched FROM public.book_drafts WHERE id = v_rb2)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : avant='||coalesce(v_ok::text,'∅')||' apres='||(SELECT retake_untouched FROM public.book_drafts WHERE id = v_rb2)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 oubli a l''abandon';
  BEGIN
    v_txt := '';
    SELECT count(*) INTO v_audit FROM public.catalog_audit_log WHERE action = 'delete';
    -- d'autrui : refusé, sans erreur
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_autre, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_ok := public.discard_untouched_retake('exemplar', v_rx);
    EXECUTE 'RESET ROLE';
    IF v_ok OR NOT EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE id = v_rx) THEN v_txt := v_txt || 'oubliee-par-autrui '; END IF;
    -- de son autrice : oubliée
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_ok := public.discard_untouched_retake('exemplar', v_rx);
    v_ok2 := public.discard_untouched_retake('book', v_rb);
    EXECUTE 'RESET ROLE';
    IF NOT v_ok OR EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE id = v_rx) THEN v_txt := v_txt || 'exemplaire-garde '; END IF;
    IF NOT v_ok2 OR EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_rb) THEN v_txt := v_txt || 'notice-gardee '; END IF;
    -- enregistrée : gardée
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_ok := public.discard_untouched_retake('author', v_ra);
    EXECUTE 'RESET ROLE';
    IF v_ok OR NOT EXISTS (SELECT 1 FROM public.author_drafts WHERE id = v_ra) THEN v_txt := v_txt || 'autorite-enregistree-oubliee '; END IF;
    -- notice vierge qui porte un exemplaire : gardée
    v_rb3 := public.create_book_draft_from_book(v_book, NULL);
    INSERT INTO public.exemplar_drafts (action, status, label_status, book_draft_id, created_by)
    VALUES ('create', 'draft', 'pending', v_rb3, v_coordA);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_ok := public.discard_untouched_retake('book', v_rb3);
    EXECUTE 'RESET ROLE';
    IF v_ok OR NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_rb3) THEN v_txt := v_txt || 'notice-avec-exemplaire-oubliee '; END IF;
    -- ni journal, ni corbeille
    IF (SELECT count(*) FROM public.catalog_audit_log WHERE action = 'delete') <> v_audit THEN v_txt := v_txt || 'journal-ecrit '; END IF;
    IF v_txt = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 filet horaire : plus de 24 h';
  BEGIN
    v_txt := '';
    SELECT count(*) INTO v_audit FROM public.catalog_audit_log WHERE action = 'delete';
    v_old    := public.create_author_draft_from_author(v_author, NULL);
    v_recent := public.create_author_draft_from_author(v_author, NULL);
    v_saved  := public.create_author_draft_from_author(v_author, NULL);
    PERFORM set_config('anarbib.skip_touch_updated_at', 'on', true);
    UPDATE public.author_drafts SET created_at = now() - interval '2 days' WHERE id IN (v_old, v_saved);
    UPDATE public.author_drafts SET created_at = now() - interval '1 hour' WHERE id = v_recent;
    PERFORM set_config('anarbib.skip_touch_updated_at', '', true);
    UPDATE public.author_drafts SET notes = 'RV enregistre' WHERE id = v_saved;
    v_n := private.fn_purge_untouched_retakes();
    IF EXISTS (SELECT 1 FROM public.author_drafts WHERE id = v_old)        THEN v_txt := v_txt || 'ancienne-gardee '; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.author_drafts WHERE id = v_recent) THEN v_txt := v_txt || 'recente-oubliee '; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.author_drafts WHERE id = v_saved)  THEN v_txt := v_txt || 'enregistree-oubliee '; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_rb3)      THEN v_txt := v_txt || 'notice-avec-exemplaire-purgee '; END IF;
    IF (SELECT count(*) FROM public.catalog_audit_log WHERE action = 'delete') <> v_audit THEN v_txt := v_txt || 'journal-ecrit '; END IF;
    IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anarbib-purge-untouched-retakes'
                    AND command ILIKE '%private.fn_purge_untouched_retakes()%') THEN v_txt := v_txt || 'job-absent '; END IF;
    IF v_txt = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt||'(purgees='||v_n||')'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 droits';
  BEGIN
    IF NOT has_function_privilege('anon', 'public.discard_untouched_retake(text, bigint)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.discard_untouched_retake(text, bigint)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'private.fn_purge_untouched_retakes(interval)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'private.fn_purge_untouched_retakes(interval)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : privileges inattendus'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'REPRISES-VIERGES OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'REPRISES-VIERGES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
