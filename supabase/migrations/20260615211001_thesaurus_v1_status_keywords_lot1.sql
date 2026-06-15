-- ════════════════════════════════════════════════════════════════════════════
-- Thésaurus matière — v1 Étape 1 : gouvernance par consentement + mots-clés locaux
-- Session : Fédération — Communs & Entraide
-- Cadrage : docs/journal/cadrages/CADRAGE_thesaurus_matiere_2026-06-15.md (D1–D5 validés)
-- Filiation : prolonge OPAC-ATL1 (subjects, book_subjects, book_draft_subjects).
--
--   1) subjects.status (proposto|ativo|depreciado) — défaut « proposto » ; la
--      graine curée existante passe à « ativo ».
--   2) Garde-fou : un·e simple catalogu·euse ne peut PAS changer le status par
--      l'UPDATE libre ; l'activation passe par api.fn_subject_set_status, gardé
--      par la capacité de coordination catalogage (coordenador/administrador ou
--      admin réseau). Cf. décision D3.
--   3) Mots-clés locaux (soupape « ça tend ») : book_draft_keywords + book_keywords
--      + synchro au publish, calquée sur book_subjects. Cf. décision D1.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1) Cycle de vie d'un sujet ──────────────────────────────────────────────
ALTER TABLE public.subjects
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'proposto'
    CHECK (status IN ('proposto','ativo','depreciado'));

-- Toutes les lignes présentes = la graine curée OPAC-ATL1 → actives.
-- (S'exécute AVANT la création du garde-fou ci-dessous : contexte migration,
--  auth.uid() NULL, donc non bloqué de toute façon.)
UPDATE public.subjects SET status = 'ativo' WHERE status = 'proposto';

CREATE INDEX IF NOT EXISTS subjects_status_idx ON public.subjects(status);

-- ── 2) Gouvernance : seule la coordination catalogage change le status ───────
-- Capacité = membership actif coordenador/administrador OU admin réseau actif.
CREATE OR REPLACE FUNCTION public.fn_is_catalog_coordinator()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_catalog
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid() AND m.status = 'active'
      AND m.role IN ('coordenador','administrador')
  ) OR EXISTS (
    SELECT 1 FROM public.network_administrators na
    WHERE na.user_id = auth.uid() AND na.status = 'active'
  );
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_is_catalog_coordinator() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_is_catalog_coordinator() TO authenticated;

-- Garde-fou : bloque un changement de status par un·e authentifié·e non-coordo.
-- (auth.uid() NULL = contexte migration/admin → non bloqué ; anon n'a aucun
--  droit d'écriture sur subjects, donc n'atteint jamais ce trigger.)
CREATE OR REPLACE FUNCTION public.fn_subjects_guard_status()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status
     AND auth.uid() IS NOT NULL
     AND NOT public.fn_is_catalog_coordinator() THEN
    RAISE EXCEPTION 'Seule la coordination catalogage peut changer le statut d''un sujet'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $function$;
REVOKE EXECUTE ON FUNCTION public.fn_subjects_guard_status() FROM PUBLIC;

CREATE TRIGGER trg_subjects_guard_status
  BEFORE UPDATE OF status ON public.subjects
  FOR EACH ROW EXECUTE FUNCTION public.fn_subjects_guard_status();

-- RPC d'activation / dépréciation (gate coordination, audité).
CREATE OR REPLACE FUNCTION api.fn_subject_set_status(p_subject_id bigint, p_status text)
RETURNS public.subjects LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $function$
DECLARE r public.subjects;
BEGIN
  IF NOT public.fn_is_catalog_coordinator() THEN
    RAISE EXCEPTION 'Réservé à la coordination catalogage' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_status NOT IN ('proposto','ativo','depreciado') THEN
    RAISE EXCEPTION 'Statut invalide : %', p_status USING ERRCODE = 'check_violation';
  END IF;
  UPDATE public.subjects
    SET status = p_status, updated_by = auth.uid(), updated_at = now()
    WHERE id = p_subject_id
    RETURNING * INTO r;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sujet introuvable : %', p_subject_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN r;
END $function$;
REVOKE EXECUTE ON FUNCTION api.fn_subject_set_status(bigint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_subject_set_status(bigint, text) TO authenticated;

-- ── 3) Mots-clés locaux (soupape : indexation libre, sans gouvernance) ───────
-- Côté brouillon : écriture par le staff catalogage (miroir book_draft_subjects).
CREATE TABLE IF NOT EXISTS public.book_draft_keywords (
  book_draft_id bigint NOT NULL REFERENCES public.book_drafts(id) ON DELETE CASCADE,
  keyword       text   NOT NULL CHECK (length(btrim(keyword)) BETWEEN 1 AND 80),
  ord           int    NOT NULL DEFAULT 0,
  PRIMARY KEY (book_draft_id, keyword)
);
ALTER TABLE public.book_draft_keywords ENABLE ROW LEVEL SECURITY;
CREATE POLICY book_draft_keywords_catalogacao_all ON public.book_draft_keywords
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
  WITH CHECK (EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true));
REVOKE ALL ON public.book_draft_keywords FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_draft_keywords TO authenticated;

-- Côté publié : lecture publique ; écriture = trigger de publish (DEFINER).
CREATE TABLE IF NOT EXISTS public.book_keywords (
  book_id  bigint NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,
  keyword  text   NOT NULL CHECK (length(btrim(keyword)) BETWEEN 1 AND 80),
  ord      int    NOT NULL DEFAULT 0,
  PRIMARY KEY (book_id, keyword)
);
CREATE INDEX IF NOT EXISTS book_keywords_book_idx ON public.book_keywords(book_id);
ALTER TABLE public.book_keywords ENABLE ROW LEVEL SECURITY;
CREATE POLICY book_keywords_select_public ON public.book_keywords
  FOR SELECT TO anon, authenticated USING (true);
REVOKE ALL ON public.book_keywords FROM anon, authenticated;
GRANT SELECT ON public.book_keywords TO anon, authenticated;

-- Synchro brouillon → publié au publish (miroir fn_sync_book_subjects_on_publish).
CREATE OR REPLACE FUNCTION public.fn_sync_book_keywords_on_publish()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NEW.published_book_id IS NOT NULL THEN
    DELETE FROM public.book_keywords WHERE book_id = NEW.published_book_id;
    INSERT INTO public.book_keywords (book_id, keyword, ord)
      SELECT NEW.published_book_id, dk.keyword, dk.ord
      FROM public.book_draft_keywords dk WHERE dk.book_draft_id = NEW.id
      ON CONFLICT (book_id, keyword) DO NOTHING;
  END IF;
  RETURN NULL;
END $function$;
REVOKE EXECUTE ON FUNCTION public.fn_sync_book_keywords_on_publish() FROM PUBLIC;

CREATE TRIGGER trg_sync_book_keywords_on_publish
  AFTER UPDATE OF status ON public.book_drafts
  FOR EACH ROW
  WHEN (NEW.status = 'published' AND NEW.status IS DISTINCT FROM OLD.status)
  EXECUTE FUNCTION public.fn_sync_book_keywords_on_publish();

NOTIFY pgrst, 'reload schema';
