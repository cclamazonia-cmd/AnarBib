-- =====================================================================
-- AnarBib — Tests : G16 — le vote des transitions parle la langue de la
-- base, et l'abstention est gardée (règle de la cooptation).
-- Date    : 2026-10-05
-- Réf     : supabase/migrations/20261005101029_le_vote_des_transitions_parle_la_langue_de_la_base.sql
--
-- La suite EMPRUNTE le circuit : fn_propose_library_profile_change (la vraie
-- classification des transitions), puis fn_vote_library_profile_change sous la
-- session de chaque membre de l'équipe.
--   · type 2 (majorité, 3 personnes) : abstention + deux « pour » → acceptée,
--     sans carence ni verrou (le vote gagnant échouait sur la CHECK du verrou) ;
--     deux abstentions → rejetée, la majorité n'est plus atteignable ;
--   · type 3 (unanimité, 2 personnes) : « pour » + abstention → rejetée ;
--     deux « pour » → acceptée, carence 7 jours ;
--   · type 4 (unanimité étendue, 3 personnes) : trois « pour » → acceptée,
--     carence 14 jours et verrou de carence — elle ne se fermait jamais ;
--     une opposition motivée → rejetée ;
--   · la tâche d'application (cron) applique la majorité acceptée, et laisse
--     attendre celles qui sont en carence ;
--   · les valeurs de l'ancien écran (« pro ») sont refusées avec leur clé ; une
--     opposition de moins de 20 caractères aussi ; une abstention ne porte pas
--     de motif (CHECK).
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'VOTE-TRANSITIONS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_u uuid[] := ARRAY[gen_random_uuid(), gen_random_uuid(), gen_random_uuid()];
  v_suf text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_libs uuid[] := ARRAY[]::uuid[]; v_lib uuid; v_p uuid; v_res jsonb; v_hint text; v_st text; v_grace timestamptz;
  i int;
