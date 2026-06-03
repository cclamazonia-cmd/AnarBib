-- Migration P1.4b-etape-2 -- matrice d'actions §6.2 dans les resolveurs locaux
-- spec-exemplaires-circulation §6.2 + §8 + REGISTRE DOC-CIRC-1.
--
-- Applique l'autorise/visible par exemplaire (la disponibilite reste resolue par item-grain) :
--   - Consultation : exemplaire consultable  = visibility='public' ET circulation_policy IN (consulta, ambos)
--   - Pret local   : exemplaire empruntable  = visibility='public' ET circulation_policy IN (emprestavel, ambos)
--
-- Deux fonctions, greffees sur la def autoritaire (pg_get_functiondef) ; seules les lignes
-- -- P1.4b different de la prod.
--
-- (1) fn_v2_resolve_consulta_exemplar : point unique de selection cote consultation
--     (le createur fn_v2_create_consulta_local_by_holdings y delegue). 2 lignes ajoutees.
-- (2) fn_v2_create_emprestimo_by_holdings : la selection d'exemplaire libre apparait 2x
--     (boucle validation + boucle creation, predicats identiques). Garde ajoutee aux 2.
--     Le check legacy `loanable` (booleen fiche) est conserve comme pre-filtre grossier.
--
-- HORS PERIMETRE : le PEB (fn_v2_create_emprestimo_interbibliotecas) ne selectionne aucun
-- exemplaire (cree l'enveloppe inter-bibs) ; la garde PEB se jouera dans le chemin de
-- recherche/rattachement d'exemplaires (fn_peb_search_exemplares), chantier separe.
--
-- Deploiement : CREATE OR REPLACE SECURITY DEFINER (ACL preservees) -> commit --no-verify.

-- =====================================================================
-- (1) Consultation : exemplaire consultable seulement
-- =====================================================================
CREATE OR REPLACE FUNCTION public.fn_v2_resolve_consulta_exemplar(p_holding_id bigint)
 RETURNS bigint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Renvoie l'id d'un exemplaire du holding non engage dans aucun circuit,
  -- ou NULL si aucun n'est libre. Quatre circuits croises, comme
  -- fn_peb_search_exemplares (#ILL-availability).
  SELECT e.id
  FROM public.exemplares e
  WHERE e.holding_id = p_holding_id
    -- (0) consultable per §6.2 (DOC-CIRC-1) : visible au public + autorise a la consultation
    AND e.visibility = 'public'                          -- P1.4b §6.2
    AND e.circulation_policy IN ('consulta', 'ambos')    -- P1.4b §6.2
    -- (1) pas d'emprunt ordinaire en cours
    AND NOT EXISTS (
      SELECT 1 FROM public.emprestimo_itens_v2 ei
      WHERE ei.item_id = e.id AND ei.item_status = 'aberto'
    )
    -- (2) pas de reservation active
    AND NOT EXISTS (
      SELECT 1 FROM public.reserva_linhas_v2 rl
      WHERE rl.item_id = e.id AND rl.item_status = 'ativa'
    )
    -- (3) pas engage dans un PEB
    AND NOT EXISTS (
      SELECT 1 FROM public.interlibrary_loan_items_v2 ili
      WHERE ili.item_id = e.id
        AND ili.item_status IN ('reservado_para_saida', 'emprestado')
    )
    -- (4) pas deja en consultation active (desormais a l'item_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.consulta_linhas_v2 cl
      WHERE cl.item_id = e.id AND cl.item_status = 'ativa'
    )
  ORDER BY e.id
  LIMIT 1;
$function$;

-- =====================================================================
-- (2) Pret local : exemplaire empruntable seulement (garde x2)
-- =====================================================================
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
      and e.visibility = 'public'                            -- P1.4b §6.2
      and e.circulation_policy in ('emprestavel', 'ambos')   -- P1.4b §6.2
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
      and e.visibility = 'public'                            -- P1.4b §6.2
      and e.circulation_policy in ('emprestavel', 'ambos')   -- P1.4b §6.2
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
$function$;

-- =====================================================================
-- Verifications non destructives
-- =====================================================================
do $$
declare
  v_def_consulta text := pg_get_functiondef('public.fn_v2_resolve_consulta_exemplar(bigint)'::regprocedure);
  v_def_pret     text := pg_get_functiondef('public.fn_v2_create_emprestimo_by_holdings(uuid,bigint[],date,text)'::regprocedure);
begin
  -- (1) resolveur consulta : garde {consulta, ambos} + visibility
  if position('circulation_policy' in v_def_consulta) = 0
     or position('''ambos''' in v_def_consulta) = 0
     or position('e.visibility' in v_def_consulta) = 0 then
    raise exception 'P1.4b: garde consultation (visibility + circulation_policy) absente de fn_v2_resolve_consulta_exemplar';
  end if;

  -- (2) pret local : garde par exemplaire presente 2x (boucle validation + boucle creation)
  if (length(v_def_pret) - length(replace(v_def_pret, 'circulation_policy in', ''))) / length('circulation_policy in') < 2 then
    raise exception 'P1.4b: garde pret (x2 : validation + creation) absente de fn_v2_create_emprestimo_by_holdings';
  end if;
  if position('e.visibility' in v_def_pret) = 0 then
    raise exception 'P1.4b: garde visibility absente de fn_v2_create_emprestimo_by_holdings';
  end if;
end
$$;
