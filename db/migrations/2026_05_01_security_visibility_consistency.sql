-- ============================================================================
-- Migration : Sécurité & cohérence visibility - sémantique A étendue
-- Date      : 2026-05-01
-- Auteur    : Xavier
-- Contexte  : Item rouge #1 du backlog (sécurité résiduelle BookPage).
--             Audit RLS complet ayant révélé plusieurs fuites :
--             - exemplares en qual=true (2461 lignes lisibles par anon)
--             - book_authors et authors en qual=true
--             - book_digital_resources et digital_assets sans filtre biblio
--             - library_document_governance en qual=true
--             - libraries_authenticated_read avec branche network buggée
--               (manquait ulm.library_id check, mais sémantique voulue = A)
--             - library_commons sans policy
--             - catalog_ref_* sans policy
--             - GRANTs DELETE/INSERT/UPDATE inertes sur 7 vues anon
-- Sémantique:
--   public  = visible à tous (anon inclus)
--   network = visible à tout user authentifié avec >=1 membership actif quelque part
--   private = visible uniquement aux membres actifs de la biblio en question
-- Tests post-migration : voir commentaires en fin de fichier.
-- ============================================================================

-- ============================================================================
-- BLOC 1 : HELPERS DE VISIBILITY (sémantique A étendue)
-- ============================================================================

BEGIN;

-- 1.1 - User a-t-il >=1 membership actif quelque part ?
CREATE OR REPLACE FUNCTION public.fn_current_user_is_in_network()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships ulm
    WHERE ulm.user_id = auth.uid()
      AND ulm.status = 'active'
  );
$$;

COMMENT ON FUNCTION public.fn_current_user_is_in_network() IS
  'Semantique A : true si auth.uid() a >=1 membership actif. Determine acces aux ressources visibility=network.';

GRANT EXECUTE ON FUNCTION public.fn_current_user_is_in_network() TO anon, authenticated;


-- 1.2 - User est-il membre actif d'une biblio donnée ?
CREATE OR REPLACE FUNCTION public.fn_current_user_is_member_of(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships ulm
    WHERE ulm.user_id = auth.uid()
      AND ulm.library_id = p_library_id
      AND ulm.status = 'active'
  );
$$;

COMMENT ON FUNCTION public.fn_current_user_is_member_of(uuid) IS
  'true si auth.uid() est membre actif de la biblio donnee. Determine acces aux ressources visibility=private.';

GRANT EXECUTE ON FUNCTION public.fn_current_user_is_member_of(uuid) TO anon, authenticated;


-- 1.3 - Helper composite : la biblio est-elle visible pour l'appelant ?
CREATE OR REPLACE FUNCTION public.fn_library_visible_to_caller(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.libraries l
    WHERE l.id = p_library_id
      AND l.is_active = true
      AND (
        l.visibility_level = 'public'
        OR (
          l.visibility_level = 'network'
          AND auth.uid() IS NOT NULL
          AND public.fn_current_user_is_in_network()
        )
        OR (
          l.visibility_level = 'private'
          AND auth.uid() IS NOT NULL
          AND public.fn_current_user_is_member_of(p_library_id)
        )
      )
  );
$$;

COMMENT ON FUNCTION public.fn_library_visible_to_caller(uuid) IS
  'Semantique A complete : public=tous, network=membres reseau, private=membres biblio. Helper unifie pour RLS et frontend.';

GRANT EXECUTE ON FUNCTION public.fn_library_visible_to_caller(uuid) TO anon, authenticated;

COMMIT;


-- ============================================================================
-- BLOC 2 : RLS FIXES - fuites P1 (anon) + cohérence P2 (network/private)
-- ============================================================================

BEGIN;

-- 2.1 - exemplares (fuite confirmee : 2461 lignes lisibles par anon)
DROP POLICY IF EXISTS exemplares_public_read ON public.exemplares;

CREATE POLICY exemplares_public_read
ON public.exemplares
FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.book_holdings h
    WHERE h.id = exemplares.holding_id
      AND public.fn_library_visible_to_caller(h.library_id)
  )
);

