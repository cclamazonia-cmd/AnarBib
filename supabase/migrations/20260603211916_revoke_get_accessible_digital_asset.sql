-- ════════════════════════════════════════════════════════════════════════
-- DOC-OBJ-2 : verrou EXECUTE sur get_accessible_digital_asset_by_id_v2
-- ════════════════════════════════════════════════════════════════════════
-- Fonction SECURITY DEFINER (search_path TO public deja fige, OK) mais SANS
-- aucun GRANT/REVOKE explicite : EXECUTE ouvert a PUBLIC / service_role par
-- defaut. Audit du corps (03/06) : le gating interne est sain -- le WHERE ne
-- renvoie l'actif que si access_scope='publico' OU (access_scope='conta_ativa'
-- ET fn_current_user_conta_ativa()) -- donc pas de fuite active. Mais la
-- doctrine DOC-OBJ-2 exige le verrou explicite.
--
-- Appelee directement depuis le frontend (.rpc) par anon (actifs publico) et
-- authenticated (actifs conta_ativa). Aucun appelant interne, aucun usage
-- service_role. => REVOKE de tous (PUBLIC seul insuffisant : Supabase re-grant
-- par ALTER DEFAULT PRIVILEGES), puis GRANT EXECUTE aux deux seuls roles vises.
-- Aucune modification du corps de la fonction.
-- ════════════════════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION public.get_accessible_digital_asset_by_id_v2(bigint)
  FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.get_accessible_digital_asset_by_id_v2(bigint)
  TO anon, authenticated;

-- Verification en fin de transaction : le grant fonctionnel doit avoir pris
-- (sinon RAISE EXCEPTION -> rollback auto). Le retrait service_role est verifie
-- en soft (non bloquant : un re-grant par defaut privileges resterait benin ici,
-- le gating interne de la fonction restant la garde reelle).
DO $verify$
DECLARE
  v_fn text := 'public.get_accessible_digital_asset_by_id_v2(bigint)';
BEGIN
  IF NOT has_function_privilege('anon', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'anon doit pouvoir EXECUTE % (grant fonctionnel manquant)', v_fn;
  END IF;
  IF NOT has_function_privilege('authenticated', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated doit pouvoir EXECUTE % (grant fonctionnel manquant)', v_fn;
  END IF;
  IF has_function_privilege('service_role', v_fn, 'EXECUTE') THEN
    RAISE NOTICE 'service_role conserve EXECUTE sur % (re-grant defaut privileges possible) - non bloquant', v_fn;
  END IF;
END
$verify$;
