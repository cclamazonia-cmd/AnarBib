-- ════════════════════════════════════════════════════════════════════════════
-- CARD-LOCAL — Lot 3 (N5) : « dernier identifiant attribué » (hint dérivé, coord)
-- Auteur  : Xavier + Claude
-- Session : Identité lecteur·rice locale (CARD-LOCAL §27)
-- Date    : 2026-06-12 (UTC)
--
-- DÉCISION REGISTRE §27 CARD-LOCAL-2 : le « dernier identifiant attribué »
-- (hint d'aide à l'ouverture de la config) est DÉRIVÉ en RPC coordenador —
-- PAS de colonne cache (libraries est anon-lisible : un cache fuiterait ~le
-- compteur de lecteur·rices et risquerait d'être obsolète). Guide NON bloquant.
--
-- Les colonnes de config elles-mêmes (libraries.reader_identity_model /
-- reader_validation_mode) sont écrites par l'onglet « identité » de
-- BibliotecaPage via l'UPDATE direct existant (RLS coordenador + CHECK enum),
-- exactement comme reader_cards_enabled — pas besoin de RPC d'écriture dédiée.
--
-- DOCTRINE : SECURITY DEFINER + search_path + REVOKE PUBLIC + GRANT authenticated
-- + NOTIFY pgrst. Gardée coordenador (user_can_manage_library).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION api.get_last_assigned_reader_identity(
  p_library_id uuid
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_last text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  -- Coordenador/admin de la biblio uniquement (écran de config).
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'Acesso de coordenação obrigatório nesta biblioteca.'
      USING ERRCODE = 'P0001', HINT = 'error.coord_required';
  END IF;

  -- Dérivation : plus grand identifiant NUMÉRIQUE attribué à une appartenance
  -- vivante (≠ removed/terminated). Les identités non numériques (modèle 'name')
  -- sont ignorées par le filtre regex. NULL si aucun identifiant numérique.
  SELECT max(m.local_reader_number::bigint)::text
    INTO v_last
    FROM public.user_library_memberships m
   WHERE m.library_id = p_library_id
     AND coalesce(m.status, '') NOT IN ('removed', 'terminated')
     AND m.local_reader_number ~ '^[0-9]+$';

  RETURN v_last;
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.get_last_assigned_reader_identity(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.get_last_assigned_reader_identity(uuid) TO authenticated;

COMMENT ON FUNCTION api.get_last_assigned_reader_identity(uuid) IS
  'CARD-LOCAL-2/N5 : dérive le dernier identifiant NUMÉRIQUE attribué (hint config), '
  'pas de cache (libraries anon-lisible). Gardée coordenador. Créée par CARD-LOCAL Lot 3 du 12/06/2026.';

DO $$
DECLARE v_ok boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'api' AND p.proname = 'get_last_assigned_reader_identity'
  ) THEN
    RAISE EXCEPTION 'Vérification échouée : api.get_last_assigned_reader_identity absente.';
  END IF;
  SELECT has_function_privilege('public', 'api.get_last_assigned_reader_identity(uuid)', 'EXECUTE') INTO v_ok;
  IF v_ok THEN
    RAISE EXCEPTION 'Vérification échouée : EXECUTE encore ouvert à PUBLIC.';
  END IF;
  RAISE NOTICE 'CARD-LOCAL Lot 3 : api.get_last_assigned_reader_identity OK.';
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════════════════
-- Rollback : DROP FUNCTION IF EXISTS api.get_last_assigned_reader_identity(uuid);
-- ════════════════════════════════════════════════════════════════════════════
