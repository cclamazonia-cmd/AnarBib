-- 20260622121316_catalog_discard_book_cascade.sql
-- ----------------------------------------------------------------------------
-- Descarte d'un document AVEC ses exemplaires/holdings de MA bibliothèque.
--
-- discard_book (existant) bloque si le document possède des book_holdings
-- (« Descarte os exemplares primeiro »). Or supprimer un document, c'est
-- logiquement vouloir retirer aussi le fonds de SA propre bibliothèque. Cette RPC
-- fait le cascade ATOMIQUE et SCOPÉ :
--   1. supprime les exemplaires des bibliothèques que l'appelant·e gère, rattachés
--      à ce document (via holding) — REFUS si l'un a un historique de circulation
--      (consulta / emprunt / PEB) : on n'efface jamais d'historique ;
--   2. supprime les holdings de ces bibliothèques pour ce document ;
--   3. supprime le DOCUMENT lui-même UNIQUEMENT s'il ne reste plus AUCUN holding
--      (fédération : on ne supprime pas une notice qu'une autre biblio détient) —
--      avec le même garde-fou « historique d'emprunt » que discard_book.
-- Tout est audité (catalog_audit_log). Renvoie un bilan jsonb.
--
-- Garde-fous anti-suppression erronée : staff only, refus si circulation/emprunt,
-- document conservé s'il reste détenu ailleurs. L'avertissement UI précède l'appel.
--
-- Auteur  : Claude (assistant·e)
-- Session : Fonds sonores
-- Doctrine: SECURITY DEFINER + search_path + REVOKE/GRANT. Validé BEGIN/ROLLBACK.
-- ----------------------------------------------------------------------------

begin;

create or replace function public.discard_book_cascade(p_book_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid   uuid := auth.uid();
  v_label text;
  v_snap  jsonb;
  v_ex_deleted   int := 0;
  v_hold_deleted int := 0;
  v_book_deleted boolean := false;
  v_remaining    int;
  r record;
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

  -- 1) Exemplaires de MES bibliothèques rattachés à ce document (via holding).
  for r in
    select e.id, e.library_id, coalesce(e.tombo, e.bib_ref) as lbl, to_jsonb(e) as snap
      from public.exemplares e
      join public.book_holdings h on h.id = e.holding_id
     where h.book_id = p_book_id
       and public.user_can_manage_library(e.library_id)
  loop
    if exists (select 1 from public.consulta_linhas_v2         where item_id = r.id)
       or exists (select 1 from public.emprestimo_itens_v2        where item_id = r.id)
       or exists (select 1 from public.interlibrary_loan_items_v2 where item_id = r.id) then
      raise exception 'Um exemplar deste documento tem histórico de circulação e não pode ser apagado.'
        using errcode = 'P0001', hint = 'error.catalog.discard.exemplarInCirculation';
    end if;
    insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
    values (v_uid, 'discard', 'exemplar', r.id, r.library_id, r.lbl,
            jsonb_build_object('via', 'CatalogPanel:cascade', 'book_id', p_book_id, 'snapshot', r.snap));
    delete from public.exemplares where id = r.id;
    v_ex_deleted := v_ex_deleted + 1;
  end loop;

  -- 2) Holdings de MES bibliothèques pour ce document.
  for r in
    select h.id, h.library_id from public.book_holdings h
     where h.book_id = p_book_id and public.user_can_manage_library(h.library_id)
  loop
    delete from public.book_holdings where id = r.id;
    v_hold_deleted := v_hold_deleted + 1;
  end loop;

  -- 3) Le document : supprimé seulement si plus AUCUN holding ne reste (autres biblios).
  select count(*) into v_remaining from public.book_holdings where book_id = p_book_id;
  if v_remaining = 0 then
    if exists (select 1 from public.emprestimo_itens_v2 where book_id = p_book_id) then
      raise exception 'Este documento tem histórico de empréstimo e não pode ser apagado.'
        using errcode = 'P0001', hint = 'error.catalog.discard.bookHasLoans';
    end if;
    delete from public.user_wishlist where book_id = p_book_id;
    insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
    values (v_uid, 'discard', 'book', p_book_id, v_label,
            jsonb_build_object('via', 'CatalogPanel:cascade', 'snapshot', v_snap));
    delete from public.books where id = p_book_id;
    v_book_deleted := true;
  end if;

  return jsonb_build_object(
    'ok', true,
    'exemplars_deleted', v_ex_deleted,
    'holdings_deleted',  v_hold_deleted,
    'book_deleted',      v_book_deleted,
    'remaining_holdings', v_remaining
  );
end;
$function$;

revoke all on function public.discard_book_cascade(bigint) from public, anon, service_role;
grant execute on function public.discard_book_cascade(bigint) to authenticated;

notify pgrst, 'reload schema';

do $$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                 where n.nspname='public' and p.proname='discard_book_cascade') then
    raise exception 'discard_book_cascade manquante';
  end if;
  raise notice 'discard_book_cascade OK';
end $$;

commit;
