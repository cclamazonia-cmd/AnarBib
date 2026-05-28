-- =============================================================================
-- Migration : carte-lecteur — generation ouverte a tout membre actif
-- Chantier mobile, 28/05/2026. Correctif suite au test en prod : la version
-- initiale exigeait role='reader', excluant le staff (coordenador/librarian)
-- qui est pourtant membre legitime de la bibliotheque et emprunte comme tout
-- le monde. Decision (Lecture A, 28/05) : tout membre actif peut generer sa
-- carte, sans distinction de role. Horizontalite.
--
-- CREATE OR REPLACE conserve les privileges existants ; on re-pose REVOKE/GRANT
-- par idempotence et conformite au hook pre-commit (doctrine objets securises v2).
-- =============================================================================

CREATE OR REPLACE FUNCTION api.generate_my_reader_card(p_library_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid        uuid := auth.uid();
  v_membership public.user_library_memberships%ROWTYPE;
  v_cards_on   boolean;
  v_slug       text;
  v_token      text;
  v_token_id   uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  -- Appartenance active a cette bibliotheque, QUEL QUE SOIT le role.
  -- (Lecture A 28/05 : reader, librarian, coordenador peuvent tous generer
  -- leur carte. Le staff emprunte aussi ; pas de hierarchie sur la carte.)
  SELECT * INTO v_membership
  FROM public.user_library_memberships
  WHERE user_id = v_uid AND library_id = p_library_id
    AND status = 'active'
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_a_member');
  END IF;

  -- Capacite activee cote biblio ?
  SELECT reader_cards_enabled, slug INTO v_cards_on, v_slug
  FROM public.libraries WHERE id = p_library_id;
  IF NOT COALESCE(v_cards_on, false) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'cards_disabled');
  END IF;

  -- Revoquer le jeton actif precedent (regeneration)
  UPDATE public.reader_card_tokens
  SET status = 'revoked', revoked_at = now(), revoked_reason = 'regenerated'
  WHERE membership_id = v_membership.id AND status = 'active';

  -- Generer le jeton opaque en clair (20 bytes = 40 hex) puis stocker son hash.
  v_token := lower(encode(gen_random_bytes(20), 'hex'));

  INSERT INTO public.reader_card_tokens
    (membership_id, user_id, library_id, token_hash, status)
  VALUES
    (v_membership.id, v_uid, p_library_id, public.fn_hash_claim_token(v_token), 'active')
  RETURNING id INTO v_token_id;

  RETURN jsonb_build_object(
    'ok', true,
    'token', v_token,
    'token_id', v_token_id,
    'library_slug', v_slug
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION api.generate_my_reader_card(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.generate_my_reader_card(uuid) TO authenticated;

COMMENT ON FUNCTION api.generate_my_reader_card(uuid) IS
  'Genere (ou regenere) la carte-lecteur du membre authentifie pour p_library_id. '
  'Tout membre actif (reader/librarian/coordenador), pas seulement reader (Lecture A '
  '28/05). Revoque le jeton actif precedent. Stocke le HASH du jeton, retourne le '
  'clair une seule fois. Retour {ok, token, token_id, library_slug}.';

-- ── DO-block de verification ────────────────────────────────────────────────
DO $$
DECLARE
  v_count int;
BEGIN
  -- La fonction existe toujours et est SECURITY DEFINER
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api' AND p.proname = 'generate_my_reader_card'
    AND p.prosecdef = true;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF KO : generate_my_reader_card absente ou pas SECURITY DEFINER';
  END IF;

  -- anon n'a pas EXECUTE
  SELECT count(*) INTO v_count
  FROM information_schema.routine_privileges
  WHERE routine_schema = 'api' AND routine_name = 'generate_my_reader_card'
    AND grantee IN ('anon', 'PUBLIC');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'VERIF KO : anon/PUBLIC a EXECUTE sur generate_my_reader_card';
  END IF;

  RAISE NOTICE 'VERIF OK : generate_my_reader_card ouverte a tout membre actif.';
END;
$$;
