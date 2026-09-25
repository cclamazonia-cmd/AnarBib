-- =========================================================================
-- Les cinq relations SKOS s'ouvrent à l'application (25/09/2026)
-- =========================================================================
-- Réf. : backlog v34 H9 ; migration 20260907172508 (domaine étendu, porte
--        laissée fermée exprès) ; REGISTRE §30 DOC-THES-1.
--
-- Le 07/09, le domaine de subject_ficedl_links.match_type a reçu broad, narrow
-- et related, mais api.fn_subject_add_ficedl_match est restée bornée à
-- exact/close : la page-sujet et le sérialiseur SKOS rendaient match_type en
-- binaire, et un `broad` aurait été publié comme correspondance EXACTE. Les
-- trois consommateurs sont livrés dans le même commit que cette migration :
-- src/lib/skosExport.js (table à cinq entrées, SKOS_MATCH, rien par défaut),
-- src/pages/public/SubjectPage.jsx et l'éditeur de la coordination
-- (SubjectLabelEditor.jsx, choix de la relation), plus les clés dans les dix
-- locales. La porte peut donc s'ouvrir.
--
-- Fonction reprise de sa définition RÉELLE en production (lue le 25/09) : seule
-- la liste de la garde change. Signature, DEFINER, search_path et droits
-- inchangés (CREATE OR REPLACE garde l'ACL).
--
-- Le bloc de vérification 4.2 de 20260907172508 (« la porte reste fermée »)
-- est INVERSÉ ici, en 2) : il continue de passer au rejeu, puisqu'il s'exécute
-- avant cette migration.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) La garde accepte les cinq relations
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_subject_add_ficedl_match(p_subject_id bigint, p_mot_id text, p_match_type text DEFAULT 'exact'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
  IF NOT public.fn_is_catalog_coordinator() THEN
    RAISE EXCEPTION 'Réservé à la coordination catalogage' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_match_type IS NULL OR p_match_type NOT IN ('exact', 'close', 'broad', 'narrow', 'related') THEN
    RAISE EXCEPTION 'match_type invalide : %', p_match_type USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.subjects WHERE id = p_subject_id) THEN
    RAISE EXCEPTION 'Sujet introuvable : %', p_subject_id USING ERRCODE = 'no_data_found';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ficedl_thesaurus_terms WHERE mot_id = p_mot_id) THEN
    RAISE EXCEPTION 'Descripteur FICEDL introuvable : %', p_mot_id USING ERRCODE = 'no_data_found';
  END IF;
  INSERT INTO public.subject_ficedl_links(subject_id, mot_id, match_type, created_by)
    VALUES (p_subject_id, p_mot_id, p_match_type, auth.uid())
    ON CONFLICT (subject_id, mot_id) DO UPDATE SET match_type = EXCLUDED.match_type;
END $function$;

COMMENT ON COLUMN public.subject_ficedl_links.match_type IS
  'Relation SKOS déclarée DEPUIS le sujet AnarBib VERS le descripteur FICEDL. '
  'exact = skos:exactMatch (même concept) ; close = skos:closeMatch (voisins, '
  'interchangeables en recherche) ; broad = skos:broadMatch (le descripteur '
  'FICEDL est PLUS LARGE que le sujet local) ; narrow = skos:narrowMatch (il est '
  'PLUS ÉTROIT) ; related = skos:relatedMatch (associés, sans hiérarchie). '
  'Domaine étendu le 07/09/2026, ouvert à l''application le 25/09/2026 (H9) : '
  'api.fn_subject_add_ficedl_match accepte les cinq, src/lib/skosExport.js '
  '(SKOS_MATCH) et src/lib/ficedlMatch.js les rendent.';

-- -------------------------------------------------------------------------
-- 2) Vérification — le 4.2 de 20260907172508, inversé
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api' AND p.proname = 'fn_subject_add_ficedl_match';
  IF v_def IS NULL OR v_def NOT LIKE '%''broad''%' OR v_def NOT LIKE '%''narrow''%' OR v_def NOT LIKE '%''related''%' THEN
    RAISE EXCEPTION 'fn_subject_add_ficedl_match n''accepte pas encore broad/narrow/related.';
  END IF;
  IF has_function_privilege('anon', 'api.fn_subject_add_ficedl_match(bigint, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_subject_add_ficedl_match ouverte à anon.';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;
