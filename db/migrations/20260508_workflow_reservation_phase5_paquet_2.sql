-- =============================================================================
-- Migration : Workflow réservation v2 — Phase 5 paquet 2
--             (RPC négociation symétrique + trigger compteur + cron timeout)
-- Date      : 2026-05-08
-- Spec      : docs/spec-workflow-reservation-v2-negotiation.md
-- Paquet    : 2/6 (RPC + trigger + cron)
-- Préreq    : 20260508_workflow_reservation_phase5_negotiation.sql appliquée
-- =============================================================================
-- Wrappers api.* SECURITY INVOKER + 1 trigger + 1 cron pour la négociation
-- symétrique du créneau de retrait :
--
--   - api.fn_propose_pickup_slot_as_library : la biblio propose/repropose
--     un créneau (pickup_proposed_by = 'biblio', en attente du lecteur)
--   - api.fn_propose_pickup_slot_as_reader  : le lecteur·rice contre-propose
--     un créneau (pickup_proposed_by = 'leitor', en attente de la biblio)
--   - trg_increment_negotiation_counter : auto-incrément quand un lecteur
--     contre-propose (semantique B validée CCLA : 3 contre-propositions max)
--   - fn_expire_negotiation_timeout + cron : expire les négociations qui
--     dépassent reservation_negotiation_timeout_days (default 21j)
--
-- Pattern commun des RPC (cohérent avec phase2_paquet_a/b) :
--   1. Auth : auth.uid() requis
--   2. Contexte : reservas_v2 + reserva_item_workflow_v2 + library_notification_policies
--   3. Validation : rôle / propriété + helper matrice + paramètres + flags biblio
--   4. Délégation : fn_v2_set_reserva_linhas_workflow + UPDATE complémentaire
--                   pour pickup_proposed_by (le compteur est géré par trigger)
--
-- Décisions de design (validées CCLA 2026-05-08) :
--   - Compteur incrémenté UNIQUEMENT lors d'une contre-proposition lecteur
--     (semantique B : 3 cycles complets = 3 contre-propositions du lecteur)
--   - Le compteur est incrémenté par trigger pour éviter la double-comptabilité
--     (le wrapper RPC ne le touche pas directement)
--   - Si le flag library_notification_policies.reservation_allow_reader_counter_proposal
--     est false, fn_propose_pickup_slot_as_reader rejette avec un code clair
--   - Le timeout global de 21j (configurable 7-60j) expire toutes les
--     réservations en stages intermédiaires non aboutis
--
-- Codes d'erreur ajoutés :
--   - pickup_counter_proposal_disabled_by_library
--   - pickup_negotiation_max_iterations_reached
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. api.fn_propose_pickup_slot_as_library(p_reserva_id, p_line_no, p_pickup_at, p_note)
-- =============================================================================
-- Permet à la biblio (librarian/coordenador) de proposer (ou re-proposer)
-- un créneau de retrait précis. La proposition met le stage en
-- retirada_agendada (première proposition) ou re-retirada_agendada (proposition
-- ultérieure), avec pickup_proposed_by = 'biblio'.
--
-- Le compteur d'itérations n'est PAS incrémenté ici (semantique B).
-- =============================================================================

