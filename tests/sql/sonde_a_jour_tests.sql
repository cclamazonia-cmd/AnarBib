-- =====================================================================
-- AnarBib — Tests : le témoin voit si la sonde de santé tourne.
-- Date    : 2026-10-23
-- Session : Modele de menace
-- Réf     : supabase/migrations/20261023153155_le_temoin_voit_si_la_sonde_tourne.sql
--
--   T1 aucune tournée récente → faux
--   T2 une tournée il y a 5 minutes → vrai
--   T3 seule une tournée vieille de 20 minutes → faux
--   T4 anon l'exécute (le témoin passe par la clé publiable) et reçoit
--      « vrai » sans voir une seule tournée (la RLS les lui cache)
--   T5 elle ne rend qu'un booléen
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'SONDE-A-JOUR OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_b boolean; v_n int;
BEGIN
  DELETE FROM public.service_health_probes;

  v_t := 'T1 aucune tournée récente → faux';
  IF api.sonde_a_jour() = false THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  INSERT INTO public.service_health_probes (endpoint, ok, status_code, latency_ms, checked_at)
  VALUES ('auth', true, 200, 100, now() - interval '5 minutes');
  v_t := 'T2 une tournée il y a 5 minutes → vrai';
  IF api.sonde_a_jour() = true THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  DELETE FROM public.service_health_probes;
  INSERT INTO public.service_health_probes (endpoint, ok, status_code, latency_ms, checked_at)
  VALUES ('auth', true, 200, 100, now() - interval '20 minutes');
  v_t := 'T3 seule une tournée vieille de 20 minutes → faux';
  IF api.sonde_a_jour() = false THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- anon a le droit de TABLE sur service_health_probes ; c'est la RLS (lecture
  -- réservée à l'administration du réseau) qui lui cache les lignes. On vérifie
  -- donc ce qui compte : anon ne voit aucune tournée, mais la fonction lui dit vrai.
  v_t := 'T4 anon reçoit le booléen sans voir aucune tournée';
  INSERT INTO public.service_health_probes (endpoint, ok, status_code, latency_ms, checked_at)
  VALUES ('auth', true, 200, 100, now() - interval '1 minute');
  IF has_function_privilege('anon', 'api.sonde_a_jour()', 'EXECUTE') THEN
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    SET LOCAL ROLE anon;
    v_b := api.sonde_a_jour();
    SELECT count(*) INTO v_n FROM public.service_health_probes;
    RESET ROLE;
    IF v_b = true AND v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rendu '||v_b||', lignes vues '||v_n); END IF;
  ELSE
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : anon ne l''exécute pas');
  END IF;

  v_t := 'T5 elle ne rend qu''un booléen';
  IF (SELECT prorettype FROM pg_proc WHERE oid = 'api.sonde_a_jour()'::regprocedure) = 'boolean'::regtype
     AND (SELECT proretset FROM pg_proc WHERE oid = 'api.sonde_a_jour()'::regprocedure) = false THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'SONDE-A-JOUR OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'SONDE-A-JOUR ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
