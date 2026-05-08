-- =============================================================================
-- Migration : Workflow réservation v2 — Phase 5 paquet 2 bis
--             (RPC confirmation symétrique + extension matrice + extension vue)
-- Date      : 2026-05-08
-- Spec      : docs/spec-workflow-reservation-v2-negotiation.md
-- Paquet    : 2 bis (complète le paquet 2 du même jour)
-- Préreq    : 20260508_workflow_reservation_phase5_negotiation.sql appliquée
--             20260508_workflow_reservation_phase5_paquet_2.sql appliquée
-- =============================================================================
-- Trois ajouts pour permettre la fermeture symétrique d'une négociation :
--
--   1. Extension de fn_check_workflow_transition : autorise le rôle 'lecteur'
--      à faire les transitions retirada_agendada → pronta_para_retirada et
--      re-retirada_agendada → pronta_para_retirada (= acceptation du créneau
--      proposé par la biblio).
--
--   2. api.fn_confirm_pickup_slot_as_library : la biblio accepte le créneau
--      contre-proposé par le lecteur·rice. Précondition : pickup_proposed_by
--      = 'leitor'. Effet : transition vers pronta_para_retirada,
--      pickup_proposed_by = NULL, note d'audit.
--
--   3. api.fn_confirm_pickup_slot_as_reader : le lecteur·rice accepte le
--      créneau proposé par la biblio. Précondition : pickup_proposed_by
--      = 'biblio'. Effet : transition vers pronta_para_retirada,
--      pickup_proposed_by = NULL, note d'audit.
--
--   4. Extension de la vue api.reserva_itens_followup_ui pour exposer
--      pickup_proposed_by et negotiation_iteration_count (sinon le frontend
--      du paquet 3 ne peut pas distinguer les états de négociation).
--
-- Pattern commun (cohérent avec phase2_paquet_a et paquet 2 du jour) :
--   1. Auth : auth.uid() requis
--   2. Contexte : reservas_v2 + reserva_item_workflow_v2 en une requête
--   3. Validation : ownership/rôle + état de négociation + helper matrice
--   4. Délégation : fn_v2_set_reserva_linhas_workflow + UPDATE complémentaire
--                   pour pickup_proposed_by = NULL + reset legacy pickup_reply_*
--
-- Décisions de design (validées CCLA 2026-05-08) :
--   - Variante 1 : confirmation mutuelle déclenche → pronta_para_retirada
--     immédiatement, pickup_proposed_by = NULL. La matrice considère ce stage
--     comme « créneau verrouillé, staff prépare l'exemplaire ».
--   - Modèle M1 : la transition côté lecteur est déclarée comme actor_role
--     = 'lecteur' dans la matrice (pas de bypass SECURITY DEFINER).
--   - Note d'audit machine-parseable dans workflow_note avec préfixes
--     [autoconf-by-library] / [autoconf-by-reader] + timestamp ISO 8601 UTC.
--   - Le legacy pickup_reply_status / pickup_reply_note / pickup_reply_at est
--     reseté lors de la confirmation mutuelle (cohérence : la négociation est
--     close, plus de réponse en attente).
--
-- Codes d'erreur ajoutés :
--   - pickup_confirmation_not_applicable_in_stage   (stage hors retrait)
--   - pickup_confirmation_wrong_proposer            (mauvais pickup_proposed_by)
--   - pickup_no_active_proposal                     (pickup_proposed_by IS NULL)
-- =============================================================================

BEGIN;

