-- =====================================================================
-- AnarBib — Tests d'acceptation : CYCLE DE VIE PEB + PARTAGE NUMERIQUE (ILL)
-- Date    : 2026-07-02  ·  Session : jonction ch.6 GLB v16 (deux lignes ~90%)
-- Objet   : comble le residuel CI du chapitre 6 (PEB + partage numerique sont
--           cables de bout en bout cote frontend, mais n'avaient AUCUN test de
--           cycle de vie automatise ; profils d'adoption en a un). Une fois vert,
--           les deux lignes passent de « Tenue (~90%) » a « Tenue » avec preuve.
--
-- Fonctions couvertes :
--   PEB  : fn_peb_authorized · fn_peb_create_loan_with_items · fn_peb_update_status
--          · fn_peb_update_item_status · fn_peb_archive_loan · fn_peb_unarchive_loan
--   ILL  : fn_ill_request · fn_ill_respond · fn_ill_start_digitization
--          · fn_ill_transmit · fn_ill_acknowledge · fn_ill_close
--          + rejets a garde explicite : livre a ISBN (ill_isbn_use_peb), decision invalide.
--   Hors perimetre SQL : fn_ill_signed_url (URL signee Storage, testee via l'Edge
--          Function read-ill-shared-asset).
--
-- USAGE : UN seul bloc DO, termine par 'PEB-ILL OK : N/N tests passes' (RAISE)
--   -> ROLLBACK total. Les fixtures (2 biblios federees + partenariat + droit
--   digital_share + PEB + share) ne touchent JAMAIS la prod.
-- FIXTURES dynamiques (pas d'UUID perissable, seed-compatible) : un admin reseau
--   satisfait user_can_manage_library ET user_can_act_as_staff_on_library sur toute
--   biblio ; modes = colonnes directes de public.libraries (federated + circulation).
-- =====================================================================
DO $peb$
DECLARE
  v_admin uuid := gen_random_uuid();
  v_libA uuid; v_libB uuid;
  v_book bigint; v_book_isbn bigint; v_holding bigint; v_item bigint;
  v_loan bigint; v_loanitem bigint;
  v_partnership uuid; v_asset bigint; v_share uuid;
  v_res jsonb; v_status text; v_n int; v_caught boolean;
  v_pass int := 0; v_total int := 0;
BEGIN
  -- Isolation : le webhook de notification PEB (trg_interlibrary_loan_enqueue_notifications)
  -- fait un net.http_post synchrone sous secret vault, indisponible en base CI et hors
  -- perimetre de ce test (on teste le state-machine PEB, pas l'integration webhook).
  -- On le desactive ; on GARDE trg_peb_propagate_status + trg_peb_validate_status_transition,
  -- eux testes ici. Tout est rollback en fin de bloc (le trigger est re-actif ensuite).
  ALTER TABLE public.interlibrary_loans_v2 DISABLE TRIGGER trg_interlibrary_loan_enqueue_notifications;

  -- ===== FIXTURES =====
  INSERT INTO auth.users (id, email) VALUES (v_admin, v_admin::text||'@peb-test.invalid');
  INSERT INTO profiles (id) VALUES (v_admin) ON CONFLICT (id) DO NOTHING;
  INSERT INTO network_administrators (user_id, status) VALUES (v_admin, 'active');

  INSERT INTO libraries (slug, name, network_mode, circulation_mode, is_active)
    VALUES ('peb-test-a-'||substr(v_admin::text,1,8), 'PEB Test A', 'federated', 'full_sigb', true) RETURNING id INTO v_libA;
  INSERT INTO libraries (slug, name, network_mode, circulation_mode, is_active)
    VALUES ('peb-test-b-'||substr(v_admin::text,1,8), 'PEB Test B', 'federated', 'full_sigb', true) RETURNING id INTO v_libB;

  INSERT INTO books DEFAULT VALUES RETURNING id INTO v_book;
  INSERT INTO books (isbn) VALUES ('978-test-'||substr(v_admin::text,1,6)) RETURNING id INTO v_book_isbn;
  INSERT INTO book_holdings (book_id, library_id) VALUES (v_book, v_libA) RETURNING id INTO v_holding;
  INSERT INTO exemplares (bib_ref, tombo, library_id, circulation_policy, holding_id)
    VALUES ('PEB-TEST-REF', 'PEB-TOMBO-1', v_libA, 'emprestavel', v_holding) RETURNING id INTO v_item;

  INSERT INTO library_partnerships (library_id, partner_library_id, status)
    VALUES (v_libA, v_libB, 'active') RETURNING id INTO v_partnership;
  INSERT INTO partnership_rights (partnership_id, right_key) VALUES (v_partnership, 'digital_share');
  INSERT INTO digital_assets (title, source_name, bucket_name, object_path, asset_kind, is_public)
    VALUES ('PEB Test Asset', 'test', 'pdf-restrito', 'test/peb-ill.pdf', 'pdf', false) RETURNING id INTO v_asset;

  -- Config des transitions de statut PEB : presente en prod, mais ABSENTE de la
  -- base CI reconstruite (non peuplee par une migration). On seede les cibles
  -- utilisees (ON CONFLICT DO NOTHING -> no-op en prod, ajout rollback en CI).
  INSERT INTO interlibrary_loan_status_transitions (from_status, to_status) VALUES
    ('preparacao','aguardando_saida'),
    ('aguardando_saida','emprestado'),
    ('emprestado','devolvido'),
    ('emprestado','parcialmente_devolvido')
  ON CONFLICT DO NOTHING;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin::text, 'role','authenticated')::text, true);

  -- ================= PEB =================
  v_total:=v_total+1;
  IF public.fn_peb_authorized(v_libA, v_libB) THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T1 peb_authorized(A,B)'; END IF;

  v_total:=v_total+1;
  IF NOT public.fn_peb_authorized(v_libA, v_libA) THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T2 peb_authorized self'; END IF;

  v_total:=v_total+1;
  v_res := public.fn_peb_create_loan_with_items(
    jsonb_build_object('lender_library_id', v_libA, 'borrower_library_id', v_libB, 'initiated_by_library_id', v_libA),
    jsonb_build_array(jsonb_build_object('line_no',1,'holding_id',v_holding,'item_id',v_item,'bib_ref','PEB-TEST-REF')));
  v_loan := (v_res->'loan'->>'id')::bigint; v_loanitem := (v_res->'items'->0->>'id')::bigint;
  IF v_loan IS NOT NULL AND (v_res->'loan'->>'status_global')='preparacao' AND jsonb_array_length(v_res->'items')=1
    THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T3 create PEB: %', v_res; END IF;

  v_total:=v_total+1;
  PERFORM public.fn_peb_update_status(v_loan, 'aguardando_saida');
  SELECT status_global INTO v_status FROM interlibrary_loans_v2 WHERE id=v_loan;
  IF v_status='aguardando_saida' THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T4 status=%', v_status; END IF;

  v_total:=v_total+1;
  PERFORM public.fn_peb_update_status(v_loan, 'emprestado');
  SELECT status_global INTO v_status FROM interlibrary_loans_v2 WHERE id=v_loan;
  IF v_status='emprestado' THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T5 status=%', v_status; END IF;

  v_total:=v_total+1;
  v_res := public.fn_peb_update_item_status(v_loan, jsonb_build_array(jsonb_build_object('id', v_loanitem, 'new_status','devolvido')));
  IF (v_res->'items'->0->>'item_status')='devolvido' THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T6 item_status: %', v_res; END IF;

  v_total:=v_total+1;
  PERFORM public.fn_peb_archive_loan(v_loan);
  SELECT count(*) INTO v_n FROM interlibrary_loans_v2 WHERE id=v_loan AND archived_at IS NOT NULL;
  IF v_n=1 THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T7 archive'; END IF;

  v_total:=v_total+1;
  PERFORM public.fn_peb_unarchive_loan(v_loan);
  SELECT count(*) INTO v_n FROM interlibrary_loans_v2 WHERE id=v_loan AND archived_at IS NULL;
  IF v_n=1 THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T8 unarchive'; END IF;

  -- ================= ILL (partage numerique) =================
  v_total:=v_total+1;
  v_share := public.fn_ill_request(v_libA, v_libB, v_book, 'ponctuel', 'test');
  SELECT flux_state INTO v_status FROM ill_digital_shares WHERE id=v_share;
  IF v_share IS NOT NULL AND v_status='demande' THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T9 request=%', v_status; END IF;

  v_total:=v_total+1;
  PERFORM public.fn_ill_respond(v_share, 'accepte', NULL);
  SELECT flux_state INTO v_status FROM ill_digital_shares WHERE id=v_share;
  IF v_status='accepte' THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T10 respond=%', v_status; END IF;

  v_total:=v_total+1;
  PERFORM public.fn_ill_start_digitization(v_share);
  SELECT flux_state INTO v_status FROM ill_digital_shares WHERE id=v_share;
  IF v_status='numerisation' THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T11 digit=%', v_status; END IF;

  v_total:=v_total+1;
  PERFORM public.fn_ill_transmit(v_share, v_asset, 'staff_only');
  SELECT flux_state INTO v_status FROM ill_digital_shares WHERE id=v_share;
  IF v_status='transmis' THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T12 transmit=%', v_status; END IF;

  v_total:=v_total+1;
  PERFORM public.fn_ill_acknowledge(v_share);
  v_pass:=v_pass+1;

  v_total:=v_total+1;
  PERFORM public.fn_ill_close(v_share);
  SELECT flux_state INTO v_status FROM ill_digital_shares WHERE id=v_share;
  IF v_status='cloture' THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T14 close=%', v_status; END IF;

  -- rejets a garde explicite
  v_total:=v_total+1;
  BEGIN PERFORM public.fn_ill_request(v_libA, v_libB, v_book_isbn, 'ponctuel', NULL); v_caught:=false;
  EXCEPTION WHEN OTHERS THEN v_caught := (SQLERRM LIKE '%isbn_use_peb%'); END;
  IF v_caught THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T15 rejet ISBN non obtenu'; END IF;

  v_total:=v_total+1;
  BEGIN PERFORM public.fn_ill_respond(v_share, 'bogus', NULL); v_caught:=false;
  EXCEPTION WHEN OTHERS THEN v_caught := (SQLERRM LIKE '%invalid_decision%'); END;
  IF v_caught THEN v_pass:=v_pass+1; ELSE RAISE EXCEPTION 'T16 rejet decision non obtenu'; END IF;

  RAISE EXCEPTION 'PEB-ILL OK : %/% tests passes', v_pass, v_total;
END $peb$;
