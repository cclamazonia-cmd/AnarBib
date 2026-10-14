-- =========================================================================
-- Chaque bibliothèque dit ses numéros d'inventaire dans la ligne des exemplaires
-- =========================================================================
-- Date     : 2026-10-14
-- Chantier : OPAC par œuvre, ligne « exemplaires par bibliothèque » (relevé de Xavier)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : Catalogue — numéros d'inventaire par bibliothèque
-- Ref      : 20260904150000 (définition précédente de la fonction)
--
-- LE CONSTAT (14/10/2026).
--   Dans le catalogue, le « + » d'une édition (ex. « Proudhon — textos
--   escolhidos », book_id 1841) liste ses exemplaires bibliothèque par
--   bibliothèque. Chaque ligne affichait local_bib_ref, la référence de la
--   NOTICE : BTL et MLEG montraient toutes deux BTL-TL-001961, alors que la
--   fiche livre distingue bien BTL-TL-EX-001961 (BTL) et MLEG-2026-0224 (MLEG).
--
-- LE GESTE.
--   api.book_copies_by_library_v1 transmet en plus `tombos`, les numéros
--   d'inventaire de la bibliothèque, lus dans holding_libraries_json->tombos_json
--   de public.v_book_detail_public_v2 (même vue, même ligne). Rien d'autre ne
--   change : la fonction reste INVOKER, et ces numéros sont déjà publics (la
--   fiche livre les affiche, la vue les expose à l'anon) — la doctrine A1/A2/A3
--   (disponibilité masquée à l'anon) n'est pas touchée.
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION api.book_copies_by_library_v1(p_book_id bigint)
RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path = public, pg_catalog
AS $fn$
DECLARE
  v_auth boolean := (auth.uid() IS NOT NULL);
  v_slug text; v_hint text; v_avail integer;
  v_out jsonb;
BEGIN
  IF v_auth THEN
    -- Branche jamais atteinte par l'anon : la vue de session n'est verifiee que pour une lectrice.
    SELECT c.session_library_slug, c.session_status_hint, c.session_available_count
      INTO v_slug, v_hint, v_avail
      FROM api.catalog_list_session_v1 c
     WHERE c.book_id = p_book_id
     LIMIT 1;
  END IF;

  SELECT jsonb_build_object(
    'book_id', p_book_id,
    'is_auth', v_auth,
    'libraries', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'library_slug',     h->>'library_slug',
               'short_name',       h->>'short_name',
               'library_name',     h->>'library_name',
               'city',             h->>'city',
               'local_bib_ref',    h->>'local_bib_ref',
               -- Numéros d'inventaire de CETTE bibliothèque (public, comme sur la fiche).
               'tombos',           CASE WHEN jsonb_typeof(h->'tombos_json') = 'array' THEN h->'tombos_json' ELSE '[]'::jsonb END,
               'exemplares_total', (h->>'exemplares_total')::int,
               -- Doctrine A1/A2/A3 : rien de plus pour un visiteur non connecte.
               'available_count',  CASE WHEN v_auth THEN (h->>'available_count')::int END,
               'loanable',         CASE WHEN v_auth THEN (h->>'loanable')::boolean END,
               'earliest_due_back_at', CASE WHEN v_auth THEN h->'earliest_due_back_at' END,
               'is_session_library', (v_slug IS NOT NULL AND v_slug = (h->>'library_slug')),
               'session_status_hint', CASE WHEN v_slug = (h->>'library_slug') THEN v_hint END,
               'session_available_count', CASE WHEN v_slug = (h->>'library_slug') THEN v_avail END)
             ORDER BY h->>'library_name')
      FROM public.v_book_detail_public_v2 d
      CROSS JOIN LATERAL jsonb_array_elements(
        CASE WHEN jsonb_typeof(d.holding_libraries_json) = 'array' THEN d.holding_libraries_json ELSE '[]'::jsonb END) h
      WHERE d.book_id = p_book_id), '[]'::jsonb))
  INTO v_out;
  RETURN v_out;
END;
$fn$;
GRANT EXECUTE ON FUNCTION api.book_copies_by_library_v1(bigint) TO anon, authenticated;

DO $$
BEGIN
  IF NOT has_function_privilege('anon', 'api.book_copies_by_library_v1(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou : book_copies_by_library_v1 doit rester publique (OPAC)';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;
