-- =========================================================================
-- Paquet fix — corriger le nom de colonne source_lib -> source_library
-- =========================================================================
-- Session  : Exemplaires & nettoyage catalogue
-- Auteur   : Xavier + Claude
-- Chantier : Catalogage / champs acquisition
--
-- BUG
-- ---
-- La colonne reelle (exemplar_drafts ET exemplares) est `source_library`, pas
-- `source_lib`. Les fonctions publish_exemplar_draft et
-- create_exemplar_draft_from_exemplar referencaient `v_draft.source_lib` /
-- colonne `source_lib`. plpgsql ne valide pas les champs %rowtype a la creation
-- -> les migrations ont deploye "vert" mais cassent au RUNTIME :
--   "Could not find the 'source_lib' column of 'exemplar_drafts'".
-- (Le formulaire ExemplarDraftForm est corrige en parallele cote frontend.)
--
-- CREATE OR REPLACE des 2 fonctions a l'identique + source_lib -> source_library.
-- =========================================================================

BEGIN;

-- 1) publish_exemplar_draft : valeur INSERT + coalesce UPDATE
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
      acquisition_mode,                     -- acquisition
      acquisition_date,                     -- acquisition
      provenance_note,                      -- acquisition
      source_library,                       -- acquisition
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
      coalesce(v_draft.circulation_policy, v_seed_policy),   -- P1.2
      coalesce(v_draft.visibility, 'public'),                -- P1.2
      v_draft.acquisition_mode,
      v_draft.acquisition_date,
      v_draft.provenance_note,
      v_draft.source_library,
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
           acquisition_mode = coalesce(v_draft.acquisition_mode, public.exemplares.acquisition_mode),
           acquisition_date = coalesce(v_draft.acquisition_date, public.exemplares.acquisition_date),
           provenance_note  = coalesce(v_draft.provenance_note,  public.exemplares.provenance_note),
           source_library   = coalesce(v_draft.source_library,   public.exemplares.source_library),
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

-- 2) create_exemplar_draft_from_exemplar : nom de colonne INSERT
CREATE OR REPLACE FUNCTION public.create_exemplar_draft_from_exemplar(p_exemplar_id bigint, p_batch_id bigint DEFAULT NULL::bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id bigint;
begin
  insert into public.exemplar_drafts (
    published_exemplar_id,
    batch_id,
    action,
    status,
    label_status,
    target_bib_ref,
    target_library_id,
    target_holding_id,
    tombo,
    shelf_location,
    label_title_override,
    label_author_override,
    label_cdd_override,
    label_note,
    notes,
    acquisition_mode,
    acquisition_date,
    provenance_note,
    source_library,
    created_by,
    updated_by
  )
  select
    e.id,
    p_batch_id,
    'update',
    'draft',
    'pending',
    coalesce(
      nullif(trim(h.local_bib_ref), ''),
      rb.local_bib_ref,
      b_holding.bib_ref,
      b_legacy.bib_ref,
      e.bib_ref
    ) as target_bib_ref,
    e.library_id as target_library_id,
    coalesce(e.holding_id, rb.holding_id) as target_holding_id,
    e.tombo,
    e.shelf_location,
    e.label_title_override,
    e.label_author_override,
    e.label_cdd_override,
    e.label_note,
    e.notes,
    e.acquisition_mode,
    e.acquisition_date,
    e.provenance_note,
    e.source_library,
    auth.uid(),
    auth.uid()
  from public.exemplares e
  left join public.book_holdings h
    on h.id = e.holding_id
  left join public.books b_holding
    on b_holding.id = h.book_id
  left join lateral public.resolve_library_holding_bridge(e.library_id, e.bib_ref) rb
    on e.holding_id is null
  left join public.books b_legacy
    on e.holding_id is null
   and rb.holding_id is null
   and b_legacy.bib_ref = e.bib_ref
  where e.id = p_exemplar_id
  returning id into v_id;

  if v_id is null then
    raise exception 'Exemplar não encontrado: %', p_exemplar_id;
  end if;

  perform public.sync_exemplar_draft_holdings_bridge(v_id);

  return v_id;
end;
$function$;

NOTIFY pgrst, 'reload schema';

COMMIT;
