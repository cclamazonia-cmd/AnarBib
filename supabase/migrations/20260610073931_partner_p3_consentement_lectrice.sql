-- ════════════════════════════════════════════════════════════════════════════
-- §21 PARTNER — P3 : consentement de la lectrice (opt-in révocable, versionné)
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
-- Registre: §21 PARTNER (PARTNER-D1 opt-in ; PARTNER-D8 révocation + versionnage)
--
-- OBJET : une lectrice COMMUNE à deux biblios partenaires consent (ou retire son
-- consentement) à la transparence enrichie, AU NIVEAU DU PARTENARIAT (pas droit
-- par droit). Opt-in explicite ; défaut = transparence minimale (absence de ligne).
--
-- VERSIONNAGE (D8) : le consentement porte sur library_partnerships.config_version
-- (bumpé à chaque AJOUT de droit par P2). Consentement valide ssi config_version
-- consenti = config_version courant. AJOUT de droit → mismatch → re-sollicitation
-- (« vers le haut »). RETRAIT → config_version inchangé → consentement maintenu.
--
-- IDENTITÉ-PAIRE : le consentement référence la ligne CANONIQUE du couple
-- (library_id < partner_library_id), unique représentante de la paire {A,B}.
--
-- HORS P3 : la RLS de transparence qui CONSOMME fn_reader_consent_valid (P4).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Table de consentement ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reader_partnership_consent (
  user_id        uuid        NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  partnership_id uuid        NOT NULL REFERENCES public.library_partnerships (id) ON DELETE CASCADE,  -- ligne canonique
  config_version integer     NOT NULL,
  consented_at   timestamptz NOT NULL DEFAULT now(),
  revoked_at     timestamptz,
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reader_partnership_consent_pkey PRIMARY KEY (user_id, partnership_id)
);

COMMENT ON TABLE public.reader_partnership_consent IS
  'Consentement opt-in d''une lectrice commune à la transparence enrichie d''un partenariat '
  '(PARTNER-D1/D8). partnership_id = ligne canonique de la paire. Valide ssi revoked_at IS NULL '
  'ET config_version = config_version courant du partenariat. Absence de ligne = transparence minimale.';

REVOKE ALL ON TABLE public.reader_partnership_consent FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.reader_partnership_consent TO authenticated;  -- écritures via RPC DEFINER
GRANT ALL ON TABLE public.reader_partnership_consent TO service_role;

ALTER TABLE public.reader_partnership_consent ENABLE ROW LEVEL SECURITY;
-- Lecture : chacune voit uniquement SES propres consentements.
CREATE POLICY reader_partnership_consent_select ON public.reader_partnership_consent
  FOR SELECT USING (user_id = auth.uid());
-- Pas de policy d'écriture : INSERT/UPDATE via RPC DEFINER self-service.

