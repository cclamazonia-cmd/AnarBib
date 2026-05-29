-- ═══════════════════════════════════════════════════════════════════════════
-- Renouvellement granulaire par item — PHASE 2 (vues de statut par item)
-- ───────────────────────────────────────────────────────────────────────────
-- Spec : docs/specs/spec-renouvellement-granulaire.md
-- Prérequis : phases 1a + 1b appliquées (colonne renewals_used par item + cœur).
--
-- CONTENU 2 :
--   2 nouvelles vues exposant le statut de renouvellement PAR ITEM (et non plus
--   agrégé par emprunt) :
--     - api.my_loans_renewal_status_by_item_v1     (parcours lecteur)
--     - api.staff_loans_renewal_status_by_item_v1  (Painel staff)
--
--   Elles répliquent exactement la logique des vues par emprunt existantes
--   (my_loans_renewal_status_v1 / staff_loans_renewal_status_v1) mais au grain
--   item : chaque ligne = un item ouvert, évalué contre SON propre compteur
--   renewals_used et SON book_id (pour la réservation concurrente), avec
--   p_quantity => 1.
--
--   CHOIX : les vues par emprunt existantes ne sont PAS modifiées (additif, pas
--   de régression du front actuel). Le moteur de règles (resolve_circulation_rule,
--   get_due_date_after_renewal, get_remaining_renewals) est agnostique et reste
--   inchangé — il suffit de l'alimenter avec le compteur par item.
--
--   HORS PÉRIMÈTRE PHASE 2 : les vues d'historique (my_loans_history_v1,
--   painel_loans_history_v1) continuent d'exposer le renewals_used du header.
--   L'historique d'un emprunt archivé garde son sens au niveau emprunt
--   (combien de fois il a été prolongé au total) ; granulariser l'historique
--   par item est non prioritaire et pourra être traité ultérieurement.
--
--   security_invoker = true : même mode que les vues existantes (RLS appliquée
--   selon l'appelant·e — le lecteur voit ses emprunts, le staff ceux de sa
--   bibliothèque, via les policies de emprestimos_v2 / emprestimo_itens_v2).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Vue lecteur : statut de renouvellement par item ─────────────────────────
CREATE OR REPLACE VIEW api.my_loans_renewal_status_by_item_v1
WITH (security_invoker = true) AS
WITH my_open_items AS (
  SELECT e.id AS emprestimo_id,
         i.line_no,
         i.sub_id,
         i.book_id,
         i.holding_id,
         e.user_id,
         e.library_id,
         COALESCE(i.renewals_used, 0) AS renewals_used,
         COALESCE(i.extended_until, i.due_at) AS effective_due_at
  FROM emprestimos_v2 e
  JOIN emprestimo_itens_v2 i ON i.emprestimo_id = e.id
  WHERE e.user_id = auth.uid()
    AND e.archived_at IS NULL
    AND i.item_status = 'aberto'
),
with_dues AS (
  SELECT l.*,
         fn_is_loan_blocked_by_dues(l.user_id, l.library_id) AS dues_blocked,
         (EXISTS (
            SELECT 1
              FROM reserva_linhas_v2 rl
              JOIN reservas_v2 r ON r.id = rl.reserva_id
             WHERE rl.book_id = l.book_id
               AND r.library_id = l.library_id
               AND r.user_id <> l.user_id
               AND (r.status_global = ANY (ARRAY['ativa'::text, 'parcialmente_encerrada'::text]))
               AND rl.item_status = 'ativa'::text
               AND r.archived_at IS NULL
         )) AS reserved_by_other
  FROM my_open_items l
),
with_rule AS (
  SELECT w.*,
         rr.renewable,
         rr.renewals_remaining,
         rr.renewal_days,
         rr.rule_label
  FROM with_dues w
  LEFT JOIN LATERAL api.get_remaining_renewals(
    p_library_id => w.library_id,
    p_user_id => w.user_id,
    p_book_id => w.book_id,
    p_holding_id => w.holding_id,
    p_quantity => 1,
    p_renewals_used => w.renewals_used,
    p_as_of_date => CURRENT_DATE
  ) rr(renewable, renewals_remaining, renewal_days, policy_set_id, rule_id, rule_label, explanation) ON true
)
SELECT emprestimo_id,
       line_no,
       sub_id,
       library_id,
       book_id,
       effective_due_at,
       renewals_used,
       COALESCE(renewable, false) AS renewable,
       COALESCE(renewals_remaining, 0) AS renewals_remaining,
       rule_label,
       CASE
         WHEN dues_blocked THEN 'dues_blocked'::text
         WHEN COALESCE(effective_due_at, CURRENT_DATE) < CURRENT_DATE THEN 'overdue'::text
         WHEN reserved_by_other THEN 'reserved_by_other'::text
         WHEN COALESCE(renewable, false) IS FALSE AND COALESCE(renewals_remaining, 0) <= 0 AND COALESCE(renewals_used, 0) > 0 THEN 'quota_exceeded'::text
         WHEN COALESCE(renewable, false) IS FALSE THEN 'not_renewable'::text
         WHEN COALESCE(renewals_used, 0) >= 1 AND COALESCE(renewals_remaining, 0) <= 0 THEN 'already_extended'::text
         ELSE NULL::text
       END AS blocking_reason,
       (COALESCE(renewable, false) IS TRUE
         AND NOT dues_blocked
         AND COALESCE(effective_due_at, CURRENT_DATE) >= CURRENT_DATE
         AND NOT reserved_by_other
         AND COALESCE(renewals_remaining, 0) > 0) AS can_renew
