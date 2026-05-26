-- ============================================================================
-- Migration : EA-05 Paquet 2b — harmonisation message d'erreur
--             api.fn_clear_my_signup_metadata_field
-- Chantier  : A — Lisibilite immediate (audit Painel)
-- ============================================================================
--
-- OBJET
-- -----
-- Derniere fonction de la famille C (RAISE a phrase libre). Traitee a part de
-- la migration 2a car c'est la SEULE fonction SECURITY DEFINER du lot : son
-- bloc de permissions doit etre repose explicitement.
--
-- Le RAISE 'Non authentifie' (phrase, sans ERRCODE) devient le code
-- 'auth_required' — code deja utilise partout ailleurs dans le schema api.
-- L'ERRCODE '28000' (invalid_authorization_specification) est ajoute pour
-- homogeneite avec les autres auth_required du schema (decision 26/05/2026).
-- La phrase d'origine est conservee en HINT (diagnostic console).
--
-- PERIMETRE STRICT
-- ----------------
-- SEULE la ligne RAISE est modifiee. Le corps de la fonction (le bloc UPDATE
-- public.profiles), la signature, le LANGUAGE, le SET search_path, le OWNER :
-- inchanges, recopies a l'identique du dump.
--
-- DOCTRINE — permissions (creation objets securises §5.2 et §5.3)
-- ---------------------------------------------------------------
-- fn_clear_my_signup_metadata_field est SECURITY DEFINER ET appelee par le
-- frontend (nettoyage des metadonnees de signup de l'usager authentifie).
-- C'est donc une fonction EXPOSEE, pas un helper interne :
--   - REVOKE EXECUTE etendu sur les 4 roles (forme §5.2, contre le piege
--     ALTER DEFAULT PRIVILEGES) ;
--   - puis GRANT EXECUTE explicite a authenticated et service_role — les deux
--     roles que le dump d'origine accordait (passage de GRANT ALL a
--     GRANT EXECUTE, plus precis).
-- REVOKE volontairement sur UNE seule ligne (le hook pre-commit attend
-- 'REVOKE EXECUTE ... FROM PUBLIC' sans saut de ligne intermediaire).
--
-- Migration appliquee par Woodpecker (supabase db push --linked).
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Fonction corrigee (corps identique au dump, seul le RAISE change)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."fn_clear_my_signup_metadata_field"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'api', 'auth', 'pg_temp'
    AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Non authentifie';
  END IF;
  UPDATE public.profiles
     SET signup_intent_metadata =
           signup_intent_metadata - 'library_name_mentioned'
   WHERE id = auth.uid();
END;
$$;

ALTER FUNCTION "api"."fn_clear_my_signup_metadata_field"() OWNER TO "postgres";

-- Permissions (doctrine §5.2 forme etendue + §5.3 fonction exposee au frontend).
REVOKE EXECUTE ON FUNCTION "api"."fn_clear_my_signup_metadata_field"() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION "api"."fn_clear_my_signup_metadata_field"() TO authenticated;
GRANT EXECUTE ON FUNCTION "api"."fn_clear_my_signup_metadata_field"() TO service_role;

-- ----------------------------------------------------------------------------
-- Verification statique en fin de transaction (rollback automatique si echec)
-- ----------------------------------------------------------------------------
-- Interroge pg_proc / pg_get_functiondef() — meme methode que la migration 2a
-- (recherche par nom, insensible a la signature). Confirme que la fonction
-- contient bien le code auth_required et plus la phrase 'Non authentifie'
-- en position de message de RAISE.
DO $verif$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid)
    INTO v_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api'
     AND p.proname = 'fn_clear_my_signup_metadata_field';

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'Verification echouee : fonction api.fn_clear_my_signup_metadata_field introuvable';
  END IF;

  IF position('auth_required' IN v_def) = 0 THEN
    RAISE EXCEPTION 'Verification echouee : le code auth_required est absent de la definition';
  END IF;

  IF position('RAISE EXCEPTION ''Non authentifie' IN v_def) > 0 THEN
    RAISE EXCEPTION 'Verification echouee : la phrase Non authentifie subsiste en message de RAISE';
  END IF;

  RAISE NOTICE 'Verification OK : api.fn_clear_my_signup_metadata_field harmonisee.';
END;
$verif$;

COMMIT;
