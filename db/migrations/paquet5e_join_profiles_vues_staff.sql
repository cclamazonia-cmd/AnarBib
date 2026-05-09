-- ═══════════════════════════════════════════════════════════
-- Paquet 5e — UX painel : ajout user_name/user_email/user_public_id
--              dans les vues staff (résas, consultations, emprunts)
-- ═══════════════════════════════════════════════════════════
-- Bug observé en prod : côté PanelPage onglet reservas (et probablement
-- consultas et emprunts), quand le lecteur·rice n'a pas user_name ni
-- user_email exposés par la vue, le frontend tombe sur le fallback
-- r.user_id?.slice(0,8) qui affiche un fragment d'UUID brut comme
-- 'd6710372'. Inutilisable pour les bibliothécaires non-spé qui n'ont
-- aucune info pour identifier la personne.
--
-- Cause : 4 vues staff exposent user_id mais pas user_name/user_email :
--   - api.reserva_itens_followup_ui
--   - api.consulta_itens_followup_ui
--   - api.consulta_itens_ui (passe-plat sur followup_ui)
--   - api.emprestimo_itens_ui
--
-- En revanche emprestimo_itens_painel_ui et emprestimo_lotes_painel_ui
-- exposent déjà ces colonnes via JOIN profiles. On reproduit le même
-- pattern pour les 4 vues incomplètes :
--
--   LEFT JOIN profiles p ON p.id = <table_principale>.user_id
--   p.public_id AS user_public_id
--   p.email AS user_email
--   NULLIF(TRIM(BOTH FROM concat_ws(' ', p.first_name, p.last_name)), '')
--     AS user_name
--
-- Stratégie : LEFT JOIN (pas inner) pour ne pas filtrer les enregistrements
-- dont le profile aurait été supprimé (résas/emprunts orphelins). Dans ce
-- cas, user_name=NULL, user_email=NULL et le frontend tombera sur le
-- fragment UUID — comportement actuel inchangé pour ces cas extrêmes.
--
-- Aucune migration de données. Aucun changement RLS/permissions :
-- - Les vues sont dans le schéma 'api' qui hérite des permissions des
--   tables sources via SECURITY INVOKER (pas de SECURITY DEFINER).
-- - Le LEFT JOIN sur profiles est sécurisé : seuls les profils que
--   l'utilisateur authentifié peut voir via RLS sur public.profiles
--   seront exposés. Les autres apparaîtront comme NULL.
-- - Côté staff librarian/coordenador, la RLS profiles permet déjà la
--   lecture des profils des lecteurs de leur biblio (cf. policies en
--   place pour emprestimo_itens_painel_ui qui marche).
--
-- Note Postgres CREATE OR REPLACE VIEW : on ajoute les 3 colonnes en
-- fin de liste SELECT pour éviter "cannot change name of view column".
-- ═══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. api.reserva_itens_followup_ui
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW api.reserva_itens_followup_ui AS
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
       -- AJOUTS paquet 5e (en fin pour CREATE OR REPLACE)
       p.public_id AS user_public_id,
       p.email AS user_email,
       NULLIF(TRIM(BOTH FROM concat_ws(' '::text, p.first_name, p.last_name)), ''::text) AS user_name
FROM reservas_v2 r
  JOIN reserva_linhas_v2 rl ON rl.reserva_id = r.id
  JOIN libraries l ON l.id = r.library_id
  LEFT JOIN books b ON b.id = rl.book_id
  LEFT JOIN reserva_item_workflow_v2 w
    ON w.reserva_id = rl.reserva_id AND w.line_no = rl.line_no
  LEFT JOIN profiles p ON p.id = r.user_id;

COMMENT ON VIEW api.reserva_itens_followup_ui IS
  'Vue de suivi des items de réservation pour le painel staff. Paquet 5e
   (2026-05-09) : ajout user_public_id/user_email/user_name via LEFT JOIN
   profiles pour identifier le·la lecteur·rice côté painel sans tomber
   sur un fragment d''UUID brut.';

