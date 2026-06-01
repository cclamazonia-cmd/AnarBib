-- =====================================================================
-- Migration : #CL.8 rétention historique lectrice — paquet C.1b (irréversible)
-- Réf doctrine : docs/specs/spec-historico-retencao-lectrice.md v1.0, D.2 + D.7
-- DÉPEND DE : C.1a (colonnes + table préférences déjà en place)
-- À POUSSER : seulement APRÈS validation de C.1a en production (Woodpecker vert + test runtime)
-- Audit FK préalable (01/06/2026) : toutes les FK entrantes des 3 tables sont CASCADE.
--   DELETE sûr, cascade sur workflows et items, aucun blocage ni orphelin parasite.
-- Cohérence racine : option (ii) — nettoyage inline des racines réservation/consultation
--   devenues vides après suppression de leur dernière ligne.
-- =====================================================================

BEGIN;

-- =====================================================================
-- 1. Suppression physique d'une ligne d'historique (D.2 — irréversible)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_delete_history_item(p_domain text, p_record_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid        uuid := auth.uid();
  v_reserva_id  bigint;
  v_consulta_id bigint;
  v_count      integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING HINT = 'history.error.not_authenticated';
  END IF;

  IF p_domain = 'loans' THEN
    -- DELETE direct sur la racine ; cascade sur emprestimo_itens_v2 + loan_midpoint_message_log
    DELETE FROM public.emprestimos_v2
     WHERE id = p_record_id
       AND user_id = v_uid
       AND status_global = 'encerrado';
    GET DIAGNOSTICS v_count = ROW_COUNT;

  ELSIF p_domain = 'reservations' THEN
    -- Vérifier ownership + état terminal, capturer la racine
    SELECT rl.reserva_id INTO v_reserva_id
      FROM public.reserva_linhas_v2 rl
      JOIN public.reservas_v2 r ON r.id = rl.reserva_id
     WHERE rl.id = p_record_id
       AND r.user_id = v_uid
       AND rl.item_status IN ('cancelada_leitor','cancelada_biblioteca','convertida_em_emprestimo','expirada','liberada_para_circulacao');

    IF v_reserva_id IS NULL THEN
      RAISE EXCEPTION 'item_not_found_or_not_terminal' USING HINT = 'history.error.not_found_or_active';
    END IF;

    DELETE FROM public.reserva_linhas_v2 WHERE id = p_record_id;  -- cascade workflow
    GET DIAGNOSTICS v_count = ROW_COUNT;

    -- Nettoyage racine orpheline (option ii)
    IF NOT EXISTS (SELECT 1 FROM public.reserva_linhas_v2 WHERE reserva_id = v_reserva_id) THEN
      DELETE FROM public.reservas_v2 WHERE id = v_reserva_id;
    END IF;

  ELSIF p_domain = 'consultations' THEN
    SELECT cl.consulta_id INTO v_consulta_id
      FROM public.consulta_linhas_v2 cl
      JOIN public.consultas_locais_v2 c ON c.id = cl.consulta_id
     WHERE cl.id = p_record_id
       AND c.user_id = v_uid
       AND cl.item_status IN ('consultada','cancelada_leitor','cancelada_biblioteca','expirada');

    IF v_consulta_id IS NULL THEN
      RAISE EXCEPTION 'item_not_found_or_not_terminal' USING HINT = 'history.error.not_found_or_active';
    END IF;

    DELETE FROM public.consulta_linhas_v2 WHERE id = p_record_id;  -- cascade workflow
    GET DIAGNOSTICS v_count = ROW_COUNT;

    IF NOT EXISTS (SELECT 1 FROM public.consulta_linhas_v2 WHERE consulta_id = v_consulta_id) THEN
      DELETE FROM public.consultas_locais_v2 WHERE id = v_consulta_id;
    END IF;

  ELSE
    RAISE EXCEPTION 'invalid_domain' USING HINT = 'history.error.invalid_domain';
  END IF;

  IF v_count = 0 THEN
    RAISE EXCEPTION 'item_not_found_or_not_terminal' USING HINT = 'history.error.not_found_or_active';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_delete_history_item(text, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_delete_history_item(text, bigint) TO authenticated;

-- =====================================================================
-- 2. Suppression de masse de l'historique passé d'un domaine pour une biblio (D.7)
--    Action destructive — garde-fou UX côté frontend (C.5, mot de confirmation 8 langues).
--    Retourne le nombre de lignes/objets supprimés.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_delete_all_my_history(p_library_id uuid, p_domain text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_count integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING HINT = 'history.error.not_authenticated';
  END IF;

  IF p_domain = 'loans' THEN
    DELETE FROM public.emprestimos_v2
     WHERE user_id = v_uid
       AND library_id = p_library_id
       AND status_global = 'encerrado';
    GET DIAGNOSTICS v_count = ROW_COUNT;

  ELSIF p_domain = 'reservations' THEN
    DELETE FROM public.reserva_linhas_v2 rl
      USING public.reservas_v2 r
     WHERE rl.reserva_id = r.id
       AND r.user_id = v_uid
       AND r.library_id = p_library_id
       AND rl.item_status IN ('cancelada_leitor','cancelada_biblioteca','convertida_em_emprestimo','expirada','liberada_para_circulacao');
    GET DIAGNOSTICS v_count = ROW_COUNT;

    -- Nettoyage racines orphelines de cette lectrice/biblio
    DELETE FROM public.reservas_v2 r
     WHERE r.user_id = v_uid
       AND r.library_id = p_library_id
       AND NOT EXISTS (SELECT 1 FROM public.reserva_linhas_v2 rl WHERE rl.reserva_id = r.id);

  ELSIF p_domain = 'consultations' THEN
    DELETE FROM public.consulta_linhas_v2 cl
      USING public.consultas_locais_v2 c
     WHERE cl.consulta_id = c.id
       AND c.user_id = v_uid
       AND c.library_id = p_library_id
       AND cl.item_status IN ('consultada','cancelada_leitor','cancelada_biblioteca','expirada');
    GET DIAGNOSTICS v_count = ROW_COUNT;

    DELETE FROM public.consultas_locais_v2 c
     WHERE c.user_id = v_uid
       AND c.library_id = p_library_id
       AND NOT EXISTS (SELECT 1 FROM public.consulta_linhas_v2 cl WHERE cl.consulta_id = c.id);

  ELSE
    RAISE EXCEPTION 'invalid_domain' USING HINT = 'history.error.invalid_domain';
  END IF;

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_delete_all_my_history(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_delete_all_my_history(uuid, text) TO authenticated;

-- =====================================================================
-- 3. Vérification DO-block
-- =====================================================================

DO $$
DECLARE v_missing text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname='fn_delete_history_item')
    THEN v_missing := v_missing || 'fn_delete_history_item; '; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname='fn_delete_all_my_history')
    THEN v_missing := v_missing || 'fn_delete_all_my_history; '; END IF;

  IF v_missing <> '' THEN
    RAISE EXCEPTION 'Migration C.1b incomplète, objets manquants : %', v_missing;
  END IF;
  RAISE NOTICE 'Migration C.1b : RPC de suppression présentes.';
END;
$$;

COMMIT;
