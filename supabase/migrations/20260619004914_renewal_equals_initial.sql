-- =========================================================================
-- Circulation : option « le renouvellement reprend la durée initiale du prêt »
-- =========================================================================
-- Date     : 2026-06-19
-- Chantier : Renouvellement = durée initiale (position C, généralisable)
-- Auteur   : Claude (assistant·e)
-- Session  : Renouvellement = durée initiale (réunion exécutive BLMF)
-- Branche  : feat-renewal-equals-initial (hors worktree partagé)
--
-- Contexte : les durées de prêt INITIALES sont étagées par nombre d'ouvrages
-- (résolues avec quantity = total du lot), tandis que le RENOUVELLEMENT est
-- résolu item par item avec quantity = 1 -> il ne « voit » jamais le palier
-- d'origine. Impossible donc, par simple config (renewal_days), d'obtenir
-- « renouvellement = durée initiale » quand l'initial est étagé.
--
-- Solution (option C) : un flag PAR JEU DE RÈGLES,
-- library_circulation_policy_sets.renewal_equals_initial. Quand il est actif,
-- fn_v2_extend_core prolonge de la DURÉE INITIALE RÉELLE du prêt — déjà encodée
-- dans (item.due_at - item.created_at), donc l'étagement est repris
-- automatiquement, et un éventuel due_at personnalisé à la création aussi —
-- au lieu de renewal_days. La règle `renewal` reste nécessaire (elle pilote
-- SI / COMBIEN de renouvellements via renewable / renewal_max_count) ; seule la
-- DURÉE est dérivée du prêt initial. Réutilisable par toute biblio qui active
-- le flag sur son jeu de règles.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) Flag sur le jeu de règles
-- -------------------------------------------------------------------------
ALTER TABLE public.library_circulation_policy_sets
  ADD COLUMN IF NOT EXISTS renewal_equals_initial boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.library_circulation_policy_sets.renewal_equals_initial IS
  'Si vrai, le renouvellement prolonge de la durée initiale réelle du prêt (due_at - created_at), reprenant l''étagement, au lieu de renewal_days. La règle renewal pilote toujours SI/COMBIEN (renewable, renewal_max_count).';

