-- =============================================================================
-- Migration : EA-10 — tracabilite et horizontalite de la restriction
-- Chantier-cadre #PAINEL, chantier D. Decision doctrine mixte (28/05/2026) :
--   - membership.is_restricted = restriction LOCALE ordinaire (staff local)
--   - profiles.is_restricted   = gel GLOBAL exceptionnel (admin reseau)
-- Avant : la restriction etait un UPDATE direct frontend sur profiles, sans RPC
-- ni tracabilite, au mauvais niveau. On corrige les 3 defauts d'un coup.
--
-- Doctrine RPC v3 (RPC obligatoire pour ecriture sensible) + objets securises v2
-- (REVOKE EXECUTE FROM PUBLIC, search_path fixe, DO-block).
-- Migration de l'existant : NON DESTRUCTIVE. Les profiles.is_restricted actuels
-- restent tels quels (interpretes comme gels globaux). Rebascule manuelle au cas
-- par cas si besoin, apres verification du contexte.
-- =============================================================================

-- ── 1. Colonnes de tracabilite ──────────────────────────────────────────────
-- Niveau membership (restriction locale) : qui + quand. La raison existe deja.
ALTER TABLE public.user_library_memberships
  ADD COLUMN IF NOT EXISTS restricted_by uuid,
  ADD COLUMN IF NOT EXISTS restricted_at timestamptz;

COMMENT ON COLUMN public.user_library_memberships.restricted_by IS
  'EA-10 (28/05/2026) : staff (uuid) ayant pose la restriction LOCALE. Horizontalite.';
COMMENT ON COLUMN public.user_library_memberships.restricted_at IS
  'EA-10 (28/05/2026) : date de pose de la restriction locale.';

-- Niveau profiles (gel global) : le quand (restricted_since) existe deja, on
-- ajoute le qui.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS restricted_by uuid;

COMMENT ON COLUMN public.profiles.restricted_by IS
  'EA-10 (28/05/2026) : admin reseau (uuid) ayant pose le gel GLOBAL du compte.';

-- ── 2. RPC restriction LOCALE (membership) ──────────────────────────────────
-- Habilitation : staff de la biblio (librarian/coordenador) ou admin reseau,
-- via le helper existant user_can_act_as_staff_on_library.
CREATE OR REPLACE FUNCTION api.restrict_member(
  p_user_id uuid, p_library_id uuid, p_reason text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
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

  RETURN jsonb_build_object('ok', true, 'membership_id', v_membership_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION api.restrict_member(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.restrict_member(uuid, uuid, text) TO authenticated;

COMMENT ON FUNCTION api.restrict_member(uuid, uuid, text) IS
  'EA-10 : restriction LOCALE d''un membre dans une biblio. Staff local ou admin '
  'reseau. Raison obligatoire >= 5 car. Trace restricted_by + restricted_at. '
  'Chantier D #PAINEL, 28/05/2026.';

-- ── 3. RPC levee de restriction locale ──────────────────────────────────────
CREATE OR REPLACE FUNCTION api.unrestrict_member(
  p_user_id uuid, p_library_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
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

  RETURN jsonb_build_object('ok', true, 'membership_id', v_membership_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION api.unrestrict_member(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.unrestrict_member(uuid, uuid) TO authenticated;

COMMENT ON FUNCTION api.unrestrict_member(uuid, uuid) IS
  'EA-10 : leve une restriction LOCALE. Staff local ou admin reseau. Chantier D.';

-- ── 4. RPC gel GLOBAL (profiles) — admin reseau seulement ───────────────────
CREATE OR REPLACE FUNCTION api.freeze_account(
  p_user_id uuid, p_reason text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
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

  RETURN jsonb_build_object('ok', true, 'user_id', p_user_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION api.freeze_account(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.freeze_account(uuid, text) TO authenticated;

COMMENT ON FUNCTION api.freeze_account(uuid, text) IS
  'EA-10 : gel GLOBAL exceptionnel d''un compte (securite reseau). Admin reseau '
  'seulement. Raison obligatoire. Trace restricted_by + restricted_since. Chantier D.';

-- ── 5. RPC degel global ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.unfreeze_account(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
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

  RETURN jsonb_build_object('ok', true, 'user_id', p_user_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION api.unfreeze_account(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.unfreeze_account(uuid) TO authenticated;

COMMENT ON FUNCTION api.unfreeze_account(uuid) IS
  'EA-10 : leve un gel global. Admin reseau seulement. Chantier D.';

-- ── 6. DO-block de verification ─────────────────────────────────────────────
DO $$
DECLARE
  v_count int;
BEGIN
  -- Colonnes creees
  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema='public' AND table_name='user_library_memberships'
    AND column_name IN ('restricted_by','restricted_at');
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'VERIF KO : colonnes membership.restricted_by/at manquantes (%)', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema='public' AND table_name='profiles' AND column_name='restricted_by';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF KO : profiles.restricted_by manquante';
  END IF;

  -- 4 RPC presentes
  SELECT count(*) INTO v_count FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='api' AND p.proname IN
    ('restrict_member','unrestrict_member','freeze_account','unfreeze_account');
  IF v_count <> 4 THEN
    RAISE EXCEPTION 'VERIF KO : 4 RPC attendues, trouve %', v_count;
  END IF;

  -- anon sans EXECUTE sur restrict_member
  SELECT count(*) INTO v_count FROM information_schema.routine_privileges
  WHERE routine_schema='api' AND routine_name='restrict_member'
    AND grantee IN ('anon','PUBLIC');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'VERIF KO : anon/PUBLIC a EXECUTE sur restrict_member';
  END IF;

  RAISE NOTICE 'VERIF OK : EA-10 tracabilite restriction installee (mixte local/global).';
END;
$$;
