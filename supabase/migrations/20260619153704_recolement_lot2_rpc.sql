-- =====================================================================
-- AnarBib — Récolement / Veille du commun — LOT 2 : RPC + trigger passif
-- Auteur  : coordination AnarBib
-- Session : Récolement (veille du commun)
-- Réf     : 20260619152022_recolement_lot1_schema_census.sql ; CADRAGE_recolement.
--
-- Rend la veille FONCTIONNELLE : lancer une campagne, scanner (idempotent),
-- clôturer (pose le drapeau « non vu » doux sur les non-scannés du périmètre),
-- rapport vu/non-vu/inattendu, noter l'état. + trigger passif : un retour de
-- prêt rafraîchit last_seen et efface le drapeau « non vu » (D1/D2).
-- =====================================================================

-- ── Helper interne : exemplaires en périmètre d'une campagne ─────────
CREATE OR REPLACE FUNCTION public.fn_inventory_in_scope_exemplares(p_campaign_id bigint)
RETURNS TABLE(exemplar_id bigint) LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
  SELECT e.id
  FROM public.inventory_campaigns c
  JOIN public.exemplares e ON e.library_id = c.library_id
  WHERE c.id = p_campaign_id
    AND (c.scope_type <> 'location' OR e.shelf_location = c.scope_value);
$$;
ALTER FUNCTION public.fn_inventory_in_scope_exemplares(bigint) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_inventory_in_scope_exemplares(bigint) FROM PUBLIC, anon, authenticated, service_role;

