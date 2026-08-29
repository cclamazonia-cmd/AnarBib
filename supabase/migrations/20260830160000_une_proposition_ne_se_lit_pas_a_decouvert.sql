-- =========================================================================
-- Paquet API-VUES-DEFINER — une proposition de gouvernance ne se lit pas
-- a decouvert
-- =========================================================================
-- Date     : 2026-08-29
-- Chantier : hygiene de la securite — item B3 du backlog v34
-- Ref      : docs/backlogs/AnarBib-Backlog-2026-08-29-v34.md (B3)
--            grants_herites_tests.sql T7, qui porte le meme invariant sur `public`
--
-- LE CONSTAT. Sept vues du schema `api` sont restees sans `security_invoker`,
-- anterieures au hook pre-commit qui l'interdit depuis mai. Une vue sans cet
-- attribut s'execute avec les droits de son proprietaire : la RLS de ses tables
-- de base est CONTOURNEE pour quiconque peut la lire. Le lot se partage en deux,
-- et une seule moitie est un defaut.
--
-- MOITIE SANS CONSEQUENCE — les quatre vues gazette et lettre. Elles filtrent
-- elles-memes le statut (`published`, `sent`), exactement ce que disent les
-- policies de leurs tables. Le contournement n'expose donc aucun brouillon.
-- On les passe en `security_invoker` quand meme : le jour ou quelqu'un modifie
-- la vue et oublie le WHERE, la policy rattrapera. C'est de la defense en
-- profondeur, sans effet visible aujourd'hui.
--
-- MOITIE QUI EN EST UN — les deux vues de gouvernance. Elles ne portent AUCUN
-- filtre de visibilite : elles selectionnent sur le seul statut de la
-- proposition, exposent le prenom, le nom, le courriel et l'identifiant public
-- de la personne visee ET de celle qui propose, plus la motivation — et elles
-- sont accordees en SELECT a `authenticated`. La policy des tables de base dit
-- pourtant exactement qui doit voir :
--
--     fn_caller_is_network_admin() OR proposed_user_id = auth.uid()
--
-- La vue la contourne. Autrement dit : tout compte connecte peut lire les
-- propositions de cooptation et de retrait collectif en cours, nominativement.
--
-- Rien n'est expose EN CE MOMENT : les deux tables sont vides. Mais elles se
-- rempliront le jour ou le reseau obtiendra d'autres administrateur·rices —
-- c'est-a-dire au moment ou le projet reussira l'item A1, le plus important de
-- son backlog. La faille s'ouvrirait exactement le jour de la reussite.
--
-- POURQUOI CES DEUX-LA NE PASSENT PAS EN `security_invoker`. Ce serait le geste
-- naturel, et il casserait l'ecran. Les vues joignent `public.profiles`, dont
-- la policy de lecture est `id = auth.uid() OR can_manage_profile_from_my_libraries(id)`
-- — un administrateur reseau n'y est PAS couvert s'il ne gere pas la
-- bibliotheque de la personne visee. En invoker, les colonnes de nom et de
-- courriel deviendraient NULL pour celle ou celui-la meme qui doit decider.
-- On garde donc le proprietaire, et on ecrit dans la vue la garde que la policy
-- porte deja — a l'identique, sans l'elargir.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- BLOC A — Les quatre vues publiques passent sous les policies
-- -------------------------------------------------------------------------

ALTER VIEW api.gazette_issues_public_v1  SET (security_invoker = true);
ALTER VIEW api.gazette_locales_public_v1 SET (security_invoker = true);
ALTER VIEW api.lettre_public_v1          SET (security_invoker = true);
ALTER VIEW api.lettre_locales_public_v1  SET (security_invoker = true);

COMMENT ON VIEW api.gazette_issues_public_v1 IS
  'Numeros de la gazette publies. security_invoker=true depuis le paquet '
  'API-VUES-DEFINER du 29/08/2026 : le filtre de statut de la vue et la policy '
  'gazette_issues_read_published disent la meme chose, la policy est le filet.';
