-- =====================================================================
-- ATELIER AUTORITÉS — Paquet 1, lot 2 : RPC + cron (voie B validée)
-- spec-atelier-autorites §4/§5 ; REGISTRE §28 (ATE-1..4, ATE-O2)
-- =====================================================================
-- Validé sur lot1+lot2 en BEGIN/ROLLBACK contre la prod le 13/06 (zéro persistance, cron compris).
-- Dépend du lot 1 (tables network_contributors / authority_proposals / _objections).
--
-- Voie B (tranchée) : le consentement (échéance sans objection) est AUTO
-- (fn_authority_resolve_due -> resolved_consent) ; l'écriture irréversible dans
-- le corpus est CONFIRMÉE par un·e staff (fn_authority_apply, contexte staff ->
-- merge_author/merge_subject CAT-H1 utilisables tels quels, garde respectée).
-- Périmètre apply lot 2 : FUSION (merge_*) + ÉDITION (authors/subjects).
-- Création/traduction : lodgeables, apply différé (message explicite).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- Helper : la biblio détient-elle un document lié à l'autorité ? (ATE-1)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_library_uses_authority(p_library_id uuid, p_target_kind text, p_target_id bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
  SELECT CASE p_target_kind
    WHEN 'author' THEN EXISTS (
      SELECT 1 FROM public.book_authors ba
      JOIN public.book_holdings bh ON bh.book_id = ba.book_id
      WHERE ba.author_id = p_target_id AND bh.library_id = p_library_id)
    WHEN 'subject' THEN EXISTS (
      SELECT 1 FROM public.book_subjects bs
      JOIN public.book_holdings bh ON bh.book_id = bs.book_id
      WHERE bs.subject_id = p_target_id AND bh.library_id = p_library_id)
    ELSE false
  END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_library_uses_authority(uuid, text, bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_library_uses_authority(uuid, text, bigint) TO authenticated;

-- ---------------------------------------------------------------------
-- 1) PROPOSER (contributeur OU staff) — ATE-3
-- ---------------------------------------------------------------------
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

  -- ATE-O2 : fenêtre opt-out modulée par l'impact.
  v_deadline := now() + CASE WHEN p_kind = 'fusion' THEN interval '14 days' ELSE interval '7 days' END;

  INSERT INTO public.authority_proposals (kind, target_kind, target_id, merge_into_id, payload, rationale, deadline, proposed_by)
  VALUES (p_kind, p_target_kind, p_target_id, p_merge_into_id, COALESCE(p_payload, '{}'::jsonb), p_rationale, v_deadline, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION api.fn_authority_propose(text, text, bigint, bigint, jsonb, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION api.fn_authority_propose(text, text, bigint, bigint, jsonb, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 2) OBJECTER (coordenador d'une biblio UTILISATRICE) — ATE-1/ATE-3 + FED-O5
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_authority_object(p_proposal_id uuid, p_library_id uuid, p_reason text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
DECLARE v_p public.authority_proposals; n_obj int; n_users int; v_new_status text;
BEGIN
  SELECT * INTO v_p FROM public.authority_proposals WHERE id = p_proposal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'proposal_not_found'; END IF;
  IF v_p.status NOT IN ('open','contested') THEN RAISE EXCEPTION 'proposal_closed'; END IF;

  -- agir = coordenador de la biblio (FED-4), et la biblio doit être utilisatrice (ATE-1)
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'forbidden' USING HINT = 'atelier.error.notCoordenador';
  END IF;
  IF v_p.target_id IS NOT NULL AND NOT public.fn_library_uses_authority(p_library_id, v_p.target_kind, v_p.target_id) THEN
    RAISE EXCEPTION 'library_not_concerned' USING HINT = 'atelier.error.notUsingAuthority';
  END IF;
  IF char_length(btrim(coalesce(p_reason,''))) < 20 THEN RAISE EXCEPTION 'reason_too_short'; END IF;

  INSERT INTO public.authority_proposal_objections (proposal_id, objecting_library_id, objecting_by, reason)
  VALUES (p_proposal_id, p_library_id, auth.uid(), p_reason);  -- UNIQUE -> lève si déjà objecté

  -- FED-O5 anti-blackball : refus si >=2 biblios distinctes (ou 1 si <=2 utilisatrices)
  SELECT count(DISTINCT objecting_library_id) INTO n_obj
    FROM public.authority_proposal_objections WHERE proposal_id = p_proposal_id;
  IF v_p.target_id IS NULL THEN
    n_users := 99;  -- création : pas de biblio utilisatrice -> régime standard (>=2)
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
  RETURN v_new_status;
END;
$$;
REVOKE EXECUTE ON FUNCTION api.fn_authority_object(uuid, uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION api.fn_authority_object(uuid, uuid, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 3) RETIRER sa proposition (le proposeur)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_authority_withdraw(p_proposal_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
DECLARE v_p public.authority_proposals;
BEGIN
  SELECT * INTO v_p FROM public.authority_proposals WHERE id = p_proposal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'proposal_not_found'; END IF;
  IF v_p.proposed_by <> auth.uid() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF v_p.status NOT IN ('open','contested') THEN RAISE EXCEPTION 'proposal_closed'; END IF;
  UPDATE public.authority_proposals SET status='withdrawn', resolved_at=now(), updated_at=now() WHERE id=p_proposal_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION api.fn_authority_withdraw(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION api.fn_authority_withdraw(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- 4) RÉSOUDRE LES ÉCHUES (cron, idempotent) — consentement opt-out, voie B
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_authority_resolve_due()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
DECLARE n int;
BEGIN
  WITH due AS (
    UPDATE public.authority_proposals p
       SET status='resolved_consent', resolved_at=now(), updated_at=now()
     WHERE p.status='open' AND p.deadline <= now()
       AND NOT EXISTS (SELECT 1 FROM public.authority_proposal_objections o WHERE o.proposal_id = p.id)
    RETURNING 1)
  SELECT count(*) INTO n FROM due;
  RETURN n;
END;
$$;
REVOKE EXECUTE ON FUNCTION api.fn_authority_resolve_due() FROM PUBLIC, anon;
-- cron uniquement : pas de grant authenticated.

-- ---------------------------------------------------------------------
-- 5) APPLIQUER une proposition consentie (staff) — voie B, écriture corpus
-- ---------------------------------------------------------------------
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
    -- création / traduction : apply différé (lot ultérieur ; passer par catalogação)
    RAISE EXCEPTION 'apply_kind_not_implemented' USING HINT = 'atelier.error.applyKindDeferred';
  END IF;

  UPDATE public.authority_proposals SET status='applied', applied_at=now(), updated_at=now() WHERE id=p_proposal_id;
  RETURN 'applied';
END;
$$;
REVOKE EXECUTE ON FUNCTION api.fn_authority_apply(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION api.fn_authority_apply(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- 6) Cron quotidien (calqué sur anarbib-circle-resolve-due-daily)
-- ---------------------------------------------------------------------
SELECT cron.schedule('anarbib-authority-resolve-due-daily', '45 3 * * *', $cron$ SELECT api.fn_authority_resolve_due(); $cron$);

COMMIT;
