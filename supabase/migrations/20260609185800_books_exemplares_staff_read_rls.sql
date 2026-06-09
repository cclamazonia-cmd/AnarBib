-- Migration : policies staff_read pour books et exemplares
-- Auteur  : Claude Opus 4.6
-- Session : Lot 2 – Fontes externas bout-en-bout (fix compteurs)
-- Date    : 2026-06-09
--
-- Ajoute des policies staff_read sur books et exemplares, alignées
-- sur authors_staff_read déjà en place. Donne un chemin d'accès
-- rapide au staff (librarian/coordenador) sans passer par la chaîne
-- book_holdings → fn_library_visible_to_caller → fn_current_user_is_in_network
-- qui provoque des timeouts sur les COUNT(*) avec 2600+ livres.

-- ═══════════════════════════════════════════════════════════════
-- 1. books_staff_read
-- ═══════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'books' AND policyname = 'books_staff_read'
  ) THEN
    CREATE POLICY books_staff_read ON public.books
      FOR SELECT TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.user_library_memberships m
          WHERE m.user_id = auth.uid()
            AND m.status = 'active'
            AND m.role IN ('librarian', 'coordenador')
        )
      );
  END IF;
END $$;

COMMENT ON POLICY books_staff_read ON public.books IS
  'Raccourci staff : tout librarian/coordenador actif voit tous les livres '
  'sans passer par la chaîne book_holdings → fn_library_visible_to_caller. '
  'Aligné sur authors_staff_read (paquet existant).';

-- ═══════════════════════════════════════════════════════════════
-- 2. exemplares_staff_read
-- ═══════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'exemplares' AND policyname = 'exemplares_staff_read'
  ) THEN
    CREATE POLICY exemplares_staff_read ON public.exemplares
      FOR SELECT TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.user_library_memberships m
          WHERE m.user_id = auth.uid()
            AND m.status = 'active'
            AND m.role IN ('librarian', 'coordenador')
        )
      );
  END IF;
END $$;

COMMENT ON POLICY exemplares_staff_read ON public.exemplares IS
  'Raccourci staff : tout librarian/coordenador actif voit tous les exemplaires '
  'sans passer par la chaîne book_holdings → fn_library_visible_to_caller. '
  'Aligné sur authors_staff_read (paquet existant).';

-- ═══════════════════════════════════════════════════════════════
-- 3. Vérification
-- ═══════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_books_ok boolean;
  v_exemplares_ok boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'books' AND policyname = 'books_staff_read'
  ) INTO v_books_ok;

  SELECT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'exemplares' AND policyname = 'exemplares_staff_read'
  ) INTO v_exemplares_ok;

  IF NOT v_books_ok OR NOT v_exemplares_ok THEN
    RAISE EXCEPTION 'staff_read policies manquantes: books=%, exemplares=%', v_books_ok, v_exemplares_ok;
  END IF;

  RAISE NOTICE 'staff_read_ok: books=%, exemplares=%', v_books_ok, v_exemplares_ok;
END $$;
