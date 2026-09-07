-- =========================================================================
-- L'alignement dit vers quelle liste il pointe
-- =========================================================================
-- Date     : 2026-09-07
-- Chantier : Thésaurus FICEDL — deux vocabulaires, pas un
-- Rattaché : claude/REPONSE_hortical_deux_thesaurus_2026-09-07.md
--            claude/VERIF_subject_ficedl_links_schema_2026-09-07.md
--
-- OBJET
--   La FICEDL tient DEUX vocabulaires distincts — « liste commune » (facette
--   sujets) et « géo-histo » (facettes geo et dates) — confirmé le 07/09/2026
--   par un·e administrateur·rice du thésaurus. AnarBib les a importés dans une
--   seule table, et son export SKOS présentait ses 98 alignements comme pointant
--   vers un vocabulaire unique, alors que 72 visent la liste commune et 26 la
--   géo-histo. Ce n'est pas une modification de la source : c'est une
--   description fausse de sa structure. C'est le seul point de cette affaire qui
--   méritait le mot « fork », et cette migration le corrige.
--
--   1) L'export SKOS déclare, pour chaque alignement, la ou les facettes du
--      descripteur visé (clé `scheme` — ajout rétro-compatible, cf. la doctrine
--      inscrite dans thesaurus_export_v1 au 30/06).
--   2) Le domaine de `match_type` accueille les trois relations SKOS qui
--      manquaient : broad, narrow, related.
--   3) Le commentaire de `ficedl_thesaurus_terms.facet` cesse de mentir : il
--      annonçait trois valeurs, la colonne en porte quatre (159 lignes `dates`).
--
-- CE QUE CETTE MIGRATION NE FAIT PAS, ET POURQUOI
--   Elle n'ouvre PAS le nouveau domaine à l'application :
--   api.fn_subject_add_ficedl_match reste bornée à exact/close.
--   Raison mesurée, pas prudentielle : src/pages/public/SubjectPage.jsx (l.163)
--   rend match_type en binaire — `close` sinon « correspondance exacte ». Une
--   valeur `broad` s'afficherait donc publiquement comme « exacte », soit
--   exactement la sur-affirmation que ce chantier cherche à supprimer. Ouvrir la
--   porte suppose le front ET trois clés i18n dans les dix locales (test i18n
--   bloquant en CI). Chantier du 14/09, à faire d'un bloc.
--
-- ANTI-FORK : aucune ligne de public.ficedl_thesaurus_terms n'est touchée.
-- GEL : aucune donnée modifiée, aucune signature de fonction changée, aucun
--       changement de comportement pour le front. Jouable la veille du gel.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) Le domaine des correspondances : cinq relations SKOS au lieu de deux
-- -------------------------------------------------------------------------
ALTER TABLE public.subject_ficedl_links
  DROP CONSTRAINT subject_ficedl_links_match_type_check;

ALTER TABLE public.subject_ficedl_links
  ADD CONSTRAINT subject_ficedl_links_match_type_check
  CHECK (match_type IN ('exact', 'close', 'broad', 'narrow', 'related'));

COMMENT ON COLUMN public.subject_ficedl_links.match_type IS
  'Relation SKOS déclarée DEPUIS le sujet AnarBib VERS le descripteur FICEDL. '
  'exact = skos:exactMatch (même concept) ; close = skos:closeMatch (voisins, '
  'interchangeables en recherche) ; broad = skos:broadMatch (le descripteur '
  'FICEDL est PLUS LARGE que le sujet local) ; narrow = skos:narrowMatch (il est '
  'PLUS ÉTROIT) ; related = skos:relatedMatch (associés, sans hiérarchie). '
  'Domaine étendu le 07/09/2026 ; broad/narrow/related ne sont pas encore '
  'ouverts à l''application (front binaire, cf. en-tête de la migration).';

-- -------------------------------------------------------------------------
-- 2) Le commentaire de la facette dit ce que la colonne porte réellement
-- -------------------------------------------------------------------------
COMMENT ON COLUMN public.ficedl_thesaurus_terms.facet IS
  'Facette(s) FICEDL du descripteur, TELLES QU''ASPIRÉES : {sujets} | {geo} | '
  '{dates} | {sujets,geo}. Elles relèvent de DEUX vocabulaires distincts tenus '
  'séparément par la FICEDL : la « liste commune » (sujets) et la « géo-histo » '
  '(geo + dates). Ce sont les noms de la source, pas des identifiants inventés '
  'par AnarBib.';

-- -------------------------------------------------------------------------
-- 3) L'export SKOS déclare le vocabulaire visé par chaque alignement
--    (signature inchangée ; ajout de la clé `scheme` dans les objets `ficedl`)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.thesaurus_export_v1() RETURNS jsonb
  LANGUAGE sql STABLE
  SET search_path TO 'public', 'pg_catalog'
