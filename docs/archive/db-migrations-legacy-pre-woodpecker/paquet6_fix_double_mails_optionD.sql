-- ============================================================================
-- paquet6_fix_double_mails_optionD.sql — fix bug #1 (mails en doublon)
-- ============================================================================
-- Date : 2026-05-09
-- Auteur : refactor Option D (consolidation 2 UPDATE → 1 UPDATE)
--
-- DIAGNOSTIC :
--   5 RPC faisaient 2 UPDATE successifs sur reserva_item_workflow_v2 :
--     - api.fn_propose_pickup_slot_as_library
--     - api.fn_propose_pickup_slot_as_reader
--     - api.advance_reservation
--     - api.fn_confirm_pickup_slot_as_library
--     - api.fn_confirm_pickup_slot_as_reader
--
--   Pattern commun :
--     1) Via fn_v2_set_reserva_linhas_workflow (workflow_stage, pickup_*)
--     2) Manuel pour set/clear pickup_proposed_by + clear pickup_reply_*
--
--   Or le trigger trg_notify_reserva_workflow se déclenche sur
--     AFTER INSERT OR UPDATE OF workflow_stage, pickup_reply_status
--   et "UPDATE OF column" tire dès que la colonne est mentionnée dans le SET,
--   même si la valeur ne change pas. Comme le 2e UPDATE manuel mentionne
--   pickup_reply_status (= NULL), le trigger tirait 2 fois pour 1 action
--   utilisateur → 2 invocations notify-event → 2 mails identiques.
--
--   RPC NON CONCERNÉES (vérifiées propres) :
--     - api.mark_no_show : helper seul, pas de 2e UPDATE
--     - api.confirm_pickup_v1 : n'utilise pas le helper (conversion en prêt)
--     - api.confirm_pickup_slot : utilise fn_v2_set_reserva_linhas_pickup_reply
--       (helper séparé, à vérifier indépendamment)
--
-- FIX :
--   1. fn_v2_set_reserva_linhas_workflow accepte 2 nouveaux paramètres
--      optionnels :
--        - p_pickup_proposed_by text : 'biblio' | 'leitor' | '__CLEAR__'
--          (=> NULL) | NULL (=> ne pas toucher)
--        - p_clear_pickup_reply boolean : si true, NULL pour status/note/at
--   2. Les 5 RPC consolident en 1 seul appel au helper.
--   3. Le 2e UPDATE manuel est supprimé partout.
--
-- INVARIANTS PRÉSERVÉS :
--   - fn_increment_negotiation_counter : continue de marcher (1 update au lieu
--     de 2, mais la condition pickup_proposed_by='leitor' AND DISTINCT reste
--     vraie, donc incrément correct).
--   - Bloc 3 du trigger : toujours nécessaire pour la contre-prop lecteur dans
--     le même stage retirada_a_combinar (le seul UPDATE consolidé matchera ce
--     bloc, pas le Bloc 1, et tirera 1 webhook = comportement correct).
--   - Aucune autre RPC n'est cassée : les paramètres ajoutés ont DEFAULT NULL
--     donc les callsites existants continuent de marcher à l'identique.
--
-- IDEMPOTENCE :
--   Toutes les fonctions sont CREATE OR REPLACE. Re-exécutable sans effet
--   secondaire. Pas de DDL destructif.
--
-- ROLLBACK :
--   Voir paquet6_fix_double_mails_optionD_ROLLBACK.sql en cas de pépin.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Refactor du helper : accepte p_pickup_proposed_by + p_clear_pickup_reply
-- ============================================================================
-- NB : nouvelle signature avec 2 paramètres optionnels en queue. Les anciens
-- callsites n'ont pas à changer (DEFAULT NULL / DEFAULT false).
-- Cas spécial : la valeur '__CLEAR__' pour p_pickup_proposed_by signale qu'on
-- veut FORCER NULL (différent de NULL = "ne pas toucher"). Ce mécanisme évite
-- le piège du COALESCE qui ne distingue pas "rien à dire" de "mettre à NULL".

