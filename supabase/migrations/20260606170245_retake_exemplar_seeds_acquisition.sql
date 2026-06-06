-- =========================================================================
-- Paquet fix — la reprise d'un exemplaire re-seed les champs d'acquisition
-- =========================================================================
-- Date     : 2026-06-06 (horodatage UTC reel)
-- Chantier : Catalogage / round-trip provenance
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- create_exemplar_draft_from_exemplar (action 'Retomar') ne copiait PAS les
-- champs d'acquisition de l'exemplaire publie vers le brouillon. Couple a la
-- propagation cote publish (paquet 20260606164834), le COALESCE evitait toute
-- PERTE, mais l'editeur affichait des champs vides : pas de round-trip complet.
-- Ce paquet seed acquisition_mode/acquisition_date/provenance_note (+ mapping
-- exemplares.source_library -> exemplar_drafts.source_lib) a la reprise.
--
-- CREATE OR REPLACE a l'identique de la version en place + ajout des 4 champs.
-- =========================================================================

BEGIN;

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
    source_lib,
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
    e.source_library,                 -- exemplares.source_library -> draft.source_lib
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

-- =========================================================================
-- Rollback : restaurer la version sans les 4 champs (cf. RPC discard/retake
-- d'origine). Non destructif (CREATE OR REPLACE).
-- =========================================================================
