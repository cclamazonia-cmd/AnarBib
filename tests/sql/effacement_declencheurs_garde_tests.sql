-- =====================================================================
-- AnarBib — Tests d'acceptation : AUCUN DÉCLENCHEUR DE REFUS NE BLOQUE L'EFFACEMENT
-- Date    : 2026-10-23  ·  Réf : migrations 20261023203225_l_effacement_traverse_les_journaux_du_reseau.sql
--                                et 20261023220625_l_effacement_traverse_profil_et_notes_de_lecture.sql
--
-- fn_delete_my_account met à jour des tables directement (re-pointage vers le
-- jeton, compte « removido ») et, en supprimant le profil et le compte, par
-- les FK en ON DELETE SET NULL / SET DEFAULT. Un déclencheur BEFORE UPDATE qui
-- refuse cet UPDATE annule tout l'effacement : vécu le 23/10/2026 sur les deux
-- journaux du réseau, puis trouvé au banc sur le profil des bibliothèques et
-- les notes de lecture.
--
-- Couvre :
--   T1  liste VIVANTE — tout déclencheur BEFORE UPDATE actif d'une table que
--       l'effacement met à jour, et dont la fonction peut lever, connaît le
--       drapeau anarbib.effacement_compte ou figure dans la liste close des
--       refus conditionnels (avec leur motif). Un nouveau journal en ajout
--       seul fait rougir cette suite, pas la personne qui s'efface.
--   T2  la liste close ne désigne que des refus réels, encore attachés à une
--       table visée, et qui ne connaissent pas encore le drapeau.
--   T3  toute colonne en SET NULL / SET DEFAULT vers profiles ou auth.users
--       qui est NOT NULL, ou dont la table porte un déclencheur de refus, est
--       traitée dans le corps de fn_delete_my_account (avant la suppression).
--   T4  effacement réel d'une coordinatrice qui a changé et proposé un profil
--       de bibliothèque, annulé une proposition, écrit et masqué une note :
--       ok=true.
--   T5  après : profil au jeton, notes à NULL, reste des lignes intact.
--   T6  historique du profil, toujours refusé hors du re-pointage exact.
--   T7  propositions : verrou de proposed_by, toujours refusé hors du
--       re-pointage exact ; DELETE refusé.
--   T8  propositions : une colonne libre (status) se modifie comme avant.
--   T9  notes : refusé hors du passage exact à NULL ; l'autrice édite encore
--       sa note sous authenticated (SECURITY INVOKER sans régression).
--   Bilan OK : 'EFFACEMENT-DECLENCHEURS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int:=0; v_failed int:=0; v_failures text[]:=ARRAY[]::text[]; v_t text;
  -- Refus conditionnels : la fonction lève, mais pas sur ce que l'effacement
  -- change. Toute entrée dit pourquoi ; la liste ne s'allonge que consciemment.
  v_conditionnels constant text[] := ARRAY[
    -- collision d'identité lecteur·rice sur une adhésion vivante : l'effacement
    -- ne change ni local_reader_number ni status
    'fn_enforce_local_reader_identity_uniqueness',
    -- 4e contre-proposition de retrait : l'effacement ne change que updated_by
    'fn_increment_negotiation_counter'
  ];
  v_src text;
  v_x text[];
  v_suf  text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_u    uuid := gen_random_uuid();   -- la coordinatrice qui s'efface
  v_o    uuid := gen_random_uuid();   -- une autre personne, témoin
  v_lib  uuid; v_work bigint; v_work2 bigint;
  v_tok  uuid; v_tok_o uuid;
  h_u uuid; h_o uuid; p_u uuid; p_annulee uuid; p_o uuid;
  n_autrice bigint; n_masquee bigint; n_o bigint;
  v_avant_h text; v_avant_p text; v_avant_pa text; v_avant_na text; v_avant_nm text; v_avant_ho text; v_avant_po text; v_avant_no text;
  v_json jsonb; v_err text; v_n int;
