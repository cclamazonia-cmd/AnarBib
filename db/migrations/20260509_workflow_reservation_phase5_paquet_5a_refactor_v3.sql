-- =============================================================================
-- Migration : Workflow réservation v3 — Phase 5 paquet 5a (DB only)
--             Refactor sémantique : retirada_a_combinar = négo active,
--             retirada_agendada = aboutissement verrouillé
-- Date      : 2026-05-09
-- Spec      : docs/spec-refactor-v3-semantique.md
-- Préreq    : tous les paquets précédents (1, 2, 2 bis, 2 ter, 3A, 3B, 4, 4A)
-- =============================================================================
-- Le paquet 5b (UI : PanelPage, AccountPage, NegotiationStateBadge, i18n) est
-- séparé pour pouvoir tester le DB de manière isolée. L'UI actuelle continuera
-- de fonctionner après ce paquet 5a parce que les noms de stages restent
-- identiques — seules les mécaniques de négociation changent.
--
-- 6 modifications :
--   1. fn_check_workflow_transition : nouvelle matrice (cf. spec)
--   2. api.fn_propose_pickup_slot_as_library : cible toujours retirada_a_combinar
--   3. api.fn_propose_pickup_slot_as_reader : source = retirada_a_combinar
--   4. api.fn_confirm_pickup_slot_as_library : source = retirada_a_combinar,
--      cible = retirada_agendada
--   5. api.fn_confirm_pickup_slot_as_reader : idem
--   6. api.advance_reservation : interdire cibles retirada_agendada et
--      re-retirada_agendada depuis solicitada/em_preparacao
--   7. fn_expire_negotiation_timeout (cron) : retirer retirada_agendada
--      et re-retirada_agendada de la liste
--
-- Décisions politiques (validées 2026-05-08) :
--   Q1 : Pas de chemin direct vers retirada_agendada — seule voie = confirmation
--   Q2 : Cron retirada_agendada retiré (créneau verrouillé = pas de timeout)
--   Q3 : re-retirada_agendada déprécié (matrice false partout)
--
-- Sécurité du déploiement :
--   - Aucune résa active en retirada_agendada ou re-retirada_agendada en prod
--     au moment du refactor (vérifié 2026-05-08).
--   - Si à l'avenir une résa se retrouve en re-retirada_agendada, elle sera
--     bloquée par la matrice — à traiter manuellement.
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. Refonte de fn_check_workflow_transition (matrice v3)
-- =============================================================================
-- Nouvelle matrice :
--   - retirada_a_combinar devient stage central de négociation
--   - retirada_agendada devient stage d'aboutissement (atteint uniquement
--     depuis retirada_a_combinar via les fn_confirm_*)
--   - re-retirada_agendada déprécié : aucune transition entrante ni sortante
--   - solicitada/em_preparacao ne peuvent plus aller direct à retirada_agendada
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_check_workflow_transition(
  p_from text, p_to text, p_actor_role text
) RETURNS boolean
LANGUAGE sql
IMMUTABLE PARALLEL SAFE
SET search_path TO 'public'
AS $function$
WITH normalized AS (
  SELECT
    CASE WHEN p_from = 'nao_retirada' THEN 'retirada_no_show'
         ELSE p_from END AS f,
    CASE WHEN p_to = 'nao_retirada' THEN 'retirada_no_show'
         ELSE p_to END AS t,
    p_actor_role AS r
)
SELECT CASE
  -- ===== Garde-fou paramètres =====
  WHEN f IS NULL OR t IS NULL OR r IS NULL THEN false

  -- ===== États terminaux : aucune transition humaine sortante =====
  WHEN f IN (
    'retirada_efetivada',
    'cancelada_leitor',
    'cancelada_biblioteca',
    'expirada',
    'liberada_para_circulacao'
  ) THEN false

  -- ===== retirada_no_show : terminal côté API =====
  WHEN f = 'retirada_no_show' THEN false

  -- ===== re-retirada_agendada DÉPRÉCIÉ (paquet 5a) : aucune transition =====
  -- Conservé dans le code uniquement pour ne pas casser les éventuelles résas
  -- historiques. À supprimer définitivement au paquet 7 de polish.
  WHEN f = 're-retirada_agendada' THEN false
  WHEN t = 're-retirada_agendada' THEN false

  -- ===== Lecteur·rice : annulation à tout moment avant retirada_efetivada =====
  WHEN r = 'lecteur' AND t = 'cancelada_leitor' AND f IN (
    'solicitada',
    'em_preparacao',
    'retirada_a_combinar',
    'retirada_agendada',
    'pronta_para_retirada'
  ) THEN true

  -- ===== Lecteur·rice : contre-proposition de créneau (négo dans a_combinar) =====
  -- Le lecteur peut contre-proposer en restant dans retirada_a_combinar.
  -- Conditions dynamiques (flag biblio, compteur < 3) vérifiées par le wrapper.
  WHEN r = 'lecteur' AND t = 'retirada_a_combinar' AND f = 'retirada_a_combinar' THEN true

  -- ===== Lecteur·rice : confirmation du créneau biblio =====
  -- La confirmation depuis retirada_a_combinar mène à retirada_agendada
  -- (créneau verrouillé, négociation close). Précondition pickup_proposed_by
  -- = 'biblio' vérifiée par api.fn_confirm_pickup_slot_as_reader.
  WHEN r = 'lecteur' AND t = 'retirada_agendada' AND f = 'retirada_a_combinar' THEN true

  -- ===== Lecteur·rice : aucune autre transition autorisée =====
  WHEN r = 'lecteur' THEN false

  -- ===== Coordenador : annulation biblio à toute étape non-terminale =====
  WHEN r = 'coordenador' AND t = 'cancelada_biblioteca' AND f IN (
    'solicitada',
    'em_preparacao',
    'retirada_a_combinar',
    'retirada_agendada',
    'pronta_para_retirada'
  ) THEN true

  -- ===== System (cron, trigger) : transitions automatiques =====
  WHEN r = 'system' AND t = 'expirada' AND f = 'solicitada' THEN true
  -- Spec v3 : timeout global négociation expire seulement em_preparacao et
  -- retirada_a_combinar (PAS retirada_agendada qui est verrouillé).
  WHEN r = 'system' AND t = 'expirada' AND f IN (
    'em_preparacao',
    'retirada_a_combinar'
  ) THEN true
  WHEN r = 'system' AND t = 'retirada_no_show' AND f IN (
    'pronta_para_retirada',
    'retirada_agendada'
  ) THEN true
  WHEN r = 'system' THEN false

  -- ===== Librarian/coordenador : transitions opérationnelles =====

  -- Depuis solicitada (Q1 : retirada_agendada direct interdit)
  WHEN f = 'solicitada' AND t IN (
    'em_preparacao',
    'retirada_a_combinar'
  ) AND r IN ('librarian', 'coordenador') THEN true

  -- Depuis em_preparacao (Q1 : retirada_agendada direct interdit)
  WHEN f = 'em_preparacao' AND t IN (
    'retirada_a_combinar'
  ) AND r IN ('librarian', 'coordenador') THEN true

  -- Depuis retirada_a_combinar (stage central de négociation)
  -- Le staff peut re-proposer (boucle a_combinar → a_combinar) ou conclure
  -- (a_combinar → retirada_agendada via fn_confirm_pickup_slot_as_library).
  -- Pronta_para_retirada ATTEINT seulement après retirada_agendada.
  WHEN f = 'retirada_a_combinar' AND t IN (
    'retirada_a_combinar',
    'retirada_agendada'
  ) AND r IN ('librarian', 'coordenador') THEN true

  -- Depuis retirada_agendada (stage verrouillé, on prépare pour le retrait)
  WHEN f = 'retirada_agendada' AND t IN (
    'pronta_para_retirada'
  ) AND r IN ('librarian', 'coordenador') THEN true

  -- Depuis pronta_para_retirada
  WHEN f = 'pronta_para_retirada' AND t IN (
    'retirada_efetivada',
    'retirada_no_show'
  ) AND r IN ('librarian', 'coordenador') THEN true

  -- ===== Tout le reste = refusé =====
  ELSE false
