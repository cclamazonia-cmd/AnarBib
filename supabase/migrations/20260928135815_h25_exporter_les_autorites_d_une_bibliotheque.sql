-- =============================================================================
-- H25 — Exporter les autorités d'une bibliothèque (UNIMARC Autorités), pour que
-- les liens $3 de l'export bibliographique (H24) mènent quelque part
--
-- public.fn_export_authorities_lote(p_library_id) : les fiches d'autorité liées
-- aux notices que la bibliothèque détient — personnes, collectivités, congrès
-- (book_contributors.author_id) et sujets du thésaurus (book_subjects), avec
-- les ancêtres de ces sujets pour que les renvois génériques (550 $5 g)
-- mènent eux aussi quelque part. Même garde que fn_export_catalog_lote :
-- coordination de la bibliothèque, ou administration du réseau.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_export_authorities_lote(p_library_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_authorized boolean;
  v_library    jsonb;
  v_locale     text;
  v_auteurs    jsonb;
  v_sujets     jsonb;
BEGIN
  IF p_library_id IS NULL THEN
    RAISE EXCEPTION 'library_id obrigatorio.';
  END IF;

  -- IMP-14 : reservé au coordenador de la bibliothèque (ou à l'admin réseau).
  SELECT (
    EXISTS (
      SELECT 1 FROM public.user_library_memberships m
      WHERE m.user_id   = auth.uid()
        AND m.library_id = p_library_id
        AND m.status     = 'active'
        AND m.role       = 'coordenador'
    )
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;

  IF NOT v_authorized THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT jsonb_build_object('id', l.id, 'slug', l.slug, 'name', l.name, 'short_name', l.short_name,
                            'country', l.country, 'default_locale', l.default_locale),
         coalesce(l.default_locale, 'pt-BR')
    INTO v_library, v_locale
    FROM public.libraries l WHERE l.id = p_library_id;

  -- Personnes, collectivités, congrès liés aux notices détenues. Les formes
  -- rejetées : variant_forms est un tableau de {form, source} (fusions) ou un
  -- objet {langue: [formes]} (relevés Wikidata) — les deux donnent des formes.
  WITH livres AS (
    SELECT DISTINCT h.book_id FROM public.book_holdings h WHERE h.library_id = p_library_id
  ), ids AS (
    SELECT DISTINCT bc.author_id FROM public.book_contributors bc
      JOIN livres l ON l.book_id = bc.book_id
     WHERE bc.author_id IS NOT NULL
  )
  SELECT coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'id', a.id,
           'type', coalesce(a.authority_type, 'person'),
           'preferredName', a.preferred_name,
           'sortName', a.sort_name,
           'birthYear', a.birth_year, 'deathYear', a.death_year,
           'activityPeriod', a.activity_period,
           'country', a.country, 'nameLang', a.name_lang,
           'variants', (
             SELECT jsonb_agg(DISTINCT v) FROM (
               SELECT btrim(e->>'form') AS v FROM jsonb_array_elements(
                 CASE WHEN jsonb_typeof(a.variant_forms) = 'array' THEN a.variant_forms ELSE '[]'::jsonb END) e
               UNION
               SELECT btrim(x) FROM jsonb_each(
                   CASE WHEN jsonb_typeof(a.variant_forms) = 'object' THEN a.variant_forms ELSE '{}'::jsonb END) o(k, val)
                 CROSS JOIN LATERAL jsonb_array_elements_text(CASE WHEN jsonb_typeof(o.val) = 'array' THEN o.val ELSE '[]'::jsonb END) x
             ) f
             WHERE nullif(v, '') IS NOT NULL
               AND v IS DISTINCT FROM a.preferred_name AND v IS DISTINCT FROM a.sort_name),
           'viaf', a.viaf_id, 'isni', a.isni, 'wikidata', a.wikidata_id,
           'idref', a.external_ids->>'idref', 'lccn', a.external_ids->>'lccn',
           'note', a.dates_note))
         ORDER BY a.id), '[]'::jsonb)
    INTO v_auteurs
    FROM public.authors a JOIN ids ON ids.author_id = a.id;

  -- Sujets du thésaurus liés aux notices détenues, et leurs ancêtres.
  WITH RECURSIVE livres AS (
    SELECT DISTINCT h.book_id FROM public.book_holdings h WHERE h.library_id = p_library_id
  ), directs AS (
    SELECT DISTINCT bs.subject_id FROM public.book_subjects bs JOIN livres l ON l.book_id = bs.book_id
  ), arbre AS (
    SELECT s.id, s.parent_id FROM public.subjects s JOIN directs d ON d.subject_id = s.id
    UNION
    SELECT p.id, p.parent_id FROM public.subjects p JOIN arbre a ON a.parent_id = p.id
  )
  SELECT coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'id', s.id,
           'slug', s.slug,
           'label', coalesce(s.label_i18n->>v_locale, s.label_i18n->>'pt-BR',
                             (SELECT v FROM jsonb_each_text(s.label_i18n) x(k, v) ORDER BY k LIMIT 1), s.slug),
           'alt', CASE WHEN jsonb_typeof(s.alt_i18n->v_locale) = 'array' AND s.alt_i18n->v_locale <> '[]'::jsonb
                       THEN s.alt_i18n->v_locale END,
           'broader', s.parent_id,
           'related', (SELECT jsonb_agg(DISTINCT r.autre ORDER BY r.autre) FROM (
                         SELECT sr.related_subject_id AS autre FROM public.subject_relations sr WHERE sr.subject_id = s.id
                         UNION
                         SELECT sr.subject_id FROM public.subject_relations sr WHERE sr.related_subject_id = s.id) r),
           'notation', s.notation,
           'scopeNote', s.scope_note))
         ORDER BY s.id), '[]'::jsonb)
    INTO v_sujets
    FROM public.subjects s
   WHERE s.id IN (SELECT id FROM arbre);

  RETURN jsonb_build_object(
    'ok', true,
    'library_id', p_library_id,
    'library', v_library,
    'authors', v_auteurs,
    'subjects', v_sujets
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_export_authorities_lote(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_export_authorities_lote(uuid) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_export_authorities_lote(uuid) IS
  'H25 (28/09/2026) : les autorites (personnes, collectivites, congres, sujets et leurs ancetres) liees aux '
  'notices qu''une bibliotheque detient, pour l''export UNIMARC Autorites ; coordination de la bibliotheque '
  'ou administration du reseau.';
