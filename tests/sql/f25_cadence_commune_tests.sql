-- =====================================================================
-- AnarBib — Tests d'acceptation : une cadence commune aux envois Resend
-- Date    : 2026-10-17  ·  Backlog v34 F25 (suite de l'épreuve réelle)
-- Ref     : migration 20261017204847_f25_une_cadence_commune_aux_envois_resend
--
-- L'épreuve du 17/10 : quatorze isolats en parallèle, chacun cadencé à huit
-- envois par seconde, ont fait répondre 429 à Resend 82 fois. La cadence est
-- désormais réservée en base, une ligne par canal.
--
-- T1 trois réservations de suite sur un canal neuf : 0, puis un pas, puis
--    deux pas d'attente (à la milliseconde près) — les créneaux s'enchaînent.
-- T2 un créneau passé ne s'accumule pas : après une pause plus longue que le
--    pas, la réservation suivante n'attend rien.
-- T3 deux canaux sont indépendants.
-- T4 le pas est borné (négatif → 0, au-delà de deux secondes → 2 000) ; un
--    canal vide est refusé (22023).
-- T5 droits : ni anon ni authenticated n'exécutent, service_role oui ;
--    DEFINER, search_path vide ; la table est fermée, RLS activée.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'F25-CADENCE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  a int; b int; c int; v_b boolean; v_state text;
BEGIN
  -- ── T1 ──
  v_t := 'T1 créneaux enchaînés';
  BEGIN
    a := public.fn_mail_cadence_creneau('essai-f25-a', 500);
    b := public.fn_mail_cadence_creneau('essai-f25-a', 500);
    c := public.fn_mail_cadence_creneau('essai-f25-a', 500);
    IF a = 0 AND b BETWEEN 450 AND 500 AND c BETWEEN 950 AND 1000 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||a||'/'||b||'/'||c); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──
  v_t := 'T2 pas d''accumulation';
  BEGIN
    a := public.fn_mail_cadence_creneau('essai-f25-b', 20);
    PERFORM pg_sleep(0.1);
    b := public.fn_mail_cadence_creneau('essai-f25-b', 20);
    IF a = 0 AND b = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||a||'/'||b); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──
  v_t := 'T3 canaux indépendants';
  BEGIN
    a := public.fn_mail_cadence_creneau('essai-f25-c', 1000);
    b := public.fn_mail_cadence_creneau('essai-f25-d', 1000);
    IF a = 0 AND b = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||a||'/'||b); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──
  v_t := 'T4 bornes';
  BEGIN
    a := public.fn_mail_cadence_creneau('essai-f25-e', -50);
    b := public.fn_mail_cadence_creneau('essai-f25-e', -50);
    PERFORM public.fn_mail_cadence_creneau('essai-f25-f', 999999);
    c := public.fn_mail_cadence_creneau('essai-f25-f', 999999);
    v_state := NULL;
    BEGIN
      PERFORM public.fn_mail_cadence_creneau('', 125);
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; END;
    IF a = 0 AND b = 0 AND c BETWEEN 1950 AND 2000 AND v_state = '22023' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||a||'/'||b||'/'||c||'/'||coalesce(v_state,'aucun refus')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──
  v_t := 'T5 droits et forme';
  BEGIN
    SELECT NOT has_function_privilege('anon', 'public.fn_mail_cadence_creneau(text, integer)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.fn_mail_cadence_creneau(text, integer)', 'EXECUTE')
       AND has_function_privilege('service_role', 'public.fn_mail_cadence_creneau(text, integer)', 'EXECUTE')
       AND p.prosecdef AND 'search_path=""' = ANY (p.proconfig)
       AND NOT has_table_privilege('anon', 'private.mail_cadence', 'SELECT')
       AND NOT has_table_privilege('authenticated', 'private.mail_cadence', 'UPDATE')
       AND (SELECT relrowsecurity FROM pg_class WHERE oid = 'private.mail_cadence'::regclass)
      INTO v_b
      FROM pg_proc p WHERE p.oid = 'public.fn_mail_cadence_creneau(text, integer)'::regprocedure;
    IF v_b THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : privileges ou forme'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'F25-CADENCE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'F25-CADENCE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
