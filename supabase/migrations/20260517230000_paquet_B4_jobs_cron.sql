-- ============================================================================
-- AnarBib -- Paquet B.4 -- Jobs pg_cron cycle de vie des propositions
-- ============================================================================
-- Date            : 17/05/2026
-- Auteur          : Xavier (via Claude)
-- Chantier        : #98-B Profils d'adoption / Paquet B Transitions
-- Spec reference  : docs/specs/spec-profils-bibliotheque.md v0.3 §9.5
-- Doctrine        : docs/decisions/CHANTIER_doctrine_transitions_profils_2026-05-17.md
-- Prerequis       : B.1 (tables), B.2 (classification), B.3 (RPC metier) en prod
-- ============================================================================
--
-- Objectif :
--   Deposer 2 jobs pg_cron qui automatisent le cycle de vie des propositions
--   de transition de profil :
--
--     1. fn_expire_overdue_profile_proposals()
--        Daily a 03:00 UTC. Marque comme 'expired' les propositions 'open'
--        dont expires_at < now(). Politiquement : une deliberation qui
--        n'aboutit pas dans 30 jours est consideree comme abandonnee.
--
--     2. fn_execute_due_profile_proposals()
--        Toutes les 15 min. Execute les propositions 'accepted_*' dont la
--        carence est echue. Filet de securite de la doctrine D3 (cloture
--        hybride) : si fn_vote n'a pas reussi a enclencher l'execution dans
--        sa transaction, ce cron rattrape.
--
-- Decisions doctrinales (session 17/05/2026) :
--   D7. Fréquence expiration : daily 03:00 UTC (peu de propositions, pas urgent).
--   D8. Fréquence execution : toutes les 15 min (UX correcte, charge minimale).
--   D9. Audit : RAISE NOTICE dans le code (visible dans pg_cron logs).
--       Pas de table dediee library_profile_cron_runs (overkill).
--   D10. Grace_locks : les jobs B.4 N'INTERROGENT PAS la table
--        library_profile_grace_locks. Ces locks signalent aux AUTRES jobs
--        (futurs, hors B) qu'ils doivent skip une biblio pendant la carence.
--        Les jobs B.4 operent sur library_profile_proposals (leur propre
--        table), pas sur libraries.*_mode directement (delegue a fn_execute_*).
--
-- Doctrine #141.2.E rappelee :
--   fn_execute_library_profile_change (RPC B.3) gere deja l'ordre des UPDATEs
--   narrative-avant-etat. Les jobs B.4 se contentent d'appeler ce RPC, donc
--   l'ordre est respecte sans avoir a se preoccuper de la sequence interne.
--
-- Extension pg_cron :
--   Supposee disponible (chantier admin reseau v0.3 et chantier consultations
--   utilisent deja pg_cron). On schedule via cron.schedule() avec verification
--   prealable de l'existence de l'extension.
--
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Job d'expiration : fn_expire_overdue_profile_proposals
-- ============================================================================
-- Logique :
--   FOR chaque proposal WHERE status='open' AND expires_at <= now() LOOP
--     UPDATE proposal SET status='expired' WHERE id = ...
--   END LOOP
--
-- Note : on n'utilise PAS un simple UPDATE en masse parce que la doctrine
-- d'audit veut une trace ligne par ligne. RAISE NOTICE pour chaque expiration
-- pour visibilite dans les logs pg_cron.
--
-- Volume attendu : tres faible (quelques expirations par mois en croisiere).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_expire_overdue_profile_proposals()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
DECLARE
  v_proposal record;
  v_count    int := 0;
