-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — B42, lot 3 (13/10/2026) : Storage exige la double authentification
-- comme PostgREST. LIVRÉE SANS EFFET tant que le mode reste 'off'.
--
-- La fonction d'avant-requête de PostgREST (private.fn_avant_requete,
-- migration 20261013171710) ne couvre pas Storage : le service Storage évalue
-- les politiques RLS de storage.objects avec le jeton de l'appelant, sans
-- passer par PostgREST. Une session aal1 d'un compte d'équipe lirait encore
-- les buckets restreints (pdf-restrito, anarbib-media-restricted,
-- library-regimentos-private…) par l'API Storage directe.
--
-- UNE POLITIQUE RESTRICTIVE, et une seule. Les 47 politiques de storage.objects
-- (toutes PERMISSIVES, posées hors dépôt) disent qui peut quoi ; une politique
-- RESTRICTIVE s'ajoute à TOUTES par un ET, pour toutes les commandes, sans en
-- élargir aucune. Elle ne vise que `authenticated` : la lecture publique
-- (anon, /object/public, URL signées) n'en est pas touchée.
--
-- La règle reste écrite à un seul endroit : private.fn_aal2_exige_pour_moi
-- (mode off / facteurs / equipes de private.double_facteur_reglage). En 'off',
-- l'aide rend toujours vrai : la politique ne change rien.
--
-- Échec ouvert, comme la fonction d'avant-requête : une erreur imprévue de
-- l'aide laisserait sinon tout Storage refuser tout le monde.
--
-- Pose par migration vérifiée le 13/10 en production : `postgres` crée une
-- politique sur storage.objects (essai dans une transaction annulée), bien
-- qu'il n'en soit pas propriétaire. Il ne peut pas, en revanche, la commenter
-- sur une image auto-hébergée (voir plus bas) : ce fichier ne le fait plus.
-- Suite : tests/sql/b42_double_authentification_tests.sql (T11).
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION private.fn_session_double_facteur_ok()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
BEGIN
  IF coalesce(auth.jwt() ->> 'aal', '') = 'aal2' THEN RETURN true; END IF;
  RETURN NOT private.fn_aal2_exige_pour_moi();
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'B42 fn_session_double_facteur_ok, échec ouvert : % (%)', SQLERRM, SQLSTATE;
  RETURN true;
END $$;
REVOKE ALL ON FUNCTION private.fn_session_double_facteur_ok() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.fn_session_double_facteur_ok() TO authenticated, service_role;
COMMENT ON FUNCTION private.fn_session_double_facteur_ok() IS
  'B42 — vrai si la session est en aal2 ou si son compte n''a pas à l''être (private.fn_aal2_exige_pour_moi) ; échec ouvert. INVOKER, ouverte à authenticated : lue par la politique restrictive b42_double_authentification de storage.objects.';

DO $storage$
BEGIN
  IF to_regclass('storage.objects') IS NULL THEN
    RAISE NOTICE 'B42 : storage.objects absent, politique non posée';
    RETURN;
  END IF;
  DROP POLICY IF EXISTS b42_double_authentification ON storage.objects;
  -- (SELECT …) : évaluée une fois par requête (initplan), pas une fois par ligne.
  CREATE POLICY b42_double_authentification ON storage.objects
    AS RESTRICTIVE
    FOR ALL
    TO authenticated
    USING ((SELECT private.fn_session_double_facteur_ok()))
    WITH CHECK ((SELECT private.fn_session_double_facteur_ok()));
  -- Pas de COMMENT ON POLICY : sur une image Supabase auto-hébergée, postgres
  -- CRÉE une politique sur storage.objects mais ne la COMMENTE pas (« must be
  -- owner of relation objects », rejeu-image #1728 du 13/10). La production,
  -- où la première version de ce fichier est passée, porte ce commentaire :
  -- « B42 — RESTRICTIVE : une session aal1 dont le compte doit être en aal2 ne
  -- lit ni n'écrit rien dans Storage. Sans effet en mode off. »
END $storage$;
