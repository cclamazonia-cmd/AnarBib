-- ============================================================================
-- #NOTIFY-Painel-acts — Famille 2 : notification du membre à la restriction
-- locale / au gel global (et à leurs levées).
-- ----------------------------------------------------------------------------
-- Auteur  : Claude (Opus 4.8) pour Xavier Van Welden
-- Session : Audit #NOTIFY-Painel-acts
-- Date    : 2026-06-08 (UTC 20260608104325)
-- ----------------------------------------------------------------------------
-- Les 4 actes EA-10 émettent désormais un event (best-effort) après l'UPDATE,
-- pour que l'EF notify-event prévienne le membre (e-mail OBLIGATOIRE, NOTIF-PA3
-- + copie staff optionnelle) :
--   api.restrict_member    -> member_restricted_local
--   api.unrestrict_member  -> member_unrestricted_local
--   api.freeze_account     -> member_frozen_global
--   api.unfreeze_account   -> member_unfrozen_global
-- record_id factice = 1 (l'EF exige > 0) ; les données (user_id, library_id,
-- reason, at) passent en extra. Corps des fonctions préservés à l'identique,
-- seul le PERFORM de dispatch est ajouté. Grants préservés (authenticated ;
-- REVOKE PUBLIC pour la doctrine objets backend / garde-fou pre-commit).
-- DOC-NOTIF-1 : on notifie le membre, pas l'acteur. Débloqué par #110.
-- ============================================================================

-- ── Restriction LOCALE ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.restrict_member(p_user_id uuid, p_library_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_membership_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  -- Habilitation : staff de cette biblio
  IF NOT public.user_can_act_as_staff_on_library(p_library_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authorized');
  END IF;

  -- Raison obligatoire (horizontalite : un acte sensible se motive)
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'reason_required');
  END IF;

  -- Appartenance active du membre cible a cette biblio
  SELECT id INTO v_membership_id
  FROM public.user_library_memberships
  WHERE user_id = p_user_id AND library_id = p_library_id AND status = 'active'
  LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_a_member');
  END IF;

  UPDATE public.user_library_memberships
  SET is_restricted = true,
      restricted_reason = btrim(p_reason),
      restricted_by = v_uid,
      restricted_at = now()
  WHERE id = v_membership_id;

  PERFORM public.fn_dispatch_notify_event('member_restricted_local', 1,
    jsonb_build_object('user_id', p_user_id::text, 'library_id', p_library_id::text,
                       'reason', btrim(p_reason), 'at', now()::text));

  RETURN jsonb_build_object('ok', true, 'membership_id', v_membership_id);
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.restrict_member(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.restrict_member(uuid, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION api.unrestrict_member(p_user_id uuid, p_library_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_membership_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;
  IF NOT public.user_can_act_as_staff_on_library(p_library_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authorized');
  END IF;

  SELECT id INTO v_membership_id
  FROM public.user_library_memberships
  WHERE user_id = p_user_id AND library_id = p_library_id AND status = 'active'
  LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_a_member');
  END IF;

  UPDATE public.user_library_memberships
  SET is_restricted = false,
      restricted_reason = NULL,
      restricted_by = NULL,
      restricted_at = NULL
  WHERE id = v_membership_id;

  PERFORM public.fn_dispatch_notify_event('member_unrestricted_local', 1,
    jsonb_build_object('user_id', p_user_id::text, 'library_id', p_library_id::text, 'at', now()::text));

  RETURN jsonb_build_object('ok', true, 'membership_id', v_membership_id);
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.unrestrict_member(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.unrestrict_member(uuid, uuid) TO authenticated;

-- ── Gel GLOBAL (profil / réseau) ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.freeze_account(p_user_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  -- Gel global = acte exceptionnel reserve aux admins reseau
  IF NOT public.fn_caller_is_network_admin() THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authorized');
  END IF;

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'reason_required');
  END IF;

  UPDATE public.profiles
  SET is_restricted = true,
      restricted_reason = btrim(p_reason),
      restricted_since = now(),
      restricted_by = v_uid
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'profile_not_found');
  END IF;

  PERFORM public.fn_dispatch_notify_event('member_frozen_global', 1,
    jsonb_build_object('user_id', p_user_id::text, 'reason', btrim(p_reason), 'at', now()::text));

  RETURN jsonb_build_object('ok', true, 'user_id', p_user_id);
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.freeze_account(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.freeze_account(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION api.unfreeze_account(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;
  IF NOT public.fn_caller_is_network_admin() THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authorized');
  END IF;

  UPDATE public.profiles
  SET is_restricted = false,
      restricted_reason = NULL,
      restricted_since = NULL,
      restricted_by = NULL
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'profile_not_found');
  END IF;

  PERFORM public.fn_dispatch_notify_event('member_unfrozen_global', 1,
    jsonb_build_object('user_id', p_user_id::text, 'at', now()::text));

  RETURN jsonb_build_object('ok', true, 'user_id', p_user_id);
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.unfreeze_account(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.unfreeze_account(uuid) TO authenticated;
