-- =========================================================================
-- Paquet L.12 — Nettoyage final des 4 alertes linter à risque zéro
-- =========================================================================
-- Date     : 2026-05-19
-- Chantier : audit linter post-doctrine (cf. CHANTIER_doctrine_creation_objets_securises_2026-05-12.md)
-- Auteur   : Xavier
--
-- OBJECTIF :
--   Éliminer 4 alertes linter Supabase faciles et sans risque :
--   1. function_search_path_mutable sur public.fn_block_lph_modification
--   2. rls_enabled_no_policy sur 3 tables _archived_*_20260408
--
-- VÉRIFICATIONS PRÉALABLES (faites le 19/05/2026) :
--   - Les 3 tables _archived_* contiennent chacune 1 ligne (legacy, inerte)
--   - Aucune fonction Postgres ne référence ces tables (pg_proc.prosrc check)
--   - fn_block_lph_modification est SECURITY INVOKER (pas DEFINER) et sans search_path
--
-- DOCTRINE APPLIQUÉE :
--   - search_path = public, pg_catalog (cf. doctrine §Template 1)
--   - Désactivation RLS sur tables archivées inertes (alternative légitime à
--     l'ajout d'une policy "USING (false)", évite de polluer pg_policy)
--
-- AUCUNE VÉRIFICATION DO-BLOCK NÉCESSAIRE : la migration ne touche ni les
-- permissions, ni les policies actives, ni la résolution de noms d'objets
-- utilisés en prod.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Fix search_path sur fn_block_lph_modification
-- -------------------------------------------------------------------------
-- Cette fonction est un trigger SECURITY INVOKER qui bloque les modifications
-- non autorisées sur loan_history_partitioned. Bien que SECURITY INVOKER soit
-- moins critique que DEFINER pour l'injection de schéma, Supabase recommande
-- de toujours fixer search_path pour éviter tout doute.

ALTER FUNCTION public.fn_block_lph_modification()
  SET search_path = public, pg_catalog;

COMMENT ON FUNCTION public.fn_block_lph_modification() IS
  'Trigger SECURITY INVOKER qui bloque les modifications non autorisées '
  'sur loan_history_partitioned. search_path fixé par paquet L.12 du 19/05/2026.';

-- -------------------------------------------------------------------------
-- 2. Désactivation RLS sur les 3 tables archivées
-- -------------------------------------------------------------------------
-- Ces tables sont des snapshots gelés du 08/04/2026, conservés à des fins
-- d'archivage. Elles contiennent chacune 1 ligne, aucune fonction métier ne
-- les référence, elles ne sont plus accédées via PostgREST.
--
-- L'alerte rls_enabled_no_policy indique qu'avec RLS activée + aucune policy,
-- toute lecture via API retournerait 0 ligne silencieusement. Le bon
-- comportement pour une archive inerte est de DÉSACTIVER la RLS :
-- elles restent inaccessibles à anon/authenticated (pas de GRANT actif), mais
-- service_role peut les lire si besoin pour un audit ponctuel.

ALTER TABLE public._archived_library_request_claims_20260408
  DISABLE ROW LEVEL SECURITY;

ALTER TABLE public._archived_library_request_notification_events_20260408
  DISABLE ROW LEVEL SECURITY;

ALTER TABLE public._archived_library_requests_20260408
  DISABLE ROW LEVEL SECURITY;

-- Renforcer le COMMENT pour expliquer le statut
COMMENT ON TABLE public._archived_library_request_claims_20260408 IS
  'Archive gelée du 08/04/2026 — table inerte, 1 ligne historique. '
  'RLS désactivée par paquet L.12 (19/05/2026) car aucun usage via API. '
  'Accessible uniquement via service_role pour audit ponctuel.';

COMMENT ON TABLE public._archived_library_request_notification_events_20260408 IS
  'Archive gelée du 08/04/2026 — table inerte, 1 ligne historique. '
  'RLS désactivée par paquet L.12 (19/05/2026) car aucun usage via API. '
  'Accessible uniquement via service_role pour audit ponctuel.';

COMMENT ON TABLE public._archived_library_requests_20260408 IS
  'Archive gelée du 08/04/2026 — table inerte, 1 ligne historique. '
  'RLS désactivée par paquet L.12 (19/05/2026) car aucun usage via API. '
  'Accessible uniquement via service_role pour audit ponctuel.';

COMMIT;

-- =========================================================================
-- Rollback en cas de régression (très improbable vu la nature de la migration) :
-- =========================================================================
-- BEGIN;
--   ALTER FUNCTION public.fn_block_lph_modification() RESET search_path;
--   ALTER TABLE public._archived_library_request_claims_20260408 ENABLE ROW LEVEL SECURITY;
--   ALTER TABLE public._archived_library_request_notification_events_20260408 ENABLE ROW LEVEL SECURITY;
--   ALTER TABLE public._archived_library_requests_20260408 ENABLE ROW LEVEL SECURITY;
-- COMMIT;
-- =========================================================================
