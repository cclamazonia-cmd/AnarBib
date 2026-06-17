-- =====================================================================
-- AnarBib — Tests d'acceptation : module COTISATIONS / gate de circulation
-- Date    : 2026-06-17
-- Session : Audit 360 — correctifs P0
-- Réf     : Audit 360° 17/06/2026, P0 n°1 (#33) — « tests cotisations
--           inexistants ». Couvre aussi le fix §6.1 du jour (revérification
--           au renouvellement dans fn_v2_extend_core).
--
-- USAGE :
--   Coller dans Supabase Studio SQL Editor et Run (ou psql / supabase db execute).
--   Tout est dans UN bloc DO $$ qui se termine par une EXCEPTION portant le
--   bilan. Cette EXCEPTION finale fait ROLLBACK de TOUTE la transaction → les
--   fixtures seedées ne touchent JAMAIS la prod.
--   - Bilan OK  : 'COTISATION OK : N/N tests passés (S skips)'
--   - Bilan KO  : 'COTISATION ECHEC : ...' + liste des échecs.
--
-- FIXTURES — résolues DYNAMIQUEMENT (pas d'UUID codé en dur, qui se périment) :
--   - v_subject : un profil SANS adhésion BLMF → sujet dont on contrôle l'état
--                 de A à Z (adhésion + paiements seedés dans la transaction).
--   - v_staff   : un coordenador actif de BLMF → acteur staff (JWT simulé).
--   Sections dépendantes SKIPpées si la fixture est introuvable.
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

  c_blmf  constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_subject uuid;
  v_staff   uuid;

  v_rule_id uuid;
  v_vu date;
  v_blocked boolean;
  v_verdict text;
  v_rec record;
  v_loan record;
  v_json jsonb;
  v_n int;
  v_has_subject boolean;
  v_has_staff boolean;
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
  UPDATE public.libraries SET membership_enabled = true WHERE id = c_blmf;

  INSERT INTO public.library_membership_rules
    (library_id, name, amount_min, currency, period_type, period_anchor, is_required, is_active)
  VALUES (c_blmf, '__TEST_COTISATION__', 10, 'EUR', 'annual', 'rolling', true, true)
  RETURNING id INTO v_rule_id;

  IF v_has_subject THEN
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_restricted)
    VALUES (v_subject, c_blmf, 'reader', 'active', false);
  END IF;

  -- =====================================================================
  -- SECTION 1 : fn_compute_membership_validity (toujours exécutée)
  -- =====================================================================
  v_t := '1.01 annual/rolling -> +1 an -1 jour';
  BEGIN
    SELECT valid_until INTO v_vu FROM public.fn_compute_membership_validity(v_rule_id, '2026-06-17 12:00:00+00');
    IF v_vu = DATE '2027-06-16' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_vu::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := '1.02 calendar/annual -> 31/12';
  BEGIN
    UPDATE public.library_membership_rules SET period_anchor='calendar' WHERE id=v_rule_id;
    SELECT valid_until INTO v_vu FROM public.fn_compute_membership_validity(v_rule_id, '2026-06-17 12:00:00+00');
    UPDATE public.library_membership_rules SET period_anchor='rolling' WHERE id=v_rule_id;
    IF v_vu = DATE '2026-12-31' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_vu::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := '1.03 lifetime -> NULL';
  BEGIN
    UPDATE public.library_membership_rules SET period_type='lifetime' WHERE id=v_rule_id;
    SELECT valid_until INTO v_vu FROM public.fn_compute_membership_validity(v_rule_id, now());
    UPDATE public.library_membership_rules SET period_type='annual' WHERE id=v_rule_id;
    IF v_vu IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || v_vu::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- =====================================================================
  -- SECTION 2 : fn_is_loan_blocked_by_dues  (nécessite v_subject)
  -- =====================================================================
  IF NOT v_has_subject THEN
    v_skipped := v_skipped + 4; v_skips := v_skips || '2.xx : aucun profil sans adhésion BLMF';
  ELSE
    v_t := '2.01 never_paid -> bloqué';
    BEGIN
      DELETE FROM public.membership_payments WHERE user_id=v_subject AND library_id=c_blmf;
      v_blocked := public.fn_is_loan_blocked_by_dues(v_subject, c_blmf);
      IF v_blocked THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '2.02 up_to_date -> non bloqué';
    BEGIN
      DELETE FROM public.membership_payments WHERE user_id=v_subject AND library_id=c_blmf;
      INSERT INTO public.membership_payments (user_id, library_id, rule_id, amount_paid, currency, paid_at, valid_from, valid_until, payment_method)
      VALUES (v_subject, c_blmf, v_rule_id, 10, 'EUR', now(), CURRENT_DATE, CURRENT_DATE + 30, 'cash');
      v_blocked := public.fn_is_loan_blocked_by_dues(v_subject, c_blmf);
      IF NOT v_blocked THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '2.03 expired -> bloqué';
    BEGIN
      DELETE FROM public.membership_payments WHERE user_id=v_subject AND library_id=c_blmf;
      INSERT INTO public.membership_payments (user_id, library_id, rule_id, amount_paid, currency, paid_at, valid_from, valid_until, payment_method)
      VALUES (v_subject, c_blmf, v_rule_id, 10, 'EUR', now() - interval '400 days', CURRENT_DATE - 400, CURRENT_DATE - 30, 'cash');
      v_blocked := public.fn_is_loan_blocked_by_dues(v_subject, c_blmf);
      IF v_blocked THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '2.04 membership disabled -> non bloqué';
    BEGIN
      UPDATE public.libraries SET membership_enabled=false WHERE id=c_blmf;
      v_blocked := public.fn_is_loan_blocked_by_dues(v_subject, c_blmf);
      UPDATE public.libraries SET membership_enabled=true WHERE id=c_blmf;
      IF NOT v_blocked THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  END IF;

  -- =====================================================================
  -- SECTION 3 : fn_membership_can_engage_circulation  (nécessite v_subject)
  -- =====================================================================
  IF NOT v_has_subject THEN
    v_skipped := v_skipped + 4; v_skips := v_skips || '3.xx : aucun profil sans adhésion BLMF';
  ELSE
    -- état de base : actif, non restreint, à jour
    DELETE FROM public.membership_payments WHERE user_id=v_subject AND library_id=c_blmf;
    INSERT INTO public.membership_payments (user_id, library_id, rule_id, amount_paid, currency, paid_at, valid_from, valid_until, payment_method)
    VALUES (v_subject, c_blmf, v_rule_id, 10, 'EUR', now(), CURRENT_DATE, CURRENT_DATE + 30, 'cash');
    UPDATE public.user_library_memberships SET status='active', is_restricted=false WHERE user_id=v_subject AND library_id=c_blmf;

    v_t := '3.01 membre OK -> NULL';
    BEGIN
      v_verdict := public.fn_membership_can_engage_circulation(v_subject, c_blmf);
      IF v_verdict IS NULL THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_verdict,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '3.02 sans adhésion active -> no_active_membership';
    BEGIN
      UPDATE public.user_library_memberships SET status='inactive' WHERE user_id=v_subject AND library_id=c_blmf;
      v_verdict := public.fn_membership_can_engage_circulation(v_subject, c_blmf);
      UPDATE public.user_library_memberships SET status='active' WHERE user_id=v_subject AND library_id=c_blmf;
      IF v_verdict = 'no_active_membership' THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_verdict,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '3.03 restreint -> restricted';
    BEGIN
      UPDATE public.user_library_memberships SET is_restricted=true WHERE user_id=v_subject AND library_id=c_blmf;
      v_verdict := public.fn_membership_can_engage_circulation(v_subject, c_blmf);
      UPDATE public.user_library_memberships SET is_restricted=false WHERE user_id=v_subject AND library_id=c_blmf;
      IF v_verdict = 'restricted' THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_verdict,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    v_t := '3.04 impayé -> dues';
    BEGIN
      DELETE FROM public.membership_payments WHERE user_id=v_subject AND library_id=c_blmf;
      v_verdict := public.fn_membership_can_engage_circulation(v_subject, c_blmf);
      IF v_verdict = 'dues' THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_verdict,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

    -- remet le subject à jour pour la section 4 (payee actif)
    INSERT INTO public.membership_payments (user_id, library_id, rule_id, amount_paid, currency, paid_at, valid_from, valid_until, payment_method)
    VALUES (v_subject, c_blmf, v_rule_id, 10, 'EUR', now(), CURRENT_DATE, CURRENT_DATE + 30, 'cash');
  END IF;

  -- =====================================================================
  -- SECTION 4 : fn_record_membership_payment (auth + validations)
  -- =====================================================================
  v_t := '4.01 anon rejeté';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    PERFORM * FROM public.fn_record_membership_payment(coalesce(v_subject, c_blmf), v_rule_id, 10);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

  IF NOT v_has_subject THEN
    v_skipped := v_skipped + 1; v_skips := v_skips || '4.02 : pas de profil non-staff';
  ELSE
    v_t := '4.02 non-staff rejeté';
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_subject, 'role', 'authenticated')::text, true);
      PERFORM * FROM public.fn_record_membership_payment(v_subject, v_rule_id, 10);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
    EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;
  END IF;

  IF NOT (v_has_staff AND v_has_subject) THEN
    v_skipped := v_skipped + 2; v_skips := v_skips || '4.03/4.04 : pas de staff coordenador OU pas de subject';
  ELSE
    v_t := '4.03 staff montant < min rejeté';
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staff, 'role', 'authenticated')::text, true);
      PERFORM * FROM public.fn_record_membership_payment(v_subject, v_rule_id, 1);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
    EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

    v_t := '4.04 staff paiement valide ok=true';
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staff, 'role', 'authenticated')::text, true);
      SELECT * INTO v_rec FROM public.fn_record_membership_payment(v_subject, v_rule_id, 10);
      IF v_rec.ok IS TRUE AND v_rec.payment_id IS NOT NULL THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' ok=' || coalesce(v_rec.ok::text,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  END IF;
  PERFORM set_config('request.jwt.claims', '', true);

  -- =====================================================================
  -- SECTION 5 : câblage du gate + verrou du fix §6.1 (introspection)
  -- =====================================================================
  v_t := '5.01 gate BEFORE INSERT câblé sur emprestimos_v2 ET consultas_locais_v2';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_trigger t
    WHERE t.tgfoid = 'public.fn_enforce_membership_circulation_gate'::regproc AND NOT t.tgisinternal
      AND t.tgrelid IN ('public.emprestimos_v2'::regclass, 'public.consultas_locais_v2'::regclass);
    IF v_n = 2 THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' n=' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := '5.02 gate délègue à can_engage_circulation + 3 hints';
  BEGIN
    IF pg_get_functiondef('public.fn_enforce_membership_circulation_gate'::regproc) ~ 'fn_membership_can_engage_circulation'
       AND pg_get_functiondef('public.fn_enforce_membership_circulation_gate'::regproc) ~ 'error.membership.not_active'
       AND pg_get_functiondef('public.fn_enforce_membership_circulation_gate'::regproc) ~ 'error.membership.restricted'
       AND pg_get_functiondef('public.fn_enforce_membership_circulation_gate'::regproc) ~ 'error.membership.dues'
    THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := '5.03 fn_v2_extend_core revérifie l''éligibilité (fix §6.1)';
  BEGIN
    IF pg_get_functiondef('public.fn_v2_extend_core'::regproc) ~ 'fn_membership_can_engage_circulation'
    THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : appel absent — régression du fix renouvellement !'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- =====================================================================
  -- SECTION 6 (best-effort) : renouvellement bloqué pour membre restreint
  -- =====================================================================
  v_t := '6.01 renouvellement self d''un membre restreint -> reason=restricted';
  BEGIN
    SELECT e.id, e.user_id, e.library_id INTO v_loan
    FROM public.emprestimos_v2 e
    JOIN public.emprestimo_itens_v2 i ON i.emprestimo_id = e.id AND i.item_status = 'aberto'
    WHERE e.user_id IS NOT NULL LIMIT 1;

    IF v_loan.id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_t || ' : aucun prêt ouvert en base');
    ELSE
      UPDATE public.user_library_memberships SET status='active', is_restricted=true
      WHERE user_id=v_loan.user_id AND library_id=v_loan.library_id;
      IF NOT FOUND THEN
        INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_restricted)
        VALUES (v_loan.user_id, v_loan.library_id, 'reader', 'active', true);
      END IF;
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_loan.user_id, 'role', 'authenticated')::text, true);
      SELECT public.fn_renew_my_loan(v_loan.id) INTO v_json;
      PERFORM set_config('request.jwt.claims', '', true);
      IF (v_json->>'ok') = 'false' AND (v_json->>'reason') = 'restricted' THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' ok=' || coalesce(v_json->>'ok','?') || ' reason=' || coalesce(v_json->>'reason','NULL')); END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN (RAISE = rollback de toute la transaction, fixtures comprises)
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'COTISATION OK : %/% tests passés (% skips)%',
      v_passed, (v_passed + v_failed), v_skipped,
      CASE WHEN v_skipped > 0 THEN ' | SKIPS: ' || array_to_string(v_skips, ' ; ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'COTISATION ECHEC : %/% OK, % échec(s) | %  (skips: %)',
      v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || '), array_to_string(v_skips, ' ; ');
  END IF;
END $$;
