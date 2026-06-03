-- =====================================================================
-- Phase 1 Catalogação — P1.2 : destination dans publish_exemplar_draft
-- (seed circulation_policy + propagation circulation_policy/visibility du draft)
--
-- CORRIGE AUSSI une régression introduite par P1.1 : circulation_policy est
-- NOT NULL sans DEFAULT ; l'INSERT de création d'exemplaire ne l'alimentait pas
-- => toute création d'exemplaire au publish levait une violation NOT NULL.
--
-- DOCTRINE :
--   - CREATE OR REPLACE (signature inchangée) => les ACL existantes sont
--     PRÉSERVÉES. On ne touche PAS aux droits ici (dump sans ACL : modèle de
--     droits non vérifiable ; un REVOKE/GRANT à l'aveugle risquerait de couper
--     l'appel). Durcissement éventuel = geste séparé après inspection proacl.
--   - Le hook pre-commit (Test 2) va signaler ce SECURITY DEFINER sans
--     "REVOKE EXECUTE FROM PUBLIC" : c'est ATTENDU pour un CREATE OR REPLACE de
--     fonction existante. Commit avec  git commit --no-verify  (cas documenté
--     par le hook lui-même).
--   - Seed du padrão : dérivé de books.loanable AUJOURD'HUI ; le padrão
--     3-valeurs « Circulação local padrão » viendra avec spec-catalogacao-fiche.
--
-- ⚠️ AVANT PUSH : ce corps est RECONSTRUIT depuis le dump schéma 03/06 (qui
--    portait des artefacts d'encodage UTF-16 sur les chaînes PT-BR). DIFFER
--    contre la définition courante en prod (pg_get_functiondef / source repo) :
--    les SEULES modifications voulues sont marquées « -- P1.2 ».
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.publish_exemplar_draft(p_draft_id bigint)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
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

  -- P1.2 : seed du padrão de circulation depuis la fiche (books.loanable).
  --        Fallback prudent 'consulta' (exemplaire sans holding/fiche résolus).
  select case when b.loanable then 'emprestavel' else 'consulta' end
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
$$;

-- Vérification minimale (information_schema ; RAISE = rollback)
DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'publish_exemplar_draft'
      AND p.prosecdef                              -- SECURITY DEFINER conservé
  ) THEN
    RAISE EXCEPTION 'publish_exemplar_draft absente ou non SECURITY DEFINER apres remplacement';
  END IF;
END
$do$;

COMMIT;
