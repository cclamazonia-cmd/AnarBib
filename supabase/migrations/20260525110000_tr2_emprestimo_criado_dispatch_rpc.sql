-- =============================================================================
-- Migration TR-2 — chantier #153.A (corrections post-audit #153)
-- =============================================================================
-- Objet : résorber le doublon de mail subi par le ou la lectrice lors d'une
--         conversion réservation -> emprunt.
--
-- Contexte : aujourd'hui le trigger AFTER INSERT trg_notify_emprestimo_criado
-- émet 'emprestimo_v2_criado' pour TOUT emprunt créé, sans pouvoir distinguer un
-- emprunt né d'une conversion d'un emprunt créé directement (la provenance n'est
-- portée que par emprestimo_itens_v2, inséré APRÈS le déclenchement du trigger).
-- Conséquence : une conversion produit un mail 'res.converted' (workflow de
-- réservation) PUIS un mail de création d'emprunt — deux mails pour un seul
-- événement vécu.
--
-- Décision D-1 (dossier-cadre post-audit #153, 24/05/2026) et option β
-- (validée 25/05) : on retire le trigger et on fait émettre le dispatch par
-- chacune des deux RPC de création d'emprunt, qui — elles — connaissent leur
-- propre contexte. La RPC de conversion passe le drapeau suppress_user_mail afin
-- que le handler EF saute le mail lecteur·rice tout en conservant le mail admin.
--
-- Périmètre de cette migration (SQL uniquement) :
--   1. Retrait du trigger trg_notify_emprestimo_criado et de sa fonction.
--   2. fn_v2_create_emprestimo_by_holdings (création directe) : émet le dispatch
--      avec p_extra vide -> comportement identique à l'ancien trigger.
--   3. fn_v2_convert_reserva_linhas_to_emprestimo (conversion) : émet le dispatch
--      avec {"suppress_user_mail": true}.
--   4. COMMENT ON FUNCTION sur les deux RPC (garde-fou doctrine option β).
--   5. Bloc DO de vérification en fin de transaction.
--
-- Le volet Edge Function (dispatch.ts transmet le payload ; handleEmprestimoV2
-- lit suppress_user_mail) est livré séparément, hors migration.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Retrait du trigger de notification au niveau header
-- -----------------------------------------------------------------------------
-- L'émission de 'emprestimo_v2_criado' est désormais portée par les RPC de
-- création (points 2 et 3). Le trigger devient redondant et, surtout, nuisible :
-- il ne peut pas porter le drapeau suppress_user_mail.

DROP TRIGGER IF EXISTS trg_notify_emprestimo_criado ON public.emprestimos_v2;
DROP FUNCTION IF EXISTS public.trg_notify_emprestimo_criado();

-- -----------------------------------------------------------------------------
-- 2. fn_v2_create_emprestimo_by_holdings — création directe au comptoir
-- -----------------------------------------------------------------------------
-- Reproduction intégrale de la fonction (dump du 25/05/2026), à l'identique,
-- avec un seul ajout : l'appel à fn_dispatch_circulation_notify_event juste
-- avant le RETURN QUERY. p_extra est vide -> mail lecteur·rice + mail admin,
-- exactement comme le faisait l'ancien trigger pour ce chemin.

CREATE OR REPLACE FUNCTION public.fn_v2_create_emprestimo_by_holdings(
  p_user_id uuid,
  p_holding_ids bigint[],
  p_due_at date DEFAULT NULL::date,
  p_notes text DEFAULT NULL::text
) RETURNS TABLE(ok boolean, emprestimo_id bigint, due_at date, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'api'
    AS $$
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

  -- TR-2 (#153.A) : émission de la notification de création d'emprunt.
  -- Remplace l'ancien trigger trg_notify_emprestimo_criado. p_extra vide :
  -- création directe -> mail lecteur·rice + mail admin (comportement inchangé).
  perform public.fn_dispatch_circulation_notify_event(
    'emprestimo_v2_criado',
    v_emprestimo_id,
    '{}'::jsonb
  );

  return query
  select true,
         v_emprestimo_id,
         v_due_at,
         coalesce(
           nullif(v_rule.explanation, ''),
           format('Empréstimo criado com %s item(ns).', v_line_no)
         );
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. fn_v2_convert_reserva_linhas_to_emprestimo — conversion réservation
-- -----------------------------------------------------------------------------
-- Reproduction intégrale de la fonction (dump du 25/05/2026), à l'identique,
-- avec un seul ajout : l'appel à fn_dispatch_circulation_notify_event juste
-- avant le RETURN. p_extra porte {"suppress_user_mail": true} : le handler EF
-- handleEmprestimoV2 sautera le mail lecteur·rice (le mail 'res.converted' du
-- workflow de réservation fait foi) tout en conservant le mail admin.

CREATE OR REPLACE FUNCTION public.fn_v2_convert_reserva_linhas_to_emprestimo(
  p_reserva_id bigint,
  p_line_nos integer[],
  p_due_at date DEFAULT NULL::date,
  p_notes text DEFAULT NULL::text
) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'api'
    AS $$
declare
  v_actor public.my_access%rowtype;
  v_reserva public.reservas_v2%rowtype;
  v_due_at date;
  v_item_count integer;
  v_emprestimo_id bigint;
  v_line_no integer := 0;
  v_line record;
  v_item record;
  v_new_item_id bigint;

  v_first_holding_id bigint := null;
  v_first_book_id bigint := null;
  v_rule record;
  v_legacy_loan_days integer := null;
  v_bridge record;

  v_dues_blocked boolean;
  v_dues_status text;
  v_dues_message text;
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select * into v_actor from public.my_access limit 1;

  if coalesce(v_actor.can_access_painel, false) is false then
    raise exception 'Acesso bibliotecário obrigatório.';
  end if;

  select * into v_reserva
  from public.reservas_v2
  where id = p_reserva_id;

  if not found then
    raise exception 'Reserva não encontrada: %', p_reserva_id;
  end if;

  if v_actor.library_id is distinct from v_reserva.library_id then
    raise exception 'Esta reserva pertence a outra biblioteca.';
  end if;

  -- VÉRIFICATION COTISATION
  v_dues_blocked := public.fn_is_loan_blocked_by_dues(v_reserva.user_id, v_reserva.library_id);

  if v_dues_blocked then
    select dues_status into v_dues_status
    from public.v_active_memberships
    where user_id = v_reserva.user_id and library_id = v_reserva.library_id;

    v_dues_message := case v_dues_status
      when 'never_paid' then
        'Contribuição obrigatória não registrada para este(a) leitor(a). Registre o pagamento antes de converter a reserva.'
      when 'expired' then
        'Contribuição vencida. Renove antes de converter a reserva em empréstimo.'
      else
        'Contribuição obrigatória não está em dia para este(a) leitor(a).'
    end;

    raise exception '%', v_dues_message
      using errcode = 'P0001',
            hint = 'Acesse a aba Contribuições no painel para registrar o pagamento.';
  end if;

  select count(*)
    into v_item_count
  from public.reserva_linhas_v2 rl
  where rl.reserva_id = p_reserva_id
    and rl.line_no = any(p_line_nos)
    and rl.item_status = 'ativa';

  if v_item_count = 0 then
    raise exception 'Nenhuma linha ativa selecionada para conversão.';
  end if;

  select
    rl.holding_id,
    rl.book_id
    into v_first_holding_id, v_first_book_id
  from public.reserva_linhas_v2 rl
  where rl.reserva_id = p_reserva_id
    and rl.line_no = any(p_line_nos)
    and rl.item_status = 'ativa'
  order by rl.line_no
  limit 1;

  v_legacy_loan_days := case
    when v_item_count = 1 then 21
    when v_item_count between 2 and 3 then 30
    else 38
  end;

  select *
    into v_rule
  from api.resolve_circulation_rule(
    p_library_id := v_reserva.library_id,
    p_mode := 'loan',
    p_user_id := v_reserva.user_id,
    p_book_id := v_first_book_id,
    p_holding_id := v_first_holding_id,
    p_quantity := v_item_count,
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
    v_reserva.user_id,
    v_reserva.library_id,
    p_notes,
    'aberto',
    v_due_at,
    now(),
    now()
  )
  returning id into v_emprestimo_id;

  for v_line in
    select rl.*
    from public.reserva_linhas_v2 rl
    where rl.reserva_id = p_reserva_id
      and rl.line_no = any(p_line_nos)
      and rl.item_status = 'ativa'
    order by rl.line_no
  loop
    if v_line.item_id is not null then
      select e.id, e.tombo, e.holding_id
      into v_item
      from public.exemplares e
      where e.id = v_line.item_id
        and e.library_id = v_reserva.library_id
        and not exists (
          select 1 from public.emprestimo_itens_v2 i
          where i.item_id = e.id and i.item_status = 'aberto'
        )
      limit 1;

    elsif v_line.holding_id is not null then
      select e.id, e.tombo, e.holding_id
      into v_item
      from public.exemplares e
      where e.holding_id = v_line.holding_id
        and e.library_id = v_reserva.library_id
        and not exists (
          select 1 from public.emprestimo_itens_v2 i
          where i.item_id = e.id and i.item_status = 'aberto'
        )
      order by e.id
      limit 1;

    else
      select * into v_bridge
      from public.resolve_library_holding_bridge(v_reserva.library_id, v_line.bib_ref)
      limit 1;

      if found and v_bridge.holding_id is not null then
        select e.id, e.tombo, e.holding_id
        into v_item
        from public.exemplares e
        where e.holding_id = v_bridge.holding_id
          and e.library_id = v_reserva.library_id
          and not exists (
            select 1 from public.emprestimo_itens_v2 i
            where i.item_id = e.id and i.item_status = 'aberto'
          )
        order by e.id
        limit 1;
      else
        select e.id, e.tombo, e.holding_id
        into v_item
        from public.exemplares e
        where e.bib_ref = v_line.bib_ref
          and e.library_id = v_reserva.library_id
          and not exists (
            select 1 from public.emprestimo_itens_v2 i
            where i.item_id = e.id and i.item_status = 'aberto'
          )
        order by e.id
        limit 1;
      end if;
    end if;

    if not found then
      raise exception 'Nenhum exemplar disponível para conversão da reserva: %', v_line.bib_ref;
    end if;

    v_line_no := v_line_no + 1;

    insert into public.emprestimo_itens_v2 (
      emprestimo_id, line_no, sub_id,
      book_id, holding_id, item_id,
      reserva_id, reserva_line_no,
      bib_ref, rotulo_cache,
      titulo_cache, autor_cache, editora_cache, ano_cache,
      item_status, due_at, created_at, updated_at
    )
    values (
      v_emprestimo_id, v_line_no, format('%s.%s', v_emprestimo_id, v_line_no),
      v_line.book_id, coalesce(v_line.holding_id, v_item.holding_id), v_item.id,
      p_reserva_id, v_line.line_no,
      v_line.bib_ref, coalesce(v_line.rotulo_cache, v_item.tombo),
      v_line.titulo_cache, v_line.autor_cache, v_line.editora_cache, v_line.ano_cache,
      'aberto', v_due_at, now(), now()
    )
    returning id into v_new_item_id;

    update public.reserva_linhas_v2
       set item_status = 'convertida_em_emprestimo',
           item_id = coalesce(item_id, v_item.id),
           emprestimo_item_id = v_new_item_id,
           converted_at = now(),
           updated_at = now()
     where reserva_id = p_reserva_id
       and line_no = v_line.line_no;

    insert into public.reserva_item_workflow_v2 (
      reserva_id, line_no, workflow_stage, workflow_note, updated_at, updated_by
    )
    values (
      p_reserva_id, v_line.line_no, 'retirada_efetivada',
      coalesce(p_notes, 'Retirada presencial confirmada no painel.'),
      now(), auth.uid()
    )
    on conflict (reserva_id, line_no) do update
      set workflow_stage = excluded.workflow_stage,
          workflow_note = excluded.workflow_note,
          updated_at = excluded.updated_at,
          updated_by = excluded.updated_by;
  end loop;

  update public.books b
     set available_count = greatest(coalesce(b.available_count, 0) - x.qty, 0)
    from (
      select book_id, count(*)::int as qty
      from public.emprestimo_itens_v2
      where emprestimo_id = v_emprestimo_id
      group by book_id
    ) x
   where b.id = x.book_id;

  perform public.fn_v2_refresh_reserva_status_global(p_reserva_id);
  perform public.fn_v2_recompute_from_emprestimo_lines(v_emprestimo_id, null);

  -- TR-2 (#153.A) : émission de la notification de création d'emprunt.
  -- Remplace l'ancien trigger trg_notify_emprestimo_criado. Le drapeau
  -- suppress_user_mail demande au handler EF de NE PAS envoyer le mail
  -- lecteur·rice : sur une conversion, c'est le mail 'res.converted' du
  -- workflow de réservation qui fait foi. Le mail admin, lui, reste émis.
  perform public.fn_dispatch_circulation_notify_event(
    'emprestimo_v2_criado',
    v_emprestimo_id,
    '{"suppress_user_mail": true}'::jsonb
  );

  return v_emprestimo_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Garde-fous documentaires (doctrine option β)
-- -----------------------------------------------------------------------------
-- Le trigger automatique ayant été retiré, l'émission de 'emprestimo_v2_criado'
-- repose désormais sur la discipline d'appel. Toute future voie de création
-- d'un emprunt v2 doit émettre elle-même cet event, sans quoi aucune
-- notification ne partira. Ces commentaires en gardent la trace.

COMMENT ON FUNCTION public.fn_v2_create_emprestimo_by_holdings(uuid, bigint[], date, text)
  IS 'Création directe d''un emprunt v2 au comptoir. TR-2 (#153.A, 25/05/2026) : '
     'émet elle-même fn_dispatch_circulation_notify_event(''emprestimo_v2_criado'') '
     'depuis le 25/05 — le trigger trg_notify_emprestimo_criado a été retiré. '
     'Toute nouvelle voie de création d''emprunt doit émettre cet event elle-même.';

COMMENT ON FUNCTION public.fn_v2_convert_reserva_linhas_to_emprestimo(bigint, integer[], date, text)
  IS 'Conversion réservation -> emprunt. Passe 42 backend phase 1 : résout '
     'd''abord le holding local avant le fallback legacy par bib_ref. '
     'TR-2 (#153.A, 25/05/2026) : émet elle-même '
     'fn_dispatch_circulation_notify_event(''emprestimo_v2_criado'', ..., '
     '{"suppress_user_mail": true}) — le mail lecteur·rice est porté par '
     '''res.converted'' (workflow de réservation), pas par la création d''emprunt.';

-- -----------------------------------------------------------------------------
-- 5. Vérification en fin de transaction
-- -----------------------------------------------------------------------------
-- RAISE EXCEPTION ici => rollback automatique de toute la migration.

DO $verify$
BEGIN
  -- 5.1 Le trigger doit avoir disparu.
  IF EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_notify_emprestimo_criado'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'TR-2 : le trigger trg_notify_emprestimo_criado est encore présent.';
  END IF;

  -- 5.2 Sa fonction doit avoir disparu.
  IF EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'trg_notify_emprestimo_criado'
      AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'TR-2 : la fonction trg_notify_emprestimo_criado() est encore présente.';
  END IF;

  -- 5.3 Les deux RPC de création doivent toujours exister.
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'fn_v2_create_emprestimo_by_holdings'
      AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'TR-2 : fn_v2_create_emprestimo_by_holdings introuvable après migration.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'fn_v2_convert_reserva_linhas_to_emprestimo'
      AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'TR-2 : fn_v2_convert_reserva_linhas_to_emprestimo introuvable après migration.';
  END IF;

  -- 5.4 La fonction de dispatch appelée par les deux RPC doit exister.
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'fn_dispatch_circulation_notify_event'
      AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'TR-2 : fn_dispatch_circulation_notify_event introuvable — les RPC ne pourraient pas notifier.';
  END IF;

  RAISE NOTICE 'TR-2 : migration vérifiée — trigger retiré, 2 RPC en place, dispatch disponible.';
END;
$verify$;
