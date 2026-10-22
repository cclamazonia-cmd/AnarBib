-- =====================================================================
-- AnarBib — Tests d'acceptation : les appels aux flux OPDS et RSS comptés
-- (J10 / DOC-GEL-2)
-- Date    : 2026-10-22
-- Ref     : migration 20261022204106_j10_les_appels_opds_rss_comptes_un_mois
--
-- T1 trois appels du même flux, route et client → une ligne, n = 3
-- T2 routes et clients distincts → lignes distinctes ; client hors forme → « autre »
-- T3 refus (22023) : flux inconnu, route vide ou hors forme — rien écrit
-- T4 table fermée (RLS, aucun droit au lectorat) ; service_role seul exécute
--   Bilan OK : 'FLUX-APPELS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_jour date := (now() AT TIME ZONE 'UTC')::date;
  v_l text; v_state text; v_n int;
BEGIN
  DELETE FROM private.flux_appels WHERE route LIKE 'zz-%';

  v_t := 'T1 un compteur par jour';
  BEGIN
    PERFORM public.fn_flux_compter_v1('opds', 'zz-tout', 'koreader');
    PERFORM public.fn_flux_compter_v1('opds', 'zz-tout', 'koreader');
    PERFORM public.fn_flux_compter_v1('opds', 'zz-tout', 'koreader');
    SELECT string_agg(jour::text || '/' || flux || '/' || route || '/' || client || '=' || n, ',') INTO v_l
      FROM private.flux_appels WHERE route = 'zz-tout';
    IF v_l = v_jour::text || '/opds/zz-tout/koreader=3' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_l,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T2 lignes distinctes, client hors forme en « autre »';
  BEGIN
    PERFORM public.fn_flux_compter_v1('rss', 'zz-biblio', 'feedly');
    PERFORM public.fn_flux_compter_v1('rss', 'zz-biblio', 'Mozilla/5.0 (X11)');
    PERFORM public.fn_flux_compter_v1('rss', 'zz-biblio', NULL);
    SELECT string_agg(client || '=' || n, ',' ORDER BY client) INTO v_l
      FROM private.flux_appels WHERE route = 'zz-biblio' AND flux = 'rss';
    IF v_l = 'autre=2,feedly=1' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_l,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 refus';
  BEGIN
    v_l := '';
    BEGIN PERFORM public.fn_flux_compter_v1('atom', 'zz-x', 'autre'); v_l := v_l || 'flux accepté;';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; IF v_state <> '22023' THEN v_l := v_l || 'flux:' || v_state || ';'; END IF; END;
    BEGIN PERFORM public.fn_flux_compter_v1('opds', '', 'autre'); v_l := v_l || 'route vide acceptée;';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; IF v_state <> '22023' THEN v_l := v_l || 'vide:' || v_state || ';'; END IF; END;
    BEGIN PERFORM public.fn_flux_compter_v1('opds', 'ZZ/../x', 'autre'); v_l := v_l || 'route hors forme acceptée;';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; IF v_state <> '22023' THEN v_l := v_l || 'forme:' || v_state || ';'; END IF; END;
    SELECT count(*) INTO v_n FROM private.flux_appels WHERE route IN ('zz-x', '');
    IF v_l = '' AND v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_l||' lignes='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T4 fermé au lectorat';
  IF (SELECT relrowsecurity FROM pg_class WHERE oid = 'private.flux_appels'::regclass)
     AND NOT has_table_privilege('anon', 'private.flux_appels', 'SELECT')
     AND NOT has_table_privilege('authenticated', 'private.flux_appels', 'INSERT')
     AND NOT has_function_privilege('anon', 'public.fn_flux_compter_v1(text, text, text)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_flux_compter_v1(text, text, text)', 'EXECUTE')
     AND has_function_privilege('service_role', 'public.fn_flux_compter_v1(text, text, text)', 'EXECUTE')
  THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'FLUX-APPELS OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'FLUX-APPELS ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
