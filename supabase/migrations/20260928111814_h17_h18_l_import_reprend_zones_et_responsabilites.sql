-- =============================================================================
-- H17 / H18 / H22 — l'import reprend les zones courantes d'un catalogue PMB et
-- ses responsabilités (aller-retour PMB)
--
--  * H22 : le format « pmb_xml » (XML propre à PMB, lu par marc.ts) est admis.
--  * H18 : book_draft_contributors et book_contributors gagnent la nature
--    (personne, collectivité, congrès — le vocabulaire de authors.authority_type)
--    et le code de fonction d'origine ($4) ; la publication et la reprise les
--    recopient ; l'import crée les contributeurs (jusqu'ici : aucun, 0 sur les
--    1 673 brouillons du lot 63) ; les brouillons importés en cours qui n'en
--    ont pas en reçoivent depuis ce que l'import a gardé ; les rapprochements
--    d'autorité se PROPOSENT en révision (fn_batch_contributor_candidates),
--    jamais d'office.
--  * H17 : type de matériel déduit du guide, pages, volume, collection, notes,
--    classification, adresse, périodique et article dépouillé.
--
--  * Revue du 28/09 : la recherche par nom en une passe pour tout un lot
--    (fn_conv_autorites_homonymes) dans le rapport de révision et les
--    rapprochements ; la reprise d'une notice recopie ce que la publication
--    réécrit ; la scission d'autorité garde nature et code d'origine.
--
-- Fonctions recréées depuis leur définition réelle (md5 contrôlé) :
-- ingest.fn_create_book_drafts_from_import_rows (version H20),
-- fn_sync_book_contributors_on_publish, fn_seed_draft_contributors,
-- fn_batch_review_report, create_book_draft_from_book, fn_authority_split,
-- fn_fusion_notices (version H20).
-- =============================================================================

-- ── 1. H22 : le XML propre à PMB est un format admis ────────────────────────
-- process-partner-catalog-import écrit 'pmb_xml' pour un export « UNIMARC PMB
-- XML » (<unimarc><notice><f c=…>), que marc.ts lit désormais. Même défaut que
-- H28 : un format que l'EF écrit doit appartenir à la CHECK, sinon l'UPDATE
-- final du run échoue et ses lignes restent invisibles.
ALTER TABLE ingest.partner_catalog_import_runs
  DROP CONSTRAINT IF EXISTS partner_catalog_import_runs_detected_format_check;
ALTER TABLE ingest.partner_catalog_import_runs
  ADD CONSTRAINT partner_catalog_import_runs_detected_format_check
  CHECK (detected_format = ANY (ARRAY[
    'csv', 'tsv', 'xlsx', 'xls', 'ods', 'json', 'csl_json', 'ris',
    'bibtex', 'biblatex', 'mods', 'marcxml', 'xml', 'pdf', 'zip',
    'marc_iso2709',
    -- H22 (27/09/2026) : le XML propre à PMB, toujours de l'UNIMARC.
    'pmb_xml',
    'lookup',
    'oai_pmh',
    'unknown'
  ]));
COMMENT ON CONSTRAINT partner_catalog_import_runs_detected_format_check
  ON ingest.partner_catalog_import_runs IS
  'Formats de fichier, plus deux provenances SANS fichier : ''lookup'' (run '
  'alimente ligne a ligne par fn_import_ingest_candidate) et ''oai_pmh'' (run '
  'ne d''un moissonnage, dont le format reel n''est pas connu a sa naissance). '
  'Elargie le 28/08/2026, le 26/09/2026 a ''marc_iso2709'' (H28), le 27/09/2026 '
  'a ''pmb_xml'' (H22 : XML propre a PMB). UNIMARC/MARC21 est un vocabulaire '
  '(forced_vocabulary), pas un format.';

-- ── 2. H18 : la nature d'un contributeur et son code de fonction d'origine ──
-- nature : le vocabulaire de authors.authority_type (CONV-O7) — une personne,
-- une collectivité, un congrès — pour un contributeur qui n'est pas (encore)
-- rattaché à une autorité ; role_code : le code $4 (UNIMARC 070, 730…, MARC21
-- aut, trl…) tel que le fichier le portait, que l'export (H24) réémet.
ALTER TABLE public.book_draft_contributors
  ADD COLUMN IF NOT EXISTS nature text,
  ADD COLUMN IF NOT EXISTS role_code text;
ALTER TABLE public.book_draft_contributors DROP CONSTRAINT IF EXISTS book_draft_contributors_nature_check;
ALTER TABLE public.book_draft_contributors
  ADD CONSTRAINT book_draft_contributors_nature_check
  CHECK (nature IS NULL OR nature = ANY (ARRAY['person', 'collective', 'congress']));
ALTER TABLE public.book_contributors
  ADD COLUMN IF NOT EXISTS nature text,
  ADD COLUMN IF NOT EXISTS role_code text;
ALTER TABLE public.book_contributors DROP CONSTRAINT IF EXISTS book_contributors_nature_check;
ALTER TABLE public.book_contributors
  ADD CONSTRAINT book_contributors_nature_check
  CHECK (nature IS NULL OR nature = ANY (ARRAY['person', 'collective', 'congress']));
COMMENT ON COLUMN public.book_draft_contributors.nature IS
  'H18 : person | collective | congress (vocabulaire de authors.authority_type) ; NULL = inconnue. Une autorite rattachee dit la sienne.';
COMMENT ON COLUMN public.book_draft_contributors.role_code IS
  'H18 : code de fonction d''origine ($4 UNIMARC 070, 730… ; MARC21 aut, trl… ou le terme $e), garde tel quel pour l''export.';
COMMENT ON COLUMN public.book_contributors.nature IS
  'H18 : person | collective | congress ; recopie du brouillon a la publication.';
COMMENT ON COLUMN public.book_contributors.role_code IS
  'H18 : code de fonction d''origine, recopie du brouillon a la publication.';

-- ── 2 bis. Le nom d'un·e auteur·rice d'une ligne d'import ────────────────────
-- staging.authors porte des chaînes (CSV, RIS, MARC) ou des objets : la
-- recherche institutionnelle range {label, role…}, un paquet de fonds
-- {name, role, ord}, d'anciens imports {display, family, given}. Revue du
-- 28/09 : lus en texte, ces objets devenaient des contributeurs nommés en JSON.
CREATE OR REPLACE FUNCTION ingest.fn_h18_nom_d_auteur(p_auteur jsonb)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog'
AS $function$
  select nullif(btrim(case jsonb_typeof(p_auteur)
           when 'string' then p_auteur #>> '{}'
           when 'object' then coalesce(nullif(btrim(p_auteur->>'name'), ''), nullif(btrim(p_auteur->>'label'), ''),
                                       nullif(btrim(p_auteur->>'display'), ''),
                                       nullif(concat_ws(', ', nullif(btrim(p_auteur->>'family'), ''),
                                                              nullif(btrim(p_auteur->>'given'), '')), ''))
         end), '');
