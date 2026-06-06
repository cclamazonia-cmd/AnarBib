-- =========================================================================
-- Paquet revert — retrait des colonnes activity_*/affiliation (B2, voie A)
-- =========================================================================
-- Session  : Exemplaires & nettoyage catalogue
-- Auteur   : Xavier + Claude
--
-- CONTEXTE
-- --------
-- La migration 20260606221008 avait ajoute activity_start/activity_end/affiliation
-- a authors + author_drafts. MAIS le formulaire d'autorite gere deja la periode
-- d'activite en META texte-libre encodee dans `notes` (champ activityPeriod) —
-- ces colonnes faisaient doublon et perdaient la souplesse texte-libre.
-- Choix valide (voie A) : revenir au modele meta existant. On revert
-- publish_author_draft a sa version d'origine et on retire les 3 colonnes.
-- =========================================================================

BEGIN;

-- Revert : publish_author_draft sans activity_*/affiliation (version d'origine).
CREATE OR REPLACE FUNCTION public.publish_author_draft(p_draft_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_draft public.author_drafts%rowtype;
  v_author_id bigint;
begin
  select * into v_draft
  from public.author_drafts
  where id = p_draft_id;

  if not found then
    raise exception 'Rascunho de autor não encontrado: %', p_draft_id;
  end if;

  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de autor foi descartado.';
  end if;

  if v_draft.published_author_id is null then
    insert into public.authors (
      preferred_name, sort_name, biography, birth_year, death_year, country,
      source_kind, source_label, source_url, viaf_id, isni, wikidata_id,
      variant_forms, photo_object_path, notes,
      created_by, updated_by, updated_at
    )
    values (
      v_draft.preferred_name, v_draft.sort_name, v_draft.biography, v_draft.birth_year, v_draft.death_year, v_draft.country,
      v_draft.source_kind, v_draft.source_label, v_draft.source_url, v_draft.viaf_id, v_draft.isni, v_draft.wikidata_id,
      v_draft.variant_forms, v_draft.photo_object_path, v_draft.notes,
      coalesce(v_draft.created_by, auth.uid()), coalesce(v_draft.updated_by, auth.uid()), now()
    )
    returning id into v_author_id;
  else
    update public.authors
    set
      preferred_name = v_draft.preferred_name,
      sort_name = v_draft.sort_name,
      biography = v_draft.biography,
      birth_year = v_draft.birth_year,
      death_year = v_draft.death_year,
      country = v_draft.country,
      source_kind = v_draft.source_kind,
      source_label = v_draft.source_label,
      source_url = v_draft.source_url,
      viaf_id = v_draft.viaf_id,
      isni = v_draft.isni,
      wikidata_id = v_draft.wikidata_id,
      variant_forms = v_draft.variant_forms,
      photo_object_path = v_draft.photo_object_path,
      notes = v_draft.notes,
      updated_by = coalesce(v_draft.updated_by, auth.uid()),
      updated_at = now()
    where id = v_draft.published_author_id
    returning id into v_author_id;
  end if;

  update public.author_drafts
  set
    published_author_id = v_author_id,
    status = 'published',
    updated_by = coalesce(v_draft.updated_by, auth.uid()),
    updated_at = now()
  where id = p_draft_id;

  return v_author_id;
end;
$function$;

-- Retrait des colonnes prematurees.
ALTER TABLE public.authors
  DROP COLUMN IF EXISTS activity_start,
  DROP COLUMN IF EXISTS activity_end,
  DROP COLUMN IF EXISTS affiliation;

ALTER TABLE public.author_drafts
  DROP COLUMN IF EXISTS activity_start,
  DROP COLUMN IF EXISTS activity_end,
  DROP COLUMN IF EXISTS affiliation;

NOTIFY pgrst, 'reload schema';

COMMIT;
