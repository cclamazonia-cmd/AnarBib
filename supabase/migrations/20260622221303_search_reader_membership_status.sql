-- =========================================================================
-- fn_painel_search_reader : exposer le statut de l'appartenance correspondante
-- =========================================================================
-- Date     : 2026-06-22
-- Chantier : validation des inscriptions (BLMF) — Suite 7
-- Auteur   : Claude (livré en fichier, appliqué par Forgejo / supabase db push)
--
-- Contexte : « Gerir leitor » trouve aussi les inscriptions en attente
-- (le filtre n'excluait que removed/terminated), et le front affichait toute la
-- gestion (édition, restriction, gel, identité) sur un·e candidat·e non validé·e.
-- On ajoute le `membership_status` de l'appartenance correspondante au retour,
-- pour que le front bascule en LECTURE SEULE + renvoi vers Validações quand
-- 'pending_validation'. Ajout purement additif (les 2 consommateurs front lisent
-- res.profile/… et ignorent les champs supplémentaires).
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_painel_search_reader(p_lookup text, p_library_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
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
  v_membership_status text;   -- Suite 7
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
    -- Suite 7 : statut de l'appartenance correspondante (le front passe en lecture
    -- seule + renvoi Validações si 'pending_validation').
    SELECT m.status INTO v_membership_status
    FROM public.user_library_memberships m
    WHERE m.user_id = v_user_id AND m.library_id = v_matched_lib
      AND coalesce(m.status, '') NOT IN ('removed', 'terminated')
    ORDER BY m.is_primary DESC NULLS LAST, m.created_at ASC
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'profile',              to_jsonb(v_row),
    'matched_via',          v_matched_via,
    'matched_library_id',   v_matched_lib,
    'matched_library_name', v_lib_name,
    'local_identity',       v_local_ident,
    'membership_status',    v_membership_status,
    'is_fallback',          v_is_fallback
  );
END;
$function$;

NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
  RAISE NOTICE 'fn_painel_search_reader : membership_status exposé. OK.';
END $$;

COMMIT;
