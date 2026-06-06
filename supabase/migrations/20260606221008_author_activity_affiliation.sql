-- =========================================================================
-- Paquet feat — fiche auteur : dates d'activite + affiliation (B2)
-- =========================================================================
-- Session  : Exemplaires & nettoyage catalogue
-- Auteur   : Xavier + Claude
-- Chantier : Autorites / enrichissement fiche auteur
--
-- OBJET
-- -----
-- Ajoute aux autorites deux infos plus utiles que la simple repetition des
-- dates de naissance/deces (cf. B1) : la PERIODE D'ACTIVITE (activity_start /
-- activity_end) et l'AFFILIATION (organisation politique/syndicale, etc.).
-- Champs ajoutes a authors ET author_drafts, et propages par publish_author_draft
-- (INSERT + UPDATE). Donnees a saisir ulterieurement (formulaire d'autorite).
-- =========================================================================

BEGIN;

ALTER TABLE public.authors
  ADD COLUMN IF NOT EXISTS activity_start smallint,
  ADD COLUMN IF NOT EXISTS activity_end   smallint,
  ADD COLUMN IF NOT EXISTS affiliation    text;

ALTER TABLE public.author_drafts
  ADD COLUMN IF NOT EXISTS activity_start smallint,
  ADD COLUMN IF NOT EXISTS activity_end   smallint,
  ADD COLUMN IF NOT EXISTS affiliation    text;

COMMENT ON COLUMN public.authors.activity_start IS 'Annee de debut de periode d''activite (floruit), si connue.';
COMMENT ON COLUMN public.authors.activity_end   IS 'Annee de fin de periode d''activite, si connue.';
COMMENT ON COLUMN public.authors.affiliation    IS 'Appartenance (organisation politique/syndicale, collectif...), texte libre.';

-- Propagation brouillon -> autorite.
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
      activity_start, activity_end, affiliation,
      created_by, updated_by, updated_at
    )
    values (
      v_draft.preferred_name, v_draft.sort_name, v_draft.biography, v_draft.birth_year, v_draft.death_year, v_draft.country,
      v_draft.source_kind, v_draft.source_label, v_draft.source_url, v_draft.viaf_id, v_draft.isni, v_draft.wikidata_id,
      v_draft.variant_forms, v_draft.photo_object_path, v_draft.notes,
      v_draft.activity_start, v_draft.activity_end, v_draft.affiliation,
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
      activity_start = v_draft.activity_start,
      activity_end = v_draft.activity_end,
      affiliation = v_draft.affiliation,
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

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback : CREATE OR REPLACE de publish_author_draft sans les 3 champs +
-- ALTER TABLE ... DROP COLUMN activity_start, activity_end, affiliation.
-- =========================================================================
