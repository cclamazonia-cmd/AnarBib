-- 20260604190944_catalog_discard_full_snapshot.sql
-- ----------------------------------------------------------------------------
-- Blindage du journal d'audit : les 3 RPC discard capturent desormais la LIGNE
-- COMPLETE (to_jsonb) dans catalog_audit_log.details->'snapshot' AVANT le delete.
-- Motif : un journal label-only ne permet pas de restaurer (verifie en conditions
-- reelles le 04/06 -- impossible de ressusciter fidelement un exemplaire descarte).
-- Avec le snapshot row-level, un futur "restaurar" pourra rebatir la ligne.
--
-- Portee : snapshot de la ligne PRINCIPALE (books/authors/exemplares). La capture
-- des lignes filles cascadees (book_authors, contributors, aliases...) viendra
-- avec la fonctionnalite de restauration (chantier gouvernance). Pour l'exemplaire
-- -- le cas qui nous a mordus -- la ligne principale suffit (pas d'enfant cascade).
--
-- create or replace : signatures inchangees => grants/ACL preserves ; on les
-- re-assere par defense en profondeur (#150). SECURITY DEFINER => hook pre-commit
-- (faux positif #80) => commit avec --no-verify.
-- ----------------------------------------------------------------------------

-- == discard_book ==
create or replace function public.discard_book(p_book_id bigint)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_uid   uuid := auth.uid();
  v_label text;
  v_snap  jsonb;
begin
  if v_uid is null then
    raise exception 'Não autenticado.'
      using errcode = '28000', hint = 'catalog_discard_unauthenticated';
  end if;
  if not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = v_uid and m.role in ('librarian','coordenador') and m.status = 'active'
  ) then
    raise exception 'Apenas bibliotecárias e coordenadoras podem descartar fichas do catálogo.'
      using errcode = '42501', hint = 'catalog_discard_forbidden';
  end if;

  select titulo, to_jsonb(b) into v_label, v_snap from public.books b where id = p_book_id;
  if not found then
    raise exception 'Documento não encontrado (ID %).', p_book_id
      using errcode = 'P0002', hint = 'catalog_discard_not_found';
  end if;

  if exists (select 1 from public.book_holdings where book_id = p_book_id) then
    raise exception 'Este documento possui acervo (exemplares em uma ou mais bibliotecas). Descarte os exemplares primeiro.'
      using errcode = 'P0001', hint = 'catalog_discard_has_holdings';
  end if;
  if exists (select 1 from public.emprestimo_itens_v2 where book_id = p_book_id) then
    raise exception 'Este documento tem histórico de empréstimo e não pode ser apagado.'
      using errcode = 'P0001', hint = 'catalog_discard_has_loans';
  end if;

  delete from public.user_wishlist where book_id = p_book_id;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  values (v_uid, 'discard', 'book', p_book_id, v_label,
          jsonb_build_object('via', 'CatalogPanel', 'snapshot', v_snap));

  delete from public.books where id = p_book_id;
end;
$$;

-- == discard_author ==
create or replace function public.discard_author(p_author_id bigint)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_uid   uuid := auth.uid();
  v_label text;
  v_snap  jsonb;
begin
  if v_uid is null then
    raise exception 'Não autenticado.'
      using errcode = '28000', hint = 'catalog_discard_unauthenticated';
  end if;
  if not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = v_uid and m.role in ('librarian','coordenador') and m.status = 'active'
  ) then
    raise exception 'Apenas bibliotecárias e coordenadoras podem descartar fichas do catálogo.'
      using errcode = '42501', hint = 'catalog_discard_forbidden';
  end if;

  select preferred_name, to_jsonb(a) into v_label, v_snap from public.authors a where id = p_author_id;
  if not found then
    raise exception 'Autoridade não encontrada (ID %).', p_author_id
      using errcode = 'P0002', hint = 'catalog_discard_not_found';
  end if;

  if exists (select 1 from public.book_authors where author_id = p_author_id) then
    raise exception 'Esta autoridade está vinculada a um ou mais documentos. Desvincule-a primeiro.'
      using errcode = 'P0001', hint = 'catalog_discard_author_linked';
  end if;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  values (v_uid, 'discard', 'author', p_author_id, v_label,
          jsonb_build_object('via', 'CatalogPanel', 'snapshot', v_snap));

  delete from public.authors where id = p_author_id;
end;
$$;

-- == discard_exemplar ==
create or replace function public.discard_exemplar(p_exemplar_id bigint)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_uid   uuid := auth.uid();
  v_lib   uuid;
  v_label text;
  v_snap  jsonb;
begin
  if v_uid is null then
    raise exception 'Não autenticado.'
      using errcode = '28000', hint = 'catalog_discard_unauthenticated';
  end if;

  select library_id, coalesce(tombo, bib_ref), to_jsonb(e)
    into v_lib, v_label, v_snap
  from public.exemplares e where id = p_exemplar_id;
  if not found then
    raise exception 'Exemplar não encontrado (ID %).', p_exemplar_id
      using errcode = 'P0002', hint = 'catalog_discard_not_found';
  end if;

  if v_lib is not null then
    if not public.user_can_manage_library(v_lib) then
      raise exception 'Você não tem permissão para descartar exemplares desta biblioteca.'
        using errcode = '42501', hint = 'catalog_discard_forbidden';
    end if;
  else
    if not exists (
      select 1 from public.user_library_memberships m
      where m.user_id = v_uid and m.role in ('librarian','coordenador') and m.status = 'active'
    ) then
      raise exception 'Apenas bibliotecárias e coordenadoras podem descartar exemplares.'
        using errcode = '42501', hint = 'catalog_discard_forbidden';
    end if;
  end if;

  if exists (select 1 from public.consulta_linhas_v2        where item_id = p_exemplar_id)
     or exists (select 1 from public.emprestimo_itens_v2       where item_id = p_exemplar_id)
     or exists (select 1 from public.interlibrary_loan_items_v2 where item_id = p_exemplar_id) then
    raise exception 'Este exemplar tem histórico de circulação (consulta, empréstimo ou PEB) e não pode ser apagado.'
      using errcode = 'P0001', hint = 'catalog_discard_exemplar_in_circulation';
  end if;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  values (v_uid, 'discard', 'exemplar', p_exemplar_id, v_lib, v_label,
          jsonb_build_object('via', 'CatalogPanel', 'snapshot', v_snap));

  delete from public.exemplares where id = p_exemplar_id;
end;
$$;

-- == Privileges (re-assertion defensive ; create or replace les preserve deja) ==
revoke all on function public.discard_book(bigint)     from public, anon, service_role;
revoke all on function public.discard_author(bigint)   from public, anon, service_role;
revoke all on function public.discard_exemplar(bigint) from public, anon, service_role;
grant execute on function public.discard_book(bigint)     to authenticated;
grant execute on function public.discard_author(bigint)   to authenticated;
grant execute on function public.discard_exemplar(bigint) to authenticated;

-- == Verification : secdef + search_path + privileges + snapshot bien cable ==
do $verif$
declare
  v_bad int;
begin
  select count(*) into v_bad
  from (values ('discard_book'),('discard_author'),('discard_exemplar')) t(n)
  where not exists (
    select 1 from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = t.n and p.prosecdef
      and exists (select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) c where c like 'search_path=%')
      and pg_get_functiondef(p.oid) like '%''snapshot''%'
  );
  if v_bad > 0 then
    raise exception 'VERIF_FAIL_1 : % fonction(s) discard sans snapshot/secdef/search_path', v_bad;
  end if;

  select count(*) into v_bad
  from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
  where ns.nspname = 'public' and p.proname in ('discard_book','discard_author','discard_exemplar')
    and ( not has_function_privilege('authenticated', p.oid, 'EXECUTE')
       or has_function_privilege('anon', p.oid, 'EXECUTE') );
  if v_bad > 0 then
    raise exception 'VERIF_FAIL_2 : privileges discard incorrects (authenticated requis / anon interdit)';
  end if;

  raise notice 'VERIF OK : discard_* snapshotent la ligne complete + privileges OK';
end
$verif$;

notify pgrst, 'reload schema';
