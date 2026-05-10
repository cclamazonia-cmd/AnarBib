-- =====================================================================
-- AnarBib — Paquet 19 v2 (fix) : autoriser le staff a renouveler ses
-- propres emprunts via api.renew_my_loan
-- Date : 2026-05-11
--
-- Bug detecte : un coordenador/librarian/administrador qui est aussi
-- lecteur de sa propre biblio ne pouvait pas renouveler ses emprunts.
-- fn_resolve_caller_role_for_library retournait son role staff (plus
-- eleve que leitor), et fn_check_loan_action n'autorisait que leitor
-- pour l'action renew_as_reader.
--
-- Fix : autoriser tous les roles authentifies pour renew_as_reader.
-- L'ownership reste verifie dans le wrapper api.renew_my_loan
-- (v_ctx.leitor_user_id <> v_caller_uid).
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_check_loan_action(
  p_action text,
  p_current_status text,
  p_actor_role text
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_action text := lower(trim(coalesce(p_action, '')));
  v_status text := lower(trim(coalesce(p_current_status, '')));
  v_role text := lower(trim(coalesce(p_actor_role, '')));
  v_is_library boolean := v_role IN ('librarian', 'coordenador', 'administrador');
  v_is_reader boolean := v_role = 'leitor';
  v_is_system boolean := v_role = 'system';
  v_active_status boolean := v_status IN ('aberto', 'parcialmente_devolvido');
BEGIN
  IF v_action = '' OR v_role = '' THEN
    RETURN false;
  END IF;

  CASE v_action
    WHEN 'create_loan_at_counter' THEN
      RETURN v_is_library;

    WHEN 'return_total', 'return_partial', 'extend_as_library', 'mark_return_missed' THEN
      RETURN v_is_library AND v_active_status;

    -- Paquet 19 v2 (11/05/2026) : autoriser staff a renouveler leurs propres
    -- emprunts (l'ownership reste verifiee par le wrapper api.renew_my_loan).
    WHEN 'renew_as_reader' THEN
      RETURN (v_is_reader OR v_is_library) AND v_active_status;

    WHEN 'schedule_return', 'clear_return_schedule' THEN
      RETURN (v_is_library OR v_is_reader) AND v_active_status;

    WHEN 'mark_return_missed_by_system' THEN
      RETURN v_is_system AND v_active_status;

    ELSE
      RETURN false;
  END CASE;
END;
$$;

COMMENT ON FUNCTION public.fn_check_loan_action(text, text, text) IS
'Paquet 19 v2 (11/05/2026) : matrice action x acteur x statut pour les emprunts.
Equivalent emprunts du fn_check_workflow_transition pour les reservations.
Fix v2 : renew_as_reader autorise pour les staff aussi (ownership verifiee
dans le wrapper api.renew_my_loan).
Actions : create_loan_at_counter, return_total, return_partial,
extend_as_library, renew_as_reader, schedule_return, clear_return_schedule,
mark_return_missed, mark_return_missed_by_system.
Statuts : aberto, parcialmente_devolvido (actifs) ou null (creation).
Roles : leitor, librarian, coordenador, administrador, system.';

COMMIT;

-- Test post-deploiement :
-- SELECT public.fn_check_loan_action('renew_as_reader', 'aberto', 'leitor');       -- true
-- SELECT public.fn_check_loan_action('renew_as_reader', 'aberto', 'coordenador');  -- true (etait false avant)
-- SELECT public.fn_check_loan_action('renew_as_reader', 'aberto', 'system');       -- false (system ne renouvelle pas)
