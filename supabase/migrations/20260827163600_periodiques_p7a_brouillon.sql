-- =========================================================================
-- Paquet PÉRIODIQUES P7a — Le brouillon de catalogage porte le titre de revue
-- =========================================================================
-- Date     : 2026-08-27
-- Chantier : périodiques (spec-periodiques v0.1, §11 paquet P7)
-- Auteur   : Xavier (arbitrages) + Claude (rédaction)
--
-- POURQUOI CE PAQUET EXISTE, ALORS QUE LA SPEC N'EN PARLE PAS. La spec §11
-- annonce en P7 « UI catalogage : sélecteur de titre, création à la volée,
-- liste des numéros ». Elle suppose que le lien peut être posé pendant le
-- catalogage. Or le catalogage travaille sur public.book_drafts, qui ne porte
-- PAS serial_id : le sélecteur n'aurait eu nulle part où écrire.
--
-- Deux façons de contourner, toutes deux mauvaises :
--   · faire poser le lien par l'interface APRÈS la publication, en deux appels
--     — si le second échoue, le fascicule est publié détaché, et rien ne le
--     signale ;
--   · créer une seconde voie de publication qui prend le titre en paramètre —
--     deux chemins de publication à tenir à jour, c'est ainsi qu'ils divergent.
-- La bonne réponse est celle que le reste du modèle applique déjà à
-- titulo_periodico, volume, numero, fasciculo : le brouillon porte le champ, et
-- la publication le recopie. C'est ce que fait ce paquet.
--
-- CE QU'IL CHANGE DANS publish_book_draft. Trois lignes, et rien d'autre : la
-- colonne dans la liste d'INSERT, la valeur en face, et l'affectation dans la
-- branche UPDATE (republication d'une fiche déjà publiée — sans elle, corriger
-- un fascicule publié lui ferait PERDRE son titre). La fonction est reproduite
-- entière parce que Postgres l'exige, mais le patch a été appliqué par script
-- sur la définition en base, sur trois ancres uniques vérifiées — pas
-- retranscrit à la main.
--
-- GARDE G3 AUSSI SUR LE BROUILLON. Le trigger de P1 protège public.books. Sans
-- son équivalent ici, poser un titre de revue sur un brouillon de monographie
-- serait accepté à la saisie et refusé à la PUBLICATION — c'est-à-dire au pire
-- moment, après tout le travail, sur une erreur qui ne dit pas quoi corriger.
-- La garde doit tomber là où la faute se commet.
--
-- CHECKLIST DOCTRINE
--   [x] CREATE OR REPLACE : signature et type de retour INCHANGÉS
--   [x] SECURITY DEFINER + search_path conservés à l'identique
--   [x] Garde staff conservée à l'identique
--   [x] DO block de vérification structurelle
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Le brouillon porte le lien
-- -------------------------------------------------------------------------
ALTER TABLE public.book_drafts
  ADD COLUMN IF NOT EXISTS serial_id bigint
    REFERENCES public.serials(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS book_drafts_serial_id_idx
  ON public.book_drafts (serial_id) WHERE serial_id IS NOT NULL;

COMMENT ON COLUMN public.book_drafts.serial_id IS
  'Titre de périodique en forme d''autorité, choisi pendant le catalogage. '
  'Recopié tel quel dans books.serial_id à la publication, comme '
  'titulo_periodico / volume / numero / fasciculo. NULL pour tout ce qui n''est '
  'pas un fascicule. Ajouté par le paquet PÉRIODIQUES P7a du 27/08/2026.';

-- -------------------------------------------------------------------------
-- 2. Garde G3 au point de saisie
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_book_drafts_serial_id_requires_periodico()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NEW.serial_id IS NOT NULL
     AND coalesce(NEW.tipo_material, '') NOT IN ('periodico','artigo') THEN
    RAISE EXCEPTION
      'Un titre de périodique ne peut être rattaché qu''à un fascicule ou un article (tipo_material=%).',
      coalesce(NEW.tipo_material, '∅')
      USING ERRCODE = 'P0001', HINT = 'error.serial.attach.wrongMaterial';
  END IF;
  RETURN NEW;
END $function$;

COMMENT ON FUNCTION public.fn_book_drafts_serial_id_requires_periodico() IS
  'Garde G3 portée jusqu''au BROUILLON : sans elle, l''erreur ne tomberait qu''à '
  'la publication, après tout le travail de saisie. Une garde doit tomber là où '
  'la faute se commet. Paquet PÉRIODIQUES P7a.';

DROP TRIGGER IF EXISTS book_drafts_serial_id_requires_periodico ON public.book_drafts;
CREATE TRIGGER book_drafts_serial_id_requires_periodico
  BEFORE INSERT OR UPDATE OF serial_id, tipo_material ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.fn_book_drafts_serial_id_requires_periodico();

-- -------------------------------------------------------------------------
-- 3. La publication recopie le lien
-- -------------------------------------------------------------------------
-- Reproduite entière (Postgres l'exige) mais patchée par script : seules les
-- trois lignes marquées « #périodiques P7 » diffèrent de la version du
-- 17/08/2026.
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
  v_auto_tombo text;                         -- #tombo-serie (17/06)
  v_copies int;                              -- #copies (17/08) : nb d'exemplaires initiaux
  v_i int;
  v_valid_types text[] := ARRAY[
    'livro','periodico','tract','cartaz','audio','audiovisual',
    'recurso_digital','dossie','tese','artigo','relatorio','zine'
  ];
begin
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  select * into v_draft from public.book_drafts where id = p_draft_id;
  if not found then
    raise exception 'rascunho_nao_encontrado' using hint = 'error.publish.draft_not_found';
  end if;
  if v_draft.status = 'cancelled' then
    raise exception 'rascunho_descartado' using hint = 'error.publish.draft_cancelled';
  end if;

  if v_draft.titulo is null or btrim(v_draft.titulo) = '' then
    raise exception 'titulo_obrigatorio' using hint = 'error.publish.titulo_required';
  end if;
  if v_draft.bib_ref is null or btrim(v_draft.bib_ref) = '' then
    raise exception 'bib_ref_obrigatoria' using hint = 'error.publish.bib_ref_required';
  end if;
  if v_draft.tipo_material is null or btrim(v_draft.tipo_material) = '' then
    raise exception 'tipo_material_obrigatorio' using hint = 'error.publish.tipo_material_required';
  end if;
  if lower(v_draft.tipo_material) <> ALL(v_valid_types) then
    raise exception 'tipo_material_invalido' using hint = 'error.publish.tipo_material_invalid';
  end if;

  select b.id into v_existing_book_id
    from public.books b
   where b.bib_ref = v_draft.bib_ref
     and (v_draft.published_book_id is null or b.id <> v_draft.published_book_id)
   limit 1;
  if v_existing_book_id is not null then
    raise exception 'bib_ref_duplicado: %', v_existing_book_id
      using errcode = 'P0001',
            hint = format('Ja existe uma ficha publicada com a mesma referencia bibliografica %s (ficha %s). Altere a bib_ref ou verifique a ficha existente.', v_draft.bib_ref, v_existing_book_id);
  end if;
  v_existing_book_id := null;

  if v_draft.published_book_id is null then
    v_isbn_norm := regexp_replace(upper(coalesce(v_draft.isbn, '')), '[^0-9X]', '', 'g');
    if v_isbn_norm <> '' then
      select b.id into v_existing_book_id
        from public.books b
       where regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g') = v_isbn_norm
       limit 1;
      if v_existing_book_id is not null then
        raise exception 'isbn_duplicado: %', v_existing_book_id
          using errcode = 'P0001',
                hint = format('Ja existe uma ficha publicada com o mesmo ISBN (ficha %s). Revise o ISBN ou adicione um exemplar a ficha existente.', v_existing_book_id);
      end if;
    end if;

    insert into public.books (
      work_id,
      cdd, autor, titulo, ano, editora, bib_ref, loanable,
      subtitulo, edicao, local_publicacao, isbn, issn, idioma, paginas,
      notas, tipo_material, cover_object_path, marc_json, catalog_source,
      created_by, updated_by, updated_at, last_cataloged_at,
      serial_id,                             -- #périodiques P7 (27/08)
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
      distribuidora, gravadora, tese_university, tese_advisor,
      artigo_source, artigo_volume, artigo_issue, artigo_pages,
      relatorio_org, relatorio_recipient, relatorio_internal_notes,
      zine_print_run, zine_technique, zine_format,
      subjects
    )
    values (
      v_draft.work_id,                       -- #œuvre (17/08) : NULL -> fn_books_ensure_work crée une œuvre neuve
      v_draft.cdd, v_draft.autor, v_draft.titulo, v_draft.ano,
      v_draft.editora, v_draft.bib_ref, coalesce(v_draft.loanable, true),
      v_draft.subtitulo, v_draft.edicao, v_draft.local_publicacao,
      v_draft.isbn, v_draft.issn, v_draft.idioma, v_draft.paginas,
      v_draft.notas, v_draft.tipo_material, v_draft.cover_object_path,
      coalesce(v_draft.marc_json, '{}'::jsonb), 'catalogacao',
      coalesce(v_draft.created_by, auth.uid()),
      coalesce(v_draft.updated_by, auth.uid()), now(), now(),
      v_draft.serial_id,                     -- #périodiques P7 (27/08)
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
      v_draft.distribuidora, v_draft.gravadora, v_draft.tese_university, v_draft.tese_advisor,
      v_draft.artigo_source, v_draft.artigo_volume, v_draft.artigo_issue,
      v_draft.artigo_pages, v_draft.relatorio_org, v_draft.relatorio_recipient,
      v_draft.relatorio_internal_notes,
      v_draft.zine_print_run, v_draft.zine_technique, v_draft.zine_format,
      v_draft.subjects
    )
    returning id into v_book_id;

    v_library_id := v_draft.owner_library_id;
    if v_library_id is null then
      select ulm.library_id into v_library_id
        from public.user_library_memberships ulm
       where ulm.user_id = coalesce(v_draft.created_by, auth.uid())
       order by ulm.role desc
       limit 1;
    end if;

    -- #biblio-choisie (17/08) : un·e admin réseau peut cibler explicitement la
    -- biblio des exemplaires initiaux. Pour le reste du staff, le champ est ignoré
    -- (garde-fou serveur, indépendant de l'UI).
    if v_draft.initial_copies_library_id is not null and public.fn_caller_is_network_admin() then
      v_library_id := v_draft.initial_copies_library_id;
    end if;

    if v_library_id is not null then
      v_circ_policy := case when coalesce(v_draft.loanable, true) then 'emprestavel' else 'consulta' end;
      insert into public.book_holdings (book_id, library_id)
      values (v_book_id, v_library_id)
      on conflict (book_id, library_id) do update set updated_at = now()
      returning id into v_holding_id;

      -- #copies (17/08) : N exemplaires (défaut 1, borné 1..50). fn_next_tombo,
      -- appelée en boucle dans la même transaction, voit ses propres INSERT et
      -- renvoie des tombos séquentiels distincts (+ verrou d'avis par préfixe).
      v_copies := greatest(1, least(coalesce(v_draft.initial_copies, 1), 50));
      for v_i in 1..v_copies loop
        begin
          v_auto_tombo := public.fn_next_tombo(v_library_id);
        exception when others then
          -- Pas de tombo_pattern : repli sur bib_ref, suffixé pour éviter la
          -- collision d'unicité globale au-delà du 1er exemplaire.
          v_auto_tombo := case when v_i = 1 then v_draft.bib_ref
                               else v_draft.bib_ref || '-' || v_i::text end;
        end;
        if v_auto_tombo is null or btrim(v_auto_tombo) = '' then
          v_auto_tombo := case when v_i = 1 then v_draft.bib_ref
                               else v_draft.bib_ref || '-' || v_i::text end;
        end if;
        insert into public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
        values (v_draft.bib_ref, v_auto_tombo, v_library_id, v_holding_id, v_circ_policy, 'public');
      end loop;

      perform public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_holding_id]);
    end if;

  else
    update public.books
    set
      work_id = coalesce(v_draft.work_id, work_id),
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
      serial_id = v_draft.serial_id,         -- #périodiques P7 (27/08)
      titulo_periodico = v_draft.titulo_periodico,
      volume = v_draft.volume, numero = v_draft.numero,
      fasciculo = v_draft.fasciculo, data_edicao = v_draft.data_edicao,
      periodicidade = v_draft.periodicidade, colecao = v_draft.colecao,
      acquisition_mode = v_draft.acquisition_mode,
      acquisition_date = v_draft.acquisition_date,
      owner_library = v_draft.owner_library, holder_library = v_draft.holder_library,
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
      print_technique = v_draft.print_technique,
      physical_state = v_draft.physical_state,
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
      distribuidora = v_draft.distribuidora, gravadora = v_draft.gravadora,
      tese_university = v_draft.tese_university, tese_advisor = v_draft.tese_advisor,
      artigo_source = v_draft.artigo_source, artigo_volume = v_draft.artigo_volume,
      artigo_issue = v_draft.artigo_issue, artigo_pages = v_draft.artigo_pages,
      relatorio_org = v_draft.relatorio_org,
      relatorio_recipient = v_draft.relatorio_recipient,
      relatorio_internal_notes = v_draft.relatorio_internal_notes,
      zine_print_run = v_draft.zine_print_run,
      zine_technique = v_draft.zine_technique, zine_format = v_draft.zine_format,
      subjects = v_draft.subjects
    where id = v_draft.published_book_id
    returning id into v_book_id;
  end if;

  update public.book_drafts
  set published_book_id = v_book_id, status = 'published',
      updated_by = coalesce(v_draft.updated_by, auth.uid()), updated_at = now()
  where id = p_draft_id;

  perform public.publish_book_draft_digital_resources(p_draft_id, v_book_id);

  return v_book_id;
end;
$function$;

COMMENT ON FUNCTION public.publish_book_draft(bigint) IS
  'Publie un brouillon de catalogage en notice books (ou met à jour la notice '
  'déjà publiée). Recopie serial_id depuis le brouillon depuis le paquet '
  'PÉRIODIQUES P7a du 27/08/2026 — dans les DEUX branches : l''oublier dans '
  'l''UPDATE ferait perdre son titre à un fascicule qu''on republie.';

-- -------------------------------------------------------------------------
-- 4. Vérification structurelle
-- -------------------------------------------------------------------------
DO $verif$
DECLARE v_def text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'book_drafts'
       AND column_name = 'serial_id') THEN
    RAISE EXCEPTION 'P7a : book_drafts.serial_id absente.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgrelid = 'public.book_drafts'::regclass
                    AND tgname = 'book_drafts_serial_id_requires_periodico') THEN
    RAISE EXCEPTION 'P7a : la garde G3 manque sur le brouillon.';
  END IF;

  v_def := pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure);

  -- Les DEUX branches. Compter les occurrences plutôt que de tester la
  -- présence : une seule des trois lignes suffirait à faire passer un test
  -- naïf, et c'est justement la branche UPDATE qu'on oublie.
  IF (length(v_def) - length(replace(v_def, 'v_draft.serial_id', ''))) / length('v_draft.serial_id') < 2 THEN
    RAISE EXCEPTION 'P7a : publish_book_draft ne recopie serial_id que dans une branche sur deux.';
  END IF;
  IF v_def NOT LIKE '%serial_id = v_draft.serial_id%' THEN
    RAISE EXCEPTION 'P7a : la branche UPDATE de publish_book_draft ne recopie pas serial_id — republier détacherait le fascicule.';
  END IF;

  -- Les gardes préexistantes n'ont pas été perdues au passage.
  IF v_def NOT LIKE '%Acesso restrito ao staff de catalogacao%'
     OR v_def NOT LIKE '%bib_ref_duplicado%'
     OR v_def NOT LIKE '%isbn_duplicado%' THEN
    RAISE EXCEPTION 'P7a : une garde de publish_book_draft a disparu au patch.';
  END IF;

  RAISE NOTICE 'Paquet PÉRIODIQUES P7a : vérifications structurelles OK (colonne, garde G3, recopie dans les deux branches, gardes préexistantes intactes).';
END $verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé :
-- =========================================================================
-- BEGIN;
--   -- Réappliquer la définition de publish_book_draft du 17/08/2026 (sans les
--   -- trois lignes « #périodiques P7 »), PUIS :
--   DROP TRIGGER IF EXISTS book_drafts_serial_id_requires_periodico ON public.book_drafts;
--   DROP FUNCTION IF EXISTS public.fn_book_drafts_serial_id_requires_periodico();
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS serial_id;
-- COMMIT;
-- =========================================================================
