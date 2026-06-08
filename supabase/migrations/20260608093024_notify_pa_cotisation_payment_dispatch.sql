-- ============================================================================
-- #NOTIFY-Painel-acts — Famille 1 (cotisation) : notification du membre au
-- paiement de contribution.
-- ----------------------------------------------------------------------------
-- Auteur  : Claude (Opus 4.8) pour Xavier Van Welden
-- Session : Audit #NOTIFY-Painel-acts
-- Date    : 2026-06-08 (UTC 20260608093024)
-- ----------------------------------------------------------------------------
-- (1) Nouvelle colonne de politique `cotisation_payment_mail_enabled` (défaut
--     ON) — souveraineté biblio, NOTIF-PA2 ; lue directement par le handler EF.
-- (2) `fn_record_membership_payment` émet désormais l'event
--     'cotisation_payment_recorded' (best-effort) après l'insert, pour que l'EF
--     notify-event envoie le reçu au membre (DOC-NOTIF-1 : le membre, pas le
--     staff). record_id factice = 1 (l'EF exige > 0) ; l'uuid du paiement passe
--     en extra. Corps de la fonction préservé à l'identique, seul le PERFORM de
--     dispatch est ajouté.
-- Débloqué par la clôture de #110 (Resend). Déploiement : EF d'abord, migration
-- ensuite (assuré par l'ordre du pipeline Woodpecker).
-- ============================================================================

-- (1) Politique biblio --------------------------------------------------------
ALTER TABLE public.library_notification_policies
  ADD COLUMN IF NOT EXISTS cotisation_payment_mail_enabled boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.library_notification_policies.cotisation_payment_mail_enabled IS
  '#NOTIFY-Painel-acts : envoyer au membre le reçu e-mail au paiement de contribution (NOTIF-PA2, défaut ON, configurable par la biblio).';

-- (2) Dispatch de l''event au paiement ----------------------------------------
CREATE OR REPLACE FUNCTION public.fn_record_membership_payment(
  p_user_id uuid,
  p_rule_id uuid,
  p_amount_paid numeric,
  p_payment_method membership_payment_method DEFAULT 'cash'::membership_payment_method,
  p_paid_at timestamp with time zone DEFAULT now(),
  p_notes text DEFAULT NULL::text,
  p_valid_from date DEFAULT NULL::date,
  p_valid_until date DEFAULT NULL::date)
 RETURNS TABLE(ok boolean, payment_id uuid, valid_from date, valid_until date, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_rule public.library_membership_rules%rowtype;
  v_user_belongs boolean;
  v_computed_from date;
  v_computed_until date;
  v_final_from date;
  v_final_until date;
  v_payment_id uuid;
BEGIN
  -- Authentification
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  -- Droits staff (administrador ou coordenador)
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;

  IF COALESCE(v_actor.can_access_painel, false) IS false THEN
    RAISE EXCEPTION 'Acesso bibliotecário obrigatório.';
  END IF;

  IF v_actor.library_id IS NULL THEN
    RAISE EXCEPTION 'Biblioteca ativa não identificada.';
  END IF;

  -- La règle existe et appartient à la bibliothèque active
  SELECT * INTO v_rule
  FROM public.library_membership_rules
  WHERE id = p_rule_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Regra de contribuição não encontrada.';
  END IF;

  IF v_rule.library_id <> v_actor.library_id THEN
    RAISE EXCEPTION 'Esta regra pertence a outra biblioteca.';
  END IF;

  IF NOT v_rule.is_active THEN
    RAISE EXCEPTION 'Esta regra está desativada.';
  END IF;

  -- Validation : montant >= amount_min (sauf pour exemption et in_kind)
  IF p_payment_method NOT IN ('exemption', 'in_kind')
     AND p_amount_paid < v_rule.amount_min THEN
    RAISE EXCEPTION 'Valor pago (%) inferior ao mínimo da regra (%).',
      p_amount_paid, v_rule.amount_min;
  END IF;

  -- L'usager appartient à cette bibliothèque
  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = p_user_id
      AND library_id = v_actor.library_id
      AND status = 'active'
  ) INTO v_user_belongs;

  IF NOT v_user_belongs THEN
    RAISE EXCEPTION 'Este(a) leitor(a) não está vinculado(a) à biblioteca ativa.';
  END IF;

  -- Calcul de validité (si non fourni)
  SELECT cv.valid_from, cv.valid_until
    INTO v_computed_from, v_computed_until
  FROM public.fn_compute_membership_validity(p_rule_id, p_paid_at) cv;

  v_final_from  := COALESCE(p_valid_from,  v_computed_from);
  v_final_until := COALESCE(p_valid_until, v_computed_until);

  -- Insertion
  INSERT INTO public.membership_payments (
    user_id, library_id, rule_id,
    amount_paid, currency,
    paid_at, valid_from, valid_until,
    payment_method, notes,
    recorded_by
  ) VALUES (
    p_user_id, v_actor.library_id, p_rule_id,
    p_amount_paid, v_rule.currency,
    p_paid_at, v_final_from, v_final_until,
    p_payment_method, p_notes,
    auth.uid()
  )
  RETURNING id INTO v_payment_id;

  -- #NOTIFY-Painel-acts : reçu au membre (best-effort ; fn_dispatch_notify_event
  -- avale ses propres erreurs et ne casse jamais l'enregistrement du paiement).
  PERFORM public.fn_dispatch_notify_event(
    'cotisation_payment_recorded',
    1,
    jsonb_build_object('payment_id', v_payment_id::text)
  );

  RETURN QUERY
  SELECT true,
         v_payment_id,
         v_final_from,
         v_final_until,
         format('Contribuição registrada com sucesso para o período de %s a %s.',
                v_final_from,
                COALESCE(v_final_until::text, '∞'));
END $function$;

-- Grants préservés (authenticated + service_role ; pas d'anon) + REVOKE PUBLIC
-- (doctrine objets backend / garde-fou pre-commit).
REVOKE EXECUTE ON FUNCTION public.fn_record_membership_payment(uuid, uuid, numeric, membership_payment_method, timestamptz, text, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_record_membership_payment(uuid, uuid, numeric, membership_payment_method, timestamptz, text, date, date) TO authenticated, service_role;
