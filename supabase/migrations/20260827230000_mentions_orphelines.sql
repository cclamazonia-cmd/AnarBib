-- =============================================================================
-- Mentions de bibliotheques hors reseau — exposition consentie (decision C)
-- =============================================================================
-- Date     : 2026-08-27
-- Ref      : docs/journal/cadrages/CADRAGE_invitation_bibliotheque_2026-08-27.md
--
-- DE QUOI ON PARLE. Le cas « je suis lecteur·rice d'une bibliotheque qui n'est
-- pas encore sur AnarBib » (/criar-conta) offre un champ facultatif ou la
-- personne peut nommer sa bibliotheque. Ce nom vit depuis des mois dans
-- profiles.signup_intent_metadata->>'library_name_mentioned'. L'app annonce a la
-- lectrice que ce nom « aide la coordination a connaitre les bibliotheques
-- encore hors du reseau » et qu'il « n'est lisible que par l'equipe qui
-- administre le reseau » — sauf que RIEN ne l'exposait a la coordination. La
-- promesse etait tenue dans le vide.
--
-- CE QUI EST DECIDE (C, 27/08/2026), ET POURQUOI C'EST PLUS ETROIT QUE L'ANNONCE.
-- « Aider a connaitre » ne dit pas « pourra ecrire a cette bibliotheque en votre
-- nom ». Le passage du SAVOIR au CONTACTER n'a jamais ete annonce. Deux
-- consentements EXPLICITES et distincts sont donc demandes a l'inscription :
--
--   mention_contact_consent      la coordination peut contacter cette
--                                bibliotheque. SANS LUI, LA MENTION N'APPARAIT
--                                NULLE PART — l'absence vaut refus.
--   mention_attribution_consent  et elle peut savoir que c'est moi qui l'ai
--                                citee. Sans lui, la mention est comptee mais
--                                jamais rattachee a personne.
--
-- POURQUOI LA FORME AGREGEE PAR DEFAUT. Montrer QUI a cite QUOI produirait un
-- graphe social : on apprendrait qui frequente quel lieu militant non affilie.
-- La lectrice a repondu a « quelle est ta bibliotheque ? », pas a « autorises-tu
-- qu'on sache que tu frequentes ce lieu ? ». Et la bibliotheque nommee, elle,
-- n'a jamais rien consenti du tout — d'ou le premier consentement, qui protege
-- un tiers absent de la conversation.
--
-- UNE FONCTION QUI LIT, JAMAIS UNE COPIE. La lectrice peut effacer sa mention
-- dans /conta (api.fn_clear_my_signup_metadata_field). Si la coordination
-- travaillait sur une table recopiee, cet effacement ne se propagerait pas et sa
-- faculte de retrait serait fictive. Cette fonction lit profiles a chaque appel :
-- effacer la mention la fait disparaitre d'ici, immediatement et sans rien a
-- synchroniser. C'est la raison pour laquelle il n'y a pas de table ici.
--
-- ETAT AU MOMENT DE POSER CECI : zero profil porte une mention (verifie). Aucun
-- consentement retroactif a inventer, aucune donnee ancienne a reclasser — les
-- deux drapeaux absents valent refus, donc les comptes anterieurs restent
-- invisibles par construction.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_list_orphan_library_mentions()
RETURNS TABLE(
  library_name text,
  mentions integer,
  derniere_mention timestamptz,
  personnes jsonb
)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $fn$
  -- Garde DANS le where : un appel non autorise rend zero ligne plutot qu'une
  -- erreur, comme fn_list_library_request_invitations.
  select
    min(btrim(p.signup_intent_metadata->>'library_name_mentioned')) as library_name,
    count(*)::int as mentions,
    max(p.signup_intent_set_at) as derniere_mention,
    -- Le rattachement nominatif n'apparait QUE pour les personnes qui l'ont
    -- consenti. Les autres sont comptees dans `mentions` et restent anonymes :
    -- c'est exactement la forme agregee par defaut.
    coalesce(
      jsonb_agg(
        jsonb_build_object('public_id', p.public_id, 'prenom', p.first_name)
        ORDER BY p.signup_intent_set_at
      ) FILTER (WHERE (p.signup_intent_metadata->>'mention_attribution_consent')::boolean is true),
      '[]'::jsonb
    ) as personnes
  from public.profiles p
  where public.fn_caller_is_network_admin()
    and p.signup_intent = 'reader_orphan'
    and nullif(btrim(coalesce(p.signup_intent_metadata->>'library_name_mentioned', '')), '') is not null
    -- Sans consentement au contact, la mention n'existe pas pour la coordination.
    and (p.signup_intent_metadata->>'mention_contact_consent')::boolean is true
  group by lower(btrim(p.signup_intent_metadata->>'library_name_mentioned'))
  order by count(*) desc, 1;
$fn$;

REVOKE ALL ON FUNCTION public.fn_list_orphan_library_mentions() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_list_orphan_library_mentions() FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_list_orphan_library_mentions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_list_orphan_library_mentions() TO service_role;

COMMENT ON FUNCTION public.fn_list_orphan_library_mentions() IS
  'Bibliotheques hors reseau nommees par des lecteur·rices, pour la coordination (admins reseau seuls). Decision C du 27/08/2026 : n''expose une mention QUE si mention_contact_consent est vrai, et ne la rattache a une personne QUE si mention_attribution_consent l''est aussi. Lit profiles en direct et non une copie : effacer la mention dans /conta la fait disparaitre d''ici immediatement.';
