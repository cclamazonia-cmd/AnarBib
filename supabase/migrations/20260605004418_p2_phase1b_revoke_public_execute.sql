-- 20260605140000_p2_phase1b_revoke_public_execute.sql
--
-- P2 (phase 1b) — complète la phase 1.
--
-- 4 fonctions tenaient leur EXECUTE pour anon (et authenticated) via un grant à
-- PUBLIC, que "REVOKE ... FROM anon/authenticated" ne retire pas. On retire donc
-- le grant PUBLIC. Ce sont précisément des fonctions héritées d'avant la doctrine
-- "REVOKE EXECUTE FROM PUBLIC" (cf. hook pre-commit .githooks).
--
--   * 3 fonctions de TRIGGER : n'ont besoin d'AUCUN grant EXECUTE (un trigger ne
--     vérifie pas l'EXECUTE de l'appelant). postgres / service_role conservés.
--   * fn_can_engage_library_for_storage : conserve son grant DIRECT à
--     authenticated (helper staff) ; seul PUBLIC (donc anon) est retiré.
--
-- Effet attendu : anon 22 -> 18 ; authenticated 187 -> 184 ; total WARN 213 -> 206.
-- Les 18 fonctions anon restantes sont toutes légitimes (4 helpers RLS + 14 RPC
-- publiques confirmees cote frontend).

REVOKE EXECUTE ON FUNCTION public.fn_can_engage_library_for_storage(p_library_id uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_replicate_consulta_agendada_to_inapp() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_replicate_reserva_pronta_to_inapp() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.tg_enqueue_task_level_notifications_from_task() FROM PUBLIC;
