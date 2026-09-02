-- Suite d'acceptation — migration 20260902175631 (B20, rattrapage : une vue appelle aussi).
--
-- Trois fonctions fermées par les campagnes du 01-02/09 sont appelées par
-- des vues `api` en security_invoker que le front lit ; une vue
-- security_invoker exécute ses fonctions sous le rôle du lecteur, EXECUTE
-- lui est donc nécessaire (PostgREST rend 403 sinon). Cette suite garde
-- les deux bords : ouvertes à authenticated, fermées à anon, et la
-- dépendance vue → fonction toujours visible dans pg_depend (pg_rewrite),
-- pour que la prochaine campagne la trouve.

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_liste text;
BEGIN
  -- T1 : les trois sont ouvertes à authenticated
  v_test_name := 'T1 ouvertes à authenticated';
  SELECT string_agg(a.nsp||'.'||a.nom, ', ') INTO v_liste
  FROM (VALUES ('public','fn_circle_member_count'),('public','fn_assembleia_facilitator_name'),
               ('api','get_remaining_renewals')) a(nsp, nom)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = a.nsp AND p.proname = a.nom
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : fermées ou introuvables — ' || v_liste); END IF;

  -- T2 : aucune n'est ouverte à anon (les vues appelantes ne le sont pas non plus)
  v_test_name := 'T2 fermées à anon';
  SELECT string_agg(n.nspname||'.'||p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE ((n.nspname = 'public' AND p.proname IN ('fn_circle_member_count','fn_assembleia_facilitator_name'))
      OR (n.nspname = 'api' AND p.proname = 'get_remaining_renewals'))
    AND has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ouvertes à anon — ' || v_liste); END IF;

  -- T3 : la dépendance vue → fonction est visible dans pg_depend (classid pg_rewrite),
  --      et chaque vue appelante est en security_invoker — c'est ce couple qui
  --      rend le grant nécessaire.
  v_test_name := 'T3 vues appelantes en security_invoker';
  SELECT string_agg(a.vue||' → '||a.fn, ', ') INTO v_liste
  FROM (VALUES ('my_library_circles_v1','fn_circle_member_count'),
               ('circles_directory_v1','fn_circle_member_count'),
               ('assembleia_facilitators_v1','fn_assembleia_facilitator_name'),
               ('my_loans_renewal_status_v1','get_remaining_renewals'),
               ('staff_loans_renewal_status_v1','get_remaining_renewals')) a(vue, fn)
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_rewrite rw ON rw.ev_class = c.oid
    JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid
                    AND d.refclassid = 'pg_proc'::regclass
    JOIN pg_proc p ON p.oid = d.refobjid
    WHERE c.relnamespace = 'api'::regnamespace AND c.relname = a.vue AND c.relkind = 'v'
      AND 'security_invoker=true' = ANY (c.reloptions)
      AND p.proname = a.fn);
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : dépendance absente ou vue plus en security_invoker — ' || v_liste); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'UNE_VUE_APPELLE_AUSSI ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'UNE_VUE_APPELLE_AUSSI OK : %/% tests passés', v_passed, v_passed;
END $$;
