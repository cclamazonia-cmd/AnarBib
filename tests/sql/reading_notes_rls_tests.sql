-- =====================================================================
-- AnarBib — Tests d'acceptation RLS : NOTES DE LECTURE (notes-de-lecture)
-- Date : 2026-08-04 · Session : notes de lecture (Lot 4)
-- Réf  : migrations 20260803185613 (Lot 1 schéma+RLS), 20260803202157 (Lot 2
--        fn_my_reading_note_target), 20260804113000 (Lot 4 fix policy INSERT).
--        Cadrage : docs/journal/cadrages/CADRAGE_notes_de_lecture_2026-08-01.md
--
-- Particularité : ces tests exercent la RLS RÉELLE (pas seulement des RPC
-- SECURITY DEFINER). On bascule donc en `SET ROLE authenticated` (rôle NON
-- superutilisateur -> RLS appliquée) et on pilote l'identité via le JWT simulé
-- (set_config request.jwt.claims). Les FIXTURES et les VÉRIFICATIONS de vérité-
-- terrain se font en postgres (RESET ROLE, RLS contournée).
--
-- Couvre : INSERT (lecteur validé OK ; non-membre / restreint / biblio non
-- activée refusés ; anti-usurpation d'auteur ; unicité par œuvre+auteur),
-- SELECT (note publiée visible réseau ; note masquée invisible aux tiers, visible
-- à l'auteur·rice et au staff), UPDATE auteur·rice (édition body -> edited ;
-- statut figé) et staff (modère le statut ; contenu figé ; staff d'une AUTRE
-- biblio ne peut rien), signalements (créer sur note publiée seulement ; lecture
-- + résolution réservées au staff d'origine ; le signaleur voit le sien), DELETE
-- (auteur·rice et staff ; tiers refusé).
--   Bilan OK : 'READING-NOTES-RLS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_n int; v_status text; v_body text; v_author uuid; v_edited boolean;
  v_hidden_by uuid; v_hidden_at timestamptz; v_ts timestamptz;

  c_blmf    constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca'; -- biblio seedée
  c_staff   constant uuid := '11111111-1111-1111-1111-111111111111'; -- coordenador BLMF (seed)
  c_outsider constant uuid := '22222222-2222-2222-2222-222222222222'; -- sans adhésion (seed)
  c_reader     constant uuid := 'ccccddaa-0000-4000-8000-000000000001';
  c_reader2    constant uuid := 'ccccddaa-0000-4000-8000-000000000002';
  c_restricted constant uuid := 'ccccddaa-0000-4000-8000-000000000003';
  c_lib2_staff constant uuid := 'ccccddaa-0000-4000-8000-000000000004';
  c_lib2_reader constant uuid := 'ccccddaa-0000-4000-8000-000000000005';
  c_lib3_reader constant uuid := 'ccccddaa-0000-4000-8000-000000000006';
  c_lib2 constant uuid := 'ddddaabb-0000-4000-8000-000000000002';
  c_lib3 constant uuid := 'ddddaabb-0000-4000-8000-000000000003';

  v_work bigint; v_note1 bigint; v_note2 bigint; v_report bigint; v_rec record;
BEGIN
  -- ═══════════════════════ FIXTURES (postgres) ═══════════════════════════
  -- Biblio d'origine BLMF : activer les notes de lecture.
  INSERT INTO public.library_service_state (library_id, reading_notes_enabled)
  VALUES (c_blmf, true)
  ON CONFLICT (library_id) DO UPDATE SET reading_notes_enabled = true;

  -- 2e biblio (activée) : sert à tester l'isolement staff / la visibilité réseau.
  INSERT INTO public.libraries (id, slug, name)
  VALUES (c_lib2, 'lib2-notes-test', 'Biblio 2 (test notes)')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.library_service_state (library_id, reading_notes_enabled)
  VALUES (c_lib2, true) ON CONFLICT (library_id) DO UPDATE SET reading_notes_enabled = true;

  -- 3e biblio : notes NON activées (opt-in par défaut false) -> insertion refusée.
  INSERT INTO public.libraries (id, slug, name)
  VALUES (c_lib3, 'lib3-notes-test', 'Biblio 3 (notes off)')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.library_service_state (library_id, reading_notes_enabled)
  VALUES (c_lib3, false) ON CONFLICT (library_id) DO UPDATE SET reading_notes_enabled = false;

  -- Comptes auth + profils.
  FOR v_rec IN SELECT * FROM (VALUES
    (c_reader,'reader'),(c_reader2,'reader2'),(c_restricted,'restr'),
    (c_lib2_staff,'lib2staff'),(c_lib2_reader,'lib2reader'),(c_lib3_reader,'lib3reader')
  ) AS x(uid, sfx) LOOP
    INSERT INTO auth.users (instance_id,id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000000', v_rec.uid,'authenticated','authenticated',
            v_rec.sfx||'.notes@anarbib.local', now(),now(),now(),
            '{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.profiles (id,email,first_name,last_name,preferred_language)
    VALUES (v_rec.uid, v_rec.sfx||'.notes@anarbib.local', v_rec.sfx, 'Test','fr')
    ON CONFLICT (id) DO NOTHING;
  END LOOP;

  -- Adhésions.
  INSERT INTO public.user_library_memberships (user_id,library_id,role,status,is_restricted)
  VALUES
    (c_reader,      c_blmf, 'reader',      'active', false),
    (c_reader2,     c_blmf, 'reader',      'active', false),
    (c_restricted,  c_blmf, 'reader',      'active', true),   -- restreint -> pas d'écriture
    (c_lib2_staff,  c_lib2, 'coordenador', 'active', false),
    (c_lib2_reader, c_lib2, 'reader',      'active', false),
    (c_lib3_reader, c_lib3, 'reader',      'active', false)
  ON CONFLICT DO NOTHING;

  -- Une œuvre support.
  INSERT INTO public.works (uniform_title) VALUES ('Œuvre test — notes de lecture')
  RETURNING id INTO v_work;

  -- ═══════════════════ A. INSERT (with-check + trigger) ══════════════════
  v_t := 'A1 lecteur validé publie une note -> OK';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub',c_reader,'role','authenticated')::text, true);
    INSERT INTO public.book_reading_notes (work_id, author_user_id, author_pseudonym, origin_library_id, body)
    VALUES (v_work, c_reader, 'Camarade Un', c_blmf, 'Une belle lecture, très stimulante.')
    RETURNING id INTO v_note1;
    RESET ROLE;
    v_passed := v_passed+1;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' a levé: '||SQLERRM); END;

  v_t := 'A2 trigger force author=soi, status=published, edited=false';
  RESET ROLE;
  SELECT author_user_id, status, edited INTO v_author, v_status, v_edited
    FROM public.book_reading_notes WHERE id = v_note1;
  IF v_author = c_reader AND v_status = 'published' AND v_edited = false
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1;
    v_failures:=v_failures||(v_t||' got author='||coalesce(v_author::text,'∅')||' status='||coalesce(v_status,'∅')||' edited='||coalesce(v_edited::text,'∅')); END IF;

  v_t := 'A3 non-membre publie -> refus RLS';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub',c_outsider,'role','authenticated')::text, true);
    INSERT INTO public.book_reading_notes (work_id, author_user_id, author_pseudonym, origin_library_id, body)
    VALUES (v_work, c_outsider, 'Intrus', c_blmf, 'je ne devrais pas pouvoir');
    RESET ROLE; v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_passed:=v_passed+1; END;

  v_t := 'A4 membre restreint publie -> refus RLS';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub',c_restricted,'role','authenticated')::text, true);
    INSERT INTO public.book_reading_notes (work_id, author_user_id, author_pseudonym, origin_library_id, body)
    VALUES (v_work, c_restricted, 'Restreint', c_blmf, 'moi non plus');
    RESET ROLE; v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_passed:=v_passed+1; END;

  v_t := 'A5 biblio non activée (opt-in off) -> refus RLS [couvre le fix Lot 4]';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub',c_lib3_reader,'role','authenticated')::text, true);
    INSERT INTO public.book_reading_notes (work_id, author_user_id, author_pseudonym, origin_library_id, body)
    VALUES (v_work, c_lib3_reader, 'Lib3', c_lib3, 'notes désactivées ici');
    RESET ROLE; v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_passed:=v_passed+1; END;

  v_t := 'A6 usurpation d''auteur neutralisée (author forcé = soi)';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub',c_reader2,'role','authenticated')::text, true);
    -- reader2 tente de publier au nom de l'outsider : le trigger force author=reader2.
    INSERT INTO public.book_reading_notes (work_id, author_user_id, author_pseudonym, origin_library_id, body)
    VALUES (v_work, c_outsider, 'Camarade Deux', c_blmf, 'Deuxième regard sur l''œuvre.')
    RETURNING id INTO v_note2;
    RESET ROLE;
    SELECT author_user_id INTO v_author FROM public.book_reading_notes WHERE id = v_note2;
    IF v_author = c_reader2 THEN v_passed:=v_passed+1;
      ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' author='||coalesce(v_author::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' a levé: '||SQLERRM); END;

  v_t := 'A7 unicité : 2e note même œuvre+auteur -> refus';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub',c_reader,'role','authenticated')::text, true);
    INSERT INTO public.book_reading_notes (work_id, author_user_id, author_pseudonym, origin_library_id, body)
    VALUES (v_work, c_reader, 'Camarade Un', c_blmf, 'un doublon');
    RESET ROLE; v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever (unicité)');
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_passed:=v_passed+1; END;

  -- ═══════════════════ B. SELECT visibilité (publiée) ════════════════════
  v_t := 'B1 note publiée visible d''un lecteur d''une AUTRE biblio (réseau)';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_lib2_reader,'role','authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.book_reading_notes WHERE work_id = v_work AND status='published';
  RESET ROLE;
  IF v_n >= 2 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;

  -- ═══════════════════ C. UPDATE auteur·rice + trigger ═══════════════════
  v_t := 'C1 auteur·rice édite body -> edited=true, body changé';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_reader,'role','authenticated')::text, true);
  UPDATE public.book_reading_notes SET body = 'Version révisée de ma note.' WHERE id = v_note1;
  RESET ROLE;
  SELECT body, edited, status INTO v_body, v_edited, v_status FROM public.book_reading_notes WHERE id = v_note1;
  IF v_body = 'Version révisée de ma note.' AND v_edited = true AND v_status='published'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1;
    v_failures:=v_failures||(v_t||' body='||coalesce(v_body,'∅')||' edited='||coalesce(v_edited::text,'∅')); END IF;

  v_t := 'C2 auteur·rice ne peut pas changer le statut (trigger fige)';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_reader,'role','authenticated')::text, true);
  UPDATE public.book_reading_notes SET status = 'hidden' WHERE id = v_note1;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RESET ROLE;
  SELECT status INTO v_status FROM public.book_reading_notes WHERE id = v_note1;
  IF v_status = 'published' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' status='||coalesce(v_status,'∅')); END IF;

  v_t := 'C3 lecteur tiers ne peut pas éditer la note d''autrui -> 0 ligne';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_reader2,'role','authenticated')::text, true);
  UPDATE public.book_reading_notes SET body = 'sabotage' WHERE id = v_note1;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RESET ROLE;
  SELECT body INTO v_body FROM public.book_reading_notes WHERE id = v_note1;
  IF v_n = 0 AND v_body = 'Version révisée de ma note.' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' rows='||v_n||' body='||coalesce(v_body,'∅')); END IF;

  -- ═══════════════════ D. UPDATE staff (modération) ══════════════════════
  v_t := 'D1 staff d''origine masque -> status=hidden + hidden_by/hidden_at';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_staff,'role','authenticated')::text, true);
  UPDATE public.book_reading_notes SET status = 'hidden' WHERE id = v_note1;
  RESET ROLE;
  SELECT status, hidden_by, hidden_at INTO v_status, v_hidden_by, v_hidden_at FROM public.book_reading_notes WHERE id = v_note1;
  IF v_status='hidden' AND v_hidden_by = c_staff AND v_hidden_at IS NOT NULL
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1;
    v_failures:=v_failures||(v_t||' status='||coalesce(v_status,'∅')||' by='||coalesce(v_hidden_by::text,'∅')); END IF;

  v_t := 'D2 staff ne peut pas réécrire le contenu (trigger fige body)';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_staff,'role','authenticated')::text, true);
  UPDATE public.book_reading_notes SET body = 'réécrit par le staff', status='hidden' WHERE id = v_note2;
  RESET ROLE;
  SELECT body, status INTO v_body, v_status FROM public.book_reading_notes WHERE id = v_note2;
  IF v_body = 'Deuxième regard sur l''œuvre.' AND v_status='hidden'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1;
    v_failures:=v_failures||(v_t||' body='||coalesce(v_body,'∅')||' status='||coalesce(v_status,'∅')); END IF;

  v_t := 'D3 staff d''une AUTRE biblio ne peut pas modérer -> 0 ligne';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_lib2_staff,'role','authenticated')::text, true);
  UPDATE public.book_reading_notes SET status = 'published' WHERE id = v_note1;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RESET ROLE;
  IF v_n = 0 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' rows='||v_n); END IF;

  -- Visibilité d'une note masquée (v_note1 est hidden).
  v_t := 'D4a note masquée invisible au lecteur tiers';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_lib2_reader,'role','authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.book_reading_notes WHERE id = v_note1;
  RESET ROLE;
  IF v_n = 0 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;

  v_t := 'D4b note masquée visible de son auteur·rice';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_reader,'role','authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.book_reading_notes WHERE id = v_note1;
  RESET ROLE;
  IF v_n = 1 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;

  v_t := 'D4c note masquée visible du staff d''origine';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_staff,'role','authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.book_reading_notes WHERE id = v_note1;
  RESET ROLE;
  IF v_n = 1 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;

  v_t := 'D5 staff rétablit -> status=published, hidden_by/at effacés';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_staff,'role','authenticated')::text, true);
  UPDATE public.book_reading_notes SET status = 'published' WHERE id = v_note1;
  RESET ROLE;
  SELECT status, hidden_by, hidden_at INTO v_status, v_hidden_by, v_hidden_at FROM public.book_reading_notes WHERE id = v_note1;
  IF v_status='published' AND v_hidden_by IS NULL AND v_hidden_at IS NULL
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1;
    v_failures:=v_failures||(v_t||' status='||coalesce(v_status,'∅')||' by='||coalesce(v_hidden_by::text,'∅')); END IF;

  -- ═══════════════════ E. Signalements ═══════════════════════════════════
  v_t := 'E1 lecteur signale une note publiée -> OK';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub',c_reader2,'role','authenticated')::text, true);
    INSERT INTO public.book_reading_note_reports (note_id, reporter_user_id, reason)
    VALUES (v_note1, c_reader2, 'contenu problématique') RETURNING id INTO v_report;
    RESET ROLE; v_passed:=v_passed+1;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' a levé: '||SQLERRM); END;

  -- Masquer v_note1 pour tester le refus de signalement sur note non publiée.
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_staff,'role','authenticated')::text, true);
  UPDATE public.book_reading_notes SET status='hidden' WHERE id = v_note1;
  RESET ROLE;

  v_t := 'E2 signaler une note NON publiée -> refus RLS';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub',c_lib2_reader,'role','authenticated')::text, true);
    INSERT INTO public.book_reading_note_reports (note_id, reporter_user_id, reason)
    VALUES (v_note1, c_lib2_reader, 'trop tard');
    RESET ROLE; v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_passed:=v_passed+1; END;

  v_t := 'E3 staff d''origine lit les signalements de ses notes';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_staff,'role','authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.book_reading_note_reports WHERE note_id = v_note1;
  RESET ROLE;
  IF v_n >= 1 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;

  v_t := 'E4 staff d''une AUTRE biblio ne voit pas ces signalements -> 0';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_lib2_staff,'role','authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.book_reading_note_reports WHERE note_id = v_note1;
  RESET ROLE;
  IF v_n = 0 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;

  v_t := 'E5 le signaleur voit son propre signalement';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_reader2,'role','authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.book_reading_note_reports WHERE id = v_report;
  RESET ROLE;
  IF v_n = 1 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;

  v_t := 'E6 staff d''origine résout le signalement -> resolved_at posé';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_staff,'role','authenticated')::text, true);
  UPDATE public.book_reading_note_reports SET resolved_at = now(), resolved_by = c_staff WHERE id = v_report;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RESET ROLE;
  SELECT resolved_at INTO v_ts FROM public.book_reading_note_reports WHERE id = v_report;
  IF v_n = 1 AND v_ts IS NOT NULL THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' rows='||v_n); END IF;

  v_t := 'E7 le signaleur (non-staff) ne peut pas résoudre -> 0 ligne';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_reader2,'role','authenticated')::text, true);
  UPDATE public.book_reading_note_reports SET resolved_by = c_reader2 WHERE id = v_report;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RESET ROLE;
  IF v_n = 0 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' rows='||v_n); END IF;

  -- ═══════════════════ F. DELETE ═════════════════════════════════════════
  v_t := 'F1 auteur·rice supprime sa propre note -> OK';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_reader2,'role','authenticated')::text, true);
  DELETE FROM public.book_reading_notes WHERE id = v_note2;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RESET ROLE;
  IF v_n = 1 AND NOT EXISTS (SELECT 1 FROM public.book_reading_notes WHERE id = v_note2)
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' rows='||v_n); END IF;

  v_t := 'F2 tiers (non auteur, non staff) ne supprime pas -> 0 ligne';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_outsider,'role','authenticated')::text, true);
  DELETE FROM public.book_reading_notes WHERE id = v_note1;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RESET ROLE;
  IF v_n = 0 AND EXISTS (SELECT 1 FROM public.book_reading_notes WHERE id = v_note1)
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' rows='||v_n); END IF;

  v_t := 'F3 staff d''origine supprime en dernier recours -> OK';
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',c_staff,'role','authenticated')::text, true);
  DELETE FROM public.book_reading_notes WHERE id = v_note1;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RESET ROLE;
  IF v_n = 1 AND NOT EXISTS (SELECT 1 FROM public.book_reading_notes WHERE id = v_note1)
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' rows='||v_n); END IF;

  -- ═══════════════════ Bilan ═════════════════════════════════════════════
  RESET ROLE;
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'READING-NOTES-RLS OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'READING-NOTES-RLS ECHEC : %/% OK, % échec(s) | %',
      v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || ');
  END IF;
END $$;
