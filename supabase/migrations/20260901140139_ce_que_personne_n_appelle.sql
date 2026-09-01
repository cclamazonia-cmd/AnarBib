-- B14, schéma `public`, paquet 7 : fermer ce que personne n'appelle.
--
-- ============================================================================
-- LE CRITÈRE, ET SA VÉRIFICATION
-- ============================================================================
-- Une RPC est normalement appelée par le **front**, pas par une autre fonction :
-- « sans appelant en base » ne veut donc rien dire tout seul. Le critère utile
-- croise les deux : sans appelant en base **et** absente du dépôt.
--
--   227 fonctions exposées à `authenticated` n'ont aucun appelant en base
--        (ni fonction, ni policy, ni trigger) ;
--    53 d'entre elles n'apparaissent **nulle part** dans `src/`,
--        `supabase/functions/` ou `scripts/`.
--
-- **Ce critère aurait pu être faux, et il a été éprouvé avant d'être cru.** Le
-- front appelle certaines RPC par une variable (`supabase.rpc(fn, …)`) : si un
-- nom était **construit** par concaténation, aucune recherche textuelle ne le
-- verrait, et la fonction paraîtrait morte en étant vivante. Contrôle fait :
-- aucun nom n'est concaténé ni interpolé — les `fn` dynamiques sont toujours des
-- littéraux choisis dans un ternaire, et les wrappers (`callRpc(rpcName, …)`)
-- reçoivent le nom en clair depuis leur appelant.
--
-- ============================================================================
-- CE QUE CETTE MIGRATION FERME, ET CE QU'ELLE NE FERME PAS
-- ============================================================================
-- Elle ne révoque **pas** les 53. Beaucoup sont des fonctions livrées qui
-- attendent leur écran — tout le prêt entre bibliothèques
-- (`fn_v2_*_interbibliotecas`), le parcours de candidature
-- (`fn_review_library_request`) — et les fermer casserait un chantier en cours
-- au lieu de protéger quoi que ce soit. La liste complète est portée à l'audit
-- comme chantier mesuré ; c'est une décision de priorité, pas un oubli.
--
-- Elle ferme **cinq** fonctions que le dépôt lui-même désigne comme dépréciées
-- ou remplacées, et qui touchent toutes à l'identité des personnes :
--
--   * `fn_assembleia_facilitator_name(uuid)` — rend **prénom et nom** pour un
--     identifiant donné, **sans aucune garde**, et ne répond que si la personne
--     est facilitatrice : elle joint donc une identité *et* un rôle militant.
--     Elle avait été fermée à `anon` le 17/08 ; personne n'avait regardé
--     `authenticated`. Aucun appelant nulle part.
--   * `fn_painel_find_profile_by_email(text)` et `fn_painel_get_profile_by_id(uuid)`
--     — remplacées par `fn_painel_find_profile_by_lookup`, la seule que l'écran
--     appelle. Ironie utile : elles ont reçu ce matin même le correctif d'oracle
--     du paquet 2. **On avait unifié les messages de fonctions que personne
--     n'appelle** — le correctif était juste, la cible ne l'était pas.
--   * `fn_caller_is_administrador()` — son corps ne fait que lever
--     `deprecated: … Use fn_caller_is_network_admin`. Elle documente sa propre
--     mort depuis des mois et restait exécutable.
--   * `fn_team_promote_to_administrador(...)` — `src/lib/teamMutations.js` la
--     déclare « RPC dépréciée en D.8 » dans son en-tête.
--
-- **Le refus vit dans le corps, pas dans le droit** (`DOC-RPC-3`) — sauf quand
-- il n'y a pas de corps à atteindre. Ici aucun écran ne casse, parce qu'aucun
-- écran n'appelle.

REVOKE EXECUTE ON FUNCTION public.fn_assembleia_facilitator_name(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_painel_find_profile_by_email(text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_painel_get_profile_by_id(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_caller_is_administrador() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_team_promote_to_administrador(uuid, uuid) FROM authenticated;

COMMENT ON FUNCTION public.fn_assembleia_facilitator_name(uuid) IS
  'Nom d''une personne facilitatrice d''assemblée. Fermée à authenticated le 01/09/2026 (B14, paquet 7) : elle n''avait AUCUNE garde et joignait une identité à un rôle militant, pour n''importe quel identifiant. Fermée à anon le 17/08 ; authenticated n''avait pas été regardé. Aucun appelant, ni en base ni au dépôt.';

COMMENT ON FUNCTION public.fn_painel_get_profile_by_id(uuid) IS
  'Profil par identifiant, pour le panneau. REMPLACÉE par fn_painel_find_profile_by_lookup, la seule que l''écran appelle. Fermée à authenticated le 01/09/2026 (B14, paquet 7), quelques heures après avoir reçu le correctif d''oracle du paquet 2 : le correctif était juste, la cible ne l''était pas.';

-- ============================================================================
-- GARDES DE FIN
-- ============================================================================
DO $$
DECLARE v_reste text;
BEGIN
  -- 1) Les quatre sont bien fermées.
  SELECT string_agg(p.proname, ', ')
    INTO v_reste
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_assembleia_facilitator_name','fn_painel_find_profile_by_email',
                       'fn_painel_get_profile_by_id','fn_caller_is_administrador',
                       'fn_team_promote_to_administrador')
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE');

  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'révocation sans effet sur : % — rollback', v_reste;
  END IF;

  -- 2) LA fonction que l'écran appelle vraiment reste ouverte. C'est la moitié
  --    qui compte : fermer les remplacées sans garder la remplaçante donnerait
  --    un panneau muet, et la suite de tests du paquet 2 le dit déjà.
  IF NOT has_function_privilege('authenticated', 'public.fn_painel_find_profile_by_lookup(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_painel_find_profile_by_lookup fermée par erreur — le panneau ne trouverait plus personne — rollback';
  END IF;
END $$;
