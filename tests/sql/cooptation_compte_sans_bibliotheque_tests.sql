-- =====================================================================
-- AnarBib — Tests : la cooptation trouve un compte sans bibliothèque.
-- Date    : 2026-10-05
-- Réf     : supabase/migrations/20261005113021_la_cooptation_trouve_un_compte_sans_bibliotheque.sql
--
--   · une personne inscrite sans aucune bibliothèque est INVISIBLE à l'admin
--     réseau par `profiles` (RLS) — la cause du « Aucun compte trouvé » ;
--   · fn_network_admin_find_user_by_email la trouve, casse et espaces ignorés ;
--   · l'adresse est comparée exactement (`_` n'est pas un joker) ;
--   · une personne qui n'administre pas le réseau est refusée (error.forbidden) ;
--   · ni anon ni le public n'exécutent la fonction.
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'COOPTATION-SANS-BIBLIO OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_admin uuid := gen_random_uuid(); v_seul uuid := gen_random_uuid(); v_autre uuid := gen_random_uuid();
  v_suf text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_id uuid; v_n int; v_hint text;
BEGIN
  INSERT INTO auth.users (id, email) VALUES
    (v_admin, 'coopt-admin-' || v_suf || '@example.invalid'),
    (v_seul,  'coopt_seul-' || v_suf || '@example.invalid'),
    (v_autre, 'cooptxseul-' || v_suf || '@example.invalid');
  INSERT INTO public.profiles (id, email) VALUES
    (v_admin, 'coopt-admin-' || v_suf || '@example.invalid'),
    (v_seul,  'coopt_seul-' || v_suf || '@example.invalid'),
    (v_autre, 'cooptxseul-' || v_suf || '@example.invalid')
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;

  v_t := 'T1 la cause : sous la RLS, l''admin réseau ne voit pas le profil d''une personne sans bibliothèque';
  SELECT count(*) INTO v_n FROM public.profiles WHERE id = v_seul;
  IF v_n = 0 THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : visible'); END IF;

  v_t := 'T2 la fonction la trouve, casse et espaces ignorés';
  v_id := public.fn_network_admin_find_user_by_email('  COOPT_SEUL-' || upper(v_suf) || '@Example.Invalid ');
  IF v_id = v_seul THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_id::text,'NULL')); END IF;

  v_t := 'T3 l''adresse est exacte : « _ » n''est pas un joker, une adresse inconnue rend NULL';
  IF public.fn_network_admin_find_user_by_email('coopt_seul-' || v_suf || '@example.invalid') = v_seul
     AND public.fn_network_admin_find_user_by_email('cooptxseul-' || v_suf || '@example.invalid') = v_autre
     AND public.fn_network_admin_find_user_by_email('coopt%seul-' || v_suf || '@example.invalid') IS NULL
     AND public.fn_network_admin_find_user_by_email('') IS NULL
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_autre, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  v_t := 'T4 une personne qui n''administre pas le réseau est refusée (error.forbidden)';
  v_hint := NULL;
  BEGIN
    PERFORM public.fn_network_admin_find_user_by_email('coopt_seul-' || v_suf || '@example.invalid');
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  IF v_hint = 'error.forbidden' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'aucun')); END IF;
  RESET ROLE;

  v_t := 'T5 ni anon ni le public n''exécutent la fonction ; authenticated oui';
  IF NOT has_function_privilege('anon', 'public.fn_network_admin_find_user_by_email(text)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.fn_network_admin_find_user_by_email(text)', 'EXECUTE')
     AND NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
                      WHERE p.oid = 'public.fn_network_admin_find_user_by_email(text)'::regprocedure
                        AND a.grantee = 0 AND a.privilege_type = 'EXECUTE')
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  PERFORM set_config('request.jwt.claims', '', true);
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'COOPTATION-SANS-BIBLIO OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'COOPTATION-SANS-BIBLIO ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