$function$;
REVOKE EXECUTE ON FUNCTION ingest.fn_h18_nom_d_auteur(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h18_nom_d_auteur(jsonb) TO service_role;

-- ── 2 ter. La recherche par nom, pour tout un lot en une passe ──────────────
-- La même règle que fn_conv_autorite_homonyme (LA recherche par nom du
-- catalogage : nom ou forme « Prénom Nom », contre sort_name, preferred_name et
-- la forme dérivée de sort_name ; les fiches de formation en dernier, puis la
-- plus ancienne) — mais pour un tableau de noms, en une jointure. Revue du
-- 28/09 : appelée nom par nom (≈ 40 ms), elle dépassait les 8 s du rôle
-- authenticated sur le lot 63 (≈ 1 700 contributeurs après H18).
CREATE OR REPLACE FUNCTION public.fn_conv_autorites_homonymes(p_noms text[])
 RETURNS TABLE(nom text, aid bigint)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  with c as materialized (
    select n.nom,
           lower(extensions.unaccent(btrim(regexp_replace(n.nom, '\s+', ' ', 'g')))) as k,
           case
             when n.nom ~ ', ' and (length(n.nom) - length(replace(n.nom, ',', ''))) = 1
                  and btrim(split_part(n.nom, ', ', 2)) <> ''
               then lower(extensions.unaccent(btrim(regexp_replace(split_part(n.nom, ', ', 2) || ' ' || split_part(n.nom, ', ', 1), '\s+', ' ', 'g'))))
             else lower(extensions.unaccent(btrim(regexp_replace(n.nom, '\s+', ' ', 'g'))))
           end as kd
      from (select distinct x as nom from unnest(p_noms) x where x is not null) n
  ), cles as materialized (
    select a.id, (coalesce(a.source_label, '') like 'formacao-%') as formation, v.k
      from public.authors a
      cross join lateral (values (lower(extensions.unaccent(btrim(a.sort_name)))),
                                 (lower(extensions.unaccent(btrim(a.preferred_name)))),
                                 (case when a.sort_name ~ ', '
                                       then lower(extensions.unaccent(btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1)))) end)) v(k)
     where v.k is not null
  )
  select distinct on (c.nom) c.nom, f.id
    from c
    cross join lateral (values (c.k), (c.kd)) ck(k)
    join cles f on f.k = ck.k
   where c.k <> ''
   order by c.nom, f.formation, f.id
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_conv_autorites_homonymes(text[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_conv_autorites_homonymes(text[]) TO service_role;
COMMENT ON FUNCTION public.fn_conv_autorites_homonymes(text[]) IS
  'H18 (28/09/2026) : fn_conv_autorite_homonyme pour un tableau de noms, en une jointure (rapport de revision, rapprochements proposes).';

-- ── Les fonctions recréées ─────────────────────────────────────────────────
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
      nullif(trim(rec.language), ''),
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
$function$;

CREATE OR REPLACE FUNCTION public.fn_sync_book_contributors_on_publish()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_prior jsonb;
BEGIN
  IF NEW.published_book_id IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.book_draft_contributors dc WHERE dc.draft_id = NEW.id) THEN
    RETURN NULL;
  END IF;

  -- Filet : author_id existants par nom normalise (repli quand le brouillon
  -- ne porte pas de lien explicite).
  SELECT jsonb_object_agg(nf, author_id) INTO v_prior
  FROM (
    SELECT public.fn_normalize_name(name) AS nf, max(author_id) AS author_id
    FROM public.book_contributors
    WHERE book_id = NEW.published_book_id AND author_id IS NOT NULL
    GROUP BY public.fn_normalize_name(name)
  ) s;

  DELETE FROM public.book_contributors WHERE book_id = NEW.published_book_id;

  -- H18 : la nature (personne, collectivité, congrès) et le code de fonction
  -- d'origine suivent le contributeur.
  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary, author_id, nature, role_code)
  SELECT NEW.published_book_id, dc.position, dc.name, dc.role, dc.is_primary,
         COALESCE(dc.author_id, NULLIF(v_prior ->> public.fn_normalize_name(dc.name), '')::bigint),
         dc.nature, dc.role_code
  FROM public.book_draft_contributors dc
  WHERE dc.draft_id = NEW.id
  ORDER BY dc.position, dc.id;

  RETURN NULL;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_seed_draft_contributors()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
  IF NEW.published_book_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.book_draft_contributors dc WHERE dc.draft_id = NEW.id) THEN
    -- H18 : nature et code d'origine suivent la reprise.
    INSERT INTO public.book_draft_contributors (draft_id, position, name, role, is_primary, author_id, nature, role_code)
    SELECT NEW.id, bc.position, bc.name, bc.role, bc.is_primary, bc.author_id, bc.nature, bc.role_code
    FROM public.book_contributors bc
    WHERE bc.book_id = NEW.published_book_id
    ORDER BY bc.position, bc.id;
  END IF;
  RETURN NULL;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_batch_review_report(p_batch_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'extensions'
AS $function$
declare
  v_batch      public.catalog_batches%rowtype;
  v_conv       jsonb := '[]'::jsonb;
  v_rule       record;
  v_items      jsonb;
  v_count      int;
  v_issues     int := 0;
  v_dup_isbn   jsonb;
  v_dup_meta   jsonb;
  v_dup_intra  jsonb;
  v_matching   jsonb;
  v_unlinked   jsonb;
  v_unlinked_n int;
  v_linkable_n int;
  v_title_n    int;
  v_from       text;
  v_sql        text;
  v_ctx        text;
  v_coverage   jsonb;
  v_items_import jsonb;
  v_items_admin boolean;
  v_items_staff uuid[];
  v_hint_err text;   -- B29
begin
  if not (public.fn_caller_is_network_admin()
          or exists (select 1 from public.user_library_memberships m
                      where m.user_id = auth.uid() and m.status = 'active'
                        and m.role in ('librarian', 'coordenador'))) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using hint = 'error.catalog.staff_only';
  end if;

  -- B30 (CAT-E18) : le rapport est au staff de la bibliothèque du lot (et à
  -- l'administration) — refus avant le test d'existence.
  if not public.fn_caller_owns_batch(p_batch_id) then
    raise exception 'Lote de outra biblioteca.' using hint = 'error.batch.other_libraries';
  end if;
  select * into v_batch from public.catalog_batches where id = p_batch_id;
  if not found then
    raise exception 'Lote % introuvable', p_batch_id using hint = 'error.review.batch_not_found';
  end if;

  -- Les brouillons vivants du lot : une fonction, pas une table temporaire.
  -- (Une table temporaire creee dans une RPC reveille pgrst_ddl_watch a
  -- chaque appel : rechargement du cache PostgREST, et l'ecran recevait un 400.)
  v_from := format('public.fn_batch_live_drafts(%s) d', p_batch_id);

  -- ── Conventions : une regle = un SELECT (id, titulo, valeur) sur `d` ──
  for v_rule in
    select * from (values
      ('titulo_missing',   $q$ select d.id, d.titulo, null::text from %s where d.titulo is null or btrim(d.titulo) = '' $q$),
      ('titulo_caps',      $q$ select d.id, d.titulo, d.titulo from %s where d.titulo = upper(d.titulo) and d.titulo ~ '[A-ZÀ-Þ]{4,}' $q$),
      ('titulo_article_end', $q$ select d.id, d.titulo, d.titulo from %s where d.titulo ~ ', (O|A|Os|As|Um|Uma|Le|La|Les|El|Los|Las|The)$' $q$),
      ('autor_missing',    $q$ select d.id, d.titulo, null::text from %s
                                where (d.autor is null or btrim(d.autor) = '')
                                  and not exists (select 1 from public.book_draft_contributors c where c.draft_id = d.id) $q$),
      ('autor_unstructured', $q$ select d.id, d.titulo, d.autor from %s
                                where d.autor is not null and btrim(d.autor) <> ''
                                  and not public.fn_conv_est_non_agent(d.autor)
                                  and not exists (select 1 from public.book_draft_contributors c where c.draft_id = d.id) $q$),
      ('contrib_non_agent', $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where public.fn_conv_est_non_agent(c.name) $q$),
      ('contrib_caps',     $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where c.name ~ '\m[A-ZÀ-Þ]{2,}\M' and c.name !~ '[A-ZÀ-Þ]\.' and not public.fn_conv_est_non_agent(c.name) $q$),
      ('contrib_direct_form', $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where c.name !~ ',' and btrim(c.name) ~ '\s' and not public.fn_conv_est_non_agent(c.name) $q$),
      ('ano_invalid',      $q$ select d.id, d.titulo, d.ano from %s
                                where d.approximate_date is null and (d.ano is null or d.ano !~ '^\d{4}$') $q$),
      ('editora_missing',  $q$ select d.id, d.titulo, null::text from %s where d.editora is null or btrim(d.editora) = '' $q$),
      ('idioma_missing',   $q$ select d.id, d.titulo, null::text from %s where d.idioma is null or btrim(d.idioma) = '' $q$),
      ('tipo_material_invalid', $q$ select d.id, d.titulo, d.tipo_material from %s
                                where d.tipo_material is null or lower(d.tipo_material) <> all (array['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine']) $q$),
      ('isbn_invalid',     $q$ select d.id, d.titulo, d.isbn from %s
                                where d.isbn is not null and btrim(d.isbn) <> ''
                                  and length(regexp_replace(upper(d.isbn), '[^0-9X]', '', 'g')) not in (10, 13) $q$),
      ('bib_ref_missing',  $q$ select d.id, d.titulo, null::text from %s where d.bib_ref is null or btrim(d.bib_ref) = '' $q$),
      ('subjects_missing', $q$ select d.id, d.titulo, null::text from %s
                                where (d.subjects is null or btrim(d.subjects) = '')
                                  and not exists (select 1 from public.book_draft_subjects s where s.book_draft_id = d.id) $q$)
    ) as r(rule, sql)
  loop
    v_sql := format(v_rule.sql, v_from);
    execute format('select count(*) from (%s) as q(id, titulo, v)', v_sql) into v_count;
    if v_count > 0 then
      execute format('select coalesce(jsonb_agg(jsonb_build_object(''draft_id'', t.id, ''titulo'', t.titulo, ''value'', t.v)), ''[]''::jsonb)
                        from (select q.id, q.titulo, q.v from (%s) as q(id, titulo, v) order by q.id limit 40) t', v_sql)
         into v_items;
      v_conv := v_conv || jsonb_build_object('rule', v_rule.rule, 'count', v_count, 'items', v_items);
      v_issues := v_issues + v_count;
    end if;
  end loop;

  -- Entree au titre (CONV-8) : informatif, pas un ecart.
  select count(*) into v_title_n from public.fn_batch_live_drafts(p_batch_id) d
   where d.autor is not null and public.fn_conv_est_non_agent(d.autor);

  -- ── Doublons contre le catalogue : ISBN, puis titre + auteur + annee ──
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_isbn from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'book_id', b.id, 'reason', 'isbn') as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.books b
        on regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g')
         = regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g')
     where coalesce(d.isbn, '') <> ''
       and (d.published_book_id is null or b.id <> d.published_book_id)
     order by d.id limit 40) s;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_meta from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'book_id', b.id, 'reason', 'titulo_autor_ano') as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.books b
        on lower(extensions.unaccent(btrim(coalesce(b.titulo, '')))) = lower(extensions.unaccent(btrim(coalesce(d.titulo, ''))))
       and coalesce(b.ano, '') = coalesce(d.ano, '')
       and lower(extensions.unaccent(btrim(coalesce(b.autor, '')))) = lower(extensions.unaccent(btrim(coalesce(d.autor, ''))))
     where coalesce(d.titulo, '') <> ''
       and (d.published_book_id is null or b.id <> d.published_book_id)
       and not (coalesce(d.isbn, '') <> '' and
                regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g')
              = regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g'))
     order by d.id limit 40) s;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_intra from (
    select jsonb_build_object('titulo', min(d.titulo), 'draft_ids', jsonb_agg(d.id order by d.id)) as x
      from public.fn_batch_live_drafts(p_batch_id) d
     where coalesce(d.titulo, '') <> ''
     group by lower(extensions.unaccent(btrim(d.titulo))),
              lower(extensions.unaccent(btrim(coalesce(d.autor, '')))),
              coalesce(d.ano, '')
    having count(*) > 1
     order by min(d.id) limit 40) s;

  select coalesce(jsonb_object_agg(match_status, n), '{}'::jsonb) into v_matching from (
    select sr.match_status, count(*) as n
      from ingest.partner_catalog_row_to_draft m
      join ingest.partner_catalog_staging_rows sr on sr.id = m.staging_row_id
     where m.batch_id = p_batch_id
     group by sr.match_status) s;

  -- ── Autorites : contributeurs non lies, et ceux qu'une fiche attend ──
  -- H18 (revue du 28/09/2026) : la recherche par nom en UNE passe pour tout le
  -- lot (fn_conv_autorites_homonymes, la regle de fn_conv_autorite_homonyme) ;
  -- appelee nom par nom (~40 ms), elle depassait les 8 s du role authenticated
  -- sur un lot de 1 700 contributeurs, et le rapport ne s'ouvrait plus.
  with nl as materialized (
    select d.id as draft_id, d.titulo, c.name
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.book_draft_contributors c on c.draft_id = d.id
     where c.author_id is null and not public.fn_conv_est_non_agent(c.name)
  ), h as materialized (
    select x.nom, x.aid from public.fn_conv_autorites_homonymes(array(select distinct nl.name from nl)) x
  )
  select count(*), count(h.aid)
    into v_unlinked_n, v_linkable_n
    from nl left join h on h.nom = nl.name;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_unlinked from (
    with nl as materialized (
      select d.id as draft_id, d.titulo, c.name
        from public.fn_batch_live_drafts(p_batch_id) d
        join public.book_draft_contributors c on c.draft_id = d.id
       where c.author_id is null and not public.fn_conv_est_non_agent(c.name)
    ), h as materialized (
      select x.nom, x.aid from public.fn_conv_autorites_homonymes(array(select distinct nl.name from nl)) x
    )
    select jsonb_build_object('draft_id', nl.draft_id, 'titulo', nl.titulo, 'name', nl.name,
                              'suggested_author_id', a.id, 'suggested_sort_name', a.sort_name) as x
      from nl
      left join h on h.nom = nl.name
      left join public.authors a on a.id = h.aid
     order by (a.id is null), nl.draft_id limit 40) s;

  -- ── H16 (26/09/2026) : ce que chaque import d'origine a repris ────────
  -- Pour chaque run dont ce lot est issu : les comptes (repris / indice /
  -- brut), l'encodage lu, les entrees ecartees, et SEULEMENT les zones,
  -- colonnes ou balises NON reprises (le rapport ne recopie pas tout le
  -- fichier). La couverture complete reste dans le summary du run.
  select coalesce(jsonb_agg(x order by (x->>'run_id')::bigint), '[]'::jsonb) into v_coverage from (
    select jsonb_build_object(
             'run_id', r.id,
             'original_filename', r.original_filename,
             'detected_format', r.detected_format,
             'counts', r.summary->'coverage_counts',
             'encoding', r.summary->'encoding',
             'skipped_rows', r.summary->'skipped_rows',
             'kind', r.summary->'coverage'->>'kind',
             'not_taken', coalesce(
               jsonb_path_query_array(r.summary->'coverage', '$.zones[*] ? (@.status != "repris")'),
               '[]'::jsonb)
               || coalesce(jsonb_path_query_array(r.summary->'coverage', '$.columns[*] ? (@.status != "repris")'), '[]'::jsonb)
               || coalesce(jsonb_path_query_array(r.summary->'coverage', '$.tags[*] ? (@.status != "repris")'), '[]'::jsonb)
           ) as x
      from ingest.partner_catalog_import_runs r
     where r.id in (select distinct m.run_id from ingest.partner_catalog_row_to_draft m where m.batch_id = p_batch_id)
  ) s;

  -- ── H19 (26-27/09/2026) : les exemplaires importés du lot ─────────────
  -- Ceux d'une notice promue (book_draft_id) et ceux d'un rapprochement
  -- (import_staging_row_id, sans notice). Ce qui empêcherait leur
  -- publication, dit AVANT : pas de bibliothèque ; bibliothèque autre que
  -- celle où la notice publiera ; pas de schéma de numérotation (fn_next_tombo
  -- lèverait) ; code d'origine déjà pris dans la bibliothèque ; présent deux
  -- fois dans le lot ; attendu par un brouillon vivant d'un AUTRE lot.
  -- En un passage (fenêtre, pas de sous-requête corrélée par ligne : un
  -- catalogue PMB entier passe dans un lot) ; 40 problèmes au plus, comme les
  -- autres sections, les comptes portent sur tout. « Code déjà pris » ne se
  -- calcule que pour une bibliothèque dont l'appelant est staff (ou pour
  -- l'administration du réseau) : ailleurs il renseignerait sur des
  -- exemplaires qu'il ne voit pas.
  v_items_admin := public.fn_caller_is_network_admin();
  select coalesce(array_agg(m.library_id), '{}'::uuid[]) into v_items_staff
    from public.user_library_memberships m
   where m.user_id = auth.uid() and m.status = 'active'
     and m.role in ('librarian', 'coordenador');

  with q0 as (
    select x.id, x.book_draft_id, x.source_item_code, x.target_library_id, x.tombo,
           coalesce(d.titulo, b.titulo) as titulo,
           case when d.id is not null
                then public.fn_book_draft_library(d.id) end as record_library,   -- B29 : sans repli sur qui regarde
           l.tombo_pattern,
           count(*) over (partition by x.target_library_id, x.source_item_code) as n_same_code
      from public.exemplar_drafts x
      left join public.book_drafts d on d.id = x.book_draft_id
      left join lateral (select bk.titulo from public.books bk
                          where x.book_draft_id is null and bk.bib_ref = x.target_bib_ref
                          limit 1) b on true
      left join public.libraries l on l.id = x.target_library_id
     where x.batch_id = p_batch_id
       and (x.book_draft_id is not null or x.import_staging_row_id is not null)
       and x.status in ('draft', 'ready')
       and (d.id is null or d.status in ('draft', 'ready'))
       -- B30 : hors administration, les exemplaires de la bibliothèque du lot
       -- (d'une notice : la bibliothèque de la notice ; d'un rapprochement : sa cible).
       and (v_items_admin
            or (d.id is null and x.target_library_id = v_batch.library_id)
            or (d.id is not null
                and coalesce(d.owner_library_id, private.fn_book_draft_creator_library(d.id, d.created_by))
                    is not distinct from v_batch.library_id))
  ), q as (
    select q0.*,
           case
             when q0.target_library_id is null then 'without_library'
             when q0.book_draft_id is not null
                  and q0.record_library is distinct from q0.target_library_id then 'library_mismatch'
             when q0.tombo_pattern is null and nullif(btrim(coalesce(q0.tombo, '')), '') is null then 'library_without_numbering'
             when q0.source_item_code is not null
                  and (v_items_admin or q0.target_library_id = any(v_items_staff))
                  and exists (select 1 from public.exemplares e
                               where e.library_id = q0.target_library_id
                                 and e.source_item_code = q0.source_item_code) then 'code_taken'
             when q0.source_item_code is not null and q0.n_same_code > 1 then 'code_twice'
             when q0.source_item_code is not null and exists (
                    select 1 from public.exemplar_drafts y
                     where y.target_library_id = q0.target_library_id
                       and y.source_item_code = q0.source_item_code
                       and y.batch_id is distinct from p_batch_id
                       and y.status in ('draft', 'ready')) then 'code_pending_elsewhere'
             else null
           end as reason
      from q0
  )
  select jsonb_build_object(
           'count', count(*),
           'with_code', count(*) filter (where q.source_item_code is not null),
           'without_library', count(*) filter (where q.reason = 'without_library'),
           'library_mismatch', count(*) filter (where q.reason = 'library_mismatch'),
           'library_without_numbering', count(*) filter (where q.reason = 'library_without_numbering'),
           'code_taken', count(*) filter (where q.reason = 'code_taken'),
           'code_twice', count(*) filter (where q.reason = 'code_twice'),
           'code_pending_elsewhere', count(*) filter (where q.reason = 'code_pending_elsewhere'),
           'problems', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'item_draft_id', p.id, 'draft_id', p.book_draft_id, 'titulo', p.titulo,
                      'source_item_code', p.source_item_code, 'reason', p.reason)
                    order by p.book_draft_id nulls last, p.id)
               from (select * from q where q.reason is not null
                      order by q.book_draft_id nulls last, q.id limit 40) p), '[]'::jsonb))
    into v_items_import
    from q;

  return jsonb_build_object(
    'batch', jsonb_build_object(
      'id', v_batch.id, 'name', v_batch.name, 'status', v_batch.status,
      'library_id', v_batch.library_id,   -- B30
      'library_name', (select coalesce(l.short_name, l.name) from public.libraries l where l.id = v_batch.library_id),
      'imported', public.fn_batch_is_imported(p_batch_id),
      'drafts_active', (select count(*) from public.fn_batch_live_drafts(p_batch_id)),
      'drafts_published', (select count(*) from public.book_drafts where batch_id = p_batch_id and status = 'published'),
      -- B30 : la corbeille de la bibliothèque du lot (les publiées : tout le lot, son historique).
      'drafts_cancelled', (select count(*) from public.book_drafts d where d.batch_id = p_batch_id and d.status = 'cancelled'
                             and (v_items_admin
                                  or coalesce(d.owner_library_id, private.fn_book_draft_creator_library(d.id, d.created_by))
                                     is not distinct from v_batch.library_id)),
      'title_entries', v_title_n),
    'generated_at', now(),
    'coverage', v_coverage,
    'items', v_items_import,
    'conventions', v_conv,
    'duplicates', jsonb_build_object(
      'catalog_isbn', v_dup_isbn,
      'catalog_meta', v_dup_meta,
      'intra_lot', v_dup_intra,
      'import_matching', v_matching),
    'authorities', jsonb_build_object(
      'unlinked_count', v_unlinked_n,
      'linkable_count', v_linkable_n,
      'unlinked', v_unlinked),
    'totals', jsonb_build_object(
      'convention_issues', v_issues,
      'duplicates', jsonb_array_length(v_dup_isbn) + jsonb_array_length(v_dup_meta) + jsonb_array_length(v_dup_intra),
      'unlinked_authorities', v_unlinked_n)
  );
