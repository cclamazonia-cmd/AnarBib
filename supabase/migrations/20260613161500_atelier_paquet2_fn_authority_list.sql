-- =====================================================================
-- ATELIER AUTORITÉS — Paquet 2 (support backend) : lecture de la file
-- =====================================================================
-- Endpoint de lecture enrichi pour la page /atelier-autoridades : la file de
-- propositions avec libellés résolus (auteur preferred_name / matière label_i18n),
-- libellé canonique (fusion), nom du proposeur, compte d'objections.
-- Gardé aux participants (contributeur / staff / admin réseau) ; non-participant
-- = liste vide (anti-panoptique : on ne révèle rien). Requête validée read-only
-- contre la prod le 13/06.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION api.fn_authority_list()
RETURNS TABLE(
  id uuid, kind text, target_kind text, target_id bigint, target_label text,
  merge_into_id bigint, merge_into_label text, status text, deadline timestamptz,
  rationale text, proposed_by uuid, proposer_name text, objection_count integer,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
BEGIN
  IF NOT (public.fn_caller_is_network_contributor() OR public.fn_caller_is_staff() OR public.fn_caller_is_network_admin()) THEN
    RETURN;  -- non-participant : liste vide
  END IF;
  RETURN QUERY
  SELECT p.id, p.kind, p.target_kind, p.target_id,
    CASE p.target_kind
      WHEN 'author'  THEN (SELECT a.preferred_name FROM public.authors a WHERE a.id = p.target_id)
      WHEN 'subject' THEN (SELECT coalesce(s.label_i18n->>'pt-BR', s.slug) FROM public.subjects s WHERE s.id = p.target_id)
    END,
    p.merge_into_id,
    CASE WHEN p.merge_into_id IS NULL THEN NULL
      WHEN p.target_kind='author'  THEN (SELECT a.preferred_name FROM public.authors a WHERE a.id = p.merge_into_id)
      WHEN p.target_kind='subject' THEN (SELECT coalesce(s.label_i18n->>'pt-BR', s.slug) FROM public.subjects s WHERE s.id = p.merge_into_id)
    END,
    p.status, p.deadline, p.rationale, p.proposed_by,
    (SELECT nullif(btrim(coalesce(pr.first_name,'')||' '||coalesce(pr.last_name,'')),'') FROM public.profiles pr WHERE pr.id = p.proposed_by),
    (SELECT count(*)::integer FROM public.authority_proposal_objections o WHERE o.proposal_id = p.id),
    p.created_at
  FROM public.authority_proposals p
  ORDER BY p.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION api.fn_authority_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION api.fn_authority_list() TO authenticated;
COMMENT ON FUNCTION api.fn_authority_list() IS
  'Atelier autorités (paquet 2) : file de propositions enrichie (libellés auteur/matière, proposeur, nb objections), gardée aux participants (contributeur/staff/admin). Non-participant = vide.';

COMMIT;
