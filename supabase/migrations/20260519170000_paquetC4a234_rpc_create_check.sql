-- ============================================================================
-- Paquet C.4a.2/3/4 — Patches RPC creation (emprestimo + reserva + consulta)
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.3
-- Dependance : paquetC2_helpers_modes_profils.sql (fn_library_has_circulation)
--
-- Objectif : ajouter check fn_library_has_circulation() en debut de chaque RPC
-- de creation. Sans ce check, les fonctions SECURITY DEFINER bypassent les
-- RLS C.3 et pourraient creer des transactions sur biblio en off.
--
-- 3 RPC patchees :
--   - fn_v2_create_emprestimo_by_holdings (check sur v_actor.library_id)
--   - fn_v2_create_reserva_by_holdings (check sur v_batch_library_id)
--   - fn_v2_create_consulta_local_by_holdings (check sur v_batch_library_id)
--
-- Point d'injection : pour emprestimo, juste apres v_actor.library_id validee.
-- Pour reserva et consulta, juste apres la boucle qui definit v_batch_library_id
-- et avant les raise exception agreges.
--
-- Hint i18n : error.library.circulation_disabled (a traduire en C.4c x 6 locales).
--
-- Risque : modifie 3 fonctions de production. Mitigation : definitions exactement
-- identiques aux originales modulo le bloc ajoute.
-- ============================================================================

BEGIN;

