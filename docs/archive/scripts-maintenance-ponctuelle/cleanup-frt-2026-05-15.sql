-- ============================================================
-- ARCHIVE. Deplace de `tests/sql/` le 29/08/2026 (backlog v34, item I14).
--
-- Ce fichier n'a jamais ete une suite de tests : c'est un script de menage
-- ponctuel, a passer une fois a la main, et il ne figure pas a
-- `tests/sql/ci-suites.txt`. Il nomme l'identifiant REEL de la bibliotheque
-- FRT en production -- ce qui est normal pour un script de maintenance, et
-- inacceptable au milieu de fixtures de test, ou la meme chaine se lit comme
-- une donnee inventee.
--
-- Le menage a eu lieu : la bibliotheque FRT n'existe plus en base
-- (verifie le 29/08/2026). Le script est donc epuise ; il est conserve pour
-- la trace, pas pour etre rejoue.
-- ============================================================

-- ============================================================
-- Cleanup biblio FRT (test résiduel d'avril 2026)
-- À exécuter dans Supabase SQL Editor, manuellement, en une fois
-- ============================================================
-- Contexte : la biblio FRT (id ab36f7a8-...) a été créée le 8 avril
-- comme test. Elle est is_active=false, visibility=private, et n'a
-- AUCUNE donnée métier vivante (0 membership, 0 holding).
-- Seules 2 lignes de config par défaut existent (library_commons,
-- library_service_state) qui partiront automatiquement si les FK
-- sont en CASCADE.
-- ============================================================

BEGIN;

-- 1. Re-vérification finale (rollback si quoi que ce soit a changé depuis)
DO $$
DECLARE
  v_memberships int;
  v_holdings int;
BEGIN
  SELECT count(*) INTO v_memberships 
    FROM public.user_library_memberships 
    WHERE library_id = 'ab36f7a8-1fa1-4701-9c46-f534d795359d';
  
  SELECT count(*) INTO v_holdings 
    FROM public.book_holdings 
    WHERE library_id = 'ab36f7a8-1fa1-4701-9c46-f534d795359d';
  
  IF v_memberships > 0 OR v_holdings > 0 THEN
    RAISE EXCEPTION 'Donnees metier presentes sur FRT (memberships=%, holdings=%), abandon du cleanup', 
      v_memberships, v_holdings;
  END IF;
  
  RAISE NOTICE 'Verification OK : aucune donnee metier sur FRT';
END $$;

-- 2. Suppression manuelle des lignes de config (au cas où CASCADE pas configuré)
-- Ces DELETE sont idempotents : si CASCADE est actif, ils ne suppriment rien
-- (déjà supprimé par le DELETE 3). Si CASCADE pas actif, ils nettoient avant.
DELETE FROM public.library_commons 
  WHERE library_id = 'ab36f7a8-1fa1-4701-9c46-f534d795359d';

DELETE FROM public.library_service_state 
  WHERE library_id = 'ab36f7a8-1fa1-4701-9c46-f534d795359d';

-- 3. Suppression de la ligne libraries
DELETE FROM public.libraries 
  WHERE id = 'ab36f7a8-1fa1-4701-9c46-f534d795359d';

-- 4. Vérification post-cleanup
DO $$
DECLARE
  v_remaining int;
  v_total_libs int;
BEGIN
  SELECT count(*) INTO v_remaining 
    FROM public.libraries 
    WHERE id = 'ab36f7a8-1fa1-4701-9c46-f534d795359d';
  
  IF v_remaining > 0 THEN
    RAISE EXCEPTION 'Echec cleanup : biblio FRT toujours presente';
  END IF;
  
  SELECT count(*) INTO v_total_libs FROM public.libraries;
  RAISE NOTICE 'Cleanup OK : biblio FRT supprimee. Total biblios restantes : %', v_total_libs;
END $$;

-- 5. Si tout est OK, COMMIT explicite (sinon ROLLBACK manuel)
COMMIT;

-- ============================================================
-- Apres execution :
-- - libraries doit contenir 2 lignes : BLMF et BTL
-- - library_commons et library_service_state nettoyes
-- - tracer dans docs/decisions/CLEANUP_FRT_2026-05-15.md
-- ============================================================
