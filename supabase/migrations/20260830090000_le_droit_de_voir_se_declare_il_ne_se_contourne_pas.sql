-- =====================================================================
-- AnarBib -- Les deux vues de gouvernance passent sous les policies
-- Date    : 2026-08-30  ·  Item B3 (reprise) ; advisor Supabase 0010
-- Ref     : migration 20260830160000 (paquet API-VUES-DEFINER, 29/08)
--
-- CE QUE CORRIGE CETTE MIGRATION, ET POURQUOI ELLE REVIENT SUR HIER.
--
-- Hier, cinq des sept vues de `api` sont passees en `security_invoker`.
-- Les deux vues de gouvernance ont ete gardees en DEFINER, avec la clause
-- de visibilite recopiee dans le corps de la vue. Le motif invoque etait
-- exact -- en invoker, la jointure sur `profiles` renvoie NULL a
-- l'administratrice qui doit decider -- mais c'etait le SYMPTOME d'une
-- policy manquante sur `profiles`, pas une raison de contourner les
-- policies. On a traite le symptome.
--
-- En relisant les tables de base, trois choses apparaissent :
--
--   1. La clause recopiee dans les vues EST DEJA la policy des tables de
--      base, mot pour mot. On dupliquait une regle existante -- ce que le
--      corpus interdit precisement ailleurs (foyer unique).
--
--   2. `profiles` ne laisse lire que « mon profil ou ceux de mes
--      bibliotheques ». Une admin reseau statuant sur quelqu'un
--      d'exterieur voit des champs vides.
--
--   3. Plus grave : `network_admin_collective_removal_votes` n'est lisible
--      que par `fn_caller_is_network_admin()`. La personne VISEE par une
--      proposition de retrait a le droit de voir la proposition, mais
--      verrait « 0 vote » au lieu du decompte reel. Pas un refus : un
--      chiffre faux, silencieux. C'est pire qu'une erreur d'advisor, et
--      c'est ce qui serait arrive a qui aurait bascule les vues sans
--      regarder dessous.
--
-- LE PARTI PRIS. Le droit de voir se declare, il ne se contourne pas. Les
-- deux policies ci-dessous n'ouvrent rien de neuf : elles enoncent comme
-- regle ce que la vue DEFINER accordait deja de fait, a la meme population,
-- et en le bornant aux propositions EN COURS. La difference est qu'une
-- regle est opposable, testable, et lisible par qui audite la base --
-- tandis qu'un contournement ne se voit qu'en lisant le corps d'une vue.
--
-- Effet attendu : advisor 0010 a zero sur ce projet.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. `profiles` : les personnes concernees par une proposition en cours
-- ---------------------------------------------------------------------
-- Portee volontairement etroite :
--   * seulement les propositions NON CLOSES (`open`, et `unanimous` pour
--     le retrait, qui reste affiche pendant le delai de retractation) ;
--   * seulement la personne VISEE et la personne PROPOSANTE ;
--   * seulement pour une admin reseau, ou pour la personne visee
--     elle-meme -- qui doit pouvoir savoir qui la propose.
-- Une proposition close, expiree ou annulee ne donne plus rien : le droit
-- de voir dure ce que dure la deliberation.
--
-- Pas de recursion : `fn_caller_is_network_admin()` est SECURITY DEFINER
-- et ne lit que `network_administrators`, jamais `profiles`.
DROP POLICY IF EXISTS profiles_select_gouvernance_en_cours ON public.profiles;
CREATE POLICY profiles_select_gouvernance_en_cours
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
        FROM public.network_administrator_cooptation_proposals p
       WHERE p.status = 'open'
         AND (p.proposed_user_id = profiles.id OR p.proposed_by = profiles.id)
         AND (public.fn_caller_is_network_admin()
              OR p.proposed_user_id = (SELECT auth.uid()))
    )
    OR EXISTS (
      SELECT 1
        FROM public.network_admin_collective_removal_proposals p
       WHERE p.status IN ('open', 'unanimous')
         AND (p.proposed_user_id = profiles.id OR p.proposed_by = profiles.id)
         AND (public.fn_caller_is_network_admin()
              OR p.proposed_user_id = (SELECT auth.uid()))
    )
  );

COMMENT ON POLICY profiles_select_gouvernance_en_cours ON public.profiles IS
  'Deliberation de gouvernance en cours : les admins reseau, et la personne visee, '
  'lisent le profil des deux personnes concernees (visee et proposante) le temps '
  'de la deliberation seulement. Enonce comme regle ce que les vues '
  'api.cooptation_proposals_current_v1 et api.collective_removal_proposals_current_v1 '
  'accordaient auparavant en contournant les policies. Ajoutee le 30/08/2026.';