-- ─────────────────────────────────────────────────────────────
-- 2. api.consulta_itens_followup_ui
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW api.consulta_itens_followup_ui AS
WITH latest_workflow AS (
  SELECT DISTINCT ON (w.consulta_id, w.line_no)
         w.consulta_id,
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
       -- AJOUTS paquet 5e (en fin pour CREATE OR REPLACE)
       p.public_id AS user_public_id,
       p.email AS user_email,
       NULLIF(TRIM(BOTH FROM concat_ws(' '::text, p.first_name, p.last_name)), ''::text) AS user_name
FROM consultas_locais_v2 c
  JOIN consulta_linhas_v2 cl ON cl.consulta_id = c.id
  JOIN libraries l ON l.id = c.library_id
  LEFT JOIN latest_workflow lw
    ON lw.consulta_id = cl.consulta_id AND lw.line_no = cl.line_no
  LEFT JOIN profiles p ON p.id = c.user_id;

COMMENT ON VIEW api.consulta_itens_followup_ui IS
  'Vue de suivi des items de consultation pour le painel staff. Paquet 5e
   (2026-05-09) : ajout user_public_id/user_email/user_name via LEFT JOIN
   profiles.';

-- ─────────────────────────────────────────────────────────────
-- 3. api.consulta_itens_ui (passe-plat sur followup_ui)
-- ─────────────────────────────────────────────────────────────
-- Cette vue est un re-SELECT explicite des colonnes de followup_ui.
-- Elle filtre donc les nouvelles colonnes si on ne l'étend pas aussi.
-- On reproduit la même structure avec les 3 colonnes ajoutées en fin.
CREATE OR REPLACE VIEW api.consulta_itens_ui AS
SELECT consulta_id,
       consulta_item_id,
       line_no,
       sub_id,
       user_id,
       library_id,
       library_slug,
       library_name,
       consulta_created_at,
       consulta_updated_at,
       consulta_status,
       book_id,
       holding_id,
       bib_ref,
       rotulo,
       autor,
       titulo,
       editora,
       ano,
       item_status,
       expires_at,
       cancelled_at,
       consulted_at,
       expired_at,
       item_notes,
       workflow_stage_effective,
       workflow_note,
       consultation_scheduled_for,
       workflow_stage_updated_at_effective,
       dismissed_by_reader_at,
       schedule_reply_status,
       schedule_reply_note,
       schedule_reply_at,
       consultation_starts_at,
       consultation_ends_at,
       -- AJOUTS paquet 5e (en fin pour CREATE OR REPLACE)
       user_public_id,
       user_email,
       user_name
FROM api.consulta_itens_followup_ui;

COMMENT ON VIEW api.consulta_itens_ui IS
  'Vue UI des items de consultation (passe-plat sur followup_ui).
   Paquet 5e (2026-05-09) : répercute user_public_id/user_email/user_name
   depuis la vue source.';

-- ─────────────────────────────────────────────────────────────
-- 4. api.emprestimo_itens_ui
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW api.emprestimo_itens_ui AS
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
       -- AJOUTS paquet 5e (en fin pour CREATE OR REPLACE)
       p.public_id AS user_public_id,
       p.email AS user_email,
       NULLIF(TRIM(BOTH FROM concat_ws(' '::text, p.first_name, p.last_name)), ''::text) AS user_name
FROM emprestimos_v2 e
  JOIN emprestimo_itens_v2 i ON i.emprestimo_id = e.id
  LEFT JOIN profiles p ON p.id = e.user_id;

COMMENT ON VIEW api.emprestimo_itens_ui IS
  'Vue UI des items d''emprunt. Paquet 5e (2026-05-09) : ajout
   user_public_id/user_email/user_name via LEFT JOIN profiles.';

-- ═══════════════════════════════════════════════════════════
-- Requêtes d'acceptation à lancer après application
-- ═══════════════════════════════════════════════════════════
-- Q1 : les 4 vues exposent maintenant les 3 colonnes
-- SELECT table_name, column_name
-- FROM information_schema.columns
-- WHERE table_schema = 'api'
--   AND table_name IN ('reserva_itens_followup_ui', 'consulta_itens_followup_ui',
--                      'consulta_itens_ui', 'emprestimo_itens_ui')
--   AND column_name IN ('user_public_id', 'user_email', 'user_name')
-- ORDER BY table_name, column_name;
--
-- Attendu : 12 lignes (4 vues × 3 colonnes)
--
-- Q2 : la résa #6 (test à chaud) remonte bien le nom du lecteur
-- SELECT reserva_id, line_no, user_id, user_public_id, user_email, user_name
-- FROM api.reserva_itens_followup_ui
-- WHERE reserva_id = 6;
--
-- Attendu : 1 ligne avec user_name='Xavier VAN WELDEN',
--           user_email='x.vanwelden@gmail.com'
--
-- Q3 : aucune régression sur les vues qui exposaient déjà ces colonnes
-- SELECT count(*)
-- FROM api.emprestimo_itens_painel_ui
-- WHERE user_name IS NOT NULL OR user_email IS NOT NULL;
-- (doit retourner > 0 si des emprunts existent — comportement inchangé)
-- ═══════════════════════════════════════════════════════════
