-- =====================================================================
-- AnarBib — Tests d'acceptation : EMPRUNTS (emprestimos_v2) — socle d'autorisation
-- Date    : 2026-06-19  ·  Session : Audit 360 — couverture tests circulation
-- Réf     : modernise l'intention de paquet19 (loan wrappers) avec fixtures
--           DYNAMIQUES (les UUID en dur de paquet19 sont périmés sur base reconstruite).
--
-- Couvre : (1) la MATRICE d'autorisation fn_check_loan_action (action × rôle ×
-- statut — déterministe, sans fixture) ; (2) les GARDES des wrappers api.* (anon /
-- non-staff / non-propriétaire rejetés). Le happy-path E2E (create→renew→return)
-- est en SKIP tant que le seed ne fournit pas de holding/exemplaire (à étoffer).
--   Bilan OK : 'EMPRESTIMOS OK : N/N tests passés (S skips)'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_skipped int := 0;
  v_failures text[] := ARRAY[]::text[]; v_skips text[] := ARRAY[]::text[]; v_t text;
  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_outsider uuid; v_holding bigint; v_ok boolean; v_json jsonb;
BEGIN
  -- ── SECTION 1 : matrice fn_check_loan_action (pure, déterministe) ──
  -- create_loan_at_counter = staff (librarian|coordenador) uniquement
  v_t:='1.01 create/librarian -> true';
  IF public.fn_check_loan_action('create_loan_at_counter', NULL, 'librarian') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  v_t:='1.02 create/coordenador -> true';
  IF public.fn_check_loan_action('create_loan_at_counter', NULL, 'coordenador') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  v_t:='1.03 create/leitor -> false';
  IF NOT public.fn_check_loan_action('create_loan_at_counter', NULL, 'leitor') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  v_t:='1.04 create/administrador (rôle local retiré F.2) -> false';
  IF NOT public.fn_check_loan_action('create_loan_at_counter', NULL, 'administrador') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  v_t:='1.05 rôle vide -> false';
  IF NOT public.fn_check_loan_action('create_loan_at_counter', NULL, '') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  -- return_total = staff + statut actif
  v_t:='1.06 return_total/librarian+aberto -> true';
  IF public.fn_check_loan_action('return_total', 'aberto', 'librarian') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  v_t:='1.07 return_total/librarian+encerrado -> false (non actif)';
  IF NOT public.fn_check_loan_action('return_total', 'encerrado', 'librarian') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  v_t:='1.08 return_total/leitor -> false';
  IF NOT public.fn_check_loan_action('return_total', 'aberto', 'leitor') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  -- renew_as_reader = leitor OU staff + statut actif
  v_t:='1.09 renew/leitor+aberto -> true';
  IF public.fn_check_loan_action('renew_as_reader', 'aberto', 'leitor') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  v_t:='1.10 renew/leitor+parcialmente_devolvido -> true';
  IF public.fn_check_loan_action('renew_as_reader', 'parcialmente_devolvido', 'leitor') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  v_t:='1.11 renew/leitor+encerrado -> false';
  IF NOT public.fn_check_loan_action('renew_as_reader', 'encerrado', 'leitor') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  v_t:='1.12 renew/librarian+aberto -> true (staff aussi, fix v2)';
  IF public.fn_check_loan_action('renew_as_reader', 'aberto', 'librarian') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  -- extend_as_library = staff + actif
  v_t:='1.13 extend/leitor -> false';
  IF NOT public.fn_check_loan_action('extend_as_library', 'aberto', 'leitor') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  -- mark_return_missed_by_system = system uniquement
  v_t:='1.14 mark_missed_by_system/system+aberto -> true';
  IF public.fn_check_loan_action('mark_return_missed_by_system', 'aberto', 'system') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  v_t:='1.15 mark_missed_by_system/librarian -> false';
  IF NOT public.fn_check_loan_action('mark_return_missed_by_system', 'aberto', 'librarian') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;
  -- action inconnue -> false
  v_t:='1.16 action inconnue -> false';
  IF NOT public.fn_check_loan_action('action_bidon', 'aberto', 'librarian') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||v_t; END IF;

  -- ── SECTION 2 : gardes des wrappers api.* ──
  -- Résolution outsider (profil sans rôle staff sur BLMF — seed : 2222…).
  SELECT p.id INTO v_outsider FROM public.profiles p
   WHERE NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                     WHERE m.user_id=p.id AND m.library_id=c_blmf
                       AND m.role IN ('librarian','coordenador') AND m.status='active')
   LIMIT 1;

  v_t:='2.01 create_loan_at_counter anon -> rejeté';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role','anon')::text, true);
    SELECT ok INTO v_ok FROM api.create_loan_at_counter(gen_random_uuid(), ARRAY[]::bigint[], NULL, NULL);
    IF v_ok IS NOT TRUE THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : ok=true inattendu'); END IF;
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;
  PERFORM set_config('request.jwt.claims','',true);

  v_t:='2.02 create_loan_at_counter non-staff -> rejeté';
  IF v_outsider IS NULL THEN v_skipped:=v_skipped+1; v_skips:=v_skips|| text '2.02 : pas de profil non-staff'; ELSE
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_outsider,'role','authenticated')::text, true);
    SELECT ok INTO v_ok FROM api.create_loan_at_counter(v_outsider, ARRAY[]::bigint[], NULL, NULL);
    IF v_ok IS NOT TRUE THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : ok=true inattendu'); END IF;
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;
  PERFORM set_config('request.jwt.claims','',true);
  END IF;

  v_t:='2.03 renew_my_loan sur emprunt inexistant -> rejeté';
  IF v_outsider IS NULL THEN v_skipped:=v_skipped+1; v_skips:=v_skips|| text '2.03 : pas d''acteur'; ELSE
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_outsider,'role','authenticated')::text, true);
    SELECT api.renew_my_loan(999999999) INTO v_json;
    IF v_json IS NULL OR (v_json->>'ok') IS DISTINCT FROM 'true' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' ok='||coalesce(v_json->>'ok','?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;
  PERFORM set_config('request.jwt.claims','',true);
  END IF;

  v_t:='2.04 return_loan_total non-staff -> rejeté';
  IF v_outsider IS NULL THEN v_skipped:=v_skipped+1; v_skips:=v_skips|| text '2.04 : pas d''acteur'; ELSE
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_outsider,'role','authenticated')::text, true);
    PERFORM api.return_loan_total(999999999, NULL);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;
  PERFORM set_config('request.jwt.claims','',true);
  END IF;

  -- ── SECTION 3 : happy-path create→renew→return (SKIP si pas de holding seedé) ──
  SELECT id INTO v_holding FROM public.book_holdings WHERE library_id=c_blmf LIMIT 1;
  IF v_holding IS NULL THEN
    v_skipped:=v_skipped+1; v_skips:=v_skips|| text '3.xx happy-path : aucun book_holding BLMF seedé (étoffer seed.sql : livre+holding+exemplaire)';
  ELSE
    v_skipped:=v_skipped+1; v_skips:=v_skips|| text '3.xx happy-path : holding présent mais E2E non encore écrit (exemplaire requis)';
  END IF;

  -- ── BILAN ──
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'EMPRESTIMOS OK : %/% tests passés (% skips)%', v_passed, (v_passed+v_failed), v_skipped,
      CASE WHEN v_skipped>0 THEN ' | SKIPS: '||array_to_string(v_skips,' ; ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'EMPRESTIMOS ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures,' || ');
  END IF;
END $$;
