-- =====================================================================
-- ATELIER AUTORITÉS — Paquet 2 : application des propositions de TRADUCTION
-- =====================================================================
-- fn_authority_apply gère désormais kind='traduction' → UPSERT dans
-- author_translations (bio multilingue d'une autorité PERSONNE ; langue ∈ 10
-- locales via le CHECK existant ; status 'reviewed' car consenti). C'est le
-- « champ caché par langue » : silence = consentement (FED-O5), puis écriture
-- discrète de la bio dans la langue concernée. Fusion + édition inchangées ;
-- création toujours différée.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION api.fn_authority_apply(p_proposal_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
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

  ELSIF v_p.kind = 'traduction' THEN
    -- Bio multilingue d'une autorité PERSONNE (author_translations). La traduction
    -- des matières (subjects) passe par label_i18n = édition, pas traduction.
    IF v_p.target_kind <> 'author' THEN RAISE EXCEPTION 'traduction_author_only'; END IF;
    v_f := COALESCE(v_p.payload, '{}'::jsonb);
    IF NULLIF(btrim(coalesce(v_f->>'lang','')), '') IS NULL
       OR NULLIF(btrim(coalesce(v_f->>'biography','')), '') IS NULL THEN
      RAISE EXCEPTION 'traduction_missing_fields';
    END IF;
    INSERT INTO public.author_translations (author_id, lang, biography, status, created_by, updated_by)
    VALUES (v_p.target_id, v_f->>'lang', v_f->>'biography', 'reviewed', auth.uid(), auth.uid())
    ON CONFLICT (author_id, lang) DO UPDATE SET
      biography  = EXCLUDED.biography,
      status     = 'reviewed',
      updated_at = now(),
      updated_by = auth.uid();

  ELSE
    -- création : apply différé (lot ultérieur ; passer par catalogação)
    RAISE EXCEPTION 'apply_kind_not_implemented' USING HINT = 'atelier.error.applyKindDeferred';
  END IF;

  UPDATE public.authority_proposals SET status='applied', applied_at=now(), updated_at=now() WHERE id=p_proposal_id;
  RETURN 'applied';
END;
$function$;

COMMIT;
