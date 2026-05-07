-- =============================================================================
-- Migration : Workflow réservation — Phase 2 helper (matrice de transitions)
-- Date      : 2026-05-07
-- Spec      : docs/specs/spec-workflow-reservation.md section 4
-- =============================================================================
-- Helper SQL pur encodant la matrice de transitions autorisées du workflow
-- de réservation. Consommé par les wrappers api.* qui suivront.
--
-- Acteurs encodés :
--   'lecteur'      : annulation à tout moment avant retirada_efetivada
--   'librarian'    : transitions opérationnelles (bibliothécaire)
--   'coordenador'  : tout ce qu'un librarian fait + cancelada_biblioteca
--   'system'       : cron (expirada, retirada_no_show automatique)
--                  + trigger (liberada_para_circulacao, hors helper)
--
-- Notes d'implémentation :
--   - Alias 'nao_retirada' normalisé en 'retirada_no_show' en entrée
--   - Pas de règle générique f=t→false : la boucle re-retirada_agendada→
--     re-retirada_agendada est explicitement autorisée (refus créneau lecteur)
--   - retirada_efetivada autorisée dans le helper depuis pronta_para_retirada,
--     mais c'est api.confirm_pickup_v1 qui DOIT être utilisé (api.advance
--     rejettera la cible)
--   - liberada_para_circulacao : émise uniquement par trigger, hors helper
--   - expirada : réservée à 'system', un coordenador doit utiliser
--     cancelada_biblioteca avec raison "Délai dépassé" pour le cas équivalent
--
-- Validé par 14 tests d'acceptation (cf. SESSION_2026-05-07.md section 4).
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
  -- après refus lecteur, cf. spec section 4)
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
  'Helper SQL pur encodant la matrice de transitions autorisées du workflow de réservation (cf. spec-workflow-reservation.md section 4). Retourne true si la transition (from→to) est autorisée pour l''actor_role donné. Acteurs : lecteur, librarian, coordenador, system. Alias nao_retirada normalisé. États terminaux : retirada_efetivada, cancelada_*, expirada, liberada_para_circulacao, retirada_no_show.';
