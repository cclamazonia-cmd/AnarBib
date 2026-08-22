-- =========================================================================
-- DURCISSEMENT-GRANTS — rappel : ce qui est né depuis juillet
-- =========================================================================
-- Date     : 2026-08-22
-- Chantier : surface d'API — advisors Supabase 0011 / 0028 / 0029
--
-- POURQUOI CETTE MIGRATION EXISTE, ET POURQUOI ELLE RESSEMBLE À UNE AUTRE.
-- Le paquet du 2026-07-02 (`20260702101413`, `20260702103557`, `20260702112425`)
-- a fait passer l'advisor 0028 de 86 à 37. Mais ce sont des `REVOKE` PONCTUELS,
-- pas une règle permanente : le schéma `public` accorde `EXECUTE` à `PUBLIC`
-- par défaut, donc **toute fonction créée depuis naît de nouveau ouverte** et
-- réapparaît dans les advisors. Le tri est à refaire périodiquement ; ce n'est
-- pas une case qu'on coche une fois.
--
-- Constaté le 21/08 sur la production : deux fonctions `RETURNS trigger`
-- créées après le 02/07 étaient de nouveau exécutables par `anon` —
-- `tg_exemplares_ensure_holding()` (garde-fou exemplaires/holdings, mi-juillet)
-- et `trg_library_events_touch()`. Risque pratique nul, Postgres refusant
-- d'appeler une fonction trigger en RPC direct ; mais c'est la démonstration
-- que la règle a besoin d'être rejouée, et le bloc ci-dessous est donc écrit
-- pour être **rejouable tel quel** dans six mois.
--
-- CE QUI N'EST PAS TOUCHÉ, ET C'EST DÉLIBÉRÉ. Les ~200 lignes des advisors
-- 0028/0029 restent : l'API `api.*` entière est faite de RPC `SECURITY DEFINER`
-- qui gatent DANS LEUR CORPS (`auth.uid()`, `fn_caller_is_*`,
-- `user_can_act_as_staff_on_library`). Le linter ne voit pas ces gardes.
-- Révoquer casserait l'application, et notamment les helpers appelés par les
-- politiques RLS — qui s'évaluent sous le rôle `anon` en lecture publique.
-- Repère de tri : la seule question qui compte est « le bloc `anon` a-t-il
-- GRANDI ? ». Au 21/08 il comptait 35 fonctions contre 37 après juillet.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) Advisor 0011 — `search_path` mutable sur trois fonctions
-- -------------------------------------------------------------------------
-- Les trois sont `SECURITY INVOKER` : un `search_path` mutable n'y ouvre RIEN,
-- puisqu'elles s'exécutent déjà avec les droits de l'appelant — il n'y a aucun
-- privilège à voler. C'est de l'hygiène, pas un correctif de sécurité, et il
-- faut le dire pour que personne ne se croie obligé de traiter le prochain
-- warning 0011 dans l'urgence.
--
-- Le critère qui distingue les deux cas est unique : `pg_proc.prosecdef`. Sur
-- une fonction `SECURITY DEFINER`, le même warning désigne une vraie escalade
-- (détourner `public.now()` et consorts sous l'identité du propriétaire), et
-- se corrige tout de suite. Vérifié le 22/08 : la base n'en compte AUCUNE.
--
-- L'épinglage est sans risque ici : les trois fonctions sont des constantes.
-- Deux renvoient un tableau littéral de noms de colonnes, la troisième une
-- chaîne d'expression régulière ; aucune ne lit de table, ne référence de type
-- ni n'appelle quoi que ce soit.
--
-- ⚠️ Piège à connaître : `CREATE OR REPLACE FUNCTION` sans clause `SET`
-- RÉINITIALISE `proconfig`. Si l'une de ces trois fonctions est un jour
-- redéfinie, l'épinglage saute en silence et le warning revient. Le
-- `set search_path` doit alors être remis dans la définition elle-même.
alter function public.fn_dedup_non_transferable_fields()
  set search_path = public, pg_catalog;

alter function public.fn_dedup_non_transferable_author_fields()
  set search_path = public, pg_catalog;

alter function private.conv_motifs_collectivite()
  set search_path = public, pg_catalog;

-- -------------------------------------------------------------------------
-- 2) Rappel du durcissement des fonctions trigger
-- -------------------------------------------------------------------------
-- Reprise littérale de la logique de `20260702101413`, avec deux différences :
-- le schéma `private` entre dans la portée, et le bloc est pensé pour être
-- rejoué. Postgres ne vérifie pas le droit `EXECUTE` au déclenchement d'un
-- trigger (vérifié empiriquement le 02/07) : retirer ce droit est sans effet
-- sur le fonctionnement, ça ne fait que supprimer une surface absurde.
--
-- On révoque à `PUBLIC` **en plus** de `anon` et `authenticated`, et c'est le
-- point qui avait manqué au premier essai de juillet (corrigé par
-- `20260702112425`) : l'accès de `anon` vient soit d'un grant direct, soit du
-- grant par défaut à `PUBLIC` dont il hérite. `REVOKE FROM anon` seul est un
-- no-op sur le second cas. `service_role`, le propriétaire et `postgres`
-- conservent leurs droits : la chaîne `SECURITY DEFINER` est inchangée.
DO $$
DECLARE
  r record;
  v_n integer := 0;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_type     t ON t.oid = p.prorettype
    WHERE n.nspname IN ('public', 'api', 'private')
      AND t.typname = 'trigger'
      AND NOT EXISTS (                       -- exclut les fonctions d'extension
        SELECT 1 FROM pg_depend d
        WHERE d.objid = p.oid AND d.deptype = 'e'
      )
      -- Ne journaliser que ce qui était réellement encore ouvert, pour que la
      -- NOTICE dise quelque chose de vrai quand on rejoue le bloc.
      AND (has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
  LOOP
    EXECUTE format(
      'REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated',
      r.sig
    );
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE 'DURCISSEMENT-GRANTS (rappel) : % fonction(s) trigger refermee(s).', v_n;
END $$;

-- -------------------------------------------------------------------------
-- 3) Contrôle : la migration se vérifie elle-même
-- -------------------------------------------------------------------------
-- Une migration de durcissement qui ne constate pas son propre effet est un
-- vœu pieux. On échoue bruyamment plutôt que de laisser croire que c'est fait.
DO $$
DECLARE
  v_triggers integer;
  v_sans_path integer;
BEGIN
  SELECT count(*) INTO v_triggers
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_type     t ON t.oid = p.prorettype
   WHERE n.nspname IN ('public', 'api', 'private')
     AND t.typname = 'trigger'
     AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
     AND has_function_privilege('anon', p.oid, 'EXECUTE');

  IF v_triggers > 0 THEN
    RAISE EXCEPTION 'DURCISSEMENT-GRANTS : % fonction(s) trigger restent ouvertes a anon', v_triggers;
  END IF;

  SELECT count(*) INTO v_sans_path
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE p.proname IN ('fn_dedup_non_transferable_fields',
                       'fn_dedup_non_transferable_author_fields',
                       'conv_motifs_collectivite')
     AND (p.proconfig IS NULL
          OR NOT EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%'));

  IF v_sans_path > 0 THEN
    RAISE EXCEPTION 'DURCISSEMENT-GRANTS : % fonction(s) sans search_path epingle', v_sans_path;
  END IF;

  RAISE NOTICE 'DURCISSEMENT-GRANTS : controle OK (0 trigger ouvert, 3 search_path epingles).';
END $$;

COMMIT;
