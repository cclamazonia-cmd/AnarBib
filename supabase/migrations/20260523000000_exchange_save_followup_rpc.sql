-- =============================================================================
-- 20260523000000_exchange_save_followup_rpc.sql
-- =============================================================================
-- Etape 10 (EA-11, exchanges) - PAQUET 4 : suivi / followup des trocas.
--
-- L'etat de suivi d'une troca acceptee est stocke dans la sous-cle
-- object_ref.execution_followup de la document_permission_request elle-meme
-- (pas de table dediee). Cette RPC ecrit ce suivi en faisant le MERGE COTE
-- SERVEUR : elle lit l'object_ref actuel en base, fusionne le patch dans
-- execution_followup, et reecrit - sans jamais ecraser les autres cles de
-- l'object_ref (les documents de la troca poses au paquet 1).
--
-- POURQUOI une RPC et pas un .from().update() : le suivi de troca est
-- bidirectionnel (les deux bibliotheques coordonnent l'execution). Un UPDATE
-- direct ecraserait toute la colonne object_ref depuis une copie client
-- potentiellement perimee -> risque de lost update sur les donnees posees
-- par l'autre partie. En lisant l'etat reel en base avant de fusionner, la
-- RPC elimine ce risque sur les cles hors execution_followup.
--
-- SECURITY INVOKER : la RPC s'execute avec les droits de l'appelant, donc la
-- RLS document_permission_requests_update (USING + WITH CHECK :
-- user_can_manage_library(requester) OR user_can_manage_library(target))
-- reste le filtre de securite. Seules les deux parties de la troca peuvent
-- ecrire. La RPC n'ajoute donc pas de privilege, elle ajoute un merge sur.
--
-- Conforme doctrine RPC v3 (ecriture avec merge/validation -> RPC) et
-- doctrine de creation d'objets backend v2 (REVOKE large + GRANT cible,
-- DO-block de verification).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_exchange_save_followup(
  p_request_id uuid,
  p_followup_patch jsonb
)
RETURNS public.document_permission_requests
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.document_permission_requests;
  v_ref jsonb;
  v_current_followup jsonb;
  v_next_followup jsonb;
BEGIN
  IF p_request_id IS NULL THEN
    RAISE EXCEPTION 'fn_exchange_save_followup: identifiant de proposition manquant.';
  END IF;

  -- Lecture de la ligne. La RLS SELECT borne deja l'acces aux deux parties.
  SELECT * INTO v_row
  FROM public.document_permission_requests
  WHERE id = p_request_id
  LIMIT 1;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'fn_exchange_save_followup: proposition de troca introuvable.';
  END IF;

  -- Le suivi ne concerne que les trocas, et seulement quand elles sont acceptees.
  IF lower(coalesce(v_row.object_type, '')) <> 'interlibrary_exchange' THEN
    RAISE EXCEPTION 'fn_exchange_save_followup: cette proposition n''est pas une troca.';
  END IF;
  IF lower(coalesce(v_row.status, '')) <> 'accepted' THEN
    RAISE EXCEPTION 'fn_exchange_save_followup: le suivi n''est possible que pour une troca aceita.';
  END IF;

  -- object_ref courant (peut etre une chaine JSON ou deja un jsonb selon
  -- l'historique des ecritures ; on tolere les deux).
  BEGIN
    v_ref := CASE
      WHEN v_row.object_ref IS NULL OR btrim(v_row.object_ref) = '' THEN '{}'::jsonb
      ELSE v_row.object_ref::jsonb
    END;
  EXCEPTION WHEN others THEN
    -- object_ref non parseable : on repart d'un objet vide plutot que d'echouer.
    v_ref := '{}'::jsonb;
  END;

  -- Merge du patch dans execution_followup, en preservant le reste de l'object_ref.
  v_current_followup := coalesce(v_ref->'execution_followup', '{}'::jsonb);
  IF jsonb_typeof(v_current_followup) <> 'object' THEN
    v_current_followup := '{}'::jsonb;
  END IF;
  IF jsonb_typeof(coalesce(p_followup_patch, '{}'::jsonb)) <> 'object' THEN
    RAISE EXCEPTION 'fn_exchange_save_followup: le patch de suivi doit etre un objet JSON.';
  END IF;

  v_next_followup := v_current_followup
    || coalesce(p_followup_patch, '{}'::jsonb)
    || jsonb_build_object('updated_at', to_char(timezone('utc', now()), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));

  v_ref := v_ref || jsonb_build_object('execution_followup', v_next_followup);

  -- Ecriture. La RLS UPDATE (USING + WITH CHECK) s'applique : si l'appelant
  -- ne gere aucune des deux bibliotheques, l'UPDATE ne touche aucune ligne.
  UPDATE public.document_permission_requests
     SET object_ref = v_ref::text,
         updated_at = timezone('utc', now()),
         updated_by = auth.uid()
   WHERE id = p_request_id
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'fn_exchange_save_followup: ecriture refusee (permissions insuffisantes pour cette troca).';
  END IF;

  RETURN v_row;
END;
$$;

-- --- Permissions : REVOKE large puis GRANT cible (doctrine objets v2) --------
REVOKE ALL ON FUNCTION public.fn_exchange_save_followup(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_exchange_save_followup(uuid, jsonb) TO authenticated, service_role;

-- --- Verification en fin de transaction --------------------------------------
DO $$
DECLARE
  v_exists boolean;
  v_auth_exec boolean;
  v_anon_exec boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_exchange_save_followup'
  ) INTO v_exists;
  IF NOT v_exists THEN
    RAISE EXCEPTION 'Echec : fn_exchange_save_followup non creee.';
  END IF;

  SELECT has_function_privilege('authenticated', 'public.fn_exchange_save_followup(uuid, jsonb)', 'EXECUTE')
    INTO v_auth_exec;
  IF NOT v_auth_exec THEN
    RAISE EXCEPTION 'Echec : authenticated n''a pas EXECUTE sur fn_exchange_save_followup.';
  END IF;

  SELECT has_function_privilege('anon', 'public.fn_exchange_save_followup(uuid, jsonb)', 'EXECUTE')
    INTO v_anon_exec;
  IF v_anon_exec THEN
    RAISE EXCEPTION 'Echec : anon ne doit pas avoir EXECUTE sur fn_exchange_save_followup.';
  END IF;

  RAISE NOTICE 'OK : fn_exchange_save_followup creee, EXECUTE accorde a authenticated (refuse a anon). SECURITY INVOKER -> la RLS document_permission_requests_update reste le filtre.';
END $$;
