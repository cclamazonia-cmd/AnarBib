-- =====================================================================
-- AnarBib — Tests d'acceptation : RÉSERVATIONS (reservas_v2) — gardes de création
-- Date    : 2026-06-19  ·  Session : Audit 360 — couverture tests circulation
-- Réf     : première couverture CI du domaine réservations (était « Aucun »).
--
-- Couvre les GARDES de fn_v2_create_reserva_by_holdings (SECDEF) + le câblage de
-- fn_v2_refresh_reserva_status_global. Le happy-path E2E (create→annulation +
-- invariant entête↔lignes) reste en SKIP, mais plus pour la raison écrite en
-- juin : le seed fournit désormais holdings et exemplaires. Deux règles du
-- modèle restent à établir — voir le commentaire de la section 2.xx.
-- Fixtures dynamiques (pas d'UUID en dur).
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

  -- 1.04 — fn_v2_refresh_reserva_status_global est câblée.
  -- Réécrit le 30/08/2026 (item I15). Les DEUX branches comptaient un succès :
  -- « renvoie sans planter = OK » et « lève proprement = OK aussi ». Un test
  -- dont toutes les issues passent ne teste rien — et sa branche EXCEPTION
  -- était morte de toute façon : la fonction ne contient aucun RAISE.
  -- On sépare ce que « câblée » veut dire en deux affirmations vérifiables.
  v_t:='1.04a refresh_reserva_status_global existe avec la signature attendue';
  IF to_regprocedure('public.fn_v2_refresh_reserva_status_global(bigint)') IS NOT NULL THEN
    v_passed:=v_passed+1;
  ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : introuvable (renommée ? signature changée ?)'); END IF;

  v_t:='1.04b refresh_reserva_status_global ne lève pas sur un id absent';
  BEGIN
    v_txt := public.fn_v2_refresh_reserva_status_global(999999999);
    v_passed:=v_passed+1;
  EXCEPTION WHEN OTHERS THEN
    v_failed:=v_failed+1;
    v_failures:=v_failures||(v_t||' : a levé ['||SQLSTATE||'] '||SQLERRM
      ||' — le rafraîchissement est appelé depuis des triggers, il doit tolérer une ligne disparue');
  END;

  -- 2.xx — happy-path create→annulation + invariant entête↔lignes.
  -- TOUJOURS EN SKIP au 30/08/2026, mais le motif change — et c'est le sujet.
  -- L'ancien disait « exemplaire + workflow requis » : faux depuis que le seed
  -- fournit livres, holdings et exemplaires. Le pendant côté emprunts a été
  -- écrit ce jour-là (paquet_emprestimos section 3), toutes ses préconditions
  -- ayant été vérifiées une par une.
  --
  -- Ici DEUX règles restent à établir avant d'écrire quoi que ce soit :
  --   1. ce qui remplit `v_unavailable` dans fn_v2_create_reserva_by_holdings
  --      (« Sem exemplares disponíveis para reserva ») : réserve-t-on quand un
  --      exemplaire est libre, ou seulement quand tout est sorti ? Le seed pose
  --      un exemplaire libre sur TEST-CIRC-1 ; la réponse décide du holding.
  --   2. ~~ce que rend `api.resolve_circulation_rule(p_mode := 'reservation')`
  --      pour `blmf-test`~~ — **RÉSOLU le 30/08**, et par un autre test : le
  --      chemin E2E des emprunts a rapporté `reason=not_renewable`, c'est-à-dire
  --      que le résolveur refuse tout à une bibliothèque sans jeu de règles
  --      actif. Le seed en pose désormais un, avec une règle `reservation`.
  --
  -- Écrire le test avant de trancher ces deux points, ce serait parier — et un
  -- test qui échoue pour une précondition non tenue coûte plus cher qu'un skip
  -- qui dit ce qu'il attend. Celui-ci le dit.
  SELECT h.id INTO v_holding
    FROM public.book_holdings h JOIN public.books b ON b.id = h.book_id
   WHERE h.library_id = c_blmf AND b.bib_ref = 'TEST-CIRC-1'
   LIMIT 1;
  IF v_holding IS NULL THEN
    v_skipped:=v_skipped+1;
    v_skips:=v_skips|| text '2.xx : le seed ne fournit plus le holding TEST-CIRC-1 (supabase/seed.sql)';
  ELSE
    v_skipped:=v_skipped+1;
    v_skips:=v_skips|| text '2.xx happy-path : deux règles à établir d''abord — remplissage de v_unavailable, et reservation_allowed pour une biblio sans politique de circulation (voir le commentaire du test)';
  END IF;

  IF v_failed = 0 THEN
    -- Dénominateur incluant les skips (30/08/2026, item I15).
    RAISE EXCEPTION 'RESERVAS OK : %/% tests passés (% skips)%', v_passed, (v_passed+v_failed+v_skipped), v_skipped,
      CASE WHEN v_skipped>0 THEN ' | SKIPS: '||array_to_string(v_skips,' ; ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'RESERVAS ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures,' || ');
  END IF;
END $$;
