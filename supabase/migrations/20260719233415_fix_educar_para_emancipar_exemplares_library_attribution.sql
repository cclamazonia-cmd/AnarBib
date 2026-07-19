-- Corrige l'attribution des 3 exemplaires du livre "Educar para emancipar"
-- (Hugues Lenoir, book_id=2301, bib_ref=0000100), tous rattaches a BLMF alors
-- qu'ils devaient etre repartis BLMF/BTL/MLEG :
--   - CCLA.2026.40 (exemplar id=2466) -> deplace vers BTL (holding 1330),
--     retombe BTL-TL-EX-002365, comme demande par le catalogueur.
--   - MLEG-2026-0268 (exemplar id=2746, cree le 18/07) n'avait encore aucun
--     book_holdings MLEG pour ce livre -> get-or-create + rattachement.
-- Cause racine (bug applicatif, deja corrige par les 2 migrations precedentes
-- de cette serie #cross-lib-reassign) : sync_exemplar_draft_holdings_bridge
-- retombait sur le holding ACTUEL de l'exemplaire au lieu de re-resoudre pour
-- la nouvelle bibliotheque cible, et publish_exemplar_draft ne pouvait de
-- toute facon jamais ecraser library_id sur un exemplaire deja publie.
--
-- Migration de donnees ponctuelle (staging uniquement, cf. garde-fous
-- d'existence pour rester no-op sur le schema CI vide).
do $$
declare
  v_book_id bigint := 2301;
  v_btl_id uuid := 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a';
  v_mleg_id uuid := 'dfa87c64-4a2f-4a6d-9e92-646d90ac2b22';
  v_btl_holding_id bigint := 1330;
  v_mleg_holding_id bigint;
begin
  if not exists (select 1 from public.books where id = v_book_id) then
    raise notice 'fix_educar_para_emancipar: livre % absent (hors staging) - migration ignoree.', v_book_id;
    return;
  end if;

  -- 1) CCLA.2026.40 -> BTL.
  if exists (select 1 from public.exemplares where id = 2466 and tombo = 'CCLA.2026.40') then
    update public.exemplares
       set library_id = v_btl_id,
           holding_id = v_btl_holding_id,
           tombo = 'BTL-TL-EX-002365',
           bib_ref = 'BTL-TL-000986',
           updated_at = now()
     where id = 2466;

    update public.exemplar_drafts
       set status = 'published',
           label_status = 'ready',
           updated_at = now()
     where id = 28
       and published_exemplar_id = 2466;
  else
    raise notice 'fix_educar_para_emancipar: exemplar 2466/CCLA.2026.40 absent ou deja deplace - etape BTL ignoree.';
  end if;

  -- 2) get-or-create le holding MLEG pour ce livre, rattacher MLEG-2026-0268.
  if exists (select 1 from public.exemplares where id = 2746 and tombo = 'MLEG-2026-0268') then
    insert into public.book_holdings (book_id, library_id)
    values (v_book_id, v_mleg_id)
    on conflict (book_id, library_id) do update set updated_at = now()
    returning id into v_mleg_holding_id;

    update public.exemplares
       set library_id = v_mleg_id,
           holding_id = v_mleg_holding_id,
           updated_at = now()
     where id = 2746;

    update public.exemplar_drafts
       set published_exemplar_id = 2746,
           target_holding_id = v_mleg_holding_id,
           tombo = 'MLEG-2026-0268',
           status = 'published',
           label_status = 'ready',
           updated_at = now()
     where id = 27
       and target_library_id = v_mleg_id
       and published_exemplar_id is null;
  else
    raise notice 'fix_educar_para_emancipar: exemplar 2746/MLEG-2026-0268 absent - etape MLEG ignoree.';
  end if;

  perform public.fn_v2_recompute_holdings_availability(p_book_ids := ARRAY[v_book_id]);
end $$;
