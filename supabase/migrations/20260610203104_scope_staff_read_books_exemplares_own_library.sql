-- Migration : scoper books_staff_read / exemplares_staff_read à la biblio propre
-- Auteur  : Claude Opus 4.8
-- Session : Verrou catalogação (docs/exemplaires limités à la biblio d'appartenance)
-- Date    : 2026-06-10 (UTC)
--
-- FUITE CORRIGÉE. Les policies books_staff_read / exemplares_staff_read (ajoutées
-- au fix des compteurs) autorisaient TOUT staff (librarian/coordenador, n'importe
-- quelle biblio) à lire TOUS les livres / exemplaires du réseau — y compris des
-- documents NON publiés d'autres bibliothèques. Décision (Xavier) : un·e
-- non-admin-réseau ne doit voir, en catalogação, que les docs/exemplaires de SA
-- bibliothèque. On scope donc ces policies à la biblio de l'appelant·e (via
-- user_has_library_staff_role), l'admin réseau gardant l'accès transverse.
--
-- Les policies *_public_read (visibilité réseau pour l'OPAC) sont INCHANGÉES.

-- ═══════════════════════════════════════════════════════════════
-- 1. books_staff_read — scopé : livres détenus par une biblio où je suis staff
-- ═══════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS books_staff_read ON public.books;

CREATE POLICY books_staff_read ON public.books
  FOR SELECT TO authenticated
  USING (
    public.fn_caller_is_network_admin()
    OR EXISTS (
      SELECT 1 FROM public.book_holdings h
      WHERE h.book_id = books.id
        AND public.user_has_library_staff_role((SELECT auth.uid()), h.library_id)
    )
  );

COMMENT ON POLICY books_staff_read ON public.books IS
  'Staff : voit les livres détenus par une bibliothèque où il/elle a un rôle '
  'staff (user_has_library_staff_role), pas le reste du réseau. Admin réseau = '
  'transverse. La visibilité publique réseau reste gérée par books_public_read.';

-- ═══════════════════════════════════════════════════════════════
-- 2. exemplares_staff_read — scopé : exemplaires de ma biblio
-- ═══════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS exemplares_staff_read ON public.exemplares;

CREATE POLICY exemplares_staff_read ON public.exemplares
  FOR SELECT TO authenticated
  USING (
    public.fn_caller_is_network_admin()
    OR public.user_has_library_staff_role((SELECT auth.uid()), exemplares.library_id)
  );

COMMENT ON POLICY exemplares_staff_read ON public.exemplares IS
  'Staff : voit uniquement les exemplaires de sa/ses bibliothèque(s) '
  '(exemplares.library_id via user_has_library_staff_role). Admin réseau = '
  'transverse. La visibilité publique reste gérée par exemplares_public_read.';

-- ═══════════════════════════════════════════════════════════════
-- 3. Vérification
-- ═══════════════════════════════════════════════════════════════

DO $verif$
DECLARE
  v_books_scoped boolean;
  v_exemp_scoped boolean;
BEGIN
  SELECT (qual ILIKE '%user_has_library_staff_role%') INTO v_books_scoped
    FROM pg_policies WHERE schemaname='public' AND tablename='books' AND policyname='books_staff_read';
  SELECT (qual ILIKE '%user_has_library_staff_role%') INTO v_exemp_scoped
    FROM pg_policies WHERE schemaname='public' AND tablename='exemplares' AND policyname='exemplares_staff_read';

  IF NOT coalesce(v_books_scoped, false) OR NOT coalesce(v_exemp_scoped, false) THEN
    RAISE EXCEPTION 'Verrou catalogação : policies non scopées (books=%, exemplares=%)', v_books_scoped, v_exemp_scoped;
  END IF;
  RAISE NOTICE 'Verrou catalogação OK : books_staff_read + exemplares_staff_read scopées à la biblio.';
END
$verif$;
