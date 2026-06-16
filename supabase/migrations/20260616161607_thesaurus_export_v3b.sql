-- ============================================================================
-- Thésaurus v3-B : export SKOS/RDF — RPC de lecture du graphe complet
-- ----------------------------------------------------------------------------
-- Auteur  : AnarBib
-- Session : Fédération — Communs & Entraide
-- Date    : 2026-06-16 (UTC)
--
-- api.thesaurus_export_v1() renvoie le thésaurus comme graphe JSON (concepts +
-- relations associatives), que le frontend sérialise en SKOS (Turtle + JSON-LD)
-- pour téléchargement public. Le commun « thésaurus » devient ainsi une donnée
-- liée réutilisable par d'autres institutions.
--
-- Exporte les sujets ativo ET depreciado (les URI ne doivent pas disparaître ;
-- depreciado => owl:deprecated côté sérialiseur). Exclut proposto (pas encore
-- adopté). parent_slug = broader ; relations = skos:related. SECURITY INVOKER,
-- lecture publique. URI de base des concepts (côté frontend) :
-- https://app.anarbib.org/thesaurus/<slug>.
-- ============================================================================

CREATE OR REPLACE FUNCTION api.thesaurus_export_v1()
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO 'public','pg_catalog'
AS $function$
  SELECT jsonb_build_object(
    'concepts', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'slug', s.slug,
        'label_i18n', s.label_i18n,
        'alt_i18n', COALESCE(s.alt_i18n,'{}'::jsonb),
        'hidden_i18n', COALESCE(s.hidden_i18n,'{}'::jsonb),
        'notation', s.notation,
        'scope_note', s.scope_note,
        'parent_slug', p.slug,
        'deprecated', (s.status = 'depreciado')
      ) ORDER BY s.slug)
      FROM public.subjects s
      LEFT JOIN public.subjects p ON p.id = s.parent_id AND p.status IN ('ativo','depreciado')
      WHERE s.status IN ('ativo','depreciado')), '[]'::jsonb),
    'relations', COALESCE((SELECT jsonb_agg(jsonb_build_object('a', sa.slug, 'b', sb.slug) ORDER BY sa.slug, sb.slug)
      FROM public.subject_relations r
      JOIN public.subjects sa ON sa.id = r.subject_id          AND sa.status IN ('ativo','depreciado')
      JOIN public.subjects sb ON sb.id = r.related_subject_id  AND sb.status IN ('ativo','depreciado')), '[]'::jsonb)
  );
$function$;

REVOKE EXECUTE ON FUNCTION api.thesaurus_export_v1() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.thesaurus_export_v1() TO anon, authenticated;
