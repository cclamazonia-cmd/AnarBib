-- =========================================================================
-- Paquet fix — RPC get_exemplar_labels (debloque le module Etiquettes)
-- =========================================================================
-- Date     : 2026-06-06
-- Chantier : Catalogage / etiquettes de cote
-- Auteur   : Xavier + Claude
--
-- PROBLEME (diagnostic 2026-06-06)
-- --------------------------------
-- Le module d'impression d'etiquettes (LabelSheetPrinter) lit directement la
-- vue v_exemplar_labels. Cette vue est security_invoker=true et appelle en
-- LATERAL la fonction resolve_library_holding_bridge() — laquelle est
-- SECURITY DEFINER mais N'EST PAS executable par le role authenticated. Resultat
-- pour tout staff connecte :
--     ERROR 42501: permission denied for function resolve_library_holding_bridge
-- -> la requete .from('v_exemplar_labels') echoue, le composant avale l'erreur
--    (setLabels(data || [])) et affiche une liste VIDE. Le module semble casse.
-- (Meme cause que le workaround PEB fn_peb_search_exemplares, qui n'avait pas
--  ete applique au module etiquettes.)
--
-- CORRECTIF
-- ---------
-- RPC SECURITY DEFINER get_exemplar_labels(p_library_id) : executee comme owner,
-- elle peut interroger la vue (le bridge s'execute alors avec les droits owner)
-- et renvoyer les lignes d'etiquettes de la bibliotheque demandee. Gate interne
-- staff (user_has_library_staff_role) qui remplace la RLS contournee. Le
-- frontend bascule de .from('v_exemplar_labels') vers .rpc('get_exemplar_labels').
--
-- DOCTRINE : SECURITY DEFINER + search_path + REVOKE FROM PUBLIC, anon +
--   GRANT authenticated + gate staff interne (comme search_authors_by_name).
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.get_exemplar_labels(p_library_id uuid)
RETURNS SETOF public.v_exemplar_labels
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  -- Gate : staff (librarian/coordenador/administrador) de la bibliotheque ciblee
  IF p_library_id IS NULL
     OR NOT public.user_has_library_staff_role(auth.uid(), p_library_id) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff da biblioteca.';
  END IF;

  RETURN QUERY
    SELECT v.*
    FROM public.v_exemplar_labels v
    WHERE v.library_id = p_library_id
    ORDER BY v.exemplar_id DESC;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_exemplar_labels(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_exemplar_labels(uuid) TO authenticated;

COMMENT ON FUNCTION public.get_exemplar_labels(uuid) IS
  'Etiquettes de cote d''une bibliotheque (staff). Wrapper SECURITY DEFINER de v_exemplar_labels : contourne le souci de droit sur resolve_library_holding_bridge (vue security_invoker). Gate staff interne. Module LabelSheetPrinter. 06/06/2026.';

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback : DROP FUNCTION IF EXISTS public.get_exemplar_labels(uuid);
-- =========================================================================