BEGIN
  RAISE NOTICE '[fn_expire_overdue_profile_proposals] start at %', now();

  FOR v_proposal IN
    SELECT id, library_id, axis, proposed_at, expires_at
    FROM public.library_profile_proposals
    WHERE status = 'open'
      AND expires_at <= now()
    ORDER BY expires_at
    FOR UPDATE SKIP LOCKED  -- skip les propositions deja lockees par un vote en cours
  LOOP
    BEGIN
      UPDATE public.library_profile_proposals
      SET status = 'expired'
      WHERE id = v_proposal.id;

      v_count := v_count + 1;
      RAISE NOTICE '[fn_expire_overdue_profile_proposals] expired proposal % (library=%, axis=%, expires_at=%)',
        v_proposal.id, v_proposal.library_id, v_proposal.axis, v_proposal.expires_at;

    EXCEPTION WHEN OTHERS THEN
      -- Une expiration en erreur ne doit pas bloquer les autres
      RAISE WARNING '[fn_expire_overdue_profile_proposals] FAIL on proposal % : % (%)',
        v_proposal.id, SQLERRM, SQLSTATE;
    END;
  END LOOP;

  RAISE NOTICE '[fn_expire_overdue_profile_proposals] done at %, % propositions expired',
    now(), v_count;

  RETURN v_count;
END;
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_expire_overdue_profile_proposals() FROM PUBLIC, anon, authenticated, service_role;
-- Doctrine securite Supabase (17/05/2026) : ALTER DEFAULT PRIVILEGES grant
-- EXECUTE TO anon/authenticated/service_role par defaut sur toute fonction
-- du schema public. REVOKE FROM PUBLIC seul ne suffit pas pour isoler.
-- Cette fonction est appelee UNIQUEMENT par pg_cron (role postgres).

COMMENT ON FUNCTION public.fn_expire_overdue_profile_proposals() IS
  'B.4 cron : marque expired les propositions open dont expires_at <= now(). Daily 03:00 UTC. Returns count.';

-- ============================================================================
-- 2. Job d'execution post-carence : fn_execute_due_profile_proposals
-- ============================================================================
-- Logique :
--   FOR chaque proposal WHERE status IN ('accepted_unanimous','accepted_majority')
--     AND grace_period_until <= now()
--   LOOP
--     CALL fn_execute_library_profile_change(proposal.id)
--       (RPC B.3 qui fait : INSERT history -> UPDATE library -> UPDATE proposal -> UPDATE grace_lock)
--   END LOOP
--
-- Les erreurs individuelles sont catchées pour ne pas bloquer le batch entier.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_execute_due_profile_proposals()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
DECLARE
  v_proposal      record;
  v_count_success int := 0;
  v_count_fail    int := 0;
  v_result        jsonb;
BEGIN
  RAISE NOTICE '[fn_execute_due_profile_proposals] start at %', now();

  FOR v_proposal IN
    SELECT id, library_id, axis, governance_required, grace_period_until
    FROM public.library_profile_proposals
    WHERE status IN ('accepted_unanimous', 'accepted_majority')
      AND grace_period_until IS NOT NULL
      AND grace_period_until <= now()
    ORDER BY grace_period_until
    FOR UPDATE SKIP LOCKED  -- skip les propositions deja lockees (concurrence vote/execute manuel)
  LOOP
    BEGIN
      -- Appel du RPC B.3 dans sa propre savepoint pour isolation
      -- auth.uid() sera NULL ici (contexte cron postgres) -> fn_execute_*
      -- reconnait cet appel systeme et impute l'execution au proposeur original.
      v_result := public.fn_execute_library_profile_change(v_proposal.id);

      v_count_success := v_count_success + 1;
      RAISE NOTICE '[fn_execute_due_profile_proposals] executed proposal % (library=%, axis=%, gov=%, grace_ended=%)',
        v_proposal.id, v_proposal.library_id, v_proposal.axis,
        v_proposal.governance_required, v_proposal.grace_period_until;

    EXCEPTION WHEN OTHERS THEN
      -- Une execution en erreur ne doit pas bloquer le batch
      v_count_fail := v_count_fail + 1;
      RAISE WARNING '[fn_execute_due_profile_proposals] FAIL on proposal % : % (%)',
        v_proposal.id, SQLERRM, SQLSTATE;
    END;
  END LOOP;

  RAISE NOTICE '[fn_execute_due_profile_proposals] done at %, % success, % failed',
    now(), v_count_success, v_count_fail;

  RETURN v_count_success;
