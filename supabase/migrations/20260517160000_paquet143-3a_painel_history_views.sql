-- ============================================================
-- Migration 143.3.a — Vues historique pour PanelPage
-- ============================================================
-- Sous-paquet du chantier #143 (Painel : onglet Historique).
--
-- Cree 3 vues api.painel_*_history_v1 qui retournent les items
-- archives filtres par library_id du staff connecte. La RLS sur
-- les tables sous-jacentes (reservas_v2, consultas_locais_v2,
-- emprestimos_v2) filtre naturellement par la membership du staff.
--
-- Doctrine securite (docs/decisions/CHANTIER_doctrine_creation_objets
-- _securises_2026-05-12.md) :
--   - security_invoker = on (la RLS de l'appelant filtre)
--   - GRANT SELECT TO authenticated explicite (pas PUBLIC)
--   - DO-block de verification en fin
--
-- Difference cle vs vues lecteur my_*_history :
--   - reservations : staff voit TOUTES les reservations archivees
--     de sa biblio, pas seulement les siennes
--   - consultas : idem ; et on inclut les cancelada_biblioteca meme
--     sans dismiss_by_reader (critere pertinent lecteur, pas staff)
--   - emprestimos : idem
--
-- Colonnes alignees sur les choix UI du chantier 143.3 :
--   Reservations : Titre, Statut, Lecteur, Date demande, Date archivage, Motif
--   Consultas    : Titre, Statut, Lecteur, Date prevue, Date archivage, Motif
--   Emprestimos  : Items (groupes), Type (uni/groupe), Lecteur, Date retour
-- ============================================================

-- ============================================================
-- VUE 1 — api.painel_reservations_history_v1
-- ============================================================
CREATE OR REPLACE VIEW api.painel_reservations_history_v1
WITH (security_invoker = on) AS
SELECT
  r.reserva_id,
  r.reserva_item_id,
  r.line_no,
  r.library_id,
  r.library_slug,
  r.library_name,
  -- Identite item
  r.book_id,
  r.bib_ref,
  r.titulo,
  r.autor,
  r.ano,
  r.editora,
  r.rotulo,
  -- Statut + workflow
  r.item_status,
  r.workflow_stage_effective,
  r.workflow_note,
  -- Lecteur (pour staff visible)
  r.user_id,
  r.user_public_id,
  r.user_email,
  r.user_name,
  -- Dates
  r.reserva_created_at AS requested_at,
  r.cancelled_at,
  r.converted_at,
  r.expired_at,
  r.reserva_updated_at,
  COALESCE(r.cancelled_at, r.converted_at, r.expired_at, r.reserva_updated_at) AS closed_at
FROM api.reserva_itens_followup_ui r
WHERE r.item_status = ANY (ARRAY[
  'cancelada_leitor'::text,
  'cancelada_biblioteca'::text,
  'convertida_em_emprestimo'::text,
  'expirada'::text,
  'liberada_para_circulacao'::text
])
ORDER BY 
  COALESCE(r.cancelled_at, r.converted_at, r.expired_at, r.reserva_updated_at) DESC,
  r.reserva_id DESC, 
  r.line_no;

COMMENT ON VIEW api.painel_reservations_history_v1 IS
  'Reservations archivees (historique) pour PanelPage. v1 chantier 143.3.a (17/05/2026). RLS via security_invoker sur reservas_v2 (le staff voit les reservations de sa biblio).';

REVOKE ALL ON api.painel_reservations_history_v1 FROM PUBLIC;
GRANT SELECT ON api.painel_reservations_history_v1 TO authenticated;


-- ============================================================
-- VUE 2 — api.painel_consultas_history_v1
-- ============================================================
CREATE OR REPLACE VIEW api.painel_consultas_history_v1
WITH (security_invoker = on) AS
SELECT
  r.consulta_id,
  r.consulta_item_id,
  r.line_no,
  r.library_id,
  r.library_slug,
  r.library_name,
  -- Identite item
  r.book_id,
  r.holding_id,
  r.bib_ref,
  r.titulo,
  r.autor,
  r.ano,
  r.editora,
  -- Statut + workflow
  r.item_status,
  r.workflow_stage_effective,
  r.workflow_note,
  r.schedule_reply_status,
  r.schedule_reply_note,
  -- Lecteur
  r.user_id,
  r.user_public_id,
  r.user_email,
  r.user_name,
  -- Dates
  r.consulta_created_at AS requested_at,
  r.consultation_scheduled_for AS scheduled_for,
  r.consultation_starts_at,
  r.consultation_ends_at,
  r.cancelled_at,
  r.consulted_at,
  r.expired_at,
  r.dismissed_by_reader_at,
  r.consulta_updated_at,
  COALESCE(r.cancelled_at, r.consulted_at, r.expired_at, r.consulta_updated_at) AS closed_at
FROM api.consulta_itens_followup_ui r
WHERE r.item_status = ANY (ARRAY[
  'cancelada_biblioteca'::text,
  'cancelada_leitor'::text,
  'consultada'::text,
  'expirada'::text
])
ORDER BY 
  COALESCE(r.cancelled_at, r.consulted_at, r.expired_at, r.consulta_updated_at) DESC,
  r.consulta_id DESC, 
  r.line_no;

COMMENT ON VIEW api.painel_consultas_history_v1 IS
  'Consultations archivees (historique) pour PanelPage. v1 chantier 143.3.a (17/05/2026). RLS via security_invoker sur consultas_locais_v2 (le staff voit les consultations de sa biblio). Inclut les cancelada_biblioteca meme sans dismiss lecteur (critere lecteur, pas staff).';

REVOKE ALL ON api.painel_consultas_history_v1 FROM PUBLIC;
GRANT SELECT ON api.painel_consultas_history_v1 TO authenticated;


-- ============================================================
-- VUE 3 — api.painel_loans_history_v1
-- ============================================================
-- Vue agregee : un emprestimo (groupe) = 1 ligne, items concatenes.
-- Permet d'identifier visuellement uni (items_count=1) vs groupe (>1).
CREATE OR REPLACE VIEW api.painel_loans_history_v1
WITH (security_invoker = on) AS
WITH items_agg AS (
  SELECT 
    i.emprestimo_id,
    count(*)::integer AS items_count,
    string_agg(
      COALESCE(i.titulo_cache, '[' || COALESCE(i.bib_ref, '') || ']'),
      ' ; ' ORDER BY i.line_no
    ) AS titulos,
    string_agg(
      DISTINCT COALESCE(i.autor_cache, ''),
      ' ; '
    ) FILTER (WHERE COALESCE(i.autor_cache, '') <> '') AS autores,
    string_agg(i.bib_ref, ' ; ' ORDER BY i.line_no) AS bib_refs,
    max(i.returned_at) AS last_returned_at,
    min(i.book_id) AS first_book_id
  FROM emprestimo_itens_v2 i
  GROUP BY i.emprestimo_id
)
SELECT
  e.id AS emprestimo_id,
  e.library_id,
  l.slug AS library_slug,
  l.name AS library_name,
  -- Items agreges
  ia.items_count,
  CASE WHEN ia.items_count = 1 THEN 'uni' ELSE 'groupe' END AS loan_type,
  ia.titulos,
  ia.autores,
  ia.bib_refs,
  ia.first_book_id AS book_id,
  -- Statut + workflow
  e.status_global,
  e.notes,
  -- Lecteur
  e.user_id,
  p.public_id AS user_public_id,
  p.email AS user_email,
  NULLIF(TRIM(BOTH FROM concat_ws(' ', p.first_name, p.last_name)), '') AS user_name,
  -- Dates
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
WHERE e.status_global = 'encerrado'
ORDER BY 
  COALESCE(ia.last_returned_at, e.updated_at) DESC,
  e.id DESC;

COMMENT ON VIEW api.painel_loans_history_v1 IS
  'Emprestimos archives (historique) pour PanelPage. v1 chantier 143.3.a (17/05/2026). RLS via security_invoker sur emprestimos_v2 (le staff voit les emprestimos de sa biblio). Agrege les emprestimo_itens_v2 (1 emprestimo = 1 ligne avec items_count + titulos concatenes).';

REVOKE ALL ON api.painel_loans_history_v1 FROM PUBLIC;
GRANT SELECT ON api.painel_loans_history_v1 TO authenticated;


-- ============================================================
-- VERIFICATIONS (DO-block doctrine)
-- ============================================================
DO $$
DECLARE
  v_view_count int;
  v_invoker_count int;
  v_grant_count int;
  v_public_count int;
BEGIN
  -- 1. Les 3 vues existent
  SELECT count(*) INTO v_view_count
  FROM information_schema.views
  WHERE table_schema = 'api'
    AND table_name IN (
      'painel_reservations_history_v1',
      'painel_consultas_history_v1',
      'painel_loans_history_v1'
    );
  
  IF v_view_count <> 3 THEN
    RAISE EXCEPTION 'Verification echouee : % vues creees au lieu de 3', v_view_count;
  END IF;
  RAISE NOTICE 'OK : 3 vues api.painel_*_history_v1 creees';

  -- 2. security_invoker est bien actif sur les 3 vues
  SELECT count(*) INTO v_invoker_count
  FROM pg_class c
  JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = 'api'
    AND c.relname IN (
      'painel_reservations_history_v1',
      'painel_consultas_history_v1',
      'painel_loans_history_v1'
    )
    AND c.relkind = 'v'
    AND EXISTS (
      SELECT 1 FROM unnest(c.reloptions) opt
      WHERE opt LIKE 'security_invoker=on%' OR opt LIKE 'security_invoker=true%'
    );
  
  IF v_invoker_count <> 3 THEN
    RAISE EXCEPTION 'Verification echouee : % vues avec security_invoker au lieu de 3', v_invoker_count;
  END IF;
  RAISE NOTICE 'OK : security_invoker=on sur les 3 vues';

  -- 3. GRANT SELECT TO authenticated existe
  SELECT count(*) INTO v_grant_count
  FROM information_schema.role_table_grants
  WHERE table_schema = 'api'
    AND table_name IN (
      'painel_reservations_history_v1',
      'painel_consultas_history_v1',
      'painel_loans_history_v1'
    )
    AND grantee = 'authenticated'
    AND privilege_type = 'SELECT';
  
  IF v_grant_count <> 3 THEN
    RAISE EXCEPTION 'Verification echouee : % GRANT SELECT to authenticated au lieu de 3', v_grant_count;
  END IF;
  RAISE NOTICE 'OK : GRANT SELECT TO authenticated sur les 3 vues';

  -- 4. PUBLIC n'a aucun privilege
  SELECT count(*) INTO v_public_count
  FROM information_schema.role_table_grants
  WHERE table_schema = 'api'
    AND table_name IN (
      'painel_reservations_history_v1',
      'painel_consultas_history_v1',
      'painel_loans_history_v1'
    )
    AND grantee = 'PUBLIC';
  
  IF v_public_count <> 0 THEN
    RAISE EXCEPTION 'Verification echouee : PUBLIC a encore des privileges (% trouves)', v_public_count;
  END IF;
  RAISE NOTICE 'OK : PUBLIC ne peut rien sur les 3 vues';

  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 143.3.a appliquee avec succes';
  RAISE NOTICE '  - api.painel_reservations_history_v1 (5 statuts archives)';
  RAISE NOTICE '  - api.painel_consultas_history_v1 (4 statuts archives)';
  RAISE NOTICE '  - api.painel_loans_history_v1 (status_global=encerrado, agregee)';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Suite : sous-paquet 143.3.b (i18n staff history) + 143.3.c (JSX fetch + affichage)';
END $$;
