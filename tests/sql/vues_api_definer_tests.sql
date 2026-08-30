-- =====================================================================
-- AnarBib — Tests : les vues de `api` et les droits qui les portent
-- Date    : 2026-08-29, revu le 30/08  ·  Item B3
-- Ref     : 20260830160000 (paquet API-VUES-DEFINER)
--           20260830090000 (le droit de voir se declare)
--
-- Le T7 de `grants_herites_tests.sql` porte le meme invariant sur `public` :
-- aucune vue hors des policies lisible par anon ou authenticated. Il ne
-- regardait pas `api`, ou sept vues etaient dans ce cas.
--
-- Le 30/08, les deux vues de gouvernance ont rejoint les cinq autres sous
-- les policies. Ce qui les en tenait ecartees n'etait pas un choix mais une
-- policy manquante sur `profiles` : une admin reseau statuant sur quelqu'un
-- d'exterieur a ses bibliotheques lisait des champs vides. Le droit de voir
-- est desormais ENONCE (policy `profiles_select_gouvernance_en_cours`) au
-- lieu d'etre contourne.
--
-- T3 est le test le plus important de cette suite. Il garde le decompte des
-- votes de retrait pour la personne VISEE : sa policy ne couvrait qu'elle
-- les admins, si bien que la personne visee aurait lu « 0 vote » au lieu du
-- decompte reel. Un chiffre faux ne se signale pas tout seul.
--   Bilan OK : 'VUES-API OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_n int; v_txt text;
BEGIN
  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 toutes les vues de api passent sous les policies, sauf library_email_identity';
  BEGIN
    SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
      INTO v_n, v_txt
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'api' AND c.relkind = 'v'
       AND c.relname <> 'library_email_identity'
       AND coalesce((SELECT option_value FROM pg_options_to_table(c.reloptions)
                      WHERE option_name = 'security_invoker'), 'false') <> 'true';
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 le droit de voir les profils en deliberation est porte par une policy';
  -- Sans elle, les deux ecrans de gouvernance affichent des champs vides a
  -- l'administratrice qui doit decider -- et la tentation revient de
  -- ressortir la vue des policies pour « que ca remarche ».
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
     WHERE c.relname = 'profiles' AND c.relnamespace = 'public'::regnamespace
       AND p.polname = 'profiles_select_gouvernance_en_cours'
       AND p.polpermissive
       AND pg_get_expr(p.polqual, p.polrelid) LIKE '%cooptation_proposals%'
       AND pg_get_expr(p.polqual, p.polrelid) LIKE '%collective_removal_proposals%';
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : policy absente, non permissive, ou ne couvrant pas les deux familles de proposition');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 la personne visee par un retrait voit le decompte des votes qui la concerne';
  -- Le test le plus important : ce qui manquait ici ne produisait pas un
  -- refus mais un ZERO. Une permission absente qui se lit comme une donnee.
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
     WHERE c.relname = 'network_admin_collective_removal_votes'
       AND p.polname = 'rls_crv_select'
       AND pg_get_expr(p.polqual, p.polrelid) LIKE '%proposed_user_id%';
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : la personne visee lirait un decompte a zero au lieu du decompte reel');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 la policy historique de profiles est intacte';
  -- On a AJOUTE un cas le 30/08. Si quelqu'un consolide un jour les deux
  -- policies en une seule, ce test le dira avant que le cas historique --
  -- mon profil, ceux de mes bibliotheques -- ne parte avec.
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
     WHERE c.relname = 'profiles' AND c.relnamespace = 'public'::regnamespace
       AND p.polname = 'profiles_select_consolidated';
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : profiles_select_consolidated a disparu'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 api.library_email_identity n''est accordee a aucun role applicatif';
  BEGIN
    SELECT count(*), coalesce(string_agg(DISTINCT grantee, ', '), '')
      INTO v_n, v_txt
      FROM information_schema.role_table_grants
     WHERE table_schema = 'api' AND table_name = 'library_email_identity'
       AND grantee IN ('anon', 'authenticated');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : accordee a '||v_txt||' — la passer sous les policies');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 toute vue de api restee hors des policies dit pourquoi';
  -- Une vue hors des policies ne se distingue d'un oubli que par son
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
  v_t := 'T7 aucune vue NOUVELLE de api n''echappe aux policies en etant lisible';
  -- La derogation restante est nommee plutot que devinee. Depuis le 30/08
  -- il n'en reste qu'une, et elle n'est lisible par personne.
  BEGIN
    SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
      INTO v_n, v_txt
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'api' AND c.relkind = 'v'
       AND coalesce((SELECT option_value FROM pg_options_to_table(c.reloptions)
                      WHERE option_name = 'security_invoker'), 'false') <> 'true'
       AND c.relname NOT IN ('library_email_identity')
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
