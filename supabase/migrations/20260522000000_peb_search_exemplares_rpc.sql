-- =============================================================================
-- 20260522000000_peb_search_exemplares_rpc.sql
-- =============================================================================
-- Correctif de l'etape 9 (EA-12 phase 2, dette 4 - parite PEB).
--
-- CONTEXTE : le patch d'etape 9 avait branche la recherche d'exemplaires du
-- PEB sur la vue v_exemplar_labels. Cette vue appelle en interne la fonction
-- resolve_library_holding_bridge(), sur laquelle le role `authenticated` n'a
-- PAS de GRANT EXECUTE. Toute lecture de la vue par le frontend echouait donc
-- avec « 42501 permission denied for function resolve_library_holding_bridge »
-- -> la recherche d'exemplaires ne renvoyait jamais aucun resultat.
--
-- CHOIX : plutot que d'ouvrir resolve_library_holding_bridge a authenticated
-- (elargir une surface d'execution interne pour une mauvaise raison), on cree
-- une RPC de recherche dediee qui interroge directement les tables reelles
-- exemplares -> book_holdings -> books. Ces trois tables ont deja RLS + GRANT
-- SELECT pour authenticated ; la RPC est SECURITY INVOKER, donc la recherche
-- reste filtree par la RLS de chaque table (fn_library_visible_to_caller).
--
-- La RPC couvre uniquement les exemplaires rattaches a un holding
-- (exemplares.holding_id NOT NULL). Les exemplaires legacy sans holding_id
-- (que la vue resolvait via le bridge) ne sont pas cherchables ici : en PEB,
-- on prete un exemplaire correctement catalogue, rattache a un fonds.
--
-- Conforme doctrine RPC v3 (recherche jointe = operation non triviale -> RPC)
-- et doctrine de creation d'objets backend v2 (REVOKE puis GRANT cible,
-- DO-block de verification).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_peb_search_exemplares(p_query text)
RETURNS TABLE (
  exemplar_id   bigint,
  holding_id    bigint,
  book_id       bigint,
  titulo        text,
  autor         text,
  bib_ref       text,
  tombo         text,
  library_id    uuid
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    e.id          AS exemplar_id,
    e.holding_id  AS holding_id,
    h.book_id     AS book_id,
    b.titulo      AS titulo,
    b.autor       AS autor,
    COALESCE(NULLIF(btrim(h.local_bib_ref), ''), b.bib_ref, e.bib_ref) AS bib_ref,
    e.tombo       AS tombo,
    e.library_id  AS library_id
  FROM public.exemplares e
  JOIN public.book_holdings h ON h.id = e.holding_id
  JOIN public.books b         ON b.id = h.book_id
  WHERE e.holding_id IS NOT NULL
    AND (
         b.titulo ILIKE '%' || btrim(p_query) || '%'
      OR b.autor  ILIKE '%' || btrim(p_query) || '%'
      OR e.tombo  ILIKE '%' || btrim(p_query) || '%'
      OR b.bib_ref ILIKE '%' || btrim(p_query) || '%'
    )
  ORDER BY b.titulo, e.tombo
  LIMIT 20;
$$;

-- --- Permissions : REVOKE large puis GRANT cible (doctrine objets v2) --------
REVOKE ALL ON FUNCTION public.fn_peb_search_exemplares(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_peb_search_exemplares(text) TO authenticated, service_role;

-- --- Verification en fin de transaction --------------------------------------
DO $$
DECLARE
  v_exists boolean;
  v_auth_exec boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_peb_search_exemplares'
  ) INTO v_exists;
  IF NOT v_exists THEN
    RAISE EXCEPTION 'Echec : fn_peb_search_exemplares non creee.';
  END IF;

  SELECT has_function_privilege('authenticated', 'public.fn_peb_search_exemplares(text)', 'EXECUTE')
    INTO v_auth_exec;
  IF NOT v_auth_exec THEN
    RAISE EXCEPTION 'Echec : authenticated n''a pas EXECUTE sur fn_peb_search_exemplares.';
  END IF;

  RAISE NOTICE 'OK : fn_peb_search_exemplares creee, EXECUTE accorde a authenticated. SECURITY INVOKER -> recherche filtree par la RLS de exemplares/book_holdings/books.';
END $$;
