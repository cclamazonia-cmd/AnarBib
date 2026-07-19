-- #cross-lib-reassign (19/07) : quand un brouillon change explicitement de
-- bibliotheque-cible par rapport a la bibliotheque actuelle de l'exemplaire
-- publie, la fonction retombait sur le holding ACTUEL de l'exemplaire (autre
-- bibliotheque) au lieu de le laisser vide pour re-resolution. Cela ecrasait
-- un target_holding_id volontairement nul par un holding perime et faisait
-- echouer publish_exemplar_draft avec une erreur de coherence biblio/holding
-- (ERRCODE 23514) des qu'on tentait de reattribuer un exemplaire existant a
-- une autre bibliotheque via le formulaire d'indexacao.
CREATE OR REPLACE FUNCTION public.sync_exemplar_draft_holdings_bridge(p_draft_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_target_bib_ref text;
  v_published_exemplar_id bigint;
  v_target_library_id uuid;
  v_target_holding_id bigint;

  v_resolved_library_id uuid := null;
  v_resolved_holding_id bigint := null;
  v_resolved_reference_code text := null;

  v_exemplar_library_id uuid := null;
  v_exemplar_holding_id bigint := null;
  v_bridge record;
  v_holding record;
begin
  select
    d.target_bib_ref,
    d.published_exemplar_id,
    d.target_library_id,
    d.target_holding_id
  into
    v_target_bib_ref,
    v_published_exemplar_id,
    v_target_library_id,
    v_target_holding_id
  from public.exemplar_drafts d
  where d.id = p_draft_id;

  if not found then
    raise exception 'Rascunho de exemplar não encontrado: %', p_draft_id;
  end if;

  if v_published_exemplar_id is not null then
    select e.library_id, e.holding_id
      into v_exemplar_library_id, v_exemplar_holding_id
    from public.exemplares e
    where e.id = v_published_exemplar_id
    limit 1;
  end if;

  v_resolved_library_id := coalesce(v_target_library_id, v_exemplar_library_id);
  v_resolved_holding_id := coalesce(
    v_target_holding_id,
    case
      when v_exemplar_holding_id is not null
           and v_exemplar_library_id is not null
           and v_resolved_library_id is not null
           and v_exemplar_library_id <> v_resolved_library_id
      then null
      else v_exemplar_holding_id
    end
  );

  if v_resolved_holding_id is not null then
    select
      h.id,
      h.library_id,
      coalesce(nullif(trim(h.local_bib_ref), ''), b.bib_ref) as reference_code
    into v_holding
    from public.book_holdings h
    left join public.books b
      on b.id = h.book_id
    where h.id = v_resolved_holding_id
      and (v_resolved_library_id is null or h.library_id = v_resolved_library_id)
    limit 1;

    if found then
      v_resolved_holding_id := v_holding.id;
      v_resolved_library_id := coalesce(v_holding.library_id, v_resolved_library_id);
      v_resolved_reference_code := v_holding.reference_code;
    end if;
  end if;

  if v_resolved_holding_id is null
     and v_resolved_library_id is not null
     and nullif(trim(v_target_bib_ref), '') is not null then
    select *
      into v_bridge
    from public.resolve_library_holding_bridge(v_resolved_library_id, v_target_bib_ref)
    limit 1;

    if found then
      v_resolved_holding_id := v_bridge.holding_id;
      v_resolved_reference_code := coalesce(v_bridge.local_bib_ref, v_bridge.resolved_bib_ref, v_target_bib_ref);
    end if;
  end if;

  update public.exemplar_drafts d
     set target_library_id = coalesce(v_resolved_library_id, d.target_library_id),
         target_holding_id = coalesce(v_resolved_holding_id, d.target_holding_id),
         target_bib_ref = coalesce(v_resolved_reference_code, d.target_bib_ref),
         updated_at = now()
   where d.id = p_draft_id;

  return true;
end;
$function$;