CREATE OR REPLACE FUNCTION public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id bigint,
    p_line_nos integer[],
    p_workflow_stage text,
    p_workflow_note text DEFAULT NULL,
    p_pickup_scheduled_for timestamp with time zone DEFAULT NULL,
    p_pickup_proposed_by text DEFAULT NULL,
    p_clear_pickup_reply boolean DEFAULT false
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_stage text := trim(coalesce(p_workflow_stage, ''));
  v_updated int := 0;
  -- Résolution du sentinel '__CLEAR__' pour pickup_proposed_by
  v_pb_resolved text;
  v_pb_should_set boolean := (p_pickup_proposed_by IS NOT NULL);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  IF v_stage = '' THEN
    RAISE EXCEPTION 'Etapa de workflow obrigatória.';
  END IF;

  -- Validation valeur p_pickup_proposed_by
  IF v_pb_should_set THEN
    IF p_pickup_proposed_by NOT IN ('biblio', 'leitor', '__CLEAR__') THEN
      RAISE EXCEPTION 'p_pickup_proposed_by deve ser ''biblio'', ''leitor'' ou ''__CLEAR__'' (recebido: %).', p_pickup_proposed_by
        USING ERRCODE = '22023';
    END IF;
    v_pb_resolved := CASE WHEN p_pickup_proposed_by = '__CLEAR__' THEN NULL ELSE p_pickup_proposed_by END;
  END IF;

  SELECT r.library_id INTO v_library_id
  FROM public.reservas_v2 r
  WHERE r.id = p_reserva_id;

  IF v_library_id IS NULL THEN
    RAISE EXCEPTION 'Reserva não encontrada.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM api.my_access a
    WHERE a.user_id = v_uid
      AND a.can_access_painel = true
      AND a.library_id = v_library_id
  ) THEN
    RAISE EXCEPTION 'Você não pode gerir esta reserva.';
  END IF;

  -- Bloc 1 : mise à jour des reserva_linhas_v2 (statut, dates de cancellation)
  UPDATE public.reserva_linhas_v2 rl
     SET item_status = CASE
           WHEN v_stage = 'cancelada_biblioteca' THEN 'cancelada_biblioteca'
           WHEN v_stage = 'expirada' THEN 'expirada'
           WHEN v_stage = 'liberada_para_circulacao' THEN 'liberada_para_circulacao'
           ELSE rl.item_status
         END,
         cancelled_at = CASE
           WHEN v_stage = 'cancelada_biblioteca' THEN coalesce(rl.cancelled_at, timezone('utc', now()))
           ELSE rl.cancelled_at
         END,
         expired_at = CASE
           WHEN v_stage = 'expirada' THEN coalesce(rl.expired_at, timezone('utc', now()))
           ELSE rl.expired_at
         END,
         updated_at = timezone('utc', now())
   WHERE rl.reserva_id = p_reserva_id
     AND rl.line_no = ANY(p_line_nos)
     AND rl.item_status = 'ativa';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  -- Bloc 2 : upsert reserva_item_workflow_v2 (UN SEUL UPDATE !)
  -- Toutes les colonnes susceptibles de changer sont passées dans le SET en
  -- une fois, ce qui empêche le déclenchement multiple du trigger AFTER UPDATE.
  --
  -- Convention sur p_pickup_proposed_by :
  --   - NULL  → ne pas toucher (COALESCE classique)
  --   - 'biblio'/'leitor' → set à cette valeur
  --   - '__CLEAR__' → forcer NULL (résolu en v_pb_resolved=NULL ci-dessus,
  --     mais on doit le distinguer du cas "ne pas toucher" via v_pb_should_set)
  INSERT INTO public.reserva_item_workflow_v2 (
    reserva_id,
    line_no,
    workflow_stage,
    workflow_note,
    pickup_scheduled_for,
    pickup_proposed_by,
    pickup_reply_status,
    pickup_reply_note,
    pickup_reply_at,
    updated_at,
    updated_by
  )
  SELECT
    rl.reserva_id,
    rl.line_no,
    v_stage,
    nullif(trim(p_workflow_note), ''),
    p_pickup_scheduled_for,
    -- À l'INSERT : on respecte p_pickup_proposed_by si fourni, NULL sinon
    CASE WHEN v_pb_should_set THEN v_pb_resolved ELSE NULL END,
    -- À l'INSERT : pickup_reply_* toujours NULL (rien encore reçu)
    NULL,
    NULL,
    NULL,
    timezone('utc', now()),
    v_uid
  FROM public.reserva_linhas_v2 rl
  WHERE rl.reserva_id = p_reserva_id
    AND rl.line_no = ANY(p_line_nos)
  ON CONFLICT (reserva_id, line_no)
  DO UPDATE
     SET workflow_stage = excluded.workflow_stage,
         workflow_note = coalesce(excluded.workflow_note, public.reserva_item_workflow_v2.workflow_note),
         pickup_scheduled_for = coalesce(excluded.pickup_scheduled_for, public.reserva_item_workflow_v2.pickup_scheduled_for),
         -- pickup_proposed_by : 3 cas distincts gérés via v_pb_should_set
         pickup_proposed_by = CASE
           WHEN v_pb_should_set THEN v_pb_resolved  -- 'biblio'/'leitor' ou NULL via __CLEAR__
           ELSE public.reserva_item_workflow_v2.pickup_proposed_by  -- ne pas toucher
         END,
         -- pickup_reply_* : nullifiés ssi p_clear_pickup_reply=true
         pickup_reply_status = CASE
           WHEN p_clear_pickup_reply THEN NULL
           ELSE public.reserva_item_workflow_v2.pickup_reply_status
         END,
         pickup_reply_note = CASE
           WHEN p_clear_pickup_reply THEN NULL
           ELSE public.reserva_item_workflow_v2.pickup_reply_note
         END,
         pickup_reply_at = CASE
           WHEN p_clear_pickup_reply THEN NULL
           ELSE public.reserva_item_workflow_v2.pickup_reply_at
         END,
         updated_at = excluded.updated_at,
         updated_by = excluded.updated_by;

  PERFORM public.fn_v2_refresh_reserva_status_global(p_reserva_id);
  PERFORM public.fn_v2_recompute_from_reserva_lines(p_reserva_id, p_line_nos);

  RETURN v_updated;
