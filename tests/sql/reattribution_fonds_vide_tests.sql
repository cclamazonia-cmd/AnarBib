-- =====================================================================
-- AnarBib — Tests : une réattribution ne laisse pas de fonds vide
-- Date    : 2026-09-29
-- Réf     : 20260929151902_une_reattribution_ne_laisse_pas_de_fonds_vide.sql
--           registre CAT-E19 (amende CAT-E14)
--
-- CE QUE CETTE SUITE PROUVE, en EMPRUNTANT les deux fonctions comme le
-- panneau de réattribution (admin réseau) :
--   · un aller-retour A → B → A ne laisse aucun fonds vide, la fiche publique
--     compte UNE bibliothèque (le 29/09, la notice 771 en comptait deux :
--     « BLMF — 0 exemplaire »), et le fonds revient tel qu'il était — cote
--     locale, prêtabilité, notes — avec la cote de ses exemplaires ;
--   · chaque fonds supprimé est gardé entier au journal du catalogue, même
--     quand l'admin réseau est staff de la cible (le journal réseau, lui, ne
--     s'écrit pas alors) ;
--   · les brouillons publiés des exemplaires déplacés suivent leur exemplaire
--     et sortent du lot d'une autre bibliothèque ;
--   · un fonds DÉJÀ vide avant l'appel (notice importée sans exemplaire) n'est
--     pas touché ;
--   · un fonds auquel quelque chose renvoie — ligne de prêt, de PEB (clé
--     RESTRICT), de réservation, de consultation, brouillon ouvert par son
--     identifiant ou par sa cote — reste, sans erreur, et la réponse le nomme ;
--     un brouillon ANNULÉ ne le retient pas ;
--   · l'état de collection d'une revue est recompté ;
--   · un non-admin est refusé ; les droits ne changent pas.
-- Avant le 29/09, aucune suite n'empruntait ces deux fonctions.
--
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'REATTRIBUTION FONDS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_admin uuid := gen_random_uuid();
  v_autre uuid := gen_random_uuid();
  v_suf text; v_cote text;
  v_libA uuid; v_libB uuid; v_libC uuid; v_lotA bigint; v_serie bigint;
  v_b1 bigint; v_b2 bigint; v_b10 bigint; v_b11 bigint;
  v_h1 bigint; v_h2 bigint; v_h2c bigint; v_h10 bigint; v_h11 bigint;
  v_x1 bigint; v_x2 bigint; v_x3 bigint;
  v_d1 bigint; v_emp bigint; v_peb bigint; v_res_id bigint; v_cons bigint;
  -- notices « à renvoi » : 3 prêt, 4 PEB, 5 brouillon ouvert, 6 réservation,
  -- 7 consultation, 8 brouillon ouvert par sa cote, 9 brouillon annulé
  v_bk bigint[] := ARRAY[]::bigint[]; v_hk bigint[] := ARRAY[]::bigint[]; v_xk bigint[] := ARRAY[]::bigint[];
  v_k int; v_id bigint; v_hid bigint; v_xid bigint;
  v_res jsonb; v_res2 jsonb; v_n int; v_hB bigint; v_hA bigint; v_setup text; v_txt text;
  v_row record;
