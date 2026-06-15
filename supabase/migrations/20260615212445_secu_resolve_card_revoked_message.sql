-- =========================================================================
-- Paquet CARD-UX — resolve_reader_card : message clair pour une carte révoquée
-- =========================================================================
-- Date     : 2026-06-15
-- Chantier : Carte-lecteur — UX de résolution staff (MOBILE)
-- Auteur   : AnarBib
-- Session  : Perf UX + nettoyage advisors sécurité
--
-- POURQUOI
--   Régénérer une carte révoque la précédente. Jusqu'ici, scanner une vieille
--   carte (révoquée) donnait le même « non reconnu » qu'un jeton inconnu
--   (token_not_found) — anti-fuite, mais déroutant pour le staff face au·à la
--   lecteur·rice. On distingue désormais une carte RÉVOQUÉE, mais UNIQUEMENT
--   pour le staff de la bonne biblio (même garde que la résolution réussie) :
--   aucune fuite vers un appelant non autorisé.
--
-- ANTI-FUITE (préservé)
--   token inconnu  → token_not_found  (message neutre)
--   jeton existant mais appelant non staff de sa biblio → not_staff_of_library
--     (message neutre IDENTIQUE → on ne divulgue pas que le jeton existe)
--   jeton existant + appelant staff de sa biblio + statut <> active
--     → card_revoked (message utile, réservé au staff légitime)
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION api.resolve_reader_card(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid      uuid := auth.uid();
  v_hash     text;
  v_tok      public.reader_card_tokens%ROWTYPE;
  v_prof     public.profiles%ROWTYPE;
  v_is_staff boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  IF COALESCE(btrim(p_token), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_token');
  END IF;

  v_hash := public.fn_hash_claim_token(lower(btrim(p_token)));

  -- Jeton recherché QUEL QUE SOIT le statut (actif privilégié en cas de
  -- collision de hash, impossible en pratique) → permet de distinguer ensuite
  -- carte révoquée vs jeton inconnu, sans fuite (cf. en-tête).
  SELECT * INTO v_tok
  FROM public.reader_card_tokens
  WHERE token_hash = v_hash
  ORDER BY (status = 'active') DESC, created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'token_not_found');
  END IF;

  -- Garde : staff actif (librarian|coordenador) de la biblio du jeton.
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships m
    WHERE m.user_id = v_uid
      AND m.library_id = v_tok.library_id
      AND m.status = 'active'
      AND m.role IN ('librarian', 'coordenador')
  ) INTO v_is_staff;

  IF NOT v_is_staff THEN
    -- Message neutre identique à token_not_found (anti-fuite).
    RETURN jsonb_build_object('ok', false, 'reason', 'not_staff_of_library');
  END IF;

  -- L'appelant est staff de la bonne biblio : on peut l'informer précisément.
  IF v_tok.status <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'card_revoked');
  END IF;

  -- Résolution de l'identité (le staff de la bonne biblio y a droit).
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
$function$;

-- -------------------------------------------------------------------------
-- Vérification : la fonction s'exécute (contexte authentifié simulé) ; deux
-- branches sûres testées. Rollback si comportement inattendu.
-- -------------------------------------------------------------------------
DO $verify$
DECLARE
  v_uid uuid;
  r1 jsonb;
  r2 jsonb;
BEGIN
  SELECT id INTO v_uid FROM auth.users LIMIT 1;
  IF v_uid IS NULL THEN
    RAISE NOTICE 'CARD-UX : aucun utilisateur pour le test, branches non exercées.';
  ELSE
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    r1 := api.resolve_reader_card('');                      -- attendu : invalid_token
    r2 := api.resolve_reader_card('zzzz_not_a_real_token'); -- attendu : token_not_found
    RESET ROLE;
    IF (r1->>'reason') <> 'invalid_token' THEN
      RAISE EXCEPTION 'Verif echouee : jeton vide attendu invalid_token, obtenu %. Rollback.', r1;
    END IF;
    IF (r2->>'reason') <> 'token_not_found' THEN
      RAISE EXCEPTION 'Verif echouee : jeton bidon attendu token_not_found, obtenu %. Rollback.', r2;
    END IF;
    RAISE NOTICE 'CARD-UX OK : resolve_reader_card branches invalid_token + token_not_found.';
  END IF;
END
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;
