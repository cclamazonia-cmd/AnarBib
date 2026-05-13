-- ============================================================================
-- Paquet F.2 - Refacto 14 fonctions Type A/B (retrait 'administrador')
-- ============================================================================
-- Date  : 2026-05-13
-- Auteur: Xavier (AnarBib)
-- Ref.  : docs/spec-administrateur-reseau.md v0.3
--
-- Contexte
-- --------
-- Suite de F.1 (cleanup schema). Refacto des 14 fonctions qui mentionnent
-- encore 'administrador' comme role local dans des arrays/IN/CASE.
--
-- Classification (audit pre-F.2)
-- ------------------------------
-- Type A (12 fonctions) : 'administrador' dans un array de roles staff,
--                          retrait mecanique.
-- Type B (1 fonction)   : 'administrador' dans un IN avec 'coordenador'
--                          seul (fn_set_retention_policy) -> devient
--                          test d'egalite sur 'coordenador'.
-- Type C (1 fonction)   : 'administrador' dans un commentaire seulement
--                          (api.advance_consulta) -> commentaire mis a jour.
--
-- Doctrine v0.3
-- -------------
-- Les fonctions resteront fonctionnellement equivalentes pour les roles
-- 'librarian' et 'coordenador'. Le test 'administrador' devient mort code
-- garanti par F.1 (plus aucun ulm ne peut porter ce role).
-- fn_team_list_memberships : le CASE WHEN 'administrador' THEN 1 est aussi
-- retire pour propreté (devenu mort code).
--
-- Effet en prod
-- -------------
-- Aucun visible. Comportement identique pour staff librarian/coordenador.
-- ============================================================================

BEGIN;

-- ============================================================================
-- Type C : api.advance_consulta (commentaire seulement)
-- ============================================================================

CREATE OR REPLACE FUNCTION api.advance_consulta(
    p_consulta_id bigint,
    p_line_nos integer[],
    p_target_stage text,
    p_workflow_note text DEFAULT NULL::text,
    p_consultation_scheduled_for timestamp with time zone DEFAULT NULL::timestamp with time zone,
    p_consultation_starts_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
    p_consultation_ends_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
    p_consultation_timezone text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
  v_current_stage text;
  v_heterogeneous_count int;
  v_effective_tz text;
  v_updated int;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  IF p_consulta_id IS NULL THEN
    RAISE EXCEPTION 'not_found: p_consulta_id manquant' USING ERRCODE = 'P0001';
  END IF;

  IF p_line_nos IS NULL OR cardinality(p_line_nos) = 0 THEN
    RAISE EXCEPTION 'not_found: p_line_nos vide' USING ERRCODE = 'P0001';
  END IF;

  IF p_target_stage IS NULL OR p_target_stage = '' THEN
    RAISE EXCEPTION 'invalid_stage: p_target_stage manquant' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_consulta_context(p_consulta_id);
  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'not_found: consulta % nao encontrada', p_consulta_id
      USING ERRCODE = 'P0001';
  END IF;

  -- F.2 v0.3 : la resolution du role retourne 'leitor' / 'librarian' /
  -- 'coordenador' / NULL (le role 'administrador' a ete supprime en F.1).
  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  SELECT workflow_stage
    INTO v_current_stage
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = p_consulta_id
    AND line_no = p_line_nos[1];

  IF v_current_stage IS NULL THEN
    RAISE EXCEPTION 'not_found: linha % da consulta % nao encontrada',
      p_line_nos[1], p_consulta_id
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*)
    INTO v_heterogeneous_count
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = p_consulta_id
    AND line_no = ANY(p_line_nos)
    AND workflow_stage IS DISTINCT FROM v_current_stage;

  IF v_heterogeneous_count > 0 THEN
    RAISE EXCEPTION 'invalid_stage: linhas com etapas heterogeneas (esperado %, % linhas diferentes)',
      v_current_stage, v_heterogeneous_count
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.fn_check_consulta_transition(v_current_stage, p_target_stage, v_actor_role) THEN
    RAISE EXCEPTION 'invalid_stage: transicao % -> % nao permitida para %',
      v_current_stage, p_target_stage, COALESCE(v_actor_role, '(null)')
      USING ERRCODE = '42501';
  END IF;

  IF p_target_stage = 'consulta_agendada' AND p_consultation_starts_at IS NOT NULL THEN
    v_effective_tz := COALESCE(
      p_consultation_timezone,
      (SELECT consultation_timezone FROM public.library_service_state
        WHERE library_id = v_ctx.library_id),
      'UTC'
    );

    IF p_consultation_ends_at IS NULL THEN
      RAISE EXCEPTION 'schedule_missing: p_consultation_ends_at obrigatorio com p_consultation_starts_at'
        USING ERRCODE = 'P0001';
    END IF;

    v_updated := public.fn_v2_set_consulta_linhas_workflow_slot(
      p_consulta_id,
      p_line_nos,
      p_target_stage,
      p_workflow_note,
      to_char(p_consultation_starts_at AT TIME ZONE v_effective_tz, 'YYYY-MM-DD'),
      to_char(p_consultation_starts_at AT TIME ZONE v_effective_tz, 'HH24:MI'),
      to_char(p_consultation_ends_at   AT TIME ZONE v_effective_tz, 'HH24:MI'),
      v_effective_tz
    );

  ELSIF p_target_stage = 'consulta_agendada' AND p_consultation_scheduled_for IS NULL THEN
    RAISE EXCEPTION 'schedule_missing: p_consultation_scheduled_for ou p_consultation_starts_at obrigatorio'
      USING ERRCODE = 'P0001';

  ELSE
    v_updated := public.fn_v2_set_consulta_linhas_workflow(
      p_consulta_id,
      p_line_nos,
      p_target_stage,
      p_workflow_note,
      p_consultation_scheduled_for
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'updated_count', v_updated);
END;
$function$;

