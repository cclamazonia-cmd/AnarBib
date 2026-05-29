-- ═══════════════════════════════════════════════════════════════════════════
-- Migration : durcir la policy books_public_read (cascade visibility biblio)
-- Date      : 2026-05-05
-- ═══════════════════════════════════════════════════════════════════════════
--
-- CONTEXTE
-- --------
-- La policy `books_public_read` filtrait simplement par "il existe au moins
-- un holding pour ce livre", sans vérifier la visibility de la biblio
-- hébergeante. Cohérence partielle : les RLS de book_holdings, exemplares,
-- book_authors, etc. ont été cascadées via fn_library_visible_to_caller le
-- 02/05 (commit 039af1e), mais books a été oublié dans cette migration.
--
-- IMPACT ACTUEL : nul (toutes les biblios actives sont en visibility_level
-- = 'public' au 05/05/2026). Le leak ne se déclenche que si on active une
-- biblio en visibility_level = 'network' ou 'private'.
--
-- IMPACT POTENTIEL : critique. Une biblio activée en network ou private
-- aurait tous ses livres immédiatement leakés aux anons (titres, auteurs,
-- métadonnées) sans avertissement.
--
-- FIX : aligner sur le pattern utilisé pour book_authors, exemplares,
-- book_digital_resources, etc. (cascade via fn_library_visible_to_caller).
--
-- VÉRIFICATION POST-MIGRATION : le count(*) de books pour anon doit rester
-- inchangé tant qu'aucune biblio n'est en network/private. Aujourd'hui : 240.
-- ═══════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS books_public_read ON public.books;

CREATE POLICY books_public_read
ON public.books
FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.book_holdings h
    WHERE h.book_id = books.id
      AND public.fn_library_visible_to_caller(h.library_id)
  )
);

COMMENT ON POLICY books_public_read ON public.books IS
  'Cascade visibility biblio : un livre est visible si au moins un de ses '
  'holdings est dans une bibliothèque visible pour l''appelant·e (sémantique A : '
  'public/network/private). Aligné sur book_authors_public_read et '
  'exemplares_public_read (commit 039af1e du 02/05). Durci 2026-05-05.';

-- ═══════════════════════════════════════════════════════════════════════════
-- VÉRIFICATION POST-MIGRATION
-- ═══════════════════════════════════════════════════════════════════════════
-- 1. La policy est en place :
--   SELECT polname, pg_get_expr(polqual, polrelid)
--   FROM pg_policy WHERE polrelid = 'public.books'::regclass;
--
-- 2. Le count anon doit rester inchangé (240 actuellement, toutes biblios public) :
--   BEGIN; SET LOCAL ROLE anon;
--   SELECT count(*) FROM books;
--   ROLLBACK;
