-- ============================================================================
-- Hotfix C.5 - GRANT SELECT manquants sur vues recreees
-- ============================================================================
-- Regression introduite par la migration 20260519200000_paquetC5_views_mv_profils :
-- la recreation DROP + CREATE des vues api.network_overview et
-- api.catalog_list_session_v1 a supprime tous les GRANTs pre-existants.
--
-- Symptome utilisateur : catalogue vide ("Aucune reference trouvee"),
-- dashboard reseau muet, parce que les vues retournent
-- 'permission denied for view' aux roles anon et authenticated.
--
-- Decouvert le 19/05/2026 ~22h apres push C.5 a 17h.
-- Aucune autre vue/MV de C.5 n'est concernee (libraries_public_v1 etait
-- inchangee, MV est lisible sans grant via security_invoker).
--
-- Doctrine apprise : tout DROP VIEW / DROP MATERIALIZED VIEW + CREATE doit
-- IMPERATIVEMENT etre suivi des GRANTs explicites. C'est un piege classique
-- du pattern recreation que les ALTER ne reproduisent pas. A graver dans la
-- doctrine v2.2 (mise a jour Grand Livre Blanc).
-- ============================================================================

BEGIN;

-- api.catalog_list_session_v1 : consomme par CatalogPage (lecteurs loggues)
-- Calquage sur api.catalog_books_public_session_v2 qui a 'authenticated' seul.
GRANT SELECT ON api.catalog_list_session_v1 TO authenticated;

-- api.network_overview : consomme par dashboard reseau (staff loggue uniquement)
GRANT SELECT ON api.network_overview TO authenticated;

-- ---------------------------------------------------------------------------
-- DO block de verification fail-fast
-- ---------------------------------------------------------------------------
DO $verif$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
    FROM information_schema.role_table_grants
   WHERE table_schema = 'api'
     AND table_name IN ('catalog_list_session_v1', 'network_overview')
     AND grantee = 'authenticated'
     AND privilege_type = 'SELECT';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'VERIF_FAIL : %/2 GRANTs SELECT authenticated restaures', v_count;
  END IF;
  RAISE NOTICE 'Hotfix C.5 - Verification OK : GRANTs restaures sur les 2 vues';
END
$verif$;

COMMIT;
