-- Migration : corrige l'enregistrement de partenaire de dépôt (CHECK source_kind
--              + valeurs relation_status valides)
-- Auteur  : Claude Opus 4.8
-- Session : Unification partenaire <-> source d'import (fix B1)
-- Date    : 2026-06-11 (UTC)
--
-- BUG : fn_partner_register_deposit_source (B1) insérait dans
-- ingest.partner_catalog_sources avec source_kind='partner_deposit' ET
-- relation_status='active' — DEUX valeurs refusées par les CHECK de la table :
--   - source_kind ∈ {manual_upload, zotero_file_export, zotero_api}  → 'partner_deposit' ABSENT
--   - relation_status ∈ {mapeada, contatada, …, importacao_autorizada, …} → 'active' ABSENT
-- (C'est aussi pourquoi l'ANCIEN « + » de la page Import échouait : même vocabulaire faux.)
--
-- Or le frontend (ImportacoesPage filtre source_kind='partner_deposit') et la RPC
-- veulent 'partner_deposit'. On régularise donc le CHECK + on utilise les bons
-- statuts (importacao_autorizada / mapeada). Vocabulaires distincts à noter :
--   catalog_partners.relationship_status : état initial = 'identificada'
--   partner_catalog_sources.relation_status : état initial = 'mapeada'

-- ═══════════════════════════════════════════════════════════════
-- 1. Régularise le CHECK source_kind (ajoute 'partner_deposit')
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE ingest.partner_catalog_sources
  DROP CONSTRAINT IF EXISTS partner_catalog_sources_source_kind_check;

ALTER TABLE ingest.partner_catalog_sources
  ADD CONSTRAINT partner_catalog_sources_source_kind_check
  CHECK (source_kind = ANY (ARRAY['manual_upload', 'zotero_file_export', 'zotero_api', 'partner_deposit']));

-- ═══════════════════════════════════════════════════════════════
-- 2. Corrige fn_partner_register_deposit_source (statuts valides)
-- ═══════════════════════════════════════════════════════════════

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
  v_partner_status  text;
  v_source_status   text;
BEGIN
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

  v_slug := trim(both '-' from regexp_replace(lower(trim(p_display_name)), '[^a-z0-9]+', '-', 'g'));
  IF v_slug = '' THEN
    RAISE EXCEPTION 'Nome do parceiro invalido (slug vazio).';
  END IF;

  -- Vocabulaires DISTINCTS entre les deux tables :
  v_partner_status := CASE WHEN p_import_authorized THEN 'importacao_autorizada' ELSE 'identificada' END; -- catalog_partners
  v_source_status  := CASE WHEN p_import_authorized THEN 'importacao_autorizada' ELSE 'mapeada' END;       -- partner_catalog_sources

  -- Dédup : entité existante par slug exact -> réutilisée
  SELECT id INTO v_partner_id FROM public.catalog_partners WHERE slug = v_slug LIMIT 1;
  IF v_partner_id IS NULL THEN
    INSERT INTO public.catalog_partners
      (slug, display_name, base_url, country_code, notes,
       integration_mode, relationship_status, is_active)
    VALUES
      (v_slug, trim(p_display_name), coalesce(nullif(trim(p_base_url), ''), ''),
       nullif(trim(p_country_code), ''), nullif(trim(p_notes), ''),
       'file_deposit', v_partner_status, true)
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
      (trim(p_display_name), v_actor.library_id, v_source_status, 'partner_deposit',
       p_import_authorized, nullif(trim(p_notes), ''), v_partner_id)
    RETURNING id INTO v_source_id;
    v_source_created := true;
  ELSE
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

-- ═══════════════════════════════════════════════════════════════
-- 3. Vérification
-- ═══════════════════════════════════════════════════════════════

DO $verif$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO v_def
    FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace
   WHERE n.nspname='ingest' AND t.relname='partner_catalog_sources'
     AND c.conname='partner_catalog_sources_source_kind_check';
  IF v_def IS NULL OR v_def NOT LIKE '%partner_deposit%' THEN
    RAISE EXCEPTION 'CHECK source_kind ne contient pas partner_deposit.';
  END IF;
  RAISE NOTICE 'Fix B1 OK : source_kind accepte partner_deposit + statuts valides.';
END
$verif$;
