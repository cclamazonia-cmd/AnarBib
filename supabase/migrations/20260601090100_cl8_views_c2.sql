-- =====================================================================
-- Migration : #CL.8 rétention historique lectrice — paquet C.2 (vues)
-- Réf doctrine : docs/specs/spec-historico-retencao-lectrice.md v1.0
-- Architecture lecture : δ-PostgREST — is_hidden_by_user ajouté EN PROJECTION
--   des 5 vues, sans filtre dans la vue. Le frontend filtre via .eq() serveur.
--   La même colonne sert : (a) lectrice → filtre, (b) staff → badge (D.3).
-- DÉPEND DE : C.1a (colonnes is_hidden_by_user en place sur les 3 tables)
-- Toutes les vues conservent WITH (security_invoker = true).
-- Colonne ajoutée EN FIN de projection (contrainte CREATE OR REPLACE VIEW).
-- Ordre : vues followup d'abord (dépendances), puis vues history.
-- =====================================================================

BEGIN;

SET LOCAL search_path = public, api;

-- =====================================================================
-- 1. reserva_itens_followup_ui  (+ rl.is_hidden_by_user)
-- =====================================================================
CREATE OR REPLACE VIEW api.reserva_itens_followup_ui
WITH (security_invoker = true) AS
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
    NULLIF(TRIM(BOTH FROM concat_ws(' '::text, p.first_name, p.last_name)), ''::text) AS user_name,
    rl.is_hidden_by_user
   FROM reservas_v2 r
     JOIN reserva_linhas_v2 rl ON rl.reserva_id = r.id
     JOIN libraries l ON l.id = r.library_id
     LEFT JOIN books b ON b.id = rl.book_id
     LEFT JOIN reserva_item_workflow_v2 w ON w.reserva_id = rl.reserva_id AND w.line_no = rl.line_no
     LEFT JOIN profiles p ON p.id = r.user_id
  WHERE r.archived_at IS NULL;

-- =====================================================================
-- 2. consulta_itens_followup_ui  (+ cl.is_hidden_by_user)
-- =====================================================================
CREATE OR REPLACE VIEW api.consulta_itens_followup_ui
WITH (security_invoker = true) AS
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
    NULLIF(TRIM(BOTH FROM concat_ws(' '::text, p.first_name, p.last_name)), ''::text) AS user_name,
    cl.is_hidden_by_user
   FROM consultas_locais_v2 c
     JOIN consulta_linhas_v2 cl ON cl.consulta_id = c.id
     JOIN libraries l ON l.id = c.library_id
     LEFT JOIN latest_workflow lw ON lw.consulta_id = cl.consulta_id AND lw.line_no = cl.line_no
     LEFT JOIN profiles p ON p.id = c.user_id
  WHERE c.archived_at IS NULL;

