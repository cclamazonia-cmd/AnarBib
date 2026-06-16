-- ════════════════════════════════════════════════════════════════════════════
-- Thésaurus matière — v2 étape H-1 (backend) : RPC d'édition des libellés
-- Session : Fédération — Communs & Entraide
-- Cadrage : docs/journal/cadrages/CADRAGE_thesaurus_matiere_v2_2026-06-16.md (H-1)
--
-- Écrit pref (label_i18n) + synonymes (alt_i18n) + variantes (hidden_i18n) d'un
-- sujet. GATE : coordination catalogage seule (fn_is_catalog_coordinator) — pas
-- les contributeur·rices pour l'instant (élargissement = décision d'une AG réseau).
-- L'éditeur envoie l'ÉTAT COMPLET désiré (charge l'existant, fusionne, renvoie).
-- N'écrit pas `status` → ne déclenche pas le garde-fou trg_subjects_guard_status.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION api.fn_subject_update_labels(
  p_subject_id  bigint,
  p_label_i18n  jsonb,   -- {locale: "libellé pref"}
  p_alt_i18n    jsonb,   -- {locale: ["synonyme", ...]}
  p_hidden_i18n jsonb    -- {locale: ["variante de recherche", ...]}
) RETURNS public.subjects
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $function$
DECLARE r public.subjects;
BEGIN
  IF NOT public.fn_is_catalog_coordinator() THEN
    RAISE EXCEPTION 'Réservé à la coordination catalogage' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_label_i18n IS NULL OR jsonb_typeof(p_label_i18n) <> 'object' THEN
    RAISE EXCEPTION 'label_i18n doit être un objet {locale: texte}' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  IF p_alt_i18n IS NOT NULL AND jsonb_typeof(p_alt_i18n) <> 'object' THEN
    RAISE EXCEPTION 'alt_i18n doit être un objet {locale: [..]}' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  IF p_hidden_i18n IS NOT NULL AND jsonb_typeof(p_hidden_i18n) <> 'object' THEN
    RAISE EXCEPTION 'hidden_i18n doit être un objet {locale: [..]}' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  UPDATE public.subjects
    SET label_i18n  = p_label_i18n,
        alt_i18n    = COALESCE(p_alt_i18n, '{}'::jsonb),
        hidden_i18n = COALESCE(p_hidden_i18n, '{}'::jsonb),
        updated_by  = auth.uid(),
        updated_at  = now()
    WHERE id = p_subject_id
    RETURNING * INTO r;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sujet introuvable : %', p_subject_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN r;
END $function$;
REVOKE EXECUTE ON FUNCTION api.fn_subject_update_labels(bigint, jsonb, jsonb, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_subject_update_labels(bigint, jsonb, jsonb, jsonb) TO authenticated;

NOTIFY pgrst, 'reload schema';