CREATE OR REPLACE FUNCTION api.fn_propose_pickup_slot_as_library(
  p_reserva_id bigint,
  p_line_no integer,
  p_pickup_at timestamptz,
  p_note text DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_current_stage text;
  v_actor_role text;
  v_target_stage text;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF p_pickup_at IS NULL THEN
    RAISE EXCEPTION 'pickup_scheduled_for_required'
      USING ERRCODE = '22023',
            HINT = 'p_pickup_at (timestamptz) est obligatoire pour une proposition de créneau';
  END IF;

  IF p_pickup_at < now() THEN
    RAISE EXCEPTION 'pickup_scheduled_for_in_past'
      USING ERRCODE = '22023',
            HINT = 'le créneau proposé doit être dans le futur';
  END IF;

  SELECT r.library_id, riw.workflow_stage
    INTO v_library_id, v_current_stage
  FROM public.reservas_v2 r
  JOIN public.reserva_item_workflow_v2 riw ON riw.reserva_id = r.id
  WHERE r.id = p_reserva_id AND riw.line_no = p_line_no;

  IF v_library_id IS NULL THEN
    RAISE EXCEPTION 'reserva_line_not_found' USING ERRCODE = '02000';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_library_id);
  IF v_actor_role IS NULL THEN
    RAISE EXCEPTION 'not_staff_of_this_library' USING ERRCODE = '42501';
  END IF;

  -- Détermination du stage cible :
  -- - Première proposition (depuis solicitada/em_preparacao/retirada_a_combinar)
  --   → retirada_agendada
  -- - Re-proposition (depuis retirada_agendada/re-retirada_agendada)
  --   → re-retirada_agendada
  v_target_stage := CASE
    WHEN v_current_stage IN ('solicitada', 'em_preparacao', 'retirada_a_combinar')
      THEN 'retirada_agendada'
    WHEN v_current_stage IN ('retirada_agendada', 're-retirada_agendada')
      THEN 're-retirada_agendada'
    ELSE NULL
  END;

  IF v_target_stage IS NULL THEN
    RAISE EXCEPTION 'pickup_proposal_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. Les propositions de créneau sont valides depuis solicitada/em_preparacao/retirada_a_combinar/retirada_agendada/re-retirada_agendada.',
              v_current_stage
            );
  END IF;

  -- Sanity check via la matrice (défense en profondeur)
  IF NOT public.fn_check_workflow_transition(v_current_stage, v_target_stage, v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → %s refusée pour rôle %s',
              v_current_stage, v_target_stage, v_actor_role
            );
  END IF;

  -- Délégation au helper standard pour le stage + pickup_scheduled_for + note
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], v_target_stage, p_note, p_pickup_at
  );

  -- MAJ pickup_proposed_by = 'biblio' (le trigger ne touche pas au compteur ici)
  UPDATE public.reserva_item_workflow_v2
  SET pickup_proposed_by = 'biblio',
      pickup_reply_status = NULL,  -- reset de toute réponse précédente
      pickup_reply_note = NULL,
      pickup_reply_at = NULL
  WHERE reserva_id = p_reserva_id AND line_no = p_line_no;

  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.fn_propose_pickup_slot_as_library(bigint, integer, timestamptz, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.fn_propose_pickup_slot_as_library(bigint, integer, timestamptz, text) FROM anon;
GRANT EXECUTE ON FUNCTION api.fn_propose_pickup_slot_as_library(bigint, integer, timestamptz, text) TO authenticated;

COMMENT ON FUNCTION api.fn_propose_pickup_slot_as_library(bigint, integer, timestamptz, text) IS
  'Propose ou re-propose un créneau de retrait au lecteur·rice. Réservé au staff (librarian/coordenador) de la biblio. Met pickup_proposed_by = ''biblio'' et reset des éventuelles réponses précédentes. Le compteur d''itérations n''est PAS incrémenté ici (semantique B : seules les contre-propositions lecteur comptent). Spec v2 négociation symétrique.';

-- =============================================================================
-- 2. api.fn_propose_pickup_slot_as_reader(p_reserva_id, p_line_no, p_pickup_at, p_note)
-- =============================================================================
-- Permet au lecteur·rice de contre-proposer un créneau de retrait quand la
-- biblio en a déjà proposé un. Met pickup_proposed_by = 'leitor' et passe le
-- stage en re-retirada_agendada. Le compteur est incrémenté par trigger.
--
-- Vérifications spécifiques :
--   - reservation_allow_reader_counter_proposal = true (sinon refus)
--   - negotiation_iteration_count < 3 (sinon refus)
-- =============================================================================

CREATE OR REPLACE FUNCTION api.fn_propose_pickup_slot_as_reader(
  p_reserva_id bigint,
  p_line_no integer,
  p_pickup_at timestamptz,
  p_note text DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_library_id uuid;
  v_current_stage text;
  v_iteration_count int;
  v_allow_counter boolean;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF p_pickup_at IS NULL THEN
    RAISE EXCEPTION 'pickup_scheduled_for_required'
      USING ERRCODE = '22023',
            HINT = 'p_pickup_at (timestamptz) est obligatoire pour une contre-proposition';
  END IF;

  IF p_pickup_at < now() THEN
    RAISE EXCEPTION 'pickup_scheduled_for_in_past'
      USING ERRCODE = '22023',
            HINT = 'le créneau proposé doit être dans le futur';
  END IF;

  -- Lecture du contexte complet en une seule requête
  SELECT
    r.user_id,
    r.library_id,
    riw.workflow_stage,
    riw.negotiation_iteration_count,
    lnp.reservation_allow_reader_counter_proposal
  INTO
    v_owner,
    v_library_id,
    v_current_stage,
    v_iteration_count,
    v_allow_counter
  FROM public.reservas_v2 r
  JOIN public.reserva_item_workflow_v2 riw ON riw.reserva_id = r.id
  LEFT JOIN public.library_notification_policies lnp ON lnp.library_id = r.library_id
  WHERE r.id = p_reserva_id AND riw.line_no = p_line_no;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'reserva_line_not_found' USING ERRCODE = '02000';
  END IF;

  IF v_owner <> v_uid THEN
    RAISE EXCEPTION 'not_your_reserva' USING ERRCODE = '42501';
  END IF;

  -- Stage doit autoriser la contre-proposition (= biblio a proposé un créneau)
  IF v_current_stage NOT IN ('retirada_agendada', 're-retirada_agendada') THEN
    RAISE EXCEPTION 'pickup_counter_proposal_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. La contre-proposition n''est valide que si la biblio a proposé un créneau (retirada_agendada ou re-retirada_agendada).',
              v_current_stage
            );
  END IF;

  -- Vérification du flag biblio : autorise-t-elle les contre-propositions ?
  -- Fail-safe : si pas de policy explicite, on prend le default (true)
  IF v_allow_counter IS NOT NULL AND v_allow_counter = false THEN
    RAISE EXCEPTION 'pickup_counter_proposal_disabled_by_library'
      USING ERRCODE = '42501',
            HINT = 'Cette bibliothèque n''accepte pas les contre-propositions de créneau. Tu peux confirmer le créneau proposé, le refuser, ou annuler ta réservation.';
  END IF;

  -- Vérification du compteur d'itérations (max 3 selon semantique B)
  IF v_iteration_count >= 3 THEN
    RAISE EXCEPTION 'pickup_negotiation_max_iterations_reached'
      USING ERRCODE = '22023',
            HINT = 'La négociation a atteint sa limite de 3 contre-propositions. Pour finaliser, contacte directement la biblio par téléphone, mail ou de visu.';
  END IF;

  -- Sanity check via la matrice (défense en profondeur)
  IF NOT public.fn_check_workflow_transition(v_current_stage, 're-retirada_agendada', 'lecteur') THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → re-retirada_agendada refusée pour lecteur (incohérence helper, à investiguer)',
              v_current_stage
            );
  END IF;

  -- Délégation au helper standard pour le stage + pickup_scheduled_for + note
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 're-retirada_agendada', p_note, p_pickup_at
  );

  -- MAJ pickup_proposed_by = 'leitor' (le trigger incrémentera le compteur)
  UPDATE public.reserva_item_workflow_v2
  SET pickup_proposed_by = 'leitor',
      pickup_reply_status = NULL,  -- reset des réponses précédentes
      pickup_reply_note = NULL,
      pickup_reply_at = NULL
  WHERE reserva_id = p_reserva_id AND line_no = p_line_no;

  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.fn_propose_pickup_slot_as_reader(bigint, integer, timestamptz, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.fn_propose_pickup_slot_as_reader(bigint, integer, timestamptz, text) FROM anon;
GRANT EXECUTE ON FUNCTION api.fn_propose_pickup_slot_as_reader(bigint, integer, timestamptz, text) TO authenticated;

COMMENT ON FUNCTION api.fn_propose_pickup_slot_as_reader(bigint, integer, timestamptz, text) IS
  'Permet au lecteur·rice de contre-proposer un créneau de retrait. Réservé au lecteur·rice propriétaire. Échoue si la biblio a désactivé reservation_allow_reader_counter_proposal, ou si le compteur d''itérations a atteint 3 (semantique B validée CCLA). Met pickup_proposed_by = ''leitor''. Le trigger trg_increment_negotiation_counter incrémente le compteur. Spec v2 négociation symétrique.';

-- =============================================================================
-- 3. Trigger trg_increment_negotiation_counter
-- =============================================================================
-- Incrémente automatiquement negotiation_iteration_count chaque fois que
-- pickup_proposed_by passe à 'leitor' (= contre-proposition du lecteur).
-- Semantique B : on compte uniquement les contre-propositions du lecteur,
-- pas les propositions initiales/relances de la biblio.
--
-- Garde-fou : empêche aussi le compteur de dépasser 3 même si l'application
-- court-circuite la RPC (défense en profondeur).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_increment_negotiation_counter()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Détection : passage à pickup_proposed_by = 'leitor'
  -- (NULL → leitor, biblio → leitor, ou même leitor → leitor en cas de re-proposition)
  IF NEW.pickup_proposed_by = 'leitor'
     AND (OLD.pickup_proposed_by IS DISTINCT FROM NEW.pickup_proposed_by
          OR OLD.pickup_scheduled_for IS DISTINCT FROM NEW.pickup_scheduled_for) THEN

    -- Garde-fou : ne pas dépasser 3 (la contrainte CHECK rejetterait sinon)
    IF NEW.negotiation_iteration_count >= 3 THEN
      RAISE EXCEPTION 'pickup_negotiation_max_iterations_reached'
        USING ERRCODE = '22023',
              HINT = 'Garde-fou trigger : compteur d''itérations déjà à 3, contre-proposition refusée. Cette erreur ne devrait pas remonter en pratique car la RPC fn_propose_pickup_slot_as_reader vérifie aussi.';
    END IF;

    NEW.negotiation_iteration_count := COALESCE(OLD.negotiation_iteration_count, 0) + 1;
  END IF;

  RETURN NEW;
END;
$$;

-- Drop si existe (idempotence)
DROP TRIGGER IF EXISTS trg_increment_negotiation_counter ON public.reserva_item_workflow_v2;

CREATE TRIGGER trg_increment_negotiation_counter
  BEFORE UPDATE ON public.reserva_item_workflow_v2
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_increment_negotiation_counter();

COMMENT ON FUNCTION public.fn_increment_negotiation_counter() IS
  'Trigger BEFORE UPDATE qui incrémente negotiation_iteration_count quand pickup_proposed_by passe à ''leitor'' (= contre-proposition du lecteur). Semantique B (validée CCLA) : seules les contre-propositions lecteur comptent, pas les propositions/relances biblio. Garde-fou : RAISE si dépassement de 3. Spec v2 § 4.';

-- =============================================================================
-- 4. fn_expire_negotiation_timeout (cron)
-- =============================================================================
-- Bascule en 'expirada' les réservations en stages intermédiaires
-- (em_preparacao, retirada_agendada, retirada_a_combinar, re-retirada_agendada)
-- dont l'âge depuis reservas_v2.created_at dépasse
-- library_notification_policies.reservation_negotiation_timeout_days (default 21j).
--
-- Note : solicitada est déjà géré par fn_expire_solicitada_reservations
-- (timeout court, default 14j). Ce nouveau cron gère le timeout long de la
-- négociation (default 21j).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_expire_negotiation_timeout()
RETURNS TABLE(
  processed_count integer,
  error_count integer,
  details jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
  v_processed integer := 0;
  v_errors integer := 0;
  v_errors_details jsonb := '[]'::jsonb;
BEGIN
  FOR v_row IN
    SELECT
      riw.id,
      riw.reserva_id,
      riw.line_no,
      riw.workflow_stage,
      r.created_at AS reserva_created_at,
      r.library_id,
      lnp.reservation_negotiation_timeout_days AS timeout_days,
      now() - r.created_at AS age
    FROM public.reserva_item_workflow_v2 riw
    JOIN public.reservas_v2 r ON r.id = riw.reserva_id
    JOIN public.library_notification_policies lnp ON lnp.library_id = r.library_id
    WHERE riw.workflow_stage IN (
            'em_preparacao',
            'retirada_agendada',
            'retirada_a_combinar',
            're-retirada_agendada'
          )
      AND r.created_at < now() - make_interval(days => lnp.reservation_negotiation_timeout_days)
  LOOP
    BEGIN
      IF NOT public.fn_check_workflow_transition(v_row.workflow_stage, 'expirada', 'system') THEN
        RAISE EXCEPTION 'helper_refused_transition';
      END IF;

      UPDATE public.reserva_item_workflow_v2
      SET workflow_stage = 'expirada',
          workflow_note = format(
            'Négociation expirée automatiquement par cron (timeout: %s jours, âge: %s, stage précédent: %s)',
            v_row.timeout_days, v_row.age::text, v_row.workflow_stage
          ),
          updated_at = now()
      WHERE id = v_row.id;

      v_processed := v_processed + 1;
    EXCEPTION
      WHEN OTHERS THEN
        v_errors := v_errors + 1;
        v_errors_details := v_errors_details || jsonb_build_object(
          'reserva_id', v_row.reserva_id,
          'line_no', v_row.line_no,
          'workflow_stage', v_row.workflow_stage,
          'sqlstate', SQLSTATE,
          'message', SQLERRM
        );
    END;
  END LOOP;

  processed_count := v_processed;
  error_count := v_errors;
  details := jsonb_build_object(
    'run_at', now(),
    'errors', v_errors_details
  );
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_expire_negotiation_timeout() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_expire_negotiation_timeout() FROM anon;
REVOKE ALL ON FUNCTION public.fn_expire_negotiation_timeout() FROM authenticated;

COMMENT ON FUNCTION public.fn_expire_negotiation_timeout() IS
  'Job cron : expire les réservations en stages intermédiaires (em_preparacao, retirada_agendada, retirada_a_combinar, re-retirada_agendada) dont l''âge depuis reservas_v2.created_at dépasse library_notification_policies.reservation_negotiation_timeout_days (default 21j). Complète fn_expire_solicitada_reservations (timeout court 14j). Tourne en SECURITY DEFINER avec sanity check. Try/catch par ligne pour résilience. Spec v2 § 3.1.';

-- =============================================================================
-- 5. Déclaration du cron job (1h de granularité, démarrage à xh:25 pour éviter
--    de tomber exactement en même temps que les 2 autres crons à xh:05/xh:15)
-- =============================================================================

-- Suppression idempotente (le job peut déjà exister si on rejoue la migration)
DO $$
BEGIN
  PERFORM cron.unschedule('anarbib-reservation-expire-negotiation');
EXCEPTION
  WHEN OTHERS THEN NULL;  -- ignore si le job n'existait pas
END $$;

SELECT cron.schedule(
  'anarbib-reservation-expire-negotiation',
  '25 * * * *',
  $cron$ SELECT public.fn_expire_negotiation_timeout(); $cron$
);

COMMIT;

-- =============================================================================
-- Validation post-migration
-- =============================================================================
-- Lancer ces requêtes APRÈS la migration pour vérifier qu'elle s'est bien
-- appliquée. Toutes doivent retourner les valeurs attendues.
--
-- Q1. Vérifier que les 2 nouvelles RPC existent dans le schéma api
-- SELECT routine_name, routine_type, security_type
--   FROM information_schema.routines
--   WHERE routine_schema = 'api'
--     AND routine_name IN ('fn_propose_pickup_slot_as_library', 'fn_propose_pickup_slot_as_reader')
--   ORDER BY routine_name;
-- Attendu : 2 lignes, security_type = 'INVOKER'
--
-- Q2. Vérifier que la fonction trigger existe dans public
-- SELECT routine_name, routine_type
--   FROM information_schema.routines
--   WHERE routine_schema = 'public'
--     AND routine_name = 'fn_increment_negotiation_counter';
-- Attendu : 1 ligne
--
-- Q3. Vérifier que le trigger est bien attaché à la table
-- SELECT trigger_name, event_manipulation, action_timing
--   FROM information_schema.triggers
--   WHERE event_object_table = 'reserva_item_workflow_v2'
--     AND trigger_name = 'trg_increment_negotiation_counter';
-- Attendu : 1 ligne, event_manipulation = 'UPDATE', action_timing = 'BEFORE'
--
-- Q4. Vérifier que la fonction du cron existe
-- SELECT routine_name, security_type
--   FROM information_schema.routines
--   WHERE routine_schema = 'public'
--     AND routine_name = 'fn_expire_negotiation_timeout';
-- Attendu : 1 ligne, security_type = 'DEFINER'
--
-- Q5. Vérifier que le cron job est bien programmé
-- SELECT jobname, schedule, active
--   FROM cron.job
--   WHERE jobname = 'anarbib-reservation-expire-negotiation';
-- Attendu : 1 ligne, schedule = '25 * * * *', active = true
--
-- Q6. Vérifier les permissions sur les RPC
-- SELECT routine_name, grantee, privilege_type
--   FROM information_schema.routine_privileges
--   WHERE routine_schema = 'api'
--     AND routine_name IN ('fn_propose_pickup_slot_as_library', 'fn_propose_pickup_slot_as_reader')
--     AND grantee IN ('authenticated', 'anon', 'PUBLIC')
--   ORDER BY routine_name, grantee;
-- Attendu : 2 lignes (authenticated, EXECUTE) — pas de anon ni PUBLIC
--
-- Q7. Test du trigger (sans persister) — créer une transaction temporaire
-- BEGIN;
--   -- Crée une résa de test avec une ligne en retirada_agendada
--   -- (à adapter selon tes données existantes)
--   -- Puis simule un UPDATE qui passe pickup_proposed_by à 'leitor'
--   -- Le trigger doit incrémenter le compteur
--   -- (à exécuter manuellement avec des IDs réels)
-- ROLLBACK;
--
-- Q8. Vérifier que la fn_expire_negotiation_timeout tourne sans erreur (dry run)
-- SELECT * FROM public.fn_expire_negotiation_timeout();
-- Attendu : (0, 0, jsonb) si aucune résa n'est en timeout, ou les chiffres réels
-- =============================================================================
