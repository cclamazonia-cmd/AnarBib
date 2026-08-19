-- Exemplaires sans holding : garde-fou + reparation.
--
-- SYMPTOME (19/08/2026). Deux exemplaires crees pour la BLMF sur « Tres
-- Depoimentos Libertarios » (bib_ref BTL-TL-000049) n'apparaissaient pas au
-- catalogue. Cause : ils ont bien library_id = BLMF, mais holding_id = NULL.
-- Or v_book_detail_public_v2 joint les exemplaires AUX HOLDINGS : sans holding,
-- l'exemplaire est invisible.
--
-- CAUSE RACINE. publish_exemplar_draft() resout le holding via
-- resolve_library_holding_bridge(), qui est STABLE : elle CHERCHE un holding
-- existant dans la bibliotheque cible et ne renvoie rien s'il n'y en a pas.
-- Sa branche `else` se contente alors de conserver le bib_ref et laisse
-- v_resolved_holding_id a NULL — l'insert passe sans erreur. C'est exactement
-- le cas de MUTUALISATION : une bibliotheque ajoute un exemplaire sur une
-- notice commune catalogee par une AUTRE bibliotheque, et n'a donc pas encore
-- de holding local. Autrement dit, le scenario meme qui justifie le reseau.
-- (publish_book_draft(), lui, cree explicitement le holding — d'ou l'asymetrie.)
--
-- POURQUOI LE GARDE-FOU DE JUILLET N'A RIEN VU.
-- fn_validate_exemplar_library_matches_holding() ouvre par
-- « IF NEW.holding_id IS NOT NULL THEN » : il protege du MAUVAIS rattachement
-- (exemplaire d'une biblio accroche au holding d'une autre, incident du 17/07),
-- pas de l'ABSENCE de rattachement. Un holding NULL passait donc tout droit.
--
-- CHOIX : un trigger BEFORE INSERT plutot qu'un correctif dans
-- publish_exemplar_draft(). Il couvre TOUTES les voies d'insertion (publication
-- de brouillon, imports, reprises manuelles), pas seulement celle-ci, et il
-- n'oblige pas a reecrire une fonction de 200 lignes que d'autres chantiers
-- modifient en parallele. Meme esprit que le garde-fou de juillet.
--
-- NOMMAGE : trg_exemplar_ensure_holding se classe avant
-- trg_exemplar_library_matches_holding dans l'ordre alphabetique, donc il
-- s'execute AVANT lui. Le holding qu'il pose est ensuite valide par le garde.
create or replace function public.tg_exemplares_ensure_holding()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
declare
  v_holding_id bigint;
  v_matches    integer;
  v_book_id    bigint;
  v_ref        text := trim(coalesce(new.bib_ref, ''));
begin
  if new.holding_id is not null or new.library_id is null or v_ref = '' then
    return new;
  end if;

  -- 1. Un holding existe-t-il deja pour ce couple (reference, bibliotheque) ?
  --    Meme ordre de resolution que resolve_library_holding_bridge : reference
  --    locale d'abord, reference de la notice commune ensuite.
  select h.id into v_holding_id
  from public.book_holdings h
  join public.books b on b.id = h.book_id
  where h.library_id = new.library_id
    and (trim(coalesce(h.local_bib_ref, '')) = v_ref
      or trim(coalesce(b.bib_ref, ''))       = v_ref)
  order by (trim(coalesce(h.local_bib_ref, '')) = v_ref) desc, h.id
  limit 1;

  if v_holding_id is not null then
    new.holding_id := v_holding_id;
    return new;
  end if;

  -- 2. Sinon, creer le holding local — mais seulement si la notice commune est
  --    identifiee SANS AMBIGUITE. Si zero ou plusieurs notices portent ce
  --    bib_ref, on ne devine pas : on laisse NULL comme avant, et la sonde
  --    ci-dessous permettra de le reperer.
  select count(*), min(b.id) into v_matches, v_book_id
  from public.books b
  where trim(coalesce(b.bib_ref, '')) = v_ref;

  if v_matches = 1 then
    insert into public.book_holdings (book_id, library_id)
    values (v_book_id, new.library_id)
    returning id into new.holding_id;
  end if;

  return new;
end $fn$;

comment on function public.tg_exemplares_ensure_holding() is
  'Garantit qu''un exemplaire insere sans holding_id est rattache au holding local de sa bibliotheque, en le creant si la notice commune est identifiee sans ambiguite. Complete fn_validate_exemplar_library_matches_holding, qui ne verifie que les holdings DEJA renseignes.';

drop trigger if exists trg_exemplar_ensure_holding on public.exemplares;
create trigger trg_exemplar_ensure_holding
  before insert on public.exemplares
  for each row execute function public.tg_exemplares_ensure_holding();

-- Reparation des exemplaires deja orphelins.
-- Au 19/08/2026 : 5 exemplaires invisibles, tous sur le meme motif (une biblio
-- ajoute un exemplaire sur une notice BTL sans holding local) —
-- MLEG-2026-0269 (01/08), CCLA.2026.87 et .88 (15/08), CCLA.2026.90 et .91 (19/08).
do $$
declare
  r record;
  v_holding_id bigint;
  v_matches integer;
  v_book_id bigint;
  v_ref text;
  v_ids bigint[] := '{}';
  v_repares integer := 0;
begin
  for r in
    select id, bib_ref, library_id
    from public.exemplares
    where holding_id is null and library_id is not null
    order by id
  loop
    v_ref := trim(coalesce(r.bib_ref, ''));
    continue when v_ref = '';
    v_holding_id := null;

    select h.id into v_holding_id
    from public.book_holdings h
    join public.books b on b.id = h.book_id
    where h.library_id = r.library_id
      and (trim(coalesce(h.local_bib_ref, '')) = v_ref
        or trim(coalesce(b.bib_ref, ''))       = v_ref)
    order by (trim(coalesce(h.local_bib_ref, '')) = v_ref) desc, h.id
    limit 1;

    if v_holding_id is null then
      select count(*), min(b.id) into v_matches, v_book_id
      from public.books b
      where trim(coalesce(b.bib_ref, '')) = v_ref;

      if v_matches = 1 then
        insert into public.book_holdings (book_id, library_id)
        values (v_book_id, r.library_id)
        returning id into v_holding_id;
      end if;
    end if;

    if v_holding_id is not null then
      update public.exemplares set holding_id = v_holding_id where id = r.id;
      v_ids := v_ids || v_holding_id;
      v_repares := v_repares + 1;
    end if;
  end loop;

  -- Les compteurs (exemplares_total / available_count) sont tenus par un
  -- trigger AFTER INSERT sur exemplares ; un UPDATE du holding_id ne le
  -- declenche pas, d'ou le recalcul explicite.
  if array_length(v_ids, 1) > 0 then
    perform public.fn_v2_recompute_holdings_availability(p_holding_ids := v_ids, p_book_ids := null);
  end if;

  raise notice 'Exemplaires orphelins repares : %', v_repares;
end $$;
