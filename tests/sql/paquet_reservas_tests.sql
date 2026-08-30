-- =====================================================================
-- AnarBib — Tests d'acceptation : RÉSERVATIONS (reservas_v2) — gardes de création
-- Date    : 2026-06-19  ·  Session : Audit 360 — couverture tests circulation
-- Réf     : première couverture CI du domaine réservations (était « Aucun »).
--
-- Couvre les GARDES de fn_v2_create_reserva_by_holdings (SECDEF) + le câblage de
-- fn_v2_refresh_reserva_status_global, ET le happy-path E2E complet
-- create→doublon refusé→annulation→invariant entête↔lignes, écrit le
-- 30/08/2026 (item I15). Il était en SKIP depuis le 19/06 ; les deux règles du
-- modèle qui manquaient sont tombées le même jour, l'une rapportée par le
-- chemin E2E des EMPRUNTS, l'autre lue dans la fonction — aucune supposée.
-- Fixtures dynamiques (pas d'UUID en dur).
--   Bilan OK : 'RESERVAS OK : N/N tests passés (S skips)'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_skipped int := 0;
  v_failures text[] := ARRAY[]::text[]; v_skips text[] := ARRAY[]::text[]; v_t text;
  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_outsider uuid; v_coord uuid; v_holding bigint; v_res bigint; v_txt text;
  c_leitor_b constant uuid := '44444444-4444-4444-4444-444444444444';
  v_n int;
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

  -- ── 2.xx : happy-path create→annulation + invariant entête↔lignes ──
  -- Écrit le 30/08/2026 (item I15). Les deux règles qui manquaient sont
  -- tombées le même jour, et aucune des deux par supposition :
  --
  --   1. `reservation_allowed` : le chemin E2E des EMPRUNTS a rapporté
  --      `reason=not_renewable`, c'est-à-dire qu'une bibliothèque sans jeu de
  --      règles actif se voit tout refuser. Le seed en pose un depuis.
  --   2. Le remplissage de `v_unavailable`, lu dans la fonction :
  --        exemplares_total − emprestimos_abertos − reservas_ativas < 1
  --      Donc **on réserve un exemplaire encore LIBRE**, pas un exemplaire
  --      sorti. C'est une mise de côté, pas une file d'attente — et c'est
  --      l'inverse de ce que j'aurais parié. D'où le choix du holding :
  --      TEST-CIRC-1 porte trois exemplaires pour deux emprunts ouverts et
  --      aucune réservation, soit exactement un disponible.
  SELECT h.id INTO v_holding
    FROM public.book_holdings h JOIN public.books b ON b.id = h.book_id
   WHERE h.library_id = c_blmf AND b.bib_ref = 'TEST-CIRC-1'
   LIMIT 1;

  IF v_holding IS NULL THEN
    v_skipped:=v_skipped+1;
    v_skips:=v_skips|| text '2.xx : le seed ne fournit plus le holding TEST-CIRC-1 (supabase/seed.sql)';
  ELSE
    -- 2.01 — le lecteur B réserve pour lui-même.
    v_t:='2.01 create_reserva pour soi-meme';
    BEGIN
      SET LOCAL ROLE authenticated;
      PERFORM set_config('request.jwt.claims',
        '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}', true);
      v_res := public.fn_v2_create_reserva_by_holdings(
                 c_leitor_b, ARRAY[v_holding]::bigint[], NULL, 'E2E paquet reservas');
      RESET ROLE;
      IF v_res IS NULL THEN
        v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aucun id de reserva renvoye');
      ELSE v_passed:=v_passed+1; END IF;
    EXCEPTION WHEN OTHERS THEN
      RESET ROLE;
      v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : ['||SQLSTATE||'] '||SQLERRM);
    END;

    IF v_res IS NULL THEN
      v_skipped:=v_skipped+1;
      v_skips:=v_skips|| text '2.02-2.05 : sans reserva creee, la suite du chemin n''a rien a verifier';
    ELSE
      -- 2.02 — l'entête est active et porte exactement une ligne active.
      v_t:='2.02 la reserva creee est ativa avec une ligne ativa';
      RESET ROLE;
      SELECT count(*) INTO v_n
        FROM public.reservas_v2 r JOIN public.reserva_linhas_v2 rl ON rl.reserva_id = r.id
       WHERE r.id = v_res AND r.status_global = 'ativa' AND rl.item_status = 'ativa';
      IF v_n = 1 THEN v_passed:=v_passed+1;
      ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||' ligne(s) active(s) au lieu d''une'); END IF;

      -- 2.03 — la meme demande une seconde fois est refusee comme doublon.
      -- Invariant peu couteux et vite casse : sans lui, une double soumission
      -- du formulaire pose deux reserves sur le meme exemplaire.
      v_t:='2.03 une seconde reserva sur le meme holding est refusee';
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims',
          '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}', true);
        PERFORM public.fn_v2_create_reserva_by_holdings(
                  c_leitor_b, ARRAY[v_holding]::bigint[], NULL, 'E2E doublon');
        RESET ROLE;
        v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : le doublon a ete accepte');
      EXCEPTION WHEN OTHERS THEN
        RESET ROLE;
        IF SQLERRM LIKE '%Já existe reserva ativa%' OR SQLERRM LIKE '%existe reserva ativa%' THEN
          v_passed:=v_passed+1;
        ELSE
          v_failed:=v_failed+1;
          v_failures:=v_failures||(v_t||' : refuse pour une autre raison -> '||SQLERRM);
        END IF;
      END;

      -- 2.04 — le lecteur B annule SA reserva.
      v_t:='2.04 cancel_my_reservation par la personne concernee';
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims',
          '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}', true);
        PERFORM api.cancel_my_reservation(v_res);
        RESET ROLE;
        v_passed:=v_passed+1;
      EXCEPTION WHEN OTHERS THEN
        RESET ROLE;
        v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : ['||SQLSTATE||'] '||SQLERRM);
      END;

      -- 2.05 — L'INVARIANT ENTETE <-> LIGNES, la raison d'etre de ce chemin.
      -- Une ligne annulee sans que l'entete suive laisse une reserva « active »
      -- qui ne reserve rien : elle bloque un exemplaire au decompte de
      -- disponibilite (cf. v_unavailable ci-dessus) sans que personne ne
      -- l'attende. C'est ce que fn_v2_refresh_reserva_status_global doit tenir.
      v_t:='2.05 l''entete suit ses lignes apres annulation';
      RESET ROLE;
      SELECT count(*) INTO v_n
        FROM public.reservas_v2 r JOIN public.reserva_linhas_v2 rl ON rl.reserva_id = r.id
       WHERE r.id = v_res
         AND rl.item_status IN ('cancelada_leitor','cancelada_biblioteca')
         AND r.status_global = 'encerrada';
      IF v_n = 1 THEN v_passed:=v_passed+1;
      ELSE
        SELECT r.status_global||' / '||coalesce(string_agg(rl.item_status,','),'(aucune ligne)')
          INTO v_txt
          FROM public.reservas_v2 r LEFT JOIN public.reserva_linhas_v2 rl ON rl.reserva_id = r.id
         WHERE r.id = v_res GROUP BY r.status_global;
        v_failed:=v_failed+1;
        v_failures:=v_failures||(v_t||' : etat obtenu '||coalesce(v_txt,'(reserva introuvable)')
          ||' -- une ligne annulee sans entete qui suit bloque un exemplaire pour personne');
      END IF;
    END IF;
  END IF;

  RESET ROLE;
  PERFORM set_config('request.jwt.claims','',true);

  IF v_failed = 0 THEN
    -- Dénominateur incluant les skips (30/08/2026, item I15).
    RAISE EXCEPTION 'RESERVAS OK : %/% tests passés (% skips)%', v_passed, (v_passed+v_failed+v_skipped), v_skipped,
      CASE WHEN v_skipped>0 THEN ' | SKIPS: '||array_to_string(v_skips,' ; ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'RESERVAS ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures,' || ');
  END IF;
END $$;
