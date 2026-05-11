-- =====================================================================
-- AnarBib — Phase 1 spec consultations — livrable 1 : helpers
-- =====================================================================
-- Fichier : supabase/migrations/20260512120000_consulta_helpers.sql
-- Date    : 2026-05-12
-- Auteur  : Xavier (AnarBib)
--
-- Pose les deux helpers de la spec §5.2 et §9 :
--   1) fn_check_consulta_transition(p_from, p_to, p_actor_role)
--      Pattern decalque de fn_check_workflow_transition (reservations).
--      SQL pur, IMMUTABLE PARALLEL SAFE, fail-closed sur NULL.
--   2) fn_get_consulta_context(p_consulta_id)
--      Pattern decalque de fn_get_loan_context (emprunts).
--      SQL STABLE, SECURITY INVOKER implicite (LANGUAGE sql sans SECURITY DEFINER).
--
-- Convention rolemap consultations (5 acteurs vs 4 sur reservations) :
--   leitor / librarian / coordenador / administrador / system
--   Staff = librarian + coordenador + administrador (les 3 du milieu).
--
-- Pas de RLS bypass : les helpers ne lisent pas de donnees protegees
-- au-dela de ce qui est deja accessible a authenticated via RLS.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) fn_check_consulta_transition
-- ---------------------------------------------------------------------
-- Matrice spec §5.2. Raisonne sur les 8 workflow_stages de
-- consulta_item_workflow_v2 (PAS sur les 5 item_status de
-- consulta_linhas_v2 — l'item_status est derive par le refresh global).
--
-- Stages :
--   solicitada / em_preparacao / consulta_agendada
--   consulta_realizada / nao_compareceu
--   cancelada_leitor / cancelada_biblioteca / expirada
--
-- Etats terminaux : consulta_realizada, cancelada_*, expirada
-- Etat "anormal" reclassable : nao_compareceu -> cancelada_biblioteca uniquement
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_check_consulta_transition(
  p_from text,
  p_to text,
  p_actor_role text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE PARALLEL SAFE
SET search_path TO 'public'
AS $function$
WITH normalized AS (
  SELECT
    p_from        AS f,
    p_to          AS t,
    p_actor_role  AS r
)
SELECT CASE
  -- ===== Garde-fou parametres (fail-closed) =====
  WHEN f IS NULL OR t IS NULL OR r IS NULL THEN false
  WHEN f = '' OR t = '' OR r = '' THEN false

  -- ===== Etats terminaux : aucune transition sortante =====
  WHEN f IN (
    'consulta_realizada',
    'cancelada_leitor',
    'cancelada_biblioteca',
    'expirada'
  ) THEN false

  -- ===== nao_compareceu : reclassement erreur biblio uniquement =====
  WHEN f = 'nao_compareceu' AND t = 'cancelada_biblioteca'
       AND r IN ('librarian', 'coordenador', 'administrador') THEN true
  WHEN f = 'nao_compareceu' THEN false

  -- ===== Lecteur·rice : annulation a tout moment avant terminal =====
  WHEN r = 'leitor' AND t = 'cancelada_leitor' AND f IN (
    'solicitada',
    'em_preparacao',
    'consulta_agendada'
  ) THEN true

  -- ===== Lecteur·rice : aucune autre transition autorisee =====
  WHEN r = 'leitor' THEN false

  -- ===== System (cron) : expiration des stages actifs =====
  WHEN r = 'system' AND t = 'expirada' AND f IN (
    'solicitada',
    'em_preparacao',
    'consulta_agendada'
  ) THEN true
  WHEN r = 'system' THEN false

  -- ===== Staff (librarian / coordenador / administrador) =====

  -- Depuis solicitada
  WHEN f = 'solicitada' AND t IN (
    'em_preparacao',
    'cancelada_biblioteca'
  ) AND r IN ('librarian', 'coordenador', 'administrador') THEN true

  -- Depuis em_preparacao
  WHEN f = 'em_preparacao' AND t IN (
    'consulta_agendada',
    'cancelada_biblioteca'
  ) AND r IN ('librarian', 'coordenador', 'administrador') THEN true

  -- Depuis consulta_agendada (re-proposition negociation + sorties)
  -- La boucle consulta_agendada -> consulta_agendada permet a la biblio de
  -- re-proposer un creneau apres refus ou contre-proposition lecteur.
  WHEN f = 'consulta_agendada' AND t IN (
    'consulta_agendada',
    'consulta_realizada',
    'nao_compareceu',
    'cancelada_biblioteca'
  ) AND r IN ('librarian', 'coordenador', 'administrador') THEN true

  -- ===== Tout le reste = refuse =====
  ELSE false
END
FROM normalized;
$function$;

COMMENT ON FUNCTION public.fn_check_consulta_transition(text, text, text) IS
'Helper matrice de transitions du workflow consultations locales (spec-flux-consultations §5.2). '
'Pattern decalque de fn_check_workflow_transition (reservations). '
'Raisonne sur les 8 workflow_stages de consulta_item_workflow_v2. '
'Fail-closed sur NULL ou valeurs vides. Roles : leitor / librarian / coordenador / administrador / system.';

GRANT EXECUTE ON FUNCTION public.fn_check_consulta_transition(text, text, text) TO authenticated;


-- ---------------------------------------------------------------------
-- 2) fn_get_consulta_context
-- ---------------------------------------------------------------------
-- Decalque exact de fn_get_loan_context :
--   - SQL STABLE
--   - Pas de SECURITY DEFINER (lecture via RLS de l'appelant)
--   - Renvoie le contexte minimal pour les wrappers api.* Phase 2
--
-- Renvoie une ligne vide (NULLs) si l'ID n'existe pas.
-- Utilisable en JOIN LATERAL.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_get_consulta_context(
  p_consulta_id bigint
)
RETURNS TABLE(
  library_id uuid,
  leitor_user_id uuid,
  status_global text
)
LANGUAGE sql
STABLE
AS $function$
  SELECT
    library_id,
    user_id        AS leitor_user_id,
    status_global
  FROM public.consultas_locais_v2
  WHERE id = p_consulta_id;
$function$;

COMMENT ON FUNCTION public.fn_get_consulta_context(bigint) IS
'Helper lookup contexte d''une demande de consultation locale (spec-flux-consultations §9). '
'Pattern decalque de fn_get_loan_context. SQL STABLE, SECURITY INVOKER implicite. '
'Renvoie library_id, user_id (alias leitor_user_id), status_global. '
'Renvoie une ligne avec NULLs si l''ID n''existe pas.';

GRANT EXECUTE ON FUNCTION public.fn_get_consulta_context(bigint) TO authenticated;


-- =====================================================================
-- Fin migration helpers consultations.
-- =====================================================================
