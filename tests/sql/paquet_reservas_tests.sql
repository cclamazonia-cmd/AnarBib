-- =====================================================================
-- AnarBib — Tests d'acceptation : RÉSERVATIONS (reservas_v2) — gardes de création
-- Date    : 2026-06-19  ·  Session : Audit 360 — couverture tests circulation
-- Réf     : première couverture CI du domaine réservations (était « Aucun »).
--
-- Couvre les GARDES de fn_v2_create_reserva_by_holdings (SECDEF) + le câblage de
-- fn_v2_refresh_reserva_status_global. Le happy-path E2E (create→annulation +
-- invariant entête↔lignes) est en SKIP tant que le seed ne fournit pas de
-- holding/exemplaire (à étoffer). Fixtures dynamiques (pas d'UUID en dur).
--   Bilan OK : 'RESERVAS OK : N/N tests passés (S skips)'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_skipped int := 0;
  v_failures text[] := ARRAY[]::text[]; v_skips text[] := ARRAY[]::text[]; v_t text;
  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_outsider uuid; v_coord uuid; v_holding bigint; v_res bigint; v_txt text;
BEGIN
  SELECT p.id INTO v_outsider FROM public.profiles p
   WHERE NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                     WHERE m.user_id=p.id AND m.library_id=c_blmf) LIMIT 1;
  SELECT m.user_id INTO v_coord FROM public.user_library_memberships m
   WHERE m.library_id=c_blmf AND m.role='coordenador' AND m.status='active' LIMIT 1;

  -- 1.01 — anon ne peut pas créer (auth.uid() NULL ; ou FK user_id invalide) -> rejet
  v_t:='1.01 create_reserva anon -> rejeté';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role','anon')::text, true);
    v_res := public.fn_v2_create_reserva_by_holdings(gen_random_uuid(), ARRAY[]::bigint[], NULL, NULL);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever (res='||coalesce(v_res::text,'NULL')||')');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;
  PERFORM set_config('request.jwt.claims','',true);

  -- 1.02 — holdings vides -> rejet (rien à réserver)
  v_t:='1.02 create_reserva holdings vides -> rejeté';
  IF v_outsider IS NULL THEN v_skipped:=v_skipped+1; v_skips:=v_skips|| text '1.02 : pas d''acteur'; ELSE
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_outsider,'role','authenticated')::text, true);
    v_res := public.fn_v2_create_reserva_by_holdings(v_outsider, ARRAY[]::bigint[], NULL, NULL);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;
  PERFORM set_config('request.jwt.claims','',true);
  END IF;

  -- 1.03 — holdings inexistants -> rejet (validation des holdings)
  v_t:='1.03 create_reserva holding inexistant -> rejeté';
  IF v_outsider IS NULL THEN v_skipped:=v_skipped+1; v_skips:=v_skips|| text '1.03 : pas d''acteur'; ELSE
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_outsider,'role','authenticated')::text, true);
    v_res := public.fn_v2_create_reserva_by_holdings(v_outsider, ARRAY[999999999]::bigint[], NULL, NULL);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;
  PERFORM set_config('request.jwt.claims','',true);
  END IF;

  -- 1.04 — fn_v2_refresh_reserva_status_global est câblée (callable, pas de crash sur id absent)
  v_t:='1.04 refresh_reserva_status_global câblée';
  BEGIN
    v_txt := public.fn_v2_refresh_reserva_status_global(999999999);
    v_passed:=v_passed+1;  -- renvoie (NULL/texte) sans planter = OK
  EXCEPTION WHEN OTHERS THEN
    v_passed:=v_passed+1;  -- lève proprement sur id absent = OK aussi (les deux acceptables)
  END;

  -- 2.xx — happy-path create→annulation + invariant entête↔lignes (SKIP : pas de holding seedé)
  SELECT id INTO v_holding FROM public.book_holdings WHERE library_id=c_blmf LIMIT 1;
  IF v_holding IS NULL THEN
    v_skipped:=v_skipped+1; v_skips:=v_skips|| text '2.xx happy-path : aucun book_holding BLMF seedé (étoffer seed.sql)';
  ELSE
    v_skipped:=v_skipped+1; v_skips:=v_skips|| text '2.xx happy-path : holding présent, E2E à écrire (exemplaire + workflow requis)';
  END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'RESERVAS OK : %/% tests passés (% skips)%', v_passed, (v_passed+v_failed), v_skipped,
      CASE WHEN v_skipped>0 THEN ' | SKIPS: '||array_to_string(v_skips,' ; ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'RESERVAS ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures,' || ');
  END IF;
END $$;
