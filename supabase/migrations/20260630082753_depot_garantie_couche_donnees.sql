-- =========================================================================
-- Paquet DEPOT-GARANTIE (Phase 1) — couche données
-- =========================================================================
-- Date     : 2026-06-30
-- Chantier : dépôt de garantie remboursable par livre / par emprunt
-- Spec     : docs/specs/spec-depot-garantie.md (cadrage v0.1, DEPOT-0…DEPOT-10)
-- Auteur   : session « réflexion dépôt de garantie »
--
-- Crée la couche données (aucune UI ici) :
--   - enum public.deposit_status
--   - libraries.deposit_enabled (interrupteur maître, défaut false — DEPOT-1)
--   - library_notification_policies.deposit_receipt_mail_enabled (défaut true)
--   - public.library_deposit_rules (règles par biblio : scope per_item|per_loan)
--   - public.loan_deposits (registre : detenu/rembourse/retenu/partiel)
--   - fn_record_deposit / fn_refund_deposit / fn_retain_deposit (actes staff)
--   - fn_deposit_status_for_loan + api.fn_my_deposits_status (lecture)
--   - vue public.v_library_deposits (état dérivé : held/refunded/retained)
--
-- Doctrine : AnarBib = registre, jamais séquestre (DEPOT-0) → zéro donnée
-- bancaire stockée. Exemption de droit, montant 0 forcé (DEPOT-4). Réutilise
-- l'enum membership_payment_method des cotisations. Erreurs codées (i18n front
-- via panel.apiError.*), pas de prose en dur.
--
-- CHECKLIST DOCTRINE (CHANTIER_doctrine_creation_objets_securises_2026-05-12) :
--   [x] Fonctions SECURITY DEFINER : SET search_path = public, pg_catalog ;
--       REVOKE EXECUTE FROM PUBLIC ; GRANT EXECUTE TO authenticated.
--   [x] Tables public : GRANT explicites + ENABLE RLS + policies + GRANT ALL
--       service_role.
--   [x] Vue : WITH (security_invoker = true).
--   [x] DO block de vérification automatique en fin de transaction.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 0. Enum de statut
-- -------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'deposit_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.deposit_status AS ENUM ('detenu', 'rembourse', 'retenu', 'partiel');
  END IF;
END $$;

-- -------------------------------------------------------------------------
-- 1. Interrupteurs de configuration
-- -------------------------------------------------------------------------
ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS deposit_enabled boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.libraries.deposit_enabled IS
  'DEPOT-1 : interrupteur maître du dépôt de garantie. true = la biblio collecte une caution remboursable à l''emprunt (soft-gate + affichage /conta). Défaut false. Paquet DEPOT-GARANTIE Phase 1 du 30/06/2026.';

ALTER TABLE public.library_notification_policies
  ADD COLUMN IF NOT EXISTS deposit_receipt_mail_enabled boolean NOT NULL DEFAULT true;
COMMENT ON COLUMN public.library_notification_policies.deposit_receipt_mail_enabled IS
  'DEPOT §7 : envoi du reçu e-mail (collecte + remboursement) au membre. Défaut ON (calque cotisation_payment_mail_enabled). Paquet DEPOT-GARANTIE Phase 1.';

-- -------------------------------------------------------------------------
-- 2. Table public.library_deposit_rules (règles par biblio — DEPOT-6)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.library_deposit_rules (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id    uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  scope         text NOT NULL DEFAULT 'per_loan' CHECK (scope IN ('per_item', 'per_loan')),
  amount        numeric(10,2) NOT NULL CHECK (amount >= 0),
  currency      text NOT NULL DEFAULT 'EUR' CHECK (currency ~ '^[A-Z]{3}$'),
  refundable    boolean NOT NULL DEFAULT true,
  is_active     boolean NOT NULL DEFAULT true,
  name          text,
  description   text,
  display_order integer NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS library_deposit_rules_library_id_idx
  ON public.library_deposit_rules(library_id) WHERE is_active;

-- Scénario A : règles affichables (anon SELECT grant, mais RLS gate sur appartenance)
GRANT SELECT ON public.library_deposit_rules TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_deposit_rules TO authenticated;
GRANT ALL ON public.library_deposit_rules TO service_role;

ALTER TABLE public.library_deposit_rules ENABLE ROW LEVEL SECURITY;

-- Lecture : membre actif de la biblio OU staff (calque lmr_select).
DROP POLICY IF EXISTS library_deposit_rules_select ON public.library_deposit_rules;
CREATE POLICY library_deposit_rules_select
  ON public.library_deposit_rules
  FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
            WHERE m.user_id = (SELECT auth.uid())
              AND m.library_id = library_deposit_rules.library_id
              AND m.status = 'active')
    OR public.user_can_engage_library(library_id)
  );

