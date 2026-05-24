-- ============================================================================
-- 20260524020000_consulta_item_id_rpc.sql
-- ----------------------------------------------------------------------------
-- Chantier #MODEL-item-grain — volet B : fonctions.
-- Specification : docs/specs/spec-granularite-item.md
-- Pre-requis : migration 20260524010000 (colonne item_id NOT NULL + FK).
--
-- TROIS CHANGEMENTS
--   1. fn_v2_resolve_consulta_exemplar(holding_id) — NOUVELLE fonction :
--      resout un exemplaire disponible d'un holding, en croisant les quatre
--      circuits (emprunt / reservation / PEB / consultation). Logique reprise
--      de fn_peb_search_exemplares, restreinte a un holding.
--   2. fn_v2_create_consulta_local_by_holdings — ADAPTEE : a la creation de
--      chaque consulta_linha, resout l'exemplaire et le pose en item_id.
--      L'exemplaire fait foi : si aucun exemplaire libre, la demande est
--      refusee meme si available_count etait > 0 (available_count est un
--      compteur denormalise, faillible ; l'exemplaire reel est la verite).
--   3. fn_peb_search_exemplares — RESSERREE : le NOT EXISTS (4) sur la
--      consultation passe de la jointure holding a la jointure item_id.
--      Leve la regle PROVISOIRE posee dans #ILL-availability.
-- ============================================================================


-- ============================================================================
-- 1. fn_v2_resolve_consulta_exemplar — resolution d'un exemplaire disponible
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_v2_resolve_consulta_exemplar(p_holding_id bigint)
 RETURNS bigint
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Renvoie l'id d'un exemplaire du holding non engage dans aucun circuit,
  -- ou NULL si aucun n'est libre. Quatre circuits croises, comme
  -- fn_peb_search_exemplares (#ILL-availability).
  SELECT e.id
  FROM public.exemplares e
  WHERE e.holding_id = p_holding_id
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

REVOKE EXECUTE ON FUNCTION public.fn_v2_resolve_consulta_exemplar(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_v2_resolve_consulta_exemplar(bigint) TO authenticated, service_role;


-- ============================================================================
-- 2. fn_v2_create_consulta_local_by_holdings — adaptee (#MODEL-item-grain)
--    Reprise integrale de la definition existante ; seul change le bloc
--    d'insertion des consulta_linhas, qui resout et pose item_id.
-- ============================================================================
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
      raise exception
        'Nenhum exemplar disponível para o holding % (todos os exemplares estão engajados em outro circuito).',
        v_holding_id
        using errcode = 'P0001';
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

-- Droits explicites. La fonction preexiste (CREATE OR REPLACE conserve les
-- GRANT) et porte deja EXECUTE pour authenticated/service_role, sans anon.
-- On les reaffirme ici : idempotent, auto-documente, conforme doctrine #150.
REVOKE EXECUTE ON FUNCTION public.fn_v2_create_consulta_local_by_holdings(uuid, bigint[], timestamp with time zone, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_v2_create_consulta_local_by_holdings(uuid, bigint[], timestamp with time zone, text) TO authenticated, service_role;


-- ============================================================================
-- 3. fn_peb_search_exemplares — resserrement du NOT EXISTS (4)
--    La jointure consultation passe du holding a l'item_id : une consultation
--    active ne bloque plus tout le fonds, mais seulement l'exemplaire vise.
--    Leve la regle PROVISOIRE de #ILL-availability.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_peb_search_exemplares(p_query text, p_lender_library_id uuid)
 RETURNS TABLE(exemplar_id bigint, holding_id bigint, book_id bigint, titulo text, autor text, bib_ref text, tombo text, library_id uuid)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT
    e.id          AS exemplar_id,
    e.holding_id  AS holding_id,
    h.book_id     AS book_id,
    b.titulo      AS titulo,
    b.autor       AS autor,
    COALESCE(NULLIF(btrim(h.local_bib_ref), ''), b.bib_ref, e.bib_ref) AS bib_ref,
    e.tombo       AS tombo,
    e.library_id  AS library_id
  FROM public.exemplares e
  JOIN public.book_holdings h ON h.id = e.holding_id
  JOIN public.books b         ON b.id = h.book_id
  WHERE e.holding_id IS NOT NULL
    -- #ILL-search-scope : uniquement les exemplaires de la prêteuse.
    AND e.library_id = p_lender_library_id
    AND (
         b.titulo ILIKE '%' || btrim(p_query) || '%'
      OR b.autor  ILIKE '%' || btrim(p_query) || '%'
      OR e.tombo  ILIKE '%' || btrim(p_query) || '%'
      OR b.bib_ref ILIKE '%' || btrim(p_query) || '%'
    )
    -- #ILL-availability : exemplaire non engage dans un autre circuit.
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
    -- (3) pas deja engage dans un autre PEB
    AND NOT EXISTS (
      SELECT 1 FROM public.interlibrary_loan_items_v2 ili
      WHERE ili.item_id = e.id
        AND ili.item_status IN ('reservado_para_saida', 'emprestado')
    )
    -- (4) pas de consultation active sur CET exemplaire.
    --     #MODEL-item-grain : jointure a l'item_id (regle resserree —
    --     auparavant jointure au holding, faute d'item_id).
    AND NOT EXISTS (
      SELECT 1 FROM public.consulta_linhas_v2 cl
      WHERE cl.item_id = e.id AND cl.item_status = 'ativa'
    )
  ORDER BY b.titulo, e.tombo
  LIMIT 20;
$function$;


-- ============================================================================
-- VERIFICATION POST-MIGRATION
-- ============================================================================
DO $verif$
declare
  v_count integer;
begin
  -- La fonction de resolution existe.
  select count(*) into v_count
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'fn_v2_resolve_consulta_exemplar';
  if v_count <> 1 then
    raise exception 'Verification echouee : fn_v2_resolve_consulta_exemplar absente.';
  end if;

  -- fn_v2_create_consulta_local_by_holdings reference bien item_id.
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'fn_v2_create_consulta_local_by_holdings'
      and pg_get_functiondef(p.oid) ilike '%item_id%'
  ) then
    raise exception 'Verification echouee : fn_v2_create_consulta_local_by_holdings ne reference pas item_id.';
  end if;

  -- fn_peb_search_exemplares : le NOT EXISTS (4) joint desormais cl.item_id.
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'fn_peb_search_exemplares'
      and pg_get_functiondef(p.oid) ilike '%cl.item_id = e.id%'
  ) then
    raise exception 'Verification echouee : fn_peb_search_exemplares non resserree (jointure consultation toujours au holding).';
  end if;

  raise notice 'Migration 20260524020000 : verification OK (resolution + create_consulta adaptee + search_exemplares resserree).';
end;
$verif$;
