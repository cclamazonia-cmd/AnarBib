-- Retour arrière de 20261012111851_sept_portes_sans_appelant_quittent_le_schema_api.sql
-- Recrée les sept fonctions api telles qu'elles étaient en production le 11/10/2026
-- (pg_get_functiondef), puis les referme à tous les rôles comme B20 les avait laissées.
-- Fichier préfixé « _rollback_ » : jamais appliqué par la CI, à jouer à la main si besoin.

CREATE OR REPLACE FUNCTION api.attach_exemplar(p_book_id bigint, p_tombo text DEFAULT NULL::text, p_circulation_policy text DEFAULT NULL::text, p_visibility text DEFAULT NULL::text, p_acquisition_mode text DEFAULT NULL::text, p_acquisition_date date DEFAULT NULL::date, p_provenance_note text DEFAULT NULL::text, p_source_library text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid          uuid := auth.uid();
  v_library_id   uuid;
  v_role         text;
  v_bib_ref      text;
  v_pol          text := nullif(btrim(lower(coalesce(p_circulation_policy, ''))), '');
  v_vis          text := nullif(btrim(lower(coalesce(p_visibility, ''))), '');
  v_holding_id   bigint;
  v_draft_id     bigint;
  v_exemplar_id  bigint;
begin
  -- auth
  if v_uid is null then
    raise exception 'auth_required'
      using errcode = '28000', hint = 'Authentification obrigatoria.';
  end if;

  -- biblio courante = membership actif principal ; doit etre staff
  select ulm.library_id, ulm.role
    into v_library_id, v_role
  from public.user_library_memberships ulm
  where ulm.user_id = v_uid
    and ulm.status = 'active'
    and ulm.is_primary = true
  limit 1;

  if v_library_id is null then
    raise exception 'library_not_identified'
      using errcode = 'P0001',
            hint = 'Nenhuma biblioteca ativa/principal encontrada para o usuario atual.';
  end if;

  if v_role not in ('librarian', 'coordenador') then
    raise exception 'not_staff_of_this_library'
      using errcode = '42501',
            hint = 'Esta acao esta reservada a equipe da biblioteca.';
  end if;

  -- garde-fous d'enum (laisse passer null = defaut/seed)
  if v_pol is not null and v_pol not in ('emprestavel', 'consulta', 'ambos') then
    raise exception 'invalid_circulation_policy: %', p_circulation_policy
      using errcode = '22023',
            hint = 'Padrao de circulacao invalido (emprestavel|consulta|ambos).';
  end if;
  if v_vis is not null and v_vis not in ('public', 'staff_only') then
    raise exception 'invalid_visibility: %', p_visibility
      using errcode = '22023',
            hint = 'Visibilidade invalida (public|staff_only).';
  end if;

  -- notice cible : doit exister (notice publiee, partagee reseau)
  select b.bib_ref into v_bib_ref
  from public.books b
  where b.id = p_book_id;

  if not found then
    raise exception 'book_not_found: %', p_book_id
      using errcode = 'P0001',
            hint = format('Ficha %s nao encontrada.', p_book_id);
  end if;

  -- get-or-create du holding local (Camada 2) pour (notice, biblio courante)
  insert into public.book_holdings (book_id, library_id)
  values (p_book_id, v_library_id)
  on conflict (book_id, library_id) do update
    set updated_at = now()
  returning id into v_holding_id;

  -- brouillon d'exemplaire deja resolu sur le holding ; attributs optionnels.
  -- circulation_policy null => publish_exemplar_draft seede depuis la notice (P1.2).
  insert into public.exemplar_drafts (
    action, status,
    target_library_id, target_holding_id, target_bib_ref,
    tombo,
    circulation_policy, visibility,
    acquisition_mode, acquisition_date, provenance_note, source_library,
    created_by, updated_by
  )
  values (
    'create', 'ready',
    v_library_id, v_holding_id, v_bib_ref,
    nullif(btrim(coalesce(p_tombo, '')), ''),
    v_pol,
    coalesce(v_vis, 'public'),
    nullif(btrim(coalesce(p_acquisition_mode, '')), ''),
    p_acquisition_date,
    nullif(btrim(coalesce(p_provenance_note, '')), ''),
    nullif(btrim(coalesce(p_source_library, '')), ''),
    v_uid, v_uid
  )
  returning id into v_draft_id;

  -- publication -> cree l'exemplaire (seed P1.2) et renvoie son id
  v_exemplar_id := public.publish_exemplar_draft(v_draft_id);

  -- le holding vient peut-etre d'etre cree (0/0) : recalcul des compteurs
  perform public.fn_v2_recompute_holdings_availability(array[v_holding_id]::bigint[], null);

  return v_exemplar_id;
end;
$function$;

CREATE OR REPLACE FUNCTION api.clear_loan_return_schedule(p_emprestimo_id bigint, p_line_nos integer[])
 RETURNS TABLE(ok boolean, message text, return_scheduled_for timestamp with time zone)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  IF p_line_nos IS NULL OR array_length(p_line_nos, 1) = 0 THEN
    RAISE EXCEPTION 'line_required' USING ERRCODE = 'P0001', HINT = 'Pelo menos uma linha deve ser indicada.';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'loan_not_found' USING ERRCODE = 'P0001', HINT = format('Emprestimo %s nao encontrado.', p_emprestimo_id);
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF v_actor_role = 'leitor' AND v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'not_your_loan' USING ERRCODE = '42501', HINT = 'Voce so pode cancelar o agendamento dos seus proprios emprestimos.';
  END IF;

  IF NOT public.fn_check_loan_action('clear_return_schedule', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
  END IF;

  RETURN QUERY
  SELECT * FROM public.fn_v2_clear_emprestimo_return_schedule(
    p_emprestimo_id := p_emprestimo_id,
    p_line_nos := p_line_nos,
    p_actor_role := v_actor_role
  );
END;
$function$;

CREATE OR REPLACE FUNCTION api.schedule_loan_return(p_emprestimo_id bigint, p_line_nos integer[], p_return_scheduled_for timestamp with time zone)
 RETURNS TABLE(ok boolean, message text, return_scheduled_for timestamp with time zone)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  IF p_line_nos IS NULL OR array_length(p_line_nos, 1) = 0 THEN
    RAISE EXCEPTION 'line_required' USING ERRCODE = 'P0001', HINT = 'Pelo menos uma linha deve ser indicada.';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'loan_not_found' USING ERRCODE = 'P0001', HINT = format('Emprestimo %s nao encontrado.', p_emprestimo_id);
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  -- Si lecteur, verifier ownership
  IF v_actor_role = 'leitor' AND v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'not_your_loan' USING ERRCODE = '42501', HINT = 'Voce so pode agendar a devolucao dos seus proprios emprestimos.';
  END IF;

  IF NOT public.fn_check_loan_action('schedule_return', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
  END IF;

  RETURN QUERY
  SELECT * FROM public.fn_v2_schedule_emprestimo_return(
    p_emprestimo_id := p_emprestimo_id,
    p_line_nos := p_line_nos,
    p_return_scheduled_for := p_return_scheduled_for,
    p_actor_role := v_actor_role
  );
END;
$function$;

CREATE OR REPLACE FUNCTION api.mark_loan_return_missed(p_emprestimo_id bigint, p_line_nos integer[])
 RETURNS TABLE(ok boolean, message text)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  IF p_line_nos IS NULL OR array_length(p_line_nos, 1) = 0 THEN
    RAISE EXCEPTION 'line_required' USING ERRCODE = 'P0001', HINT = 'Pelo menos uma linha deve ser indicada.';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'loan_not_found' USING ERRCODE = 'P0001', HINT = format('Emprestimo %s nao encontrado.', p_emprestimo_id);
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('mark_return_missed', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
  END IF;

  RETURN QUERY
  SELECT * FROM public.fn_v2_mark_emprestimo_return_missed(
    p_emprestimo_id := p_emprestimo_id,
    p_line_nos := p_line_nos,
    p_actor_role := v_actor_role
  );
END;
$function$;

CREATE OR REPLACE FUNCTION api.refuse_pickup_slot(p_reserva_id bigint, p_line_no integer, p_reason text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_current_stage text;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  -- Validation paramètre p_reason (obligatoire, ≥ 5 caractères trim)
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'reason_required_min_5_chars'
      USING ERRCODE = '22023',
            HINT = 'Pour refuser un créneau, indique une raison d''au moins 5 caractères (ex : indisponibilité, autre lieu préféré, etc.)';
  END IF;

  -- Vérifier ownership + récupérer current_stage
  SELECT r.user_id, riw.workflow_stage
    INTO v_owner, v_current_stage
  FROM public.reservas_v2 r
  JOIN public.reserva_item_workflow_v2 riw ON riw.reserva_id = r.id
  WHERE r.id = p_reserva_id AND riw.line_no = p_line_no;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'reserva_line_not_found' USING ERRCODE = '02000';
  END IF;

  IF v_owner <> v_uid THEN
    RAISE EXCEPTION 'not_your_reserva' USING ERRCODE = '42501';
  END IF;

  IF v_current_stage NOT IN ('retirada_agendada', 're-retirada_agendada', 'retirada_a_combinar') THEN
    RAISE EXCEPTION 'pickup_reply_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format('stage actuel = %s, attendu retirada_agendada|re-retirada_agendada|retirada_a_combinar', v_current_stage);
  END IF;

  v_n := public.fn_v2_set_reserva_linhas_pickup_reply(
    p_reserva_id, ARRAY[p_line_no], 'recusado_leitor', btrim(p_reason)
  );
  RETURN v_n;
END;
$function$;

CREATE OR REPLACE FUNCTION api.conv_controle_qualite(p_regra text DEFAULT NULL::text, p_limite integer DEFAULT 500)
 RETURNS TABLE(dominio text, regra text, problema text, id text, valor text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'private', 'public', 'pg_catalog'
AS $function$
begin
  if not public.fn_caller_is_staff() then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;

  return query
    select v.dominio, v.regra, v.problema, v.id, v.valor
      from private.v_conv_controle_qualite v
     where p_regra is null or v.regra = p_regra
     order by v.dominio, v.regra, v.id
     limit greatest(1, least(coalesce(p_limite, 500), 5000));
end;
$function$;

CREATE OR REPLACE FUNCTION api.conv_controle_resumo()
 RETURNS TABLE(dominio text, regra text, problema text, total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'private', 'public', 'pg_catalog'
AS $function$
begin
  if not public.fn_caller_is_staff() then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;

  return query
    select r.dominio, r.regra, r.problema, r.total
      from private.v_conv_controle_resumo r
     order by r.total desc;
end;
$function$;

-- Refermées comme B20 les avait laissées : aucun rôle de l'application ne les exécute.
REVOKE ALL ON FUNCTION api.attach_exemplar(bigint, text, text, text, text, date, text, text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION api.clear_loan_return_schedule(bigint, integer[]) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION api.schedule_loan_return(bigint, integer[], timestamp with time zone) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION api.mark_loan_return_missed(bigint, integer[]) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION api.refuse_pickup_slot(bigint, integer, text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION api.conv_controle_qualite(text, integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION api.conv_controle_resumo() FROM PUBLIC, anon, authenticated, service_role;
