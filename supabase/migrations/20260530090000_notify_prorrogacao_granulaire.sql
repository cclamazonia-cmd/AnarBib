-- Migration : notification de prorrogação granulaire (#NOTIFY-prorrogacao, étape 2)
-- 29/05/2026 — Émet la notification de prorrogation PAR ACTION (portant les
-- line_nos effectivement renouvelés) depuis fn_v2_extend_core, et retire le
-- trigger header trg_notify_emprestimo_prorrogacao qui ne tirait qu'une fois
-- par lot (MAX des compteurs), sans contexte item, et datait le mail sur
-- l'échéance header jamais mise à jour.
-- L'Edge Function notify-event (déjà déployée, étape 1) lit payload.line_nos
-- et affiche extended_until par item (liste « titre — date »).
-- Doctrine : fichier appliqué par Woodpecker (supabase db push --linked).
-- Le trigger trg_sync_header_renewals (affichage) reste en place.

CREATE OR REPLACE FUNCTION public.fn_v2_extend_core(p_emprestimo_id bigint, p_line_nos integer[] DEFAULT NULL::integer[], p_require_self_only boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_header public.emprestimos_v2%ROWTYPE;
  v_actor public.my_access%ROWTYPE;
  v_is_self boolean := false;
  v_dues_blocked boolean := false;
  v_item record;
  v_rule record;
  v_renewed jsonb := '[]'::jsonb;
  v_skipped jsonb := '[]'::jsonb;
  v_has_reservation boolean;
  v_new_due date;
  v_extension_note text;
  v_any_renewed boolean := false;
  v_first_new_due date := NULL;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  SELECT * INTO v_header FROM public.emprestimos_v2 WHERE id = p_emprestimo_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  -- Circulation activée ?
  IF NOT public.fn_library_has_circulation(v_header.library_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'circulation_disabled');
  END IF;

  -- Autorisation : self toujours OK ; staff de la bibliothèque OK sauf si
  -- p_require_self_only (cas renew_my_loan, réservé au propriétaire).
  v_is_self := (v_header.user_id = auth.uid());
  IF p_require_self_only THEN
    IF NOT v_is_self THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
    END IF;
  ELSE
    IF NOT v_is_self THEN
      SELECT * INTO v_actor FROM public.my_access LIMIT 1;
      IF NOT (COALESCE(v_actor.can_access_painel, false) IS true
              AND v_actor.library_id = v_header.library_id) THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
      END IF;
    END IF;
  END IF;

  -- Blocage par cotisations dues ?
  v_dues_blocked := public.fn_is_loan_blocked_by_dues(v_header.user_id, v_header.library_id);
  IF v_dues_blocked THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'dues_blocked');
  END IF;

  v_extension_note := CASE WHEN v_is_self THEN 'renewal_by_reader' ELSE 'renewal_by_library' END;

  -- Boucle par item ouvert ciblé. p_line_nos NULL = tous les items ouverts.
  FOR v_item IN
    SELECT i.line_no, i.book_id, i.holding_id,
           COALESCE(i.renewals_used, 0) AS renewals_used,
           COALESCE(i.extended_until, i.due_at) AS current_due
    FROM public.emprestimo_itens_v2 i
    WHERE i.emprestimo_id = p_emprestimo_id
      AND i.item_status = 'aberto'
      AND (p_line_nos IS NULL OR i.line_no = ANY(p_line_nos))
    ORDER BY i.line_no
  LOOP
    -- En retard → non renouvelable
    IF COALESCE(v_item.current_due, CURRENT_DATE) < CURRENT_DATE THEN
      v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'overdue');
      CONTINUE;
    END IF;

    -- Réservé par un autre lecteur (sur le book_id de cet item)
    SELECT EXISTS (
      SELECT 1
        FROM public.reserva_linhas_v2 rl
        JOIN public.reservas_v2 r ON r.id = rl.reserva_id
       WHERE rl.book_id = v_item.book_id
         AND r.library_id = v_header.library_id
         AND r.user_id <> v_header.user_id
         AND r.status_global IN ('ativa', 'parcialmente_encerrada')
         AND rl.item_status = 'ativa'
    ) INTO v_has_reservation;
    IF v_has_reservation THEN
      v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'reserved_by_other');
      CONTINUE;
    END IF;

    -- Règle de renouvellement, évaluée pour CET item (quantity=1, son propre compteur)
    SELECT * INTO v_rule
    FROM api.get_due_date_after_renewal(
      p_library_id := v_header.library_id,
      p_user_id := v_header.user_id,
      p_book_id := v_item.book_id,
      p_holding_id := v_item.holding_id,
      p_quantity := 1,
      p_current_due_date := GREATEST(COALESCE(v_item.current_due, CURRENT_DATE), CURRENT_DATE),
      p_renewals_used := v_item.renewals_used,
      p_as_of_date := CURRENT_DATE
    )
    LIMIT 1;

    IF v_rule IS NULL OR v_rule.new_due_date IS NULL THEN
      v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'not_renewable');
      CONTINUE;
    END IF;
    IF COALESCE(v_rule.renewable, false) IS false THEN
      IF COALESCE(v_rule.renewals_remaining, 0) <= 0 AND v_item.renewals_used > 0 THEN
        v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'quota_exceeded');
      ELSE
        v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'not_renewable');
      END IF;
      CONTINUE;
    END IF;
    IF v_item.renewals_used >= 1 AND COALESCE(v_rule.renewals_remaining, 0) <= 0 THEN
      v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'already_extended');
      CONTINUE;
    END IF;

    -- Appliquer l'extension sur cet item. Le trigger trg_sync_header_renewals
    -- (phase 1a) resynchronise emprestimos_v2.renewals_used = MAX(items ouverts).
    v_new_due := v_rule.new_due_date;
    UPDATE public.emprestimo_itens_v2
       SET extended_until = v_new_due,
           renewals_used = renewals_used + 1,
           extension_note = COALESCE(NULLIF(v_rule.explanation, ''), v_extension_note),
           return_schedule_status = 'emprestimo_prorrogado',
           return_scheduled_for = NULL,
           return_scheduled_by = NULL,
           return_scheduled_at = NULL,
           return_completed_at = NULL,
           return_missed_at = NULL,
           updated_at = now()
     WHERE emprestimo_id = p_emprestimo_id
       AND line_no = v_item.line_no;

    v_renewed := v_renewed || jsonb_build_object('line_no', v_item.line_no, 'new_due_date', v_new_due);
    v_any_renewed := true;
    IF v_first_new_due IS NULL THEN v_first_new_due := v_new_due; END IF;
  END LOOP;

  -- Aucun item ciblé trouvé (ni renouvelé ni ignoré) → emprunt/ligne inexistant
  IF jsonb_array_length(v_renewed) = 0 AND jsonb_array_length(v_skipped) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  -- Marqueur d'extension sur le header (le compteur est géré par le trigger).
  IF v_any_renewed THEN
    UPDATE public.emprestimos_v2
       SET extended_at = now(), updated_at = now()
     WHERE id = p_emprestimo_id;

    -- #NOTIFY-prorrogacao (B, 29/05/2026) : emission PAR ACTION portant les
    -- line_nos effectivement renouveles. Remplace le trigger header (retire
    -- dans cette migration) qui ne tirait qu'une fois par lot, sans contexte item.
    PERFORM public.fn_dispatch_circulation_notify_event(
      'emprestimo_v2_prorrogado',
      p_emprestimo_id,
      jsonb_build_object(
        'line_nos',
        (SELECT array_agg((e->>'line_no')::int ORDER BY (e->>'line_no')::int)
           FROM jsonb_array_elements(v_renewed) e)
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', v_any_renewed,
    'reason', CASE WHEN v_any_renewed THEN 'renewed'
                   ELSE COALESCE(v_skipped->0->>'reason', 'not_renewable') END,
    'new_due_date', v_first_new_due,
    'renewed', v_renewed,
    'skipped', v_skipped
  );
END;
$function$


-- Retrait du trigger header devenu redondant (l'émission a lieu dans le cœur RPC).
DROP TRIGGER IF EXISTS trg_notify_emprestimo_prorrogacao ON public.emprestimos_v2;
DROP FUNCTION IF EXISTS public.trg_notify_emprestimo_prorrogacao();

-- Vérification en fin de transaction (RAISE EXCEPTION => rollback de la migration).
DO $verify$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger
     WHERE tgname = 'trg_notify_emprestimo_prorrogacao' AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION '[#NOTIFY-prorrogacao] trigger header non retiré';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'trg_notify_emprestimo_prorrogacao'
  ) THEN
    RAISE EXCEPTION '[#NOTIFY-prorrogacao] fonction trigger non retirée';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'fn_v2_extend_core'
       AND pg_get_functiondef(p.oid) LIKE '%fn_dispatch_circulation_notify_event%'
  ) THEN
    RAISE EXCEPTION '[#NOTIFY-prorrogacao] dispatch absent de fn_v2_extend_core';
  END IF;
  RAISE NOTICE '[#NOTIFY-prorrogacao] migration OK : trigger header retiré, dispatch présent dans le cœur.';
END
$verify$;
