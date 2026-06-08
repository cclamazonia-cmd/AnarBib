-- Migration : fn_import_ingest_candidate — Lot 2 fontes externas
-- Auteur  : Claude Opus 4.6
-- Session : Lot 2 – Fontes externas bout-en-bout
-- Date    : 2026-06-08
--
-- Pont entre catalog_metadata_lookup (candidats affichés à l'écran)
-- et ingest.partner_catalog_staging_rows (file de révision).
-- Crée automatiquement une source « institutional_lookup » par biblio
-- et un run journalier de type lookup.

-- ═══════════════════════════════════════════════════════════════
-- 1. PUBLIC RPC : fn_import_ingest_candidate
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_import_ingest_candidate(
  p_candidate  jsonb,
  p_source_id  bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $$
DECLARE
  v_actor   public.my_access%rowtype;
  v_src_id  bigint;
  v_run_id  bigint;
  v_row_id  bigint;
  v_today   date := current_date;
  v_row_no  integer;
BEGIN
  -- ── 1. Contrôle d'accès ────────────────────────────────
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  -- ── 2. Résolution de la source ─────────────────────────
  IF p_source_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM ingest.partner_catalog_sources
      WHERE id = p_source_id AND library_id = v_actor.library_id
    ) THEN
      RAISE EXCEPTION 'Source % nao pertence a esta biblioteca', p_source_id;
    END IF;
    v_src_id := p_source_id;
  ELSE
    SELECT id INTO v_src_id
      FROM ingest.partner_catalog_sources
     WHERE library_id = v_actor.library_id
       AND source_kind = 'institutional_lookup'
     LIMIT 1;

    IF v_src_id IS NULL THEN
      INSERT INTO ingest.partner_catalog_sources
        (partner_name, library_id, source_kind, import_enabled)
      VALUES
        ('Recherche institutionnelle', v_actor.library_id,
         'institutional_lookup', true)
      RETURNING id INTO v_src_id;
    END IF;
  END IF;

  -- ── 3. Run journalier de type lookup ───────────────────
  SELECT id INTO v_run_id
    FROM ingest.partner_catalog_import_runs
   WHERE source_id   = v_src_id
     AND library_id  = v_actor.library_id
     AND detected_format = 'lookup'
     AND created_at::date = v_today
     AND run_status NOT IN ('drafts_created', 'failed')
   ORDER BY id DESC
   LIMIT 1;

  IF v_run_id IS NULL THEN
    INSERT INTO ingest.partner_catalog_import_runs
      (source_id, library_id, detected_format, run_status,
       original_filename, requested_by, imported_rows)
    VALUES
      (v_src_id, v_actor.library_id, 'lookup', 'ready_for_review',
       'lookup-' || v_today::text, v_actor.user_id, 0)
    RETURNING id INTO v_run_id;
  END IF;

  -- ── 4. Insertion du candidat comme staging_row ─────────
  SELECT coalesce(max(row_no), 0) + 1 INTO v_row_no
    FROM ingest.partner_catalog_staging_rows
   WHERE run_id = v_run_id;

  INSERT INTO ingest.partner_catalog_staging_rows (
    run_id,
    row_no,
    external_key,
    item_type,
    title,
    subtitle,
    responsibility_statement,
    authors,
    publisher,
    place_of_publication,
    publication_year,
    edition_statement,
    language,
    isbn,
    issn,
    subjects,
    raw_payload,
    normalized_payload,
    parse_status,
    match_status,
    review_status,
    confidence
  ) VALUES (
    v_run_id,
    v_row_no,
    p_candidate->>'source_record_id',
    'lookup',
    p_candidate->>'title',
    p_candidate->>'subtitle',
    p_candidate->>'responsibility_statement',
    CASE WHEN p_candidate->'contributors' IS NOT NULL
         THEN p_candidate->'contributors'
         ELSE '[]'::jsonb END,
    p_candidate->>'publisher',
    p_candidate->>'place',
    p_candidate->>'year',
    p_candidate->>'edition',
    p_candidate->>'language',
    p_candidate->'isbn'->>0,
    p_candidate->'issn'->>0,
    CASE WHEN p_candidate->'subjects' IS NOT NULL
         THEN p_candidate->'subjects'
         ELSE '[]'::jsonb END,
    p_candidate,
    jsonb_build_object(
      'title',                    p_candidate->>'title',
      'subtitle',                 p_candidate->>'subtitle',
      'responsibility_statement', p_candidate->>'responsibility_statement',
      'authors',                  coalesce(p_candidate->'contributors', '[]'::jsonb),
      'publisher',                p_candidate->>'publisher',
      'place_of_publication',     p_candidate->>'place',
      'publication_year',         p_candidate->>'year',
      'isbn',                     p_candidate->'isbn'->>0,
      'issn',                     p_candidate->'issn'->>0,
      'subjects',                 coalesce(p_candidate->'subjects', '[]'::jsonb),
      'source',                   p_candidate->>'source',
      'source_url',               p_candidate->>'source_url',
      'raw_format',               p_candidate->>'raw_format',
      'parser_version',           'lookup_v1'
    ),
    'parsed',
    'pre_matched',
    'pending',
    coalesce((p_candidate->>'confidence')::numeric, 0)
  ) RETURNING id INTO v_row_id;

  -- ── 5. Mise à jour des compteurs du run ────────────────
  UPDATE ingest.partner_catalog_import_runs
     SET imported_rows = coalesce(imported_rows, 0) + 1
   WHERE id = v_run_id;

  RETURN jsonb_build_object(
    'ok',     true,
    'run_id', v_run_id,
    'row_id', v_row_id,
    'source', p_candidate->>'source'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_ingest_candidate(jsonb, bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_ingest_candidate(jsonb, bigint) TO authenticated;

COMMENT ON FUNCTION public.fn_import_ingest_candidate IS
  'Lot 2 — Insère un candidat catalog_metadata_lookup dans la file de révision (staging_row). '
  'Crée automatiquement une source institutional_lookup et un run journalier si nécessaire.';
