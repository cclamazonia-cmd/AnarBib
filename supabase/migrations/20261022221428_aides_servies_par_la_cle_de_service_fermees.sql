-- ===========================================================================
-- Advisors 0028 et 0029 — trois fonctions SECURITY DEFINER que seule la clé
-- de service appelle, fermées à anon et à authenticated.
--
-- Relevé du 23/10/2026 (Security Advisor) : 466 WARN = 444 (0029) + 22 (0028),
-- 0011 = 0, rls_enabled_no_policy = 33 (INFO).
--
-- Passe refaite (méthode du 06/10 et du 14/10) : sur les 444, 391 sans
-- appelant SQL sous le rôle du lecteur ; 388 appelées par le front, une Edge
-- Function ou un script ; trois sans aucun appel, toutes des RPC d'admin
-- réseau voulues sans écran (api.fn_outbox_abandonnees/_acquitter — F12 ;
-- fn_restricted_resources_without_holder — D19) : elles restent.
--
-- Tri de plus, neuf : les fonctions que SEULE une Edge Function appelle, et
-- avec quelle clé. Treize ; dix passent par le jeton de l'appelant
-- (userClient / asCaller) et ont besoin d'authenticated. Trois passent par la
-- clé de service, sans autre appelant qui s'exécute sous anon ou
-- authenticated :
--
--   public.fn_oai_harvestable_libraries()
--   public.fn_oai_harvestable_records(text, timestamptz, timestamptz, integer, integer, bigint)
--       L'Edge Function oai-pmh-provider crée son client avec secretKey()
--       (index.ts, l. 113-117) ; le commentaire de la fonction le dit
--       (« Consommée par l'EF oai-pmh-provider (service_role) »). Le protocole
--       OAI-PMH est anonyme pour le moissonneur, pas pour la base : l'audit du
--       30/08 (« anonyme par construction ») les avait ouvertes à anon sur
--       cette prémisse. Aucun appel du front ni de la vitrine.
--       fn_oai_harvestable_libraries est aussi appelée par
--       fn_oai_harvestable_records, DEFINER.
--   public.fn_authority_using_libraries(text, bigint)
--       Appelée par supabaseAdmin (_shared/domain/authority.ts, l. 94) et par
--       api.fn_authority_object, DEFINER.
--
-- 0028 passe de 22 à 20, 0029 de 444 à 441. service_role garde EXECUTE (la
-- garde le vérifie) ; rien d'autre ne change : ni corps, ni politique, ni
-- donnée. Rouvrir = un GRANT écrit avec le nouvel appelant, et ses lignes en
-- T10/T12 de grants_herites_tests.
--
-- Gardes : le bloc DO final ; en continu, aides_definer_fermees_tests (T1 :
-- service_role garde l'accès), grants_herites_tests T10/T12.
-- ===========================================================================

REVOKE EXECUTE ON FUNCTION public.fn_oai_harvestable_libraries() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_oai_harvestable_records(text, timestamp with time zone, timestamp with time zone, integer, integer, bigint) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_authority_using_libraries(text, bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_oai_harvestable_libraries() TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_oai_harvestable_records(text, timestamp with time zone, timestamp with time zone, integer, integer, bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_authority_using_libraries(text, bigint) TO service_role;

DO $garde$
DECLARE
  v_fermees text[] := ARRAY[
    'public.fn_oai_harvestable_libraries()',
    'public.fn_oai_harvestable_records(text, timestamp with time zone, timestamp with time zone, integer, integer, bigint)',
    'public.fn_authority_using_libraries(text, bigint)'
  ];
  v_f      text;
  v_oid    oid;
  v_nom    text;
  v_ecarts text := '';
BEGIN
  FOREACH v_f IN ARRAY v_fermees LOOP
    v_oid := v_f::regprocedure;
    SELECT p.proname INTO v_nom FROM pg_proc p WHERE p.oid = v_oid;
    IF has_function_privilege('authenticated', v_oid, 'EXECUTE')
       OR has_function_privilege('anon', v_oid, 'EXECUTE') THEN
      v_ecarts := v_ecarts || ' encore-ouverte:' || v_f;
    END IF;
    IF NOT has_function_privilege('service_role', v_oid, 'EXECUTE') THEN
      v_ecarts := v_ecarts || ' service_role-perdu:' || v_f;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_depend d
                WHERE d.refclassid = 'pg_proc'::regclass AND d.refobjid = v_oid
                  AND d.classid <> 'pg_trigger'::regclass
                  AND (d.classid <> 'pg_proc'::regclass
                       OR NOT (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = d.objid))) THEN
      v_ecarts := v_ecarts || ' dependance:' || v_f;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_policy pol
                WHERE (coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' '
                       || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')) ~ ('\m' || v_nom || '\M')) THEN
      v_ecarts := v_ecarts || ' politique:' || v_f;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_views v
                WHERE v.schemaname NOT IN ('pg_catalog', 'information_schema')
                  AND v.definition ~ ('\m' || v_nom || '\M')) THEN
      v_ecarts := v_ecarts || ' vue:' || v_f;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE NOT p.prosecdef AND p.oid <> v_oid
                  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
                  AND p.prosrc ~ ('\m' || v_nom || '\s*\(')) THEN
      v_ecarts := v_ecarts || ' appelant-invoker:' || v_f;
    END IF;
  END LOOP;
  -- La porte DEFINER de fn_authority_using_libraries reste ouverte.
  IF NOT has_function_privilege('authenticated', 'api.fn_authority_object(uuid, uuid, text)', 'EXECUTE') THEN
    v_ecarts := v_ecarts || ' porte-fermee:api.fn_authority_object';
  END IF;
  IF v_ecarts <> '' THEN
    RAISE EXCEPTION 'aides servies par la clé de service : écart(s) —%', v_ecarts;
  END IF;
END
$garde$;