COMMENT ON VIEW api.gazette_locales_public_v1 IS
  'Contenus localises des numeros publies. security_invoker=true depuis le paquet '
  'API-VUES-DEFINER du 29/08/2026.';
COMMENT ON VIEW api.lettre_public_v1 IS
  'Numeros de la lettre envoyes. security_invoker=true depuis le paquet '
  'API-VUES-DEFINER du 29/08/2026.';
COMMENT ON VIEW api.lettre_locales_public_v1 IS
  'Contenus localises des lettres envoyees. security_invoker=true depuis le paquet '
  'API-VUES-DEFINER du 29/08/2026.';

-- -------------------------------------------------------------------------
-- BLOC B — Les deux vues de gouvernance portent enfin leur garde
-- -------------------------------------------------------------------------
-- Definitions reprises a l'identique, AVEC en plus la clause de visibilite.
-- Les references sont prefixees `public.` : le search_path d'une vue est fige
-- a sa creation, et une migration ne doit pas dependre de celui de sa session.

CREATE OR REPLACE VIEW api.cooptation_proposals_current_v1 AS
 WITH active_admin_count AS (
   SELECT count(*)::integer AS total
     FROM public.network_administrators
    WHERE network_administrators.status = 'active'::text
 )
 SELECT p.id AS proposal_id,
    p.proposed_user_id,
    p.proposed_by,
    p.proposed_at,
    p.expires_at,
    p.motivation,
    p.status,
    target_profile.public_id   AS proposed_public_id,
    target_profile.first_name  AS proposed_first_name,
    target_profile.last_name   AS proposed_last_name,
    target_profile.email       AS proposed_email,
    proposer_profile.public_id  AS proposer_public_id,
    proposer_profile.first_name AS proposer_first_name,
    proposer_profile.last_name  AS proposer_last_name,
    proposer_profile.email      AS proposer_email,
    (( SELECT count(*) AS count
         FROM public.network_administrator_cooptation_votes v
        WHERE v.proposal_id = p.id AND v.vote = 'favorable'::text))::integer AS favorable_count,
    (( SELECT count(*) AS count
         FROM public.network_administrator_cooptation_votes v
        WHERE v.proposal_id = p.id AND v.vote = 'opposed'::text))::integer AS opposed_count,
    (( SELECT count(*) AS count
         FROM public.network_administrator_cooptation_votes v
        WHERE v.proposal_id = p.id AND v.vote = 'abstain'::text))::integer AS abstain_count,
    (( SELECT active_admin_count.total FROM active_admin_count)) -
      CASE
        WHEN (EXISTS ( SELECT 1
                FROM public.network_administrators na
               WHERE na.user_id = p.proposed_user_id AND na.status = 'active'::text)) THEN 1
        ELSE 0
      END AS required_votes,
    (EXISTS ( SELECT 1
         FROM public.network_administrator_cooptation_votes v
        WHERE v.proposal_id = p.id AND v.voter_user_id = auth.uid())) AS caller_has_voted,
    p.proposed_user_id = auth.uid() AS caller_is_target,
    p.proposed_by = auth.uid()      AS caller_is_proposer
   FROM public.network_administrator_cooptation_proposals p
     LEFT JOIN public.profiles target_profile   ON target_profile.id = p.proposed_user_id
     LEFT JOIN public.profiles proposer_profile ON proposer_profile.id = p.proposed_by
  WHERE p.status = 'open'::text
    -- Garde ajoutee le 29/08/2026 : reprend a l'identique la policy
    -- proposals_select_admins_or_proposed de la table de base.
    AND (public.fn_caller_is_network_admin() OR p.proposed_user_id = auth.uid());

