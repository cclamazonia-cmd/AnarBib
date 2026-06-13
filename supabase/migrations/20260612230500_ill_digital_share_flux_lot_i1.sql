-- =========================================================================
-- Paquet ILL-I1 — Socle DB : flux de partage numérique entre biblios fédérées
-- =========================================================================
-- Date     : 2026-06-12 (UTC, parqué — re-timbrer > max au push)
-- Chantier : Importacoes/Exportacoes — face Export, sortie « partilha de documento »
-- Auteur   : Claude (Opus 4.8) pour Xavier Van Welden
--
-- BESOIN (spec-flux-partage-numerique, ILL-1..9 ; §12 remplissage)
--   Circulation de documents NUMÉRISÉS entre deux biblios AnarBib — circuit
--   DISTINCT du PEB physique et de l'OAI (qui expose des notices). N'existe que
--   comme DROIT d'un partenariat stabilisé : pas de partenariat actif portant
--   `digital_share` → pas de partage. GATÉ INACTIF tant qu'aucun partenariat
--   n'active ce droit (déjà géré par fn_partnership_set_right).
--
--   Flux (ILL-7) : demande → accepte | refuse | indisponible → numerisation
--   → transmis → cloture. Cible (ILL-1) : matériel gris NON commercialisé ;
--   demi-verrou ISBN/ISSN (ILL-2) → réoriente vers le PEB. Plafond binaire
--   public|staff_only (ILL-9, aligné CAT-B3) : un doc reçu sous staff_only
--   n'est JAMAIS catalogué (durable) — verrou §5. Trace double horodatée
--   immuable (déclaration export + accusé réception) — audit append-only (§3/§6).
--
-- CONTENU : 2 tables (RLS) + helper droit-actif + dispatch notif (découplé I4)
--   + RPC du flux + RPC d'URL signée (autorisation pour l'EF I2).
-- =========================================================================

BEGIN;

-- =========================================================================
-- 1. TABLES
-- =========================================================================

-- ─── ill_digital_shares : une ligne = une demande de partage numérique ──────
CREATE TABLE IF NOT EXISTS public.ill_digital_shares (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_library_id    uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,  -- A : demande
  source_library_id       uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,  -- B : détient/numérise
  partnership_id          uuid REFERENCES public.library_partnerships(id) ON DELETE SET NULL,
  book_id                 bigint REFERENCES public.books(id) ON DELETE SET NULL,            -- doc visé (catalogue de B)
  digital_asset_id        bigint REFERENCES public.digital_assets(id) ON DELETE SET NULL,   -- rempli à la transmission
  mode                    text NOT NULL DEFAULT 'ponctuel',   -- 'ponctuel' (sans copie) | 'durable' (libre de droits)
  plafond                 text,                                -- 'public' | 'staff_only' (déclaré à la transmission, ILL-9)
  flux_state              text NOT NULL DEFAULT 'demande',
  note                    text,
  refusal_reason          text,
  requested_by            uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  requested_at            timestamptz NOT NULL DEFAULT now(),
  responded_by            uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  responded_at            timestamptz,
  digitization_started_at timestamptz,
  transmitted_by          uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  transmitted_at          timestamptz,                         -- trace 1 : déclaration à l'export
  received_ack_at         timestamptz,                         -- trace 2 : accusé de réception
  closed_by               uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  closed_at               timestamptz,
  metadata                jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ill_mode_chk    CHECK (mode IN ('ponctuel','durable')),
  CONSTRAINT ill_plafond_chk CHECK (plafond IS NULL OR plafond IN ('public','staff_only')),
  CONSTRAINT ill_state_chk   CHECK (flux_state IN ('demande','accepte','refuse','indisponible','numerisation','transmis','cloture')),
  CONSTRAINT ill_no_self_chk CHECK (requester_library_id <> source_library_id),
  -- §5 : un document reçu sous plafond staff_only n'est JAMAIS catalogué (durable).
  CONSTRAINT ill_staffonly_never_durable_chk CHECK (NOT (plafond = 'staff_only' AND mode = 'durable'))
);

