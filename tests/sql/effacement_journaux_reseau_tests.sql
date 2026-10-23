-- =====================================================================
-- AnarBib — Tests d'acceptation : L'EFFACEMENT PASSE À TRAVERS LES DEUX JOURNAUX DU RÉSEAU
-- Date    : 2026-10-23  ·  Réf : migration 20261023203225_l_effacement_traverse_les_journaux_du_reseau.sql
--
-- Les deux journaux de l'administration du réseau sont append-only
-- (network_admin_cross_library_actions_log, network_administrator_audit) :
-- leurs déclencheurs refusaient aussi le re-pointage vers le jeton pseudonyme
-- que fait fn_delete_my_account, et tout l'effacement d'un·e admin du réseau
-- était annulé.
--
-- Couvre :
--   T1  une personne qui a agi sur une autre bibliothèque et figure trois fois
--       dans l'audit (sujet, actrice) efface son compte : ok=true.
--   T2  la ligne inter-bibliothèques porte le jeton, le reste de la ligne est
--       intact ; la ligne d'une autre personne n'a pas bougé.
--   T3  l'audit : sujet et actrice passent au jeton, la cible (une autre
--       personne) reste nommée, le reste de chaque ligne est intact.
--   T4  le drapeau d'effacement est retombé à la sortie de la fonction.
--   T5  journal inter-bibliothèques, toujours refusé : UPDATE sans drapeau ;
--       drapeau d'une autre personne ; vers autre chose que le jeton ;
--       une autre colonne changée avec l'acteur ; DELETE sous le drapeau ;
--       drapeau de purge seul.
--   T6  audit, toujours refusé : sans drapeau ; une autre colonne changée ;
--       une colonne qui ne nommait pas la personne ; DELETE sous le drapeau.
--   T7  hors du propriétaire de fn_delete_my_account (service_role), même avec
--       le bon drapeau et le bon jeton : refusé par le déclencheur.
--   Bilan OK : 'EFFACEMENT-JOURNAUX-RESEAU OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int:=0; v_failed int:=0; v_failures text[]:=ARRAY[]::text[]; v_t text;
  v_suf  text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_u    uuid := gen_random_uuid();   -- l'admin qui efface son compte
  v_o    uuid := gen_random_uuid();   -- une autre admin, cible et témoin
  v_lib  uuid;
  v_tok  uuid; v_tok_o uuid;
  x_u bigint; x_o bigint;
  a_sujet bigint; a_acte bigint; a_o bigint;
  v_avant_x text; v_avant_xo text; v_avant_a1 text; v_avant_a2 text; v_avant_ao text;
  v_json jsonb; v_err text; v_n int;
