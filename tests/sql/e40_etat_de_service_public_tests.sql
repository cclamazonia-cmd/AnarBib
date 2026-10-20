-- =====================================================================
-- AnarBib — Tests d'acceptation : l'état de service d'une bibliothèque
-- publique se lit sans compte (E40)
-- Date    : 2026-10-20
-- Ref     : migration 20261020193858_e40_l_etat_de_service_des_bibliotheques_publiques_se_lit
--
-- Fixture : une bibliothèque publique P et une privée Q, posées ici, chacune
-- avec son état de service et un mot public ; la coordination BLMF du seed.
-- T1 anon : api.library_service_public rend P (mot public compris), rien de Q.
-- T2 anon : la table ne rend que P, et seulement les colonnes de la vue —
--    l'horaire de consultation est refusé (42501).
-- T3 un compte sans bibliothèque : P, rien de Q.
-- T4 l'équipe garde tout sur sa bibliothèque (coordination BLMF : ligne et
--    réglages de consultation lus, mise à jour permise).
-- T5 anon n'écrit rien.
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'E40-ETAT-SERVICE-PUBLIC OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_seul  uuid := gen_random_uuid();                       -- un compte sans bibliothèque
  v_P uuid := gen_random_uuid(); v_Q uuid := gen_random_uuid();
  v_x text; v_n int;
BEGIN
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level) VALUES
    (v_P, 'e40-publique', 'E40 Publique', true, 'public'),
    (v_Q, 'e40-privee', 'E40 Privée', true, 'private');
  INSERT INTO public.library_service_state (library_id, public_message, consultation_timezone)
  VALUES (v_P, 'Fermée le lundi', 'Europe/Paris'), (v_Q, 'Mot de la privée', 'Europe/Paris')
  ON CONFLICT (library_id) DO UPDATE SET public_message = EXCLUDED.public_message;
  INSERT INTO public.library_service_state (library_id) VALUES (v_lib) ON CONFLICT (library_id) DO NOTHING;

  v_t := 'T1 anon : la vue publique rend P, rien de Q';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT string_agg(slug || '=' || coalesce(public_message, '∅'), ',' ORDER BY slug) INTO v_x
      FROM api.library_service_public WHERE slug IN ('e40-publique', 'e40-privee');
    EXECUTE 'RESET ROLE';
    IF v_x = 'e40-publique=Fermée le lundi' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_x,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T2 anon : la table rend P seule, sans l''horaire de consultation';
  DECLARE v_refus boolean := false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT count(*) INTO v_n FROM public.library_service_state WHERE library_id IN (v_P, v_Q);
    BEGIN
      PERFORM consultation_schedule_struct FROM public.library_service_state WHERE library_id = v_P;
    EXCEPTION WHEN insufficient_privilege THEN v_refus := true;
    END;
    EXECUTE 'RESET ROLE';
    IF v_n = 1 AND v_refus THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lignes '||v_n||', horaire refusé '||v_refus); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 un compte sans bibliothèque : P, rien de Q';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_seul, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT string_agg(slug, ',' ORDER BY slug) INTO v_x
      FROM api.library_service_public WHERE slug IN ('e40-publique', 'e40-privee');
    EXECUTE 'RESET ROLE';
    IF v_x = 'e40-publique' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_x,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T4 l''équipe garde tout sur sa bibliothèque';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated', 'aal', 'aal2')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.library_service_state WHERE library_id = v_lib AND consultation_timezone IS NOT NULL;
    UPDATE public.library_service_state SET public_message = 'E40 essai' WHERE library_id = v_lib;
    EXECUTE 'RESET ROLE';
    IF v_n = 1 AND (SELECT public_message FROM public.library_service_state WHERE library_id = v_lib) = 'E40 essai'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lue '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T5 anon n''écrit rien';
  DECLARE v_refus boolean := false;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    EXECUTE 'SET LOCAL ROLE anon';
    BEGIN
      UPDATE public.library_service_state SET public_message = 'pirate' WHERE library_id = v_P;
    EXCEPTION WHEN insufficient_privilege THEN v_refus := true;
    END;
    EXECUTE 'RESET ROLE';
    IF v_refus AND (SELECT public_message FROM public.library_service_state WHERE library_id = v_P) = 'Fermée le lundi'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'E40-ETAT-SERVICE-PUBLIC OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'E40-ETAT-SERVICE-PUBLIC ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
