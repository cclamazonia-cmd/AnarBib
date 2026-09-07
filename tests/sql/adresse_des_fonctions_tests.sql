-- =====================================================================
-- AnarBib — Tests d'acceptation : l'adresse des fonctions n'est plus
--           codée en dur (I20)
-- Date    : 2026-09-07  ·  Backlog v34 I20  ·  REGISTRE §24 FED-O11
-- Ref     : migration 20260907123000_l_adresse_des_fonctions_n_est_plus_codee_en_dur
--
-- Pourquoi cette suite existe : douze dispatchers PL/pgSQL et un job cron
-- portaient l'URL du projet cloud du mainteneur. Une instance auto-hébergée
-- aurait envoyé ses dépêches (courriels, gazette, sonde, moisson) à la
-- production d'AnarBib, avec son propre secret en en-tête. La migration a
-- remplacé le littéral par `private.fn_functions_base_url()`, qui lit le
-- réglage `anarbib.functions_base_url` et se replie sur l'adresse cloud.
--
--   T1 réglage absent/vide → repli : l'adresse cloud historique (la
--      production ne change pas de comportement)
--   T2 réglage posé pour la session → le helper le rend tel quel
--   T3 plus AUCUN corps de fonction (hors le helper) ne porte le littéral
--   T4 les douze fonctions nommées appellent le helper
--   T5 le job cron `anarbib-health-probe` appelle le helper (déclaré « sur
--      stub » si cron.is_ci_stub() existe — DOC-SILENCE-1)
--   T6 ni anon ni authenticated ne peuvent exécuter le helper
--   T7 la fonction de dispatch de la moisson construit bien son URL avec le
--      réglage : on lit `pg_get_functiondef` et on vérifie la forme
--      « helper || '/functions/v1/harvest-oai-pmh' »
--
--   Bilan OK : 'ADRESSE-FONCTIONS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed   int := 0;
  v_failed   int := 0;
  v_failures text[] := '{}';
  v_t        text;
  v_txt      text;
  v_n        int;
  v_sig      text;
  v_manque   text[] := '{}';
  v_stub     boolean := false;
BEGIN
  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 réglage absent → repli cloud';
  PERFORM set_config('anarbib.functions_base_url', '', true);
  IF private.fn_functions_base_url() = 'https://uflwmikiyjfnikiphtcp.supabase.co' THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(private.fn_functions_base_url(), '∅'));
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 réglage posé → rendu tel quel';
  PERFORM set_config('anarbib.functions_base_url', '  https://api.exemple.invalid  ', true);
  IF private.fn_functions_base_url() = 'https://api.exemple.invalid' THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(private.fn_functions_base_url(), '∅'));
  END IF;
  PERFORM set_config('anarbib.functions_base_url', '', true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 plus aucun corps de fonction ne porte le littéral cloud';
  SELECT string_agg(n.nspname || '.' || p.proname, ', ') INTO v_txt
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE p.prosrc LIKE '%uflwmikiyjfnikiphtcp.supabase.co/functions/v1/%'
     AND NOT (n.nspname = 'private' AND p.proname = 'fn_functions_base_url');
  IF v_txt IS NULL THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt);
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 les douze fonctions appellent private.fn_functions_base_url()';
  FOREACH v_sig IN ARRAY ARRAY[
    'ingest.fn_cron_gc_deposits()',
    'ingest.fn_dispatch_oai_harvest(bigint, integer)',
    'ingest.fn_dispatch_partner_catalog_import(bigint, boolean)',
    'public.fn_cartography_outbox_dispatch_trigger()',
    'public.fn_enqueue_library_request_notification(uuid, text, text, uuid)',
    'public.fn_gazette_build_call(text, integer)',
    'public.fn_gazette_outbox_dispatch_trigger()',
    'public.fn_gazette_translate_call()',
    'public.fn_lettre_outbox_dispatch_trigger()',
    'public.fn_rede_digest_call()',
    'public.fn_team_outbox_dispatch_trigger()',
    'public.fn_work_titles_autofill_call()'
  ] LOOP
    IF to_regprocedure(v_sig) IS NULL
       OR (SELECT prosrc FROM pg_proc WHERE oid = to_regprocedure(v_sig)) NOT LIKE '%private.fn_functions_base_url()%' THEN
      v_manque := v_manque || v_sig;
    END IF;
  END LOOP;
  IF cardinality(v_manque) = 0 THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || array_to_string(v_manque, ', '));
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 le job cron anarbib-health-probe appelle le helper';
  IF to_regnamespace('cron') IS NULL THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : schéma cron absent');
  ELSE
    IF to_regprocedure('cron.is_ci_stub()') IS NOT NULL THEN
      EXECUTE 'select cron.is_ci_stub()' INTO v_stub;
    END IF;
    EXECUTE $q$ select count(*) from cron.job
                 where jobname = 'anarbib-health-probe'
                   and command like '%private.fn_functions_base_url()%'
                   and command not like '%uflwmikiyjfnikiphtcp.supabase.co/functions/v1/%' $q$
      INTO v_n;
    IF v_n = 1 THEN
      v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' job(s) conformes');
    END IF;
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 anon et authenticated ne peuvent pas exécuter le helper';
  IF NOT has_function_privilege('anon', 'private.fn_functions_base_url()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'private.fn_functions_base_url()', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || v_t;
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 la moisson construit son URL depuis le réglage';
  SELECT prosrc INTO v_txt FROM pg_proc WHERE oid = to_regprocedure('ingest.fn_dispatch_oai_harvest(bigint, integer)');
  IF v_txt LIKE '%(private.fn_functions_base_url() || ''/functions/v1/harvest-oai-pmh'')%' THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || v_t;
  END IF;

  -- ─── Bilan ────────────────────────────────────────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ADRESSE-FONCTIONS OK : %/% tests passés%', v_passed, v_passed + v_failed,
      CASE WHEN v_stub THEN ' (T5 sur le stub cron de la CI : prouve la commande, pas le job en production)' ELSE '' END;
  ELSE
    RAISE EXCEPTION 'ADRESSE-FONCTIONS ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
