-- ════════════════════════════════════════════════════════════════════════════
-- MULTI — Multi-appartenance lecteur — UI validation staff (backend)
-- Auteur  : Claude (Opus)
-- Session : MULTI P5 (frontend) — volet validation staff
-- Date    : 2026-06-09 (UTC)
-- Registre: §20 MULTI (spec §8, #CL.10) — complète P4 (request/validate_membership)
--
-- RPC `api.list_pending_validations(library)` : liste les inscriptions
-- `pending_validation` (rôle reader) d'une biblio, AVEC nom/email du·de la
-- postulant·e, pour l'écran staff de validation.
--
-- POURQUOI une RPC SECURITY DEFINER plutôt qu'un SELECT direct côté client :
-- la RLS `profiles_select_same_library_librarian` repose sur
-- `can_manage_profile_from_my_libraries(id)`, qui exige une appartenance
-- `status='active'`. Or un·e postulant·e est `pending_validation` (pas encore
-- active) → son profil est INVISIBLE au staff via RLS (poule-œuf). La RPC lève
-- ce blocage tout en restreignant l'exposition : seul·e un·e librarian/coordenador
-- ACTIF de la biblio voit les demandes de SA biblio, et uniquement les champs
-- d'affichage nécessaires.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION api.list_pending_validations(p_library_id uuid DEFAULT NULL)
RETURNS TABLE (
  membership_id uuid,
  user_id       uuid,
  library_id    uuid,
  library_name  text,
  email         text,
  first_name    text,
  last_name     text,
  requested_at  timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT m.id, m.user_id, m.library_id,
         COALESCE(l.short_name, l.name) AS library_name,
         p.email, p.first_name, p.last_name,
         m.created_at AS requested_at
  FROM public.user_library_memberships m
  JOIN public.libraries l ON l.id = m.library_id
  LEFT JOIN public.profiles p ON p.id = m.user_id
  WHERE m.role = 'reader'
    AND m.status = 'pending_validation'
    AND (p_library_id IS NULL OR m.library_id = p_library_id)
    -- L'appelant·e doit être staff ACTIF (librarian/coordenador) de la biblio
    -- de l'appartenance — même garde que api.validate_membership (P4).
    AND EXISTS (
      SELECT 1 FROM public.user_library_memberships s
      WHERE s.user_id = auth.uid()
        AND s.library_id = m.library_id
        AND s.role IN ('librarian', 'coordenador')
        AND s.status = 'active'
    )
  ORDER BY m.created_at ASC;
$function$;

REVOKE EXECUTE ON FUNCTION api.list_pending_validations(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.list_pending_validations(uuid) TO authenticated;
