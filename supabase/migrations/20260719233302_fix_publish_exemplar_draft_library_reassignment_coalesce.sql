-- #cross-lib-reassign (19/07) : dans la branche UPDATE (edition d'un exemplaire
-- deja publie), "library_id = coalesce(exemplares.library_id, v_library_id)"
-- gardait TOUJOURS l'ancienne bibliotheque puisqu'un exemplaire existant a
-- toujours un library_id non nul -> aucune reattribution de bibliotheque
-- n'etait jamais possible via ce RPC, meme quand v_library_id avait ete
-- correctement resolu vers la nouvelle bibliotheque cible. On inverse l'ordre
-- pour que la bibliotheque nouvellement resolue l'emporte (elle est garantie
-- non nulle a ce point de la fonction).
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
  v_final_tombo text;                       -- chantier 14 : tombo final (saisi ou auto)
begin
  -- #79 RBAC : publication reservee au staff de catalogacao (librarian/coordenador).
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
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
     limit 1;
    if found then
      -- #fix-attrib (17/07) : l'ancien filtre "(v_library_id is null or h.library_id
      -- = v_library_id)" degenerait en vrai quand v_library_id etait encore nul, et
      -- la ligne suivante ecrasait silenciosamente v_library_id par celle du holding
      -- trouve, quelle que soit sa biblio. Desormais on ne rejette que le cas d'un
      -- conflit explicite (biblio-cible deja connue et differente du holding vise) ;
      -- sinon on adopte la biblio du holding comme avant.
      if v_library_id is not null and v_holding.library_id is distinct from v_library_id then
        raise exception 'O holding % pertence a outra biblioteca do que a biblioteca-alvo do rascunho.', v_draft.target_holding_id
          USING ERRCODE = '23514', HINT = 'error.catalog.holding_library_mismatch';
      end if;
      v_resolved_holding_id := v_holding.id;
      v_library_id := v_holding.library_id;
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

  -- P1.2 + DOC-CIRC-1 : seed du padrão de circulation depuis a fiche (books.loanable).
  select case when b.loanable then 'ambos' else 'consulta' end   -- DOC-CIRC-1
    into v_seed_policy
    from public.book_holdings h
    join public.books b on b.id = h.book_id
   where h.id = v_resolved_holding_id;
  v_seed_policy := coalesce(v_seed_policy, 'consulta');

  -- Chantier 14 : tombo final. Si le brouillon n'en porte pas, on genere le
  -- prochain libre via fn_next_tombo (v_library_id est garanti non-null ici).
  v_final_tombo := nullif(btrim(coalesce(v_draft.tombo, '')), '');
  if v_final_tombo is null then
    v_final_tombo := public.fn_next_tombo(v_library_id);
  end if;

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
      v_final_tombo,
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
           tombo = coalesce(v_final_tombo, public.exemplares.tombo),
           shelf_location = v_draft.shelf_location,
           label_title_override = v_draft.label_title_override,
           label_author_override = v_draft.label_author_override,
           label_cdd_override = v_draft.label_cdd_override,
           label_note = v_draft.label_note,
           notes = v_draft.notes,
           library_id = coalesce(v_library_id, public.exemplares.library_id),
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
