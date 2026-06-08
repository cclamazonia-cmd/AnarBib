-- Lot 0 -- API publique d'import (couche RPC authenticated)
-- Session : Refonte Importacoes/Exportacoes
-- Ref : CADRAGE 08/06 S5, REGISTRE IMP-1..15
--
-- Ajoute library_id sur les runs + 8 RPC publiques (3 lecture, 5 ecriture)
-- qui valident can_access_painel et deleguent aux ingest.* intacts.

-- =====================================================================
-- 1. ADD COLUMN library_id sur ingest.partner_catalog_import_runs
-- =====================================================================

ALTER TABLE ingest.partner_catalog_import_runs
  ADD COLUMN IF NOT EXISTS library_id uuid;

-- Backfill runs existants depuis leur source
UPDATE ingest.partner_catalog_import_runs r
SET library_id = s.library_id
FROM ingest.partner_catalog_sources s
WHERE r.source_id = s.id
  AND r.library_id IS NULL;

-- Trigger : auto-stamp library_id depuis la source a chaque INSERT
CREATE OR REPLACE FUNCTION ingest.fn_stamp_run_library_id()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'ingest'
AS $$
BEGIN
  IF NEW.library_id IS NULL AND NEW.source_id IS NOT NULL THEN
    SELECT s.library_id INTO NEW.library_id
    FROM ingest.partner_catalog_sources s
    WHERE s.id = NEW.source_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_stamp_run_library_id
  ON ingest.partner_catalog_import_runs;

CREATE TRIGGER trg_stamp_run_library_id
  BEFORE INSERT ON ingest.partner_catalog_import_runs
  FOR EACH ROW
  EXECUTE FUNCTION ingest.fn_stamp_run_library_id();

