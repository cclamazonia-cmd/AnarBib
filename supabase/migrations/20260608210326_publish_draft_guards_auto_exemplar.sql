-- =========================================================================
-- publish_book_draft — gardes obligatoires + auto-exemplaire
-- =========================================================================
-- Date     : 2026-06-08 21:03 UTC (horodatage réel)
-- Session  : BTL cleanup (suite)
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- Trois problèmes critiques :
--   1. Un brouillon pouvait être publié SANS bib_ref → livre invisible
--      (pas d'exemplaire, pas dans l'OPAC).
--   2. Un brouillon pouvait être publié avec un tipo_material invalide →
--      violation du CHECK constraint brut (message Postgres en anglais).
--   3. Un brouillon publié ne créait AUCUN exemplaire → le livre existait
--      dans `books` mais n'apparaissait pas dans le catalogue public.
--
-- CORRECTIFS :
--   A. Garde bib_ref obligatoire : RAISE EXCEPTION si bib_ref vide/NULL.
--   B. Garde tipo_material explicite : RAISE EXCEPTION intelligible AVANT
--      le INSERT, plutôt que laisser le CHECK constraint Postgres brut.
--   C. Garde titulo obligatoire : empêcher les fiches sans titre.
--   D. Auto-création holding + exemplaire après INSERT (création seule,
--      pas mise à jour). L'exemplaire prend :
--        - bib_ref = celle du brouillon
--        - tombo = bib_ref (par convention, identique)
--        - library_id = owner_library_id du brouillon
--        - circulation_policy = déduit de loanable
--        - visibility = 'public'
--   E. Recalcul des compteurs de disponibilité du holding.
--
-- Toutes les gardes utilisent la convention HINT i18n pour des messages
-- localisés côté frontend.
--
-- Signature inchangée, ACL préservées (CREATE OR REPLACE).
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
  v_holding_id bigint;
  v_library_id uuid;
  v_circ_policy text;
  v_valid_types text[] := ARRAY[
    'livro','periodico','tract','cartaz','audio','audiovisual',
    'recurso_digital','dossie','tese','artigo','relatorio','zine'
  ];
