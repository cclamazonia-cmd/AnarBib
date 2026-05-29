-- =============================================================================
-- Migration : Workflow réservation — Phase 5 (négociation symétrique)
-- Date      : 2026-05-08
-- Spec      : docs/spec-workflow-reservation-v2-negotiation.md
-- Paquet    : 1/6 (schéma DB uniquement)
-- =============================================================================
-- Cette migration introduit le schéma nécessaire pour la négociation
-- symétrique entre lecteur·rice et bibliothèque dans le workflow de
-- réservation.
--
-- Modifications :
--   1. reserva_item_workflow_v2 :
--        + colonne pickup_proposed_by ('biblio' | 'leitor' | NULL)
--        + colonne negotiation_iteration_count (0..3)
--   2. library_notification_policies :
--        + colonne reservation_allow_reader_counter_proposal (default true)
--        + colonne reservation_negotiation_timeout_days (default 21, range 7-60)
--   3. fn_check_workflow_transition :
--        + nouvelle règle : lecteur peut transitionner
--          retirada_agendada → re-retirada_agendada
--          (contraintes flag biblio + compteur < 3 vérifiées par le wrapper RPC,
--           pas par cette fonction SQL pure)
--
-- Migration idempotente : peut être ré-exécutée sans danger.
-- Rétrocompatible : aucune colonne existante modifiée, aucune contrainte
-- existante supprimée. Le code v1 continue de fonctionner sans changement.
--
-- Validé politiquement par CCLA (8 mai 2026).
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. reserva_item_workflow_v2 : nouvelles colonnes
-- =============================================================================

-- Colonne pickup_proposed_by
ALTER TABLE public.reserva_item_workflow_v2
  ADD COLUMN IF NOT EXISTS pickup_proposed_by text;

-- CHECK constraint pour pickup_proposed_by (drop + recreate pour idempotence)
ALTER TABLE public.reserva_item_workflow_v2
  DROP CONSTRAINT IF EXISTS chk_pickup_proposed_by;
ALTER TABLE public.reserva_item_workflow_v2
  ADD CONSTRAINT chk_pickup_proposed_by
    CHECK (pickup_proposed_by IN ('biblio', 'leitor') OR pickup_proposed_by IS NULL);

COMMENT ON COLUMN public.reserva_item_workflow_v2.pickup_proposed_by IS
  'Qui a fait la dernière proposition de créneau de retrait. ''biblio'' = en attente de réponse du lecteur. ''leitor'' = en attente de réponse de la biblio. NULL = créneau confirmé ou pas de proposition en cours. Spec v2 négociation symétrique.';

-- Colonne negotiation_iteration_count
ALTER TABLE public.reserva_item_workflow_v2
  ADD COLUMN IF NOT EXISTS negotiation_iteration_count int NOT NULL DEFAULT 0;

-- CHECK constraint pour negotiation_iteration_count (max 3)
ALTER TABLE public.reserva_item_workflow_v2
  DROP CONSTRAINT IF EXISTS chk_negotiation_iteration_max;
ALTER TABLE public.reserva_item_workflow_v2
  ADD CONSTRAINT chk_negotiation_iteration_max
    CHECK (negotiation_iteration_count >= 0 AND negotiation_iteration_count <= 3);

COMMENT ON COLUMN public.reserva_item_workflow_v2.negotiation_iteration_count IS
  'Nombre de contre-propositions échangées dans la négociation du créneau de retrait. Plafonné à 3 (validation politique CCLA). Au-delà, la spec recommande de poursuivre par téléphone/mail/de visu. Incrementé par trigger lors de chaque proposition (paquet 2).';


-- =============================================================================
-- 2. library_notification_policies : nouveaux paramètres biblio
-- =============================================================================

-- Flag pour autoriser les contre-propositions côté lecteur
ALTER TABLE public.library_notification_policies
  ADD COLUMN IF NOT EXISTS reservation_allow_reader_counter_proposal boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.library_notification_policies.reservation_allow_reader_counter_proposal IS
  'Si true (default, éthique anarchiste), le lecteur peut contre-proposer un créneau quand la biblio en propose un. Si false, le lecteur ne peut que confirmer ou annuler (pour structures à créneaux fixes). Spec v2 § 3.2.';

-- Timeout global de la négociation
ALTER TABLE public.library_notification_policies
  ADD COLUMN IF NOT EXISTS reservation_negotiation_timeout_days int NOT NULL DEFAULT 21;

ALTER TABLE public.library_notification_policies
  DROP CONSTRAINT IF EXISTS chk_negotiation_timeout;
