-- Retrait definitif de l'exemplaire surnumeraire CCLA.2026.41 (id=2467,
-- holding BLMF 1251) du livre "Educar para emancipar" (book_id=2301) : la
-- BLMF ne detient reellement qu'1 seul exemplaire physique (CCLA.2026.39),
-- pas 2. Aucun historique de circulation (0 emprestimo/reserva/interbib) au
-- moment de cette migration -> retrait sans risque de perte de donnees de
-- circulation. Journalise dans catalog_audit_log avant suppression, comme le
-- fait discard_book_cascade pour les retraits via le CatalogPanel.
--
-- Migration de donnees ponctuelle (staging uniquement, garde-fous
-- d'existence + de non-circulation pour rester no-op ailleurs et refuser un
-- rejeu apres qu'un emprunt aurait ete enregistre entre-temps).
do $$
declare
  v_exemplar record;
begin
  select e.id, e.tombo, e.library_id, e.holding_id, h.book_id, to_jsonb(e) as snap
    into v_exemplar
    from public.exemplares e
    join public.book_holdings h on h.id = e.holding_id
   where e.id = 2467
     and e.tombo = 'CCLA.2026.41';

  if not found then
    raise notice 'discard_surplus_exemplar_ccla_2026_41: exemplar 2467/CCLA.2026.41 absent (hors staging ou deja retire) - migration ignoree.';
    return;
  end if;

  if exists (select 1 from public.consulta_linhas_v2 where item_id = v_exemplar.id)
     or exists (select 1 from public.emprestimo_itens_v2 where item_id = v_exemplar.id)
     or exists (select 1 from public.interlibrary_loan_items_v2 where item_id = v_exemplar.id)
     or exists (select 1 from public.reserva_linhas_v2 where item_id = v_exemplar.id) then
    raise exception 'discard_surplus_exemplar_ccla_2026_41: exemplar 2467 a um historico de circulacao - retrait refuse.';
  end if;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  values (null, 'discard', 'exemplar', v_exemplar.id, v_exemplar.library_id, v_exemplar.tombo,
          jsonb_build_object('via', 'migration:discard_surplus_exemplar_ccla_2026_41',
                              'reason', 'surnumeraire - BLMF ne detient qu 1 exemplaire reel',
                              'book_id', v_exemplar.book_id,
                              'snapshot', v_exemplar.snap));

  delete from public.exemplares where id = v_exemplar.id;

  perform public.fn_v2_recompute_holdings_availability(p_book_ids := ARRAY[v_exemplar.book_id]);
end $$;
