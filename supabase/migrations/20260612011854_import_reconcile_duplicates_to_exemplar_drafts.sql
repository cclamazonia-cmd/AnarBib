-- Migration : rapprochement d'un doublon d'import -> brouillon d'exemplaire
-- Auteur  : Claude (Opus 4.8)
-- Session : Import/Export — fiabilisation matching & rapprochement
-- Date    : 2026-06-12 (UTC)
--
-- Chantier B. Dans la Fila de revisao, un doublon confirme contre un livre DEJA
-- PUBLIE (proposed_book_id) ne doit PAS creer un book_draft (notice biblio en
-- double) mais un BROUILLON D'EXEMPLAIRE (public.exemplar_drafts) au nom de la
-- biblio importatrice, rattache a ce livre. Valide ensuite en Catalogacao ->
-- exemplares definitif. Condition (decision Xavier) : match au niveau edition,
-- donc proposed_book_id (livre publie) uniquement -- les doublons contre un
-- book_draft non publie restent hors scope (rejet ou attente).
--
-- Rattachement : exemplar_drafts(action='create', target_library_id = biblio de
-- l'import, target_bib_ref = books.bib_ref[proposed_book_id], source_library =
-- nom du parceiro) puis sync_exemplar_draft_holdings_bridge() resout/cree le
-- book_holdings (a la publication si absent). Modele :
--   books <- book_holdings(book_id,library_id) <- exemplares.
--
-- Idempotence via la nouvelle colonne created_exemplar_draft_id (miroir de
-- created_book_draft_id). Les compteurs de run comptent created_drafts via
-- created_book_draft_id uniquement -> les exemplaires n'y sont pas comptes
-- (etat par-ligne « Exemplar criado » dans la Fila).

-- ──────────────────────────────────────────────────────────────────────────
-- 1) Marqueur d'idempotence + etat sur la staging row
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE ingest.partner_catalog_staging_rows
  ADD COLUMN IF NOT EXISTS created_exemplar_draft_id bigint
  REFERENCES public.exemplar_drafts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_pcsr_created_exemplar_draft
  ON ingest.partner_catalog_staging_rows (created_exemplar_draft_id)
  WHERE created_exemplar_draft_id IS NOT NULL;

