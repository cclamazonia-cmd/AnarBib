-- =========================================================================
-- publish_book_draft — garde doublon bib_ref
-- =========================================================================
-- Date     : 2026-06-06 23:25 UTC (horodatage reel)
-- Session  : Catalogacao work completion
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- Deux catalogueur-euse-s en parallele peuvent recevoir la meme suggestion
-- de next_bib_ref (max+1 sans verrou). Le second a publier obtient une
-- violation de contrainte unique brute ("duplicate key value violates
-- unique constraint books_bib_ref_unique") — inintelligible.
--
-- Ce script ajoute une garde explicite (meme patron que isbn_duplicado)
-- AVANT l'INSERT/UPDATE : si une fiche publiee porte deja la meme
-- bib_ref, l'erreur 'bib_ref_duplicado: <id>' est levee avec un hint
-- comprehensible. Le frontend mappe ce code vers un message i18n clair.
--
-- La garde couvre les deux chemins (creation et re-publication/mise a jour)
-- en excluant le livre lui-meme quand published_book_id est non null.
--
-- Signature inchangee, ACL preservees (CREATE OR REPLACE).
-- =========================================================================

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
      cdd,
      autor,
      titulo,
      ano,
      editora,
      bib_ref,
      loanable,
      subtitulo,
      edicao,
      local_publicacao,
      isbn,
      issn,
      idioma,
      paginas,
      notas,
      tipo_material,
      cover_object_path,
      marc_json,
      catalog_source,
      created_by,
      updated_by,
      updated_at,
      last_cataloged_at,
      titulo_periodico,
      volume,
      numero,
      fasciculo,
      data_edicao,
      periodicidade,
      colecao,
      acquisition_mode,
      acquisition_date,
      owner_library,
      holder_library,
      partner_source,
      source_record_id,
      source_record_url,
      import_format,
      import_method,
      provenance_note,
      mutualization_status,
      source_label,
      tract_campaign,
      emitter_org,
      approximate_date,
      diffusion_place,
      recto_verso,
      physical_format,
      print_technique,
      physical_state,
      audio_duration,
      audio_support,
      audio_format,
      audio_language,
      audio_participants,
      audio_recording_type,
      audiovisual_duration,
      audiovisual_support,
      audiovisual_language,
      audiovisual_director,
      audiovisual_participants,
      audiovisual_subtitles,
      audiovisual_access_note,
      digital_native_url,
      digital_native_access,
      digital_native_restriction,
      digital_native_usage,
      digital_native_file_note,
      dossier_scope,
      dossier_period,
      dossier_organizations,
      dossier_context,
      -- Colonnes consolidees (ex-trigger only)
      distribuidora,
      tese_university,
      tese_advisor,
      artigo_source,
      artigo_volume,
      artigo_issue,
      artigo_pages,
      relatorio_org,
      relatorio_recipient,
      relatorio_internal_notes,
      zine_print_run,
      zine_technique,
      zine_format,
      subjects,
      viaf,
      isni,
      wikidata
    )
    values (
      v_draft.cdd,
      v_draft.autor,
      v_draft.titulo,
      v_draft.ano,
      v_draft.editora,
      v_draft.bib_ref,
      coalesce(v_draft.loanable, true),
      v_draft.subtitulo,
      v_draft.edicao,
      v_draft.local_publicacao,
      v_draft.isbn,
      v_draft.issn,
      v_draft.idioma,
      v_draft.paginas,
      v_draft.notas,
      v_draft.tipo_material,
      v_draft.cover_object_path,
      coalesce(v_draft.marc_json, '{}'::jsonb),
      'catalogacao',
      coalesce(v_draft.created_by, auth.uid()),
      coalesce(v_draft.updated_by, auth.uid()),
      now(),
      now(),
      v_draft.titulo_periodico,
      v_draft.volume,
      v_draft.numero,
      v_draft.fasciculo,
      v_draft.data_edicao,
      v_draft.periodicidade,
      v_draft.colecao,
      v_draft.acquisition_mode,
      v_draft.acquisition_date,
      v_draft.owner_library,
      v_draft.holder_library,
      v_draft.partner_source,
      v_draft.source_record_id,
      v_draft.source_record_url,
      v_draft.import_format,
      v_draft.import_method,
      v_draft.provenance_note,
      v_draft.mutualization_status,
      v_draft.source_label,
      v_draft.tract_campaign,
      v_draft.emitter_org,
      v_draft.approximate_date,
      v_draft.diffusion_place,
      v_draft.recto_verso,
      v_draft.physical_format,
      v_draft.print_technique,
      v_draft.physical_state,
      v_draft.audio_duration,
      v_draft.audio_support,
      v_draft.audio_format,
      v_draft.audio_language,
      v_draft.audio_participants,
      v_draft.audio_recording_type,
      v_draft.audiovisual_duration,
      v_draft.audiovisual_support,
      v_draft.audiovisual_language,
      v_draft.audiovisual_director,
      v_draft.audiovisual_participants,
      v_draft.audiovisual_subtitles,
      v_draft.audiovisual_access_note,
      v_draft.digital_native_url,
      v_draft.digital_native_access,
      v_draft.digital_native_restriction,
      v_draft.digital_native_usage,
      v_draft.digital_native_file_note,
      v_draft.dossier_scope,
      v_draft.dossier_period,
      v_draft.dossier_organizations,
      v_draft.dossier_context,
      -- Colonnes consolidees
      v_draft.distribuidora,
      v_draft.tese_university,
      v_draft.tese_advisor,
      v_draft.artigo_source,
      v_draft.artigo_volume,
      v_draft.artigo_issue,
      v_draft.artigo_pages,
      v_draft.relatorio_org,
      v_draft.relatorio_recipient,
      v_draft.relatorio_internal_notes,
      v_draft.zine_print_run,
      v_draft.zine_technique,
      v_draft.zine_format,
      v_draft.subjects,
      v_draft.viaf,
      v_draft.isni,
      v_draft.wikidata
    )
    returning id into v_book_id;
  else
    update public.books
    set
      cdd = v_draft.cdd,
      autor = v_draft.autor,
      titulo = v_draft.titulo,
      ano = v_draft.ano,
      editora = v_draft.editora,
      bib_ref = v_draft.bib_ref,
      loanable = coalesce(v_draft.loanable, true),
      subtitulo = v_draft.subtitulo,
      edicao = v_draft.edicao,
      local_publicacao = v_draft.local_publicacao,
      isbn = v_draft.isbn,
      issn = v_draft.issn,
      idioma = v_draft.idioma,
      paginas = v_draft.paginas,
      notas = v_draft.notas,
      tipo_material = v_draft.tipo_material,
      cover_object_path = v_draft.cover_object_path,
      marc_json = coalesce(v_draft.marc_json, '{}'::jsonb),
      updated_by = coalesce(v_draft.updated_by, auth.uid()),
      updated_at = now(),
      last_cataloged_at = now(),
      titulo_periodico = v_draft.titulo_periodico,
      volume = v_draft.volume,
      numero = v_draft.numero,
      fasciculo = v_draft.fasciculo,
      data_edicao = v_draft.data_edicao,
      periodicidade = v_draft.periodicidade,
      colecao = v_draft.colecao,
      acquisition_mode = v_draft.acquisition_mode,
      acquisition_date = v_draft.acquisition_date,
      owner_library = v_draft.owner_library,
      holder_library = v_draft.holder_library,
      partner_source = v_draft.partner_source,
      source_record_id = v_draft.source_record_id,
      source_record_url = v_draft.source_record_url,
      import_format = v_draft.import_format,
      import_method = v_draft.import_method,
      provenance_note = v_draft.provenance_note,
      mutualization_status = v_draft.mutualization_status,
      source_label = v_draft.source_label,
      tract_campaign = v_draft.tract_campaign,
      emitter_org = v_draft.emitter_org,
      approximate_date = v_draft.approximate_date,
      diffusion_place = v_draft.diffusion_place,
      recto_verso = v_draft.recto_verso,
      physical_format = v_draft.physical_format,
      print_technique = v_draft.print_technique,
      physical_state = v_draft.physical_state,
      audio_duration = v_draft.audio_duration,
      audio_support = v_draft.audio_support,
      audio_format = v_draft.audio_format,
      audio_language = v_draft.audio_language,
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
      dossier_scope = v_draft.dossier_scope,
      dossier_period = v_draft.dossier_period,
      dossier_organizations = v_draft.dossier_organizations,
      dossier_context = v_draft.dossier_context,
      -- Colonnes consolidees (ex-trigger only)
      distribuidora = v_draft.distribuidora,
      tese_university = v_draft.tese_university,
      tese_advisor = v_draft.tese_advisor,
      artigo_source = v_draft.artigo_source,
      artigo_volume = v_draft.artigo_volume,
      artigo_issue = v_draft.artigo_issue,
      artigo_pages = v_draft.artigo_pages,
      relatorio_org = v_draft.relatorio_org,
      relatorio_recipient = v_draft.relatorio_recipient,
      relatorio_internal_notes = v_draft.relatorio_internal_notes,
      zine_print_run = v_draft.zine_print_run,
      zine_technique = v_draft.zine_technique,
      zine_format = v_draft.zine_format,
      subjects = v_draft.subjects,
      viaf = v_draft.viaf,
      isni = v_draft.isni,
      wikidata = v_draft.wikidata
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

-- Verification : gardes + colonnes consolidees
DO $verif$
BEGIN
  IF position('bib_ref_duplicado' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: garde bib_ref_duplicado absente de publish_book_draft';
  END IF;
  IF position('isbn_duplicado' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: garde isbn_duplicado absente (regression P1.3a)';
  END IF;
  IF position('distribuidora' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: distribuidora absente de publish_book_draft';
  END IF;
  IF position('wikidata' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: wikidata absente de publish_book_draft';
  END IF;
END
$verif$;
