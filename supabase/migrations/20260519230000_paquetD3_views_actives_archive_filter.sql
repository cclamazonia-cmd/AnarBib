-- ============================================================================
-- Paquet D.3 - Patch des vues actives : filtre archived_at IS NULL
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.4 (paquet D)
-- Dependance : paquet D.1 (colonnes archived_at) et D.2 (helpers).
--
-- Objectif : ajouter le filtre WHERE archived_at IS NULL sur les vues qui
-- exposent les transactions vivantes des 5 tables transactionnelles.
-- Les transactions archivees (lors d'une transition de profil type 4)
-- disparaissent automatiquement des UIs courantes.
--
-- 11 vues patchees :
--
--   Vues actives (filtre archived_at IS NULL ajoute) :
--     1.  api.consulta_itens_followup_ui      (c.archived_at)
--     2.  api.emprestimo_itens_painel_ui      (e.archived_at)
--     3.  api.emprestimo_itens_ui             (e.archived_at)
--     4.  api.interlibrary_loan_items_ui      (h.archived_at)
--     5.  api.interlibrary_loans_painel_ui    (h.archived_at)
--     6.  api.interlibrary_loans_reports_ui   (h.archived_at)
--     7.  api.library_circulation_stats       (multiples sous-requetes)
--     8.  api.my_loans_renewal_status_v1      (e + r.archived_at)
--     9.  api.reserva_itens_followup_ui       (r.archived_at)
--    10.  api.staff_loans_renewal_status_v1   (e + r.archived_at)
--    11.  public.v_active_memberships         (mp.archived_at dans CTE)
--
-- Vues historique (filtre circulation_mode <> 'off' a faire en D.4) :
--   - api.my_loans_history_v1
--   - api.painel_loans_history_v1
--
-- Doctrine v2.2 : on utilise CREATE OR REPLACE VIEW pour preserver les grants
-- existants (anti-pattern C.5 evite : pas de DROP+CREATE qui perd les grants).
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. api.consulta_itens_followup_ui
-- ============================================================================
CREATE OR REPLACE VIEW api.consulta_itens_followup_ui WITH (security_invoker=true) AS
 WITH latest_workflow AS (
         SELECT DISTINCT ON (w.consulta_id, w.line_no) w.consulta_id,
            w.line_no,
            w.workflow_stage,
            w.workflow_note,
            w.consultation_scheduled_for,
            w.schedule_reply_status,
            w.schedule_reply_note,
            w.schedule_reply_at,
            w.consultation_starts_at,
            w.consultation_ends_at,
            w.updated_at,
            w.updated_by
           FROM consulta_item_workflow_v2 w
          ORDER BY w.consulta_id, w.line_no, w.updated_at DESC, w.id DESC
        )
 SELECT c.id AS consulta_id,
    cl.id AS consulta_item_id,
    cl.line_no,
    cl.sub_id,
    c.user_id,
    c.library_id,
    l.slug AS library_slug,
    l.name AS library_name,
    c.created_at AS consulta_created_at,
    c.updated_at AS consulta_updated_at,
    c.status_global AS consulta_status,
    cl.book_id,
    cl.holding_id,
    cl.bib_ref,
    NULL::text AS rotulo,
    cl.autor_cache AS autor,
    cl.titulo_cache AS titulo,
    cl.editora_cache AS editora,
    cl.ano_cache AS ano,
    cl.item_status,
    cl.expires_at,
    cl.cancelled_at,
    cl.consulted_at,
    cl.expired_at,
    cl.notes AS item_notes,
    COALESCE(lw.workflow_stage,
        CASE
            WHEN cl.item_status = 'consultada'::text THEN 'consulta_realizada'::text
            WHEN cl.item_status = 'cancelada_leitor'::text THEN 'cancelada_leitor'::text
            WHEN cl.item_status = 'cancelada_biblioteca'::text THEN 'cancelada_biblioteca'::text
            WHEN cl.item_status = 'expirada'::text THEN 'expirada'::text
            ELSE 'solicitada'::text
        END) AS workflow_stage_effective,
    lw.workflow_note,
    lw.consultation_scheduled_for,
    COALESCE(lw.updated_at, cl.updated_at, c.updated_at) AS workflow_stage_updated_at_effective,
    cl.dismissed_by_reader_at,
    lw.schedule_reply_status,
    lw.schedule_reply_note,
    lw.schedule_reply_at,
    lw.consultation_starts_at,
    lw.consultation_ends_at,
    p.public_id AS user_public_id,
    p.email AS user_email,
    NULLIF(TRIM(BOTH FROM concat_ws(' '::text, p.first_name, p.last_name)), ''::text) AS user_name
   FROM consultas_locais_v2 c
     JOIN consulta_linhas_v2 cl ON cl.consulta_id = c.id
     JOIN libraries l ON l.id = c.library_id
     LEFT JOIN latest_workflow lw ON lw.consulta_id = cl.consulta_id AND lw.line_no = cl.line_no
     LEFT JOIN profiles p ON p.id = c.user_id
  WHERE c.archived_at IS NULL;

-- ============================================================================
-- 2. api.emprestimo_itens_painel_ui
-- ============================================================================
CREATE OR REPLACE VIEW api.emprestimo_itens_painel_ui WITH (security_invoker=true) AS
 SELECT e.id AS emprestimo_id,
    i.id AS emprestimo_item_id,
    i.line_no,
    i.sub_id,
    e.user_id,
    p.public_id AS user_public_id,
    p.email AS user_email,
    NULLIF(TRIM(BOTH FROM concat_ws(' '::text, p.first_name, p.last_name)), ''::text) AS user_name,
    e.created_at AS emprestimo_created_at,
    i.due_at,
    e.status_global AS emprestimo_status,
    i.item_status,
    i.returned_at,
    i.book_id,
    i.item_id,
    i.bib_ref,
    i.rotulo_cache AS rotulo,
    i.autor_cache AS autor,
    i.titulo_cache AS titulo,
    i.editora_cache AS editora,
    i.ano_cache AS ano,
    i.return_scheduled_for,
    i.return_scheduled_by,
    i.return_scheduled_at,
    i.return_schedule_status,
    i.return_completed_at,
    i.return_missed_at,
    i.extended_until,
    i.extension_note,
    e.extended_once
   FROM emprestimos_v2 e
     JOIN emprestimo_itens_v2 i ON i.emprestimo_id = e.id
     LEFT JOIN profiles p ON p.id = e.user_id
  WHERE e.archived_at IS NULL;

-- ============================================================================
-- 3. api.emprestimo_itens_ui
-- ============================================================================
CREATE OR REPLACE VIEW api.emprestimo_itens_ui WITH (security_invoker=true) AS
 SELECT e.id AS emprestimo_id,
    i.id AS emprestimo_item_id,
    i.line_no,
    i.sub_id,
    e.user_id,
    e.created_at AS emprestimo_created_at,
    i.due_at,
    e.status_global AS emprestimo_status,
    i.item_status,
    i.returned_at,
    i.book_id,
    i.bib_ref,
    i.rotulo_cache AS rotulo,
    i.autor_cache AS autor,
    i.titulo_cache AS titulo,
    i.editora_cache AS editora,
    i.ano_cache AS ano,
    i.return_scheduled_for,
    i.return_scheduled_by,
    i.return_scheduled_at,
    i.return_schedule_status,
    i.return_completed_at,
    i.return_missed_at,
    i.extended_until,
    i.extension_note,
    p.public_id AS user_public_id,
    p.email AS user_email,
    NULLIF(TRIM(BOTH FROM concat_ws(' '::text, p.first_name, p.last_name)), ''::text) AS user_name
   FROM emprestimos_v2 e
     JOIN emprestimo_itens_v2 i ON i.emprestimo_id = e.id
     LEFT JOIN profiles p ON p.id = e.user_id
  WHERE e.archived_at IS NULL;

-- ============================================================================
-- 4. api.interlibrary_loan_items_ui
-- ============================================================================
CREATE OR REPLACE VIEW api.interlibrary_loan_items_ui WITH (security_invoker=true) AS
 SELECT h.id AS interlibrary_loan_id,
    i.id AS interlibrary_loan_item_id,
    i.line_no,
    i.sub_id,
    h.request_id,
    h.lender_library_id,
    ll.slug AS lender_library_slug,
    ll.name AS lender_library_name,
    ll.short_name AS lender_library_short_name,
    h.borrower_library_id,
    bl.slug AS borrower_library_slug,
    bl.name AS borrower_library_name,
    bl.short_name AS borrower_library_short_name,
        CASE
            WHEN user_can_manage_library(h.lender_library_id) AND user_can_manage_library(h.borrower_library_id) THEN 'ambas'::text
            WHEN user_can_manage_library(h.lender_library_id) THEN 'emprestadora'::text
            WHEN user_can_manage_library(h.borrower_library_id) THEN 'tomadora'::text
            ELSE NULL::text
        END AS local_role,
        CASE
            WHEN user_can_manage_library(h.lender_library_id) AND NOT user_can_manage_library(h.borrower_library_id) THEN h.borrower_library_id
            WHEN user_can_manage_library(h.borrower_library_id) AND NOT user_can_manage_library(h.lender_library_id) THEN h.lender_library_id
            ELSE NULL::uuid
        END AS partner_library_id,
        CASE
            WHEN user_can_manage_library(h.lender_library_id) AND NOT user_can_manage_library(h.borrower_library_id) THEN bl.name
            WHEN user_can_manage_library(h.borrower_library_id) AND NOT user_can_manage_library(h.lender_library_id) THEN ll.name
            ELSE NULL::text
        END AS partner_library_name,
    COALESCE(i.book_id, bh.book_id) AS book_id,
    i.holding_id,
    i.item_id,
    COALESCE(i.bib_ref, bh.local_bib_ref, e.bib_ref) AS bib_ref,
    COALESCE(i.rotulo_cache, e.tombo) AS tombo,
    i.titulo_cache AS titulo,
    i.autor_cache AS autor,
    i.editora_cache AS editora,
    i.ano_cache AS ano,
    h.status_global,
    i.item_status,
    h.start_date,
    COALESCE(i.due_date, h.due_date) AS due_date,
    i.reserved_at,
    i.dispatched_at,
    i.returned_at,
        CASE
            WHEN i.item_status = 'emprestado'::text AND COALESCE(i.due_date, h.due_date) IS NOT NULL AND COALESCE(i.due_date, h.due_date) < CURRENT_DATE THEN true
            ELSE false
        END AS is_overdue,
        CASE
            WHEN i.returned_at IS NOT NULL THEN 0
            WHEN COALESCE(i.due_date, h.due_date) IS NULL THEN NULL::integer
            ELSE GREATEST(COALESCE(i.due_date, h.due_date) - CURRENT_DATE, 0)
        END AS days_until_due,
        CASE
            WHEN i.returned_at IS NOT NULL THEN 0
            WHEN COALESCE(i.due_date, h.due_date) IS NULL THEN NULL::integer
            WHEN COALESCE(i.due_date, h.due_date) < CURRENT_DATE THEN CURRENT_DATE - COALESCE(i.due_date, h.due_date)
            ELSE 0
        END AS days_overdue,
    h.coordination_contact_name,
    h.coordination_contact_email,
    h.coordination_contact_phone,
    h.logistics_mode,
    h.meeting_point,
    h.notes AS loan_notes,
    i.notes AS item_notes,
    h.created_at,
    h.updated_at
   FROM interlibrary_loans_v2 h
     JOIN interlibrary_loan_items_v2 i ON i.interlibrary_loan_id = h.id
     LEFT JOIN book_holdings bh ON bh.id = i.holding_id
     LEFT JOIN exemplares e ON e.id = i.item_id
     LEFT JOIN libraries ll ON ll.id = h.lender_library_id
     LEFT JOIN libraries bl ON bl.id = h.borrower_library_id
  WHERE h.archived_at IS NULL
    AND (user_can_manage_library(h.lender_library_id) OR user_can_manage_library(h.borrower_library_id));

-- ============================================================================
-- 5. api.interlibrary_loans_painel_ui
-- ============================================================================
CREATE OR REPLACE VIEW api.interlibrary_loans_painel_ui WITH (security_invoker=true) AS
 SELECT h.id,
    h.request_id,
    h.lender_library_id,
    ll.slug AS lender_library_slug,
    ll.name AS lender_library_name,
    ll.short_name AS lender_library_short_name,
    h.borrower_library_id,
    bl.slug AS borrower_library_slug,
    bl.name AS borrower_library_name,
    bl.short_name AS borrower_library_short_name,
        CASE
            WHEN user_can_manage_library(h.lender_library_id) AND user_can_manage_library(h.borrower_library_id) THEN 'ambas'::text
            WHEN user_can_manage_library(h.lender_library_id) THEN 'emprestadora'::text
            WHEN user_can_manage_library(h.borrower_library_id) THEN 'tomadora'::text
            ELSE NULL::text
        END AS local_role,
        CASE
            WHEN user_can_manage_library(h.lender_library_id) AND NOT user_can_manage_library(h.borrower_library_id) THEN h.borrower_library_id
            WHEN user_can_manage_library(h.borrower_library_id) AND NOT user_can_manage_library(h.lender_library_id) THEN h.lender_library_id
            ELSE NULL::uuid
        END AS partner_library_id,
        CASE
            WHEN user_can_manage_library(h.lender_library_id) AND NOT user_can_manage_library(h.borrower_library_id) THEN bl.name
            WHEN user_can_manage_library(h.borrower_library_id) AND NOT user_can_manage_library(h.lender_library_id) THEN ll.name
            ELSE NULL::text
        END AS partner_library_name,
    h.status_global,
    h.start_date,
    h.due_date,
    h.dispatched_at,
    h.return_started_at,
    h.returned_at,
    count(i.id)::integer AS items_count,
    count(*) FILTER (WHERE i.item_status = 'reservado_para_saida'::text)::integer AS items_reserved_count,
    count(*) FILTER (WHERE i.item_status = 'emprestado'::text)::integer AS items_open_count,
    count(*) FILTER (WHERE i.item_status = 'devolvido'::text)::integer AS items_returned_count,
    count(*) FILTER (WHERE i.item_status = 'cancelado'::text)::integer AS items_cancelled_count,
    count(*) FILTER (WHERE i.item_status = 'emprestado'::text AND COALESCE(i.due_date, h.due_date) IS NOT NULL AND COALESCE(i.due_date, h.due_date) < CURRENT_DATE)::integer AS items_overdue_count,
    string_agg(DISTINCT COALESCE(i.titulo_cache, i.bib_ref), ' · '::text ORDER BY (COALESCE(i.titulo_cache, i.bib_ref))) AS titulos_resumo,
    string_agg(DISTINCT COALESCE(i.rotulo_cache, ''::text), ' · '::text ORDER BY (COALESCE(i.rotulo_cache, ''::text))) FILTER (WHERE COALESCE(i.rotulo_cache, ''::text) <> ''::text) AS tombos_resumo,
    h.coordination_contact_name,
    h.coordination_contact_email,
    h.coordination_contact_phone,
    h.logistics_mode,
    h.meeting_point,
    h.notes,
    h.created_at,
    h.updated_at
   FROM interlibrary_loans_v2 h
     LEFT JOIN interlibrary_loan_items_v2 i ON i.interlibrary_loan_id = h.id
     LEFT JOIN libraries ll ON ll.id = h.lender_library_id
     LEFT JOIN libraries bl ON bl.id = h.borrower_library_id
  WHERE h.archived_at IS NULL
    AND (user_can_manage_library(h.lender_library_id) OR user_can_manage_library(h.borrower_library_id))
  GROUP BY h.id, h.request_id, h.lender_library_id, ll.slug, ll.name, ll.short_name, h.borrower_library_id, bl.slug, bl.name, bl.short_name, h.status_global, h.start_date, h.due_date, h.dispatched_at, h.return_started_at, h.returned_at, h.coordination_contact_name, h.coordination_contact_email, h.coordination_contact_phone, h.logistics_mode, h.meeting_point, h.notes, h.created_at, h.updated_at;

-- ============================================================================
-- 6. api.interlibrary_loans_reports_ui
-- ============================================================================
CREATE OR REPLACE VIEW api.interlibrary_loans_reports_ui WITH (security_invoker=true) AS
 SELECT h.id AS interlibrary_loan_id,
    i.id AS interlibrary_loan_item_id,
    i.line_no,
    i.sub_id,
        CASE
            WHEN user_can_manage_library(h.lender_library_id) AND user_can_manage_library(h.borrower_library_id) THEN 'ambas'::text
            WHEN user_can_manage_library(h.lender_library_id) THEN 'emprestadora'::text
            WHEN user_can_manage_library(h.borrower_library_id) THEN 'tomadora'::text
            ELSE NULL::text
        END AS local_role,
    ll.name AS lender_library_name,
    bl.name AS borrower_library_name,
    COALESCE(i.bib_ref, bh.local_bib_ref, e.bib_ref) AS bib_ref,
    COALESCE(i.rotulo_cache, e.tombo) AS tombo,
    i.titulo_cache AS titulo,
    i.autor_cache AS autor,
    h.status_global,
    i.item_status,
    h.start_date,
    COALESCE(i.due_date, h.due_date) AS due_date,
    i.returned_at::date AS returned_date,
        CASE
            WHEN i.returned_at IS NOT NULL THEN NULL::integer
            WHEN COALESCE(i.due_date, h.due_date) IS NULL THEN NULL::integer
            ELSE COALESCE(i.due_date, h.due_date) - CURRENT_DATE
        END AS saldo_dias,
        CASE
            WHEN i.returned_at IS NOT NULL THEN 0
            WHEN COALESCE(i.due_date, h.due_date) IS NULL THEN NULL::integer
            WHEN COALESCE(i.due_date, h.due_date) < CURRENT_DATE THEN CURRENT_DATE - COALESCE(i.due_date, h.due_date)
            ELSE 0
        END AS dias_atraso,
    h.coordination_contact_name,
    h.coordination_contact_email,
    h.logistics_mode,
    h.meeting_point,
    h.notes AS loan_notes,
    i.notes AS item_notes,
    h.created_at,
    h.updated_at
   FROM interlibrary_loans_v2 h
     JOIN interlibrary_loan_items_v2 i ON i.interlibrary_loan_id = h.id
     LEFT JOIN book_holdings bh ON bh.id = i.holding_id
     LEFT JOIN exemplares e ON e.id = i.item_id
     LEFT JOIN libraries ll ON ll.id = h.lender_library_id
     LEFT JOIN libraries bl ON bl.id = h.borrower_library_id
  WHERE h.archived_at IS NULL
    AND (user_can_manage_library(h.lender_library_id) OR user_can_manage_library(h.borrower_library_id));

-- ============================================================================
-- 7. api.library_circulation_stats
-- ============================================================================
-- Cette vue contient 7 sous-requetes scalaires sur emp/res/con qu'il faut
-- toutes filtrer par archived_at IS NULL.
CREATE OR REPLACE VIEW api.library_circulation_stats WITH (security_invoker=true) AS
 SELECT id AS library_id,
    slug,
    name AS library_name,
    ( SELECT count(*) AS count
           FROM emprestimos_v2 e
          WHERE e.library_id = l.id AND e.status_global = 'aberto'::text AND e.archived_at IS NULL) AS loans_open,
    ( SELECT count(*) AS count
           FROM emprestimos_v2 e
          WHERE e.library_id = l.id AND e.status_global = 'aberto'::text AND e.due_at < CURRENT_DATE AND e.archived_at IS NULL) AS loans_overdue,
    ( SELECT count(*) AS count
           FROM emprestimos_v2 e
          WHERE e.library_id = l.id AND e.status_global = 'devolvido'::text AND e.updated_at >= (CURRENT_DATE - '7 days'::interval) AND e.archived_at IS NULL) AS loans_returned_7d,
    ( SELECT count(*) AS count
           FROM emprestimos_v2 e
          WHERE e.library_id = l.id AND (e.status_global = ANY (ARRAY['aberto'::text, 'devolvido'::text])) AND e.created_at >= (CURRENT_DATE - '7 days'::interval) AND e.archived_at IS NULL) AS loans_created_7d,
    ( SELECT count(*) AS count
           FROM emprestimos_v2 e
          WHERE e.library_id = l.id AND (e.status_global = ANY (ARRAY['aberto'::text, 'devolvido'::text])) AND e.created_at >= (CURRENT_DATE - '30 days'::interval) AND e.archived_at IS NULL) AS loans_created_30d,
    ( SELECT count(*) AS count
           FROM reservas_v2 r
          WHERE r.library_id = l.id AND (r.status_global = ANY (ARRAY['ativa'::text, 'em_preparacao'::text])) AND r.archived_at IS NULL) AS reservations_active,
    ( SELECT count(*) AS count
           FROM reservas_v2 r
          WHERE r.library_id = l.id AND (r.status_global = ANY (ARRAY['ativa'::text, 'em_preparacao'::text, 'retirada_efetivada'::text, 'cancelada_leitor'::text, 'cancelada_biblioteca'::text, 'expirada'::text])) AND r.created_at >= (CURRENT_DATE - '30 days'::interval) AND r.archived_at IS NULL) AS reservations_30d,
    ( SELECT count(*) AS count
           FROM consultas_locais_v2 c
          WHERE c.library_id = l.id AND (c.status_global = ANY (ARRAY['ativa'::text, 'em_preparacao'::text])) AND c.archived_at IS NULL) AS consultations_active,
    ( SELECT count(*) AS count
           FROM book_holdings h
          WHERE h.library_id = l.id) AS holdings_count,
    ( SELECT count(*) AS count
           FROM exemplares e2
          WHERE e2.library_id = l.id) AS exemplars_count,
    ( SELECT count(DISTINCT m.user_id) AS count
           FROM user_library_memberships m
          WHERE m.library_id = l.id AND m.role = 'reader'::text AND m.status = 'active'::text) AS readers_active,
    ( SELECT count(DISTINCT m.user_id) AS count
           FROM user_library_memberships m
          WHERE m.library_id = l.id AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND m.status = 'active'::text) AS librarians_active,
    ( SELECT jsonb_agg(row_to_json(tb.*) ORDER BY tb.cnt DESC) AS jsonb_agg
           FROM ( SELECT b.titulo,
                    b.autor,
                    count(*) AS cnt
                   FROM emprestimo_itens_v2 ei
                     JOIN emprestimos_v2 e ON e.id = ei.emprestimo_id
                     JOIN book_holdings h ON h.id = ei.holding_id
                     JOIN books b ON b.id = h.book_id
                  WHERE e.library_id = l.id AND e.created_at >= (CURRENT_DATE - '90 days'::interval) AND e.archived_at IS NULL
                  GROUP BY b.titulo, b.autor
                  ORDER BY (count(*)) DESC
                 LIMIT 5) tb) AS top_books_90d
   FROM libraries l;

-- ============================================================================
-- 8. api.my_loans_renewal_status_v1
-- ============================================================================
CREATE OR REPLACE VIEW api.my_loans_renewal_status_v1 WITH (security_invoker=true) AS
 WITH my_open_loans AS (
         SELECT e.id AS emprestimo_id,
            e.user_id,
            e.library_id,
            e.renewals_used,
            e.extended_once,
            ( SELECT count(*)::integer AS count
                   FROM emprestimo_itens_v2 i
                  WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'::text) AS open_items_count,
            ( SELECT min(i.book_id) AS min
                   FROM emprestimo_itens_v2 i
                  WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'::text) AS first_book_id,
            ( SELECT min(i.holding_id) AS min
                   FROM emprestimo_itens_v2 i
                  WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'::text) AS first_holding_id,
            ( SELECT max(COALESCE(i.extended_until, i.due_at)) AS max
                   FROM emprestimo_itens_v2 i
                  WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'::text) AS effective_due_at
           FROM emprestimos_v2 e
          WHERE e.user_id = auth.uid()
            AND e.archived_at IS NULL
            AND (EXISTS ( SELECT 1
                   FROM emprestimo_itens_v2 i
                  WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'::text))
        ), with_dues AS (
         SELECT l.emprestimo_id,
            l.user_id,
            l.library_id,
            l.renewals_used,
            l.extended_once,
            l.open_items_count,
            l.first_book_id,
            l.first_holding_id,
            l.effective_due_at,
            fn_is_loan_blocked_by_dues(l.user_id, l.library_id) AS dues_blocked,
            (EXISTS ( SELECT 1
                   FROM reserva_linhas_v2 rl
                     JOIN reservas_v2 r ON r.id = rl.reserva_id
                  WHERE rl.book_id = l.first_book_id AND r.library_id = l.library_id AND r.user_id <> l.user_id AND (r.status_global = ANY (ARRAY['ativa'::text, 'parcialmente_encerrada'::text])) AND rl.item_status = 'ativa'::text AND r.archived_at IS NULL)) AS reserved_by_other
           FROM my_open_loans l
        ), with_rule AS (
         SELECT w.emprestimo_id,
            w.user_id,
            w.library_id,
            w.renewals_used,
            w.extended_once,
            w.open_items_count,
            w.first_book_id,
            w.first_holding_id,
            w.effective_due_at,
            w.dues_blocked,
            w.reserved_by_other,
            rr.renewable,
            rr.renewals_remaining,
            rr.renewal_days,
            rr.rule_label
           FROM with_dues w
             LEFT JOIN LATERAL api.get_remaining_renewals(p_library_id => w.library_id, p_user_id => w.user_id, p_book_id => w.first_book_id, p_holding_id => w.first_holding_id, p_quantity => w.open_items_count, p_renewals_used => COALESCE(w.renewals_used, 0), p_as_of_date => CURRENT_DATE) rr(renewable, renewals_remaining, renewal_days, policy_set_id, rule_id, rule_label, explanation) ON true
        )
 SELECT emprestimo_id,
    library_id,
    effective_due_at,
    open_items_count,
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
    COALESCE(renewable, false) IS TRUE AND NOT dues_blocked AND COALESCE(effective_due_at, CURRENT_DATE) >= CURRENT_DATE AND NOT reserved_by_other AND COALESCE(renewals_remaining, 0) > 0 AS can_renew
   FROM with_rule;

-- ============================================================================
-- 9. api.reserva_itens_followup_ui
-- ============================================================================
CREATE OR REPLACE VIEW api.reserva_itens_followup_ui WITH (security_invoker=true) AS
 SELECT r.id AS reserva_id,
    rl.id AS reserva_item_id,
    rl.line_no,
    rl.sub_id,
    r.user_id,
    r.library_id,
    l.slug AS library_slug,
    l.name AS library_name,
    r.created_at AS reserva_created_at,
    r.updated_at AS reserva_updated_at,
    r.status_global AS reserva_status,
    rl.book_id,
    rl.item_id,
    rl.bib_ref,
    rl.rotulo_cache AS rotulo,
    COALESCE(rl.autor_cache, b.autor) AS autor,
    COALESCE(rl.titulo_cache, b.titulo) AS titulo,
    COALESCE(rl.editora_cache, b.editora) AS editora,
    COALESCE(rl.ano_cache, b.ano) AS ano,
    rl.item_status,
    rl.expires_at,
    rl.cancelled_at,
    rl.converted_at,
    rl.expired_at,
    rl.emprestimo_item_id,
    rl.notes AS item_notes,
    COALESCE(w.workflow_stage,
        CASE
            WHEN rl.item_status = 'ativa'::text THEN 'solicitada'::text
            WHEN rl.item_status = 'cancelada_leitor'::text THEN 'cancelada_leitor'::text
            WHEN rl.item_status = 'cancelada_biblioteca'::text THEN 'cancelada_biblioteca'::text
            WHEN rl.item_status = 'expirada'::text THEN 'expirada'::text
            WHEN rl.item_status = 'convertida_em_emprestimo'::text THEN 'retirada_efetivada'::text
            WHEN rl.item_status = 'liberada_para_circulacao'::text THEN 'liberada_para_circulacao'::text
            ELSE 'solicitada'::text
        END) AS workflow_stage_effective,
    w.workflow_note,
    w.pickup_scheduled_for,
    w.updated_at AS workflow_stage_updated_at_effective,
    w.pickup_reply_status,
    w.pickup_reply_note,
    w.pickup_reply_at,
    w.pickup_proposed_by,
    COALESCE(w.negotiation_iteration_count, 0) AS negotiation_iteration_count,
    p.public_id AS user_public_id,
    p.email AS user_email,
    NULLIF(TRIM(BOTH FROM concat_ws(' '::text, p.first_name, p.last_name)), ''::text) AS user_name
   FROM reservas_v2 r
     JOIN reserva_linhas_v2 rl ON rl.reserva_id = r.id
     JOIN libraries l ON l.id = r.library_id
     LEFT JOIN books b ON b.id = rl.book_id
     LEFT JOIN reserva_item_workflow_v2 w ON w.reserva_id = rl.reserva_id AND w.line_no = rl.line_no
     LEFT JOIN profiles p ON p.id = r.user_id
  WHERE r.archived_at IS NULL;

-- ============================================================================
-- 10. api.staff_loans_renewal_status_v1
-- ============================================================================
CREATE OR REPLACE VIEW api.staff_loans_renewal_status_v1 WITH (security_invoker=true) AS
 WITH staff_open_loans AS (
         SELECT e.id AS emprestimo_id,
            e.user_id,
            e.library_id,
            e.renewals_used,
            e.extended_once,
            ( SELECT count(*)::integer AS count
                   FROM emprestimo_itens_v2 i
                  WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'::text) AS open_items_count,
            ( SELECT min(i.book_id) AS min
                   FROM emprestimo_itens_v2 i
                  WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'::text) AS first_book_id,
            ( SELECT min(i.holding_id) AS min
                   FROM emprestimo_itens_v2 i
                  WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'::text) AS first_holding_id,
            ( SELECT max(COALESCE(i.extended_until, i.due_at)) AS max
                   FROM emprestimo_itens_v2 i
                  WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'::text) AS effective_due_at
           FROM emprestimos_v2 e
          WHERE e.archived_at IS NULL
            AND (EXISTS ( SELECT 1
                   FROM emprestimo_itens_v2 i
                  WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'::text))
        ), with_dues AS (
         SELECT l.emprestimo_id,
            l.user_id,
            l.library_id,
            l.renewals_used,
            l.extended_once,
            l.open_items_count,
            l.first_book_id,
            l.first_holding_id,
            l.effective_due_at,
            fn_is_loan_blocked_by_dues(l.user_id, l.library_id) AS dues_blocked,
            (EXISTS ( SELECT 1
                   FROM reserva_linhas_v2 rl
                     JOIN reservas_v2 r ON r.id = rl.reserva_id
                  WHERE rl.book_id = l.first_book_id AND r.library_id = l.library_id AND r.user_id <> l.user_id AND (r.status_global = ANY (ARRAY['ativa'::text, 'parcialmente_encerrada'::text])) AND rl.item_status = 'ativa'::text AND r.archived_at IS NULL)) AS reserved_by_other
           FROM staff_open_loans l
        ), with_rule AS (
         SELECT w.emprestimo_id,
            w.user_id,
            w.library_id,
            w.renewals_used,
            w.extended_once,
            w.open_items_count,
            w.first_book_id,
            w.first_holding_id,
            w.effective_due_at,
            w.dues_blocked,
            w.reserved_by_other,
            rr.renewable,
            rr.renewals_remaining,
            rr.renewal_days,
            rr.rule_label
           FROM with_dues w
             LEFT JOIN LATERAL api.get_remaining_renewals(p_library_id => w.library_id, p_user_id => w.user_id, p_book_id => w.first_book_id, p_holding_id => w.first_holding_id, p_quantity => w.open_items_count, p_renewals_used => COALESCE(w.renewals_used, 0), p_as_of_date => CURRENT_DATE) rr(renewable, renewals_remaining, renewal_days, policy_set_id, rule_id, rule_label, explanation) ON true
        )
 SELECT emprestimo_id,
    user_id,
    library_id,
    effective_due_at,
    open_items_count,
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
    COALESCE(renewable, false) IS TRUE AND NOT dues_blocked AND COALESCE(effective_due_at, CURRENT_DATE) >= CURRENT_DATE AND NOT reserved_by_other AND COALESCE(renewals_remaining, 0) > 0 AS can_renew
   FROM with_rule;

-- ============================================================================
-- 11. public.v_active_memberships
-- ============================================================================
-- CTE last_payment doit filtrer archived_at IS NULL.
CREATE OR REPLACE VIEW public.v_active_memberships AS
 WITH last_payment AS (
         SELECT DISTINCT ON (membership_payments.user_id, membership_payments.library_id) membership_payments.id,
            membership_payments.user_id,
            membership_payments.library_id,
            membership_payments.rule_id,
            membership_payments.amount_paid,
            membership_payments.currency,
            membership_payments.paid_at,
            membership_payments.valid_from,
            membership_payments.valid_until,
            membership_payments.payment_method
           FROM membership_payments
          WHERE membership_payments.archived_at IS NULL
          ORDER BY membership_payments.user_id, membership_payments.library_id, membership_payments.valid_until DESC, membership_payments.paid_at DESC
        )
 SELECT ulm.user_id,
    ulm.library_id,
    ulm.role,
    ulm.is_primary,
    ulm.status AS membership_status,
    l.membership_enabled,
    lp.id AS last_payment_id,
    lp.rule_id AS last_rule_id,
    lp.amount_paid AS last_amount_paid,
    lp.currency AS last_currency,
    lp.paid_at AS last_paid_at,
    lp.valid_from AS last_valid_from,
    lp.valid_until AS last_valid_until,
    lp.payment_method AS last_payment_method,
        CASE
            WHEN NOT l.membership_enabled THEN 'not_applicable'::text
            WHEN lp.id IS NULL THEN 'never_paid'::text
            WHEN lp.valid_until IS NULL THEN 'lifetime'::text
            WHEN lp.valid_until >= CURRENT_DATE THEN 'up_to_date'::text
            ELSE 'expired'::text
        END AS dues_status,
        CASE
            WHEN lp.valid_until IS NULL THEN NULL::integer
            ELSE lp.valid_until - CURRENT_DATE
        END AS days_until_expiry
   FROM user_library_memberships ulm
     JOIN libraries l ON l.id = ulm.library_id
     LEFT JOIN last_payment lp ON lp.user_id = ulm.user_id AND lp.library_id = ulm.library_id;

-- ============================================================================
-- DO block de verification fail-fast
-- ============================================================================
DO $verif$
DECLARE
  v_count int;
BEGIN
  -- Les 11 vues doivent toujours exister
  SELECT count(*) INTO v_count
    FROM information_schema.views
   WHERE (table_schema = 'api' AND table_name IN (
          'consulta_itens_followup_ui', 'emprestimo_itens_painel_ui',
          'emprestimo_itens_ui', 'interlibrary_loan_items_ui',
          'interlibrary_loans_painel_ui', 'interlibrary_loans_reports_ui',
          'library_circulation_stats', 'my_loans_renewal_status_v1',
          'reserva_itens_followup_ui', 'staff_loans_renewal_status_v1'))
      OR (table_schema = 'public' AND table_name = 'v_active_memberships');
  IF v_count <> 11 THEN
    RAISE EXCEPTION 'VERIF_FAIL_A : %/11 vues presentes apres patch', v_count;
  END IF;

  -- Verifier que CREATE OR REPLACE a preserve les grants (anti-pattern C.5)
  -- Au moins 1 grant authenticated SELECT par vue api.*
  SELECT count(DISTINCT table_name) INTO v_count
    FROM information_schema.role_table_grants
   WHERE table_schema = 'api'
     AND table_name IN ('consulta_itens_followup_ui', 'emprestimo_itens_painel_ui',
                        'emprestimo_itens_ui', 'interlibrary_loan_items_ui',
                        'interlibrary_loans_painel_ui', 'interlibrary_loans_reports_ui',
                        'library_circulation_stats', 'my_loans_renewal_status_v1',
                        'reserva_itens_followup_ui', 'staff_loans_renewal_status_v1')
     AND grantee = 'authenticated'
     AND privilege_type = 'SELECT';
  IF v_count <> 10 THEN
    RAISE EXCEPTION 'VERIF_FAIL_B : %/10 vues api.* sans grant authenticated SELECT (grants perdus par CREATE OR REPLACE ?)', v_count;
  END IF;

  -- Sanity check : aucune ligne en prod ne doit avoir disparu
  -- (cohherent : 0 ligne avec archived_at non-NULL au start)
  SELECT (SELECT count(*) FROM api.emprestimo_itens_painel_ui)
       + (SELECT count(*) FROM api.reserva_itens_followup_ui)
       + (SELECT count(*) FROM api.consulta_itens_followup_ui)
  INTO v_count;
  -- Pas de verification stricte ici (les comptes dependent du caller), juste no-crash.

  RAISE NOTICE 'Paquet D.3 - Verification OK : 11 vues patches, grants preserves';
END
$verif$;

COMMIT;
