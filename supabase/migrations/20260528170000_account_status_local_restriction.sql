-- =====================================================================
-- 20260528170000_account_status_local_restriction.sql
-- ---------------------------------------------------------------------
-- Contexte : test prod EA-10 (#PAINEL chantier D, 28/05/2026).
--
-- BUG : apres restriction LOCALE d'un·e membre via api.restrict_member
-- (qui ecrit user_library_memberships.is_restricted = true), le bandeau
-- du compte lecteur affiche toujours « Conta ativa ». Cause :
-- fn_my_account_status() ne lit la restriction QUE sur profiles.is_restricted
-- (gel global reseau) et ignore membership.is_restricted (restriction
-- locale staff). La doctrine MIXTE (28/05) distingue les deux niveaux :
--   - profiles.is_restricted   = gel global (admin reseau, freeze_account)
--   - membership.is_restricted = restriction locale (staff, restrict_member)
--
-- CORRECTIF : les DEUX niveaux menent au statut 'restricted'. Priorite au
-- gel global (portee reseau, plus grave) ; sinon restriction locale. Message
-- differencie : 'account.alert.restricted' (global, existant) vs
-- 'account.alert.restricted.local' (local, nouvelle cle i18n).
--
-- v_membership est deja charge par SELECT * (cf. migration 160000), donc
-- v_membership.is_restricted / .restricted_reason sont disponibles sans
-- requete supplementaire.
--
-- Verification : DO-block en fin de transaction. Lívia GUSMAO VASCONCELOS
-- (restreinte localement le 28/05) doit ressortir 'restricted'.
-- =====================================================================

BEGIN;

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
    v_alerts := v_alerts || jsonb_build_object('level','danger','message_key','account.alert.restricted','reason', COALESCE(v_profile.restricted_reason, ''));
  ELSIF COALESCE(v_membership.is_restricted, false) THEN
    -- Restriction locale staff (doctrine MIXTE 28/05)
    v_status := 'restricted';
    v_alerts := v_alerts || jsonb_build_object('level','danger','message_key','account.alert.restricted.local','reason', COALESCE(v_membership.restricted_reason, ''));
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

-- ── Verification (doctrine hotfix) ───────────────────────────────────
-- Simule le contexte PostgREST de Lívia (restreinte localement le 28/05)
-- et asserte que fn_my_account_status renvoie bien status='restricted'.
DO $verify$
DECLARE
  v_result jsonb;
  v_lib_restricted boolean;
BEGIN
  -- Sanity : la donnee de Lívia est bien une restriction LOCALE (pas globale)
  SELECT m.is_restricted INTO v_lib_restricted
  FROM user_library_memberships m
  WHERE m.user_id = '366cdc4e-10e0-44ad-8554-a444bcf9607a' AND m.status='active';

  IF v_lib_restricted IS NOT TRUE THEN
    RAISE EXCEPTION 'Pre-condition KO : Lívia n''est pas restreinte localement (test non significatif)';
  END IF;

  -- Simulation du contexte authentifie de Lívia
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims',
    '{"sub":"366cdc4e-10e0-44ad-8554-a444bcf9607a","role":"authenticated"}', true);

  v_result := public.fn_my_account_status();

  -- Retour au role par defaut pour la suite de la transaction
  RESET role;

  IF v_result->>'status' <> 'restricted' THEN
    RAISE EXCEPTION 'Echec : fn_my_account_status renvoie status=% pour Lívia (attendu: restricted)', v_result->>'status';
  END IF;
  IF (v_result->>'is_restricted_local')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'Echec : is_restricted_local non remonte pour Lívia';
  END IF;

  RAISE NOTICE 'OK : restriction locale correctement reflechie (status=restricted, is_restricted_local=true).';
END;
$verify$;

COMMIT;
