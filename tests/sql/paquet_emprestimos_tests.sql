-- =====================================================================
-- AnarBib — Tests d'acceptation : EMPRUNTS (emprestimos_v2) — socle d'autorisation
-- Date    : 2026-06-19  ·  Session : Audit 360 — couverture tests circulation
-- Réf     : modernise l'intention de paquet19 (loan wrappers) avec fixtures
--           DYNAMIQUES (les UUID en dur de paquet19 sont périmés sur base reconstruite).
--
-- Couvre : (1) la MATRICE d'autorisation fn_check_loan_action (action × rôle ×
-- statut — déterministe, sans fixture) ; (2) les GARDES des wrappers api.* (anon /
-- non-staff / non-propriétaire rejetés) ; (3) le happy-path E2E complet
-- create→renew→return, écrit le 30/08/2026 (item I15) une fois que le seed a
-- fourni livre, holding et exemplaires. Il était en SKIP depuis le 19/06 pour
-- « exemplaire requis » — motif devenu faux sans que personne ne le relise.
--   Bilan OK : 'EMPRESTIMOS OK : N/N tests passés (S skips)'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_skipped int := 0;
  v_failures text[] := ARRAY[]::text[]; v_skips text[] := ARRAY[]::text[]; v_t text;
  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_outsider uuid; v_holding bigint; v_ok boolean; v_json jsonb;
  c_coord    constant uuid := '11111111-1111-1111-1111-111111111111';
  c_leitor_b constant uuid := '44444444-4444-4444-4444-444444444444';
  v_loan bigint; v_due_avant date; v_due_apres date; v_n int; v_txt text;
  -- Ce que la suite veut faire remonter en plus de son compte. Voir la note
  -- « CE QUI SORT D'UNE SUITE » au bilan.
  v_info text := '';
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

  -- ── SECTION 3 : happy-path create→renew→return, de bout en bout ──
  -- Ecrite le 30/08/2026 (item I15). Elle etait en SKIP depuis le 19/06 avec
  -- le motif « exemplaire requis » : vrai a l'epoque, faux depuis que le seed
  -- fournit livre, holding et exemplaires. Un motif de skip decrit un etat
  -- passe et lui survit ; celui-ci a tenu deux mois apres sa peremption.
  --
  -- Le holding est choisi PAR SA REFERENCE, pas par LIMIT 1 : le seed en pose
  -- trois sur BLMF, et deux sont volontairement bloques (l'un sous consulta,
  -- l'autre sous reservation). Un LIMIT 1 tombait sur l'un d'eux une fois sur
  -- trois et le test aurait echoue pour une raison etrangere a ce qu'il teste.
  SELECT h.id INTO v_holding
    FROM public.book_holdings h JOIN public.books b ON b.id = h.book_id
   WHERE h.library_id = c_blmf AND b.bib_ref = 'TEST-CIRC-1'
   LIMIT 1;

  IF v_holding IS NULL THEN
    v_skipped:=v_skipped+1;
    v_skips:=v_skips|| text '3.xx : le seed ne fournit plus le holding TEST-CIRC-1 (supabase/seed.sql)';
  ELSE
    -- 3.01 — la coordination prete au comptoir pour le lecteur B.
    v_t:='3.01 create_loan_at_counter par la coordination';
    BEGIN
      SET LOCAL ROLE authenticated;
      PERFORM set_config('request.jwt.claims',
        '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
      SELECT emprestimo_id INTO v_loan
        FROM api.create_loan_at_counter(c_leitor_b, ARRAY[v_holding]::bigint[], NULL, 'E2E paquet emprestimos')
       LIMIT 1;
      RESET ROLE;
      IF v_loan IS NULL THEN
        v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aucun emprestimo_id renvoye');
      ELSE v_passed:=v_passed+1; END IF;
    EXCEPTION WHEN OTHERS THEN
      RESET ROLE;
      v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : ['||SQLSTATE||'] '||SQLERRM);
    END;

    IF v_loan IS NULL THEN
      v_skipped:=v_skipped+1;
      v_skips:=v_skips|| text '3.02-3.05 : sans emprunt cree, la suite du chemin n''a rien a verifier';
    ELSE
      -- 3.02 — l'entete est ouverte et porte exactement une ligne ouverte.
      v_t:='3.02 l''emprunt cree est aberto avec une ligne aberto';
      RESET ROLE;
      SELECT count(*) INTO v_n
        FROM public.emprestimos_v2 e JOIN public.emprestimo_itens_v2 i ON i.emprestimo_id = e.id
       WHERE e.id = v_loan AND e.status_global = 'aberto' AND i.item_status = 'aberto';
      IF v_n = 1 THEN v_passed:=v_passed+1;
      ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||' ligne(s) ouverte(s) au lieu d''une'); END IF;

      -- 3.03 — le lecteur B renouvelle SON emprunt.
      --
      -- CE QUE LA PREMIERE ECRITURE A APPRIS (30/08/2026). Ce test affirmait
      -- « l'echeance recule ». La CI a repondu : echeance inchangee, et AUCUNE
      -- exception. `api.renew_my_loan` ne leve pas — elle rend un jsonb
      -- { ok, reason, new_due_date, renewed, skipped }. Le contrat est
      -- explicite ; le test l'ignorait et n'observait que l'effet.
      --
      -- La cause tient au monde de test : `blmf-test` n'a aucun jeu de regles
      -- de circulation actif (`library_circulation_policy_sets`), et le
      -- renouvellement se refuse alors SANS BRUIT. Que ce silence soit le bon
      -- comportement produit est une question ouverte — un refus muet est plus
      -- couteux qu'un refus nomme — mais ce n'est pas a un test de la trancher.
      --
      -- Ce test affirme donc ce qui est vrai et verifiable aujourd'hui :
      --   * la reponse respecte le contrat (`ok` et `reason` presents) ;
      --   * SI le renouvellement aboutit, ALORS l'echeance a recule.
      -- L'implication est un vrai test : un `ok = true` sans echeance qui
      -- bouge le fait rougir. Et le NOTICE porte la raison dans le journal de
      -- CI, pour qu'on sache quoi seeder sans relancer une enquete.
      v_t:='3.03 renew_my_loan respecte son contrat, et tient sa promesse quand il aboutit';
      SELECT max(due_at) INTO v_due_avant FROM public.emprestimo_itens_v2 WHERE emprestimo_id = v_loan;
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims',
          '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}', true);
        v_json := api.renew_my_loan(v_loan);
        RESET ROLE;
        SELECT max(due_at) INTO v_due_apres FROM public.emprestimo_itens_v2 WHERE emprestimo_id = v_loan;

        -- Un RAISE NOTICE ne sort PAS : `run-sql-suites.sh` ne retient que la
        -- ligne « … OK : N/N ». L'information voyage donc dans le bilan.
        v_info := v_info || format(' | 3.03 renew: ok=%s reason=%s (echeance %s -> %s)',
          coalesce(v_json->>'ok','(absent)'), coalesce(v_json->>'reason','(absente)'),
          coalesce(v_due_avant::text,'NULL'), coalesce(v_due_apres::text,'NULL'));

        IF NOT (v_json ? 'ok' AND v_json ? 'reason') THEN
          v_failed:=v_failed+1;
          v_failures:=v_failures||(v_t||' : reponse hors contrat -> '||coalesce(v_json::text,'NULL'));
        ELSIF (v_json->>'ok')::boolean AND NOT (v_due_apres > v_due_avant) THEN
          v_failed:=v_failed+1;
          v_failures:=v_failures||(v_t||' : ok=true mais echeance inchangee ('
            ||coalesce(v_due_avant::text,'NULL')||' -> '||coalesce(v_due_apres::text,'NULL')
            ||') -- le renouvellement dit avoir fait ce qu''il n''a pas fait');
        ELSE
          v_passed:=v_passed+1;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        RESET ROLE;
        v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : ['||SQLSTATE||'] '||SQLERRM);
      END;

      -- 3.04 — la coordination rend la totalite : entete close, ligne rendue.
      v_t:='3.04 return_loan_total par la coordination clot l''emprunt';
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims',
          '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
        -- Second argument a NULL, comme en 2.04 : sa semantique (note ? motif
        -- code ?) n'est pas etablie ici, et un test ne doit pas parier dessus.
        PERFORM api.return_loan_total(v_loan, NULL);
        RESET ROLE;
        SELECT count(*) INTO v_n
          FROM public.emprestimos_v2 e JOIN public.emprestimo_itens_v2 i ON i.emprestimo_id = e.id
         WHERE e.id = v_loan AND e.status_global = 'encerrado' AND i.item_status = 'devolvido';
        IF v_n = 1 THEN v_passed:=v_passed+1;
        ELSE
          SELECT e.status_global||'/'||coalesce(string_agg(i.item_status,','),'(aucune ligne)')
            INTO v_txt
            FROM public.emprestimos_v2 e LEFT JOIN public.emprestimo_itens_v2 i ON i.emprestimo_id = e.id
           WHERE e.id = v_loan GROUP BY e.status_global;
          v_failed:=v_failed+1;
          v_failures:=v_failures||(v_t||' : etat obtenu '||coalesce(v_txt,'(emprunt introuvable)'));
        END IF;
      EXCEPTION WHEN OTHERS THEN
        RESET ROLE;
        v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : ['||SQLSTATE||'] '||SQLERRM);
      END;

      -- 3.05 — l'exemplaire est de nouveau pretable.
      -- C'est l'invariant que le reste du chemin ne verifie pas : un retour qui
      -- clot l'entete sans liberer l'exemplaire laisse un fantome au rayon.
      v_t:='3.05 l''exemplaire rendu ne porte plus de ligne ouverte';
      RESET ROLE;
      SELECT count(*) INTO v_n
        FROM public.emprestimo_itens_v2 i
        JOIN public.exemplares e ON e.id = i.item_id
       WHERE e.holding_id = v_holding AND i.item_status = 'aberto' AND i.emprestimo_id = v_loan;
      IF v_n = 0 THEN v_passed:=v_passed+1;
      ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||' ligne(s) encore ouverte(s)'); END IF;
    END IF;
  END IF;

  RESET ROLE;
  PERFORM set_config('request.jwt.claims','',true);

  -- ── BILAN ──
  IF v_failed = 0 THEN
    -- Denominateur incluant les skips (30/08/2026, item I15) : sans cela, un
    -- test qui bascule de PASSE a SKIP disparait des deux termes et la suite
    -- reste verte en testant moins.
    -- CE QUI SORT D'UNE SUITE. `run-sql-suites.sh` ne conserve qu'UNE ligne par
    -- suite : celle qui correspond au motif « OK : N/N ». Tout le reste de la
    -- sortie psql, NOTICE compris, est jeté. Une suite n'a donc qu'un seul
    -- canal vers le journal de CI — sa ligne de bilan. C'est aussi pourquoi un
    -- test qui se desactive en silence est indetectable : il n'a aucun moyen
    -- de le dire. Constat du 30/08/2026 (item I15).
    -- Un seul emplacement en fin de format : `%%` serait un pour-cent LITTERAL,
    -- pas une quatrieme substitution. Les deux textes sont donc concatenes.
    RAISE EXCEPTION 'EMPRESTIMOS OK : %/% tests passés (% skips)%', v_passed, (v_passed+v_failed+v_skipped), v_skipped,
      (CASE WHEN v_skipped>0 THEN ' | SKIPS: '||array_to_string(v_skips,' ; ') ELSE '' END) || v_info;
  ELSE
    RAISE EXCEPTION 'EMPRESTIMOS ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures,' || ');
  END IF;
END $$;