-- ── 1. Lancer une campagne ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_inventory_start_campaign(
  p_library_id uuid, p_scope_type text DEFAULT 'all', p_scope_value text DEFAULT NULL, p_notes text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_actor uuid := auth.uid(); v_id bigint;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  IF NOT public.user_can_manage_library_notifications(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only active library staff can start a campaign';
  END IF;
  IF p_scope_type NOT IN ('all','location','collection') THEN RAISE EXCEPTION 'invalid scope_type'; END IF;
  INSERT INTO public.inventory_campaigns (library_id, scope_type, scope_value, status, started_by, notes)
  VALUES (p_library_id, p_scope_type, p_scope_value, 'open', v_actor, p_notes)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'campaign_id', v_id);
END $$;
ALTER FUNCTION public.fn_inventory_start_campaign(uuid, text, text, text) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_inventory_start_campaign(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_inventory_start_campaign(uuid, text, text, text) TO authenticated, service_role;

-- ── 2. Scanner un exemplaire (idempotent) ────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_inventory_record_scan(p_campaign_id bigint, p_exemplar_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_actor uuid := auth.uid(); v_lib uuid; v_cstatus text; v_ex_lib uuid; v_rows int;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  SELECT library_id, status INTO v_lib, v_cstatus FROM public.inventory_campaigns WHERE id = p_campaign_id;
  IF v_lib IS NULL THEN RAISE EXCEPTION 'not_found: campaign'; END IF;
  IF v_cstatus <> 'open' THEN RAISE EXCEPTION 'conflict: campaign not open'; END IF;
  IF NOT public.user_can_manage_library_notifications(v_lib) THEN RAISE EXCEPTION 'unauthorized: only staff can scan'; END IF;
  SELECT library_id INTO v_ex_lib FROM public.exemplares WHERE id = p_exemplar_id;
  IF v_ex_lib IS NULL THEN RAISE EXCEPTION 'not_found: exemplar'; END IF;
  IF v_ex_lib <> v_lib THEN RAISE EXCEPTION 'conflict: exemplar belongs to another library'; END IF;
  INSERT INTO public.inventory_scans (campaign_id, exemplar_id, scanned_by)
  VALUES (p_campaign_id, p_exemplar_id, v_actor)
  ON CONFLICT (campaign_id, exemplar_id) DO NOTHING;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  -- l'exemplaire est « vu » : rafraîchir last_seen + effacer le drapeau « non vu »
  UPDATE public.exemplares
    SET last_seen_at = now(), last_seen_via = 'inventory_scan',
        not_seen_flag = false, not_seen_at = NULL, not_seen_campaign_id = NULL
    WHERE id = p_exemplar_id;
  RETURN jsonb_build_object('ok', true, 'already_scanned', (v_rows = 0));
END $$;
ALTER FUNCTION public.fn_inventory_record_scan(bigint, bigint) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_inventory_record_scan(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_inventory_record_scan(bigint, bigint) TO authenticated, service_role;

-- ── 3. Clôturer une campagne (pose le drapeau « non vu » doux) ───────
CREATE OR REPLACE FUNCTION public.fn_inventory_close_campaign(p_campaign_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_actor uuid := auth.uid(); v_lib uuid; v_cstatus text; v_seen int; v_not_seen int;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  SELECT library_id, status INTO v_lib, v_cstatus FROM public.inventory_campaigns WHERE id = p_campaign_id;
  IF v_lib IS NULL THEN RAISE EXCEPTION 'not_found: campaign'; END IF;
  IF NOT public.user_can_manage_library_notifications(v_lib) THEN RAISE EXCEPTION 'unauthorized: only staff can close'; END IF;
  IF v_cstatus <> 'open' THEN RAISE EXCEPTION 'conflict: campaign already closed'; END IF;
  UPDATE public.exemplares e
    SET not_seen_flag = true, not_seen_at = now(), not_seen_campaign_id = p_campaign_id
    WHERE e.id IN (SELECT exemplar_id FROM public.fn_inventory_in_scope_exemplares(p_campaign_id))
      AND e.id NOT IN (SELECT exemplar_id FROM public.inventory_scans WHERE campaign_id = p_campaign_id);
  GET DIAGNOSTICS v_not_seen = ROW_COUNT;
  SELECT count(*) INTO v_seen FROM public.inventory_scans WHERE campaign_id = p_campaign_id;
  UPDATE public.inventory_campaigns SET status='closed', closed_at=now(), closed_by=v_actor WHERE id = p_campaign_id;
  RETURN jsonb_build_object('ok', true, 'seen', v_seen, 'not_seen', v_not_seen);
END $$;
ALTER FUNCTION public.fn_inventory_close_campaign(bigint) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_inventory_close_campaign(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_inventory_close_campaign(bigint) TO authenticated, service_role;

-- ── 4. Rapport de réconciliation ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_inventory_campaign_report(p_campaign_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_lib uuid; v_seen int; v_not_seen int; v_unexpected int;
BEGIN
  SELECT library_id INTO v_lib FROM public.inventory_campaigns WHERE id = p_campaign_id;
  IF v_lib IS NULL THEN RAISE EXCEPTION 'not_found: campaign'; END IF;
  IF NOT public.user_can_manage_library_notifications(v_lib) THEN RAISE EXCEPTION 'unauthorized'; END IF;
  SELECT count(*) INTO v_seen FROM public.inventory_scans WHERE campaign_id = p_campaign_id;
  SELECT count(*) INTO v_not_seen FROM public.fn_inventory_in_scope_exemplares(p_campaign_id) s
    WHERE s.exemplar_id NOT IN (SELECT exemplar_id FROM public.inventory_scans WHERE campaign_id = p_campaign_id);
  SELECT count(*) INTO v_unexpected FROM public.inventory_scans sc
    WHERE sc.campaign_id = p_campaign_id
      AND sc.exemplar_id NOT IN (SELECT exemplar_id FROM public.fn_inventory_in_scope_exemplares(p_campaign_id));
  RETURN jsonb_build_object('ok', true, 'seen', v_seen, 'not_seen', v_not_seen, 'unexpected', v_unexpected);
END $$;
ALTER FUNCTION public.fn_inventory_campaign_report(bigint) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_inventory_campaign_report(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_inventory_campaign_report(bigint) TO authenticated, service_role;

-- ── 5. Noter l'état d'un exemplaire (D3) ─────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_inventory_set_condition(p_exemplar_id bigint, p_condition text, p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_actor uuid := auth.uid(); v_lib uuid;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  IF p_condition NOT IN ('bom','a_reparar','a_encadernar','a_desbastar') THEN RAISE EXCEPTION 'invalid condition'; END IF;
  SELECT library_id INTO v_lib FROM public.exemplares WHERE id = p_exemplar_id;
  IF v_lib IS NULL THEN RAISE EXCEPTION 'not_found: exemplar'; END IF;
  IF NOT public.user_can_manage_library_notifications(v_lib) THEN RAISE EXCEPTION 'unauthorized: only staff'; END IF;
  UPDATE public.exemplares
    SET condition_status = p_condition, condition_note = p_note, condition_set_at = now(), condition_set_by = v_actor
    WHERE id = p_exemplar_id;
  RETURN jsonb_build_object('ok', true, 'condition', p_condition);
END $$;
ALTER FUNCTION public.fn_inventory_set_condition(bigint, text, text) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_inventory_set_condition(bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_inventory_set_condition(bigint, text, text) TO authenticated, service_role;

-- ── 6. Trigger passif : retour de prêt → l'exemplaire est « vu » ─────
CREATE OR REPLACE FUNCTION public.fn_inventory_touch_last_seen_on_return()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
BEGIN
  IF NEW.item_id IS NOT NULL AND NEW.item_status = 'devolvido' AND OLD.item_status IS DISTINCT FROM 'devolvido' THEN
    UPDATE public.exemplares
      SET last_seen_at = now(), last_seen_via = 'loan_return',
          not_seen_flag = false, not_seen_at = NULL, not_seen_campaign_id = NULL
      WHERE id = NEW.item_id;
  END IF;
  RETURN NEW;
END $$;
ALTER FUNCTION public.fn_inventory_touch_last_seen_on_return() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_inventory_touch_last_seen_on_return() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_inventory_touch_last_seen ON public.emprestimo_itens_v2;
CREATE TRIGGER trg_inventory_touch_last_seen
  AFTER UPDATE OF item_status ON public.emprestimo_itens_v2
  FOR EACH ROW EXECUTE FUNCTION public.fn_inventory_touch_last_seen_on_return();

NOTIFY pgrst, 'reload schema';
