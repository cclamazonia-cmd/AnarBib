-- =============================================================================
-- La bibliotheque de destination ne se choisit pas par accident
-- =============================================================================
-- Date     : 2026-08-29
-- Chantier : catalogage — portee des gestes (suite de l'examen RLS des rascunhos)
--
-- Publier un rascunho cree un book_holding et un exemplaire avec un tombo pris
-- dans la serie de LA bibliotheque choisie. Trois lignes decidaient de ce choix,
-- et deux d'entre elles n'etaient gardees par rien.
--
-- 1. LE GARDE-FOU ETAIT SUR LE MAUVAIS CHAMP. Le commentaire #biblio-choisie du
--    17/08 dit l'intention — « un·e admin reseau peut cibler explicitement la
--    biblio [...] ; pour le reste du staff, le champ est ignore (garde-fou
--    serveur, independant de l'UI) » — et le pose sur initial_copies_library_id.
--    Mais c'est owner_library_id qui est LU EN PREMIER, et il se modifie
--    librement : la policy des rascunhos est une policy ALL sans aucune portee de
--    bibliotheque, et UPDATE est accorde sur les 103 colonnes. Verifie par essai
--    sous JWT le 29/08 : une bibliothecaire de la BLMF a reaffecte un rascunho de
--    Terra Livre vers une troisieme bibliotheque (UPDATE lignes=1).
--
-- 2. ET SURTOUT : LE REPLI CHOISISSAIT TOUT SEUL. Quand owner_library_id est nul
--    — 1663 rascunhos non publies sur 1810 au 29/08 — la destination venait de
--    `order by ulm.role desc limit 1` sur les adhesions. C'est un tri
--    ALPHABETIQUE sur le NOM du role : il met `reader` devant `librarian` et
--    `coordenador`. Il ne filtrait pas `status` non plus, donc une adhesion
--    REVOQUEE pouvait designer la bibliotheque (4 adhesions librarian revoquees
--    en base, les comptes de mutirao). Et entre deux adhesions de meme role,
--    l'ordre n'etait meme pas deterministe : une personne du reseau a des
--    adhesions dans DEUX bibliotheques et deux lignes `reader` que rien ne
--    departage. Aucun reglage de role ne corrige un tri alphabetique : ce
--    correctif-la ne demande aucune decision collective.
--
-- CE QUE CA CHANGE POUR LES RASCUNHOS EN ATTENTE (mesure le 29/08) :
--   * 147 rascunhos non publies portent owner_library_id = MLEG. Ils restent
--     publiables par la personne du staff MLEG (1 adhesion active) ou par une
--     admin reseau ; par quelqu'un d'autre, ils sont desormais REFUSES au lieu
--     d'aller silencieusement ailleurs.
--   * 1663 rascunhos (lot Solidaires #18) n'ont pas d'owner_library_id : le
--     nouveau repli les rattache a BLMF, la bibliotheque de la personne qui a
--     fait l'import — comme l'ancien, mais pour une raison lisible cette fois.
--     ⚠ Ce n'est PAS une decision technique : « Bibliotheque Solidaires » n'est
--     pas une bibliotheque du reseau (source d'import 17), et publier ce lot
--     creerait 1663 holdings BLMF. A trancher avant de promouvoir le lot.
--
-- Corps repris VERBATIM de pg_get_functiondef, un seul bloc remplace.
-- =============================================================================

begin;

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

    -- #biblio-choisie (17/08, elargi le 29/08/2026). La regle voulue : choisir
    -- explicitement la bibliotheque de destination est reserve a l'admin reseau.
    -- Elle etait posee sur initial_copies_library_id SEULEMENT, alors que
    -- owner_library_id est lu AVANT lui, decide donc en premier, et se modifie
    -- librement par toute personne qui catalogue (policy ALL sans portee de
    -- bibliotheque, UPDATE sur les 103 colonnes). La regle etait donc appliquee
    -- sur un champ et ouverte sur celui qui a la priorite.
    v_library_id := v_draft.owner_library_id;

    -- Publier dans le catalogue d'une bibliotheque, c'est y creer un holding et
    -- un exemplaire avec un tombo pris dans SA serie : on ne le fait pas au nom
    -- d'un collectif dont on n'est pas membre.
    if v_library_id is not null
       and not public.fn_caller_is_network_admin()
       and not exists (
         select 1 from public.user_library_memberships ulm
          where ulm.user_id = auth.uid()
            and ulm.status = 'active'
            and ulm.role = any (array['librarian'::text, 'coordenador'::text])
            and ulm.library_id = v_library_id
       ) then
      raise exception
        'Ce rascunho est rattache a une bibliotheque dont vous n''etes pas membre (%).', v_library_id
        using hint = 'error.publish.other_library';
    end if;

    if v_library_id is null then
      -- Le repli decidait de la destination par un tri ALPHABETIQUE DESCENDANT
      -- sur le NOM du role. (La chaine exacte n'est pas recopiee ici : le bloc
      -- de verification de la migration cherche sa disparition dans ce corps.)
      -- Ce tri met `reader` DEVANT `librarian` et `coordenador` — exactement
      -- le contraire de son intention — et il ne
      -- filtrait pas `status`, donc une adhesion REVOQUEE pouvait designer la
      -- bibliotheque ou le livre atterrit. Il y a 4 adhesions `librarian`
      -- revoquees en base (comptes de mutirao). Personne ne choisissait : le
      -- tri choisissait.
      --
      -- Desormais : adhesion ACTIVE et de catalogage seulement, departagee comme
      -- api.my_access departage l'adhesion effective (principale, puis
      -- anciennete), avec library_id en dernier critere pour que le resultat soit
      -- DETERMINISTE — deux adhesions de meme rang ne doivent pas donner deux
      -- reponses selon le jour.
      --
      -- On demande d'abord a qui a CREE le rascunho (c'est sa bibliotheque qui l'a
      -- catalogue), et seulement a defaut a qui publie : sinon un compte de
      -- mutirao revoque rendrait la publication impossible a rattacher.
      select ulm.library_id into v_library_id
        from public.user_library_memberships ulm
       where ulm.user_id = v_draft.created_by
         and ulm.status = 'active'
         and ulm.role = any (array['librarian'::text, 'coordenador'::text])
       order by ulm.is_primary desc, ulm.created_at, ulm.library_id
       limit 1;

      if v_library_id is null then
        select ulm.library_id into v_library_id
          from public.user_library_memberships ulm
         where ulm.user_id = auth.uid()
           and ulm.status = 'active'
           and ulm.role = any (array['librarian'::text, 'coordenador'::text])
         order by ulm.is_primary desc, ulm.created_at, ulm.library_id
         limit 1;
      end if;
    end if;

    -- L'override admin reste le seul chemin pour cibler une autre bibliotheque.
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
      -- #périodiques P7b (27/08) : coalesce, comme work_id juste au-dessus.
      -- Un brouillon antérieur à la colonne porte NULL ; l'écrire tel quel
      -- EFFAÇAIT le rattachement à chaque republication, en silence.
      serial_id = coalesce(v_draft.serial_id, serial_id),
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
$function$
;

comment on function public.publish_book_draft(bigint) is
  'Publie un rascunho de livre. La bibliotheque de destination vient de '
  'owner_library_id (refuse si ce n''est pas une des siennes, sauf admin reseau), '
  'sinon d''une adhesion ACTIVE de catalogage — du createur, a defaut de qui '
  'publie — departagee de facon deterministe. Garde-fou elargi le 29/08/2026 : '
  'il ne portait que sur initial_copies_library_id.';

-- -----------------------------------------------------------------------------
-- Verification structurelle
-- -----------------------------------------------------------------------------
-- Le comportement est tenu par tests/sql/publication_biblio_destination_tests.sql :
-- la fonction exige un JWT, elle n'est pas appelable ici.
do $verif$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'publish_book_draft';

  if v_def like '%order by ulm.role desc%' then
    raise exception 'le tri alphabetique de role est toujours la';
  end if;
  if v_def not like '%error.publish.other_library%' then
    raise exception 'le garde-fou sur owner_library_id n''a pas ete pose';
  end if;
  if v_def not like '%ulm.is_primary desc, ulm.created_at, ulm.library_id%' then
    raise exception 'le repli n''est pas deterministe';
  end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'publish_book_draft' and p.prosecdef
  ) then
    raise exception 'publish_book_draft a perdu SECURITY DEFINER au remplacement';
  end if;
  if exists (
    select 1 from information_schema.routine_privileges
     where routine_schema = 'public' and routine_name = 'publish_book_draft'
       and grantee in ('anon', 'PUBLIC')
  ) then
    raise exception 'publish_book_draft est ouverte a anon ou PUBLIC';
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   -- Ou iraient les rascunhos en attente, sans rien publier :
--   select coalesce(l.slug, '(repli sur adhesion)') as destination, count(*)
--     from public.book_drafts d
--     left join public.libraries l on l.id = d.owner_library_id
--    where d.status in ('draft','ready')
--    group by 1 order by 2 desc;
-- =============================================================================
