-- =====================================================================
-- ATELIER AUTORITÉS — Sous-paquet 1b : events & notifications
-- spec-atelier-autorites §6 ; dépend du paquet 1 (lots 1+2, 13/06).
-- =====================================================================
-- Couche events du cycle de vie des propositions d'autorité. Mécanique
-- notify-event existante, patron OUTBOX (durable + réconciliable, §6.1/§6.2) :
--   1) chaque RPC fn_authority_* insère UNE ligne d'outbox (1 event), puis
--      appelle notify-event avec record_id = id bigint de l'outbox ;
--   2) l'EF (handler handleAuthorityEvent) lit la ligne, résout les
--      destinataires (biblios utilisatrices + coord. atelier + proposeur) et
--      envoie les mails (fan-out côté EF, pattern E.1bis) ;
--   3) un cron de réconciliation re-dispatch les lignes restées non 'sent'.
--
-- 6 events (§6.3) : proposal_opened / proposal_objected / proposal_refused /
-- proposal_resolved_consent / merge_executed / edit_applied.
--
-- Anti-panoptique (INV-A3) : destinataires dérivés des données (biblios qui
-- détiennent un document lié à l'autorité), aucune vue agrégée d'usage.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1) Table outbox (calquée sur team_notification_outbox ; ATE-O4 -> dédiée)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.authority_proposal_notification_outbox (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event       text NOT NULL,
  payload     jsonb NOT NULL DEFAULT '{}'::jsonb,
  status      text NOT NULL DEFAULT 'queued',
  attempts    integer NOT NULL DEFAULT 0,
  last_error  text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  sent_at     timestamptz,
  CONSTRAINT authority_outbox_status_chk CHECK (status IN ('queued','sent','failed'))
);
-- Index pour le scan du cron de réconciliation (lignes non livrées).
CREATE INDEX IF NOT EXISTS idx_authority_outbox_pending
  ON public.authority_proposal_notification_outbox (created_at)
  WHERE status <> 'sent';

-- RLS : table d'infra interne. Aucune policy -> authenticated/anon n'y touchent ;
-- l'EF lit via service_role (bypass RLS) et les RPC écrivent via SECURITY DEFINER.
ALTER TABLE public.authority_proposal_notification_outbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.authority_proposal_notification_outbox FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.authority_proposal_notification_outbox IS
  'File d''événements de l''atelier autorités (sous-paquet 1b, spec §6.2). '
  '1 ligne par event ; record_id notify-event = id bigint. Calquée sur '
  'team_notification_outbox. status: queued -> sent (EF) / failed ; le cron '
  'fn_cron_reconcile_authority_dispatch re-dispatch les lignes non sent.';

-- ---------------------------------------------------------------------
-- 2) Helper d'émission : insère la ligne outbox + dispatch notify-event
-- ---------------------------------------------------------------------
-- Centralise le patron (1 INSERT + 1 dispatch) appelé par les RPC fn_authority_*.
-- SECURITY DEFINER : appelée depuis les RPC (eux-mêmes definer) ; non exposée.
CREATE OR REPLACE FUNCTION public.fn_authority_emit(p_event text, p_payload jsonb)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
DECLARE v_id bigint;
BEGIN
  INSERT INTO public.authority_proposal_notification_outbox (event, payload)
  VALUES (p_event, COALESCE(p_payload, '{}'::jsonb))
  RETURNING id INTO v_id;
  -- net.http_post fire-and-forget (transactionnel : rollback => non envoyé).
  PERFORM public.fn_dispatch_notify_event(p_event, v_id, '{}'::jsonb);
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_authority_emit(text, jsonb) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3) Helper résolution destinataires : biblios utilisatrices d'une autorité
-- ---------------------------------------------------------------------
-- Set-returning (ATE-1) : les biblios qui détiennent un document lié à
-- l'autorité. Utilisé par le handler EF (via rpc service_role) pour résoudre
-- les coordinateur·rices à notifier. Reprend la requête de fn_authority_object.
CREATE OR REPLACE FUNCTION public.fn_authority_using_libraries(p_target_kind text, p_target_id bigint)
RETURNS TABLE(library_id uuid) LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
  SELECT DISTINCT bh.library_id
  FROM public.book_holdings bh
  WHERE p_target_id IS NOT NULL AND (
        (p_target_kind = 'author'  AND bh.book_id IN (SELECT book_id FROM public.book_authors  WHERE author_id  = p_target_id))
     OR (p_target_kind = 'subject' AND bh.book_id IN (SELECT book_id FROM public.book_subjects WHERE subject_id = p_target_id))
  );
