-- ============================================================================
-- Paquet D.4 - Patch des vues d'historique : couche masquage circulation_mode
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.4 (paquet D, couche masquage)
-- Dependance : paquet D.1, D.2, D.3.
--
-- Objectif : masquer les transactions historiques (encerrado, cancelado, etc.)
-- quand une biblio est en circulation_mode = 'off'.
--
-- Doctrine §9.4 :
--   - Le filtre est RETROACTIF et AUTOMATIQUE.
--   - Si une biblio passe en circulation_mode = 'off', son historique disparait
--     des UIs courantes.
--   - Si elle revient a 'informal' ou 'full_sigb', l'historique REAPPARAIT.
--   - L'historique n'est PAS supprime ni archive - il est juste masque par filtre.
--
-- 6 vues a patcher (la spec en mentionnait 2 mais en pratique il y en a 6) :
--
--   Cote lecteur (preserve la conta du leitor·a) :
--     1. api.my_consultas_history_v2
--     2. api.my_loans_history_v1
--     3. api.my_reservations_history_v2
--
--   Cote staff (preserve le painel coordination) :
--     4. api.painel_consultas_history_v1
--     5. api.painel_loans_history_v1
--     6. api.painel_reservations_history_v1
--
-- Cas non concernes (decision doctrinale v0.5) :
--   - Cotisations : la tracabilite comptable exige que l'historique reste
--     accessible meme en circulation_mode = 'off'. Pas de filtre applique
--     (v_active_memberships utilise membership_enabled + archived_at, pas
--     circulation_mode).
--   - PEB rapports : la coordination inter-bibs doit pouvoir consulter les
--     PEB passes meme si une biblio se retire. interlibrary_loans_reports_ui
--     reste filtre uniquement par archived_at IS NULL (D.3), pas par
--     circulation_mode.
--
-- Doctrine v2.2 : CREATE OR REPLACE VIEW pour preserver les grants.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. api.my_consultas_history_v2
-- ============================================================================
-- Cascade depuis api.consulta_itens_followup_ui (D.3 filtre archived_at).
-- Ajout : filtre EXISTS (... libraries.circulation_mode <> 'off') sur library_id.
CREATE OR REPLACE VIEW api.my_consultas_history_v2 WITH (security_invoker=true) AS
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
    r.consultation_ends_at
   FROM me m
     JOIN api.consulta_itens_followup_ui r ON r.user_id = m.id
  WHERE m.is_authenticated = true
    AND ((r.item_status = ANY (ARRAY['consultada'::text, 'cancelada_leitor'::text, 'expirada'::text]))
         OR r.item_status = 'cancelada_biblioteca'::text AND r.dismissed_by_reader_at IS NOT NULL)
    AND EXISTS (
      SELECT 1 FROM public.libraries lib
       WHERE lib.id = r.library_id
         AND lib.circulation_mode <> 'off'
    )
  ORDER BY (COALESCE(r.dismissed_by_reader_at, r.cancelled_at, r.consulted_at, r.expired_at, r.consulta_updated_at)) DESC, r.consulta_id DESC, r.line_no;

-- ============================================================================
-- 2. api.my_loans_history_v1
-- ============================================================================
-- Source : emprestimos_v2 direct (pas cascade via D.3).
-- Ajout : filtre circulation_mode <> 'off' sur e.library_id.
CREATE OR REPLACE VIEW api.my_loans_history_v1 WITH (security_invoker=true) AS
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
    COALESCE(ia.last_returned_at, e.updated_at) AS closed_at
   FROM emprestimos_v2 e
     JOIN me m ON e.user_id = m.id
     LEFT JOIN items_aggreg ia ON ia.emprestimo_id = e.id
     LEFT JOIN library_commons l ON l.library_id = e.library_id
  WHERE m.is_authenticated = true
    AND e.status_global = 'encerrado'::text
    AND EXISTS (
      SELECT 1 FROM public.libraries lib
       WHERE lib.id = e.library_id
         AND lib.circulation_mode <> 'off'
    )
  ORDER BY (COALESCE(ia.last_returned_at, e.updated_at)) DESC, e.id DESC;

-- ============================================================================
-- 3. api.my_reservations_history_v2
-- ============================================================================
-- Cascade via api.reserva_itens_followup_ui (D.3).
CREATE OR REPLACE VIEW api.my_reservations_history_v2 WITH (security_invoker=true) AS
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
    r.rotulo
   FROM me m
     JOIN api.reserva_itens_followup_ui r ON r.user_id = m.id
  WHERE m.is_authenticated = true
    AND (r.item_status = ANY (ARRAY['cancelada_leitor'::text, 'cancelada_biblioteca'::text, 'convertida_em_emprestimo'::text, 'expirada'::text, 'liberada_para_circulacao'::text]))
    AND EXISTS (
      SELECT 1 FROM public.libraries lib
       WHERE lib.id = r.library_id
         AND lib.circulation_mode <> 'off'
    )
  ORDER BY (COALESCE(r.cancelled_at, r.converted_at, r.expired_at, r.reserva_updated_at)) DESC, r.reserva_id DESC, r.line_no;

