-- =========================================================================
-- José Luis Gutiérrez Molina : une seule fiche (11572 → 10907)
-- =========================================================================
-- Date     : 2026-10-20
-- Chantier : catalogage / autorités
-- Auteur   : Xavier (+ Claude)
--
-- DÉCISION DE XAVIER (20/10/2026, soir) : « fusion 11572 → 10907, puis nom
-- "José Luis Gutiérrez Molina" et tri "Gutiérrez Molina, José Luis" sur
-- 10907 » — puis « fais-le toi ».
--
-- Deux fiches pour l'historien espagnol (né en 1952), même Wikidata Q51862284 :
--   - 10907 « José Luís Gutiérrez Molina », tri « Molina, José Luís Gutiérrez »
--     (08/06, import Terra Livre), enrichie le 26/09 : 1952, ES, langue es ;
--     liée à « Colectividades libertarias en Castilla » (livre 614, œuvre 1350),
--     un alias « Molina, José Luís Gutiérrez » ;
--   - 11572 « José Luis Gutiérrez Molina » (27/09), créée par la scission C9 de
--     la fiche 11420 (Germinal 9, livre 2583) : la recherche d'une fiche
--     existante y était faite à la lettre et n'a pas vu 10907 (« Luís », tri
--     coupé au second nom) ; Q51862284 lui a été posé le 18/10 par une
--     proposition C4 (bebb7a02) qui ne regardait pas s'il était déjà pris.
-- Aucun champ de 11572 n'est perdu (pays et Wikidata identiques, rien d'autre
-- de rempli) ; sa graphie, qui est la bonne, passe à 10907.
--
-- COMMENT. Corps de public.merge_author recopié (sa garde d'arbitre lit
-- auth.uid(), vide en migration), plus audio_track_contributors, comme pour
-- Netchaïev (20261012145557). Garde : les deux fiches existent et portent
-- Q51862284 ; sinon rien ne bouge (rejouable, no-op sur une base sans elles).
-- La graphie n'est réécrite que si 10907 porte encore l'ancienne.
-- =========================================================================

BEGIN;

DO $$
DECLARE
  c_can CONSTANT bigint := 10907;
  c_dup CONSTANT bigint := 11572;
  v_can public.authors%rowtype;
  v_dup public.authors%rowtype;
BEGIN
  SELECT * INTO v_can FROM public.authors WHERE id = c_can;
  SELECT * INTO v_dup FROM public.authors WHERE id = c_dup;
  IF v_dup.id IS NULL THEN
    RAISE NOTICE 'Q51862284 : 11572 n''existe plus — rien à fusionner.';
  ELSE
    IF v_can.id IS NULL
       OR coalesce(btrim(v_can.wikidata_id), '') <> 'Q51862284'
       OR coalesce(btrim(v_dup.wikidata_id), '') <> 'Q51862284' THEN
      RAISE EXCEPTION 'Q51862284 : fiches inattendues (10907 %, 11572 %) — fusion refusée.',
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
                               'duplicate_source_label', v_dup.source_label,
                               'via', 'migration 20261020174232, décision de Xavier du 20/10/2026 : même Wikidata Q51862284'),
            null);

    DELETE FROM public.authors WHERE id = c_dup;
  END IF;

  -- La graphie d'usage (celle de Wikidata et de ses livres), sur la fiche gardée.
  -- L'alias « Molina, José Luís Gutiérrez » reste : l'ancienne forme est retrouvée.
  UPDATE public.authors
     SET preferred_name = 'José Luis Gutiérrez Molina',
         sort_name      = 'Gutiérrez Molina, José Luis',
         updated_at     = now()
   WHERE id = c_can
     AND preferred_name = 'José Luís Gutiérrez Molina'
     AND sort_name      = 'Molina, José Luís Gutiérrez';
END $$;

-- Vérification
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.authors WHERE id = 11572) THEN
    RAISE EXCEPTION 'Q51862284 : 11572 existe encore.';
  END IF;
  -- Base sans ces fiches (banc, rejeu zéro) : rien à vérifier de plus.
  IF EXISTS (SELECT 1 FROM public.authors WHERE id = 10907) THEN
    IF (SELECT count(*) FROM public.authors WHERE wikidata_id = 'Q51862284') <> 1 THEN
      RAISE EXCEPTION 'Q51862284 : encore porté par plusieurs fiches.';
    END IF;
    IF EXISTS (SELECT 1 FROM public.books WHERE id = 2583)
       AND NOT EXISTS (SELECT 1 FROM public.book_contributors bc
                        WHERE bc.author_id = 10907 AND bc.book_id = 2583) THEN
      RAISE EXCEPTION 'Q51862284 : « Germinal » 9 n''est pas rattaché à 10907.';
    END IF;
  END IF;
END $$;

COMMIT;
