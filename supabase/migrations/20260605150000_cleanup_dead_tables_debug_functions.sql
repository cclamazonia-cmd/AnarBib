-- 20260605150000_cleanup_dead_tables_debug_functions.sql
--
-- P4 -- nettoyage : suppression de tables de sauvegarde mortes et de fonctions
-- debug orphelines. Toutes les operations sont gardees par IF EXISTS (idempotent).
--
-- Verifie le 2026-06-05 (lecture seule) :
--   - 0 FK entrante vers les 4 tables ci-dessous -> aucun risque de cascade.
--   - Comptes : _archived_*_20260408 = 1 ligne chacune ; book_authors_backup_suspect_mono = 56 lignes.
--     Ce sont des copies de sauvegarde ; les donnees vivantes sont ailleurs.
--   - import_terra_livre_zotero_staging (2265 lignes) = CONSERVEE (import en cours) -> DROP commente.
--   - fn_my_account_status (la vraie, invoker) = CONSERVEE ; seules les variantes debug/probe partent.
--
-- Les DROP FUNCTION sont SANS CASCADE a dessein : si une dependance existait
-- encore, le DROP echouerait bruyamment (pipeline rouge) plutot que de casser
-- quelque chose en silence. Si ca arrive, ne force pas -> signale-le.

-- 1) Tables de sauvegarde mortes (aucune FK entrante)
DROP TABLE IF EXISTS public._archived_library_requests_20260408;
DROP TABLE IF EXISTS public._archived_library_request_claims_20260408;
DROP TABLE IF EXISTS public._archived_library_request_notification_events_20260408;
DROP TABLE IF EXISTS public.book_authors_backup_suspect_mono;

-- 2) CONSERVE : staging d'import Zotero en cours d'utilisation.
--    NE PAS decommenter tant que l'import n'est pas termine.
-- DROP TABLE IF EXISTS public.import_terra_livre_zotero_staging;

-- 3) Fonctions debug/probe orphelines (la fonction de prod fn_my_account_status reste)
DROP FUNCTION IF EXISTS public.fn_my_account_status_debug();
DROP FUNCTION IF EXISTS public.fn_my_account_status_debug2();
DROP FUNCTION IF EXISTS public.fn_my_account_status_debug3();
DROP FUNCTION IF EXISTS public.fn_my_account_status_debug4();
DROP FUNCTION IF EXISTS public.fn_my_account_status_probe();