BEGIN
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-eff-journaux-' || v_suf, 'Essai effacement journaux', true, 'public') RETURNING id INTO v_lib;

  INSERT INTO auth.users (instance_id,id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
  SELECT '00000000-0000-0000-0000-000000000000', x.id, 'authenticated','authenticated', x.mail, now(),now(),now(),
         '{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb
    FROM (VALUES (v_u, 'eff-journaux-u-' || v_suf || '@example.invalid'),
                 (v_o, 'eff-journaux-o-' || v_suf || '@example.invalid')) AS x(id, mail);
  INSERT INTO public.profiles (id,email,first_name,last_name,preferred_language)
  SELECT u.id, u.email, 'Essai', 'Journaux', 'fr' FROM auth.users u WHERE u.id IN (v_u, v_o)
  ON CONFLICT (id) DO NOTHING;
  -- Le compte pseudonyme de la témoin existe, comme après un effacement : les
  -- UPDATE vers son jeton de T5/T6 ne butent pas sur la FK, seul le déclencheur
  -- peut les refuser (les blocs n'attrapent que raise_exception).
  v_tok_o := public.fn_pseudonymize_token(v_o);
  INSERT INTO auth.users (id, email, role, aud) VALUES (v_tok_o, v_tok_o::text || '@pseudonimizado.anarbib.local', 'authenticated', 'authenticated')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id) VALUES (v_tok_o) ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.network_admin_cross_library_actions_log (actor_user_id, library_id, action_type, payload, created_at)
  VALUES (v_u, v_lib, 'essai_effacement', '{"motif":"essai"}'::jsonb, now() - interval '3 days') RETURNING id INTO x_u;
  INSERT INTO public.network_admin_cross_library_actions_log (actor_user_id, library_id, action_type, payload)
  VALUES (v_o, v_lib, 'essai_effacement', '{"motif":"temoin"}'::jsonb) RETURNING id INTO x_o;

  INSERT INTO public.network_administrator_audit (user_id, event_type, actor_user_id, target_user_id, metadata)
  VALUES (v_u, 'foundational_admin_added', NULL, NULL, '{"essai":1}'::jsonb) RETURNING id INTO a_sujet;
  INSERT INTO public.network_administrator_audit (user_id, event_type, actor_user_id, target_user_id, metadata)
  VALUES (v_u, 'cooptation_proposed', v_u, v_o, '{"essai":2}'::jsonb) RETURNING id INTO a_acte;
  INSERT INTO public.network_administrator_audit (user_id, event_type, actor_user_id, target_user_id, metadata)
  VALUES (v_o, 'foundational_admin_added', NULL, NULL, '{"essai":3}'::jsonb) RETURNING id INTO a_o;

  SELECT (to_jsonb(l) - 'actor_user_id')::text INTO v_avant_x  FROM public.network_admin_cross_library_actions_log l WHERE id = x_u;
  SELECT to_jsonb(l)::text                     INTO v_avant_xo FROM public.network_admin_cross_library_actions_log l WHERE id = x_o;
  SELECT (to_jsonb(a) - 'user_id')::text       INTO v_avant_a1 FROM public.network_administrator_audit a WHERE id = a_sujet;
  SELECT (to_jsonb(a) - 'user_id' - 'actor_user_id')::text INTO v_avant_a2 FROM public.network_administrator_audit a WHERE id = a_acte;
  SELECT to_jsonb(a)::text                     INTO v_avant_ao FROM public.network_administrator_audit a WHERE id = a_o;

  -- ── T1 ─────────────────────────────────────────────────────────────────
  v_t:='T1 fn_delete_my_account rend ok=true pour une admin présente dans les deux journaux';
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

  v_tok   := public.fn_pseudonymize_token(v_u);

  -- ── T2 ─────────────────────────────────────────────────────────────────
  v_t:='T2 la ligne inter-bibliothèques porte le jeton, rien d''autre n''a bougé';
  IF (SELECT actor_user_id FROM public.network_admin_cross_library_actions_log WHERE id = x_u) = v_tok
     AND (SELECT (to_jsonb(l) - 'actor_user_id')::text FROM public.network_admin_cross_library_actions_log l WHERE id = x_u) = v_avant_x
     AND (SELECT to_jsonb(l)::text FROM public.network_admin_cross_library_actions_log l WHERE id = x_o) = v_avant_xo
     AND NOT EXISTS (SELECT 1 FROM public.network_admin_cross_library_actions_log WHERE actor_user_id = v_u)
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : acteur='||coalesce((SELECT actor_user_id::text FROM public.network_admin_cross_library_actions_log WHERE id = x_u),'NULL'));
  END IF;

  -- ── T3 ─────────────────────────────────────────────────────────────────
  v_t:='T3 l''audit : sujet et actrice au jeton, la cible reste nommée';
  IF (SELECT user_id FROM public.network_administrator_audit WHERE id = a_sujet) = v_tok
     AND (SELECT (to_jsonb(a) - 'user_id')::text FROM public.network_administrator_audit a WHERE id = a_sujet) = v_avant_a1
     AND (SELECT user_id = v_tok AND actor_user_id = v_tok AND target_user_id = v_o FROM public.network_administrator_audit WHERE id = a_acte)
     AND (SELECT (to_jsonb(a) - 'user_id' - 'actor_user_id')::text FROM public.network_administrator_audit a WHERE id = a_acte) = v_avant_a2
     AND (SELECT to_jsonb(a)::text FROM public.network_administrator_audit a WHERE id = a_o) = v_avant_ao
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t;
  END IF;

  -- ── T4 ─────────────────────────────────────────────────────────────────
  v_t:='T4 le drapeau d''effacement est retombé';
  IF COALESCE(current_setting('anarbib.effacement_compte', true), '') = ''
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||current_setting('anarbib.effacement_compte', true));
  END IF;

  -- ── T5 : journal inter-bibliothèques, la ligne témoin de v_o ─────────────
  v_t:='T5 le journal inter-bibliothèques refuse tout ce qui n''est pas le re-pointage exact';
  v_n := 0;
  BEGIN UPDATE public.network_admin_cross_library_actions_log SET actor_user_id = v_tok_o WHERE id = x_o;
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  PERFORM set_config('anarbib.effacement_compte', v_u::text, true);   -- drapeau d'une autre personne
  BEGIN UPDATE public.network_admin_cross_library_actions_log SET actor_user_id = v_tok_o WHERE id = x_o;
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  PERFORM set_config('anarbib.effacement_compte', v_o::text, true);
  BEGIN UPDATE public.network_admin_cross_library_actions_log SET actor_user_id = v_tok WHERE id = x_o;
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  BEGIN UPDATE public.network_admin_cross_library_actions_log SET actor_user_id = v_tok_o, action_type = 'x' WHERE id = x_o;
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  BEGIN UPDATE public.network_admin_cross_library_actions_log SET actor_user_id = v_tok_o, payload = '{}'::jsonb WHERE id = x_o;
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  BEGIN DELETE FROM public.network_admin_cross_library_actions_log WHERE id = x_o;
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  PERFORM set_config('anarbib.effacement_compte', '', true);
  PERFORM set_config('anarbib.purge_retention', 'on', true);
  BEGIN UPDATE public.network_admin_cross_library_actions_log SET actor_user_id = v_tok_o WHERE id = x_o;
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  PERFORM set_config('anarbib.purge_retention', '', true);
  IF v_n = 7 AND (SELECT to_jsonb(l)::text FROM public.network_admin_cross_library_actions_log l WHERE id = x_o) = v_avant_xo
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||'/7 refus');
  END IF;

  -- ── T6 : audit, la ligne témoin de v_o et la cible de a_acte ─────────────
  v_t:='T6 l''audit refuse tout ce qui n''est pas le re-pointage exact';
  v_n := 0;
  BEGIN UPDATE public.network_administrator_audit SET user_id = v_tok_o WHERE id = a_o;
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  PERFORM set_config('anarbib.effacement_compte', v_o::text, true);
  BEGIN UPDATE public.network_administrator_audit SET user_id = v_tok_o, event_type = 'inactivity_marked' WHERE id = a_o;
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  BEGIN UPDATE public.network_administrator_audit SET user_id = v_tok_o, metadata = '{}'::jsonb WHERE id = a_o;
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  BEGIN UPDATE public.network_administrator_audit SET user_id = v_tok_o, actor_user_id = v_tok_o WHERE id = a_o;  -- actor était NULL
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  BEGIN UPDATE public.network_administrator_audit SET user_id = v_o WHERE id = a_acte;  -- user_id ne nommait pas v_o
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  BEGIN DELETE FROM public.network_administrator_audit WHERE id = a_o;
  EXCEPTION WHEN raise_exception THEN v_n := v_n + 1; END;
  PERFORM set_config('anarbib.effacement_compte', '', true);
  IF v_n = 6 AND (SELECT to_jsonb(a)::text FROM public.network_administrator_audit a WHERE id = a_o) = v_avant_ao
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||'/6 refus');
  END IF;

  -- ── T7 : un autre rôle que le propriétaire de fn_delete_my_account ────────
  v_t:='T7 sous service_role, le bon drapeau et le bon jeton ne suffisent pas';
  -- service_role a le droit UPDATE sur les deux tables (et ignore la RLS) :
  -- seul le déclencheur peut refuser, c'est son message qu'on attend.
  v_n := 0;
  IF NOT (has_table_privilege('service_role', 'public.network_admin_cross_library_actions_log', 'UPDATE')
          AND has_table_privilege('service_role', 'public.network_administrator_audit', 'UPDATE')) THEN
    v_n := -10;  -- la mesure ne prouverait plus rien : la faire changer de rôle
  END IF;
  PERFORM set_config('anarbib.effacement_compte', v_o::text, true);
  SET LOCAL ROLE service_role;
  BEGIN UPDATE public.network_admin_cross_library_actions_log SET actor_user_id = v_tok_o WHERE id = x_o;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE 'cross_library_log_immutable%' THEN v_n := v_n + 1; END IF;
  END;
  BEGIN UPDATE public.network_administrator_audit SET user_id = v_tok_o WHERE id = a_o;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE 'audit_immutable%' THEN v_n := v_n + 1; END IF;
  END;
  RESET ROLE;
  PERFORM set_config('anarbib.effacement_compte', '', true);
  IF v_n = 2 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||'/2 refus');
  END IF;

  IF v_failed=0 THEN
    RAISE EXCEPTION 'EFFACEMENT-JOURNAUX-RESEAU OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'EFFACEMENT-JOURNAUX-RESEAU ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || ');
  END IF;
END $$;