ALTER TABLE public.library_notification_policies
  ADD CONSTRAINT chk_negotiation_timeout
    CHECK (reservation_negotiation_timeout_days BETWEEN 7 AND 60);

COMMENT ON COLUMN public.library_notification_policies.reservation_negotiation_timeout_days IS
  'Délai global après création de la résa au-delà duquel une négociation non aboutie est expirée par cron (passe en stage expirada). Range raisonnable 7-60 jours, default 21 (validé CCLA). Indépendant du compteur d''itérations qui plafonne à 3. Spec v2 § 3.1.';


-- =============================================================================
-- 3. fn_check_workflow_transition : ajout de la règle lecteur → re-retirada_agendada
-- =============================================================================
-- La fonction reste SQL pure (LANGUAGE sql IMMUTABLE) — les contraintes
-- dynamiques (flag biblio, compteur d'itérations) sont vérifiées en amont
-- par le wrapper RPC fn_propose_pickup_slot_as_reader (paquet 2).
--
-- Nouvelles règles ajoutées :
--   - lecteur : retirada_agendada → re-retirada_agendada (contre-proposition)
--   - lecteur : re-retirada_agendada → re-retirada_agendada (re-contre-proposition)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_check_workflow_transition(
  p_from text,
  p_to text,
  p_actor_role text
) RETURNS boolean
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = public
AS $$
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
$$;

REVOKE ALL ON FUNCTION public.fn_check_workflow_transition(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_check_workflow_transition(text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_check_workflow_transition(text, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_check_workflow_transition(text, text, text) IS
  'Helper SQL pur encodant la matrice de transitions autorisées du workflow de réservation (cf. spec-workflow-reservation-v2-negotiation.md). Retourne true si la transition (from→to) est autorisée pour l''actor_role donné. Acteurs : lecteur, librarian, coordenador, system. Alias nao_retirada normalisé. États terminaux : retirada_efetivada, cancelada_*, expirada, liberada_para_circulacao, retirada_no_show. Spec v2 ajoute : lecteur peut transitionner retirada_agendada→re-retirada_agendada (contre-proposition). Contraintes dynamiques (flag biblio, compteur < 3) gérées par les wrappers api.* et non par ce helper SQL pur.';

COMMIT;

-- =============================================================================
-- Validation post-migration
-- =============================================================================
-- Lancer ces requêtes APRÈS la migration pour vérifier qu'elle s'est bien
-- appliquée. Toutes doivent retourner les valeurs attendues.
--
-- Q1. Vérifier que les nouvelles colonnes existent dans reserva_item_workflow_v2
-- SELECT column_name, data_type, column_default
--   FROM information_schema.columns
--   WHERE table_name = 'reserva_item_workflow_v2'
--     AND column_name IN ('pickup_proposed_by', 'negotiation_iteration_count')
--   ORDER BY column_name;
-- Attendu : 2 lignes
--
-- Q2. Vérifier que les nouvelles colonnes existent dans library_notification_policies
-- SELECT column_name, data_type, column_default
--   FROM information_schema.columns
--   WHERE table_name = 'library_notification_policies'
--     AND column_name IN ('reservation_allow_reader_counter_proposal', 'reservation_negotiation_timeout_days')
--   ORDER BY column_name;
-- Attendu : 2 lignes
--
-- Q3. Vérifier que les contraintes CHECK existent
-- SELECT conname, conrelid::regclass, contype
--   FROM pg_constraint
--   WHERE conname IN (
--     'chk_pickup_proposed_by',
--     'chk_negotiation_iteration_max',
--     'chk_negotiation_timeout'
--   );
-- Attendu : 3 lignes (toutes contype='c')
--
-- Q4. Vérifier que la nouvelle règle de transition est active
-- SELECT public.fn_check_workflow_transition('retirada_agendada', 're-retirada_agendada', 'lecteur');
-- Attendu : true
-- (avant la migration, retournait false)
--
-- SELECT public.fn_check_workflow_transition('re-retirada_agendada', 're-retirada_agendada', 'lecteur');
-- Attendu : true
-- (avant la migration, retournait false)
--
-- Q5. Vérifier que les anciennes règles fonctionnent toujours (non-régression)
-- SELECT public.fn_check_workflow_transition('solicitada', 'em_preparacao', 'librarian');
-- Attendu : true
--
-- SELECT public.fn_check_workflow_transition('retirada_efetivada', 'em_preparacao', 'librarian');
-- Attendu : false (état terminal)
--
-- SELECT public.fn_check_workflow_transition('solicitada', 'retirada_efetivada', 'lecteur');
-- Attendu : false (lecteur ne peut faire que cancelada_leitor + contre-proposition)
-- =============================================================================
