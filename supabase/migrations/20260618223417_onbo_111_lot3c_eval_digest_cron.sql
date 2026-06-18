-- =========================================================================
-- #111 — Lot 3c : digest proactif d'évaluation (cron) — ONBO-Q10
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : Onboarding biblioteca (#111) ; CADRAGE_111_… §5.3 ; spec §5/§10
-- Auteur    : AnarBib · Session : Audit 360 — morceaux rouges (ONBO-Q13 + #111)
--
-- POURQUOI
--   Rappeler proactivement à la coordination réseau : (1) les propositions
--   ouvertes (proposta_*) dont des admins actif·ves n'ont pas encore voté ;
--   (2) le backlog de demandes en attente (pendente > 7 j). Calqué sur
--   fn_cron_cooptation_send_reminders (D.7) : un seul event network.% par cas,
--   fan-out résolu côté Edge Function notify-event depuis pending_voters[].
--
-- ⚠️ Le rendu/envoi du digest dépend d'un handler 'network.request_eval_digest'
--   dans l'EF notify-event — à ajouter avec le chantier « localiser les e-mails
--   onboarding » (cf. cadrage §4.3). Le JOB est créé INACTIF : il ne tourne pas
--   tant que la coordination ne l'active pas (cron.alter_job active:=true), donc
--   aucun event n'est émis d'ici là. Doctrine pg_cron : créer inactif, jamais
--   d'UPDATE cron.job (perm denied) — (in)activer via cron.alter_job.
--
-- DOCTRINE : SECURITY DEFINER search_path fixé ; émission via fn_network_notify_event
-- (déjà défensive) ; job créé inactif et défensivement (cron parfois absent de la
-- base de test).
-- =========================================================================

CREATE OR REPLACE FUNCTION "public"."fn_cron_request_eval_digest"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE
  v_req record;
  v_pending jsonb;
  v_proposals int := 0;
  v_pending_reqs int := 0;
  v_now timestamptz := now();
BEGIN
  -- 1) Propositions ouvertes avec des admins actif·ves n'ayant pas voté.
  FOR v_req IN
    SELECT id, proposed_decision FROM public.library_requests
    WHERE request_status IN ('proposta_aprovacao','proposta_recusa')
  LOOP
    SELECT COALESCE(jsonb_agg(na.user_id), '[]'::jsonb) INTO v_pending
    FROM public.network_administrators na
    WHERE na.status = 'active'
      AND NOT EXISTS (
        SELECT 1 FROM public.library_request_votes v
        WHERE v.request_id = v_req.id AND v.voter_admin_id = na.user_id
      );
    IF v_pending = '[]'::jsonb THEN CONTINUE; END IF;
    PERFORM public.fn_network_notify_event(
      'network.request_eval_digest',
      jsonb_build_object(
        'kind', 'open_proposal',
        'request_id', v_req.id,
        'proposed_decision', v_req.proposed_decision,
        'pending_voters', v_pending
      )
    );
    v_proposals := v_proposals + 1;
  END LOOP;

  -- 2) Backlog : demandes en attente d'examen depuis > 7 jours.
  SELECT count(*) INTO v_pending_reqs FROM public.library_requests
   WHERE request_status = 'pendente' AND created_at < v_now - interval '7 days';
  IF v_pending_reqs > 0 THEN
    PERFORM public.fn_network_notify_event(
      'network.request_eval_digest',
      jsonb_build_object('kind', 'pending_backlog', 'pending_count', v_pending_reqs)
    );
  END IF;

  RETURN jsonb_build_object(
    'open_proposals_reminded', v_proposals,
    'pending_backlog', v_pending_reqs,
    'run_at', v_now
  );
END;
$$;
ALTER FUNCTION "public"."fn_cron_request_eval_digest"() OWNER TO "postgres";
COMMENT ON FUNCTION "public"."fn_cron_request_eval_digest"() IS '#111 ONBO-Q10 — digest cron : rappelle les propositions proposta_* non encore votées par tous les admins actifs + le backlog pendente > 7 j. Émet network.request_eval_digest (fan-out EF). Calqué fn_cron_cooptation_send_reminders.';
REVOKE ALL ON FUNCTION "public"."fn_cron_request_eval_digest"() FROM PUBLIC;
REVOKE ALL ON FUNCTION "public"."fn_cron_request_eval_digest"() FROM "anon";
REVOKE ALL ON FUNCTION "public"."fn_cron_request_eval_digest"() FROM "authenticated";
GRANT ALL ON FUNCTION "public"."fn_cron_request_eval_digest"() TO "service_role";

-- Job cron quotidien (08:17 UTC, horaire non rond pour ne pas s'agréger aux autres),
-- créé INACTIF. Défensif : la base de test fraîche peut ne pas avoir le schéma cron.
DO $cron$
DECLARE v_jobid bigint;
BEGIN
  v_jobid := cron.schedule('anarbib-request-eval-digest', '17 8 * * *', 'SELECT public.fn_cron_request_eval_digest();');
  PERFORM cron.alter_job(v_jobid, active := false);
  RAISE NOTICE '#111 L3c : job cron anarbib-request-eval-digest créé (INACTIF).';
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING '#111 L3c : job cron NON créé (cron indisponible ici ?) : %. À créer/vérifier en prod (inactif).', SQLERRM;
END;
$cron$;

-- Smoke (db push) : la fonction existe (le job est vérifié en prod, cf. ci-dessus).
DO $smoke$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_cron_request_eval_digest'
  ) THEN
    RAISE EXCEPTION '#111 L3c SMOKE ECHEC : fonction digest absente';
  END IF;
  RAISE NOTICE '#111 L3c SMOKE OK.';
END;
$smoke$;
