-- =====================================================================
-- AnarBib — Tests : les vues de `api` qui echappent aux policies
-- Date    : 2026-08-29  ·  Session : hygiene de la securite, item B3
-- Ref     : migration 20260830160000_une_proposition_ne_se_lit_pas_a_decouvert
--
-- Pourquoi cette suite existe. Le T7 de `grants_herites_tests.sql` porte
-- exactement cet invariant — aucune vue sans `security_invoker` lisible par
-- anon ou authenticated — et ne regarde que `public`. C'est la troisieme fois
-- de la journee qu'un controle juste s'arrete au bon schema : `ingest` d'abord,
-- `api` ensuite. Sept vues de `api` etaient concernees.
--
-- T2 est le test le plus important. Les deux vues de gouvernance restent
-- volontairement sans `security_invoker` — en invoker, la jointure sur
-- `public.profiles` renverrait NULL a l'administrateur·rice qui doit decider,
-- parce que la policy de `profiles` ne couvre pas ce cas. Leur visibilite est
-- donc portee par une clause dans la vue, reprise de la policy des tables de
-- base. Cette clause est la SEULE chose qui empeche tout compte connecte de
-- lire nominativement les propositions de cooptation et de retrait — avec les
-- noms, les courriels et les motivations. Un `CREATE OR REPLACE VIEW` distrait
-- la ferait disparaitre sans bruit.
--
-- T5 est le garde-fou de demain plutot que d'aujourd'hui : il refuse toute
-- vue NOUVELLE qui echapperait aux policies tout en etant lisible, hors des
-- deux derogations connues et nommees.
--   Bilan OK : 'VUES-API OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_n int; v_txt text;
BEGIN
  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 les quatre vues publiques gazette/lettre passent sous les policies';
  BEGIN
    SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
      INTO v_n, v_txt
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'api' AND c.relkind = 'v'
       AND c.relname IN ('gazette_issues_public_v1', 'gazette_locales_public_v1',
                         'lettre_public_v1', 'lettre_locales_public_v1')
       AND coalesce((SELECT option_value FROM pg_options_to_table(c.reloptions)
                      WHERE option_name = 'security_invoker'), 'false') <> 'true';
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 les deux vues de gouvernance portent leur clause de visibilite';
  BEGIN
    SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
      INTO v_n, v_txt
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'api' AND c.relkind = 'v'
       AND c.relname IN ('cooptation_proposals_current_v1', 'collective_removal_proposals_current_v1')
       AND pg_get_viewdef(c.oid, true) NOT LIKE '%fn_caller_is_network_admin%';
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_n||' -> '||v_txt||' — lisible nominativement par tout compte connecte');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 api.library_email_identity n''est accordee a aucun role applicatif';
  BEGIN
    SELECT count(*), coalesce(string_agg(DISTINCT grantee, ', '), '')
      INTO v_n, v_txt
      FROM information_schema.role_table_grants
     WHERE table_schema = 'api' AND table_name = 'library_email_identity'
       AND grantee IN ('anon', 'authenticated');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : accordee a '||v_txt||' — la passer en security_invoker');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 toute vue de api qui echappe aux policies dit pourquoi';
  -- Une vue sans security_invoker ne se distingue d'un oubli que par son
  -- commentaire. C'est lui qui porte l'information, pas la structure.
  BEGIN
    SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
      INTO v_n, v_txt
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'api' AND c.relkind = 'v'
       AND coalesce((SELECT option_value FROM pg_options_to_table(c.reloptions)
                      WHERE option_name = 'security_invoker'), 'false') <> 'true'
       AND coalesce(obj_description(c.oid, 'pg_class'), '') NOT LIKE '%API-VUES-DEFINER%';
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||left(v_txt, 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 aucune vue NOUVELLE de api n''echappe aux policies en etant lisible';
  -- Les deux derogations sont nommees plutot que devinees : une regle qui dirait
  -- « toutes les vues en security_invoker » forcerait a casser les deux ecrans
  -- de gouvernance, et serait donc contournee au premier besoin reel.
  BEGIN
    SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
      INTO v_n, v_txt
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'api' AND c.relkind = 'v'
       AND coalesce((SELECT option_value FROM pg_options_to_table(c.reloptions)
                      WHERE option_name = 'security_invoker'), 'false') <> 'true'
       AND c.relname NOT IN ('cooptation_proposals_current_v1',
                             'collective_removal_proposals_current_v1',
                             'library_email_identity')
       AND EXISTS (SELECT 1 FROM information_schema.role_table_grants g
                    WHERE g.table_schema = 'api' AND g.table_name = c.relname
                      AND g.grantee IN ('anon', 'authenticated')
                      AND g.privilege_type = 'SELECT');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||left(v_txt, 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'VUES-API OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'VUES-API ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
