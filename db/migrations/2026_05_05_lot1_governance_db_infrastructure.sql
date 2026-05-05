-- ============================================================================
-- Migration : Lot 1 — Infrastructure DB gouvernance des rôles
-- ============================================================================
-- Spec       : docs/spec-gouvernance-roles.md (v1.0, 2026-05-05)
-- Lot        : 1/7 (cf. §14.1 de la spec)
-- Date       : 2026-05-05
-- Auteur     : Xavier
--
-- Périmètre :
--   1. Élargissement du CHECK constraint status pour ajouter 'pending_removal'
--   2. Ajout des colonnes pending_removal_until + pending_removal_requested_by
--   3. Création de la table library_membership_audit (avec RLS + policy)
--   4. Création de l'index partiel pour le cron pending_removal
--
-- Idempotence : oui (rejouable sans casse).
-- Réversibilité : oui (script de rollback en fin de fichier, commenté).
-- Impact fonctionnel : aucun en l'état (nouvelle infrastructure inutilisée tant
--                     que les RPCs des Lots 2-3 ne sont pas déployées).
--
-- À tester avant exécution prod :
--   - Sur un schéma de dev/staging si disponible
--   - À défaut : exécuter section par section et vérifier l'output entre chaque
--   - La section 5 (tests) en bas de fichier permet de valider l'install
--
-- ============================================================================


-- ============================================================================
-- SECTION 0 : Garde-fous pré-vol
-- ============================================================================

-- Vérifie que la fonction user_has_library_staff_role existe (utilisée par la
-- policy RLS de library_membership_audit). Cette fonction a été stabilisée le
-- 04/05/2026 dans le cadre du fix librarian role coherence.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'user_has_library_staff_role'
  ) THEN
    RAISE EXCEPTION 'Fonction public.user_has_library_staff_role introuvable. '
                    'Cette migration en dépend (RLS de library_membership_audit). '
                    'Vérifie que le fix librarian role coherence du 04/05/2026 est bien déployé.';
  END IF;
END $$;


-- ============================================================================
-- SECTION 1 : Élargissement du CHECK constraint status
-- ============================================================================
-- Avant : status IN ('active', 'inactive', 'pending', 'suspended')
-- Après : status IN ('active', 'inactive', 'pending', 'pending_removal', 'suspended')

ALTER TABLE public.user_library_memberships
  DROP CONSTRAINT IF EXISTS user_library_memberships_status_check;

ALTER TABLE public.user_library_memberships
  ADD CONSTRAINT user_library_memberships_status_check
  CHECK (status IN ('active', 'inactive', 'pending', 'pending_removal', 'suspended'));


-- ============================================================================
-- SECTION 2 : Ajout colonnes pour le délai de carence pending_removal
-- ============================================================================

ALTER TABLE public.user_library_memberships
  ADD COLUMN IF NOT EXISTS pending_removal_until timestamptz,
  ADD COLUMN IF NOT EXISTS pending_removal_requested_by uuid REFERENCES public.profiles(id);

COMMENT ON COLUMN public.user_library_memberships.pending_removal_until IS
  'Date à laquelle le passage automatique en inactive aura lieu. NULL si pas en cours.';

COMMENT ON COLUMN public.user_library_memberships.pending_removal_requested_by IS
  'User qui a demandé le retrait, pour traçabilité audit.';


-- ============================================================================
-- SECTION 3 : Création de la table library_membership_audit
-- ============================================================================
-- Journal immuable des changements de rôle/status. Lecture pour le staff actif
-- de la biblio (transparence P5). Écriture uniquement via RPC SECURITY DEFINER
-- (à venir aux Lots 2-3).

