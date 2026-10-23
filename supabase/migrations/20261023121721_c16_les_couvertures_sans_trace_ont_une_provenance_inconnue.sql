-- =====================================================================
-- C16 — les couvertures publiées sans trace reçoivent une provenance
-- « unknown », assumée (décision Xavier, 23/10/2026 ; REGISTRE CAPAS-8)
--
-- La provenance des couvertures (books.cover_source) n'est tenue que depuis
-- le 27/09/2026 (20260927130518, règle des trois endroits). Le stock posé
-- avant n'en a pas : 244 notices publiées avec couverture et sans provenance
-- le 23/10 (sur 1 158). Xavier a tranché : ne pas chercher de trace, poser
-- « unknown » sur tout ce stock et l'assumer par écrit (CAPAS-8). La licence
-- (cover_license) reste vide : elle n'est pas connue non plus.
--
-- Valeurs en usage dans cover_source : manual, pdf_page1, openlibrary,
-- inventaire, photo ; « unknown » s'y ajoute. Seules les lignes encore sans
-- provenance sont touchées ; rejouée, la migration ne fait rien.
-- =====================================================================

DO $$
DECLARE
  v_n int;
BEGIN
  UPDATE public.books
     SET cover_source = 'unknown'
   WHERE cover_object_path IS NOT NULL
     AND coalesce(btrim(cover_source), '') = '';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'C16 : % couverture(s) publiée(s) en provenance « unknown »', v_n;

  IF EXISTS (SELECT 1 FROM public.books WHERE cover_object_path IS NOT NULL AND coalesce(btrim(cover_source), '') = '') THEN
    RAISE EXCEPTION 'C16 : il reste des couvertures publiées sans provenance';
  END IF;
END $$;
