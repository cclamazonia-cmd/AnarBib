-- =========================================================================
-- Paquet AUT-VAR, suite — Netchaïev : une seule fiche (10950 → 11577)
-- =========================================================================
-- Date     : 2026-10-12
-- Chantier : catalogage / autorités
-- Auteur   : Xavier (+ Claude)
--
-- DÉCISION DE XAVIER (12/10/2026, 17 h Paris) : « garde 11577 ».
-- Deux fiches pour Sergueï Netchaïev, même Wikidata (Q430883), même VIAF
-- (59205185), même ISNI :
--   - 10950 « Sergei Nechayev » (08/06), sans biographie, liée à
--     « Catechism of the Revolutionist » (livre 639), un alias « Nechayev, Sergei »,
--     une œuvre ;
--   - 11577 « Serge Netchaïev » (12/10), portrait, biographie en 10 langues,
--     graphies Wikidata.
-- La détection de doublons ne les voyait pas (noms à 0,19) : corrigé par
-- 20261012145418. La fusion se fait ici une fois pour toutes.
--
-- COMMENT. Corps de public.merge_author recopié (sa garde d'arbitre lit
-- auth.uid(), vide en migration), plus audio_track_contributors que
-- merge_author ne déplace pas (0 ligne ici, mais la FK est ON DELETE SET NULL :
-- on ne perd rien en silence). Garde : les deux fiches existent et portent le
-- même Wikidata ; sinon rien ne bouge (rejouable, no-op après coup).
-- L'alias de 10950 passe à 11577 : « Nechayev, Sergei » reste une forme connue.
-- =========================================================================

BEGIN;

DO $$
DECLARE
  c_can CONSTANT bigint := 11577;
  c_dup CONSTANT bigint := 10950;
  v_can public.authors%rowtype;
  v_dup public.authors%rowtype;
BEGIN
  SELECT * INTO v_can FROM public.authors WHERE id = c_can;
  SELECT * INTO v_dup FROM public.authors WHERE id = c_dup;
  IF v_dup.id IS NULL THEN
    RAISE NOTICE 'AUT-VAR fusion : 10950 n''existe plus — rien à faire.';
    RETURN;
  END IF;
  IF v_can.id IS NULL
     OR coalesce(btrim(v_can.wikidata_id), '') <> 'Q430883'
     OR coalesce(btrim(v_dup.wikidata_id), '') <> 'Q430883' THEN
    RAISE EXCEPTION 'AUT-VAR fusion : fiches inattendues (11577 %, 10950 %) — fusion refusée.',
      v_can.wikidata_id, v_dup.wikidata_id;
  END IF;

  -- Corps de merge_author, recopié.
  UPDATE public.book_contributors SET author_id = c_can WHERE author_id = c_dup;
  INSERT INTO public.book_authors (book_id, author_id, role, ord)
    SELECT book_id, c_can, role, ord FROM public.book_authors WHERE author_id = c_dup
    ON CONFLICT (book_id, author_id, role, ord) DO NOTHING;
  DELETE FROM public.book_authors WHERE author_id = c_dup;
  UPDATE public.author_translations t SET author_id = c_can
    WHERE t.author_id = c_dup
      AND NOT EXISTS (SELECT 1 FROM public.author_translations c
                       WHERE c.author_id = c_can AND c.lang = t.lang);
  UPDATE public.author_name_aliases SET author_id = c_can WHERE author_id = c_dup;
  UPDATE public.author_drafts SET published_author_id = c_can WHERE published_author_id = c_dup;
  UPDATE public.book_draft_contributors SET author_id = c_can WHERE author_id = c_dup;
  UPDATE public.works SET primary_author_id = c_can WHERE primary_author_id = c_dup;
  -- Que merge_author oublie.
  UPDATE public.audio_track_contributors SET author_id = c_can WHERE author_id = c_dup;

  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('author', c_can, c_dup,
          jsonb_build_object('duplicate_preferred_name', v_dup.preferred_name,
                             'duplicate_sort_name', v_dup.sort_name,
                             'via', 'migration 20261012145557 (AUT-VAR), décision de Xavier du 12/10/2026 : même Wikidata Q430883'),
          null);

  DELETE FROM public.authors WHERE id = c_dup;
END $$;

-- Vérification
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.authors WHERE id = 10950) THEN
    RAISE EXCEPTION 'AUT-VAR fusion : 10950 existe encore.';
  END IF;
  -- Base sans ces fiches (banc, rejeu zéro) : rien à vérifier de plus.
  IF EXISTS (SELECT 1 FROM public.books WHERE id = 639)
     AND EXISTS (SELECT 1 FROM public.authors WHERE id = 11577)
     AND NOT EXISTS (SELECT 1 FROM public.book_contributors bc
                      WHERE bc.author_id = 11577 AND bc.book_id = 639) THEN
    RAISE EXCEPTION 'AUT-VAR fusion : « Catechism of the Revolutionist » n''est pas rattaché à 11577.';
  END IF;
END $$;

COMMIT;
