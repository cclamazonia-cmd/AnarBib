-- ════════════════════════════════════════════════════════════════════════════
-- MULTI — Multi-appartenance lecteur — Phase 2 : statut par bibliothèque
-- Auteur  : Claude (Opus)
-- Session : MULTI P2 (statut par biblio)
-- Date    : 2026-06-08 (UTC)
-- Registre: §20 MULTI (MULTI-Z23, spec §17.2/§11) ; #CL.10
--
-- `api.fn_my_memberships_status()` : détail par appartenance pour la lectrice
-- courante (onglet « mes biblios », bandeau de contexte, P5). Complète
-- `fn_my_account_status` (qui garde « la vérité vue de la primaire ») en
-- exposant le statut de CHAQUE biblio + les drapeaux des conditions de
-- circulation (validation par-appartenance, restriction, cotisation).
--
-- SECURITY DEFINER filtrée strictement sur `auth.uid()` → ne renvoie JAMAIS
-- que les appartenances de l'appelant·e (auth.uid() lit le JWT de la requête,
-- pas le propriétaire de la fonction). Évite les frictions RLS sur
-- `v_active_memberships` (jointure paiements).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION api.fn_my_memberships_status()
RETURNS TABLE (
  library_id           uuid,
  library_slug         text,
  library_name         text,
  role                 text,
  status               text,
  is_primary           boolean,
  physically_validated boolean,
  is_restricted        boolean,
  restricted_reason    text,
  local_reader_number  text,
  membership_enabled   boolean,
  dues_status          text,
  dues_blocking        boolean,
  days_until_expiry    integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT
    m.library_id,
    l.slug,
    COALESCE(l.short_name, l.name),
    m.role,
    m.status,
    m.is_primary,
    (m.physically_validated_at IS NOT NULL),
    m.is_restricted,
    m.restricted_reason,
    m.local_reader_number,
    COALESCE(l.membership_enabled, false),
    am.dues_status,
    public.fn_is_loan_blocked_by_dues(m.user_id, m.library_id),
    am.days_until_expiry::integer
  FROM public.user_library_memberships m
  JOIN public.libraries l ON l.id = m.library_id
  LEFT JOIN public.v_active_memberships am
    ON am.user_id = m.user_id AND am.library_id = m.library_id
  WHERE m.user_id = auth.uid()
    AND m.status <> 'removed'
  ORDER BY m.is_primary DESC, l.name;
$function$;

REVOKE EXECUTE ON FUNCTION api.fn_my_memberships_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_my_memberships_status() TO authenticated;
