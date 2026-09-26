-- =====================================================================
-- H16 — le rapport de révision d'un lot importé dit ce que l'import a repris
-- Date : 2026-09-26 · Backlog v34 H16 · Aller-retour PMB (G15, H14)
--
-- Depuis H16, process-partner-catalog-import écrit dans le summary de chaque
-- run sa COUVERTURE : pour chaque zone/sous-zone MARC, colonne CSV ou balise
-- RIS du fichier, « repris » (un champ de la notice), « indice » (relu par le
-- SQL : collection, cote locale) ou « brut » (gardé seulement dans
-- raw_payload → marc_json). Jusqu'ici la perte ne se voyait nulle part : relevé
-- du 26/09, l'import Solidaires n'a repris que 4 colonnes sur 17.
--
-- fn_batch_review_report gagne la clé `coverage` : un élément par run dont le
-- lot est issu (ingest.partner_catalog_row_to_draft), avec les comptes,
-- l'encodage lu, les entrées écartées et les seuls éléments NON repris.
-- fn_batch_review_request et fn_batch_review_verdict l'appellent : la clé
-- entre dans les revues enregistrées.
--
-- Corps EXTRAIT de pg_get_functiondef (banc local dont le md5 est celui de la
-- production : 9fe707120fba70204ea2a24663959ec0, 10 763 caractères, 26/09),
-- modifié par trois ancrages, jamais retapé. Aucune table temporaire
-- (mémoire : elle recharge le cache PostgREST → 400).
-- =====================================================================

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
begin
  if not (public.fn_caller_is_network_admin()
          or exists (select 1 from public.user_library_memberships m
                      where m.user_id = auth.uid() and m.status = 'active'
                        and m.role in ('librarian', 'coordenador'))) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using hint = 'error.catalog.staff_only';
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
  select count(*),
         count(*) filter (where public.fn_conv_autorite_homonyme(c.name) is not null)
    into v_unlinked_n, v_linkable_n
    from public.fn_batch_live_drafts(p_batch_id) d
    join public.book_draft_contributors c on c.draft_id = d.id
   where c.author_id is null and not public.fn_conv_est_non_agent(c.name);

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_unlinked from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'name', c.name,
                              'suggested_author_id', a.id, 'suggested_sort_name', a.sort_name) as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.book_draft_contributors c on c.draft_id = d.id
      left join public.authors a on a.id = public.fn_conv_autorite_homonyme(c.name)
     where c.author_id is null and not public.fn_conv_est_non_agent(c.name)
     order by (a.id is null), d.id limit 40) s;

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

  return jsonb_build_object(
    'batch', jsonb_build_object(
      'id', v_batch.id, 'name', v_batch.name, 'status', v_batch.status,
      'imported', public.fn_batch_is_imported(p_batch_id),
      'drafts_active', (select count(*) from public.fn_batch_live_drafts(p_batch_id)),
      'drafts_published', (select count(*) from public.book_drafts where batch_id = p_batch_id and status = 'published'),
      'drafts_cancelled', (select count(*) from public.book_drafts where batch_id = p_batch_id and status = 'cancelled'),
      'title_entries', v_title_n),
    'generated_at', now(),
    'coverage', v_coverage,
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
  get stacked diagnostics v_ctx = pg_exception_context;
  -- Pas de HINT i18n ici : l'ecran afficherait la cle traduite et perdrait le
  -- message ; le texte brut, lui, dit ou ca casse.
  raise exception '% [%] @ %', sqlerrm, sqlstate, left(regexp_replace(v_ctx, E'\\s+', ' ', 'g'), 240)
    using errcode = sqlstate;
end;
$function$;

-- Droits inchangés (CREATE OR REPLACE les conserve) ; réaffirmés pour les
-- gardes : pas anon (rapport_reseau_evidences_tests), authenticated oui.
REVOKE EXECUTE ON FUNCTION public.fn_batch_review_report(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_batch_review_report(bigint) TO authenticated, service_role;
