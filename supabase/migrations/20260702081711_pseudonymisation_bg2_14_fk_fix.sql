-- ===========================================================================
-- 20260702081711_pseudonymisation_bg2_14_fk_fix.sql
-- ---------------------------------------------------------------------------
-- CORRECTIF BG2-14 : les 19 colonnes d'acteur network_* pseudonymisees par
-- fn_delete_my_account portent TOUTES une FK (17 -> auth.users, 2 -> profiles)
-- et 6 tables ont une PK sur user_id / (proposal_id, voter_user_id).
--
-- La version 20260701193418 remplacait user_id par un jeton SANS materialiser
-- ce jeton comme utilisateur : violation de FK des qu'une ligne de gouvernance
-- existe (revele par le test d'effacement reel du 02/07). La fonction etait donc
-- CASSEE en prod pour tout membre de gouvernance (un simple lecteur, lui, passait
-- car ses UPDATE touchaient 0 ligne).
--
-- Correctif = piste hybride : on MATERIALISE le jeton comme COMPTE PSEUDONYME
-- distinct (une ligne auth.users + profiles portant le jeton comme id) AVANT les
-- UPDATE. Le jeton reste distinct par personne (PK OK, distinction BG2-5 gardee)
-- et pointe vers une ligne reelle (FK OK). Le compte pseudonyme ne contient
-- AUCUNE donnee personnelle : id = jeton HMAC irreversible, email derive du jeton,
-- meta neutres. Conforme a l'effacement (pas de PII conservee).
--
-- Autonome : on insere EXPLICITEMENT auth.users ET profiles, sans dependre du
-- trigger on_auth_user_created_profile (present en prod, absent en base de test
-- CI reconstruite depuis template0). En prod le trigger cree profiles a l'insert
-- auth.users, puis notre INSERT profiles explicite est absorbe par ON CONFLICT.
--
-- Doctrine : migration immuable -> ce fichier NE modifie PAS 20260701193418
-- (deja appliquee) ; il fait CREATE OR REPLACE de la fonction. Deploiement via
-- CI Forgejo (supabase db push). Teste en transaction annulee avant commit.
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.fn_delete_my_account()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id  uuid := auth.uid();
  v_removido constant uuid := '00000000-0000-0000-0000-000000000001';
  v_open_loans int;
  v_cancelled  int := 0;
  v_anon_res   int := 0;
  v_anon_loans int := 0;
  v_token      uuid;
  v_gov_rows   int := 0;
  v_n          int;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Nenhum usuário autenticado.');
  END IF;
  IF v_user_id = v_removido THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Conta técnica não pode ser excluída.');
  END IF;
  SELECT count(*) INTO v_open_loans
  FROM emprestimos_v2 e
  JOIN emprestimo_itens_v2 ei ON ei.emprestimo_id = e.id
  WHERE e.user_id = v_user_id AND ei.item_status = 'aberto';
  IF v_open_loans > 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Você tem ' || v_open_loans || ' empréstimo(s) em aberto. Devolva todos os itens antes de excluir sua conta.',
      'open_loans', v_open_loans
    );
  END IF;

  -- ==== CIRCULATION -> removido (EXISTANT, inchangé) ====
  UPDATE reserva_linhas_v2 l
     SET item_status = 'cancelada_biblioteca', cancelled_at = now()
    FROM reservas_v2 r
   WHERE l.reserva_id = r.id AND r.user_id = v_user_id AND l.item_status = 'ativa';
  GET DIAGNOSTICS v_cancelled = ROW_COUNT;
  UPDATE reservas_v2 SET status_global = 'encerrada'
   WHERE user_id = v_user_id AND status_global <> 'encerrada';
  UPDATE reservas_v2  SET user_id = v_removido WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_anon_res = ROW_COUNT;
  UPDATE emprestimos_v2 SET user_id = v_removido WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_anon_loans = ROW_COUNT;
  UPDATE reader_library_messages SET sender_id    = v_removido WHERE sender_id    = v_user_id;
  UPDATE reader_library_messages SET recipient_id = v_removido WHERE recipient_id = v_user_id;
  UPDATE entraide_help_offers    SET helper_user_id = v_removido WHERE helper_user_id = v_user_id;
  UPDATE entraide_help_requests  SET author_user_id = v_removido WHERE author_user_id = v_user_id;
  UPDATE emprestimo_itens_v2      SET return_scheduled_by = NULL WHERE return_scheduled_by = v_user_id;
  UPDATE reserva_item_workflow_v2 SET updated_by = NULL WHERE updated_by = v_user_id;

  -- ==== GOUVERNANCE -> jeton stable (NOUVEAU, BG2-14) ====
  v_token := public.fn_pseudonymize_token(v_user_id);

  -- CORRECTIF FK/PK (20260702) : materialiser le jeton comme COMPTE PSEUDONYME
  -- distinct AVANT les UPDATE, sinon les FK (17 -> auth.users, 2 -> profiles) et
  -- les PK (user_id ; proposal_id,voter_user_id) sont violees. Autonome : on cree
  -- auth.users ET profiles explicitement (independant du trigger, absent en CI).
  -- Aucune PII : id = jeton HMAC irreversible, email derive, meta neutres.
  INSERT INTO auth.users (id, email, role, aud, raw_app_meta_data, raw_user_meta_data)
  VALUES (v_token,
          v_token::text || '@pseudonimizado.anarbib.local',
          'authenticated', 'authenticated',
          '{"provider":"pseudonymized","providers":["pseudonymized"]}'::jsonb,
          '{"first_name":"Membro","last_name":"pseudonimizado"}'::jsonb)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id) VALUES (v_token)
  ON CONFLICT (id) DO NOTHING;

  UPDATE network_admin_collective_removal_proposals SET proposed_user_id = v_token WHERE proposed_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_admin_collective_removal_proposals SET proposed_by = v_token WHERE proposed_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_admin_collective_removal_proposals SET cancelled_by = v_token WHERE cancelled_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_admin_collective_removal_votes SET voter_user_id = v_token WHERE voter_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_admin_cross_library_actions_log SET actor_user_id = v_token WHERE actor_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrator_audit SET user_id = v_token WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrator_audit SET actor_user_id = v_token WHERE actor_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrator_audit SET target_user_id = v_token WHERE target_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrator_cooptation_proposals SET proposed_user_id = v_token WHERE proposed_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrator_cooptation_proposals SET proposed_by = v_token WHERE proposed_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrator_cooptation_votes SET voter_user_id = v_token WHERE voter_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrators SET user_id = v_token WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_contributors SET user_id = v_token WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_contributors SET sponsored_by = v_token WHERE sponsored_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_reviewers SET user_id = v_token WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_reviewers SET added_by_user_id = v_token WHERE added_by_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_staff SET user_id = v_token WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_staff SET added_by_user_id = v_token WHERE added_by_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_staff SET updated_by_user_id = v_token WHERE updated_by_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;

  UPDATE network_contributors SET display_name = v_token::text WHERE user_id = v_token;

  INSERT INTO erasure_log (pseudonym_token, erased_at) VALUES (v_token, now())
  ON CONFLICT (pseudonym_token) DO NOTHING;

  DELETE FROM reader_card_tokens WHERE user_id = v_user_id;
  DELETE FROM profiles WHERE id = v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'ok', true,
    'cancelled_reservations', v_cancelled,
    'anonymized_reservations', v_anon_res,
    'anonymized_loans', v_anon_loans,
    'pseudonymized_governance_rows', v_gov_rows,
    'message', 'Conta excluída. Histórico de circulação anonimizado, atos de governança pseudonimizados.'
  );
