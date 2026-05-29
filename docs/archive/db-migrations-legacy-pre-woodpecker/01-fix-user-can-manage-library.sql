-- ============================================================================
-- Fix critique : user_can_manage_library
-- ============================================================================
-- Avant : la fonction testait des rôles 'admin' et 'owner' qui n'existent pas
-- dans le schéma user_library_memberships. Conséquence : la fonction renvoyait
-- toujours false sauf pour 'librarian' (rôle inexistant en pratique aussi).
--
-- Cette fonction est utilisée dans 16 RLS et 19 fonctions RPC :
--   - interlibrary_loans_v2_*
--   - library_notification_profiles, library_notification_policies
--   - library_mail_channels
--   - document_permission_requests
--
-- Le fix : aligner sur les rôles réels et la sémantique de "manage"
-- (= prendre des décisions politiques pour la biblio).
--
-- Distinction avec user_has_library_staff_role (qui inclut librarian) :
--   - user_has_library_staff_role     → "fait partie de l'équipe"
--   - user_can_manage_library         → "peut engager politiquement la biblio"
--
-- Mode préservé : STABLE + SECURITY INVOKER (déclaration originale).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.user_can_manage_library(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.library_id = p_library_id
      AND m.status = 'active'
      AND m.role IN ('coordenador', 'administrador')
  );
$$;

-- ─── Vérifications post-exécution ────────────────────────────────────────────
--
-- 1. Vérifier que le mode est préservé :
-- SELECT 
--   proname,
--   CASE provolatile WHEN 's' THEN 'STABLE' ELSE 'AUTRE' END AS volatility,
--   CASE WHEN prosecdef THEN 'DEFINER' ELSE 'INVOKER' END AS security_mode
-- FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname='public' AND p.proname='user_can_manage_library';
--
-- 2. Vérifier le nouveau corps :
-- SELECT prosrc FROM pg_proc p
--   JOIN pg_namespace n ON n.oid = p.pronamespace
--   WHERE n.nspname='public' AND p.proname='user_can_manage_library';
-- → doit contenir : m.role IN ('coordenador', 'administrador')
-- ============================================================================