-- ============================================================================
-- Type A : api.create_consulta_local (retrait 'administrador' du NOT IN)
-- ============================================================================

CREATE OR REPLACE FUNCTION api.create_consulta_local(
    p_user_id uuid,
    p_holding_ids bigint[],
    p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_first_holding_id bigint;
  v_library_id uuid;
  v_actor_role text;
  v_consulta_id bigint;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'not_found: p_user_id manquant' USING ERRCODE = 'P0001';
  END IF;

  IF p_holding_ids IS NULL OR cardinality(p_holding_ids) = 0 THEN
    RAISE EXCEPTION 'not_found: nenhum holding informado' USING ERRCODE = 'P0001';
  END IF;

  SELECT h
    INTO v_first_holding_id
  FROM unnest(p_holding_ids) AS h
  WHERE h IS NOT NULL
  LIMIT 1;

  IF v_first_holding_id IS NULL THEN
    RAISE EXCEPTION 'not_found: nenhum holding valido informado' USING ERRCODE = 'P0001';
  END IF;

  IF p_user_id <> v_caller_uid THEN
    SELECT library_id
      INTO v_library_id
    FROM public.book_holdings
    WHERE id = v_first_holding_id;

    IF v_library_id IS NULL THEN
      RAISE EXCEPTION 'not_found: holding % nao encontrado', v_first_holding_id
        USING ERRCODE = 'P0001';
    END IF;

    v_actor_role := public.fn_resolve_caller_role_for_library(v_library_id);

    -- F.2 v0.3 : retrait 'administrador' (role local supprime en F.1)
    IF v_actor_role NOT IN ('librarian', 'coordenador') THEN
      RAISE EXCEPTION 'not_authorized: criacao para outro leitor requer papel de staff'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  v_consulta_id := public.fn_v2_create_consulta_local_by_holdings(
    p_user_id, p_holding_ids, p_expires_at, p_notes
  );

  RETURN jsonb_build_object('ok', true, 'consulta_id', v_consulta_id);
END;
$function$;

-- ============================================================================
-- Type A : 5 fonctions can_manage_* (mecanique identique)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.can_manage_document_requests_for_library(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships ulm
    WHERE ulm.user_id = auth.uid()
      AND ulm.library_id = p_library_id
      AND ulm.status = 'active'
      AND lower(coalesce(ulm.role, '')) IN ('librarian', 'coordenador')
  );
$function$;

CREATE OR REPLACE FUNCTION public.can_manage_library_circulation_policies(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships ulm
    WHERE ulm.user_id = auth.uid()
      AND ulm.library_id = p_library_id
      AND ulm.status = 'active'
      AND lower(coalesce(ulm.role, '')) IN ('librarian', 'coordenador')
  );
$function$;

CREATE OR REPLACE FUNCTION public.can_manage_library_contact_profile(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships ulm
    WHERE ulm.user_id = auth.uid()
      AND ulm.library_id = p_library_id
      AND ulm.status = 'active'
      AND lower(coalesce(ulm.role, '')) IN ('librarian', 'coordenador')
  );
$function$;

CREATE OR REPLACE FUNCTION public.can_manage_library_document_governance(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships ulm
    WHERE ulm.user_id = auth.uid()
      AND ulm.library_id = p_library_id
      AND ulm.status = 'active'
      AND lower(coalesce(ulm.role, '')) IN ('librarian', 'coordenador')
  );
$function$;

CREATE OR REPLACE FUNCTION public.can_manage_library_regulation_documents(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships ulm
    WHERE ulm.user_id = auth.uid()
      AND ulm.library_id = p_library_id
      AND ulm.status = 'active'
      AND lower(coalesce(ulm.role, '')) IN ('librarian', 'coordenador')
  );
$function$;

-- ============================================================================
-- Type A : circulation_reader_scope (retrait administrador du IN staff)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.circulation_reader_scope(p_user_id uuid, p_library_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_profile public.profiles%rowtype;
begin
  if p_user_id is null then
    return 'non_member';
  end if;

  select *
    into v_profile
  from public.profiles p
  where p.id = p_user_id
  limit 1;

  if coalesce(v_profile.is_restricted, false) is true then
    return 'restricted';
  end if;

  -- F.2 v0.3 : Staff local (bibliothécaire, coordinateur·rice) partagent
  -- le même scope de circulation : ils peuvent emprunter sans les
  -- restrictions appliquées aux membres simples.
  if exists (
    select 1
    from public.user_library_memberships ulm
    where ulm.user_id = p_user_id
      and ulm.library_id = p_library_id
      and ulm.status = 'active'
      and lower(coalesce(ulm.role, '')) in (
        'librarian',
        'coordenador'
      )
  ) then
    return 'librarian';
  end if;

  if exists (
    select 1
    from public.user_library_memberships ulm
    where ulm.user_id = p_user_id
      and ulm.library_id = p_library_id
      and ulm.status = 'active'
  ) then
    return 'local_member';
  end if;

  if exists (
    select 1
    from public.user_library_memberships ulm
    join public.libraries l
      on l.id = ulm.library_id
    where ulm.user_id = p_user_id
      and ulm.status = 'active'
      and l.is_active = true
  ) then
    return 'network_member';
  end if;

  return 'non_member';
end;
$function$;

-- ============================================================================
-- Type A : fn_check_consulta_transition (4 occurrences toutes mecaniques)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_check_consulta_transition(p_from text, p_to text, p_actor_role text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE PARALLEL SAFE
SET search_path TO 'public'
AS $function$
WITH normalized AS (
  SELECT
    p_from        AS f,
    p_to          AS t,
    p_actor_role  AS r
)
SELECT CASE
  WHEN f IS NULL OR t IS NULL OR r IS NULL THEN false
  WHEN f = '' OR t = '' OR r = '' THEN false

  WHEN f IN (
    'consulta_realizada',
    'cancelada_leitor',
    'cancelada_biblioteca',
    'expirada'
  ) THEN false

  -- F.2 v0.3 : retrait 'administrador' (4 occurrences)
  WHEN f = 'nao_compareceu' AND t = 'cancelada_biblioteca'
       AND r IN ('librarian', 'coordenador') THEN true
  WHEN f = 'nao_compareceu' THEN false

  WHEN r = 'leitor' AND t = 'cancelada_leitor' AND f IN (
    'solicitada',
    'em_preparacao',
    'consulta_agendada'
  ) THEN true

  WHEN r = 'leitor' THEN false

  WHEN r = 'system' AND t = 'expirada' AND f IN (
    'solicitada',
    'em_preparacao',
    'consulta_agendada'
  ) THEN true
  WHEN r = 'system' THEN false

  WHEN f = 'solicitada' AND t IN (
    'em_preparacao',
    'cancelada_biblioteca'
  ) AND r IN ('librarian', 'coordenador') THEN true

  WHEN f = 'em_preparacao' AND t IN (
    'consulta_agendada',
    'cancelada_biblioteca'
  ) AND r IN ('librarian', 'coordenador') THEN true

  WHEN f = 'consulta_agendada' AND t IN (
    'consulta_agendada',
    'consulta_realizada',
    'nao_compareceu',
    'cancelada_biblioteca'
  ) AND r IN ('librarian', 'coordenador') THEN true

  ELSE false
END
FROM normalized;
$function$;

-- ============================================================================
-- Type A : fn_check_loan_action (retrait administrador du is_library)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_check_loan_action(p_action text, p_current_status text, p_actor_role text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_action text := lower(trim(coalesce(p_action, '')));
  v_status text := lower(trim(coalesce(p_current_status, '')));
  v_role text := lower(trim(coalesce(p_actor_role, '')));
  -- F.2 v0.3 : retrait 'administrador' (role local supprime)
  v_is_library boolean := v_role IN ('librarian', 'coordenador');
  v_is_reader boolean := v_role = 'leitor';
  v_is_system boolean := v_role = 'system';
  v_active_status boolean := v_status IN ('aberto', 'parcialmente_devolvido');
BEGIN
  IF v_action = '' OR v_role = '' THEN
    RETURN false;
  END IF;

  CASE v_action
    WHEN 'create_loan_at_counter' THEN
      RETURN v_is_library;

    WHEN 'return_total', 'return_partial', 'extend_as_library', 'mark_return_missed' THEN
      RETURN v_is_library AND v_active_status;

    WHEN 'renew_as_reader' THEN
      RETURN (v_is_reader OR v_is_library) AND v_active_status;

    WHEN 'schedule_return', 'clear_return_schedule' THEN
      RETURN (v_is_library OR v_is_reader) AND v_active_status;

    WHEN 'mark_return_missed_by_system' THEN
      RETURN v_is_system AND v_active_status;

    ELSE
      RETURN false;
  END CASE;
END;
$function$;

-- ============================================================================
-- Type B : fn_set_retention_policy (IN devient egalite sur coordenador)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_set_retention_policy(
    p_library_id uuid,
    p_loans_days integer,
    p_reservations_days integer,
    p_consultations_days integer,
    p_notifications_days integer,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_can_manage boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  -- F.2 v0.3 : la politique de retention est reservee aux coordenador
  -- de la biblio (role 'administrador' supprime en F.1).
  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = v_user_id
      AND m.library_id = p_library_id
      AND m.status = 'active'
      AND m.role = 'coordenador'
  ) INTO v_can_manage;

  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Vous n''avez pas le droit de modifier la politique de retention de cette bibliotheque.'
      USING ERRCODE = '42501';
  END IF;

  IF p_loans_days IS NOT NULL AND p_loans_days < 0 THEN
    RAISE EXCEPTION 'Duree de retention emprunts invalide (doit etre >= 0).' USING ERRCODE = '23514';
  END IF;
  IF p_reservations_days IS NOT NULL AND p_reservations_days < 0 THEN
    RAISE EXCEPTION 'Duree de retention reservations invalide (doit etre >= 0).' USING ERRCODE = '23514';
  END IF;
  IF p_consultations_days IS NOT NULL AND p_consultations_days < 0 THEN
    RAISE EXCEPTION 'Duree de retention consultations invalide (doit etre >= 0).' USING ERRCODE = '23514';
  END IF;
  IF p_notifications_days IS NOT NULL AND p_notifications_days < 0 THEN
    RAISE EXCEPTION 'Duree de retention notifications invalide (doit etre >= 0).' USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.library_retention_policies (
    library_id,
    retention_loans_days,
    retention_reservations_days,
    retention_consultations_days,
    retention_notifications_days,
    notes,
    updated_by
  ) VALUES (
    p_library_id,
    p_loans_days,
    p_reservations_days,
    p_consultations_days,
    p_notifications_days,
    p_notes,
    v_user_id
  )
  ON CONFLICT (library_id) DO UPDATE
    SET
      retention_loans_days = EXCLUDED.retention_loans_days,
      retention_reservations_days = EXCLUDED.retention_reservations_days,
      retention_consultations_days = EXCLUDED.retention_consultations_days,
      retention_notifications_days = EXCLUDED.retention_notifications_days,
      notes = EXCLUDED.notes,
      updated_by = EXCLUDED.updated_by;

  RETURN public.fn_get_retention_policy(p_library_id);
END;
$function$;

-- ============================================================================
-- Type A : fn_team_list_memberships (retrait administrador IN + CASE WHEN)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_team_list_memberships(p_scope text, p_library_id uuid DEFAULT NULL::uuid)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_caller            uuid := auth.uid();
    v_caller_is_netadmin boolean;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'auth_required'
            USING HINT = 'Sign in before calling this function.';
    END IF;

    IF p_scope NOT IN ('library', 'network') THEN
        RAISE EXCEPTION 'invalid_scope'
            USING HINT = 'p_scope must be ''library'' or ''network''.';
    END IF;

    v_caller_is_netadmin := public.fn_caller_is_network_admin();

    IF p_scope = 'library' THEN
        IF p_library_id IS NULL THEN
            RAISE EXCEPTION 'library_id_required'
                USING HINT = 'Scope library requires a non-null p_library_id.';
        END IF;

        IF NOT (
            v_caller_is_netadmin
            OR public.user_has_library_staff_role(v_caller, p_library_id)
        ) THEN
            RAISE EXCEPTION 'forbidden'
                USING HINT = 'Caller is not staff of this library and not a network administrator.';
        END IF;

        -- F.2 v0.3 : retrait 'administrador' (role local supprime).
        -- Le CASE WHEN 'administrador' est aussi retire (devenu mort code).
        RETURN QUERY
            SELECT jsonb_build_object(
                'id',                          ulm.id,
                'user_id',                     ulm.user_id,
                'library_id',                  ulm.library_id,
                'role',                        ulm.role,
                'status',                      ulm.status,
                'is_primary',                  ulm.is_primary,
                'created_at',                  ulm.created_at,
                'updated_at',                  ulm.updated_at,
                'is_restricted',               ulm.is_restricted,
                'restricted_reason',           ulm.restricted_reason,
                'pending_removal_until',       ulm.pending_removal_until,
                'pending_removal_requested_by', ulm.pending_removal_requested_by,
                'profiles', jsonb_build_object(
                    'email',      p.email,
                    'first_name', p.first_name,
                    'last_name',  p.last_name,
                    'public_id',  p.public_id
                ),
                'libraries', jsonb_build_object(
                    'id',         l.id,
                    'name',       l.name,
                    'short_name', l.short_name,
                    'slug',       l.slug
                )
            )
            FROM public.user_library_memberships ulm
            LEFT JOIN public.profiles p  ON p.id = ulm.user_id
            LEFT JOIN public.libraries l ON l.id = ulm.library_id
            WHERE ulm.library_id = p_library_id
              AND ulm.role IN ('librarian', 'coordenador')
            ORDER BY
                CASE ulm.role
                    WHEN 'coordenador'   THEN 1
                    WHEN 'librarian'     THEN 2
                    ELSE 99
                END,
                p.last_name,
                p.first_name,
                ulm.created_at;

        RETURN;
    END IF;

    IF p_scope = 'network' THEN
        IF NOT v_caller_is_netadmin THEN
            RAISE EXCEPTION 'forbidden'
                USING HINT = 'Network scope is reserved to network administrators.';
        END IF;

        RETURN QUERY
            SELECT jsonb_build_object(
                'id',                          ulm.id,
                'user_id',                     ulm.user_id,
                'library_id',                  ulm.library_id,
                'role',                        ulm.role,
                'status',                      ulm.status,
                'is_primary',                  ulm.is_primary,
                'created_at',                  ulm.created_at,
                'updated_at',                  ulm.updated_at,
                'is_restricted',               ulm.is_restricted,
                'restricted_reason',           ulm.restricted_reason,
                'pending_removal_until',       ulm.pending_removal_until,
                'pending_removal_requested_by', ulm.pending_removal_requested_by,
                'profiles', jsonb_build_object(
                    'email',      p.email,
                    'first_name', p.first_name,
                    'last_name',  p.last_name,
                    'public_id',  p.public_id
                ),
                'libraries', jsonb_build_object(
                    'id',         l.id,
                    'name',       l.name,
                    'short_name', l.short_name,
                    'slug',       l.slug
                )
            )
            FROM public.user_library_memberships ulm
            LEFT JOIN public.profiles p  ON p.id = ulm.user_id
            LEFT JOIN public.libraries l ON l.id = ulm.library_id
            WHERE ulm.role IN ('librarian', 'coordenador')
            ORDER BY
                l.short_name NULLS LAST,
                CASE ulm.role
                    WHEN 'coordenador'   THEN 1
                    WHEN 'librarian'     THEN 2
                    ELSE 99
                END,
                p.last_name,
                p.first_name,
                ulm.created_at;

        RETURN;
    END IF;
END;
$function$;

-- ============================================================================
-- Type A : user_can_manage_library_notifications
-- ============================================================================

CREATE OR REPLACE FUNCTION public.user_can_manage_library_notifications(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships ulm
    WHERE ulm.user_id = auth.uid()
      AND ulm.library_id = p_library_id
      AND ulm.status = 'active'
      AND lower(coalesce(ulm.role, '')) IN ('librarian', 'coordenador')
  );
$function$;

-- ============================================================================
-- Type A : user_has_library_staff_role
-- ============================================================================

CREATE OR REPLACE FUNCTION public.user_has_library_staff_role(p_user_id uuid, p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  -- F.2 v0.3 : retrait 'administrador' (role local supprime)
  select exists (
    select 1
    from public.user_library_memberships ulm
    where ulm.user_id = p_user_id
      and ulm.library_id = p_library_id
      and ulm.status = 'active'
      and lower(coalesce(ulm.role, '')) in (
        'librarian',
        'coordenador'
        -- TODO: harmoniser ces valeurs en anglais lors d'une migration
        -- de nommage des roles (voir dette technique audit famille D, point 2).
      )
  );
$function$;

COMMIT;