END
FROM normalized;
$function$;

COMMENT ON FUNCTION public.fn_check_workflow_transition(text, text, text) IS
  'Source de vérité de la matrice de transitions du workflow réservation v3 (refactor sémantique 2026-05-09). retirada_a_combinar est le stage central de négociation symétrique. retirada_agendada est le stage d''aboutissement (créneau verrouillé). Le chemin direct solicitada/em_preparacao → retirada_agendada est interdit (Q1). re-retirada_agendada est déprécié (Q3) : aucune transition entrante ni sortante. Le rôle ''lecteur'' peut contre-proposer (a_combinar → a_combinar) ET confirmer (a_combinar → retirada_agendada). Les wrappers api.* font des sanity checks redondants en défense en profondeur.';

-- =============================================================================
-- 2. api.fn_propose_pickup_slot_as_library (refactor v3)
-- =============================================================================
-- Avant v3 : cible variable (retirada_agendada ou re-retirada_agendada)
-- Après v3 : cible toujours retirada_a_combinar (stage central de négo)
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

  -- Refactor v3 : cible toujours retirada_a_combinar.
  -- Stages source autorisés : solicitada, em_preparacao, retirada_a_combinar (loop)
  IF v_current_stage NOT IN ('solicitada', 'em_preparacao', 'retirada_a_combinar') THEN
    RAISE EXCEPTION 'pickup_proposal_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. Les propositions de créneau sont valides depuis solicitada, em_preparacao ou retirada_a_combinar.',
              v_current_stage
            );
  END IF;

  -- Sanity check via la matrice (défense en profondeur)
  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_a_combinar', v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → retirada_a_combinar refusée pour rôle %s',
              v_current_stage, v_actor_role
            );
  END IF;

  -- Délégation au helper standard pour le stage + pickup_scheduled_for + note
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 'retirada_a_combinar', p_note, p_pickup_at
  );

  -- MAJ pickup_proposed_by = 'biblio' (le compteur n'est pas touché côté biblio)
  UPDATE public.reserva_item_workflow_v2
  SET pickup_proposed_by = 'biblio',
      pickup_reply_status = NULL,
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
  'Propose ou re-propose un créneau de retrait au lecteur·rice. Réservé au staff (librarian/coordenador) de la biblio. Refactor v3 (2026-05-09) : cible toujours retirada_a_combinar (stage central de négo). Met pickup_proposed_by = ''biblio'' et reset des éventuelles réponses précédentes. Le compteur d''itérations n''est PAS incrémenté ici (semantique B). Spec refactor v3.';

-- =============================================================================
-- 3. api.fn_propose_pickup_slot_as_reader (refactor v3)
-- =============================================================================
-- Avant v3 : source ∈ {retirada_agendada, re-retirada_agendada}, cible re-retirada_agendada
-- Après v3 : source = retirada_a_combinar, cible retirada_a_combinar (loop)
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

  -- Refactor v3 : la contre-proposition lecteur n'est valide que dans le stage
  -- de négociation active retirada_a_combinar.
  IF v_current_stage <> 'retirada_a_combinar' THEN
    RAISE EXCEPTION 'pickup_counter_proposal_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. La contre-proposition n''est valide que pendant la négociation active (retirada_a_combinar).',
              v_current_stage
            );
  END IF;

  -- Vérification du flag biblio
  IF v_allow_counter IS NOT NULL AND v_allow_counter = false THEN
    RAISE EXCEPTION 'pickup_counter_proposal_disabled_by_library'
      USING ERRCODE = '42501',
            HINT = 'Cette bibliothèque n''accepte pas les contre-propositions de créneau. Tu peux confirmer le créneau proposé ou annuler ta réservation.';
  END IF;

  -- Vérification du compteur d'itérations (max 3 selon semantique B)
  IF v_iteration_count >= 3 THEN
    RAISE EXCEPTION 'pickup_negotiation_max_iterations_reached'
      USING ERRCODE = '22023',
            HINT = 'La négociation a atteint sa limite de 3 contre-propositions. Pour finaliser, contacte directement la biblio par téléphone, mail ou de visu.';
  END IF;

  -- Sanity check via la matrice (refactor v3 : a_combinar → a_combinar pour lecteur)
  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_a_combinar', 'lecteur') THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → retirada_a_combinar refusée pour lecteur (incohérence helper, à investiguer)',
              v_current_stage
            );
  END IF;

  -- Délégation au helper standard (cible = retirada_a_combinar, pas changement)
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 'retirada_a_combinar', p_note, p_pickup_at
  );

  -- MAJ pickup_proposed_by = 'leitor' (le trigger incrémente le compteur)
  UPDATE public.reserva_item_workflow_v2
  SET pickup_proposed_by = 'leitor',
      pickup_reply_status = NULL,
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
  'Permet au lecteur·rice de contre-proposer un créneau pendant la négociation active. Refactor v3 (2026-05-09) : source = retirada_a_combinar, cible = retirada_a_combinar (loop dans le stage central de négo). Réservé au lecteur·rice propriétaire. Échoue si flag biblio désactivé ou compteur >= 3. Met pickup_proposed_by = ''leitor''. Le trigger incrémente le compteur. Spec refactor v3.';