CREATE OR REPLACE VIEW api.collective_removal_proposals_current_v1 AS
 WITH active_admin_count AS (
   SELECT count(*)::integer AS total
     FROM public.network_administrators
    WHERE network_administrators.status = 'active'::text
 )
 SELECT p.id AS proposal_id,
    p.proposed_user_id,
    p.proposed_by,
    p.proposed_at,
    p.expires_at,
    p.motivation,
    p.status,
    p.unanimous_at,
    p.pending_removal_until,
    target_profile.public_id   AS proposed_public_id,
    target_profile.first_name  AS proposed_first_name,
    target_profile.last_name   AS proposed_last_name,
    target_profile.email       AS proposed_email,
    proposer_profile.public_id  AS proposer_public_id,
    proposer_profile.first_name AS proposer_first_name,
    proposer_profile.last_name  AS proposer_last_name,
    proposer_profile.email      AS proposer_email,
    (( SELECT count(*) AS count
         FROM public.network_admin_collective_removal_votes v
        WHERE v.proposal_id = p.id AND v.vote = 'favor'::text))::integer AS favor_count,
    (( SELECT count(*) AS count
         FROM public.network_admin_collective_removal_votes v
        WHERE v.proposal_id = p.id AND v.vote = 'against'::text))::integer AS against_count,
    (( SELECT active_admin_count.total FROM active_admin_count)) -
      CASE
        WHEN (EXISTS ( SELECT 1
                FROM public.network_administrators na
               WHERE na.user_id = p.proposed_user_id AND na.status = 'active'::text)) THEN 1
        ELSE 0
      END AS required_votes,
    (EXISTS ( SELECT 1
         FROM public.network_admin_collective_removal_votes v
        WHERE v.proposal_id = p.id AND v.voter_user_id = auth.uid())) AS caller_has_voted,
    p.proposed_user_id = auth.uid() AS caller_is_target,
    p.proposed_by = auth.uid()      AS caller_is_proposer
   FROM public.network_admin_collective_removal_proposals p
     LEFT JOIN public.profiles target_profile   ON target_profile.id = p.proposed_user_id
     LEFT JOIN public.profiles proposer_profile ON proposer_profile.id = p.proposed_by
  WHERE p.status = ANY (ARRAY['open'::text, 'unanimous'::text])
    -- Garde ajoutee le 29/08/2026 : reprend a l'identique la policy
    -- rls_crp_select de la table de base.
    AND (public.fn_caller_is_network_admin() OR p.proposed_user_id = auth.uid());

COMMENT ON VIEW api.cooptation_proposals_current_v1 IS
  'Propositions de cooptation en cours. Reste volontairement SANS security_invoker : '
  'la vue joint public.profiles, dont la policy ne couvre pas un·e administrateur·rice '
  'reseau qui ne gere pas la bibliotheque de la personne visee — en invoker, les noms et '
  'courriels seraient NULL pour qui doit decider. La visibilite est donc portee par la '
  'clause WHERE de la vue, reprise a l''identique de la policy de la table de base. '
  'Toute modification de cette vue DOIT conserver cette clause. Paquet API-VUES-DEFINER du 29/08/2026.';

COMMENT ON VIEW api.collective_removal_proposals_current_v1 IS
  'Propositions de retrait collectif en cours. Reste volontairement SANS security_invoker, '
  'pour la meme raison que api.cooptation_proposals_current_v1 : la jointure sur '
  'public.profiles serait videe pour l''administrateur·rice appelant·e. La visibilite est '
  'portee par la clause WHERE de la vue, reprise a l''identique de la policy rls_crp_select. '
  'Toute modification de cette vue DOIT conserver cette clause. Paquet API-VUES-DEFINER du 29/08/2026.';

-- -------------------------------------------------------------------------
-- BLOC C — La septieme vue : DEFINER assume, et sans aucun droit accorde
-- -------------------------------------------------------------------------

COMMENT ON VIEW api.library_email_identity IS
  'Identite d''expedition par bibliotheque, lue par les fonctions d''envoi de courriel. '
  'Reste SANS security_invoker et n''est accordee a AUCUN role applicatif : ni anon ni '
  'authenticated ne peuvent la lire, verifie le 29/08/2026. Si un GRANT lui etait accorde '
  'un jour, il faudrait la passer en security_invoker dans le meme mouvement. '
  'Paquet API-VUES-DEFINER du 29/08/2026.';