-- =====================================================================
-- 2. RPC LECTURE (scopees biblio de l'acteur via my_access)
-- =====================================================================

-- 2a. fn_import_list_sources
CREATE OR REPLACE FUNCTION public.fn_import_list_sources()
RETURNS TABLE(
  id              bigint,
  partner_name    text,
  library_id      uuid,
  relation_status text,
  source_kind     text,
  import_enabled  boolean,
  notes           text,
  meta            jsonb,
  created_at      timestamptz,
  updated_at      timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $$
DECLARE
  v_actor public.my_access%rowtype;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  RETURN QUERY
  SELECT s.id, s.partner_name, s.library_id, s.relation_status,
         s.source_kind, s.import_enabled, s.notes, s.meta,
         s.created_at, s.updated_at
  FROM ingest.partner_catalog_sources s
  WHERE s.library_id = v_actor.library_id
  ORDER BY s.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_sources() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_sources() TO authenticated;

-- 2b. fn_import_list_runs
CREATE OR REPLACE FUNCTION public.fn_import_list_runs(
  p_source_id bigint DEFAULT NULL
)
RETURNS TABLE(
  id                bigint,
  source_id         bigint,
  source_name       text,
  library_id        uuid,
  run_status        text,
  detected_format   text,
  original_filename text,
  imported_rows     integer,
  selected_rows     integer,
  created_drafts    integer,
  summary           jsonb,
  error_log         jsonb,
  created_at        timestamptz,
  started_at        timestamptz,
  finished_at       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $$
DECLARE
  v_actor public.my_access%rowtype;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  RETURN QUERY
  SELECT r.id, r.source_id, s.partner_name,
         r.library_id, r.run_status, r.detected_format,
         r.original_filename,
         r.imported_rows, r.selected_rows, r.created_drafts,
         r.summary, r.error_log,
         r.created_at, r.started_at, r.finished_at
  FROM ingest.partner_catalog_import_runs r
  JOIN ingest.partner_catalog_sources s ON s.id = r.source_id
  WHERE r.library_id = v_actor.library_id
    AND (p_source_id IS NULL OR r.source_id = p_source_id)
  ORDER BY r.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_runs(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_runs(bigint) TO authenticated;

-- 2c. fn_import_list_run_rows
CREATE OR REPLACE FUNCTION public.fn_import_list_run_rows(
  p_run_id bigint
)
RETURNS TABLE(
  id                       bigint,
  run_id                   bigint,
  row_no                   integer,
  external_key             text,
  item_type                text,
  title                    text,
  subtitle                 text,
  responsibility_statement text,
  authors                  jsonb,
  publisher                text,
  place_of_publication     text,
  publication_year         text,
  edition_statement        text,
  language                 text,
  isbn                     text,
  issn                     text,
  subjects                 jsonb,
  parse_status             text,
  match_status             text,
  review_status            text,
  confidence               numeric,
  warnings                 jsonb,
  editorial_decision       text,
  editorial_note           text,
  selected_for_draft       boolean,
  proposed_book_id         bigint,
  proposed_book_draft_id   bigint,
  created_book_draft_id    bigint,
  created_at               timestamptz
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
         sr.created_book_draft_id,
         sr.created_at
  FROM ingest.partner_catalog_staging_rows sr
  WHERE sr.run_id = p_run_id
  ORDER BY sr.row_no, sr.id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) TO authenticated;

-- =====================================================================
-- 3. RPC ECRITURE (valident can_access_painel, deleguent aux ingest.*)
-- =====================================================================

-- 3a. fn_import_create — estampille library_id, preserve idempotence sha256
CREATE OR REPLACE FUNCTION public.fn_import_create(
  p_source_id         bigint,
  p_storage_path      text,
  p_original_filename text,
  p_bucket_id         text    DEFAULT 'catalogos_parceiros_raw',
  p_mime_type         text    DEFAULT NULL,
  p_size_bytes        bigint  DEFAULT NULL,
  p_sha256            text    DEFAULT NULL,
  p_detected_format   text    DEFAULT 'unknown'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $$
DECLARE
  v_actor public.my_access%rowtype;
  v_source_library_id uuid;
  v_run_id bigint;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  SELECT s.library_id INTO v_source_library_id
  FROM ingest.partner_catalog_sources s
  WHERE s.id = p_source_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Source % introuvable', p_source_id;
  END IF;

  IF v_source_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Source % nao pertence a esta biblioteca', p_source_id;
  END IF;

  v_run_id := ingest.fn_create_partner_catalog_import(
    p_source_id         := p_source_id,
    p_storage_path      := p_storage_path,
    p_original_filename := p_original_filename,
    p_bucket_id         := p_bucket_id,
    p_mime_type         := p_mime_type,
    p_size_bytes        := p_size_bytes,
    p_sha256            := p_sha256,
    p_detected_format   := p_detected_format,
    p_requested_by      := v_actor.user_id
  );

  UPDATE ingest.partner_catalog_import_runs
  SET library_id = v_actor.library_id
  WHERE id = v_run_id AND library_id IS NULL;

  RETURN jsonb_build_object(
    'ok',         true,
    'run_id',     v_run_id,
    'library_id', v_actor.library_id
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_create(bigint, text, text, text, text, bigint, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_create(bigint, text, text, text, text, bigint, text, text) TO authenticated;

-- 3b. fn_import_dispatch
CREATE OR REPLACE FUNCTION public.fn_import_dispatch(
  p_run_id       bigint,
  p_force_reparse boolean DEFAULT false
)
RETURNS jsonb
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

  RETURN ingest.fn_dispatch_partner_catalog_import(
    p_run_id       := p_run_id,
    p_force_reparse := p_force_reparse
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_dispatch(bigint, boolean) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_dispatch(bigint, boolean) TO authenticated;

-- 3c. fn_import_set_rows_review
CREATE OR REPLACE FUNCTION public.fn_import_set_rows_review(
  p_run_id            bigint,
  p_row_ids           bigint[],
  p_review_status     text,
  p_selected_for_draft boolean DEFAULT NULL,
  p_match_status      text    DEFAULT NULL
)
RETURNS jsonb
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

  RETURN ingest.fn_set_partner_catalog_rows_review(
    p_run_id            := p_run_id,
    p_row_ids           := p_row_ids,
    p_review_status     := p_review_status,
    p_selected_for_draft := p_selected_for_draft,
    p_match_status      := p_match_status
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_set_rows_review(bigint, bigint[], text, boolean, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_set_rows_review(bigint, bigint[], text, boolean, text) TO authenticated;

-- 3d. fn_import_set_editorial
CREATE OR REPLACE FUNCTION public.fn_import_set_editorial(
  p_run_id             bigint,
  p_row_ids            bigint[],
  p_editorial_decision text,
  p_editorial_note     text DEFAULT NULL
)
RETURNS jsonb
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

  RETURN ingest.fn_set_partner_catalog_editorial_decision(
    p_run_id             := p_run_id,
    p_row_ids            := p_row_ids,
    p_editorial_decision := p_editorial_decision,
    p_editorial_note     := p_editorial_note,
    p_decided_by         := v_actor.user_id
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_set_editorial(bigint, bigint[], text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_set_editorial(bigint, bigint[], text, text) TO authenticated;

-- 3e. fn_import_promote
CREATE OR REPLACE FUNCTION public.fn_import_promote(
  p_run_id              bigint,
  p_match_statuses      text[]  DEFAULT NULL,
  p_editorial_decisions text[]  DEFAULT ARRAY['accept_new', 'accept_duplicate'],
  p_batch_name          text    DEFAULT NULL,
  p_batch_notes         text    DEFAULT NULL
)
RETURNS jsonb
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

  RETURN ingest.fn_bulk_create_book_drafts_from_run(
    p_run_id              := p_run_id,
    p_match_statuses      := p_match_statuses,
    p_editorial_decisions := p_editorial_decisions,
    p_batch_name          := p_batch_name,
    p_batch_notes         := p_batch_notes,
    p_created_by          := v_actor.user_id
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_promote(bigint, text[], text[], text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_promote(bigint, text[], text[], text, text) TO authenticated;