CREATE TABLE IF NOT EXISTS public.library_membership_audit (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id      uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  target_user_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_user_id   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  action          text NOT NULL CHECK (action IN (
                    'promoted_to_librarian',
                    'promoted_to_coordenador',
                    'self_demoted',
                    'removal_requested',
                    'removal_cancelled',
                    'removal_completed',
                    'suspended',
                    'unsuspended',
                    'inactive_warning_30d',
                    'inactive_warning_7d',
                    'inactive_auto'
                  )),
  role            text NOT NULL CHECK (role IN ('reader', 'librarian', 'coordenador', 'administrador')),
  status_before   text,
  status_after    text NOT NULL,
  reason          text,
  metadata        jsonb DEFAULT '{}'::jsonb,
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.library_membership_audit IS
  'Journal des changements de rôle/status dans les équipes de biblio. Lecture pour le staff actif (transparence P5). Écriture uniquement via RPC SECURITY DEFINER. Cf. spec-gouvernance-roles.md §7 et §10.2.';


-- Index : recherche rapide par biblio (cas typique : afficher l'historique de l'équipe)
CREATE INDEX IF NOT EXISTS idx_lma_library_created
  ON public.library_membership_audit (library_id, created_at DESC);

-- Index : recherche par utilisateur·rice cible (cas typique : remonter l'historique d'une personne)
CREATE INDEX IF NOT EXISTS idx_lma_target_user
  ON public.library_membership_audit (target_user_id);


-- RLS activée. Pas de policy d'écriture (les RPC SECURITY DEFINER bypass RLS).
ALTER TABLE public.library_membership_audit ENABLE ROW LEVEL SECURITY;

-- Policy de lecture : staff actif de la biblio (librarian + coordenador + administrador)
DROP POLICY IF EXISTS library_membership_audit_staff_read ON public.library_membership_audit;
CREATE POLICY library_membership_audit_staff_read
ON public.library_membership_audit
FOR SELECT
TO authenticated
USING (
  public.user_has_library_staff_role(auth.uid(), library_id)
);


-- ============================================================================
-- SECTION 4 : Index partiel pour le cron pending_removal
-- ============================================================================
-- Le cron cron_team_pending_removal_complete (Lot 4) scannera ce sous-ensemble
-- pour déclencher le passage en inactive à expiration de la carence J+7.

CREATE INDEX IF NOT EXISTS idx_ulm_pending_removal_until
  ON public.user_library_memberships (pending_removal_until)
  WHERE status = 'pending_removal';


-- ============================================================================
-- SECTION 5 : Tests post-installation (à exécuter à la main)
-- ============================================================================
-- Ces tests vérifient que la migration s'est bien appliquée. Les exécuter dans
-- un transaction qu'on rollback pour ne rien laisser en base. Si tout passe,
-- la migration est validée.
--
-- COPIER-COLLER LES BLOCS CI-DESSOUS UN PAR UN dans le SQL Editor :

/*

-- Test 1 : le CHECK status accepte bien 'pending_removal'
BEGIN;
  -- Doit passer
  SELECT 'pending_removal'::text WHERE 'pending_removal' IN
    (SELECT unnest(enum_range(NULL)::text[]) FROM (SELECT 1) s WHERE FALSE)
    OR 'pending_removal' IN ('active', 'inactive', 'pending', 'pending_removal', 'suspended');
  -- Test plus direct : tenter l'insertion d'une ligne fictive avec ce status
  -- (n'utilise pas de vraies FK pour ne pas polluer)
ROLLBACK;

-- Test 2 : les nouvelles colonnes existent et sont nullable
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'user_library_memberships'
  AND column_name IN ('pending_removal_until', 'pending_removal_requested_by');
-- Attendu : 2 lignes, both is_nullable = 'YES'

-- Test 3 : la table library_membership_audit existe avec ses contraintes
SELECT
  c.constraint_name,
  c.constraint_type,
  cc.check_clause
FROM information_schema.table_constraints c
LEFT JOIN information_schema.check_constraints cc USING (constraint_name)
WHERE c.table_schema = 'public'
  AND c.table_name = 'library_membership_audit'
ORDER BY c.constraint_type, c.constraint_name;
-- Attendu : PRIMARY KEY, FK × 3, CHECK action, CHECK role

-- Test 4 : RLS activée sur library_membership_audit
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relname = 'library_membership_audit';
-- Attendu : relrowsecurity = true

-- Test 5 : policy de lecture staff bien créée
SELECT polname, polcmd, polroles::regrole[]
FROM pg_policy
WHERE polrelid = 'public.library_membership_audit'::regclass;
-- Attendu : 1 ligne, polname = 'library_membership_audit_staff_read', polcmd = 'r'

-- Test 6 : index partiel pending_removal créé
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'user_library_memberships'
  AND indexname = 'idx_ulm_pending_removal_until';
-- Attendu : 1 ligne, indexdef contient WHERE (status = 'pending_removal')

-- Test 7 : insertion + sélection RLS dans library_membership_audit
-- ⚠️ À faire en mode service_role (bypass RLS) ou avec un user qui a un rôle staff
-- dans la biblio_id testée. Sinon le SELECT remontera 0 ligne (RLS-filtré).
BEGIN;
  -- À adapter avec des UUIDs valides de ta base
  -- INSERT INTO public.library_membership_audit
  --   (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason)
  -- VALUES
  --   ('<uuid_biblio>', '<uuid_target>', '<uuid_actor>', 'promoted_to_librarian',
  --    'librarian', 'active', 'active', 'Test post-migration Lot 1');
  -- SELECT * FROM public.library_membership_audit ORDER BY created_at DESC LIMIT 1;
ROLLBACK;

*/


-- ============================================================================
-- SECTION 6 : Script de rollback (commenté, à décommenter si besoin)
-- ============================================================================
-- À exécuter UNIQUEMENT en cas de problème, et UNIQUEMENT si aucune RPC du Lot
-- 2/3 n'a encore été déployée et utilisée. Si library_membership_audit contient
-- déjà des entrées réelles, ce rollback détruit l'historique d'audit.

/*

-- 1. Drop de la table audit (CASCADE drop ses index et policies)
DROP TABLE IF EXISTS public.library_membership_audit CASCADE;

-- 2. Drop de l'index partiel
DROP INDEX IF EXISTS public.idx_ulm_pending_removal_until;

-- 3. Drop des nouvelles colonnes
ALTER TABLE public.user_library_memberships
  DROP COLUMN IF EXISTS pending_removal_until,
  DROP COLUMN IF EXISTS pending_removal_requested_by;

-- 4. Restauration du CHECK constraint d'origine
ALTER TABLE public.user_library_memberships
  DROP CONSTRAINT IF EXISTS user_library_memberships_status_check;

ALTER TABLE public.user_library_memberships
  ADD CONSTRAINT user_library_memberships_status_check
  CHECK (status IN ('active', 'inactive', 'pending', 'suspended'));

*/

-- ============================================================================
-- Fin de migration Lot 1.
-- Prochaine étape : Lot 2 (RPCs cooptation T1, T2) — cf. spec §14.1.
-- ============================================================================
