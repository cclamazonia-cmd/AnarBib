-- Migration : infrastructure OAI-PMH harvesting (Lot 3a)
-- Auteur  : Claude Opus 4.6
-- Session : Lot 3a – OAI-PMH infrastructure DB
-- Date    : 2026-06-08
--
-- Fondations pour le moissonnage OAI-PMH :
--   1. Colonnes OAI sur partner_catalog_sources
--   2. Table dédiée ingest.oai_harvest_state
--   3. RPC fn_import_register_oai_source  (admin réseau)
--   4. RPC fn_import_list_oai_sources     (can_access_painel)
--   5. RPC fn_import_harvest_oai          (can_access_painel, placeholder EF)

-- ═══════════════════════════════════════════════════════════════
-- 1. COLONNES OAI sur partner_catalog_sources
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE ingest.partner_catalog_sources
  ADD COLUMN IF NOT EXISTS oai_endpoint_url    text,
  ADD COLUMN IF NOT EXISTS oai_metadata_prefix text DEFAULT 'marcxml',
  ADD COLUMN IF NOT EXISTS oai_set             text;

COMMENT ON COLUMN ingest.partner_catalog_sources.oai_endpoint_url    IS 'URL de l''endpoint OAI-PMH (ex: https://example.org/oai). Null si la source n''est pas OAI.';
COMMENT ON COLUMN ingest.partner_catalog_sources.oai_metadata_prefix IS 'Préfixe de métadonnées OAI (marcxml, oai_dc). Fallback auto-négocié par l''EF.';
COMMENT ON COLUMN ingest.partner_catalog_sources.oai_set             IS 'Set OAI optionnel pour filtrer le moissonnage.';

-- ═══════════════════════════════════════════════════════════════
-- 2. TABLE ingest.oai_harvest_state
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ingest.oai_harvest_state (
  id                          bigserial PRIMARY KEY,
  source_id                   bigint NOT NULL REFERENCES ingest.partner_catalog_sources(id) ON DELETE CASCADE,
  harvest_status              text NOT NULL DEFAULT 'idle'
                              CHECK (harvest_status IN ('idle', 'in_progress', 'paused', 'error', 'completed')),
  last_harvest_at             timestamptz,
  pending_resumption_token    text,
  last_run_id                 bigint,
  lots_per_cycle              integer NOT NULL DEFAULT 5,
  lots_completed_this_cycle   integer NOT NULL DEFAULT 0,
  total_records_harvested     bigint NOT NULL DEFAULT 0,
  last_error                  text,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT oai_harvest_state_source_unique UNIQUE (source_id)
);

COMMENT ON TABLE ingest.oai_harvest_state IS
  'État de moissonnage OAI-PMH par source. Une ligne par source oai_pmh. '
  'Permet le moissonnage incrémental (from/until) et la reprise (resumptionToken).';

-- Trigger updated_at
CREATE OR REPLACE FUNCTION ingest.fn_oai_harvest_state_touch_updated()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_oai_harvest_state_updated ON ingest.oai_harvest_state;
CREATE TRIGGER trg_oai_harvest_state_updated
  BEFORE UPDATE ON ingest.oai_harvest_state
  FOR EACH ROW EXECUTE FUNCTION ingest.fn_oai_harvest_state_touch_updated();

