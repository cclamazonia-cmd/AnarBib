-- =====================================================================
-- AnarBib — Tests d'acceptation : L'EFFACEMENT D'UN COMPTE NE BUTE SUR AUCUNE FK (B28)
-- Date    : 2026-09-22  ·  Réf : migration 20260922214500_b28_l_effacement_repointe_tout_acte_sur_le_jeton.sql
--
-- Couvre :
--   T1  liste VIVANTE — toute colonne portant une FK vers profiles ou
--       auth.users en NO ACTION / RESTRICT (hors schéma auth) est citée dans
--       le corps de fn_delete_my_account : une table nouvelle qui oublierait
--       l'effacement fait rougir cette suite, pas la personne qui supprime.
--   T2  cas réel — une personne qui a créé un éditeur (publishers.created_by,
--       NO ACTION) et déposé une demande d'entrée (library_requests.
--       submitted_by_user_id, RESTRICT) supprime son compte : ok=true,
--       profil et compte partis, les deux actes portent le jeton, erasure_log
--       a sa ligne.
--   Bilan OK : 'EFFACEMENT-FK OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int:=0; v_failed int:=0; v_failures text[]:=ARRAY[]::text[]; v_t text;
  v_src text;
  v_manquantes text[];
  v_u uuid := 'b0000000-0000-4000-8000-0000000000b2';
  v_pub_id bigint;
  v_req_id uuid;
  v_json jsonb;
  v_token uuid;
  v_err text;
BEGIN
  SELECT prosrc INTO v_src FROM pg_proc
   WHERE proname='fn_delete_my_account' AND pronamespace='public'::regnamespace;
  IF v_src IS NULL THEN RAISE EXCEPTION 'SETUP: fn_delete_my_account absente'; END IF;

  -- ── T1 : aucune FK NO ACTION / RESTRICT vers profiles/auth.users hors de la fonction ──
  v_t:='T1 toute FK NO ACTION/RESTRICT vers profiles ou auth.users est re-pointée par la fonction';
  SELECT array_agg(c.conrelid::regclass::text || '.' || a.attname ORDER BY 1)
    INTO v_manquantes
    FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
   WHERE c.contype = 'f'
     AND c.confrelid IN ('auth.users'::regclass, 'public.profiles'::regclass)
     AND c.confdeltype IN ('a', 'r')
     AND c.conrelid::regclass::text NOT LIKE 'auth.%'
     AND NOT (v_src ~ ('\m' || c.conrelid::regclass::text || '\M[^;]*\m' || a.attname || '\M'));
  IF v_manquantes IS NULL OR cardinality(v_manquantes) = 0
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : non traitées = '||array_to_string(v_manquantes, ', '));
  END IF;

  -- ── Jeu : une personne avec un éditeur créé et une demande d'entrée déposée ──
  INSERT INTO auth.users (instance_id,id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', v_u,'authenticated','authenticated',
          'b28.efface@anarbib.local', now(),now(),now(),
          '{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id,email,first_name,last_name,preferred_language)
  VALUES (v_u,'b28.efface@anarbib.local','B28','Test','fr')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.publishers (name, created_by) VALUES ('Éditions de l''effacement (B28)', v_u)
  RETURNING id INTO v_pub_id;
  INSERT INTO public.library_requests
    (submitted_by_user_id, submitted_by_email_snapshot, library_name, city, library_email,
     project_stage, contact_name, contact_email, summary)
  VALUES (v_u, 'b28.efface@anarbib.local', 'Biblioteca B28', 'Belém', 'b28@exemplo.test',
          'ideia', 'B28 Test', 'b28@exemplo.test', 'Demande déposée puis compte effacé (B28).')
  RETURNING id INTO v_req_id;

  -- ── T2 : la suppression passe, et les actes changent d'auteur ──
  v_t:='T2 fn_delete_my_account rend ok=true malgré publishers.created_by et library_requests.submitted_by_user_id';
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

  v_t:='T3 le profil et le compte ont disparu';
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=v_u) AND NOT EXISTS (SELECT 1 FROM auth.users WHERE id=v_u)
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' KO'); END IF;

  v_t:='T4 les deux actes portent le jeton pseudonyme, et erasure_log le connaît';
  SELECT created_by INTO v_token FROM public.publishers WHERE id=v_pub_id;
  IF v_token IS NOT NULL AND v_token <> v_u
     AND (SELECT submitted_by_user_id FROM public.library_requests WHERE id=v_req_id) = v_token
     AND EXISTS (SELECT 1 FROM public.erasure_log WHERE pseudonym_token=v_token)
     AND EXISTS (SELECT 1 FROM public.profiles WHERE id=v_token)
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : publishers.created_by='||coalesce(v_token::text,'NULL')
      ||' library_requests.submitted_by_user_id='||coalesce((SELECT submitted_by_user_id::text FROM public.library_requests WHERE id=v_req_id),'NULL')); END IF;

  v_t:='T5 la réponse compte les actes re-pointés (pseudonymized_act_rows = 2)';
  IF (v_json->>'pseudonymized_act_rows')::int = 2
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json->>'pseudonymized_act_rows','NULL')); END IF;

  IF v_failed=0 THEN
    RAISE EXCEPTION 'EFFACEMENT-FK OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'EFFACEMENT-FK ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || ');
  END IF;
END $$;
