-- ════════════════════════════════════════════════════════════════════════════
-- Erreurs traduisibles pour la fusion de doublons (#152)
-- Redéfinit api.merge_draft_into_book + api.merge_book_drafts en ajoutant un
-- HINT i18n ('error.merge.*') à chaque RAISE, pour que localizeError(err, t)
-- affiche un message DANS LA LANGUE de l'usager·ère (jamais de PT brut).
-- Corps fonctionnel inchangé par rapport à 20260612074558 ; seuls les HINT
-- sont ajoutés. Clés i18n correspondantes livrées côté locales.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION api.merge_draft_into_book(
  p_draft_id bigint,
  p_book_id  bigint,
  p_fields   jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_draft         public.book_drafts%rowtype;
  v_book_bib_ref  text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING HINT = 'error.merge.staff_only';
  END IF;

  SELECT * INTO v_draft FROM public.book_drafts WHERE id = p_draft_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho % inexistente.', p_draft_id
      USING HINT = 'error.merge.draft_not_found';
  END IF;
  IF v_draft.status NOT IN ('draft', 'ready') THEN
    RAISE EXCEPTION 'Rascunho % nao esta na fila (status=%).', p_draft_id, v_draft.status
      USING HINT = 'error.merge.draft_not_in_queue';
  END IF;

  SELECT bib_ref INTO v_book_bib_ref FROM public.books WHERE id = p_book_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Livro % inexistente.', p_book_id
      USING HINT = 'error.merge.book_not_found';
  END IF;

  UPDATE public.books SET
    titulo    = COALESCE(p_fields->>'titulo',    titulo),
    subtitulo = COALESCE(p_fields->>'subtitulo', subtitulo),
    autor     = COALESCE(p_fields->>'autor',     autor),
    isbn      = COALESCE(p_fields->>'isbn',      isbn),
    ano       = COALESCE(p_fields->>'ano',       ano),
    editora   = COALESCE(p_fields->>'editora',   editora),
    cdd       = COALESCE(p_fields->>'cdd',       cdd),
    colecao   = COALESCE(p_fields->>'colecao',   colecao),
    idioma    = COALESCE(p_fields->>'idioma',    idioma),
    updated_by = auth.uid(), updated_at = now(), last_cataloged_at = now()
  WHERE id = p_book_id;

  UPDATE public.book_drafts SET
    published_book_id = p_book_id,
    bib_ref           = COALESCE(bib_ref, v_book_bib_ref),
    action            = 'update',
    status            = 'cancelled',
    updated_by = auth.uid(), updated_at = now()
  WHERE id = p_draft_id;

  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('book_draft', p_book_id, p_draft_id,
          jsonb_build_object('scenario', 'draft_into_book',
                             'fields', COALESCE(p_fields, '{}'::jsonb)),
          auth.uid());

  RETURN p_book_id;
END;
$function$;

CREATE OR REPLACE FUNCTION api.merge_book_drafts(
  p_survivor_id bigint,
  p_loser_id    bigint,
  p_fields      jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_surv public.book_drafts%rowtype;
  v_lose public.book_drafts%rowtype;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING HINT = 'error.merge.staff_only';
  END IF;

  IF p_survivor_id = p_loser_id THEN
    RAISE EXCEPTION 'Sobrevivente e duplicado identicos.'
      USING HINT = 'error.merge.same_draft';
  END IF;

  SELECT * INTO v_surv FROM public.book_drafts WHERE id = p_survivor_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho sobrevivente % inexistente.', p_survivor_id
      USING HINT = 'error.merge.draft_not_found';
  END IF;
  SELECT * INTO v_lose FROM public.book_drafts WHERE id = p_loser_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho duplicado % inexistente.', p_loser_id
      USING HINT = 'error.merge.draft_not_found';
  END IF;
  IF v_surv.status NOT IN ('draft', 'ready') OR v_lose.status NOT IN ('draft', 'ready') THEN
    RAISE EXCEPTION 'Ambos os rascunhos devem estar na fila.'
      USING HINT = 'error.merge.draft_not_in_queue';
  END IF;
  IF v_surv.owner_library_id IS DISTINCT FROM v_lose.owner_library_id THEN
    RAISE EXCEPTION 'Rascunhos de bibliotecas diferentes nao podem ser fundidos.'
      USING HINT = 'error.merge.cross_library';
  END IF;

  UPDATE public.book_drafts SET
    titulo    = COALESCE(p_fields->>'titulo',    titulo),
    subtitulo = COALESCE(p_fields->>'subtitulo', subtitulo),
    autor     = COALESCE(p_fields->>'autor',     autor),
    isbn      = COALESCE(p_fields->>'isbn',      isbn),
    ano       = COALESCE(p_fields->>'ano',       ano),
    editora   = COALESCE(p_fields->>'editora',   editora),
    cdd       = COALESCE(p_fields->>'cdd',       cdd),
    colecao   = COALESCE(p_fields->>'colecao',   colecao),
    idioma    = COALESCE(p_fields->>'idioma',    idioma),
    updated_by = auth.uid(), updated_at = now()
  WHERE id = p_survivor_id;

  IF v_lose.bib_ref IS NOT NULL AND v_surv.bib_ref IS NOT NULL THEN
    UPDATE public.exemplar_drafts SET
      target_bib_ref = v_surv.bib_ref, updated_at = now()
    WHERE batch_id IS NOT DISTINCT FROM v_lose.batch_id
      AND target_bib_ref = v_lose.bib_ref;
  END IF;

  UPDATE public.book_drafts SET
    status = 'cancelled', updated_by = auth.uid(), updated_at = now()
  WHERE id = p_loser_id;

  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('book_draft', p_survivor_id, p_loser_id,
          jsonb_build_object('scenario', 'draft_into_draft',
                             'fields', COALESCE(p_fields, '{}'::jsonb)),
          auth.uid());

  RETURN p_survivor_id;
END;
$function$;

NOTIFY pgrst, 'reload schema';
