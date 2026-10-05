-- =====================================================================
-- AnarBib — Tests d'acceptation : qui la liste du catalogue nomme (CAT-G4)
-- Date    : 2026-10-05
-- Ref     : migration 20261005164328_la_liste_du_catalogue_nomme_aussi_les_coauteurs
-- Session : Doublons SNI & forme autorisée des contributeurs
--
-- v_book_authors_canonical (author_display / author_chips de la liste et de
-- la fiche) retient les mêmes responsables principaux que les citations :
-- T1 auteur + coauteur nommés, traduction et illustration non ;
-- T2 un livre n'ayant que des coauteurs les nomme (pas de repli sur
--    l'organisation) ;
-- T3 sans auteur ni coauteur, l'organisation est nommée.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'LISTE-COAUTEURS OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_b1 bigint; v_b2 bigint; v_b3 bigint; v_txt text;
BEGIN
  INSERT INTO public.books (titulo, tipo_material) VALUES ('LC auteur et coauteur', 'livro') RETURNING id INTO v_b1;
  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary) VALUES
    (v_b1, 1, 'Auteur, Premier', 'autor', true),
    (v_b1, 2, 'Coauteur, Second', 'coautor', false),
    (v_b1, 3, 'Traduction, Tiers', 'tradutor', false),
    (v_b1, 4, 'Illustration, Quart', 'ilustrador', false);
  INSERT INTO public.books (titulo, tipo_material) VALUES ('LC coauteurs seuls', 'livro') RETURNING id INTO v_b2;
  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary) VALUES
    (v_b2, 1, 'Coauteur, Un', 'coautor', true),
    (v_b2, 2, 'Coauteur, Deux', 'coautor', false),
    (v_b2, 3, 'Organisation, Trois', 'organizador', false);
  INSERT INTO public.books (titulo, tipo_material) VALUES ('LC organisation', 'livro') RETURNING id INTO v_b3;
  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary) VALUES
    (v_b3, 1, 'Organisation, Seule', 'organizador', true),
    (v_b3, 2, 'Préface, Autre', 'prefaciador', false);

  v_t := 'T1 auteur et coauteur nommes, traduction et illustration non';
  BEGIN
    SELECT author_display INTO v_txt FROM public.v_book_authors_canonical WHERE book_id = v_b1;
    IF v_txt = 'AUTEUR, Premier ; COAUTEUR, Second'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T2 des coauteurs seuls sont nommes, sans repli sur l''organisation';
  BEGIN
    SELECT author_display INTO v_txt FROM public.v_book_authors_canonical WHERE book_id = v_b2;
    IF v_txt = 'COAUTEUR, Un ; COAUTEUR, Deux'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 sans auteur ni coauteur, l''organisation est nommee';
  BEGIN
    SELECT author_display INTO v_txt FROM public.v_book_authors_canonical WHERE book_id = v_b3;
    IF v_txt = 'ORGANISATION, Seule'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'LISTE-COAUTEURS OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'LISTE-COAUTEURS ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
