-- =========================================================================
-- Admin réseau — attribuer une notice + ses exemplaires à une bibliothèque
-- =========================================================================
-- Date     : 2026-06-06 (horodatage UTC réel)
-- Chantier : réseau / catalogação (action cross-bibliothèque, doctrine RES)
--
-- OBJET (demande Xavier)
--   Un·e admin réseau peut, depuis toute fiche document, attribuer la notice
--   ET ses exemplaires rattachés à une bibliothèque du réseau (transfert
--   complet). Choix actés : owner_library/holder_library ← nom de la cible ;
--   tous les exemplaires de la notice déplacés vers le holding de la cible ;
--   sélecteur limité aux biblios « catalogue présent » (catalog_mode =
--   'network_published').
--
--   - list_catalog_libraries() : biblios cible candidates (network_published).
--   - network_admin_reassign_book_to_library(book, library) : le transfert,
--     gardé par fn_caller_is_network_admin(), journalisé en action critique
--     (fn_log_cross_library_action → notif staff local).
--
-- DOCTRINE : SECURITY DEFINER + search_path + REVOKE EXECUTE FROM PUBLIC +
--   GRANT authenticated + gating interne admin réseau. Les anciens holdings
--   vidés ne sont PAS supprimés (évite tout effet de bord FK prêts/réservations) ;
--   leurs compteurs sont remis à zéro par le recompute.
-- =========================================================================

BEGIN;

-- Sélecteur : bibliothèques dont le catalogue est présent dans AnarBib --------
CREATE OR REPLACE FUNCTION public.list_catalog_libraries()
RETURNS TABLE (id uuid, name text, slug text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT l.id, l.name, l.slug
  FROM public.libraries l
  WHERE l.catalog_mode = 'network_published'
    AND public.fn_caller_is_network_admin()
  ORDER BY l.name;
$function$;

REVOKE EXECUTE ON FUNCTION public.list_catalog_libraries() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_catalog_libraries() TO authenticated;

-- Transfert : notice + exemplaires → bibliothèque cible ----------------------
CREATE OR REPLACE FUNCTION public.network_admin_reassign_book_to_library(
  p_book_id bigint,
  p_target_library_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_lib_name       text;
  v_lib_mode       text;
  v_book_loanable  boolean;
  v_target_holding bigint;
  v_old_holdings   bigint[];
  v_moved          integer := 0;
  v_affected       bigint[];
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao administrador de rede.';
  END IF;

  SELECT name, catalog_mode INTO v_lib_name, v_lib_mode
  FROM public.libraries WHERE id = p_target_library_id;
  IF v_lib_name IS NULL THEN
    RAISE EXCEPTION 'Biblioteca alvo inexistente: %', p_target_library_id;
  END IF;
  IF v_lib_mode IS DISTINCT FROM 'network_published' THEN
    RAISE EXCEPTION 'A biblioteca alvo não tem catálogo presente na rede.';
  END IF;

  SELECT loanable INTO v_book_loanable FROM public.books WHERE id = p_book_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Notícia inexistente: %', p_book_id;
  END IF;

  -- Holdings actuels de la notice (pour le recompute).
  SELECT array_agg(id) INTO v_old_holdings
  FROM public.book_holdings WHERE book_id = p_book_id;

  -- Get-or-create le holding de la bibliothèque cible pour cette notice.
  SELECT id INTO v_target_holding
  FROM public.book_holdings
  WHERE book_id = p_book_id AND library_id = p_target_library_id
  LIMIT 1;
  IF v_target_holding IS NULL THEN
    INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
    VALUES (p_book_id, p_target_library_id, COALESCE(v_book_loanable, true), 0, 0)
    RETURNING id INTO v_target_holding;
  END IF;

  -- Déplacer tous les exemplaires rattachés à la notice vers le holding cible.
  UPDATE public.exemplares e
  SET holding_id = v_target_holding,
      library_id = p_target_library_id,
      updated_at = now()
  WHERE e.holding_id IN (SELECT id FROM public.book_holdings WHERE book_id = p_book_id)
    AND e.holding_id IS DISTINCT FROM v_target_holding;
  GET DIAGNOSTICS v_moved = ROW_COUNT;

  -- Attribuer la notice à la bibliothèque cible.
  UPDATE public.books
  SET owner_library = v_lib_name,
      holder_library = v_lib_name,
      updated_at = now()
  WHERE id = p_book_id;

  -- Recompute des compteurs (anciens holdings + cible + livre).
  v_affected := COALESCE(v_old_holdings, ARRAY[]::bigint[]) || v_target_holding;
  PERFORM public.fn_v2_recompute_holdings_availability(v_affected, ARRAY[p_book_id]);

  -- Journal action cross-bibliothèque (critique → notif staff local, RES-Q6).
  PERFORM public.fn_log_cross_library_action(
    p_target_library_id, 'reassign_book_to_library', true, 'book', NULL,
    jsonb_build_object('book_id', p_book_id, 'target_library', v_lib_name, 'exemplares_moved', v_moved)
  );

  RETURN jsonb_build_object(
    'ok', true,
    'target_library', v_lib_name,
    'exemplares_moved', v_moved,
    'target_holding', v_target_holding
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.network_admin_reassign_book_to_library(bigint, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.network_admin_reassign_book_to_library(bigint, uuid) TO authenticated;

COMMENT ON FUNCTION public.network_admin_reassign_book_to_library(bigint, uuid) IS
  'Admin réseau : attribue une notice + ses exemplaires à une bibliothèque (transfert complet, journalisé). 06/06/2026.';

-- Vérification -------------------------------------------------------------
DO $verif$
BEGIN
  IF NOT has_function_privilege('authenticated', 'public.network_admin_reassign_book_to_library(bigint, uuid)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'VERIF_FAIL_1 : authenticated sans EXECUTE';
  END IF;
  IF has_function_privilege('public', 'public.network_admin_reassign_book_to_library(bigint, uuid)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'VERIF_FAIL_2 : PUBLIC a EXECUTE (doit etre REVOKE)';
  END IF;
  IF has_function_privilege('public', 'public.list_catalog_libraries()'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'VERIF_FAIL_3 : PUBLIC a EXECUTE sur list_catalog_libraries';
  END IF;
END
$verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback :
--   DROP FUNCTION IF EXISTS public.network_admin_reassign_book_to_library(bigint, uuid);
--   DROP FUNCTION IF EXISTS public.list_catalog_libraries();
-- =========================================================================
