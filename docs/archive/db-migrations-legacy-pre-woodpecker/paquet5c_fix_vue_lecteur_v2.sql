-- ═══════════════════════════════════════════════════════════
-- Paquet 5c — fix vue lecteur api.my_reservations_active_v2
-- ═══════════════════════════════════════════════════════════
-- Bug observé après paquet 5b : côté AccountPage, une résa en
-- workflow_stage = 'retirada_a_combinar' avec pickup_proposed_by = 'biblio'
-- n'affiche pas les boutons d'action lecteur (Aceitar este horário /
-- Propor outro horário / Cancelar).
--
-- Cause : la vue api.my_reservations_active_v2 sélectionne explicitement ses
-- colonnes depuis api.reserva_itens_followup_ui mais ne fait pas remonter
-- pickup_proposed_by ni negotiation_iteration_count. La vue source les expose
-- depuis le paquet 2 bis, mais cette vue dérivée a été créée avant et n'a pas
-- été mise à jour.
--
-- Fix : recréer la vue avec ces 2 colonnes en plus. Aucune migration de
-- données. Aucun changement permissions/RLS (la vue hérite de sa source).
--
-- Note : les 2 nouvelles colonnes sont AJOUTÉES EN FIN de la liste SELECT
-- pour respecter la contrainte Postgres "cannot change name of view column"
-- imposée par CREATE OR REPLACE VIEW. Postgres autorise l'ajout en queue
-- mais pas le réordonnancement ni le renommage. Côté frontend ça n'a aucun
-- impact : les colonnes sont accessibles par nom (r.pickup_proposed_by, etc.)
-- et l'ordre de SELECT est juste un détail de présentation.
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW api.my_reservations_active_v2 AS
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
       -- AJOUTS paquet 5c (en fin de liste pour respecter CREATE OR REPLACE)
       r.pickup_proposed_by,
       COALESCE(r.negotiation_iteration_count, 0) AS negotiation_iteration_count
FROM me m
JOIN api.reserva_itens_followup_ui r ON r.user_id = m.id
WHERE m.is_authenticated = true
  AND r.item_status = 'ativa'::text
ORDER BY r.reserva_created_at DESC, r.reserva_id DESC, r.line_no;

COMMENT ON VIEW api.my_reservations_active_v2 IS
  'Vue lecteur des réservations actives. Paquet 5c (2026-05-09) : ajout
   pickup_proposed_by et negotiation_iteration_count en fin de liste pour
   alimenter les boutons de négociation symétrique côté AccountPage en
   sémantique v3.';

-- ═══════════════════════════════════════════════════════════
-- Requêtes d'acceptation à lancer après application
-- ═══════════════════════════════════════════════════════════
-- Q1 : la vue expose maintenant les 2 colonnes
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_schema = 'api'
--   AND table_name = 'my_reservations_active_v2'
--   AND column_name IN ('pickup_proposed_by', 'negotiation_iteration_count')
-- ORDER BY column_name;
--
-- Attendu : 2 lignes
--   negotiation_iteration_count | integer
--   pickup_proposed_by          | text
--
-- Q2 : la résa #6 (test à chaud) remonte bien biblio/0
-- SELECT reserva_id, line_no, workflow_stage_effective,
--        pickup_proposed_by, negotiation_iteration_count, pickup_scheduled_for
-- FROM api.my_reservations_active_v2
-- WHERE reserva_id = 6;
--
-- Attendu : 1 ligne avec pickup_proposed_by='biblio', negotiation_iteration_count=0
-- ═══════════════════════════════════════════════════════════
