-- =========================================================================
-- Autorités : la langue du nom se saisit (CONV-6, 27/09/2026)
-- =========================================================================
-- Réf. : REGISTRE §37 CONV-6 (acté 03/09 : `authors.name_lang` pilote la règle
--        d'entrée, distinct de `country`, jamais deviné) ; spec
--        conventions-catalographiques §3.1 et §7.1 ; demande de Xavier du 27/09
--        (« on traite ces limites » : name_lang au formulaire).
--
-- `authors.name_lang` existe depuis le 21/08 (21 fiches renseignées) mais aucun
-- chemin de saisie ne l'écrivait : ni les brouillons, ni la publication. Trois
-- endroits, comme pour writing_language le 26/09 :
--   * `author_drafts.name_lang` (même contrainte que la table des autorités) ;
--   * `publish_author_draft` la recopie vers `authors` (insertion ET mise à jour) ;
--   * `create_author_draft_from_author` la recopie vers le brouillon.
-- Les deux fonctions sont DÉRIVÉES du texte de la migration B29
-- (20260927160000), vérifié identique à la production (md5 du corps) le 27/09,
-- par remplacements comptés : seule la colonne est ajoutée aux listes.
-- Horodatage postérieur à B29, sans quoi un rejeu depuis zéro la ferait passer
-- avant et B29 écraserait les fonctions sans la colonne.
--
-- Avant de publier un brouillon ouvert né AVANT cette migration, sa langue du
-- nom serait NULL et effacerait celle de l'autorité : on la recopie ici dans
-- les brouillons ouverts qui reprennent une autorité.
-- =========================================================================

BEGIN;

ALTER TABLE public.author_drafts
  ADD COLUMN IF NOT EXISTS name_lang text
  CONSTRAINT author_drafts_name_lang_bcp47_chk CHECK (name_lang IS NULL OR name_lang ~ '^[a-z]{2}(-[A-Z]{2})?$');
COMMENT ON COLUMN public.author_drafts.name_lang IS
  'Langue de la forme du nom (BCP-47, CONV-6), recopiée vers authors.name_lang par publish_author_draft. Pilote la découpe du point d''accès (src/lib/nameEntry.js).';

UPDATE public.author_drafts d
   SET name_lang = a.name_lang
  FROM public.authors a
 WHERE d.published_author_id = a.id
   AND d.name_lang IS NULL
   AND a.name_lang IS NOT NULL
   AND d.status NOT IN ('published', 'cancelled');

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
  -- #79 RBAC : publication reservee au staff de catalogage (librarian/coordenador).
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  select * into v_draft
  from public.author_drafts
  where id = p_draft_id;

  if not found then
    raise exception 'Rascunho de autor nao encontrado: %', p_draft_id;
  end if;
  -- B29 (CAT-E18 2) : un brouillon d'autorité se lit partout, mais ne s'écrit
  -- (ni ne se publie) que par qui l'a créé, ou par l'administration du réseau.
  if not coalesce(public.fn_caller_can_edit_author_draft(p_draft_id), false) then
    raise exception 'Rascunho de autoridade de outra pessoa.' using hint = 'error.catalog.author_draft_creator_only';
  end if;

  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de autor foi descartado.';
  end if;

  if v_draft.published_author_id is null then
    insert into public.authors (
      preferred_name, sort_name, biography, birth_year, death_year, country,
      source_kind, source_label, source_url, viaf_id, isni, wikidata_id,
      variant_forms, photo_object_path, notes, structured_meta, writing_language, name_lang,
      created_by, updated_by, updated_at
    )
    values (
      v_draft.preferred_name, v_draft.sort_name, v_draft.biography,
      v_draft.birth_year, v_draft.death_year, v_draft.country,
      v_draft.source_kind, v_draft.source_label, v_draft.source_url,
      v_draft.viaf_id, v_draft.isni, v_draft.wikidata_id,
      v_draft.variant_forms, v_draft.photo_object_path, v_draft.notes,
      coalesce(v_draft.structured_meta, '{}'::jsonb), v_draft.writing_language, v_draft.name_lang,
      coalesce(v_draft.created_by, auth.uid()),
      coalesce(v_draft.updated_by, auth.uid()), now()
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
      structured_meta = coalesce(v_draft.structured_meta, '{}'::jsonb),
      writing_language = v_draft.writing_language,
      name_lang = v_draft.name_lang,
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

CREATE OR REPLACE FUNCTION public.create_author_draft_from_author(p_author_id bigint, p_batch_id bigint DEFAULT NULL::bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id bigint;
begin
  -- B29 : reprendre une autorité est un geste de catalogage (staff actif, ou
  -- administration du réseau) ; le brouillon est à qui l'a repris.
  if not (public.fn_caller_is_network_admin()
          or cardinality(public.fn_caller_staff_library_ids()) > 0) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using hint = 'error.catalog.staff_only';
  end if;
  if p_batch_id is not null and not public.fn_caller_owns_batch(p_batch_id) then
    raise exception 'Lote com rascunhos de outras bibliotecas.' using hint = 'error.batch.other_libraries';
  end if;
  insert into public.author_drafts (
    published_author_id, batch_id, action, status,
    preferred_name, sort_name, biography, birth_year, death_year, country,
    source_kind, source_label, source_url, viaf_id, isni, wikidata_id,
    variant_forms, photo_object_path, notes, structured_meta, writing_language, name_lang,
    created_by, updated_by
  )
  select
    a.id, p_batch_id, 'update', 'draft',
    a.preferred_name, a.sort_name, a.biography, a.birth_year, a.death_year, a.country,
    a.source_kind, a.source_label, a.source_url, a.viaf_id, a.isni, a.wikidata_id,
    a.variant_forms, a.photo_object_path, a.notes,
    coalesce(a.structured_meta, '{}'::jsonb), a.writing_language, a.name_lang,
    auth.uid(), auth.uid()
  from public.authors a
  where a.id = p_author_id
  returning id into v_id;

  if v_id is null then
    raise exception 'Autor nao encontrado: %', p_author_id;
  end if;

  return v_id;
end;
$function$;

DO $$
BEGIN
  IF (SELECT prosrc FROM pg_proc WHERE oid = 'public.publish_author_draft(bigint)'::regprocedure) !~ 'name_lang = v_draft\.name_lang'
     OR (SELECT prosrc FROM pg_proc WHERE oid = 'public.create_author_draft_from_author(bigint, bigint)'::regprocedure) !~ 'a\.name_lang' THEN
    RAISE EXCEPTION 'CONV-6 : name_lang absente des fonctions de recopie';
  END IF;
  IF EXISTS (SELECT 1 FROM public.author_drafts d JOIN public.authors a ON a.id = d.published_author_id
              WHERE d.status NOT IN ('published', 'cancelled') AND a.name_lang IS NOT NULL
                AND d.name_lang IS DISTINCT FROM a.name_lang) THEN
    RAISE EXCEPTION 'CONV-6 : un brouillon ouvert effacerait la langue du nom de son autorité';
  END IF;
END $$;

COMMIT;