begin
  select * into v_draft
  from public.book_drafts
  where id = p_draft_id;

  if not found then
    raise exception 'rascunho_nao_encontrado'
      using hint = 'error.publish.draft_not_found';
  end if;

  if v_draft.status = 'cancelled' then
    raise exception 'rascunho_descartado'
      using hint = 'error.publish.draft_cancelled';
  end if;

  -- ═══════════════════════════════════════════════════════════════════════
  -- GARDES OBLIGATOIRES (Chantier B — P0)
  -- ═══════════════════════════════════════════════════════════════════════

  -- Garde A : titre obligatoire
  if v_draft.titulo is null or btrim(v_draft.titulo) = '' then
    raise exception 'titulo_obrigatorio'
      using hint = 'error.publish.titulo_required';
  end if;

  -- Garde B : bib_ref obligatoire
  if v_draft.bib_ref is null or btrim(v_draft.bib_ref) = '' then
    raise exception 'bib_ref_obrigatoria'
      using hint = 'error.publish.bib_ref_required';
  end if;

  -- Garde C : tipo_material obligatoire ET valide
  if v_draft.tipo_material is null or btrim(v_draft.tipo_material) = '' then
    raise exception 'tipo_material_obrigatorio'
      using hint = 'error.publish.tipo_material_required';
  end if;

  if lower(v_draft.tipo_material) <> ALL(v_valid_types) then
    raise exception 'tipo_material_invalido'
      using hint = 'error.publish.tipo_material_invalid';
  end if;

  -- ═══════════════════════════════════════════════════════════════════════
  -- GARDES DOUBLON (existantes — ISBN + bib_ref)
  -- ═══════════════════════════════════════════════════════════════════════

  -- Garde doublon bib_ref
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

  if v_draft.published_book_id is null then
    -- Garde doublon ISBN (création uniquement)
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

    -- ═════════════════════════════════════════════════════════════════════
    -- INSERT NOUVELLE FICHE (création)
    -- ═════════════════════════════════════════════════════════════════════
    insert into public.books (
      cdd, autor, titulo, ano, editora, bib_ref, loanable,
      subtitulo, edicao, local_publicacao, isbn, issn, idioma, paginas,
      notas, tipo_material, cover_object_path, marc_json, catalog_source,
      created_by, updated_by, updated_at, last_cataloged_at,
      titulo_periodico, volume, numero, fasciculo, data_edicao,
      periodicidade, colecao, acquisition_mode, acquisition_date,
      owner_library, holder_library, partner_source, source_record_id,
      source_record_url, import_format, import_method, provenance_note,
      mutualization_status, source_label,
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
      subjects, viaf, isni, wikidata
    )
    values (
      v_draft.cdd, v_draft.autor, v_draft.titulo, v_draft.ano,
      v_draft.editora, v_draft.bib_ref, coalesce(v_draft.loanable, true),
      v_draft.subtitulo, v_draft.edicao, v_draft.local_publicacao,
      v_draft.isbn, v_draft.issn, v_draft.idioma, v_draft.paginas,
      v_draft.notas, v_draft.tipo_material, v_draft.cover_object_path,
      coalesce(v_draft.marc_json, '{}'::jsonb), 'catalogacao',
      coalesce(v_draft.created_by, auth.uid()),
      coalesce(v_draft.updated_by, auth.uid()), now(), now(),
      v_draft.titulo_periodico, v_draft.volume, v_draft.numero,
      v_draft.fasciculo, v_draft.data_edicao, v_draft.periodicidade,
      v_draft.colecao, v_draft.acquisition_mode, v_draft.acquisition_date,
      v_draft.owner_library, v_draft.holder_library, v_draft.partner_source,
      v_draft.source_record_id, v_draft.source_record_url,
      v_draft.import_format, v_draft.import_method, v_draft.provenance_note,
      v_draft.mutualization_status, v_draft.source_label,
      v_draft.tract_campaign, v_draft.emitter_org, v_draft.approximate_date,
      v_draft.diffusion_place, v_draft.recto_verso, v_draft.physical_format,
      v_draft.print_technique, v_draft.physical_state,
      v_draft.audio_duration, v_draft.audio_support, v_draft.audio_format,
      v_draft.audio_language, v_draft.audio_participants,
      v_draft.audio_recording_type,
      v_draft.audiovisual_duration, v_draft.audiovisual_support,
      v_draft.audiovisual_language, v_draft.audiovisual_director,
      v_draft.audiovisual_participants, v_draft.audiovisual_subtitles,
      v_draft.audiovisual_access_note,
      v_draft.digital_native_url, v_draft.digital_native_access,
      v_draft.digital_native_restriction, v_draft.digital_native_usage,
      v_draft.digital_native_file_note,
      v_draft.dossier_scope, v_draft.dossier_period,
      v_draft.dossier_organizations, v_draft.dossier_context,
      v_draft.distribuidora, v_draft.tese_university, v_draft.tese_advisor,
      v_draft.artigo_source, v_draft.artigo_volume, v_draft.artigo_issue,
      v_draft.artigo_pages, v_draft.relatorio_org, v_draft.relatorio_recipient,
      v_draft.relatorio_internal_notes,
      v_draft.zine_print_run, v_draft.zine_technique, v_draft.zine_format,
      v_draft.subjects, v_draft.viaf, v_draft.isni, v_draft.wikidata
    )
    returning id into v_book_id;

    -- ═════════════════════════════════════════════════════════════════════
    -- AUTO-EXEMPLAIRE (Chantier A — nouveau livre uniquement)
    -- ═════════════════════════════════════════════════════════════════════
    -- Résolution de la bibliothèque propriétaire
    v_library_id := v_draft.owner_library_id;
    if v_library_id is null then
      -- Fallback : bibliothèque principale de l'usager
      select ulm.library_id into v_library_id
        from public.user_library_memberships ulm
       where ulm.user_id = coalesce(v_draft.created_by, auth.uid())
       order by ulm.role desc   -- coordenador > bibliotecario > leitor
       limit 1;
    end if;

    if v_library_id is not null then
      -- Politique de circulation déduite
      v_circ_policy := case
        when coalesce(v_draft.loanable, true) then 'emprestavel'
        else 'consulta'
      end;

      -- get-or-create du holding (book ↔ library)
      insert into public.book_holdings (book_id, library_id)
      values (v_book_id, v_library_id)
      on conflict (book_id, library_id) do update
        set updated_at = now()
      returning id into v_holding_id;

      -- Création de l'exemplaire par défaut
      insert into public.exemplares (
        bib_ref, tombo, library_id, holding_id,
        circulation_policy, visibility
      )
      values (
        v_draft.bib_ref,
        v_draft.bib_ref,         -- tombo = bib_ref par convention
        v_library_id,
        v_holding_id,
        v_circ_policy,
        'public'
      );

      -- Recalcul des compteurs de disponibilité
      perform public.fn_v2_recompute_holdings_availability(
        p_holding_ids := ARRAY[v_holding_id]
      );
    end if;

  else
    -- ═════════════════════════════════════════════════════════════════════
    -- UPDATE FICHE EXISTANTE (édition / re-publication)
    -- ═════════════════════════════════════════════════════════════════════
    update public.books
    set
      cdd = v_draft.cdd, autor = v_draft.autor, titulo = v_draft.titulo,
      ano = v_draft.ano, editora = v_draft.editora,
      bib_ref = v_draft.bib_ref,
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
      titulo_periodico = v_draft.titulo_periodico,
      volume = v_draft.volume, numero = v_draft.numero,
      fasciculo = v_draft.fasciculo, data_edicao = v_draft.data_edicao,
      periodicidade = v_draft.periodicidade, colecao = v_draft.colecao,
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
      viaf = v_draft.viaf, isni = v_draft.isni, wikidata = v_draft.wikidata
    where id = v_draft.published_book_id
    returning id into v_book_id;
  end if;

  -- Mise à jour du statut du brouillon
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

-- Vérifications de non-régression
DO $verif$
BEGIN
  -- Gardes obligatoires (nouveaux)
  IF position('titulo_obrigatorio' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: garde titulo_obrigatorio absente';
  END IF;
  IF position('bib_ref_obrigatoria' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: garde bib_ref_obrigatoria absente';
  END IF;
  IF position('tipo_material_obrigatorio' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: garde tipo_material_obrigatorio absente';
  END IF;
  -- Gardes doublon (existantes)
  IF position('bib_ref_duplicado' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: garde bib_ref_duplicado absente';
  END IF;
  IF position('isbn_duplicado' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: garde isbn_duplicado absente';
  END IF;
  -- Auto-exemplaire
  IF position('fn_v2_recompute_holdings_availability' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: auto-exemplaire / recompute absente';
  END IF;
  -- Colonnes consolidées (régression)
  IF position('wikidata' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: wikidata absente (regression)';
  END IF;
END
$verif$;