-- ═══════════════════════════════════════════════════════════════
-- 3. RPC fn_import_register_oai_source (admin réseau uniquement)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_import_register_oai_source(
  p_partner_name        text,
  p_oai_endpoint_url    text,
  p_library_id          uuid,
  p_oai_metadata_prefix text DEFAULT 'marcxml',
  p_oai_set             text DEFAULT NULL,
  p_lots_per_cycle      integer DEFAULT 5,
  p_notes               text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $$
DECLARE
  v_source_id  bigint;
  v_state_id   bigint;
BEGIN
  -- Admin réseau obligatoire
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito a administradores de rede.';
  END IF;

  -- Validation
  IF p_oai_endpoint_url IS NULL OR trim(p_oai_endpoint_url) = '' THEN
    RAISE EXCEPTION 'oai_endpoint_url obrigatorio.';
  END IF;

  IF p_library_id IS NULL THEN
    RAISE EXCEPTION 'library_id obrigatorio.';
  END IF;

  -- Cherche une source OAI existante avec le même endpoint pour la même biblio
  SELECT id INTO v_source_id
    FROM ingest.partner_catalog_sources
   WHERE library_id       = p_library_id
     AND source_kind      = 'oai_pmh'
     AND oai_endpoint_url = trim(p_oai_endpoint_url)
   LIMIT 1;

  IF v_source_id IS NOT NULL THEN
    -- Met à jour les paramètres si la source existe déjà
    UPDATE ingest.partner_catalog_sources
       SET oai_metadata_prefix = coalesce(p_oai_metadata_prefix, oai_metadata_prefix),
           oai_set             = p_oai_set,
           notes               = coalesce(p_notes, notes),
           partner_name        = coalesce(p_partner_name, partner_name),
           updated_at          = now()
     WHERE id = v_source_id;

    -- Met à jour lots_per_cycle sur le state
    UPDATE ingest.oai_harvest_state
       SET lots_per_cycle = coalesce(p_lots_per_cycle, lots_per_cycle)
     WHERE source_id = v_source_id;

    RETURN jsonb_build_object(
      'ok', true, 'source_id', v_source_id, 'created', false
    );
  END IF;

  -- Crée la source
  INSERT INTO ingest.partner_catalog_sources
    (partner_name, library_id, relation_status, source_kind,
     import_enabled, oai_endpoint_url, oai_metadata_prefix, oai_set, notes)
  VALUES
    (p_partner_name, p_library_id, 'active', 'oai_pmh',
     true, trim(p_oai_endpoint_url), coalesce(p_oai_metadata_prefix, 'marcxml'),
     p_oai_set, p_notes)
  RETURNING id INTO v_source_id;

  -- Crée la ligne harvest_state associée
  INSERT INTO ingest.oai_harvest_state (source_id, lots_per_cycle)
  VALUES (v_source_id, coalesce(p_lots_per_cycle, 5))
  RETURNING id INTO v_state_id;

  RETURN jsonb_build_object(
    'ok', true, 'source_id', v_source_id, 'state_id', v_state_id, 'created', true
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_register_oai_source(text, text, uuid, text, text, integer, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_register_oai_source(text, text, uuid, text, text, integer, text) TO authenticated;

COMMENT ON FUNCTION public.fn_import_register_oai_source IS
  'Lot 3a — Enregistre une source OAI-PMH + initialise son état de moissonnage. '
  'Réservé aux admins réseau. Idempotent : met à jour si l''endpoint existe déjà.';

-- ═══════════════════════════════════════════════════════════════
-- 4. RPC fn_import_list_oai_sources (can_access_painel)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_import_list_oai_sources()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $$
DECLARE
  v_actor   public.my_access%rowtype;
  v_is_admin boolean;
  v_result  jsonb;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  v_is_admin := public.fn_caller_is_network_admin();

  SELECT coalesce(jsonb_agg(row_to_jsonb(sub) ORDER BY sub.partner_name), '[]'::jsonb)
    INTO v_result
    FROM (
      SELECT s.id, s.partner_name, s.library_id, s.oai_endpoint_url,
             s.oai_metadata_prefix, s.oai_set, s.import_enabled,
             s.relation_status, s.notes,
             h.harvest_status, h.last_harvest_at,
             h.pending_resumption_token IS NOT NULL AS has_pending_token,
             h.lots_per_cycle, h.lots_completed_this_cycle,
             h.total_records_harvested, h.last_error,
             h.updated_at AS harvest_updated_at
        FROM ingest.partner_catalog_sources s
        LEFT JOIN ingest.oai_harvest_state h ON h.source_id = s.id
       WHERE s.source_kind = 'oai_pmh'
         AND (v_is_admin OR s.library_id = v_actor.library_id)
    ) sub;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_oai_sources() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_oai_sources() TO authenticated;

COMMENT ON FUNCTION public.fn_import_list_oai_sources IS
  'Lot 3a — Liste les sources OAI-PMH avec leur état de moissonnage. '
  'Admin réseau voit tout, staff voit sa bibliothèque.';

-- ═══════════════════════════════════════════════════════════════
-- 5. RPC fn_import_harvest_oai (placeholder — EF viendra Lot 3b)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_import_harvest_oai(
  p_source_id  bigint,
  p_max_lots   integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $$
DECLARE
  v_actor      public.my_access%rowtype;
  v_source     record;
  v_state      record;
  v_run_id     bigint;
  v_max        integer;
BEGIN
  -- 1. Contrôle d'accès
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  -- 2. Vérifier la source
  SELECT * INTO v_source
    FROM ingest.partner_catalog_sources
   WHERE id = p_source_id AND source_kind = 'oai_pmh';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Source OAI-PMH % introuvable.', p_source_id;
  END IF;

  -- Vérifier appartenance (sauf admin réseau)
  IF NOT public.fn_caller_is_network_admin()
     AND v_source.library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Source % nao pertence a esta biblioteca.', p_source_id;
  END IF;

  -- 3. Vérifier l'état
  SELECT * INTO v_state
    FROM ingest.oai_harvest_state
   WHERE source_id = p_source_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Etat de moissonnage introuvable pour source %.', p_source_id;
  END IF;

  IF v_state.harvest_status = 'in_progress' THEN
    RAISE EXCEPTION 'Moissonnage deja en cours pour source %.', p_source_id;
  END IF;

  v_max := coalesce(p_max_lots, v_state.lots_per_cycle);

  -- 4. Créer un run
  INSERT INTO ingest.partner_catalog_import_runs
    (source_id, library_id, detected_format, run_status,
     original_filename, requested_by, imported_rows)
  VALUES
    (p_source_id, v_source.library_id, 'oai_pmh', 'pending',
     'oai-harvest-' || current_date::text, v_actor.user_id, 0)
  RETURNING id INTO v_run_id;

  -- 5. Marquer l'état en cours
  UPDATE ingest.oai_harvest_state
     SET harvest_status            = 'in_progress',
         last_run_id               = v_run_id,
         lots_completed_this_cycle = 0,
         last_error                = NULL
   WHERE source_id = p_source_id;

  -- 6. TODO Lot 3b : appel pg_net vers l'EF harvest-oai-pmh
  --    Pour l'instant on retourne l'info du run créé.
  --    L'EF mettra à jour le run et le state après parsing.

  RETURN jsonb_build_object(
    'ok',        true,
    'run_id',    v_run_id,
    'source_id', p_source_id,
    'max_lots',  v_max,
    'endpoint',  v_source.oai_endpoint_url,
    'prefix',    v_source.oai_metadata_prefix,
    'from_date', v_state.last_harvest_at,
    'note',      'Edge Function harvest-oai-pmh pas encore deployee (Lot 3b). Run cree en attente.'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_harvest_oai(bigint, integer) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_harvest_oai(bigint, integer) TO authenticated;

COMMENT ON FUNCTION public.fn_import_harvest_oai IS
  'Lot 3a — Déclenche un moissonnage OAI-PMH pour une source donnée. '
  'Crée un run + marque le state in_progress. Lot 3b branchera l''EF.';
