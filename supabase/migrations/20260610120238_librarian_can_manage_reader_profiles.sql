-- ════════════════════════════════════════════════════════════════════════════
-- Gouvernance : un·e librarian gère les données de base lecteur·rice
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
--
-- DÉCISION (Xavier, 10/06) : au quotidien, un·e bibliothécaire (librarian) DOIT
-- pouvoir gérer les données de base d'un·e lecteur·rice — recherche, lecture,
-- édition de profil/adresse, restriction LOCALE — en lecture ET écriture. Seul le
-- GEL GLOBAL réseau reste réservé aux admins réseau. Sans cela, tout se concentre
-- sur les coordenadores (goulot ingérable : il faudrait un·e coord à chaque
-- permanence). À ratifier dans spec-gouvernance-roles / REGISTRE.
--
-- BUG corrigé : `can_manage_profile_from_my_libraries` gardait sur
-- `user_can_manage_library` (= coordenador/admin) — incohérent, car les RPC de
-- restriction locale (restrict_member, etc.) autorisent déjà le staff (librarian),
-- et les policies RLS profiles s'appellent pourtant « ..._librarian ». Résultat :
-- une librarian pouvait restreindre une lectrice mais ni la CHERCHER ni éditer
-- son profil (erreur trompeuse « não pertence à biblioteca ativa »).
--
-- FIX : faire pointer la garde vers `user_can_act_as_staff_on_library` (librarian
-- + coordenador + admin). Un seul changement → débloque d'un coup la recherche
-- (fn_painel_find_profile_by_lookup), la fiche (fn_painel_get_profile_by_id) et les
-- policies RLS profiles SELECT/UPDATE. Le gel global (freeze_account) n'utilise PAS
-- cette fonction → reste admin-only, intact.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.can_manage_profile_from_my_libraries(p_profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
  SELECT
    coalesce(
      p_profile_id = auth.uid()
      OR EXISTS (
        SELECT 1
        FROM public.user_library_memberships target
        WHERE target.user_id = p_profile_id
          AND coalesce(target.status, '') = 'active'
          AND public.user_can_act_as_staff_on_library(target.library_id)  -- ← librarian inclus
      ),
      false
    );
$function$;

NOTIFY pgrst, 'reload schema';
