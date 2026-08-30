-- =========================================================================
-- Paquet IDENTITE-MAIL — la vue d'expédition devient lisible par le service
-- =========================================================================
-- Date     : 2026-08-30
-- Chantier : dédoublonnage de l'identité mail des bibliothèques
-- Ref      : 20260830160000 (API-VUES-DEFINER), 20260510000000 (baseline)
--
-- HORODATAGE : ce fichier trie AVANT 20260830203000 et 20260830210000, déjà
-- appliquées. Ce n'est pas une inversion accidentelle mais la conséquence de
-- leur propre défaut : elles ont été datées en heure locale (20:30 et 21:00)
-- alors que la convention est UTC — c'est le cas nommé par la huitième règle
-- du hook pre-commit, ajoutée dans la foulée. Les renommer les ferait rejouer,
-- donc elles restent. Celle-ci prend l'heure UTC réelle, à la seconde.
-- Aucune dépendance entre les trois : ce paquet ne touche que
-- api.library_email_identity, qui existe depuis le baseline. Rejouée depuis
-- zéro en CI, elle passe avant les deux autres sans que rien n'en dépende.
--
-- POURQUOI
--
-- `api.library_email_identity` existe déjà et fait exactement ce qu'il faut :
-- elle dérive l'identité d'expédition de `libraries` ⋈ `library_commons`. Son
-- commentaire dit qu'elle est « lue par les fonctions d'envoi de courriel ».
-- Elle ne l'est pas : personne ne peut la lire, elle n'est accordée à aucun
-- rôle. La fonction `register` lit à la place la TABLE `public.library_email_identity`,
-- copie figée des mêmes champs que rien ne synchronise — au 30/08/2026 elle
-- portait encore, pour la BLMF et la BTL, un `logo_url` pointant vers l'ancien
-- site de staging sur github.io.
--
-- Ce paquet ne fait qu'ouvrir la vue au rôle de service. Il ne débranche RIEN :
-- `register` continue de lire la table, et la bascule est un paquet séparé.
-- C'est délibéré — dans ci.yml, les edge functions sont déployées AVANT
-- `supabase db push` (étapes « Deploy Edge Functions » puis « Deploy Migrations »).
-- Livrer le GRANT et la bascule dans la même poussée ouvrirait une fenêtre où
-- la nouvelle fonction lirait une vue qu'elle n'a pas encore le droit de lire,
-- et toute inscription échouerait pendant ce temps.
--
-- CE QUI RESTE FERMÉ
--
-- La vue est SECURITY DEFINER et le reste : c'est un choix assumé du paquet
-- API-VUES-DEFINER du 29/08. Elle n'est accordée ni à `anon` ni à
-- `authenticated` — elle expose les adresses de contact et les adresses
-- postales des bibliothèques, c'est-à-dire de quoi reconstituer un annuaire.
-- `service_role` n'est pas un rôle applicatif : il n'est porté par aucune
-- session de navigateur, seulement par les edge functions côté serveur.
-- =========================================================================

BEGIN;

GRANT SELECT ON api.library_email_identity TO service_role;

COMMENT ON VIEW api.library_email_identity IS
  'Identite d''expedition par bibliotheque, derivee de libraries ⋈ library_commons, '
  'lue par les fonctions d''envoi de courriel (service_role uniquement, GRANT du '
  '30/08/2026 — jusque-la la vue etait accordee a personne et register lisait a la '
  'place la table public.library_email_identity, copie figee non synchronisee). '
  'Reste SANS security_invoker : elle est lue par un role de service, hors de toute '
  'session utilisateur. N''est accordee ni a anon ni a authenticated, et ne doit '
  'jamais l''etre — elle reconstitue l''annuaire des bibliotheques (adresses de '
  'contact et postales). Si un GRANT applicatif lui etait accorde un jour, il '
  'faudrait la passer en security_invoker dans le meme mouvement. '
  'Paquet API-VUES-DEFINER du 29/08/2026, elargi le 30/08/2026.';

-- -------------------------------------------------------------------------
-- Vérification (doctrine) — structurelle, donc valable aussi en CI.
-- -------------------------------------------------------------------------
DO $$
DECLARE v_n int;
BEGIN
  IF NOT has_table_privilege('service_role', 'api.library_email_identity', 'SELECT') THEN
    RAISE EXCEPTION 'service_role ne peut toujours pas lire api.library_email_identity';
  END IF;

  -- Le garde-fou du paquet API-VUES-DEFINER, repris a l'identique : la vue ne
  -- doit jamais devenir lisible par un role de session.
  SELECT count(*) INTO v_n
    FROM information_schema.role_table_grants
   WHERE table_schema = 'api' AND table_name = 'library_email_identity'
     AND grantee IN ('anon', 'authenticated');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'api.library_email_identity accordee a % role(s) applicatif(s)', v_n;
  END IF;
END $$;

COMMIT;
