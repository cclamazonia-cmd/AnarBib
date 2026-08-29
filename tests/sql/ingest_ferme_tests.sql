-- =====================================================================
-- AnarBib — Tests : le schema `ingest` reste ferme
-- Date    : 2026-08-29  ·  Session : hygiene de la securite, item B1
-- Ref     : migration 20260830140000_ingest_ne_depend_plus_d_un_grant
--
-- Pourquoi cette suite existe. `grants_herites_tests.sql` garde `public`, et
-- son T2 dit exactement le bon critere : une table ecrivable sans RLS. Mais il
-- ne regarde que `public` — et c'est par la que `ingest` est passe au travers
-- pendant des mois, avec huit tables sans RLS que personne n'avait relevees.
-- Cette suite est le meme controle, pour le schema qui manquait.
--
-- `ingest` porte les catalogues des bibliotheques partenaires : 2 172 lignes
-- de staging, 2 084 correspondances vers des brouillons. Ce sont des donnees
-- de tiers.
--
-- T2 est le test le plus important, et il ne parle pas de securite : FORCE ROW
-- LEVEL SECURITY sur ces tables couperait les DIX-SEPT fonctions d'import d'un
-- coup, silencieusement, parce qu'elles s'appuient sur le fait que le
-- proprietaire n'est pas soumis a la RLS. C'est le seul geste qui peut casser
-- l'import a partir d'ici, et il a l'air d'un durcissement.
--
-- T6 garde l'invariant qui rend tout le reste possible : tables et fonctions
-- DEFINER appartiennent au MEME role. S'il se defait, la RLS sans policy cesse
-- d'etre transparente et ferme l'import pour de bon.
--
-- T5 est un test de l'evenement redoute plutot que de l'intention, sur le
-- modele du T5 de la suite `grants_herites` : on cree une table dans `ingest`
-- et on regarde ce qu'elle recoit.
--   Bilan OK : 'INGEST-FERME OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_n int; v_txt text; v_owner_tables int; v_owner_fns int;
BEGIN
  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 aucune table du schema ingest sans RLS';
  BEGIN
    SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
      INTO v_n, v_txt
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'ingest' AND c.relkind = 'r' AND NOT c.relrowsecurity;
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||left(v_txt, 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 aucune table du schema ingest en FORCE ROW LEVEL SECURITY';
  BEGIN
    SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
      INTO v_n, v_txt
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'ingest' AND c.relkind = 'r' AND c.relforcerowsecurity;
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_n||' -> '||left(v_txt, 200)||' — les fonctions d''import sont coupees');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 ni anon ni authenticated n''a USAGE sur le schema ingest';
  BEGIN
    SELECT count(*), coalesce(string_agg(r.rolname, ', ' ORDER BY r.rolname), '')
      INTO v_n, v_txt
      FROM pg_roles r
     WHERE r.rolname IN ('anon', 'authenticated')
       AND has_schema_privilege(r.rolname, 'ingest', 'USAGE');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 aucun droit de table accorde a anon/authenticated dans ingest';
  BEGIN
    SELECT count(*), coalesce(string_agg(DISTINCT table_name, ', ' ORDER BY table_name), '')
      INTO v_n, v_txt
      FROM information_schema.role_table_grants
     WHERE table_schema = 'ingest' AND grantee IN ('anon', 'authenticated');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||left(v_txt, 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 une table neuve dans ingest ne recoit aucun droit herite';
  BEGIN
    CREATE TABLE ingest.__essai_ingest_ferme (id int);
    SELECT count(*) INTO v_n
      FROM information_schema.role_table_grants
     WHERE table_schema = 'ingest' AND table_name = '__essai_ingest_ferme'
       AND grantee IN ('anon', 'authenticated');
    DROP TABLE ingest.__essai_ingest_ferme;
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : une table neuve recoit '||v_n||' droit(s) — le defaut du schema a change');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    BEGIN DROP TABLE IF EXISTS ingest.__essai_ingest_ferme; EXCEPTION WHEN OTHERS THEN NULL; END;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le libelle dit « secdef » et non la formule complete a dessein : le hook
  -- pre-commit retire les commentaires avant analyse, mais pas les litteraux,
  -- et il exigerait ici le SET search_path qui va normalement avec.
  v_t := 'T6 tables et fonctions secdef de ingest ont le meme proprietaire';
  -- C'est ce qui rend la RLS sans policy transparente pour l'import : le
  -- proprietaire n'est pas soumis aux policies. Si les deux divergent, les
  -- fonctions cessent de passer et l'import s'arrete.
  BEGIN
    SELECT count(DISTINCT c.relowner) INTO v_owner_tables
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'ingest' AND c.relkind = 'r';

    SELECT count(DISTINCT p.proowner) INTO v_owner_fns
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'ingest' AND p.prosecdef;

    SELECT count(*) INTO v_n
      FROM (SELECT DISTINCT c.relowner AS o
              FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'ingest' AND c.relkind = 'r') t
     WHERE NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n2 ON n2.oid = p.pronamespace
                        WHERE n2.nspname = 'ingest' AND p.prosecdef AND p.proowner = t.o);

    IF v_owner_tables = 1 AND v_owner_fns = 1 AND v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_owner_tables||' proprietaire(s) de table, '
                    ||v_owner_fns||' de fonction, '||v_n||' sans correspondance');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 chaque table de ingest dit pourquoi elle n''a pas de policy';
  -- Une table avec RLS et sans policy ne se distingue d'un oubli que par son
  -- commentaire. C'est le commentaire qui porte l'information, pas la structure.
  BEGIN
    SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
      INTO v_n, v_txt
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'ingest' AND c.relkind = 'r'
       AND NOT EXISTS (SELECT 1 FROM pg_policy pol WHERE pol.polrelid = c.oid)
       AND coalesce(obj_description(c.oid, 'pg_class'), '') NOT LIKE '%INGEST-RLS%';
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||left(v_txt, 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'INGEST-FERME OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'INGEST-FERME ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
