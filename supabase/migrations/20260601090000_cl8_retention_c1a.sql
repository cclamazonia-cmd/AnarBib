-- =====================================================================
-- Migration : #CL.8 rétention historique lectrice — paquet C.1a (réversible)
-- Réf doctrine : docs/specs/spec-historico-retencao-lectrice.md v1.0
-- Granularité : option A (granularité d'affichage)
--   - emprunts   : is_hidden sur emprestimos_v2 (racine, affichage agrège)
--   - réservations : is_hidden sur reserva_linhas_v2 (ligne = affichage)
--   - consultations : is_hidden sur consulta_linhas_v2 (ligne = affichage)
-- Architecture lecture : δ-PostgREST (flag en projection des vues, filtre serveur côté frontend)
-- NE CONTIENT PAS : RPC de suppression physique (paquet C.1b, après audit FK)
-- =====================================================================

BEGIN;

-- =====================================================================
-- 1. Colonnes is_hidden_by_user + hidden_at (option A)
-- =====================================================================

ALTER TABLE public.emprestimos_v2
  ADD COLUMN IF NOT EXISTS is_hidden_by_user boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hidden_at timestamptz;

ALTER TABLE public.reserva_linhas_v2
  ADD COLUMN IF NOT EXISTS is_hidden_by_user boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hidden_at timestamptz;

ALTER TABLE public.consulta_linhas_v2
  ADD COLUMN IF NOT EXISTS is_hidden_by_user boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hidden_at timestamptz;

-- =====================================================================
-- 2. Table de préférences prospectives par biblio (Scénario C — lock-down)
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.user_history_retention_preferences (
  user_id           uuid NOT NULL REFERENCES auth.users(id)      ON DELETE CASCADE,
  library_id        uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  domain            text NOT NULL CHECK (domain IN ('loans','reservations','consultations')),
  disable_retention boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, library_id, domain)
);

-- Scénario C : table hors Data API, manipulée uniquement par RPC SECURITY DEFINER.
ALTER TABLE public.user_history_retention_preferences ENABLE ROW LEVEL SECURITY;
-- Aucune policy : lock-down total. Les RPC SECURITY DEFINER (propriétaire) bypassent la RLS.
REVOKE ALL ON public.user_history_retention_preferences FROM PUBLIC;
REVOKE ALL ON public.user_history_retention_preferences FROM anon;
REVOKE ALL ON public.user_history_retention_preferences FROM authenticated;
-- GRANT à service_role seul (doctrine Scénario C) : bypass RLS pour EF/admin, accès direct interdit aux rôles client.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_history_retention_preferences TO service_role;

-- =====================================================================
-- 3. RPC de masquage / réaffichage (réversibles)
-- =====================================================================

