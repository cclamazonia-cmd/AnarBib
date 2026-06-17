-- ═══════════════════════════════════════════════════════════════════════════
-- Correctif — revérification COMPLÈTE de l'éligibilité circulation au
-- RENOUVELLEMENT (fn_v2_extend_core)
-- ───────────────────────────────────────────────────────────────────────────
-- Session : Audit 360 — correctifs P0
-- Auteur  : AnarBib (assist. Claude)
-- Réf     : Audit 360° du 17/06/2026, §6.1 / point P0 n°2.
--
-- PROBLÈME
--   Le gate cotisation/appartenance est un trigger BEFORE INSERT
--   (fn_enforce_membership_circulation_gate) : il protège la CRÉATION d'un prêt
--   mais pas son RENOUVELLEMENT, qui est un UPDATE. Le cœur fn_v2_extend_core
--   ne revérifiait QUE les impayés (fn_is_loan_blocked_by_dues), pas
--   l'appartenance active ni la restriction. Conséquence : un membre RESTREINT
--   ou dont l'appartenance n'est plus ACTIVE pouvait prolonger un prêt en cours
--   (par lui-même OU via le staff), alors qu'il serait bloqué à la création.
--   Les 4 chemins (fn_renew_my_loan, fn_renew_my_loan_item,
--   fn_v2_extend_emprestimo_once, fn_v2_extend_emprestimo_item_once) délèguent
--   tous à ce cœur ; seul fn_v2_extend_core écrit extended_until → corriger le
--   cœur corrige tout, sans bypass.
--
-- CORRECTIF
--   Remplacer le contrôle « impayés seuls » par un appel unique à
--   public.fn_membership_can_engage_circulation(user_id, library_id), qui
--   couvre déjà les trois conditions (appartenance active, restriction, ET
--   impayés — sa condition 4 appelle fn_is_loan_blocked_by_dues). Miroir exact
--   du gate BEFORE INSERT.
--
-- COMPATIBILITÉ
--   Le reason 'dues_blocked' est PRÉSERVÉ pour le cas impayés (front inchangé).
--   Deux nouveaux reasons 'no_active_membership' et 'restricted' sont renvoyés
--   pour les deux autres cas (mapping i18n côté front = suivi séparé).
--
-- Corps repris VERBATIM de la définition LIVE (= phase 1b du 20260529181000 +
-- patch notify du 20260530090000) ; SEULES changent la déclaration de variable
-- et le bloc de contrôle d'éligibilité (signalés par « ← FIX » ci-dessous).
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_v2_extend_core(
  p_emprestimo_id bigint,
  p_line_nos integer[] DEFAULT NULL,
  p_require_self_only boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_header public.emprestimos_v2%ROWTYPE;
  v_actor public.my_access%ROWTYPE;
  v_is_self boolean := false;
  v_block text;                       -- ← FIX : remplace v_dues_blocked boolean
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

  -- ← FIX : revérification COMPLÈTE de l'éligibilité à la circulation, en miroir
  -- exact du gate BEFORE INSERT (fn_enforce_membership_circulation_gate) :
  -- appartenance ACTIVE, absence de RESTRICTION, ET cotisation à jour. Auparavant
  -- seuls les impayés étaient revérifiés ici (le renouvellement est un UPDATE, non
  -- couvert par le trigger d'INSERT) → un membre restreint ou inactif pouvait
  -- prolonger un prêt qu'il ne pourrait pas créer. fn_membership_can_engage_-
  -- circulation englobe déjà le test des impayés (sa condition 4), donc cet appel
  -- unique remplace l'ancien fn_is_loan_blocked_by_dues.
  v_block := public.fn_membership_can_engage_circulation(v_header.user_id, v_header.library_id);
  IF v_block = 'dues' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'dues_blocked');
  ELSIF v_block = 'no_active_membership' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_active_membership');
  ELSIF v_block = 'restricted' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'restricted');
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
    PERFORM public.fn_dispatch_notify_event(
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
$function$;

-- Verrouillage des privilèges d'exécution (préserve l'ACL existante :
-- authenticated + service_role ; jamais anon/PUBLIC).
REVOKE EXECUTE ON FUNCTION public.fn_v2_extend_core(bigint, integer[], boolean) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_v2_extend_core(bigint, integer[], boolean) TO authenticated, service_role;

-- ── Vérifications (RAISE EXCEPTION = auto-rollback) ──────────────────────────
DO $$
DECLARE
  v_def text;
  v_anon_on_core boolean;
BEGIN
  -- 1. La revérification d'éligibilité est bien présente dans le nouveau corps.
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'fn_v2_extend_core'
    AND pg_get_function_identity_arguments(p.oid)
        = 'p_emprestimo_id bigint, p_line_nos integer[], p_require_self_only boolean';

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'fix extend_core : fn_v2_extend_core(bigint, integer[], boolean) introuvable apres remplacement';
  END IF;
  IF position('fn_membership_can_engage_circulation' IN v_def) = 0 THEN
    RAISE EXCEPTION 'fix extend_core : la reverification d''eligibilite (fn_membership_can_engage_circulation) est absente du nouveau corps';
  END IF;

  -- 2. anon ne doit PAS avoir EXECUTE sur le cœur.
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routine_privileges
    WHERE routine_schema = 'public' AND routine_name = 'fn_v2_extend_core'
      AND grantee = 'anon' AND privilege_type = 'EXECUTE'
  ) INTO v_anon_on_core;
  IF v_anon_on_core THEN
    RAISE EXCEPTION 'fix extend_core : anon ne doit pas avoir EXECUTE sur fn_v2_extend_core';
  END IF;

  RAISE NOTICE 'fix extend_core OK : reverification membership en place, grants conformes.';
END $$;