END;
$function$;

-- ===========================================================================
-- VERIFICATION (auto-test en sous-transaction annulee ; n'affecte pas le deploy)
-- Cree un user de test, l'inscrit dans une table de gouvernance a PK+FK, appelle
-- la vraie fonction, verifie que la pseudonymisation passe SANS violer FK/PK, que
-- le compte pseudonyme est materialise et que le user est supprime. Tout est
-- annule via une exception attrapee -> aucune ecriture ne subsiste.
-- ===========================================================================
DO $verif$
DECLARE
  v_uid   constant uuid := '0ff1ce00-dead-4bad-8bad-0000000fffff';
  v_tok   uuid;
  v_res   jsonb;
  v_staff_uid int; v_staff_tok int; v_pseudo int; v_log int; v_gone int;
BEGIN
  v_tok := public.fn_pseudonymize_token(v_uid);
  BEGIN
    INSERT INTO auth.users (id, email) VALUES (v_uid, 'verif-bg2fix@example.invalid');
    INSERT INTO profiles (id) VALUES (v_uid) ON CONFLICT (id) DO NOTHING;
    INSERT INTO network_staff (user_id) VALUES (v_uid);

    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid::text)::text, true);
    v_res := public.fn_delete_my_account();

    SELECT count(*) INTO v_staff_uid FROM network_staff WHERE user_id = v_uid;
    SELECT count(*) INTO v_staff_tok FROM network_staff WHERE user_id = v_tok;
    SELECT count(*) INTO v_pseudo FROM auth.users WHERE id = v_tok;
    SELECT count(*) INTO v_log   FROM erasure_log WHERE pseudonym_token = v_tok;
    SELECT count(*) INTO v_gone  FROM auth.users WHERE id = v_uid;

    IF (v_res->>'ok') <> 'true' THEN
      RAISE EXCEPTION 'BG2-14 fix KO : fn a retourne ok=false : %', v_res;
    END IF;
    IF v_staff_uid <> 0 THEN RAISE EXCEPTION 'BG2-14 fix KO : staff porte encore user_id'; END IF;
    IF v_staff_tok <> 1 THEN RAISE EXCEPTION 'BG2-14 fix KO : staff ne porte pas le jeton'; END IF;
    IF v_pseudo   <> 1 THEN RAISE EXCEPTION 'BG2-14 fix KO : compte pseudonyme non materialise'; END IF;
    IF v_log      <> 1 THEN RAISE EXCEPTION 'BG2-14 fix KO : erasure_log sans jeton'; END IF;
    IF v_gone     <> 0 THEN RAISE EXCEPTION 'BG2-14 fix KO : user non supprime'; END IF;

    RAISE EXCEPTION 'BG2FIX_OK_ROLLBACK';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM = 'BG2FIX_OK_ROLLBACK' THEN
        RAISE NOTICE 'BG2-14 fix : verification OK (compte pseudonyme + FK/PK + suppression). Jeu de test annule.';
      ELSE
        RAISE;
      END IF;
  END;
END;
$verif$;
