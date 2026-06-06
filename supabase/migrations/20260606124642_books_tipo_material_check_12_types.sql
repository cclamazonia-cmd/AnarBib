-- =========================================================================
-- Fix — books_tipo_material_check désynchronisé (bloque la publication)
-- =========================================================================
-- Date     : 2026-06-06 (horodatage UTC réel)
-- Chantier : catalogação — types de matériel
--
-- BUG (constaté en prod, repro « Batalha em Seattle » / DVD audiovisuel)
-- --------------------------------------------------------------------
--   La contrainte CHECK `books_tipo_material_check` n'autorisait que l'ancien
--   set ['livro','periodico','folheto','arquivo','zine','outro']. L'extension
--   Track A à 12 types (CAT-E8/Lot 3b) a élargi le formulaire et book_drafts
--   (qui n'a AUCUN CHECK sur tipo_material), mais PAS `books`. Conséquence :
--   le brouillon accepte 'audiovisual' (et tract/cartaz/audio/recurso_digital/
--   dossie/tese/artigo/relatorio), mais la PUBLICATION vers `books` viole le
--   CHECK → « new row for relation "books" violates check constraint
--   books_tipo_material_check ». Seuls livro/periodico/zine publiaient.
--   Message d'erreur trompeur (laisse croire à une colonne manquante).
--
-- CORRECTIF
--   Élargir le CHECK aux 12 types courants du registre (fieldRegistry.js
--   MATERIAL_TYPE_KEYS) + conserver les valeurs legacy présentes/anciennes
--   (folheto : 3 lignes en base ; arquivo ; outro) pour ne casser aucune
--   ligne existante. book_drafts reste sans CHECK (statu quo).
-- =========================================================================

BEGIN;

ALTER TABLE public.books DROP CONSTRAINT IF EXISTS books_tipo_material_check;

ALTER TABLE public.books
  ADD CONSTRAINT books_tipo_material_check
  CHECK (tipo_material = ANY (ARRAY[
    -- 12 types courants (registre Track A)
    'livro'::text, 'periodico'::text, 'tract'::text, 'cartaz'::text,
    'audio'::text, 'audiovisual'::text, 'recurso_digital'::text, 'dossie'::text,
    'tese'::text, 'artigo'::text, 'relatorio'::text, 'zine'::text,
    -- legacy conservés (données existantes / ancien CHECK)
    'folheto'::text, 'arquivo'::text, 'outro'::text
  ]));

-- -------------------------------------------------------------------------
-- Vérification : le nouveau CHECK accepte 'audiovisual' et préserve l'existant
-- -------------------------------------------------------------------------
DO $verif$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_constraintdef(oid) INTO v_def
  FROM pg_constraint WHERE conname = 'books_tipo_material_check'
    AND conrelid = 'public.books'::regclass;
  IF v_def IS NULL THEN
    RAISE EXCEPTION 'VERIF_FAIL_1 : contrainte absente';
  END IF;
  IF position('audiovisual' IN v_def) = 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_2 : audiovisual non autorisé';
  END IF;
  IF position('folheto' IN v_def) = 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_3 : legacy folheto perdu (3 lignes existantes)';
  END IF;
  -- aucune ligne existante ne doit violer (sinon ADD CONSTRAINT aurait échoué,
  -- mais on double-vérifie la cohérence des données)
  IF EXISTS (
    SELECT 1 FROM public.books
    WHERE tipo_material IS NOT NULL
      AND tipo_material <> ALL (ARRAY['livro','periodico','tract','cartaz','audio',
        'audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine',
        'folheto','arquivo','outro'])
  ) THEN
    RAISE EXCEPTION 'VERIF_FAIL_4 : valeurs tipo_material hors liste en base';
  END IF;
END
$verif$;

COMMIT;

-- =========================================================================
-- Rollback (déconseillé — rebloquerait la publication des 9 types récents) :
--   ALTER TABLE public.books DROP CONSTRAINT books_tipo_material_check;
--   ALTER TABLE public.books ADD CONSTRAINT books_tipo_material_check
--     CHECK (tipo_material = ANY (ARRAY['livro','periodico','folheto','arquivo','zine','outro']));
-- =========================================================================
