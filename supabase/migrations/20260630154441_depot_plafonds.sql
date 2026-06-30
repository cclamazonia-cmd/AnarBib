-- =========================================================================
-- Paquet DEPOT-GARANTIE (plafonds) — anti-barrière
-- =========================================================================
-- Date     : 2026-06-30
-- Chantier : dépôt de garantie — plafonds (spec §11)
-- Réf      : 20260630082753 (couche données) + 20260630104743 (fix status)
--
-- Deux garde-fous « anti-barrière », opt-in par biblio (NULL = pas de limite) :
--   1) libraries.deposit_cap_per_reader — plafond du CUMUL des dépôts DÉTENUS
--      d'une même personne dans la biblio. fn_record_deposit refuse une collecte
--      qui ferait dépasser ce cumul (deposit_cap_reached) → le prêt se fait sans
--      dépôt supplémentaire (protège des cautions qui s'empilent).
--   2) libraries.deposit_max_per_rule — borne haute du montant qu'une règle de
--      dépôt peut fixer. Trigger BEFORE INS/UPD sur library_deposit_rules
--      (deposit_rule_exceeds_max).
--
-- fn_record_deposit est ré-émise (CREATE OR REPLACE) avec le check de cumul,
-- en conservant le fix d'ambiguïté status (alias ld.status).
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Colonnes de plafond (NULL = illimité)
-- -------------------------------------------------------------------------
ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS deposit_cap_per_reader numeric(10,2)
    CHECK (deposit_cap_per_reader IS NULL OR deposit_cap_per_reader >= 0);
COMMENT ON COLUMN public.libraries.deposit_cap_per_reader IS
  'DEPOT plafonds : cumul max des dépôts détenus par lecteur·rice dans la biblio (anti-barrière). NULL = illimité. Paquet plafonds 30/06/2026.';

ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS deposit_max_per_rule numeric(10,2)
    CHECK (deposit_max_per_rule IS NULL OR deposit_max_per_rule >= 0);
COMMENT ON COLUMN public.libraries.deposit_max_per_rule IS
  'DEPOT plafonds : montant max qu''une règle de dépôt peut fixer (garde-fou config). NULL = illimité. Paquet plafonds 30/06/2026.';

-- -------------------------------------------------------------------------
-- 2. fn_record_deposit — + plafond cumul par lecteur·rice (garde fix status)
-- -------------------------------------------------------------------------
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

  IF p_emprestimo_item_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.emprestimo_itens_v2
    WHERE id = p_emprestimo_item_id AND emprestimo_id = p_emprestimo_id
  ) THEN
    RAISE EXCEPTION 'item_not_in_loan' USING ERRCODE = '22023';
  END IF;

  -- Anti-double (status qualifié via ld pour lever l'ambiguïté avec l'OUT param).
  IF EXISTS (
    SELECT 1 FROM public.loan_deposits ld
    WHERE ld.emprestimo_id = p_emprestimo_id
      AND ld.emprestimo_item_id IS NOT DISTINCT FROM p_emprestimo_item_id
      AND ld.status = 'detenu'
  ) THEN
    RAISE EXCEPTION 'deposit_already_held' USING ERRCODE = '22023';
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
      RAISE EXCEPTION 'amount_must_be_positive' USING ERRCODE = '22023',
        HINT = 'un dépôt réel exige un montant > 0 ; pour dispenser, utilise la méthode « exemption ».';
    END IF;
  END IF;

  -- Plafond cumul par lecteur·rice (anti-barrière) : si configuré, la somme des
  -- dépôts DÉTENUS de la personne + ce dépôt ne doit pas dépasser le plafond.
  -- Les exemptions / dépôts à 0 ne comptent pas (v_amount = 0).
  IF v_amount > 0 THEN
    SELECT deposit_cap_per_reader INTO v_cap FROM public.libraries WHERE id = v_lib;
    IF v_cap IS NOT NULL THEN
      SELECT COALESCE(SUM(ld.amount), 0) INTO v_held
      FROM public.loan_deposits ld
      WHERE ld.user_id = v_user AND ld.library_id = v_lib AND ld.status = 'detenu';
      IF v_held + v_amount > v_cap THEN
        RAISE EXCEPTION 'deposit_cap_reached' USING ERRCODE = '22023',
          HINT = format('cumul détenu (%s) + ce dépôt (%s) dépasserait le plafond de %s.', v_held, v_amount, v_cap);
      END IF;
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

  PERFORM public.fn_dispatch_notify_event(
    'deposit_collected', p_emprestimo_id,
    jsonb_build_object('deposit_id', v_id::text)
  );

  RETURN QUERY SELECT true, v_id, 'detenu'::public.deposit_status, 'deposit_recorded'::text;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_record_deposit(bigint, bigint, uuid, numeric, public.membership_payment_method, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_record_deposit(bigint, bigint, uuid, numeric, public.membership_payment_method, text) TO authenticated;

-- -------------------------------------------------------------------------
-- 3. Trigger : borne haute du montant par règle (deposit_max_per_rule)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_deposit_rule_max()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_max numeric(10,2);
BEGIN
  SELECT deposit_max_per_rule INTO v_max FROM public.libraries WHERE id = NEW.library_id;
  IF v_max IS NOT NULL AND NEW.amount > v_max THEN
    RAISE EXCEPTION 'deposit_rule_exceeds_max' USING ERRCODE = '22023',
      HINT = format('le montant (%s) dépasse le plafond par règle de la biblio (%s).', NEW.amount, v_max);
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS library_deposit_rules_max_check ON public.library_deposit_rules;
CREATE TRIGGER library_deposit_rules_max_check
  BEFORE INSERT OR UPDATE ON public.library_deposit_rules
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_deposit_rule_max();

COMMENT ON FUNCTION public.fn_trg_deposit_rule_max() IS
  'DEPOT plafonds : refuse une règle de dépôt dont le montant dépasse libraries.deposit_max_per_rule. Paquet plafonds 30/06/2026.';

-- -------------------------------------------------------------------------
-- 4. Vérification
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_missing text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='libraries' AND column_name='deposit_cap_per_reader') THEN
    v_missing := v_missing || ' col:deposit_cap_per_reader';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='libraries' AND column_name='deposit_max_per_rule') THEN
    v_missing := v_missing || ' col:deposit_max_per_rule';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
                 WHERE n.nspname='public' AND c.relname='library_deposit_rules' AND t.tgname='library_deposit_rules_max_check') THEN
    v_missing := v_missing || ' trigger:library_deposit_rules_max_check';
  END IF;
  IF (SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname='fn_record_deposit') !~ 'deposit_cap_reached' THEN
    v_missing := v_missing || ' fn:cap-check-absent';
  END IF;
  IF v_missing <> '' THEN
    RAISE EXCEPTION 'Paquet DEPOT plafonds : objets manquants ->%. Rollback.', v_missing;
  END IF;
  RAISE NOTICE 'Paquet DEPOT plafonds : OK (2 colonnes, cap dans fn_record_deposit, trigger max par règle).';
END $$;

COMMIT;