-- ---------------------------------------------------------------------
-- 2. Votes de retrait : la personne visee voit le decompte qui la concerne
-- ---------------------------------------------------------------------
-- La policy ne couvrait que les admins reseau. La personne visee, qui a le
-- droit de LIRE la proposition, aurait vu un decompte a zero -- un chiffre
-- faux plutot qu'un refus. On aligne sur la policy des votes de
-- cooptation, qui traitait deja ce cas correctement.
DROP POLICY IF EXISTS rls_crv_select ON public.network_admin_collective_removal_votes;
CREATE POLICY rls_crv_select
  ON public.network_admin_collective_removal_votes
  FOR SELECT
  USING (
    public.fn_caller_is_network_admin()
    OR voter_user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
        FROM public.network_admin_collective_removal_proposals p
       WHERE p.id = network_admin_collective_removal_votes.proposal_id
         AND p.proposed_user_id = (SELECT auth.uid())
    )
  );

COMMENT ON POLICY rls_crv_select ON public.network_admin_collective_removal_votes IS
  'Admins reseau, votant sur son propre vote, et personne visee sur les votes de sa '
  'propre proposition. Le troisieme cas a ete ajoute le 30/08/2026 : sans lui, la '
  'personne visee lisait un decompte a zero au lieu du decompte reel.';

-- ---------------------------------------------------------------------
-- 3. Les deux vues passent sous les policies
-- ---------------------------------------------------------------------
-- La clause `fn_caller_is_network_admin() OR proposed_user_id = auth.uid()`
-- reste dans le corps des vues. Elle devient redondante avec la policy des
-- tables de base, mais on ne retouche pas un corps de vue de quarante
-- lignes pour retirer un predicat juste : la redondance ne coute rien et
-- garde la vue lisible seule.
ALTER VIEW api.cooptation_proposals_current_v1          SET (security_invoker = true);
ALTER VIEW api.collective_removal_proposals_current_v1  SET (security_invoker = true);

COMMENT ON VIEW api.cooptation_proposals_current_v1 IS
  'Propositions de cooptation en cours. Sous les policies depuis le 30/08/2026 '
  '(security_invoker) : la visibilite des profils concernes est portee par la policy '
  'profiles_select_gouvernance_en_cours, plus par une derogation de la vue.';

COMMENT ON VIEW api.collective_removal_proposals_current_v1 IS
  'Propositions de retrait collectif en cours. Sous les policies depuis le 30/08/2026 '
  '(security_invoker) : visibilite des profils portee par '
  'profiles_select_gouvernance_en_cours, decompte des votes par rls_crv_select.';

-- ---------------------------------------------------------------------
-- 4. Verification -- annule tout si l'etat vise n'est pas atteint
-- ---------------------------------------------------------------------
DO $$
DECLARE
  v_definer  int;
  v_pol_prof int;
  v_pol_vote int;
  v_txt      text;
BEGIN
  -- 4.1 Plus aucune vue de `api` hors policies, sauf library_email_identity
  --     (accordee a aucun role applicatif, donc hors de portee).
  SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
    INTO v_definer, v_txt
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'api' AND c.relkind = 'v'
     AND c.relname <> 'library_email_identity'
     AND coalesce((SELECT option_value FROM pg_options_to_table(c.reloptions)
                    WHERE option_name = 'security_invoker'), 'false') <> 'true';
  IF v_definer > 0 THEN
    RAISE EXCEPTION 'ECHEC : % vue(s) de api hors des policies -> %', v_definer, v_txt;
  END IF;

  -- 4.2 Les deux policies sont bien en place et PERMISSIVE (sans quoi elles
  --     restreindraient au lieu d'ajouter).
  SELECT count(*) INTO v_pol_prof
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
   WHERE c.relname = 'profiles' AND c.relnamespace = 'public'::regnamespace
     AND p.polname = 'profiles_select_gouvernance_en_cours'
     AND p.polpermissive;
  IF v_pol_prof <> 1 THEN
    RAISE EXCEPTION 'ECHEC : policy profiles_select_gouvernance_en_cours absente ou non permissive';
  END IF;

  SELECT count(*) INTO v_pol_vote
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
   WHERE c.relname = 'network_admin_collective_removal_votes'
     AND p.polname = 'rls_crv_select'
     AND pg_get_expr(p.polqual, p.polrelid) LIKE '%proposed_user_id%';
  IF v_pol_vote <> 1 THEN
    RAISE EXCEPTION 'ECHEC : rls_crv_select ne couvre pas la personne visee';
  END IF;

  -- 4.3 La policy historique de profiles est intacte : on AJOUTE un cas,
  --     on n'en retire aucun.
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
     WHERE c.relname = 'profiles' AND c.relnamespace = 'public'::regnamespace
       AND p.polname = 'profiles_select_consolidated'
  ) THEN
    RAISE EXCEPTION 'ECHEC : profiles_select_consolidated a disparu';
  END IF;

  RAISE NOTICE 'OK : 2 vues de gouvernance sous les policies, 2 policies posees, profiles intacte.';
END $$;

COMMIT;
