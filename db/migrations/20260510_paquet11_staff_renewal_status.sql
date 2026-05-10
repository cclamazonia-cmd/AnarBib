-- =====================================================================
-- AnarBib — Paquet 11 : vue staff_loans_renewal_status_v1
-- Date : 2026-05-10
-- Spec : docs/spec-flux-emprunts.md Phase 5
--
-- Vue de pre-evaluation des renouvellements pour PanelPage (staff biblio).
-- Symetrique à api.my_loans_renewal_status_v1 (paquet 7) mais sans filtre
-- explicite par auth.uid() : on s'appuie sur la policy RLS
-- emprestimos_v2_select_policy qui autorise deja staff + propre lecteur.
--
-- Avec security_invoker=true, la vue herite de l'identite de l'appelant
-- et applique automatiquement la policy RLS. Le staff voit donc les
-- emprunts de sa bibliotheque ; un lecteur ne verrait que ses propres
-- emprunts (cas legitime mais sans interet pratique cote /painel).
--
-- Filtre métier : on ne calcule l'evaluation que pour les emprunts
-- avec au moins un item ouvert. Les emprunts encerrados sont exclus.
-- =====================================================================

BEGIN;

CREATE OR REPLACE VIEW api.staff_loans_renewal_status_v1
WITH (security_invoker='true')
AS
WITH staff_open_loans AS (
  SELECT
    e.id AS emprestimo_id,
    e.user_id,
    e.library_id,
    e.renewals_used,
    e.extended_once,
    -- Aggrégats sur les items ouverts
    (SELECT COUNT(*)::int
       FROM public.emprestimo_itens_v2 i
      WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto') AS open_items_count,
    (SELECT MIN(i.book_id)
       FROM public.emprestimo_itens_v2 i
      WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto') AS first_book_id,
    (SELECT MIN(i.holding_id)
       FROM public.emprestimo_itens_v2 i
      WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto') AS first_holding_id,
    (SELECT MAX(COALESCE(i.extended_until, i.due_at))
       FROM public.emprestimo_itens_v2 i
      WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto') AS effective_due_at
  FROM public.emprestimos_v2 e
  -- Pas de WHERE sur user_id : la policy RLS s'en charge.
  -- On filtre quand meme sur "au moins un item ouvert" pour ne pas
  -- pre-evaluer des emprunts deja encerrados.
  WHERE EXISTS (
    SELECT 1 FROM public.emprestimo_itens_v2 i
     WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'
  )
),
with_dues AS (
  SELECT l.*,
         public.fn_is_loan_blocked_by_dues(l.user_id, l.library_id) AS dues_blocked,
         EXISTS (
           SELECT 1
             FROM public.reserva_linhas_v2 rl
             JOIN public.reservas_v2 r ON r.id = rl.reserva_id
            WHERE rl.book_id = l.first_book_id
              AND r.library_id = l.library_id
              AND r.user_id <> l.user_id
              AND r.status_global IN ('ativa', 'parcialmente_encerrada')
              AND rl.item_status = 'ativa'
         ) AS reserved_by_other
    FROM staff_open_loans l
),
with_rule AS (
  SELECT w.*,
         rr.renewable,
         rr.renewals_remaining,
         rr.renewal_days,
         rr.rule_label
    FROM with_dues w
    LEFT JOIN LATERAL api.get_remaining_renewals(
      p_library_id := w.library_id,
      p_user_id := w.user_id,
      p_book_id := w.first_book_id,
      p_holding_id := w.first_holding_id,
      p_quantity := w.open_items_count,
      p_renewals_used := COALESCE(w.renewals_used, 0),
      p_as_of_date := CURRENT_DATE
    ) rr ON true
)
SELECT
  emprestimo_id,
  user_id,
  library_id,
  effective_due_at,
  open_items_count,
  renewals_used,
  COALESCE(renewable, false) AS renewable,
  COALESCE(renewals_remaining, 0) AS renewals_remaining,
  rule_label,
  -- blocking_reason : ordre de priorite identique à my_loans_renewal_status_v1
  -- (et donc à fn_renew_my_loan / fn_v2_extend_emprestimo_once)
  CASE
    WHEN dues_blocked
      THEN 'dues_blocked'
    WHEN COALESCE(effective_due_at, CURRENT_DATE) < CURRENT_DATE
      THEN 'overdue'
    WHEN reserved_by_other
      THEN 'reserved_by_other'
    WHEN COALESCE(renewable, false) IS false
         AND COALESCE(renewals_remaining, 0) <= 0
         AND COALESCE(renewals_used, 0) > 0
      THEN 'quota_exceeded'
    WHEN COALESCE(renewable, false) IS false
      THEN 'not_renewable'
    WHEN COALESCE(renewals_used, 0) >= 1
         AND COALESCE(renewals_remaining, 0) <= 0
      THEN 'already_extended'
    ELSE NULL
  END AS blocking_reason,
  (
    COALESCE(renewable, false) IS true
    AND NOT dues_blocked
    AND COALESCE(effective_due_at, CURRENT_DATE) >= CURRENT_DATE
    AND NOT reserved_by_other
    AND COALESCE(renewals_remaining, 0) > 0
  ) AS can_renew
FROM with_rule;

ALTER VIEW api.staff_loans_renewal_status_v1 OWNER TO postgres;

COMMENT ON VIEW api.staff_loans_renewal_status_v1 IS
'Paquet 11 (10/05/2026) : pre-evaluation des renouvellements pour PanelPage
(staff biblio). Symetrique à api.my_loans_renewal_status_v1 sans filtre
auth.uid() explicite : la policy RLS emprestimos_v2_select_policy applique
le filtre staff/lecteur automatiquement via security_invoker=true. Permet
de pre-desactiver le bouton Prorrogar avec tooltip explicatif.';

GRANT SELECT ON api.staff_loans_renewal_status_v1 TO authenticated;

COMMIT;

-- =====================================================================
-- Test apres deploiement (en tant que staff) :
--
-- SELECT emprestimo_id, can_renew, blocking_reason, renewals_remaining
-- FROM api.staff_loans_renewal_status_v1
-- ORDER BY emprestimo_id DESC;
-- =====================================================================
