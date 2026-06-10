-- ════════════════════════════════════════════════════════════════════════════
-- Fix : v_active_memberships exclut les appartenances 'removed'
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
--
-- BUG : v_active_memberships (zone cotisations/MULTI) part de
-- user_library_memberships SANS filtrer le statut → elle laisse passer les
-- lignes 'removed' (anciens rôles conservés pour l'historique). Conséquence :
-- pour un·e lectrice ayant changé de rôle (ex. reader→librarian, ancienne ligne
-- 'removed'), la vue renvoie 2 lignes pour (user, library). La RPC
-- api.fn_my_memberships_status joint cette vue sur (user_id, library_id) sans
-- dédup → l'appartenance active est DUPLIQUÉE à l'affichage (« Mes bibliothèques »
-- montrait 2 lignes identiques). Cas réel : Lívia (BLMF librarian + reader removed).
--
-- FIX : ajouter `WHERE ulm.status <> 'removed'` — conforme au nom/intention de la
-- vue. Corrige tout fan-out dû aux lignes removed (tous consommateurs). Grants et
-- security_invoker préservés par CREATE OR REPLACE.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.v_active_memberships
  WITH (security_invoker = true) AS
  WITH last_payment AS (
    SELECT DISTINCT ON (mp.user_id, mp.library_id)
      mp.id, mp.user_id, mp.library_id, mp.rule_id, mp.amount_paid, mp.currency,
      mp.paid_at, mp.valid_from, mp.valid_until, mp.payment_method
    FROM public.membership_payments mp
    WHERE mp.archived_at IS NULL
    ORDER BY mp.user_id, mp.library_id, mp.valid_until DESC, mp.paid_at DESC
  )
  SELECT
    ulm.user_id,
    ulm.library_id,
    ulm.role,
    ulm.is_primary,
    ulm.status AS membership_status,
    l.membership_enabled,
    lp.id            AS last_payment_id,
    lp.rule_id       AS last_rule_id,
    lp.amount_paid   AS last_amount_paid,
    lp.currency      AS last_currency,
    lp.paid_at       AS last_paid_at,
    lp.valid_from    AS last_valid_from,
    lp.valid_until   AS last_valid_until,
    lp.payment_method AS last_payment_method,
    CASE
      WHEN NOT l.membership_enabled THEN 'not_applicable'
      WHEN lp.id IS NULL THEN 'never_paid'
      WHEN lp.valid_until IS NULL THEN 'lifetime'
      WHEN lp.valid_until >= CURRENT_DATE THEN 'up_to_date'
      ELSE 'expired'
    END AS dues_status,
    CASE WHEN lp.valid_until IS NULL THEN NULL::integer
         ELSE lp.valid_until - CURRENT_DATE END AS days_until_expiry
  FROM public.user_library_memberships ulm
    JOIN public.libraries l ON l.id = ulm.library_id
    LEFT JOIN last_payment lp ON lp.user_id = ulm.user_id AND lp.library_id = ulm.library_id
  WHERE ulm.status <> 'removed';

NOTIFY pgrst, 'reload schema';