BEGIN
  FOR i IN 1 .. 3 LOOP
    INSERT INTO auth.users (id, email) VALUES (v_u[i], 'g16-' || i || '-' || v_suf || '@example.invalid');
    INSERT INTO public.profiles (id) VALUES (v_u[i]) ON CONFLICT (id) DO NOTHING;
  END LOOP;

  -- Une bibliothèque d'essai par scénario : n membres d'équipe actifs.
  FOR i IN 1 .. 6 LOOP
    INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, governance_mode, catalog_mode, is_active, visibility_level)
    VALUES ('g16-' || i || '-' || v_suf, 'G16 ' || i || ' (essai)', 'federated', 'full_sigb', 'full_governance', 'network_published', true, 'public')
    RETURNING id INTO v_lib;
    v_libs := v_libs || v_lib;
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
    SELECT v_u[k], v_lib, CASE WHEN k = 1 THEN 'coordenador' ELSE 'librarian' END, 'active', false
      FROM generate_series(1, CASE WHEN i IN (3, 4) THEN 2 ELSE 3 END) k;
  END LOOP;

  -- ── type 2, majorité : abstention + deux « pour » ────────────────────
  v_lib := v_libs[1];
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[1], 'role', 'authenticated')::text, true);
  v_res := public.fn_propose_library_profile_change(v_lib, 'governance_mode', 'staff_roles', 'G16 recul doux (essai)');
  v_p := (v_res->>'proposal_id')::uuid;
  v_t := 'T1 full_governance → staff_roles est une majorité (type 2)';
  IF v_res->>'governance_required' = 'majority' AND v_res->>'status' = 'open'
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res::text); END IF;

  v_t := 'T2 une abstention puis un « pour » : la proposition reste ouverte (2 « pour » requis, un vote restant)';
  BEGIN
    PERFORM public.fn_vote_library_profile_change(v_p, 'abstain', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[2], 'role', 'authenticated')::text, true);
    v_res := public.fn_vote_library_profile_change(v_p, 'for', NULL);
    IF v_res->>'proposal_status' = 'open' AND (v_res->>'votes_abstain')::int = 1
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 le second « pour » fait la majorité : acceptée, sans carence ni verrou (le vote gagnant échouait)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[3], 'role', 'authenticated')::text, true);
    v_res := public.fn_vote_library_profile_change(v_p, 'for', NULL);
    SELECT status, grace_period_until INTO v_st, v_grace FROM public.library_profile_proposals WHERE id = v_p;
    IF v_st = 'accepted_majority' AND v_grace <= now()
       AND NOT EXISTS (SELECT 1 FROM public.library_profile_grace_locks WHERE proposal_id = v_p)
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_st,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── type 2, majorité : deux abstentions ──────────────────────────────
  v_lib := v_libs[2];
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[1], 'role', 'authenticated')::text, true);
  v_p := (public.fn_propose_library_profile_change(v_lib, 'governance_mode', 'staff_roles', 'G16 recul doux (essai)')->>'proposal_id')::uuid;
  v_t := 'T4 deux abstentions sur trois : la majorité n''est plus atteignable, rejetée';
  BEGIN
    PERFORM public.fn_vote_library_profile_change(v_p, 'abstain', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[2], 'role', 'authenticated')::text, true);
    PERFORM public.fn_vote_library_profile_change(v_p, 'abstain', NULL);
    SELECT status INTO v_st FROM public.library_profile_proposals WHERE id = v_p;
    IF v_st = 'rejected' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_st,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── type 3, unanimité : « pour » + abstention ────────────────────────
  v_lib := v_libs[3];
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[1], 'role', 'authenticated')::text, true);
  v_res := public.fn_propose_library_profile_change(v_lib, 'network_mode', 'observer', 'G16 sortie de la fédération (essai)');
  v_p := (v_res->>'proposal_id')::uuid;
  v_t := 'T5 une abstention rend l''unanimité impossible : rejetée aussitôt (type 3)';
  BEGIN
    PERFORM public.fn_vote_library_profile_change(v_p, 'for', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[2], 'role', 'authenticated')::text, true);
    PERFORM public.fn_vote_library_profile_change(v_p, 'abstain', NULL);
    SELECT status INTO v_st FROM public.library_profile_proposals WHERE id = v_p;
    IF v_res->>'governance_required' = 'unanimous' AND v_st = 'rejected'
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_st,'NULL')||' '||v_res::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── type 3, unanimité : deux « pour » ────────────────────────────────
  v_lib := v_libs[4];
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[1], 'role', 'authenticated')::text, true);
  v_p := (public.fn_propose_library_profile_change(v_lib, 'network_mode', 'observer', 'G16 sortie de la fédération (essai)')->>'proposal_id')::uuid;
  v_t := 'T6 tout le staff « pour » : acceptée à l''unanimité, carence de 7 jours';
  BEGIN
    PERFORM public.fn_vote_library_profile_change(v_p, 'for', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[2], 'role', 'authenticated')::text, true);
    PERFORM public.fn_vote_library_profile_change(v_p, 'for', NULL);
    SELECT status, grace_period_until INTO v_st, v_grace FROM public.library_profile_proposals WHERE id = v_p;
    IF v_st = 'accepted_unanimous' AND v_grace BETWEEN now() + interval '6 days 23 hours' AND now() + interval '7 days 1 hour'
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_st,'NULL')||' '||coalesce(v_grace::text,'')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── type 4, unanimité étendue : trois « pour » ───────────────────────
  v_lib := v_libs[5];
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[1], 'role', 'authenticated')::text, true);
  v_res := public.fn_propose_library_profile_change(v_lib, 'circulation_mode', 'informal', 'G16 fin de la circulation formelle (essai)');
  v_p := (v_res->>'proposal_id')::uuid;
  v_t := 'T7 type 4 : trois « pour » ferment la proposition — acceptée, carence de 14 jours, verrou posé';
  BEGIN
    FOR i IN 1 .. 3 LOOP
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[i], 'role', 'authenticated')::text, true);
      PERFORM public.fn_vote_library_profile_change(v_p, 'for', NULL);
    END LOOP;
    SELECT status, grace_period_until INTO v_st, v_grace FROM public.library_profile_proposals WHERE id = v_p;
    IF v_res->>'governance_required' = 'unanimous_extended' AND v_st = 'accepted_unanimous'
       AND v_grace BETWEEN now() + interval '13 days 23 hours' AND now() + interval '14 days 1 hour'
       AND EXISTS (SELECT 1 FROM public.library_profile_grace_locks WHERE proposal_id = v_p)
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_st,'NULL')||' '||coalesce(v_grace::text,'')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── type 4 : une opposition motivée ──────────────────────────────────
  v_lib := v_libs[6];
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u[1], 'role', 'authenticated')::text, true);
  v_p := (public.fn_propose_library_profile_change(v_lib, 'circulation_mode', 'informal', 'G16 fin de la circulation formelle (essai)')->>'proposal_id')::uuid;

  v_t := 'T8 les valeurs de l''ancien écran (« pro ») sont refusées, avec leur clé';
  v_hint := NULL;
  BEGIN
    PERFORM public.fn_vote_library_profile_change(v_p, 'pro', NULL);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  IF v_hint = 'error.profile_change.vote_invalid' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'aucun')); END IF;

  v_t := 'T9 une opposition de moins de 20 caractères est refusée';
  v_hint := NULL;
  BEGIN
    PERFORM public.fn_vote_library_profile_change(v_p, 'against', 'trop court');
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  IF v_hint = 'error.profile_change.rationale_required' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'aucun')); END IF;

  v_t := 'T10 type 4 : une opposition motivée rejette la proposition (elle ne se fermait jamais)';
  BEGIN
    PERFORM public.fn_vote_library_profile_change(v_p, 'against', 'Les prêts en cours doivent d''abord être rendus.');
    SELECT status INTO v_st FROM public.library_profile_proposals WHERE id = v_p;
    IF v_st = 'rejected' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_st,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T11 une abstention ne porte pas de motif (CHECK de la table)';
  BEGIN
    INSERT INTO public.library_profile_votes (proposal_id, voter_id, vote, rationale_against)
    VALUES (v_p, v_u[3], 'abstain', 'un motif qui n''a pas lieu d''être ici');
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : accepté');
  EXCEPTION WHEN check_violation THEN v_passed := v_passed+1;
  END;

  -- ── et l'application : la tâche planifiée applique la majorité acceptée ──
  PERFORM set_config('request.jwt.claims', '', true);
  v_t := 'T12 la tâche d''application (cron) applique la proposition acceptée à la majorité : la bibliothèque passe en staff_roles';
  BEGIN
    PERFORM public.fn_execute_due_profile_proposals();
    IF (SELECT governance_mode FROM public.libraries WHERE id = v_libs[1]) = 'staff_roles'
       AND (SELECT count(*) FROM public.library_profile_proposals
             WHERE library_id = v_libs[1] AND status = 'completed' AND completed_at IS NOT NULL) = 1
       -- les acceptées EN CARENCE (types 3 et 4) attendent
       AND (SELECT network_mode FROM public.libraries WHERE id = v_libs[4]) = 'federated'
       AND (SELECT circulation_mode FROM public.libraries WHERE id = v_libs[5]) = 'full_sigb'
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'VOTE-TRANSITIONS OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'VOTE-TRANSITIONS ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
