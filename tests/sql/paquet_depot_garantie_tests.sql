-- =====================================================================
-- AnarBib — Tests d'acceptation : DÉPÔT DE GARANTIE (loan_deposits)
-- Date    : 2026-06-30  ·  Session : réflexion dépôt de garantie
-- Spec    : docs/specs/spec-depot-garantie.md (DEPOT-0…DEPOT-10)
-- Migration: 20260630082753_depot_garantie_couche_donnees.sql
--
-- USAGE : coller dans Supabase Studio SQL Editor et Run (ou psql / runner CI).
--   Tout est dans UN bloc DO $$ terminé par une EXCEPTION portant le bilan.
--   Cette EXCEPTION finale fait ROLLBACK de TOUTE la transaction → les fixtures
--   seedées (adhésion, emprunts, dépôts) ne touchent JAMAIS la prod.
--   - Bilan OK : 'DEPOT-GARANTIE OK : N/N tests passés (S skips)'
--   - Bilan KO : 'DEPOT-GARANTIE ECHEC : ...' + liste des échecs.
--
-- FIXTURES (dynamiques, pas d'UUID périssable) :
--   v_subject : profil SANS adhésion BLMF → emprunteur·se qu'on contrôle.
--   v_staff   : coordenador actif de BLMF → acteur staff (JWT simulé).
--   On seede une adhésion active non restreinte + membership_enabled=false
--   (le gate de circulation ne bloque que no_active_membership/restricted/dues)
--   pour pouvoir créer des emprunts de test sans heurter le gate.
--   BLMF (library) : 1234825f-a0f9-4fbd-a875-6551c30ea4ca
-- =====================================================================

DO $$
DECLARE
  v_passed  int := 0;
  v_failed  int := 0;
  v_skipped int := 0;
  v_failures text[] := ARRAY[]::text[];
  v_skips    text[] := ARRAY[]::text[];
  v_t text;

  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_subject uuid;
  v_staff   uuid;
  v_has_subject boolean;
  v_has_staff   boolean;
  v_has_loan    boolean := false;

  v_rule_id uuid;
  v_loan_a bigint; v_loan_b bigint; v_loan_c bigint;
  v_loan_d bigint; v_loan_e bigint; v_loan_f bigint;

  v_rec    record;
  v_dep_id  uuid;
  v_dep_id2 uuid;
  v_dep_c   uuid;
  v_dep_e   uuid;
  v_dep_f   uuid;
  v_amount  numeric;
  v_reason  text;
  v_cnt     int;
BEGIN
  -- ── Résolution des fixtures ────────────────────────────────────────
  SELECT p.id INTO v_subject
  FROM public.profiles p
  WHERE NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                    WHERE m.user_id = p.id AND m.library_id = c_blmf)
  LIMIT 1;
  v_has_subject := v_subject IS NOT NULL;

  SELECT m.user_id INTO v_staff
  FROM public.user_library_memberships m
  WHERE m.library_id = c_blmf AND m.role = 'coordenador' AND m.status = 'active'
  LIMIT 1;
  v_has_staff := v_staff IS NOT NULL;

  -- ── Seed commun ────────────────────────────────────────────────────
  UPDATE public.libraries SET deposit_enabled = true, membership_enabled = false WHERE id = c_blmf;

  INSERT INTO public.library_deposit_rules (library_id, scope, amount, currency, is_active, name)
  VALUES (c_blmf, 'per_loan', 3, 'EUR', true, '__TEST_DEPOT__')
  RETURNING id INTO v_rule_id;

  IF v_has_subject THEN
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_restricted)
    VALUES (v_subject, c_blmf, 'reader', 'active', false);

    -- Emprunts de FIXTURE : on neutralise les triggers métier d'INSERT (gate de
    -- circulation, plafond simultané, gel/restriction) le temps de créer les
    -- lignes-support — session_replication_role='replica' exige superuser (le
    -- runner CI et Studio tournent en postgres). Repli gracieux (skip) sinon.
    BEGIN
      SET LOCAL session_replication_role = 'replica';
      INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
        VALUES (v_subject, c_blmf, 'aberto', CURRENT_DATE + 30) RETURNING id INTO v_loan_a;
      INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
        VALUES (v_subject, c_blmf, 'aberto', CURRENT_DATE + 30) RETURNING id INTO v_loan_b;
      INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
        VALUES (v_subject, c_blmf, 'aberto', CURRENT_DATE + 30) RETURNING id INTO v_loan_c;
      INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
        VALUES (v_subject, c_blmf, 'aberto', CURRENT_DATE + 30) RETURNING id INTO v_loan_d;
      INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
        VALUES (v_subject, c_blmf, 'aberto', CURRENT_DATE + 30) RETURNING id INTO v_loan_e;
      INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
        VALUES (v_subject, c_blmf, 'aberto', CURRENT_DATE + 30) RETURNING id INTO v_loan_f;
      SET LOCAL session_replication_role = 'origin';
      v_has_loan := true;
    EXCEPTION WHEN OTHERS THEN
      v_has_loan := false;
      v_skips := v_skips || ('seed emprunts impossible : ' || SQLERRM);
    END;
  END IF;

  -- =====================================================================
  -- SECTION 1 : gardes auth / staff (fn_record_deposit)
  -- =====================================================================
  v_t := '1.01 anon -> rejeté';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    PERFORM * FROM public.fn_record_deposit(COALESCE(v_loan_a, 999999999::bigint), NULL, v_rule_id, 3, 'cash'::public.membership_payment_method, NULL);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

  IF NOT v_has_subject THEN
    v_skipped := v_skipped + 1; v_skips := v_skips || text '1.02 : pas de profil non-staff';
  ELSE
    v_t := '1.02 non-staff -> rejeté';
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_subject, 'role', 'authenticated')::text, true);
      PERFORM * FROM public.fn_record_deposit(COALESCE(v_loan_a, 999999999::bigint), NULL, v_rule_id, 3, 'cash'::public.membership_payment_method, NULL);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
    EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;
  END IF;
  PERFORM set_config('request.jwt.claims', '', true);

  -- =====================================================================
  -- SECTIONS 2–6 : nécessitent staff + emprunts seedés
  -- =====================================================================
  IF NOT (v_has_staff AND v_has_loan) THEN
    v_skipped := v_skipped + 18;
    v_skips := v_skips || text '2.xx–6.xx : pas de staff coordenador BLMF ou seed emprunts indisponible';
  ELSE
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staff, 'role', 'authenticated')::text, true);

    -- ── SECTION 2 : collecte ─────────────────────────────────────────
    v_t := '2.01 collecte per_loan (cash, via règle) -> detenu, montant 3';
    BEGIN
      SELECT * INTO v_rec FROM public.fn_record_deposit(v_loan_a, NULL, v_rule_id, NULL, 'cash'::public.membership_payment_method, '__t__');
      v_dep_id := v_rec.deposit_id;
      SELECT amount INTO v_amount FROM public.loan_deposits WHERE id = v_dep_id;
      IF v_rec.ok IS TRUE AND v_rec.status = 'detenu' AND v_amount = 3 THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' ok=' || coalesce(v_rec.ok::text,'?') || ' st=' || coalesce(v_rec.status::text,'?') || ' mt=' || coalesce(v_amount::text,'?')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '2.02 anti-double sur le même emprunt -> deposit_already_held';
    BEGIN
      PERFORM * FROM public.fn_record_deposit(v_loan_a, NULL, v_rule_id, NULL, 'cash'::public.membership_payment_method, NULL);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
    EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

    v_t := '2.03 exemption ⟹ montant forcé à 0 (même si 3 fourni)';
    BEGIN
      SELECT * INTO v_rec FROM public.fn_record_deposit(v_loan_b, NULL, v_rule_id, 3, 'exemption'::public.membership_payment_method, NULL);
      v_dep_id2 := v_rec.deposit_id;
      SELECT amount INTO v_amount FROM public.loan_deposits WHERE id = v_dep_id2;
      IF v_rec.ok IS TRUE AND v_amount = 0 THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' montant=' || coalesce(v_amount::text,'?')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '2.04 cash + montant 0 -> amount_must_be_positive';
    BEGIN
      PERFORM * FROM public.fn_record_deposit(v_loan_c, NULL, NULL, 0, 'cash'::public.membership_payment_method, NULL);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
    EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

    v_t := '2.05 in_kind + montant 0 -> accepté (detenu)';
    BEGIN
      SELECT * INTO v_rec FROM public.fn_record_deposit(v_loan_d, NULL, NULL, 0, 'in_kind'::public.membership_payment_method, NULL);
      IF v_rec.ok IS TRUE AND v_rec.status = 'detenu' THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' ok=' || coalesce(v_rec.ok::text,'?')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '2.06 item étranger à l''emprunt -> item_not_in_loan';
    BEGIN
      PERFORM * FROM public.fn_record_deposit(v_loan_c, 999999999::bigint, v_rule_id, NULL, 'cash'::public.membership_payment_method, NULL);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
    EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

    -- ── SECTION 3 : remboursement ────────────────────────────────────
    v_t := '3.01 remboursement total -> rembourse, refunded_amount=3';
    BEGIN
      SELECT * INTO v_rec FROM public.fn_refund_deposit(v_dep_id, 'cash'::public.membership_payment_method, NULL, NULL);
      SELECT refunded_amount INTO v_amount FROM public.loan_deposits WHERE id = v_dep_id;
      IF v_rec.ok IS TRUE AND v_rec.status = 'rembourse' AND v_amount = 3 THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' st=' || coalesce(v_rec.status::text,'?') || ' ra=' || coalesce(v_amount::text,'?')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '3.02 remboursement d''un dépôt déjà soldé -> deposit_not_held';
    BEGIN
      PERFORM * FROM public.fn_refund_deposit(v_dep_id, 'cash'::public.membership_payment_method, NULL, NULL);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
    EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

    -- collecte d'un dépôt à 10 sur loan_c pour les cas partiels
    BEGIN
      SELECT * INTO v_rec FROM public.fn_record_deposit(v_loan_c, NULL, NULL, 10, 'cash'::public.membership_payment_method, NULL);
      v_dep_c := v_rec.deposit_id;
    EXCEPTION WHEN OTHERS THEN v_dep_c := NULL; END;

    v_t := '3.03 remboursement partiel sans note -> partial_refund_reason_required';
    IF v_dep_c IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || text '3.03 : collecte loan_c indisponible';
    ELSE
      BEGIN
        PERFORM * FROM public.fn_refund_deposit(v_dep_c, 'cash'::public.membership_payment_method, 4, NULL);
        v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
      EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;
    END IF;

    v_t := '3.04 remboursement partiel avec note -> partiel, refunded_amount=4';
    IF v_dep_c IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || text '3.04 : collecte loan_c indisponible';
    ELSE
      BEGIN
        SELECT * INTO v_rec FROM public.fn_refund_deposit(v_dep_c, 'cash'::public.membership_payment_method, 4, 'usure de la couverture');
        SELECT refunded_amount, retention_reason INTO v_amount, v_reason FROM public.loan_deposits WHERE id = v_dep_c;
        IF v_rec.ok IS TRUE AND v_rec.status = 'partiel' AND v_amount = 4 AND v_reason IS NOT NULL THEN v_passed := v_passed + 1;
        ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' st=' || coalesce(v_rec.status::text,'?') || ' ra=' || coalesce(v_amount::text,'?')); END IF;
      EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
    END IF;

    -- ── SECTION 4 : rétention ────────────────────────────────────────
    BEGIN
      SELECT * INTO v_rec FROM public.fn_record_deposit(v_loan_e, NULL, NULL, 5, 'cash'::public.membership_payment_method, NULL);
      v_dep_e := v_rec.deposit_id;
    EXCEPTION WHEN OTHERS THEN v_dep_e := NULL; END;

    v_t := '4.01 rétention sans motif -> retention_reason_required';
    IF v_dep_e IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || text '4.01 : collecte loan_e indisponible';
    ELSE
      BEGIN
        PERFORM * FROM public.fn_retain_deposit(v_dep_e, '   ', NULL, 'cash'::public.membership_payment_method);
        v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
      EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;
    END IF;

    v_t := '4.02 rétention totale avec motif -> retenu, refunded_amount NULL';
    IF v_dep_e IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || text '4.02 : collecte loan_e indisponible';
    ELSE
      BEGIN
        SELECT * INTO v_rec FROM public.fn_retain_deposit(v_dep_e, 'livre perdu', NULL, 'cash'::public.membership_payment_method);
        SELECT refunded_amount, retention_reason INTO v_amount, v_reason FROM public.loan_deposits WHERE id = v_dep_e;
        IF v_rec.ok IS TRUE AND v_rec.status = 'retenu' AND v_amount IS NULL AND v_reason = 'livre perdu' THEN v_passed := v_passed + 1;
        ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' st=' || coalesce(v_rec.status::text,'?') || ' ra=' || coalesce(v_amount::text,'NULL')); END IF;
      EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
    END IF;

    v_t := '4.03 rétention partielle (rend une partie) -> partiel';
    BEGIN
      SELECT * INTO v_rec FROM public.fn_record_deposit(v_loan_f, NULL, NULL, 8, 'cash'::public.membership_payment_method, NULL);
      v_dep_f := v_rec.deposit_id;
      SELECT * INTO v_rec FROM public.fn_retain_deposit(v_dep_f, 'page arrachée', 3, 'cash'::public.membership_payment_method);
      SELECT refunded_amount, retention_reason INTO v_amount, v_reason FROM public.loan_deposits WHERE id = v_dep_f;
      IF v_rec.ok IS TRUE AND v_rec.status = 'partiel' AND v_amount = 3 AND v_reason = 'page arrachée' THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' st=' || coalesce(v_rec.status::text,'?') || ' ra=' || coalesce(v_amount::text,'?')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    -- ── SECTION 5 : lecture ──────────────────────────────────────────
    v_t := '5.01 fn_deposit_status_for_loan (staff) -> 1 ligne sur loan_c';
    BEGIN
      SELECT count(*) INTO v_cnt FROM public.fn_deposit_status_for_loan(v_loan_c);
      IF v_cnt = 1 THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' n=' || v_cnt); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '5.02 fn_deposit_status_for_loan (emprunteur·se) -> voit son dépôt';
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_subject, 'role', 'authenticated')::text, true);
      SELECT count(*) INTO v_cnt FROM public.fn_deposit_status_for_loan(v_loan_a);
      IF v_cnt = 1 THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' n=' || v_cnt); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '5.03 api.fn_my_deposits_status -> 6 dépôts du subject';
    BEGIN
      SELECT count(*) INTO v_cnt FROM api.fn_my_deposits_status();
      IF v_cnt = 6 THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' n=' || v_cnt || ' (attendu 6)'); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
    PERFORM set_config('request.jwt.claims', '', true);

    -- ── SECTION 6 : contrainte CHECK statut↔montants (intégrité directe) ──
    v_t := '6.01 CHECK rejette un statut incohérent (rembourse sans montant)';
    BEGIN
      INSERT INTO public.loan_deposits (user_id, library_id, emprestimo_id, amount, status, refunded_amount)
      VALUES (v_subject, c_blmf, v_loan_a, 5, 'rembourse', NULL);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever (CHECK)');
    EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;
  END IF;

  PERFORM set_config('request.jwt.claims', '', true);

  -- =====================================================================
  -- BILAN (RAISE = rollback de toute la transaction, fixtures comprises)
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'DEPOT-GARANTIE OK : %/% tests passés (% skips)%',
      v_passed, (v_passed + v_failed), v_skipped,
      CASE WHEN v_skipped > 0 THEN ' | SKIPS: ' || array_to_string(v_skips, ' ; ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'DEPOT-GARANTIE ECHEC : %/% OK, % échec(s) | %  (skips: %)',
      v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || '), array_to_string(v_skips, ' ; ');
  END IF;
END $$;
