-- B20, lot cartographie : deux fonctions mortes fermées, la troisième branchée.
--
-- ============================================================================
-- LE TRI, ET SES MESURES (02/09/2026)
-- ============================================================================
-- Trois fonctions du lot cartographie n'avaient aucun appelant (GLB v17 ch. 6,
-- contre-vérifié : grep dépôt 0 occurrence, 0 appelant SQL/policy/cron).
-- Le tri les sépare :
--
-- * `fn_cartography_toggle_public` — REDONDANTE des deux côtés : son public
--   « staff de la biblio liée » passe par `fn_cartography_update_self` (câblée,
--   couvre `statut_public`), son public « coordination » par
--   `fn_cartography_update_admin` (câblée, idem). Fermée.
-- * `fn_cartography_create_entry` — JAMAIS SERVIE, même pas à l'amorçage :
--   les 187 entrées viennent de deux imports uMap (18 et 25/06), et les ajouts
--   passent par la soumission publique (Altcha) + modération. Fermée ; la
--   restauration est un GRANT le jour où un écran de création admin est dû.
-- * `fn_cartography_delete` — SEUL chemin de retrait d'une fiche, et le besoin
--   est réel : la carte expose 105 entrées publiques sur des collectifs tiers
--   (adresse, e-mail, tél). Un collectif qui demande son retrait ne doit pas
--   dépendre d'un SQL à la main. BRANCHÉE ce jour dans CartographyEditModal
--   (coordination seule) — pas touchée ici.
--
-- ACL lue AVANT d'écrire (leçon de 20260902092104, le matin même) :
-- {postgres=X, authenticated=X} — grant explicite, pas d'entrée PUBLIC héritée.
-- Le REVOKE nomme quand même les trois cibles, par ceinture : les deux
-- mécanismes de grant sont indépendants (cf. B2, 30/08).

REVOKE EXECUTE ON FUNCTION api.fn_cartography_create_entry(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION api.fn_cartography_toggle_public(uuid, boolean) FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  v_reste text;
BEGIN
  SELECT string_agg(p.proname, ', ') INTO v_reste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('fn_cartography_create_entry','fn_cartography_toggle_public')
    AND (has_function_privilege('authenticated', p.oid, 'EXECUTE')
      OR has_function_privilege('anon', p.oid, 'EXECUTE'));
  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'révocation sans effet sur : % — rollback', v_reste;
  END IF;

  -- La fonction branchée aujourd'hui garde son EXECUTE : la fermer ici
  -- rendrait muet le bouton livré dans le même commit.
  IF NOT has_function_privilege('authenticated', 'api.fn_cartography_delete(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_cartography_delete fermée par erreur — le bouton de retrait serait muet — rollback';
  END IF;
END $$;