END;
$function$;

COMMENT ON FUNCTION public.fn_v2_set_reserva_linhas_workflow(
  bigint, integer[], text, text, timestamp with time zone, text, boolean
) IS
'Helper de mise à jour atomique du workflow d''une réservation v2. Refactor paquet6 fix-up 2026-05-09 : 2 nouveaux paramètres optionnels (p_pickup_proposed_by, p_clear_pickup_reply) permettent aux RPC fn_propose_pickup_slot_* et advance_reservation de consolider leur 2e UPDATE manuel. Évite le doublon de webhooks notify-event causé par "UPDATE OF pickup_reply_status" qui tirait sur le SET=NULL même quand la valeur ne changeait pas.';


-- ============================================================================
-- 2. Refactor de api.fn_propose_pickup_slot_as_library
-- ============================================================================
-- Suppression du 2e UPDATE manuel : tout est consolidé dans l'appel au helper.

CREATE OR REPLACE FUNCTION api.fn_propose_pickup_slot_as_library(
    p_reserva_id bigint,
    p_line_no integer,
    p_pickup_at timestamp with time zone,
    p_note text DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_current_stage text;
  v_actor_role text;
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

  IF v_current_stage NOT IN ('solicitada', 'em_preparacao', 'retirada_a_combinar') THEN
    RAISE EXCEPTION 'pickup_proposal_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. Les propositions de créneau sont valides depuis solicitada, em_preparacao ou retirada_a_combinar.',
              v_current_stage
            );
  END IF;

  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_a_combinar', v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → retirada_a_combinar refusée pour rôle %s',
              v_current_stage, v_actor_role
            );
  END IF;

  -- Refactor paquet6 fix-up 2026-05-09 : appel UNIQUE au helper avec
  -- p_pickup_proposed_by='biblio' et p_clear_pickup_reply=true.
  -- Plus de 2e UPDATE manuel → plus de doublon webhook.
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id,
    ARRAY[p_line_no],
    'retirada_a_combinar',
    p_note,
    p_pickup_at,
    'biblio',     -- p_pickup_proposed_by
    true          -- p_clear_pickup_reply
  );

  RETURN v_n;
END;
$function$;


-- ============================================================================
-- 3. Refactor de api.fn_propose_pickup_slot_as_reader
-- ============================================================================
-- Idem : suppression du 2e UPDATE manuel.
-- Note : le trigger BEFORE fn_increment_negotiation_counter continuera de
-- s'incrémenter correctement (1 fois) car la condition NEW.pickup_proposed_by
-- = 'leitor' AND DISTINCT FROM OLD restera vraie sur l'unique UPDATE.