END;
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_execute_due_profile_proposals() FROM PUBLIC, anon, authenticated, service_role;
-- Doctrine securite Supabase (17/05/2026) : meme raison que ci-dessus.
-- Cette fonction est appelee UNIQUEMENT par pg_cron (role postgres).

COMMENT ON FUNCTION public.fn_execute_due_profile_proposals() IS
  'B.4 cron : execute les propositions accepted_* dont grace_period_until <= now(). Toutes les 15 min. Filet de securite de fn_vote (doctrine D3 hybride). Returns count success.';

-- ============================================================================
-- Enregistrement dans pg_cron
-- ============================================================================
-- Verification prealable que l'extension est disponible. Si elle ne l'est pas,
-- on RAISE WARNING (pas EXCEPTION) pour ne pas casser la migration : la cause
-- la plus probable serait un environnement de test sans pg_cron, on accepte
-- que la prod l'ait et le test pas.
--
-- En cas de re-execution de la migration, cron.unschedule() leve une erreur
-- si le job n'existe pas. On utilise DO block + EXCEPTION WHEN OTHERS pour
-- idempotence.
-- ============================================================================

DO $cron_setup$
DECLARE
  v_has_pg_cron boolean;
BEGIN
  -- Verifier que pg_cron est installe
  SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) INTO v_has_pg_cron;

  IF NOT v_has_pg_cron THEN
    RAISE WARNING '[B.4 cron_setup] pg_cron non installe : jobs non enregistres. Les fonctions fn_expire_overdue_profile_proposals et fn_execute_due_profile_proposals sont creees mais ne seront pas appelees automatiquement.';
    RETURN;
  END IF;

  -- ===== Job 1 : expiration (daily 03:00 UTC) =====
  -- Idempotence : unschedule prealable si existe deja
  BEGIN
    PERFORM cron.unschedule('anarbib_expire_profile_proposals');
    RAISE NOTICE '[B.4 cron_setup] anarbib_expire_profile_proposals : unschedule precedent OK';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[B.4 cron_setup] anarbib_expire_profile_proposals : pas de schedule precedent (ok)';
  END;

  PERFORM cron.schedule(
    'anarbib_expire_profile_proposals',
    '0 3 * * *',  -- daily a 03:00 UTC
    $$SELECT public.fn_expire_overdue_profile_proposals();$$
  );
  RAISE NOTICE '[B.4 cron_setup] anarbib_expire_profile_proposals scheduled (daily 03:00 UTC)';

  -- ===== Job 2 : execution post-carence (toutes les 15 min) =====
  BEGIN
    PERFORM cron.unschedule('anarbib_execute_profile_proposals');
    RAISE NOTICE '[B.4 cron_setup] anarbib_execute_profile_proposals : unschedule precedent OK';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[B.4 cron_setup] anarbib_execute_profile_proposals : pas de schedule precedent (ok)';
  END;

  PERFORM cron.schedule(
    'anarbib_execute_profile_proposals',
    '*/15 * * * *',  -- toutes les 15 min
    $$SELECT public.fn_execute_due_profile_proposals();$$
  );
  RAISE NOTICE '[B.4 cron_setup] anarbib_execute_profile_proposals scheduled (every 15 min)';
END
$cron_setup$;

-- ============================================================================
-- DO-block de verification finale
-- ============================================================================

DO $verif$
DECLARE
  v_count          int;
  v_has_pg_cron    boolean;
  v_jobs_registered int;