-- =============================================================================
-- 4. api.fn_confirm_pickup_slot_as_library (refactor v3)
-- =============================================================================
-- Avant v3 : source ∈ {retirada_agendada, re-retirada_agendada}, cible pronta_para_retirada
-- Après v3 : source = retirada_a_combinar, cible retirada_agendada
-- =============================================================================

CREATE OR REPLACE FUNCTION api.fn_confirm_pickup_slot_as_library(
  p_reserva_id bigint,
  p_line_no integer
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
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

  -- Refactor v3 : la confirmation se fait depuis retirada_a_combinar (négo active)
  -- vers retirada_agendada (créneau verrouillé).
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

  -- Note d'audit machine-parseable (préfixe ajusté pour refactor v3)
  v_audit_note := format(
    '[autoconf-by-library] %s — créneau verrouillé (retirada_agendada) après contre-proposition lecteur·rice (créneau: %s)',
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    COALESCE(to_char(v_pickup_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), 'NULL')
  );

  -- Refactor v3 : cible retirada_agendada (au lieu de pronta_para_retirada)
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 'retirada_agendada', v_audit_note, v_pickup_at
  );

  -- Reset négociation : pickup_proposed_by = NULL + reset legacy pickup_reply_*
  UPDATE public.reserva_item_workflow_v2
  SET pickup_proposed_by = NULL,
      pickup_reply_status = NULL,
      pickup_reply_note = NULL,
      pickup_reply_at = NULL
  WHERE reserva_id = p_reserva_id AND line_no = p_line_no;

  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.fn_confirm_pickup_slot_as_library(bigint, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.fn_confirm_pickup_slot_as_library(bigint, integer) FROM anon;
GRANT EXECUTE ON FUNCTION api.fn_confirm_pickup_slot_as_library(bigint, integer) TO authenticated;

COMMENT ON FUNCTION api.fn_confirm_pickup_slot_as_library(bigint, integer) IS
  'La biblio (librarian/coordenador) accepte le créneau contre-proposé par le lecteur·rice. Refactor v3 (2026-05-09) : source = retirada_a_combinar, cible = retirada_agendada (créneau verrouillé). Réservé au staff. Précondition pickup_proposed_by = ''leitor''. Effet : transition vers retirada_agendada, pickup_proposed_by = NULL, note d''audit machine-parseable. Reset des champs legacy pickup_reply_*. Spec refactor v3.';

-- =============================================================================
-- 5. api.fn_confirm_pickup_slot_as_reader (refactor v3)
-- =============================================================================
-- Symétrique : source = retirada_a_combinar, cible = retirada_agendada
-- =============================================================================

CREATE OR REPLACE FUNCTION api.fn_confirm_pickup_slot_as_reader(
  p_reserva_id bigint,
  p_line_no integer
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
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

  -- Refactor v3 : confirmation depuis retirada_a_combinar
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

  -- Refactor v3 : cible retirada_agendada
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 'retirada_agendada', v_audit_note, v_pickup_at
  );

  UPDATE public.reserva_item_workflow_v2
  SET pickup_proposed_by = NULL,
      pickup_reply_status = NULL,
      pickup_reply_note = NULL,
      pickup_reply_at = NULL
  WHERE reserva_id = p_reserva_id AND line_no = p_line_no;

  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.fn_confirm_pickup_slot_as_reader(bigint, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.fn_confirm_pickup_slot_as_reader(bigint, integer) FROM anon;
GRANT EXECUTE ON FUNCTION api.fn_confirm_pickup_slot_as_reader(bigint, integer) TO authenticated;

COMMENT ON FUNCTION api.fn_confirm_pickup_slot_as_reader(bigint, integer) IS
  'Le lecteur·rice accepte le créneau proposé par la biblio. Refactor v3 (2026-05-09) : source = retirada_a_combinar, cible = retirada_agendada (créneau verrouillé). Réservé au lecteur·rice propriétaire. Précondition pickup_proposed_by = ''biblio''. Effet : transition vers retirada_agendada, pickup_proposed_by = NULL, note d''audit machine-parseable. Reset des champs legacy pickup_reply_*. Spec refactor v3.';

-- =============================================================================
-- 6. api.advance_reservation (refactor v3)
-- =============================================================================
-- Avant v3 : cible IN (retirada_agendada, re-retirada_agendada) → set
--            pickup_proposed_by = 'biblio'
-- Après v3 : cible = retirada_a_combinar → set pickup_proposed_by = 'biblio'.
--            Cibles retirada_agendada et re-retirada_agendada interdites
--            depuis solicitada/em_preparacao (la matrice les refuse).
-- =============================================================================

CREATE OR REPLACE FUNCTION api.advance_reservation(
  p_reserva_id bigint,
  p_line_no integer,
  p_target_stage text,
  p_options jsonb DEFAULT '{}'::jsonb
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
  v_note text;
  v_pickup timestamptz;
  v_n integer;
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

  -- Refactor v3 : retirada_agendada n'est plus accessible via advance_reservation
  -- (le seul chemin légitime est la confirmation mutuelle via fn_confirm_*).
  IF p_target_stage = 'retirada_agendada' THEN
    RAISE EXCEPTION 'target_stage_has_dedicated_rpc'
      USING ERRCODE = '22023',
            HINT = 'cible retirada_agendada non autorisée via advance_reservation. Le seul chemin légitime est la confirmation mutuelle (api.fn_confirm_pickup_slot_as_library ou as_reader) depuis retirada_a_combinar. Utilise api.fn_propose_pickup_slot_as_library pour ouvrir une négociation.';
  END IF;

  -- Refactor v3 : re-retirada_agendada déprécié
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

  -- Refactor v3 : retirada_a_combinar requiert un créneau (Q-B garde obligatoire)
  IF p_target_stage IN ('retirada_a_combinar') AND v_pickup IS NULL THEN
    RAISE EXCEPTION 'pickup_scheduled_for_required'
      USING ERRCODE = '22023',
            HINT = format(
              'cible %s requiert p_options->>''pickup_scheduled_for'' (timestamptz). Même approximatif, indique un créneau initial pour ouvrir la négociation.',
              p_target_stage
            );
  END IF;

  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], p_target_stage, v_note, v_pickup
  );

  -- Refactor v3 : pickup_proposed_by automatique selon la cible
  IF p_target_stage = 'retirada_a_combinar' THEN
    -- Ouverture (ou relance) de la négociation par la biblio
    UPDATE public.reserva_item_workflow_v2
    SET pickup_proposed_by   = 'biblio',
        pickup_reply_status  = NULL,
        pickup_reply_note    = NULL,
        pickup_reply_at      = NULL
    WHERE reserva_id = p_reserva_id AND line_no = p_line_no;
  ELSE
    -- Toute autre cible (em_preparacao, pronta_para_retirada, etc.) :
    -- la négociation est close ou non applicable, on remet à NULL.
    UPDATE public.reserva_item_workflow_v2
    SET pickup_proposed_by   = NULL,
        pickup_reply_status  = NULL,
        pickup_reply_note    = NULL,
        pickup_reply_at      = NULL
    WHERE reserva_id = p_reserva_id AND line_no = p_line_no
      AND pickup_proposed_by IS NOT NULL;
  END IF;

  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) TO authenticated;