FROM with_rule;

GRANT SELECT ON api.my_loans_renewal_status_by_item_v1 TO authenticated;

-- ── Vue staff : statut de renouvellement par item ───────────────────────────
CREATE OR REPLACE VIEW api.staff_loans_renewal_status_by_item_v1
WITH (security_invoker = true) AS
WITH staff_open_items AS (
  SELECT e.id AS emprestimo_id,
         i.line_no,
         i.sub_id,
         i.book_id,
         i.holding_id,
         e.user_id,
         e.library_id,
         COALESCE(i.renewals_used, 0) AS renewals_used,
         COALESCE(i.extended_until, i.due_at) AS effective_due_at
  FROM emprestimos_v2 e
  JOIN emprestimo_itens_v2 i ON i.emprestimo_id = e.id
  WHERE e.archived_at IS NULL
    AND i.item_status = 'aberto'
),
with_dues AS (
  SELECT l.*,
         fn_is_loan_blocked_by_dues(l.user_id, l.library_id) AS dues_blocked,
         (EXISTS (
            SELECT 1
              FROM reserva_linhas_v2 rl
              JOIN reservas_v2 r ON r.id = rl.reserva_id
             WHERE rl.book_id = l.book_id
               AND r.library_id = l.library_id
               AND r.user_id <> l.user_id
               AND (r.status_global = ANY (ARRAY['ativa'::text, 'parcialmente_encerrada'::text]))
               AND rl.item_status = 'ativa'::text
               AND r.archived_at IS NULL
         )) AS reserved_by_other
  FROM staff_open_items l
),
with_rule AS (
  SELECT w.*,
         rr.renewable,
         rr.renewals_remaining,
         rr.renewal_days,
         rr.rule_label
  FROM with_dues w
  LEFT JOIN LATERAL api.get_remaining_renewals(
    p_library_id => w.library_id,
    p_user_id => w.user_id,
    p_book_id => w.book_id,
    p_holding_id => w.holding_id,
    p_quantity => 1,
    p_renewals_used => w.renewals_used,
    p_as_of_date => CURRENT_DATE
  ) rr(renewable, renewals_remaining, renewal_days, policy_set_id, rule_id, rule_label, explanation) ON true
)
SELECT emprestimo_id,
       line_no,
       sub_id,
       user_id,
       library_id,
       book_id,
       effective_due_at,
       renewals_used,
       COALESCE(renewable, false) AS renewable,
       COALESCE(renewals_remaining, 0) AS renewals_remaining,
       rule_label,
       CASE
         WHEN dues_blocked THEN 'dues_blocked'::text
         WHEN COALESCE(effective_due_at, CURRENT_DATE) < CURRENT_DATE THEN 'overdue'::text
         WHEN reserved_by_other THEN 'reserved_by_other'::text
         WHEN COALESCE(renewable, false) IS FALSE AND COALESCE(renewals_remaining, 0) <= 0 AND COALESCE(renewals_used, 0) > 0 THEN 'quota_exceeded'::text
         WHEN COALESCE(renewable, false) IS FALSE THEN 'not_renewable'::text
         WHEN COALESCE(renewals_used, 0) >= 1 AND COALESCE(renewals_remaining, 0) <= 0 THEN 'already_extended'::text
         ELSE NULL::text
       END AS blocking_reason,
       (COALESCE(renewable, false) IS TRUE
         AND NOT dues_blocked
         AND COALESCE(effective_due_at, CURRENT_DATE) >= CURRENT_DATE
         AND NOT reserved_by_other
         AND COALESCE(renewals_remaining, 0) > 0) AS can_renew
FROM with_rule;

GRANT SELECT ON api.staff_loans_renewal_status_by_item_v1 TO authenticated;

-- ── Vérifications (RAISE EXCEPTION = auto-rollback) ──────────────────────────
DO $$
DECLARE
  v_my_invoker text;
  v_staff_invoker text;
BEGIN
  -- Présence + security_invoker = true sur les 2 vues
  SELECT COALESCE((SELECT option_value FROM pg_options_to_table(c.reloptions)
                   WHERE option_name='security_invoker'), 'false')
    INTO v_my_invoker
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='api' AND c.relname='my_loans_renewal_status_by_item_v1';

  IF v_my_invoker IS NULL THEN
    RAISE EXCEPTION 'phase2: vue my_loans_renewal_status_by_item_v1 absente';
  END IF;
  IF v_my_invoker <> 'true' THEN
    RAISE EXCEPTION 'phase2: my_loans_renewal_status_by_item_v1 pas en security_invoker';
  END IF;

  SELECT COALESCE((SELECT option_value FROM pg_options_to_table(c.reloptions)
                   WHERE option_name='security_invoker'), 'false')
    INTO v_staff_invoker
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='api' AND c.relname='staff_loans_renewal_status_by_item_v1';

  IF v_staff_invoker IS NULL THEN
    RAISE EXCEPTION 'phase2: vue staff_loans_renewal_status_by_item_v1 absente';
  END IF;
  IF v_staff_invoker <> 'true' THEN
    RAISE EXCEPTION 'phase2: staff_loans_renewal_status_by_item_v1 pas en security_invoker';
  END IF;

  RAISE NOTICE 'phase2 OK : 2 vues par item en place, security_invoker confirme.';
END $$;