-- -------------------------------------------------------------------------
-- 2) fn_v2_extend_core : durée du renouvellement = durée initiale si le flag actif
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_v2_extend_core(p_emprestimo_id bigint, p_line_nos integer[] DEFAULT NULL::integer[], p_require_self_only boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_header public.emprestimos_v2%ROWTYPE;
  v_actor public.my_access%ROWTYPE;
  v_is_self boolean := false;
  v_block text;
  v_item record;
  v_rule record;
  v_renewed jsonb := '[]'::jsonb;
  v_skipped jsonb := '[]'::jsonb;
  v_has_reservation boolean;
  v_new_due date;
  v_extension_note text;
  v_any_renewed boolean := false;
  v_first_new_due date := NULL;
  v_renewal_eq_initial boolean := false;   -- ← option C : durée = durée initiale
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  SELECT * INTO v_header FROM public.emprestimos_v2 WHERE id = p_emprestimo_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  IF NOT public.fn_library_has_circulation(v_header.library_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'circulation_disabled');
  END IF;

  v_is_self := (v_header.user_id = auth.uid());
  IF p_require_self_only THEN
    IF NOT v_is_self THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
    END IF;
  ELSE
    IF NOT v_is_self THEN
      SELECT * INTO v_actor FROM public.my_access LIMIT 1;
      IF NOT (COALESCE(v_actor.can_access_painel, false) IS true
              AND v_actor.library_id = v_header.library_id) THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
      END IF;
    END IF;
  END IF;

  v_block := public.fn_membership_can_engage_circulation(v_header.user_id, v_header.library_id);
  IF v_block = 'dues' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'dues_blocked');
  ELSIF v_block = 'no_active_membership' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_active_membership');
  ELSIF v_block = 'restricted' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'restricted');
  END IF;

  -- ← OPTION C : flag du jeu de règles ACTIF de la biblio (même sélection que
  -- resolve_circulation_rule). Si vrai, la durée du renouvellement = durée
  -- initiale réelle de chaque item.
  SELECT COALESCE(s.renewal_equals_initial, false)
    INTO v_renewal_eq_initial
  FROM public.library_circulation_policy_sets s
  WHERE s.library_id = v_header.library_id
    AND s.is_active = true
    AND s.status = 'active'
    AND (s.effective_from IS NULL OR s.effective_from <= CURRENT_DATE)
    AND (s.effective_until IS NULL OR s.effective_until >= CURRENT_DATE)
  ORDER BY s.activated_at DESC NULLS LAST, s.updated_at DESC, s.id DESC
  LIMIT 1;
  v_renewal_eq_initial := COALESCE(v_renewal_eq_initial, false);

  v_extension_note := CASE WHEN v_is_self THEN 'renewal_by_reader' ELSE 'renewal_by_library' END;

  FOR v_item IN
    SELECT i.line_no, i.book_id, i.holding_id,
           COALESCE(i.renewals_used, 0) AS renewals_used,
           COALESCE(i.extended_until, i.due_at) AS current_due,
           i.due_at AS original_due,
           i.created_at AS item_created_at
    FROM public.emprestimo_itens_v2 i
    WHERE i.emprestimo_id = p_emprestimo_id
      AND i.item_status = 'aberto'
      AND (p_line_nos IS NULL OR i.line_no = ANY(p_line_nos))
    ORDER BY i.line_no
  LOOP
    IF COALESCE(v_item.current_due, CURRENT_DATE) < CURRENT_DATE THEN
      v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'overdue');
      CONTINUE;
    END IF;

    SELECT EXISTS (
      SELECT 1
        FROM public.reserva_linhas_v2 rl
        JOIN public.reservas_v2 r ON r.id = rl.reserva_id
       WHERE rl.book_id = v_item.book_id
         AND r.library_id = v_header.library_id
         AND r.user_id <> v_header.user_id
         AND r.status_global IN ('ativa', 'parcialmente_encerrada')
         AND rl.item_status = 'ativa'
    ) INTO v_has_reservation;
    IF v_has_reservation THEN
      v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'reserved_by_other');
      CONTINUE;
    END IF;

    SELECT * INTO v_rule
    FROM api.get_due_date_after_renewal(
      p_library_id := v_header.library_id,
      p_user_id := v_header.user_id,
      p_book_id := v_item.book_id,
      p_holding_id := v_item.holding_id,
      p_quantity := 1,
      p_current_due_date := GREATEST(COALESCE(v_item.current_due, CURRENT_DATE), CURRENT_DATE),
      p_renewals_used := v_item.renewals_used,
      p_as_of_date := CURRENT_DATE
    )
    LIMIT 1;

    -- En mode « renouvellement = durée initiale », new_due_date (issu de
    -- renewal_days) peut être NULL : on n'exige pas renewal_days, la durée vient
    -- du prêt initial. Sinon (mode classique), une durée nulle => non renouvelable.
    IF v_rule IS NULL
       OR (NOT (v_renewal_eq_initial AND v_item.original_due IS NOT NULL)
           AND v_rule.new_due_date IS NULL) THEN
      v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'not_renewable');
      CONTINUE;
    END IF;
    IF COALESCE(v_rule.renewable, false) IS false THEN
      IF COALESCE(v_rule.renewals_remaining, 0) <= 0 AND v_item.renewals_used > 0 THEN
        v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'quota_exceeded');
      ELSE
        v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'not_renewable');
      END IF;
      CONTINUE;
    END IF;
    IF v_item.renewals_used >= 1 AND COALESCE(v_rule.renewals_remaining, 0) <= 0 THEN
      v_skipped := v_skipped || jsonb_build_object('line_no', v_item.line_no, 'reason', 'already_extended');
      CONTINUE;
    END IF;

    -- Durée : initiale (option C) ou renewal_days (classique).
    IF v_renewal_eq_initial AND v_item.original_due IS NOT NULL THEN
      v_new_due := GREATEST(COALESCE(v_item.current_due, CURRENT_DATE), CURRENT_DATE)
                 + GREATEST((v_item.original_due - v_item.item_created_at::date), 1);
    ELSE
      v_new_due := v_rule.new_due_date;
    END IF;

    UPDATE public.emprestimo_itens_v2
       SET extended_until = v_new_due,
           renewals_used = renewals_used + 1,
           extension_note = COALESCE(NULLIF(v_rule.explanation, ''), v_extension_note),
           return_schedule_status = 'emprestimo_prorrogado',
           return_scheduled_for = NULL,
           return_scheduled_by = NULL,
           return_scheduled_at = NULL,
           return_completed_at = NULL,
           return_missed_at = NULL,
           updated_at = now()
     WHERE emprestimo_id = p_emprestimo_id
       AND line_no = v_item.line_no;

    v_renewed := v_renewed || jsonb_build_object('line_no', v_item.line_no, 'new_due_date', v_new_due);
    v_any_renewed := true;
    IF v_first_new_due IS NULL THEN v_first_new_due := v_new_due; END IF;
  END LOOP;

  IF jsonb_array_length(v_renewed) = 0 AND jsonb_array_length(v_skipped) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  IF v_any_renewed THEN
    UPDATE public.emprestimos_v2
       SET extended_at = now(), updated_at = now()
     WHERE id = p_emprestimo_id;

    PERFORM public.fn_dispatch_notify_event(
      'emprestimo_v2_prorrogado',
      p_emprestimo_id,
      jsonb_build_object(
        'line_nos',
        (SELECT array_agg((e->>'line_no')::int ORDER BY (e->>'line_no')::int)
           FROM jsonb_array_elements(v_renewed) e)
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', v_any_renewed,
    'reason', CASE WHEN v_any_renewed THEN 'renewed'
                   ELSE COALESCE(v_skipped->0->>'reason', 'not_renewable') END,
    'new_due_date', v_first_new_due,
    'renewed', v_renewed,
    'skipped', v_skipped
  );
END;
$function$;

-- -------------------------------------------------------------------------
-- 3) upsert_library_circulation_policy_set : accepter/persister le flag
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.upsert_library_circulation_policy_set(p_library_id uuid, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS library_circulation_policy_sets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_library_id uuid;
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_id bigint := nullif(trim(coalesce(v_payload->>'id', '')), '')::bigint;
  v_existing public.library_circulation_policy_sets%rowtype;
  v_status text;
  v_row public.library_circulation_policy_sets;
begin
  v_library_id := public.resolve_managed_library_id(p_library_id);

  if not public.can_manage_library_circulation_policies(v_library_id) then
    raise exception 'permission denied for library_circulation_policy_sets';
  end if;

  if v_id is not null then
    select * into v_existing from public.library_circulation_policy_sets s where s.id = v_id;
    if v_existing.id is null then
      raise exception 'Conjunto de regras não encontrado: %', v_id;
    end if;
    if v_existing.library_id <> v_library_id then
      raise exception 'Este conjunto de regras pertence a outra biblioteca.';
    end if;
  end if;

  v_status := coalesce(nullif(trim(coalesce(v_payload->>'status', '')), ''), coalesce(v_existing.status, 'draft'));
  if v_status not in ('draft', 'active', 'archived') then
    v_status := coalesce(v_existing.status, 'draft');
  end if;

  if v_existing.id is null then
    insert into public.library_circulation_policy_sets (
      library_id, regulation_document_id, label, status, is_active, config_version,
      effective_from, effective_until, activation_note, scope_note, metadata,
      renewal_equals_initial,
      created_by, updated_by, activated_at, activated_by
    )
    values (
      v_library_id,
      nullif(trim(coalesce(v_payload->>'regulation_document_id', '')), '')::bigint,
      coalesce(nullif(trim(coalesce(v_payload->>'label', '')), ''), 'Novo conjunto de regras'),
      v_status, false,
      greatest(coalesce((v_payload->>'config_version')::integer, 1), 1),
      case when nullif(trim(coalesce(v_payload->>'effective_from', '')), '') is null then null else (v_payload->>'effective_from')::date end,
      case when nullif(trim(coalesce(v_payload->>'effective_until', '')), '') is null then null else (v_payload->>'effective_until')::date end,
      nullif(trim(coalesce(v_payload->>'activation_note', '')), ''),
      nullif(trim(coalesce(v_payload->>'scope_note', '')), ''),
      coalesce(v_payload->'metadata', '{}'::jsonb),
      coalesce((v_payload->>'renewal_equals_initial')::boolean, false),
      auth.uid(), auth.uid(), null, null
    )
    returning * into v_row;
  else
    update public.library_circulation_policy_sets s
       set regulation_document_id = case when v_payload ? 'regulation_document_id' then nullif(trim(coalesce(v_payload->>'regulation_document_id', '')), '')::bigint else s.regulation_document_id end,
           label = coalesce(nullif(trim(coalesce(v_payload->>'label', '')), ''), s.label),
           status = v_status,
           config_version = greatest(coalesce((v_payload->>'config_version')::integer, s.config_version), 1),
           effective_from = case when v_payload ? 'effective_from' then case when nullif(trim(coalesce(v_payload->>'effective_from', '')), '') is null then null else (v_payload->>'effective_from')::date end else s.effective_from end,
           effective_until = case when v_payload ? 'effective_until' then case when nullif(trim(coalesce(v_payload->>'effective_until', '')), '') is null then null else (v_payload->>'effective_until')::date end else s.effective_until end,
           activation_note = case when v_payload ? 'activation_note' then nullif(trim(coalesce(v_payload->>'activation_note', '')), '') else s.activation_note end,
           scope_note = case when v_payload ? 'scope_note' then nullif(trim(coalesce(v_payload->>'scope_note', '')), '') else s.scope_note end,
           metadata = case when v_payload ? 'metadata' then coalesce(v_payload->'metadata', '{}'::jsonb) else s.metadata end,
           renewal_equals_initial = case when v_payload ? 'renewal_equals_initial' then coalesce((v_payload->>'renewal_equals_initial')::boolean, false) else s.renewal_equals_initial end,
           updated_at = now(),
           updated_by = auth.uid()
     where s.id = v_existing.id
     returning * into v_row;
  end if;

  return v_row;
end;
$function$;

-- -------------------------------------------------------------------------
-- 4) get_library_circulation_policy_sets_ui : exposer le flag (DROP+CREATE car
--    le type de retour change ; grants reposés)
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS api.get_library_circulation_policy_sets_ui(uuid);
CREATE OR REPLACE FUNCTION api.get_library_circulation_policy_sets_ui(p_library_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(id bigint, library_id uuid, library_slug text, library_name text, regulation_document_id bigint, regulation_doc_kind text, regulation_version_label text, label text, status text, is_active boolean, renewal_equals_initial boolean, config_version integer, effective_from date, effective_until date, activation_note text, scope_note text, metadata jsonb, rule_count bigint, active_rule_count bigint, created_at timestamp with time zone, updated_at timestamp with time zone, activated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'api', 'pg_temp'
AS $function$
declare
  v_library_id uuid;
begin
  v_library_id := public.resolve_managed_library_id(p_library_id);

  return query
  select
    s.id, s.library_id, l.slug, l.name,
    s.regulation_document_id, d.doc_kind, d.version_label,
    s.label, s.status, s.is_active, s.renewal_equals_initial,
    s.config_version, s.effective_from, s.effective_until,
    s.activation_note, s.scope_note, s.metadata,
    coalesce(rc.rule_count, 0) as rule_count,
    coalesce(rc.active_rule_count, 0) as active_rule_count,
    s.created_at, s.updated_at, s.activated_at
  from public.library_circulation_policy_sets s
  join public.libraries l on l.id = s.library_id
  left join public.library_regulation_documents d on d.id = s.regulation_document_id
  left join lateral (
    select count(*)::bigint as rule_count,
           count(*) filter (where r.is_active)::bigint as active_rule_count
    from public.library_circulation_policy_rules r
    where r.policy_set_id = s.id
  ) rc on true
  where s.library_id = v_library_id
  order by s.is_active desc, s.activated_at desc nulls last, s.updated_at desc, s.id desc;
end;
$function$;
REVOKE EXECUTE ON FUNCTION api.get_library_circulation_policy_sets_ui(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.get_library_circulation_policy_sets_ui(uuid) TO authenticated;

COMMIT;