CREATE OR REPLACE FUNCTION api.fn_propose_pickup_slot_as_reader(
    p_reserva_id bigint,
    p_line_no integer,
    p_pickup_at timestamp with time zone,
    p_note text DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
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

  IF v_current_stage <> 'retirada_a_combinar' THEN
    RAISE EXCEPTION 'pickup_counter_proposal_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. La contre-proposition n''est valide que pendant la négociation active (retirada_a_combinar).',
              v_current_stage
            );
  END IF;

  IF v_allow_counter IS NOT NULL AND v_allow_counter = false THEN
    RAISE EXCEPTION 'pickup_counter_proposal_disabled_by_library'
      USING ERRCODE = '42501',
            HINT = 'Cette bibliothèque n''accepte pas les contre-propositions de créneau. Tu peux confirmer le créneau proposé ou annuler ta réservation.';
  END IF;

  IF v_iteration_count >= 3 THEN
    RAISE EXCEPTION 'pickup_negotiation_max_iterations_reached'
      USING ERRCODE = '22023',
            HINT = 'La négociation a atteint sa limite de 3 contre-propositions. Pour finaliser, contacte directement la biblio par téléphone, mail ou de visu.';
  END IF;

  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_a_combinar', 'lecteur') THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → retirada_a_combinar refusée pour lecteur (incohérence helper, à investiguer)',
              v_current_stage
            );
  END IF;

  -- Refactor paquet6 fix-up 2026-05-09 : appel UNIQUE au helper avec
  -- p_pickup_proposed_by='leitor' et p_clear_pickup_reply=true.
  -- Le trigger BEFORE fn_increment_negotiation_counter incrémente
  -- automatiquement le compteur sur ce seul UPDATE (1 fois, pas 2).
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id,
    ARRAY[p_line_no],
    'retirada_a_combinar',
    p_note,
    p_pickup_at,
    'leitor',     -- p_pickup_proposed_by
    true          -- p_clear_pickup_reply
  );

  RETURN v_n;
END;
$function$;


-- ============================================================================
-- 4. Refactor de api.advance_reservation
-- ============================================================================
-- Cette RPC a un comportement plus complexe : elle gère tous les changements
-- de stage, et l'auteur (biblio) ouvre la négo via cette RPC OU via
-- fn_propose_pickup_slot_as_library. Le 2e UPDATE manuel originel set
-- pickup_proposed_by='biblio' pour les transitions vers retirada_a_combinar,
-- ou NULL pour les autres transitions (pour clore la négo).

CREATE OR REPLACE FUNCTION api.advance_reservation(
    p_reserva_id bigint,
    p_line_no integer,
    p_target_stage text,
    p_options jsonb DEFAULT '{}'::jsonb
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_current_stage text;
  v_actor_role text;
  v_note text;
  v_pickup timestamptz;
  v_n integer;
  v_proposed_by_arg text;
  v_clear_reply boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF p_target_stage IN ('retirada_efetivada', 'liberada_para_circulacao', 'expirada') THEN
    RAISE EXCEPTION 'target_stage_has_dedicated_rpc'
      USING ERRCODE = '22023',
            HINT = format(
              'cible %s non autorisée via api.advance_reservation. Utilise api.confirm_pickup_v1 (retirada_efetivada) ; les autres sont automatiques (cron/trigger).',
              p_target_stage
            );
  END IF;

  IF p_target_stage = 'retirada_agendada' THEN
    RAISE EXCEPTION 'target_stage_has_dedicated_rpc'
      USING ERRCODE = '22023',
            HINT = 'cible retirada_agendada non autorisée via advance_reservation. Le seul chemin légitime est la confirmation mutuelle (api.fn_confirm_pickup_slot_as_library ou as_reader) depuis retirada_a_combinar. Utilise api.fn_propose_pickup_slot_as_library pour ouvrir une négociation.';
  END IF;

  IF p_target_stage = 're-retirada_agendada' THEN
    RAISE EXCEPTION 'target_stage_deprecated'
      USING ERRCODE = '22023',
            HINT = 'cible re-retirada_agendada dépréciée par le refactor v3. Utilise retirada_a_combinar pour la négociation symétrique.';
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

  IF NOT public.fn_check_workflow_transition(v_current_stage, p_target_stage, v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → %s refusée pour rôle %s',
              v_current_stage, p_target_stage, v_actor_role
            );
  END IF;

  v_note := p_options->>'note';
  v_pickup := CASE
    WHEN p_options ? 'pickup_scheduled_for'
      THEN (p_options->>'pickup_scheduled_for')::timestamptz
    ELSE NULL
  END;

  IF p_target_stage IN ('retirada_a_combinar') AND v_pickup IS NULL THEN
    RAISE EXCEPTION 'pickup_scheduled_for_required'
      USING ERRCODE = '22023',
            HINT = format(
              'cible %s requiert p_options->>''pickup_scheduled_for'' (timestamptz). Même approximatif, indique un créneau initial pour ouvrir la négociation.',
              p_target_stage
            );
  END IF;

  -- Refactor paquet6 fix-up 2026-05-09 : déterminer les valeurs des nouveaux
  -- paramètres du helper selon le stage cible.
  IF p_target_stage = 'retirada_a_combinar' THEN
    -- Ouverture (ou relance) de la négociation par la biblio
    v_proposed_by_arg := 'biblio';
    v_clear_reply := true;
  ELSE
    -- Toute autre cible : la négociation est close → forcer NULL
    v_proposed_by_arg := '__CLEAR__';
    v_clear_reply := true;
  END IF;

  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id,
    ARRAY[p_line_no],
    p_target_stage,
    v_note,
    v_pickup,
    v_proposed_by_arg,
    v_clear_reply
  );

  RETURN v_n;
