-- =====================================================================
-- AnarBib — Tests : l'effacement d'un compte traite le journal du catalogue (B34)
-- Date    : 2026-09-27  ·  Réf : 20260927184954_b34_l_effacement_traite_le_journal_du_catalogue
--
-- catalog_audit_log garde l'acteur de chaque suppression (actor_id, sans clé
-- étrangère) et, dans l'instantané d'un brouillon supprimé, les comptes qui
-- l'avaient créé et modifié (details->'snapshot'->>'created_by'/'updated_by').
-- Jusqu'au 27/09, fn_delete_my_account n'y touchait pas : l'identifiant d'une
-- personne effacée y serait resté.
--
-- Couvre :
--   T1 fn_delete_my_account rend ok=true pour une personne qui a catalogué ;
--   T2 plus aucune ligne n'a son identifiant pour acteur ;
--   T3 plus aucun instantané ne la nomme (created_by, updated_by) ;
--   T4 les trois champs portent le jeton pseudonyme de l'effacement (erasure_log) ;
--   T5 une ligne qui ne la concerne pas est intacte ;
--   T6 la réponse compte les actes re-pointés (1 acteur + 2 created_by + 1 updated_by = 4).
--   Bilan OK : 'EFFACEMENT-JOURNAL OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_u      constant uuid := 'b34b34b3-0000-4000-8000-000000000001';  -- la personne effacée
  v_autre  constant uuid := 'b34b34b3-0000-4000-8000-000000000002';  -- une autre personne
  v_a bigint; v_b bigint; v_c bigint;
  v_json jsonb; v_token uuid; v_err text; v_n int;
BEGIN
  -- ── Fixtures ──
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  SELECT '00000000-0000-0000-0000-000000000000', x.id, 'authenticated', 'authenticated', x.mail, now(), now(), now(),
         '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb
    FROM (VALUES (v_u, 'b34.efface@anarbib.local'), (v_autre, 'b34.autre@anarbib.local')) x(id, mail)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (v_u, 'b34.efface@anarbib.local', 'B34', 'Effacée', 'fr'),
         (v_autre, 'b34.autre@anarbib.local', 'B34', 'Autre', 'fr')
  ON CONFLICT (id) DO NOTHING;

  -- A : elle a supprimé un brouillon qu'elle avait créé et modifié.
  INSERT INTO public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  VALUES (v_u, 'delete', 'book', 900001, 'Brouillon B34 A',
          jsonb_build_object('snapshot', jsonb_build_object('titulo', 'A', 'created_by', v_u, 'updated_by', v_u)))
  RETURNING id INTO v_a;
  -- B : l'autre personne a supprimé un brouillon qu'ELLE avait créé.
  INSERT INTO public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  VALUES (v_autre, 'delete', 'book', 900002, 'Brouillon B34 B',
          jsonb_build_object('snapshot', jsonb_build_object('titulo', 'B', 'created_by', v_u, 'updated_by', v_autre)))
  RETURNING id INTO v_b;
  -- C : témoin, ne la concerne pas.
  INSERT INTO public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  VALUES (v_autre, 'discard', 'author', 900003, 'Témoin B34',
          jsonb_build_object('snapshot', jsonb_build_object('preferred_name', 'C', 'created_by', v_autre, 'updated_by', v_autre)))
  RETURNING id INTO v_c;

  -- ── T1 : l'effacement passe ──
  v_t := 'T1 fn_delete_my_account rend ok=true';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u, 'role', 'authenticated')::text, true);
    v_json := public.fn_delete_my_account();
    IF (v_json->>'ok') = 'true' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_json::text, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : a levé ' || v_err);
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  -- Le jeton : celui qu'erasure_log a consigné pour cet effacement, lu par la
  -- ligne A (si elle n'a pas été re-pointée, aucun jeton ne correspond : T4 rougit).
  SELECT e.pseudonym_token INTO v_token FROM public.erasure_log e
   WHERE e.pseudonym_token = (SELECT actor_id FROM public.catalog_audit_log WHERE id = v_a);

  v_t := 'T2 plus aucune ligne n''a la personne effacée pour acteur';
  SELECT count(*) INTO v_n FROM public.catalog_audit_log WHERE actor_id = v_u;
  IF v_n = 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' ligne(s)'); END IF;

  v_t := 'T3 plus aucun instantané ne la nomme';
  SELECT count(*) INTO v_n FROM public.catalog_audit_log
   WHERE details->'snapshot'->>'created_by' = v_u::text OR details->'snapshot'->>'updated_by' = v_u::text;
  IF v_n = 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' ligne(s)'); END IF;

  v_t := 'T4 acteur et instantanés portent le jeton de l''effacement';
  IF v_token IS NOT NULL AND v_token <> v_u
     AND (SELECT details->'snapshot'->>'created_by' FROM public.catalog_audit_log WHERE id = v_a) = v_token::text
     AND (SELECT details->'snapshot'->>'updated_by' FROM public.catalog_audit_log WHERE id = v_a) = v_token::text
     AND (SELECT details->'snapshot'->>'created_by' FROM public.catalog_audit_log WHERE id = v_b) = v_token::text
     AND (SELECT details->'snapshot'->>'updated_by' FROM public.catalog_audit_log WHERE id = v_b) = v_autre::text
     AND (SELECT actor_id FROM public.catalog_audit_log WHERE id = v_b) = v_autre
     AND (SELECT details->'snapshot'->>'titulo' FROM public.catalog_audit_log WHERE id = v_a) = 'A'
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : jeton=' || coalesce(v_token::text, 'NULL')
    || ' A=' || coalesce((SELECT details::text FROM public.catalog_audit_log WHERE id = v_a), 'NULL')); END IF;

  v_t := 'T5 le témoin est intact';
  IF (SELECT actor_id = v_autre AND details->'snapshot'->>'created_by' = v_autre::text
        AND details->'snapshot'->>'updated_by' = v_autre::text FROM public.catalog_audit_log WHERE id = v_c)
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : modifié'); END IF;

  v_t := 'T6 la réponse compte 4 actes re-pointés (1 acteur + 2 created_by + 1 updated_by)';
  IF (v_json->>'pseudonymized_act_rows')::int = 4 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_json->>'pseudonymized_act_rows', 'NULL')); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'EFFACEMENT-JOURNAL ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'EFFACEMENT-JOURNAL OK : %/%', v_passed, v_passed;
END $$;