-- =============================================================================
-- 0. Extension de la matrice de transitions
-- =============================================================================
-- Ajoute deux règles pour le rôle 'lecteur' :
--   - retirada_agendada    → pronta_para_retirada
--   - re-retirada_agendada → pronta_para_retirada
-- Ces transitions sont déclenchées exclusivement par
-- api.fn_confirm_pickup_slot_as_reader (sanity check côté wrapper +
-- défense en profondeur côté matrice).
--
-- Toutes les autres règles existantes sont conservées à l'identique.
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
    -- Normalisation des alias : nao_retirada → retirada_no_show
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

  -- ===== retirada_no_show : terminal côté API (le trigger gère liberada) =====
  WHEN f = 'retirada_no_show' THEN false

  -- ===== Lecteur·rice : annulation à tout moment avant retirada_efetivada =====
  WHEN r = 'lecteur' AND t = 'cancelada_leitor' AND f IN (
    'solicitada',
    'em_preparacao',
    'retirada_agendada',
    'retirada_a_combinar',
    're-retirada_agendada',
    'pronta_para_retirada'
  ) THEN true

  -- ===== Lecteur·rice : contre-proposition de créneau (spec v2) =====
  -- Le lecteur peut contre-proposer un créneau quand la biblio en a proposé un.
  -- Conditions dynamiques (flag biblio, compteur < 3) vérifiées par le wrapper.
  WHEN r = 'lecteur' AND t = 're-retirada_agendada' AND f IN (
    'retirada_agendada',
    're-retirada_agendada'
  ) THEN true

  -- ===== Lecteur·rice : confirmation du créneau biblio (spec v2 paquet 2 bis) =====
  -- Le lecteur peut confirmer le créneau proposé par la biblio, ce qui
  -- déclenche la transition vers pronta_para_retirada (créneau verrouillé,
  -- staff prépare l'exemplaire). Précondition pickup_proposed_by = 'biblio'
  -- vérifiée par api.fn_confirm_pickup_slot_as_reader.
  WHEN r = 'lecteur' AND t = 'pronta_para_retirada' AND f IN (
    'retirada_agendada',
    're-retirada_agendada'
  ) THEN true

  -- ===== Lecteur·rice : aucune autre transition autorisée =====
  WHEN r = 'lecteur' THEN false

  -- ===== Coordenador : annulation biblio à toute étape non-terminale =====
  -- (la contrainte "raison obligatoire ≥ retirada_agendada" est gérée
  --  côté wrapper api.cancel_reservation_as_library)
  WHEN r = 'coordenador' AND t = 'cancelada_biblioteca' AND f IN (
    'solicitada',
    'em_preparacao',
    'retirada_agendada',
    'retirada_a_combinar',
    're-retirada_agendada',
    'pronta_para_retirada'
  ) THEN true

  -- ===== System (cron, trigger) : transitions automatiques =====
  WHEN r = 'system' AND t = 'expirada' AND f = 'solicitada' THEN true
  -- Spec v2 : timeout global négociation expire aussi les stages intermédiaires
  WHEN r = 'system' AND t = 'expirada' AND f IN (
    'em_preparacao',
    'retirada_agendada',
    'retirada_a_combinar',
    're-retirada_agendada'
  ) THEN true
  WHEN r = 'system' AND t = 'retirada_no_show' AND f IN (
    'pronta_para_retirada',
    'retirada_agendada',
    're-retirada_agendada'
  ) THEN true
  -- liberada_para_circulacao : trigger tourne en court-circuit, jamais via helper
  WHEN r = 'system' THEN false

  -- ===== Librarian (et coordenador par inclusion) : transitions opérationnelles =====

  -- Depuis solicitada
  WHEN f = 'solicitada' AND t IN (
    'em_preparacao',
    'retirada_agendada',
    'retirada_a_combinar'
  ) AND r IN ('librarian', 'coordenador') THEN true

  -- Depuis em_preparacao
  WHEN f = 'em_preparacao' AND t IN (
    'retirada_agendada',
    'retirada_a_combinar'
  ) AND r IN ('librarian', 'coordenador') THEN true

  -- Depuis retirada_agendada
  WHEN f = 'retirada_agendada' AND t IN (
    're-retirada_agendada',
    'pronta_para_retirada'
  ) AND r IN ('librarian', 'coordenador') THEN true

  -- Depuis retirada_a_combinar
  WHEN f = 'retirada_a_combinar' AND t IN (
    'retirada_agendada',
    're-retirada_agendada',
    'pronta_para_retirada'
  ) AND r IN ('librarian', 'coordenador') THEN true

  -- Depuis re-retirada_agendada (boucle autorisée pour reproposer un créneau
  -- après refus lecteur ou contre-proposition lecteur, cf. spec v2)
  WHEN f = 're-retirada_agendada' AND t IN (
    're-retirada_agendada',
    'pronta_para_retirada'
  ) AND r IN ('librarian', 'coordenador') THEN true

  -- Depuis pronta_para_retirada
  -- - retirada_efetivada : passe par api.confirm_pickup_v1 (atomique, pas par advance)
  --   mais on autorise ici pour cohérence avec spec section 4
  -- - retirada_no_show : staff peut le marquer manuellement aussi (spec §4)
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
  'Source de vérité de la matrice de transitions du workflow réservation v2. Retourne true si la transition (p_from → p_to) est autorisée pour p_actor_role ∈ {lecteur, librarian, coordenador, system}. Spec v2 négociation symétrique : le rôle ''lecteur'' peut contre-proposer (re-retirada_agendada) ET confirmer le créneau biblio (pronta_para_retirada). Les wrappers api.* font des sanity checks redondants en défense en profondeur.';

-- =============================================================================
-- 1. api.fn_confirm_pickup_slot_as_library(p_reserva_id, p_line_no)
-- =============================================================================
-- Permet à la biblio (librarian/coordenador) d'accepter le créneau qui a été
-- contre-proposé par le lecteur·rice. La négociation se ferme : transition
-- vers pronta_para_retirada, pickup_proposed_by = NULL, note d'audit.
--
-- Préconditions :
--   - rôle staff de la biblio
--   - stage ∈ {retirada_agendada, re-retirada_agendada}
--   - pickup_proposed_by = 'leitor' (sinon ce n'est pas la biblio qui doit
--     accepter, c'est le lecteur)
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

  -- Lecture du contexte en une seule requête
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

  -- Validation rôle staff
  v_actor_role := public.fn_resolve_caller_role_for_library(v_library_id);
  IF v_actor_role IS NULL THEN
    RAISE EXCEPTION 'not_staff_of_this_library' USING ERRCODE = '42501';
  END IF;

  -- Stage doit être un stage de négociation de créneau
  IF v_current_stage NOT IN ('retirada_agendada', 're-retirada_agendada') THEN
    RAISE EXCEPTION 'pickup_confirmation_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. La confirmation n''est valide que depuis retirada_agendada ou re-retirada_agendada.',
              v_current_stage
            );
  END IF;

  -- Précondition spécifique : c'est bien le lecteur qui a contre-proposé
  IF v_proposed_by IS NULL THEN
    RAISE EXCEPTION 'pickup_no_active_proposal'
      USING ERRCODE = '22023',
            HINT = 'aucune proposition active à confirmer (pickup_proposed_by IS NULL). Le créneau est déjà verrouillé ou n''a jamais été proposé.';
  END IF;

  IF v_proposed_by <> 'leitor' THEN
    RAISE EXCEPTION 'pickup_confirmation_wrong_proposer'
      USING ERRCODE = '22023',
            HINT = format(
              'pickup_proposed_by = %s. La biblio ne peut confirmer que les contre-propositions du lecteur·rice (pickup_proposed_by = ''leitor''). Si tu veux re-proposer un autre créneau, utilise fn_propose_pickup_slot_as_library.',
              v_proposed_by
            );
  END IF;

  -- Sanity check via la matrice (défense en profondeur)
  IF NOT public.fn_check_workflow_transition(v_current_stage, 'pronta_para_retirada', v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → pronta_para_retirada refusée pour rôle %s (incohérence helper, à investiguer)',
              v_current_stage, v_actor_role
            );
  END IF;

  -- Construction de la note d'audit machine-parseable
  v_audit_note := format(
    '[autoconf-by-library] %s — créneau confirmé mutuellement après contre-proposition lecteur·rice (créneau: %s)',
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    COALESCE(to_char(v_pickup_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), 'NULL')
  );

  -- Délégation au helper standard pour le stage + note
  -- (le pickup_scheduled_for est conservé tel quel : on confirme le créneau existant)
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 'pronta_para_retirada', v_audit_note, v_pickup_at
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
  'La biblio (librarian/coordenador) accepte le créneau contre-proposé par le lecteur·rice. Réservé au staff de la biblio. Précondition : pickup_proposed_by = ''leitor''. Effet : transition vers pronta_para_retirada (créneau verrouillé, staff prépare l''exemplaire), pickup_proposed_by = NULL, note d''audit machine-parseable. Reset des champs legacy pickup_reply_*. Spec v2 négociation symétrique paquet 2 bis.';

-- =============================================================================
-- 2. api.fn_confirm_pickup_slot_as_reader(p_reserva_id, p_line_no)
-- =============================================================================
-- Permet au lecteur·rice d'accepter le créneau proposé par la biblio. La
-- négociation se ferme : transition vers pronta_para_retirada,
-- pickup_proposed_by = NULL, note d'audit.
--
-- Préconditions :
--   - ownership de la résa
--   - stage ∈ {retirada_agendada, re-retirada_agendada}
--   - pickup_proposed_by = 'biblio' (sinon ce n'est pas le lecteur qui doit
--     accepter, c'est la biblio)
--
-- À noter : ce wrapper s'utilise depuis le frontend via
--   supabase.schema('api').rpc('fn_confirm_pickup_slot_as_reader', { ... })
-- et NON via supabase.rpc(..., { schema: 'api' }) qui est silencieusement
-- ignoré par supabase-js v2 et appellerait public.fn_confirm_pickup_slot_as_reader
-- (qui n'existe pas) → erreur 404.
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

  -- Lecture du contexte en une seule requête
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

  -- Validation ownership lecteur·rice
  IF v_owner <> v_uid THEN
    RAISE EXCEPTION 'not_your_reserva' USING ERRCODE = '42501';
  END IF;

  -- Stage doit être un stage de négociation de créneau
  IF v_current_stage NOT IN ('retirada_agendada', 're-retirada_agendada') THEN
    RAISE EXCEPTION 'pickup_confirmation_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. La confirmation n''est valide que depuis retirada_agendada ou re-retirada_agendada.',
              v_current_stage
            );
  END IF;

  -- Précondition spécifique : c'est bien la biblio qui a proposé
  IF v_proposed_by IS NULL THEN
    RAISE EXCEPTION 'pickup_no_active_proposal'
      USING ERRCODE = '22023',
            HINT = 'aucune proposition active à confirmer (pickup_proposed_by IS NULL). Le créneau est déjà verrouillé ou n''a jamais été proposé.';
  END IF;

  IF v_proposed_by <> 'biblio' THEN
    RAISE EXCEPTION 'pickup_confirmation_wrong_proposer'
      USING ERRCODE = '22023',
            HINT = format(
              'pickup_proposed_by = %s. Tu ne peux confirmer que les créneaux proposés par la biblio (pickup_proposed_by = ''biblio''). Si tu veux contre-proposer un autre créneau, utilise fn_propose_pickup_slot_as_reader.',
              v_proposed_by
            );
  END IF;

  -- Sanity check via la matrice (défense en profondeur, repose sur la nouvelle
  -- règle ajoutée en section 0 de cette migration)
  IF NOT public.fn_check_workflow_transition(v_current_stage, 'pronta_para_retirada', 'lecteur') THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → pronta_para_retirada refusée pour lecteur (incohérence helper, à investiguer)',
              v_current_stage
            );
  END IF;

  -- Construction de la note d'audit machine-parseable
  v_audit_note := format(
    '[autoconf-by-reader] %s — créneau confirmé mutuellement après proposition biblio (créneau: %s)',
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    COALESCE(to_char(v_pickup_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), 'NULL')
  );

  -- Délégation au helper standard pour le stage + note
  -- (le pickup_scheduled_for est conservé tel quel : on confirme le créneau existant)
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 'pronta_para_retirada', v_audit_note, v_pickup_at
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

REVOKE ALL ON FUNCTION api.fn_confirm_pickup_slot_as_reader(bigint, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.fn_confirm_pickup_slot_as_reader(bigint, integer) FROM anon;
GRANT EXECUTE ON FUNCTION api.fn_confirm_pickup_slot_as_reader(bigint, integer) TO authenticated;

COMMENT ON FUNCTION api.fn_confirm_pickup_slot_as_reader(bigint, integer) IS
  'Le lecteur·rice accepte le créneau proposé par la biblio. Réservé au lecteur·rice propriétaire. Précondition : pickup_proposed_by = ''biblio''. Effet : transition vers pronta_para_retirada (créneau verrouillé), pickup_proposed_by = NULL, note d''audit machine-parseable. Reset des champs legacy pickup_reply_*. Spec v2 négociation symétrique paquet 2 bis.';

-- =============================================================================
-- 3. Extension de la vue api.reserva_itens_followup_ui
-- =============================================================================
-- Expose les nouveaux champs de négociation pour que le frontend des paquets
-- 3 et 4 puisse afficher l'état de négociation et le compteur d'itérations.
-- Toutes les autres colonnes restent identiques à la version d'origine.
-- =============================================================================

CREATE OR REPLACE VIEW api.reserva_itens_followup_ui AS
SELECT r.id AS reserva_id,
    rl.id AS reserva_item_id,
    rl.line_no,
    rl.sub_id,
    r.user_id,
    r.library_id,
    l.slug AS library_slug,
    l.name AS library_name,
    r.created_at AS reserva_created_at,
    r.updated_at AS reserva_updated_at,
    r.status_global AS reserva_status,
    rl.book_id,
    rl.item_id,
    rl.bib_ref,
    rl.rotulo_cache AS rotulo,
    COALESCE(rl.autor_cache, b.autor) AS autor,
    COALESCE(rl.titulo_cache, b.titulo) AS titulo,
    COALESCE(rl.editora_cache, b.editora) AS editora,
    COALESCE(rl.ano_cache, b.ano) AS ano,
    rl.item_status,
    rl.expires_at,
    rl.cancelled_at,
    rl.converted_at,
    rl.expired_at,
    rl.emprestimo_item_id,
    rl.notes AS item_notes,
    COALESCE(w.workflow_stage,
        CASE
            WHEN rl.item_status = 'ativa'::text THEN 'solicitada'::text
            WHEN rl.item_status = 'cancelada_leitor'::text THEN 'cancelada_leitor'::text
            WHEN rl.item_status = 'cancelada_biblioteca'::text THEN 'cancelada_biblioteca'::text
            WHEN rl.item_status = 'expirada'::text THEN 'expirada'::text
            WHEN rl.item_status = 'convertida_em_emprestimo'::text THEN 'retirada_efetivada'::text
            WHEN rl.item_status = 'liberada_para_circulacao'::text THEN 'liberada_para_circulacao'::text
            ELSE 'solicitada'::text
        END) AS workflow_stage_effective,
    w.workflow_note,
    w.pickup_scheduled_for,
    w.updated_at AS workflow_stage_updated_at_effective,
    w.pickup_reply_status,
    w.pickup_reply_note,
    w.pickup_reply_at,
    -- Nouveaux champs négociation symétrique v2 (paquet 2 bis)
    w.pickup_proposed_by,
    COALESCE(w.negotiation_iteration_count, 0) AS negotiation_iteration_count
   FROM reservas_v2 r
     JOIN reserva_linhas_v2 rl ON rl.reserva_id = r.id
     JOIN libraries l ON l.id = r.library_id
     LEFT JOIN books b ON b.id = rl.book_id
     LEFT JOIN reserva_item_workflow_v2 w ON w.reserva_id = rl.reserva_id AND w.line_no = rl.line_no;

COMMENT ON VIEW api.reserva_itens_followup_ui IS
  'Vue de suivi UI des items de réservation : jointure reservas_v2 + reserva_linhas_v2 + reserva_item_workflow_v2 + libraries + books. Expose le workflow_stage_effective (avec fallback selon item_status si pas de ligne workflow), les champs de retrait scheduled/reply, et — depuis le paquet 2 bis — les nouveaux champs de négociation symétrique pickup_proposed_by et negotiation_iteration_count.';

COMMIT;

-- =============================================================================
-- Validation post-migration
-- =============================================================================
-- Lancer ces requêtes APRÈS la migration pour vérifier qu'elle s'est bien
-- appliquée. Toutes doivent retourner les valeurs attendues.
--
-- Q1. Les 2 nouvelles RPC existent dans api avec security_type INVOKER
-- SELECT routine_name, routine_type, security_type
--   FROM information_schema.routines
--   WHERE routine_schema = 'api'
--     AND routine_name IN ('fn_confirm_pickup_slot_as_library', 'fn_confirm_pickup_slot_as_reader')
--   ORDER BY routine_name;
-- Attendu : 2 lignes, security_type = 'INVOKER'
--
-- Q2. La matrice autorise bien les nouvelles transitions lecteur → pronta
-- SELECT
--   public.fn_check_workflow_transition('retirada_agendada',    'pronta_para_retirada', 'lecteur')    AS lecteur_ag_to_pronta,
--   public.fn_check_workflow_transition('re-retirada_agendada', 'pronta_para_retirada', 'lecteur')    AS lecteur_reag_to_pronta,
--   public.fn_check_workflow_transition('retirada_agendada',    'pronta_para_retirada', 'librarian')  AS librarian_ag_to_pronta,
--   public.fn_check_workflow_transition('retirada_agendada',    'pronta_para_retirada', 'coordenador') AS coord_ag_to_pronta;
-- Attendu : tout à true
--
-- Q3. Non-régression : les transitions ambiguës restent refusées pour lecteur
-- SELECT
--   public.fn_check_workflow_transition('pronta_para_retirada', 'retirada_agendada',    'lecteur') AS lecteur_pronta_to_ag,
--   public.fn_check_workflow_transition('solicitada',           'pronta_para_retirada', 'lecteur') AS lecteur_sol_to_pronta,
--   public.fn_check_workflow_transition('em_preparacao',        'pronta_para_retirada', 'lecteur') AS lecteur_prep_to_pronta,
--   public.fn_check_workflow_transition('retirada_agendada',    'retirada_efetivada',   'lecteur') AS lecteur_ag_to_efet;
-- Attendu : tout à false
--
-- Q4. Non-régression : les transitions existantes du paquet 2 sont toujours valides
-- SELECT
--   public.fn_check_workflow_transition('retirada_agendada',    're-retirada_agendada', 'lecteur')    AS lecteur_counter_proposal,
--   public.fn_check_workflow_transition('retirada_agendada',    'cancelada_leitor',     'lecteur')    AS lecteur_cancel,
--   public.fn_check_workflow_transition('em_preparacao',        'expirada',             'system')     AS system_timeout_prep,
--   public.fn_check_workflow_transition('re-retirada_agendada', 'expirada',             'system')     AS system_timeout_reag;
-- Attendu : tout à true
--
-- Q5. Permissions sur les RPC
-- SELECT routine_name, grantee, privilege_type
--   FROM information_schema.routine_privileges
--   WHERE routine_schema = 'api'
--     AND routine_name IN ('fn_confirm_pickup_slot_as_library', 'fn_confirm_pickup_slot_as_reader')
--     AND grantee IN ('authenticated', 'anon', 'PUBLIC')
--   ORDER BY routine_name, grantee;
-- Attendu : 2 lignes (authenticated, EXECUTE) — pas de anon ni PUBLIC
--
-- Q6. La vue expose bien les 2 nouveaux champs
-- SELECT column_name, data_type
--   FROM information_schema.columns
--   WHERE table_schema = 'api'
--     AND table_name = 'reserva_itens_followup_ui'
--     AND column_name IN ('pickup_proposed_by', 'negotiation_iteration_count')
--   ORDER BY column_name;
-- Attendu : 2 lignes (pickup_proposed_by text, negotiation_iteration_count integer)
--
-- Q7. Idempotence : on peut rejouer la migration sans erreur
-- (Re-lance le script entier dans une session : doit passer sans casse)
-- =============================================================================