COMMENT ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) IS
  'Fait progresser une ligne de réservation vers un stage cible. Réservé au staff. Refactor v3 (2026-05-09) : retirada_agendada non accessible (passer par fn_confirm_*), re-retirada_agendada déprécié. Cible retirada_a_combinar set automatiquement pickup_proposed_by = ''biblio''. Cibles exclues : retirada_efetivada (api.confirm_pickup_v1), liberada_para_circulacao (trigger auto), expirada (cron). Spec refactor v3.';

-- =============================================================================
-- 7. fn_expire_negotiation_timeout (refactor v3)
-- =============================================================================
-- Avant v3 : cibles ('em_preparacao', 'retirada_agendada', 'retirada_a_combinar', 're-retirada_agendada')
-- Après v3 : cibles ('em_preparacao', 'retirada_a_combinar') seulement
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
            -- Refactor v3 : retirada_agendada et re-retirada_agendada retirés
            'em_preparacao',
            'retirada_a_combinar'
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
  'Job cron : expire les réservations en stages de négociation (em_preparacao, retirada_a_combinar) dont l''âge depuis reservas_v2.created_at dépasse library_notification_policies.reservation_negotiation_timeout_days (default 21j). Refactor v3 (2026-05-09) : retirada_agendada retiré du périmètre (créneau verrouillé = pas de timeout, géré par retirada_no_show), re-retirada_agendada retiré (déprécié). Spec refactor v3.';

