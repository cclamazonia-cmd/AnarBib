-- ════════════════════════════════════════════════════════════════════════════
-- OPAC étape 2 — Autorité matière — Paquet 2 : catalogage (lien + RPC + synchro)
-- Auteur  : Claude (Opus)
-- Session : Etape 2 autorite matiere (P2 catalogage)
-- Date    : 2026-06-08 (UTC)
-- Registre: OPAC-ATL1
--
-- - Durcit les grants de subjects/book_subjects (Supabase auto-accorde ALL ;
--   la RLS neutralisait deja, on retire le superflu — defense en profondeur).
-- - Ecriture de l'autorite matiere par le staff catalogage (policy my_access),
--   auto-slug a la creation.
-- - book_draft_subjects (lien cote brouillon) + RLS catalogage (miroir
--   book_draft_contributors) : le formulaire ecrit directement (RLS gardee).
-- - api.search_subjects : typeahead (tous libelles + slug).
-- - fn_sync_book_subjects_on_publish : copie brouillon -> publie au publish.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Durcissement P1 : grants minimaux ───────────────────────────────────────
REVOKE ALL ON public.subjects FROM anon, authenticated;
GRANT SELECT ON public.subjects TO anon;
GRANT SELECT, INSERT, UPDATE ON public.subjects TO authenticated;  -- ecriture gardee par RLS
REVOKE ALL ON public.book_subjects FROM anon, authenticated;
GRANT SELECT ON public.book_subjects TO anon, authenticated;        -- ecriture = trigger publish (DEFINER)

-- ── Ecriture de l'autorite matiere par le staff catalogage ──────────────────
CREATE POLICY subjects_write_catalogacao ON public.subjects
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
  WITH CHECK (EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true));

-- ── Auto-slug a la creation d'un sujet ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_subjects_autoslug()
RETURNS trigger LANGUAGE plpgsql SET search_path = public, pg_catalog
AS $function$
DECLARE base text; cand text; i int := 2;
BEGIN
  IF NEW.slug IS NOT NULL AND btrim(NEW.slug) <> '' THEN RETURN NEW; END IF;
  base := btrim(regexp_replace(lower(f_normalize_search(
            COALESCE(NEW.label_i18n->>'pt-BR', NEW.label_i18n->>'en',
                     (SELECT value FROM jsonb_each_text(NEW.label_i18n) LIMIT 1)))),
          '[^a-z0-9]+', '-', 'g'), '-');
  IF base IS NULL OR base = '' THEN base := 'sujet'; END IF;
  cand := base;
  WHILE EXISTS (SELECT 1 FROM public.subjects WHERE slug = cand) LOOP
    cand := base || '-' || i; i := i + 1;
  END LOOP;
  NEW.slug := cand;
  RETURN NEW;
END $function$;

CREATE TRIGGER trg_subjects_autoslug
  BEFORE INSERT ON public.subjects
  FOR EACH ROW EXECUTE FUNCTION public.fn_subjects_autoslug();

-- ── Lien brouillon ↔ sujet (catalogage) ─────────────────────────────────────
CREATE TABLE public.book_draft_subjects (
  book_draft_id bigint NOT NULL REFERENCES public.book_drafts(id) ON DELETE CASCADE,
  subject_id    bigint NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  ord           int NOT NULL DEFAULT 0,
  PRIMARY KEY (book_draft_id, subject_id)
);
CREATE INDEX book_draft_subjects_subject_idx ON public.book_draft_subjects(subject_id);
ALTER TABLE public.book_draft_subjects ENABLE ROW LEVEL SECURITY;
CREATE POLICY book_draft_subjects_catalogacao_all ON public.book_draft_subjects
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
  WITH CHECK (EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true));
REVOKE ALL ON public.book_draft_subjects FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_draft_subjects TO authenticated;

-- ── Typeahead : recherche de sujets (tous libelles + slug) ──────────────────
CREATE OR REPLACE FUNCTION api.search_subjects(p_query text, p_limit int DEFAULT 12)
RETURNS TABLE (id bigint, slug text, label_i18n jsonb, parent_id bigint, parent_label jsonb)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_catalog
AS $function$
  SELECT s.id, s.slug, s.label_i18n, s.parent_id, p.label_i18n
  FROM public.subjects s LEFT JOIN public.subjects p ON p.id = s.parent_id
  WHERE NULLIF(btrim(p_query), '') IS NOT NULL AND (
    s.slug ILIKE '%'||btrim(p_query)||'%'
    OR EXISTS (SELECT 1 FROM jsonb_each_text(s.label_i18n) kv
               WHERE f_normalize_search(kv.value) LIKE '%'||f_normalize_search(btrim(p_query))||'%')
  )
  ORDER BY (s.label_i18n->>'pt-BR'), s.slug
  LIMIT LEAST(COALESCE(p_limit, 12), 50);
$function$;
REVOKE EXECUTE ON FUNCTION api.search_subjects(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.search_subjects(text, int) TO authenticated;

-- ── Synchro brouillon → publie au publish (miroir contributeurs) ────────────
CREATE OR REPLACE FUNCTION public.fn_sync_book_subjects_on_publish()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NEW.published_book_id IS NOT NULL THEN
    DELETE FROM public.book_subjects WHERE book_id = NEW.published_book_id;
    INSERT INTO public.book_subjects (book_id, subject_id, ord)
      SELECT NEW.published_book_id, ds.subject_id, ds.ord
      FROM public.book_draft_subjects ds WHERE ds.book_draft_id = NEW.id
      ON CONFLICT (book_id, subject_id) DO NOTHING;
  END IF;
  RETURN NULL;
END $function$;
REVOKE EXECUTE ON FUNCTION public.fn_sync_book_subjects_on_publish() FROM PUBLIC;

CREATE TRIGGER trg_sync_book_subjects_on_publish
  AFTER UPDATE OF status ON public.book_drafts
  FOR EACH ROW
  WHEN (NEW.status = 'published' AND NEW.status IS DISTINCT FROM OLD.status)
  EXECUTE FUNCTION public.fn_sync_book_subjects_on_publish();
