-- ============================================================================
-- Paquet C.4b — Patches RPC renouvellement (fn_renew_my_loan + fn_v2_extend_emprestimo_once)
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.3
-- Dependance : paquetC2_helpers_modes_profils.sql (fn_library_has_circulation)
--
-- Objectif : ajouter check fn_library_has_circulation() apres chargement de
-- l'emprestimo, avant verifications metier (cotisation, retard, reserve).
--
-- Pattern de retour : ces 2 fonctions retournent jsonb {ok, reason}, donc
-- pas de RAISE EXCEPTION : on renvoie {ok: false, reason: 'circulation_disabled'}.
-- C'est conforme au style frontend qui sait deja parser ce format de reponse.
--
-- Point d'injection : juste apres SELECT v_header, avant v_dues_blocked (cotisation).
-- Coherence : si circulation off, inutile de verifier cotisation.
-- ============================================================================

BEGIN;

-- ===========================================================================
-- fn_renew_my_loan — renouvellement par le lecteur
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.fn_renew_my_loan(p_emprestimo_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_header public.emprestimos_v2%ROWTYPE;
  v_quantity int := 0;
  v_first_book_id bigint := NULL;
  v_first_holding_id bigint := NULL;
  v_current_due date := NULL;
  v_renewals_used int := 0;
  v_rule record;
  v_dues_blocked boolean := false;
  v_has_reservation boolean := false;
  v_new_due date;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  SELECT * INTO v_header
    FROM public.emprestimos_v2
   WHERE id = p_emprestimo_id AND user_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  -- ========================================================
  -- PAQUET C.4b — check circulation_mode <> off
  -- ========================================================
  IF NOT public.fn_library_has_circulation(v_header.library_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'circulation_disabled');
  END IF;

  v_dues_blocked := public.fn_is_loan_blocked_by_dues(v_user_id, v_header.library_id);
  IF v_dues_blocked THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'dues_blocked');
  END IF;

  SELECT COUNT(*)::int,
         MIN(i.book_id),
         MIN(i.holding_id),
         MAX(COALESCE(i.extended_until, i.due_at))
    INTO v_quantity, v_first_book_id, v_first_holding_id, v_current_due
    FROM public.emprestimo_itens_v2 i
   WHERE i.emprestimo_id = p_emprestimo_id
     AND i.item_status = 'aberto';

  IF COALESCE(v_quantity, 0) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  IF COALESCE(v_current_due, CURRENT_DATE) < CURRENT_DATE THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'overdue');
  END IF;

  SELECT EXISTS (
    SELECT 1
      FROM public.reserva_linhas_v2 rl
      JOIN public.reservas_v2 r ON r.id = rl.reserva_id
     WHERE rl.book_id = v_first_book_id
       AND r.library_id = v_header.library_id
       AND r.user_id <> v_user_id
       AND r.status_global IN ('ativa', 'parcialmente_encerrada')
       AND rl.item_status = 'ativa'
  ) INTO v_has_reservation;

  IF v_has_reservation THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'reserved_by_other');
  END IF;

  v_renewals_used := COALESCE(v_header.renewals_used, 0);

  SELECT *
    INTO v_rule
    FROM api.get_due_date_after_renewal(
      p_library_id := v_header.library_id,
      p_user_id := v_user_id,
      p_book_id := v_first_book_id,
      p_holding_id := v_first_holding_id,
      p_quantity := v_quantity,
      p_current_due_date := GREATEST(COALESCE(v_current_due, CURRENT_DATE), CURRENT_DATE),
      p_renewals_used := v_renewals_used,
      p_as_of_date := CURRENT_DATE
    )
    LIMIT 1;

  IF v_rule IS NOT NULL AND COALESCE(v_rule.renewable, false) IS false THEN
    IF COALESCE(v_rule.renewals_remaining, 0) <= 0 AND v_renewals_used > 0 THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'quota_exceeded');
    ELSE
      RETURN jsonb_build_object('ok', false, 'reason', 'not_renewable');
    END IF;
  END IF;

  IF v_rule.new_due_date IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_renewable');
  END IF;

  IF v_renewals_used >= 1
     AND COALESCE(v_rule.renewals_remaining, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_extended');
  END IF;

  v_new_due := v_rule.new_due_date;

  UPDATE public.emprestimo_itens_v2
     SET extended_until = v_new_due,
         extension_note = COALESCE(NULLIF(v_rule.explanation, ''), 'renewal_by_reader'),
         return_schedule_status = 'emprestimo_prorrogado',
         return_scheduled_for = NULL,
         return_scheduled_by = NULL,
         return_scheduled_at = NULL,
         return_completed_at = NULL,
         return_missed_at = NULL,
         updated_at = now()
   WHERE emprestimo_id = p_emprestimo_id
     AND item_status = 'aberto';

  UPDATE public.emprestimos_v2
     SET renewals_used = renewals_used + 1,
         extended_at = now(),
         updated_at = now()
   WHERE id = p_emprestimo_id;

  RETURN jsonb_build_object('ok', true, 'reason', 'renewed', 'new_due_date', v_new_due);
END;
$function$;

-- ===========================================================================
-- fn_v2_extend_emprestimo_once — extension par lecteur OU staff
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.fn_v2_extend_emprestimo_once(p_emprestimo_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_actor public.my_access%ROWTYPE;
  v_header public.emprestimos_v2%ROWTYPE;
  v_quantity int := 0;
  v_first_book_id bigint := NULL;
  v_first_holding_id bigint := NULL;
  v_current_due date := NULL;
  v_renewals_used int := 0;
  v_rule record;
  v_dues_blocked boolean := false;
  v_has_reservation boolean := false;
  v_new_due date;
  v_is_self boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  SELECT * INTO v_header
    FROM public.emprestimos_v2
   WHERE id = p_emprestimo_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  -- ========================================================
  -- PAQUET C.4b — check circulation_mode <> off
  -- ========================================================
  IF NOT public.fn_library_has_circulation(v_header.library_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'circulation_disabled');
  END IF;

  v_is_self := (v_header.user_id = auth.uid());
  IF NOT v_is_self THEN
    SELECT * INTO v_actor FROM public.my_access LIMIT 1;
    IF NOT (
      COALESCE(v_actor.can_access_painel, false) IS true
      AND v_actor.library_id = v_header.library_id
    ) THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
    END IF;
  END IF;

  v_dues_blocked := public.fn_is_loan_blocked_by_dues(v_header.user_id, v_header.library_id);
  IF v_dues_blocked THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'dues_blocked');
  END IF;

  SELECT COUNT(*)::int,
         MIN(i.book_id),
         MIN(i.holding_id),
         MAX(COALESCE(i.extended_until, i.due_at))
    INTO v_quantity, v_first_book_id, v_first_holding_id, v_current_due
    FROM public.emprestimo_itens_v2 i
   WHERE i.emprestimo_id = p_emprestimo_id
     AND i.item_status = 'aberto';

  IF COALESCE(v_quantity, 0) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  IF COALESCE(v_current_due, CURRENT_DATE) < CURRENT_DATE THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'overdue');
  END IF;

  SELECT EXISTS (
    SELECT 1
      FROM public.reserva_linhas_v2 rl
      JOIN public.reservas_v2 r ON r.id = rl.reserva_id
     WHERE rl.book_id = v_first_book_id
       AND r.library_id = v_header.library_id
       AND r.user_id <> v_header.user_id
       AND r.status_global IN ('ativa', 'parcialmente_encerrada')
       AND rl.item_status = 'ativa'
  ) INTO v_has_reservation;

  IF v_has_reservation THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'reserved_by_other');
  END IF;

  v_renewals_used := COALESCE(v_header.renewals_used, 0);

  SELECT *
    INTO v_rule
    FROM api.get_due_date_after_renewal(
      p_library_id := v_header.library_id,
      p_user_id := v_header.user_id,
      p_book_id := v_first_book_id,
      p_holding_id := v_first_holding_id,
      p_quantity := v_quantity,
      p_current_due_date := GREATEST(COALESCE(v_current_due, CURRENT_DATE), CURRENT_DATE),
      p_renewals_used := v_renewals_used,
      p_as_of_date := CURRENT_DATE
    )
    LIMIT 1;

  IF v_rule IS NOT NULL AND COALESCE(v_rule.renewable, false) IS false THEN
    IF COALESCE(v_rule.renewals_remaining, 0) <= 0 AND v_renewals_used > 0 THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'quota_exceeded');
    ELSE
      RETURN jsonb_build_object('ok', false, 'reason', 'not_renewable');
    END IF;
  END IF;

  IF v_rule.new_due_date IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_renewable');
  END IF;

  IF v_renewals_used >= 1
     AND COALESCE(v_rule.renewals_remaining, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_extended');
  END IF;

  v_new_due := v_rule.new_due_date;

  UPDATE public.emprestimo_itens_v2
     SET extended_until = v_new_due,
         extension_note = COALESCE(NULLIF(v_rule.explanation, ''),
                                    CASE WHEN v_is_self
                                         THEN 'renewal_by_reader'
                                         ELSE 'renewal_by_library' END),
         return_schedule_status = 'emprestimo_prorrogado',
         return_scheduled_for = NULL,
         return_scheduled_by = NULL,
         return_scheduled_at = NULL,
         return_completed_at = NULL,
         return_missed_at = NULL,
         updated_at = now()
   WHERE emprestimo_id = p_emprestimo_id
     AND item_status = 'aberto';

  UPDATE public.emprestimos_v2
     SET renewals_used = renewals_used + 1,
         extended_at = now(),
         updated_at = now()
   WHERE id = p_emprestimo_id;

  RETURN jsonb_build_object('ok', true, 'reason', 'renewed', 'new_due_date', v_new_due);
END;
$function$;

-- ---------------------------------------------------------------------------
-- DO block de verification fail-fast
-- ---------------------------------------------------------------------------
DO $verif$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_renew_my_loan', 'fn_v2_extend_emprestimo_once')
     AND pg_get_functiondef(p.oid) LIKE '%fn_library_has_circulation%';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'VERIF_FAIL : %/2 RPC renouvellement contiennent fn_library_has_circulation', v_count;
  END IF;

  RAISE NOTICE 'Paquet C.4b — Verification OK : 2 RPC renouvellement patchees';
END
$verif$;

COMMIT;
