-- =========================================================================
-- Paquet L.11 — Bascule api.my_access en security_invoker + doctrine
-- explicite sur api.library_circulation_stats
-- =========================================================================
-- Contexte : deux ERRORs security_definer_view sont apparues post-L.1
-- (probablement via les paquets 24c-* ou des modifications dashboard) :
--   - api.my_access : vue de contexte utilisateur·rice (qui suis-je,
--     quelle biblio, suis-je staff, suis-je admin réseau)
--   - api.library_circulation_stats : vue d'agrégation des statistiques
--     de circulation par bibliothèque
--
-- AUDIT PRÉALABLE (12/05/2026 après-midi) :
--   - api.my_access : logique interne filtre déjà par auth.uid() partout,
--     toutes les tables sources accessibles à authenticated, dépendance
--     my_session_context déjà en security_invoker. Bascule SANS RISQUE.
--   - api.library_circulation_stats : vue d'agrégation pure qui lit
--     emprestimos_v2 / reservas_v2 / consultas_locais_v2 dont les RLS
--     filtrent par staff ou propriétaire de la ligne. En security_invoker
--     les non-staff verraient 0 partout sauf leur propre biblio.
--
-- DOCTRINE POLITIQUE (12/05/2026) :
--   AnarBib distingue deux régimes de transparence :
--     (a) AGRÉGATS STATISTIQUES = TRANSPARENCE TOTALE par doctrine
--         anarchiste de réseau d'entraide. Tout le monde voit combien de
--         prêts dans chaque biblio, combien de lecteur·rices actifs·ves,
--         etc. La force du réseau se construit sur la connaissance
--         partagée de son activité.
--     (b) DONNÉES INDIVIDUELLES = CONFIDENTIALITÉ STRICTE par doctrine
--         de vie privée militante. Qui a emprunté quoi, qui a réservé
--         quoi, qui a consulté quoi : protégé par RLS ligne par ligne.
--
--   library_circulation_stats incarne (a) en s'appuyant sur (b) : la vue
--   en SECURITY DEFINER agrège SANS exposer les lignes individuelles.
--   C'est exactement l'usage légitime du SECURITY DEFINER : réconcilier
--   transparence agrégée et confidentialité individuelle.
--
--   On ASSUME donc le 1 ERROR linter restant sur cette vue, documenté
--   par COMMENT ON VIEW pour traçabilité doctrinale.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Bascule api.my_access en security_invoker=true
-- -------------------------------------------------------------------------
-- Sécurisé parce que :
--   - tous les filtres internes utilisent auth.uid()
--   - toutes les tables sources (profiles, libraries, user_library_memberships,
--     network_administrators) sont SELECT-grantées à authenticated
--   - my_session_context (dépendance) est déjà invoker
--   - aucun usage anon (V3 audit : anon_select=false)

ALTER VIEW api.my_access SET (security_invoker = true);

COMMENT ON VIEW api.my_access IS
  'Contexte de l''utilisateur·rice connecté·e : identité, biblio par '
  'défaut, statuts staff et admin réseau, droits d''accès UI '
  '(can_access_painel, can_access_catalogacao). security_invoker=true '
  'depuis paquet L.11 (12/05/2026). Filtrage interne par auth.uid() '
  'sur user_library_memberships et network_administrators, donc la vue '
  'ne retourne jamais que les données du caller. Accessible à '
  'authenticated uniquement, pas à anon.';

-- -------------------------------------------------------------------------
-- 2. Documentation politique de library_circulation_stats
-- -------------------------------------------------------------------------
-- La vue RESTE en SECURITY DEFINER. Choix politique conscient. Le
-- COMMENT ON VIEW formalise la doctrine pour traçabilité.

COMMENT ON VIEW api.library_circulation_stats IS
  'Agrégats statistiques de circulation par bibliothèque : nombre de '
  'prêts ouverts, prêts en retard, réservations actives, consultations, '
  'top 5 livres empruntés sur 90j, etc. '
  'DOCTRINE : SECURITY DEFINER MAINTENU VOLONTAIREMENT (paquet L.11, '
  '12/05/2026). AnarBib applique deux régimes de transparence : '
  'agrégats statistiques = transparence totale du réseau anarchiste '
  '(tout·e usager·ère voit l''activité de toutes les biblios), '
  'données individuelles = confidentialité stricte (RLS ligne à ligne '
  'sur emprestimos_v2 / reservas_v2 / consultas_locais_v2). Cette vue '
  'agrège SANS exposer les lignes individuelles, ce qui réconcilie les '
  'deux régimes. Le linter signale 1 ERROR security_definer_view sur '
  'cette vue : c''est conscient et documenté.';

