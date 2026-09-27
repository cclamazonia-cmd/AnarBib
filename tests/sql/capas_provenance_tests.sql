-- =====================================================================
-- AnarBib — Tests d'acceptation : la provenance de la capa suit la couverture
-- Date : 2026-09-27 · Migration 20260927130518_capas_la_provenance_suit_la_couverture
--
-- POURQUOI. books.cover_source / cover_license existaient depuis le 05/06/2026
-- sans qu'aucun des trois endroits ne les recopie (brouillon envoyé par
-- l'écran, publish_book_draft, create_book_draft_from_book) : 0 capa attribuée
-- sur 250 en production. Leçon du 27/08 (serial_id) : pour un champ recopié,
-- tester les DEUX valeurs, renseignée ET nulle — un test qui ne couvre que le
-- chemin heureux donne la confiance sans la garantie.
--
-- Superutilisateur pour les fixtures, identité simulée d'un membre staff pour
-- les gardes de rôle des deux fonctions.
--   Bilan OK : 'CAPAS PROVENANCE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_staff uuid; v_lib uuid;
  v_draft bigint; v_book bigint; v_rep bigint;
  v_src text; v_lic text; v_path text;
  c_ref constant text := 'TEST-CAPAS-PROV-1';
  c_jpg constant text := 'books/TEST-CAPAS-PROV-1/front.jpg';
BEGIN
  SELECT m.user_id, m.library_id INTO v_staff, v_lib
    FROM public.user_library_memberships m
   WHERE m.status = 'active' AND m.role IN ('librarian','coordenador')
   ORDER BY (m.role = 'coordenador') DESC
   LIMIT 1;

  IF v_staff IS NULL THEN
    RAISE EXCEPTION 'CAPAS PROVENANCE ECHEC : aucun membre staff dans le seed, la suite ne peut rien mesurer.';
  END IF;

  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_staff, 'role', 'authenticated')::text, true);

  -- ── Publication d'une notice NEUVE ─────────────────────────────────
  v_t := 'T1 publication neuve : la notice reçoit la provenance et la licence du brouillon';
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material,
                                  owner_library_id, cover_object_path, cover_source, cover_license, created_by)
  VALUES ('create', 'draft', c_ref, 'Capa témoin', 'livro',
          v_lib, c_jpg, 'inventaire', 'CC-BY-SA-4.0', v_staff)
  RETURNING id INTO v_draft;
  v_book := public.publish_book_draft(v_draft);
  SELECT cover_source, cover_license INTO v_src, v_lic FROM public.books WHERE id = v_book;
  IF v_src = 'inventaire' AND v_lic = 'CC-BY-SA-4.0' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' source='||coalesce(v_src,'∅')||' licence='||coalesce(v_lic,'∅')); END IF;

  -- ── Reprise d'une notice en brouillon ──────────────────────────────
  v_t := 'T2 reprise : le brouillon emporte provenance et licence';
  v_rep := public.create_book_draft_from_book(v_book, NULL);
  SELECT cover_source, cover_license INTO v_src, v_lic FROM public.book_drafts WHERE id = v_rep;
  IF v_src = 'inventaire' AND v_lic = 'CC-BY-SA-4.0' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' source='||coalesce(v_src,'∅')||' licence='||coalesce(v_lic,'∅')); END IF;

  -- ── Republication : même image ─────────────────────────────────────
  v_t := 'T3 même image, brouillon SANS provenance (reprise d''avant la migration) : l''attribution connue reste';
  UPDATE public.book_drafts SET cover_source = NULL, cover_license = NULL WHERE id = v_rep;
  PERFORM public.publish_book_draft(v_rep);
  SELECT cover_source, cover_license INTO v_src, v_lic FROM public.books WHERE id = v_book;
  IF v_src = 'inventaire' AND v_lic = 'CC-BY-SA-4.0' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' source='||coalesce(v_src,'∅')||' (effacée)'); END IF;

  v_t := 'T4 même chemin, NOUVELLE provenance (candidate re-choisie) : la paire du brouillon, licence nulle comprise';
  -- Open Library et Inventaire écrivent au même chemin books/<clé>/front.jpg :
  -- garder la licence d'Inventaire à côté d'une image d'Open Library serait une
  -- attribution fausse.
  v_rep := public.create_book_draft_from_book(v_book, NULL);
  UPDATE public.book_drafts SET cover_source = 'openlibrary', cover_license = NULL WHERE id = v_rep;
  PERFORM public.publish_book_draft(v_rep);
  SELECT cover_source, cover_license INTO v_src, v_lic FROM public.books WHERE id = v_book;
  IF v_src = 'openlibrary' AND v_lic IS NULL THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' source='||coalesce(v_src,'∅')||' licence='||coalesce(v_lic,'∅')); END IF;

  -- ── Republication : autre image ────────────────────────────────────
  v_t := 'T5 autre image AVEC provenance : celle du brouillon';
  v_rep := public.create_book_draft_from_book(v_book, NULL);
  UPDATE public.book_drafts
     SET cover_object_path = 'books/TEST-CAPAS-PROV-1/front.png', cover_source = 'manual', cover_license = NULL
   WHERE id = v_rep;
  PERFORM public.publish_book_draft(v_rep);
  SELECT cover_object_path, cover_source, cover_license INTO v_path, v_src, v_lic FROM public.books WHERE id = v_book;
  IF v_path LIKE '%front.png' AND v_src = 'manual' AND v_lic IS NULL THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' chemin='||coalesce(v_path,'∅')||' source='||coalesce(v_src,'∅')||' licence='||coalesce(v_lic,'∅')); END IF;

  v_t := 'T6 autre image SANS provenance : rien n''est hérité de l''ancienne image';
  v_rep := public.create_book_draft_from_book(v_book, NULL);
  UPDATE public.book_drafts
     SET cover_object_path = 'books/TEST-CAPAS-PROV-1/front.webp', cover_source = NULL, cover_license = NULL
   WHERE id = v_rep;
  PERFORM public.publish_book_draft(v_rep);
  SELECT cover_source INTO v_src FROM public.books WHERE id = v_book;
  IF v_src IS NULL THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' source='||v_src||' (héritée d''une autre image)'); END IF;

  v_t := 'T7 capa retirée : ni chemin, ni provenance';
  UPDATE public.books SET cover_source = 'manual' WHERE id = v_book;
  v_rep := public.create_book_draft_from_book(v_book, NULL);
  UPDATE public.book_drafts SET cover_object_path = NULL, cover_source = NULL, cover_license = NULL WHERE id = v_rep;
  PERFORM public.publish_book_draft(v_rep);
  SELECT cover_object_path, cover_source INTO v_path, v_src FROM public.books WHERE id = v_book;
  IF v_path IS NULL AND v_src IS NULL THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' chemin='||coalesce(v_path,'∅')||' source='||coalesce(v_src,'∅')); END IF;

  -- ── Bilan (le RAISE annule toutes les fixtures) ────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'CAPAS PROVENANCE OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'CAPAS PROVENANCE ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