-- Écriture : staff de la biblio (granularité coordenador gardée applicativement, comme les règles cotisation).
DROP POLICY IF EXISTS library_deposit_rules_modify ON public.library_deposit_rules;
CREATE POLICY library_deposit_rules_modify
  ON public.library_deposit_rules
  FOR ALL
  TO authenticated
  USING (public.user_can_engage_library(library_id))
  WITH CHECK (public.user_can_engage_library(library_id));

CREATE TRIGGER library_deposit_rules_set_updated_at
  BEFORE UPDATE ON public.library_deposit_rules
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.library_deposit_rules IS
  'DEPOT-6 : règles de dépôt de garantie par bibliothèque (gérées par coordenador). scope per_item|per_loan, montant fixe remboursable. Paquet DEPOT-GARANTIE Phase 1 du 30/06/2026.';

-- -------------------------------------------------------------------------
-- 3. Table public.loan_deposits (registre — DEPOT-0/2/3)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.loan_deposits (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  library_id         uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  emprestimo_id      bigint NOT NULL REFERENCES public.emprestimos_v2(id) ON DELETE CASCADE,
  emprestimo_item_id bigint REFERENCES public.emprestimo_itens_v2(id) ON DELETE SET NULL,
  rule_id            uuid REFERENCES public.library_deposit_rules(id) ON DELETE SET NULL,
  amount             numeric(10,2) NOT NULL CHECK (amount >= 0),
  currency           text NOT NULL DEFAULT 'EUR' CHECK (currency ~ '^[A-Z]{3}$'),
  collected_at       timestamptz NOT NULL DEFAULT now(),
  collected_method   public.membership_payment_method NOT NULL DEFAULT 'cash',
  recorded_by        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  status             public.deposit_status NOT NULL DEFAULT 'detenu',
  refunded_at        timestamptz,
  refunded_amount    numeric(10,2) CHECK (refunded_amount IS NULL OR refunded_amount >= 0),
  refunded_method    public.membership_payment_method,
  refunded_by        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  retention_reason   text,
  notes              text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  archived_at        timestamptz,
  archive_reason     text CHECK (archive_reason IS NULL OR archive_reason IN ('profile_transition', 'admin_manual', 'system_cleanup')),
  -- Cohérence statut ↔ montants/motif (les 4 chemins des fonctions ci-dessous).
  CONSTRAINT loan_deposits_status_chk CHECK (
    (status = 'detenu'    AND refunded_at IS NULL     AND refunded_amount IS NULL  AND retention_reason IS NULL) OR
    (status = 'rembourse' AND refunded_at IS NOT NULL AND refunded_amount = amount AND retention_reason IS NULL) OR
    (status = 'partiel'   AND refunded_at IS NOT NULL AND refunded_amount > 0 AND refunded_amount < amount AND retention_reason IS NOT NULL) OR
    (status = 'retenu'    AND refunded_at IS NULL     AND refunded_amount IS NULL  AND retention_reason IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS loan_deposits_emprestimo_id_idx ON public.loan_deposits(emprestimo_id);
CREATE INDEX IF NOT EXISTS loan_deposits_library_status_idx ON public.loan_deposits(library_id, status);
CREATE INDEX IF NOT EXISTS loan_deposits_user_id_idx ON public.loan_deposits(user_id);

-- Scénario B : table d'argent privée (authenticated uniquement ; anon AUCUN accès, comme membership_payments).
GRANT SELECT, INSERT, UPDATE, DELETE ON public.loan_deposits TO authenticated;
GRANT ALL ON public.loan_deposits TO service_role;

ALTER TABLE public.loan_deposits ENABLE ROW LEVEL SECURITY;

-- Lecture : le membre voit les siens.
DROP POLICY IF EXISTS loan_deposits_select_own ON public.loan_deposits;
CREATE POLICY loan_deposits_select_own
  ON public.loan_deposits
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- Lecture : le staff voit ceux de sa biblio.
DROP POLICY IF EXISTS loan_deposits_select_staff ON public.loan_deposits;
CREATE POLICY loan_deposits_select_staff
  ON public.loan_deposits
  FOR SELECT
  TO authenticated
  USING (public.user_can_engage_library(library_id));

-- Écriture : staff de la biblio (en pratique via les fonctions SECURITY DEFINER ci-dessous).
DROP POLICY IF EXISTS loan_deposits_modify_staff ON public.loan_deposits;
CREATE POLICY loan_deposits_modify_staff
  ON public.loan_deposits
  FOR ALL
  TO authenticated
  USING (public.user_can_engage_library(library_id))
  WITH CHECK (public.user_can_engage_library(library_id));

CREATE TRIGGER loan_deposits_set_updated_at
  BEFORE UPDATE ON public.loan_deposits
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.loan_deposits IS
  'DEPOT-0 : registre des dépôts de garantie. AnarBib trace (qui a versé quoi, état), ne séquestre jamais les fonds → zéro donnée bancaire. detenu→rembourse|retenu|partiel. Archivable (jamais de suppression dure hors RGPD). Paquet DEPOT-GARANTIE Phase 1 du 30/06/2026.';

-- -------------------------------------------------------------------------
-- 4. fn_record_deposit — collecte (acte staff, DEPOT-3/4)
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
  IF EXISTS (
    SELECT 1 FROM public.loan_deposits
    WHERE emprestimo_id = p_emprestimo_id
      AND emprestimo_item_id IS NOT DISTINCT FROM p_emprestimo_item_id
      AND status = 'detenu'
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
COMMENT ON FUNCTION public.fn_record_deposit(bigint, bigint, uuid, numeric, public.membership_payment_method, text) IS
  'DEPOT-3 : enregistre la collecte d''un dépôt (acte staff). exemption ⟹ montant 0 (DEPOT-4). Émet deposit_collected. Paquet DEPOT-GARANTIE Phase 1.';

-- -------------------------------------------------------------------------
-- 5. fn_refund_deposit — remboursement au retour (acte staff)
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

  v_amount := COALESCE(p_refunded_amount, v_dep.amount);
  IF v_amount <= 0 THEN
    RAISE EXCEPTION 'refund_must_be_positive' USING ERRCODE = '22023',
      HINT = 'pour ne rien rendre (perte/dégât), utilise fn_retain_deposit.';
  END IF;
  IF v_amount > v_dep.amount THEN
    RAISE EXCEPTION 'refund_exceeds_amount' USING ERRCODE = '22023';
  END IF;

  v_status := CASE WHEN v_amount = v_dep.amount THEN 'rembourse' ELSE 'partiel' END;

  -- Remboursement partiel ⟹ une note expliquant la part retenue est requise.
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
    'deposit_refunded', v_dep.emprestimo_id,
    jsonb_build_object('deposit_id', p_deposit_id::text)
  );

  RETURN QUERY SELECT true, v_status, 'deposit_refunded'::text;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_refund_deposit(uuid, public.membership_payment_method, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_refund_deposit(uuid, public.membership_payment_method, numeric, text) TO authenticated;
COMMENT ON FUNCTION public.fn_refund_deposit(uuid, public.membership_payment_method, numeric, text) IS
  'DEPOT-2 : rembourse un dépôt au retour (total = rembourse ; < montant = partiel, note requise). Émet deposit_refunded. Paquet DEPOT-GARANTIE Phase 1.';

-- -------------------------------------------------------------------------
-- 6. fn_retain_deposit — rétention pour perte/dégât (acte staff)
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
      'deposit_refunded', v_dep.emprestimo_id,
      jsonb_build_object('deposit_id', p_deposit_id::text)
    );
  END IF;

  RETURN QUERY SELECT true, v_status, 'deposit_retained'::text;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_retain_deposit(uuid, text, numeric, public.membership_payment_method) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_retain_deposit(uuid, text, numeric, public.membership_payment_method) TO authenticated;
COMMENT ON FUNCTION public.fn_retain_deposit(uuid, text, numeric, public.membership_payment_method) IS
  'DEPOT-2 : retient un dépôt (perte/dégât) — motif requis. Remboursement partiel optionnel (→ partiel). Paquet DEPOT-GARANTIE Phase 1.';

-- -------------------------------------------------------------------------
-- 7. fn_deposit_status_for_loan — lecture par emprunt (UI ; owner OU staff)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_deposit_status_for_loan(p_emprestimo_id bigint)
RETURNS TABLE(
  deposit_id         uuid,
  emprestimo_item_id bigint,
  amount             numeric,
  currency           text,
  status             public.deposit_status,
  collected_method   public.membership_payment_method,
  collected_at       timestamptz,
  refunded_amount    numeric,
  refunded_at        timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT d.id, d.emprestimo_item_id, d.amount, d.currency, d.status,
         d.collected_method, d.collected_at, d.refunded_amount, d.refunded_at
  FROM public.loan_deposits d
  JOIN public.emprestimos_v2 e ON e.id = d.emprestimo_id
  WHERE d.emprestimo_id = p_emprestimo_id
    AND d.archived_at IS NULL
    AND (e.user_id = auth.uid() OR public.user_can_engage_library(d.library_id))
  ORDER BY d.collected_at;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_deposit_status_for_loan(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_deposit_status_for_loan(bigint) TO authenticated;
COMMENT ON FUNCTION public.fn_deposit_status_for_loan(bigint) IS
  'DEPOT-5 : état des dépôts d''un emprunt (emprunteur·se OU staff de la biblio). Paquet DEPOT-GARANTIE Phase 1.';

-- -------------------------------------------------------------------------
-- 8. api.fn_my_deposits_status — lecture lectrice (tous ses dépôts)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_my_deposits_status()
RETURNS TABLE(
  deposit_id      uuid,
  library_id      uuid,
  emprestimo_id   bigint,
  amount          numeric,
  currency        text,
  status          public.deposit_status,
  collected_at    timestamptz,
  refunded_at     timestamptz,
  refunded_amount numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT d.id, d.library_id, d.emprestimo_id, d.amount, d.currency, d.status,
         d.collected_at, d.refunded_at, d.refunded_amount
  FROM public.loan_deposits d
  WHERE d.user_id = auth.uid() AND d.archived_at IS NULL
  ORDER BY d.collected_at DESC;
$function$;

REVOKE EXECUTE ON FUNCTION api.fn_my_deposits_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_my_deposits_status() TO authenticated;
COMMENT ON FUNCTION api.fn_my_deposits_status() IS
  'DEPOT §8 : dépôts de la lectrice authentifiée (bandeau /conta). Paquet DEPOT-GARANTIE Phase 1.';

-- -------------------------------------------------------------------------
-- 9. Vue public.v_library_deposits — état dérivé (rapports / conta)
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_library_deposits
WITH (security_invoker = true)
AS
  SELECT
    d.id AS deposit_id,
    d.library_id,
    d.user_id,
    d.emprestimo_id,
    d.emprestimo_item_id,
    d.amount,
    d.currency,
    d.status,
    d.collected_method,
    d.collected_at,
    d.refunded_amount,
    d.refunded_method,
    d.refunded_at,
    d.retention_reason,
    CASE WHEN d.status = 'detenu' THEN d.amount ELSE 0 END AS amount_held,
    CASE WHEN d.status = 'rembourse' THEN d.amount
         WHEN d.status = 'partiel'   THEN COALESCE(d.refunded_amount, 0)
         ELSE 0 END AS amount_refunded,
    CASE WHEN d.status = 'retenu'  THEN d.amount
         WHEN d.status = 'partiel' THEN d.amount - COALESCE(d.refunded_amount, 0)
         ELSE 0 END AS amount_retained
  FROM public.loan_deposits d
  WHERE d.archived_at IS NULL;

GRANT SELECT ON public.v_library_deposits TO authenticated;

COMMENT ON VIEW public.v_library_deposits IS
  'DEPOT-9 : état dérivé des dépôts (held/refunded/retained) pour rapports et /conta. security_invoker=true depuis sa création (RLS de loan_deposits appliquée). Paquet DEPOT-GARANTIE Phase 1 du 30/06/2026. Source : public.loan_deposits.';

-- -------------------------------------------------------------------------
-- 10. Vérification automatique (rollback si échec)
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_missing text := '';
BEGIN
  -- Enum
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'deposit_status' AND n.nspname = 'public') THEN
    v_missing := v_missing || ' enum:deposit_status';
  END IF;
  -- Colonnes de config
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public' AND table_name = 'libraries' AND column_name = 'deposit_enabled') THEN
    v_missing := v_missing || ' col:libraries.deposit_enabled';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public' AND table_name = 'library_notification_policies' AND column_name = 'deposit_receipt_mail_enabled') THEN
    v_missing := v_missing || ' col:lnp.deposit_receipt_mail_enabled';
  END IF;
  -- Tables + RLS
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE n.nspname = 'public' AND c.relname = 'library_deposit_rules' AND c.relrowsecurity) THEN
    v_missing := v_missing || ' table+rls:library_deposit_rules';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE n.nspname = 'public' AND c.relname = 'loan_deposits' AND c.relrowsecurity) THEN
    v_missing := v_missing || ' table+rls:loan_deposits';
  END IF;
  -- Au moins 1 policy par table
  IF (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'loan_deposits') < 3 THEN
    v_missing := v_missing || ' policies:loan_deposits<3';
  END IF;
  -- Fonctions
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.proname = 'fn_record_deposit') THEN
    v_missing := v_missing || ' fn:fn_record_deposit';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.proname = 'fn_refund_deposit') THEN
    v_missing := v_missing || ' fn:fn_refund_deposit';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.proname = 'fn_retain_deposit') THEN
    v_missing := v_missing || ' fn:fn_retain_deposit';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'api' AND p.proname = 'fn_my_deposits_status') THEN
    v_missing := v_missing || ' fn:api.fn_my_deposits_status';
  END IF;
  -- Vue
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE n.nspname = 'public' AND c.relname = 'v_library_deposits' AND c.relkind = 'v') THEN
    v_missing := v_missing || ' view:v_library_deposits';
  END IF;

  IF v_missing <> '' THEN
    RAISE EXCEPTION 'Paquet DEPOT-GARANTIE Phase 1 : objets manquants ->%. Rollback automatique.', v_missing;
  END IF;
  RAISE NOTICE 'Paquet DEPOT-GARANTIE Phase 1 : tous les objets créés (enum, 2 tables, 2 colonnes, 5 fonctions, 1 vue).';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé (à adapter en cas de régression post-déploiement) :
-- =========================================================================
-- BEGIN;
--   DROP VIEW IF EXISTS public.v_library_deposits;
--   DROP FUNCTION IF EXISTS api.fn_my_deposits_status();
--   DROP FUNCTION IF EXISTS public.fn_deposit_status_for_loan(bigint);
--   DROP FUNCTION IF EXISTS public.fn_retain_deposit(uuid, text, numeric, public.membership_payment_method);
--   DROP FUNCTION IF EXISTS public.fn_refund_deposit(uuid, public.membership_payment_method, numeric, text);
--   DROP FUNCTION IF EXISTS public.fn_record_deposit(bigint, bigint, uuid, numeric, public.membership_payment_method, text);
--   DROP TABLE IF EXISTS public.loan_deposits;
--   DROP TABLE IF EXISTS public.library_deposit_rules;
--   ALTER TABLE public.library_notification_policies DROP COLUMN IF EXISTS deposit_receipt_mail_enabled;
--   ALTER TABLE public.libraries DROP COLUMN IF EXISTS deposit_enabled;
--   DROP TYPE IF EXISTS public.deposit_status;
-- COMMIT;
-- =========================================================================
