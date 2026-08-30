-- =====================================================================
-- AnarBib -- Un grant que la fonction contredit, et cinq qu'il ne faut
--            surtout pas retirer
-- Date    : 2026-08-30  ·  Item B2, lots 1 et 2  ·  advisor Supabase 0028
-- Ref     : CONSTAT_500_avertissements_advisor_2026-08-30
--           migration 20260702103557 (premier durcissement 0028)
--
-- SUR L'HORODATAGE. Les horodatages de migration sont des jetons d'ORDRE, pas
-- des horloges : `supabase db push` indexe par version et la CI rejoue en ordre
-- lexicographique. La migration precedente porte 20260830180000 (poussee a
-- l'heure ronde le 30/08 pour eviter une collision) ; celle-ci doit donc trier
-- apres elle. D'ou 18:12:07 -- a la seconde, comme la convention adoptee le
-- 30/08 le demande, et posterieur au dernier jeton utilise.
--
-- ---------------------------------------------------------------------
-- CE QUE COMPTE L'ADVISOR, ET CE QUE CETTE MIGRATION EN FAIT.
--
-- Les 500 avertissements du tableau de bord sont deux lints et rien d'autre :
-- 36 fonctions `SECURITY DEFINER` executables par `anon` (0028) et 464 par
-- `authenticated` (0029). Ce ne sont pas 500 problemes.
--
-- Et ce ne sont pas non plus 36 decisions. Le schema `public` porte, depuis le
-- socle Supabase, `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
-- GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role`. Les 621
-- fonctions de `public` appartiennent a `postgres` : toute fonction creee la
-- NAIT executable par `anon`. Le grant est explicite dans l'ACL parce que
-- Postgres materialise le defaut a la creation -- pas parce qu'une personne a
-- decide. Retourner ce defaut est le lot 3 de B2 ; c'est une decision de
-- doctrine, elle ne se prend pas dans une migration de nettoyage.
--
-- Cette migration fait les deux lots qui ne demandent aucune decision :
--
--   LOT 1 -- trois grants que la fonction elle-meme contredit. Elles refusent
--   `anon` dans leur propre corps. Le REVOKE ne change AUCUN comportement
--   observable ; il fait cesser une contradiction entre deux lignes. C'est la
--   seule raison, et elle suffit : le jour ou quelqu'un retire la garde
--   `auth.uid() is null` pour reparer autre chose, le grant serait toujours la,
--   et personne ne l'aurait mis ce jour-la.
--
--   LOT 2 -- cinq fonctions qu'il ne faut JAMAIS fermer a `anon`, et qui ne le
--   disaient pas. Elles sont appelees DEPUIS L'INTERIEUR de 107 policies RLS,
--   dont 39 evaluees par `anon`. Leur retirer `EXECUTE` ne ferme rien : la
--   lecture publique echoue avec `permission denied for function`, et le
--   catalogue cesse de s'afficher. Sans commentaire, la prochaine personne qui
--   lit « 36 avertissements » sur le tableau de bord refera ce raisonnement --
--   ou fera le revoke.
--
-- Ce que cette migration NE fait pas : toucher au privilege par defaut (lot 3),
-- et se prononcer sur les vingt-huit autres fonctions ouvertes a `anon` (lot 4).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- LOT 1 -- Trois grants que le corps de la fonction contredit
-- ---------------------------------------------------------------------
-- Verifie avant ecriture : aucune des trois n'est appelee par une policy, par
-- une vue, ni par une fonction `SECURITY INVOKER`. `authenticated` conserve
-- `EXECUTE` : ce sont des outils de catalogage et de gestion, utilises par le
-- staff connecte.

-- Corps : RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
REVOKE EXECUTE ON FUNCTION public.search_authors_by_name(text, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.search_publishers_by_name(text, integer) FROM anon;

-- Corps : if auth.uid() is null then raise exception 'authentication required'
REVOKE EXECUTE ON FUNCTION public.remove_library_regulation_document(bigint) FROM anon;

-- ---------------------------------------------------------------------
-- LOT 2 -- Cinq fonctions qui portent des policies evaluees par `anon`
-- ---------------------------------------------------------------------
-- Les decomptes sont dates : ils bougeront, et c'est normal. Ce qui ne bouge
-- pas, c'est la raison -- une policy evaluee par `anon` a besoin que `anon`
-- puisse executer ce qu'elle appelle.

COMMENT ON FUNCTION public.user_can_act_as_staff_on_library(uuid) IS
  'Retourne TRUE si l''appelant peut agir comme membre du staff sur la biblio donnee. '
  'Inclut les administrateurs reseau (droit transverse) et le staff local actif '
  '(librarian + coordenador). '
  'NE PAS RETIRER EXECUTE A anon : appelee depuis 33 policies RLS, dont 17 evaluees '
  'par anon (decompte du 30/08/2026). Sans ce droit, la lecture publique echoue avec '
  '« permission denied for function ». L''avertissement 0028 de l''advisor est ici le '
  'prix d''une architecture, pas un defaut. Item B2.';

COMMENT ON FUNCTION public.user_can_engage_library(uuid) IS
  'Retourne TRUE si l''appelant peut engager politiquement la biblio (modifications '
  'structurelles, reglement, politique de circulation). Inclut administrateurs reseau '
  'et coordenadores locaux. '
  'NE PAS RETIRER EXECUTE A anon : appelee depuis 32 policies RLS, dont 5 evaluees par '
  'anon (decompte du 30/08/2026). Item B2.';

COMMENT ON FUNCTION public.fn_caller_is_network_admin() IS
  'Retourne TRUE si l''appelant courant est un administrateur reseau actif. Remplace '
  'fn_caller_is_administrador() (qui reste operationnel pendant la coexistence du '
  'paquet B). '
  'NE PAS RETIRER EXECUTE A anon : appelee depuis 28 policies RLS, dont 3 evaluees par '
  'anon (decompte du 30/08/2026). Item B2.';

COMMENT ON FUNCTION public.fn_library_visible_to_caller(uuid) IS
  'Visibilite biblio pour caller (anon/auth/membre). Etendue paquet C.2 : network_mode '
  '<> isolated sur branches public/network. Branche private inchangee. '
  'NE PAS RETIRER EXECUTE A anon : appelee depuis 13 policies RLS, TOUTES evaluees par '
  'anon (decompte du 30/08/2026) -- c''est la fonction qui decide ce qu''une visiteuse '
  'non connectee a le droit de voir. La fermer rendrait le catalogue public '
  'inaccessible. Item B2.';

COMMENT ON FUNCTION public.fn_caller_is_library_staff(uuid) IS
  'Vrai si l''appelant (auth.uid()) est librarian/coordenador actif de la bibliotheque '
  'donnee. Variante sans oracle de user_has_library_staff_role : ne renseigne que sur '
  'soi-meme, donc exposable a anon, pour qui auth.uid() est NULL et le resultat '
  'toujours false. '
  'Deuxieme raison, ajoutee le 30/08/2026 : elle est appelee depuis une policy RLS '
  'evaluee par anon. Les deux raisons tiennent ; la seconde suffirait seule. Item B2.';

-- ---------------------------------------------------------------------
-- Verification -- annule tout si l'etat vise n'est pas atteint
-- ---------------------------------------------------------------------
-- Portee volontairement etroite : cette migration verifie CE QU'ELLE FAIT.
-- L'invariant general -- aucune fonction ouverte a `anon` hors d'une liste
-- nommee -- est l'affaire d'une suite, pas d'une migration, parce que la CI
-- rejoue chaque migration contre l'etat de la base A SA DATE.
DO $$
DECLARE
  v_txt text;
BEGIN
  -- 1. Les trois fermees le sont, et `authenticated` les garde.
  SELECT string_agg(f.sig, ', ' ORDER BY f.sig) INTO v_txt
    FROM (VALUES
      ('public.search_authors_by_name(text,integer)'),
      ('public.search_publishers_by_name(text,integer)'),
      ('public.remove_library_regulation_document(bigint)')
    ) AS f(sig)
   WHERE has_function_privilege('anon', f.sig::regprocedure, 'EXECUTE');
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'ECHEC lot 1 : encore executable(s) par anon -> %', v_txt;
  END IF;

  SELECT string_agg(f.sig, ', ' ORDER BY f.sig) INTO v_txt
    FROM (VALUES
      ('public.search_authors_by_name(text,integer)'),
      ('public.search_publishers_by_name(text,integer)'),
      ('public.remove_library_regulation_document(bigint)')
    ) AS f(sig)
   WHERE NOT has_function_privilege('authenticated', f.sig::regprocedure, 'EXECUTE');
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'ECHEC lot 1 : le revoke a emporte authenticated -> % (le staff connecte perd son outil)', v_txt;
  END IF;

  -- 2. Les cinq intouchables le sont restees, et portent leur raison.
  SELECT string_agg(f.sig, ', ' ORDER BY f.sig) INTO v_txt
    FROM (VALUES
      ('public.user_can_act_as_staff_on_library(uuid)'),
      ('public.user_can_engage_library(uuid)'),
      ('public.fn_caller_is_network_admin()'),
      ('public.fn_library_visible_to_caller(uuid)'),
      ('public.fn_caller_is_library_staff(uuid)')
    ) AS f(sig)
   WHERE NOT has_function_privilege('anon', f.sig::regprocedure, 'EXECUTE');
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'ECHEC lot 2 : fonction(s) fermee(s) a anon -> % (la lecture publique casse)', v_txt;
  END IF;

  SELECT string_agg(f.sig, ', ' ORDER BY f.sig) INTO v_txt
    FROM (VALUES
      ('public.user_can_act_as_staff_on_library(uuid)'),
      ('public.user_can_engage_library(uuid)'),
      ('public.fn_caller_is_network_admin()'),
      ('public.fn_library_visible_to_caller(uuid)'),
      ('public.fn_caller_is_library_staff(uuid)')
    ) AS f(sig)
   WHERE coalesce(obj_description(f.sig::regprocedure::oid, 'pg_proc'), '') NOT LIKE '%Item B2.%';
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'ECHEC lot 2 : commentaire absent ou tronque -> %', v_txt;
  END IF;

  RAISE NOTICE 'OK : 3 grants contredits retires, 5 fonctions portent desormais leur raison.';
END $$;

COMMIT;