-- ──────────────────────────────────────────────────────────────────────────
-- 2) Worker : creer les brouillons d'exemplaire pour les lignes rapprochees
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_create_exemplar_drafts_from_import_rows(
  p_run_id bigint,
  p_row_ids bigint[] DEFAULT NULL::bigint[],
  p_batch_name text DEFAULT NULL::text,
  p_batch_notes text DEFAULT NULL::text,
  p_created_by uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'ingest', 'public', 'auth'
AS $function$
declare
  v_actor uuid;
  v_library_id uuid;
  v_partner_name text;
  v_original_filename text;
  v_detected_format text;
  v_batch_id bigint;
  v_batch_name text;
  v_batch_notes text;
  v_requested_count integer := 0;
  v_created_count integer := 0;
  v_exemplar_draft_id bigint;
  v_provenance_note text;
  v_refresh jsonb;
  rec record;
begin
  v_actor := coalesce(p_created_by, auth.uid());

  select r.library_id, s.partner_name, r.original_filename, r.detected_format
    into v_library_id, v_partner_name, v_original_filename, v_detected_format
  from ingest.partner_catalog_import_runs r
  join ingest.partner_catalog_sources s on s.id = r.source_id
  where r.id = p_run_id;

  if not found then
    raise exception 'import_run % introuvable', p_run_id;
  end if;

  -- Eligibilite : doublon d'un livre PUBLIE, decision accept_duplicate, pas
  -- deja rapproche.
  select count(*)::integer
    into v_requested_count
  from ingest.partner_catalog_staging_rows sr
  where sr.run_id = p_run_id
    and sr.created_exemplar_draft_id is null
    and sr.proposed_book_id is not null
    and sr.editorial_decision = 'accept_duplicate'
    and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision')
    and (coalesce(array_length(p_row_ids, 1), 0) = 0 or sr.id = any(p_row_ids));

  if v_requested_count = 0 then
    raise exception 'Aucune ligne eligible au rapprochement pour le run %', p_run_id;
  end if;

  v_batch_name := coalesce(
    nullif(trim(p_batch_name), ''),
    format(
      'Rapprochement parceiro #%s — %s — %s',
      p_run_id,
      left(coalesce(v_partner_name, 'parceiro sem nome'), 80),
      to_char(now() at time zone 'UTC', 'YYYY-MM-DD HH24:MI UTC')
    )
  );

  v_batch_notes := coalesce(
    nullif(trim(p_batch_notes), ''),
    format(
      'Exemplares de rascunho criados a partir do import run %s (%s, formato %s).',
      p_run_id,
      coalesce(v_original_filename, 'arquivo sem nome'),
      coalesce(v_detected_format, 'unknown')
    )
  );

  insert into public.catalog_batches (name, notes, created_by)
  values (v_batch_name, v_batch_notes, v_actor)
  returning id into v_batch_id;

  for rec in
    select sr.id as row_id,
           sr.row_no,
           b.bib_ref as proposed_bib_ref,
           b.titulo  as proposed_titulo
    from ingest.partner_catalog_staging_rows sr
    join public.books b on b.id = sr.proposed_book_id
    where sr.run_id = p_run_id
      and sr.created_exemplar_draft_id is null
      and sr.proposed_book_id is not null
      and sr.editorial_decision = 'accept_duplicate'
      and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision')
      and (coalesce(array_length(p_row_ids, 1), 0) = 0 or sr.id = any(p_row_ids))
    order by sr.row_no, sr.id
  loop
    v_provenance_note := format(
      'Exemplar criado a partir de catalogo parceiro "%s" (%s, run %s, linha %s): biblioteca importadora declara possuir um exemplar de "%s".',
      coalesce(v_partner_name, 'parceiro sem nome'),
      coalesce(v_original_filename, 'arquivo sem nome'),
      p_run_id,
      rec.row_no,
      coalesce(rec.proposed_titulo, 'sem titulo')
    );

    insert into public.exemplar_drafts (
      batch_id,
      action,
      status,
      label_status,
      target_library_id,
      target_bib_ref,
      source_library,
      provenance_note,
      created_by,
      updated_by
    ) values (
      v_batch_id,
      'create',
      'draft',
      'pending',
      v_library_id,
      rec.proposed_bib_ref,
      v_partner_name,
      v_provenance_note,
      v_actor,
      v_actor
    )
    returning id into v_exemplar_draft_id;

    -- Resout / relie le book_holdings (cree a la publication si absent).
    perform public.sync_exemplar_draft_holdings_bridge(v_exemplar_draft_id);

    update ingest.partner_catalog_staging_rows
       set created_exemplar_draft_id = v_exemplar_draft_id,
           review_status = 'draft_created',
           selected_for_draft = false
     where id = rec.row_id;

    v_created_count := v_created_count + 1;
  end loop;

  if v_created_count = 0 then
    delete from public.catalog_batches where id = v_batch_id;
    raise exception 'Aucun brouillon d''exemplaire cree pour le run %', p_run_id;
  end if;

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);

  return jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch_id,
    'batch_name', v_batch_name,
    'requested_rows', v_requested_count,
    'created_exemplar_drafts', v_created_count,
    'run', v_refresh
  );
end;
$function$;

REVOKE EXECUTE ON FUNCTION ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid) TO service_role;

