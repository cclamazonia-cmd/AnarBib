-- =============================================================================
-- Migration : EA-10 (suite) — RPC de lecture de l'etat de restriction
-- Chantier D #PAINEL. Complement au backend 20260528140000.
-- Retourne, pour un membre dans une biblio donnee :
--   - restriction LOCALE (membership) : is_restricted, reason, by + nom, at
--   - gel GLOBAL (profile) : is_restricted, reason, by + nom, since
-- Resolution du nom du restricteur sur le modele de fn_list_membership_payments
-- (LEFT JOIN profiles, COALESCE nom complet -> email). Lecture seule.
-- Habilitation : staff de la biblio (user_can_act_as_staff_on_library).
-- =============================================================================

CREATE OR REPLACE FUNCTION api.get_member_restriction(
  p_user_id uuid, p_library_id uuid
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_local  record;
  v_global record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  IF NOT public.user_can_act_as_staff_on_library(p_library_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authorized');
  END IF;

  -- Restriction LOCALE (membership actif du membre dans cette biblio)
  SELECT m.is_restricted, m.restricted_reason, m.restricted_by, m.restricted_at,
         COALESCE(NULLIF(btrim(pb.first_name || ' ' || COALESCE(pb.last_name, '')), ''), pb.email) AS by_name
    INTO v_local
  FROM public.user_library_memberships m
  LEFT JOIN public.profiles pb ON pb.id = m.restricted_by
  WHERE m.user_id = p_user_id AND m.library_id = p_library_id AND m.status = 'active'
  LIMIT 1;

  -- Gel GLOBAL (profile)
  SELECT pr.is_restricted, pr.restricted_reason, pr.restricted_by, pr.restricted_since,
         COALESCE(NULLIF(btrim(pg.first_name || ' ' || COALESCE(pg.last_name, '')), ''), pg.email) AS by_name
    INTO v_global
  FROM public.profiles pr
  LEFT JOIN public.profiles pg ON pg.id = pr.restricted_by
  WHERE pr.id = p_user_id
  LIMIT 1;

  RETURN jsonb_build_object(
    'ok', true,
    'local', jsonb_build_object(
      'is_restricted', COALESCE(v_local.is_restricted, false),
      'reason',        v_local.restricted_reason,
      'by',            v_local.restricted_by,
      'by_name',       v_local.by_name,
      'at',            v_local.restricted_at
    ),
    'global', jsonb_build_object(
      'is_restricted', COALESCE(v_global.is_restricted, false),
      'reason',        v_global.restricted_reason,
      'by',            v_global.restricted_by,
      'by_name',       v_global.by_name,
      'since',         v_global.restricted_since
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION api.get_member_restriction(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.get_member_restriction(uuid, uuid) TO authenticated;

COMMENT ON FUNCTION api.get_member_restriction(uuid, uuid) IS
  'EA-10 : etat de restriction d''un membre (local membership + global profile) '
  'avec nom du restricteur resolu. Staff de la biblio. Lecture seule. Chantier D.';

-- ── DO-block de verification ────────────────────────────────────────────────
DO $$
DECLARE v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='api' AND p.proname='get_member_restriction';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF KO : api.get_member_restriction absente';
  END IF;

  SELECT count(*) INTO v_count FROM information_schema.routine_privileges
  WHERE routine_schema='api' AND routine_name='get_member_restriction'
    AND grantee IN ('anon','PUBLIC');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'VERIF KO : anon/PUBLIC a EXECUTE sur get_member_restriction';
  END IF;

  RAISE NOTICE 'VERIF OK : api.get_member_restriction installee.';
END;
$$;
