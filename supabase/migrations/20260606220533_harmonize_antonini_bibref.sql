-- =========================================================================
-- Paquet data — harmonisation de la bib_ref d'Antonini (#3a)
-- =========================================================================
-- Session  : Exemplaires & nettoyage catalogue
-- Auteur   : Xavier + Claude
-- Chantier : Catalogage / conventions de reference (cas Antonini)
--
-- CONTEXTE
-- --------
-- Notice 2453 « Por uma Economia libertaria » (Frederic Antonini) : titre
-- PARTAGE par BLMF (exemplaire BEL-EX-000001) et BTL (SP-EX-000001), mais avec
-- une reference nue « 2453 » hors convention des deux cotes. On garde la notice
-- partagee et on donne a chaque holding son local_bib_ref selon SA convention
-- (BLMF 0000NNN ; BTL BTL-TL-NNNNNN). Le canonique books.bib_ref est aligne sur
-- l'owner (BTL). Les references sont recalculees a l'application (max + 1, en
-- excluant la notice 2453 elle-meme), conformement a next_bib_ref().
-- =========================================================================

BEGIN;

DO $fix$
DECLARE
  v_blmf text;
  v_btl  text;
BEGIN
  -- Garde : etat attendu (refs nues "2453").
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = 2453 AND bib_ref = '2453') THEN
    RAISE EXCEPTION 'abort : la notice 2453 n''est pas dans l''etat attendu (bib_ref=2453).';
  END IF;

  -- Prochaine ref BLMF (largeur >= 7, exclut la notice 2453 elle-meme).
  SELECT lpad((COALESCE(max((substring(COALESCE(NULLIF(h.local_bib_ref,''), b.bib_ref) FROM '^([0-9]{7,})$'))::bigint), 0) + 1)::text, 7, '0')
    INTO v_blmf
    FROM public.book_holdings h
    JOIN public.books b ON b.id = h.book_id
    JOIN public.libraries l ON l.id = h.library_id
   WHERE l.name ILIKE '%Maxwell%' AND h.book_id <> 2453;

  -- Prochaine ref BTL.
  SELECT 'BTL-TL-' || lpad((COALESCE(max((substring(COALESCE(NULLIF(h.local_bib_ref,''), b.bib_ref) FROM '^BTL-TL-([0-9]{6,})$'))::bigint), 0) + 1)::text, 6, '0')
    INTO v_btl
    FROM public.book_holdings h
    JOIN public.books b ON b.id = h.book_id
    JOIN public.libraries l ON l.id = h.library_id
   WHERE l.name ILIKE '%Terra Livre%' AND h.book_id <> 2453;

  -- BLMF : holding 2122 + exemplaire 2458.
  UPDATE public.book_holdings SET local_bib_ref = v_blmf WHERE id = 2122 AND book_id = 2453;
  UPDATE public.exemplares    SET bib_ref = v_blmf, updated_at = now() WHERE id = 2458;

  -- BTL : holding 1130 + exemplaire 2459.
  UPDATE public.book_holdings SET local_bib_ref = v_btl WHERE id = 1130 AND book_id = 2453;
  UPDATE public.exemplares    SET bib_ref = v_btl, updated_at = now() WHERE id = 2459;

  -- Canonique aligne sur l'owner (BTL).
  UPDATE public.books SET bib_ref = v_btl, updated_at = now() WHERE id = 2453;

  RAISE NOTICE 'Antonini (2453) harmonise : BLMF=%, BTL=% (canonique=%)', v_blmf, v_btl, v_btl;
END
$fix$;

COMMIT;

-- =========================================================================
-- Rollback : non automatique (remettre bib_ref/local_bib_ref a '2453' si besoin).
-- =========================================================================
