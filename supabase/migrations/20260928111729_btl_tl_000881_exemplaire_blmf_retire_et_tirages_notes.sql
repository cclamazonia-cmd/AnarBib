-- ============================================================================
-- BTL-TL-000881 : l'exemplaire CCLA.2026.93 (BLMF), créé par erreur le 27/09,
-- est retiré ; les deux exemplaires BTL portent leur tirage (2010, 2011).
-- Demandé par Xavier le 28/09/2026 (« sur cette notice, ce sont deux
-- exemplaires qu'il faut attribuer à BTL : un de 2010 et l'autre de 2011 »).
--
-- CONTEXTE. Le 27/09 à 19:18 UTC, pendant que la fusion de BTL-TL-000880
-- (2011) dans BTL-TL-000881 (2010) était impossible à l'écran — doublon non
-- détecté, réglé par 20260927194141 —, un exemplaire a été créé sur
-- BTL-TL-000881 depuis un poste BLMF (brouillon d'exemplaire 39) : tombo
-- CCLA.2026.93, fonds BLMF 2745, jamais prêté ni réservé. La BLMF ne détient
-- pas ce titre. Après la fusion, les deux exemplaires BTL sont là :
-- BTL-TL-EX-000881 (tirage 2010) et BTL-TL-EX-000880 (tirage 2011, venu de la
-- notice fusionnée) ; la notice garde 2010, la première édition.
--
-- Rejouée sur une base sans ces données (banc, CI), la migration ne fait rien.
-- ============================================================================
begin;

do $$
declare
  v_ex public.exemplares%rowtype;
  v_n  int;
begin
  select * into v_ex from public.exemplares where tombo = 'CCLA.2026.93';
  if not found then
    raise notice 'CCLA.2026.93 absent : rien à retirer (banc, ou déjà fait)';
  else
    -- Garde : l'exemplaire attendu (id 2796, fonds BLMF 2745 de BTL-TL-000881),
    -- et qui n'a jamais circulé. Sinon on ne retire rien.
    if v_ex.id <> 2796 or v_ex.holding_id is distinct from 2745
       or not exists (select 1 from public.book_holdings h join public.books b on b.id = h.book_id
                       where h.id = v_ex.holding_id and b.bib_ref = 'BTL-TL-000881') then
      raise exception 'CCLA.2026.93 n''est pas l''exemplaire attendu (id %, fonds %) : rien retiré',
        v_ex.id, v_ex.holding_id;
    end if;
    if exists (select 1 from public.emprestimo_itens_v2 where item_id = v_ex.id)
       or exists (select 1 from public.reserva_linhas_v2 where item_id = v_ex.id)
       or exists (select 1 from public.consulta_linhas_v2 where item_id = v_ex.id)
       or exists (select 1 from public.interlibrary_loan_items_v2 where item_id = v_ex.id) then
      raise exception 'CCLA.2026.93 a circulé : rien retiré';
    end if;

    -- Le brouillon qui l'a créé garde la trace ; il n'est plus « publié »
    -- (la clé published_exemplar_id passe à NULL avec l'exemplaire).
    update public.exemplar_drafts
       set status = 'cancelled',
           notes = concat_ws(' — ', nullif(btrim(notes), ''),
                             'Exemplaire créé par erreur le 27/09/2026 sur BTL-TL-000881 (doublon non détecté) ; retiré par migration le 28/09/2026.'),
           updated_at = now()
     where published_exemplar_id = v_ex.id;

    delete from public.exemplares where id = v_ex.id;

    -- Le fonds BLMF n'avait que lui.
    delete from public.book_holdings h
     where h.id = v_ex.holding_id
       and not exists (select 1 from public.exemplares e where e.holding_id = h.id);
    get diagnostics v_n = row_count;
    raise notice 'CCLA.2026.93 retiré ; fonds BLMF supprimé : %', v_n;
  end if;

  -- Les tirages, en note interne de chaque exemplaire BTL (une seule fois).
  update public.exemplares e
     set notes = concat_ws(' — ', nullif(btrim(e.notes), ''), 'Tirage de 2010.'),
         updated_at = now()
   where e.tombo = 'BTL-TL-EX-000881' and coalesce(e.notes, '') not like '%Tirage de 2010%';
  update public.exemplares e
     set notes = concat_ws(' — ', nullif(btrim(e.notes), ''),
                           'Tirage de 2011 (ex-notice BTL-TL-000880, fusionnée dans BTL-TL-000881 le 28/09/2026 ; la notice garde 2010, la première édition).'),
         updated_at = now()
   where e.tombo = 'BTL-TL-EX-000880' and coalesce(e.notes, '') not like '%Tirage de 2011%';

  if exists (select 1 from public.books where bib_ref = 'BTL-TL-000881') then
    perform public.fn_v2_recompute_holdings_availability(
      null, array[(select id from public.books where bib_ref = 'BTL-TL-000881')]);
  end if;
end $$;

commit;
