-- =====================================================================
-- AnarBib — Tests : les droits herites ne reviennent pas
-- Date    : 2026-08-29  ·  Session : chantier hygiene des GRANT
-- Ref     : migration 20260829140000_droits_herites_inutiles_retires
--
-- Pourquoi cette suite existe. Le paquet qui l'accompagne retire TRUNCATE,
-- REFERENCES et TRIGGER a `anon`/`authenticated` sur tout `public`. Le retirer
-- une fois ne sert a rien : `ALTER DEFAULT PRIVILEGES` du schema accorde
-- `arwdDxtm` sur CHAQUE table neuve, et le defaut pose par `supabase_admin`
-- n'est pas modifiable depuis une migration. Sans cette suite, le nettoyage
-- se defait au prochain CREATE TABLE et personne ne le voit.
--
-- C'est donc une liste QUI SE VERIFIE, pas une intention — meme role que
-- deploy/bg2-known-tables.txt pour la sauvegarde.
--
-- T2 est le test le plus important, et il ne parle pas des trois droits du
-- paquet : il garde a ZERO la classe REELLEMENT dangereuse — une table de
-- `public` ecrivable par anon/authenticated SANS RLS. Les trois droits retires
-- ne sont pas exposes par PostgREST ; celle-la le serait.
--
-- T3 est un test de NON-ACTION : le nettoyage ne doit pas avoir rogne les
-- droits metier. Un REVOKE trop large passerait T1 et T2 sans broncher.
--
-- T8 et T9, ajoutes le 30/08/2026 (item B2), portent la meme logique sur les
-- droits EXECUTE des FONCTIONS -- ou le meme ALTER DEFAULT PRIVILEGES accorde
-- `anon` sur chaque fonction neuve. T9 garde dans le sens inverse des autres :
-- cinq fonctions ne doivent JAMAIS perdre `anon`, parce que des policies
-- evaluees par `anon` les appellent. Les fermer ne fermerait rien -- ca ferait
-- echouer la lecture publique.
--   Bilan OK : 'GRANTS-HERITES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_n int; v_txt text;
BEGIN
  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 aucune table de public n''accorde TRUNCATE/REFERENCES/TRIGGER a anon ou authenticated';
  BEGIN
    SELECT count(*), coalesce(string_agg(DISTINCT table_name, ', ' ORDER BY table_name), '')
      INTO v_n, v_txt
      FROM information_schema.role_table_grants
     WHERE table_schema = 'public'
       AND grantee IN ('anon', 'authenticated')
       AND privilege_type IN ('TRUNCATE', 'REFERENCES', 'TRIGGER');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_n||' droit(s) sur '||left(v_txt, 200));
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 aucune table de public ecrivable par anon/authenticated sans RLS';
  BEGIN
    SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
      INTO v_n, v_txt
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity
       AND EXISTS (SELECT 1 FROM information_schema.role_table_grants g
                    WHERE g.table_schema = 'public' AND g.table_name = c.relname
                      AND g.grantee IN ('anon', 'authenticated')
                      AND g.privilege_type IN ('INSERT', 'UPDATE', 'DELETE'));
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||left(v_txt, 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 les droits metier du catalogage sont intacts (non-action)';
  BEGIN
    SELECT count(*) INTO v_n
      FROM information_schema.role_table_grants
     WHERE table_schema = 'public' AND grantee = 'authenticated'
       AND table_name IN ('book_drafts', 'author_drafts', 'exemplar_drafts', 'catalog_batches')
       AND privilege_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE');
    IF v_n = 16 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/16 droits metier'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 le catalogue public reste lisible par anon';
  BEGIN
    SELECT count(*) INTO v_n
      FROM information_schema.role_table_grants
     WHERE table_schema = 'public' AND grantee = 'anon'
       AND table_name IN ('books', 'exemplares', 'libraries')
       AND privilege_type = 'SELECT';
    IF v_n = 3 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/3 lectures publiques'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 le defaut du schema ne redonnera pas ces droits aux tables neuves';
  -- On ne lit pas pg_default_acl a l'oeil : on CREE une table et on regarde ce
  -- qu'elle recoit. C'est le seul controle qui vaut, puisque c'est exactement
  -- l'evenement qu'on redoute. La table est supprimee dans la foulee.
  BEGIN
    CREATE TABLE public.__essai_droits_herites (id int);
    SELECT count(*) INTO v_n
      FROM information_schema.role_table_grants
     WHERE table_schema = 'public' AND table_name = '__essai_droits_herites'
       AND grantee IN ('anon', 'authenticated')
       AND privilege_type IN ('TRUNCATE', 'REFERENCES', 'TRIGGER');
    DROP TABLE public.__essai_droits_herites;
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : une table neuve recoit encore '||v_n||' droit(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN
    BEGIN DROP TABLE IF EXISTS public.__essai_droits_herites; EXCEPTION WHEN OTHERS THEN NULL; END;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 aucune VUE de public n''est une cible d''ecriture pour anon/authenticated';
  -- Le defaut du schema redonne INSERT/UPDATE/DELETE a chaque relation neuve,
  -- vues comprises, et on ne peut PAS le corriger a la source : `ALTER DEFAULT
  -- PRIVILEGES ... ON TABLES` ne distingue pas les tables des vues, et ces
  -- droits sur les TABLES sont exactement ce qui fait marcher l'API. Cet
  -- invariant ne peut donc vivre que dans un controle — celui-ci.
  BEGIN
    SELECT count(*), coalesce(string_agg(DISTINCT g.table_name, ', ' ORDER BY g.table_name), '')
      INTO v_n, v_txt
      FROM information_schema.role_table_grants g
     WHERE g.table_schema = 'public'
       AND g.grantee IN ('anon', 'authenticated')
       AND g.privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
       AND EXISTS (SELECT 1 FROM pg_views v
                    WHERE v.schemaname = 'public' AND v.viewname = g.table_name);
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||left(v_txt, 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 aucune vue SANS security_invoker n''est lisible par anon/authenticated';
  -- C'est LA classe dangereuse, et elle ne se confond pas avec T6 : sans
  -- security_invoker, une vue s'execute avec les droits de son proprietaire, donc
  -- la RLS des tables de base est CONTOURNEE pour qui peut la lire. Au 30/08 les
  -- 5 vues concernees (listes de travail dedoublonnage, Terra Livre) ne sont
  -- accordees a personne : l'invariant tient, et c'est lui qu'il faut garder —
  -- pas « toutes les vues en security_invoker », qui forcerait des changements
  -- sans objet sur des vues internes.
  BEGIN
    SELECT count(*), coalesce(string_agg(DISTINCT c.relname, ', ' ORDER BY c.relname), '')
      INTO v_n, v_txt
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind = 'v'
       AND coalesce((SELECT option_value FROM pg_options_to_table(c.reloptions)
                      WHERE option_name = 'security_invoker'), 'false') <> 'true'
       AND EXISTS (SELECT 1 FROM information_schema.role_table_grants g
                    WHERE g.table_schema = 'public' AND g.table_name = c.relname
                      AND g.grantee IN ('anon', 'authenticated')
                      AND g.privilege_type = 'SELECT');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||left(v_txt, 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- T8 et T9 : les droits EXECUTE sur les fonctions (item B2, 30/08/2026).
  -- Meme logique que T1 : le schema `public` porte un ALTER DEFAULT PRIVILEGES
  -- qui accorde EXECUTE a `anon` sur CHAQUE fonction neuve. Un REVOKE ponctuel
  -- ne tient donc que jusqu'au prochain CREATE OR REPLACE FUNCTION -- qui,
  -- lui, ne recree pas l'ACL, mais un DROP + CREATE si. C'est une liste qui se
  -- verifie, pas une intention.
  v_t := 'T8 les trois fonctions dont le corps refuse anon ne lui sont plus accordees';
  -- search_authors_by_name et search_publishers_by_name levent « Acesso restrito
  -- ao staff de catalogacao. » ; remove_library_regulation_document leve
  -- « authentication required ». Le grant contredisait la fonction.
  BEGIN
    SELECT count(*), coalesce(string_agg(f.sig, ', ' ORDER BY f.sig), '')
      INTO v_n, v_txt
      FROM (VALUES
        ('public.search_authors_by_name(text,integer)'),
        ('public.search_publishers_by_name(text,integer)'),
        ('public.remove_library_regulation_document(bigint)')
      ) AS f(sig)
     WHERE has_function_privilege('anon', f.sig::regprocedure, 'EXECUTE');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : rouvert(es) a anon -> '||v_txt);
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 les cinq fonctions appelees par des policies evaluees par anon lui restent accordees';
  -- LE TEST LE PLUS IMPORTANT DE CETTE SUITE, et il garde dans l'autre sens.
  -- Ces cinq-la sont appelees DEPUIS L'INTERIEUR de 107 policies RLS, dont 39
  -- evaluees par `anon`. Leur retirer EXECUTE ne ferme rien : la lecture
  -- publique echoue avec « permission denied for function » et le catalogue
  -- cesse de s'afficher. Quiconque lit « 36 avertissements 0028 » sur le
  -- tableau de bord et decide de faire le menage tombera sur ce test avant de
  -- tomber sur un catalogue vide.
  BEGIN
    SELECT count(*), coalesce(string_agg(f.sig, ', ' ORDER BY f.sig), '')
      INTO v_n, v_txt
      FROM (VALUES
        ('public.user_can_act_as_staff_on_library(uuid)'),
        ('public.user_can_engage_library(uuid)'),
        ('public.fn_caller_is_network_admin()'),
        ('public.fn_library_visible_to_caller(uuid)'),
        ('public.fn_caller_is_library_staff(uuid)')
      ) AS f(sig)
     WHERE NOT has_function_privilege('anon', f.sig::regprocedure, 'EXECUTE');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : fermee(s) a anon -> '||v_txt
        ||' -- la lecture publique echouera avec « permission denied for function »');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- T10 : LA LISTE NOMMEE (item B2, lot 4, 30/08/2026).
  -- Ce test est la conclusion de l'audit du 30/08 et la condition du lot 3.
  --
  -- Le schema `public` porte un ALTER DEFAULT PRIVILEGES qui accorde EXECUTE a
  -- `anon` sur CHAQUE fonction neuve. Le depot porte 141 REVOKE : le projet
  -- lutte contre ce defaut une fonction a la fois depuis des mois, sans jamais
  -- retourner la cause. Retourner le defaut est le lot 3 -- et il n'est sur
  -- QU'AVEC CE TEST : si l'ALTER casse un acces legitime, c'est ici qu'on le
  -- verra, pas sur une page publique.
  --
  -- La liste est ouverte dans les DEUX SENS, comme le TEST 15 de paquetA :
  --   * une fonction ouverte a `anon` hors liste = une exposition non decidee ;
  --   * une fonction de la liste fermee a `anon` = un acces public casse.
  -- Ajouter une entree ici doit etre un acte, pas un effet de bord. Chaque nom
  -- a un verdict ecrit dans docs/journal/audits/AUDIT_execute_anon_2026-08-30.md.
  v_t := 'T10 les fonctions SECURITY DEFINER ouvertes a anon sont exactement celles de la liste nommee';
  BEGIN
    WITH nommees(fn) AS (VALUES
      ('api.audio_tracklist_public'),
      ('api.search_catalog_v1'),
      ('api.subject_related_v1'),
      ('public.fn_book_due_dates'),
      ('public.fn_book_restricted_pdf_state'),
      ('public.fn_book_restricted_pdf_state_for_current_user'),
      ('public.fn_caller_is_library_staff'),
      ('public.fn_caller_is_network_admin'),
      ('public.fn_consume_library_request_claim'),
      ('public.fn_current_user_is_member_of_holding_library'),
      ('public.fn_get_library_request_claim_context'),
      ('public.fn_library_catalog_mode'),
      ('public.fn_library_circulation_mode'),
      ('public.fn_library_governance_mode'),
      ('public.fn_library_network_mode'),
      ('public.fn_library_visible_to_caller'),
      ('public.fn_oai_harvestable_libraries'),
      ('public.fn_oai_harvestable_records'),
      ('public.fn_oai_library_is_harvest_eligible'),
      ('public.fn_reading_notes_enabled_for'),
      ('public.fn_serial_caller_is_library_staff'),
      ('public.fn_submit_library_request'),
      ('public.fn_submit_library_request_via_claim'),
      ('public.get_accessible_digital_asset_by_id_v2'),
      ('public.get_book_contributors_public'),
      ('public.get_book_primary_public_digital_asset_v2'),
      ('public.list_catalog_libraries'),
      ('public.user_can_act_as_staff_on_library'),
      ('public.user_can_engage_library')
    ), reelles AS (
      SELECT DISTINCT n.nspname||'.'||p.proname AS fn
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE p.prosecdef AND n.nspname IN ('api','public')
         AND has_function_privilege('anon', p.oid, 'EXECUTE')
    )
    SELECT
      coalesce(string_agg(x.fn||' ('||x.sens||')', ', ' ORDER BY x.fn), ''),
      count(*)
      INTO v_txt, v_n
      FROM (
        SELECT fn, 'ouverte hors liste' AS sens FROM reelles
         WHERE fn NOT IN (SELECT fn FROM nommees)
        UNION ALL
        SELECT fn, 'attendue mais fermee' FROM nommees
         WHERE fn NOT IN (SELECT fn FROM reelles)
      ) x;

    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_n||' ecart(s) -> '||left(v_txt, 400)
        ||' | une ouverture hors liste est une exposition non decidee ; une fermeture'
        ||' d''une entree de la liste casse un acces public');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'GRANTS-HERITES OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'GRANTS-HERITES ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
