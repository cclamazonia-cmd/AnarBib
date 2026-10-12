-- =========================================================================
-- Paquet AUT-VAR, suite — les 8 paires au même Wikidata, fusionnées
-- =========================================================================
-- Date     : 2026-10-12
-- Chantier : catalogage / autorités
-- Auteur   : Xavier (+ Claude)
--
-- DÉCISION DE XAVIER (12/10/2026, 18 h Paris) : « Fusionne aussi les 8 autres
-- paires. » Ce sont les paires que la détection par identifiant
-- (20261012145418) fait remonter : les deux fiches de chaque paire portent le
-- même Wikidata, et aussi le même VIAF et le même ISNI.
--
-- FICHE GARDÉE : la graphie d'usage, et sinon la plus riche.
--   Barrett        10030 « Rafael Barrett »                <- 10287 « Rafael Barret »
--   Guyau          10686 « Jean-Marie Guyau » (7 alias)     <- 10085 « J. M. Guyau »
--   Carone         10162 « Edgard Carone »                  <- 10403 « Edgar Carone »
--   Berneri        10325 « Camillo Berneri »                <- 10201 « Camilo Berneri »
--   Ferrer         10581 « Francisco Ferrer Y Guardia »     <- 11397 (tri « Guàrdia, Francesc Ferrer I. »)
--   Pigault-Lebrun 11445 « Pigault-Lebrun »                 <- 10775 (tri « Lebrun, Pigault »)
--   Marcos         10856 « Subcomandante Insurgente Marcos »<- 11548 « Subcomandante Marcos »
--   Montseny       10910 « Federica Montseny »              <- 10911 « Frederica Montseny »
--
-- COMMENT. Même corps que 20261012145557 (Netchaïev) : celui de
-- public.merge_author, plus audio_track_contributors. Garde par paire : les
-- deux fiches existent et portent le Wikidata attendu ; si la fiche à fusionner
-- n'existe plus, la paire est sautée (rejouable) ; si les identifiants ne
-- concordent plus, tout s'arrête.
-- =========================================================================

BEGIN;

DO $$
DECLARE
  r     record;
  v_can public.authors%rowtype;
  v_dup public.authors%rowtype;
  v_n   int := 0;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      (10030::bigint, 10287::bigint, 'Q353806'),
      (10686, 10085, 'Q707490'),
      (10162, 10403, 'Q10270185'),
      (10325, 10201, 'Q969881'),
      (10581, 11397, 'Q354202'),
      (11445, 10775, 'Q3388279'),
      (10856, 11548, 'Q491635'),
      (10910, 10911, 'Q549307')
    ) AS t(can, dup, qid)
  LOOP
    v_can := NULL; v_dup := NULL;
    SELECT * INTO v_can FROM public.authors WHERE id = r.can;
    SELECT * INTO v_dup FROM public.authors WHERE id = r.dup;
    IF v_dup.id IS NULL THEN
      CONTINUE;  -- déjà fusionnée, ou base sans ces fiches (banc)
    END IF;
    IF v_can.id IS NULL
       OR coalesce(btrim(v_can.wikidata_id), '') <> r.qid
       OR coalesce(btrim(v_dup.wikidata_id), '') <> r.qid THEN
      RAISE EXCEPTION 'AUT-VAR fusion : paire % <- % inattendue (Wikidata % / %) — rien n''est fusionné.',
        r.can, r.dup, v_can.wikidata_id, v_dup.wikidata_id;
    END IF;

    -- Corps de merge_author, recopié.
    UPDATE public.book_contributors SET author_id = r.can WHERE author_id = r.dup;
    INSERT INTO public.book_authors (book_id, author_id, role, ord)
      SELECT book_id, r.can, role, ord FROM public.book_authors WHERE author_id = r.dup
      ON CONFLICT (book_id, author_id, role, ord) DO NOTHING;
    DELETE FROM public.book_authors WHERE author_id = r.dup;
    UPDATE public.author_translations t SET author_id = r.can
      WHERE t.author_id = r.dup
        AND NOT EXISTS (SELECT 1 FROM public.author_translations c
                         WHERE c.author_id = r.can AND c.lang = t.lang);
    UPDATE public.author_name_aliases SET author_id = r.can WHERE author_id = r.dup;
    UPDATE public.author_drafts SET published_author_id = r.can WHERE published_author_id = r.dup;
    UPDATE public.book_draft_contributors SET author_id = r.can WHERE author_id = r.dup;
    UPDATE public.works SET primary_author_id = r.can WHERE primary_author_id = r.dup;
    -- Que merge_author oublie.
    UPDATE public.audio_track_contributors SET author_id = r.can WHERE author_id = r.dup;

    INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
    VALUES ('author', r.can, r.dup,
            jsonb_build_object('duplicate_preferred_name', v_dup.preferred_name,
                               'duplicate_sort_name', v_dup.sort_name,
                               'via', 'migration 20261012160705 (AUT-VAR), décision de Xavier du 12/10/2026 : même Wikidata ' || r.qid),
            null);

    DELETE FROM public.authors WHERE id = r.dup;
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE 'AUT-VAR fusion : % paire(s) fusionnée(s).', v_n;
END $$;

-- Vérification : plus aucune des fiches fusionnées, et plus aucune paire au
-- même Wikidata parmi les fiches gardées.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.authors
              WHERE id IN (10287, 10085, 10403, 10201, 11397, 10775, 11548, 10911)) THEN
    RAISE EXCEPTION 'AUT-VAR fusion : une fiche à fusionner existe encore.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.authors a JOIN public.authors b
                ON b.id <> a.id AND nullif(btrim(b.wikidata_id), '') = nullif(btrim(a.wikidata_id), '')
              WHERE a.id IN (10030, 10686, 10162, 10325, 10581, 11445, 10856, 10910)) THEN
    RAISE EXCEPTION 'AUT-VAR fusion : une fiche gardée partage encore son Wikidata.';
  END IF;
END $$;

COMMIT;