-- =====================================================================
-- 3. my_loans_history_v1  (+ e.is_hidden_by_user)
-- =====================================================================
CREATE OR REPLACE VIEW api.my_loans_history_v1
WITH (security_invoker = true) AS
 WITH me AS (
         SELECT mp.id,
            mp.is_authenticated,
            mp.default_library_id
           FROM api.my_profile mp
        ), items_aggreg AS (
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
    e.id,
    e.user_id,
    e.library_id,
    l.library_slug,
    l.display_name AS library_name,
    e.library_id = m.default_library_id AS is_default_library,
    e.status_global,
    e.notes,
    e.created_at AS emprestimo_created_at,
    e.created_at,
    e.updated_at,
    e.due_at,
    e.extended_once,
    e.extended_at,
    e.renewals_used,
    ia.items_count,
    ia.titulos,
    ia.autores,
    ia.bib_refs,
    ia.last_returned_at AS returned_at,
    ia.first_book_id AS book_id,
    COALESCE(ia.last_returned_at, e.updated_at) AS closed_at,
    e.is_hidden_by_user
   FROM emprestimos_v2 e
     JOIN me m ON e.user_id = m.id
     LEFT JOIN items_aggreg ia ON ia.emprestimo_id = e.id
     LEFT JOIN library_commons l ON l.library_id = e.library_id
  WHERE m.is_authenticated = true AND e.status_global = 'encerrado'::text AND (EXISTS ( SELECT 1
           FROM libraries lib
          WHERE lib.id = e.library_id AND lib.circulation_mode <> 'off'::text))
  ORDER BY (COALESCE(ia.last_returned_at, e.updated_at)) DESC, e.id DESC;

-- =====================================================================
-- 4. my_reservations_history_v2  (+ r.is_hidden_by_user, propagé du followup)
-- =====================================================================
CREATE OR REPLACE VIEW api.my_reservations_history_v2
WITH (security_invoker = true) AS
 WITH me AS (
         SELECT mp.id,
            mp.is_authenticated,
            mp.default_library_id
           FROM api.my_profile mp
        )
 SELECT r.reserva_id AS id,
    r.reserva_id,
    r.reserva_item_id,
    r.line_no,
    r.sub_id,
    r.user_id,
    r.book_id,
    r.item_id,
    r.library_id,
    r.library_slug,
    r.library_name,
    r.library_id = m.default_library_id AS is_default_library,
    r.bib_ref,
    r.titulo,
    r.autor,
    r.ano,
    r.editora,
    NULL::text AS cover_object_path,
    r.item_status AS status,
    r.item_notes AS notes,
    r.reserva_created_at AS reserved_at,
    r.reserva_created_at AS created_at,
    r.reserva_updated_at AS updated_at,
    r.cancelled_at,
    r.converted_at AS fulfilled_at,
    r.expired_at,
    COALESCE(r.cancelled_at, r.converted_at, r.expired_at, r.reserva_updated_at) AS closed_at,
    r.reserva_status,
    r.workflow_stage_effective,
    r.workflow_note,
    r.pickup_scheduled_for,
    r.workflow_stage_updated_at_effective,
    r.pickup_reply_status,
    r.pickup_reply_note,
    r.pickup_reply_at,
    r.emprestimo_item_id,
    r.rotulo,
    r.is_hidden_by_user
   FROM me m
     JOIN api.reserva_itens_followup_ui r ON r.user_id = m.id
  WHERE m.is_authenticated = true AND (r.item_status = ANY (ARRAY['cancelada_leitor'::text, 'cancelada_biblioteca'::text, 'convertida_em_emprestimo'::text, 'expirada'::text, 'liberada_para_circulacao'::text])) AND (EXISTS ( SELECT 1
           FROM libraries lib
          WHERE lib.id = r.library_id AND lib.circulation_mode <> 'off'::text))
  ORDER BY (COALESCE(r.cancelled_at, r.converted_at, r.expired_at, r.reserva_updated_at)) DESC, r.reserva_id DESC, r.line_no;

-- =====================================================================
-- 5. my_consultas_history_v2  (+ r.is_hidden_by_user, propagé du followup)
-- =====================================================================
CREATE OR REPLACE VIEW api.my_consultas_history_v2
WITH (security_invoker = true) AS
 WITH me AS (
         SELECT mp.id,
            mp.is_authenticated,
            mp.default_library_id
           FROM api.my_profile mp
        )
 SELECT r.consulta_id AS id,
    r.consulta_id,
    r.consulta_item_id,
    r.line_no,
    r.sub_id,
    r.user_id,
    r.book_id,
    r.holding_id,
    r.library_id,
    r.library_slug,
    r.library_name,
    r.library_id = m.default_library_id AS is_default_library,
    r.bib_ref,
    r.titulo,
    r.autor,
    r.ano,
    r.editora,
    NULL::text AS cover_object_path,
    r.item_status AS status,
    r.item_notes AS notes,
    r.consulta_created_at AS requested_at,
    r.consulta_created_at AS created_at,
    r.consulta_updated_at AS updated_at,
    r.cancelled_at,
    r.consulted_at,
    r.expired_at,
    COALESCE(r.dismissed_by_reader_at, r.cancelled_at, r.consulted_at, r.expired_at, r.consulta_updated_at) AS closed_at,
    r.consulta_status,
    r.workflow_stage_effective,
    r.workflow_note,
    r.consultation_scheduled_for,
    r.workflow_stage_updated_at_effective,
    r.rotulo,
    r.dismissed_by_reader_at,
    r.schedule_reply_status,
    r.schedule_reply_note,
    r.schedule_reply_at,
    r.consultation_starts_at,
    r.consultation_ends_at,
    r.is_hidden_by_user
   FROM me m
     JOIN api.consulta_itens_followup_ui r ON r.user_id = m.id
  WHERE m.is_authenticated = true AND ((r.item_status = ANY (ARRAY['consultada'::text, 'cancelada_leitor'::text, 'expirada'::text])) OR r.item_status = 'cancelada_biblioteca'::text AND r.dismissed_by_reader_at IS NOT NULL) AND (EXISTS ( SELECT 1
           FROM libraries lib
          WHERE lib.id = r.library_id AND lib.circulation_mode <> 'off'::text))
  ORDER BY (COALESCE(r.dismissed_by_reader_at, r.cancelled_at, r.consulted_at, r.expired_at, r.consulta_updated_at)) DESC, r.consulta_id DESC, r.line_no;

-- =====================================================================
-- 6. Vérification DO-block
-- =====================================================================
DO $$
DECLARE v_missing text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='api' AND table_name='my_loans_history_v1' AND column_name='is_hidden_by_user')
    THEN v_missing := v_missing || 'my_loans_history_v1.is_hidden_by_user; '; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='api' AND table_name='my_reservations_history_v2' AND column_name='is_hidden_by_user')
    THEN v_missing := v_missing || 'my_reservations_history_v2.is_hidden_by_user; '; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='api' AND table_name='my_consultas_history_v2' AND column_name='is_hidden_by_user')
    THEN v_missing := v_missing || 'my_consultas_history_v2.is_hidden_by_user; '; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='api' AND table_name='reserva_itens_followup_ui' AND column_name='is_hidden_by_user')
    THEN v_missing := v_missing || 'reserva_itens_followup_ui.is_hidden_by_user; '; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='api' AND table_name='consulta_itens_followup_ui' AND column_name='is_hidden_by_user')
    THEN v_missing := v_missing || 'consulta_itens_followup_ui.is_hidden_by_user; '; END IF;

  IF v_missing <> '' THEN
    RAISE EXCEPTION 'Migration C.2 incomplète, colonnes manquantes : %', v_missing;
  END IF;
  RAISE NOTICE 'Migration C.2 : is_hidden_by_user projeté dans les 5 vues.';
END;
$$;

COMMIT;