BEGIN
  -- Le webhook de notification PEB fait un appel réseau sous secret, absent du
  -- banc ; il est hors sujet ici (comme dans paquet_peb_ill_lifecycle_tests).
  ALTER TABLE public.interlibrary_loans_v2 DISABLE TRIGGER trg_interlibrary_loan_enqueue_notifications;

  -- ── Décor ───────────────────────────────────────────────────────────
  v_suf := substr(replace(v_admin::text, '-', ''), 1, 8);
  v_cote := 'COTE-LOC-' || v_suf;
  INSERT INTO auth.users (id, email) VALUES
    (v_admin, 'reat-admin-' || v_suf || '@example.invalid'),
    (v_autre, 'reat-autre-' || v_suf || '@example.invalid');
  INSERT INTO public.profiles (id) VALUES (v_admin), (v_autre) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');

  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('reat-a-' || v_suf, 'Réattribution A', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('reat-b-' || v_suf, 'Réattribution B', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_libB;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('reat-c-' || v_suf, 'Réattribution C', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_libC;
  -- L'admin réseau est AUSSI coordination de C (cas du journal réseau muet).
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_autre, v_libA, 'reader', 'active', true),
    (v_admin, v_libC, 'coordenador', 'active', true);
  INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('Lot de A (réattribution)', v_admin, v_libA) RETURNING id INTO v_lotA;

  -- Notice 1 : deux exemplaires en A, dans un fonds qui a sa cote locale, sa
  -- note, et n'est pas prêtable ; un brouillon publié rangé dans le lot de A.
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('A Revolução desconhecida (essai)', 'REAT-1-' || v_suf, 'livro') RETURNING id INTO v_b1;
  INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref, loanable, notes)
  VALUES (v_b1, v_libA, v_cote, false, 'note du fonds A') RETURNING id INTO v_h1;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES (v_cote, 'REAT-' || v_suf || '-1', v_libA, v_h1, 'ambos', 'public') RETURNING id INTO v_x1;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES (v_cote, 'REAT-' || v_suf || '-2', v_libA, v_h1, 'ambos', 'public') RETURNING id INTO v_x2;
  INSERT INTO public.exemplar_drafts (action, status, target_library_id, target_holding_id, published_exemplar_id, tombo, batch_id)
  VALUES ('create', 'published', v_libA, v_h1, v_x1, 'REAT-' || v_suf || '-1', v_lotA) RETURNING id INTO v_d1;

  -- Notice 2 : un exemplaire en A, et un fonds C déjà vide (légitime : IMP-25).
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Notice 2 (essai)', 'REAT-2-' || v_suf, 'livro') RETURNING id INTO v_b2;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b2, v_libA) RETURNING id INTO v_h2;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_b2, v_libC, 0, 0) RETURNING id INTO v_h2c;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('REAT-2-' || v_suf, 'REAT-' || v_suf || '-3', v_libA, v_h2, 'ambos', 'public') RETURNING id INTO v_x3;

  -- Notices 3 à 9 : un exemplaire en A chacune ; leur fonds recevra un renvoi.
  FOR v_k IN 3 .. 9 LOOP
    INSERT INTO public.books (titulo, bib_ref, tipo_material)
    VALUES ('Notice ' || v_k || ' (essai)', 'REAT-' || v_k || '-' || v_suf, 'livro') RETURNING id INTO v_id;
    INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref)
    VALUES (v_id, v_libA, CASE WHEN v_k = 8 THEN v_cote || '-8' END) RETURNING id INTO v_hid;
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
    VALUES ('REAT-' || v_k || '-' || v_suf, 'REAT-' || v_suf || '-x' || v_k, v_libA, v_hid, 'ambos', 'public') RETURNING id INTO v_xid;
    v_bk := v_bk || v_id; v_hk := v_hk || v_hid; v_xk := v_xk || v_xid;
  END LOOP;
  -- (indices : v_bk[1] = notice 3, … v_bk[7] = notice 9)

  -- Notice 10 : réattribuée vers C, dont l'admin est coordination.
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Notice 10 (essai)', 'REAT-10-' || v_suf, 'livro') RETURNING id INTO v_b10;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b10, v_libA) RETURNING id INTO v_h10;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('REAT-10-' || v_suf, 'REAT-' || v_suf || '-10', v_libA, v_h10, 'ambos', 'public');

  -- Notice 11 : un fascicule de revue ; A a déclaré l'état de collection.
  INSERT INTO public.serials (slug, uniform_title) VALUES ('reat-revue-' || v_suf, 'Revue (essai)') RETURNING id INTO v_serie;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, serial_id, ano)
  VALUES ('Revue (essai), n° 1', 'REAT-11-' || v_suf, 'periodico', v_serie, '1902') RETURNING id INTO v_b11;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b11, v_libA) RETURNING id INTO v_h11;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('REAT-11-' || v_suf, 'REAT-' || v_suf || '-11', v_libA, v_h11, 'ambos', 'public');
  INSERT INTO public.serial_holdings (serial_id, library_id, computed_count) VALUES (v_serie, v_libA, 1);

  -- Les renvois.
  v_setup := NULL;
  BEGIN
    -- 3 : une ligne de prêt
    INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
    VALUES (v_autre, v_libA, 'aberto', current_date + 30) RETURNING id INTO v_emp;
    INSERT INTO public.emprestimo_itens_v2 (emprestimo_id, line_no, sub_id, book_id, item_id, holding_id, bib_ref, due_at)
    VALUES (v_emp, 1, v_emp || '.1', v_bk[1], v_xk[1], v_hk[1], 'REAT-3-' || v_suf, current_date + 30);
    -- 4 : une ligne de PEB (clé RESTRICT)
    INSERT INTO public.interlibrary_loans_v2 (lender_library_id, borrower_library_id, initiated_by_library_id)
    VALUES (v_libA, v_libC, v_libA) RETURNING id INTO v_peb;
    INSERT INTO public.interlibrary_loan_items_v2 (interlibrary_loan_id, line_no, holding_id, item_id, bib_ref)
    VALUES (v_peb, 1, v_hk[2], v_xk[2], 'REAT-4-' || v_suf);
    -- 5 : un brouillon d'exemplaire ouvert, par l'identifiant du fonds
    INSERT INTO public.exemplar_drafts (action, status, target_library_id, target_holding_id, tombo)
    VALUES ('create', 'draft', v_libA, v_hk[3], 'REAT-' || v_suf || '-b5');
    -- 6 : une ligne de réservation — close : une réservation ACTIVE refuse
    -- désormais la réattribution (C14, 04/10/2026) ; son historique garde le fonds.
    INSERT INTO public.reservas_v2 (user_id, library_id, status_global) VALUES (v_autre, v_libA, 'ativa') RETURNING id INTO v_res_id;
    INSERT INTO public.reserva_linhas_v2 (reserva_id, line_no, book_id, holding_id, bib_ref, item_status, cancelled_at)
    VALUES (v_res_id, 1, v_bk[4], v_hk[4], 'REAT-6-' || v_suf, 'cancelada_biblioteca', now());
    -- 7 : une ligne de consultation (colonne sans clé étrangère)
    INSERT INTO public.consultas_locais_v2 (user_id, library_id, status_global, notes)
    VALUES (v_autre, v_libA, 'ativa', 'réattribution (essai)') RETURNING id INTO v_cons;
    INSERT INTO public.consulta_linhas_v2 (consulta_id, line_no, book_id, holding_id, item_id, bib_ref, titulo_cache, autor_cache, item_status, expires_at)
    VALUES (v_cons, 1, v_bk[5], v_hk[5], v_xk[5], 'REAT-7-' || v_suf, 'Notice 7', 'Essai', 'ativa', now() + interval '30 days');
    -- 8 : un brouillon ouvert qui vise le fonds par sa COTE (le pont le résoudra)
    INSERT INTO public.exemplar_drafts (action, status, target_library_id, target_holding_id, target_bib_ref, tombo)
    VALUES ('create', 'ready', v_libA, NULL, v_cote || '-8', 'REAT-' || v_suf || '-b8');
    -- 9 : un brouillon ANNULÉ qui vise le fonds — il ne le retient pas
    INSERT INTO public.exemplar_drafts (action, status, target_library_id, target_holding_id, tombo)
    VALUES ('create', 'cancelled', v_libA, v_hk[7], 'REAT-' || v_suf || '-b9');
  EXCEPTION WHEN OTHERS THEN v_setup := SQLSTATE || ' ' || SQLERRM;
  END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  -- ── T1 : l'aller A → B supprime le fonds A vidé ─────────────────────
  v_t := 'T1 aller A→B : le fonds A vidé disparaît';
  BEGIN
    v_res := public.network_admin_reassign_book_from_to_library(v_b1, v_libA, v_libB);
    v_hB := (v_res->>'target_holding')::bigint;
    IF (v_res->>'exemplares_moved')::int = 2
       AND jsonb_array_length(v_res->'holdings_deleted') = 1
       AND (v_res->'holdings_deleted'->0->>'id')::bigint = v_h1
       AND v_res->'holdings_kept' = 'null'::jsonb
       AND NOT EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_h1)
       AND (SELECT count(*) FROM public.exemplares WHERE holding_id = v_hB AND library_id = v_libB) = 2 THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res::text); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLSTATE || ' ' || SQLERRM);
  END;

  -- ── T2 : le brouillon publié suit son exemplaire et sort du lot de A ──
  v_t := 'T2 le brouillon publié suit son exemplaire (fonds, bibliothèque, lot)';
  SELECT target_holding_id, target_library_id, batch_id INTO v_row FROM public.exemplar_drafts WHERE id = v_d1;
  IF v_row.target_holding_id = v_hB AND v_row.target_library_id = v_libB AND v_row.batch_id IS NULL THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || row_to_json(v_row)::text); END IF;

  -- ── T3 : le fonds supprimé est au journal du catalogue, entier, chez A ─
  v_t := 'T3 trace au journal du catalogue, rattachée à la source';
  IF EXISTS (SELECT 1 FROM public.catalog_audit_log
              WHERE action = 'holding_removed_after_reassign' AND entity_type = 'book'
                AND entity_id = v_b1 AND library_id = v_libA AND actor_id = v_admin
                AND (details->'fonds'->>'id')::bigint = v_h1
                AND details->'fonds'->>'local_bib_ref' = v_cote
                AND details->'fonds'->>'notes' = 'note du fonds A'
                AND (details->'fonds'->>'loanable')::boolean = false
                AND (details->>'target_library_id')::uuid = v_libB) THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- ── T4 : le retour B → A rend tout : un fonds, sa cote, ses notes, « non prêtable »
  v_t := 'T4 retour B→A : un seul fonds, rendu tel qu''il était';
  BEGIN
    v_res2 := public.network_admin_reassign_book_from_to_library(v_b1, v_libB, v_libA);
    v_hA := (v_res2->>'target_holding')::bigint;
    SELECT count(*) INTO v_n FROM public.book_holdings WHERE book_id = v_b1;
    IF v_n = 1
       AND NOT EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_hB)
       AND EXISTS (SELECT 1 FROM public.book_holdings
                    WHERE id = v_hA AND library_id = v_libA AND local_bib_ref = v_cote
                      AND loanable = false AND notes = 'note du fonds A')
       AND (SELECT count(*) FROM public.exemplares
             WHERE holding_id = v_hA AND library_id = v_libA AND bib_ref = v_cote) = 2 THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : fonds ' || v_n || ', ' || v_res2::text);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLSTATE || ' ' || SQLERRM);
  END;

  -- ── T5 : la fiche publique compte UNE bibliothèque, lue en visiteur anonyme
  v_t := 'T5 la fiche publique (anon) compte une bibliothèque';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    SET LOCAL ROLE anon;
    SELECT to_jsonb(v)->>'bibliotecas_count' INTO v_txt FROM api.catalog_book_detail_public_v2 v WHERE v.id = v_b1;
    RESET ROLE;
    IF v_txt = '1' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLSTATE || ' ' || SQLERRM);
  END;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  -- ── T6 : le journal réseau porte aussi les fonds supprimés ───────────
  v_t := 'T6 le journal réseau porte holdings_deleted';
  IF EXISTS (SELECT 1 FROM public.network_admin_cross_library_actions_log
              WHERE action_type = 'reassign_book_from_to_library'
                AND (payload->>'book_id')::bigint = v_b1
                AND (payload->'holdings_deleted'->0->>'id')::bigint = v_h1) THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- ── T7 : transfert complet — le fonds C, déjà vide avant, n'est pas touché
  v_t := 'T7 to_library : fonds vidé supprimé, fonds déjà vide épargné';
  BEGIN
    v_res := public.network_admin_reassign_book_to_library(v_b2, v_libB);
    IF jsonb_array_length(v_res->'holdings_deleted') = 1
       AND (v_res->'holdings_deleted'->0->>'id')::bigint = v_h2
       AND NOT EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_h2)
       AND EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_h2c) THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res::text); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLSTATE || ' ' || SQLERRM);
  END;

  -- ── T8 à T13 : un renvoi garde le fonds, sans erreur, et la réponse le nomme
  --     T14 : un brouillon annulé ne le garde pas
  IF v_setup IS NOT NULL THEN
    v_failed := v_failed + 7; v_failures := v_failures || ('T8-T14 décor des renvois : ' || v_setup);
  ELSE
    FOR v_k IN 1 .. 7 LOOP
      v_t := 'T' || (v_k + 7) || ' ' || (ARRAY['une ligne de prêt garde le fonds',
                                               'une ligne de PEB (clé RESTRICT) garde le fonds, sans 23503',
                                               'un brouillon ouvert (par identifiant) garde le fonds',
                                               'une ligne de réservation garde le fonds',
                                               'une ligne de consultation garde le fonds',
                                               'un brouillon ouvert qui vise la cote garde le fonds',
                                               'un brouillon annulé ne garde pas le fonds'])[v_k];
      BEGIN
        v_res := public.network_admin_reassign_book_from_to_library(v_bk[v_k], v_libA, v_libB);
        IF v_k < 7 THEN
          IF v_res->'holdings_deleted' = '[]'::jsonb
             AND v_res->'holdings_kept' = jsonb_build_array(v_hk[v_k])
             AND EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_hk[v_k]) THEN
            v_passed := v_passed + 1;
          ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res::text); END IF;
        ELSE
          IF jsonb_array_length(v_res->'holdings_deleted') = 1
             AND NOT EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_hk[v_k]) THEN
            v_passed := v_passed + 1;
          ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res::text); END IF;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLSTATE || ' ' || SQLERRM);
      END;
    END LOOP;
  END IF;

  -- ── T15 : l'admin est staff de la cible — la trace s'écrit quand même ─
  v_t := 'T15 admin staff de la cible : trace au journal du catalogue malgré tout';
  BEGIN
    v_res := public.network_admin_reassign_book_from_to_library(v_b10, v_libA, v_libC);
    IF jsonb_array_length(v_res->'holdings_deleted') = 1
       AND EXISTS (SELECT 1 FROM public.catalog_audit_log
                    WHERE action = 'holding_removed_after_reassign' AND entity_id = v_b10
                      AND (details->'fonds'->>'id')::bigint = v_h10) THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res::text); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLSTATE || ' ' || SQLERRM);
  END;

  -- ── T16 : l'état de collection de la revue est recompté ─────────────
  v_t := 'T16 état de collection recompté (source 0, cible 1)';
  BEGIN
    PERFORM public.network_admin_reassign_book_from_to_library(v_b11, v_libA, v_libB);
    IF (SELECT computed_count FROM public.serial_holdings WHERE serial_id = v_serie AND library_id = v_libA) = 0
       AND (SELECT computed_count FROM public.serial_holdings WHERE serial_id = v_serie AND library_id = v_libB) = 1 THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLSTATE || ' ' || SQLERRM);
  END;

  -- ── T17 : un non-admin est refusé, et rien n'est supprimé ────────────
  v_t := 'T17 un non-admin est refusé';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_autre, 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM public.network_admin_reassign_book_from_to_library(v_b1, v_libA, v_libB);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : la réattribution est passée');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE 'Acesso restrito%' AND EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_hA) THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLSTATE || ' ' || SQLERRM); END IF;
  END;

  -- ── T18 : droits inchangés — authenticated seulement, pas anon ───────
  v_t := 'T18 droits : authenticated, pas anon';
  IF has_function_privilege('authenticated', 'public.network_admin_reassign_book_from_to_library(bigint, uuid, uuid)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.network_admin_reassign_book_to_library(bigint, uuid)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.network_admin_reassign_book_from_to_library(bigint, uuid, uuid)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.network_admin_reassign_book_to_library(bigint, uuid)', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'REATTRIBUTION FONDS ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed,
      array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'REATTRIBUTION FONDS OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