-- 3.1 — Masquer une ligne d'historique en état terminal
CREATE OR REPLACE FUNCTION public.fn_hide_history_item(p_domain text, p_record_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_count integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING HINT = 'history.error.not_authenticated';
  END IF;

  IF p_domain = 'loans' THEN
    UPDATE public.emprestimos_v2
       SET is_hidden_by_user = true, hidden_at = now()
     WHERE id = p_record_id
       AND user_id = v_uid
       AND status_global = 'encerrado';
    GET DIAGNOSTICS v_count = ROW_COUNT;

  ELSIF p_domain = 'reservations' THEN
    UPDATE public.reserva_linhas_v2 rl
       SET is_hidden_by_user = true, hidden_at = now()
      FROM public.reservas_v2 r
     WHERE rl.id = p_record_id
       AND rl.reserva_id = r.id
       AND r.user_id = v_uid
       AND rl.item_status IN ('cancelada_leitor','cancelada_biblioteca','convertida_em_emprestimo','expirada','liberada_para_circulacao');
    GET DIAGNOSTICS v_count = ROW_COUNT;

  ELSIF p_domain = 'consultations' THEN
    UPDATE public.consulta_linhas_v2 cl
       SET is_hidden_by_user = true, hidden_at = now()
      FROM public.consultas_locais_v2 c
     WHERE cl.id = p_record_id
       AND cl.consulta_id = c.id
       AND c.user_id = v_uid
       AND cl.item_status IN ('consultada','cancelada_leitor','cancelada_biblioteca','expirada');
    GET DIAGNOSTICS v_count = ROW_COUNT;

  ELSE
    RAISE EXCEPTION 'invalid_domain' USING HINT = 'history.error.invalid_domain';
  END IF;

  IF v_count = 0 THEN
    RAISE EXCEPTION 'item_not_found_or_not_terminal' USING HINT = 'history.error.not_found_or_active';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_hide_history_item(text, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_hide_history_item(text, bigint) TO authenticated;

-- 3.2 — Réafficher une ligne précédemment masquée (toujours autorisé)
CREATE OR REPLACE FUNCTION public.fn_unhide_history_item(p_domain text, p_record_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_count integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING HINT = 'history.error.not_authenticated';
  END IF;

  IF p_domain = 'loans' THEN
    UPDATE public.emprestimos_v2
       SET is_hidden_by_user = false, hidden_at = NULL
     WHERE id = p_record_id AND user_id = v_uid;
    GET DIAGNOSTICS v_count = ROW_COUNT;

  ELSIF p_domain = 'reservations' THEN
    UPDATE public.reserva_linhas_v2 rl
       SET is_hidden_by_user = false, hidden_at = NULL
      FROM public.reservas_v2 r
     WHERE rl.id = p_record_id AND rl.reserva_id = r.id AND r.user_id = v_uid;
    GET DIAGNOSTICS v_count = ROW_COUNT;

  ELSIF p_domain = 'consultations' THEN
    UPDATE public.consulta_linhas_v2 cl
       SET is_hidden_by_user = false, hidden_at = NULL
      FROM public.consultas_locais_v2 c
     WHERE cl.id = p_record_id AND cl.consulta_id = c.id AND c.user_id = v_uid;
    GET DIAGNOSTICS v_count = ROW_COUNT;

  ELSE
    RAISE EXCEPTION 'invalid_domain' USING HINT = 'history.error.invalid_domain';
  END IF;

  IF v_count = 0 THEN
    RAISE EXCEPTION 'item_not_found' USING HINT = 'history.error.not_found';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_unhide_history_item(text, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_unhide_history_item(text, bigint) TO authenticated;

-- =====================================================================
-- 4. RPC de préférences prospectives (get / set)
-- =====================================================================

-- 4.1 — Lire ses préférences
CREATE OR REPLACE FUNCTION public.fn_get_my_retention_preferences()
RETURNS TABLE(library_id uuid, domain text, disable_retention boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING HINT = 'history.error.not_authenticated';
  END IF;
  RETURN QUERY
    SELECT p.library_id, p.domain, p.disable_retention
      FROM public.user_history_retention_preferences p
     WHERE p.user_id = v_uid;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_get_my_retention_preferences() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_get_my_retention_preferences() TO authenticated;

-- 4.2 — Définir une préférence prospective (upsert)
CREATE OR REPLACE FUNCTION public.fn_set_my_retention_preference(
  p_library_id uuid, p_domain text, p_disable boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING HINT = 'history.error.not_authenticated';
  END IF;

  IF p_domain NOT IN ('loans','reservations','consultations') THEN
    RAISE EXCEPTION 'invalid_domain' USING HINT = 'history.error.invalid_domain';
  END IF;

  -- La lectrice doit avoir une appartenance à cette biblio (toute appartenance, même inactive,
  -- car la préférence est prospective et peut précéder une réactivation).
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
     WHERE m.user_id = v_uid AND m.library_id = p_library_id
  ) THEN
    RAISE EXCEPTION 'not_a_member' USING HINT = 'history.error.not_a_member';
  END IF;

  INSERT INTO public.user_history_retention_preferences (user_id, library_id, domain, disable_retention)
  VALUES (v_uid, p_library_id, p_domain, p_disable)
  ON CONFLICT (user_id, library_id, domain)
  DO UPDATE SET disable_retention = EXCLUDED.disable_retention, updated_at = now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_set_my_retention_preference(uuid, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_set_my_retention_preference(uuid, text, boolean) TO authenticated;

-- =====================================================================
-- 5. Triggers de masquage prospectif (D.7) — fonctions privées SECURITY DEFINER
-- =====================================================================

-- 5.1 — Emprunts : à la clôture (status_global -> encerrado)
CREATE OR REPLACE FUNCTION public.fn_auto_hide_loans_on_close()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_disable boolean;
BEGIN
  SELECT disable_retention INTO v_disable
    FROM public.user_history_retention_preferences
   WHERE user_id = NEW.user_id AND library_id = NEW.library_id AND domain = 'loans';
  IF v_disable IS TRUE THEN
    NEW.is_hidden_by_user := true;
    NEW.hidden_at := now();
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_loans_on_close() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_loans_on_close() FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_loans_on_close() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_loans_on_close() FROM service_role;

DROP TRIGGER IF EXISTS trg_auto_hide_loans_on_close ON public.emprestimos_v2;
CREATE TRIGGER trg_auto_hide_loans_on_close
  BEFORE UPDATE ON public.emprestimos_v2
  FOR EACH ROW
  WHEN (NEW.status_global = 'encerrado' AND OLD.status_global IS DISTINCT FROM NEW.status_global)
  EXECUTE FUNCTION public.fn_auto_hide_loans_on_close();

-- 5.2 — Réservations : à la clôture d'une ligne (item_status -> terminal)
CREATE OR REPLACE FUNCTION public.fn_auto_hide_reserva_linha_on_close()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_disable    boolean;
  v_user_id    uuid;
  v_library_id uuid;
BEGIN
  SELECT r.user_id, r.library_id INTO v_user_id, v_library_id
    FROM public.reservas_v2 r WHERE r.id = NEW.reserva_id;

  SELECT disable_retention INTO v_disable
    FROM public.user_history_retention_preferences
   WHERE user_id = v_user_id AND library_id = v_library_id AND domain = 'reservations';

  IF v_disable IS TRUE THEN
    NEW.is_hidden_by_user := true;
    NEW.hidden_at := now();
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_reserva_linha_on_close() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_reserva_linha_on_close() FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_reserva_linha_on_close() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_reserva_linha_on_close() FROM service_role;

DROP TRIGGER IF EXISTS trg_auto_hide_reserva_linha_on_close ON public.reserva_linhas_v2;
CREATE TRIGGER trg_auto_hide_reserva_linha_on_close
  BEFORE UPDATE ON public.reserva_linhas_v2
  FOR EACH ROW
  WHEN (NEW.item_status IN ('cancelada_leitor','cancelada_biblioteca','convertida_em_emprestimo','expirada','liberada_para_circulacao')
        AND OLD.item_status IS DISTINCT FROM NEW.item_status)
  EXECUTE FUNCTION public.fn_auto_hide_reserva_linha_on_close();

-- 5.3 — Consultations : à la clôture d'une ligne (item_status -> terminal)
CREATE OR REPLACE FUNCTION public.fn_auto_hide_consulta_linha_on_close()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_disable    boolean;
  v_user_id    uuid;
  v_library_id uuid;
BEGIN
  SELECT c.user_id, c.library_id INTO v_user_id, v_library_id
    FROM public.consultas_locais_v2 c WHERE c.id = NEW.consulta_id;

  SELECT disable_retention INTO v_disable
    FROM public.user_history_retention_preferences
   WHERE user_id = v_user_id AND library_id = v_library_id AND domain = 'consultations';

  IF v_disable IS TRUE THEN
    NEW.is_hidden_by_user := true;
    NEW.hidden_at := now();
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_consulta_linha_on_close() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_consulta_linha_on_close() FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_consulta_linha_on_close() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_auto_hide_consulta_linha_on_close() FROM service_role;

DROP TRIGGER IF EXISTS trg_auto_hide_consulta_linha_on_close ON public.consulta_linhas_v2;
CREATE TRIGGER trg_auto_hide_consulta_linha_on_close
  BEFORE UPDATE ON public.consulta_linhas_v2
  FOR EACH ROW
  WHEN (NEW.item_status IN ('consultada','cancelada_leitor','cancelada_biblioteca','expirada')
        AND OLD.item_status IS DISTINCT FROM NEW.item_status)
  EXECUTE FUNCTION public.fn_auto_hide_consulta_linha_on_close();

-- =====================================================================
-- 6. Trigger de synchronisation history_enabled (option ρ)
--    Maintient user_library_memberships.history_enabled pour fn_export_my_data.
--    history_enabled = false ssi les 3 domaines sont tous disable_retention = true.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_sync_history_enabled()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id     uuid;
  v_library_id  uuid;
  v_all_disabled boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_user_id := OLD.user_id;  v_library_id := OLD.library_id;
  ELSE
    v_user_id := NEW.user_id;  v_library_id := NEW.library_id;
  END IF;

  SELECT (COUNT(*) FILTER (WHERE disable_retention = true) = 3)
    INTO v_all_disabled
    FROM public.user_history_retention_preferences
   WHERE user_id = v_user_id AND library_id = v_library_id;

  UPDATE public.user_library_memberships
     SET history_enabled = NOT v_all_disabled
   WHERE user_id = v_user_id AND library_id = v_library_id;

  IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_sync_history_enabled() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_sync_history_enabled() FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_sync_history_enabled() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_sync_history_enabled() FROM service_role;

DROP TRIGGER IF EXISTS trg_sync_history_enabled ON public.user_history_retention_preferences;
CREATE TRIGGER trg_sync_history_enabled
  AFTER INSERT OR UPDATE OR DELETE ON public.user_history_retention_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_history_enabled();

-- =====================================================================
-- 7. Vérification DO-block (doctrine : auto-vérification en transaction)
-- =====================================================================

DO $$
DECLARE
  v_missing text := '';
BEGIN
  -- Colonnes
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='emprestimos_v2' AND column_name='is_hidden_by_user')
    THEN v_missing := v_missing || 'emprestimos_v2.is_hidden_by_user; '; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='reserva_linhas_v2' AND column_name='is_hidden_by_user')
    THEN v_missing := v_missing || 'reserva_linhas_v2.is_hidden_by_user; '; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='consulta_linhas_v2' AND column_name='is_hidden_by_user')
    THEN v_missing := v_missing || 'consulta_linhas_v2.is_hidden_by_user; '; END IF;

  -- Table
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='user_history_retention_preferences')
    THEN v_missing := v_missing || 'table user_history_retention_preferences; '; END IF;

  -- RPC
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname='fn_hide_history_item')
    THEN v_missing := v_missing || 'fn_hide_history_item; '; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname='fn_set_my_retention_preference')
    THEN v_missing := v_missing || 'fn_set_my_retention_preference; '; END IF;

  -- Triggers
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_auto_hide_loans_on_close')
    THEN v_missing := v_missing || 'trg_auto_hide_loans_on_close; '; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_sync_history_enabled')
    THEN v_missing := v_missing || 'trg_sync_history_enabled; '; END IF;

  IF v_missing <> '' THEN
    RAISE EXCEPTION 'Migration C.1a incomplète, objets manquants : %', v_missing;
  END IF;

  RAISE NOTICE 'Migration C.1a : tous les objets vérifiés présents.';
END;
$$;

COMMIT;
