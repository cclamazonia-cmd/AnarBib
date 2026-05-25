-- Fix: fn_my_account_status — branche cotisation morte
--
-- Cause : la fonction testait les variables record v_profile et v_membership
-- avec IS NULL / IS NOT NULL. En PostgreSQL, "record IS NOT NULL" n'est vrai
-- que si TOUS les champs sont non-nuls ; le garde IF v_membership IS NOT NULL
-- devenait donc faux dès qu'une colonne nullable de user_library_memberships
-- valait NULL, et le bloc cotisation entier était sauté.
--
-- Correctif : capter FOUND après chaque SELECT INTO, tester des booléens.
-- Aucun autre changement de comportement.

CREATE OR REPLACE FUNCTION public.fn_my_account_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile record;
  v_membership record;
  v_has_profile boolean := false;
  v_has_membership boolean := false;
  v_overdue_count int;
  v_open_loans int;
  v_active_reservations int;
  v_status text;
  v_alerts jsonb := '[]'::jsonb;
  -- Cotisation (variables scalaires explicites, NULL par défaut)
  v_dues_status text := NULL;
  v_dues_valid_until date := NULL;
  v_dues_days_until_expiry int := NULL;
  v_membership_required boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('status', 'unknown', 'alerts', '[]'::jsonb);
  END IF;

  SELECT * INTO v_profile FROM profiles WHERE id = v_user_id;
  v_has_profile := FOUND;

  SELECT * INTO v_membership FROM user_library_memberships
   WHERE user_id = v_user_id AND is_primary = true AND status = 'active' LIMIT 1;
  v_has_membership := FOUND;

  -- Count overdue loans
  SELECT count(*) INTO v_overdue_count
  FROM emprestimos_v2 e JOIN emprestimo_itens_v2 ei ON ei.emprestimo_id = e.id
  WHERE e.user_id = v_user_id AND ei.item_status = 'aberto'
    AND COALESCE(ei.extended_until, ei.due_at) < CURRENT_DATE;

  SELECT count(*) INTO v_open_loans
  FROM emprestimos_v2 e JOIN emprestimo_itens_v2 ei ON ei.emprestimo_id = e.id
  WHERE e.user_id = v_user_id AND ei.item_status = 'aberto';

  SELECT count(*) INTO v_active_reservations
  FROM reservas_v2 WHERE user_id = v_user_id
    AND status_global IN ('ativa', 'parcialmente_encerrada');

  -- Cotisation : SELECT INTO sur variables scalaires (pas de RECORD)
  IF v_has_membership THEN
    SELECT dues_status, last_valid_until, days_until_expiry
      INTO v_dues_status, v_dues_valid_until, v_dues_days_until_expiry
    FROM v_active_memberships
    WHERE user_id = v_user_id AND library_id = v_membership.library_id;
    -- Si pas trouvé, les 3 variables restent NULL (déjà initialisées)

    SELECT EXISTS (
      SELECT 1 FROM library_membership_rules
      WHERE library_id = v_membership.library_id
        AND is_active = true AND is_required = true
    ) INTO v_membership_required;
  END IF;

  -- Determine status (priorité : restricted > overdue > dues_expired > attention > active)
  IF NOT v_has_profile OR NOT v_has_membership THEN
    v_status := 'incomplete';
    v_alerts := v_alerts || jsonb_build_object('level','warn','message_key','account.alert.incomplete');
  ELSIF v_profile.is_restricted THEN
    v_status := 'restricted';
    v_alerts := v_alerts || jsonb_build_object('level','danger','message_key','account.alert.restricted','reason', COALESCE(v_profile.restricted_reason, ''));
  ELSIF v_overdue_count > 0 THEN
    v_status := 'attention';
    v_alerts := v_alerts || jsonb_build_object('level','danger','message_key','account.alert.overdue','count', v_overdue_count);
  ELSIF v_dues_status = 'expired' AND v_membership_required THEN
    v_status := 'attention';
    v_alerts := v_alerts || jsonb_build_object('level','danger','message_key','membership.alert.expired');
  ELSIF v_dues_status = 'never_paid' AND v_membership_required THEN
    v_status := 'attention';
    v_alerts := v_alerts || jsonb_build_object('level','warn','message_key','membership.alert.neverPaidUser');
  ELSIF v_profile.must_change_password THEN
    v_status := 'attention';
    v_alerts := v_alerts || jsonb_build_object('level','warn','message_key','account.alert.changePassword');
  ELSE
    v_status := 'active';
  END IF;

  -- Additional info alerts
  IF v_open_loans > 0 AND v_overdue_count = 0 THEN
    v_alerts := v_alerts || jsonb_build_object('level','info','message_key','account.alert.openLoans','count', v_open_loans);
  END IF;
  IF v_active_reservations > 0 THEN
    v_alerts := v_alerts || jsonb_build_object('level','info','message_key','account.alert.activeReservations','count', v_active_reservations);
  END IF;

  -- Cotisation expirant bientôt (J-30) : alerte info en plus
  IF v_dues_status = 'up_to_date'
     AND v_dues_days_until_expiry IS NOT NULL
     AND v_dues_days_until_expiry <= 30 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'level','warn',
      'message_key','membership.alert.expiringSoon',
      'days', v_dues_days_until_expiry
    );
  END IF;

  RETURN jsonb_build_object(
    'status', v_status,
    'role', COALESCE(v_membership.role, 'reader'),
    'is_restricted', COALESCE(v_profile.is_restricted, false),
    'overdue_count', v_overdue_count,
    'open_loans', v_open_loans,
    'active_reservations', v_active_reservations,
    'dues_status', COALESCE(v_dues_status, 'not_applicable'),
    'dues_valid_until', v_dues_valid_until,
    'dues_days_until_expiry', v_dues_days_until_expiry,
    'alerts', v_alerts
  );
END;
$function$;

-- Vérification automatique en contexte simulé (RAISE EXCEPTION = rollback auto)
DO $$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef('public.fn_my_account_status()'::regprocedure) INTO v_def;
  ASSERT v_def NOT LIKE '%v_membership IS NOT NULL%',
    'ECHEC : un test "record IS NOT NULL" subsiste dans la fonction';
  ASSERT v_def NOT LIKE '%v_membership IS NULL%',
    'ECHEC : un test "record IS NULL" subsiste dans la fonction';
  ASSERT v_def NOT LIKE '%v_profile IS NULL%',
    'ECHEC : un test "v_profile IS NULL" subsiste dans la fonction';
  RAISE NOTICE 'OK : fn_my_account_status ne contient plus de test IS NULL sur record';
END $$;