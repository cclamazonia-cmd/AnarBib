-- Migration P1.4b-etape-1 -- DOC-CIRC-1 : defaut de circulation_policy empruntable -> 'ambos'
-- spec-exemplaires-circulation §4.2 (amende) + REGISTRE DOC-CIRC-1 (03/06/2026).
--
-- Deux volets, une transaction :
--   (1) Re-backfill : tous les 'emprestavel' actuels viennent du defaut (backfill P1.1 / seed P1.2),
--       aucun n'a ete pose a la main (editeur d'exemplaire pas encore livre, P1.6). On les passe
--       a 'ambos' (pret + consultation), conformement a DOC-CIRC-1. 'emprestavel' redevient une
--       restriction deliberee par exemplaire, jamais un defaut.
--   (2) Seed : publish_exemplar_draft pre-remplit desormais empruntable -> 'ambos' (et non plus
--       'emprestavel'), sinon chaque nouvelle publication re-injecterait l'ancien defaut.
--       Greffe sur la def autoritaire (pg_get_functiondef) : seule la ligne -- DOC-CIRC-1 differe.
--
-- N'AFFECTE PAS les compteurs : P1.4a filtre sur visibility, pas sur circulation_policy.
-- Aucun recompute requis (circulation_policy ne change pas la visibilite d'un exemplaire).
-- Deploiement : CREATE OR REPLACE SECURITY DEFINER (ACL preservees) -> commit --no-verify.

-- =====================================================================
-- (1) Re-backfill : 'emprestavel' (defaut) -> 'ambos'
-- =====================================================================
do $$
declare
  v_count integer;
begin
  update public.exemplares
     set circulation_policy = 'ambos',
         updated_at = timezone('utc', now())
   where circulation_policy = 'emprestavel';
  get diagnostics v_count = row_count;
  raise notice 'DOC-CIRC-1 re-backfill: % exemplaire(s) emprestavel -> ambos', v_count;
end
$$;

-- =====================================================================
-- (2) Seed corrige dans publish_exemplar_draft (empruntable -> 'ambos')
-- =====================================================================
CREATE OR REPLACE FUNCTION public.publish_exemplar_draft(p_draft_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_draft public.exemplar_drafts%rowtype;
  v_exemplar_id bigint;
  v_library_id uuid;
  v_bridge record;
  v_resolved_holding_id bigint := null;
  v_resolved_bib_ref text := null;
  v_holding record;
  v_seed_policy text;                       -- P1.2 : seed circulation_policy
begin
  perform public.sync_exemplar_draft_holdings_bridge(p_draft_id);

  select * into v_draft from public.exemplar_drafts where id = p_draft_id;
  if not found then
    raise exception 'Rascunho de exemplar não encontrado: %', p_draft_id;
  end if;
  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de exemplar foi descartado.';
  end if;

  v_library_id := v_draft.target_library_id;

  if v_draft.target_holding_id is not null then
    select h.id, h.library_id,
           coalesce(nullif(trim(h.local_bib_ref), ''), b.bib_ref) as reference_code
      into v_holding
      from public.book_holdings h
      left join public.books b on b.id = h.book_id
     where h.id = v_draft.target_holding_id
       and (v_library_id is null or h.library_id = v_library_id)
     limit 1;
    if found then
      v_resolved_holding_id := v_holding.id;
      v_library_id := coalesce(v_holding.library_id, v_library_id);
      v_resolved_bib_ref := v_holding.reference_code;
    end if;
  end if;

  if v_library_id is null and v_draft.published_exemplar_id is not null then
    select e.library_id into v_library_id
      from public.exemplares e where e.id = v_draft.published_exemplar_id;
  end if;

  if v_library_id is null then
    select ulm.library_id into v_library_id
      from public.user_library_memberships ulm
     where ulm.user_id = auth.uid()
       and ulm.status = 'active'
       and ulm.is_primary = true
     limit 1;
  end if;

  if v_library_id is null then
    raise exception 'Nenhuma biblioteca ativa/principal encontrada para o usuário atual.';
  end if;

  if v_resolved_holding_id is null then
    select * into v_bridge
      from public.resolve_library_holding_bridge(v_library_id, v_draft.target_bib_ref)
     limit 1;
    if found then
      v_resolved_holding_id := v_bridge.holding_id;
      v_resolved_bib_ref := coalesce(v_bridge.local_bib_ref, v_bridge.resolved_bib_ref);
    else
      v_resolved_bib_ref := nullif(trim(v_draft.target_bib_ref), '');
    end if;
  end if;

  -- P1.2 + DOC-CIRC-1 : seed du padrão de circulation depuis la fiche (books.loanable).
  --        Empruntable -> 'ambos' (prêt + consultation, consultation = droit par défaut).
  --        Sinon -> 'consulta'. Fallback prudent 'consulta' (sans holding/fiche résolus).
  select case when b.loanable then 'ambos' else 'consulta' end   -- DOC-CIRC-1
    into v_seed_policy
    from public.book_holdings h
    join public.books b on b.id = h.book_id
   where h.id = v_resolved_holding_id;
  v_seed_policy := coalesce(v_seed_policy, 'consulta');

  if v_draft.published_exemplar_id is null then
    insert into public.exemplares (
      bib_ref,
      tombo,
      shelf_location,
      label_title_override,
      label_author_override,
      label_cdd_override,
      label_note,
      notes,
      library_id,
      holding_id,
      circulation_policy,                   -- P1.2
      visibility,                           -- P1.2
      created_at,
      updated_at
    )
    values (
      coalesce(v_resolved_bib_ref, v_draft.target_bib_ref),
      v_draft.tombo,
      v_draft.shelf_location,
      v_draft.label_title_override,
      v_draft.label_author_override,
      v_draft.label_cdd_override,
      v_draft.label_note,
      v_draft.notes,
      v_library_id,
      v_resolved_holding_id,
      coalesce(v_draft.circulation_policy, v_seed_policy),   -- P1.2 : override draft, sinon seed
      coalesce(v_draft.visibility, 'public'),                -- P1.2
      now(),
      now()
    )
    returning id into v_exemplar_id;
  else
    update public.exemplares
       set bib_ref = coalesce(v_resolved_bib_ref, v_draft.target_bib_ref),
           tombo = v_draft.tombo,
           shelf_location = v_draft.shelf_location,
           label_title_override = v_draft.label_title_override,
           label_author_override = v_draft.label_author_override,
           label_cdd_override = v_draft.label_cdd_override,
           label_note = v_draft.label_note,
           notes = v_draft.notes,
           library_id = coalesce(public.exemplares.library_id, v_library_id),
           holding_id = coalesce(v_resolved_holding_id, public.exemplares.holding_id),
           circulation_policy = coalesce(v_draft.circulation_policy, public.exemplares.circulation_policy),  -- P1.2
           visibility = coalesce(v_draft.visibility, public.exemplares.visibility),                          -- P1.2
           updated_at = now()
     where id = v_draft.published_exemplar_id
    returning id into v_exemplar_id;
  end if;

  update public.exemplar_drafts
     set published_exemplar_id = v_exemplar_id,
         target_library_id = coalesce(v_library_id, target_library_id),
         target_holding_id = coalesce(v_resolved_holding_id, target_holding_id),
         target_bib_ref = coalesce(v_resolved_bib_ref, target_bib_ref),
         status = 'published',
         label_status = 'ready',
         updated_by = coalesce(v_draft.updated_by, auth.uid()),
         updated_at = now()
   where id = p_draft_id;

  return v_exemplar_id;
end;
$function$;

-- =====================================================================
-- Verifications non destructives
-- =====================================================================
do $$
begin
  -- (1) plus aucun 'emprestavel' residuel a l'instant de la migration (tout converti en ambos)
  if exists (select 1 from public.exemplares where circulation_policy = 'emprestavel') then
    raise exception 'DOC-CIRC-1: des exemplaires emprestavel subsistent apres re-backfill';
  end if;

  -- (2) le seed de publish_exemplar_draft mappe bien empruntable -> ambos, plus -> emprestavel
  if position('then ''ambos''' in pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure)) = 0 then
    raise exception 'DOC-CIRC-1: seed ambos absent de publish_exemplar_draft';
  end if;
  if position('then ''emprestavel''' in pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure)) > 0 then
    raise exception 'DOC-CIRC-1: ancien seed emprestavel encore present dans publish_exemplar_draft';
  end if;
end
$$;
