-- =========================================================================
-- Paquet INTERRUPTEUR-UNIQUE — refermer fn_library_ensure_mail_channel
-- =========================================================================
-- Date     : 2026-08-30
-- Chantier : commutateur d'envoi des bibliothèques
-- Ref      : 20260830203000 (toute_biblio_a_sa_ligne_de_canal)
--
-- La migration 20260830203000 a créé fn_library_ensure_mail_channel avec un
-- REVOKE EXECUTE ... FROM PUBLIC, en suivant la checklist du _TEMPLATE. Ça ne
-- suffit pas : sur cette base, `anon` et `authenticated` reçoivent EXECUTE sur
-- les fonctions de `public` par des privilèges PAR DÉFAUT, qui ne passent pas
-- par PUBLIC. Révoquer PUBLIC laisse donc les deux rôles servis, et la fonction
-- s'est retrouvée ouverte à anon.
--
-- Le T10 de tests/sql/grants_herites_tests.sql l'a vue tout de suite : la liste
-- des fonctions SECURITY DEFINER ouvertes à anon est nommée une par une, et
-- toute entrée hors liste est « une exposition non décidée ». Le garde-fou a
-- fait exactement son travail — c'est la raison pour laquelle il existe.
--
-- Une fonction de trigger n'a besoin d'EXECUTE pour PERSONNE : c'est l'exécuteur
-- qui l'appelle quand le trigger se déclenche, pas un appelant qui la nomme. Le
-- privilège n'est vérifié qu'à la création du trigger. Les autres fonctions de
-- trigger de la base le confirment (tg_libraries_log_cross_library_action, elle
-- aussi SECURITY DEFINER, est à anon=false/authenticated=false et se déclenche
-- sans difficulté sur chaque UPDATE de `libraries`).
--
-- On ne l'inscrit donc PAS dans la liste nommée du T10 : elle n'a rien à y
-- faire. On lui retire ce qu'elle n'aurait jamais dû recevoir.
-- =========================================================================

BEGIN;

REVOKE EXECUTE ON FUNCTION public.fn_library_ensure_mail_channel() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_library_ensure_mail_channel() FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_library_ensure_mail_channel() FROM authenticated;

-- -------------------------------------------------------------------------
-- Vérification (doctrine) : structurelle, donc valable aussi en CI.
-- -------------------------------------------------------------------------
DO $$
BEGIN
  IF has_function_privilege('anon', 'public.fn_library_ensure_mail_channel()', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_library_ensure_mail_channel reste ouverte a anon';
  END IF;
  IF has_function_privilege('authenticated', 'public.fn_library_ensure_mail_channel()', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_library_ensure_mail_channel reste ouverte a authenticated';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE c.relname = 'libraries'
      AND t.tgname = 'trg_library_ensure_mail_channel'
      AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION 'trg_library_ensure_mail_channel absent : le REVOKE ne doit pas le retirer';
  END IF;
END $$;

COMMIT;
