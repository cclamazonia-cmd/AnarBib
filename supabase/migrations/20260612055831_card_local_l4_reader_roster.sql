-- ════════════════════════════════════════════════════════════════════════════
-- CARD-LOCAL — Lot 4 (N3) : roster lecteur·rice (agrégat coordenador, export PDF/CSV)
-- Auteur  : Xavier + Claude
-- Session : Identité lecteur·rice locale (CARD-LOCAL §27)
-- Date    : 2026-06-12 (UTC)
--
-- DÉCISION REGISTRE §27 CARD-LOCAL-N3 : roster dans l'écran biblio, COORDENADOR
-- uniquement. Colonnes : NOM, prénom, inscrit·e depuis, e-mail, UUID, identité,
-- statut, legacy/AnarBib (imported_from_legacy). Export PDF tableau = livrable
-- principal ; CSV en option (côté front). Scopé RLS coordenador.
--
-- Cette RPC est l'agrégat de données ; les emprunts/résa/consultations/cotisation
-- « optionnels » (CARD-LOCAL-N3) ne sont PAS inclus dans cette première version
-- (livrable cœur = identité/statut/origine), à ajouter ultérieurement si besoin.
--
-- DOCTRINE : SECURITY DEFINER + search_path + REVOKE PUBLIC + GRANT authenticated
-- + NOTIFY pgrst. Gardée coordenador (user_can_manage_library).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION api.get_reader_roster(
  p_library_id uuid
)
RETURNS TABLE (
  user_id              uuid,
  last_name            text,
  first_name           text,
  email                text,
  local_identity       text,
  status               text,
  imported_from_legacy boolean,
  registered_since     timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  -- Coordenador/admin de la biblio uniquement (RLS coordenador, CARD-LOCAL-N3).
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'Acesso de coordenação obrigatório nesta biblioteca.'
      USING ERRCODE = 'P0001', HINT = 'error.coord_required';
  END IF;

  RETURN QUERY
    SELECT
      m.user_id,
      p.last_name,
      p.first_name,
      p.email,
      m.local_reader_number             AS local_identity,
      m.status,
      coalesce(m.imported_from_legacy, false) AS imported_from_legacy,
      m.created_at                      AS registered_since
    FROM public.user_library_memberships m
    JOIN public.profiles p ON p.id = m.user_id
   WHERE m.library_id = p_library_id
     AND m.role = 'reader'
     AND coalesce(m.status, '') NOT IN ('removed', 'terminated')
   ORDER BY lower(coalesce(p.last_name, '')), lower(coalesce(p.first_name, '')), p.email;
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.get_reader_roster(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.get_reader_roster(uuid) TO authenticated;

COMMENT ON FUNCTION api.get_reader_roster(uuid) IS
  'CARD-LOCAL-N3 : roster lecteur·rice d''une biblio (NOM, prénom, e-mail, UUID, '
  'identité locale, statut, legacy/AnarBib, inscrit depuis). Gardée coordenador. '
  'Exclut removed/terminated. Créée par CARD-LOCAL Lot 4 du 12/06/2026.';

DO $$
DECLARE v_ok boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'api' AND p.proname = 'get_reader_roster'
  ) THEN
    RAISE EXCEPTION 'Vérification échouée : api.get_reader_roster absente.';
  END IF;
  SELECT has_function_privilege('public', 'api.get_reader_roster(uuid)', 'EXECUTE') INTO v_ok;
  IF v_ok THEN
    RAISE EXCEPTION 'Vérification échouée : EXECUTE encore ouvert à PUBLIC sur api.get_reader_roster.';
  END IF;
  RAISE NOTICE 'CARD-LOCAL Lot 4 : api.get_reader_roster OK.';
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════════════════
-- Rollback : DROP FUNCTION IF EXISTS api.get_reader_roster(uuid);
-- ════════════════════════════════════════════════════════════════════════════
