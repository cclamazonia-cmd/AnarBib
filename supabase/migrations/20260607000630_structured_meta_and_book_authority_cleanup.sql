-- =========================================================================
-- structured_meta jsonb + retrait colonnes autorite niveau livre
-- =========================================================================
-- Date     : 2026-06-07 00:06 UTC (horodatage reel)
-- Session  : Catalogacao work completion
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- A) Ajoute `structured_meta jsonb` a `authors` et `author_drafts`.
--    Les metadonnees structurees (authorityType, activityPeriod,
--    affiliation, variantNames, pseudonyms, activityPlace, contextLinks,
--    acronym) sont actuellement encodees en JSON entre des marqueurs
--    texte dans la colonne `notes`. Cette migration :
--    1. Cree la colonne
--    2. Extrait le JSON des marqueurs dans structured_meta
--    3. Nettoie notes (retire les marqueurs)
--    4. Met a jour publish_author_draft pour propager structured_meta
--    5. Met a jour create_author_draft_from_author pour copier
--       structured_meta ET variant_forms (correction d'un trou existant)
--
-- B) Retire les colonnes viaf/isni/wikidata de books et book_drafts.
--    Ces identifiants d'autorite appartiennent au niveau auteur
--    (authors.viaf_id / isni / wikidata_id), pas au niveau livre.
--    Les colonnes etaient vides en production (0 lignes peuplees).
--    Met a jour publish_book_draft pour ne plus les referencer.
-- =========================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- PARTIE A : structured_meta sur authors / author_drafts
-- ═══════════════════════════════════════════════════════════════

-- 1. DDL
ALTER TABLE public.authors
  ADD COLUMN IF NOT EXISTS structured_meta jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.author_drafts
  ADD COLUMN IF NOT EXISTS structured_meta jsonb DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.authors.structured_meta
  IS 'Metadonnees structurees de l''autorite (authorityType, activityPeriod, affiliation, etc.). Remplace l''encodage JSON dans notes.';

-- 2. Population : extraire le JSON des marqueurs dans notes
-- Le JSON est sur une seule ligne (produit par JSON.stringify)
UPDATE public.authors
SET
  structured_meta = substring(notes from '---anarbib_author_meta---\n(.*)\n---end_anarbib_author_meta---')::jsonb,
  notes = trim(both E'\n' from regexp_replace(notes, E'\n?---anarbib_author_meta---\n.*\n---end_anarbib_author_meta---', ''))
WHERE notes LIKE '%anarbib_author_meta%';

UPDATE public.author_drafts
SET
  structured_meta = substring(notes from '---anarbib_author_meta---\n(.*)\n---end_anarbib_author_meta---')::jsonb,
  notes = trim(both E'\n' from regexp_replace(notes, E'\n?---anarbib_author_meta---\n.*\n---end_anarbib_author_meta---', ''))
WHERE notes LIKE '%anarbib_author_meta%';

-- 3. Initialiser les lignes sans meta a un objet vide
UPDATE public.authors SET structured_meta = '{}'::jsonb WHERE structured_meta IS NULL;
UPDATE public.author_drafts SET structured_meta = '{}'::jsonb WHERE structured_meta IS NULL;

