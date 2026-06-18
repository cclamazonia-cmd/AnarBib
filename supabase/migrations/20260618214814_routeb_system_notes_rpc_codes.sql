-- =========================================================================
-- Route B — Notes système consulta/réserve traduites à l'affichage
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : i18n notes système (Route B) — sentinelles @@note:<clé>
-- Auteur   : AnarBib · Session : Notes système i18n (Route B)
--
-- Les RPC de création/annulation stockaient le LIBELLÉ pt-BR figé dans la note
-- (notes / workflow_note). On stocke désormais une SENTINELLE « @@note:<clé i18n> »
-- décodée à l'affichage dans la locale courante (front : src/lib/systemNotes.js ;
-- mail : supabase/functions/_shared/i18n/systemNotes.ts).
--
-- Ces fonctions sont des CREATE OR REPLACE de SECURITY DEFINER déjà existantes :
-- les GRANT/REVOKE sont préservés. Définitions reprises VERBATIM de la prod
-- (uflwmikiyjfnikiphtcp, pg_get_functiondef au 2026-06-18) ; SEULS les littéraux
-- par défaut changent (coalesce(nullif(trim(p_notes/p_workflow_note),''), …)).
--
-- Mapping littéral pt-BR → code :
--   'Pedido de consulta local criado pela conta do(a/e) leitor(a/e).' → @@note:account.reserve.noteConsult
--   'Pedido de consulta local recebido.'                              → @@note:systemNote.consultaReceived
--   'Reserva criada pela conta do(a/e) leitor(a/e).'                  → @@note:account.reserve.noteLoan
--   'Reserva recebida.'                                               → @@note:systemNote.reservaReceived
--   'Cancelamento solicitado pela conta do(a/e) leitor(a/e).'         → @@note:systemNote.cancelRequestedByReader
--   'Cancelamento efetuado pela biblioteca.'                          → @@note:systemNote.cancelledByLibrary
--
-- NB : fn_v2_set_consulta_linhas_workflow n'est PAS touchée (def live n'a plus de
-- littéral par défaut — workflow_note = nullif(trim(p_workflow_note),'')).
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) fn_v2_create_consulta_local_by_holdings
--    consultas_locais_v2.notes            → @@note:account.reserve.noteConsult
--    consulta_linhas_v2.notes             → @@note:systemNote.consultaReceived
--    consulta_item_workflow_v2.workflow_note → @@note:systemNote.consultaReceived
-- -------------------------------------------------------------------------
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
    coalesce(nullif(trim(p_notes), ''), '@@note:account.reserve.noteConsult'),
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
      coalesce(nullif(trim(p_notes), ''), '@@note:systemNote.consultaReceived')
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
      coalesce(nullif(trim(p_notes), ''), '@@note:systemNote.consultaReceived'),
      v_uid
    );
  end loop;

  perform public.fn_v2_refresh_consulta_status_global(v_consulta_id);

  return v_consulta_id;
end;
$function$;

-- -------------------------------------------------------------------------
-- 2) fn_v2_create_reserva_by_holdings
--    reservas_v2.notes                       → @@note:account.reserve.noteLoan
--    reserva_linhas_v2.notes                 → @@note:account.reserve.noteLoan
--    reserva_item_workflow_v2.workflow_note  → @@note:systemNote.reservaReceived
-- -------------------------------------------------------------------------
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
    coalesce(nullif(trim(p_notes), ''), '@@note:account.reserve.noteLoan'),
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
      coalesce(nullif(trim(p_notes), ''), '@@note:account.reserve.noteLoan')
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
      coalesce(nullif(trim(p_notes), ''), '@@note:systemNote.reservaReceived'),
      v_uid
    );
  end loop;

  perform public.fn_v2_refresh_reserva_status_global(v_reserva_id);
  perform public.fn_v2_recompute_from_reserva_lines(v_reserva_id, null);

  return v_reserva_id;
end;
$function$;

