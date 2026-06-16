-- ============================================================================
-- Thésaurus v3-A : relations associatives « voir aussi » (skos:related)
-- ----------------------------------------------------------------------------
-- Auteur  : AnarBib
-- Session : Fédération — Communs & Entraide
-- Date    : 2026-06-16 (UTC)
--
-- La hiérarchie broader/narrower existe déjà via subjects.parent_id. Cette
-- migration ajoute la dimension ASSOCIATIVE (skos:related) : une relation
-- symétrique « voir aussi » entre deux sujets actifs, stockée en UNE seule
-- ligne canonique (subject_id < related_subject_id) pour garantir la symétrie
-- et l'absence de doublon par construction.
--
-- Écriture : coordination catalogage uniquement (RPCs SECURITY DEFINER gardées
-- par public.fn_is_catalog_coordinator(), cohérent avec libellés/statut/notation).
-- Lecture : publique (OPAC « voir aussi »), filtrée aux sujets ativo.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.subject_relations (
  subject_id          bigint NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  related_subject_id  bigint NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  created_at          timestamptz NOT NULL DEFAULT now(),
  created_by          uuid DEFAULT auth.uid(),
  CONSTRAINT subject_relations_no_self   CHECK (subject_id <> related_subject_id),
  CONSTRAINT subject_relations_canonical CHECK (subject_id < related_subject_id),
  PRIMARY KEY (subject_id, related_subject_id)
);

ALTER TABLE public.subject_relations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS subject_relations_read ON public.subject_relations;
CREATE POLICY subject_relations_read ON public.subject_relations FOR SELECT USING (true);
-- Aucune policy INSERT/UPDATE/DELETE : les écritures passent EXCLUSIVEMENT par
-- les RPCs SECURITY DEFINER ci-dessous (garde coordination).

GRANT SELECT ON public.subject_relations TO anon, authenticated;

CREATE INDEX IF NOT EXISTS idx_subject_relations_related
  ON public.subject_relations(related_subject_id);

-- ── Ajout d'une relation (coordination) ─────────────────────────────────────
CREATE OR REPLACE FUNCTION api.fn_subject_add_relation(p_subject_id bigint, p_related_id bigint)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_catalog'
AS $function$
DECLARE a bigint; b bigint;
BEGIN
  IF NOT public.fn_is_catalog_coordinator() THEN
    RAISE EXCEPTION 'Réservé à la coordination catalogage' USING ERRCODE='insufficient_privilege';
  END IF;
  IF p_subject_id = p_related_id THEN
    RAISE EXCEPTION 'Un sujet ne peut être relié à lui-même' USING ERRCODE='check_violation';
  END IF;
  IF (SELECT count(*) FROM public.subjects WHERE id IN (p_subject_id,p_related_id) AND status='ativo') <> 2 THEN
    RAISE EXCEPTION 'Les deux sujets doivent exister et être actifs' USING ERRCODE='check_violation';
  END IF;
  a := least(p_subject_id,p_related_id);
  b := greatest(p_subject_id,p_related_id);
  INSERT INTO public.subject_relations(subject_id, related_subject_id, created_by)
    VALUES (a, b, auth.uid())
    ON CONFLICT DO NOTHING;
END $function$;

-- ── Retrait d'une relation (coordination) ───────────────────────────────────
CREATE OR REPLACE FUNCTION api.fn_subject_remove_relation(p_subject_id bigint, p_related_id bigint)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_catalog'
AS $function$
DECLARE a bigint; b bigint;
BEGIN
  IF NOT public.fn_is_catalog_coordinator() THEN
    RAISE EXCEPTION 'Réservé à la coordination catalogage' USING ERRCODE='insufficient_privilege';
  END IF;
  a := least(p_subject_id,p_related_id);
  b := greatest(p_subject_id,p_related_id);
  DELETE FROM public.subject_relations WHERE subject_id=a AND related_subject_id=b;
END $function$;

-- ── Lecture des sujets reliés (publique, ativo, bidirectionnelle) ───────────
CREATE OR REPLACE FUNCTION api.subject_related_v1(p_subject_id bigint)
RETURNS TABLE(id bigint, slug text, label_i18n jsonb, notation text)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_catalog' STABLE
AS $function$
  SELECT s.id, s.slug, s.label_i18n, s.notation
  FROM public.subject_relations r
  JOIN public.subjects s
    ON s.id = CASE WHEN r.subject_id = p_subject_id THEN r.related_subject_id ELSE r.subject_id END
  WHERE (r.subject_id = p_subject_id OR r.related_subject_id = p_subject_id)
    AND s.status = 'ativo'
  ORDER BY s.slug;
$function$;

REVOKE EXECUTE ON FUNCTION api.fn_subject_add_relation(bigint,bigint)    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api.fn_subject_remove_relation(bigint,bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api.subject_related_v1(bigint)                FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.fn_subject_add_relation(bigint,bigint)    TO authenticated;
GRANT  EXECUTE ON FUNCTION api.fn_subject_remove_relation(bigint,bigint) TO authenticated;
GRANT  EXECUTE ON FUNCTION api.subject_related_v1(bigint)                TO anon, authenticated;
