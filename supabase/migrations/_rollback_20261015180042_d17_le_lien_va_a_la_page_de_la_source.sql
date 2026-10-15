-- Retour arrière de 20261015180042_d17_le_lien_va_a_la_page_de_la_source.sql
-- Rend à get_accessible_digital_asset_by_id_v2 sa forme du 04/10 (sans
-- source_page_url ; source_url rendue telle quelle, le masquage ne tenant plus
-- que dans read-digital-asset). Publication et reprise : rejouer leurs
-- définitions de 20261006175037 AVANT de retirer les colonnes, sinon elles
-- échouent à la première exécution.
-- Fichier préfixé « _rollback_ » : jamais appliqué par la CI, à jouer à la main si besoin
-- (tracé : DOC-DEPLOY-3).
-- Session : D17 lien vers la page source

BEGIN;

DROP FUNCTION IF EXISTS public.get_accessible_digital_asset_by_id_v2(bigint);
CREATE FUNCTION public.get_accessible_digital_asset_by_id_v2(p_asset_id bigint)
 RETURNS TABLE(asset_id bigint, book_id bigint, resource_type text, usage_type text, access_scope text, mime_type text, storage_bucket text, storage_path text, language_code text, source_name text, source_url text, attribution_text text, rights_status text, label text, is_primary boolean, requires_active_account boolean, access_granted boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    r.id AS asset_id, r.book_id, r.resource_type, r.usage_type, r.access_scope,
    r.mime_type, r.storage_bucket, r.storage_path, r.language_code, r.source_name,
    r.source_url, r.attribution_text, r.rights_status, r.label, r.is_primary,
    (r.access_scope = 'conta_ativa') AS requires_active_account,
    CASE
      WHEN r.access_scope = 'publico' THEN true
      WHEN r.access_scope = 'conta_ativa'
        THEN public.fn_current_user_conta_ativa()
         AND public.fn_current_user_is_member_of_holding_library(r.book_id)
      ELSE false
    END AS access_granted
  FROM public.book_digital_resources r
  WHERE r.id = p_asset_id
    AND r.status = 'active'
    AND COALESCE(r.is_active, false) = true
    AND (
      r.access_scope = 'publico'
      OR (
        r.access_scope = 'conta_ativa'
        AND public.fn_current_user_conta_ativa()
        AND public.fn_current_user_is_member_of_holding_library(r.book_id)
      )
    )
    AND EXISTS (
      SELECT 1 FROM public.book_holdings h
      WHERE h.book_id = r.book_id
        AND public.fn_library_visible_to_caller(h.library_id)
    )
  LIMIT 1;
$function$;
REVOKE EXECUTE ON FUNCTION public.get_accessible_digital_asset_by_id_v2(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_accessible_digital_asset_by_id_v2(bigint) TO anon, authenticated, service_role;

-- Ici : rejouer copy_book_digital_resources_to_draft et
-- publish_book_draft_digital_resources depuis 20261006175037.

ALTER TABLE public.book_draft_digital_resources DROP COLUMN IF EXISTS source_page_url;
ALTER TABLE public.book_digital_resources DROP COLUMN IF EXISTS source_page_url;

NOTIFY pgrst, 'reload schema';

COMMIT;
