-- =============================================================================
-- Migration : carte-lecteur (phase beta — generation + revocation)
-- Chantier mobile, decision 28/05/2026 (DECISION_chantier_mobile_arbitrages).
-- Spec : spec-carte-lecteur-v0_1 (amendee en cours d'implementation 28/05) :
--   - token HACHE (reutilise fn_hash_claim_token), jamais stocke en clair
--   - index unique partiel au lieu de contrainte EXCLUDE (pas de btree_gist)
--
-- Doctrine RPC v3 : RPC obligatoire pour ecritures DB. Doctrine objets
-- securises v2 : REVOKE etendu, search_path fixe, DO-block de verification.
-- =============================================================================

-- ── 1. Capacite activable par bibliotheque (modele circulation_mode) ────────
ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS reader_cards_enabled boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.libraries.reader_cards_enabled IS
  'Capacite carte-lecteur (chantier mobile, decision 28/05/2026). Si true, les '
  'lecteur·ices membres peuvent generer une carte-laissez-passer detachable pour '
  'cette bibliotheque. Si false, identification nominale en permanence.';

-- ── 2. Table des jetons de carte-lecteur ────────────────────────────────────
-- On stocke le HASH du jeton (SHA-256 via fn_hash_claim_token), jamais le clair.
-- Le clair n'existe qu'au moment de la generation, retourne une seule fois pour
-- fabriquer le QR. Une fuite de cette table ne revele aucun jeton utilisable.
CREATE TABLE IF NOT EXISTS public.reader_card_tokens (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membership_id   uuid NOT NULL
                    REFERENCES public.user_library_memberships(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL,        -- denormalise pour RLS simple
  library_id      uuid NOT NULL,        -- denormalise pour resolution staff (Paquet 3)
  token_hash      text NOT NULL UNIQUE, -- SHA-256 hex du jeton opaque, jamais le clair
  status          text NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'revoked')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  revoked_at      timestamptz,
  revoked_reason  text                  -- 'regenerated' | 'user_revoked' | NULL
);

COMMENT ON TABLE public.reader_card_tokens IS
  'Jetons de carte-lecteur (chantier mobile, 28/05/2026, A.3 mini-table dediee). '
  'Un jeton actif par appartenance (A.2, garanti par index unique partiel), '
  'historique des revocations conserve. token_hash = SHA-256 du pointeur opaque, '
  'jamais le clair. Resolution vers appartenance via RPC staff (Paquet 3, hors beta).';

-- Index unique partiel : au plus UN jeton actif par appartenance.
-- (Remplace la contrainte EXCLUDE de la spec v0.1 : pas besoin de btree_gist.)
CREATE UNIQUE INDEX IF NOT EXISTS uq_reader_card_active_per_membership
  ON public.reader_card_tokens (membership_id)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_reader_card_tokens_hash
  ON public.reader_card_tokens (token_hash) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_reader_card_tokens_user
  ON public.reader_card_tokens (user_id);


-- ── GRANT explicites sur la table (doctrine objets securises v2, Template 2) ─
-- Scenario B partiel : le lecteur lit ses propres jetons (RLS select_own), mais
-- les ecritures (INSERT/UPDATE/DELETE) sont reservees aux RPC SECURITY DEFINER.
-- anon n'a aucun acces.
REVOKE ALL ON public.reader_card_tokens FROM anon;
GRANT SELECT ON public.reader_card_tokens TO authenticated;
-- Pas de GRANT INSERT/UPDATE/DELETE : seules les RPC DEFINER ecrivent.

-- ── 3. RLS ──────────────────────────────────────────────────────────────────
ALTER TABLE public.reader_card_tokens ENABLE ROW LEVEL SECURITY;

-- Le lecteur lit ses propres jetons (pour afficher l'etat de sa carte).
DROP POLICY IF EXISTS reader_card_tokens_select_own ON public.reader_card_tokens;
CREATE POLICY reader_card_tokens_select_own
  ON public.reader_card_tokens FOR SELECT
  USING (user_id = auth.uid());

-- Aucune policy INSERT/UPDATE/DELETE : tout passe par les RPC SECURITY DEFINER.

-- ── 4. RPC generation (ou regeneration) ─────────────────────────────────────
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

  -- Appartenance reader active a cette bibliotheque
  SELECT * INTO v_membership
  FROM public.user_library_memberships
  WHERE user_id = v_uid AND library_id = p_library_id
    AND role = 'reader' AND status = 'active'
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

  -- Generer le jeton opaque en clair (20 bytes = 40 hex, pattern maison public_id)
  -- puis stocker SEULEMENT son hash. Le clair est retourne une seule fois.
  v_token := lower(encode(gen_random_bytes(20), 'hex'));

  INSERT INTO public.reader_card_tokens
    (membership_id, user_id, library_id, token_hash, status)
  VALUES
    (v_membership.id, v_uid, p_library_id, public.fn_hash_claim_token(v_token), 'active')
  RETURNING id INTO v_token_id;

  -- Retour : le jeton EN CLAIR (pour le QR, une seule fois) + le slug. Jamais de user_id.
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
  'Genere (ou regenere) la carte-lecteur du lecteur authentifie pour p_library_id. '
  'Revoque le jeton actif precedent. Stocke le HASH du jeton, retourne le clair une '
  'seule fois pour le QR. Retour {ok, token, token_id, library_slug}. Phase beta, 28/05/2026.';

-- ── 5. RPC revocation ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.revoke_my_reader_card(p_token_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.reader_card_tokens%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  SELECT * INTO v_row FROM public.reader_card_tokens WHERE id = p_token_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;
  IF v_row.user_id <> v_uid THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_owner');
  END IF;
  IF v_row.status <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_revoked');
  END IF;

  UPDATE public.reader_card_tokens
  SET status = 'revoked', revoked_at = now(), revoked_reason = 'user_revoked'
  WHERE id = p_token_id;

  RETURN jsonb_build_object('ok', true, 'token_id', p_token_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION api.revoke_my_reader_card(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.revoke_my_reader_card(uuid) TO authenticated;

COMMENT ON FUNCTION api.revoke_my_reader_card(uuid) IS
  'Revoque une carte-lecteur du lecteur authentifie (ownership check). Retour '
  '{ok, token_id}. Phase beta, 28/05/2026.';

-- ── 6. DO-block de verification (doctrine objets securises v2) ──────────────
-- Teste en contexte anon simule que les RPC refusent et que la RLS protege.
-- RAISE EXCEPTION => rollback auto de toute la migration si un invariant casse.
DO $$
DECLARE
  v_count int;
BEGIN
  -- La table existe et a RLS activee
  SELECT count(*) INTO v_count
  FROM pg_tables WHERE schemaname = 'public' AND tablename = 'reader_card_tokens'
    AND rowsecurity = true;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF KO : reader_card_tokens absente ou RLS non activee';
  END IF;

  -- Les 2 RPC existent dans le schema api
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('generate_my_reader_card', 'revoke_my_reader_card');
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'VERIF KO : RPC api.generate/revoke_my_reader_card manquantes (trouve %)', v_count;
  END IF;

  -- L'index unique partiel existe
  SELECT count(*) INTO v_count
  FROM pg_indexes WHERE schemaname = 'public'
    AND indexname = 'uq_reader_card_active_per_membership';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF KO : index unique partiel manquant';
  END IF;

  -- anon ne doit PAS pouvoir executer generate (REVOKE effectif)
  SELECT count(*) INTO v_count
  FROM information_schema.routine_privileges
  WHERE routine_schema = 'api' AND routine_name = 'generate_my_reader_card'
    AND grantee IN ('anon', 'PUBLIC');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'VERIF KO : anon/PUBLIC a encore EXECUTE sur generate_my_reader_card';
  END IF;

  RAISE NOTICE 'VERIF OK : carte-lecteur phase beta installee correctement.';
END;
$$;
