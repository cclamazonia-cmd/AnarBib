-- =========================================================================
-- Robustesse tombo — fin des collisions 23505 à la publication d'exemplaires
-- =========================================================================
-- Date     : 2026-08-15
-- Chantier : catalogage / exemplaires
-- Auteur   : Xavier (+ Claude)
--
-- Symptôme : publish_exemplar_draft échoue avec 23505 (unique_violation) sur
-- public.exemplares_unique_tombo — l'index unique porte sur `tombo` SEUL, donc
-- GLOBAL (toutes bibliothèques). Deux causes réelles :
--   1. Le tombo est pré-rempli à l'OUVERTURE du formulaire (fn_next_tombo) puis
--      figé dans le brouillon. En mutirão / double-clic, un autre exemplaire
--      prend ce numéro entre-temps → le tombo figé est obsolète à la publication.
--   2. fn_next_tombo calculait le max en filtrant sur library_id ; si deux
--      biblios partagent un préfixe, la valeur « libre pour la biblio » pouvait
--      être déjà prise globalement.
--
-- Deux correctifs complémentaires :
--   A. fn_next_tombo : max PAR PRÉFIXE (sans filtre library_id) + verrou d'avis
--      sur le préfixe → respecte l'unicité globale.
--   B. publish_exemplar_draft : l'INSERT dans exemplares est encapsulé ; sur
--      unique_violation (forcément le tombo — seul index unique hors PK), on
--      régénère un tombo libre via fn_next_tombo et on réessaie une fois.
--      Sûr : l'étiquette est imprimée APRÈS publication depuis le tombo réel
--      stocké, donc aucun décalage physique.
--
-- Aucun changement de signature / sécurité / grants (CREATE OR REPLACE).
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- A. fn_next_tombo — unicité GLOBALE par préfixe
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_next_tombo(p_library_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_pat         jsonb;
  v_prefix      text;
  v_use_year    boolean;
  v_sep         text;
  v_pad         int;
  v_full_prefix text;
  v_max         bigint;
  v_next        bigint;
  v_num_str     text;
begin
  select tombo_pattern into v_pat
    from public.libraries where id = p_library_id;

  if v_pat is null then
    raise exception 'tombo_pattern_not_configured'
      using errcode = 'P0001',
            hint = format('Nenhum padrão de tombo configurado para a biblioteca %s.', p_library_id);
  end if;

  v_prefix   := coalesce(v_pat->>'prefix', '');
  v_use_year := coalesce((v_pat->>'year')::boolean, false);
  v_sep      := coalesce(v_pat->>'sep', '');
  v_pad      := coalesce((v_pat->>'pad')::int, 0);

  v_full_prefix := v_prefix
    || case when v_use_year then to_char(current_date, 'YYYY') || v_sep else '' end;

  -- Sérialise la génération PAR PRÉFIXE (même biblio OU biblios au préfixe
  -- partagé) pour la durée de la transaction. #fix-tombo-global (15/08/2026).
  perform pg_advisory_xact_lock(hashtext('tombo:' || v_full_prefix));

  -- Max sous ce préfixe, TOUTES BIBLIOTHÈQUES CONFONDUES (unicité globale de
  -- `tombo`). Séquence à trous tolérée. Préfixes prod sans '%' ni '_' → LIKE sûr.
  select coalesce(max(
           (substring(e.tombo from char_length(v_full_prefix) + 1))::bigint
         ), 0)
    into v_max
    from public.exemplares e
   where e.tombo like v_full_prefix || '%'
     and substring(e.tombo from char_length(v_full_prefix) + 1) ~ '^[0-9]+$';

  v_next := v_max + 1;
  v_num_str := case when v_pad > 0
                    then lpad(v_next::text, v_pad, '0')
                    else v_next::text end;

  return v_full_prefix || v_num_str;
end;
$function$;

-- -------------------------------------------------------------------------
-- B. publish_exemplar_draft — régénération du tombo sur collision
-- -------------------------------------------------------------------------
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
  v_seed_policy text;
  v_final_tombo text;
begin
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

  select case when b.loanable then 'ambos' else 'consulta' end
    into v_seed_policy
    from public.book_holdings h
    join public.books b on b.id = h.book_id
   where h.id = v_resolved_holding_id;
  v_seed_policy := coalesce(v_seed_policy, 'consulta');

  -- Chantier 14 : tombo final. Si le brouillon n'en porte pas, on génère le
  -- prochain libre via fn_next_tombo (v_library_id garanti non-null ici).
  v_final_tombo := nullif(btrim(coalesce(v_draft.tombo, '')), '');
  if v_final_tombo is null then
    v_final_tombo := public.fn_next_tombo(v_library_id);
  end if;

  if v_draft.published_exemplar_id is null then
    -- #fix-tombo-stale (15/08/2026) : le tombo figé dans le brouillon peut être
    -- devenu obsolète (mutirão, double-clic, préfixe partagé). Sur collision
    -- d'unicité (forcément le tombo — seul index unique hors PK), on régénère un
    -- tombo libre et on réessaie une fois. fn_next_tombo est global-safe.
    begin
      insert into public.exemplares (
        bib_ref, tombo, shelf_location,
        label_title_override, label_author_override, label_cdd_override, label_note,
        notes, library_id, holding_id,
        circulation_policy, visibility,
        acquisition_mode, acquisition_date, provenance_note, source_library,
        created_at, updated_at
      ) values (
        coalesce(v_resolved_bib_ref, v_draft.target_bib_ref),
        v_final_tombo, v_draft.shelf_location,
        v_draft.label_title_override, v_draft.label_author_override, v_draft.label_cdd_override, v_draft.label_note,
        v_draft.notes, v_library_id, v_resolved_holding_id,
        coalesce(v_draft.circulation_policy, v_seed_policy),
        coalesce(v_draft.visibility, 'public'),
        v_draft.acquisition_mode, v_draft.acquisition_date, v_draft.provenance_note, v_draft.source_library,
        now(), now()
      )
      returning id into v_exemplar_id;
    exception when unique_violation then
      v_final_tombo := public.fn_next_tombo(v_library_id);
      insert into public.exemplares (
        bib_ref, tombo, shelf_location,
        label_title_override, label_author_override, label_cdd_override, label_note,
        notes, library_id, holding_id,
        circulation_policy, visibility,
        acquisition_mode, acquisition_date, provenance_note, source_library,
        created_at, updated_at
      ) values (
        coalesce(v_resolved_bib_ref, v_draft.target_bib_ref),
        v_final_tombo, v_draft.shelf_location,
        v_draft.label_title_override, v_draft.label_author_override, v_draft.label_cdd_override, v_draft.label_note,
        v_draft.notes, v_library_id, v_resolved_holding_id,
        coalesce(v_draft.circulation_policy, v_seed_policy),
        coalesce(v_draft.visibility, 'public'),
        v_draft.acquisition_mode, v_draft.acquisition_date, v_draft.provenance_note, v_draft.source_library,
        now(), now()
      )
      returning id into v_exemplar_id;
    end;
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
           circulation_policy = coalesce(v_draft.circulation_policy, public.exemplares.circulation_policy),
           visibility = coalesce(v_draft.visibility, public.exemplares.visibility),
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

COMMIT;
