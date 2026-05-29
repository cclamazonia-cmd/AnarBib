-- ═══════════════════════════════════════════════════════════════════════════
-- Renouvellement granulaire par item — PHASE 1b (bascule logique)
-- ───────────────────────────────────────────────────────────────────────────
-- Spec : docs/specs/spec-renouvellement-granulaire.md
-- Prérequis : phase 1a (colonne emprestimo_itens_v2.renewals_used + trigger
--             trg_sync_header_renewals) déjà appliquée.
--
-- CONTENU 1b :
--   1. fn_v2_extend_core : cœur factorisé, raisonne PAR ITEM. Le quota et la
--      nouvelle échéance sont évalués item par item ; un item inéligible est
--      ignoré et listé dans `skipped`, les autres sont étendus. Incrémente
--      emprestimo_itens_v2.renewals_used (le header est resynchronisé par le
--      trigger trg_sync_header_renewals de la phase 1a).
--   2. fn_v2_extend_emprestimo_once : réécrite en appelant du cœur (mode tous
--      items, self OU staff). Format de retour rétro-compatible {ok, reason,
--      new_due_date} + nouveaux champs {renewed, skipped}.
--   3. fn_renew_my_loan : réécrite en appelant du cœur (mode tous, self only).
--   4. fn_v2_extend_emprestimo_item_once : NOUVELLE, extension d'un item.
--   5. api.extend_loan_item_as_library : NOUVEAU wrapper (calqué sur
--      api.extend_loan_as_library, même contrôle d'action).
--
-- Validation préalable (29/05/2026) : la règle de renouvellement BLMF ne dépend
-- pas de la quantité (get_due_date_after_renewal donne le même résultat pour
-- p_quantity=1 et p_quantity=4) → le passage au traitement par item (quantity=1)
-- est iso-comportement pour la règle actuelle.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Cœur factorisé ───────────────────────────────────────────────────────
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

-- Verrouillage des privileges d'execution (bloc complet, juste apres la fonction)
REVOKE EXECUTE ON FUNCTION public.fn_v2_extend_core(bigint, integer[], boolean) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_v2_extend_core(bigint, integer[], boolean) TO authenticated, service_role;

-- ── 2. fn_v2_extend_emprestimo_once : réécrite en appelant du cœur ───────────
CREATE OR REPLACE FUNCTION public.fn_v2_extend_emprestimo_once(p_emprestimo_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'api'
AS $function$
BEGIN
  -- Mode « tous les items ouverts », autorisation self OU staff.
  RETURN public.fn_v2_extend_core(p_emprestimo_id, NULL, false);
END;
$function$;

-- Verrouillage des privileges d'execution (bloc complet, juste apres la fonction)
REVOKE EXECUTE ON FUNCTION public.fn_v2_extend_emprestimo_once(bigint) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_v2_extend_emprestimo_once(bigint) TO authenticated, service_role;

-- ── 3. fn_renew_my_loan : réécrite en appelant du cœur ───────────────────────
CREATE OR REPLACE FUNCTION public.fn_renew_my_loan(p_emprestimo_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'api'
AS $function$
BEGIN
  -- Mode « tous les items ouverts », autorisation propriétaire seul.
  RETURN public.fn_v2_extend_core(p_emprestimo_id, NULL, true);
END;
$function$;

-- Verrouillage des privileges d'execution (bloc complet, juste apres la fonction)
REVOKE EXECUTE ON FUNCTION public.fn_renew_my_loan(bigint) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_renew_my_loan(bigint) TO authenticated, service_role;

-- ── 4. fn_v2_extend_emprestimo_item_once : NOUVELLE (extension d'un item) ────
CREATE OR REPLACE FUNCTION public.fn_v2_extend_emprestimo_item_once(
  p_emprestimo_id bigint,
  p_line_no integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'api'
AS $function$
BEGIN
  -- Mode « un item », autorisation self OU staff (le cœur tranche).
  RETURN public.fn_v2_extend_core(p_emprestimo_id, ARRAY[p_line_no], false);
END;
$function$;

-- Verrouillage des privileges d'execution (bloc complet, juste apres la fonction)
REVOKE EXECUTE ON FUNCTION public.fn_v2_extend_emprestimo_item_once(bigint, integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_v2_extend_emprestimo_item_once(bigint, integer) TO authenticated, service_role;

-- ── 5. api.extend_loan_item_as_library : NOUVEAU wrapper ─────────────────────
-- Calqué sur api.extend_loan_as_library : mêmes contrôles (auth, contexte,
-- rôle, action 'extend_as_library'), puis délègue à la fonction par item.
CREATE OR REPLACE FUNCTION api.extend_loan_item_as_library(
  p_emprestimo_id bigint,
  p_line_no integer
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'loan_not_found' USING ERRCODE = 'P0001', HINT = format('Emprestimo %s nao encontrado.', p_emprestimo_id);
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('extend_as_library', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
  END IF;

  RETURN public.fn_v2_extend_emprestimo_item_once(p_emprestimo_id := p_emprestimo_id, p_line_no := p_line_no);
END;
$function$;

-- ── 7. Vérifications (RAISE EXCEPTION = auto-rollback) ───────────────────────
DO $$
DECLARE
  v_missing text;
  v_anon_on_core boolean;
  v_auth_on_item boolean;
BEGIN
  -- 7.1 Présence des 4 fonctions + wrapper
  SELECT string_agg(want.fqname, ', ') INTO v_missing
  FROM (
    SELECT unnest(ARRAY[
      'public.fn_v2_extend_core',
      'public.fn_v2_extend_emprestimo_once',
      'public.fn_renew_my_loan',
      'public.fn_v2_extend_emprestimo_item_once',
      'api.extend_loan_item_as_library'
    ]) AS fqname
  ) want
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname || '.' || p.proname = want.fqname
  );

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION '1b: fonction(s) manquante(s): %', v_missing;
  END IF;

  -- 7.2 anon ne doit PAS avoir EXECUTE sur le cœur
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routine_privileges
    WHERE routine_schema='public' AND routine_name='fn_v2_extend_core'
      AND grantee='anon' AND privilege_type='EXECUTE'
  ) INTO v_anon_on_core;
  IF v_anon_on_core THEN
    RAISE EXCEPTION '1b: anon ne doit pas avoir EXECUTE sur fn_v2_extend_core';
  END IF;

  -- 7.3 authenticated DOIT avoir EXECUTE sur la fonction par item
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routine_privileges
    WHERE routine_schema='public' AND routine_name='fn_v2_extend_emprestimo_item_once'
      AND grantee='authenticated' AND privilege_type='EXECUTE'
  ) INTO v_auth_on_item;
  IF NOT v_auth_on_item THEN
    RAISE EXCEPTION '1b: authenticated doit avoir EXECUTE sur fn_v2_extend_emprestimo_item_once';
  END IF;

  RAISE NOTICE '1b OK : 5 objets en place, grants conformes.';
END $$;