exception when others then
  -- Le contexte de l'erreur remonte a l'ecran : la prochaine panne dira ou.
  get stacked diagnostics v_ctx = pg_exception_context, v_hint_err = pg_exception_hint;
  -- B29 : un refus métier (HINT 'error.…' : staff, lot d'autres bibliothèques)
  -- remonte tel quel, traduisible par l'écran ; une panne, avec son contexte.
  if v_hint_err like 'error.%' then
    raise exception '%', sqlerrm using errcode = sqlstate, hint = v_hint_err;
  end if;
  -- Pas de HINT i18n ici : l'ecran afficherait la cle traduite et perdrait le
  -- message ; le texte brut, lui, dit ou ca casse.
  raise exception '% [%] @ %', sqlerrm, sqlstate, left(regexp_replace(v_ctx, E'\\s+', ' ', 'g'), 240)
    using errcode = sqlstate;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_book_draft_from_book(p_book_id bigint, p_batch_id bigint DEFAULT NULL::bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id bigint;
begin
  -- B29 (CAT-E18) : reprendre une notice publiée crée un brouillon de SA
  -- bibliothèque — celle de la notice si l'on y est staff, sinon la sienne
  -- (catalogue partagé : une bibliothèque qui détient le livre peut en
  -- proposer une reprise ; la publication ne touche pas owner_library_id).
  if not (public.fn_caller_is_network_admin()
          or cardinality(public.fn_caller_staff_library_ids()) > 0) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using hint = 'error.catalog.staff_only';
  end if;
  -- B30 : dans un lot de la bibliothèque du brouillon (celle de la notice si
  -- l'on y est staff, sinon la sienne) où l'on est staff.
  if p_batch_id is not null and not public.fn_caller_can_range_in_batch(p_batch_id,
       (select case when public.fn_caller_is_network_admin()
                         or b.owner_library_id = any (public.fn_caller_staff_library_ids())
                    then b.owner_library_id
                    else public.fn_user_staff_library((select auth.uid())) end
          from public.books b where b.id = p_book_id)) then
    if public.fn_caller_can_see_batch(p_batch_id) then   -- B30
      raise exception 'Rascunho de outra biblioteca do que a do lote.' using errcode = '42501', hint = 'error.batch.library_mismatch';
    end if;
    raise exception 'Lote com rascunhos de outras bibliotecas.' using hint = 'error.batch.other_libraries';
  end if;
  insert into public.book_drafts (
    published_book_id, batch_id, action, status,
    bib_ref, titulo, subtitulo, autor, edicao, local_publicacao, editora, ano,
    isbn, issn, serial_id, titulo_periodico, volume, numero, fasciculo, data_edicao, periodicidade,
    cdd, idioma, paginas, notas, tipo_material, loanable, colecao,
    cover_object_path, cover_source, cover_license, marc_json,
    acquisition_mode, acquisition_date,
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
    -- H17/H18 (revue du 28/09) : ce que publish_book_draft réécrit tel quel
    artigo_source, artigo_volume, artigo_issue, artigo_pages,
    tese_university, tese_advisor, relatorio_org, relatorio_recipient, relatorio_internal_notes,
    zine_format, zine_print_run, zine_technique, distribuidora, gravadora, subjects,
    created_by, updated_by
  )
  select
    b.id, p_batch_id, 'update', 'draft',
    b.bib_ref, b.titulo, b.subtitulo, b.autor, b.edicao, b.local_publicacao, b.editora, b.ano,
    b.isbn, b.issn, b.serial_id, b.titulo_periodico, b.volume, b.numero, b.fasciculo, b.data_edicao, b.periodicidade,
    b.cdd, b.idioma, b.paginas, b.notas, b.tipo_material, b.loanable, b.colecao,
    b.cover_object_path, b.cover_source, b.cover_license, coalesce(b.marc_json, '{}'::jsonb),
    b.acquisition_mode, b.acquisition_date,
    b.owner_library, b.holder_library,
    case when public.fn_caller_is_network_admin()
              or b.owner_library_id = any (public.fn_caller_staff_library_ids())
         then b.owner_library_id
         else public.fn_user_staff_library((select auth.uid())) end,
    b.holder_library_id,
    b.partner_source, b.source_record_id, b.source_record_url,
    b.import_format, b.import_method, b.provenance_note, b.mutualization_status, b.source_label,
    b.tract_campaign, b.emitter_org, b.approximate_date, b.diffusion_place,
    b.recto_verso, b.physical_format, b.print_technique, b.physical_state,
    b.audio_duration, b.audio_support, b.audio_format, b.audio_language,
    b.audio_participants, b.audio_recording_type,
    b.audiovisual_duration, b.audiovisual_support, b.audiovisual_language,
    b.audiovisual_director, b.audiovisual_participants, b.audiovisual_subtitles,
    b.audiovisual_access_note,
    b.digital_native_url, b.digital_native_access, b.digital_native_restriction,
    b.digital_native_usage, b.digital_native_file_note,
    b.dossier_scope, b.dossier_period, b.dossier_organizations, b.dossier_context,
    b.artigo_source, b.artigo_volume, b.artigo_issue, b.artigo_pages,
    b.tese_university, b.tese_advisor, b.relatorio_org, b.relatorio_recipient, b.relatorio_internal_notes,
    b.zine_format, b.zine_print_run, b.zine_technique, b.distribuidora, b.gravadora, b.subjects,
    auth.uid(), auth.uid()
  from public.books b
  where b.id = p_book_id
  returning id into v_id;

  if v_id is null then
    raise exception 'Livro nao encontrado: %', p_book_id;
  end if;

  perform public.copy_book_digital_resources_to_draft(p_book_id, v_id);

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_authority_split(p_author_id bigint, p_parts jsonb, p_avant text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_part  jsonb;
  v_new   bigint;
  v_i     int := 0;
  v_crees bigint := 0;
  v_pref0 text;
  v_sort0 text;
  v_type0 text;
  v_actuel text;
  v_noms  text;
begin
  select a.sort_name into v_actuel from public.authors a where a.id = p_author_id for update;
  if not found then raise exception 'split_target_not_found'; end if;

  -- Anti-écrasement (CONV-O6) : la fiche a-t-elle bougé depuis la
  -- proposition ? Quatorze jours, c'est le temps qu'il faut pour que
  -- quelqu'un d'autre la corrige entre-temps. Écrire quand même
  -- effacerait son travail sans que personne ne le voie.
  if p_avant is not null and v_actuel is distinct from p_avant then
    raise exception 'split_target_changed: % (proposition faite sur « % »)', v_actuel, p_avant
      using hint = 'atelier.error.splitTargetChanged';
  end if;

  -- Le nom composé recomposé, pour réparer le champ libre `books.autor`.
  select string_agg(btrim(x ->> 'sort_name'), ' ; ' order by x.ord)
    into v_noms
    from jsonb_array_elements(p_parts) with ordinality as x(x, ord);

  -- ── Part 0 : la fiche d'origine, renommée ─────────────────────────
  v_part  := p_parts -> 0;
  v_pref0 := btrim(v_part ->> 'preferred_name');
  v_sort0 := btrim(v_part ->> 'sort_name');
  v_type0 := coalesce(v_part ->> 'authority_type', 'person');

  update public.authors
     set preferred_name  = v_pref0,
         sort_name       = v_sort0,
         authority_type  = v_type0,
         structured_meta = jsonb_set(coalesce(structured_meta, '{}'::jsonb),
                                     '{authorityType}', to_jsonb(v_type0), true),
         updated_at      = now(),
         updated_by      = auth.uid()
   where id = p_author_id;

  -- `book_contributors.name` est une COPIE du nom, pas une jointure :
  -- sans cette ligne la fiche serait scindée et le livre continuerait
  -- d'afficher le nom composé.
  update public.book_contributors
     set name = v_pref0, updated_at = now()
   where author_id = p_author_id;

  -- ── Parts 1..n : fiches créées, liaisons recopiées ────────────────
  for v_part in select * from jsonb_array_elements(p_parts) offset 1 loop
    v_i := v_i + 1;

    insert into public.authors (preferred_name, sort_name, authority_type, structured_meta)
    values (btrim(v_part ->> 'preferred_name'),
            btrim(v_part ->> 'sort_name'),
            coalesce(v_part ->> 'authority_type', 'person'),
            jsonb_build_object('authorityType', coalesce(v_part ->> 'authority_type', 'person')))
    returning id into v_new;
    v_crees := v_crees + 1;

    -- `ord` doit rester libre dans (book_id, author_id, role, ord).
    -- `row_number()` en plus du max : si la fiche d'origine figure DEUX
    -- fois sur le même livre (deux rôles), un max seul donnerait deux
    -- fois la même valeur et la clé primaire sauterait.
    insert into public.book_authors (book_id, author_id, role, ord)
    select ba.book_id, v_new, ba.role,
           ((select coalesce(max(b2.ord), 0) from public.book_authors b2 where b2.book_id = ba.book_id)
            + row_number() over (partition by ba.book_id order by ba.ord, ba.role))::smallint
      from public.book_authors ba
     where ba.author_id = p_author_id
    on conflict do nothing;

    -- H18 : la nature est celle de la part (sa fiche) ; le code de fonction
    -- d'origine suit la liaison recopiée.
    insert into public.book_contributors (book_id, author_id, position, name, role, is_primary, nature, role_code)
    select bc.book_id, v_new,
           ((select coalesce(max(c2.position), 0) from public.book_contributors c2 where c2.book_id = bc.book_id)
            + row_number() over (partition by bc.book_id order by bc.position))::int,
           btrim(v_part ->> 'preferred_name'), bc.role, false,
           coalesce(v_part ->> 'authority_type', 'person'), bc.role_code
      from public.book_contributors bc
     where bc.author_id = p_author_id
    on conflict do nothing;
  end loop;

  -- ── Le champ libre `books.autor` ──────────────────────────────────
  -- Déprécié (CONV-O3) mais toujours affiché : le laisser porter le nom
  -- composé après la scission serait réparer à moitié. Réécrit seulement
  -- s'il vaut EXACTEMENT l'ancien nom — s'il dit autre chose, quelqu'un
  -- l'a saisi à la main et ce n'est pas à nous de l'écraser.
  update public.books b
     set autor = v_noms
    from public.book_authors ba
   where ba.book_id = b.id
     and ba.author_id = p_author_id
     and p_avant is not null
     and b.autor = p_avant;

  return v_crees;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_fusion_notices(p_canonical_id bigint, p_duplicate_id bigint, p_champs text[] DEFAULT '{}'::text[], p_reprendre_vides boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_c         public.books%rowtype;   -- la notice gardée, AVANT la fusion
  v_d         public.books%rowtype;   -- le doublon
  v_snap      jsonb;
  v_col       text;
  v_n         int;
  v_choisis   text[] := '{}';
  v_repris    text[] := '{}';
  v_sujets    int := 0;
  v_contrib   int := 0;
  v_ecartes   int := 0;
  v_ouverts   bigint[];
  dh          record;
  v_ch        bigint;
  v_ref_avant text;
  v_ref_apres text;
begin
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  -- Garde de rattachement (2026-08-20, durcie le 2026-08-21) : fusionner deux
  -- notices qui appartiennent à d'autres bibliothèques que la sienne engage des
  -- collectifs dont on n'est pas membre.
  IF NOT EXISTS (SELECT 1 FROM public.network_administrators na
                  WHERE na.user_id = auth.uid() AND na.status = 'active')
     AND EXISTS (SELECT 1 FROM public.book_holdings h
                 WHERE h.book_id IN (p_canonical_id, p_duplicate_id))
     AND NOT EXISTS (
       SELECT 1
       FROM public.book_holdings h
       JOIN public.user_library_memberships m
         ON m.library_id = h.library_id
        AND m.user_id = auth.uid()
        AND m.status = 'active'
        AND m.role = 'coordenador'
       WHERE h.book_id IN (p_canonical_id, p_duplicate_id)
     ) THEN
    RAISE EXCEPTION 'Fusao restrita a coordenacao de uma das bibliotecas detentoras (ou a administracao da rede).'
      USING ERRCODE = '42501', HINT = 'error.catalog.merge_not_related';
  END IF;

  IF p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Canonico e duplicado identicos.';
  END IF;
  SELECT * INTO v_d FROM public.books WHERE id = p_duplicate_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Duplicado % inexistente.', p_duplicate_id;
  END IF;
  SELECT * INTO v_c FROM public.books WHERE id = p_canonical_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Canonico % inexistente.', p_canonical_id;
  END IF;

  -- 0. Le doublon, gardé ENTIER, avant tout changement.
  v_snap := jsonb_build_object(
    'duplicate_titulo', v_d.titulo,
    'notice', to_jsonb(v_d),
    'sujets', (select coalesce(jsonb_agg(to_jsonb(s) order by s.ord), '[]'::jsonb)
                 from public.book_subjects s where s.book_id = p_duplicate_id),
    'contributeurs', (select coalesce(jsonb_agg(to_jsonb(x) order by x.position), '[]'::jsonb)
                        from public.book_contributors x where x.book_id = p_duplicate_id),
    'contexte_catalogage', (select to_jsonb(x) from public.book_catalog_context x where x.book_id = p_duplicate_id),
    'fonds', (select coalesce(jsonb_agg(to_jsonb(h)), '[]'::jsonb)
                from public.book_holdings h where h.book_id = p_duplicate_id),
    'exemplaires', (select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb)
                      from public.exemplares e join public.book_holdings h on h.id = e.holding_id
                     where h.book_id = p_duplicate_id),
    'brouillons', (select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'status', d.status, 'action', d.action)), '[]'::jsonb)
                     from public.book_drafts d where d.published_book_id = p_duplicate_id),
    'couverture_proposee', (select to_jsonb(cp) from public.cover_proposals cp where cp.book_id = p_duplicate_id));

  -- 1. Les champs CHOISIS (assistant) : la valeur du doublon remplace. La
  --    validation (champ inconnu, non reprenable) est faite par l'appelant.
  for v_col in select distinct c from unnest(coalesce(p_champs, '{}'::text[])) c
                where nullif(btrim(c), '') is not null
  loop
    execute format('update public.books g set %1$I = d.%1$I from public.books d where g.id = $1 and d.id = $2', v_col)
      using p_canonical_id, p_duplicate_id;
    v_choisis := v_choisis || v_col;
  end loop;

  -- 2. Les champs VIDES de la notice gardée (merge_book) : ceux du doublon.
  --    Jamais par-dessus une valeur : la notice gardée décide. Un titre de
  --    périodique (serial_id) ne se pose que sur un fascicule ou un article.
  if p_reprendre_vides then
    for v_col in
      select c.column_name from information_schema.columns c
       where c.table_schema = 'public' and c.table_name = 'books' and c.is_generated = 'NEVER'
         and c.column_name <> all (public.fn_dedup_non_transferable_fields())
         and c.column_name <> all (v_choisis)
         and (c.column_name <> 'serial_id' or v_c.tipo_material in ('periodico', 'artigo'))
       order by c.ordinal_position
    loop
      execute format(
        'update public.books g set %1$I = d.%1$I from public.books d
          where g.id = $1 and d.id = $2
            and nullif(btrim(coalesce(g.%1$I::text, '''')), '''') is null
            and nullif(btrim(coalesce(d.%1$I::text, '''')), '''') is not null', v_col)
        using p_canonical_id, p_duplicate_id;
      get diagnostics v_n = row_count;
      if v_n > 0 then v_repris := v_repris || v_col; end if;
    end loop;
  end if;

  -- 3. Les brouillons OUVERTS de la notice gardée reçoivent ce qu'elle vient de
  --    recevoir, là où ils n'ont rien changé (valeur vide, ou encore celle de
  --    la notice avant la fusion) : publiés ensuite, ils l'auraient effacé.
  select array_agg(d.id) into v_ouverts
    from public.book_drafts d
   where d.published_book_id = p_canonical_id and d.status not in ('published', 'cancelled');
  if v_ouverts is not null then
    for v_col in
      select c from unnest(v_choisis || v_repris) c
       where exists (select 1 from information_schema.columns b
                       join information_schema.columns bd
                         on bd.table_schema = 'public' and bd.table_name = 'book_drafts'
                        and bd.column_name = b.column_name and bd.data_type = b.data_type
                      where b.table_schema = 'public' and b.table_name = 'books' and b.column_name = c)
    loop
      execute format(
        'update public.book_drafts bd set %1$I = g.%1$I
           from public.books g
          where g.id = $1 and bd.id = any ($2)
            and (nullif(btrim(coalesce(bd.%1$I::text, '''')), '''') is null
                 or bd.%1$I::text is not distinct from $3)
            and (%2$L <> ''serial_id'' or bd.tipo_material in (''periodico'', ''artigo''))', v_col, v_col)
        using p_canonical_id, v_ouverts, (to_jsonb(v_c) ->> v_col);
    end loop;
  end if;

  -- 4. Sujets et contributeur·rices du doublon qui manquent — à la notice
  --    gardée, et à ses brouillons ouverts (leur publication les remplace).
  insert into public.book_subjects (book_id, subject_id, ord)
  select p_canonical_id, s.subject_id,
         coalesce((select max(t.ord) from public.book_subjects t where t.book_id = p_canonical_id), 0)
           + row_number() over (order by s.ord, s.subject_id)
    from public.book_subjects s
   where s.book_id = p_duplicate_id
     and not exists (select 1 from public.book_subjects t
                      where t.book_id = p_canonical_id and t.subject_id = s.subject_id);
  get diagnostics v_sujets = row_count;

  -- H18 : la nature et le code de fonction d'origine suivent le contributeur.
  insert into public.book_contributors (book_id, author_id, position, name, role, is_primary, nature, role_code)
  select p_canonical_id, x.author_id,
         coalesce((select max(t.position) from public.book_contributors t where t.book_id = p_canonical_id), 0)
           + row_number() over (order by x.position, x.id),
         x.name, x.role, false, x.nature, x.role_code
    from public.book_contributors x
   where x.book_id = p_duplicate_id
     and not exists (select 1 from public.book_contributors t
                      where t.book_id = p_canonical_id
                        and coalesce(t.role, '') = coalesce(x.role, '')
                        and ((t.author_id is not null and t.author_id = x.author_id)
                             or public.fn_normalize_name(t.name) = public.fn_normalize_name(x.name)));
  get diagnostics v_contrib = row_count;

  if v_ouverts is not null then
    insert into public.book_draft_subjects (book_draft_id, subject_id, ord)
    select bd, s.subject_id,
           coalesce((select max(t.ord) from public.book_draft_subjects t where t.book_draft_id = bd), 0)
             + row_number() over (partition by bd order by s.ord, s.subject_id)
      from unnest(v_ouverts) bd
      cross join public.book_subjects s
     where s.book_id = p_duplicate_id
       and not exists (select 1 from public.book_draft_subjects t
                        where t.book_draft_id = bd and t.subject_id = s.subject_id);

    -- Un brouillon sans contributeur·rices ne touche pas ceux de la notice à la
    -- publication (fn_sync_book_contributors_on_publish) : on ne lui en ajoute pas.
    insert into public.book_draft_contributors (draft_id, author_id, position, name, role, is_primary, nature, role_code)
    select bd, x.author_id,
           coalesce((select max(t.position) from public.book_draft_contributors t where t.draft_id = bd), 0)
             + row_number() over (partition by bd order by x.position, x.id),
           x.name, x.role, false, x.nature, x.role_code
      from unnest(v_ouverts) bd
      cross join public.book_contributors x
     where x.book_id = p_duplicate_id
       and exists (select 1 from public.book_draft_contributors t0 where t0.draft_id = bd)
       and not exists (select 1 from public.book_draft_contributors t
                        where t.draft_id = bd
                          and coalesce(t.role, '') = coalesce(x.role, '')
                          and ((t.author_id is not null and t.author_id = x.author_id)
                               or public.fn_normalize_name(t.name) = public.fn_normalize_name(x.name)));
  end if;

  -- 5. Brouillons du doublon : l'ouvert est écarté (rattaché puis publié, il
  --    écraserait la notice gardée) ; tous suivent la notice gardée.
  update public.book_drafts set status = 'cancelled'
   where published_book_id = p_duplicate_id and status not in ('published', 'cancelled');
  get diagnostics v_ecartes = row_count;
  update public.book_drafts set published_book_id = p_canonical_id where published_book_id = p_duplicate_id;

  -- 6. Fonds et exemplaires. Un fonds du doublon dans une bibliothèque où la
  --    notice gardée en a déjà un : ses exemplaires et ses lignes rejoignent
  --    celui-ci (sa référence locale et ses notes aussi, si le fonds gardé n'en
  --    a pas), et il disparaît. Sinon il passe sous la notice gardée. Dans les
  --    deux cas la référence des exemplaires suit par déclencheur (fonds
  --    modifié) ; celle des lignes déplacées suit ici.
  for dh in select * from public.book_holdings where book_id = p_duplicate_id loop
    v_ref_avant := coalesce(nullif(btrim(dh.local_bib_ref), ''), v_d.bib_ref);
    select id into v_ch from public.book_holdings
     where book_id = p_canonical_id and library_id = dh.library_id order by id limit 1;
    if v_ch is not null then
      update public.exemplares set holding_id = v_ch where holding_id = dh.id;
      update public.exemplar_drafts            set target_holding_id = v_ch where target_holding_id = dh.id;
      update public.emprestimo_itens_v2        set holding_id = v_ch where holding_id = dh.id;
      update public.reserva_linhas_v2          set holding_id = v_ch where holding_id = dh.id;
      update public.interlibrary_loan_items_v2 set holding_id = v_ch where holding_id = dh.id;
      update public.consulta_linhas_v2         set holding_id = v_ch where holding_id = dh.id;
      delete from public.book_holdings where id = dh.id;
      -- (après la suppression : la référence locale est unique par bibliothèque)
      update public.book_holdings h
         set local_bib_ref = coalesce(nullif(btrim(h.local_bib_ref), ''), nullif(btrim(dh.local_bib_ref), '')),
             notes         = coalesce(nullif(btrim(h.notes), ''), dh.notes)
       where h.id = v_ch
         and ((nullif(btrim(h.local_bib_ref), '') is null and nullif(btrim(dh.local_bib_ref), '') is not null)
              or (nullif(btrim(h.notes), '') is null and nullif(btrim(dh.notes), '') is not null));
      select coalesce(nullif(btrim(h.local_bib_ref), ''), g.bib_ref) into v_ref_apres
        from public.book_holdings h join public.books g on g.id = h.book_id where h.id = v_ch;
      update public.emprestimo_itens_v2        set bib_ref = v_ref_apres where holding_id = v_ch and bib_ref = v_ref_avant;
      update public.reserva_linhas_v2          set bib_ref = v_ref_apres where holding_id = v_ch and bib_ref = v_ref_avant;
      update public.interlibrary_loan_items_v2 set bib_ref = v_ref_apres where holding_id = v_ch and bib_ref = v_ref_avant;
      update public.consulta_linhas_v2         set bib_ref = v_ref_apres where holding_id = v_ch and bib_ref = v_ref_avant;
    else
      -- Le déclencheur du fonds aligne exemplaires et lignes sur la nouvelle notice.
      update public.book_holdings set book_id = p_canonical_id where id = dh.id;
    end if;
    v_ch := null;
  end loop;
  -- Les exemplaires encore à créer qui visaient le doublon par sa référence.
  update public.exemplar_drafts set target_bib_ref = v_c.bib_ref
   where target_bib_ref = v_d.bib_ref and status in ('draft', 'ready')
     and v_d.bib_ref is not null and v_c.bib_ref is not null;

  -- 7. Tout ce qui désigne encore le doublon suit la notice gardée.
  update public.emprestimo_itens_v2        set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.reserva_linhas_v2          set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.interlibrary_loan_items_v2 set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.consulta_linhas_v2         set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.digital_assets             set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.ill_digital_shares         set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.work_titles                set source_book_id = p_canonical_id where source_book_id = p_duplicate_id;
  update ingest.partner_catalog_staging_rows set proposed_book_id = p_canonical_id where proposed_book_id = p_duplicate_id;
  update public.audio_tracks a
     set book_id = p_canonical_id,
         position = a.position + coalesce((select max(t.position) from public.audio_tracks t where t.book_id = p_canonical_id), 0)
   where a.book_id = p_duplicate_id;
  delete from public.user_wishlist w
   where w.book_id = p_duplicate_id
     and exists (select 1 from public.user_wishlist w2 where w2.user_id = w.user_id and w2.book_id = p_canonical_id);
  update public.user_wishlist set book_id = p_canonical_id where book_id = p_duplicate_id;
  -- Une par notice : celle du doublon ne vaut que si la notice gardée n'en a pas.
  update public.cover_proposals set book_id = p_canonical_id
   where book_id = p_duplicate_id
     and not exists (select 1 from public.cover_proposals where book_id = p_canonical_id);
  update public.book_catalog_context set book_id = p_canonical_id
   where book_id = p_duplicate_id
     and not exists (select 1 from public.book_catalog_context where book_id = p_canonical_id);

  -- H20 (revue du 28/09/2026) : les identifiants d'origine du doublon (le
  -- numéro que la source de chaque bibliothèque lui donnait) passent à la
  -- notice gardée ; la suppression ci-dessous les emportait en cascade. Pas de
  -- conflit possible : la clé unique (bibliothèque, schéma, valeur) ne
  -- contient pas la notice.
  update public.book_external_ids set book_id = p_canonical_id, updated_at = now()
   where book_id = p_duplicate_id;

  -- 8. La trace : le doublon entier, et ce que la fusion a repris.
  insert into public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  values ('book', p_canonical_id, p_duplicate_id,
          v_snap || jsonb_build_object(
            'champs_choisis', to_jsonb(v_choisis), 'champs_repris', to_jsonb(v_repris),
            'sujets_repris', v_sujets, 'contributeurs_repris', v_contrib,
            'brouillons_ecartes', v_ecartes),
          auth.uid());

  -- 9. Supprimer le doublon (cascade : ce qui n'a pas été repris, et qui est
  --    dans merge_log), recalculer la disponibilité.
  delete from public.books where id = p_duplicate_id;
  perform public.fn_v2_recompute_holdings_availability(null, array[p_canonical_id]);

  return jsonb_build_object(
    'champs_choisis', to_jsonb(v_choisis), 'champs_repris', to_jsonb(v_repris),
    'sujets_repris', v_sujets, 'contributeurs_repris', v_contrib, 'brouillons_ecartes', v_ecartes);
end;
$function$;

-- ── 3. Les brouillons importés en cours qui n'ont aucun contributeur ────────
-- L'import n'en créait aucun (0 sur les 1 673 brouillons du lot 63 le 27/09) :
-- publiées en l'état, ces notices n'auraient eu aucun contributeur. On les
-- crée depuis ce que l'import a gardé : les responsabilités structurées de la
-- ligne (marc_json.contributors, MARC) ; sinon ses noms (marc_json.ingest.
-- authors : chaînes, ou objets de la recherche institutionnelle et des
-- paquets de fonds), en auteur·rice. Jamais un non-agent (« Collectif »,
-- « Vários » : CONV-8 les avait retirés ; la notice reste une entrée au titre).
-- Rien de publié n'est touché ; un brouillon qui a déjà un contributeur (saisi
-- à la main) non plus. Une fonction nommée : la suite SQL l'éprouve.
CREATE OR REPLACE FUNCTION ingest.fn_h18_contributeurs_des_brouillons_importes()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_structures integer;
  v_noms integer;
BEGIN
  INSERT INTO public.book_draft_contributors (draft_id, position, name, role, is_primary, nature, role_code)
  SELECT d.id, row_number() OVER (PARTITION BY d.id ORDER BY c.ord)::integer, left(btrim(c.value->>'name'), 500),
         CASE WHEN c.value->>'role' = ANY (ARRAY['autor','coautor','organizacao','organizador','tradutor',
              'ilustrador','prefaciador','coordenador','editor','realizador','roteirista','ator','interprete',
              'compositor','narrador','produtor','locutor','outro']) THEN c.value->>'role' ELSE 'outro' END,
         row_number() OVER (PARTITION BY d.id ORDER BY c.ord) = 1 AND (c.value->'primary') IS DISTINCT FROM 'false'::jsonb,
         CASE WHEN c.value->>'nature' IN ('person', 'collective', 'congress') THEN c.value->>'nature' END,
         nullif(left(btrim(c.value->>'role_code'), 40), '')
    FROM public.book_drafts d
    CROSS JOIN LATERAL jsonb_array_elements(d.marc_json->'contributors') WITH ORDINALITY AS c(value, ord)
   WHERE d.marc_json ? 'ingest' AND d.status IN ('draft', 'ready')
     AND jsonb_typeof(d.marc_json->'contributors') = 'array'
     AND jsonb_typeof(c.value) = 'object' AND nullif(btrim(c.value->>'name'), '') IS NOT NULL
     AND NOT public.fn_conv_est_non_agent(c.value->>'name')
     AND NOT EXISTS (SELECT 1 FROM public.book_draft_contributors x WHERE x.draft_id = d.id);
  GET DIAGNOSTICS v_structures = ROW_COUNT;

  INSERT INTO public.book_draft_contributors (draft_id, position, name, role, is_primary)
  SELECT d.id, row_number() OVER (PARTITION BY d.id ORDER BY a.ord)::integer, left(n.nom, 500),
         CASE WHEN a.value->>'role' = ANY (ARRAY['autor','coautor','organizacao','organizador','tradutor',
              'ilustrador','prefaciador','coordenador','editor','realizador','roteirista','ator','interprete',
              'compositor','narrador','produtor','locutor','outro']) THEN a.value->>'role' ELSE 'autor' END,
         row_number() OVER (PARTITION BY d.id ORDER BY a.ord) = 1
    FROM public.book_drafts d
    CROSS JOIN LATERAL jsonb_array_elements(d.marc_json->'ingest'->'authors') WITH ORDINALITY AS a(value, ord)
    CROSS JOIN LATERAL (SELECT ingest.fn_h18_nom_d_auteur(a.value) AS nom) n
   WHERE d.marc_json ? 'ingest' AND d.status IN ('draft', 'ready')
     AND jsonb_typeof(d.marc_json->'ingest'->'authors') = 'array'
     AND n.nom IS NOT NULL AND NOT public.fn_conv_est_non_agent(n.nom)
     AND NOT EXISTS (SELECT 1 FROM public.book_draft_contributors x WHERE x.draft_id = d.id);
  GET DIAGNOSTICS v_noms = ROW_COUNT;
  RETURN v_structures + v_noms;
END;
$function$;
REVOKE EXECUTE ON FUNCTION ingest.fn_h18_contributeurs_des_brouillons_importes() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h18_contributeurs_des_brouillons_importes() TO service_role;

DO $h18$
DECLARE v_n integer;
BEGIN
  v_n := ingest.fn_h18_contributeurs_des_brouillons_importes();
  RAISE NOTICE 'H18 : % contributeur(s) créé(s) sur les brouillons importés en cours qui n''en avaient aucun.', v_n;
END
$h18$;

-- ── 4. Rapprochements d'autorité PROPOSÉS en révision de lot ────────────────
-- Pour les contributeurs sans autorité des brouillons en cours d'un lot (ceux
-- de la bibliothèque du lot, comme le rapport : fn_batch_live_drafts), la
-- fiche que la recherche par nom propose (fn_conv_autorites_homonymes : la
-- règle de fn_conv_autorite_homonyme, en une passe pour tout le lot). Un
-- congrès importé porte « Nom (numéro ; date ; lieu) » ; ses autorités sont
-- nues : on cherche aussi le nom seul. Rien n'est rattaché ici : l'écran
-- propose, la personne qui catalogue rattache (book_draft_contributors.
-- author_id, sous ses politiques). Au plus p_limite PROPOSITIONS.
CREATE OR REPLACE FUNCTION public.fn_batch_contributor_candidates(p_batch_id bigint, p_limite integer DEFAULT 500)
 RETURNS TABLE(contributor_id bigint, draft_id bigint, titulo text, name text, role text, nature text,
               author_id bigint, author_name text, author_type text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Le rapport du lot est au staff de sa bibliothèque et à l'administration (B30).
  IF NOT public.fn_caller_owns_batch(p_batch_id) THEN
    RAISE EXCEPTION 'Lote de outra biblioteca.' USING HINT = 'error.batch.other_libraries';
  END IF;
  RETURN QUERY
  WITH cibles AS MATERIALIZED (
    SELECT c.id AS cid, c.draft_id AS did, d.titulo AS tit, c.name AS nom, c.role AS rol, c.nature AS nat, c.position AS pos,
           CASE WHEN c.nature = 'congress' AND c.name ~ '\s\([^()]*\)\s*$'
                THEN regexp_replace(c.name, '\s*\([^()]*\)\s*$', '') END AS nom_nu
      FROM public.fn_batch_live_drafts(p_batch_id) d
      JOIN public.book_draft_contributors c ON c.draft_id = d.id
     WHERE c.author_id IS NULL AND nullif(btrim(c.name), '') IS NOT NULL
       AND NOT public.fn_conv_est_non_agent(c.name)
  ), h AS MATERIALIZED (
    SELECT x.nom, x.aid
      FROM public.fn_conv_autorites_homonymes(
             ARRAY(SELECT t.nom FROM cibles t UNION SELECT t.nom_nu FROM cibles t WHERE t.nom_nu IS NOT NULL)) x
  )
  SELECT t.cid, t.did, t.tit, t.nom, t.rol, t.nat, a.id, a.preferred_name, a.authority_type
    FROM cibles t
    LEFT JOIN h h1 ON h1.nom = t.nom
    LEFT JOIN h h2 ON h2.nom = t.nom_nu
    JOIN public.authors a ON a.id = coalesce(h1.aid, h2.aid)
   ORDER BY t.did, t.pos
   LIMIT greatest(1, least(coalesce(p_limite, 500), 2000));
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_batch_contributor_candidates(bigint, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_batch_contributor_candidates(bigint, integer) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_batch_contributor_candidates(bigint, integer) IS
  'H18 (27-28/09/2026) : contributeurs sans autorite des brouillons en cours d''un lot, avec la fiche que '
  'la recherche par nom propose (fn_conv_autorites_homonymes) ; rien n''est rattache ici. Staff de la '
  'bibliotheque du lot, administration.';