$$;
REVOKE ALL ON FUNCTION public.fn_authority_using_libraries(text, bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_authority_using_libraries(text, bigint) TO service_role;

-- ---------------------------------------------------------------------
-- 4) CREATE OR REPLACE des RPC du cycle de vie : ajout des émissions
--    (corps identiques au lot 2, + PERFORM fn_authority_emit aux transitions)
-- ---------------------------------------------------------------------

-- 4.1) PROPOSER -> authority.proposal_opened
CREATE OR REPLACE FUNCTION api.fn_authority_propose(
  p_kind text, p_target_kind text, p_target_id bigint,
  p_merge_into_id bigint, p_payload jsonb, p_rationale text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
DECLARE v_id uuid; v_deadline timestamptz;
BEGIN
  IF NOT (public.fn_caller_is_network_contributor() OR public.fn_caller_is_staff()) THEN
    RAISE EXCEPTION 'forbidden' USING HINT = 'atelier.error.notContributor';
  END IF;
  IF p_kind NOT IN ('creation','edition','fusion','traduction') THEN RAISE EXCEPTION 'bad_kind'; END IF;
  IF p_target_kind NOT IN ('author','subject') THEN RAISE EXCEPTION 'bad_target_kind'; END IF;

  IF p_kind = 'creation' THEN
    IF p_target_id IS NOT NULL THEN RAISE EXCEPTION 'creation_has_target'; END IF;
  ELSE
    IF p_target_id IS NULL THEN RAISE EXCEPTION 'missing_target'; END IF;
    IF p_target_kind = 'author'  AND NOT EXISTS (SELECT 1 FROM public.authors  WHERE id = p_target_id) THEN RAISE EXCEPTION 'target_not_found'; END IF;
    IF p_target_kind = 'subject' AND NOT EXISTS (SELECT 1 FROM public.subjects WHERE id = p_target_id) THEN RAISE EXCEPTION 'target_not_found'; END IF;
  END IF;

  IF p_kind = 'fusion' THEN
    IF p_merge_into_id IS NULL OR p_merge_into_id = p_target_id THEN RAISE EXCEPTION 'bad_merge_target'; END IF;
    IF p_target_kind = 'author'  AND NOT EXISTS (SELECT 1 FROM public.authors  WHERE id = p_merge_into_id) THEN RAISE EXCEPTION 'canonical_not_found'; END IF;
    IF p_target_kind = 'subject' AND NOT EXISTS (SELECT 1 FROM public.subjects WHERE id = p_merge_into_id) THEN RAISE EXCEPTION 'canonical_not_found'; END IF;
  ELSIF p_merge_into_id IS NOT NULL THEN
    RAISE EXCEPTION 'merge_target_only_for_fusion';
  END IF;

  v_deadline := now() + CASE WHEN p_kind = 'fusion' THEN interval '14 days' ELSE interval '7 days' END;

  INSERT INTO public.authority_proposals (kind, target_kind, target_id, merge_into_id, payload, rationale, deadline, proposed_by)
  VALUES (p_kind, p_target_kind, p_target_id, p_merge_into_id, COALESCE(p_payload, '{}'::jsonb), p_rationale, v_deadline, auth.uid())
  RETURNING id INTO v_id;

  -- 1b : proposition ouverte -> biblios utilisatrices + coord. atelier.
  PERFORM public.fn_authority_emit('authority.proposal_opened', jsonb_build_object(
    'proposal_id', v_id, 'kind', p_kind, 'target_kind', p_target_kind,
    'target_id', p_target_id, 'merge_into_id', p_merge_into_id, 'proposed_by', auth.uid()));
  RETURN v_id;
END;
$$;

-- 4.2) OBJECTER -> authority.proposal_objected (+ proposal_refused si refus)
CREATE OR REPLACE FUNCTION api.fn_authority_object(p_proposal_id uuid, p_library_id uuid, p_reason text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
DECLARE v_p public.authority_proposals; n_obj int; n_users int; v_new_status text;
BEGIN
  SELECT * INTO v_p FROM public.authority_proposals WHERE id = p_proposal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'proposal_not_found'; END IF;
  IF v_p.status NOT IN ('open','contested') THEN RAISE EXCEPTION 'proposal_closed'; END IF;

  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'forbidden' USING HINT = 'atelier.error.notCoordenador';
  END IF;
  IF v_p.target_id IS NOT NULL AND NOT public.fn_library_uses_authority(p_library_id, v_p.target_kind, v_p.target_id) THEN
    RAISE EXCEPTION 'library_not_concerned' USING HINT = 'atelier.error.notUsingAuthority';
  END IF;
  IF char_length(btrim(coalesce(p_reason,''))) < 20 THEN RAISE EXCEPTION 'reason_too_short'; END IF;

  INSERT INTO public.authority_proposal_objections (proposal_id, objecting_library_id, objecting_by, reason)
  VALUES (p_proposal_id, p_library_id, auth.uid(), p_reason);

  SELECT count(DISTINCT objecting_library_id) INTO n_obj
    FROM public.authority_proposal_objections WHERE proposal_id = p_proposal_id;
  IF v_p.target_id IS NULL THEN
    n_users := 99;
  ELSE
    SELECT count(*) INTO n_users FROM (
      SELECT DISTINCT bh.library_id
      FROM public.book_holdings bh
      WHERE (v_p.target_kind='author'  AND bh.book_id IN (SELECT book_id FROM public.book_authors  WHERE author_id  = v_p.target_id))
         OR (v_p.target_kind='subject' AND bh.book_id IN (SELECT book_id FROM public.book_subjects WHERE subject_id = v_p.target_id))
    ) u;
  END IF;

  IF n_obj >= 2 OR (n_users <= 2 AND n_obj >= 1) THEN v_new_status := 'refused';
  ELSE v_new_status := 'contested'; END IF;

  UPDATE public.authority_proposals
     SET status = v_new_status,
         resolved_at = CASE WHEN v_new_status='refused' THEN now() ELSE resolved_at END,
         updated_at = now()
   WHERE id = p_proposal_id;

  -- 1b : objection déposée -> proposeur + autres biblios utilisatrices.
  PERFORM public.fn_authority_emit('authority.proposal_objected', jsonb_build_object(
    'proposal_id', p_proposal_id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
    'target_id', v_p.target_id, 'proposed_by', v_p.proposed_by,
    'objecting_library_id', p_library_id, 'objecting_by', auth.uid(),
    'reason', p_reason, 'new_status', v_new_status));
  -- 1b : refus (>=2 biblios, ou 1 si <=2 utilisatrices) -> proposeur (motivé).
  IF v_new_status = 'refused' THEN
    PERFORM public.fn_authority_emit('authority.proposal_refused', jsonb_build_object(
      'proposal_id', p_proposal_id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
      'target_id', v_p.target_id, 'proposed_by', v_p.proposed_by));
  END IF;
  RETURN v_new_status;
END;
$$;

-- 4.3) RÉSOUDRE LES ÉCHUES (cron) -> authority.proposal_resolved_consent / ligne
CREATE OR REPLACE FUNCTION api.fn_authority_resolve_due()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
DECLARE n int := 0; r record;
BEGIN
  FOR r IN
    WITH due AS (
      UPDATE public.authority_proposals p
         SET status='resolved_consent', resolved_at=now(), updated_at=now()
       WHERE p.status='open' AND p.deadline <= now()
         AND NOT EXISTS (SELECT 1 FROM public.authority_proposal_objections o WHERE o.proposal_id = p.id)
      RETURNING p.id, p.kind, p.target_kind, p.target_id, p.merge_into_id, p.proposed_by)
    SELECT * FROM due
  LOOP
    n := n + 1;
    -- 1b : consentement atteint (échéance sans objection) -> proposeur + biblios.
    PERFORM public.fn_authority_emit('authority.proposal_resolved_consent', jsonb_build_object(
      'proposal_id', r.id, 'kind', r.kind, 'target_kind', r.target_kind,
      'target_id', r.target_id, 'merge_into_id', r.merge_into_id, 'proposed_by', r.proposed_by));
  END LOOP;
  RETURN n;
