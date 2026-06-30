-- =========================================================================
-- P3b — Alignement des sujets AnarBib sur le thésaurus partagé FICEDL
-- =========================================================================
-- Date     : 2026-06-30
-- Chantier : Intégration thésaurus FICEDL — fédération du vocabulaire-sujets
-- Auteur   : AnarBib
-- Session  : Intégration thésaurus FICEDL P3 (pages-sujets + fédération)
--
-- OBJET
--   Relie un sujet interne (public.subjects) à un ou plusieurs descripteurs du
--   thésaurus partagé FICEDL (public.ficedl_thesaurus_terms), en SKOS exact/close
--   match. Permet : (1) la fédération ENTRANTE (afficher « ce sujet dans les
--   catalogues partenaires » via les catalog_links du terme FICEDL) ; (2) l'export
--   SKOS enrichi d'un skos:exactMatch / skos:closeMatch vers l'URI FICEDL.
--
--   ANTI-FORK : on ne MODIFIE jamais le thésaurus FICEDL (read-only). On ne fait
--   qu'établir un lien depuis le vocabulaire interne d'AnarBib vers lui.
--
--   Gouvernance (THES-1) : poser/retirer un alignement = coordination catalogage
--   (garde public.fn_is_catalog_coordinator()), comme les libellés et relations.
--
-- CHECKLIST DOCTRINE
--   [x] Table public.subject_ficedl_links : RLS + policy SELECT publique +
--       GRANT SELECT (anon/authenticated) + REVOKE des écritures + ALL service_role.
--   [x] Fonctions SECURITY DEFINER d'écriture : search_path, REVOKE FROM PUBLIC/
--       anon/authenticated/service_role, GRANT EXECUTE authenticated, garde coord.
--   [x] Fonctions de lecture publiques : STABLE, GRANT anon + authenticated.
--   [x] NOTIFY pgrst (schéma api/public modifié) + DO-block de vérification.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) Table de jointure subjects ↔ FICEDL (n:m, exact/close match)
-- -------------------------------------------------------------------------
CREATE TABLE public.subject_ficedl_links (
  subject_id  bigint      NOT NULL REFERENCES public.subjects(id)                ON DELETE CASCADE,
  mot_id      text        NOT NULL REFERENCES public.ficedl_thesaurus_terms(mot_id) ON DELETE CASCADE,
  match_type  text        NOT NULL DEFAULT 'exact'
                          CHECK (match_type IN ('exact', 'close')),  -- skos:exactMatch / skos:closeMatch
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid,
  PRIMARY KEY (subject_id, mot_id)
);

CREATE INDEX subject_ficedl_links_mot_id_idx ON public.subject_ficedl_links(mot_id);

-- Catalogue public : lisible par tous (alimente l'OPAC + l'export SKOS).
GRANT SELECT ON public.subject_ficedl_links TO anon;
GRANT SELECT ON public.subject_ficedl_links TO authenticated;
GRANT ALL    ON public.subject_ficedl_links TO service_role;
-- Neutralise les default privileges Supabase (CRUD d'office) : lecture seule.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.subject_ficedl_links FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.subject_ficedl_links FROM authenticated;

ALTER TABLE public.subject_ficedl_links ENABLE ROW LEVEL SECURITY;

-- Lecture publique ; écriture réservée aux RPC SECURITY DEFINER ci-dessous.
CREATE POLICY "subject_ficedl_links_read"
  ON public.subject_ficedl_links
  FOR SELECT TO anon, authenticated
  USING (true);

COMMENT ON TABLE public.subject_ficedl_links IS
  'Alignement (skos:exact/closeMatch) des sujets AnarBib (public.subjects) sur le '
  'thésaurus partagé FICEDL (public.ficedl_thesaurus_terms). Écriture coord catalogage '
  'via api.fn_subject_add/remove_ficedl_match. Créé en P3b le 30/06/2026.';

-- -------------------------------------------------------------------------
-- 2) RPC d'écriture (coordination catalogage) — modèle fn_subject_add_relation
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_subject_add_ficedl_match(
  p_subject_id bigint,
  p_mot_id     text,
  p_match_type text DEFAULT 'exact'
) RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'public', 'pg_catalog'
AS $$
BEGIN
  IF NOT public.fn_is_catalog_coordinator() THEN
    RAISE EXCEPTION 'Réservé à la coordination catalogage' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_match_type NOT IN ('exact', 'close') THEN
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
END $$;

