-- =========================================================================
-- Paquet RGPD — fix fn_delete_my_account : anonymisation (compte « removido »)
-- =========================================================================
-- Date     : 2026-06-23
-- Chantier : RGPD — suppression de compte self-service
--
-- ⚠️ FICHIER RECONSTRUIT À POSTERIORI (mirror repo↔prod).
-- La migration 20260623204043 avait été APPLIQUÉE en production (via MCP) par
-- une autre session SANS être committée dans le repo, ce qui cassait
-- `supabase db push` (« Remote migration versions not found in local migrations
-- directory »). Le SQL ci-dessous est la copie EXACTE de ce qui a été appliqué
-- (source : supabase_migrations.schema_migrations.statements). Réintégré pour
-- réaligner le dépôt sur la base — doctrine : toute migration MCP doit être
-- mirrorée dans le repo Git. Déjà appliqué en prod → db push le saute (no-op).
-- =========================================================================

DO $$
DECLARE
  v_removido constant uuid := '00000000-0000-0000-0000-000000000001';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_removido) THEN
    INSERT INTO auth.users (
      id, instance_id, aud, role, email, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data,
      is_sso_user, is_anonymous, created_at, updated_at
    ) VALUES (
      v_removido,
      '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated',
      'removido@anarbib.local', now(),
      jsonb_build_object('provider','email','providers', jsonb_build_array('email')),
      jsonb_build_object('first_name','Leitor','last_name','removido'),
      false, false, now(), now()
    );
  END IF;

  UPDATE public.profiles
     SET first_name = 'Leitor',
         last_name  = 'removido',
         email      = 'removido@anarbib.local',
         is_librarian = false
   WHERE id = v_removido;
END $$;

CREATE OR REPLACE FUNCTION public.fn_delete_my_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id  uuid := auth.uid();
  v_removido constant uuid := '00000000-0000-0000-0000-000000000001';
  v_open_loans int;
  v_cancelled  int := 0;
  v_anon_res   int := 0;
  v_anon_loans int := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Nenhum usuário autenticado.');
  END IF;
  IF v_user_id = v_removido THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Conta técnica não pode ser excluída.');
  END IF;

  SELECT count(*) INTO v_open_loans
  FROM emprestimos_v2 e
  JOIN emprestimo_itens_v2 ei ON ei.emprestimo_id = e.id
  WHERE e.user_id = v_user_id AND ei.item_status = 'aberto';

  IF v_open_loans > 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Você tem ' || v_open_loans || ' empréstimo(s) em aberto. Devolva todos os itens antes de excluir sua conta.',
      'open_loans', v_open_loans
    );
  END IF;

  UPDATE reserva_linhas_v2 l
     SET item_status = 'cancelada_biblioteca', cancelled_at = now()
    FROM reservas_v2 r
   WHERE l.reserva_id = r.id
     AND r.user_id = v_user_id
     AND l.item_status = 'ativa';
  GET DIAGNOSTICS v_cancelled = ROW_COUNT;

  UPDATE reservas_v2
     SET status_global = 'encerrada'
   WHERE user_id = v_user_id AND status_global <> 'encerrada';

  UPDATE reservas_v2  SET user_id = v_removido WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_anon_res = ROW_COUNT;
  UPDATE emprestimos_v2 SET user_id = v_removido WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_anon_loans = ROW_COUNT;

  UPDATE reader_library_messages SET sender_id    = v_removido WHERE sender_id    = v_user_id;
  UPDATE reader_library_messages SET recipient_id = v_removido WHERE recipient_id = v_user_id;
  UPDATE entraide_help_offers    SET helper_user_id = v_removido WHERE helper_user_id = v_user_id;
  UPDATE entraide_help_requests  SET author_user_id = v_removido WHERE author_user_id = v_user_id;

  UPDATE emprestimo_itens_v2      SET return_scheduled_by = NULL WHERE return_scheduled_by = v_user_id;
  UPDATE reserva_item_workflow_v2 SET updated_by = NULL WHERE updated_by = v_user_id;

  DELETE FROM reader_card_tokens WHERE user_id = v_user_id;

  DELETE FROM profiles WHERE id = v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'ok', true,
    'cancelled_reservations', v_cancelled,
    'anonymized_reservations', v_anon_res,
    'anonymized_loans', v_anon_loans,
    'message', 'Conta excluída. Histórico de circulação anonimizado.'
  );
END;
$function$;
