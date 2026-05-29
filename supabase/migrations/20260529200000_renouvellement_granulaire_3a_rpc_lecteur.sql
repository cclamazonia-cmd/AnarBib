-- ═══════════════════════════════════════════════════════════════════════════
-- Renouvellement granulaire par item — PHASE 3a (RPC lecteur par item)
-- ───────────────────────────────────────────────────────────────────────────
-- Spec : docs/specs/spec-renouvellement-granulaire.md
-- Prérequis : phases 1a, 1b, 2 appliquées.
--
-- Pendant lecteur de fn_v2_extend_emprestimo_item_once, mais en mode self-only :
-- un lecteur ne renouvelle qu'un item d'un emprunt qui lui appartient.
-- Calque api.renew_my_loan pour les contrôles (auth, ownership, action).
-- ═══════════════════════════════════════════════════════════════════════════

-- Fonction de fond : délègue au cœur (un item, self-only).
CREATE OR REPLACE FUNCTION public.fn_renew_my_loan_item(p_emprestimo_id bigint, p_line_no integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'api'
AS $function$
BEGIN
  RETURN public.fn_v2_extend_core(p_emprestimo_id, ARRAY[p_line_no], true);
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_renew_my_loan_item(bigint, integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_renew_my_loan_item(bigint, integer) TO authenticated, service_role;

-- Wrapper api.* (non-DEFINER) : contrôles calqués sur api.renew_my_loan.
CREATE OR REPLACE FUNCTION api.renew_my_loan_item(p_emprestimo_id bigint, p_line_no integer)
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

  -- Ownership : un lecteur ne renouvelle que ses propres emprunts.
  IF v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'not_your_loan' USING ERRCODE = '42501', HINT = 'Voce so pode renovar seus proprios emprestimos.';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('renew_as_reader', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
  END IF;

  RETURN public.fn_renew_my_loan_item(p_emprestimo_id := p_emprestimo_id, p_line_no := p_line_no);
END;
$function$;

-- Vérifications (RAISE EXCEPTION = auto-rollback)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
                 WHERE n.nspname='public' AND p.proname='fn_renew_my_loan_item') THEN
    RAISE EXCEPTION 'phase3a: public.fn_renew_my_loan_item absente';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
                 WHERE n.nspname='api' AND p.proname='renew_my_loan_item') THEN
    RAISE EXCEPTION 'phase3a: api.renew_my_loan_item absente';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.routine_privileges
             WHERE routine_schema='public' AND routine_name='fn_renew_my_loan_item'
               AND grantee='anon' AND privilege_type='EXECUTE') THEN
    RAISE EXCEPTION 'phase3a: anon ne doit pas avoir EXECUTE sur fn_renew_my_loan_item';
  END IF;
  RAISE NOTICE 'phase3a OK : fn + wrapper en place.';
END $$;