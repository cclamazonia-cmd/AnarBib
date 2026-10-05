-- =====================================================================
-- AnarBib — Tests : C14 lot A — un brouillon périmé ne ramène pas
-- l'exemplaire ; la corbeille rend un brouillon dont le fonds a disparu.
-- Date    : 2026-10-04
-- Réf     : supabase/migrations/20261005074236_un_exemplaire_qui_change_de_bibliotheque_n_emporte_que_lui.sql
--
-- La suite EMPRUNTE les vrais chemins, sous une session d'admin réseau :
--   · la réattribution (A → B) marque le brouillon OUVERT de l'exemplaire et
--     garde le fonds source, auquel ce brouillon renvoie (holdings_kept) ;
--   · publier ce brouillon est REFUSÉ (error.publish.exemplar_moved),
--     l'exemplaire reste en B ;
--   · un changement de bibliothèque VOULU (brouillon neuf, cible C) passe,
--     et marque les autres brouillons ouverts de l'exemplaire ;
--   · un brouillon supprimé dont le fonds a disparu depuis revient de la
--     corbeille, sans fonds (au lieu d'un 23503) ;
--   · (3) la règle de CAT-E19 au désherbage et au déplacement d'un exemplaire
--     isolé : le fonds vidé disparaît (trace au journal), sauf renvoi ;
--   · (2) un PEB ouvert compte là où est son exemplaire ; un PEB clos ne
--     retient plus rien ;
--   · (2 bis) une réservation active sur un fonds source refuse la
--     réattribution ; un PEB déclaré rendu (ou annulé) à la main clôt ses lignes.
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'BROUILLON-PERIME OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_admin uuid := gen_random_uuid();
  v_suf text;
  v_libA uuid; v_libB uuid; v_libC uuid;
  v_b1 bigint; v_hA bigint; v_x1 bigint;
  v_d1 bigint; v_d2 bigint; v_d4 bigint;
  v_b2 bigint; v_hZ bigint; v_d5 bigint; v_audit bigint;
  v_res jsonb; v_txt text; v_hint text; v_lib uuid; v_n int; v_ts timestamptz;
  v_b3 bigint; v_hD bigint; v_xD bigint; v_b4 bigint; v_hK bigint; v_xK bigint;
  v_b5 bigint; v_hE bigint; v_xE bigint; v_dE bigint;
  v_b6 bigint; v_h6A bigint; v_h6B bigint; v_x6 bigint; v_b7 bigint; v_h7 bigint; v_x7 bigint; v_peb bigint;
  v_b8 bigint; v_h8 bigint; v_x8 bigint; v_r8 bigint;
  v_x9 bigint; v_x10 bigint;
BEGIN
  v_suf := substr(replace(v_admin::text, '-', ''), 1, 8);
  INSERT INTO auth.users (id, email) VALUES (v_admin, 'c14-admin-' || v_suf || '@example.invalid');
  INSERT INTO public.profiles (id) VALUES (v_admin) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('c14-a-' || v_suf, 'C14 A (essai)', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('c14-b-' || v_suf, 'C14 B (essai)', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_libB;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('c14-c-' || v_suf, 'C14 C (essai)', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_libC;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C14 (essai)', 'C14-1-' || v_suf, 'livro') RETURNING id INTO v_b1;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b1, v_libA) RETURNING id INTO v_hA;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C14-1-' || v_suf, 'C14-' || v_suf || '-1', v_libA, v_hA, 'ambos', 'public') RETURNING id INTO v_x1;
  -- Un brouillon OUVERT de l'exemplaire, ouvert quand il était en A.
  INSERT INTO public.exemplar_drafts (action, status, published_exemplar_id, target_library_id, target_holding_id, target_bib_ref, tombo)
  VALUES ('update', 'draft', v_x1, v_libA, v_hA, 'C14-1-' || v_suf, 'C14-' || v_suf || '-1') RETURNING id INTO v_d1;

  -- ── (1) la réattribution marque, la publication refuse ─────────────
  v_res := public.network_admin_reassign_book_from_to_library(v_b1, v_libA, v_libB);

  v_t := 'T1 la réattribution déplace l''exemplaire et marque son brouillon ouvert';
  IF (SELECT library_id FROM public.exemplares WHERE id = v_x1) = v_libB
     AND (SELECT exemplar_moved_at FROM public.exemplar_drafts WHERE id = v_d1) IS NOT NULL
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_res::text,'NULL')); END IF;

  v_t := 'T2 le fonds source auquel le brouillon renvoie est gardé, et la réponse le nomme (holdings_kept)';
  IF EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_hA)
     AND v_res->'holdings_kept' @> to_jsonb(ARRAY[v_hA])
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_res->>'holdings_kept','NULL')); END IF;

  v_t := 'T3 publier le brouillon périmé est refusé, l''exemplaire reste en B';
  v_hint := NULL;
  BEGIN
    PERFORM public.publish_exemplar_draft(v_d1);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
  END;
  IF v_hint = 'error.publish.exemplar_moved'
     AND (SELECT library_id FROM public.exemplares WHERE id = v_x1) = v_libB
     AND (SELECT status FROM public.exemplar_drafts WHERE id = v_d1) = 'draft'
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'aucun')); END IF;

  -- ── un changement de bibliothèque VOULU passe, et marque les autres ─
  -- Deux brouillons neufs, ouverts l'exemplaire étant en B : l'un le veut
  -- en C (le geste voulu), l'autre reste en B.
  -- Le brouillon porte le tombo de l'exemplaire, comme le formulaire : sans
  -- lui, changer de bibliothèque en demanderait un neuf à la numérotation de C.
  -- Et C a déjà son fonds de la notice : publish_exemplar_draft le trouve par
  -- la cote, il ne le crée pas.
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b1, v_libC);
  INSERT INTO public.exemplar_drafts (action, status, published_exemplar_id, target_library_id, target_bib_ref, tombo)
  VALUES ('update', 'draft', v_x1, v_libC, 'C14-1-' || v_suf, 'C14-' || v_suf || '-1') RETURNING id INTO v_d2;
  INSERT INTO public.exemplar_drafts (action, status, published_exemplar_id, target_library_id, target_bib_ref)
  VALUES ('update', 'draft', v_x1, v_libB, 'C14-1-' || v_suf) RETURNING id INTO v_d4;
  v_t := 'T4 un brouillon non marqué déplace l''exemplaire vers sa cible (le geste voulu)';
  BEGIN
    PERFORM public.publish_exemplar_draft(v_d2);
    IF (SELECT library_id FROM public.exemplares WHERE id = v_x1) = v_libC
       AND (SELECT status FROM public.exemplar_drafts WHERE id = v_d2) = 'published'
       AND (SELECT exemplar_moved_at FROM public.exemplar_drafts WHERE id = v_d2) IS NULL
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  v_t := 'T5 ce déplacement marque l''AUTRE brouillon ouvert (cible B), pas le brouillon publié';
  IF (SELECT exemplar_moved_at FROM public.exemplar_drafts WHERE id = v_d4) IS NOT NULL
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  v_t := 'T6 et ce brouillon-là est refusé à son tour';
  v_hint := NULL;
  BEGIN
    PERFORM public.publish_exemplar_draft(v_d4);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
  END;
  IF v_hint = 'error.publish.exemplar_moved' AND (SELECT library_id FROM public.exemplares WHERE id = v_x1) = v_libC
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'aucun')); END IF;

  -- ── (4) la corbeille rend un brouillon dont le fonds a disparu ─────
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C14 corbeille (essai)', 'C14-2-' || v_suf, 'livro') RETURNING id INTO v_b2;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b2, v_libA) RETURNING id INTO v_hZ;
  INSERT INTO public.exemplar_drafts (action, status, target_library_id, target_holding_id, target_bib_ref, tombo)
  VALUES ('create', 'draft', v_libA, v_hZ, 'C14-2-' || v_suf, 'C14-' || v_suf || '-2') RETURNING id INTO v_d5;
  DELETE FROM public.exemplar_drafts WHERE id = v_d5;
  DELETE FROM public.book_holdings WHERE id = v_hZ;
  SELECT max(id) INTO v_audit FROM public.catalog_audit_log
   WHERE action = 'delete' AND details->>'source_table' = 'exemplar_drafts'
     AND (details->'snapshot'->>'id')::bigint = v_d5;

  v_t := 'T7 le brouillon supprimé revient de la corbeille, sans le fonds disparu';
  BEGIN
    IF v_audit IS NULL THEN RAISE EXCEPTION 'SETUP : aucune trace de suppression pour le brouillon %', v_d5; END IF;
    v_res := public.fn_restore_deleted_draft(v_audit);
    IF (v_res->>'ok') = 'true'
       AND EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE id = v_d5 AND target_holding_id IS NULL AND target_library_id = v_libA)
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_res::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLSTATE||' '||SQLERRM);
  END;

  -- ── (3) la règle de CAT-E19 au désherbage et à la publication ──────
  -- Le désherbage demande de gérer la bibliothèque : l'admin coordonne A.
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_admin, v_libA, 'coordenador', 'active', true);

  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C14 désherbage (essai)', 'C14-3-' || v_suf, 'livro') RETURNING id INTO v_b3;
  INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref) VALUES (v_b3, v_libA, 'COTE-C14-3-' || v_suf) RETURNING id INTO v_hD;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C14-3-' || v_suf, 'C14-' || v_suf || '-3', v_libA, v_hD, 'ambos', 'public') RETURNING id INTO v_xD;
  v_t := 'T8 un désherbage qui vide son fonds le supprime, gardé entier au journal';
  BEGIN
    PERFORM public.discard_exemplar(v_xD);
    IF NOT EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_hD)
       AND EXISTS (SELECT 1 FROM public.catalog_audit_log
                    WHERE action = 'holding_removed_after_discard' AND entity_id = v_b3
                      AND (details->'fonds'->>'id')::bigint = v_hD
                      AND details->'fonds'->>'local_bib_ref' = 'COTE-C14-3-' || v_suf
                      AND (details->>'exemplar_id')::bigint = v_xD)
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C14 renvoi (essai)', 'C14-4-' || v_suf, 'livro') RETURNING id INTO v_b4;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b4, v_libA) RETURNING id INTO v_hK;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C14-4-' || v_suf, 'C14-' || v_suf || '-4', v_libA, v_hK, 'ambos', 'public') RETURNING id INTO v_xK;
  INSERT INTO public.exemplar_drafts (action, status, target_library_id, target_holding_id, target_bib_ref, tombo)
  VALUES ('create', 'draft', v_libA, v_hK, 'C14-4-' || v_suf, 'C14-' || v_suf || '-4b');
  v_t := 'T9 un fonds vidé auquel un brouillon ouvert renvoie reste';
  BEGIN
    PERFORM public.discard_exemplar(v_xK);
    IF EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_hK)
       AND NOT EXISTS (SELECT 1 FROM public.catalog_audit_log WHERE action = 'holding_removed_after_discard' AND entity_id = v_b4)
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C14 déplacement (essai)', 'C14-5-' || v_suf, 'livro') RETURNING id INTO v_b5;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b5, v_libA) RETURNING id INTO v_hE;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C14-5-' || v_suf, 'C14-' || v_suf || '-5', v_libA, v_hE, 'ambos', 'public') RETURNING id INTO v_xE;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b5, v_libC);
  INSERT INTO public.exemplar_drafts (action, status, published_exemplar_id, target_library_id, target_bib_ref, tombo)
  VALUES ('update', 'draft', v_xE, v_libC, 'C14-5-' || v_suf, 'C14-' || v_suf || '-5') RETURNING id INTO v_dE;
  v_t := 'T10 publier un exemplaire vers une autre bibliothèque supprime le fonds qu''il vide (trace au journal)';
  BEGIN
    PERFORM public.publish_exemplar_draft(v_dE);
    IF (SELECT library_id FROM public.exemplares WHERE id = v_xE) = v_libC
       AND NOT EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_hE)
       AND EXISTS (SELECT 1 FROM public.catalog_audit_log
                    WHERE action = 'holding_removed_after_reassign' AND entity_id = v_b5
                      AND (details->'fonds'->>'id')::bigint = v_hE
                      AND details->>'via' = 'publish_exemplar_draft')
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  v_t := 'T11 la règle n''est qu''aux mains des fonctions : ni anon ni authenticated ne l''appellent';
  IF NOT has_function_privilege('anon', 'private.fn_fonds_vides_menage(bigint[],text,jsonb)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'private.fn_fonds_vides_menage(bigint[],text,jsonb)', 'EXECUTE')
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  -- ── (2) la disponibilité suit l'exemplaire en PEB ───────────────────
  -- Le webhook de notification PEB appelle le réseau sous secret, absent du
  -- banc (comme reattribution_fonds_vide_tests).
  ALTER TABLE public.interlibrary_loans_v2 DISABLE TRIGGER trg_interlibrary_loan_enqueue_notifications;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C14 PEB (essai)', 'C14-6-' || v_suf, 'livro') RETURNING id INTO v_b6;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b6, v_libA) RETURNING id INTO v_h6A;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b6, v_libB) RETURNING id INTO v_h6B;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C14-6-' || v_suf, 'C14-' || v_suf || '-6', v_libA, v_h6A, 'ambos', 'public') RETURNING id INTO v_x6;
  INSERT INTO public.interlibrary_loans_v2 (lender_library_id, borrower_library_id, initiated_by_library_id)
  VALUES (v_libA, v_libC, v_libA) RETURNING id INTO v_peb;
  UPDATE public.interlibrary_loans_v2 SET status_global = 'aguardando_saida' WHERE id = v_peb;
  UPDATE public.interlibrary_loans_v2 SET status_global = 'emprestado' WHERE id = v_peb;
  INSERT INTO public.interlibrary_loan_items_v2 (interlibrary_loan_id, line_no, holding_id, item_id, bib_ref, item_status)
  VALUES (v_peb, 1, v_h6A, v_x6, 'C14-6-' || v_suf, 'emprestado');
  -- L'exemplaire change de fonds (de A à B) pendant qu'il est en PEB.
  UPDATE public.exemplares SET holding_id = v_h6B, library_id = v_libB WHERE id = v_x6;
  PERFORM public.fn_v2_recompute_holdings_availability(ARRAY[v_h6A, v_h6B], ARRAY[v_b6]);
  v_t := 'T12 un PEB ouvert compte là où est son exemplaire : la cible ne l''affiche pas disponible';
  IF (SELECT available_count FROM public.book_holdings WHERE id = v_h6B) = 0
     AND (SELECT exemplares_total FROM public.book_holdings WHERE id = v_h6B) = 1
    THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : dispo '||coalesce((SELECT available_count::text FROM public.book_holdings WHERE id = v_h6B),'NULL')); END IF;

  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C14 PEB clos (essai)', 'C14-7-' || v_suf, 'livro') RETURNING id INTO v_b7;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b7, v_libA) RETURNING id INTO v_h7;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C14-7-' || v_suf, 'C14-' || v_suf || '-7', v_libA, v_h7, 'ambos', 'public') RETURNING id INTO v_x7;
  INSERT INTO public.interlibrary_loans_v2 (lender_library_id, borrower_library_id, initiated_by_library_id)
  VALUES (v_libA, v_libC, v_libA) RETURNING id INTO v_peb;
  INSERT INTO public.interlibrary_loan_items_v2 (interlibrary_loan_id, line_no, holding_id, item_id, bib_ref, item_status)
  VALUES (v_peb, 1, v_h7, v_x7, 'C14-7-' || v_suf, 'emprestado');
  -- Rendu et clos, mais la ligne est restée « emprestado » (PEB 24 et 25, mai 2026).
  UPDATE public.interlibrary_loans_v2 SET status_global = 'aguardando_saida' WHERE id = v_peb;
  UPDATE public.interlibrary_loans_v2 SET status_global = 'emprestado' WHERE id = v_peb;
  UPDATE public.interlibrary_loans_v2 SET status_global = 'devolvido' WHERE id = v_peb;
  UPDATE public.interlibrary_loan_items_v2 SET item_status = 'emprestado' WHERE interlibrary_loan_id = v_peb;
  PERFORM public.fn_v2_recompute_holdings_availability(ARRAY[v_h7], ARRAY[v_b7]);
  v_t := 'T13 un PEB clos dont la ligne est restée « emprestado » ne retient plus l''exemplaire';
  IF (SELECT available_count FROM public.book_holdings WHERE id = v_h7) = 1
    THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : dispo '||coalesce((SELECT available_count::text FROM public.book_holdings WHERE id = v_h7),'NULL')); END IF;

  -- ── (2 bis) réservation active : la réattribution est refusée ───────
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('C14 réservée (essai)', 'C14-8-' || v_suf, 'livro') RETURNING id INTO v_b8;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b8, v_libA) RETURNING id INTO v_h8;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C14-8-' || v_suf, 'C14-' || v_suf || '-8', v_libA, v_h8, 'ambos', 'public') RETURNING id INTO v_x8;
  INSERT INTO public.reservas_v2 (user_id, library_id, status_global) VALUES (v_admin, v_libA, 'ativa') RETURNING id INTO v_r8;
  INSERT INTO public.reserva_linhas_v2 (reserva_id, line_no, book_id, holding_id, bib_ref, item_status)
  VALUES (v_r8, 1, v_b8, v_h8, 'C14-8-' || v_suf, 'ativa');
  v_t := 'T14 une réservation active sur le fonds source refuse la réattribution, rien ne bouge';
  v_hint := NULL;
  BEGIN
    PERFORM public.network_admin_reassign_book_from_to_library(v_b8, v_libA, v_libB);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
  END;
  IF v_hint = 'error.reassign.active_reservation'
     AND (SELECT library_id FROM public.exemplares WHERE id = v_x8) = v_libA
     AND EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_h8)
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'aucun')); END IF;

  v_t := 'T15 la réservation traitée, la réattribution passe';
  UPDATE public.reserva_linhas_v2 SET item_status = 'cancelada_biblioteca', cancelled_at = now() WHERE reserva_id = v_r8;
  BEGIN
    PERFORM public.network_admin_reassign_book_from_to_library(v_b8, v_libA, v_libB);
    IF (SELECT library_id FROM public.exemplares WHERE id = v_x8) = v_libB
      THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── (2 bis) un PEB déclaré rendu à la main clôt ses lignes ──────────
  -- Un exemplaire ne figure que sur une ligne de PEB ouverte à la fois : deux neufs.
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C14-7-' || v_suf, 'C14-' || v_suf || '-9', v_libA, v_h7, 'ambos', 'public') RETURNING id INTO v_x9;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('C14-7-' || v_suf, 'C14-' || v_suf || '-10', v_libA, v_h7, 'ambos', 'public') RETURNING id INTO v_x10;
  INSERT INTO public.interlibrary_loans_v2 (lender_library_id, borrower_library_id, initiated_by_library_id)
  VALUES (v_libA, v_libC, v_libA) RETURNING id INTO v_peb;
  INSERT INTO public.interlibrary_loan_items_v2 (interlibrary_loan_id, line_no, holding_id, item_id, bib_ref, item_status)
  VALUES (v_peb, 1, v_h7, v_x9, 'C14-7-' || v_suf, 'reservado_para_saida');
  UPDATE public.interlibrary_loans_v2 SET status_global = 'aguardando_saida' WHERE id = v_peb;
  UPDATE public.interlibrary_loans_v2 SET status_global = 'emprestado' WHERE id = v_peb;
  -- Le geste de l'écran : fn_peb_update_status écrit le statut tel quel.
  UPDATE public.interlibrary_loans_v2 SET status_global = 'devolvido' WHERE id = v_peb;
  v_t := 'T16 un PEB déclaré rendu à la main clôt ses lignes (devolvido, date de retour)';
  IF (SELECT item_status FROM public.interlibrary_loan_items_v2 WHERE interlibrary_loan_id = v_peb) = 'devolvido'
     AND (SELECT returned_at FROM public.interlibrary_loan_items_v2 WHERE interlibrary_loan_id = v_peb) IS NOT NULL
    THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((SELECT item_status FROM public.interlibrary_loan_items_v2 WHERE interlibrary_loan_id = v_peb),'NULL')); END IF;

  INSERT INTO public.interlibrary_loans_v2 (lender_library_id, borrower_library_id, initiated_by_library_id)
  VALUES (v_libA, v_libC, v_libA) RETURNING id INTO v_peb;
  INSERT INTO public.interlibrary_loan_items_v2 (interlibrary_loan_id, line_no, holding_id, item_id, bib_ref, item_status)
  VALUES (v_peb, 1, v_h7, v_x10, 'C14-7-' || v_suf, 'reservado_para_saida');
  UPDATE public.interlibrary_loans_v2 SET status_global = 'cancelado' WHERE id = v_peb;
  v_t := 'T17 un PEB annulé clôt ses lignes en cancelado';
  IF (SELECT item_status FROM public.interlibrary_loan_items_v2 WHERE interlibrary_loan_id = v_peb) = 'cancelado'
    THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((SELECT item_status FROM public.interlibrary_loan_items_v2 WHERE interlibrary_loan_id = v_peb),'NULL')); END IF;

  PERFORM set_config('request.jwt.claims', '', true);
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'BROUILLON-PERIME OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'BROUILLON-PERIME ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
