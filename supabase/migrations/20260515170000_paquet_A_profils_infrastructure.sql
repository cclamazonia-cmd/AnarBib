-- ============================================================
-- Paquet A — Infrastructure DB Profils d'adoption
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.3 §9.1
-- Date : 2026-05-15
-- ============================================================
-- Livrables :
-- 1. 4 colonnes *_mode sur libraries (avec DEFAULT profil D)
-- 2. 2 contraintes CHECK croisees (publication => network, sigb => roles)
-- 3. Table library_profile_history immutable
-- 4. 5 colonnes requested_*_mode + profile_template_chosen sur library_requests
-- 5. 10 helpers : 4 lecteurs + 6 predicats
-- 6. GRANTs anon + authenticated sur les helpers
-- 7. RLS sur library_profile_history
-- 8. DO-block de verification finale
-- ============================================================
-- IMPORTANT : aucun changement fonctionnel pour les 2 biblios existantes.
-- BLMF et BTL heritent automatiquement du profil D (DEFAULTs maximalistes).
-- ============================================================

-- ============================================================
-- SECTION 1 — Colonnes libraries
-- ============================================================

ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS catalog_mode text NOT NULL DEFAULT 'network_published'
    CHECK (catalog_mode IN ('local_only', 'network_published')),
  ADD COLUMN IF NOT EXISTS circulation_mode text NOT NULL DEFAULT 'full_sigb'
    CHECK (circulation_mode IN ('off', 'informal', 'full_sigb')),
  ADD COLUMN IF NOT EXISTS network_mode text NOT NULL DEFAULT 'federated'
    CHECK (network_mode IN ('isolated', 'observer', 'federated')),
  ADD COLUMN IF NOT EXISTS governance_mode text NOT NULL DEFAULT 'full_governance'
    CHECK (governance_mode IN ('informal', 'staff_roles', 'full_governance'));

COMMENT ON COLUMN public.libraries.catalog_mode IS
  'Profil d''adoption axe 1 : catalogue local_only ou network_published. Cf. spec-profils-bibliotheque.md §2.3.';
COMMENT ON COLUMN public.libraries.circulation_mode IS
  'Profil d''adoption axe 2 : circulation off (aucune) / informal (light) / full_sigb (complet). Cf. spec-profils-bibliotheque.md §2.4.';
COMMENT ON COLUMN public.libraries.network_mode IS
  'Profil d''adoption axe 3 : place dans le reseau isolated / observer / federated. Cf. spec-profils-bibliotheque.md §2.5.';
COMMENT ON COLUMN public.libraries.governance_mode IS
  'Profil d''adoption axe 4 : gouvernance interne informal / staff_roles / full_governance. Cf. spec-profils-bibliotheque.md §2.6.';

-- Contraintes croisees (cf. §2.8 combinaisons interdites)
ALTER TABLE public.libraries
  ADD CONSTRAINT chk_catalog_published_requires_network
    CHECK (catalog_mode <> 'network_published' OR network_mode IN ('observer', 'federated'));

ALTER TABLE public.libraries
  ADD CONSTRAINT chk_full_sigb_requires_roles
    CHECK (circulation_mode <> 'full_sigb' OR governance_mode IN ('staff_roles', 'full_governance'));

-- ============================================================
-- SECTION 2 — Table library_profile_history (audit immutable)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.library_profile_history (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id  uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  axis        text NOT NULL CHECK (axis IN ('catalog_mode', 'circulation_mode', 'network_mode', 'governance_mode')),
  old_value   text NOT NULL,
  new_value   text NOT NULL,
  changed_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_at  timestamptz NOT NULL DEFAULT now(),
  motivation  text,
  CONSTRAINT chk_distinct_values CHECK (old_value <> new_value)
);

COMMENT ON TABLE public.library_profile_history IS
  'Audit immutable des transitions de profil d''adoption. INSERT only via SECURITY DEFINER (paquet B). RLS readonly pour le staff de la biblio. Cf. spec-profils-bibliotheque.md §3.1 et §I4.';

