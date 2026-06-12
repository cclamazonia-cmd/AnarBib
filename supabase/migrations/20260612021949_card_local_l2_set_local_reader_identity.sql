-- ════════════════════════════════════════════════════════════════════════════
-- CARD-LOCAL — Lot 2 (N2) : attribution / édition de l'identité locale (acte staff)
-- Auteur  : Xavier + Claude
-- Session : Identité lecteur·rice locale (CARD-LOCAL §27)
-- Date    : 2026-06-12 (UTC)
--
-- DÉCISIONS REGISTRE §27 :
--   • CARD-LOCAL-STAFF : l'identité est TOUJOURS un acte staff.
--   • CARD-LOCAL-GATE  : l'identité ne gate PAS la circulation → on peut
--     l'attribuer même sur une appartenance pending_validation. On ne touche
--     donc NI au statut NI à la validation.
--   • CARD-LOCAL-UNIQ  : l'unicité conditionnelle est portée par le trigger
--     fn_enforce_local_reader_identity_uniqueness (Lot 0). Collision = message
--     SANS divulguer le compte existant.
--
-- DEUX OBJETS :
--   1) CREATE OR REPLACE du trigger d'unicité : on remplace le HINT brut
--      'reader_identity_already_taken' (qui, couplé à ERRCODE unique_violation,
--      était classé « erreur système » par src/lib/localizeError.js → message
--      masqué) par un HINT i18n 'error.cardLocal.identityTaken' (préfixe
--      'error.' → Cas 1 de localizeError, traduit dans les 10 locales). Corps
--      strictement identique au Lot 0 par ailleurs.
--   2) api.set_local_reader_identity(p_user_id, p_library_id, p_value) : RPC
--      staff qui écrit ulm.local_reader_number (le trigger gère l'unicité).
--
-- DOCTRINE : SECURITY DEFINER + search_path + REVOKE PUBLIC + GRANT authenticated
-- + DO de vérif + NOTIFY pgrst.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) Trigger d'unicité : HINT i18n routable par localizeError (Cas 1)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_enforce_local_reader_identity_uniqueness()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_model text;
BEGIN
  -- Pas d'identité, ou statut « mort » (départ définitif) : identité libre,
  -- rien à vérifier (CARD-LOCAL-6).
  IF NEW.local_reader_number IS NULL
     OR NEW.status IN ('removed', 'terminated') THEN
    RETURN NEW;
  END IF;

  -- Modèle d'identité de la biblio : l'unicité ne s'applique qu'aux modèles
  -- NUMÉRIQUES ; levée en mode 'name' (homonymes) et 'none' (CARD-LOCAL-UNIQ).
  SELECT l.reader_identity_model INTO v_model
    FROM public.libraries l
   WHERE l.id = NEW.library_id;

  IF v_model IS DISTINCT FROM 'free_number'
     AND v_model IS DISTINCT FROM 'sequenced_number' THEN
    RETURN NEW;
  END IF;

  -- Collision : même identité, même biblio, sur une appartenance VIVANTE,
  -- autre que la ligne courante.
  IF EXISTS (
    SELECT 1
      FROM public.user_library_memberships m
     WHERE m.library_id = NEW.library_id
       AND m.local_reader_number = NEW.local_reader_number
       AND m.status NOT IN ('removed', 'terminated')
       AND m.id <> NEW.id
  ) THEN
    -- HINT i18n (préfixe 'error.') → traduit côté front sans divulguer le compte.
    RAISE EXCEPTION 'Identité lecteur·rice déjà attribuée dans cette bibliothèque'
      USING ERRCODE = 'unique_violation',
            HINT    = 'error.cardLocal.identityTaken';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_enforce_local_reader_identity_uniqueness()
  FROM PUBLIC, anon, authenticated, service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) api.set_local_reader_identity — attribution / édition staff
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.set_local_reader_identity(
  p_user_id    uuid,
  p_library_id uuid,
  p_value      text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_value  text := nullif(btrim(coalesce(p_value, '')), '');
  v_mid    uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  -- Garde staff (librarian / coordenador / admin) sur CETTE biblio.
  IF NOT public.user_can_act_as_staff_on_library(p_library_id) THEN
    RAISE EXCEPTION 'Acesso de equipe obrigatório nesta biblioteca.'
      USING ERRCODE = 'P0001', HINT = 'error.staff_required';
  END IF;

  -- L'appartenance doit exister et être vivante (≠ removed/terminated). On
  -- N'EXIGE PAS qu'elle soit active : l'identité peut être posée avant
  -- validation (CARD-LOCAL-GATE).
  SELECT m.id INTO v_mid
    FROM public.user_library_memberships m
   WHERE m.user_id = p_user_id
     AND m.library_id = p_library_id
     AND coalesce(m.status, '') NOT IN ('removed', 'terminated')
   ORDER BY (m.status = 'active') DESC, m.created_at DESC
   LIMIT 1;

  IF v_mid IS NULL THEN
    RAISE EXCEPTION 'Pessoa não inscrita nesta biblioteca.'
      USING ERRCODE = 'P0001', HINT = 'error.cardLocal.noMembership';
  END IF;

  -- Écriture : le trigger fn_enforce_local_reader_identity_uniqueness valide
  -- l'unicité conditionnelle (→ HINT error.cardLocal.identityTaken en collision).
  UPDATE public.user_library_memberships
     SET local_reader_number = v_value,
         updated_at = now()
   WHERE id = v_mid;

  RETURN v_value;
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.set_local_reader_identity(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.set_local_reader_identity(uuid, uuid, text) TO authenticated;

COMMENT ON FUNCTION api.set_local_reader_identity(uuid, uuid, text) IS
  'CARD-LOCAL-2/N2 : attribution/édition de l''identité locale (ulm.local_reader_number) '
  'd''une lectrice dans une biblio. Acte staff (CARD-LOCAL-STAFF), indépendant de la '
  'validation (CARD-LOCAL-GATE). Unicité déléguée au trigger. p_value vide = effacement. '
  'Créée par CARD-LOCAL Lot 2 du 12/06/2026.';

-- ─────────────────────────────────────────────────────────────────────────────
-- Vérification automatique
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_ok boolean;
BEGIN
  -- la RPC existe et est exécutable par authenticated, pas par PUBLIC
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'api' AND p.proname = 'set_local_reader_identity'
  ) THEN
    RAISE EXCEPTION 'Vérification échouée : api.set_local_reader_identity absente.';
  END IF;

  SELECT has_function_privilege('public', 'api.set_local_reader_identity(uuid, uuid, text)', 'EXECUTE') INTO v_ok;
  IF v_ok THEN
    RAISE EXCEPTION 'Vérification échouée : EXECUTE encore ouvert à PUBLIC sur api.set_local_reader_identity.';
  END IF;

  SELECT has_function_privilege('authenticated', 'api.set_local_reader_identity(uuid, uuid, text)', 'EXECUTE') INTO v_ok;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'Vérification échouée : authenticated ne peut pas EXECUTE api.set_local_reader_identity.';
  END IF;

  RAISE NOTICE 'CARD-LOCAL Lot 2 : trigger HINT i18n + api.set_local_reader_identity OK.';
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════════════════
-- Rollback ciblé :
--   BEGIN;
--     DROP FUNCTION IF EXISTS api.set_local_reader_identity(uuid, uuid, text);
--     -- (le trigger peut être laissé : le HINT i18n est rétro-compatible)
--   COMMIT;
-- ════════════════════════════════════════════════════════════════════════════