REVOKE ALL ON FUNCTION api.fn_subject_add_ficedl_match(bigint, text, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.fn_subject_add_ficedl_match(bigint, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION api.fn_subject_remove_ficedl_match(
  p_subject_id bigint,
  p_mot_id     text
) RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'public', 'pg_catalog'
AS $$
BEGIN
  IF NOT public.fn_is_catalog_coordinator() THEN
    RAISE EXCEPTION 'Réservé à la coordination catalogage' USING ERRCODE = 'insufficient_privilege';
  END IF;
  DELETE FROM public.subject_ficedl_links WHERE subject_id = p_subject_id AND mot_id = p_mot_id;
END $$;

REVOKE ALL ON FUNCTION api.fn_subject_remove_ficedl_match(bigint, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.fn_subject_remove_ficedl_match(bigint, text) TO authenticated;

-- -------------------------------------------------------------------------
-- 3) RPC de lecture publique : liens FICEDL d'un sujet (éditeur + page-sujet)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.subject_ficedl_links_v1(p_subject_id bigint)
  RETURNS TABLE(mot_id text, match_type text, labels jsonb, el_roman text, catalog_links jsonb, source_url text)
  LANGUAGE sql STABLE
  SET search_path TO 'public', 'pg_catalog'
AS $$
  SELECT l.mot_id, l.match_type, f.labels, f.el_roman, f.catalog_links, f.source_url
  FROM public.subject_ficedl_links l
  JOIN public.ficedl_thesaurus_terms f ON f.mot_id = l.mot_id
  WHERE l.subject_id = p_subject_id
  ORDER BY l.match_type, l.mot_id;
$$;

REVOKE ALL ON FUNCTION api.subject_ficedl_links_v1(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.subject_ficedl_links_v1(bigint) TO anon, authenticated;

-- -------------------------------------------------------------------------
-- 4) RPC de lecture publique : détail d'un sujet ACTIF par slug (page-sujet)
--    (slug → id + libellés + scope_note + parent ; status='ativo' uniquement)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.subject_detail_v1(p_slug text)
  RETURNS TABLE(
    id bigint, slug text, label_i18n jsonb, alt_i18n jsonb,
    scope_note text, notation text,
    parent_id bigint, parent_slug text, parent_label_i18n jsonb
  )
  LANGUAGE sql STABLE
  SET search_path TO 'public', 'pg_catalog'
AS $$
  SELECT s.id, s.slug, s.label_i18n, s.alt_i18n,
         s.scope_note, s.notation,
         s.parent_id, p.slug, p.label_i18n
  FROM public.subjects s
  LEFT JOIN public.subjects p ON p.id = s.parent_id AND p.status = 'ativo'
  WHERE s.slug = p_slug AND s.status = 'ativo';
$$;

REVOKE ALL ON FUNCTION api.subject_detail_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.subject_detail_v1(text) TO anon, authenticated;

-- -------------------------------------------------------------------------
-- 5) Export SKOS enrichi : ajoute les liens FICEDL par concept
--    (rétro-compatible : ajoute une clé 'ficedl' ignorée des consommateurs v1)
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
          SELECT jsonb_agg(jsonb_build_object('uri', f.source_url, 'match', l.match_type) ORDER BY l.mot_id)
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
-- 6) Vérification
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_anon_writes text;
BEGIN
  -- anon/authenticated ne doivent garder que SELECT sur la table de liens.
  SELECT string_agg(grantee || ':' || privilege_type, ', ')
    INTO v_anon_writes
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public' AND table_name = 'subject_ficedl_links'
    AND grantee IN ('anon', 'authenticated') AND privilege_type <> 'SELECT';
  IF v_anon_writes IS NOT NULL THEN
    RAISE EXCEPTION 'subject_ficedl_links : privilèges d''écriture résiduels (%). Rollback.', v_anon_writes;
  END IF;

  -- L'export doit rester du JSON valide avec la clé concepts.
  PERFORM api.thesaurus_export_v1();

  RAISE NOTICE 'P3b : subject_ficedl_links + RPC alignement/lecture + export SKOS enrichi OK.';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé (à adapter) :
-- =========================================================================
-- BEGIN;
--   DROP FUNCTION IF EXISTS api.fn_subject_add_ficedl_match(bigint, text, text);
--   DROP FUNCTION IF EXISTS api.fn_subject_remove_ficedl_match(bigint, text);
--   DROP FUNCTION IF EXISTS api.subject_ficedl_links_v1(bigint);
--   DROP FUNCTION IF EXISTS api.subject_detail_v1(text);
--   DROP TABLE IF EXISTS public.subject_ficedl_links;
--   -- restaurer l'ancienne version de api.thesaurus_export_v1 (sans clé 'ficedl')
--   NOTIFY pgrst, 'reload schema';
-- COMMIT;
-- =========================================================================