-- ── 2. Helper : id de la ligne CANONIQUE du couple ──────────────────────────
CREATE OR REPLACE FUNCTION public.fn_partnership_canonical_id(p_partnership_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT CASE
           WHEN src.library_id < src.partner_library_id THEN src.id
           ELSE recip.id
         END
  FROM public.library_partnerships src
  LEFT JOIN public.library_partnerships recip
    ON recip.library_id = src.partner_library_id
   AND recip.partner_library_id = src.library_id
  WHERE src.id = p_partnership_id
    AND src.partner_library_id IS NOT NULL
  LIMIT 1;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_partnership_canonical_id(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_partnership_canonical_id(uuid) TO authenticated;

-- ── 3. Helper : le consentement d'une lectrice est-il valide ? (pour la RLS P4)
CREATE OR REPLACE FUNCTION public.fn_reader_consent_valid(p_user_id uuid, p_partnership_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.reader_partnership_consent c
    JOIN public.library_partnerships canon ON canon.id = c.partnership_id
    WHERE c.user_id = p_user_id
      AND c.partnership_id = public.fn_partnership_canonical_id(p_partnership_id)
      AND c.revoked_at IS NULL
      AND c.config_version = canon.config_version
  );
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_reader_consent_valid(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_reader_consent_valid(uuid, uuid) TO authenticated;

-- ── 4. RPC : donner son consentement (self-service /conta) ───────────────────
CREATE OR REPLACE FUNCTION public.fn_partnership_consent(p_partnership_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_canon uuid; v_a uuid; v_b uuid; v_status text; v_cv integer; v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autenticação necessária.' USING ERRCODE = '42501';
  END IF;

  v_canon := public.fn_partnership_canonical_id(p_partnership_id);
  IF v_canon IS NULL THEN
    RAISE EXCEPTION 'Parceria inexistente.' USING HINT = 'error.partnership.not_found';
  END IF;

  SELECT library_id, partner_library_id, status, config_version
    INTO v_a, v_b, v_status, v_cv
    FROM public.library_partnerships WHERE id = v_canon;

  IF v_status <> 'active' THEN
    RAISE EXCEPTION 'A parceria não está ativa.' USING HINT = 'error.partnership.not_active';
  END IF;

  -- Lectrice COMMUNE : appartenance active dans les DEUX biblios de la paire.
  IF NOT (EXISTS (SELECT 1 FROM public.user_library_memberships
                  WHERE user_id = v_uid AND library_id = v_a AND status = 'active')
      AND EXISTS (SELECT 1 FROM public.user_library_memberships
                  WHERE user_id = v_uid AND library_id = v_b AND status = 'active')) THEN
    RAISE EXCEPTION 'Apenas leitor(a/e) comum às duas bibliotecas pode consentir.'
      USING HINT = 'error.partnership.not_common_reader';
  END IF;

  INSERT INTO public.reader_partnership_consent
    (user_id, partnership_id, config_version, consented_at, revoked_at, updated_at)
  VALUES (v_uid, v_canon, v_cv, now(), NULL, now())
  ON CONFLICT (user_id, partnership_id) DO UPDATE
    SET config_version = EXCLUDED.config_version,
        consented_at   = now(),
        revoked_at     = NULL,
        updated_at     = now();
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_partnership_consent(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_partnership_consent(uuid) TO authenticated;

-- ── 5. RPC : retirer son consentement (effet immédiat, D8) ──────────────────
CREATE OR REPLACE FUNCTION public.fn_partnership_revoke_consent(p_partnership_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_canon uuid; v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autenticação necessária.' USING ERRCODE = '42501';
  END IF;
  v_canon := public.fn_partnership_canonical_id(p_partnership_id);
  IF v_canon IS NULL THEN
    RAISE EXCEPTION 'Parceria inexistente.' USING HINT = 'error.partnership.not_found';
  END IF;

  -- Retrait = pose revoked_at (la transparence retombe au minimum immédiatement
  -- via la RLS P4). Idempotent : sans ligne, no-op.
  UPDATE public.reader_partnership_consent
     SET revoked_at = now(), updated_at = now()
   WHERE user_id = v_uid AND partnership_id = v_canon AND revoked_at IS NULL;
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_partnership_revoke_consent(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_partnership_revoke_consent(uuid) TO authenticated;

-- ── 6. Vérification ─────────────────────────────────────────────────────────
DO $verify$
DECLARE v int;
BEGIN
  SELECT count(*) INTO v FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname='reader_partnership_consent' AND c.relrowsecurity=true;
  IF v <> 1 THEN RAISE EXCEPTION 'VERIFY FAILED: table consent absente ou RLS off'; END IF;

  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname IN
     ('fn_partnership_canonical_id','fn_reader_consent_valid','fn_partnership_consent','fn_partnership_revoke_consent');
  IF v <> 4 THEN RAISE EXCEPTION 'VERIFY FAILED: % / 4 fonctions P3', v; END IF;

  IF has_table_privilege('anon','public.reader_partnership_consent','SELECT') THEN
    RAISE EXCEPTION 'VERIFY FAILED: anon a un droit sur reader_partnership_consent';
  END IF;

  RAISE NOTICE 'VERIFY OK: PARTNER P3 — consentement lectrice (table + 4 fonctions).';
END;
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;