END;
$$;
REVOKE EXECUTE ON FUNCTION api.fn_authority_resolve_due() FROM PUBLIC, anon;

-- 4.4) APPLIQUER (staff) -> authority.merge_executed (fusion) / edit_applied (édition)
CREATE OR REPLACE FUNCTION api.fn_authority_apply(p_proposal_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
DECLARE v_p public.authority_proposals; v_f jsonb;
BEGIN
  IF NOT public.fn_caller_is_staff() THEN
    RAISE EXCEPTION 'forbidden' USING HINT = 'atelier.error.notStaff';
  END IF;
  SELECT * INTO v_p FROM public.authority_proposals WHERE id = p_proposal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'proposal_not_found'; END IF;
  IF v_p.status <> 'resolved_consent' THEN RAISE EXCEPTION 'not_ready' USING HINT = 'atelier.error.notResolvedConsent'; END IF;

  IF v_p.kind = 'fusion' THEN
    IF v_p.target_kind='author'  THEN PERFORM public.merge_author(v_p.merge_into_id, v_p.target_id);
    ELSIF v_p.target_kind='subject' THEN PERFORM public.merge_subject(v_p.merge_into_id, v_p.target_id);
    END IF;

  ELSIF v_p.kind = 'edition' THEN
    v_f := COALESCE(v_p.payload->'fields', '{}'::jsonb);
    IF v_p.target_kind='author' THEN
      UPDATE public.authors SET
        preferred_name  = COALESCE(v_f->>'preferred_name', preferred_name),
        sort_name       = COALESCE(v_f->>'sort_name', sort_name),
        biography       = COALESCE(v_f->>'biography', biography),
        birth_year      = COALESCE((v_f->>'birth_year')::int, birth_year),
        death_year      = COALESCE((v_f->>'death_year')::int, death_year),
        country         = COALESCE(v_f->>'country', country),
        viaf_id         = COALESCE(v_f->>'viaf_id', viaf_id),
        isni            = COALESCE(v_f->>'isni', isni),
        wikidata_id     = COALESCE(v_f->>'wikidata_id', wikidata_id),
        notes           = COALESCE(v_f->>'notes', notes),
        structured_meta = COALESCE(v_f->'structured_meta', structured_meta),
        variant_forms   = COALESCE(v_f->'variant_forms', variant_forms),
        updated_at = now(), updated_by = auth.uid()
      WHERE id = v_p.target_id;
    ELSIF v_p.target_kind='subject' THEN
      UPDATE public.subjects SET
        label_i18n = COALESCE(v_f->'label_i18n', label_i18n),
        scope_note = COALESCE(v_f->>'scope_note', scope_note),
        parent_id  = COALESCE((v_f->>'parent_id')::bigint, parent_id),
        updated_at = now(), updated_by = auth.uid()
      WHERE id = v_p.target_id;
    END IF;

  ELSE
    RAISE EXCEPTION 'apply_kind_not_implemented' USING HINT = 'atelier.error.applyKindDeferred';
  END IF;

  UPDATE public.authority_proposals SET status='applied', applied_at=now(), updated_at=now() WHERE id=p_proposal_id;

  -- 1b : écriture corpus appliquée -> biblios utilisatrices.
  IF v_p.kind = 'fusion' THEN
    PERFORM public.fn_authority_emit('authority.merge_executed', jsonb_build_object(
      'proposal_id', v_p.id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
      'target_id', v_p.target_id, 'merge_into_id', v_p.merge_into_id, 'proposed_by', v_p.proposed_by));
  ELSE
    PERFORM public.fn_authority_emit('authority.edit_applied', jsonb_build_object(
      'proposal_id', v_p.id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
      'target_id', v_p.target_id, 'proposed_by', v_p.proposed_by));
  END IF;
  RETURN 'applied';
END;
$$;

-- ---------------------------------------------------------------------
-- 5) Cron de réconciliation (modèle reconcile-task-dispatch)
-- ---------------------------------------------------------------------
-- Re-dispatch les lignes restées non 'sent' (dispatch http_post perdu, ou EF en
-- échec) au-delà de 10 min, plafonné à 5 tentatives. À chaque passage, l'EF
-- ré-exécute handleAuthorityEvent qui marque 'sent' au succès.
CREATE OR REPLACE FUNCTION public.fn_cron_reconcile_authority_dispatch(p_limit integer DEFAULT 200)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE n int := 0; r record;
BEGIN
  FOR r IN
    SELECT id, event
    FROM public.authority_proposal_notification_outbox
    WHERE status <> 'sent'
      AND attempts < 5
      AND created_at < now() - interval '10 minutes'
    ORDER BY id
    LIMIT p_limit
  LOOP
    UPDATE public.authority_proposal_notification_outbox
       SET attempts = attempts + 1 WHERE id = r.id;
    PERFORM public.fn_dispatch_notify_event(r.event, r.id, '{}'::jsonb);
    n := n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'redispatched', n);