BEGIN
  SELECT prosrc INTO v_src FROM pg_proc WHERE oid = 'public.fn_delete_my_account()'::regprocedure;

  -- Tables visées : celles que la fonction met à jour, et celles qu'une FK
  -- SET NULL / SET DEFAULT vers profiles ou auth.users fait mettre à jour.
  CREATE TEMP TABLE _visees ON COMMIT DROP AS
  SELECT DISTINCT to_regclass(CASE WHEN m[1] LIKE '%.%' THEN m[1] ELSE 'public.' || m[1] END) AS rel
    FROM regexp_matches(v_src, '\mUPDATE\s+([a-z_][a-z0-9_.]*)', 'gi') AS m
  UNION
  SELECT c.conrelid FROM pg_constraint c
   WHERE c.contype = 'f' AND c.confrelid IN ('auth.users'::regclass, 'public.profiles'::regclass)
     AND c.confdeltype IN ('n', 'd');

  CREATE TEMP TABLE _refus ON COMMIT DROP AS
  SELECT v.rel, t.tgname, p.proname,
         p.prosrc LIKE '%anarbib.effacement_compte%' AS connait
    FROM _visees v
    JOIN pg_trigger t ON t.tgrelid = v.rel AND NOT t.tgisinternal AND t.tgenabled <> 'D'
                     AND (t.tgtype & 2) = 2 AND (t.tgtype & 16) = 16
    JOIN pg_proc p ON p.oid = t.tgfoid
   WHERE p.prosrc ~* '\mRAISE\M(?!\s+(NOTICE|WARNING|INFO|LOG|DEBUG)\M)';

  -- ── T1 ─────────────────────────────────────────────────────────────────
  v_t:='T1 tout déclencheur BEFORE UPDATE de refus sur une table visée connaît le drapeau d''effacement';
  SELECT array_agg(rel::text || '.' || tgname || ' (' || proname || ')' ORDER BY 1) INTO v_x
    FROM _refus WHERE NOT connait AND proname <> ALL (v_conditionnels);
  IF v_x IS NULL THEN v_passed:=v_passed+1;
  ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : bloquerait l''effacement = '||array_to_string(v_x, ', '));
  END IF;

  -- ── T2 ─────────────────────────────────────────────────────────────────
  v_t:='T2 la liste close des refus conditionnels ne désigne que des refus réels et encore visés';
  SELECT array_agg(c ORDER BY 1) INTO v_x
    FROM unnest(v_conditionnels) AS c
   WHERE NOT EXISTS (SELECT 1 FROM _refus r WHERE r.proname = c AND NOT r.connait);
  IF v_x IS NULL THEN v_passed:=v_passed+1;
  ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : retirer = '||array_to_string(v_x, ', '));
  END IF;

  -- ── T3 ─────────────────────────────────────────────────────────────────
  v_t:='T3 les colonnes SET NULL qui ne peuvent pas passer à NULL d''elles-mêmes sont traitées par la fonction';
  SELECT array_agg(c.conrelid::regclass::text || '.' || a.attname ORDER BY 1) INTO v_x
    FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
   WHERE c.contype = 'f'
     AND c.confrelid IN ('auth.users'::regclass, 'public.profiles'::regclass)
     AND c.confdeltype IN ('n', 'd')
     AND (a.attnotnull OR EXISTS (SELECT 1 FROM _refus r WHERE r.rel = c.conrelid AND r.proname <> ALL (v_conditionnels)))
     AND NOT (v_src ~ ('\m' || (SELECT relname FROM pg_class WHERE oid = c.conrelid) || '\M[^;]*\m' || a.attname || '\M'));
  IF v_x IS NULL THEN v_passed:=v_passed+1;
  ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : non traitées = '||array_to_string(v_x, ', '));
  END IF;

  -- ── Jeu : coordinatrice v_u, témoin v_o (son compte pseudonyme existe) ──
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-eff-declencheurs-' || v_suf, 'Essai effacement déclencheurs', true, 'public') RETURNING id INTO v_lib;
  SELECT min(id), max(id) INTO v_work, v_work2 FROM (SELECT id FROM public.works ORDER BY id LIMIT 2) w;
  IF v_work2 IS NULL OR v_work2 = v_work THEN RAISE EXCEPTION 'SETUP: il faut deux oeuvres dans la base de test'; END IF;

  INSERT INTO auth.users (instance_id,id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
  SELECT '00000000-0000-0000-0000-000000000000', x.id, 'authenticated','authenticated', x.mail, now(),now(),now(),
         '{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb
    FROM (VALUES (v_u, 'eff-decl-u-' || v_suf || '@example.invalid'),
                 (v_o, 'eff-decl-o-' || v_suf || '@example.invalid')) AS x(id, mail);
  INSERT INTO public.profiles (id,email,first_name,last_name,preferred_language)
  SELECT u.id, u.email, 'Essai', 'Déclencheurs', 'fr' FROM auth.users u WHERE u.id IN (v_u, v_o)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (v_u, v_lib, 'coordenador', 'active');
  v_tok_o := public.fn_pseudonymize_token(v_o);
  INSERT INTO auth.users (id, email, role, aud) VALUES (v_tok_o, v_tok_o::text || '@pseudonimizado.anarbib.local', 'authenticated', 'authenticated')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id) VALUES (v_tok_o) ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.library_profile_history (library_id, axis, old_value, new_value, changed_by, motivation)
  VALUES (v_lib, 'catalog_mode', 'a', 'b', v_u, 'essai u') RETURNING id INTO h_u;
  INSERT INTO public.library_profile_history (library_id, axis, old_value, new_value, changed_by, motivation)
  VALUES (v_lib, 'catalog_mode', 'b', 'c', v_o, 'essai o') RETURNING id INTO h_o;
  INSERT INTO public.library_profile_proposals (library_id, axis, old_value, new_value, transition_type, governance_required, motivation, proposed_by, expires_at)
  VALUES (v_lib, 'circulation_mode', 'a', 'b', 1, 'direct', 'proposée par u', v_u, now() + interval '7 days') RETURNING id INTO p_u;
  INSERT INTO public.library_profile_proposals (library_id, axis, old_value, new_value, transition_type, governance_required, motivation, proposed_by, expires_at,
                                                status, cancelled_at, cancelled_by, cancelled_motivation)
  VALUES (v_lib, 'network_mode', 'a', 'b', 1, 'direct', 'proposée par o', v_o, now() + interval '7 days',
          'cancelled', now(), v_u, 'annulée par u') RETURNING id INTO p_annulee;
  INSERT INTO public.library_profile_proposals (library_id, axis, old_value, new_value, transition_type, governance_required, motivation, proposed_by, expires_at)
  VALUES (v_lib, 'governance_mode', 'a', 'b', 1, 'direct', 'témoin o', v_o, now() + interval '7 days') RETURNING id INTO p_o;

  -- Les notes prennent leur autrice de auth.uid() (déclencheur d'INSERT) ;
  -- le masquage se pose sans le déclencheur d'UPDATE, qui n'est pas l'objet ici.
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_u,'role','authenticated')::text, true);
  INSERT INTO public.book_reading_notes (work_id, author_user_id, author_pseudonym, origin_library_id, body)
  VALUES (v_work, v_u, 'Pseudo U', v_lib, 'Note de u.') RETURNING id INTO n_autrice;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_o,'role','authenticated')::text, true);
  INSERT INTO public.book_reading_notes (work_id, author_user_id, author_pseudonym, origin_library_id, body)
  VALUES (v_work, v_o, 'Pseudo O', v_lib, 'Note de o, masquée par u.') RETURNING id INTO n_masquee;
  INSERT INTO public.book_reading_notes (work_id, author_user_id, author_pseudonym, origin_library_id, body)
  VALUES (v_work2, v_o, 'Pseudo O', v_lib, 'Note témoin de o.') RETURNING id INTO n_o;
  PERFORM set_config('request.jwt.claims', '', true);
  ALTER TABLE public.book_reading_notes DISABLE TRIGGER trg_reading_note_before_update;
  UPDATE public.book_reading_notes SET status = 'hidden', hidden_by = v_u, hidden_at = now(), hidden_reason = 'essai' WHERE id = n_masquee;
  ALTER TABLE public.book_reading_notes ENABLE TRIGGER trg_reading_note_before_update;

  SELECT (to_jsonb(r) - 'changed_by')::text INTO v_avant_h  FROM public.library_profile_history r WHERE id = h_u;
  SELECT to_jsonb(r)::text                  INTO v_avant_ho FROM public.library_profile_history r WHERE id = h_o;
  SELECT (to_jsonb(r) - 'proposed_by')::text INTO v_avant_p FROM public.library_profile_proposals r WHERE id = p_u;
  SELECT (to_jsonb(r) - 'cancelled_by')::text INTO v_avant_pa FROM public.library_profile_proposals r WHERE id = p_annulee;
  SELECT to_jsonb(r)::text                  INTO v_avant_po FROM public.library_profile_proposals r WHERE id = p_o;
  SELECT (to_jsonb(r) - 'author_user_id')::text INTO v_avant_na FROM public.book_reading_notes r WHERE id = n_autrice;
  SELECT (to_jsonb(r) - 'hidden_by')::text  INTO v_avant_nm FROM public.book_reading_notes r WHERE id = n_masquee;
  SELECT to_jsonb(r)::text                  INTO v_avant_no FROM public.book_reading_notes r WHERE id = n_o;

  -- ── T4 ─────────────────────────────────────────────────────────────────
  v_t:='T4 fn_delete_my_account rend ok=true pour la coordinatrice';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_u,'role','authenticated')::text, true);
    v_json := public.fn_delete_my_account();
    IF (v_json->>'ok')='true' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : a levé '||v_err);
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  v_tok := public.fn_pseudonymize_token(v_u);

  -- ── T5 ─────────────────────────────────────────────────────────────────
  v_t:='T5 profil au jeton, notes à NULL, reste des lignes intact, témoins intacts';
  IF (SELECT changed_by FROM public.library_profile_history WHERE id = h_u) = v_tok
     AND (SELECT (to_jsonb(r) - 'changed_by')::text FROM public.library_profile_history r WHERE id = h_u) = v_avant_h
     AND (SELECT proposed_by FROM public.library_profile_proposals WHERE id = p_u) = v_tok
     AND (SELECT (to_jsonb(r) - 'proposed_by')::text FROM public.library_profile_proposals r WHERE id = p_u) = v_avant_p
     AND (SELECT cancelled_by FROM public.library_profile_proposals WHERE id = p_annulee) = v_tok
     AND (SELECT (to_jsonb(r) - 'cancelled_by')::text FROM public.library_profile_proposals r WHERE id = p_annulee) = v_avant_pa
     AND (SELECT author_user_id IS NULL FROM public.book_reading_notes WHERE id = n_autrice)
     AND (SELECT (to_jsonb(r) - 'author_user_id')::text FROM public.book_reading_notes r WHERE id = n_autrice) = v_avant_na
     AND (SELECT hidden_by IS NULL FROM public.book_reading_notes WHERE id = n_masquee)
     AND (SELECT (to_jsonb(r) - 'hidden_by')::text FROM public.book_reading_notes r WHERE id = n_masquee) = v_avant_nm
     AND (SELECT to_jsonb(r)::text FROM public.library_profile_history r WHERE id = h_o) = v_avant_ho
     AND (SELECT to_jsonb(r)::text FROM public.library_profile_proposals r WHERE id = p_o) = v_avant_po
     AND (SELECT to_jsonb(r)::text FROM public.book_reading_notes r WHERE id = n_o) = v_avant_no
     AND COALESCE(current_setting('anarbib.effacement_compte', true), '') = ''
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t;
  END IF;

  -- ── T6 : historique du profil, ligne témoin de v_o ───────────────────────
  v_t:='T6 l''historique du profil refuse tout ce qui n''est pas le re-pointage exact';
  v_n := 0;
  BEGIN UPDATE public.library_profile_history SET changed_by = v_tok_o WHERE id = h_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'library_profile_history is immutable%' THEN v_n := v_n + 1; END IF; END;
  PERFORM set_config('anarbib.effacement_compte', v_u::text, true);
  BEGIN UPDATE public.library_profile_history SET changed_by = v_tok_o WHERE id = h_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'library_profile_history is immutable%' THEN v_n := v_n + 1; END IF; END;
  PERFORM set_config('anarbib.effacement_compte', v_o::text, true);
  BEGIN UPDATE public.library_profile_history SET changed_by = v_tok WHERE id = h_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'library_profile_history is immutable%' THEN v_n := v_n + 1; END IF; END;
  BEGIN UPDATE public.library_profile_history SET changed_by = v_tok_o, motivation = 'x' WHERE id = h_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'library_profile_history is immutable%' THEN v_n := v_n + 1; END IF; END;
  BEGIN DELETE FROM public.library_profile_history WHERE id = h_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'library_profile_history is immutable%' THEN v_n := v_n + 1; END IF; END;
  SET LOCAL ROLE service_role;
  BEGIN UPDATE public.library_profile_history SET changed_by = v_tok_o WHERE id = h_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'library_profile_history is immutable%' THEN v_n := v_n + 1; END IF; END;
  RESET ROLE;
  PERFORM set_config('anarbib.effacement_compte', '', true);
  IF v_n = 6 AND (SELECT to_jsonb(r)::text FROM public.library_profile_history r WHERE id = h_o) = v_avant_ho
     AND has_table_privilege('service_role', 'public.library_profile_history', 'UPDATE')
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||'/6 refus');
  END IF;

  -- ── T7 : propositions, ligne témoin de v_o ───────────────────────────────
  v_t:='T7 le verrou de proposed_by ne s''ouvre qu''au re-pointage exact ; DELETE refusé';
  v_n := 0;
  BEGIN UPDATE public.library_profile_proposals SET proposed_by = v_tok_o WHERE id = p_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'LPP_LOCKED_COLUMN : proposed_by%' THEN v_n := v_n + 1; END IF; END;
  PERFORM set_config('anarbib.effacement_compte', v_u::text, true);
  BEGIN UPDATE public.library_profile_proposals SET proposed_by = v_tok_o WHERE id = p_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'LPP_LOCKED_COLUMN : proposed_by%' THEN v_n := v_n + 1; END IF; END;
  PERFORM set_config('anarbib.effacement_compte', v_o::text, true);
  BEGIN UPDATE public.library_profile_proposals SET proposed_by = v_tok WHERE id = p_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'LPP_LOCKED_COLUMN : proposed_by%' THEN v_n := v_n + 1; END IF; END;
  BEGIN UPDATE public.library_profile_proposals SET proposed_by = v_tok_o, status = 'rejected' WHERE id = p_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'LPP_LOCKED_COLUMN : proposed_by%' THEN v_n := v_n + 1; END IF; END;
  BEGIN DELETE FROM public.library_profile_proposals WHERE id = p_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'LIBRARY_PROFILE_PROPOSALS_IS_IMMUTABLE%' THEN v_n := v_n + 1; END IF; END;
  SET LOCAL ROLE service_role;
  BEGIN UPDATE public.library_profile_proposals SET proposed_by = v_tok_o WHERE id = p_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'LPP_LOCKED_COLUMN : proposed_by%' THEN v_n := v_n + 1; END IF; END;
  RESET ROLE;
  PERFORM set_config('anarbib.effacement_compte', '', true);
  IF v_n = 6 AND (SELECT to_jsonb(r)::text FROM public.library_profile_proposals r WHERE id = p_o) = v_avant_po
     AND has_table_privilege('service_role', 'public.library_profile_proposals', 'UPDATE')
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||'/6 refus');
  END IF;

  -- ── T8 ─────────────────────────────────────────────────────────────────
  v_t:='T8 une colonne libre des propositions (status) se modifie comme avant';
  BEGIN
    UPDATE public.library_profile_proposals SET status = 'rejected' WHERE id = p_o;
    IF (SELECT status FROM public.library_profile_proposals WHERE id = p_o) = 'rejected'
      THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : statut inchangé'); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : a levé '||v_err);
  END;

  -- ── T9 : notes, la note témoin de v_o ───────────────────────────────────
  v_t:='T9 la note refuse tout ce qui n''est pas le passage exact à NULL ; l''autrice l''édite encore';
  v_n := 0;
  PERFORM set_config('anarbib.effacement_compte', v_o::text, true);
  BEGIN UPDATE public.book_reading_notes SET author_user_id = NULL, body = 'réécrite' WHERE id = n_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'reading_note: modification non autorisee%' THEN v_n := v_n + 1; END IF; END;
  BEGIN UPDATE public.book_reading_notes SET author_user_id = v_tok_o WHERE id = n_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'reading_note: modification non autorisee%' THEN v_n := v_n + 1; END IF; END;
  PERFORM set_config('anarbib.effacement_compte', v_u::text, true);
  BEGIN UPDATE public.book_reading_notes SET author_user_id = NULL WHERE id = n_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'reading_note: modification non autorisee%' THEN v_n := v_n + 1; END IF; END;
  PERFORM set_config('anarbib.effacement_compte', v_o::text, true);
  SET LOCAL ROLE service_role;
  BEGIN UPDATE public.book_reading_notes SET author_user_id = NULL WHERE id = n_o;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE 'reading_note: modification non autorisee%' THEN v_n := v_n + 1; END IF; END;
  RESET ROLE;
  PERFORM set_config('anarbib.effacement_compte', '', true);
  -- L'autrice, sous authenticated : le déclencheur, désormais SECURITY
  -- INVOKER, la reconnaît et marque la note éditée.
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_o,'role','authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  BEGIN
    UPDATE public.book_reading_notes SET body = 'Note témoin de o, revue.' WHERE id = n_o;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    v_failures:=v_failures||('T9 édition par l''autrice : a levé '||v_err);
  END;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '', true);
  IF v_n = 4
     AND (SELECT author_user_id = v_o AND body = 'Note témoin de o, revue.' AND edited FROM public.book_reading_notes WHERE id = n_o)
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||'/4 refus, note='||coalesce((SELECT body || ' edited=' || edited FROM public.book_reading_notes WHERE id = n_o),'NULL'));
  END IF;

  IF v_failed=0 THEN
    RAISE EXCEPTION 'EFFACEMENT-DECLENCHEURS OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'EFFACEMENT-DECLENCHEURS ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || ');
  END IF;
END $$;
