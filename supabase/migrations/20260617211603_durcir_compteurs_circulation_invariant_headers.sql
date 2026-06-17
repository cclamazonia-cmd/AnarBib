-- =========================================================================
-- Durcissement des compteurs de circulation (compte lecteur·rice)
-- Réservations + Consultations : invariant entête<->lignes + lecture par lignes
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Durcissement décompte emprunts / résas / consultations (/conta)
-- Auteur   : Claude (assistant·e)
-- Session  : Bug résa active fantôme (no-show / entête) — durcissement
-- Branche  : durcissement-compteurs-circulation (hors worktree partagé)
--
-- Contexte : à la suite du bug « 1 réservation active » fantôme (entête
-- reservas_v2 restée 'ativa' après un no-show, cf. migration 20260617165852),
-- on durcit STRUCTURELLEMENT les compteurs pour qu'aucune désynchro
-- entête<->lignes ne puisse plus produire un décompte erroné, ni aujourd'hui
-- ni au détour d'un futur chemin d'écriture qui « oublierait » le recompute.
--
-- Principe (double garde) :
--   (A) LECTURE — la source du compteur lectrice doit être les LIGNES
--       (item_status), jamais l'entête (status_global). C'est déjà le cas pour
--       les consultations (chip via api.my_consultas_active_v2) et les emprunts
--       (bandeau + chip via emprestimo_itens_v2.item_status='aberto'). Restait
--       le bandeau « réservations » qui lisait l'entête -> on le bascule sur les
--       lignes (même définition que api.my_reservations_active_v2 et la chip).
--   (B) ÉCRITURE — un trigger d'invariant sur la table des lignes rappelle le
--       recompute canonique d'entête à chaque changement d'item_status, pour
--       que l'entête se resynchronise quel que soit l'appelant (plus de
--       dépendance à la discipline de chaque fonction).
--
-- EMPRUNTS — VOLONTAIREMENT HORS PÉRIMÈTRE ICI. Le recompute d'entête emprunt
-- (fn_v2_refresh_emprestimo_status_global) ÉMET des notifications selon la
-- transition old->new. Un trigger d'invariant qui le rappellerait pré-mettrait
-- l'entête à jour AVANT l'appel explicite des chemins de retour, qui verrait
-- alors old==new et N'ENVERRAIT PLUS le mail de retour. Le décompte emprunt est
-- déjà robuste (lu sur les items, identique côté bandeau et chip) ; le
-- durcissement « entête » des emprunts exige de DÉCOUPLER notification et
-- recompute (trigger de notif sur emprestimos_v2.status_global), refactor à
-- traiter à part avec tests de non-régression des e-mails de retour.
--
-- État au moment du correctif (prod uflwmikiyjfnikiphtcp) : 0 désynchro sur les
-- 3 domaines -> les backfills ci-dessous sont des no-op (présents pour idempotence
-- et auto-réparation).
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- (A) LECTURE — bandeau réservations compté sur les LIGNES (même source que la
--     vue/chip). Seule la requête v_active_reservations change ; tout le reste
--     de fn_my_account_status est identique.
-- -------------------------------------------------------------------------
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

  -- DURCISSEMENT 17/06 : compter les LIGNES actives (même définition que la vue
  -- api.my_reservations_active_v2 et la chip), pas l'entête status_global. Rend
  -- le bandeau immunisé à toute désynchro d'entête (cf. bug no-show, migration
  -- 20260617165852). Avant :
  --   SELECT count(*) ... FROM reservas_v2 WHERE user_id = v_user_id
  --     AND status_global IN ('ativa', 'parcialmente_encerrada');
  SELECT count(*) INTO v_active_reservations
  FROM reserva_linhas_v2 rl
  JOIN reservas_v2 r ON r.id = rl.reserva_id
  WHERE r.user_id = v_user_id
    AND r.archived_at IS NULL
    AND rl.item_status = 'ativa';

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

-- -------------------------------------------------------------------------
-- (B.1) ÉCRITURE — invariant entête réservation. À chaque changement
--       d'item_status d'une ligne, on rappelle le recompute canonique (pur,
--       sans effet de bord) -> l'entête reservas_v2.status_global se
--       resynchronise quel que soit l'appelant. Supersède (sans les retirer)
--       les appels explicites des chemins terminaux.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_sync_reserva_header_from_lines()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.fn_v2_refresh_reserva_status_global(NEW.reserva_id);
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_sync_reserva_header_from_lines() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_sync_reserva_header_from_lines ON public.reserva_linhas_v2;
CREATE TRIGGER trg_sync_reserva_header_from_lines
  AFTER UPDATE OF item_status ON public.reserva_linhas_v2
  FOR EACH ROW
  WHEN (old.item_status IS DISTINCT FROM new.item_status)
  EXECUTE FUNCTION public.fn_sync_reserva_header_from_lines();

-- -------------------------------------------------------------------------
-- (B.2) ÉCRITURE — invariant entête consultation (même schéma ; recompute pur).
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_sync_consulta_header_from_lines()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.fn_v2_refresh_consulta_status_global(NEW.consulta_id);
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_sync_consulta_header_from_lines() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_sync_consulta_header_from_lines ON public.consulta_linhas_v2;
CREATE TRIGGER trg_sync_consulta_header_from_lines
  AFTER UPDATE OF item_status ON public.consulta_linhas_v2
  FOR EACH ROW
  WHEN (old.item_status IS DISTINCT FROM new.item_status)
  EXECUTE FUNCTION public.fn_sync_consulta_header_from_lines();

-- -------------------------------------------------------------------------
-- (C) Backfill auto-réparateur (no-op au moment du correctif : 0 désynchro).
-- -------------------------------------------------------------------------
SELECT public.fn_v2_refresh_reserva_status_global(r.id)
FROM public.reservas_v2 r
WHERE r.status_global IS DISTINCT FROM (
  CASE
    WHEN (SELECT count(*) FROM public.reserva_linhas_v2 l WHERE l.reserva_id = r.id) = 0 THEN 'encerrada'
    WHEN (SELECT count(*) FROM public.reserva_linhas_v2 l WHERE l.reserva_id = r.id AND l.item_status = 'ativa')
       = (SELECT count(*) FROM public.reserva_linhas_v2 l WHERE l.reserva_id = r.id) THEN 'ativa'
    WHEN (SELECT count(*) FROM public.reserva_linhas_v2 l WHERE l.reserva_id = r.id AND l.item_status = 'ativa') > 0 THEN 'parcialmente_encerrada'
    ELSE 'encerrada'
  END
);

SELECT public.fn_v2_refresh_consulta_status_global(c.id)
FROM public.consultas_locais_v2 c
WHERE c.status_global IS DISTINCT FROM (
  CASE
    WHEN (SELECT count(*) FROM public.consulta_linhas_v2 l WHERE l.consulta_id = c.id) = 0 THEN 'encerrada'
    WHEN (SELECT count(*) FROM public.consulta_linhas_v2 l WHERE l.consulta_id = c.id AND l.item_status = 'ativa')
       = (SELECT count(*) FROM public.consulta_linhas_v2 l WHERE l.consulta_id = c.id) THEN 'ativa'
    WHEN (SELECT count(*) FROM public.consulta_linhas_v2 l WHERE l.consulta_id = c.id AND l.item_status = 'ativa') > 0 THEN 'parcialmente_encerrada'
    ELSE 'encerrada'
  END
);

COMMIT;
