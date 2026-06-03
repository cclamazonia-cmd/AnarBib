-- ════════════════════════════════════════════════════════════════════════
-- UX consulta : distinguer « aucun exemplaire consultable » de « tous engagés »
-- ════════════════════════════════════════════════════════════════════════
-- fn_v2_create_consulta_local_by_holdings : quand fn_v2_resolve_consulta_exemplar
-- renvoie NULL (aucun exemplaire à la fois consultable §6.2 ET libre), on levait
-- un message unique « todos os exemplares estão engajados em outro circuito » —
-- trompeur quand la vraie raison est « aucune copie consultable par nature »
-- (holding tout-emprestavel ou tout staff_only ; available_count optimiste car
-- filtré sur visibility seulement, pas circulation_policy → le NULL est atteignable
-- même après la validation holding-niveau de la 1ʳᵉ boucle).
--
-- Le résolveur applique déjà §6.2 (visibility public + circulation consulta|ambos,
-- vérifié 03/06). On ajoute UNIQUEMENT la distinction de message via un test
-- secondaire + 2 hints localisés (localizeError lit err.hint, Cas 1) :
--   • aucune copie consultable par nature → error.consulta.no_consultable_copy
--   • copies consultables mais toutes engagées → error.consulta.all_engaged
--
-- Signature inchangée → CREATE OR REPLACE sûr (grants/REVOKE préservés).
-- Greffé sur pg_get_functiondef du 03/06 ; seul le bloc RAISE de la 2ᵉ boucle change.
-- ════════════════════════════════════════════════════════════════════════

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

  -- #MODEL-item-grain : exemplaire resolu pour la ligne courante.
  v_item_id bigint;
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

    -- #MODEL-item-grain : resolution de l'exemplaire precis.
    -- L'exemplaire fait foi. available_count (compteur denormalise) a deja
    -- ete teste plus haut, mais c'est la disponibilite reelle exemplaire
    -- par exemplaire qui decide ici. Si aucun exemplaire n'est libre, on
    -- refuse — available_count etait optimiste.
    v_item_id := public.fn_v2_resolve_consulta_exemplar(v_holding_id);
    if v_item_id is null then
      -- #UX-consulta : distinguer « aucune copie consultable par nature »
      -- (holding tout-emprestavel ou tout staff_only) de « toutes engagées ».
      -- Le résolveur applique déjà §6.2 ; available_count est optimiste
      -- (filtré sur visibility seulement) → le cas « aucune consultable » est réel.
      if not exists (
        select 1
        from public.exemplares e
        where e.holding_id = v_holding_id
          and e.visibility = 'public'
          and e.circulation_policy in ('consulta', 'ambos')
      ) then
        raise exception
          'Nenhum exemplar consultável neste acervo para o holding %.',
          v_holding_id
          using errcode = 'P0001',
                hint = 'error.consulta.no_consultable_copy';
      else
        raise exception
          'Nenhum exemplar disponível para o holding % (todas as cópias consultáveis estão engajadas em outro circuito).',
          v_holding_id
          using errcode = 'P0001',
                hint = 'error.consulta.all_engaged';
      end if;
    end if;

    v_line_no := v_line_no + 1;

    insert into public.consulta_linhas_v2 (
      consulta_id,
      line_no,
      book_id,
      holding_id,
      item_id,
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
      v_item_id,
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
