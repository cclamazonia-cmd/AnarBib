-- =========================================================================
-- Paquet L.10 — Renommage tables _backup_*_20260408 vers _archived_*
-- =========================================================================
-- Contexte : 3 tables nommées _backup_*_20260408 existent dans public
-- depuis le 8 avril 2026, vestiges d'une migration de la chaîne library
-- requests. Elles ne sont référencées par aucune fonction métier active,
-- aucune RLS, aucun trigger. Elles servent uniquement de filet de sécurité
-- en cas de besoin de restauration.
--
-- Choix doctrinal (12/05/2026) : ne pas les supprimer (la traçabilité
-- vaut le coût de stockage) mais les renommer en _archived_* pour signaler
-- clairement à toute personne consultant le schéma qu'elles sont hors
-- workflow actif.
--
-- Risque : nul. Aucun objet ne référence ces tables.
-- =========================================================================

BEGIN;

ALTER TABLE public._backup_library_request_claims_20260408
  RENAME TO _archived_library_request_claims_20260408;

ALTER TABLE public._backup_library_request_notification_events_20260408
  RENAME TO _archived_library_request_notification_events_20260408;

ALTER TABLE public._backup_library_requests_20260408
  RENAME TO _archived_library_requests_20260408;

-- Documentation
COMMENT ON TABLE public._archived_library_request_claims_20260408 IS
  'Archive (renommée de _backup_library_request_claims_20260408 le '
  '12/05/2026 par paquet L.10). Snapshot du 8 avril 2026 conservé pour '
  'traçabilité. Hors workflow actif. À supprimer après période de '
  'rétention (suggéré : 1 an minimum après la migration originale).';

COMMENT ON TABLE public._archived_library_request_notification_events_20260408 IS
  'Archive (renommée de _backup_library_request_notification_events_20260408 '
  'le 12/05/2026 par paquet L.10). Snapshot du 8 avril 2026 conservé pour '
  'traçabilité. Hors workflow actif.';

COMMENT ON TABLE public._archived_library_requests_20260408 IS
  'Archive (renommée de _backup_library_requests_20260408 le 12/05/2026 '
  'par paquet L.10). Snapshot du 8 avril 2026 conservé pour traçabilité. '
  'Hors workflow actif.';

-- Vérification
DO $$
DECLARE
  v_n_archived int;
BEGIN
  SELECT count(*) INTO v_n_archived
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND c.relname LIKE '_archived_%_20260408';
  
  IF v_n_archived <> 3 THEN
    RAISE EXCEPTION 'L.10 vérification échouée : % tables _archived_ trouvées, attendu 3.',
      v_n_archived;
  END IF;
  
  RAISE NOTICE 'L.10 OK : 3 tables archivées renommées';
END $$;

COMMIT;

-- =========================================================================
-- Backlog : à supprimer définitivement après période de rétention
--   DROP TABLE public._archived_library_request_claims_20260408;
--   DROP TABLE public._archived_library_request_notification_events_20260408;
--   DROP TABLE public._archived_library_requests_20260408;
-- =========================================================================
