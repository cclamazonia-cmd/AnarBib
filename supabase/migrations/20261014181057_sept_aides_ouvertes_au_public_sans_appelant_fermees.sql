-- ===========================================================================
-- Advisors 0028 et 0029 — sept aides SECURITY DEFINER ouvertes au public
-- (anon) et aux comptes connectés fermées, parce qu'aucun appelant ne
-- s'exécute sous ces rôles.
--
-- Relevé du 14/10/2026 (export du tableau de bord, 18 h 03 UTC) : 467 WARN =
-- 437 (0029) + 29 (0028) + 1 (0011, fn_locale_from_idioma, voulu — B32).
--
-- Même méthode que le 06/10 (20261006202320), refaite sur les 437 : 384
-- n'ont aucun appelant SQL sous le rôle du lecteur (politique, vue, INVOKER,
-- cron, pg_depend) ; 375 de ces 384 sont appelées par le front, une Edge
-- Function ou un script. Restent neuf, les mêmes que le 06/10 : les deux RPC
-- d'admin réseau de F12 (api.fn_outbox_abandonnees, api.fn_outbox_acquitter,
-- voulues sans écran — elles restent), et sept fonctions de la liste nommée
-- T10, ouvertes à anon par l'audit du 30/08 (AUDIT_execute_anon_2026-08-30.md,
-- section B, « un usage anonyme réel »).
--
-- Cet usage existe, mais ce ne sont pas ces sept qui le portent :
--   * les quatre lecteurs de mode (fn_library_{catalog,circulation,
--     governance,network}_mode) : « une visiteuse doit savoir si une
--     bibliothèque publie son catalogue pour que sa page se rende » — aucun
--     fichier du front, d'une Edge Function, d'un script ni de la vitrine ne
--     les a jamais nommés (git log -S sur src/ et supabase/functions/ : vide) ;
--     leurs seuls appelants sont fn_propose_library_profile_change et
--     fn_required_governance_for_transition, DEFINER ;
--   * fn_oai_library_is_harvest_eligible : le moissonnage OAI passe par
--     fn_oai_harvestable_libraries / _records (DEFINER, ouvertes à anon, elles
--     restent), qui l'appellent sous leur propriétaire ;
--   * fn_consume_library_request_claim : la candidature sans compte passe par
--     fn_submit_library_request_via_claim (DEFINER, ouverte à anon, elle
--     reste), son seul appelant ;
--   * fn_book_restricted_pdf_state : son seul appelant direct était l'Edge
--     Function read-pdf, retirée par F3 (82afd616, 05/10) ; reste
--     fn_book_restricted_pdf_state_for_current_user (DEFINER, ouverte à anon,
--     elle reste).
-- La fiche, l'OAI-PMH, la candidature et la page publique continuent donc
-- d'être servies par leurs portes ; seules les aides internes ferment.
--
-- 0028 passe de 29 à 22, 0029 de 437 à 430. Rien d'autre ne change : ni
-- corps, ni politique, ni donnée ; service_role garde ce qu'il avait.
-- Rouvrir l'une d'elles = un GRANT écrit dans la migration qui crée son
-- premier appelant sous anon ou authenticated, et sa ligne en T10/T12.
--
-- Gardes : le bloc DO final (les deux camps, appelants revérifiés au
-- déploiement) ; en continu, tests/sql/aides_definer_fermees_tests.sql (les
-- portes anonymes jouées sous le rôle anon), grants_herites_tests T10/T12,
-- paquetA_profils TEST 15.
-- ===========================================================================

REVOKE EXECUTE ON FUNCTION public.fn_library_catalog_mode(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_library_circulation_mode(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_library_governance_mode(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_library_network_mode(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_oai_library_is_harvest_eligible(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_consume_library_request_claim(text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_book_restricted_pdf_state(text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Garde des deux camps. Un appelant apparu entre le relevé et le déploiement
-- (politique, vue, défaut, index, fonction INVOKER) ferait échouer la
-- migration au lieu de casser une page : c'est lui qu'on redoute.
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE
  v_fermees text[] := ARRAY[
    'public.fn_library_catalog_mode(uuid)',
    'public.fn_library_circulation_mode(uuid)',
    'public.fn_library_governance_mode(uuid)',
    'public.fn_library_network_mode(uuid)',
    'public.fn_oai_library_is_harvest_eligible(uuid)',
    'public.fn_consume_library_request_claim(text, uuid)',
    'public.fn_book_restricted_pdf_state(text)'
  ];
  -- Les portes anonymes qui portent l'usage public : elles restent ouvertes
  -- à anon et à authenticated, et DEFINER.
  v_portes_anon text[] := ARRAY[
    'public.fn_oai_harvestable_libraries()',
    'public.fn_oai_harvestable_records(text, timestamp with time zone, timestamp with time zone, integer, integer, bigint)',
    'public.fn_submit_library_request_via_claim(text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, boolean, boolean, text, text, text, text, text)',
    'public.fn_book_restricted_pdf_state_for_current_user(text)'
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

  FOREACH v_f IN ARRAY v_portes_anon LOOP
    v_oid := v_f::regprocedure;
    IF NOT has_function_privilege('anon', v_oid, 'EXECUTE') THEN
      v_ecarts := v_ecarts || ' porte-fermee-a-anon:' || v_f;
    END IF;
    IF NOT has_function_privilege('authenticated', v_oid, 'EXECUTE') THEN
      v_ecarts := v_ecarts || ' porte-fermee-a-authenticated:' || v_f;
    END IF;
    IF NOT (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = v_oid) THEN
      v_ecarts := v_ecarts || ' porte-invoker:' || v_f;
    END IF;
  END LOOP;
  IF NOT has_function_privilege('authenticated', 'public.fn_propose_library_profile_change(uuid, text, text, text)', 'EXECUTE') THEN
    v_ecarts := v_ecarts || ' porte-fermee:fn_propose_library_profile_change';
  END IF;

  IF v_ecarts <> '' THEN
    RAISE EXCEPTION 'sept aides ouvertes au public : écart(s) —%', v_ecarts;
  END IF;
END
$garde$;
