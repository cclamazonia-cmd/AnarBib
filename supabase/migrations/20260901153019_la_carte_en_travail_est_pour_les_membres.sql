-- B14, paquet 11 (le dernier) : la carte en travail est pour les membres.
--
-- ============================================================================
-- CE QUE LA PASSE DE COMPLÉTUDE A TROUVÉ
-- ============================================================================
-- Le paquet 11 est la passe de clôture de `B14` : le complément des dix
-- critères (24 fonctions, toutes saines) puis le balayage du dernier schéma
-- jamais regardé — `private`, 6 fonctions `SECURITY DEFINER` exposées, servies
-- au travers des vues invoker d'`api`.
--
-- Cinq sont des aides de catalogue anodines. La sixième porte le dernier
-- constat du lot :
--
--   `private.fn_cartography_network_rows` — le corps de
--   `api.cartography_network_v1`, la carte réseau — rendait TOUTES les entrées
--   de cartographie, **y compris les 79 non publiques** (sur 187), à tout
--   compte authentifié. Or l'inscription est ouverte : n'importe qui sait créer
--   un compte. Et une entrée `statut_public = false` peut être une entrée **en
--   attente de consentement** — la doctrine des mentions orphelines exige le
--   consentement avant d'exposer un collectif, et cette carte l'exposait à qui
--   savait s'inscrire.
--
-- Décision du 01/09/2026, posée au collectif et tranchée : **les entrées non
-- publiques sont pour les membres actifs.** Un compte sans adhésion voit la
-- carte publique — la même que les visiteurs — et l'écran (`NetworkMapTab`,
-- derrière une simple `ProtectedRoute`) continue de fonctionner tel quel :
-- il montre moins, il ne casse pas.
--
-- ============================================================================
-- ÉPREUVE (production, transaction annulée, avant écriture)
-- ============================================================================
--   total=187, publiques=108
--   compte sans adhésion  -> voit 108 (les publiques seulement)
--   membre actif          -> voit 187 (tout)
--
-- La forme est celle des paquets précédents : `pg_get_functiondef`, une
-- substitution vérifiée, jamais un corps retapé.

DO $$
DECLARE
  v_def text;
  v_new text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'private' AND p.proname = 'fn_cartography_network_rows';

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'private.fn_cartography_network_rows introuvable — migration interrompue';
  END IF;

  v_new := replace(v_def,
    'CROSS JOIN LATERAL (SELECT public.fn_caller_is_network_admin() AS is_admin) a;',
    'CROSS JOIN LATERAL (SELECT public.fn_caller_is_network_admin() AS is_admin) a
  -- Les entrées NON publiques sont pour les membres : une entrée peut attendre
  -- un consentement, et « savoir créer un compte » n''est pas un cercle de
  -- confiance (B14 paquet 11, décision du 01/09/2026). Un compte sans adhésion
  -- voit la carte publique — l''écran montre moins, il ne casse pas.
  WHERE ce.statut_public
     OR a.is_admin
     OR EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.status = ''active'');');

  IF v_new = v_def THEN
    RAISE EXCEPTION 'motif non substitué — la fonction a changé de forme, migration interrompue plutôt que sans effet';
  END IF;

  EXECUTE v_new;
END $$;

COMMENT ON FUNCTION private.fn_cartography_network_rows() IS
  'Corps de api.cartography_network_v1 (la carte réseau des membres). Depuis le 01/09/2026 (B14, paquet 11), les entrées NON publiques ne sont rendues qu''aux membres actifs et à l''administration du réseau : une entrée statut_public=false peut être en attente de consentement, et l''inscription est ouverte — « savoir créer un compte » n''est pas un cercle de confiance. Un compte sans adhésion voit la carte publique.';

-- ============================================================================
-- GARDE DE FIN
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'private' AND p.proname = 'fn_cartography_network_rows'
       AND p.prosrc ~ 'statut_public'
       AND p.prosrc ~ 'user_library_memberships'
  ) THEN
    RAISE EXCEPTION 'la garde de membrance n''est pas dans le corps — rollback';
  END IF;

  -- La vue PUBLIQUE n'a pas été touchée : elle doit continuer de servir anon.
  IF NOT has_table_privilege('anon', 'api.cartography_public_v1', 'SELECT') THEN
    RAISE EXCEPTION 'la carte publique a perdu anon — la page visiteurs casserait — rollback';
  END IF;
END $$;