COMMIT;

-- =============================================================================
-- Validation post-migration
-- =============================================================================
--
-- Q1. Les 5 RPC api.* + le helper public + le cron sont à jour
-- SELECT routine_schema, routine_name, security_type
--   FROM information_schema.routines
--   WHERE (routine_schema, routine_name) IN (
--     ('api', 'fn_propose_pickup_slot_as_library'),
--     ('api', 'fn_propose_pickup_slot_as_reader'),
--     ('api', 'fn_confirm_pickup_slot_as_library'),
--     ('api', 'fn_confirm_pickup_slot_as_reader'),
--     ('api', 'advance_reservation'),
--     ('public', 'fn_check_workflow_transition'),
--     ('public', 'fn_expire_negotiation_timeout')
--   )
--   ORDER BY routine_schema, routine_name;
-- Attendu : 7 lignes
--
-- Q2. La nouvelle matrice : transitions clés
-- SELECT
--   -- Lecteur peut négocier dans retirada_a_combinar
--   public.fn_check_workflow_transition('retirada_a_combinar', 'retirada_a_combinar', 'lecteur') AS lecteur_loop_combinar,
--   public.fn_check_workflow_transition('retirada_a_combinar', 'retirada_agendada',   'lecteur') AS lecteur_combinar_to_agendada,
--   -- Staff peut ouvrir négo
--   public.fn_check_workflow_transition('solicitada',          'retirada_a_combinar', 'librarian') AS librarian_sol_to_combinar,
--   public.fn_check_workflow_transition('em_preparacao',       'retirada_a_combinar', 'librarian') AS librarian_prep_to_combinar,
--   -- Q1 : direct interdit
--   public.fn_check_workflow_transition('solicitada',          'retirada_agendada',   'librarian') AS librarian_direct_sol_BLOCKED,
--   public.fn_check_workflow_transition('em_preparacao',       'retirada_agendada',   'librarian') AS librarian_direct_prep_BLOCKED,
--   -- Aboutissement
--   public.fn_check_workflow_transition('retirada_a_combinar', 'retirada_agendada',   'librarian') AS librarian_confirm,
--   public.fn_check_workflow_transition('retirada_agendada',   'pronta_para_retirada','librarian') AS librarian_lock_to_ready,
--   -- Q3 : re-retirada_agendada déprécié
--   public.fn_check_workflow_transition('retirada_a_combinar', 're-retirada_agendada','librarian') AS deprecated_target_BLOCKED,
--   public.fn_check_workflow_transition('re-retirada_agendada','retirada_agendada',   'librarian') AS deprecated_source_BLOCKED;
-- Attendu :
--   lecteur_loop_combinar          = true
--   lecteur_combinar_to_agendada   = true
--   librarian_sol_to_combinar      = true
--   librarian_prep_to_combinar     = true
--   librarian_direct_sol_BLOCKED   = false
--   librarian_direct_prep_BLOCKED  = false
--   librarian_confirm              = true
--   librarian_lock_to_ready        = true
--   deprecated_target_BLOCKED      = false
--   deprecated_source_BLOCKED      = false
--
-- Q3. Le cron a bien été retiré de retirada_agendada
-- (Inspection visuelle du source : cherche "retirada_agendada" dans le SELECT
-- de la fonction fn_expire_negotiation_timeout — ne doit PAS apparaître dans
-- la liste WHERE workflow_stage IN (...).)
-- SELECT pg_get_functiondef('public.fn_expire_negotiation_timeout()'::regprocedure);
-- Attendu : la liste ne contient que 'em_preparacao' et 'retirada_a_combinar'.
--
-- Q4. Permissions inchangées
-- SELECT routine_schema, routine_name, grantee, privilege_type
--   FROM information_schema.routine_privileges
--   WHERE routine_schema = 'api'
--     AND routine_name IN (
--       'fn_propose_pickup_slot_as_library',
--       'fn_propose_pickup_slot_as_reader',
--       'fn_confirm_pickup_slot_as_library',
--       'fn_confirm_pickup_slot_as_reader',
--       'advance_reservation'
--     )
--     AND grantee = 'authenticated'
--   ORDER BY routine_name;
-- Attendu : 5 lignes, toutes avec privilege_type = 'EXECUTE'
--
-- Q5. Idempotence : on peut rejouer la migration sans erreur
-- (Re-lance le fichier dans une nouvelle session SQL Editor)
--
-- Q6. Vérification de l'inventaire actuel des résas (sécurité avant déploiement)
-- SELECT workflow_stage, COUNT(*) AS nb
-- FROM public.reserva_item_workflow_v2
-- GROUP BY workflow_stage
-- ORDER BY nb DESC;
-- Vérifie qu'aucune ligne n'est en 'retirada_agendada' ou 're-retirada_agendada'
-- ACTIVE (= non terminale). Si oui, voir spec § "Migration de données".
-- =============================================================================
