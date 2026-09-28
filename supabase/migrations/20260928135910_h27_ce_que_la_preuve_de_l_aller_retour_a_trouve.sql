-- =====================================================================
-- 20260928135910_h27_ce_que_la_preuve_de_l_aller_retour_a_trouve
-- H27 (28/09/2026) — ce que la preuve de l'aller-retour PMB a trouvé côté
-- base (tests/sql/aller_retour_pmb_tests.sql : les deux fixtures exportées par
-- PMB 8.1, importées par la vraie edge function, promues, publiées, exportées).
-- Aucun import MARC n'est encore allé jusqu'à la publication en production :
-- rien à rattraper (lu le 28/09 : 0 brouillon dont la langue viole la CHECK,
-- 0 brouillon dont l'auteur s'écrit dans un alphabet non latin).
--
-- 1. LA LANGUE. L'import recopiait dans le brouillon le code BRUT (101 $a
--    UNIMARC, 008/35-37 et 041 MARC21 : `fre`, `rus`, `chi`…) ;
--    `publish_book_draft` le recopie dans `books.idioma`, dont la CHECK
--    `books_idioma_bcp47_chk` n'admet qu'un BCP-47 court
--    (`^[a-z]{2}(-[A-Z]{2})?$`, CONV-7) : 23514, le lot entier refusé.
--    `ingest.fn_idioma_bcp47` convertit une fois, à la frontière de
--    l'import : les 36 langues de `src/lib/languages.js` (ISO 639-1, 639-2/B
--    et /T, BCP-47 à région), les libellés portugais que CONV-7 normalisait ;
--    « pt » et ses variantes → « pt-BR » (la convention du catalogue). Hors des
--    36, un code à deux lettres garde sa forme canonique (admise par la
--    CHECK) ; le reste (« fro », « mul », « und »…) devient NULL — le code
--    d'origine reste dans l'enregistrement brut (`marc_json`). Réciproque de
--    `codeLangue` (`_shared/marc/ecriture.ts`).
-- 2. LES NOMS NON LATINS. `fn_conv_est_non_agent` (CONV-8) compare la forme
--    normalisée (`normalize_author_alias` : minuscules, accents latins
--    retirés, tout le reste effacé) à une liste où figure la chaîne vide : un
--    nom grec, cyrillique, arabe ou chinois se normalise en « » et passait
--    pour « Collectif ». Ses responsabilités étaient écartées à l'import, au
--    rattrapage H18, au rapport de révision et aux candidats d'autorité. Seul
--    un nom vide ou fait de ponctuation ASCII est désormais un non-agent.
-- 3. LES MOTS-CLÉS LIBRES (610 / 653). L'edge function les gardait avec les
--    vedettes (606 / 650) ; l'export les rendait donc en 606, que PMB change
--    en catégories au réimport. Ils arrivent à part (`normalized_payload.
--    keywords`) et la création du brouillon les note en un paragraphe
--    « Palavras-chave importadas: … », que l'export rend en 610 / 653.
--
-- Recréées depuis leur définition réelle (md5 identiques en production) :
-- `ingest.fn_create_book_drafts_from_import_rows` (46b2967f…, deux
-- endroits changés), `public.fn_conv_est_non_agent` (2dea4bed…).
-- =====================================================================

