-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — B42 : la double authentification s'exige, mode 'facteurs'
-- (décision de Xavier du 14/10/2026). Activation annoncée par la migration
-- 20261013171710 (« brancher la fonction viendra dans une migration à part »).
--
-- CE QUE CELA CHANGE. Une session aal1 (mot de passe seul) d'un compte qui a
-- un appareil vérifié est refusée par PostgREST (403 AAL2_REQUIRED), par la
-- politique restrictive de Storage et par les Edge Functions gardées. Les
-- autres comptes ne voient rien. Le front demandait déjà le code à ces
-- comptes depuis le lot 1 : le serveur ne fait que cesser de croire l'écran.
-- Au 14/10, un seul compte a un appareil vérifié. Le mode 'equipes' (tout
-- compte d'équipe, appareil ou non) viendra le 1er janvier 2027, par une
-- migration à part.
--
-- UN DÉFAUT DU LOT 2, TROUVÉ AVANT DE BRANCHER (pile locale, PostgREST v14.4).
-- Le refus levait DETAIL = {"status": 403}. PostgREST exige un objet avec
-- `status` ET `headers` : sans `headers`, il répond 500 PGRST121 (« Could not
-- parse JSON in the RAISE SQLSTATE 'PGRST' error ») au lieu du 403 voulu. Le
-- compte était bien bloqué, mais avec une erreur serveur. Le banc SQL ne
-- regardait que le code du refus ; il vérifie désormais la forme de DETAIL.
-- La fonction est reprise de sa définition en production (md5 du corps
-- 6d691f3bc4db74b8f5effb76030a41d7, identique au dépôt), seule la ligne
-- DETAIL change. CREATE OR REPLACE garde ses droits et son commentaire.
--
-- LE BRANCHEMENT. `ALTER ROLE authenticator SET pgrst.db_pre_request` puis
-- `NOTIFY pgrst, 'reload config'` : la méthode documentée par Supabase.
-- Prouvé sur la pile locale avant d'écrire ces lignes : anon, service_role,
-- compte sans appareil, compte en aal2 et liste blanche passent ; compte à
-- appareil vérifié en aal1 → 403 ; une table du réglage absente → échec
-- ouvert, l'API reste servie. Retour arrière :
-- _rollback_20261013234826_b42_la_double_authentification_est_exigee.sql.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION private.fn_avant_requete()
RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_claims jsonb;
  v_chemin text;
  v_bloque boolean := false;
BEGIN
  BEGIN
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
    -- anon, service_role, absence de jeton : rien à exiger.
    IF v_claims IS NULL OR v_claims ->> 'role' IS DISTINCT FROM 'authenticated' THEN RETURN; END IF;
    IF v_claims ->> 'aal' = 'aal2' THEN RETURN; END IF;
    -- La liste blanche : de quoi savoir qu'il faut un code ou s'inscrire.
    v_chemin := ltrim(coalesce(current_setting('request.path', true), ''), '/');
    IF v_chemin IN ('rpc/fn_mon_etat_double_facteur') THEN RETURN; END IF;
    v_bloque := private.fn_aal2_exige_pour_moi();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'B42 fn_avant_requete, échec ouvert : % (%)', SQLERRM, SQLSTATE;
    RETURN;
  END;
  IF v_bloque THEN
    -- DETAIL : PostgREST exige `status` ET `headers` (sinon 500 PGRST121).
    RAISE SQLSTATE 'PGRST' USING
      MESSAGE = json_build_object(
        'code', 'AAL2_REQUIRED',
        'message', 'Double authentification requise',
        'hint', 'twoFactor.required')::text,
      DETAIL = json_build_object('status', 403, 'headers', json_build_object())::text;
  END IF;
END $$;

UPDATE private.double_facteur_reglage SET mode = 'facteurs', modifie_le = now() WHERE id;

ALTER ROLE authenticator SET pgrst.db_pre_request = 'private.fn_avant_requete';
NOTIFY pgrst, 'reload config';