END;
$function$;


-- ============================================================================
-- 5. Refactor de api.fn_confirm_pickup_slot_as_library
-- ============================================================================
-- Cas : la biblio confirme une contre-proposition lecteur. Transition
--   retirada_a_combinar → retirada_agendada
-- Le 2e UPDATE manuel originel set pickup_proposed_by=NULL (clôture négo)
-- et clear pickup_reply_*. On consolide via le helper.

CREATE OR REPLACE FUNCTION api.fn_confirm_pickup_slot_as_library(
    p_reserva_id bigint,
    p_line_no integer
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_current_stage text;
  v_proposed_by text;
  v_pickup_at timestamptz;
  v_actor_role text;
  v_audit_note text;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT
    r.library_id,
    riw.workflow_stage,
    riw.pickup_proposed_by,
    riw.pickup_scheduled_for
  INTO
    v_library_id,
    v_current_stage,
    v_proposed_by,
    v_pickup_at
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

  IF v_current_stage <> 'retirada_a_combinar' THEN
    RAISE EXCEPTION 'pickup_confirmation_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. La confirmation n''est valide que depuis retirada_a_combinar (négociation active).',
              v_current_stage
            );
  END IF;

  IF v_proposed_by IS NULL THEN
    RAISE EXCEPTION 'pickup_no_active_proposal'
      USING ERRCODE = '22023',
            HINT = 'aucune proposition active à confirmer (pickup_proposed_by IS NULL).';
  END IF;

  IF v_proposed_by <> 'leitor' THEN
    RAISE EXCEPTION 'pickup_confirmation_wrong_proposer'
      USING ERRCODE = '22023',
            HINT = format(
              'pickup_proposed_by = %s. La biblio ne peut confirmer que les contre-propositions du lecteur·rice (pickup_proposed_by = ''leitor''). Si tu veux re-proposer un autre créneau, utilise fn_propose_pickup_slot_as_library.',
              v_proposed_by
            );
  END IF;

  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_agendada', v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → retirada_agendada refusée pour rôle %s (incohérence helper, à investiguer)',
              v_current_stage, v_actor_role
            );
  END IF;

  v_audit_note := format(
    '[autoconf-by-library] %s — créneau verrouillé (retirada_agendada) après contre-proposition lecteur·rice (créneau: %s)',
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    COALESCE(to_char(v_pickup_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), 'NULL')
  );

  -- Refactor paquet6 fix-up 2026-05-09 : appel UNIQUE au helper avec
  -- p_pickup_proposed_by='__CLEAR__' (clôture négo) et p_clear_pickup_reply=true.
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id,
    ARRAY[p_line_no],
    'retirada_agendada',
    v_audit_note,
    v_pickup_at,
    '__CLEAR__',  -- p_pickup_proposed_by → NULL
    true          -- p_clear_pickup_reply
  );

  RETURN v_n;
END;
$function$;