-- ===========================================================================
-- C.4a.2 — fn_v2_create_emprestimo_by_holdings
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.fn_v2_create_emprestimo_by_holdings(p_user_id uuid, p_holding_ids bigint[], p_due_at date DEFAULT NULL::date, p_notes text DEFAULT NULL::text)
 RETURNS TABLE(ok boolean, emprestimo_id bigint, due_at date, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'api'
AS $function$
declare
  v_actor public.my_access%rowtype;
  v_holding_ids bigint[];
  v_holding_count integer;
  v_due_at date;
  v_emprestimo_id bigint;
  v_line_no integer := 0;

  v_holding_id bigint;
  v_row record;
  v_item record;

  v_missing bigint[] := '{}';
  v_not_actor_library bigint[] := '{}';
  v_not_loanable bigint[] := '{}';
  v_unavailable bigint[] := '{}';
  v_consulta_active bigint[] := '{}';

  v_first_holding_id bigint := null;
  v_first_book_id bigint := null;
  v_rule record;
  v_legacy_loan_days integer := null;

  v_dues_blocked boolean;
  v_dues_status text;
  v_dues_message text;
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select *
    into v_actor
  from public.my_access
  limit 1;

  if coalesce(v_actor.can_access_painel, false) is false then
    raise exception 'Acesso bibliotecário obrigatório.';
  end if;

  if v_actor.library_id is null then
    raise exception 'Biblioteca ativa não identificada.';
  end if;

  -- ============================================================
  -- PAQUET C.4a.2 — check circulation_mode <> off
  -- ============================================================
  if not public.fn_library_has_circulation(v_actor.library_id) then
    raise exception 'A circulação está desativada para esta biblioteca. Não é possível criar empréstimos.'
      using errcode = 'P0001',
            hint = 'error.library.circulation_disabled';
  end if;

  v_dues_blocked := public.fn_is_loan_blocked_by_dues(p_user_id, v_actor.library_id);

  if v_dues_blocked then
    select dues_status into v_dues_status
    from public.v_active_memberships
    where user_id = p_user_id and library_id = v_actor.library_id;

    v_dues_message := case v_dues_status
      when 'never_paid' then
        'Contribuição obrigatória não registrada para este(a) leitor(a). Registre o pagamento antes de criar o empréstimo.'
      when 'expired' then
        'Contribuição vencida. Renove antes de criar o empréstimo.'
      else
        'Contribuição obrigatória não está em dia para este(a) leitor(a).'
    end;

    raise exception '%', v_dues_message
      using errcode = 'P0001',
            hint = 'Acesse a aba Contribuições no painel para registrar o pagamento.';
  end if;

  select array_agg(s.holding_id order by s.ord)
    into v_holding_ids
  from (
    select x.holding_id, min(x.ord) as ord
    from unnest(coalesce(p_holding_ids, '{}'::bigint[])) with ordinality as x(holding_id, ord)
    where x.holding_id is not null
    group by x.holding_id
  ) s;

  v_holding_count := coalesce(array_length(v_holding_ids, 1), 0);

  if v_holding_count = 0 then
    raise exception 'Informe ao menos 1 holding.';
  end if;

  foreach v_holding_id in array v_holding_ids
  loop
    select
      h.id as holding_id,
      h.book_id,
      h.library_id,
      coalesce(nullif(trim(h.local_bib_ref), ''), b.bib_ref) as local_bib_ref,
      b.titulo,
      b.autor,
      b.editora,
      b.ano,
      coalesce(h.loanable, b.loanable, true) as loanable
    into v_row
    from public.book_holdings h
    join public.books b
      on b.id = h.book_id
    where h.id = v_holding_id;

    if not found then
      v_missing := array_append(v_missing, v_holding_id);
      continue;
    end if;

    if v_row.library_id <> v_actor.library_id then
      v_not_actor_library := array_append(v_not_actor_library, v_holding_id);
      continue;
    end if;

    if coalesce(v_row.loanable, false) is false then
      v_not_loanable := array_append(v_not_loanable, v_holding_id);
      continue;
    end if;

    if exists (
      select 1
      from public.reserva_linhas_v2 rl
      join public.reservas_v2 r
        on r.id = rl.reserva_id
      where rl.holding_id = v_holding_id
        and rl.item_status = 'ativa'
        and r.library_id = v_actor.library_id
    ) then
      v_unavailable := array_append(v_unavailable, v_holding_id);
      continue;
    end if;

    if exists (
      select 1
      from public.consulta_linhas_v2 cl
      join public.consultas_locais_v2 c
        on c.id = cl.consulta_id
      where cl.holding_id = v_holding_id
        and cl.item_status = 'ativa'
        and c.library_id = v_actor.library_id
    ) then
      v_consulta_active := array_append(v_consulta_active, v_holding_id);
      continue;
    end if;

    select
      e.id,
      e.tombo
    into v_item
    from public.exemplares e
    where e.holding_id = v_holding_id
      and e.library_id = v_actor.library_id
      and not exists (
        select 1
        from public.emprestimo_itens_v2 i
        where i.item_id = e.id
          and i.item_status = 'aberto'
      )
      and not exists (
        select 1
        from public.reserva_linhas_v2 rl
        join public.reservas_v2 r
          on r.id = rl.reserva_id
        where (
            rl.holding_id = v_holding_id
            or rl.item_id = e.id
          )
          and rl.item_status = 'ativa'
          and r.library_id = v_actor.library_id
      )
    order by e.id
    limit 1;

    if not found then
      v_unavailable := array_append(v_unavailable, v_holding_id);
      continue;
    end if;
  end loop;

  if cardinality(v_missing) > 0 then
    raise exception 'Referência(s) não encontrada(s): %', public.fn_format_holding_refs(v_missing);
  end if;

  if cardinality(v_not_actor_library) > 0 then
    raise exception 'Referência(s) fora da biblioteca ativa: %', public.fn_format_holding_refs(v_not_actor_library);
  end if;

  if cardinality(v_not_loanable) > 0 then
    raise exception 'Referência(s) não emprestável(is): %', public.fn_format_holding_refs(v_not_loanable);
  end if;

  if cardinality(v_consulta_active) > 0 then
    raise exception 'Referência(s) com consulta local em curso: %', public.fn_format_holding_refs(v_consulta_active);
  end if;

  if cardinality(v_unavailable) > 0 then
    raise exception 'Nenhum exemplar disponível para a(s) referência(s): %', public.fn_format_holding_refs(v_unavailable);
  end if;

  if v_holding_count >= 1 then
    v_first_holding_id := v_holding_ids[1];

    select h.book_id
      into v_first_book_id
    from public.book_holdings h
    where h.id = v_first_holding_id
      and h.library_id = v_actor.library_id
    limit 1;
  end if;

  v_legacy_loan_days := case
    when v_holding_count = 1 then 21
    when v_holding_count between 2 and 3 then 30
    else 38
  end;

  select *
    into v_rule
  from api.resolve_circulation_rule(
    p_library_id := v_actor.library_id,
    p_mode := 'loan',
    p_user_id := p_user_id,
    p_book_id := v_first_book_id,
    p_holding_id := v_first_holding_id,
    p_quantity := v_holding_count,
    p_as_of_date := current_date,
    p_current_due_date := null,
    p_renewals_used := 0
  )
  limit 1;

  v_due_at := coalesce(
    p_due_at,
    current_date + coalesce(v_rule.loan_days, v_legacy_loan_days)
  );

  insert into public.emprestimos_v2 (
    user_id,
    library_id,
    notes,
    status_global,
    due_at,
    created_at,
    updated_at
  )
  values (
    p_user_id,
    v_actor.library_id,
    p_notes,
    'aberto',
    v_due_at,
    now(),
    now()
  )
  returning id into v_emprestimo_id;

  foreach v_holding_id in array v_holding_ids
  loop
    select
      h.id as holding_id,
      h.book_id,
      h.library_id,
      coalesce(nullif(trim(h.local_bib_ref), ''), b.bib_ref) as local_bib_ref,
      b.titulo,
      b.autor,
      b.editora,
      b.ano
    into v_row
    from public.book_holdings h
    join public.books b
      on b.id = h.book_id
    where h.id = v_holding_id;

    select
      e.id,
      e.tombo
    into v_item
    from public.exemplares e
    where e.holding_id = v_holding_id
      and e.library_id = v_actor.library_id
      and not exists (
        select 1
        from public.emprestimo_itens_v2 i
        where i.item_id = e.id
          and i.item_status = 'aberto'
      )
      and not exists (
        select 1
        from public.reserva_linhas_v2 rl
        join public.reservas_v2 r
          on r.id = rl.reserva_id
        where (
            rl.holding_id = v_holding_id
            or rl.item_id = e.id
          )
          and rl.item_status = 'ativa'
          and r.library_id = v_actor.library_id
      )
    order by e.id
    limit 1;

    v_line_no := v_line_no + 1;

    insert into public.emprestimo_itens_v2 (
      emprestimo_id,
      line_no,
      sub_id,
      book_id,
      holding_id,
      item_id,
      bib_ref,
      rotulo_cache,
      titulo_cache,
      autor_cache,
      editora_cache,
      ano_cache,
      item_status,
      due_at,
      created_at,
      updated_at
    )
    values (
      v_emprestimo_id,
      v_line_no,
      format('%s.%s', v_emprestimo_id, v_line_no),
      v_row.book_id,
      v_row.holding_id,
      v_item.id,
      v_row.local_bib_ref,
      v_item.tombo,
      v_row.titulo,
      v_row.autor,
      v_row.editora,
      v_row.ano,
      'aberto',
      v_due_at,
      now(),
      now()
    );
  end loop;

  update public.books b
     set available_count = greatest(coalesce(b.available_count, 0) - x.qty, 0)
    from (
      select i.book_id, count(*)::int as qty
      from public.emprestimo_itens_v2 i
      where i.emprestimo_id = v_emprestimo_id
      group by i.book_id
    ) x
   where b.id = x.book_id;

  perform public.fn_v2_recompute_from_emprestimo_lines(v_emprestimo_id, null);

  return query
  select true,
         v_emprestimo_id,
         v_due_at,
         coalesce(
           nullif(v_rule.explanation, ''),
           format('Empréstimo criado com %s item(ns).', v_line_no)
         );
end;
$function$;

-- ===========================================================================
-- C.4a.3 — fn_v2_create_reserva_by_holdings
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.fn_v2_create_reserva_by_holdings(p_user_id uuid, p_holding_ids bigint[], p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_notes text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'api'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_holding_ids bigint[];
  v_holding_id bigint;
  v_row record;
  v_policy record;

  v_reserva_id bigint;
  v_line_no int := 0;
  v_batch_library_id uuid := null;
  v_requested_quantity integer := 0;

  v_service_mode text := 'funcionamento_normal';
  v_allows_new_reservations boolean := true;

  v_missing bigint[] := '{}';
  v_duplicate bigint[] := '{}';
  v_unavailable bigint[] := '{}';
  v_not_loanable bigint[] := '{}';
  v_cross_library bigint[] := '{}';
  v_policy_blocked bigint[] := '{}';
  v_policy_blocked_message text := null;
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  if p_user_id is null or p_user_id <> v_uid then
    raise exception 'Você só pode criar reservas para sua própria conta.';
  end if;

  select array_agg(s.holding_id order by s.ord)
    into v_holding_ids
  from (
    select x.holding_id, min(x.ord) as ord
    from unnest(coalesce(p_holding_ids, '{}'::bigint[])) with ordinality as x(holding_id, ord)
    where x.holding_id is not null
    group by x.holding_id
  ) s;

  if coalesce(cardinality(v_holding_ids), 0) = 0 then
    raise exception 'Nenhum holding foi informado.';
  end if;

  v_requested_quantity := greatest(coalesce(cardinality(v_holding_ids), 0), 1);

  foreach v_holding_id in array v_holding_ids
  loop
    select
      h.id as holding_id,
      h.book_id,
      h.library_id,
      coalesce(nullif(trim(h.local_bib_ref), ''), b.bib_ref) as local_bib_ref,
      b.bib_ref as book_bib_ref,
      b.titulo,
      b.autor,
      b.editora,
      b.ano,
      coalesce(h.loanable, b.loanable, true) as loanable,
      (
        select count(*)::int
        from public.exemplares e
        where e.holding_id = h.id
      ) as exemplares_total,
      (
        select count(*)::int
        from public.emprestimo_itens_v2 i
        join public.exemplares e
          on e.id = i.item_id
        where e.holding_id = h.id
          and i.item_status = 'aberto'
      ) as emprestimos_abertos,
      (
        select count(*)::int
        from public.reserva_linhas_v2 rl
        where rl.holding_id = h.id
          and rl.item_status = 'ativa'
      ) as reservas_ativas
    into v_row
    from public.book_holdings h
    join public.books b
      on b.id = h.book_id
    where h.id = v_holding_id;

    if not found then
      v_missing := array_append(v_missing, v_holding_id);
      continue;
    end if;

    if v_batch_library_id is null then
      v_batch_library_id := v_row.library_id;
    elsif v_row.library_id <> v_batch_library_id then
      v_cross_library := array_append(v_cross_library, v_holding_id);
      continue;
    end if;

    if coalesce(v_row.loanable, true) is false then
      v_not_loanable := array_append(v_not_loanable, v_holding_id);
      continue;
    end if;

    if (
      coalesce(v_row.exemplares_total, 0)
      - coalesce(v_row.emprestimos_abertos, 0)
      - coalesce(v_row.reservas_ativas, 0)
    ) < 1 then
      v_unavailable := array_append(v_unavailable, v_holding_id);
      continue;
    end if;

    if exists (
      select 1
      from public.reserva_linhas_v2 rl
      join public.reservas_v2 r
        on r.id = rl.reserva_id
      where r.user_id = p_user_id
        and r.library_id = v_row.library_id
        and (
          rl.holding_id = v_row.holding_id
          or (rl.holding_id is null and rl.book_id = v_row.book_id)
        )
        and rl.item_status = 'ativa'
    ) then
      v_duplicate := array_append(v_duplicate, v_holding_id);
      continue;
    end if;

    select *
      into v_policy
    from api.resolve_circulation_rule(
      p_library_id := v_row.library_id,
      p_mode := 'reservation',
      p_user_id := p_user_id,
      p_book_id := v_row.book_id,
      p_holding_id := v_row.holding_id,
      p_quantity := v_requested_quantity,
      p_as_of_date := current_date,
      p_current_due_date := null,
      p_renewals_used := 0
    )
    limit 1;

    if coalesce(v_policy.reservation_allowed, false) is false then
      v_policy_blocked := array_append(v_policy_blocked, v_holding_id);
      if v_policy_blocked_message is null then
        v_policy_blocked_message := coalesce(
          nullif(v_policy.explanation, ''),
          'A política ativa de circulação não permite criar esta reserva no momento.'
        );
      end if;
      continue;
    end if;
  end loop;

  if cardinality(v_missing) > 0 then
    raise exception 'Referência(s) não encontrada(s): %', public.fn_format_holding_refs(v_missing);
  end if;

  if cardinality(v_not_loanable) > 0 then
    raise exception 'Referência(s) indisponível(is) para empréstimo: %', public.fn_format_holding_refs(v_not_loanable);
  end if;

  if cardinality(v_unavailable) > 0 then
    raise exception 'Sem exemplares disponíveis para reserva — referência(s): %', public.fn_format_holding_refs(v_unavailable);
  end if;

  if cardinality(v_duplicate) > 0 then
    raise exception 'Já existe reserva ativa para a(s) referência(s): %', public.fn_format_holding_refs(v_duplicate);
  end if;

  if cardinality(v_cross_library) > 0 then
    raise exception 'Os holdings informados pertencem a bibliotecas diferentes. Faça uma reserva por biblioteca. Referência(s) conflitante(s): %',
      public.fn_format_holding_refs(v_cross_library);
  end if;

  if cardinality(v_policy_blocked) > 0 then
    raise exception '% Referência(s) bloqueada(s): %',
      coalesce(v_policy_blocked_message, 'A política ativa de circulação não permite criar esta reserva no momento.'),
      public.fn_format_holding_refs(v_policy_blocked);
  end if;

  if v_batch_library_id is null then
    raise exception 'Nenhuma reserva pôde ser criada.';
  end if;

  -- ============================================================
  -- PAQUET C.4a.3 — check circulation_mode <> off
  -- ============================================================
  if not public.fn_library_has_circulation(v_batch_library_id) then
    raise exception 'A circulação está desativada para esta biblioteca. Não é possível criar reservas.'
      using errcode = 'P0001',
            hint = 'error.library.circulation_disabled';
  end if;

  select
    coalesce(s.service_mode, 'funcionamento_normal'),
    coalesce(s.allows_new_reservations, true)
  into
    v_service_mode,
    v_allows_new_reservations
  from public.library_service_state s
  where s.library_id = v_batch_library_id;

  if v_service_mode = 'pausada' or coalesce(v_allows_new_reservations, true) = false then
    raise exception 'As reservas públicas de empréstimo estão temporariamente fechadas para esta biblioteca.';
  end if;

  if v_service_mode = 'somente_consulta' then
    raise exception 'As reservas públicas de empréstimo estão fechadas no momento. Esta biblioteca recebe apenas pedidos de consulta local.';
  end if;

  insert into public.reservas_v2 (
    user_id,
    library_id,
    notes,
    status_global
  )
  values (
    p_user_id,
    v_batch_library_id,
    coalesce(nullif(trim(p_notes), ''), 'Reserva criada pela conta do(a/e) leitor(a/e).'),
    'ativa'
  )
  returning id into v_reserva_id;

  foreach v_holding_id in array v_holding_ids
  loop
    select
      h.id as holding_id,
      h.book_id,
      h.library_id,
      coalesce(nullif(trim(h.local_bib_ref), ''), b.bib_ref) as local_bib_ref,
      b.bib_ref as book_bib_ref,
      b.titulo,
      b.autor,
      b.editora,
      b.ano
    into v_row
    from public.book_holdings h
    join public.books b
      on b.id = h.book_id
    where h.id = v_holding_id;

    v_line_no := v_line_no + 1;

    insert into public.reserva_linhas_v2 (
      reserva_id,
      line_no,
      book_id,
      holding_id,
      bib_ref,
      item_id,
      titulo_cache,
      autor_cache,
      rotulo_cache,
      editora_cache,
      ano_cache,
      item_status,
      expires_at,
      notes
    )
    values (
      v_reserva_id,
      v_line_no,
      v_row.book_id,
      v_row.holding_id,
      v_row.local_bib_ref,
      null,
      v_row.titulo,
      v_row.autor,
      null,
      v_row.editora,
      v_row.ano,
      'ativa',
      p_expires_at,
      coalesce(nullif(trim(p_notes), ''), 'Reserva criada pela conta do(a/e) leitor(a/e).')
    );

    insert into public.reserva_item_workflow_v2 (
      reserva_id,
      line_no,
      workflow_stage,
      workflow_note,
      updated_by
    )
    values (
      v_reserva_id,
      v_line_no,
      'solicitada',
      coalesce(nullif(trim(p_notes), ''), 'Reserva recebida.'),
      v_uid
    );
  end loop;

  perform public.fn_v2_refresh_reserva_status_global(v_reserva_id);
  perform public.fn_v2_recompute_from_reserva_lines(v_reserva_id, null);

  return v_reserva_id;
end;
$function$;

-- ===========================================================================
-- C.4a.4 — fn_v2_create_consulta_local_by_holdings
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.fn_v2_create_consulta_local_by_holdings(p_user_id uuid, p_holding_ids bigint[], p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_notes text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'api'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_holding_ids bigint[];
  v_holding_id bigint;
  v_row record;
  v_policy record;

  v_consulta_id bigint;
  v_line_no int := 0;
  v_batch_library_id uuid := null;
  v_requested_quantity integer := 0;

  v_service_mode text := 'funcionamento_normal';
  v_allows_new_reservations boolean := true;

  v_missing bigint[] := '{}';
  v_duplicate bigint[] := '{}';
  v_unavailable bigint[] := '{}';
  v_cross_library bigint[] := '{}';
  v_policy_blocked bigint[] := '{}';
  v_policy_blocked_message text := null;
  v_loan_active bigint[] := '{}';
  v_reservation_active bigint[] := '{}';
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  if p_user_id is null or p_user_id <> v_uid then
    raise exception 'Você só pode criar pedidos de consulta para sua própria conta.';
  end if;

  select array_agg(s.holding_id order by s.ord)
    into v_holding_ids
  from (
    select x.holding_id, min(x.ord) as ord
    from unnest(coalesce(p_holding_ids, '{}'::bigint[])) with ordinality as x(holding_id, ord)
    where x.holding_id is not null
    group by x.holding_id
  ) s;

  if coalesce(cardinality(v_holding_ids), 0) = 0 then
    raise exception 'Nenhum holding foi informado.';
  end if;

  v_requested_quantity := greatest(coalesce(cardinality(v_holding_ids), 0), 1);

  foreach v_holding_id in array v_holding_ids
  loop
    select
      h.id as holding_id,
      h.book_id,
      h.library_id,
      coalesce(nullif(trim(h.local_bib_ref), ''), b.bib_ref) as local_bib_ref,
      b.bib_ref as book_bib_ref,
      b.titulo,
      b.autor,
      b.editora,
      b.ano,
      coalesce(h.loanable, b.loanable, true) as loanable,
      coalesce(h.available_count, 0) as available_count
    into v_row
    from public.book_holdings h
    join public.books b
      on b.id = h.book_id
    where h.id = v_holding_id;

    if not found then
      v_missing := array_append(v_missing, v_holding_id);
      continue;
    end if;

    if v_batch_library_id is null then
      v_batch_library_id := v_row.library_id;
    elsif v_row.library_id <> v_batch_library_id then
      v_cross_library := array_append(v_cross_library, v_holding_id);
      continue;
    end if;

    if coalesce(v_row.available_count, 0) < 1 then
      v_unavailable := array_append(v_unavailable, v_holding_id);
      continue;
    end if;

    if exists (
      select 1
      from public.consulta_linhas_v2 cl
      join public.consultas_locais_v2 c
        on c.id = cl.consulta_id
      where c.user_id = p_user_id
        and c.library_id = v_row.library_id
        and cl.holding_id = v_row.holding_id
        and cl.item_status = 'ativa'
    ) then
      v_duplicate := array_append(v_duplicate, v_holding_id);
      continue;
    end if;

    if exists (
      select 1
      from public.emprestimo_itens_v2 ei
      join public.emprestimos_v2 e
        on e.id = ei.emprestimo_id
      where ei.holding_id = v_row.holding_id
        and ei.item_status in ('aberto', 'parcialmente_devolvido')
        and e.library_id = v_row.library_id
    ) then
      v_loan_active := array_append(v_loan_active, v_holding_id);
      continue;
    end if;

    if exists (
      select 1
      from public.reserva_linhas_v2 rl
      join public.reservas_v2 r
        on r.id = rl.reserva_id
      where rl.holding_id = v_row.holding_id
        and rl.item_status = 'ativa'
        and r.library_id = v_row.library_id
    ) then
      v_reservation_active := array_append(v_reservation_active, v_holding_id);
      continue;
    end if;

    select *
      into v_policy
    from api.resolve_circulation_rule(
      p_library_id := v_row.library_id,
      p_mode := 'local_consultation',
      p_user_id := p_user_id,
      p_book_id := v_row.book_id,
      p_holding_id := v_row.holding_id,
      p_quantity := v_requested_quantity,
      p_as_of_date := current_date,
      p_current_due_date := null,
      p_renewals_used := 0
    )
    limit 1;

    if coalesce(v_policy.consultation_allowed, false) is false then
      v_policy_blocked := array_append(v_policy_blocked, v_holding_id);
      if v_policy_blocked_message is null then
        v_policy_blocked_message := coalesce(
          nullif(v_policy.explanation, ''),
          'A política ativa de circulação não permite criar este pedido de consulta local no momento.'
        );
      end if;
      continue;
    end if;
  end loop;

  if cardinality(v_missing) > 0 then
    raise exception 'Holding(s) não encontrado(s): %', array_to_string(v_missing, ', ');
  end if;

  if cardinality(v_cross_library) > 0 then
    raise exception 'Os holdings informados pertencem a bibliotecas diferentes. Faça um pedido por biblioteca. Holdings conflitantes: %',
      array_to_string(v_cross_library, ', ');
  end if;

  if cardinality(v_unavailable) > 0 then
    raise exception 'Holding(s) sem disponibilidade local para consulta: %', array_to_string(v_unavailable, ', ');
  end if;

  if cardinality(v_duplicate) > 0 then
    raise exception 'Já existe pedido ativo de consulta para o(s) holding(s): %', array_to_string(v_duplicate, ', ');
  end if;

  if cardinality(v_loan_active) > 0 then
    raise exception 'Holding(s) com empréstimo em curso, indisponível(is) para consulta local: %',
      public.fn_format_holding_refs(v_loan_active);
  end if;

  if cardinality(v_reservation_active) > 0 then
    raise exception 'Holding(s) com reserva ativa, indisponível(is) para consulta local: %',
      public.fn_format_holding_refs(v_reservation_active);
  end if;

  if cardinality(v_policy_blocked) > 0 then
    raise exception '% Holdings bloqueados: %',
      coalesce(v_policy_blocked_message, 'A política ativa de circulação não permite criar este pedido de consulta local no momento.'),
      array_to_string(v_policy_blocked, ', ');
  end if;

  if v_batch_library_id is null then
    raise exception 'Nenhum pedido de consulta pôde ser criado.';
  end if;

  -- ============================================================
  -- PAQUET C.4a.4 — check circulation_mode <> off
  -- ============================================================
  if not public.fn_library_has_circulation(v_batch_library_id) then
    raise exception 'A circulação está desativada para esta biblioteca. Não é possível criar pedidos de consulta.'
      using errcode = 'P0001',
            hint = 'error.library.circulation_disabled';
  end if;

  select
    coalesce(s.service_mode, 'funcionamento_normal'),
    coalesce(s.allows_new_reservations, true)
  into
    v_service_mode,
    v_allows_new_reservations
  from public.library_service_state s
  where s.library_id = v_batch_library_id;

  if v_service_mode = 'pausada' or coalesce(v_allows_new_reservations, true) = false then
    raise exception 'Os pedidos públicos de consulta local estão temporariamente fechados para esta biblioteca.';
  end if;

  insert into public.consultas_locais_v2 (
    user_id,
    library_id,
    notes,
    status_global
  )
  values (
    p_user_id,
    v_batch_library_id,
    coalesce(nullif(trim(p_notes), ''), 'Pedido de consulta local criado pela conta do(a/e) leitor(a/e).'),
    'ativa'
  )
  returning id into v_consulta_id;

  foreach v_holding_id in array v_holding_ids
  loop
    select
      h.id as holding_id,
      h.book_id,
      h.library_id,
      coalesce(nullif(trim(h.local_bib_ref), ''), b.bib_ref) as local_bib_ref,
      b.bib_ref as book_bib_ref,
      b.titulo,
      b.autor,
      b.editora,
      b.ano
    into v_row
    from public.book_holdings h
    join public.books b
      on b.id = h.book_id
    where h.id = v_holding_id;

    v_line_no := v_line_no + 1;

    insert into public.consulta_linhas_v2 (
      consulta_id,
      line_no,
      book_id,
      holding_id,
      bib_ref,
      titulo_cache,
      autor_cache,
      editora_cache,
      ano_cache,
      item_status,
      expires_at,
      notes
    )
    values (
      v_consulta_id,
      v_line_no,
      v_row.book_id,
      v_row.holding_id,
      v_row.local_bib_ref,
      v_row.titulo,
      v_row.autor,
      v_row.editora,
      v_row.ano,
      'ativa',
      p_expires_at,
      coalesce(nullif(trim(p_notes), ''), 'Pedido de consulta local recebido.')
    );

    insert into public.consulta_item_workflow_v2 (
      consulta_id,
      line_no,
      workflow_stage,
      workflow_note,
      updated_by
    )
    values (
      v_consulta_id,
      v_line_no,
      'solicitada',
      coalesce(nullif(trim(p_notes), ''), 'Pedido de consulta local recebido.'),
      v_uid
    );
  end loop;

  perform public.fn_v2_refresh_consulta_status_global(v_consulta_id);

  return v_consulta_id;
end;
$function$;

-- ---------------------------------------------------------------------------
-- DO block de verification fail-fast
-- ---------------------------------------------------------------------------
DO $verif$
DECLARE
  v_count int;
BEGIN
  -- Les 3 fonctions doivent contenir fn_library_has_circulation
  SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN (
       'fn_v2_create_emprestimo_by_holdings',
       'fn_v2_create_reserva_by_holdings',
       'fn_v2_create_consulta_local_by_holdings'
     )
     AND pg_get_functiondef(p.oid) LIKE '%fn_library_has_circulation%';
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'VERIF_FAIL : %/3 RPC contiennent fn_library_has_circulation', v_count;
  END IF;

  RAISE NOTICE 'Paquet C.4a.2/3/4 — Verification OK : 3 RPC patchees avec check fn_library_has_circulation';
END
$verif$;

COMMIT;
