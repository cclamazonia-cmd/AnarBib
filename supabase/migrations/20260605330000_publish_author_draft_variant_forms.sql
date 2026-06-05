-- =========================================================================
-- Paquet Track D / P4 — publish_author_draft propage variant_forms
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : catalogação / autorités (Track D — sources externes & autorités)
-- Auteur   : AnarBib (assisté)
--
-- POURQUOI
--   L'Atelier autorités (CAT-D5d, AuthorDraftForm tier Completo) écrit
--   `variant_forms` (jsonb : labels + alias par langue, issus de Wikidata)
--   dans `author_drafts`. La fonction `publish_author_draft` — antérieure à
--   l'ajout de la colonne (migration 20260605200000) — ne copiait PAS
--   `variant_forms` du brouillon vers `authors`. Conséquence : les formes
--   variantes étaient PERDUES à la publication. Ce patch comble le trou.
--
-- DOCTRINE
--   CREATE OR REPLACE à signature identique (p_draft_id bigint) RETURNS bigint
--   → préserve ownership + privilèges existants (REVOKE anon de L.5,
--     GRANT authenticated). On ré-assert REVOKE FROM PUBLIC + GRANT
--     authenticated par lisibilité (idempotent). search_path conservé
--     identique à la définition vivante ('public'). Pas de DROP (signature
--     inchangée → DOC-OBJ-2 n'impose pas DROP+CREATE).
--
--   Corps repris VERBATIM du dump vivant (docs/db/dump_153D_2026-05-27.sql),
--   seule différence : 2 ajouts de `variant_forms` (INSERT + UPDATE).
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.publish_author_draft(p_draft_id bigint)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $$
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
      preferred_name,
      sort_name,
      biography,
      birth_year,
      death_year,
      country,
      source_kind,
      source_label,
      source_url,
      viaf_id,
      isni,
      wikidata_id,
      variant_forms,
      photo_object_path,
      notes,
      created_by,
      updated_by,
      updated_at
    )
    values (
      v_draft.preferred_name,
      v_draft.sort_name,
      v_draft.biography,
      v_draft.birth_year,
      v_draft.death_year,
      v_draft.country,
      v_draft.source_kind,
      v_draft.source_label,
      v_draft.source_url,
      v_draft.viaf_id,
      v_draft.isni,
      v_draft.wikidata_id,
      v_draft.variant_forms,
      v_draft.photo_object_path,
      v_draft.notes,
      coalesce(v_draft.created_by, auth.uid()),
      coalesce(v_draft.updated_by, auth.uid()),
      now()
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
$$;

-- Privilèges (idempotent ; préserve l'accès frontend authenticated, anon resté REVOKE depuis L.5)
REVOKE EXECUTE ON FUNCTION public.publish_author_draft(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publish_author_draft(bigint) TO authenticated;

-- -------------------------------------------------------------------------
-- Vérification automatique
-- -------------------------------------------------------------------------
DO $verif$
DECLARE
  v_def text;
BEGIN
  -- 1) variant_forms doit désormais apparaître dans le corps de la fonction
  SELECT pg_get_functiondef('public.publish_author_draft(bigint)'::regprocedure) INTO v_def;
  IF position('variant_forms' IN v_def) = 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_1 : publish_author_draft ne reference pas variant_forms';
  END IF;

  -- 2) non-régression : authenticated doit garder EXECUTE (sinon frontend catalogage casse)
  IF NOT has_function_privilege('authenticated', 'public.publish_author_draft(bigint)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'VERIF_FAIL_2 : authenticated a perdu EXECUTE sur publish_author_draft (regression)';
  END IF;

  -- 3) anon ne doit PAS avoir EXECUTE (doctrine L.5)
  IF has_function_privilege('anon', 'public.publish_author_draft(bigint)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'VERIF_FAIL_3 : anon a EXECUTE sur publish_author_draft (doit etre REVOKE)';
  END IF;
END
$verif$;

COMMIT;