END;
$$;
REVOKE ALL ON FUNCTION public.fn_cron_reconcile_authority_dispatch(integer)
  FROM PUBLIC, anon, authenticated, service_role;

SELECT cron.schedule(
  'reconcile-authority-dispatch',
  '*/5 * * * *',
  $cron$ SELECT public.fn_cron_reconcile_authority_dispatch(); $cron$
);

-- ---------------------------------------------------------------------
-- 6) Vérification automatique (auto-rollback si échec)
-- ---------------------------------------------------------------------
DO $chk$
DECLARE has_tbl boolean; n_fn int; has_cron boolean;
BEGIN
  SELECT to_regclass('public.authority_proposal_notification_outbox') IS NOT NULL INTO has_tbl;
  IF NOT has_tbl THEN RAISE EXCEPTION 'Echec : table outbox absente'; END IF;

  SELECT count(*) INTO n_fn FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE (ns.nspname='public' AND p.proname IN ('fn_authority_emit','fn_authority_using_libraries','fn_cron_reconcile_authority_dispatch'));
  IF n_fn < 3 THEN RAISE EXCEPTION 'Echec : helpers 1b manquants (% trouvés sur 3)', n_fn; END IF;

  SELECT EXISTS(SELECT 1 FROM cron.job WHERE jobname='reconcile-authority-dispatch') INTO has_cron;
  IF NOT has_cron THEN RAISE EXCEPTION 'Echec : cron reconcile-authority-dispatch absent'; END IF;

  RAISE NOTICE 'Migration 1b events : verification OK (outbox + 3 helpers + cron).';
END $chk$;

COMMIT;
