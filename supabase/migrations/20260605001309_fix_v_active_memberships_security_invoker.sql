-- 20260605120000_fix_v_active_memberships_security_invoker.sql
--
-- Corrige l'unique ERROR des security advisors.
--
-- Problème :
--   public.v_active_memberships est une vue détenue par `postgres` et SANS
--   security_invoker → elle s'exécute avec les droits du propriétaire et
--   CONTOURNE la RLS des tables sous-jacentes (user_library_memberships,
--   membership_payments, libraries). Or `anon` disposait du droit SELECT sur
--   la vue : un visiteur non connecté pouvait donc lire, via l'API, les
--   adhésions et paiements (montants, dates, méthodes) de TOUS les usagers.
--
-- Vérifié AVANT application (lecture seule) :
--   * authenticated possède SELECT (grant table) + RLS "own/staff" sur les 3
--     tables → la vue en invoker continue de renvoyer à chaque usager SES
--     propres lignes (policies ulm_select_own_memberships / mp_select_own).
--   * anon n'a AUCUNE policy RLS sur les tables d'adhésion → la vue en invoker
--     ne lui renvoie plus rien.
--   * les fonctions SECURITY DEFINER qui lisent la vue (api.get_due_date_for_loan,
--     fn_is_loan_blocked_by_dues, fn_v2_*) ne sont pas affectées (contexte owner).
--   * fn_my_account_status (SECURITY INVOKER) conserve son SELECT sur la vue.
--
-- Nuance de comportement (attendue, plutôt plus correcte) :
--   en invoker, la vue ne renvoie une adhésion que pour une bibliothèque
--   visible de l'appelant via fn_library_visible_to_caller(id). Pour ses
--   propres adhésions, un membre passe ce test ; vérifier si jamais tu as un
--   cas de membre d'une bibliothèque "isolée" non visible de ses propres membres.

-- 1) La RLS de l'appelant s'applique désormais à la vue.
ALTER VIEW public.v_active_memberships SET (security_invoker = true);

-- 2) anon n'a aucune raison d'accéder à cette vue.
REVOKE ALL ON public.v_active_memberships FROM anon;

-- 3) authenticated ne garde que SELECT ; les droits d'écriture sur une vue
--    sont du bruit hérité des grants par défaut.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.v_active_memberships FROM authenticated;

-- 4) Hygiène / défense en profondeur : anon possède un grant SELECT inutile sur
--    membership_payments (la RLS le bloque déjà, mais on retire la surface).
REVOKE SELECT ON public.membership_payments FROM anon;
