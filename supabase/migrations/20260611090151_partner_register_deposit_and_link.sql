-- Migration : enregistrer un partenaire de DÉPÔT (entité + source liée) + recherche
-- Auteur  : Claude Opus 4.8
-- Session : Unification partenaire <-> source d'import (inc. B1)
-- Date    : 2026-06-11 (UTC)
--
-- Voie noble de création de partenaire externe (ex. CIRA Marseille, export Zotero) :
-- au lieu du « + » texte-libre de la page Import (cassé + déconnecté), on crée une
-- vraie ENTITÉ catalog_partners + on lui relie la source de dépôt de la biblio.
--
-- Modèle vérifié :
--   - catalog_partners : entité réseau (slug UNIQUE, base_url NOT NULL,
--     relationship_status ∈ {identificada … importacao_autorizada …}).
--   - L'« autorisation d'import » N'EST PAS un flag séparé : c'est
--     relationship_status = 'importacao_autorizada' (la vue policy_flags_v2.
--     import_allowed en découle).
--   - ingest.partner_catalog_sources : source de dépôt PAR biblio (source_kind=
--     'partner_deposit'). On y ajoute catalog_partner_id pour relier à l'entité.

-- ═══════════════════════════════════════════════════════════════
-- 1. Lien source de dépôt -> entité partenaire
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE ingest.partner_catalog_sources
  ADD COLUMN IF NOT EXISTS catalog_partner_id bigint
  REFERENCES public.catalog_partners(id) ON DELETE SET NULL;

COMMENT ON COLUMN ingest.partner_catalog_sources.catalog_partner_id IS
  'Entité partenaire (public.catalog_partners) dont cette source de dépôt provient. '
  'NULL pour les sources legacy créées en texte libre.';

