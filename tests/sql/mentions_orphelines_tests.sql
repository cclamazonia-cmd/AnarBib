-- =====================================================================
-- AnarBib — Tests d'acceptation : mentions de biblios hors reseau (decision C)
-- Date    : 2026-08-27  ·  Session : chantier invitation
-- Ref     : migration 20260827230000_mentions_orphelines
--
-- Ce que ces tests gardent, et qui ne se voit pas a l'oeil : que l'ABSENCE de
-- consentement vaut refus (T2), et que le rattachement nominatif ne suive pas
-- le consentement au contact (T4/T6). Si l'un des deux lache, la coordination
-- se retrouve avec un graphe social que personne n'a autorise.
--   Bilan OK : 'MENTIONS-C OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_admin uuid := gen_random_uuid();
  v_a uuid := gen_random_uuid();  -- consent contact seul
  v_b uuid := gen_random_uuid();  -- consent contact + attribution, meme biblio
  v_c uuid := gen_random_uuid();  -- aucun consentement
  v_d uuid := gen_random_uuid();  -- reader_pending (hors perimetre)
  v_n int; v_txt text; v_pers jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (v_admin,'adm@ex.org'),(v_a,'a@ex.org'),(v_b,'b@ex.org'),(v_c,'c@ex.org'),(v_d,'d@ex.org');
  -- Pas de public_id en fixture : un trigger le genere, le fournir donnerait
  -- l'illusion qu'on le maitrise (c'est ce qui a fait rougir T5 au premier jet).
  INSERT INTO public.profiles(id,email,first_name) VALUES
    (v_admin,'adm@ex.org','Adm'),
    (v_a,'a@ex.org','Ana'),
    (v_b,'b@ex.org','Bo'),
    (v_c,'c@ex.org','Ci'),
    (v_d,'d@ex.org','Di');
  INSERT INTO public.network_administrators(user_id,status) VALUES (v_admin,'active');

  -- Ana : meme biblio que Bo, ecrite differemment. Contact oui, attribution non.
  UPDATE public.profiles SET signup_intent='reader_orphan', signup_intent_set_at=now()-interval '3 days',
    signup_intent_metadata='{"library_name_mentioned":"Bibliotheque du Coin","mention_contact_consent":true}'::jsonb
   WHERE id=v_a;
  -- Bo : meme biblio, casse et espaces differents. Contact + attribution.
  UPDATE public.profiles SET signup_intent='reader_orphan', signup_intent_set_at=now()-interval '1 day',
    signup_intent_metadata='{"library_name_mentioned":"  bibliotheque du coin ","mention_contact_consent":true,"mention_attribution_consent":true}'::jsonb
   WHERE id=v_b;
  -- Ci : a nomme une biblio mais n'a RIEN consenti.
  UPDATE public.profiles SET signup_intent='reader_orphan', signup_intent_set_at=now(),
    signup_intent_metadata='{"library_name_mentioned":"Athenee Machin"}'::jsonb
   WHERE id=v_c;
  -- Di : lectrice d'une biblio du reseau, mention presente -> hors perimetre.
  UPDATE public.profiles SET signup_intent='reader_pending', signup_intent_set_at=now(),
    signup_intent_metadata='{"library_name_mentioned":"Pas Concernee","mention_contact_consent":true}'::jsonb
   WHERE id=v_d;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  v_t := 'T1 une seule bibliotheque listee (les deux graphies fusionnent)';
  BEGIN
    SELECT count(*) INTO v_n FROM public.fn_list_orphan_library_mentions();
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T2 sans consentement au contact -> mention INVISIBLE';
  BEGIN
    SELECT count(*) INTO v_n FROM public.fn_list_orphan_library_mentions()
     WHERE library_name ILIKE '%Athenee%';
    IF v_n = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : Ci exposee sans avoir consenti'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 une lectrice reader_pending n''est pas concernee';
  BEGIN
    SELECT count(*) INTO v_n FROM public.fn_list_orphan_library_mentions()
     WHERE library_name ILIKE '%Concernee%';
    IF v_n = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : reader_pending listee'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T4 les deux mentions sont COMPTEES (agrege)';
  BEGIN
    SELECT mentions INTO v_n FROM public.fn_list_orphan_library_mentions() LIMIT 1;
    IF v_n = 2 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_n::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T5 mais UNE SEULE personne est nommee (seule Bo a consenti a l''attribution)';
  BEGIN
    SELECT personnes INTO v_pers FROM public.fn_list_orphan_library_mentions() LIMIT 1;
    -- public_id est pose par un trigger, pas par la fixture : on assure sur le
    -- prenom, seul champ que ce test controle reellement.
    IF jsonb_array_length(v_pers) = 1 AND v_pers->0->>'prenom' = 'Bo' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_pers::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T6 Ana, qui n''a consenti QU''AU CONTACT, n''apparait nulle part nominativement';
  BEGIN
    SELECT personnes::text INTO v_txt FROM public.fn_list_orphan_library_mentions() LIMIT 1;
    IF position('Ana' in coalesce(v_txt,'')) = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : Ana nommee sans consentement d''attribution'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T7 la derniere mention est bien la plus recente des deux';
  BEGIN
    SELECT count(*) INTO v_n FROM public.fn_list_orphan_library_mentions()
     WHERE derniere_mention > now() - interval '2 days';
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- Le coeur de « une fonction qui lit, jamais une copie ».
  v_t := 'T8 effacer sa mention la fait disparaitre AUSSITOT de la liste';
  BEGIN
    UPDATE public.profiles
       SET signup_intent_metadata = signup_intent_metadata - 'library_name_mentioned'
     WHERE id = v_b;
    SELECT mentions INTO v_n FROM public.fn_list_orphan_library_mentions() LIMIT 1;
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_n::text,'NULL')||' (1 attendu)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T9 et la personne effacee n''est plus nommee non plus';
  BEGIN
    SELECT personnes::text INTO v_txt FROM public.fn_list_orphan_library_mentions() LIMIT 1;
    IF position('Bo' in coalesce(v_txt,'')) = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : Bo encore nommee apres effacement'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- ATTENDU CHANGÉ LE 01/09/2026, ET C'EST VOULU. Ce test exigeait « zero
  -- ligne » : c'etait la garde en WHERE de la fonction, qui rendait du vide au
  -- lieu de refuser. Decision collective du 01/09 (DOC-SILENCE-1) : un refus se
  -- dit. Une liste vide n'est pas rien, c'est une phrase — « aucune mention
  -- orpheline n'attend » — et personne ne pouvait la distinguer d'un manque de
  -- droit. La fonction leve desormais 42501. Le test garde donc le REFUS, pas
  -- le silence ; le vide reste verifie par les tests precedents, sous le JWT de
  -- la coordination, ou un zero est un vrai zero.
  v_t := 'T10 un non-admin se voit REFUSER la liste (et non servir du vide)';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM public.fn_list_orphan_library_mentions();
    v_failed:=v_failed+1;
    v_failures:=v_failures||(v_t||' : liste servie ('||v_n||' ligne(s)) au lieu d''un refus');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T11 la fonction n''est pas appelable en anonyme';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema='public' AND routine_name='fn_list_orphan_library_mentions'
       AND grantee IN ('anon','PUBLIC');
    IF v_n = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||' droit(s) de trop'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN RAISE EXCEPTION 'MENTIONS-C OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE RAISE EXCEPTION 'MENTIONS-C ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || '); END IF;
END $$;
