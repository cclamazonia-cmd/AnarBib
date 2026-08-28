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

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'GRANTS-HERITES OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'GRANTS-HERITES ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
