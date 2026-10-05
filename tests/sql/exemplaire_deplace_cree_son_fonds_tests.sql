-- =====================================================================
-- AnarBib — Tests : C23 — un exemplaire déplacé par sa publication trouve,
-- ou crée, le fonds de sa notice dans la bibliothèque visée.
-- Date    : 2026-10-05
-- Réf     : supabase/migrations/20261005092748_un_exemplaire_deplace_trouve_ou_cree_son_fonds.sql
--
-- La suite EMPRUNTE publish_exemplar_draft, sous une session d'admin réseau :
--   · vers une bibliothèque où la notice n'a aucun fonds : le fonds est créé,
--     l'exemplaire y entre, le brouillon le désigne, l'ancien fonds vidé part ;
--   · vers une bibliothèque d'où une réattribution avait supprimé le fonds :
--     il revient tel qu'il était (cote locale, prêtabilité, notes) ;
--   · vers une bibliothèque où la notice a déjà un fonds sous une AUTRE cote
--     (introuvable par la cote du brouillon) : ce fonds-là sert, aucun doublon ;
--   · une republication dans la même bibliothèque ne touche pas au fonds.
-- Les brouillons portent le tombo de l'exemplaire : les bibliothèques d'essai
-- n'ont pas de série d'inventaire.
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'FONDS-CREE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_admin uuid := gen_random_uuid();
  v_suf text;
  v_libA uuid; v_libB uuid; v_libC uuid;
  v_b1 bigint; v_h1A bigint; v_x1 bigint; v_d1 bigint; v_h1C bigint;
  v_b2 bigint; v_h2C bigint; v_x2 bigint; v_d2 bigint; v_h2back bigint;
  v_b3 bigint; v_h3A bigint; v_h3B bigint; v_x3 bigint; v_d3 bigint;
  v_b4 bigint; v_h4A bigint; v_x4 bigint; v_d4 bigint;
  v_n int;