BEGIN
  RAISE NOTICE '--- Verification finale B.4 ---';

  -- 1. Les 2 fonctions cron existent
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_expire_overdue_profile_proposals',
      'fn_execute_due_profile_proposals'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'B4_VERIF_FAIL : fonctions cron manquantes (%/2)', v_count;
  END IF;
  RAISE NOTICE 'OK : 2 fonctions cron creees';

  -- 2. Les 2 fonctions sont SECURITY DEFINER
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_expire_overdue_profile_proposals',
      'fn_execute_due_profile_proposals'
    )
    AND p.prosecdef = true;
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'B4_VERIF_FAIL : fonctions cron pas toutes SECURITY DEFINER (%/2)', v_count;
  END IF;
  RAISE NOTICE 'OK : 2 fonctions cron sont SECURITY DEFINER';

  -- 3. Les 2 fonctions sont REVOKE EXECUTE FROM PUBLIC (pas accessibles depuis frontend)
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_expire_overdue_profile_proposals',
      'fn_execute_due_profile_proposals'
    )
    AND has_function_privilege('public', p.oid, 'EXECUTE');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'B4_VERIF_FAIL : PUBLIC a encore EXECUTE sur fonctions cron (% expose)', v_count;
  END IF;
  RAISE NOTICE 'OK : 2 fonctions cron isolees de PUBLIC';

  -- 4. Idem pour authenticated (les jobs ne doivent etre callables que par postgres/cron)
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_expire_overdue_profile_proposals',
      'fn_execute_due_profile_proposals'
    )
    AND has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'B4_VERIF_FAIL : authenticated a EXECUTE sur fonctions cron (% expose - fuite)', v_count;
  END IF;
  RAISE NOTICE 'OK : 2 fonctions cron isolees de authenticated';

  -- 5. Verifier que pg_cron est installe et que les jobs sont enregistres
  SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') INTO v_has_pg_cron;

  IF v_has_pg_cron THEN
    -- pg_cron present : on attend 2 jobs enregistres
    SELECT count(*) INTO v_jobs_registered
    FROM cron.job
    WHERE jobname IN ('anarbib_expire_profile_proposals', 'anarbib_execute_profile_proposals');

    IF v_jobs_registered <> 2 THEN
      RAISE EXCEPTION 'B4_VERIF_FAIL : pg_cron installe mais % jobs enregistres au lieu de 2', v_jobs_registered;
    END IF;
    RAISE NOTICE 'OK : 2 jobs enregistres dans pg_cron.job';

    -- Verifier les schedules
    SELECT count(*) INTO v_count
    FROM cron.job
    WHERE jobname = 'anarbib_expire_profile_proposals'
      AND schedule = '0 3 * * *';
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'B4_VERIF_FAIL : schedule expire incorrect (attendu 0 3 * * *)';
    END IF;

    SELECT count(*) INTO v_count
    FROM cron.job
    WHERE jobname = 'anarbib_execute_profile_proposals'
      AND schedule = '*/15 * * * *';
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'B4_VERIF_FAIL : schedule execute incorrect (attendu */15 * * * *)';
    END IF;
    RAISE NOTICE 'OK : schedules conformes (daily 03:00 UTC + every 15 min)';
  ELSE
    RAISE NOTICE 'WARN : pg_cron non installe, jobs non enregistres (acceptable en env de test)';
  END IF;

  -- 6. Test fume : appel direct des fonctions sur tables vides doit retourner 0
  SELECT public.fn_expire_overdue_profile_proposals() INTO v_count;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'B4_VERIF_FAIL : fn_expire sur table vide a retourne % (attendu 0)', v_count;
  END IF;
  RAISE NOTICE 'OK : fn_expire sur table vide retourne 0';

  SELECT public.fn_execute_due_profile_proposals() INTO v_count;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'B4_VERIF_FAIL : fn_execute sur table vide a retourne % (attendu 0)', v_count;
  END IF;
  RAISE NOTICE 'OK : fn_execute sur table vide retourne 0';

  RAISE NOTICE '--- B.4 verifie : 2 fonctions cron + 2 jobs schedules, isolation PUBLIC/authenticated effective ---';
END
$verif$;

COMMIT;

-- ============================================================================
-- Fin du paquet B.4
-- ============================================================================