-- 4. publish_author_draft — propage structured_meta
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
    raise exception 'Rascunho de autor nao encontrado: %', p_draft_id;
  end if;

  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de autor foi descartado.';
  end if;

  if v_draft.published_author_id is null then
    insert into public.authors (
      preferred_name, sort_name, biography, birth_year, death_year, country,
      source_kind, source_label, source_url, viaf_id, isni, wikidata_id,
      variant_forms, photo_object_path, notes, structured_meta,
      created_by, updated_by, updated_at
    )
    values (
      v_draft.preferred_name, v_draft.sort_name, v_draft.biography,
      v_draft.birth_year, v_draft.death_year, v_draft.country,
      v_draft.source_kind, v_draft.source_label, v_draft.source_url,
      v_draft.viaf_id, v_draft.isni, v_draft.wikidata_id,
      v_draft.variant_forms, v_draft.photo_object_path, v_draft.notes,
      coalesce(v_draft.structured_meta, '{}'::jsonb),
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

REVOKE EXECUTE ON FUNCTION public.publish_author_draft(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publish_author_draft(bigint) TO authenticated;

-- 5. create_author_draft_from_author — copie structured_meta + variant_forms
--    (variant_forms manquait dans la version originale)
CREATE OR REPLACE FUNCTION public.create_author_draft_from_author(p_author_id bigint, p_batch_id bigint DEFAULT NULL)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id bigint;
begin
  insert into public.author_drafts (
    published_author_id, batch_id, action, status,
    preferred_name, sort_name, biography, birth_year, death_year, country,
    source_kind, source_label, source_url, viaf_id, isni, wikidata_id,
    variant_forms, photo_object_path, notes, structured_meta,
    created_by, updated_by
  )
  select
    a.id, p_batch_id, 'update', 'draft',
    a.preferred_name, a.sort_name, a.biography, a.birth_year, a.death_year, a.country,
    a.source_kind, a.source_label, a.source_url, a.viaf_id, a.isni, a.wikidata_id,
    a.variant_forms, a.photo_object_path, a.notes,
    coalesce(a.structured_meta, '{}'::jsonb),
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

REVOKE EXECUTE ON FUNCTION public.create_author_draft_from_author(bigint, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_author_draft_from_author(bigint, bigint) TO authenticated;

-- ═══════════════════════════════════════════════════════════════
-- PARTIE B : retrait viaf/isni/wikidata de books / book_drafts
-- ═══════════════════════════════════════════════════════════════

-- 6. publish_book_draft — retirer viaf/isni/wikidata
CREATE OR REPLACE FUNCTION public.publish_book_draft(p_draft_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_draft public.book_drafts%rowtype;
  v_book_id bigint;
  v_isbn_norm text;
  v_existing_book_id bigint;
begin
  select * into v_draft
  from public.book_drafts
  where id = p_draft_id;

  if not found then
    raise exception 'Rascunho de livro nao encontrado: %', p_draft_id;
  end if;

  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de livro foi descartado.';
  end if;

  -- Garde doublon bib_ref (couvre INSERT et UPDATE)
  if v_draft.bib_ref is not null and v_draft.bib_ref <> '' then
    select b.id
      into v_existing_book_id
      from public.books b
     where b.bib_ref = v_draft.bib_ref
       and (v_draft.published_book_id is null or b.id <> v_draft.published_book_id)
     limit 1;
    if v_existing_book_id is not null then
      raise exception 'bib_ref_duplicado: %', v_existing_book_id
        using errcode = 'P0001',
              hint = format(
                'Ja existe uma ficha publicada com a mesma referencia bibliografica %s (ficha %s). Altere a bib_ref ou verifique a ficha existente.',
                v_draft.bib_ref, v_existing_book_id
              );
    end if;
    v_existing_book_id := null;
  end if;

  if v_draft.published_book_id is null then
    -- Garde doublon ISBN (P1.3a)
    v_isbn_norm := regexp_replace(upper(coalesce(v_draft.isbn, '')), '[^0-9X]', '', 'g');
    if v_isbn_norm <> '' then
      select b.id
        into v_existing_book_id
        from public.books b
       where regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g') = v_isbn_norm
       limit 1;
      if v_existing_book_id is not null then
        raise exception 'isbn_duplicado: %', v_existing_book_id
          using errcode = 'P0001',
                hint = format(
                  'Ja existe uma ficha publicada com o mesmo ISBN (ficha %s). Revise o ISBN ou adicione um exemplar a ficha existente.',
                  v_existing_book_id
                );
      end if;
    end if;

    insert into public.books (
      cdd, autor, titulo, ano, editora, bib_ref, loanable,
      subtitulo, edicao, local_publicacao, isbn, issn, idioma, paginas, notas,
      tipo_material, cover_object_path, marc_json, catalog_source,
      created_by, updated_by, updated_at, last_cataloged_at,
      titulo_periodico, volume, numero, fasciculo, data_edicao, periodicidade,
      colecao, acquisition_mode, acquisition_date,
      owner_library, holder_library,
      owner_library_id, holder_library_id,
      partner_source, source_record_id, source_record_url,
      import_format, import_method, provenance_note, mutualization_status, source_label,
      tract_campaign, emitter_org, approximate_date, diffusion_place,
      recto_verso, physical_format, print_technique, physical_state,
      audio_duration, audio_support, audio_format, audio_language,
      audio_participants, audio_recording_type,
      audiovisual_duration, audiovisual_support, audiovisual_language,
      audiovisual_director, audiovisual_participants, audiovisual_subtitles,
      audiovisual_access_note,
      digital_native_url, digital_native_access, digital_native_restriction,
      digital_native_usage, digital_native_file_note,
      dossier_scope, dossier_period, dossier_organizations, dossier_context,
      distribuidora, tese_university, tese_advisor,
      artigo_source, artigo_volume, artigo_issue, artigo_pages,
      relatorio_org, relatorio_recipient, relatorio_internal_notes,
      zine_print_run, zine_technique, zine_format,
      subjects
    )
    values (
      v_draft.cdd, v_draft.autor, v_draft.titulo, v_draft.ano, v_draft.editora,
      v_draft.bib_ref, coalesce(v_draft.loanable, true),
      v_draft.subtitulo, v_draft.edicao, v_draft.local_publicacao,
      v_draft.isbn, v_draft.issn, v_draft.idioma, v_draft.paginas, v_draft.notas,
      v_draft.tipo_material, v_draft.cover_object_path,
      coalesce(v_draft.marc_json, '{}'::jsonb), 'catalogacao',
      coalesce(v_draft.created_by, auth.uid()), coalesce(v_draft.updated_by, auth.uid()),
      now(), now(),
      v_draft.titulo_periodico, v_draft.volume, v_draft.numero, v_draft.fasciculo,
      v_draft.data_edicao, v_draft.periodicidade,
      v_draft.colecao, v_draft.acquisition_mode, v_draft.acquisition_date,
      v_draft.owner_library, v_draft.holder_library,
      v_draft.owner_library_id, v_draft.holder_library_id,
      v_draft.partner_source, v_draft.source_record_id, v_draft.source_record_url,
      v_draft.import_format, v_draft.import_method, v_draft.provenance_note,
      v_draft.mutualization_status, v_draft.source_label,
      v_draft.tract_campaign, v_draft.emitter_org, v_draft.approximate_date,
      v_draft.diffusion_place, v_draft.recto_verso, v_draft.physical_format,
      v_draft.print_technique, v_draft.physical_state,
      v_draft.audio_duration, v_draft.audio_support, v_draft.audio_format,
      v_draft.audio_language, v_draft.audio_participants, v_draft.audio_recording_type,
      v_draft.audiovisual_duration, v_draft.audiovisual_support, v_draft.audiovisual_language,
      v_draft.audiovisual_director, v_draft.audiovisual_participants,
      v_draft.audiovisual_subtitles, v_draft.audiovisual_access_note,
      v_draft.digital_native_url, v_draft.digital_native_access,
      v_draft.digital_native_restriction, v_draft.digital_native_usage,
      v_draft.digital_native_file_note,
      v_draft.dossier_scope, v_draft.dossier_period, v_draft.dossier_organizations,
      v_draft.dossier_context,
      v_draft.distribuidora, v_draft.tese_university, v_draft.tese_advisor,
      v_draft.artigo_source, v_draft.artigo_volume, v_draft.artigo_issue, v_draft.artigo_pages,
      v_draft.relatorio_org, v_draft.relatorio_recipient, v_draft.relatorio_internal_notes,
      v_draft.zine_print_run, v_draft.zine_technique, v_draft.zine_format,
      v_draft.subjects
    )
    returning id into v_book_id;
  else
    update public.books
    set
      cdd = v_draft.cdd, autor = v_draft.autor, titulo = v_draft.titulo,
      ano = v_draft.ano, editora = v_draft.editora, bib_ref = v_draft.bib_ref,
      loanable = coalesce(v_draft.loanable, true),
      subtitulo = v_draft.subtitulo, edicao = v_draft.edicao,
      local_publicacao = v_draft.local_publicacao,
      isbn = v_draft.isbn, issn = v_draft.issn, idioma = v_draft.idioma,
      paginas = v_draft.paginas, notas = v_draft.notas,
      tipo_material = v_draft.tipo_material,
      cover_object_path = v_draft.cover_object_path,
      marc_json = coalesce(v_draft.marc_json, '{}'::jsonb),
      updated_by = coalesce(v_draft.updated_by, auth.uid()),
      updated_at = now(), last_cataloged_at = now(),
      titulo_periodico = v_draft.titulo_periodico, volume = v_draft.volume,
      numero = v_draft.numero, fasciculo = v_draft.fasciculo,
      data_edicao = v_draft.data_edicao, periodicidade = v_draft.periodicidade,
      colecao = v_draft.colecao, acquisition_mode = v_draft.acquisition_mode,
      acquisition_date = v_draft.acquisition_date,
      owner_library = v_draft.owner_library, holder_library = v_draft.holder_library,
      owner_library_id = v_draft.owner_library_id,
      holder_library_id = v_draft.holder_library_id,
      partner_source = v_draft.partner_source,
      source_record_id = v_draft.source_record_id,
      source_record_url = v_draft.source_record_url,
      import_format = v_draft.import_format, import_method = v_draft.import_method,
      provenance_note = v_draft.provenance_note,
      mutualization_status = v_draft.mutualization_status,
      source_label = v_draft.source_label,
      tract_campaign = v_draft.tract_campaign, emitter_org = v_draft.emitter_org,
      approximate_date = v_draft.approximate_date,
      diffusion_place = v_draft.diffusion_place, recto_verso = v_draft.recto_verso,
      physical_format = v_draft.physical_format,
      print_technique = v_draft.print_technique, physical_state = v_draft.physical_state,
      audio_duration = v_draft.audio_duration, audio_support = v_draft.audio_support,
      audio_format = v_draft.audio_format, audio_language = v_draft.audio_language,
      audio_participants = v_draft.audio_participants,
      audio_recording_type = v_draft.audio_recording_type,
      audiovisual_duration = v_draft.audiovisual_duration,
      audiovisual_support = v_draft.audiovisual_support,
      audiovisual_language = v_draft.audiovisual_language,
      audiovisual_director = v_draft.audiovisual_director,
      audiovisual_participants = v_draft.audiovisual_participants,
      audiovisual_subtitles = v_draft.audiovisual_subtitles,
      audiovisual_access_note = v_draft.audiovisual_access_note,
      digital_native_url = v_draft.digital_native_url,
      digital_native_access = v_draft.digital_native_access,
      digital_native_restriction = v_draft.digital_native_restriction,
      digital_native_usage = v_draft.digital_native_usage,
      digital_native_file_note = v_draft.digital_native_file_note,
      dossier_scope = v_draft.dossier_scope, dossier_period = v_draft.dossier_period,
      dossier_organizations = v_draft.dossier_organizations,
      dossier_context = v_draft.dossier_context,
      distribuidora = v_draft.distribuidora,
      tese_university = v_draft.tese_university, tese_advisor = v_draft.tese_advisor,
      artigo_source = v_draft.artigo_source, artigo_volume = v_draft.artigo_volume,
      artigo_issue = v_draft.artigo_issue, artigo_pages = v_draft.artigo_pages,
      relatorio_org = v_draft.relatorio_org,
      relatorio_recipient = v_draft.relatorio_recipient,
      relatorio_internal_notes = v_draft.relatorio_internal_notes,
      zine_print_run = v_draft.zine_print_run, zine_technique = v_draft.zine_technique,
      zine_format = v_draft.zine_format,
      subjects = v_draft.subjects
    where id = v_draft.published_book_id
    returning id into v_book_id;
  end if;

  update public.book_drafts
  set
    published_book_id = v_book_id,
    status = 'published',
    updated_by = coalesce(v_draft.updated_by, auth.uid()),
    updated_at = now()
  where id = p_draft_id;

  perform public.publish_book_draft_digital_resources(p_draft_id, v_book_id);

  return v_book_id;
end;
$function$;

-- 7. Drop columns viaf/isni/wikidata de books et book_drafts
ALTER TABLE public.books
  DROP COLUMN IF EXISTS viaf,
  DROP COLUMN IF EXISTS isni,
  DROP COLUMN IF EXISTS wikidata;

ALTER TABLE public.book_drafts
  DROP COLUMN IF EXISTS viaf,
  DROP COLUMN IF EXISTS isni,
  DROP COLUMN IF EXISTS wikidata;

-- ═══════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════

DO $verif$
DECLARE
  v_def text;
  v_remaining_markers integer;
BEGIN
  -- A1: structured_meta doit exister sur authors
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'authors' AND column_name = 'structured_meta'
  ) THEN
    RAISE EXCEPTION 'VERIF: colonne structured_meta absente de authors';
  END IF;

  -- A2: Plus de marqueurs dans notes
  SELECT count(*) INTO v_remaining_markers
  FROM public.authors WHERE notes LIKE '%anarbib_author_meta%';
  IF v_remaining_markers > 0 THEN
    RAISE EXCEPTION 'VERIF: % auteurs ont encore des marqueurs dans notes', v_remaining_markers;
  END IF;

  SELECT count(*) INTO v_remaining_markers
  FROM public.author_drafts WHERE notes LIKE '%anarbib_author_meta%';
  IF v_remaining_markers > 0 THEN
    RAISE EXCEPTION 'VERIF: % brouillons ont encore des marqueurs dans notes', v_remaining_markers;
  END IF;

  -- A3: publish_author_draft contient structured_meta
  SELECT pg_get_functiondef('public.publish_author_draft(bigint)'::regprocedure) INTO v_def;
  IF position('structured_meta' IN v_def) = 0 THEN
    RAISE EXCEPTION 'VERIF: structured_meta absent de publish_author_draft';
  END IF;

  -- A4: create_author_draft_from_author contient structured_meta ET variant_forms
  SELECT pg_get_functiondef('public.create_author_draft_from_author(bigint,bigint)'::regprocedure) INTO v_def;
  IF position('structured_meta' IN v_def) = 0 THEN
    RAISE EXCEPTION 'VERIF: structured_meta absent de create_author_draft_from_author';
  END IF;
  IF position('variant_forms' IN v_def) = 0 THEN
    RAISE EXCEPTION 'VERIF: variant_forms absent de create_author_draft_from_author (regression)';
  END IF;

  -- B1: colonnes viaf/isni/wikidata absentes de books
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'books' AND column_name = 'viaf'
  ) THEN
    RAISE EXCEPTION 'VERIF: colonne viaf encore presente sur books';
  END IF;

  -- B2: publish_book_draft ne reference plus viaf (mais garde ses gardes)
  SELECT pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure) INTO v_def;
  -- viaf ne doit plus etre dans la liste INSERT/UPDATE...
  -- mais 'viaf' peut apparaitre dans un commentaire, donc on verifie
  -- qu'il n'apparait PAS dans le corps VALUES/SET
  IF position('v_draft.viaf' IN v_def) > 0 THEN
    RAISE EXCEPTION 'VERIF: publish_book_draft reference encore v_draft.viaf';
  END IF;

  -- B3: gardes bib_ref/isbn toujours presentes (non-regression)
  IF position('bib_ref_duplicado' IN v_def) = 0 THEN
    RAISE EXCEPTION 'VERIF: garde bib_ref_duplicado absente (regression)';
  END IF;
  IF position('isbn_duplicado' IN v_def) = 0 THEN
    RAISE EXCEPTION 'VERIF: garde isbn_duplicado absente (regression)';
  END IF;
  IF position('owner_library_id' IN v_def) = 0 THEN
    RAISE EXCEPTION 'VERIF: owner_library_id absent (regression)';
  END IF;
END
$verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;
