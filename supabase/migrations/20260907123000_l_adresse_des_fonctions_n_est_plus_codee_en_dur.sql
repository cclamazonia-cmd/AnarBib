-- =============================================================================
-- I20 — L'adresse des Edge Functions n'est plus codée en dur sur le projet cloud
-- Date : 2026-09-07 · Backlog v34 I20 · REGISTRE §24 FED-O11
-- -----------------------------------------------------------------------------
-- Le défaut. Douze fonctions PL/pgSQL et un job cron portaient le littéral
-- `https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/…` (quinze
-- occurrences dans huit migrations). Sur une pile auto-hébergée
-- (`api.anarbib.org`, Caddy devant `functions`), chaque `net.http_post` de ces
-- dispatchers serait donc parti vers le cloud du mainteneur, avec le secret
-- local en en-tête : rien ne tourne sur place (ni courriel, ni gazette, ni
-- sonde, ni moisson), et le secret est offert à un autre opérateur. FED-O11
-- promet qu'une instance est un réseau à part entière ; ces lignes disaient le
-- contraire, sans que personne ne l'ait décidé.
--
-- Le remède. UNE source de vérité : le réglage de base de données
-- `anarbib.functions_base_url` (posé par `ALTER DATABASE … SET`, visible dans
-- `pg_db_role_setting`, lu à l'ouverture de chaque session — PostgREST,
-- pg_cron, psql), servi par `private.fn_functions_base_url()`. Quand le
-- réglage est absent ou vide, le helper rend l'adresse du projet cloud
-- actuel : la production ne change donc PAS de comportement à l'application
-- de cette migration. `deploy/bootstrap.sh` pose le réglage sur une pile
-- auto-hébergée (étape 5 bis) et le vérifie à la fin.
--
-- Comment les douze fonctions sont réécrites — et pourquoi par MOTIF.
-- Le corps de chacune est lu dans `pg_get_functiondef` AU MOMENT de
-- l'application (en production comme au rejeu CI), et le littéral y est
-- remplacé par l'appel au helper ; puis le résultat est exécuté. C'est la
-- seule façon de « repartir de la définition réelle » sur douze fonctions à
-- la fois sans recopier douze corps (cf. la leçon B14 : recopier un corps
-- depuis une vieille migration réintroduit ce qu'une campagne postérieure
-- avait changé). Pour que cette réécriture reste TROUVABLE par un grep sur le
-- nom de la fonction, la liste est nominative et fermée (ci-dessous) ; une
-- fonction absente fait ÉCHOUER la migration au lieu d'être sautée.
--
-- Fonctions réécrites (relevé pg_proc en production, 07/09/2026) :
--   ingest.fn_cron_gc_deposits()
--   ingest.fn_dispatch_oai_harvest(bigint, integer)
--   ingest.fn_dispatch_partner_catalog_import(bigint, boolean)
--   public.fn_cartography_outbox_dispatch_trigger()
--   public.fn_enqueue_library_request_notification(uuid, text, text, uuid)
--   public.fn_gazette_build_call(text, integer)
--   public.fn_gazette_outbox_dispatch_trigger()
--   public.fn_gazette_translate_call()
--   public.fn_lettre_outbox_dispatch_trigger()
--   public.fn_rede_digest_call()
--   public.fn_team_outbox_dispatch_trigger()
--   public.fn_work_titles_autofill_call()
-- Job cron réécrit : anarbib-health-probe (commande `net.http_post` directe).
--
-- Gardes : `tests/sql/adresse_des_fonctions_tests.sql` (repli, réglage, corps
-- des douze, job cron, droits) et `src/tests/migrations-sans-url-cloud.test.js`
-- (aucun nouveau littéral `supabase.co/functions/v1` dans une migration ; les
-- huit fichiers historiques et celui-ci sont la liste fermée des exceptions).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Le helper. SECURITY INVOKER : il est appelé depuis des fonctions
--    SECURITY DEFINER (propriétaire postgres) et depuis les commandes cron ;
--    aucun compte du lectorat n'a à le lire.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.fn_functions_base_url()
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $$
  SELECT coalesce(
    nullif(btrim(current_setting('anarbib.functions_base_url', true)), ''),
    'https://uflwmikiyjfnikiphtcp.supabase.co'
  );
$$;

COMMENT ON FUNCTION private.fn_functions_base_url() IS
  'Base des URL des Edge Functions de CETTE instance (sans /functions/v1). Lit le réglage anarbib.functions_base_url (ALTER DATABASE … SET, posé par deploy/bootstrap.sh) ; repli : le projet cloud historique. I20, 07/09/2026.';