BEGIN
  v_suf := substr(replace(v_admin::text, '-', ''), 1, 8);
  INSERT INTO auth.users (id, email) VALUES (v_admin, 'c23-admin-' || v_suf || '@example.invalid');
  INSERT INTO public.profiles (id) VALUES (v_admin) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('c23-a-' || v_suf, 'C23 A (essai)', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('c23-b-' || v_suf, 'C23 B (essai)', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_libB;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('c23-c-' || v_suf, 'C23 C (essai)', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_libC;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  -- ── vers une bibliothèque où la notice n'a aucun fonds ─────────────
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C23 sans fonds (essai)', 'C23-1-' || v_suf, 'livro') RETURNING id INTO v_b1;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b1, v_libA) RETURNING id INTO v_h1A;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C23-1-' || v_suf, 'C23-' || v_suf || '-1', v_libA, v_h1A, 'ambos', 'public') RETURNING id INTO v_x1;
  INSERT INTO public.exemplar_drafts (action, status, published_exemplar_id, target_library_id, target_bib_ref, tombo)
  VALUES ('update', 'draft', v_x1, v_libC, 'C23-1-' || v_suf, 'C23-' || v_suf || '-1') RETURNING id INTO v_d1;
  v_t := 'T1 vers une bibliothèque sans fonds de la notice : le fonds est créé et l''exemplaire y entre';
  BEGIN
    PERFORM public.publish_exemplar_draft(v_d1);
    SELECT h.id INTO v_h1C FROM public.book_holdings h WHERE h.book_id = v_b1 AND h.library_id = v_libC;
    IF v_h1C IS NOT NULL
       AND (SELECT library_id FROM public.exemplares WHERE id = v_x1) = v_libC
       AND (SELECT holding_id FROM public.exemplares WHERE id = v_x1) = v_h1C
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  v_t := 'T2 le brouillon publié désigne le nouveau fonds, l''ancien fonds vidé est parti (CAT-E19)';
  IF v_h1C IS NOT NULL
     AND (SELECT target_holding_id FROM public.exemplar_drafts WHERE id = v_d1) = v_h1C
     AND (SELECT status FROM public.exemplar_drafts WHERE id = v_d1) = 'published'
     AND NOT EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_h1A)
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  -- ── vers une bibliothèque d'où une réattribution avait supprimé le fonds ─
  INSERT INTO public.books (titulo, bib_ref, tipo_material, loanable) VALUES ('C23 retour (essai)', 'C23-2-' || v_suf, 'livro', true) RETURNING id INTO v_b2;
  INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref, loanable, notes)
  VALUES (v_b2, v_libC, 'C23-LOC-' || v_suf, false, 'C23 note du fonds') RETURNING id INTO v_h2C;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C23-LOC-' || v_suf, 'C23-' || v_suf || '-2', v_libC, v_h2C, 'consulta', 'public') RETURNING id INTO v_x2;
  -- La réattribution C → A supprime le fonds de C, gardé entier au journal.
  PERFORM public.network_admin_reassign_book_from_to_library(v_b2, v_libC, v_libA);
  INSERT INTO public.exemplar_drafts (action, status, published_exemplar_id, target_library_id, target_bib_ref, tombo)
  VALUES ('update', 'draft', v_x2, v_libC, 'C23-2-' || v_suf, 'C23-' || v_suf || '-2') RETURNING id INTO v_d2;
  v_t := 'T3 le fonds supprimé par une réattribution revient tel qu''il était (cote locale, prêtabilité, notes)';
  BEGIN
    IF EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_h2C) THEN
      RAISE EXCEPTION 'préalable : la réattribution n''a pas supprimé le fonds de C';
    END IF;
    PERFORM public.publish_exemplar_draft(v_d2);
    SELECT h.id INTO v_h2back FROM public.book_holdings h WHERE h.book_id = v_b2 AND h.library_id = v_libC;
    IF v_h2back IS NOT NULL
       AND (SELECT local_bib_ref FROM public.book_holdings WHERE id = v_h2back) = 'C23-LOC-' || v_suf
       AND (SELECT loanable FROM public.book_holdings WHERE id = v_h2back) = false
       AND (SELECT notes FROM public.book_holdings WHERE id = v_h2back) = 'C23 note du fonds'
       AND (SELECT holding_id FROM public.exemplares WHERE id = v_x2) = v_h2back
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  v_t := 'T4 l''exemplaire revenu reprend la cote locale de son fonds';
  IF (SELECT bib_ref FROM public.exemplares WHERE id = v_x2) = 'C23-LOC-' || v_suf
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1;
    v_failures := v_failures||(v_t||' : '||coalesce((SELECT bib_ref FROM public.exemplares WHERE id = v_x2),'NULL')); END IF;

  -- ── la notice a déjà un fonds dans la cible, sous une autre cote ───
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C23 autre cote (essai)', 'C23-3-' || v_suf, 'livro') RETURNING id INTO v_b3;
  INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref) VALUES (v_b3, v_libA, 'C23-A3-' || v_suf) RETURNING id INTO v_h3A;
  INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref) VALUES (v_b3, v_libB, 'C23-B3-' || v_suf) RETURNING id INTO v_h3B;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C23-A3-' || v_suf, 'C23-' || v_suf || '-3', v_libA, v_h3A, 'ambos', 'public') RETURNING id INTO v_x3;
  -- Le brouillon garde la cote LOCALE de A : la recherche par cote ne trouve
  -- rien en B.
  INSERT INTO public.exemplar_drafts (action, status, published_exemplar_id, target_library_id, target_bib_ref, tombo)
  VALUES ('update', 'draft', v_x3, v_libB, 'C23-A3-' || v_suf, 'C23-' || v_suf || '-3') RETURNING id INTO v_d3;
  v_t := 'T5 le fonds existant de la notice dans la cible sert, sans doublon';
  BEGIN
    PERFORM public.publish_exemplar_draft(v_d3);
    SELECT count(*) INTO v_n FROM public.book_holdings WHERE book_id = v_b3 AND library_id = v_libB;
    IF v_n = 1
       AND (SELECT holding_id FROM public.exemplares WHERE id = v_x3) = v_h3B
       AND (SELECT library_id FROM public.exemplares WHERE id = v_x3) = v_libB
       AND (SELECT bib_ref FROM public.exemplares WHERE id = v_x3) = 'C23-B3-' || v_suf
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO, fonds en B : '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── republication dans la même bibliothèque ─────────────────────────
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C23 sur place (essai)', 'C23-4-' || v_suf, 'livro') RETURNING id INTO v_b4;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b4, v_libA) RETURNING id INTO v_h4A;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C23-4-' || v_suf, 'C23-' || v_suf || '-4', v_libA, v_h4A, 'ambos', 'public') RETURNING id INTO v_x4;
  INSERT INTO public.exemplar_drafts (action, status, published_exemplar_id, target_library_id, target_bib_ref, tombo, notes)
  VALUES ('update', 'draft', v_x4, v_libA, 'C23-4-' || v_suf, 'C23-' || v_suf || '-4', 'C23 retouche') RETURNING id INTO v_d4;
  v_t := 'T6 une republication sur place garde son fonds et n''en crée aucun';
  BEGIN
    PERFORM public.publish_exemplar_draft(v_d4);
    SELECT count(*) INTO v_n FROM public.book_holdings WHERE book_id = v_b4;
    IF v_n = 1
       AND (SELECT holding_id FROM public.exemplares WHERE id = v_x4) = v_h4A
       AND (SELECT notes FROM public.exemplares WHERE id = v_x4) = 'C23 retouche'
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO, fonds : '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  PERFORM set_config('request.jwt.claims', '', true);
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'FONDS-CREE OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'FONDS-CREE ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
