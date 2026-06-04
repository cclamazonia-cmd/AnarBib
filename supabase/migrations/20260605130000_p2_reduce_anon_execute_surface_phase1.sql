-- 1) Fonctions de trigger (anon + authenticated)
REVOKE EXECUTE ON FUNCTION public.fn_replicate_consulta_agendada_to_inapp() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_replicate_reserva_pronta_to_inapp() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_trg_block_acquisition_if_restricted_emprestimo() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_trg_block_acquisition_if_restricted_reserva() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.tg_enqueue_task_level_notifications_from_task() FROM anon, authenticated;

-- 2) Fonctions internes / "mes données" (anon uniquement ; authenticated conservé)
REVOKE EXECUTE ON FUNCTION public.fn_caller_is_administrador() FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_can_engage_library_for_storage(p_library_id uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_current_user_is_in_network() FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_current_user_is_member_of(p_library_id uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_delete_all_my_history(p_library_id uuid, p_domain text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_delete_history_item(p_domain text, p_record_id bigint) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_get_my_retention_preferences() FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_hide_history_item(p_domain text, p_record_id bigint) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_is_cross_library_action(p_library_id uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_notify_event(p_event text, p_payload jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_set_my_retention_preference(p_library_id uuid, p_domain text, p_disable boolean) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_unhide_history_item(p_domain text, p_record_id bigint) FROM anon;