REVOKE ALL ON FUNCTION private.fn_functions_base_url() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.fn_functions_base_url() TO postgres, service_role;

-- -----------------------------------------------------------------------------
-- 2. Les douze fonctions : réécriture nominative, par motif, sur la définition
--    réelle. Idempotent : une fonction déjà réécrite n'a plus le littéral et
--    n'est pas touchée.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_sig   text;
  v_oid   oid;
  v_def   text;
  v_new   text;
  v_n     int := 0;
  v_pat   constant text := '''https://uflwmikiyjfnikiphtcp\.supabase\.co/functions/v1/([a-z0-9-]*)''';
  v_rep   constant text := '(private.fn_functions_base_url() || ''/functions/v1/\1'')';
BEGIN
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
    v_oid := to_regprocedure(v_sig);
    IF v_oid IS NULL THEN
      RAISE EXCEPTION 'I20 : fonction attendue introuvable : % (la liste est fermée ; la mettre à jour si la fonction a été renommée)', v_sig;
    END IF;
    v_def := pg_get_functiondef(v_oid);
    v_new := regexp_replace(v_def, v_pat, v_rep, 'g');
    IF v_new = v_def THEN
      RAISE NOTICE 'I20 : % ne porte plus le littéral, rien à faire.', v_sig;
      CONTINUE;
    END IF;
    EXECUTE v_new;
    v_n := v_n + 1;
    RAISE NOTICE 'I20 : % réécrite (adresse via private.fn_functions_base_url()).', v_sig;
  END LOOP;
  RAISE NOTICE 'I20 : % fonction(s) réécrite(s).', v_n;
END $$;

-- -----------------------------------------------------------------------------
-- 3. Le job cron `anarbib-health-probe` porte l'URL dans sa commande même.
--    `cron.schedule(nom, horaire, commande)` remplace le job du même nom (vraie
--    pg_cron comme stub CI). On saute proprement quand `cron` n'existe pas
--    (modèle 20260831111700) ; toute autre erreur remonte.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  r record;
  v_n int := 0;
BEGIN
  IF to_regnamespace('cron') IS NULL THEN
    RAISE NOTICE 'I20 : schéma cron absent ici, commandes de jobs non réécrites.';
    RETURN;
  END IF;
  FOR r IN
    SELECT jobid, jobname, schedule, command
      FROM cron.job
     WHERE command LIKE '%uflwmikiyjfnikiphtcp.supabase.co/functions/v1/%'
  LOOP
    PERFORM cron.schedule(
      r.jobname,
      r.schedule,
      regexp_replace(
        r.command,
        '''https://uflwmikiyjfnikiphtcp\.supabase\.co/functions/v1/([a-z0-9-]*)''',
        '(private.fn_functions_base_url() || ''/functions/v1/\1'')',
        'g'));
    v_n := v_n + 1;
    RAISE NOTICE 'I20 : job cron % réécrit.', r.jobname;
  END LOOP;
  RAISE NOTICE 'I20 : % job(s) cron réécrit(s).', v_n;
END $$;

-- -----------------------------------------------------------------------------
-- 4. Garde structurelle : plus aucun corps de fonction (hors le helper, qui
--    porte le repli) ni aucune commande cron ne contient le littéral.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_fn  text;
  v_job text;
BEGIN
  SELECT string_agg(n.nspname || '.' || p.proname, ', ') INTO v_fn
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE p.prosrc LIKE '%uflwmikiyjfnikiphtcp.supabase.co/functions/v1/%'
     AND NOT (n.nspname = 'private' AND p.proname = 'fn_functions_base_url');
  IF v_fn IS NOT NULL THEN
    RAISE EXCEPTION 'I20 : littéral cloud encore présent dans : %', v_fn;
  END IF;
  IF to_regnamespace('cron') IS NOT NULL THEN
    SELECT string_agg(jobname, ', ') INTO v_job
      FROM cron.job WHERE command LIKE '%uflwmikiyjfnikiphtcp.supabase.co/functions/v1/%';
    IF v_job IS NOT NULL THEN
      RAISE EXCEPTION 'I20 : littéral cloud encore présent dans le(s) job(s) : %', v_job;
    END IF;
  END IF;
  IF has_function_privilege('anon', 'private.fn_functions_base_url()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'private.fn_functions_base_url()', 'EXECUTE') THEN
    RAISE EXCEPTION 'I20 : private.fn_functions_base_url() ne doit pas être exécutable par anon/authenticated';
  END IF;
  RAISE NOTICE 'I20 OK : adresse des fonctions servie par private.fn_functions_base_url() (repli : %).',
    private.fn_functions_base_url();
END $$;
