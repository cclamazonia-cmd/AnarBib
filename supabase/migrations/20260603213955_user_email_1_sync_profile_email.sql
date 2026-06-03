-- ════════════════════════════════════════════════════════════════════════
-- USER-EMAIL-1 : profiles.email = miroir fidele de auth.users.email
-- ════════════════════════════════════════════════════════════════════════
-- profiles.email est lu partout (login via resolve_login_email, ciblage des
-- mails, lookup utilisateur par email, reponses API) : c'est un miroir
-- denormalise de auth.users.email (le schema auth est d'acces restreint, on
-- recopie donc l'email dans profiles plutot que de joindre auth.users partout).
-- Mais il n'etait ecrit qu'a la CREATION (trigger handle_auth_user_created_
-- profile, coalesce collant) -- jamais resync au CHANGEMENT d'email.
-- Le flip auth.users.email se fait hors-app (confirmation GoTrue asynchrone),
-- donc seul un trigger DB peut le capter de facon fiable.
--
-- Sans ce correctif, tout utilisateur qui change son email casse :
--   login par identifiant, ciblage des mails, lookup par la nouvelle adresse.
--
-- Ce correctif :
--   (1) fonction + trigger de sync au changement d'email ;
--   (2) reconciliation des divergences deja presentes.
-- Triggers existants sur profiles : seul set_updated_at (BEFORE UPDATE, benin)
-- et set_public_id (INSERT only) -- aucune notification mal declenchee.
-- profiles.email est nullable : poser NULL pour un compte sans email est OK.
-- ════════════════════════════════════════════════════════════════════════

-- (1) Fonction de sync. Fonction de trigger : jamais appelee directement par
--     un role -> REVOKE de tous (le trigger l'invoque comme SECURITY DEFINER).
CREATE OR REPLACE FUNCTION public.sync_profile_email_on_auth_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  UPDATE public.profiles
     SET email = NULLIF(btrim(NEW.email), '')
   WHERE id = NEW.id;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sync_profile_email_on_auth_change()
  FROM PUBLIC, anon, authenticated, service_role;

-- Trigger : se declenche uniquement quand la colonne email change reellement
-- (AFTER UPDATE OF email + garde IS DISTINCT FROM -> n'interfere pas avec les
--  autres updates de auth.users comme last_sign_in_at).
DROP TRIGGER IF EXISTS on_auth_user_email_changed ON auth.users;
CREATE TRIGGER on_auth_user_email_changed
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW
  WHEN (NEW.email IS DISTINCT FROM OLD.email)
  EXECUTE FUNCTION public.sync_profile_email_on_auth_change();

-- (2) Reconciliation de l'existant + verification (RAISE EXCEPTION = rollback).
DO $verify$
DECLARE
  v_drift int;
BEGIN
  UPDATE public.profiles p
     SET email = NULLIF(btrim(u.email), '')
    FROM auth.users u
   WHERE u.id = p.id
     AND COALESCE(NULLIF(btrim(p.email), ''), '')
         IS DISTINCT FROM COALESCE(NULLIF(btrim(u.email), ''), '');
  GET DIAGNOSTICS v_drift = ROW_COUNT;
  RAISE NOTICE 'USER-EMAIL-1: % profil(s) reconcilie(s) sur auth.users.email', v_drift;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
     WHERE tgname = 'on_auth_user_email_changed'
       AND tgrelid = 'auth.users'::regclass
  ) THEN
    RAISE EXCEPTION 'USER-EMAIL-1: trigger on_auth_user_email_changed absent apres creation';
  END IF;
END
$verify$;
