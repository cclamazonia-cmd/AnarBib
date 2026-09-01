-- =====================================================================
-- ROLLBACK de 20260901234500_le_circuit_collegial_se_dit_dans_l_app.sql
--
-- Retire les deux déclencheurs et la fonction. Les notifications déjà
-- posées ne sont PAS supprimées : elles ont été lues, ou attendent de
-- l'être, et les effacer ferait disparaître de la cloche des demandes bien
-- réelles. Elles vieilliront comme les autres.
--
-- ATTENTION : après ce rollback, le circuit collégial redevient dépendant
-- du seul e-mail pour avancer — une proposition peut à nouveau naître,
-- être ignorée et périmer sans que personne ne l'ait su.
-- =====================================================================

BEGIN;

DROP TRIGGER IF EXISTS trg_team_invitation_notify_inapp_ins ON public.library_team_invitations;
DROP TRIGGER IF EXISTS trg_team_invitation_notify_inapp_upd ON public.library_team_invitations;
DROP FUNCTION IF EXISTS public.fn_team_invitation_notify_inapp();

COMMIT;
