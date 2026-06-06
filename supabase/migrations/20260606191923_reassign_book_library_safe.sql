-- =========================================================================
-- Paquet fix — reassignation de notice sure vis-a-vis du multi-bibliotheque
-- =========================================================================
-- Session  : Exemplaires & nettoyage catalogue
-- Auteur   : Xavier + Claude
-- Chantier : Admin reseau / integrite cross-bibliotheque
--
-- CONTEXTE
-- --------
-- network_admin_reassign_book_to_library(book, target) deplacait TOUS les
-- exemplaires de la notice vers la biblio cible, quelle que soit leur biblio
-- d'origine. Pour une notice partagee (exemplaires dans plusieurs biblios),
-- cela rapatrie par erreur les copies d'autrui. Aujourd'hui 2 notices sont
-- multi-biblios, mais le risque grandit avec l'arrivee de nouvelles biblios.
--
-- POINT C — deux niveaux :
--  (1) GARDE-FOU : la fonction a 2 args REFUSE desormais si la notice a des
--      exemplaires dans > 1 biblio (oriente vers la variante scopee).
--  (2) VARIANTE SCOPEE : network_admin_reassign_book_from_to_library(book,
--      source, target) ne deplace QUE les exemplaires de la biblio source.
--      owner_library/holder_library NON modifies (notice partagee) — la
--      semantique d'appartenance de notice partagee est un sujet a part.
--
-- exemplares.library_id est la verite terrain (0 incoherence avec le holding),
-- d'ou un filtrage par library_id plutot que par convention de tombo (non
-- encodee en base, peu fiable).
-- =========================================================================

BEGIN;

-- (1) Fonction historique a 2 args : ajout du garde-fou multi-biblio.
CREATE OR REPLACE FUNCTION public.network_admin_reassign_book_to_library(p_book_id bigint, p_target_library_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_lib_name       text;
  v_lib_mode       text;
  v_book_loanable  boolean;
  v_target_holding bigint;
  v_old_holdings   bigint[];
  v_moved          integer := 0;
  v_affected       bigint[];
  v_distinct_libs  integer;
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

  -- GARDE-FOU (point C/1) : ne pas rapatrier en masse une notice partagee.
  SELECT count(DISTINCT e.library_id) INTO v_distinct_libs
  FROM public.exemplares e
  JOIN public.book_holdings h ON h.id = e.holding_id
  WHERE h.book_id = p_book_id;
  IF COALESCE(v_distinct_libs, 0) > 1 THEN
    RAISE EXCEPTION 'Esta notícia tem exemplares em % bibliotecas. Reatribuição global bloqueada: use network_admin_reassign_book_from_to_library(notícia, biblioteca_origem, biblioteca_destino) por biblioteca.', v_distinct_libs;
  END IF;

  SELECT array_agg(id) INTO v_old_holdings
  FROM public.book_holdings WHERE book_id = p_book_id;

  SELECT id INTO v_target_holding
  FROM public.book_holdings
  WHERE book_id = p_book_id AND library_id = p_target_library_id
  LIMIT 1;
  IF v_target_holding IS NULL THEN
    INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
    VALUES (p_book_id, p_target_library_id, COALESCE(v_book_loanable, true), 0, 0)
    RETURNING id INTO v_target_holding;
  END IF;

  UPDATE public.exemplares e
  SET holding_id = v_target_holding,
      library_id = p_target_library_id,
      updated_at = now()
  WHERE e.holding_id IN (SELECT id FROM public.book_holdings WHERE book_id = p_book_id)
    AND e.holding_id IS DISTINCT FROM v_target_holding;
  GET DIAGNOSTICS v_moved = ROW_COUNT;

  UPDATE public.books
  SET owner_library = v_lib_name,
      holder_library = v_lib_name,
      updated_at = now()
  WHERE id = p_book_id;

  v_affected := COALESCE(v_old_holdings, ARRAY[]::bigint[]) || v_target_holding;
  PERFORM public.fn_v2_recompute_holdings_availability(v_affected, ARRAY[p_book_id]);

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

-- (2) Variante scopee par biblio source : ne deplace QUE les exemplaires
--     rattaches a la biblio d'origine indiquee.
CREATE OR REPLACE FUNCTION public.network_admin_reassign_book_from_to_library(p_book_id bigint, p_source_library_id uuid, p_target_library_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_lib_name        text;
  v_lib_mode        text;
  v_book_loanable   boolean;
  v_target_holding  bigint;
  v_source_holdings bigint[];
  v_moved           integer := 0;
  v_affected        bigint[];
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao administrador de rede.';
  END IF;
  IF p_source_library_id = p_target_library_id THEN
    RAISE EXCEPTION 'Biblioteca de origem e destino são idênticas.';
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

  -- Holdings de la notice DANS la biblio source.
  SELECT array_agg(id) INTO v_source_holdings
  FROM public.book_holdings
  WHERE book_id = p_book_id AND library_id = p_source_library_id;
  IF v_source_holdings IS NULL THEN
    RAISE EXCEPTION 'A notícia não tem acervo na biblioteca de origem indicada.';
  END IF;

  -- get-or-create du holding cible.
  SELECT id INTO v_target_holding
  FROM public.book_holdings
  WHERE book_id = p_book_id AND library_id = p_target_library_id
  LIMIT 1;
  IF v_target_holding IS NULL THEN
    INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
    VALUES (p_book_id, p_target_library_id, COALESCE(v_book_loanable, true), 0, 0)
    RETURNING id INTO v_target_holding;
  END IF;

  -- Deplacer UNIQUEMENT les exemplaires de la biblio source.
  UPDATE public.exemplares e
  SET holding_id = v_target_holding,
      library_id = p_target_library_id,
      updated_at = now()
  WHERE e.holding_id = ANY(v_source_holdings)
    AND e.holding_id IS DISTINCT FROM v_target_holding;
  GET DIAGNOSTICS v_moved = ROW_COUNT;

  -- owner_library/holder_library volontairement NON modifies (notice partagee).

  v_affected := v_source_holdings || v_target_holding;
  PERFORM public.fn_v2_recompute_holdings_availability(v_affected, ARRAY[p_book_id]);

  PERFORM public.fn_log_cross_library_action(
    p_target_library_id, 'reassign_book_from_to_library', true, 'book', NULL,
    jsonb_build_object('book_id', p_book_id, 'source_library', p_source_library_id, 'target_library', v_lib_name, 'exemplares_moved', v_moved)
  );

  RETURN jsonb_build_object(
    'ok', true,
    'target_library', v_lib_name,
    'source_library', p_source_library_id,
    'exemplares_moved', v_moved,
    'target_holding', v_target_holding
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.network_admin_reassign_book_to_library(bigint, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.network_admin_reassign_book_from_to_library(bigint, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.network_admin_reassign_book_from_to_library(bigint, uuid, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback : CREATE OR REPLACE de la fonction 2-args sans le garde-fou +
-- DROP FUNCTION network_admin_reassign_book_from_to_library(bigint,uuid,uuid).
-- =========================================================================
