-- =====================================================================
-- ATE-O3 — Primitif de fusion/dédoublonnage des MATIÈRES (subjects)
-- REGISTRE §28 ATE-O3 (tranché 13/06/2026). Instruit FED-O7 / spec-atelier-autorites.
-- =====================================================================
-- Constat (prod vérifiée 13/06) : les « tables collectivité/matière » que
-- spec-notice §2.3 / ATE-O3 croyaient à créer EXISTENT déjà —
--   • collectivité = public.authors + structured_meta->>'authorityType'='collective'
--                    (gouvernée via le flux AUTEURS : merge_author la couvre déjà) ;
--   • matière      = public.subjects (slug UNIQUE, label_i18n, parent_id, scope_note)
--                    + book_subjects / book_draft_subjects.
-- Le vrai gap : subjects n'a pas le primitif de fusion que CAT-H1 donne aux
-- personnes/œuvres. Ce script l'ajoute (merge_subject + suggest_subject_duplicates)
-- et étend merge_log (déjà générique sauf le CHECK entity_type).
-- Validé en BEGIN/ROLLBACK contre la prod le 13/06 (aucune persistance).
-- =====================================================================

BEGIN;

-- 0) merge_log : autoriser entity_type='subject' (CHECK = author|book|book_draft).
ALTER TABLE public.merge_log DROP CONSTRAINT merge_log_entity_type_check;
ALTER TABLE public.merge_log ADD  CONSTRAINT merge_log_entity_type_check
  CHECK (entity_type = ANY (ARRAY['author','book','book_draft','subject']));