-- 2.2 - book_authors (cascade via livres visibles)
DROP POLICY IF EXISTS book_authors_public_read ON public.book_authors;

CREATE POLICY book_authors_public_read
ON public.book_authors
FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.book_holdings h
    WHERE h.book_id = book_authors.book_id
      AND public.fn_library_visible_to_caller(h.library_id)
  )
);

-- 2.3 - authors (filtre cascade : auteur visible si >=1 livre visible)
DROP POLICY IF EXISTS authors_anon_select ON public.authors;
DROP POLICY IF EXISTS authors_authenticated_select ON public.authors;

CREATE POLICY authors_public_read
ON public.authors
FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.book_authors ba
    JOIN public.book_holdings h ON h.book_id = ba.book_id
    WHERE ba.author_id = authors.id
      AND public.fn_library_visible_to_caller(h.library_id)
  )
);

-- 2.4 - book_digital_resources (filtre biblio + scope existant)
DROP POLICY IF EXISTS book_digital_resources_public_read ON public.book_digital_resources;

CREATE POLICY book_digital_resources_public_read
ON public.book_digital_resources
FOR SELECT
TO anon, authenticated
USING (
  is_active = true
  AND status = 'active'
  AND access_scope = 'publico'
  AND storage_bucket = 'anarbib-pdf-public'
  AND EXISTS (
    SELECT 1
    FROM public.book_holdings h
    WHERE h.book_id = book_digital_resources.book_id
      AND public.fn_library_visible_to_caller(h.library_id)
  )
);

-- 2.5 - digital_assets (table parallele avec book_id)
DROP POLICY IF EXISTS digital_assets_public_read ON public.digital_assets;

CREATE POLICY digital_assets_public_read
ON public.digital_assets
FOR SELECT
TO anon, authenticated
USING (
  is_public = true
  AND bucket_name = 'anarbib-pdf-public'
  AND EXISTS (
    SELECT 1
    FROM public.book_holdings h
    WHERE h.book_id = digital_assets.book_id
      AND public.fn_library_visible_to_caller(h.library_id)
  )
);

-- 2.6 - library_document_governance (filtre par biblio)
DROP POLICY IF EXISTS library_document_governance_public_read ON public.library_document_governance;

CREATE POLICY library_document_governance_public_read
ON public.library_document_governance
FOR SELECT
TO anon, authenticated
USING (
  public.fn_library_visible_to_caller(library_id)
);

-- 2.7 - book_holdings (reecriture lisible via helper, equivalent fonctionnel)
DROP POLICY IF EXISTS book_holdings_public_read ON public.book_holdings;

CREATE POLICY book_holdings_public_read
ON public.book_holdings
FOR SELECT
TO anon, authenticated
USING (
  public.fn_library_visible_to_caller(library_id)
);

-- 2.8 - libraries (fusion anon+authenticated via helpers)
DROP POLICY IF EXISTS libraries_anon_read ON public.libraries;
DROP POLICY IF EXISTS libraries_authenticated_read ON public.libraries;

CREATE POLICY libraries_public_read
ON public.libraries
FOR SELECT
TO anon, authenticated
USING (
  is_active = true
  AND (
    visibility_level = 'public'
    OR (
      visibility_level = 'network'
      AND auth.uid() IS NOT NULL
      AND public.fn_current_user_is_in_network()
    )
    OR (
      visibility_level = 'private'
      AND auth.uid() IS NOT NULL
      AND public.fn_current_user_is_member_of(id)
    )
  )
);

-- 2.9 - Mise a jour des fonctions assets (coherence visibility cascade)

