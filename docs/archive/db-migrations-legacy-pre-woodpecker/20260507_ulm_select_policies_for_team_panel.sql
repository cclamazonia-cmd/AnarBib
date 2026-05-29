-- ═══════════════════════════════════════════════════════════════════════════
-- Migration : RLS SELECT sur user_library_memberships pour TeamPanel
-- Date      : 07/05/2026
-- Auteur    : Xavier (assist Claude) — Phase B1 follow-up
-- ═══════════════════════════════════════════════════════════════════════════
--
-- CONTEXTE
-- --------
-- Avant cette migration, public.user_library_memberships avait une seule
-- policy SELECT : ulm_select_own_memberships (auth.uid() = user_id).
-- Conséquence : un·e utilisateur·rice ne pouvait voir que SES propres
-- lignes — jamais celles des autres.
--
-- Cette restriction empêche le composant <TeamPanel /> (Phase A + B1) de
-- fonctionner :
--   - En scope=library, un·e coord ne voyait que sa propre ligne au lieu
--     de toute l'équipe staff de sa biblio
--   - En scope=network, un·e admin ne voyait que sa propre ligne au lieu
--     de tous les memberships du réseau
--
-- Bug repéré le 07/05/2026 par Xavier en testant la Phase B1 : le compte
-- U000176 (Patricia, coord BTL) n'apparaissait pas dans le décompte des
-- membres du réseau.
--
-- DÉCISIONS POLITIQUES (validées 07/05/2026)
-- ------------------------------------------
-- Q1 : Visibilité staff au sein d'une lib
--   → Le staff (librarian/coord/admin) voit le staff de sa lib. JAMAIS les
--     readers via cette policy. Les readers se gèrent ailleurs avec leurs
--     propres policies adaptées (PainelPage, prêts, etc.). Surface d'attaque
--     minimale, audit plus simple.
--
-- Q2 : Visibilité cross-réseau pour l'administrador
--   → L'administrador voit TOUT (staff + readers, toutes libs). Reflète
--     honnêtement le pouvoir réel de l'admin (qui a déjà accès SQL direct).
--
-- POLICIES AJOUTÉES
-- -----------------
-- 1. ulm_select_staff_visible_to_staff_same_lib
--    Le staff actif d'une lib peut voir les memberships staff (rôle in
--    librarian/coord/admin) de SA lib. Pas les readers.
--
-- 2. ulm_select_all_for_administrador
--    L'administrador AnarBib (rôle administrador actif sur n'importe
--    quelle lib) voit tous les memberships de toutes les libs, tous rôles
--    confondus.
--
-- L'ancienne policy ulm_select_own_memberships est PRÉSERVÉE — elle reste
-- nécessaire pour qu'un reader voie ses propres lignes (account, etc.).
--
-- HELPER CRÉÉ
-- -----------
-- fn_caller_is_administrador() — SECURITY DEFINER, lit user_library_memberships
-- sans déclencher les policies. Évite les boucles RLS lors des sous-requêtes
-- dans les policies elles-mêmes.
--
-- IDEMPOTENCE
-- -----------
-- Les CREATE POLICY échouent si la policy existe déjà. Pour rendre la
-- migration ré-exécutable, on DROP IF EXISTS d'abord. Idem pour la fonction.
--
-- ROLLBACK
-- --------
-- DROP POLICY IF EXISTS ulm_select_staff_visible_to_staff_same_lib
--   ON public.user_library_memberships;
-- DROP POLICY IF EXISTS ulm_select_all_for_administrador
--   ON public.user_library_memberships;
-- DROP FUNCTION IF EXISTS public.fn_caller_is_administrador();
--
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 1. Helper : caller est-il administrador AnarBib ? ──────────────────────

CREATE OR REPLACE FUNCTION public.fn_caller_is_administrador()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships ulm
    WHERE ulm.user_id = auth.uid()
      AND ulm.role = 'administrador'
      AND ulm.status = 'active'
  );
$$;

COMMENT ON FUNCTION public.fn_caller_is_administrador() IS
  'Renvoie true si auth.uid() a un membership administrador actif (au moins '
  'une lib). SECURITY DEFINER pour éviter les boucles RLS dans les policies '
  'qui interrogent la même table user_library_memberships.';

-- ─── 2. Policy : staff voit staff de sa lib ────────────────────────────────

DROP POLICY IF EXISTS ulm_select_staff_visible_to_staff_same_lib
  ON public.user_library_memberships;

CREATE POLICY ulm_select_staff_visible_to_staff_same_lib
  ON public.user_library_memberships
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (
    -- La ligne consultée concerne un staff (pas un reader)
    role IN ('librarian', 'coordenador', 'administrador')
    -- ET le caller a un rôle staff actif dans la même lib
    AND public.user_has_library_staff_role(auth.uid(), library_id)
  );

COMMENT ON POLICY ulm_select_staff_visible_to_staff_same_lib
  ON public.user_library_memberships IS
  'Phase B1 follow-up 07/05/2026 : le staff (librarian/coord/admin) actif '
  'd''une lib peut voir tous les autres staff de la même lib. Permet à '
  '<TeamPanel scope="library" /> de fonctionner. Ne donne JAMAIS accès aux '
  'readers — visibilité minimale.';

-- ─── 3. Policy : administrador voit tout ───────────────────────────────────

DROP POLICY IF EXISTS ulm_select_all_for_administrador
  ON public.user_library_memberships;

CREATE POLICY ulm_select_all_for_administrador
  ON public.user_library_memberships
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (
    public.fn_caller_is_administrador()
  );

COMMENT ON POLICY ulm_select_all_for_administrador
  ON public.user_library_memberships IS
  'Phase B1 follow-up 07/05/2026 : un·e administrador AnarBib voit tous '
  'les memberships de toutes les libs (staff + readers). Permet à '
  '<TeamPanel scope="network" /> de fonctionner et reflète honnêtement '
  'le pouvoir réel de l''admin (qui a déjà accès SQL direct).';
