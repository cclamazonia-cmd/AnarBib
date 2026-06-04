-- 20260604174831_catalog_discard_rpcs.sql
-- ----------------------------------------------------------------------------
-- Chantier "discard catalogue" : remplacer les delete directs de CatalogPanel
-- (books / authors / exemplares) par des RPC gardees (doctrine RPC v3 + #150),
-- et amorcer la tracabilite du catalogue mutualise (catalog_audit_log).
--
-- Pourquoi : un `delete from books` direct cascade book_holdings PUIS met
-- exemplares.holding_id a NULL (orphelinage silencieux des copies physiques).
-- On ne supprime donc que ce dont RIEN ne depend ; sinon refus motive.
--   - exemplar : refus si consulta / emprestimo / PEB le referencent (RESTRICT).
--   - book     : refus si acervo (book_holdings) ou historique d'emprunt.
--   - author   : refus si rattache a >=1 documento (book_authors).
-- RBAC : exemplar borne a sa biblio (user_can_manage_library, inclut admin reseau)
--        ; book/author ouverts au staff actif (librarian/coordenador) -- le
--        catalogage est partage et ces fiches sont du commun reseau orphelin.
--
-- NB deploiement : ces fonctions sont SECURITY DEFINER -> le hook pre-commit se
-- declenche (faux positif documente #80). Commit avec --no-verify (legitime ici).
-- ----------------------------------------------------------------------------

-- == 1. Journal d'audit du catalogue (immuable ; ecrit seulement via RPC) ==
create table if not exists public.catalog_audit_log (
  id           bigint generated always as identity primary key,
  occurred_at  timestamptz not null default now(),
  actor_id     uuid,
  action       text        not null,
  entity_type  text        not null,
  entity_id    bigint      not null,
  library_id   uuid,
  label        text,
  details      jsonb       not null default '{}'::jsonb,
  constraint catalog_audit_log_entity_chk check (entity_type in ('book','author','exemplar'))
);

create index if not exists catalog_audit_log_entity_idx   on public.catalog_audit_log (entity_type, entity_id);
create index if not exists catalog_audit_log_occurred_idx on public.catalog_audit_log (occurred_at desc);
create index if not exists catalog_audit_log_actor_idx    on public.catalog_audit_log (actor_id);

alter table public.catalog_audit_log enable row level security;

-- Lecture reservee au staff actif. Aucune policy write : journal immuable,
-- ecrit uniquement par les RPC SECURITY DEFINER ci-dessous.
drop policy if exists catalog_audit_log_select_staff on public.catalog_audit_log;
create policy catalog_audit_log_select_staff on public.catalog_audit_log
  for select to authenticated
  using (exists (
    select 1 from public.user_library_memberships m
    where m.user_id = auth.uid()
      and m.role in ('librarian','coordenador')
      and m.status = 'active'
  ));

-- == 2a. discard_book ==
create or replace function public.discard_book(p_book_id bigint)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_uid   uuid := auth.uid();
  v_label text;
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

  select titulo into v_label from public.books where id = p_book_id;
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

  -- intencao de leitor, nao e historico
  delete from public.user_wishlist where book_id = p_book_id;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  values (v_uid, 'discard', 'book', p_book_id, v_label, jsonb_build_object('via', 'CatalogPanel'));

  delete from public.books where id = p_book_id;
end;
$$;

-- == 2b. discard_author ==
create or replace function public.discard_author(p_author_id bigint)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_uid   uuid := auth.uid();
  v_label text;
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

  select preferred_name into v_label from public.authors where id = p_author_id;
  if not found then
    raise exception 'Autoridade não encontrada (ID %).', p_author_id
      using errcode = 'P0002', hint = 'catalog_discard_not_found';
  end if;

  if exists (select 1 from public.book_authors where author_id = p_author_id) then
    raise exception 'Esta autoridade está vinculada a um ou mais documentos. Desvincule-a primeiro.'
      using errcode = 'P0001', hint = 'catalog_discard_author_linked';
  end if;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  values (v_uid, 'discard', 'author', p_author_id, v_label, jsonb_build_object('via', 'CatalogPanel'));

  delete from public.authors where id = p_author_id;
end;
$$;

-- == 2c. discard_exemplar ==
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
begin
  if v_uid is null then
    raise exception 'Não autenticado.'
      using errcode = '28000', hint = 'catalog_discard_unauthenticated';
  end if;

  select library_id, coalesce(tombo, bib_ref) into v_lib, v_label
  from public.exemplares where id = p_exemplar_id;
  if not found then
    raise exception 'Exemplar não encontrado (ID %).', p_exemplar_id
      using errcode = 'P0002', hint = 'catalog_discard_not_found';
  end if;

  -- RBAC : borne a la biblio de l'exemplaire (coord/libraire local ou admin reseau)
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
  values (v_uid, 'discard', 'exemplar', p_exemplar_id, v_lib, v_label, jsonb_build_object('via', 'CatalogPanel'));

  delete from public.exemplares where id = p_exemplar_id;
end;
$$;

-- == 3. Privileges : RPC frontend (Cat 1) -> authenticated uniquement ==
revoke all on function public.discard_book(bigint)     from public, anon, service_role;
revoke all on function public.discard_author(bigint)   from public, anon, service_role;
revoke all on function public.discard_exemplar(bigint) from public, anon, service_role;
grant execute on function public.discard_book(bigint)     to authenticated;
grant execute on function public.discard_author(bigint)   to authenticated;
grant execute on function public.discard_exemplar(bigint) to authenticated;

-- == 4. Verification (creation) -- Woodpecker rouge si KO ==
do $verif$
declare
  v_missing int;
  v_priv    int;
begin
  select count(*) into v_missing
  from (values ('discard_book'),('discard_author'),('discard_exemplar')) t(n)
  where not exists (
    select 1 from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = t.n and p.prosecdef
      and exists (select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) c where c like 'search_path=%')
  );
  if v_missing > 0 then
    raise exception 'VERIF_FAIL_1 : % fonction(s) discard manquante(s)/non-secdef/sans search_path', v_missing;
  end if;

  select count(*) into v_priv
  from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
  where ns.nspname = 'public' and p.proname in ('discard_book','discard_author','discard_exemplar')
    and ( not has_function_privilege('authenticated', p.oid, 'EXECUTE')
       or has_function_privilege('anon', p.oid, 'EXECUTE') );
  if v_priv > 0 then
    raise exception 'VERIF_FAIL_2 : privileges discard incorrects (authenticated requis / anon interdit)';
  end if;

  if not exists (
    select 1 from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public' and c.relname = 'catalog_audit_log' and c.relrowsecurity
  ) then
    raise exception 'VERIF_FAIL_3 : catalog_audit_log absente ou RLS desactivee';
  end if;

  raise notice 'VERIF OK : discard_book/author/exemplar + catalog_audit_log';
end
$verif$;

-- == 5. Recharger le cache PostgREST ==
notify pgrst, 'reload schema';
