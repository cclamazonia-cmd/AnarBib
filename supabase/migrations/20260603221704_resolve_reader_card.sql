-- ════════════════════════════════════════════════════════════════════════
-- CARTE-LECTEUR Paquet 3 (amorce) : api.resolve_reader_card
-- ════════════════════════════════════════════════════════════════════════
-- Resolution staff d'un jeton de carte-lecteur scanne (ou saisi). Le morceau
-- differe a la livraison du Paquet 1 (commentaire de table : "Resolution via
-- RPC staff, Paquet 3, hors beta"). Contrat : spec-carte-lecteur v0.2 (5.3).
--
-- Le jeton scanne (clair, 40 hex) est hache par la MEME fonction que la
-- generation (fn_hash_claim_token = SHA-256 hex) puis cherche parmi les jetons
-- actifs (index partiel idx_reader_card_tokens_hash). Le clair n'est jamais
-- stocke ni journalise.
--
-- Garde interne : l'appelant doit etre staff actif (librarian|coordenador) de
-- la bibliotheque DU JETON (derivee du jeton, pas un parametre). Sinon
-- not_staff_of_library, sans rien divulguer (ni l'existence du jeton ni
-- l'identite). DOC-OBJ-2 : DEFINER + search_path fige + REVOKE + GRANT cible.
-- ════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION api.resolve_reader_card(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_hash text;
  v_tok  public.reader_card_tokens%ROWTYPE;
  v_prof public.profiles%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  IF COALESCE(btrim(p_token), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_token');
  END IF;

  v_hash := public.fn_hash_claim_token(lower(btrim(p_token)));

  SELECT * INTO v_tok
  FROM public.reader_card_tokens
  WHERE token_hash = v_hash AND status = 'active'
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'token_not_found');
  END IF;

  -- Autorisation : staff actif (librarian|coordenador) de la biblio du jeton.
  -- On ne divulgue rien si l'appelant n'a pas ce droit.
  IF NOT EXISTS (
    SELECT 1
    FROM public.user_library_memberships m
    WHERE m.user_id = v_uid
      AND m.library_id = v_tok.library_id
      AND m.status = 'active'
      AND m.role IN ('librarian', 'coordenador')
  ) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_staff_of_library');
  END IF;

  -- Resolution de l'identite (le staff de la bonne biblio y a droit)
  SELECT * INTO v_prof FROM public.profiles WHERE id = v_tok.user_id;

  RETURN jsonb_build_object(
    'ok',             true,
    'reader_user_id', v_tok.user_id,
    'membership_id',  v_tok.membership_id,
    'library_id',     v_tok.library_id,
    'public_id',      v_prof.public_id,
    'display_name',   NULLIF(btrim(COALESCE(v_prof.first_name, '') || ' ' || COALESCE(v_prof.last_name, '')), ''),
    'is_restricted',  COALESCE(v_prof.is_restricted, false)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION api.resolve_reader_card(text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.resolve_reader_card(text)
  TO authenticated;

-- Verification (RAISE EXCEPTION = rollback si le grant fonctionnel n'a pas pris)
DO $verify$
DECLARE
  v_fn text := 'api.resolve_reader_card(text)';
BEGIN
  IF NOT has_function_privilege('authenticated', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated doit pouvoir EXECUTE % (grant manquant)', v_fn;
  END IF;
  IF has_function_privilege('anon', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'anon ne doit PAS pouvoir EXECUTE %', v_fn;
  END IF;
  IF has_function_privilege('service_role', v_fn, 'EXECUTE') THEN
    RAISE NOTICE 'service_role conserve EXECUTE sur % (re-grant defaut privileges possible) - non bloquant', v_fn;
  END IF;
END
$verify$;

NOTIFY pgrst, 'reload schema';
