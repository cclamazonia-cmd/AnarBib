-- 20260619160150_catalog_discard_i18n_hints.sql
-- ----------------------------------------------------------------------------
-- i18n des messages d'erreur des RPC discard_book/discard_author/discard_exemplar.
--
-- Les hints machine 'catalog_discard_*' ne commencent PAS par 'error.', donc
-- src/lib/localizeError.js (Cas 1 : err.hint.startsWith('error.')) ne les traduit
-- pas. Comme ce sont des RAISE EXCEPTION P0001 (message delibere), le helper
-- retombe au Cas 3 « phrase libre » et affiche le message BRUT en pt-BR sur une
-- UI non lusophone (ex. « Esta autoridade está vinculada... » sur une UI FR).
--
-- Fix : re-prefixer les hints en 'error.catalog.discard.*' (cles i18n reelles,
-- definies dans les 10 locales). AUCUN changement front : localizeError traduit
-- le hint automatiquement. Le texte pt-BR du RAISE reste comme fallback/log.
--
-- Bodies repris A L'IDENTIQUE des fonctions live (seuls les hints changent).
-- create or replace : signatures inchangees => grants/ACL preserves ; re-asseres
-- par defense en profondeur (#150). SECURITY DEFINER + SET search_path conserves
-- => hook pre-commit (faux positif #80) => commit avec --no-verify si besoin.
-- Session : Doublons d'autorite & i18n erreurs catalogue
-- ----------------------------------------------------------------------------

-- == discard_book ==
create or replace function public.discard_book(p_book_id bigint)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid   uuid := auth.uid();
  v_label text;
  v_snap  jsonb;
begin
  if v_uid is null then
    raise exception 'Não autenticado.'
      using errcode = '28000', hint = 'error.catalog.discard.unauthenticated';
  end if;
  if not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = v_uid and m.role in ('librarian','coordenador') and m.status = 'active'
  ) then
    raise exception 'Apenas bibliotecárias e coordenadoras podem descartar fichas do catálogo.'
      using errcode = '42501', hint = 'error.catalog.discard.forbidden';
  end if;

  select titulo, to_jsonb(b) into v_label, v_snap from public.books b where id = p_book_id;
  if not found then
    raise exception 'Documento não encontrado (ID %).', p_book_id
      using errcode = 'P0002', hint = 'error.catalog.discard.notFound';
  end if;

  if exists (select 1 from public.book_holdings where book_id = p_book_id) then
    raise exception 'Este documento possui acervo (exemplares em uma ou mais bibliotecas). Descarte os exemplares primeiro.'
      using errcode = 'P0001', hint = 'error.catalog.discard.bookHasHoldings';
  end if;
  if exists (select 1 from public.emprestimo_itens_v2 where book_id = p_book_id) then
    raise exception 'Este documento tem histórico de empréstimo e não pode ser apagado.'
      using errcode = 'P0001', hint = 'error.catalog.discard.bookHasLoans';
  end if;

  delete from public.user_wishlist where book_id = p_book_id;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  values (v_uid, 'discard', 'book', p_book_id, v_label,
          jsonb_build_object('via', 'CatalogPanel', 'snapshot', v_snap));

  delete from public.books where id = p_book_id;
end;
$function$;

-- == discard_author ==
create or replace function public.discard_author(p_author_id bigint)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid   uuid := auth.uid();
  v_label text;
  v_snap  jsonb;
begin
  if v_uid is null then
    raise exception 'Não autenticado.'
      using errcode = '28000', hint = 'error.catalog.discard.unauthenticated';
  end if;
  if not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = v_uid and m.role in ('librarian','coordenador') and m.status = 'active'
  ) then
    raise exception 'Apenas bibliotecárias e coordenadoras podem descartar fichas do catálogo.'
      using errcode = '42501', hint = 'error.catalog.discard.forbidden';
  end if;

  select preferred_name, to_jsonb(a) into v_label, v_snap from public.authors a where id = p_author_id;
  if not found then
    raise exception 'Autoridade não encontrada (ID %).', p_author_id
      using errcode = 'P0002', hint = 'error.catalog.discard.notFound';
  end if;

  if exists (select 1 from public.book_authors where author_id = p_author_id) then
    raise exception 'Esta autoridade está vinculada a um ou mais documentos. Desvincule-a primeiro.'
      using errcode = 'P0001', hint = 'error.catalog.discard.authorLinked';
  end if;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  values (v_uid, 'discard', 'author', p_author_id, v_label,
          jsonb_build_object('via', 'CatalogPanel', 'snapshot', v_snap));

  delete from public.authors where id = p_author_id;
end;
$function$;

-- == discard_exemplar ==
create or replace function public.discard_exemplar(p_exemplar_id bigint)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid   uuid := auth.uid();
  v_lib   uuid;
  v_label text;
  v_snap  jsonb;
begin
  if v_uid is null then
    raise exception 'Não autenticado.'
      using errcode = '28000', hint = 'error.catalog.discard.unauthenticated';
  end if;

  select library_id, coalesce(tombo, bib_ref), to_jsonb(e)
    into v_lib, v_label, v_snap
  from public.exemplares e where id = p_exemplar_id;
  if not found then
    raise exception 'Exemplar não encontrado (ID %).', p_exemplar_id
      using errcode = 'P0002', hint = 'error.catalog.discard.notFound';
  end if;

  if v_lib is not null then
    if not public.user_can_manage_library(v_lib) then
      raise exception 'Você não tem permissão para descartar exemplares desta biblioteca.'
        using errcode = '42501', hint = 'error.catalog.discard.forbidden';
    end if;
  else
    if not exists (
      select 1 from public.user_library_memberships m
      where m.user_id = v_uid and m.role in ('librarian','coordenador') and m.status = 'active'
    ) then
      raise exception 'Apenas bibliotecárias e coordenadoras podem descartar exemplares.'
        using errcode = '42501', hint = 'error.catalog.discard.forbidden';
    end if;
  end if;

  if exists (select 1 from public.consulta_linhas_v2        where item_id = p_exemplar_id)
     or exists (select 1 from public.emprestimo_itens_v2       where item_id = p_exemplar_id)
     or exists (select 1 from public.interlibrary_loan_items_v2 where item_id = p_exemplar_id) then
    raise exception 'Este exemplar tem histórico de circulação (consulta, empréstimo ou PEB) e não pode ser apagado.'
      using errcode = 'P0001', hint = 'error.catalog.discard.exemplarInCirculation';
  end if;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  values (v_uid, 'discard', 'exemplar', p_exemplar_id, v_lib, v_label,
          jsonb_build_object('via', 'CatalogPanel', 'snapshot', v_snap));

  delete from public.exemplares where id = p_exemplar_id;
end;
$function$;

-- == Privileges (re-assertion defensive ; create or replace les preserve deja) ==
revoke all on function public.discard_book(bigint)     from public, anon, service_role;
revoke all on function public.discard_author(bigint)   from public, anon, service_role;
revoke all on function public.discard_exemplar(bigint) from public, anon, service_role;
grant execute on function public.discard_book(bigint)     to authenticated;
grant execute on function public.discard_author(bigint)   to authenticated;
grant execute on function public.discard_exemplar(bigint) to authenticated;

notify pgrst, 'reload schema';