CREATE OR REPLACE FUNCTION public.get_accessible_digital_asset_by_id_v2(p_asset_id bigint)
RETURNS TABLE(asset_id bigint, book_id bigint, resource_type text, usage_type text, access_scope text, mime_type text, storage_bucket text, storage_path text, language_code text, source_name text, source_url text, attribution_text text, rights_status text, label text, is_primary boolean, requires_active_account boolean, access_granted boolean)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT
    r.id AS asset_id,
    r.book_id,
    r.resource_type,
    r.usage_type,
    r.access_scope,
    r.mime_type,
    r.storage_bucket,
    r.storage_path,
    r.language_code,
    r.source_name,
    r.source_url,
    r.attribution_text,
    r.rights_status,
    r.label,
    r.is_primary,
    (r.access_scope = 'conta_ativa') AS requires_active_account,
    CASE
      WHEN r.access_scope = 'publico' THEN true
      WHEN r.access_scope = 'conta_ativa' THEN public.fn_current_user_conta_ativa()
      ELSE false
    END AS access_granted
  FROM public.book_digital_resources r
  WHERE r.id = p_asset_id
    AND r.status = 'active'
    AND COALESCE(r.is_active, false) = true
    AND (
      r.access_scope = 'publico'
      OR (r.access_scope = 'conta_ativa' AND public.fn_current_user_conta_ativa())
    )
    AND EXISTS (
      SELECT 1
      FROM public.book_holdings h
      WHERE h.book_id = r.book_id
        AND public.fn_library_visible_to_caller(h.library_id)
    )
  LIMIT 1;
$function$;


CREATE OR REPLACE FUNCTION public.get_book_primary_accessible_digital_asset_v2(p_book_id bigint)
RETURNS TABLE(asset_id bigint, book_id bigint, resource_type text, usage_type text, access_scope text, mime_type text, storage_bucket text, storage_path text, language_code text, source_name text, source_url text, attribution_text text, rights_status text, label text, is_primary boolean, requires_active_account boolean, access_granted boolean)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  WITH ranked AS (
    SELECT
      r.id AS asset_id,
      r.book_id,
      r.resource_type,
      r.usage_type,
      r.access_scope,
      r.mime_type,
      r.storage_bucket,
      r.storage_path,
      r.language_code,
      r.source_name,
      r.source_url,
      r.attribution_text,
      r.rights_status,
      r.label,
      r.is_primary,
      (r.access_scope = 'conta_ativa') AS requires_active_account,
      CASE
        WHEN r.access_scope = 'publico' THEN true
        WHEN r.access_scope = 'conta_ativa' THEN public.fn_current_user_conta_ativa()
        ELSE false
      END AS access_granted,
      row_number() OVER (
        ORDER BY
          CASE WHEN r.access_scope = 'publico' THEN 0 ELSE 1 END,
          CASE WHEN COALESCE(r.is_primary, false) THEN 0 ELSE 1 END,
          r.updated_at DESC NULLS LAST,
          r.id DESC
      ) AS rn
    FROM public.book_digital_resources r
    WHERE r.book_id = p_book_id
      AND r.status = 'active'
      AND COALESCE(r.is_active, false) = true
      AND (
        r.access_scope = 'publico'
        OR (r.access_scope = 'conta_ativa' AND public.fn_current_user_conta_ativa())
      )
      AND EXISTS (
        SELECT 1
        FROM public.book_holdings h
        WHERE h.book_id = r.book_id
          AND public.fn_library_visible_to_caller(h.library_id)
      )
  )
  SELECT
    asset_id, book_id, resource_type, usage_type, access_scope, mime_type,
    storage_bucket, storage_path, language_code, source_name, source_url,
    attribution_text, rights_status, label, is_primary,
    requires_active_account, access_granted
  FROM ranked
  WHERE rn = 1;
$function$;

COMMIT;


-- ============================================================================
-- BLOC 3 : HYGIENE - REVOKE inertes + policies authenticated manquantes
-- ============================================================================

BEGIN;

-- 3.1 - REVOKE des GRANTs DELETE/INSERT/UPDATE/TRUNCATE inertes sur les vues

REVOKE ALL ON public.v_books_catalog_list_v1 FROM anon, authenticated;
GRANT SELECT ON public.v_books_catalog_list_v1 TO anon, authenticated;

REVOKE ALL ON public.v_catalog_queue FROM anon, authenticated;
GRANT SELECT ON public.v_catalog_queue TO anon, authenticated;