-- 1) FUSION ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.merge_subject(p_canonical_id bigint, p_duplicate_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_dup_slug  text;
  v_dup_label jsonb;
  v_dup_scope text;
BEGIN
  -- Garde staff (identique à merge_author).
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  IF p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Canonico e duplicado identicos.';
  END IF;

  SELECT slug, label_i18n, scope_note
    INTO v_dup_slug, v_dup_label, v_dup_scope
    FROM public.subjects WHERE id = p_duplicate_id;
  IF v_dup_slug IS NULL THEN
    RAISE EXCEPTION 'Duplicado % inexistente.', p_duplicate_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.subjects WHERE id = p_canonical_id) THEN
    RAISE EXCEPTION 'Canonico % inexistente.', p_canonical_id;
  END IF;

  -- 1. Liens livres publiés : repoint + dedupe (PK book_id, subject_id).
  INSERT INTO public.book_subjects (book_id, subject_id, ord, created_at)
    SELECT book_id, p_canonical_id, ord, created_at
    FROM public.book_subjects WHERE subject_id = p_duplicate_id
  ON CONFLICT (book_id, subject_id) DO NOTHING;
  DELETE FROM public.book_subjects WHERE subject_id = p_duplicate_id;

  -- 2. Liens brouillons : repoint + dedupe (PK book_draft_id, subject_id).
  INSERT INTO public.book_draft_subjects (book_draft_id, subject_id, ord)
    SELECT book_draft_id, p_canonical_id, ord
    FROM public.book_draft_subjects WHERE subject_id = p_duplicate_id
  ON CONFLICT (book_draft_id, subject_id) DO NOTHING;
  DELETE FROM public.book_draft_subjects WHERE subject_id = p_duplicate_id;

  -- 3. Hiérarchie : les enfants du doublon passent sous le canonique
  --    (jamais se rendre soi-même parent).
  UPDATE public.subjects SET parent_id = p_canonical_id
    WHERE parent_id = p_duplicate_id AND id <> p_canonical_id;
  -- Si le canonique avait le doublon pour parent, remonter au grand-parent.
  UPDATE public.subjects c
     SET parent_id = (SELECT parent_id FROM public.subjects WHERE id = p_duplicate_id)
   WHERE c.id = p_canonical_id AND c.parent_id = p_duplicate_id;

  -- 4. Métadonnée : compléter les langues absentes du canonique (le canonique
  --    gagne sur conflit, via ||) + scope_note si le canonique n'en a pas.
  UPDATE public.subjects c
     SET label_i18n = v_dup_label || c.label_i18n,
         scope_note = COALESCE(c.scope_note, v_dup_scope),
         updated_at = now(),
         updated_by = auth.uid()
   WHERE c.id = p_canonical_id;

  -- 5. Journaliser (merge_log générique, entity_type='subject').
  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('subject', p_canonical_id, p_duplicate_id,
          jsonb_build_object('duplicate_slug', v_dup_slug), auth.uid());

  -- 6. Supprimer le doublon (liens déjà repointés ; enfants déjà reparentés).
  DELETE FROM public.subjects WHERE id = p_duplicate_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.merge_subject(bigint, bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.merge_subject(bigint, bigint) TO authenticated;
COMMENT ON FUNCTION public.merge_subject(bigint, bigint) IS
  'ATE-O3 : fusion de doublons de matières (subjects). Repointe book_subjects/book_draft_subjects (dedupe ON CONFLICT), reparent la hiérarchie, complète label_i18n/scope_note (canonique prioritaire), journalise merge_log (entity_type=subject), supprime le doublon. Garde staff interne (librarian/coordenador). Calqué sur merge_author (CAT-H1). Exécution d''une proposition de fusion acceptée (ATE-3).';

-- 2) DÉTECTION ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.suggest_subject_duplicates(p_subject_id bigint)
RETURNS TABLE(subject_id bigint, slug text, label text, linked_books integer, match_kind text, score real)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
DECLARE
  v_forms text[];
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  -- Formes du sujet cible = slug + toutes les valeurs label_i18n, normalisées.
  SELECT array_agg(DISTINCT nf) INTO v_forms
  FROM (
    SELECT public.fn_normalize_name(s.slug) AS nf FROM public.subjects s WHERE s.id = p_subject_id
    UNION
    SELECT public.fn_normalize_name(lbl.value)
      FROM public.subjects s, LATERAL jsonb_each_text(s.label_i18n) lbl(key, value)
     WHERE s.id = p_subject_id
  ) x
  WHERE x.nf <> '';

  IF v_forms IS NULL OR array_length(v_forms, 1) IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH other AS (
    SELECT s.id,
           s.slug,
           COALESCE(s.label_i18n->>'pt-BR', s.label_i18n->>'fr', s.slug) AS lbl,
           ARRAY(
             SELECT public.fn_normalize_name(v)
             FROM ( SELECT s.slug AS v
                    UNION SELECT le.value FROM jsonb_each_text(s.label_i18n) le(key, value) ) y
             WHERE public.fn_normalize_name(v) <> ''
           ) AS forms
    FROM public.subjects s
    WHERE s.id <> p_subject_id
  )
  SELECT o.id, o.slug, o.lbl,
         (SELECT count(*)::integer FROM public.book_subjects bs WHERE bs.subject_id = o.id),
         CASE WHEN EXISTS (SELECT 1 FROM unnest(o.forms) f WHERE f = ANY (v_forms)) THEN 'exact' ELSE 'approx' END,
         CASE WHEN EXISTS (SELECT 1 FROM unnest(o.forms) f WHERE f = ANY (v_forms)) THEN 1.0::real
              ELSE (SELECT max(similarity(f, g)) FROM unnest(o.forms) f, unnest(v_forms) g) END
  FROM other o
  WHERE array_length(o.forms, 1) IS NOT NULL
    AND ( EXISTS (SELECT 1 FROM unnest(o.forms) f WHERE f = ANY (v_forms))
          -- seuil durci vs auteurs (0.45) : les slugs de matière partagent des morphèmes.
          OR (SELECT max(similarity(f, g)) FROM unnest(o.forms) f, unnest(v_forms) g) >= 0.60 )
  ORDER BY 6 DESC NULLS LAST, o.slug;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.suggest_subject_duplicates(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.suggest_subject_duplicates(bigint) TO authenticated;
COMMENT ON FUNCTION public.suggest_subject_duplicates(bigint) IS
  'ATE-O3 : suggère les doublons probables d''une matière (subjects) par slug + valeurs label_i18n normalisées (fn_normalize_name), exact ou approx (pg_trgm similarity >= 0.60 — seuil durci vs auteurs 0.45 car les slugs de matière partagent des morphèmes). Garde staff interne. Calqué sur suggest_author_duplicates.';

COMMIT;

-- Rollback manuel (si besoin) :
--   DROP FUNCTION IF EXISTS public.merge_subject(bigint, bigint);
--   DROP FUNCTION IF EXISTS public.suggest_subject_duplicates(bigint);
--   ALTER TABLE public.merge_log DROP CONSTRAINT merge_log_entity_type_check;
--   ALTER TABLE public.merge_log ADD CONSTRAINT merge_log_entity_type_check
--     CHECK (entity_type = ANY (ARRAY['author','book','book_draft']));