-- ============================================================================
-- 4. api.painel_consultas_history_v1
-- ============================================================================
-- Source : api.consulta_itens_followup_ui.
CREATE OR REPLACE VIEW api.painel_consultas_history_v1 WITH (security_invoker=true) AS
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
    COALESCE(cancelled_at, consulted_at, expired_at, consulta_updated_at) AS closed_at
   FROM api.consulta_itens_followup_ui r
  WHERE (item_status = ANY (ARRAY['cancelada_biblioteca'::text, 'cancelada_leitor'::text, 'consultada'::text, 'expirada'::text]))
    AND EXISTS (
      SELECT 1 FROM public.libraries lib
       WHERE lib.id = r.library_id
         AND lib.circulation_mode <> 'off'
    )
  ORDER BY (COALESCE(cancelled_at, consulted_at, expired_at, consulta_updated_at)) DESC, consulta_id DESC, line_no;

-- ============================================================================
-- 5. api.painel_loans_history_v1
-- ============================================================================
-- Source : emprestimos_v2 direct (pas cascade via D.3).
CREATE OR REPLACE VIEW api.painel_loans_history_v1 WITH (security_invoker=true) AS
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
    COALESCE(ia.last_returned_at, e.updated_at) AS closed_at
   FROM emprestimos_v2 e
     JOIN libraries l ON l.id = e.library_id
     LEFT JOIN items_agg ia ON ia.emprestimo_id = e.id
     LEFT JOIN profiles p ON p.id = e.user_id
  WHERE e.status_global = 'encerrado'::text
    AND l.circulation_mode <> 'off'
  ORDER BY (COALESCE(ia.last_returned_at, e.updated_at)) DESC, e.id DESC;

-- ============================================================================
-- 6. api.painel_reservations_history_v1
-- ============================================================================
-- Source : api.reserva_itens_followup_ui.
CREATE OR REPLACE VIEW api.painel_reservations_history_v1 WITH (security_invoker=true) AS
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
    COALESCE(cancelled_at, converted_at, expired_at, reserva_updated_at) AS closed_at
   FROM api.reserva_itens_followup_ui r
  WHERE (item_status = ANY (ARRAY['cancelada_leitor'::text, 'cancelada_biblioteca'::text, 'convertida_em_emprestimo'::text, 'expirada'::text, 'liberada_para_circulacao'::text]))
    AND EXISTS (
      SELECT 1 FROM public.libraries lib
       WHERE lib.id = r.library_id
         AND lib.circulation_mode <> 'off'
    )
  ORDER BY (COALESCE(cancelled_at, converted_at, expired_at, reserva_updated_at)) DESC, reserva_id DESC, line_no;

-- ============================================================================
-- DO block de verification fail-fast
-- ============================================================================
DO $verif$
DECLARE
  v_count int;
BEGIN
  -- Les 6 vues d'historique doivent exister
  SELECT count(*) INTO v_count
    FROM information_schema.views
   WHERE table_schema = 'api'
     AND table_name IN (
       'my_consultas_history_v2', 'my_loans_history_v1', 'my_reservations_history_v2',
       'painel_consultas_history_v1', 'painel_loans_history_v1', 'painel_reservations_history_v1'
     );
  IF v_count <> 6 THEN
    RAISE EXCEPTION 'VERIF_FAIL_A : %/6 vues historique presentes', v_count;
  END IF;

  -- Verifier que les grants sont preserves (anti-pattern C.5)
  SELECT count(DISTINCT table_name) INTO v_count
    FROM information_schema.role_table_grants
   WHERE table_schema = 'api'
     AND table_name IN (
       'my_consultas_history_v2', 'my_loans_history_v1', 'my_reservations_history_v2',
       'painel_consultas_history_v1', 'painel_loans_history_v1', 'painel_reservations_history_v1'
     )
     AND grantee = 'authenticated'
     AND privilege_type = 'SELECT';
  IF v_count <> 6 THEN
    RAISE EXCEPTION 'VERIF_FAIL_B : %/6 vues historique sans grant authenticated SELECT (grants perdus par CREATE OR REPLACE ?)', v_count;
  END IF;

  -- Sanity check : avec BLMF en circulation_mode='full_sigb', les 29 emp historiques
  -- doivent toujours apparaitre dans painel_loans_history_v1 (filtre passe car != 'off')
  SELECT count(*) INTO v_count FROM api.painel_loans_history_v1
   WHERE library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'::uuid;
  IF v_count <> 29 THEN
    RAISE EXCEPTION 'VERIF_FAIL_C : painel_loans_history_v1 retourne %/29 emp historiques BLMF apres patch (regression ?)', v_count;
  END IF;

  RAISE NOTICE 'Paquet D.4 - Verification OK : 6 vues historique patches, grants preserves, sanity 29 emp BLMF visible';
END
$verif$;

COMMIT;
