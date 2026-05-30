-- Migration : EA-10 bandeau « motif + qui a décidé » — backend. 30/05/2026.
--
-- Décision (30/05) : le bandeau côté compte lecteur·rice affiche le motif ET le nom
-- de qui a décidé la restriction (transparence/responsabilité horizontale).
--
-- fn_my_account_status s'exécute en SECURITY INVOKER (en tant que lecteur·rice) : il ne
-- peut pas lire le profil du décideur (RLS). On passe donc par un helper SECURITY DEFINER
-- dédié à la résolution du nom (même composition que api.get_member_restriction).
--
-- Doctrine : fichier appliqué par Woodpecker (supabase db push --linked).

-- Helper de résolution de nom (DEFINER : voit hors RLS, juste pour composer le nom).
CREATE OR REPLACE FUNCTION public.fn_user_display_name(p_uid uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $fn$
  SELECT COALESCE(NULLIF(btrim(p.first_name || ' ' || COALESCE(p.last_name, '')), ''), p.email)
    FROM public.profiles p
   WHERE p.id = p_uid;
$fn$;
REVOKE EXECUTE ON FUNCTION public.fn_user_display_name(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_user_display_name(uuid) TO authenticated, service_role;

-- fn_my_account_status : + champ decided_by (nom résolu) sur les 2 alertes restricted.
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

  -- Membership actif, primaire en priorite sinon le plus ancien (cf. 160000)
  SELECT * INTO v_membership FROM user_library_memberships
   WHERE user_id = v_user_id AND status = 'active'
   ORDER BY is_primary DESC, created_at ASC
   LIMIT 1;
  v_has_membership := FOUND;

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

  IF v_has_membership THEN
    SELECT dues_status, last_valid_until, days_until_expiry
      INTO v_dues_status, v_dues_valid_until, v_dues_days_until_expiry
    FROM v_active_memberships
    WHERE user_id = v_user_id AND library_id = v_membership.library_id;

    SELECT EXISTS (
      SELECT 1 FROM library_membership_rules
      WHERE library_id = v_membership.library_id
        AND is_active = true AND is_required = true
    ) INTO v_membership_required;
  END IF;

  -- Determine status (priorite : incomplete > gel global > restriction locale
  -- > overdue > dues > attention > active)
  IF NOT v_has_profile OR NOT v_has_membership THEN
    v_status := 'incomplete';
    v_alerts := v_alerts || jsonb_build_object('level','warn','message_key','account.alert.incomplete');
  ELSIF v_profile.is_restricted THEN
    -- Gel global reseau (priorite : portee la plus large)
    v_status := 'restricted';
    v_alerts := v_alerts || jsonb_build_object('level','danger','message_key','account.alert.restricted','reason', COALESCE(v_profile.restricted_reason, ''),'decided_by', public.fn_user_display_name(v_profile.restricted_by));
  ELSIF COALESCE(v_membership.is_restricted, false) THEN
    -- Restriction locale staff (doctrine MIXTE 28/05)
    v_status := 'restricted';
    v_alerts := v_alerts || jsonb_build_object('level','danger','message_key','account.alert.restricted.local','reason', COALESCE(v_membership.restricted_reason, ''),'decided_by', public.fn_user_display_name(v_membership.restricted_by));
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

  IF v_open_loans > 0 AND v_overdue_count = 0 THEN
    v_alerts := v_alerts || jsonb_build_object('level','info','message_key','account.alert.openLoans','count', v_open_loans);
  END IF;
  IF v_active_reservations > 0 THEN
    v_alerts := v_alerts || jsonb_build_object('level','info','message_key','account.alert.activeReservations','count', v_active_reservations);
  END IF;

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
    'is_restricted_local', COALESCE(v_membership.is_restricted, false),
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

-- Vérification (RAISE EXCEPTION => rollback).
DO $verify$
BEGIN
  IF to_regprocedure('public.fn_user_display_name(uuid)') IS NULL THEN
    RAISE EXCEPTION '[EA-10] helper fn_user_display_name absent';
  END IF;
  IF position('fn_user_display_name' in pg_get_functiondef('public.fn_my_account_status'::regproc)) = 0 THEN
    RAISE EXCEPTION '[EA-10] decided_by absent de fn_my_account_status';
  END IF;
  RAISE NOTICE '[EA-10] bandeau OK : fn_my_account_status renvoie decided_by (gel global + restriction locale).';
END
$verify$;