-- ============================================================================
-- 6. Refactor de api.fn_confirm_pickup_slot_as_reader
-- ============================================================================
-- Cas : le lecteur accepte une proposition biblio. Transition
--   retirada_a_combinar → retirada_agendada
-- Idem : consolidation en un seul UPDATE.

CREATE OR REPLACE FUNCTION api.fn_confirm_pickup_slot_as_reader(
    p_reserva_id bigint,
    p_line_no integer
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_current_stage text;
  v_proposed_by text;
  v_pickup_at timestamptz;
  v_audit_note text;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT
    r.user_id,
    riw.workflow_stage,
    riw.pickup_proposed_by,
    riw.pickup_scheduled_for
  INTO
    v_owner,
    v_current_stage,
    v_proposed_by,
    v_pickup_at
  FROM public.reservas_v2 r
  JOIN public.reserva_item_workflow_v2 riw ON riw.reserva_id = r.id
  WHERE r.id = p_reserva_id AND riw.line_no = p_line_no;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'reserva_line_not_found' USING ERRCODE = '02000';
  END IF;

  IF v_owner <> v_uid THEN
    RAISE EXCEPTION 'not_your_reserva' USING ERRCODE = '42501';
  END IF;

  IF v_current_stage <> 'retirada_a_combinar' THEN
    RAISE EXCEPTION 'pickup_confirmation_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. La confirmation n''est valide que depuis retirada_a_combinar (négociation active).',
              v_current_stage
            );
  END IF;

  IF v_proposed_by IS NULL THEN
    RAISE EXCEPTION 'pickup_no_active_proposal'
      USING ERRCODE = '22023',
            HINT = 'aucune proposition active à confirmer (pickup_proposed_by IS NULL).';
  END IF;

  IF v_proposed_by <> 'biblio' THEN
    RAISE EXCEPTION 'pickup_confirmation_wrong_proposer'
      USING ERRCODE = '22023',
            HINT = format(
              'pickup_proposed_by = %s. Tu ne peux confirmer que les créneaux proposés par la biblio (pickup_proposed_by = ''biblio''). Si tu veux contre-proposer un autre créneau, utilise fn_propose_pickup_slot_as_reader.',
              v_proposed_by
            );
  END IF;

  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_agendada', 'lecteur') THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → retirada_agendada refusée pour lecteur (incohérence helper, à investiguer)',
              v_current_stage
            );
  END IF;

  v_audit_note := format(
    '[autoconf-by-reader] %s — créneau verrouillé (retirada_agendada) après proposition biblio (créneau: %s)',
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    COALESCE(to_char(v_pickup_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), 'NULL')
  );

  -- Refactor paquet6 fix-up 2026-05-09 : appel UNIQUE au helper avec
  -- p_pickup_proposed_by='__CLEAR__' (clôture négo) et p_clear_pickup_reply=true.
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id,
    ARRAY[p_line_no],
    'retirada_agendada',
    v_audit_note,
    v_pickup_at,
    '__CLEAR__',  -- p_pickup_proposed_by → NULL
    true          -- p_clear_pickup_reply
  );

  RETURN v_n;
END;
$function$;


COMMIT;

-- ============================================================================
-- Tests d'invariants après application
-- ============================================================================
-- À lancer manuellement pour vérifier que le refactor n'a rien cassé :
--
-- (a) Vérifier que les 4 fonctions ont bien la nouvelle signature/version :
--     SELECT proname, pg_get_function_arguments(oid)
--     FROM pg_proc
--     WHERE proname IN (
--       'fn_v2_set_reserva_linhas_workflow',
--       'fn_propose_pickup_slot_as_library',
--       'fn_propose_pickup_slot_as_reader',
--       'advance_reservation'
--     )
--     ORDER BY proname;
--
-- (b) Tester à chaud sur une résa de test (cf. mémoire : résa #10) :
--     - Compter les invocations notify-event AVANT et APRÈS
--     - Faire UNE action de négociation (staff propose, ou lecteur contre-prop)
--     - Vérifier qu'on a +1 invocation, pas +2
--
-- (c) Vérifier que le compteur d'itérations s'incrémente toujours
--     correctement (pas régressé) :
--     - État initial : iter = 0
--     - Action staff propose → iter reste 0 (le trigger ne s'incrémente que
--       quand pickup_proposed_by='leitor')
--     - Action lecteur contre-propose → iter = 1
--     - Action staff répond → iter reste 1
--     - Action lecteur contre-propose → iter = 2
