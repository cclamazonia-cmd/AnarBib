-- =========================================================================
-- Paquet DEPOT-GARANTIE (fix) — lève l'ambiguïté « status » dans fn_record_deposit
-- =========================================================================
-- Date     : 2026-06-30
-- Chantier : dépôt de garantie — correctif post-CI
-- Réf      : migration 20260630082753_depot_garantie_couche_donnees.sql
--
-- BUG (révélé par la suite SQL en CI) : fn_record_deposit a un paramètre OUT
-- nommé « status » (RETURNS TABLE(... status ...)). Dans le check anti-double,
-- la condition « AND status = 'detenu' » était AMBIGUË entre ce paramètre OUT
-- et la colonne public.loan_deposits.status → erreur
--   « column reference "status" is ambiguous »
-- à chaque collecte, d'où l'échec en cascade de toute la suite (aucun dépôt
-- créé). Les fonctions refund/retain/status qualifiaient déjà leurs « status »
-- (v_dep.status, alias), elles ne sont pas concernées.
--
-- FIX : qualifier la colonne via un alias de table (ld.status) dans le check
-- anti-double. CREATE OR REPLACE conserve les grants existants ; on les
-- réaffirme par sécurité (doctrine objets sécurisés).
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_record_deposit(
  p_emprestimo_id      bigint,
  p_emprestimo_item_id bigint DEFAULT NULL,
  p_rule_id            uuid DEFAULT NULL,
  p_amount             numeric DEFAULT NULL,
  p_method             public.membership_payment_method DEFAULT 'cash',
  p_notes              text DEFAULT NULL
)
RETURNS TABLE(ok boolean, deposit_id uuid, status public.deposit_status, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_actor    public.my_access%rowtype;
  v_lib      uuid;
  v_user     uuid;
  v_rule     public.library_deposit_rules%rowtype;
  v_amount   numeric(10,2);
  v_currency text := 'EUR';
  v_id       uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF COALESCE(v_actor.can_access_painel, false) IS false THEN
    RAISE EXCEPTION 'painel_access_required' USING ERRCODE = '42501';
  END IF;

  -- L'emprunt existe : on en dérive biblio + emprunteur·se (anti-mismatch).
  SELECT library_id, user_id INTO v_lib, v_user
  FROM public.emprestimos_v2 WHERE id = p_emprestimo_id;
  IF v_lib IS NULL THEN
    RAISE EXCEPTION 'emprestimo_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_actor.library_id IS DISTINCT FROM v_lib THEN
    RAISE EXCEPTION 'not_staff_of_loan_library' USING ERRCODE = '42501';
  END IF;

  -- Item (scope per_item) : doit appartenir à l'emprunt.
  IF p_emprestimo_item_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.emprestimo_itens_v2
    WHERE id = p_emprestimo_item_id AND emprestimo_id = p_emprestimo_id
  ) THEN
    RAISE EXCEPTION 'item_not_in_loan' USING ERRCODE = '22023';
  END IF;

  -- Anti-double : un dépôt déjà détenu pour ce périmètre (emprunt/item) bloque.
  -- FIX : colonne « status » qualifiée (ld.status) pour lever l'ambiguïté avec
  -- le paramètre OUT « status » de la fonction.
  IF EXISTS (
    SELECT 1 FROM public.loan_deposits ld
    WHERE ld.emprestimo_id = p_emprestimo_id
      AND ld.emprestimo_item_id IS NOT DISTINCT FROM p_emprestimo_item_id
      AND ld.status = 'detenu'
  ) THEN
    RAISE EXCEPTION 'deposit_already_held' USING ERRCODE = '22023';
  END IF;

  -- Règle optionnelle : doit appartenir à la biblio + active ; fournit montant/devise par défaut.
  IF p_rule_id IS NOT NULL THEN
    SELECT * INTO v_rule FROM public.library_deposit_rules WHERE id = p_rule_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'deposit_rule_not_found' USING ERRCODE = '02000';
    END IF;
    IF v_rule.library_id <> v_lib THEN
      RAISE EXCEPTION 'deposit_rule_other_library' USING ERRCODE = '22023';
    END IF;
    IF NOT v_rule.is_active THEN
      RAISE EXCEPTION 'deposit_rule_inactive' USING ERRCODE = '22023';
    END IF;
    v_currency := v_rule.currency;
  END IF;

  -- Montant : exemption ⟹ 0 forcé (DEPOT-4) ; sinon montant fourni ou montant de la règle.
  IF p_method = 'exemption' THEN
    v_amount := 0;
  ELSE
    v_amount := COALESCE(p_amount, v_rule.amount);
    IF v_amount IS NULL THEN
      RAISE EXCEPTION 'amount_required' USING ERRCODE = '22023';
    END IF;
    IF p_method <> 'in_kind' AND v_amount <= 0 THEN
      RAISE EXCEPTION 'amount_must_be_positive' USING ERRCODE = '22023',
        HINT = 'un dépôt réel exige un montant > 0 ; pour dispenser, utilise la méthode « exemption ».';
    END IF;
  END IF;

  INSERT INTO public.loan_deposits (
    user_id, library_id, emprestimo_id, emprestimo_item_id, rule_id,
    amount, currency, collected_method, recorded_by, status, notes
  ) VALUES (
    v_user, v_lib, p_emprestimo_id, p_emprestimo_item_id, p_rule_id,
    v_amount, v_currency, p_method, auth.uid(), 'detenu', p_notes
  )
  RETURNING id INTO v_id;

  -- Reçu de collecte (best-effort ; fn_dispatch_notify_event avale ses erreurs).
  PERFORM public.fn_dispatch_notify_event(
    'deposit_collected', p_emprestimo_id,
    jsonb_build_object('deposit_id', v_id::text)
  );

  RETURN QUERY SELECT true, v_id, 'detenu'::public.deposit_status, 'deposit_recorded'::text;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_record_deposit(bigint, bigint, uuid, numeric, public.membership_payment_method, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_record_deposit(bigint, bigint, uuid, numeric, public.membership_payment_method, text) TO authenticated;

-- Vérification : la condition ambiguë « AND status = 'detenu' » (sans alias) ne
-- doit plus exister dans la définition.
DO $$
BEGIN
  IF (
    SELECT pg_get_functiondef(p.oid)
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_record_deposit'
  ) ~ 'AND status = ''detenu''' THEN
    RAISE EXCEPTION 'DEPOT-FIX : status encore ambigu (alias non appliqué). Rollback.';
  END IF;
  RAISE NOTICE 'DEPOT-FIX : ambiguïté status levée dans fn_record_deposit.';
END $$;

COMMIT;
