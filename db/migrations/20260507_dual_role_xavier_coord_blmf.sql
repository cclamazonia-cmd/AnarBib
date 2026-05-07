-- ═══════════════════════════════════════════════════════════════════════════
-- Migration : Matérialisation du rôle coordenador BLMF de Xavier
-- Date      : 07/05/2026
-- Auteur    : Xavier (assist Claude) — décision politique session 06-07/05
-- ═══════════════════════════════════════════════════════════════════════════
--
-- ⚠ DATA-FIX SPÉCIFIQUE INSTALLATION BLMF — non destinée à un fork
-- ════════════════════════════════════════════════════════════════════
-- Cette migration insère un user_id et library_id en dur. Elle est
-- spécifique à l'installation production AnarBib actuelle. Pour un fork
-- militant qui démarre avec une base vide, cette migration n'a pas à être
-- rejouée — elle ne ferait rien (pas de user/library matching).
--
-- Pour mémoire dans les forks : la décision politique sous-jacente
-- (admin AnarBib et coordenador d'une lib sont deux délégations distinctes,
-- matérialisées par 2 memberships) reste valide. Tout fork doit s'organiser
-- pour matérialiser explicitement ses propres double-memberships si l'admin
-- principal·e exerce aussi la coordination d'une lib particulière.
--
-- CONTEXTE POLITIQUE
-- ------------------
-- Décision validée : "administrador AnarBib" et "coordenador d'une biblio
-- particulière" sont DEUX rôles politiquement distincts. Être admin réseau
-- ne signifie pas implicitement être coord d'une bibliothèque. C'est une
-- délégation à part entière qu'il faut pouvoir donner et reprendre
-- indépendamment.
--
-- Avant cette migration, Xavier n'avait qu'un seul membership :
--   (administrador, BLMF, active, depuis 24/03/2026)
--
-- Mais il exerce de fait la coordination quotidienne de BLMF (validation
-- d'inscriptions, gestion de l'équipe, catalogage). Cette coordination
-- n'était pas matérialisée dans la base de données, ce qui créait une
-- incohérence UX :
--   - Dans /biblioteca onglet équipe (scope='library'), sa propre ligne
--     affichait targetRole='administrador' et donc une option
--     'quit_admin_functions' hors-contexte (cette action appartient à /rede)
--   - L'option contextuelle attendue dans /biblioteca, 'self_demote'
--     (rétrograder de coord à librarian), n'était pas disponible faute
--     de membership coord.
--
-- Ce que fait cette migration :
--   1. INSERT explicite d'un membership coordenador BLMF, daté du jour,
--      avec metadata d'audit traçant la régularisation politique.
--   2. PAS d'appel à fn_team_promote_to_coordenador car (a) outrepasserait
--      les préconditions hiérarchiques (un coord doit déjà être librarian),
--      et (b) enverrait une notification mail "Xavier vous a promu" à
--      Xavier lui-même, ce qui est absurde.
--
-- IMPACT
-- ------
-- - Xavier aura désormais 2 memberships actifs sur BLMF :
--     (administrador, BLMF, active) — depuis 24/03/2026
--     (coordenador,  BLMF, active) — depuis 07/05/2026
-- - Dans /rede onglet Admins : sa ligne admin avec menu quit_admin_functions
-- - Dans /biblioteca BLMF onglet équipe : sa ligne coord avec menu
--   self_demote (après le patch UI à venir qui filtrera par scope)
--
-- ROLLBACK
-- --------
-- DELETE FROM public.user_library_memberships
-- WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
--   AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
--   AND role = 'coordenador'
--   AND created_at::date = '2026-05-07';
--
-- DELETE FROM public.library_membership_audit
-- WHERE target_user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
--   AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
--   AND action = 'promoted_to_coordenador'
--   AND created_at::date = '2026-05-07';
--
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Garde-fou : vérifier qu'aucun membership coord BLMF n'existe déjà
--    (idempotence : si la migration est rejouée par accident, échec propre)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
      AND role = 'coordenador'
  ) THEN
    RAISE NOTICE 'Membership coordenador BLMF existe déjà pour Xavier — migration idempotente, no-op';
    RETURN;
  END IF;

  -- Garde-fou supplémentaire pour fork : si user_id ou library_id n'existent
  -- pas dans cette base, on no-op gracieusement au lieu d'échouer.
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = 'd6710372-e5e5-4608-800b-99a26817c677')
     OR NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca')
  THEN
    RAISE NOTICE 'User ou library cible introuvable dans cette base — migration ignorée (likely a fork)';
    RETURN;
  END IF;

  -- 2. Création du membership coord
  INSERT INTO public.user_library_memberships
    (user_id, library_id, role, status)
  VALUES
    ('d6710372-e5e5-4608-800b-99a26817c677',
     '1234825f-a0f9-4fbd-a875-6551c30ea4ca',
     'coordenador',
     'active');

  -- 3. Audit log avec metadata explicite
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role,
     status_before, status_after, reason, metadata)
  VALUES
    ('1234825f-a0f9-4fbd-a875-6551c30ea4ca',
     'd6710372-e5e5-4608-800b-99a26817c677',
     'd6710372-e5e5-4608-800b-99a26817c677',
     'promoted_to_coordenador',
     'coordenador',
     'absent',
     'active',
     'Régularisation post-décision politique 07/05/2026',
     jsonb_build_object(
       'manual_migration', true,
       'reason', 'matérialisation rétroactive de la coordination de fait',
       'political_decision_session', '06-07/05/2026',
       'rpc_bypass', 'fn_team_promote_to_coordenador outrepassée car (a) auto-promotion par admin AnarBib, (b) éviterait notification mail absurde à soi-même',
       'related_chantier', 'Phase B2 dual-role admin/coord'
     ));

  RAISE NOTICE 'Membership coordenador BLMF créé pour Xavier avec audit explicite';
END;
$$ LANGUAGE plpgsql;
