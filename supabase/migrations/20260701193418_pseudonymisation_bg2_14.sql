-- =========================================================================
-- Paquet BG2-14 — Pseudonymisation des acteurs de gouvernance à l'effacement
-- =========================================================================
-- Date     : 2026-07-01
-- Chantier : #BG2 — droit à l'effacement des acteurs network_*
-- Réfère   : docs/specs/spec-pseudonymisation-bg2-14.md ; REGISTRE §BG2
--
-- fn_delete_my_account ne touchait aucune table network_* : un·e admin réseau
-- qui supprimait son compte laissait ses actes de gouvernance avec son user_id
-- EN CLAIR (donc backups). Ce paquet pseudonymise l'acteur par un JETON stable,
-- distinct, irréversible = UUID déterministe hmac(user_id, sel Vault hors dump).
-- Deux régimes : removido (circulation, existant) + jeton (gouvernance, nouveau).
-- PRÉREQUIS : secret Vault 'pseudonym_salt' (créé 01/07, hors git, spec §6.1).
-- =========================================================================

BEGIN;

-- ---- BLOC A — erasure_log (scénario C : hors Data API) ----
-- Stocke le JETON, jamais le user_id. Rejeu restauration par recalcul (spec §4.1).
CREATE TABLE IF NOT EXISTS public.erasure_log (
  pseudonym_token uuid NOT NULL,
  erased_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pseudonym_token)
);

REVOKE ALL ON public.erasure_log FROM PUBLIC;
REVOKE ALL ON public.erasure_log FROM anon;
REVOKE ALL ON public.erasure_log FROM authenticated;
GRANT ALL ON public.erasure_log TO service_role;

ALTER TABLE public.erasure_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "erasure_log_no_direct_access"
  ON public.erasure_log FOR ALL TO anon, authenticated
  USING (false) WITH CHECK (false);

COMMENT ON TABLE public.erasure_log IS
  'Journal effacements BG2-14 : (jeton, date). Jamais de user_id en clair. Hors Data API. Paquet BG2-14 du 01/07/2026.';

-- ---- BLOC B — fn_pseudonymize_token(uuid) -> uuid ----
-- Jeton stable irréversible via hmac + sel Vault. SECURITY DEFINER pour lire
-- vault.decrypted_secrets. Aucun accès direct (appelée par fn_delete_my_account).
CREATE OR REPLACE FUNCTION public.fn_pseudonymize_token(p_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault, extensions, pg_catalog
AS $function$
DECLARE
  v_salt text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT decrypted_secret INTO v_salt
  FROM vault.decrypted_secrets
  WHERE name = 'pseudonym_salt';

  IF v_salt IS NULL THEN
    RAISE EXCEPTION 'BG2-14 : secret Vault pseudonym_salt introuvable. Creer le sel (spec 6.1) avant tout effacement.';
  END IF;

  -- UUID déterministe : 16 premiers octets du hmac-sha256 (validé 01/07).
  RETURN encode(substring(hmac(p_user_id::text, v_salt, 'sha256') for 16), 'hex')::uuid;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_pseudonymize_token(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_pseudonymize_token(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.fn_pseudonymize_token(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.fn_pseudonymize_token(uuid) FROM service_role;

COMMENT ON FUNCTION public.fn_pseudonymize_token(uuid) IS
  'BG2-14 : jeton stable irreversible (UUID deterministe hmac(user_id, sel Vault)). Aucun acces direct. Paquet BG2-14 du 01/07/2026.';

-- ---- BLOC C — fn_delete_my_account avec pseudonymisation gouvernance ----
-- Corps EXACT de la version vive (vérifié 01/07). Seul ajout : bloc gouvernance
-- APRÈS circulation removido, AVANT les DELETE. Logique removido INCHANGÉE.
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

  -- display_name (texte) -> jeton hex (spec §4.3). La ligne porte déjà v_token.
  UPDATE network_contributors SET display_name = v_token::text WHERE user_id = v_token;

  -- Journal (jeton, jamais user_id). Idempotent.
  INSERT INTO erasure_log (pseudonym_token, erased_at) VALUES (v_token, now())
  ON CONFLICT (pseudonym_token) DO NOTHING;

  -- ==== SUPPRESSION finale (EXISTANT, inchangé) ====
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

-- ---- BLOC D — Hygiène grant + vérification automatique ----
-- Retire le grant service_role superflu ; authenticated suffit (auth.uid()).
REVOKE EXECUTE ON FUNCTION public.fn_delete_my_account() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_delete_my_account() FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_delete_my_account() FROM service_role;
GRANT EXECUTE ON FUNCTION public.fn_delete_my_account() TO authenticated;

DO $verif$
DECLARE
  v_tok1 uuid; v_tok2 uuid; v_tok3 uuid; v_cnt int;
BEGIN
  v_tok1 := public.fn_pseudonymize_token('11111111-1111-1111-1111-111111111111');
  v_tok2 := public.fn_pseudonymize_token('11111111-1111-1111-1111-111111111111');
  v_tok3 := public.fn_pseudonymize_token('22222222-2222-2222-2222-222222222222');
  IF v_tok1 IS NULL THEN
    RAISE EXCEPTION 'BG2-14 verif : jeton NULL (sel Vault absent ?).';
  END IF;
  IF v_tok1 <> v_tok2 THEN
    RAISE EXCEPTION 'BG2-14 verif : jeton NON deterministe.';
  END IF;
  IF v_tok1 = v_tok3 THEN
    RAISE EXCEPTION 'BG2-14 verif : collision de jetons.';
  END IF;

  -- erasure_log doit etre INACCESSIBLE en authenticated (scenario C : REVOKE + RLS).
  -- On verifie que le SELECT LEVE bien une exception (acces refuse).
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';
  BEGIN
    SELECT count(*) INTO v_cnt FROM public.erasure_log;
    RESET ROLE;
    RAISE EXCEPTION 'BG2-14 verif : erasure_log LISIBLE en authenticated (% lignes) — scenario C KO.', v_cnt;
  EXCEPTION
    WHEN insufficient_privilege THEN
      RESET ROLE;  -- comportement attendu : acces refuse
  END;

  RAISE NOTICE 'BG2-14 verifications OK : jeton deterministe+distinct, erasure_log hors API.';
END $verif$;

COMMIT;
