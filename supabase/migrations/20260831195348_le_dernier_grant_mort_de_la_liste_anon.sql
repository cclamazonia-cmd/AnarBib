-- B2, lot 4, dernier verdict : `list_catalog_libraries` fermée à `anon`.
--
-- L'audit du 30/08 (AUDIT_execute_anon_2026-08-30.md, C.5) avait laissé cette
-- fonction ouverte : son corps réserve la liste aux administrateur·rices
-- réseau (`fn_caller_is_network_admin()`), son nom promet une liste publique,
-- et on ne savait pas lequel des deux mentait. « À trancher avec le frontend
-- avant tout REVOKE. »
--
-- Tranché le 01/09 par les faits : l'unique appelant est le formulaire de
-- catalogage (`BookDraftForm.jsx`), où le choix d'une bibliothèque cible est
-- réservé aux admins réseau PAR DÉCISION (17/08, flux création œuvre/édition).
-- La garde est donc voulue ; c'est le nom qui promet trop, et le COMMENT
-- ci-dessous le dit pour la prochaine lecture. Pour `anon`, la fonction
-- rendait une liste vide : le grant était mort, comme les trois retirés le
-- 30/08 au matin. Le retirer ne change aucun comportement.
--
-- La liste nommée du T10 (grants_herites_tests.sql) perd son entrée dans le
-- même commit : la population attendue du lint 0028 passe de 29 à 28 — le
-- nombre que l'audit du 30/08 annonçait.

REVOKE EXECUTE ON FUNCTION public.list_catalog_libraries() FROM anon;

COMMENT ON FUNCTION public.list_catalog_libraries() IS
  'Bibliothèques au catalogue publié — POUR LES ADMINS RÉSEAU SEULEMENT : le corps garde sur fn_caller_is_network_admin(), et c''est voulu (décision du 17/08 : la bibliothèque cible du catalogage se choisit en admin réseau ; appelant unique : BookDraftForm). Le nom promet plus que la garde ne donne : pour tout autre rôle la liste est vide, ce n''est pas un bug d''affichage. Fermée à anon le 01/09/2026 (B2 lot 4, audit du 30/08 §C.5).';

-- Garde : anon fermé, authenticated intact (l'appelant réel est connecté).
DO $$
BEGIN
  IF has_function_privilege('anon', 'public.list_catalog_libraries()', 'EXECUTE') THEN
    RAISE EXCEPTION 'list_catalog_libraries encore exécutable par anon — rollback';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.list_catalog_libraries()', 'EXECUTE') THEN
    RAISE EXCEPTION 'list_catalog_libraries fermée à authenticated : l''appelant du catalogage casserait — rollback';
  END IF;
END $$;
