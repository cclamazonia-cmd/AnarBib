-- fix_book_drafts_tipo_material_case
-- Corrige la casse de tipo_material dans book_drafts ET books.
--
-- Problème : 415 brouillons importés portent 'Livro' (majuscule initiale)
-- alors que le registre de champs frontend (fieldRegistry.js) utilise
-- 'livro' (minuscule). La comparaison case-sensitive de matchMat() échoue
-- → les champs spécifiques au type (ISBN, éditeur, pages…) ne s'affichent
-- pas à la reprise du brouillon.
--
-- En parallèle, 3 livres publiés portent l'ancien code 'folheto' (remplacé
-- par 'tract' dans le registre). Et la CHECK constraint de books inclut
-- encore les codes hérités 'folheto', 'arquivo', 'outro'.
--
-- Fix :
--   book_drafts : (1) LOWER, (2) mapper folheto→tract, (3) CHECK 12 types
--   books       : (4) mapper folheto→tract, (5) resserrer CHECK 12 types

BEGIN;

-- ══════════════════════════════════════════════════════════
-- book_drafts
-- ══════════════════════════════════════════════════════════

-- 1. Normaliser la casse
UPDATE public.book_drafts
  SET tipo_material = LOWER(tipo_material)
  WHERE tipo_material <> LOWER(tipo_material);

-- 2. Mapper les anciens codes
UPDATE public.book_drafts
  SET tipo_material = 'tract'
  WHERE tipo_material IN ('folheto', 'arquivo');

UPDATE public.book_drafts
  SET tipo_material = 'livro'
  WHERE tipo_material = 'outro';

-- 3. Valeurs hors liste → fallback 'livro'
UPDATE public.book_drafts
  SET tipo_material = 'livro'
  WHERE tipo_material IS NULL
     OR tipo_material NOT IN (
       'livro','periodico','tract','cartaz','audio','audiovisual',
       'recurso_digital','dossie','tese','artigo','relatorio','zine'
     );

-- 4. CHECK constraint sur book_drafts
ALTER TABLE public.book_drafts
  DROP CONSTRAINT IF EXISTS book_drafts_tipo_material_check;

ALTER TABLE public.book_drafts
  ADD CONSTRAINT book_drafts_tipo_material_check
  CHECK (tipo_material = ANY (ARRAY[
    'livro','periodico','tract','cartaz','audio','audiovisual',
    'recurso_digital','dossie','tese','artigo','relatorio','zine'
  ]));

-- ══════════════════════════════════════════════════════════
-- books (livres publiés)
-- ══════════════════════════════════════════════════════════

-- 5. Mapper les anciens codes dans books
UPDATE public.books
  SET tipo_material = 'tract'
  WHERE tipo_material IN ('folheto', 'arquivo');

UPDATE public.books
  SET tipo_material = 'livro'
  WHERE tipo_material = 'outro';

-- 6. Resserrer la CHECK (retrait des codes hérités)
ALTER TABLE public.books
  DROP CONSTRAINT IF EXISTS books_tipo_material_check;

ALTER TABLE public.books
  ADD CONSTRAINT books_tipo_material_check
  CHECK (tipo_material = ANY (ARRAY[
    'livro','periodico','tract','cartaz','audio','audiovisual',
    'recurso_digital','dossie','tese','artigo','relatorio','zine'
  ]));

-- ══════════════════════════════════════════════════════════
-- Vérifications
-- ══════════════════════════════════════════════════════════

DO $$
DECLARE
  bad_drafts integer;
  bad_books  integer;
BEGIN
  SELECT count(*) INTO bad_drafts
    FROM public.book_drafts
    WHERE tipo_material <> LOWER(tipo_material);
  IF bad_drafts > 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_1: % brouillons ont encore un tipo_material en casse mixte', bad_drafts;
  END IF;

  SELECT count(*) INTO bad_books
    FROM public.books
    WHERE tipo_material NOT IN (
      'livro','periodico','tract','cartaz','audio','audiovisual',
      'recurso_digital','dossie','tese','artigo','relatorio','zine'
    );
  IF bad_books > 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_2: % livres publiés ont un tipo_material hors liste', bad_books;
  END IF;
END $$;

COMMIT;
