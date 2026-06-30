-- =========================================================================
-- Paquet DEPOT-GARANTIE (tournant) — dépôt unique par lecteur·rice
-- =========================================================================
-- Date     : 2026-06-30
-- Chantier : dépôt de garantie — dépôt « tournant » (spec §11, retenu)
-- Réf      : 20260630082753 (couche) + 104743 (fix status) + 154441 (plafonds)
--
-- Un dépôt TOURNANT = un dépôt unique par couple (lecteur·rice, biblio) qui
-- couvre tous les emprunts successifs, au lieu d'un dépôt par emprunt. On
-- réutilise loan_deposits : un dépôt tournant = une ligne avec emprestimo_id
-- NULL (lié à user_id+library_id, pas à un emprunt). Nouveau scope 'standing'.
--
-- Cycle : collecté une fois (fn_record_standing_deposit, dérive user/biblio de
-- l'emprunt en cours au comptoir) ; remboursable SEULEMENT quand la personne
-- n'a plus aucun emprunt en cours ; rétention perte/dégât comme avant. Les
-- rapports / /conta / plafond par lecteur·rice regroupent déjà par personne →
-- réutilisés tels quels.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Élargir le scope des règles à 'standing'
-- -------------------------------------------------------------------------
ALTER TABLE public.library_deposit_rules DROP CONSTRAINT IF EXISTS library_deposit_rules_scope_check;
ALTER TABLE public.library_deposit_rules
  ADD CONSTRAINT library_deposit_rules_scope_check CHECK (scope IN ('per_item', 'per_loan', 'standing'));

-- -------------------------------------------------------------------------
-- 2. loan_deposits : emprestimo_id nullable (NULL = dépôt tournant)
-- -------------------------------------------------------------------------
ALTER TABLE public.loan_deposits ALTER COLUMN emprestimo_id DROP NOT NULL;
-- Cohérence : un exemplaire suppose un emprunt (pas d'item sans emprunt).
ALTER TABLE public.loan_deposits DROP CONSTRAINT IF EXISTS loan_deposits_item_needs_loan_chk;
ALTER TABLE public.loan_deposits
  ADD CONSTRAINT loan_deposits_item_needs_loan_chk CHECK (emprestimo_item_id IS NULL OR emprestimo_id IS NOT NULL);
COMMENT ON COLUMN public.loan_deposits.emprestimo_id IS
  'Emprunt couvert. NULL = dépôt tournant (lié au couple lecteur·rice/biblio, couvre tous les emprunts successifs). Paquet dépôt tournant 30/06/2026.';

-- -------------------------------------------------------------------------
-- 3. fn_record_standing_deposit — collecte du dépôt tournant
--    (dérive user/biblio de l'emprunt au comptoir ; emprestimo_id NULL stocké)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_record_standing_deposit(
  p_emprestimo_id bigint,
  p_rule_id       uuid DEFAULT NULL,
  p_amount        numeric DEFAULT NULL,
  p_method        public.membership_payment_method DEFAULT 'cash',
  p_notes         text DEFAULT NULL
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
  v_cap      numeric(10,2);
  v_held     numeric(10,2);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF COALESCE(v_actor.can_access_painel, false) IS false THEN
    RAISE EXCEPTION 'painel_access_required' USING ERRCODE = '42501';
  END IF;

  SELECT library_id, user_id INTO v_lib, v_user
  FROM public.emprestimos_v2 WHERE id = p_emprestimo_id;
  IF v_lib IS NULL THEN
    RAISE EXCEPTION 'emprestimo_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_actor.library_id IS DISTINCT FROM v_lib THEN
    RAISE EXCEPTION 'not_staff_of_loan_library' USING ERRCODE = '42501';
  END IF;

  -- Anti-double : un seul dépôt tournant détenu par personne/biblio.
  IF EXISTS (
    SELECT 1 FROM public.loan_deposits ld
    WHERE ld.user_id = v_user AND ld.library_id = v_lib
      AND ld.emprestimo_id IS NULL AND ld.status = 'detenu'
  ) THEN
    RAISE EXCEPTION 'standing_deposit_already_held' USING ERRCODE = '22023';
  END IF;

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

  IF p_method = 'exemption' THEN
    v_amount := 0;
  ELSE
    v_amount := COALESCE(p_amount, v_rule.amount);
    IF v_amount IS NULL THEN
      RAISE EXCEPTION 'amount_required' USING ERRCODE = '22023';
    END IF;
    IF p_method <> 'in_kind' AND v_amount <= 0 THEN
      RAISE EXCEPTION 'amount_must_be_positive' USING ERRCODE = '22023';
    END IF;
  END IF;

  -- Plafond par lecteur·rice (le tournant EST le cumul ; check par cohérence).
  IF v_amount > 0 THEN
    SELECT deposit_cap_per_reader INTO v_cap FROM public.libraries WHERE id = v_lib;
    IF v_cap IS NOT NULL THEN
      SELECT COALESCE(SUM(ld.amount), 0) INTO v_held
      FROM public.loan_deposits ld
      WHERE ld.user_id = v_user AND ld.library_id = v_lib AND ld.status = 'detenu';
      IF v_held + v_amount > v_cap THEN
        RAISE EXCEPTION 'deposit_cap_reached' USING ERRCODE = '22023';
      END IF;
    END IF;
  END IF;

  INSERT INTO public.loan_deposits (
    user_id, library_id, emprestimo_id, emprestimo_item_id, rule_id,
    amount, currency, collected_method, recorded_by, status, notes
  ) VALUES (
    v_user, v_lib, NULL, NULL, p_rule_id,
    v_amount, v_currency, p_method, auth.uid(), 'detenu', p_notes
  )
  RETURNING id INTO v_id;

  -- record_id factice (1) : dépôt tournant non lié à un emprunt ; deposit_id en payload.
  PERFORM public.fn_dispatch_notify_event(
    'deposit_collected', 1, jsonb_build_object('deposit_id', v_id::text)
  );

  RETURN QUERY SELECT true, v_id, 'detenu'::public.deposit_status, 'deposit_recorded'::text;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_record_standing_deposit(bigint, uuid, numeric, public.membership_payment_method, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_record_standing_deposit(bigint, uuid, numeric, public.membership_payment_method, text) TO authenticated;
COMMENT ON FUNCTION public.fn_record_standing_deposit(bigint, uuid, numeric, public.membership_payment_method, text) IS
  'Dépôt tournant : collecte d''un dépôt unique par personne/biblio (emprestimo_id NULL). Paquet dépôt tournant 30/06/2026.';

-- -------------------------------------------------------------------------
-- 4. fn_refund_deposit — ré-émise : garde « emprunts en cours » pour le
--    tournant + record_id non nul au dispatch (COALESCE).
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_refund_deposit(
  p_deposit_id      uuid,
  p_refunded_method public.membership_payment_method DEFAULT 'cash',
  p_refunded_amount numeric DEFAULT NULL,
  p_notes           text DEFAULT NULL
)
RETURNS TABLE(ok boolean, status public.deposit_status, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_actor  public.my_access%rowtype;
  v_dep    public.loan_deposits%rowtype;
  v_amount numeric(10,2);
  v_status public.deposit_status;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF COALESCE(v_actor.can_access_painel, false) IS false THEN
    RAISE EXCEPTION 'painel_access_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_dep FROM public.loan_deposits WHERE id = p_deposit_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'deposit_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_actor.library_id IS DISTINCT FROM v_dep.library_id THEN
    RAISE EXCEPTION 'not_staff_of_loan_library' USING ERRCODE = '42501';
  END IF;
  IF v_dep.status <> 'detenu' THEN
    RAISE EXCEPTION 'deposit_not_held' USING ERRCODE = '22023',
      HINT = 'ce dépôt est déjà soldé (remboursé ou retenu).';
  END IF;

  -- Dépôt tournant (emprestimo_id NULL) : remboursement bloqué tant qu'il reste
  -- des emprunts en cours (on garde la garantie jusqu'au dernier retour).
  IF v_dep.emprestimo_id IS NULL AND EXISTS (
    SELECT 1 FROM public.emprestimos_v2 e
    WHERE e.user_id = v_dep.user_id AND e.library_id = v_dep.library_id
      AND e.status_global IN ('aberto', 'parcialmente_devolvido')
      AND e.archived_at IS NULL
  ) THEN
    RAISE EXCEPTION 'standing_deposit_has_open_loans' USING ERRCODE = '22023',
      HINT = 'rembourse le dépôt tournant une fois tous les emprunts rendus.';
  END IF;

  v_amount := COALESCE(p_refunded_amount, v_dep.amount);
  IF v_amount <= 0 THEN
    RAISE EXCEPTION 'refund_must_be_positive' USING ERRCODE = '22023',
      HINT = 'pour ne rien rendre (perte/dégât), utilise fn_retain_deposit.';
  END IF;
  IF v_amount > v_dep.amount THEN
    RAISE EXCEPTION 'refund_exceeds_amount' USING ERRCODE = '22023';
  END IF;

  v_status := CASE WHEN v_amount = v_dep.amount THEN 'rembourse' ELSE 'partiel' END;

  IF v_status = 'partiel' AND NULLIF(btrim(COALESCE(p_notes, '')), '') IS NULL THEN
    RAISE EXCEPTION 'partial_refund_reason_required' USING ERRCODE = '22023',
      HINT = 'un remboursement partiel exige une note justifiant la part retenue.';
  END IF;

  UPDATE public.loan_deposits
  SET status           = v_status,
      refunded_at      = now(),
      refunded_amount  = v_amount,
      refunded_method  = p_refunded_method,
      refunded_by      = auth.uid(),
      retention_reason = CASE WHEN v_status = 'partiel' THEN p_notes ELSE retention_reason END,
      notes            = COALESCE(p_notes, notes)
  WHERE id = p_deposit_id;

  PERFORM public.fn_dispatch_notify_event(
    'deposit_refunded', COALESCE(v_dep.emprestimo_id, 1),
    jsonb_build_object('deposit_id', p_deposit_id::text)
  );

  RETURN QUERY SELECT true, v_status, 'deposit_refunded'::text;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_refund_deposit(uuid, public.membership_payment_method, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_refund_deposit(uuid, public.membership_payment_method, numeric, text) TO authenticated;

-- -------------------------------------------------------------------------
-- 5. fn_retain_deposit — ré-émise : record_id non nul au dispatch (COALESCE).
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_retain_deposit(
  p_deposit_id            uuid,
  p_retention_reason      text,
  p_partial_refund_amount numeric DEFAULT NULL,
  p_refunded_method       public.membership_payment_method DEFAULT 'cash'
)
RETURNS TABLE(ok boolean, status public.deposit_status, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_actor  public.my_access%rowtype;
  v_dep    public.loan_deposits%rowtype;
  v_refund numeric(10,2);
  v_status public.deposit_status;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF COALESCE(v_actor.can_access_painel, false) IS false THEN
    RAISE EXCEPTION 'painel_access_required' USING ERRCODE = '42501';
  END IF;
  IF NULLIF(btrim(COALESCE(p_retention_reason, '')), '') IS NULL THEN
    RAISE EXCEPTION 'retention_reason_required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_dep FROM public.loan_deposits WHERE id = p_deposit_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'deposit_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_actor.library_id IS DISTINCT FROM v_dep.library_id THEN
    RAISE EXCEPTION 'not_staff_of_loan_library' USING ERRCODE = '42501';
  END IF;
  IF v_dep.status <> 'detenu' THEN
    RAISE EXCEPTION 'deposit_not_held' USING ERRCODE = '22023';
  END IF;

  v_refund := COALESCE(p_partial_refund_amount, 0);
  IF v_refund < 0 OR v_refund >= v_dep.amount THEN
    RAISE EXCEPTION 'partial_refund_out_of_range' USING ERRCODE = '22023',
      HINT = 'le remboursement partiel doit être ≥ 0 et < montant ; pour tout rendre, utilise fn_refund_deposit.';
  END IF;

  v_status := CASE WHEN v_refund > 0 THEN 'partiel' ELSE 'retenu' END;

  UPDATE public.loan_deposits
  SET status           = v_status,
      retention_reason = p_retention_reason,
      refunded_at      = CASE WHEN v_refund > 0 THEN now() ELSE NULL END,
      refunded_amount  = CASE WHEN v_refund > 0 THEN v_refund ELSE NULL END,
      refunded_method  = CASE WHEN v_refund > 0 THEN p_refunded_method ELSE NULL END,
      refunded_by      = CASE WHEN v_refund > 0 THEN auth.uid() ELSE NULL END
  WHERE id = p_deposit_id;

  IF v_refund > 0 THEN
    PERFORM public.fn_dispatch_notify_event(
      'deposit_refunded', COALESCE(v_dep.emprestimo_id, 1),
      jsonb_build_object('deposit_id', p_deposit_id::text)
    );
  END IF;

  RETURN QUERY SELECT true, v_status, 'deposit_retained'::text;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_retain_deposit(uuid, text, numeric, public.membership_payment_method) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_retain_deposit(uuid, text, numeric, public.membership_payment_method) TO authenticated;

-- -------------------------------------------------------------------------
-- 6. fn_standing_deposit_for_loan — dépôt tournant de l'emprunteur·se (UI)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_standing_deposit_for_loan(p_emprestimo_id bigint)
RETURNS TABLE(
  deposit_id       uuid,
  amount           numeric,
  currency         text,
  status           public.deposit_status,
  collected_method public.membership_payment_method,
  collected_at     timestamptz,
  refunded_amount  numeric,
  refunded_at      timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT d.id, d.amount, d.currency, d.status, d.collected_method,
         d.collected_at, d.refunded_amount, d.refunded_at
  FROM public.loan_deposits d
  JOIN public.emprestimos_v2 e ON e.id = p_emprestimo_id
  WHERE d.user_id = e.user_id
    AND d.library_id = e.library_id
    AND d.emprestimo_id IS NULL
    AND d.archived_at IS NULL
    AND (e.user_id = auth.uid() OR public.user_can_engage_library(d.library_id))
  ORDER BY d.collected_at DESC
  LIMIT 1;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_standing_deposit_for_loan(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_standing_deposit_for_loan(bigint) TO authenticated;
COMMENT ON FUNCTION public.fn_standing_deposit_for_loan(bigint) IS
  'Dépôt tournant de l''emprunteur·se d''un emprunt (owner OU staff). Paquet dépôt tournant 30/06/2026.';

-- -------------------------------------------------------------------------
-- 7. Vérification
-- -------------------------------------------------------------------------
DO $$
DECLARE v_missing text := '';
BEGIN
  IF (SELECT pg_get_constraintdef(c.oid) FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid
      JOIN pg_namespace n ON n.oid=t.relnamespace
      WHERE n.nspname='public' AND t.relname='library_deposit_rules' AND c.conname='library_deposit_rules_scope_check')
     NOT LIKE '%standing%' THEN
    v_missing := v_missing || ' scope-check-sans-standing';
  END IF;
  IF (SELECT a.attnotnull FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname='loan_deposits' AND a.attname='emprestimo_id') THEN
    v_missing := v_missing || ' emprestimo_id-encore-NOT-NULL';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='fn_record_standing_deposit') THEN
    v_missing := v_missing || ' fn:fn_record_standing_deposit';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='fn_standing_deposit_for_loan') THEN
    v_missing := v_missing || ' fn:fn_standing_deposit_for_loan';
  END IF;
  IF (SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname='fn_refund_deposit') !~ 'standing_deposit_has_open_loans' THEN
    v_missing := v_missing || ' fn_refund-sans-garde-tournant';
  END IF;
  IF v_missing <> '' THEN
    RAISE EXCEPTION 'Paquet DEPOT tournant : objets manquants ->%. Rollback.', v_missing;
  END IF;
  RAISE NOTICE 'Paquet DEPOT tournant : OK.';
END $$;

COMMIT;
