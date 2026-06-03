-- Migration P1.4a -- filtre catalogue public par visibility
-- spec-exemplaires-circulation §6.2 ("Voir : visibility = public") + §8 + §4.1.
--
-- Deux volets, une transaction :
--   (1) RLS  : non-staff ne lisent que visibility='public' ; staff de la biblio voient tout.
--   (2) Compteurs : l'availability publique (book_holdings.exemplares_total/available_count,
--       seule source des vues du catalogue) ne compte que les exemplaires 'public'
--       (l'arquivo ne circule pas, §4.1). Greffe sur la def autoritaire (pg_get_functiondef) :
--       seules les lignes -- P1.4a different de la prod.
--
-- No-op sur la donnee actuelle (tous 'public' apres backfill P1.1) ; correct des qu'un
-- exemplaire passe en staff_only (toggle frontend a venir, P1.6 / arbitrage B4).
-- Deploiement : CREATE OR REPLACE SECURITY DEFINER (ACL preservees) -> commit --no-verify.

-- =====================================================================
-- (1) RLS : lecture publique filtree par visibility
-- =====================================================================
ALTER POLICY exemplares_public_read ON public.exemplares
  USING (
    EXISTS (
      SELECT 1
      FROM public.book_holdings h
      WHERE h.id = exemplares.holding_id
        AND public.fn_library_visible_to_caller(h.library_id)
        AND (
          exemplares.visibility = 'public'
          OR public.user_has_library_staff_role(auth.uid(), h.library_id)
        )
    )
  );

-- =====================================================================
-- (2) Compteurs : availability publique = stock circulant ('public')
-- =====================================================================
CREATE OR REPLACE FUNCTION public.fn_v2_recompute_holdings_availability(p_holding_ids bigint[] DEFAULT NULL::bigint[], p_book_ids bigint[] DEFAULT NULL::bigint[])
 RETURNS TABLE(holdings_recomputed integer, holdings_updated integer, books_recomputed integer, books_updated integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_holdings_recomputed integer := 0;
  v_holdings_updated integer := 0;
  v_books_recomputed integer := 0;
  v_books_updated integer := 0;
begin
  with target_holdings as (
    select h.id, h.book_id
    from public.book_holdings h
    where (
      coalesce(cardinality(p_holding_ids), 0) = 0
      or h.id = any(p_holding_ids)
    )
      and (
        coalesce(cardinality(p_book_ids), 0) = 0
        or h.book_id = any(p_book_ids)
      )
  )
  select count(*)::int
    into v_holdings_recomputed
  from target_holdings;

  with target_books as (
    select distinct h.book_id
    from public.book_holdings h
    where (
      coalesce(cardinality(p_holding_ids), 0) = 0
      or h.id = any(p_holding_ids)
    )
      and (
        coalesce(cardinality(p_book_ids), 0) = 0
        or h.book_id = any(p_book_ids)
      )

    union

    select distinct x.book_id
    from unnest(coalesce(p_book_ids, '{}'::bigint[])) as x(book_id)
  )
  select count(*)::int
    into v_books_recomputed
  from target_books;

  with target_holdings as (
    select h.id, h.book_id
    from public.book_holdings h
    where (
      coalesce(cardinality(p_holding_ids), 0) = 0
      or h.id = any(p_holding_ids)
    )
      and (
        coalesce(cardinality(p_book_ids), 0) = 0
        or h.book_id = any(p_book_ids)
      )
  ),
  exemplar_counts as (
    select
      e.holding_id,
      count(*)::int as exemplares_total_calc
    from public.exemplares e
    where e.holding_id is not null
      and e.visibility = 'public'   -- P1.4a
    group by e.holding_id
  ),
  open_loans as (
    select
      e.holding_id,
      count(*)::int as emprestimos_abertos_calc
    from public.emprestimo_itens_v2 i
    join public.exemplares e
      on e.id = i.item_id
    where i.item_status = 'aberto'
      and e.holding_id is not null
      and e.visibility = 'public'   -- P1.4a
    group by e.holding_id
  ),
  active_reservas as (
    select
      rl.holding_id,
      count(*)::int as reservas_ativas_calc
    from public.reserva_linhas_v2 rl
    where rl.item_status = 'ativa'
      and rl.holding_id is not null
    group by rl.holding_id
  ),
  open_interlibrary_loans as (
    select
      il.holding_id,
      count(*)::int as emprestimos_interbib_abertos_calc
    from public.interlibrary_loan_items_v2 il
    where il.item_status in ('reservado_para_saida', 'emprestado')
      and il.holding_id is not null
    group by il.holding_id
  ),
  stats as (
    select
      th.id as holding_id,
      th.book_id,
      coalesce(ec.exemplares_total_calc, 0)::int as exemplares_total_calc,
      greatest(
        coalesce(ec.exemplares_total_calc, 0)
        - coalesce(ol.emprestimos_abertos_calc, 0)
        - coalesce(ar.reservas_ativas_calc, 0)
        - coalesce(oil.emprestimos_interbib_abertos_calc, 0),
        0
      )::int as available_count_calc
    from target_holdings th
    left join exemplar_counts ec
      on ec.holding_id = th.id
    left join open_loans ol
      on ol.holding_id = th.id
    left join active_reservas ar
      on ar.holding_id = th.id
    left join open_interlibrary_loans oil
      on oil.holding_id = th.id
  ),
  updated as (
    update public.book_holdings h
       set exemplares_total = s.exemplares_total_calc,
           available_count = s.available_count_calc,
           updated_at = timezone('utc', now())
      from stats s
     where h.id = s.holding_id
       and (
         h.exemplares_total is distinct from s.exemplares_total_calc
         or h.available_count is distinct from s.available_count_calc
       )
    returning 1
  )
  select count(*)::int
    into v_holdings_updated
  from updated;

  with target_holdings as (
    select h.id, h.book_id
    from public.book_holdings h
    where (
      coalesce(cardinality(p_holding_ids), 0) = 0
      or h.id = any(p_holding_ids)
    )
      and (
        coalesce(cardinality(p_book_ids), 0) = 0
        or h.book_id = any(p_book_ids)
      )
  ),
  target_books as (
    select distinct th.book_id
    from target_holdings th

    union

    select distinct x.book_id
    from unnest(coalesce(p_book_ids, '{}'::bigint[])) as x(book_id)
  ),
  exemplar_counts as (
    select
      e.holding_id,
      count(*)::int as exemplares_total_calc
    from public.exemplares e
    where e.holding_id is not null
      and e.visibility = 'public'   -- P1.4a
    group by e.holding_id
  ),
  open_loans as (
    select
      e.holding_id,
      count(*)::int as emprestimos_abertos_calc
    from public.emprestimo_itens_v2 i
    join public.exemplares e
      on e.id = i.item_id
    where i.item_status = 'aberto'
      and e.holding_id is not null
      and e.visibility = 'public'   -- P1.4a
    group by e.holding_id
  ),
  active_reservas as (
    select
      rl.holding_id,
      count(*)::int as reservas_ativas_calc
    from public.reserva_linhas_v2 rl
    where rl.item_status = 'ativa'
      and rl.holding_id is not null
    group by rl.holding_id
  ),
  open_interlibrary_loans as (
    select
      il.holding_id,
      count(*)::int as emprestimos_interbib_abertos_calc
    from public.interlibrary_loan_items_v2 il
    where il.item_status in ('reservado_para_saida', 'emprestado')
      and il.holding_id is not null
    group by il.holding_id
  ),
  stats as (
    select
      th.id as holding_id,
      th.book_id,
      greatest(
        coalesce(ec.exemplares_total_calc, 0)
        - coalesce(ol.emprestimos_abertos_calc, 0)
        - coalesce(ar.reservas_ativas_calc, 0)
        - coalesce(oil.emprestimos_interbib_abertos_calc, 0),
        0
      )::int as available_count_calc
    from target_holdings th
    left join exemplar_counts ec
      on ec.holding_id = th.id
    left join open_loans ol
      on ol.holding_id = th.id
    left join active_reservas ar
      on ar.holding_id = th.id
    left join open_interlibrary_loans oil
      on oil.holding_id = th.id
  ),
  book_totals as (
    select
      tb.book_id,
      coalesce(sum(s.available_count_calc), 0)::int as available_count_calc
    from target_books tb
    left join stats s
      on s.book_id = tb.book_id
    group by tb.book_id
  ),
  updated as (
    update public.books b
       set available_count = bt.available_count_calc,
           updated_at = now()
      from book_totals bt
     where b.id = bt.book_id
       and b.available_count is distinct from bt.available_count_calc
    returning 1
  )
  select count(*)::int
    into v_books_updated
  from updated;

  return query
  select
    v_holdings_recomputed,
    v_holdings_updated,
    v_books_recomputed,
    v_books_updated;
end;
$function$;

-- =====================================================================
-- Recalcul complet sous la nouvelle regle (no-op aujourd'hui : tout 'public')
-- + smoke-test : la fonction tourne sans erreur apres remplacement.
-- =====================================================================
do $$
declare
  r record;
begin
  select * into r from public.fn_v2_recompute_holdings_availability();
  raise notice 'P1.4a recompute: holdings recalcules=%, maj=%, books recalcules=%, maj=%',
    r.holdings_recomputed, r.holdings_updated, r.books_recomputed, r.books_updated;
end
$$;

-- =====================================================================
-- Verifications non destructives
-- =====================================================================
do $$
begin
  -- (1) la policy porte le filtre visibility
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'exemplares'
      and policyname = 'exemplares_public_read' and qual like '%visibility%'
  ) then
    raise exception 'P1.4a: filtre visibility absent de la policy exemplares_public_read';
  end if;

  -- (2) la fonction de recompute porte bien le filtre visibility dans son corps
  if (length(pg_get_functiondef('public.fn_v2_recompute_holdings_availability(bigint[],bigint[])'::regprocedure))
      - length(replace(pg_get_functiondef('public.fn_v2_recompute_holdings_availability(bigint[],bigint[])'::regprocedure),
                       'e.visibility', '')))
     / length('e.visibility') < 4 then
    raise exception 'P1.4a: les 4 filtres e.visibility ne sont pas tous presents dans le recompute';
  end if;
end
$$;
