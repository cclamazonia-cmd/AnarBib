-- =========================================================================
-- Paquet OAI-O1 — Socle DB : gouvernance de l'ouverture du endpoint OAI-PMH
-- =========================================================================
-- Date     : 2026-06-12 (UTC 20260612153000)
-- Chantier : Importacoes/Exportacoes — face Export, Lot 5 « ser fonte » (OAI provider)
-- Auteur   : Claude (Opus 4.8) pour Xavier Van Welden
--
-- BESOIN
--   « Etre source » expose le catalogue d'AnarBib au moissonnage OAI-PMH. Ce
--   n'est jamais un simple interrupteur : l'ouverture est GOUVERNEE, a deux sens
--   (arbitrages Xavier 12/06/2026) :
--     - ASCENDANT  : le coordenador d'UNE biblio demande l'ouverture de SON
--       endpoint ; UN SEUL admin reseau suffit a approuver.
--     - DESCENDANT : les admins (au nom du reseau) ouvrent vers une entite
--       externe ; il faut un vote UNANIME des biblios concernees, 21 jours,
--       SILENCE = OUI (consentement tacite), une voix par biblio (coordenador).
--   Fermeture MANUELLE dans les deux cas (banniere d'alerte permanente cote UI).
--
--   Biblios « concernees » (sens descendant) = celles qui publient leur catalogue
--   au reseau : is_active AND visibility_level IN (public, network) AND
--   catalog_mode = network_published AND network_mode <> isolated. Les private /
--   local_only (qui ont refuse la visibilite) ne votent pas et ne sont pas exposees.
--
-- CONTENU
--   - Tables public.oai_opening_requests + public.oai_opening_votes (RLS, GRANTs).
--   - Helper d'eligibilite + dispatch de notification (decouple du Lot O4).
--   - RPC de gouvernance (DEFINER, garde-fous internes).
--   - RPC de lecture pour l'EF provider (service_role) : biblios moissonnables +
--     notices normalisees scopees biblio (forme serialize.ts).
--   - Cron quotidien de resolution des votes expires (consentement tacite).
--
-- DOCTRINE (CHANTIER_doctrine_creation_objets_securises_2026-05-12) :
--   [x] DEFINER : search_path fige, REVOKE PUBLIC, GRANT cible.
--   [x] Tables : GRANT explicites, RLS ON, policies, GRANT ALL service_role.
--   [x] Ecritures uniquement via RPC DEFINER (pas de DML direct authenticated).
-- =========================================================================

BEGIN;

-- =========================================================================
-- 1. TABLES
-- =========================================================================

-- ─── oai_opening_requests : une ligne = une demande/decision d'ouverture ────
CREATE TABLE IF NOT EXISTS public.oai_opening_requests (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind             text NOT NULL,                       -- 'library' (ascendant) | 'network' (descendant)
  library_id       uuid REFERENCES public.libraries(id) ON DELETE CASCADE,  -- ascendant : biblio visee
  external_entity  text,                                -- descendant : qui moissonne (entite externe)
  notes            text,
  status           text NOT NULL DEFAULT 'pending_admin',
  requested_by     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  requested_at     timestamptz NOT NULL DEFAULT now(),
  admin_decided_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,   -- ascendant
  admin_decided_at timestamptz,
  vote_opened_at   timestamptz,                          -- descendant
  vote_deadline    timestamptz,                          -- descendant : vote_opened_at + 21j
  resolved_at      timestamptz,                          -- descendant : moment de la resolution du vote
  closed_by        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  closed_at        timestamptz,
  closure_reason   text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT oai_opening_requests_kind_chk   CHECK (kind   IN ('library','network')),
  CONSTRAINT oai_opening_requests_status_chk CHECK (status IN ('pending_admin','pending_vote','open','refused','closed')),
  -- ascendant => library_id requis, pas d'entite externe ; descendant => l'inverse
  CONSTRAINT oai_opening_requests_shape_chk CHECK (
    (kind = 'library'  AND library_id IS NOT NULL AND external_entity IS NULL)
    OR
    (kind = 'network'  AND library_id IS NULL     AND external_entity IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS oai_opening_requests_library_idx ON public.oai_opening_requests(library_id);
CREATE INDEX IF NOT EXISTS oai_opening_requests_status_idx  ON public.oai_opening_requests(status);

COMMENT ON TABLE public.oai_opening_requests IS
  'Gouvernance OAI (paquet OAI-O1, 12/06/2026). Une ligne = une demande/decision '
  'd''ouverture du endpoint OAI-PMH. kind=library (ascendant : coordenador -> 1 admin) '
  'ou kind=network (descendant : admins -> vote unanime 21j des biblios concernees, '
  'silence=oui). Ecritures via RPC fn_oai_* uniquement. Fermeture manuelle.';

-- ─── oai_opening_votes : une voix par biblio concernee (sens descendant) ────
CREATE TABLE IF NOT EXISTS public.oai_opening_votes (
  request_id  uuid NOT NULL REFERENCES public.oai_opening_requests(id) ON DELETE CASCADE,
  library_id  uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  vote        text,                                      -- NULL = en attente ; 'yes' | 'no'
  voted_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  voted_at    timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (request_id, library_id),
  CONSTRAINT oai_opening_votes_vote_chk CHECK (vote IS NULL OR vote IN ('yes','no'))
);

COMMENT ON TABLE public.oai_opening_votes IS
  'Gouvernance OAI (paquet OAI-O1). Une voix par biblio concernee pour une '
  'proposition d''ouverture reseau (sens descendant). vote NULL = en attente ; '
  'a l''echeance des 21 jours, NULL -> oui (consentement tacite). Un seul ''no'' bloque.';

-- ─── GRANTs (Scenario : SELECT transparent reseau, ecritures via RPC) ───────
GRANT SELECT ON public.oai_opening_requests TO authenticated;
GRANT SELECT ON public.oai_opening_votes    TO authenticated;
GRANT ALL    ON public.oai_opening_requests TO service_role;
GRANT ALL    ON public.oai_opening_votes    TO service_role;

ALTER TABLE public.oai_opening_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oai_opening_votes    ENABLE ROW LEVEL SECURITY;

-- Transparence reseau de la GOUVERNANCE (demandes, statuts, echeances) : lisible
-- par tout staff connecte (aucune PII ; doctrine de transparence des agregats).
CREATE POLICY "oai_opening_requests_select_authenticated"
  ON public.oai_opening_requests FOR SELECT TO authenticated USING (true);

-- SCRUTIN SECRET au niveau individuel (arbitrage Xavier 12/06) : l'interet du vote
-- n'est PAS de voir qui a vote quoi, mais SEULEMENT si la demande atteint l'unanimite.
-- => chaque coordenador ne lit QUE la ligne de SA propre biblio (pour gerer son vote) ;
-- personne ne lit le vote des autres. La progression vers l'unanimite (comptes sans
-- identite) est exposee par fn_oai_network_vote_progress ; le verdict, par le statut
-- de la demande (open|refused). Les RPC DEFINER lisent tout (bypass RLS).
CREATE POLICY "oai_opening_votes_select_own_library"
  ON public.oai_opening_votes FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.user_library_memberships m
     WHERE m.user_id = auth.uid()
       AND m.library_id = oai_opening_votes.library_id
       AND m.status = 'active'
       AND m.role = 'coordenador'
  ));

CREATE TRIGGER oai_opening_requests_set_updated_at
  BEFORE UPDATE ON public.oai_opening_requests
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- =========================================================================
-- 2. HELPERS
-- =========================================================================

-- ─── Eligibilite « concernee » : la biblio publie-t-elle son catalogue ? ────
CREATE OR REPLACE FUNCTION public.fn_oai_library_is_harvest_eligible(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.libraries l
     WHERE l.id = p_library_id
       AND l.is_active
       AND l.visibility_level IN ('public','network')
       AND l.catalog_mode = 'network_published'
       AND l.network_mode <> 'isolated'
  );
$$;

REVOKE EXECUTE ON FUNCTION public.fn_oai_library_is_harvest_eligible(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_oai_library_is_harvest_eligible(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_oai_library_is_harvest_eligible(uuid) IS
  'Paquet OAI-O1. TRUE si la biblio publie son catalogue au reseau (is_active + '
  'visibility public/network + catalog_mode network_published + network_mode <> isolated). '
  'Definit l''ensemble des biblios « concernees » (vote descendant) et exposables.';

-- ─── Dispatch de notification (decouple du Lot O4 : avale toute erreur) ──────
CREATE OR REPLACE FUNCTION public.fn_internal_dispatch_oai_notification(
  p_event      text,
  p_request_id uuid,
  p_extra      jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault, extensions, pg_temp
AS $$
DECLARE
  v_url    text;
  v_secret text;
BEGIN
  BEGIN
    v_url := regexp_replace(public.fn_internal_get_vault_secret('SUPABASE_URL'), '/+$', '')
             || '/functions/v1/notify-oai-opening';
    v_secret := public.fn_internal_get_vault_secret('WEBHOOK_SECRET_NOTIFY_OAI_OPENING');

    PERFORM net.http_post(
      url     := v_url,
      headers := jsonb_build_object('Content-Type','application/json','x-webhook-secret', v_secret),
      body    := jsonb_build_object(
        'event',        p_event,
        'request_id',   p_request_id::text,
        'dispatched_at', now()
      ) || coalesce(p_extra, '{}'::jsonb),
      timeout_milliseconds := 60000
    );
  EXCEPTION WHEN OTHERS THEN
    -- Lot O4 (EF notify-oai-opening + secret vault) peut ne pas etre encore
    -- en place : on ne bloque jamais une ecriture de gouvernance sur la notif.
    RAISE NOTICE 'fn_internal_dispatch_oai_notification: notification % non emise (%).', p_event, SQLERRM;
  END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_internal_dispatch_oai_notification(text, uuid, jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_internal_dispatch_oai_notification(text, uuid, jsonb) TO service_role;

COMMENT ON FUNCTION public.fn_internal_dispatch_oai_notification(text, uuid, jsonb) IS
  'Paquet OAI-O1. Declenche l''EF notify-oai-opening (Lot O4) via net.http_post depuis '
  'l''adresse federale. Avale toute erreur (decouplage : la gouvernance ne depend pas '
  'de la disponibilite de la notif).';

-- =========================================================================
-- 3. RPC DE GOUVERNANCE
-- =========================================================================

-- ─── ASCENDANT : le coordenador demande l'ouverture de SA biblio ────────────
CREATE OR REPLACE FUNCTION public.fn_oai_request_open_library(
  p_library_id uuid,
  p_notes      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_authorized boolean;
  v_id         uuid;
BEGIN
  IF p_library_id IS NULL THEN
    RAISE EXCEPTION 'library_id_required';
  END IF;

  -- Coordenador actif de la biblio (decision interne) OU admin reseau.
  SELECT (
    EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = auth.uid()
         AND m.library_id = p_library_id
         AND m.status = 'active'
         AND m.role = 'coordenador'
    ) OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;

  IF NOT v_authorized THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.libraries l WHERE l.id = p_library_id AND l.is_active) THEN
    RAISE EXCEPTION 'library_not_found_or_inactive';
  END IF;

  -- Idempotence : pas deux demandes vivantes pour la meme biblio.
  IF EXISTS (
    SELECT 1 FROM public.oai_opening_requests r
     WHERE r.kind = 'library' AND r.library_id = p_library_id
       AND r.status IN ('pending_admin','open')
  ) THEN
    RAISE EXCEPTION 'oai_request_already_active';
  END IF;

  INSERT INTO public.oai_opening_requests (kind, library_id, notes, status, requested_by)
  VALUES ('library', p_library_id, p_notes, 'pending_admin', auth.uid())
  RETURNING id INTO v_id;

  PERFORM public.fn_internal_dispatch_oai_notification('oai_open_requested', v_id,
    jsonb_build_object('library_id', p_library_id::text));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_oai_request_open_library(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_oai_request_open_library(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_oai_request_open_library(uuid, text) IS
  'Paquet OAI-O1 (ascendant). Le coordenador d''une biblio (ou un admin reseau) '
  'demande l''ouverture OAI de SON catalogue. Cree une demande pending_admin et '
  'notifie l''adresse federale. Un seul admin l''approuvera ensuite.';

-- ─── ASCENDANT : un admin reseau approuve (ou refuse) ───────────────────────
CREATE OR REPLACE FUNCTION public.fn_oai_admin_decide_library(
  p_request_id uuid,
  p_approve    boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_req public.oai_opening_requests;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;

  SELECT * INTO v_req FROM public.oai_opening_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'request_not_found';
  END IF;
  IF v_req.kind <> 'library' OR v_req.status <> 'pending_admin' THEN
    RAISE EXCEPTION 'invalid_state' USING detail = 'expected library/pending_admin';
  END IF;

  UPDATE public.oai_opening_requests
     SET status = CASE WHEN p_approve THEN 'open' ELSE 'refused' END,
         admin_decided_by = auth.uid(),
         admin_decided_at = now()
   WHERE id = p_request_id;

  PERFORM public.fn_internal_dispatch_oai_notification(
    CASE WHEN p_approve THEN 'oai_open_approved' ELSE 'oai_open_refused' END,
    p_request_id,
    jsonb_build_object('library_id', v_req.library_id::text));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_oai_admin_decide_library(uuid, boolean) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_oai_admin_decide_library(uuid, boolean) TO authenticated;

COMMENT ON FUNCTION public.fn_oai_admin_decide_library(uuid, boolean) IS
  'Paquet OAI-O1 (ascendant). UN admin reseau approuve (open) ou refuse une demande '
  'd''ouverture de biblio. Notifie le coordenador via l''adresse federale.';

-- ─── DESCENDANT : un admin propose l'ouverture reseau vers une entite externe ─
CREATE OR REPLACE FUNCTION public.fn_oai_propose_network_open(
  p_external_entity text,
  p_notes           text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;
  IF p_external_entity IS NULL OR btrim(p_external_entity) = '' THEN
    RAISE EXCEPTION 'external_entity_required';
  END IF;

  INSERT INTO public.oai_opening_requests
    (kind, external_entity, notes, status, requested_by, vote_opened_at, vote_deadline)
  VALUES
    ('network', btrim(p_external_entity), p_notes, 'pending_vote', auth.uid(),
     now(), now() + interval '21 days')
  RETURNING id INTO v_id;

  -- Une voix par biblio concernee (qui publie son catalogue au reseau).
  INSERT INTO public.oai_opening_votes (request_id, library_id)
  SELECT v_id, l.id
    FROM public.libraries l
   WHERE l.is_active
     AND l.visibility_level IN ('public','network')
     AND l.catalog_mode = 'network_published'
     AND l.network_mode <> 'isolated';

  PERFORM public.fn_internal_dispatch_oai_notification('oai_network_proposed', v_id,
    jsonb_build_object('external_entity', btrim(p_external_entity)));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_oai_propose_network_open(text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_oai_propose_network_open(text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_oai_propose_network_open(text, text) IS
  'Paquet OAI-O1 (descendant). Un admin reseau propose d''ouvrir tout le catalogue '
  'reseau au moissonnage par une entite externe. Cree une consultation 21 jours et '
  'sieme une voix par biblio concernee. Silence = oui ; un seul non bloque.';

-- ─── DESCENDANT : une biblio vote (porte par son coordenador) ───────────────
CREATE OR REPLACE FUNCTION public.fn_oai_cast_vote(
  p_request_id uuid,
  p_library_id uuid,
  p_vote       text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_req       public.oai_opening_requests;
  v_remaining int;
  v_no_count  int;
BEGIN
  IF p_vote NOT IN ('yes','no') THEN
    RAISE EXCEPTION 'invalid_vote' USING detail = 'expected yes|no';
  END IF;

  -- Coordenador actif de la biblio qui vote (ou admin reseau pour depannage).
  IF NOT (
    EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = auth.uid()
         AND m.library_id = p_library_id
         AND m.status = 'active'
         AND m.role = 'coordenador'
    ) OR public.fn_caller_is_network_admin()
  ) THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;

  SELECT * INTO v_req FROM public.oai_opening_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR v_req.kind <> 'network' THEN
    RAISE EXCEPTION 'request_not_found';
  END IF;
  IF v_req.status <> 'pending_vote' THEN
    RAISE EXCEPTION 'vote_closed';
  END IF;
  IF v_req.vote_deadline <= now() THEN
    RAISE EXCEPTION 'vote_deadline_passed';
  END IF;

  UPDATE public.oai_opening_votes
     SET vote = p_vote, voted_by = auth.uid(), voted_at = now()
   WHERE request_id = p_request_id AND library_id = p_library_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'library_not_in_scope';
  END IF;

  -- Resolution anticipee : un non bloque immediatement ; tous oui ouvre.
  SELECT count(*) FILTER (WHERE vote = 'no'),
         count(*) FILTER (WHERE vote IS NULL)
    INTO v_no_count, v_remaining
    FROM public.oai_opening_votes WHERE request_id = p_request_id;

  IF v_no_count > 0 THEN
    UPDATE public.oai_opening_requests
       SET status = 'refused', resolved_at = now() WHERE id = p_request_id;
    PERFORM public.fn_internal_dispatch_oai_notification('oai_network_resolved', p_request_id,
      jsonb_build_object('outcome','refused'));
  ELSIF v_remaining = 0 THEN
    UPDATE public.oai_opening_requests
       SET status = 'open', resolved_at = now() WHERE id = p_request_id;
    PERFORM public.fn_internal_dispatch_oai_notification('oai_network_resolved', p_request_id,
      jsonb_build_object('outcome','open'));
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_oai_cast_vote(uuid, uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_oai_cast_vote(uuid, uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_oai_cast_vote(uuid, uuid, text) IS
  'Paquet OAI-O1 (descendant). Le coordenador d''une biblio concernee vote yes/no sur '
  'une proposition d''ouverture reseau. Resolution anticipee : un non -> refused, tous '
  'oui -> open. Sinon la resolution tacite se fait a l''echeance (fn_oai_resolve_expired_votes).';

-- ─── DESCENDANT : progression vers l'unanimite (agregat SANS identite) ──────
-- Scrutin secret : on n'expose QUE des comptes (concernees / consenties / en attente),
-- jamais qui a vote quoi. Par invariant de resolution anticipee, une proposition encore
-- 'pending_vote' n'a aucun 'no' (un non l'aurait basculee en refused) -> consented = oui.
CREATE OR REPLACE FUNCTION public.fn_oai_network_vote_progress(p_request_id uuid)
RETURNS TABLE(concerned int, consented int, pending int)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT count(*)::int,
         count(*) FILTER (WHERE vote = 'yes')::int,
         count(*) FILTER (WHERE vote IS NULL)::int
    FROM public.oai_opening_votes
   WHERE request_id = p_request_id;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_oai_network_vote_progress(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_oai_network_vote_progress(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_oai_network_vote_progress(uuid) IS
  'Paquet OAI-O1. Progression vers l''unanimite d''une proposition d''ouverture reseau, '
  'en COMPTES seulement (concernees / consenties / en attente) — aucune identite de '
  'votant·e. Unanimite atteinte quand pending = 0. Lisible par tout staff connecte.';

-- ─── DESCENDANT : resolution des votes expires (cron quotidien, tacite) ─────
CREATE OR REPLACE FUNCTION public.fn_oai_resolve_expired_votes()
RETURNS TABLE(resolved_open int, resolved_refused int, run_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_open    int := 0;
  v_refused int := 0;
  r         record;
BEGIN
  FOR r IN
    SELECT id FROM public.oai_opening_requests
     WHERE kind = 'network' AND status = 'pending_vote' AND vote_deadline <= now()
     FOR UPDATE
  LOOP
    IF EXISTS (SELECT 1 FROM public.oai_opening_votes WHERE request_id = r.id AND vote = 'no') THEN
      UPDATE public.oai_opening_requests SET status = 'refused', resolved_at = now() WHERE id = r.id;
      v_refused := v_refused + 1;
      PERFORM public.fn_internal_dispatch_oai_notification('oai_network_resolved', r.id,
        jsonb_build_object('outcome','refused'));
    ELSE
      -- Tout non-repondant -> oui (consentement tacite) : aucun non => open.
      UPDATE public.oai_opening_requests SET status = 'open', resolved_at = now() WHERE id = r.id;
      v_open := v_open + 1;
      PERFORM public.fn_internal_dispatch_oai_notification('oai_network_resolved', r.id,
        jsonb_build_object('outcome','open'));
    END IF;
  END LOOP;

  RETURN QUERY SELECT v_open, v_refused, now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_oai_resolve_expired_votes() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_oai_resolve_expired_votes() TO service_role;

COMMENT ON FUNCTION public.fn_oai_resolve_expired_votes() IS
  'Paquet OAI-O1 (descendant). Cron quotidien : pour chaque consultation reseau echue, '
  'consentement tacite (NULL -> oui). Un seul non -> refused, sinon open.';

-- ─── Fermeture manuelle (les deux sens) ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_oai_close_opening(
  p_request_id uuid,
  p_reason     text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_req public.oai_opening_requests;
  v_ok  boolean;
BEGIN
  SELECT * INTO v_req FROM public.oai_opening_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'request_not_found';
  END IF;
  IF v_req.status <> 'open' THEN
    RAISE EXCEPTION 'not_open';
  END IF;

  IF v_req.kind = 'library' THEN
    -- coordenador de la biblio OU admin reseau
    v_ok := EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = auth.uid() AND m.library_id = v_req.library_id
         AND m.status = 'active' AND m.role = 'coordenador'
    ) OR public.fn_caller_is_network_admin();
  ELSE
    -- ouverture reseau : admin reseau uniquement
    v_ok := public.fn_caller_is_network_admin();
  END IF;

  IF NOT v_ok THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;

  UPDATE public.oai_opening_requests
     SET status = 'closed', closed_by = auth.uid(), closed_at = now(), closure_reason = p_reason
   WHERE id = p_request_id;

  PERFORM public.fn_internal_dispatch_oai_notification('oai_closed', p_request_id, '{}'::jsonb);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_oai_close_opening(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_oai_close_opening(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_oai_close_opening(uuid, text) IS
  'Paquet OAI-O1. Fermeture MANUELLE d''une ouverture active. Ascendant : coordenador '
  'de la biblio ou admin reseau. Descendant : admin reseau. (UI : banniere d''alerte '
  'permanente tant que c''est ouvert -> refermer des le moissonnage confirme.)';

-- =========================================================================
-- 4. RPC DE LECTURE POUR L'EF PROVIDER (service_role)
-- =========================================================================

-- ─── Biblios actuellement moissonnables (ouverture active) ──────────────────
CREATE OR REPLACE FUNCTION public.fn_oai_harvestable_libraries()
RETURNS TABLE(library_id uuid, slug text, name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT l.id, l.slug, l.name
    FROM public.libraries l
   WHERE
     -- ascendant : ouverture propre a cette biblio
     EXISTS (
       SELECT 1 FROM public.oai_opening_requests r
        WHERE r.kind = 'library' AND r.status = 'open' AND r.library_id = l.id
     )
     OR
     -- descendant : une ouverture reseau active expose toutes les biblios concernees
     (
       public.fn_oai_library_is_harvest_eligible(l.id)
       AND EXISTS (SELECT 1 FROM public.oai_opening_requests r
                    WHERE r.kind = 'network' AND r.status = 'open')
     );
$$;

REVOKE EXECUTE ON FUNCTION public.fn_oai_harvestable_libraries() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_oai_harvestable_libraries() TO service_role;

COMMENT ON FUNCTION public.fn_oai_harvestable_libraries() IS
  'Paquet OAI-O1. Consommee par l''EF oai-pmh-provider (service_role). Renvoie les '
  'biblios actuellement moissonnables (ouverture ascendante propre OU ouverture reseau '
  'descendante active + biblio concernee). Une biblio fermee n''apparait jamais.';

-- ─── Notices normalisees d'une biblio moissonnable (forme serialize.ts) ─────
CREATE OR REPLACE FUNCTION public.fn_oai_harvestable_records(
  p_library_slug text,
  p_from         timestamptz DEFAULT NULL,
  p_until        timestamptz DEFAULT NULL,
  p_limit        int DEFAULT 100,
  p_offset       int DEFAULT 0,
  p_book_id      bigint DEFAULT NULL   -- non NULL => GetRecord d'une notice precise
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_lib     record;
  v_total   int;
  v_records jsonb;
  v_limit   int := least(greatest(coalesce(p_limit, 100), 1), 500);
  v_offset  int := greatest(coalesce(p_offset, 0), 0);
BEGIN
  SELECT l.id, l.slug INTO v_lib
    FROM public.libraries l
   WHERE l.slug = p_library_slug
     AND l.id IN (SELECT library_id FROM public.fn_oai_harvestable_libraries());

  IF v_lib.id IS NULL THEN
    -- biblio inconnue OU non ouverte au moissonnage : rien.
    RETURN jsonb_build_object('ok', false, 'reason', 'not_open', 'records', '[]'::jsonb, 'total', 0);
  END IF;

  SELECT count(*) INTO v_total
    FROM public.books b
   WHERE EXISTS (SELECT 1 FROM public.book_holdings h
                  WHERE h.book_id = b.id AND h.library_id = v_lib.id)
     AND (p_from  IS NULL OR coalesce(b.updated_at, b.created_at) >= p_from)
     AND (p_until IS NULL OR coalesce(b.updated_at, b.created_at) <= p_until)
     AND (p_book_id IS NULL OR b.id = p_book_id);

  SELECT coalesce(jsonb_agg(rec ORDER BY rec_id), '[]'::jsonb) INTO v_records
    FROM (
      SELECT
        b.id AS rec_id,
        jsonb_build_object(
          'identifier', 'oai:anarbib:' || v_lib.slug || ':' || b.id::text,
          'datestamp',  to_char(coalesce(b.updated_at, b.created_at) AT TIME ZONE 'UTC',
                                'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
          'id',             b.id,
          'bibRef',         b.bib_ref,
          'title',          b.titulo,
          'subtitle',       b.subtitulo,
          'authors', coalesce((
            SELECT jsonb_agg(jsonb_build_object('name', a.preferred_name, 'role', ba.role, 'ord', ba.ord)
                             ORDER BY ba.ord)
              FROM public.book_authors ba
              JOIN public.authors a ON a.id = ba.author_id
             WHERE ba.book_id = b.id
          ), '[]'::jsonb),
          'responsibility', b.autor,
          'publisher',      b.editora,
          'year',           b.ano,
          'place',          b.local_publicacao,
          'edition',        b.edicao,
          'isbn',           b.isbn,
          'issn',           b.issn,
          'language',       b.idioma,
          'pages',          b.paginas,
          'cdd',            b.cdd,
          'subjects',
            CASE
              WHEN coalesce(b.subjects, b.assuntos) IS NULL
                OR btrim(coalesce(b.subjects, b.assuntos)) = '' THEN '[]'::jsonb
              ELSE to_jsonb(regexp_split_to_array(btrim(coalesce(b.subjects, b.assuntos)), '\s*[;,]\s*'))
            END,
          'collection',     b.colecao,
          'materialType',   b.tipo_material,
          'notes',          b.notas
        ) AS rec
        FROM public.books b
       WHERE EXISTS (SELECT 1 FROM public.book_holdings h
                      WHERE h.book_id = b.id AND h.library_id = v_lib.id)
         AND (p_from  IS NULL OR coalesce(b.updated_at, b.created_at) >= p_from)
         AND (p_until IS NULL OR coalesce(b.updated_at, b.created_at) <= p_until)
       ORDER BY b.id
       LIMIT v_limit OFFSET v_offset
    ) sub;

  RETURN jsonb_build_object(
    'ok', true,
    'library_slug', v_lib.slug,
    'total', v_total,
    'count', jsonb_array_length(v_records),
    'limit', v_limit,
    'offset', v_offset,
    'records', v_records
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_oai_harvestable_records(text, timestamptz, timestamptz, int, int, bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_oai_harvestable_records(text, timestamptz, timestamptz, int, int, bigint) TO service_role;

COMMENT ON FUNCTION public.fn_oai_harvestable_records(text, timestamptz, timestamptz, int, int, bigint) IS
  'Paquet OAI-O1. Consommee par l''EF oai-pmh-provider (service_role). Renvoie les '
  'notices normalisees (forme serialize.ts) d''une biblio SI elle est ouverte au '
  'moissonnage, sinon rien. Datestamp + identifiant OAI par notice ; from/until + '
  'pagination (limit<=500) pour le moissonnage selectif (resumptionToken) ; '
  'p_book_id non NULL => GetRecord d''une notice precise.';

-- =========================================================================
-- 5. CRON QUOTIDIEN — resolution des votes expires (consentement tacite)
-- =========================================================================
DO $$
DECLARE
  v_job_id bigint;
BEGIN
  -- Idempotence : desinscrire un eventuel job homonyme avant de (re)programmer.
  PERFORM cron.unschedule(jobid)
    FROM cron.job WHERE jobname = 'anarbib-oai-resolve-expired-votes';

  -- Creneau 3h45 (libre : 3h15 collective-removal, 3h30 circle, 3h40 peb-overdue,
  -- 3h50 deja pris). Job ACTIF d'emblee : fonction DB pure (les net.http_post de
  -- notif sont avales par le dispatch -> aucune dependance bloquante a une EF).
  SELECT cron.schedule(
    'anarbib-oai-resolve-expired-votes',
    '45 3 * * *',
    $cron$SELECT public.fn_oai_resolve_expired_votes();$cron$
  ) INTO v_job_id;
END $$;

-- =========================================================================
-- 6. VERIFICATION (rollback auto si incoherence)
-- =========================================================================
DO $verify$
DECLARE v_tables int; v_fns int; v_rls int;
BEGIN
  SELECT count(*) INTO v_tables FROM information_schema.tables
    WHERE table_schema='public' AND table_name IN ('oai_opening_requests','oai_opening_votes');
  IF v_tables <> 2 THEN RAISE EXCEPTION 'verify: expected 2 tables, found %', v_tables; END IF;

  SELECT count(*) INTO v_rls FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname IN ('oai_opening_requests','oai_opening_votes')
      AND c.relrowsecurity;
  IF v_rls <> 2 THEN RAISE EXCEPTION 'verify: RLS not enabled on both tables (% with RLS)', v_rls; END IF;

  SELECT count(*) INTO v_fns FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN
      ('fn_oai_library_is_harvest_eligible','fn_internal_dispatch_oai_notification',
       'fn_oai_request_open_library','fn_oai_admin_decide_library','fn_oai_propose_network_open',
       'fn_oai_cast_vote','fn_oai_network_vote_progress','fn_oai_resolve_expired_votes',
       'fn_oai_close_opening','fn_oai_harvestable_libraries','fn_oai_harvestable_records');
  IF v_fns <> 11 THEN RAISE EXCEPTION 'verify: expected 11 fn_oai_* functions, found %', v_fns; END IF;

  -- En contexte migration (auth.uid() NULL) les lectures EF ne doivent rien casser.
  PERFORM count(*) FROM public.fn_oai_harvestable_libraries();
  PERFORM public.fn_oai_resolve_expired_votes();

  PERFORM 1 FROM cron.job WHERE jobname = 'anarbib-oai-resolve-expired-votes';
  IF NOT FOUND THEN RAISE EXCEPTION 'verify: cron job anarbib-oai-resolve-expired-votes not scheduled'; END IF;

  RAISE NOTICE 'paquet OAI-O1 OK : 2 tables (RLS), 11 fonctions, 1 job pg_cron. Tables vides a la creation.';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback cible (a adapter) :
-- =========================================================================
-- BEGIN;
--   SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname='anarbib-oai-resolve-expired-votes';
--   DROP FUNCTION IF EXISTS public.fn_oai_harvestable_records(text,timestamptz,timestamptz,int,int,bigint);
--   DROP FUNCTION IF EXISTS public.fn_oai_harvestable_libraries();
--   DROP FUNCTION IF EXISTS public.fn_oai_close_opening(uuid,text);
--   DROP FUNCTION IF EXISTS public.fn_oai_resolve_expired_votes();
--   DROP FUNCTION IF EXISTS public.fn_oai_network_vote_progress(uuid);
--   DROP FUNCTION IF EXISTS public.fn_oai_cast_vote(uuid,uuid,text);
--   DROP FUNCTION IF EXISTS public.fn_oai_propose_network_open(text,text);
--   DROP FUNCTION IF EXISTS public.fn_oai_admin_decide_library(uuid,boolean);
--   DROP FUNCTION IF EXISTS public.fn_oai_request_open_library(uuid,text);
--   DROP FUNCTION IF EXISTS public.fn_internal_dispatch_oai_notification(text,uuid,jsonb);
--   DROP FUNCTION IF EXISTS public.fn_oai_library_is_harvest_eligible(uuid);
--   DROP TABLE IF EXISTS public.oai_opening_votes;
--   DROP TABLE IF EXISTS public.oai_opening_requests;
-- COMMIT;
-- =========================================================================