CREATE OR REPLACE FUNCTION ingest.fn_idioma_bcp47(p_langue text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog'
AS $function$
  WITH v AS (SELECT lower(btrim(coalesce(p_langue, ''))) AS x)
  SELECT CASE
    WHEN v.x = '' THEN NULL
    -- deux lettres, avec ou sans région : la langue de base si elle est des 36
    WHEN v.x ~ '^[a-z]{2}([-_][a-z]{2})?$' THEN coalesce(
      (SELECT b FROM (VALUES
      ('ar', 'ar'), ('bg', 'bg'), ('ca', 'ca'), ('cs', 'cs'), ('da', 'da'), ('de', 'de'), ('el', 'el'), ('en', 'en'),
      ('eo', 'eo'), ('es', 'es'), ('eu', 'eu'), ('fa', 'fa'), ('fi', 'fi'), ('fr', 'fr'), ('gl', 'gl'), ('he', 'he'),
      ('hi', 'hi'), ('hr', 'hr'), ('hu', 'hu'), ('id', 'id'), ('it', 'it'), ('ja', 'ja'), ('ko', 'ko'), ('nb', 'nb'),
      ('nl', 'nl'), ('oc', 'oc'), ('pl', 'pl'), ('pt', 'pt-BR'), ('ro', 'ro'), ('ru', 'ru'), ('sk', 'sk'), ('sr', 'sr'),
      ('sv', 'sv'), ('tr', 'tr'), ('uk', 'uk'), ('zh', 'zh')) t(c, b) WHERE t.c = left(v.x, 2)),
      CASE WHEN length(v.x) = 2 THEN v.x ELSE left(v.x, 2) || '-' || upper(right(v.x, 2)) END)
    WHEN v.x ~ '^[a-z]{3}$' THEN (SELECT b FROM (VALUES
      ('ara', 'ar'), ('bul', 'bg'), ('cat', 'ca'), ('cze', 'cs'), ('ces', 'cs'), ('dan', 'da'), ('ger', 'de'), ('deu', 'de'),
      ('gre', 'el'), ('ell', 'el'), ('eng', 'en'), ('epo', 'eo'), ('spa', 'es'), ('baq', 'eu'), ('eus', 'eu'), ('per', 'fa'),
      ('fas', 'fa'), ('fin', 'fi'), ('fre', 'fr'), ('fra', 'fr'), ('glg', 'gl'), ('heb', 'he'), ('hin', 'hi'), ('hrv', 'hr'),
      ('hun', 'hu'), ('ind', 'id'), ('ita', 'it'), ('jpn', 'ja'), ('kor', 'ko'), ('nob', 'nb'), ('dut', 'nl'), ('nld', 'nl'),
      ('oci', 'oc'), ('pol', 'pl'), ('por', 'pt-BR'), ('rum', 'ro'), ('ron', 'ro'), ('rus', 'ru'), ('slo', 'sk'), ('slk', 'sk'),
      ('srp', 'sr'), ('swe', 'sv'), ('tur', 'tr'), ('ukr', 'uk'), ('chi', 'zh'), ('zho', 'zh')) t(c, b) WHERE t.c = v.x)
    ELSE (SELECT b FROM (VALUES
      ('português', 'pt-BR'), ('espanhol', 'es'), ('francês', 'fr'), ('inglês', 'en'), ('italiano', 'it'), ('alemão', 'de'),
      ('esperanto', 'eo'), ('catalão', 'ca'), ('holandês', 'nl'), ('neerlandês', 'nl'), ('grego', 'el')) t(c, b) WHERE t.c = v.x)
  END
  FROM v;
$function$;

COMMENT ON FUNCTION ingest.fn_idioma_bcp47(text) IS
  'H27 : code de langue importé (ISO 639-1, 639-2/B et /T, BCP-47, libellé portugais) → books.idioma (BCP-47 court, 36 langues de src/lib/languages.js) ; inconnu → NULL.';

REVOKE EXECUTE ON FUNCTION ingest.fn_idioma_bcp47(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.fn_conv_est_non_agent(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  -- H27 : un nom écrit dans un autre alphabet (grec, cyrillique, arabe,
  -- chinois…) ne se normalise en rien — ce n'est pas une raison d'en faire un
  -- « Collectif » ; seul un nom vide, ou fait de ponctuation ASCII, ne désigne
  -- personne.
  select case
    when btrim(coalesce(p_nom, '')) = '' then true
    when btrim(public.normalize_author_alias(p_nom)) = '' then p_nom !~ '[^\x01-\x7F]'
    else btrim(public.normalize_author_alias(p_nom)) in (
    '', 'aa vv', 'vv aa', 'aavv', 'vvaa', 'autori vari', 'autores varios', 'varios autores',
    'varios', 'divers', 'auteurs divers', 'collectif', 'coletivo', 'colectivo', 'collettivo',
    'collective', 'anonimo', 'anonima', 'anonyme', 'anonymous', 'anon', 'sem autoria',
    'sem autor', 'sin autor', 'senza autore', 'sans auteur', 'identificado nao',
    'nao identificado', 'no identificado', 'non identificato', 'desconhecido', 'desconocido',
    'inconnu', 'unknown', 's n', 's a', 'n a'
  ) end;
$function$
;

CREATE OR REPLACE FUNCTION ingest.fn_create_book_drafts_from_import_rows(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL::bigint[], p_batch_name text DEFAULT NULL::text, p_batch_notes text DEFAULT NULL::text, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'auth'
AS $function$
declare
  v_actor uuid;
  v_partner_name text;
  v_relation_status text;
  v_original_filename text;
  v_detected_format text;
  v_batch_id bigint;
  v_batch_name text;
  v_batch_notes text;
  v_created_count integer := 0;
  v_requested_count integer := 0;
  v_draft_id bigint;
  v_refresh jsonb;
  v_collection_hint text;
  v_local_classification_hint text;
  v_provenance_note text;
  rec record;
begin
  v_actor := coalesce(p_created_by, auth.uid());

  select s.partner_name, s.relation_status, r.original_filename, r.detected_format
    into v_partner_name, v_relation_status, v_original_filename, v_detected_format
  from ingest.partner_catalog_import_runs r
  join ingest.partner_catalog_sources s on s.id = r.source_id
  where r.id = p_run_id;

  if not found then
    raise exception 'import_run % introuvable', p_run_id;
  end if;

  if coalesce(array_length(p_row_ids, 1), 0) > 0 then
    select count(*)::integer
      into v_requested_count
    from ingest.partner_catalog_staging_rows sr
    where sr.run_id = p_run_id
      and sr.id = any(p_row_ids)
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      );
  else
    select count(*)::integer
      into v_requested_count
    from ingest.partner_catalog_staging_rows sr
    where sr.run_id = p_run_id
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      and sr.selected_for_draft = true
      and sr.review_status = 'approved'
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      );
  end if;

  if v_requested_count = 0 then
    raise exception 'Aucune ligne autorisée à convertir pour le run %', p_run_id;
  end if;

  v_batch_name := coalesce(
    nullif(trim(p_batch_name), ''),
    format(
      'Import parceiro #%s — %s — %s',
      p_run_id,
      left(coalesce(v_partner_name, 'parceiro sem nome'), 80),
      to_char(now() at time zone 'UTC', 'YYYY-MM-DD HH24:MI UTC')
    )
  );

  v_batch_notes := coalesce(
    nullif(trim(p_batch_notes), ''),
    format(
      'Lote criado a partir do import run %s (%s, formato %s).',
      p_run_id,
      coalesce(v_original_filename, 'arquivo sem nome'),
      coalesce(v_detected_format, 'unknown')
    )
  );

  -- B30 : le lot naît avec sa bibliothèque — celle que fn_import_promote
  -- tamponne ensuite sur ses notices : le run pour un catalogue propre, la
  -- destination pour un dépôt compagnon ou un entrepôt OAI (nulle tant qu'elle
  -- est inconnue : le lot est alors à l'administration).
  insert into public.catalog_batches (name, notes, created_by, library_id)
  values (v_batch_name, v_batch_notes, v_actor,
          (select case when s.source_kind in ('partner_deposit', 'oai_pmh') then s.destination_library_id
                       else r.library_id end
             from ingest.partner_catalog_import_runs r
             left join ingest.partner_catalog_sources s on s.id = r.source_id
            where r.id = p_run_id))
  returning id into v_batch_id;

  for rec in
    select sr.*, r.original_filename, r.detected_format, s.partner_name, s.relation_status, s.source_kind
    from ingest.partner_catalog_staging_rows sr
    join ingest.partner_catalog_import_runs r on r.id = sr.run_id
    join ingest.partner_catalog_sources s on s.id = r.source_id
    where sr.run_id = p_run_id
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      and not exists (
        select 1 from ingest.partner_catalog_row_to_draft rd where rd.staging_row_id = sr.id
      )
      and (
        (coalesce(array_length(p_row_ids, 1), 0) > 0 and sr.id = any(p_row_ids))
        or
        (coalesce(array_length(p_row_ids, 1), 0) = 0 and sr.selected_for_draft = true and sr.review_status = 'approved')
      )
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      )
    order by sr.row_no, sr.id
  loop
    v_collection_hint := ingest.fn_partner_catalog_extract_collection_hint(rec.normalized_payload, rec.raw_payload);
    v_local_classification_hint := ingest.fn_partner_catalog_extract_local_classification_hint(rec.normalized_payload, rec.raw_payload);

    v_provenance_note := format(
      'Importado de catálogo parceiro "%s" (%s, run %s, linha %s, formato bruto %s, relação %s, decisão %s).',
      rec.partner_name,
      coalesce(rec.original_filename, 'arquivo sem nome'),
      rec.run_id,
      rec.row_no,
      coalesce(rec.detected_format, 'unknown'),
      coalesce(rec.relation_status, 'sem_status'),
      coalesce(rec.editorial_decision, 'pending')
    );

    if v_local_classification_hint is not null then
      v_provenance_note := v_provenance_note || format(' Sinal local da parceira preservado: %s.', v_local_classification_hint);
    end if;

    insert into public.book_drafts (
      batch_id, action, status, titulo, subtitulo, autor, edicao,
      local_publicacao, editora, ano, isbn, issn, idioma, tipo_material,
      cdd, colecao, marc_json, created_by, updated_by, acquisition_mode,
      partner_source, source_record_id, import_format, import_method,
      provenance_note, mutualization_status, source_label, notas,
      -- H17 : pages, volume, adresse, périodique et article
      paginas, volume, digital_native_url, titulo_periodico,
      artigo_source, artigo_volume, artigo_issue, artigo_pages, data_edicao, numero
    ) values (
      v_batch_id,
      'create',
      'draft',
      nullif(trim(rec.title), ''),
      nullif(trim(rec.subtitle), ''),
      coalesce(nullif(trim(rec.responsibility_statement), ''), ingest.fn_format_partner_authors(rec.authors)),
      nullif(trim(rec.edition_statement), ''),
      nullif(trim(rec.place_of_publication), ''),
      nullif(trim(rec.publisher), ''),
      nullif(trim(rec.publication_year), ''),
      nullif(trim(rec.isbn), ''),
      coalesce(nullif(trim(rec.issn), ''),                       -- H17 : l'ISSN de la revue d'un article
               case when rec.normalized_payload->>'material_type' in ('artigo', 'periodico')
                    then nullif(btrim(rec.normalized_payload->'host'->>'issn'), '') end),
      ingest.fn_idioma_bcp47(rec.language),
      -- tipo_material : H17, le type déduit du guide MARC (article dépouillé,
      -- périodique, son…) quand il est valide ; sinon le type brut (RIS/BibTeX).
      coalesce(case when rec.normalized_payload->>'material_type' = any (array['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine'])
                    then rec.normalized_payload->>'material_type' end,
      case lower(coalesce(nullif(trim(rec.item_type), ''), 'book'))
        when 'book' then 'livro'
        when 'livro' then 'livro'
        when 'jour' then 'periodico'
        when 'mgzn' then 'periodico'
        when 'news' then 'periodico'
        when 'newspaper' then 'periodico'
        when 'periodico' then 'periodico'
        when 'chap' then 'artigo'
        when 'inbook' then 'artigo'
        when 'article' then 'artigo'
        when 'artigo' then 'artigo'
        when 'thes' then 'tese'
        when 'tese' then 'tese'
        when 'rprt' then 'relatorio'
        when 'relatorio' then 'relatorio'
        when 'pamp' then 'tract'
        when 'tract' then 'tract'
        when 'zine' then 'zine'
        when 'elec' then 'recurso_digital'
        when 'sound' then 'audio'
        when 'audio' then 'audio'
        when 'video' then 'audiovisual'
        when 'mpct' then 'audiovisual'
        when 'audiovisual' then 'audiovisual'
        else 'livro'
      end),
      -- H17 : la classification (676 / 082).
      nullif(btrim(rec.normalized_payload->>'classification'), ''),
      coalesce(nullif(btrim(rec.normalized_payload->>'series'), ''),   -- H17 : 225/410, 490
      case
        when v_collection_hint is null then null
        -- H17 (revue) : la revue d'un article ou d'un fascicule n'est pas sa collection
        when rec.normalized_payload->>'material_type' in ('artigo', 'periodico') then null
        when lower(coalesce(rec.item_type, '')) ~ '(periodic|journal|article|boletim|periodico|periódico|jour)' then null
        when lower(regexp_replace(coalesce(v_collection_hint, ''), '\s+', ' ', 'g')) = lower(regexp_replace(coalesce(rec.title, ''), '\s+', ' ', 'g')) then null
        else v_collection_hint
      end),
      coalesce(rec.normalized_payload, '{}'::jsonb)
        || jsonb_build_object(
             'ingest',
             jsonb_build_object(
               'run_id', rec.run_id,
               'source_id', (select r2.source_id from ingest.partner_catalog_import_runs r2 where r2.id = rec.run_id),   -- H20
               'staging_row_id', rec.id,
               'row_no', rec.row_no,
               'source_file_id', rec.source_file_id,
               'partner_name', rec.partner_name,
               'relation_status', rec.relation_status,
               'original_filename', rec.original_filename,
               'detected_format', rec.detected_format,
               'raw_payload', coalesce(rec.raw_payload, '{}'::jsonb),
               'authors', coalesce(rec.authors, '[]'::jsonb),
               'subjects', coalesce(rec.subjects, '[]'::jsonb),
               'editorial_decision', rec.editorial_decision,
               'editorial_note', rec.editorial_note,
               'derived_collection_hint', v_collection_hint,
               'derived_local_classification_hint', v_local_classification_hint
             )
           ),
      v_actor,
      v_actor,
      null,
      'other_partner',                               -- partner_source : code valide (FK source_partner_code). Nom precis dans provenance_note/source_label.
      -- H20 : l'identifiant d'origine du fichier (001), ou rien — jamais le
      -- numéro de la ligne de staging, qui passait pour un numéro de PMB.
      nullif(trim(rec.external_key), ''),
      null,                                          -- import_format : NULL (evite FK source_format_code)
      null,                                          -- import_method : NULL (evite FK import_method_code)
      v_provenance_note,
      null,
      coalesce(rec.original_filename, rec.partner_name),
      nullif(concat_ws(E'\n\n',
        nullif(btrim(rec.normalized_payload->>'notes'), ''),
        case when nullif(btrim(rec.normalized_payload->>'url'), '') is not null
              and rec.normalized_payload->>'material_type' is distinct from 'recurso_digital'
             then 'Endereço eletrônico: ' || btrim(rec.normalized_payload->>'url') end,
        -- H27 : les mots-clés libres (610 / 653), à part des vedettes ; l'export
        -- les rend en 610 / 653 (_shared/marc/ecriture.ts, deplierNotes).
        case when jsonb_typeof(rec.normalized_payload->'keywords') = 'array'
              and jsonb_array_length(rec.normalized_payload->'keywords') > 0
             then 'Palavras-chave importadas: '
                  || array_to_string(array(select jsonb_array_elements_text(rec.normalized_payload->'keywords')), '; ') end,
      nullif(concat_ws(
        ' ',
        case
          when rec.subjects is not null
           and jsonb_typeof(rec.subjects) = 'array'
           and jsonb_array_length(rec.subjects) > 0
          then 'Assuntos importados: '
               || array_to_string(array(select jsonb_array_elements_text(rec.subjects)), '; ')
          else null
        end,
        case
          when v_local_classification_hint is not null
          then format('Classificação / cote local preservada da parceira: %s.', v_local_classification_hint)
          else null
        end
      ), '')), ''),
      -- H17
      case when (rec.normalized_payload->>'pages') ~ '^[0-9]{1,5}$' then (rec.normalized_payload->>'pages')::integer end,
      nullif(btrim(rec.normalized_payload->>'volume'), ''),
      case when rec.normalized_payload->>'material_type' = 'recurso_digital'
           then nullif(btrim(rec.normalized_payload->>'url'), '') end,
      case when rec.normalized_payload->>'material_type' = 'periodico'
           then coalesce(nullif(btrim(rec.normalized_payload->>'key_title'), ''), nullif(trim(rec.title), '')) end,
      case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->'host'->>'title'), '') end,
      case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->'host'->>'volume'), '') end,
      case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->'issue'->>'number'), '') end,
      case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->>'extent'), '') end,
      case when rec.normalized_payload->>'material_type' in ('artigo', 'periodico') then nullif(btrim(rec.normalized_payload->'issue'->>'date'), '') end,
      -- H17 (revue) : le numéro d'un fascicule (notice de bulletin de PMB)
      case when rec.normalized_payload->>'material_type' = 'periodico' then nullif(btrim(rec.normalized_payload->'issue'->>'number'), '') end
    ) returning id into v_draft_id;

    -- H18 (27/09/2026) : les responsabilités, structurées quand le fichier les
    -- porte (MARC : nom, nature, rôle, code d'origine) ; sinon les noms de la
    -- ligne (CSV, RIS : des chaînes ; recherche institutionnelle, paquet de
    -- fonds : des objets {name|label|display|family+given, role}), en
    -- auteur·rice sauf rôle AnarBib dit. La principale d'abord. Jamais un
    -- non-agent (« Collectif », « Vários » : CONV-8, entrée au titre).
    -- Aucune autorité n'est rattachée d'office : les rapprochements se
    -- proposent en révision du lot.
    insert into public.book_draft_contributors (draft_id, position, name, role, is_primary, nature, role_code)
    select v_draft_id, row_number() over (order by c.ord)::integer, left(btrim(c.value->>'name'), 500),
           case when c.value->>'role' = any (array['autor','coautor','organizacao','organizador','tradutor','ilustrador','prefaciador','coordenador','editor','realizador','roteirista','ator','interprete','compositor','narrador','produtor','locutor','outro']) then c.value->>'role' else 'outro' end,
           row_number() over (order by c.ord) = 1 and (c.value->'primary') is distinct from 'false'::jsonb,
           case when c.value->>'nature' in ('person', 'collective', 'congress') then c.value->>'nature' end,
           nullif(left(btrim(c.value->>'role_code'), 40), '')
      from jsonb_array_elements(case when jsonb_typeof(rec.normalized_payload->'contributors') = 'array'
                                     then rec.normalized_payload->'contributors' else '[]'::jsonb end)
           with ordinality as c(value, ord)
     where jsonb_typeof(c.value) = 'object' and nullif(btrim(c.value->>'name'), '') is not null
       and not public.fn_conv_est_non_agent(c.value->>'name');
    if not found then
      insert into public.book_draft_contributors (draft_id, position, name, role, is_primary)
      select v_draft_id, row_number() over (order by a.ord)::integer, left(n.nom, 500),
             case when a.value->>'role' = any (array['autor','coautor','organizacao','organizador','tradutor','ilustrador','prefaciador','coordenador','editor','realizador','roteirista','ator','interprete','compositor','narrador','produtor','locutor','outro']) then a.value->>'role' else 'autor' end,
             row_number() over (order by a.ord) = 1
        from jsonb_array_elements(case when jsonb_typeof(rec.authors) = 'array' then rec.authors else '[]'::jsonb end)
             with ordinality as a(value, ord)
        cross join lateral (select ingest.fn_h18_nom_d_auteur(a.value) as nom) n
       where n.nom is not null and not public.fn_conv_est_non_agent(n.nom);
    end if;

    insert into ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id, created_by)
    values (rec.id, rec.run_id, v_draft_id, v_batch_id, v_actor);

    update ingest.partner_catalog_staging_rows
       set created_book_draft_id = v_draft_id,
           review_status = 'draft_created',
           selected_for_draft = false
     where id = rec.id;

    v_created_count := v_created_count + 1;
  end loop;

  if v_created_count = 0 then
    delete from public.catalog_batches where id = v_batch_id;
    raise exception 'Aucun rascunho créé pour le run %', p_run_id;
  end if;

  -- H20 (revue du 28/09) : une clé que plusieurs lignes du run portent, ou le
  -- numéro d'un fascicule, n'est pas un identifiant d'origine : effacée des
  -- brouillons du run avant qu'une publication ne la recopie.
  perform ingest.fn_h20_effacer_faux_identifiants(p_run_id);

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);

  return jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch_id,
    'batch_name', v_batch_name,
    'requested_rows', v_requested_count,
    'created_drafts', v_created_count,
    'run', v_refresh
  );