-- -------------------------------------------------------------------------
-- BLOC D — Verification automatique (RAISE EXCEPTION = rollback)
-- -------------------------------------------------------------------------

DO $$
DECLARE
  v_invoker   int;
  v_definer   int;
  v_sans_note int;
  v_sans_garde int;
  v_grants    int;
  v_noms      text;
BEGIN
  -- Les quatre vues publiques sont passees en invoker.
  SELECT count(*) INTO v_invoker
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'api' AND c.relkind = 'v'
     AND c.relname IN ('gazette_issues_public_v1','gazette_locales_public_v1',
                       'lettre_public_v1','lettre_locales_public_v1')
     AND coalesce((SELECT option_value FROM pg_options_to_table(c.reloptions)
                    WHERE option_name = 'security_invoker'), 'false') = 'true';
  IF v_invoker <> 4 THEN
    RAISE EXCEPTION 'API-VUES-DEFINER : %/4 vues publiques en security_invoker. Rollback automatique.', v_invoker;
  END IF;

  -- Les deux vues de gouvernance portent bien leur garde.
  SELECT count(*) INTO v_sans_garde
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'api' AND c.relkind = 'v'
     AND c.relname IN ('cooptation_proposals_current_v1','collective_removal_proposals_current_v1')
     AND pg_get_viewdef(c.oid, true) NOT LIKE '%fn_caller_is_network_admin%';
  IF v_sans_garde > 0 THEN
    RAISE EXCEPTION 'API-VUES-DEFINER : % vue(s) de gouvernance sans clause de visibilite. Rollback automatique.', v_sans_garde;
  END IF;

  -- Plus aucune vue DEFINER de `api` sans note expliquant pourquoi.
  SELECT count(*), coalesce(string_agg(c.relname, ', ' ORDER BY c.relname), '')
    INTO v_sans_note, v_noms
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'api' AND c.relkind = 'v'
     AND coalesce((SELECT option_value FROM pg_options_to_table(c.reloptions)
                    WHERE option_name = 'security_invoker'), 'false') <> 'true'
     AND coalesce(obj_description(c.oid, 'pg_class'), '') NOT LIKE '%API-VUES-DEFINER%';
  IF v_sans_note > 0 THEN
    RAISE EXCEPTION 'API-VUES-DEFINER : % vue(s) DEFINER sans justification (%). Rollback automatique.', v_sans_note, v_noms;
  END IF;

  -- library_email_identity ne doit toujours etre accordee a personne.
  SELECT count(*) INTO v_grants
    FROM information_schema.role_table_grants
   WHERE table_schema = 'api' AND table_name = 'library_email_identity'
     AND grantee IN ('anon', 'authenticated');
  IF v_grants > 0 THEN
    RAISE EXCEPTION 'API-VUES-DEFINER : library_email_identity a recu % droit(s) — elle doit passer en security_invoker. Rollback automatique.', v_grants;
  END IF;

  SELECT count(*) INTO v_definer
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'api' AND c.relkind = 'v'
     AND coalesce((SELECT option_value FROM pg_options_to_table(c.reloptions)
                    WHERE option_name = 'security_invoker'), 'false') <> 'true';

  RAISE NOTICE 'API-VUES-DEFINER OK : 4 vues passees en invoker, % vue(s) DEFINER restantes, toutes justifiees et gardees.', v_definer;
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé en cas de régression post-déploiement :
-- =========================================================================
-- Les quatre ALTER VIEW se defont par SET (security_invoker = false).
-- Les deux vues de gouvernance se restaurent en retirant la derniere clause
-- AND (public.fn_caller_is_network_admin() OR p.proposed_user_id = auth.uid())
-- de leur definition — mais ce serait rouvrir la lecture a tout compte connecte.
-- =========================================================================