AS $$
  SELECT jsonb_build_object(
    'concepts', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'slug', s.slug,
        'label_i18n', s.label_i18n,
        'alt_i18n', COALESCE(s.alt_i18n,'{}'::jsonb),
        'hidden_i18n', COALESCE(s.hidden_i18n,'{}'::jsonb),
        'notation', s.notation,
        'scope_note', s.scope_note,
        'parent_slug', p.slug,
        'deprecated', (s.status = 'depreciado'),
        'ficedl', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
                   'uri',    f.source_url,
                   'match',  l.match_type,
                   'scheme', to_jsonb(f.facet)
                 ) ORDER BY l.mot_id)
          FROM public.subject_ficedl_links l
          JOIN public.ficedl_thesaurus_terms f ON f.mot_id = l.mot_id
          WHERE l.subject_id = s.id
        ), '[]'::jsonb)
      ) ORDER BY s.slug)
      FROM public.subjects s
      LEFT JOIN public.subjects p ON p.id = s.parent_id AND p.status IN ('ativo','depreciado')
      WHERE s.status IN ('ativo','depreciado')), '[]'::jsonb),
    'relations', COALESCE((SELECT jsonb_agg(jsonb_build_object('a', sa.slug, 'b', sb.slug) ORDER BY sa.slug, sb.slug)
      FROM public.subject_relations r
      JOIN public.subjects sa ON sa.id = r.subject_id          AND sa.status IN ('ativo','depreciado')
      JOIN public.subjects sb ON sb.id = r.related_subject_id  AND sb.status IN ('ativo','depreciado')), '[]'::jsonb)
  );
$$;

-- -------------------------------------------------------------------------
-- 4) Vérification — la migration se refuse si elle n'a pas fait ce qu'elle dit
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_def        text;
  v_exportes   bigint;
  v_avec_scheme bigint;
  v_attendus   bigint;
BEGIN
  -- 4.1 Le domaine porte bien les cinq valeurs.
  SELECT pg_get_constraintdef(oid) INTO v_def
  FROM pg_constraint WHERE conname = 'subject_ficedl_links_match_type_check';
  IF v_def IS NULL OR v_def NOT LIKE '%related%' OR v_def NOT LIKE '%broad%' OR v_def NOT LIKE '%narrow%' THEN
    RAISE EXCEPTION 'Domaine match_type non étendu : %', COALESCE(v_def, '(contrainte absente)');
  END IF;

  -- 4.2 La porte reste fermée : la RPC d'écriture n'accepte toujours que exact/close.
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api' AND p.proname = 'fn_subject_add_ficedl_match';
  IF v_def IS NULL OR v_def LIKE '%''broad''%' THEN
    RAISE EXCEPTION 'fn_subject_add_ficedl_match ne doit pas encore ouvrir broad/narrow/related (front binaire).';
  END IF;

  -- 4.3 Chaque alignement exporté porte sa facette, et il n'en manque aucun.
  SELECT count(*) INTO v_exportes
  FROM jsonb_array_elements(api.thesaurus_export_v1()->'concepts') c,
       jsonb_array_elements(c->'ficedl') fl;
  SELECT count(*) INTO v_avec_scheme
  FROM jsonb_array_elements(api.thesaurus_export_v1()->'concepts') c,
       jsonb_array_elements(c->'ficedl') fl
  WHERE fl ? 'scheme' AND jsonb_array_length(fl->'scheme') > 0;
  SELECT count(*) INTO v_attendus
  FROM public.subject_ficedl_links l
  JOIN public.subjects s ON s.id = l.subject_id AND s.status IN ('ativo','depreciado');

  IF v_exportes <> v_attendus THEN
    RAISE EXCEPTION 'Export : % alignements rendus pour % attendus.', v_exportes, v_attendus;
  END IF;
  IF v_avec_scheme <> v_exportes THEN
    RAISE EXCEPTION 'Export : % alignements sur % sans facette déclarée.', v_exportes - v_avec_scheme, v_exportes;
  END IF;

  RAISE NOTICE 'Alignements exportés : %, tous avec leur vocabulaire déclaré.', v_exportes;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé :
-- =========================================================================
-- BEGIN;
--   -- Ne repasser à deux valeurs que si aucune ligne ne porte broad/narrow/related.
--   ALTER TABLE public.subject_ficedl_links DROP CONSTRAINT subject_ficedl_links_match_type_check;
--   ALTER TABLE public.subject_ficedl_links ADD CONSTRAINT subject_ficedl_links_match_type_check
--     CHECK (match_type IN ('exact','close'));
--   -- Puis rejouer la définition de api.thesaurus_export_v1() du 30/06/2026
--   -- (migration 20260630111113_subject_ficedl_alignment.sql, section 5).
-- COMMIT;