-- -------------------------------------------------------------------------
-- 3) fn_v2_cancel_consulta_linhas_as_leitor
--    consulta_item_workflow_v2.workflow_note → @@note:systemNote.cancelRequestedByReader
--    (consulta_linhas_v2.notes = concat du p_notes libre : INCHANGÉ)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_v2_cancel_consulta_linhas_as_leitor(p_consulta_id bigint, p_line_nos integer[], p_notes text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_updated int := 0;
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  if not exists (
    select 1
    from public.consultas_locais_v2 c
    where c.id = p_consulta_id
      and c.user_id = v_uid
  ) then
    raise exception 'Você não pode alterar este pedido de consulta local.';
  end if;

  update public.consulta_linhas_v2 cl
     set item_status = 'cancelada_leitor',
         cancelled_at = coalesce(cl.cancelled_at, timezone('utc', now())),
         notes = case
           when p_notes is null or btrim(p_notes) = '' then cl.notes
           when cl.notes is null or btrim(cl.notes) = '' then p_notes
           else cl.notes || E'\r\n' || p_notes
         end,
         updated_at = timezone('utc', now())
   where cl.consulta_id = p_consulta_id
     and cl.line_no = any(p_line_nos)
     and cl.item_status = 'ativa';

  get diagnostics v_updated = row_count;

  insert into public.consulta_item_workflow_v2 (
    consulta_id,
    line_no,
    workflow_stage,
    workflow_note,
    updated_at,
    updated_by
  )
  select
    cl.consulta_id,
    cl.line_no,
    'cancelada_leitor',
    coalesce(nullif(trim(p_notes), ''), '@@note:systemNote.cancelRequestedByReader'),
    timezone('utc', now()),
    v_uid
  from public.consulta_linhas_v2 cl
  where cl.consulta_id = p_consulta_id
    and cl.line_no = any(p_line_nos)
  on conflict (consulta_id, line_no)
  do update
     set workflow_stage = excluded.workflow_stage,
         workflow_note = excluded.workflow_note,
         updated_at = excluded.updated_at,
         updated_by = excluded.updated_by;

  perform public.fn_v2_refresh_consulta_status_global(p_consulta_id);

  return v_updated;
end;
$function$;

-- -------------------------------------------------------------------------
-- 4) fn_v2_cancel_reserva_linhas_as_biblioteca
--    reserva_item_workflow_v2.workflow_note → @@note:systemNote.cancelledByLibrary
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_v2_cancel_reserva_linhas_as_biblioteca(p_reserva_id bigint, p_line_nos integer[], p_notes text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'api'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_updated int := 0;
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select r.library_id
    into v_library_id
  from public.reservas_v2 r
  where r.id = p_reserva_id;

  if v_library_id is null then
    raise exception 'Reserva não encontrada.';
  end if;

  if not exists (
    select 1
    from api.my_access a
    where a.user_id = v_uid
      and a.can_access_painel = true
      and a.library_id = v_library_id
  ) then
    raise exception 'Você não pode gerir esta reserva.';
  end if;

  update public.reserva_linhas_v2 rl
     set item_status = 'cancelada_biblioteca',
         cancelled_at = coalesce(rl.cancelled_at, timezone('utc', now())),
         notes = case
           when p_notes is null or btrim(p_notes) = '' then rl.notes
           when rl.notes is null or btrim(rl.notes) = '' then p_notes
           else rl.notes || E'\n' || p_notes
         end,
         updated_at = timezone('utc', now())
   where rl.reserva_id = p_reserva_id
     and rl.line_no = any(p_line_nos)
     and rl.item_status = 'ativa';

  get diagnostics v_updated = row_count;

  insert into public.reserva_item_workflow_v2 (
    reserva_id,
    line_no,
    workflow_stage,
    workflow_note,
    updated_at,
    updated_by
  )
  select
    rl.reserva_id,
    rl.line_no,
    'cancelada_biblioteca',
    coalesce(nullif(trim(p_notes), ''), '@@note:systemNote.cancelledByLibrary'),
    timezone('utc', now()),
    v_uid
  from public.reserva_linhas_v2 rl
  where rl.reserva_id = p_reserva_id
    and rl.line_no = any(p_line_nos)
  on conflict (reserva_id, line_no)
  do update
     set workflow_stage = excluded.workflow_stage,
         workflow_note = excluded.workflow_note,
         updated_at = excluded.updated_at,
         updated_by = excluded.updated_by;

  perform public.fn_v2_refresh_reserva_status_global(p_reserva_id);
  perform public.fn_v2_recompute_from_reserva_lines(p_reserva_id, p_line_nos);

  return v_updated;
end;
$function$;

-- -------------------------------------------------------------------------
-- 5) fn_v2_cancel_reserva_linhas_as_leitor
--    reserva_item_workflow_v2.workflow_note → @@note:systemNote.cancelRequestedByReader
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_v2_cancel_reserva_linhas_as_leitor(p_reserva_id bigint, p_line_nos integer[], p_notes text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_updated int := 0;
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  if not exists (
    select 1
    from public.reservas_v2 r
    where r.id = p_reserva_id
      and r.user_id = v_uid
  ) then
    raise exception 'Você não pode alterar esta reserva.';
  end if;

  update public.reserva_linhas_v2 rl
     set item_status = 'cancelada_leitor',
         cancelled_at = coalesce(rl.cancelled_at, timezone('utc', now())),
         notes = case
           when p_notes is null or btrim(p_notes) = '' then rl.notes
           when rl.notes is null or btrim(rl.notes) = '' then p_notes
           else rl.notes || E'\n' || p_notes
         end,
         updated_at = timezone('utc', now())
   where rl.reserva_id = p_reserva_id
     and rl.line_no = any(p_line_nos)
     and rl.item_status = 'ativa';

  get diagnostics v_updated = row_count;

  insert into public.reserva_item_workflow_v2 (
    reserva_id,
    line_no,
    workflow_stage,
    workflow_note,
    updated_at,
    updated_by
  )
  select
    rl.reserva_id,
    rl.line_no,
    'cancelada_leitor',
    coalesce(nullif(trim(p_notes), ''), '@@note:systemNote.cancelRequestedByReader'),
    timezone('utc', now()),
    v_uid
  from public.reserva_linhas_v2 rl
  where rl.reserva_id = p_reserva_id
    and rl.line_no = any(p_line_nos)
  on conflict (reserva_id, line_no)
  do update
     set workflow_stage = excluded.workflow_stage,
         workflow_note = excluded.workflow_note,
         updated_at = excluded.updated_at,
         updated_by = excluded.updated_by;

  perform public.fn_v2_refresh_reserva_status_global(p_reserva_id);
  perform public.fn_v2_recompute_from_reserva_lines(p_reserva_id, p_line_nos);

  return v_updated;
end;
$function$;

COMMIT;
