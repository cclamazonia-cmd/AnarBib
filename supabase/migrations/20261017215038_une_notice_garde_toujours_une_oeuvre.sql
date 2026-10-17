-- =====================================================================
-- Une notice garde toujours une œuvre (17/10/2026, demande de Xavier).
--
-- Constat du relevé du 17/10 : trois notices sans œuvre (1841, 2178, 2212)
-- et une œuvre sans notice (1228). Les journaux de l'API l'expliquent : les
-- trois ont été détachées par le bouton « Détacher » de la section Œuvre du
-- formulaire (`detach_book_from_work`), qui vidait `books.work_id` sans
-- confirmation et supprimait l'œuvre quand la notice en était la seule
-- édition ; deux l'ont été juste avant une fusion, et la fusion, en supprimant
-- le doublon, laissait son œuvre à lui sans aucune notice (1228, l'œuvre de
-- 2681, fusionné dans 1841 le 14/10).
--
-- 1. « Détacher » sort une édition de son groupe : elle reçoit une œuvre à
--    elle (titre et auteur·rice principal·e de la notice, comme
--    create_work_from_book), l'œuvre quittée garde ses autres éditions. Une
--    notice qui est la seule édition de son œuvre, ou qui n'en a pas, n'est
--    pas touchée : il n'y a rien à détacher.
-- 2. Supprimer une notice range l'œuvre qu'elle laisse vide
--    (fn_work_prune_if_empty, qui garde l'œuvre tant qu'une notice, un
--    brouillon, une piste audio ou une note de lecture la désigne). Vaut pour
--    la fusion de notices et pour toute suppression.
-- 3. Les données : 1841 *Proudhon* reprend l'œuvre 1228 *Proudhon* (même
--    titre, même auteur, l'œuvre de son doublon) ; 2178 *In Russian and French
--    prisons* reçoit une œuvre à elle. Gardé par identifiant ET titre : sans
--    effet sur une autre base (banc, instance auto-hébergée).
-- =====================================================================

-- ─── 1. Détacher sans laisser la notice sans œuvre ────────────────────────
CREATE OR REPLACE FUNCTION public.detach_book_from_work(p_book_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_old    bigint;
  v_title  text;
  v_author bigint;
  v_new    bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  SELECT work_id, titulo INTO v_old, v_title FROM public.books WHERE id = p_book_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Documento inexistente.' USING ERRCODE = 'P0002', HINT = 'error.catalog.work.notFound';
  END IF;
  -- Rien à détacher : pas d'œuvre, ou seule édition de la sienne (la détacher
  -- la détruisait et laissait la notice sans œuvre — 17/10/2026).
  IF v_old IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE work_id = v_old AND id <> p_book_id) THEN
    RETURN;
  END IF;
  SELECT author_id INTO v_author FROM public.book_authors
   WHERE book_id = p_book_id AND role = 'autor' ORDER BY ord LIMIT 1;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id, created_by)
  VALUES (coalesce(nullif(v_title, ''), '(sans titre)'), public.fn_normalize_name(v_title), v_author, auth.uid())
  RETURNING id INTO v_new;
  UPDATE public.books SET work_id = v_new WHERE id = p_book_id;
  PERFORM public.fn_work_prune_if_empty(v_old);
END;
$$;
COMMENT ON FUNCTION public.detach_book_from_work(bigint) IS
  'Sort une édition de son œuvre : elle reçoit une œuvre à elle (titre et auteur·rice principal·e de la notice), l''œuvre quittée garde ses autres éditions. Sans effet sur une notice sans œuvre ou seule édition de la sienne (17/10/2026 : l''ancien geste vidait work_id). Bibliothécaires et coordinations.';

-- ─── 2. Une notice supprimée range l'œuvre qu'elle laisse vide ────────────
CREATE OR REPLACE FUNCTION public.tg_books_range_oeuvre_quittee()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF OLD.work_id IS NOT NULL THEN
    PERFORM public.fn_work_prune_if_empty(OLD.work_id);
  END IF;
  RETURN NULL;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.tg_books_range_oeuvre_quittee() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.tg_books_range_oeuvre_quittee() IS
  'Déclencheur : après la suppression d''une notice (fusion, corbeille), son œuvre est supprimée si plus rien ne la désigne (fn_work_prune_if_empty). 17/10/2026 : la fusion 1841 ← 2681 avait laissé l''œuvre 1228 sans notice.';

DROP TRIGGER IF EXISTS trg_books_range_oeuvre_quittee ON public.books;
CREATE TRIGGER trg_books_range_oeuvre_quittee
  AFTER DELETE ON public.books
  FOR EACH ROW EXECUTE FUNCTION public.tg_books_range_oeuvre_quittee();

-- ─── 3. Les deux notices sans œuvre de la production ──────────────────────
DO $$
DECLARE v_w bigint;
BEGIN
  UPDATE public.books SET work_id = 1228
   WHERE id = 1841 AND work_id IS NULL AND titulo = 'Proudhon'
     AND EXISTS (SELECT 1 FROM public.works WHERE id = 1228 AND uniform_title = 'Proudhon');

  IF EXISTS (SELECT 1 FROM public.books
              WHERE id = 2178 AND work_id IS NULL AND titulo = 'In Russian and French prisons') THEN
    INSERT INTO public.works (uniform_title, sort_title, primary_author_id)
    SELECT b.titulo, public.fn_normalize_name(b.titulo),
           (SELECT a.author_id FROM public.book_authors a
             WHERE a.book_id = b.id AND a.role = 'autor' ORDER BY a.ord LIMIT 1)
      FROM public.books b WHERE b.id = 2178
    RETURNING id INTO v_w;
    UPDATE public.books SET work_id = v_w WHERE id = 2178;
  END IF;
END $$;