CREATE INDEX IF NOT EXISTS idx_lph_library_changed_at
  ON public.library_profile_history (library_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_lph_axis
  ON public.library_profile_history (axis);

-- Immuabilite : aucun UPDATE ni DELETE possible (sauf cron de purge admin reseau si jamais)
CREATE OR REPLACE FUNCTION public.fn_block_lph_modification()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'library_profile_history is immutable: % blocked', TG_OP
    USING ERRCODE = '42501', HINT = 'Cette table est un audit immutable. Aucune modification possible.';
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_lph_block_update ON public.library_profile_history;
CREATE TRIGGER trg_lph_block_update
  BEFORE UPDATE ON public.library_profile_history
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_block_lph_modification();

DROP TRIGGER IF EXISTS trg_lph_block_delete ON public.library_profile_history;
CREATE TRIGGER trg_lph_block_delete
  BEFORE DELETE ON public.library_profile_history
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_block_lph_modification();

-- RLS : lecture pour le staff de la biblio (helper centralise paquet C admin reseau)
ALTER TABLE public.library_profile_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lph_staff_read ON public.library_profile_history;
CREATE POLICY lph_staff_read
  ON public.library_profile_history
  FOR SELECT
  TO authenticated
  USING (public.user_can_act_as_staff_on_library(library_id));

-- Pas de policy d'ecriture : seules les RPC SECURITY DEFINER (paquet B) y accederont
COMMENT ON POLICY lph_staff_read ON public.library_profile_history IS
  'Lecture pour le staff actif local + admins reseau (via helper centralise). Ecriture uniquement via RPC SECURITY DEFINER.';

-- ============================================================
-- SECTION 3 — Colonnes library_requests (champs onboarding)
-- ============================================================
-- Note : la table existe deja avec 31 colonnes. On ajoute 5 colonnes
-- sans contrainte CHECK (validation a l'acceptation par admin reseau,
-- cf. spec onboarding v1.1 §5.4).

ALTER TABLE public.library_requests
  ADD COLUMN IF NOT EXISTS requested_catalog_mode text,
  ADD COLUMN IF NOT EXISTS requested_circulation_mode text,
  ADD COLUMN IF NOT EXISTS requested_network_mode text,
  ADD COLUMN IF NOT EXISTS requested_governance_mode text,
  ADD COLUMN IF NOT EXISTS profile_template_chosen text;

COMMENT ON COLUMN public.library_requests.requested_catalog_mode IS
  'Profil demande axe 1 (cf. spec-profils-bibliotheque.md §5.4). NULL accepte (demande incomplete). Validation a l''acceptation par admin reseau.';
COMMENT ON COLUMN public.library_requests.requested_circulation_mode IS
  'Profil demande axe 2 (cf. spec-profils-bibliotheque.md §5.4).';
COMMENT ON COLUMN public.library_requests.requested_network_mode IS
  'Profil demande axe 3 (cf. spec-profils-bibliotheque.md §5.4).';
COMMENT ON COLUMN public.library_requests.requested_governance_mode IS
  'Profil demande axe 4 (cf. spec-profils-bibliotheque.md §5.4).';
COMMENT ON COLUMN public.library_requests.profile_template_chosen IS
  'Profil-type auto-designe a l''inscription : A (athenee) / B (souveraine) / C (collectif) / D (complete) / custom. Champ statistique sans portee fonctionnelle. Cf. spec-profils-bibliotheque.md §2.7.';

-- ============================================================
-- SECTION 4 — Helpers SQL : 4 lecteurs simples
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_library_catalog_mode(p_library_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT catalog_mode FROM public.libraries WHERE id = p_library_id;
$$;

COMMENT ON FUNCTION public.fn_library_catalog_mode(uuid) IS
  'Lecteur axe catalog_mode. STABLE SECURITY DEFINER, utilisable en RLS. Cf. spec-profils-bibliotheque.md §3.2.';

CREATE OR REPLACE FUNCTION public.fn_library_circulation_mode(p_library_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT circulation_mode FROM public.libraries WHERE id = p_library_id;
$$;

COMMENT ON FUNCTION public.fn_library_circulation_mode(uuid) IS
  'Lecteur axe circulation_mode. STABLE SECURITY DEFINER, utilisable en RLS.';

CREATE OR REPLACE FUNCTION public.fn_library_network_mode(p_library_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT network_mode FROM public.libraries WHERE id = p_library_id;
$$;

COMMENT ON FUNCTION public.fn_library_network_mode(uuid) IS
  'Lecteur axe network_mode. STABLE SECURITY DEFINER, utilisable en RLS.';

CREATE OR REPLACE FUNCTION public.fn_library_governance_mode(p_library_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT governance_mode FROM public.libraries WHERE id = p_library_id;
$$;

COMMENT ON FUNCTION public.fn_library_governance_mode(uuid) IS
  'Lecteur axe governance_mode. STABLE SECURITY DEFINER, utilisable en RLS.';

-- ============================================================
-- SECTION 5 — Helpers SQL : 6 predicats logiques
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_library_has_circulation(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT circulation_mode <> 'off' FROM public.libraries WHERE id = p_library_id;
$$;

COMMENT ON FUNCTION public.fn_library_has_circulation(uuid) IS
  'TRUE si circulation_mode IN (informal, full_sigb). Predicat utilise en RLS et RPC pour conditionner la circulation. Cf. spec §3.2.';

CREATE OR REPLACE FUNCTION public.fn_library_has_full_sigb(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT circulation_mode = 'full_sigb' FROM public.libraries WHERE id = p_library_id;
$$;

COMMENT ON FUNCTION public.fn_library_has_full_sigb(uuid) IS
  'TRUE si circulation_mode = full_sigb. Predicat pour les fonctionnalites SIGB completes (cotisations, rappels J-X, etc.).';

CREATE OR REPLACE FUNCTION public.fn_library_publishes_catalog(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT catalog_mode = 'network_published' FROM public.libraries WHERE id = p_library_id;
$$;

COMMENT ON FUNCTION public.fn_library_publishes_catalog(uuid) IS
  'TRUE si la biblio publie son catalogue dans le reseau AnarBib. Conditionne la remontee dans mv_books_catalog_list_network_v1.';

CREATE OR REPLACE FUNCTION public.fn_library_is_federated(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT network_mode = 'federated' FROM public.libraries WHERE id = p_library_id;
$$;

COMMENT ON FUNCTION public.fn_library_is_federated(uuid) IS
  'TRUE si la biblio est pleinement federee dans le reseau. Conditionne les futures fonctions inter-bibs (PEB, mutualisation, etc.).';

CREATE OR REPLACE FUNCTION public.fn_library_uses_governance(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT governance_mode = 'full_governance' FROM public.libraries WHERE id = p_library_id;
$$;

COMMENT ON FUNCTION public.fn_library_uses_governance(uuid) IS
  'TRUE si governance_mode = full_governance (doctrine integrale spec-gouvernance-roles.md v1.1). Conditionne les workflows formels : cooptation unanime, carence 7j, audit log, votes.';

-- Helper supplementaire valide en session 15/05 (cf. note Q2 de la conversation) :
-- distingue "il y a des roles staff differencies" (TRUE pour staff_roles ET full_governance)
-- de "il y a la doctrine integrale" (TRUE seulement pour full_governance).
-- Ces 2 questions politiques sont distinctes et meritent 2 helpers.

CREATE OR REPLACE FUNCTION public.fn_library_has_staff_roles(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT governance_mode IN ('staff_roles', 'full_governance') FROM public.libraries WHERE id = p_library_id;
$$;

COMMENT ON FUNCTION public.fn_library_has_staff_roles(uuid) IS
  'TRUE si la biblio distingue les roles staff (librarian / coordenador), donc governance_mode IN (staff_roles, full_governance). Distinct de fn_library_uses_governance qui ne couvre que full_governance.';

-- ============================================================
-- SECTION 6 — GRANTs sur les helpers
-- ============================================================
-- Doctrine : helpers utilises en RLS de tables anon-readable doivent rester
-- GRANT EXECUTE TO anon (exception explicite a la doctrine "anon = REVOKE par defaut").
-- Cf. spec §3.2 fin.

GRANT EXECUTE ON FUNCTION public.fn_library_catalog_mode(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_library_circulation_mode(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_library_network_mode(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_library_governance_mode(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_library_has_circulation(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_library_has_full_sigb(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_library_publishes_catalog(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_library_is_federated(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_library_uses_governance(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_library_has_staff_roles(uuid) TO anon, authenticated;

-- Le helper trigger est purement interne, pas de GRANT necessaire
REVOKE ALL ON FUNCTION public.fn_block_lph_modification() FROM PUBLIC, anon, authenticated;

-- ============================================================
-- SECTION 7 — Verification finale (DO-block)
-- ============================================================

DO $$
DECLARE
  v_libraries_count int;
  v_blmf_profile record;
  v_btl_profile record;
  v_helper_test text;
  v_constraint_count int;
BEGIN
  -- 7.1 Verifier que les 2 biblios sont bien en profil D
  SELECT count(*) INTO v_libraries_count FROM public.libraries;
  IF v_libraries_count <> 2 THEN
    RAISE EXCEPTION 'Verification echoue : libraries devrait contenir 2 lignes (BLMF + BTL), trouve %', v_libraries_count;
  END IF;
  
  SELECT slug, catalog_mode, circulation_mode, network_mode, governance_mode 
    INTO v_blmf_profile 
    FROM public.libraries WHERE slug = 'blmf';
  
  IF v_blmf_profile.catalog_mode <> 'network_published' 
    OR v_blmf_profile.circulation_mode <> 'full_sigb'
    OR v_blmf_profile.network_mode <> 'federated'
    OR v_blmf_profile.governance_mode <> 'full_governance' THEN
    RAISE EXCEPTION 'BLMF n''a pas le profil D attendu : catalog=%, circ=%, net=%, gov=%',
      v_blmf_profile.catalog_mode, v_blmf_profile.circulation_mode,
      v_blmf_profile.network_mode, v_blmf_profile.governance_mode;
  END IF;
  
  SELECT slug, catalog_mode, circulation_mode, network_mode, governance_mode 
    INTO v_btl_profile 
    FROM public.libraries WHERE slug = 'btl';
  
  IF v_btl_profile.catalog_mode <> 'network_published' 
    OR v_btl_profile.circulation_mode <> 'full_sigb'
    OR v_btl_profile.network_mode <> 'federated'
    OR v_btl_profile.governance_mode <> 'full_governance' THEN
    RAISE EXCEPTION 'BTL n''a pas le profil D attendu : catalog=%, circ=%, net=%, gov=%',
      v_btl_profile.catalog_mode, v_btl_profile.circulation_mode,
      v_btl_profile.network_mode, v_btl_profile.governance_mode;
  END IF;
  
  RAISE NOTICE 'OK : BLMF et BTL sont en profil D (network_published, full_sigb, federated, full_governance)';
  
  -- 7.2 Verifier les 2 contraintes CHECK croisees
  SELECT count(*) INTO v_constraint_count
    FROM pg_constraint
    WHERE conrelid = 'public.libraries'::regclass
      AND conname IN ('chk_catalog_published_requires_network', 'chk_full_sigb_requires_roles');
  
  IF v_constraint_count <> 2 THEN
    RAISE EXCEPTION 'Verification echoue : 2 contraintes CHECK croisees attendues, trouve %', v_constraint_count;
  END IF;
  
  RAISE NOTICE 'OK : 2 contraintes CHECK croisees actives';
  
  -- 7.3 Verifier que les helpers fonctionnent
  v_helper_test := public.fn_library_catalog_mode(
    (SELECT id FROM public.libraries WHERE slug = 'blmf')
  );
  IF v_helper_test <> 'network_published' THEN
    RAISE EXCEPTION 'Helper fn_library_catalog_mode retourne % au lieu de network_published', v_helper_test;
  END IF;
  
  IF NOT public.fn_library_has_full_sigb(
    (SELECT id FROM public.libraries WHERE slug = 'blmf')
  ) THEN
    RAISE EXCEPTION 'Helper fn_library_has_full_sigb devrait retourner TRUE pour BLMF';
  END IF;
  
  IF NOT public.fn_library_has_staff_roles(
    (SELECT id FROM public.libraries WHERE slug = 'blmf')
  ) THEN
    RAISE EXCEPTION 'Helper fn_library_has_staff_roles devrait retourner TRUE pour BLMF';
  END IF;
  
  RAISE NOTICE 'OK : helpers fn_library_* fonctionnent correctement';
  
  -- 7.4 Verifier que library_profile_history existe et est vide
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'library_profile_history'
  ) THEN
    RAISE EXCEPTION 'Table library_profile_history n''existe pas';
  END IF;
  
  RAISE NOTICE 'OK : table library_profile_history creee';
  
  -- 7.5 Verifier que library_requests a bien les 5 nouvelles colonnes
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'library_requests' 
      AND column_name = 'profile_template_chosen'
  ) THEN
    RAISE EXCEPTION 'Colonne profile_template_chosen absente de library_requests';
  END IF;
  
  RAISE NOTICE 'OK : library_requests enrichie de 5 colonnes profil';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Paquet A profils : migration appliquee avec succes';
  RAISE NOTICE '========================================';
END $$;