-- ──────────────────────────────────────────────────────────────────────────
-- 3) RPC public : poser accept_duplicate puis creer les exemplaires
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_import_reconcile_duplicates(
  p_run_id bigint,
  p_row_ids bigint[] DEFAULT NULL::bigint[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $function$
declare
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
begin
  select * into v_actor from public.my_access limit 1;
  if v_actor.library_id is null
     or not coalesce(v_actor.can_access_painel, false) then
    raise exception 'Acesso bibliotecario obrigatorio.';
  end if;
  if v_actor.role is distinct from 'coordenador'
     and not public.fn_caller_is_network_admin() then
    raise exception 'Acesso restrito ao coordenador da biblioteca.';
  end if;

  select r.library_id into v_run_library_id
  from ingest.partner_catalog_import_runs r
  where r.id = p_run_id;

  if not found then
    raise exception 'Run % introuvable', p_run_id;
  end if;

  if v_run_library_id is distinct from v_actor.library_id then
    raise exception 'Run % nao pertence a esta biblioteca', p_run_id;
  end if;

  -- Marque la decision accept_duplicate (avec controle de compatibilite +
  -- journalisation) sur les lignes ciblees, puis cree les exemplaires.
  perform ingest.fn_set_partner_catalog_editorial_decision(
    p_run_id             := p_run_id,
    p_row_ids            := p_row_ids,
    p_editorial_decision := 'accept_duplicate',
    p_editorial_note     := 'page import: rapprochement (exemplar)',
    p_decided_by         := v_actor.user_id
  );

  return ingest.fn_create_exemplar_drafts_from_import_rows(
    p_run_id     := p_run_id,
    p_row_ids    := p_row_ids,
    p_batch_name := null,
    p_batch_notes := null,
    p_created_by := v_actor.user_id
  );
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_import_reconcile_duplicates(bigint, bigint[]) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_reconcile_duplicates(bigint, bigint[]) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────
-- 4) fn_import_list_run_rows : exposer created_exemplar_draft_id
--    (changement de signature RETURNS TABLE -> DROP + CREATE)
-- ──────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.fn_import_list_run_rows(bigint);

CREATE FUNCTION public.fn_import_list_run_rows(
  p_run_id bigint
)
RETURNS TABLE(
  id                        bigint,
  run_id                    bigint,
  row_no                    integer,
  external_key              text,
  item_type                 text,
  title                     text,
  subtitle                  text,
  responsibility_statement  text,
  authors                   jsonb,
  publisher                 text,
  place_of_publication      text,
  publication_year          text,
  edition_statement         text,
  language                  text,
  isbn                      text,
  issn                      text,
  subjects                  jsonb,
  parse_status              text,
  match_status              text,
  review_status             text,
  confidence                numeric,
  warnings                  jsonb,
  editorial_decision        text,
  editorial_note            text,
  selected_for_draft        boolean,
  proposed_book_id          bigint,
  proposed_book_draft_id    bigint,
  proposed_title            text,
  created_book_draft_id     bigint,
  created_exemplar_draft_id bigint,
  created_at                timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  SELECT r.library_id INTO v_run_library_id
  FROM ingest.partner_catalog_import_runs r
  WHERE r.id = p_run_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  IF v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % nao pertence a esta biblioteca', p_run_id;
  END IF;

  RETURN QUERY
  SELECT sr.id, sr.run_id, sr.row_no, sr.external_key, sr.item_type,
         sr.title, sr.subtitle, sr.responsibility_statement, sr.authors,
         sr.publisher, sr.place_of_publication, sr.publication_year,
         sr.edition_statement, sr.language, sr.isbn, sr.issn, sr.subjects,
         sr.parse_status, sr.match_status, sr.review_status,
         sr.confidence, sr.warnings,
         sr.editorial_decision, sr.editorial_note, sr.selected_for_draft,
         sr.proposed_book_id, sr.proposed_book_draft_id,
         coalesce(
           (SELECT b.titulo  FROM public.books       b  WHERE b.id  = sr.proposed_book_id),
           (SELECT bd.titulo FROM public.book_drafts bd WHERE bd.id = sr.proposed_book_draft_id)
         ) AS proposed_title,
         sr.created_book_draft_id,
         sr.created_exemplar_draft_id,
         sr.created_at
  FROM ingest.partner_catalog_staging_rows sr
  WHERE sr.run_id = p_run_id
  ORDER BY sr.row_no, sr.id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) TO authenticated;

NOTIFY pgrst, 'reload schema';