end;
$function$
;

DO $$
BEGIN
  IF ingest.fn_idioma_bcp47('fre') IS DISTINCT FROM 'fr' OR ingest.fn_idioma_bcp47('POR') IS DISTINCT FROM 'pt-BR'
     OR ingest.fn_idioma_bcp47('zho') IS DISTINCT FROM 'zh' OR ingest.fn_idioma_bcp47('pt-pt') IS DISTINCT FROM 'pt-BR'
     OR ingest.fn_idioma_bcp47('fro') IS NOT NULL OR ingest.fn_idioma_bcp47('Português') IS DISTINCT FROM 'pt-BR' THEN
    RAISE EXCEPTION 'H27 : fn_idioma_bcp47 ne convertit pas comme attendu';
  END IF;
  IF public.fn_conv_est_non_agent('Παπαδόπουλος, Νίκος') OR public.fn_conv_est_non_agent('王小明')
     OR NOT public.fn_conv_est_non_agent('Collectif') OR NOT public.fn_conv_est_non_agent('---')
     OR NOT public.fn_conv_est_non_agent('') OR NOT public.fn_conv_est_non_agent(NULL) THEN
    RAISE EXCEPTION 'H27 : fn_conv_est_non_agent ne tranche pas comme attendu';
  END IF;
  IF position('ingest.fn_idioma_bcp47(rec.language)' IN pg_get_functiondef(
       'ingest.fn_create_book_drafts_from_import_rows(bigint,bigint[],text,text,uuid)'::regprocedure)) = 0
     OR position('Palavras-chave importadas' IN pg_get_functiondef(
       'ingest.fn_create_book_drafts_from_import_rows(bigint,bigint[],text,text,uuid)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'H27 : la création des brouillons n''a pas ses deux changements';
  END IF;
END $$;
