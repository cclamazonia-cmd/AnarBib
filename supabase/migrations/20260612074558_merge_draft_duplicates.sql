-- ════════════════════════════════════════════════════════════════════════════
-- Fusion de doublons dans la FILE ÉDITORIALE (#152, suite)
-- api.merge_draft_into_book  +  api.merge_book_drafts
-- Auteur  : Claude (Opus)
-- Session : Catalogação work completion
-- Date    : 2026-06-12 (UTC)
--
-- Pendant « action » de api.suggest_draft_duplicates (détection/comparaison).
-- Deux scénarios, arbitrage des champs MANUEL côté UI (jsonb p_fields) :
--   A) merge_draft_into_book : le brouillon double un LIVRE PUBLIÉ. On enrichit la
--      fiche avec les seuls champs repris, on absorbe le brouillon (corbeille,
--      traçable via published_book_id). Pas de passage par publish_book_draft
--      (évite l'écrasement des ~80 colonnes + l'exigence bib_ref).
--   B) merge_book_drafts : le brouillon double un AUTRE BROUILLON (même biblio).
--      On enrichit le survivant, repointe best-effort les exemplaires du perdant
--      (par batch_id+target_bib_ref si bib_ref connue), écarte le perdant (corbeille).
-- Champs arbitrables = 9 champs cruciaux comparés. Whitelist stricte (anti-injection) :
--   pour chaque clé présente dans p_fields, coalesce(p_fields->>'col', col).
-- Staff-only (librarian/coordenador), SECURITY DEFINER, journalisé dans merge_log.
-- merge_log.entity_type élargi à 'book_draft' (additif).
-- ════════════════════════════════════════════════════════════════════════════

-- merge_log accepte désormais les fusions impliquant un brouillon.
ALTER TABLE public.merge_log DROP CONSTRAINT IF EXISTS merge_log_entity_type_check;
ALTER TABLE public.merge_log ADD  CONSTRAINT merge_log_entity_type_check
  CHECK (entity_type = ANY (ARRAY['author'::text, 'book'::text, 'book_draft'::text]));

-- ─────────────────────────────────────────────────────────────────────────────
-- A) Brouillon → Livre publié
-- ─────────────────────────────────────────────────────────────────────────────
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
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  SELECT * INTO v_draft FROM public.book_drafts WHERE id = p_draft_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho % inexistente.', p_draft_id;
  END IF;
  IF v_draft.status NOT IN ('draft', 'ready') THEN
    RAISE EXCEPTION 'Rascunho % nao esta na fila (status=%).', p_draft_id, v_draft.status;
  END IF;

  SELECT bib_ref INTO v_book_bib_ref FROM public.books WHERE id = p_book_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Livro % inexistente.', p_book_id;
  END IF;

  -- 1. Enrichir la fiche : uniquement les champs explicitement repris.
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

  -- 2. Absorber le brouillon : discard-as-duplicate (corbeille), lien tracé.
  UPDATE public.book_drafts SET
    published_book_id = p_book_id,
    bib_ref           = COALESCE(bib_ref, v_book_bib_ref),
    action            = 'update',
    status            = 'cancelled',
    updated_by = auth.uid(), updated_at = now()
  WHERE id = p_draft_id;

  -- 3. Journaliser.
  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('book_draft', p_book_id, p_draft_id,
          jsonb_build_object('scenario', 'draft_into_book',
                             'fields', COALESCE(p_fields, '{}'::jsonb)),
          auth.uid());

  RETURN p_book_id;
END;
$function$;

-- ─────────────────────────────────────────────────────────────────────────────
-- B) Brouillon → Brouillon (même bibliothèque)
-- ─────────────────────────────────────────────────────────────────────────────
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
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  IF p_survivor_id = p_loser_id THEN
    RAISE EXCEPTION 'Sobrevivente e duplicado identicos.';
  END IF;

  SELECT * INTO v_surv FROM public.book_drafts WHERE id = p_survivor_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho sobrevivente % inexistente.', p_survivor_id;
  END IF;
  SELECT * INTO v_lose FROM public.book_drafts WHERE id = p_loser_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho duplicado % inexistente.', p_loser_id;
  END IF;
  IF v_surv.status NOT IN ('draft', 'ready') OR v_lose.status NOT IN ('draft', 'ready') THEN
    RAISE EXCEPTION 'Ambos os rascunhos devem estar na fila.';
  END IF;
  IF v_surv.owner_library_id IS DISTINCT FROM v_lose.owner_library_id THEN
    RAISE EXCEPTION 'Rascunhos de bibliotecas diferentes nao podem ser fundidos.';
  END IF;

  -- 1. Enrichir le survivant : uniquement les champs repris.
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

  -- 2. Repointer (best-effort) les exemplaires du perdant vers le survivant.
  IF v_lose.bib_ref IS NOT NULL AND v_surv.bib_ref IS NOT NULL THEN
    UPDATE public.exemplar_drafts SET
      target_bib_ref = v_surv.bib_ref, updated_at = now()
    WHERE batch_id IS NOT DISTINCT FROM v_lose.batch_id
      AND target_bib_ref = v_lose.bib_ref;
  END IF;

  -- 3. Écarter le perdant (corbeille, réversible).
  UPDATE public.book_drafts SET
    status = 'cancelled', updated_by = auth.uid(), updated_at = now()
  WHERE id = p_loser_id;

  -- 4. Journaliser.
  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('book_draft', p_survivor_id, p_loser_id,
          jsonb_build_object('scenario', 'draft_into_draft',
                             'fields', COALESCE(p_fields, '{}'::jsonb)),
          auth.uid());

  RETURN p_survivor_id;
END;
$function$;

-- Permissions : staff authentifié uniquement (la garde interne fait foi).
REVOKE EXECUTE ON FUNCTION api.merge_draft_into_book(bigint, bigint, jsonb) FROM PUBLIC, anon, service_role;
GRANT  EXECUTE ON FUNCTION api.merge_draft_into_book(bigint, bigint, jsonb) TO authenticated;
REVOKE EXECUTE ON FUNCTION api.merge_book_drafts(bigint, bigint, jsonb)    FROM PUBLIC, anon, service_role;
GRANT  EXECUTE ON FUNCTION api.merge_book_drafts(bigint, bigint, jsonb)    TO authenticated;

COMMENT ON FUNCTION api.merge_draft_into_book(bigint, bigint, jsonb) IS
  'Fusion d''un brouillon dans un livre publie (file editoriale, #152). Enrichit la '
  'fiche avec les champs repris (p_fields), absorbe le brouillon (corbeille). Staff-only.';
COMMENT ON FUNCTION api.merge_book_drafts(bigint, bigint, jsonb) IS
  'Fusion de deux brouillons (meme biblio) : enrichit le survivant, ecarte le perdant '
  '(corbeille), repointe ses exemplaires. Staff-only.';

NOTIFY pgrst, 'reload schema';