-- -------------------------------------------------------------------------
-- 3. Vérification automatique
-- -------------------------------------------------------------------------

DO $$
DECLARE
  v_my_access_mode      text;
  v_circ_stats_mode     text;
  v_my_access_count     int;
  v_circ_stats_count    int;
BEGIN
  -- Test 1 : confirmer le mode des deux vues
  SELECT
    CASE WHEN c.reloptions @> ARRAY['security_invoker=true']
         THEN 'invoker' ELSE 'definer' END
  INTO v_my_access_mode
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'api' AND c.relname = 'my_access';

  IF v_my_access_mode IS DISTINCT FROM 'invoker' THEN
    RAISE EXCEPTION 'Test 1 échec : api.my_access est en mode % au lieu de invoker.',
      COALESCE(v_my_access_mode, '(NULL)');
  END IF;

  SELECT
    CASE WHEN c.reloptions @> ARRAY['security_invoker=true']
         THEN 'invoker' ELSE 'definer' END
  INTO v_circ_stats_mode
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'api' AND c.relname = 'library_circulation_stats';

  IF v_circ_stats_mode IS DISTINCT FROM 'definer' THEN
    RAISE EXCEPTION 'Test 1 échec : api.library_circulation_stats est en mode % au lieu de definer (choix politique).',
      COALESCE(v_circ_stats_mode, '(NULL)');
  END IF;

  -- Test 2 : library_circulation_stats reste lisible et retourne au moins 1 ligne
  --          en contexte authenticated simulé. La vue étant en SECURITY
  --          DEFINER, elle bypass les RLS sources et doit toujours retourner
  --          toutes les biblios actives.
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';

  SELECT count(*) INTO v_circ_stats_count
  FROM api.library_circulation_stats;

  IF v_circ_stats_count < 1 THEN
    RAISE EXCEPTION 'Test 2 échec : library_circulation_stats retourne % lignes en auth, attendu >= 1 (au moins BLMF).',
      v_circ_stats_count;
  END IF;

  RESET ROLE;

  RAISE NOTICE 'Paquet L.11 vérifications OK :';
  RAISE NOTICE '  - api.my_access : mode %', v_my_access_mode;
  RAISE NOTICE '  - api.library_circulation_stats : mode % (conscient, doctrine politique)', v_circ_stats_mode;
  RAISE NOTICE '  - library_circulation_stats retourne % biblios en auth simulé', v_circ_stats_count;
END $$;

COMMIT;

-- =========================================================================
-- Post-conditions
-- =========================================================================
-- - 1 ERROR linter security_definer_view éradiquée (sur api.my_access)
-- - 1 ERROR linter security_definer_view PERSISTE volontairement sur
--   api.library_circulation_stats, documentée doctrinalement
-- - Page Rede continue d'afficher les stats agrégées identiques pour
--   tou·tes les caller·euses authentifié·es (transparence du réseau)
-- - Page Biblioteca (utilise my_access) continue de fonctionner :
--   filtrage interne par auth.uid() préservé en security_invoker
-- =========================================================================
-- Tests manuels recommandés après push :
-- =========================================================================
-- 1. Login en tant que coordenador BLMF (toi)
-- 2. Vérifier que la page Biblioteca de BLMF charge correctement
--    (utilise my_access pour can_access_painel et can_access_catalogacao)
-- 3. Vérifier que la page Rede affiche les stats agrégées de BLMF + BTL
-- 4. Si possible, login en tant que lecteur·rice non-staff et vérifier
--    que la page Rede affiche TOUJOURS les stats agrégées de toutes les
--    biblios (doctrine de transparence du réseau)
-- =========================================================================
-- Rollback ciblé si régression imprévue :
-- =========================================================================
-- ALTER VIEW api.my_access SET (security_invoker = false);
-- =========================================================================