CREATE INDEX IF NOT EXISTS ill_digital_shares_requester_idx ON public.ill_digital_shares(requester_library_id);
CREATE INDEX IF NOT EXISTS ill_digital_shares_source_idx    ON public.ill_digital_shares(source_library_id);
CREATE INDEX IF NOT EXISTS ill_digital_shares_state_idx     ON public.ill_digital_shares(flux_state);
CREATE INDEX IF NOT EXISTS ill_digital_shares_book_idx      ON public.ill_digital_shares(book_id);

COMMENT ON TABLE public.ill_digital_shares IS
  'Partage numérique inter-biblios fédérées (paquet ILL-I1, spec-flux-partage-numerique). '
  'Une ligne = une demande A→B. flux_state : demande→accepte|refuse|indisponible→numerisation→transmis→cloture. '
  'Gaté par le droit digital_share d''un partenariat actif (ILL-8). Écritures via RPC fn_ill_* uniquement.';

-- ─── ill_digital_share_events : audit append-only (trace immuable) ──────────
CREATE TABLE IF NOT EXISTS public.ill_digital_share_events (
  id               bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  share_id         uuid NOT NULL REFERENCES public.ill_digital_shares(id) ON DELETE CASCADE,
  event_kind       text NOT NULL,
  actor            uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_library_id uuid REFERENCES public.libraries(id) ON DELETE SET NULL,
  payload          jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ill_event_kind_chk CHECK (event_kind IN
    ('requested','accepted','refused','unavailable','digitization_started','transmitted','received_ack','closed'))
);

CREATE INDEX IF NOT EXISTS ill_digital_share_events_share_idx ON public.ill_digital_share_events(share_id);

COMMENT ON TABLE public.ill_digital_share_events IS
  'Audit immuable du flux de partage numérique (paquet ILL-I1). Append-only (aucun UPDATE/DELETE) : '
  'trace double horodatée (déclaration export + accusé réception) pour que chacun assume sa part (§3/§6).';

-- ─── GRANTs + RLS ───────────────────────────────────────────────────────────
GRANT SELECT ON public.ill_digital_shares       TO authenticated;
GRANT SELECT ON public.ill_digital_share_events TO authenticated;
GRANT ALL    ON public.ill_digital_shares       TO service_role;
GRANT ALL    ON public.ill_digital_share_events TO service_role;

ALTER TABLE public.ill_digital_shares       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ill_digital_share_events ENABLE ROW LEVEL SECURITY;

-- Lecture réservée au staff de l'une des deux biblios impliquées.
CREATE POLICY "ill_digital_shares_select_staff"
  ON public.ill_digital_shares FOR SELECT TO authenticated
  USING (public.user_can_act_as_staff_on_library(requester_library_id)
      OR public.user_can_act_as_staff_on_library(source_library_id));

CREATE POLICY "ill_digital_share_events_select_staff"
  ON public.ill_digital_share_events FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.ill_digital_shares s
     WHERE s.id = ill_digital_share_events.share_id
       AND (public.user_can_act_as_staff_on_library(s.requester_library_id)
         OR public.user_can_act_as_staff_on_library(s.source_library_id))
  ));

CREATE TRIGGER ill_digital_shares_set_updated_at
  BEFORE UPDATE ON public.ill_digital_shares
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- =========================================================================
-- 2. HELPERS
-- =========================================================================

-- ─── Droit actif entre deux biblios (réciproque par construction PARTNER) ───
CREATE OR REPLACE FUNCTION public.fn_partnership_has_active_right(
  p_from uuid, p_to uuid, p_right_key text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.library_partnerships lp
      JOIN public.partnership_rights pr ON pr.partnership_id = lp.id
     WHERE lp.status = 'active'
       AND pr.right_key = p_right_key
       AND ( (lp.library_id = p_from AND lp.partner_library_id = p_to)
          OR (lp.library_id = p_to   AND lp.partner_library_id = p_from) )
  );
$$;