-- ═══════════════════════════════════════════════════════════════
-- 2. fn_partner_register_deposit_source — crée/relie partenaire + source
-- ═══════════════════════════════════════════════════════════════
-- Coordenador-only (ou admin réseau). Détecte le doublon par slug exact (réutilise
-- l'entité existante), sinon crée l'entité. Crée/relie la source de dépôt de la
-- biblio appelante. p_import_authorized pilote relationship_status + import_enabled.

CREATE OR REPLACE FUNCTION public.fn_partner_register_deposit_source(
  p_display_name      text,
  p_base_url          text    DEFAULT '',
  p_country_code      text    DEFAULT NULL,
  p_notes             text    DEFAULT NULL,
  p_import_authorized boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, ingest, auth
AS $fn$
DECLARE
  v_actor           public.my_access%rowtype;
  v_slug            text;
  v_partner_id      bigint;
  v_partner_created boolean := false;
  v_source_id       bigint;
  v_source_created  boolean := false;
  v_status          text;
BEGIN
  -- Garde-fou : staff de coordination (cohérent avec les wrappers d'import IMP-14)
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  IF coalesce(trim(p_display_name), '') = '' THEN
    RAISE EXCEPTION 'Nome do parceiro obrigatorio.';
  END IF;

  -- Slug : minuscule -> non-alphanumérique en tiret -> trim des tirets
  v_slug := trim(both '-' from regexp_replace(lower(trim(p_display_name)), '[^a-z0-9]+', '-', 'g'));
  IF v_slug = '' THEN
    RAISE EXCEPTION 'Nome do parceiro invalido (slug vazio).';
  END IF;

  v_status := CASE WHEN p_import_authorized THEN 'importacao_autorizada' ELSE 'identificada' END;

  -- Dédup : entité existante par slug exact -> on la réutilise (pas de doublon)
  SELECT id INTO v_partner_id FROM public.catalog_partners WHERE slug = v_slug LIMIT 1;
  IF v_partner_id IS NULL THEN
    INSERT INTO public.catalog_partners
      (slug, display_name, base_url, country_code, notes,
       integration_mode, relationship_status, is_active)
    VALUES
      (v_slug, trim(p_display_name), coalesce(nullif(trim(p_base_url), ''), ''),
       nullif(trim(p_country_code), ''), nullif(trim(p_notes), ''),
       'file_deposit', v_status, true)
    RETURNING id INTO v_partner_id;
    v_partner_created := true;
  END IF;

  -- Source de dépôt de CETTE biblio, reliée à l'entité
  SELECT id INTO v_source_id
    FROM ingest.partner_catalog_sources
   WHERE library_id = v_actor.library_id
     AND source_kind = 'partner_deposit'
     AND (catalog_partner_id = v_partner_id OR partner_name = trim(p_display_name))
   LIMIT 1;

  IF v_source_id IS NULL THEN
    INSERT INTO ingest.partner_catalog_sources
      (partner_name, library_id, relation_status, source_kind,
       import_enabled, notes, catalog_partner_id)
    VALUES
      (trim(p_display_name), v_actor.library_id, 'active', 'partner_deposit',
       p_import_authorized, nullif(trim(p_notes), ''), v_partner_id)
    RETURNING id INTO v_source_id;
    v_source_created := true;
  ELSE
    -- Backfill du lien sur une source legacy
    UPDATE ingest.partner_catalog_sources
       SET catalog_partner_id = coalesce(catalog_partner_id, v_partner_id),
           import_enabled = p_import_authorized
     WHERE id = v_source_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'partner_id', v_partner_id,
    'partner_slug', v_slug,
    'partner_created', v_partner_created,
    'source_id', v_source_id,
    'source_created', v_source_created
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_partner_register_deposit_source(text, text, text, text, boolean) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_partner_register_deposit_source(text, text, text, text, boolean) TO authenticated;

COMMENT ON FUNCTION public.fn_partner_register_deposit_source(text, text, text, text, boolean) IS
  'Crée (ou réutilise par slug) une entité catalog_partners de dépôt + la source '
  'ingest.partner_catalog_sources liée pour la biblio appelante (coordenador). '
  'p_import_authorized -> relationship_status importacao_autorizada + import_enabled.';

-- ═══════════════════════════════════════════════════════════════
-- 3. fn_partner_search — détection de doublon (suggestions avant création)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_partner_search(p_query text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $fn$
DECLARE
  v_actor  public.my_access%rowtype;
  v_q      text;
  v_result jsonb;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  v_q := '%' || trim(coalesce(p_query, '')) || '%';
  IF length(trim(coalesce(p_query, ''))) < 2 THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_result
  FROM (
    SELECT id, slug, display_name, country_code, relationship_status
    FROM public.catalog_partners
    WHERE is_active AND (display_name ILIKE v_q OR slug ILIKE v_q)
    ORDER BY display_name
    LIMIT 8
  ) t;

  RETURN v_result;
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_partner_search(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_partner_search(text) TO authenticated;

COMMENT ON FUNCTION public.fn_partner_search(text) IS
  'Recherche de partenaires catalog_partners (nom/slug, ILIKE) pour la détection '
  'de doublon avant création. Staff de bibliothèque uniquement.';

-- ═══════════════════════════════════════════════════════════════
-- 4. Vérification
-- ═══════════════════════════════════════════════════════════════

DO $verif$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='ingest' AND table_name='partner_catalog_sources'
      AND column_name='catalog_partner_id'
  ) THEN
    RAISE EXCEPTION 'Colonne catalog_partner_id absente.';
  END IF;
  IF to_regprocedure('public.fn_partner_register_deposit_source(text, text, text, text, boolean)') IS NULL
     OR to_regprocedure('public.fn_partner_search(text)') IS NULL THEN
    RAISE EXCEPTION 'RPC partenaire dépôt absente(s).';
  END IF;
  RAISE NOTICE 'Inc. B1 OK : lien catalog_partner_id + fn_partner_register_deposit_source + fn_partner_search.';
END
$verif$;
