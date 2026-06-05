-- =========================================================================
-- Paquet fix (donnees) — nettoyage corruption autorites LENOIR
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorites (suite du bug clé de traductions sur id de brouillon)
-- Auteur   : Xavier + Claude
--
-- CONTEXTE
-- --------
-- Le bug "traductions clé sur l'id de brouillon" (corrige cote frontend le
-- 05/06) a provoque :
--   - 8 traductions de la bio de Hugues LENOIR ecrites a tort sous
--     author_id = 10 (= Murray BOOKCHIN, collision draft_id/author_id) ;
--   - 3 autorites LENOIR doublons vides (10117, 10118, 10119), sans livre ni
--     traduction, issues de publications repetees.
--
-- REPARATION (validee avec Xavier le 05/06)
-- -----------------------------------------
--   1. Supprimer les 8 traductions LENOIR polluant Bookchin (author_id = 10).
--   2. Preserver la saisie : repasser le brouillon 10 en 'draft' editable
--      (published_author_id = NULL) pour republication propre.
--   3. Supprimer le brouillon doublon 9.
--   4. Supprimer les 3 autorites doublons vides (10117, 10118, 10119).
--   (10092, autre LENOIR vide ancien, laisse en place — hors scope valide.)
--
-- Garde : on refuse de supprimer une autorite qui aurait acquis un livre ou une
-- traduction entre-temps.
-- =========================================================================

BEGIN;

-- 1. Traductions LENOIR mal rattachees a Bookchin (id 10).
-- Les 8 lignes sous author_id=10 sont toutes la bio de Lenoir (contamination) :
-- Bookchin n'avait aucune traduction legitime (un eventuel original aurait ete
-- ecrase par l'upsert onConflict). Suppression integrale de ces lignes.
DELETE FROM public.author_translations WHERE author_id = 10;

-- 2. Preserver la saisie du brouillon 10 (republication propre ensuite).
UPDATE public.author_drafts
SET published_author_id = NULL, status = 'draft', updated_at = now()
WHERE id = 10;

-- 3. Supprimer le brouillon doublon 9 (pointe vers 10118, supprime en 4).
DELETE FROM public.author_drafts WHERE id = 9;

-- 4. Supprimer les autorites doublons vides, avec garde de securite.
DO $$
DECLARE
  v_blocked bigint;
BEGIN
  SELECT a.id INTO v_blocked
  FROM public.authors a
  WHERE a.id IN (10117, 10118, 10119)
    AND ( (SELECT count(*) FROM public.book_authors ba WHERE ba.author_id = a.id) > 0
       OR (SELECT count(*) FROM public.author_translations t WHERE t.author_id = a.id) > 0 )
  LIMIT 1;

  IF v_blocked IS NOT NULL THEN
    RAISE EXCEPTION 'Autorite % a acquis livre/traduction : suppression annulee (rollback).', v_blocked;
  END IF;

  DELETE FROM public.authors WHERE id IN (10117, 10118, 10119);
END $$;

COMMIT;
