-- =========================================================================
-- Paquet feat — RPC staff : rafraichir le catalogue a la demande
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Catalogage / confort staff (bouton "Atualizar catalogo")
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- Les MV catalogue (mv_books_catalog_list_v1 + _network_v1) sont rafraichies
-- par un cron toutes les 15 min (fn refresh_mv_books_catalog_list_v1, choix
-- deliberé pour menager Supabase). Apres une edition d'autorite / rattachement,
-- le catalogue peut donc accuser jusqu'a 15 min de retard d'affichage.
--
-- Cette RPC expose un rafraichissement A LA DEMANDE, reserve au staff de
-- catalogage, pour un retour visuel immediat sans toucher au cron.
--
-- DOCTRINE
--   - SECURITY DEFINER + SET search_path + gate staff (librarian/coordenador),
--     comme search_authors_by_name / merge_author.
--   - REVOKE EXECUTE FROM PUBLIC, anon + GRANT authenticated (le gate interne
--     restreint au staff ; un membre non-staff recoit l'exception).
--   - Verrou advisory de transaction NON bloquant : si un autre refresh manuel
--     est deja en cours, on renvoie 'busy' immediatement au lieu d'empiler des
--     REFRESH (qui se serialiseraient de toute facon sur la meme MV).
--   - Reutilise la fonction de refresh existante (REFRESH ... CONCURRENTLY des
--     2 MV + ANALYZE) : exactement ce que fait le cron, donc compatible avec un
--     appel via fonction/transaction (le cron le prouve a chaque tick).
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.request_catalog_refresh()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_got_lock boolean;
BEGIN
  -- Gate staff catalogage
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  -- Verrou anti-concurrence non bloquant (cle arbitraire fixe). Libere au COMMIT.
  v_got_lock := pg_try_advisory_xact_lock(792025001::bigint);
  IF NOT v_got_lock THEN
    RETURN 'busy';
  END IF;

  PERFORM public.refresh_mv_books_catalog_list_v1();
  RETURN 'refreshed';
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.request_catalog_refresh() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.request_catalog_refresh() TO authenticated;

COMMENT ON FUNCTION public.request_catalog_refresh() IS
  'Rafraichit a la demande les MV catalogue (staff librarian/coordenador). Verrou advisory non bloquant -> renvoie ''busy'' si un refresh est deja en cours, ''refreshed'' sinon. Bouton Atualizar catalogo (espace catalogage). 05/06/2026.';

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback : DROP FUNCTION IF EXISTS public.request_catalog_refresh();
-- =========================================================================