REVOKE EXECUTE ON FUNCTION public.fn_partnership_has_active_right(uuid, uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_partnership_has_active_right(uuid, uuid, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_partnership_has_active_right(uuid, uuid, text) IS
  'Paquet ILL-I1. TRUE si un partenariat ACTIF entre p_from et p_to porte le droit p_right_key '
  '(réciproque par symétrie PARTNER). Sert de garde au flux ILL (digital_share).';

-- ─── Dispatch de notification (découplé du Lot I4 : avale toute erreur) ──────
CREATE OR REPLACE FUNCTION public.fn_internal_dispatch_ill_notification(
  p_event text, p_share_id uuid, p_extra jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault, extensions, pg_temp
AS $$
DECLARE v_url text; v_secret text;
BEGIN
  BEGIN
    v_url := regexp_replace(public.fn_internal_get_vault_secret('SUPABASE_URL'), '/+$', '')
             || '/functions/v1/notify-digital-share';
    v_secret := public.fn_internal_get_vault_secret('WEBHOOK_SECRET_NOTIFY_DIGITAL_SHARE');
    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object('Content-Type','application/json','x-webhook-secret', v_secret),
      body := jsonb_build_object('event', p_event, 'share_id', p_share_id::text, 'dispatched_at', now()) || coalesce(p_extra, '{}'::jsonb),
      timeout_milliseconds := 60000
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'fn_internal_dispatch_ill_notification: notif % non émise (%).', p_event, SQLERRM;
  END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_internal_dispatch_ill_notification(text, uuid, jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_internal_dispatch_ill_notification(text, uuid, jsonb) TO service_role;

-- ─── Append d'un événement d'audit (interne) ────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_internal_ill_log_event(
  p_share_id uuid, p_kind text, p_actor_library_id uuid, p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  INSERT INTO public.ill_digital_share_events (share_id, event_kind, actor, actor_library_id, payload)
  VALUES (p_share_id, p_kind, auth.uid(), p_actor_library_id, coalesce(p_payload, '{}'::jsonb));
$$;

REVOKE EXECUTE ON FUNCTION public.fn_internal_ill_log_event(uuid, text, uuid, jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_internal_ill_log_event(uuid, text, uuid, jsonb) TO service_role;

-- =========================================================================
-- 3. RPC DU FLUX
-- =========================================================================

-- ─── demande (requester staff) ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_ill_request(
  p_requester_library_id uuid,
  p_source_library_id    uuid,
  p_book_id              bigint,
  p_mode                 text DEFAULT 'ponctuel',
  p_note                 text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE v_id uuid; v_pid uuid; v_isbn text; v_issn text;
BEGIN
  IF p_requester_library_id IS NULL OR p_source_library_id IS NULL THEN
    RAISE EXCEPTION 'libraries_required';
  END IF;
  IF p_mode NOT IN ('ponctuel','durable') THEN
    RAISE EXCEPTION 'invalid_mode';
  END IF;

  IF NOT public.user_can_act_as_staff_on_library(p_requester_library_id) THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501', hint = 'error.ill.forbidden';
  END IF;

  -- ILL-8 : pas de partage sans droit digital_share d'un partenariat actif.
  IF NOT public.fn_partnership_has_active_right(p_requester_library_id, p_source_library_id, 'digital_share') THEN
    RAISE EXCEPTION 'ill_no_digital_share' USING hint = 'error.ill.noDigitalShare';
  END IF;

  -- ILL-2 : demi-verrou ISBN/ISSN → matériel commercialisé, réorienter vers le PEB.
  SELECT b.isbn, b.issn INTO v_isbn, v_issn FROM public.books b WHERE b.id = p_book_id;
  IF coalesce(btrim(v_isbn), '') <> '' OR coalesce(btrim(v_issn), '') <> '' THEN
    RAISE EXCEPTION 'ill_isbn_use_peb' USING hint = 'error.ill.isbnUsePeb';
  END IF;

  SELECT lp.id INTO v_pid
    FROM public.library_partnerships lp
   WHERE lp.status = 'active'
     AND lp.library_id = p_requester_library_id AND lp.partner_library_id = p_source_library_id
   LIMIT 1;

  INSERT INTO public.ill_digital_shares
    (requester_library_id, source_library_id, partnership_id, book_id, mode, note, flux_state, requested_by)
  VALUES (p_requester_library_id, p_source_library_id, v_pid, p_book_id, p_mode, p_note, 'demande', auth.uid())
  RETURNING id INTO v_id;

  PERFORM public.fn_internal_ill_log_event(v_id, 'requested', p_requester_library_id, jsonb_build_object('mode', p_mode));
  PERFORM public.fn_internal_dispatch_ill_notification('ill_requested', v_id, '{}'::jsonb);
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_ill_request(uuid, uuid, bigint, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_ill_request(uuid, uuid, bigint, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_ill_request(uuid, uuid, bigint, text, text) IS
  'Paquet ILL-I1. Le staff de la biblio demandeuse sollicite un partage numérique à une biblio source '
  'partenaire (droit digital_share actif requis). Demi-verrou ISBN/ISSN → PEB (ILL-2). État initial : demande.';

-- ─── réponses de la source : accepte / refuse / indisponible ────────────────
CREATE OR REPLACE FUNCTION public.fn_ill_respond(
  p_share_id uuid, p_decision text, p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE s public.ill_digital_shares; v_state text;
BEGIN
  IF p_decision NOT IN ('accepte','refuse','indisponible') THEN
    RAISE EXCEPTION 'invalid_decision';
  END IF;
  SELECT * INTO s FROM public.ill_digital_shares WHERE id = p_share_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'share_not_found'; END IF;
  IF NOT public.user_can_act_as_staff_on_library(s.source_library_id) THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;
  IF s.flux_state <> 'demande' THEN RAISE EXCEPTION 'invalid_state' USING detail = 'expected demande'; END IF;

  UPDATE public.ill_digital_shares
     SET flux_state = p_decision, responded_by = auth.uid(), responded_at = now(),
         refusal_reason = CASE WHEN p_decision = 'refuse' THEN p_reason ELSE refusal_reason END
   WHERE id = p_share_id;

  PERFORM public.fn_internal_ill_log_event(p_share_id,
    CASE p_decision WHEN 'accepte' THEN 'accepted' WHEN 'refuse' THEN 'refused' ELSE 'unavailable' END,
    s.source_library_id, jsonb_build_object('reason', p_reason));
  PERFORM public.fn_internal_dispatch_ill_notification('ill_' ||
    CASE p_decision WHEN 'accepte' THEN 'accepted' WHEN 'refuse' THEN 'refused' ELSE 'unavailable' END,
    p_share_id, '{}'::jsonb);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_ill_respond(uuid, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_ill_respond(uuid, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_ill_respond(uuid, text, text) IS
  'Paquet ILL-I1. La biblio source répond à une demande : accepte | refuse | indisponible (staff source).';

-- ─── numérisation (source staff) ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_ill_start_digitization(p_share_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE s public.ill_digital_shares;
BEGIN
  SELECT * INTO s FROM public.ill_digital_shares WHERE id = p_share_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'share_not_found'; END IF;
  IF NOT public.user_can_act_as_staff_on_library(s.source_library_id) THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;
  IF s.flux_state <> 'accepte' THEN RAISE EXCEPTION 'invalid_state' USING detail = 'expected accepte'; END IF;

  UPDATE public.ill_digital_shares SET flux_state = 'numerisation', digitization_started_at = now() WHERE id = p_share_id;
  PERFORM public.fn_internal_ill_log_event(p_share_id, 'digitization_started', s.source_library_id, '{}'::jsonb);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_ill_start_digitization(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_ill_start_digitization(uuid) TO authenticated;

-- ─── transmission (source staff) : pose l'asset + le plafond (déclaration export) ─
CREATE OR REPLACE FUNCTION public.fn_ill_transmit(
  p_share_id uuid, p_digital_asset_id bigint, p_plafond text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE s public.ill_digital_shares; v_is_public boolean;
BEGIN
  IF p_plafond NOT IN ('public','staff_only') THEN RAISE EXCEPTION 'invalid_plafond'; END IF;
  SELECT * INTO s FROM public.ill_digital_shares WHERE id = p_share_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'share_not_found'; END IF;
  IF NOT public.user_can_act_as_staff_on_library(s.source_library_id) THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;
  IF s.flux_state NOT IN ('accepte','numerisation') THEN
    RAISE EXCEPTION 'invalid_state' USING detail = 'expected accepte|numerisation';
  END IF;

  SELECT da.is_public INTO v_is_public FROM public.digital_assets da WHERE da.id = p_digital_asset_id;
  IF v_is_public IS NULL THEN RAISE EXCEPTION 'asset_not_found'; END IF;
  -- ILL-3 : on n'exporte jamais plus ouvert que ce qu'on assume soi-même.
  IF p_plafond = 'public' AND v_is_public = false THEN
    RAISE EXCEPTION 'plafond_exceeds_source' USING hint = 'error.ill.plafondExceeds';
  END IF;
  -- §5 : staff_only ⇒ jamais catalogué (durable) — coupe au plus tôt.
  IF p_plafond = 'staff_only' AND s.mode = 'durable' THEN
    RAISE EXCEPTION 'staffonly_not_durable' USING hint = 'error.ill.staffOnlyNotDurable';
  END IF;

  UPDATE public.ill_digital_shares
     SET flux_state = 'transmis', digital_asset_id = p_digital_asset_id, plafond = p_plafond,
         transmitted_by = auth.uid(), transmitted_at = now()
   WHERE id = p_share_id;

  PERFORM public.fn_internal_ill_log_event(p_share_id, 'transmitted', s.source_library_id,
    jsonb_build_object('plafond', p_plafond, 'asset', p_digital_asset_id));
  PERFORM public.fn_internal_dispatch_ill_notification('ill_transmitted', p_share_id, jsonb_build_object('plafond', p_plafond));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_ill_transmit(uuid, bigint, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_ill_transmit(uuid, bigint, text) TO authenticated;

COMMENT ON FUNCTION public.fn_ill_transmit(uuid, bigint, text) IS
  'Paquet ILL-I1. La source transmet le document numérisé : pose l''asset + déclare le plafond '
  '(ILL-3/9). Refuse un plafond public pour un asset non public. Trace 1 (déclaration export).';

-- ─── accusé de réception (requester staff) — trace 2 ────────────────────────
CREATE OR REPLACE FUNCTION public.fn_ill_acknowledge(p_share_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE s public.ill_digital_shares;
BEGIN
  SELECT * INTO s FROM public.ill_digital_shares WHERE id = p_share_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'share_not_found'; END IF;
  IF NOT public.user_can_act_as_staff_on_library(s.requester_library_id) THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;
  IF s.flux_state <> 'transmis' THEN RAISE EXCEPTION 'invalid_state' USING detail = 'expected transmis'; END IF;

  UPDATE public.ill_digital_shares SET received_ack_at = coalesce(received_ack_at, now()) WHERE id = p_share_id;
  PERFORM public.fn_internal_ill_log_event(p_share_id, 'received_ack', s.requester_library_id, '{}'::jsonb);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_ill_acknowledge(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_ill_acknowledge(uuid) TO authenticated;

-- ─── clôture (l'une ou l'autre biblio) ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_ill_close(p_share_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE s public.ill_digital_shares;
BEGIN
  SELECT * INTO s FROM public.ill_digital_shares WHERE id = p_share_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'share_not_found'; END IF;
  IF NOT (public.user_can_act_as_staff_on_library(s.requester_library_id)
       OR public.user_can_act_as_staff_on_library(s.source_library_id)) THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;
  IF s.flux_state = 'cloture' THEN RAISE EXCEPTION 'already_closed'; END IF;

  UPDATE public.ill_digital_shares SET flux_state = 'cloture', closed_by = auth.uid(), closed_at = now() WHERE id = p_share_id;
  PERFORM public.fn_internal_ill_log_event(p_share_id, 'closed', NULL, '{}'::jsonb);
  PERFORM public.fn_internal_dispatch_ill_notification('ill_closed', p_share_id, '{}'::jsonb);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_ill_close(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_ill_close(uuid) TO authenticated;

-- =========================================================================
-- 4. ACCÈS FICHIER (mode ponctuel §4) — autorisation pour l'EF (I2)
-- =========================================================================
-- Re-valide partenariat + digital_share + état transmis À CHAQUE APPEL, puis
-- renvoie les métadonnées de l'asset (bucket/chemin) ; l'EF mint l'URL signée
-- TTL court (aucune URL durable, aucune copie persistante en ponctuel).
CREATE OR REPLACE FUNCTION public.fn_ill_signed_url(p_share_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE s public.ill_digital_shares; da public.digital_assets;
BEGIN
  SELECT * INTO s FROM public.ill_digital_shares WHERE id = p_share_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'share_not_found'; END IF;

  -- Seul le staff de la biblio RÉCEPTRICE consulte le reçu.
  IF NOT public.user_can_act_as_staff_on_library(s.requester_library_id) THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;
  IF s.flux_state <> 'transmis' THEN RAISE EXCEPTION 'not_transmitted'; END IF;
  IF s.digital_asset_id IS NULL THEN RAISE EXCEPTION 'no_asset'; END IF;
  -- Re-validation du droit au moment de l'accès (révocable, PARTNER-D5).
  IF NOT public.fn_partnership_has_active_right(s.requester_library_id, s.source_library_id, 'digital_share') THEN
    RAISE EXCEPTION 'ill_no_digital_share' USING errcode = '42501';
  END IF;

  SELECT * INTO da FROM public.digital_assets WHERE id = s.digital_asset_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'asset_not_found'; END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'share_id', s.id,
    'plafond', s.plafond,
    'bucket_name', da.bucket_name,
    'object_path', da.object_path,
    'mime_type', da.mime_type,
    'asset_kind', da.asset_kind,
    'title', da.title
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_ill_signed_url(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_ill_signed_url(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_ill_signed_url(uuid) IS
  'Paquet ILL-I1. Autorise l''accès au reçu (mode ponctuel §4) : re-valide staff récepteur + '
  'partenariat + digital_share + état transmis À CHAQUE APPEL, puis renvoie les métadonnées de '
  'l''asset. L''EF (I2) mint une URL signée TTL court (aucune copie persistante).';

-- =========================================================================
-- 5. VÉRIFICATION
-- =========================================================================
DO $verify$
DECLARE v_tables int; v_fns int; v_rls int;
BEGIN
  SELECT count(*) INTO v_tables FROM information_schema.tables
    WHERE table_schema='public' AND table_name IN ('ill_digital_shares','ill_digital_share_events');
  IF v_tables <> 2 THEN RAISE EXCEPTION 'verify: expected 2 tables, found %', v_tables; END IF;

  SELECT count(*) INTO v_rls FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname IN ('ill_digital_shares','ill_digital_share_events') AND c.relrowsecurity;
  IF v_rls <> 2 THEN RAISE EXCEPTION 'verify: RLS not enabled on both tables (%)', v_rls; END IF;

  SELECT count(*) INTO v_fns FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN
      ('fn_partnership_has_active_right','fn_internal_dispatch_ill_notification','fn_internal_ill_log_event',
       'fn_ill_request','fn_ill_respond','fn_ill_start_digitization','fn_ill_transmit',
       'fn_ill_acknowledge','fn_ill_close','fn_ill_signed_url');
  IF v_fns <> 10 THEN RAISE EXCEPTION 'verify: expected 10 fn_ill/partnership functions, found %', v_fns; END IF;

  RAISE NOTICE 'paquet ILL-I1 OK : 2 tables (RLS), 10 fonctions. Tables vides a la creation.';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé (à adapter) :
-- =========================================================================
-- BEGIN;
--   DROP FUNCTION IF EXISTS public.fn_ill_signed_url(uuid);
--   DROP FUNCTION IF EXISTS public.fn_ill_close(uuid);
--   DROP FUNCTION IF EXISTS public.fn_ill_acknowledge(uuid);
--   DROP FUNCTION IF EXISTS public.fn_ill_transmit(uuid,bigint,text);
--   DROP FUNCTION IF EXISTS public.fn_ill_start_digitization(uuid);
--   DROP FUNCTION IF EXISTS public.fn_ill_respond(uuid,text,text);
--   DROP FUNCTION IF EXISTS public.fn_ill_request(uuid,uuid,bigint,text,text);
--   DROP FUNCTION IF EXISTS public.fn_internal_ill_log_event(uuid,text,uuid,jsonb);
--   DROP FUNCTION IF EXISTS public.fn_internal_dispatch_ill_notification(text,uuid,jsonb);
--   DROP FUNCTION IF EXISTS public.fn_partnership_has_active_right(uuid,uuid,text);
--   DROP TABLE IF EXISTS public.ill_digital_share_events;
--   DROP TABLE IF EXISTS public.ill_digital_shares;
-- COMMIT;
-- =========================================================================
