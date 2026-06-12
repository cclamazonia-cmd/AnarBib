-- ════════════════════════════════════════════════════════════════════════════
-- CARD-LOCAL — Lot 1 (N1) : recherche painel par identité (UUID / e-mail / identité locale)
-- Auteur  : Xavier + Claude
-- Session : Identité lecteur·rice locale (CARD-LOCAL §27)
-- Date    : 2026-06-12 (UTC)
--
-- DÉCISION REGISTRE §27 CARD-LOCAL-1 : recherche painel par UUID / e-mail /
-- identité locale, scopée à la biblio courante, avec REPLI « toutes mes biblios »
-- si zéro résultat (biblio d'origine signalée). L'identité locale = acte staff,
-- ne gate PAS la circulation (CARD-LOCAL-GATE) ; l'unicité exclut removed/terminated
-- (CARD-LOCAL-6).
--
-- CHOIX D'IMPLÉMENTATION (non cassant) : on NE TOUCHE PAS à
-- `fn_painel_find_profile_by_lookup(text)` (toujours utilisée par le borrower
-- lookup du comptoir, PanelPage l.755, RETURNS profiles). On ajoute une fonction
-- DÉDIÉE au painel lecteur, `fn_painel_search_reader(p_lookup, p_library_id)`,
-- qui renvoie un jsonb { profile, matched_via, matched_library_id/name,
-- local_identity, is_fallback } → le front garde l'accès à plat à `profile` et
-- affiche une bannière « biblio d'origine » à partir de la meta.
--
-- DOCTRINE : SECURITY DEFINER + search_path + REVOKE PUBLIC + GRANT authenticated
-- + DO de vérification + NOTIFY pgrst. Gardée staff via
-- user_can_act_as_staff_on_library / can_manage_profile_from_my_libraries.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_painel_search_reader(
  p_lookup     text,
  p_library_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_lookup      text := trim(coalesce(p_lookup, ''));
  v_uid         text := upper(trim(coalesce(p_lookup, '')));
  v_email       text := lower(trim(coalesce(p_lookup, '')));
  v_uuid        uuid;
  v_user_id     uuid;
  v_row         public.profiles;
  v_matched_via text;
  v_matched_lib uuid;
  v_lib_name    text;
  v_local_ident text;
  v_is_fallback boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF v_lookup = '' THEN
    RAISE EXCEPTION 'lookup_empty';
  END IF;

  -- Tenter de parser un UUID brut (id du profil) ; sinon NULL.
  BEGIN
    v_uuid := v_lookup::uuid;
  EXCEPTION WHEN others THEN
    v_uuid := NULL;
  END;

  -- ════════ Phase 1 — recherche SCOPÉE à la biblio courante ════════
  -- (uniquement si le staff peut agir sur cette biblio)
  IF p_library_id IS NOT NULL AND public.user_can_act_as_staff_on_library(p_library_id) THEN
    -- a) par identité locale dans cette biblio (exclut removed/terminated)
    SELECT m.user_id, m.local_reader_number, 'local_identity'
      INTO v_user_id, v_local_ident, v_matched_via
    FROM public.user_library_memberships m
    WHERE m.library_id = p_library_id
      AND coalesce(m.status, '') NOT IN ('removed', 'terminated')
      AND upper(trim(coalesce(m.local_reader_number, ''))) = v_uid
    LIMIT 1;

    -- b) par UUID / public_id / e-mail, exigeant une appartenance à cette biblio
    IF v_user_id IS NULL THEN
      SELECT m.user_id, m.local_reader_number,
             CASE
               WHEN v_uuid IS NOT NULL AND p.id = v_uuid THEN 'uuid'
               WHEN upper(trim(coalesce(p.public_id, ''))) = v_uid THEN 'public_id'
               ELSE 'email'
             END
        INTO v_user_id, v_local_ident, v_matched_via
      FROM public.user_library_memberships m
      JOIN public.profiles p ON p.id = m.user_id
      WHERE m.library_id = p_library_id
        AND coalesce(m.status, '') NOT IN ('removed', 'terminated')
        AND (
          (v_uuid IS NOT NULL AND p.id = v_uuid)
          OR upper(trim(coalesce(p.public_id, ''))) = v_uid
          OR lower(trim(coalesce(p.email, ''))) = v_email
        )
      LIMIT 1;
    END IF;

    IF v_user_id IS NOT NULL THEN
      v_matched_lib := p_library_id;
      v_is_fallback := false;
    END IF;
  END IF;

  -- ════════ Phase 2 — repli « toutes mes biblios » ════════
  IF v_user_id IS NULL THEN
    -- par UUID / public_id / e-mail (indépendant de la biblio)
    SELECT p.id INTO v_user_id
    FROM public.profiles p
    WHERE (v_uuid IS NOT NULL AND p.id = v_uuid)
       OR upper(trim(coalesce(p.public_id, ''))) = v_uid
       OR lower(trim(coalesce(p.email, ''))) = v_email
    LIMIT 1;

    -- par identité locale dans une AUTRE de mes biblios
    IF v_user_id IS NULL THEN
      SELECT m.user_id INTO v_user_id
      FROM public.user_library_memberships m
      WHERE coalesce(m.status, '') NOT IN ('removed', 'terminated')
        AND upper(trim(coalesce(m.local_reader_number, ''))) = v_uid
        AND public.user_can_act_as_staff_on_library(m.library_id)
      LIMIT 1;
    END IF;

    -- introuvable → NULL (le front affiche « non trouvé »)
    IF v_user_id IS NULL THEN
      RETURN NULL;
    END IF;

    -- garde d'accès : le profil doit être gérable depuis mes biblios
    IF NOT public.can_manage_profile_from_my_libraries(v_user_id) THEN
      RAISE EXCEPTION 'profile_not_in_my_libraries';
    END IF;

    v_is_fallback := (p_library_id IS NOT NULL);

    -- biblio d'origine : une biblio gérable où ce profil est membre actif,
    -- en préférant la biblio courante puis la primaire puis la plus ancienne.
    SELECT m.library_id, m.local_reader_number
      INTO v_matched_lib, v_local_ident
    FROM public.user_library_memberships m
    WHERE m.user_id = v_user_id
      AND coalesce(m.status, '') NOT IN ('removed', 'terminated')
      AND public.user_can_act_as_staff_on_library(m.library_id)
    ORDER BY (m.library_id = p_library_id) DESC, m.is_primary DESC NULLS LAST, m.created_at ASC
    LIMIT 1;
  END IF;

  -- Charger la ligne profil complète + dériver matched_via si pas encore fixé
  SELECT * INTO v_row FROM public.profiles WHERE id = v_user_id;
  IF v_row.id IS NULL THEN
    RETURN NULL;
  END IF;

  IF v_matched_via IS NULL THEN
    v_matched_via := CASE
      WHEN v_uuid IS NOT NULL AND v_row.id = v_uuid THEN 'uuid'
      WHEN upper(trim(coalesce(v_row.public_id, ''))) = v_uid THEN 'public_id'
      WHEN lower(trim(coalesce(v_row.email, ''))) = v_email THEN 'email'
      ELSE 'local_identity'
    END;
  END IF;

  IF v_matched_lib IS NOT NULL THEN
    SELECT name INTO v_lib_name FROM public.libraries WHERE id = v_matched_lib;
  END IF;

  RETURN jsonb_build_object(
    'profile',              to_jsonb(v_row),
    'matched_via',          v_matched_via,
    'matched_library_id',   v_matched_lib,
    'matched_library_name', v_lib_name,
    'local_identity',       v_local_ident,
    'is_fallback',          v_is_fallback
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_painel_search_reader(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_painel_search_reader(text, uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_painel_search_reader(text, uuid) IS
  'CARD-LOCAL-1 : recherche painel par UUID / public_id / e-mail / identité locale, '
  'scopée à p_library_id puis repli toutes-mes-biblios (is_fallback + biblio d''origine). '
  'Gardée staff. Renvoie jsonb {profile, matched_via, matched_library_id/name, local_identity, is_fallback} '
  'ou NULL si introuvable. Créée par CARD-LOCAL Lot 1 du 12/06/2026.';

-- -------------------------------------------------------------------------
-- Vérification automatique (permissions de la nouvelle fonction)
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_has_public boolean;
  v_has_auth   boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_painel_search_reader'
  ) INTO v_has_public;
  IF NOT v_has_public THEN
    RAISE EXCEPTION 'Vérification échouée : fn_painel_search_reader absente après création.';
  END IF;

  -- EXECUTE ne doit PAS être ouvert à PUBLIC, mais accordé à authenticated.
  SELECT has_function_privilege('public', 'public.fn_painel_search_reader(text, uuid)', 'EXECUTE')
    INTO v_has_public;
  SELECT has_function_privilege('authenticated', 'public.fn_painel_search_reader(text, uuid)', 'EXECUTE')
    INTO v_has_auth;
  IF v_has_public THEN
    RAISE EXCEPTION 'Vérification échouée : EXECUTE encore ouvert à PUBLIC sur fn_painel_search_reader.';
  END IF;
  IF NOT v_has_auth THEN
    RAISE EXCEPTION 'Vérification échouée : authenticated ne peut pas EXECUTE fn_painel_search_reader.';
  END IF;

  RAISE NOTICE 'CARD-LOCAL Lot 1 : fn_painel_search_reader créée, grants OK.';
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════════════════
-- Rollback ciblé :
--   BEGIN;
--     DROP FUNCTION IF EXISTS public.fn_painel_search_reader(text, uuid);
--   COMMIT;
-- ════════════════════════════════════════════════════════════════════════════