REVOKE ALL ON public.v_exemplar_drafts_resolved FROM anon, authenticated;
GRANT SELECT ON public.v_exemplar_drafts_resolved TO anon, authenticated;

REVOKE ALL ON public.v_exemplar_labels FROM anon, authenticated;
GRANT SELECT ON public.v_exemplar_labels TO anon, authenticated;

REVOKE ALL ON public.v_libraries_for_signup FROM anon, authenticated;
GRANT SELECT ON public.v_libraries_for_signup TO anon, authenticated;

REVOKE ALL ON public.authors_with_translations FROM anon, authenticated;
GRANT SELECT ON public.authors_with_translations TO anon, authenticated;

REVOKE ALL ON public.author_translations FROM anon, authenticated;
GRANT SELECT ON public.author_translations TO anon, authenticated;

REVOKE ALL ON public.catalog_partners FROM anon, authenticated;
REVOKE ALL ON public.catalog_partners_policy_flags FROM anon, authenticated;
REVOKE ALL ON public.catalog_partners_policy_flags_v2 FROM anon, authenticated;
REVOKE ALL ON public.partner_source_holdings FROM anon, authenticated;
REVOKE ALL ON public.partner_source_items FROM anon, authenticated;
REVOKE ALL ON public.partner_source_records FROM anon, authenticated;

-- 3.2 - Policy library_commons (backlog explicite : politique authenticated manquante)

DROP POLICY IF EXISTS library_commons_public_read ON public.library_commons;

CREATE POLICY library_commons_public_read
ON public.library_commons
FOR SELECT
TO anon, authenticated
USING (
  public.fn_library_visible_to_caller(library_id)
);

-- 3.3 - catalog_ref_* : ouverture en lecture (listes de reference pures)

CREATE POLICY catalog_ref_acquisition_modes_public_read
ON public.catalog_ref_acquisition_modes
FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY catalog_ref_confidence_levels_public_read
ON public.catalog_ref_confidence_levels
FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY catalog_ref_import_methods_public_read
ON public.catalog_ref_import_methods
FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY catalog_ref_mutualization_statuses_public_read
ON public.catalog_ref_mutualization_statuses
FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY catalog_ref_review_statuses_public_read
ON public.catalog_ref_review_statuses
FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY catalog_ref_source_formats_public_read
ON public.catalog_ref_source_formats
FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY catalog_ref_source_partners_public_read
ON public.catalog_ref_source_partners
FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY catalog_ref_source_systems_public_read
ON public.catalog_ref_source_systems
FOR SELECT TO anon, authenticated USING (true);

COMMIT;


-- ============================================================================
-- TESTS DE VALIDATION (a executer post-migration)
-- ============================================================================
--
-- Bloc 1 :
--   SELECT proname FROM pg_proc
--   WHERE proname IN ('fn_current_user_is_in_network',
--                     'fn_current_user_is_member_of',
--                     'fn_library_visible_to_caller');
--   -- Attendu : 3 lignes
--
-- Bloc 2 :
--   BEGIN; SET LOCAL ROLE anon;
--   SELECT count(*) FROM exemplares;     -- Attendu : ~247 (BLMF public)
--   SELECT count(*) FROM book_authors;   -- Attendu : ~85
--   SELECT count(*) FROM authors;        -- Attendu : ~47
--   ROLLBACK;
--
--   BEGIN; SET LOCAL ROLE authenticated;
--   SET LOCAL request.jwt.claim.sub = '<your_admin_uuid>';
--   SET LOCAL request.jwt.claims = '{"sub":"<your_admin_uuid>","role":"authenticated"}';
--   SELECT count(*) FROM exemplares;     -- Attendu : ~2458 (in_network = tout)
--   ROLLBACK;
--
-- Bloc 3 :
--   BEGIN; SET LOCAL ROLE anon;
--   SELECT count(*) FROM library_commons;             -- Attendu : 1 (BLMF)
--   SELECT count(*) FROM catalog_ref_acquisition_modes; -- Attendu : 7
--   ROLLBACK;
--
-- ============================================================================
