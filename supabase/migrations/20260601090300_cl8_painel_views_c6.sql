-- =====================================================================
-- Migration : #CL.8 rétention historique lectrice — paquet C.6 (vues painel)
-- Réf doctrine : docs/specs/spec-historico-retencao-lectrice.md v1.0, D.3
-- Objet : exposer is_hidden_by_user côté staff (badge "masqué par la lectrice").
--   Mémoire collective non-occulte : le staff voit la ligne masquée, marquée.
-- DÉPEND DE : C.1a (colonnes) + C.2 (flag projeté dans les vues followup).
-- Les 3 vues painel conservent WITH (security_invoker = true).
-- Colonne ajoutée EN FIN de projection (contrainte CREATE OR REPLACE VIEW).
-- =====================================================================

BEGIN;

SET LOCAL search_path = public, api;

-- ---------------------------------------------------------------------
-- 1. painel_reservations_history_v1  (+ is_hidden_by_user, depuis followup)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW api.painel_reservations_history_v1
WITH (security_invoker = true) AS
 SELECT reserva_id,
    reserva_item_id,
    line_no,
    library_id,
    library_slug,
    library_name,
    book_id,
    bib_ref,
    titulo,
    autor,
    ano,
    editora,
    rotulo,
    item_status,
    workflow_stage_effective,
    workflow_note,
    user_id,
    user_public_id,
    user_email,
    user_name,
    reserva_created_at AS requested_at,
    cancelled_at,
    converted_at,
    expired_at,
    reserva_updated_at,
    COALESCE(cancelled_at, converted_at, expired_at, reserva_updated_at) AS closed_at,
    is_hidden_by_user
   FROM api.reserva_itens_followup_ui r
  WHERE (item_status = ANY (ARRAY['cancelada_leitor'::text, 'cancelada_biblioteca'::text, 'convertida_em_emprestimo'::text, 'expirada'::text, 'liberada_para_circulacao'::text])) AND (EXISTS ( SELECT 1
           FROM libraries lib
          WHERE lib.id = r.library_id AND lib.circulation_mode <> 'off'::text))
  ORDER BY (COALESCE(cancelled_at, converted_at, expired_at, reserva_updated_at)) DESC, reserva_id DESC, line_no;

-- ---------------------------------------------------------------------
-- 2. painel_consultas_history_v1  (+ is_hidden_by_user, depuis followup)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW api.painel_consultas_history_v1
WITH (security_invoker = true) AS
 SELECT consulta_id,
    consulta_item_id,
    line_no,
    library_id,
    library_slug,
    library_name,
    book_id,
    holding_id,
    bib_ref,
    titulo,
    autor,
    ano,
    editora,
    item_status,
    workflow_stage_effective,
    workflow_note,
    schedule_reply_status,
    schedule_reply_note,
    user_id,
    user_public_id,
    user_email,
    user_name,
    consulta_created_at AS requested_at,
    consultation_scheduled_for AS scheduled_for,
    consultation_starts_at,
    consultation_ends_at,
    cancelled_at,
    consulted_at,
    expired_at,
    dismissed_by_reader_at,
    consulta_updated_at,
    COALESCE(cancelled_at, consulted_at, expired_at, consulta_updated_at) AS closed_at,
    is_hidden_by_user
   FROM api.consulta_itens_followup_ui r
  WHERE (item_status = ANY (ARRAY['cancelada_biblioteca'::text, 'cancelada_leitor'::text, 'consultada'::text, 'expirada'::text])) AND (EXISTS ( SELECT 1
           FROM libraries lib
          WHERE lib.id = r.library_id AND lib.circulation_mode <> 'off'::text))
  ORDER BY (COALESCE(cancelled_at, consulted_at, expired_at, consulta_updated_at)) DESC, consulta_id DESC, line_no;

-- ---------------------------------------------------------------------
-- 3. painel_loans_history_v1  (+ e.is_hidden_by_user, granularité racine)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW api.painel_loans_history_v1
WITH (security_invoker = true) AS
 WITH items_agg AS (
         SELECT i.emprestimo_id,
            count(*)::integer AS items_count,
            string_agg(COALESCE(i.titulo_cache, ('['::text || COALESCE(i.bib_ref, ''::text)) || ']'::text), ' ; '::text ORDER BY i.line_no) AS titulos,
            string_agg(DISTINCT COALESCE(i.autor_cache, ''::text), ' ; '::text) FILTER (WHERE COALESCE(i.autor_cache, ''::text) <> ''::text) AS autores,
            string_agg(i.bib_ref, ' ; '::text ORDER BY i.line_no) AS bib_refs,
            max(i.returned_at) AS last_returned_at,
            min(i.book_id) AS first_book_id
           FROM emprestimo_itens_v2 i
          GROUP BY i.emprestimo_id
        )
 SELECT e.id AS emprestimo_id,
    e.library_id,
    l.slug AS library_slug,
    l.name AS library_name,
    ia.items_count,
        CASE
            WHEN ia.items_count = 1 THEN 'uni'::text
            ELSE 'groupe'::text
        END AS loan_type,
    ia.titulos,
    ia.autores,
    ia.bib_refs,
    ia.first_book_id AS book_id,
    e.status_global,
    e.notes,
    e.user_id,
    p.public_id AS user_public_id,
    p.email AS user_email,
    NULLIF(TRIM(BOTH FROM concat_ws(' '::text, p.first_name, p.last_name)), ''::text) AS user_name,
    e.created_at AS borrowed_at,
    e.due_at,
    ia.last_returned_at AS returned_at,
    e.renewals_used,
    e.extended_once,
    e.extended_at,
    e.updated_at,
    COALESCE(ia.last_returned_at, e.updated_at) AS closed_at,
    e.is_hidden_by_user
   FROM emprestimos_v2 e
     JOIN libraries l ON l.id = e.library_id
     LEFT JOIN items_agg ia ON ia.emprestimo_id = e.id
     LEFT JOIN profiles p ON p.id = e.user_id
  WHERE e.status_global = 'encerrado'::text AND l.circulation_mode <> 'off'::text
  ORDER BY (COALESCE(ia.last_returned_at, e.updated_at)) DESC, e.id DESC;

-- ---------------------------------------------------------------------
-- 4. Vérification DO-block
-- ---------------------------------------------------------------------
DO $$
DECLARE v_missing text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='api' AND table_name='painel_reservations_history_v1' AND column_name='is_hidden_by_user')
    THEN v_missing := v_missing || 'painel_reservations_history_v1; '; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='api' AND table_name='painel_consultas_history_v1' AND column_name='is_hidden_by_user')
    THEN v_missing := v_missing || 'painel_consultas_history_v1; '; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='api' AND table_name='painel_loans_history_v1' AND column_name='is_hidden_by_user')
    THEN v_missing := v_missing || 'painel_loans_history_v1; '; END IF;

  IF v_missing <> '' THEN
    RAISE EXCEPTION 'Migration C.6 incomplète, vues sans is_hidden_by_user : %', v_missing;
  END IF;
  RAISE NOTICE 'Migration C.6 : is_hidden_by_user projeté dans les 3 vues painel.';
END;
$$;

COMMIT;
