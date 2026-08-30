-- =====================================================================
-- AnarBib -- Quatre fonctions quittent `anon`, dont une qui n'aurait
--            jamais du y etre
-- Date    : 2026-08-30  ·  Item B2, lot 4 (suite de l'audit du meme jour)
-- Ref     : docs/journal/audits/AUDIT_execute_anon_2026-08-30.md
--           migration 20260830181207 (lots 1 et 2)
--
-- L'audit a passe les 33 fonctions `SECURITY DEFINER` encore ouvertes a `anon`
-- avec le critere du 18/05 : que renvoie-t-elle, a partir de quel parametre, et
-- qu'est-ce qui interdit a un tiers non connecte de le demander ? Vingt-huit
-- sont legitimes. Cinq etaient a traiter ; quatre le sont ici.
--
-- La cinquieme, `list_catalog_libraries()`, n'est PAS touchee : son corps exige
-- `fn_caller_is_network_admin()`, donc `anon` recoit une liste vide, mais son
-- NOM promet la liste des bibliotheques au catalogue publie. Les deux ne
-- peuvent pas etre justes. Retirer le grant changerait « liste vide » en
-- « permission denied » sur une page peut-etre publique : c'est une question de
-- conception a trancher avec le front, pas un nettoyage de droits.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. La seule vraie sur-exposition : le decompte d'une deliberation
-- ---------------------------------------------------------------------
--   SELECT count(*), count(*) FILTER (WHERE vote = 'yes'), count(*) FILTER (WHERE vote IS NULL)
--     FROM public.oai_opening_votes WHERE request_id = p_request_id;
--
-- Aucun controle. Qui possede l'UUID d'une demande d'ouverture reseau lisait,
-- sans compte, combien de bibliotheques sont concernees, combien ont consenti,
-- combien n'ont pas repondu. Un UUID n'est pas un secret : il circule dans les
-- URL, les journaux, les copier-coller.
--
-- C'est la meme famille que le defaut corrige le matin meme sur les votes de
-- retrait collectif -- mais retournee. La, la personne visee lisait « 0 » au
-- lieu du decompte reel ; ici, n'importe qui lisait le decompte reel.
-- UNE DELIBERATION EN COURS N'EST PAS UNE DONNEE PUBLIQUE.
--
-- `authenticated` est le minimum, pas la fin : le bon perimetre est les
-- bibliotheques concernees par la demande, comme pour les votes de cooptation.
-- On ferme d'abord, on affine ensuite -- l'inverse laisserait la porte ouverte
-- le temps de la reflexion.
REVOKE EXECUTE ON FUNCTION public.fn_oai_network_vote_progress(uuid) FROM anon;

COMMENT ON FUNCTION public.fn_oai_network_vote_progress(uuid) IS
  'Paquet OAI-O1. Progression vers l''unanimite d''une proposition d''ouverture reseau, '
  'en COMPTES (aucun nom de votant). Fermee a anon le 30/08/2026 (item B2) : elle ne '
  'portait aucun controle, et un UUID de demande suffisait a lire une deliberation en '
  'cours. Reste a restreindre aux bibliotheques concernees, comme les votes de cooptation.';

-- ---------------------------------------------------------------------
-- 2. L'existence d'une bibliotheque est une donnee
-- ---------------------------------------------------------------------
--   SELECT lss.library_id, coalesce(...) FROM public.library_service_state lss;
--
-- Aucun filtre de visibilite : un appel anonyme rendait l'identifiant de TOUTES
-- les bibliotheques de l'instance, y compris celles en `network_mode = isolated`
-- ou au catalogue non publie.
--
-- Le fuseau horaire n'est pas sensible. L'existence d'une bibliotheque l'est :
-- pour un reseau de bibliotheques militantes, la liste complete des lieux est
-- exactement ce qu'une bibliotheque isolee a choisi de ne pas publier. La
-- fonction sert un besoin technique interne (les crons de consultation) qui n'a
-- aucune raison d'etre anonyme -- et `service_role`, qui la consomme depuis
-- l'Edge Function, conserve son droit.
REVOKE EXECUTE ON FUNCTION public.fn_library_timezones() FROM anon;

COMMENT ON FUNCTION public.fn_library_timezones() IS
  'Retourne (library_id, consultation_timezone) pour toutes les bibliotheques. '
  'SECURITY DEFINER, consommee par les crons de consultation en service_role. '
  'Fermee a anon le 30/08/2026 (item B2) : sans filtre de visibilite, elle enumerait '
  'toute l''instance -- or l''existence d''une bibliotheque isolee est precisement ce '
  'qu''elle a choisi de ne pas publier.';

-- ---------------------------------------------------------------------
-- 3. Deux fermetures sans histoire : aucun usage anonyme
-- ---------------------------------------------------------------------
-- Ni l'une ni l'autre n'est appelee par une policy, une vue ou une fonction
-- `SECURITY INVOKER` (verifie avant ecriture). Les partenariats se gerent
-- connecte ; un plafond de politique de circulation n'interesse pas un
-- visiteur.
REVOKE EXECUTE ON FUNCTION public.fn_partnership_reciprocal_id(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_circulation_concurrent_max(uuid, text) FROM anon;

-- ---------------------------------------------------------------------
-- Verification -- cette migration verifie CE QU'ELLE FAIT
-- ---------------------------------------------------------------------
DO $$
DECLARE
  v_txt text;
BEGIN
  SELECT string_agg(f.sig, ', ' ORDER BY f.sig) INTO v_txt
    FROM (VALUES
      ('public.fn_oai_network_vote_progress(uuid)'),
      ('public.fn_library_timezones()'),
      ('public.fn_partnership_reciprocal_id(uuid)'),
      ('public.fn_circulation_concurrent_max(uuid,text)')
    ) AS f(sig)
   WHERE has_function_privilege('anon', f.sig::regprocedure, 'EXECUTE');
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'ECHEC : encore executable(s) par anon -> %', v_txt;
  END IF;

  -- Le revoke ne doit toucher QUE `anon`.
  SELECT string_agg(f.sig, ', ' ORDER BY f.sig) INTO v_txt
    FROM (VALUES
      ('public.fn_oai_network_vote_progress(uuid)'),
      ('public.fn_library_timezones()'),
      ('public.fn_partnership_reciprocal_id(uuid)'),
      ('public.fn_circulation_concurrent_max(uuid,text)')
    ) AS f(sig)
   WHERE NOT has_function_privilege('service_role', f.sig::regprocedure, 'EXECUTE');
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'ECHEC : le revoke a emporte service_role -> % (les crons cassent)', v_txt;
  END IF;

  RAISE NOTICE 'OK : 4 fonctions fermees a anon, service_role intact. Reste 29 ouvertes.';
END $$;

COMMIT;
