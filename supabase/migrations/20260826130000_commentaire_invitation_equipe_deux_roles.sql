-- =====================================================================
-- 20260826130000_commentaire_invitation_equipe_deux_roles.sql
--
-- Objet : le commentaire de `public.library_team_invitations` date du lot
--         « accueil d'équipe » (20260619125325) et annonce encore
--         « rôle librarian ». Depuis 20260826120000, la même table porte
--         AUSSI les propositions de passage à la coordination.
--
-- Pourquoi ça compte : ce commentaire est ce que lit d'abord qui inspecte
--         le schéma (psql \d+, Studio, advisors). Un commentaire faux sur
--         une table de gouvernance envoie chercher ailleurs un circuit qui
--         est là — c'est le genre d'erreur qui coûte une demi-journée.
--
-- Portée : COMMENT ON uniquement. Aucune structure, aucun droit, aucune
--          fonction touchés. Idempotent par nature (COMMENT ON écrase).
--          Ne fait pas partie du circuit collégial : le rollback de
--          20260826120000 ne la défait pas, et n'a pas à le faire.
-- =====================================================================

BEGIN;

COMMENT ON TABLE public.library_team_invitations IS
  'Invitations d''équipe d''une biblio, dans les deux sens du terme : accueil (role_proposed = librarian) ou passage à la coordination (role_proposed = coordenador, depuis la migration 20260826120000). Écrites uniquement via les RPC SECDEF fn_team_*_invitation. Cf. CADRAGE_accueil_equipe_2026-06-19 et 20260826120000.';

COMMENT ON COLUMN public.library_team_invitations.role_proposed IS
  'Rôle proposé : librarian (accueil dans l''équipe) ou coordenador (promotion collégiale, migration 20260826120000, principe P2). La promotion directe par fn_team_promote_to_coordenador est désactivée depuis cette date — la fonction lève collegiality_required.';

COMMIT;
