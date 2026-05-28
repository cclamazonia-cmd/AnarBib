-- =====================================================================
-- 20260528160000_account_status_primary_fix.sql
-- ---------------------------------------------------------------------
-- Contexte : test prod EA-10 (#PAINEL chantier D, 28/05/2026).
--
-- BUG : fn_my_account_status() exigeait is_primary = true pour
-- reconnaitre la vinculacao d'un·e membre. Or 3 membres actifs sur 12
-- (dont la lectrice de test Livia GUSMAO VASCONCELOS) n'ont aucune ligne
-- active flaggee is_primary = true -> faux negatif -> bandeau
-- « account.alert.incomplete » (« Cadastro incompleto ») affiche a tort.
--
-- CORRECTIF A (code) : un·e membre est « complet·e » des qu'il/elle a
-- UN membership status='active', en preferant le primaire s'il existe
-- mais sans l'exiger. Tri : is_primary DESC, created_at ASC.
-- Robuste au cas « aucun primaire » et au cas multi-actifs.
--
-- CORRECTIF B (donnee) : backfill idempotent. Pour tout user ayant >= 1
-- membership actif mais AUCUN primaire parmi ses lignes actives, on
-- flagge sa ligne active la plus ancienne (is_primary = true). Ne touche
-- PAS les comptes ayant deja un primaire actif.
--
-- Verification : DO-block en fin de transaction (doctrine hotfix).
-- RAISE EXCEPTION = rollback automatique si l'invariant n'est pas tenu.
-- =====================================================================

BEGIN;

-- ── A. Code : assouplir le critere de vinculacao ─────────────────────
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

  -- CORRECTIF A : ne plus exiger is_primary = true. Un membership actif
  -- suffit ; on prend le primaire en priorite, sinon le plus ancien actif.
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

-- ── B. Donnee : backfill idempotent is_primary ───────────────────────
-- Pour chaque user ayant >= 1 membership actif mais aucun primaire parmi
-- ses actifs, flagger sa ligne active la plus ancienne.
WITH no_primary_users AS (
  SELECT user_id
  FROM user_library_memberships
  WHERE status = 'active'
  GROUP BY user_id
  HAVING bool_or(is_primary) = false
),
to_promote AS (
  SELECT DISTINCT ON (m.user_id) m.id
  FROM user_library_memberships m
  JOIN no_primary_users np ON np.user_id = m.user_id
  WHERE m.status = 'active'
  ORDER BY m.user_id, m.created_at ASC
)
UPDATE user_library_memberships
SET is_primary = true, updated_at = now()
WHERE id IN (SELECT id FROM to_promote);

-- ── Verification (doctrine hotfix : assert + rollback si invariant KO) ─
DO $verify$
DECLARE
  v_orphans int;
BEGIN
  -- Invariant : plus aucun user avec >= 1 actif et 0 primaire actif.
  SELECT count(*) INTO v_orphans FROM (
    SELECT user_id
    FROM user_library_memberships
    WHERE status = 'active'
    GROUP BY user_id
    HAVING bool_or(is_primary) = false
  ) q;

  IF v_orphans > 0 THEN
    RAISE EXCEPTION 'Backfill incomplet : % user(s) actif(s) sans primaire restant(s)', v_orphans;
  END IF;

  RAISE NOTICE 'OK : aucun user actif sans membership primaire. Migration coherente.';
END;
$verify$;

COMMIT;
