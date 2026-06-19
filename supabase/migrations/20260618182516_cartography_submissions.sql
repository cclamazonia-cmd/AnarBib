-- =========================================================================
-- Paquet CARTO-7 — Auto-déclaration « ajouter ma biblio » (MAP-J)
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : Cartographie du réseau (REGISTRE §34) — MAP-J
-- Auteur   : AnarBib · Session : Carte réseau 10 locales
-- Branche  : carto-7-autodeclaration (NON mergée — à relire avant déploiement)
--
-- Décisions tranchées (cf. CADRAGE_cartographie_autodeclaration_2026-06-18) :
--   J-A anonyme + Turnstile ; J-B SA biblio uniquement ; J-C table de staging
--   dédiée ; J-D approbation → fiche « cible » NON publique ; J-E modération
--   network_administrators ; J-F Turnstile + rate-limit ; J-G pin soumetteur ;
--   J-H notif outbox → notify-event (fede@anarbib.org) ; J-I champs minimaux.
--
-- Soumission (anon) via l'Edge Function publique submit-cartography-entry
-- (service_role) → INSERT cartography_submissions → trigger enfile l'outbox.
-- Modération (coordination) via RPC SECDEF gardées fn_caller_is_network_admin.
-- =========================================================================

BEGIN;

-- ── 1) Table de staging (verrouillée — Scénario C) ───────────────────────────
CREATE TABLE public.cartography_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  -- payload soumis (mono-langue : la langue du collectif)
  name text NOT NULL,
  city text,
  country text,
  categorie text NOT NULL CHECK (categorie IN
    ('biblioteca','arquivo','centro_doc','ateneu','livraria','misto')),
  langue_fonds text[] NOT NULL DEFAULT '{}'::text[],
  site_url text,
  -- contacts optionnels (N2, privés)
  email text,
  tel text,
  adresse text,
  notes text,
  notes_locale text,                    -- langue de name/city/country/notes
  submitter_note text,                  -- message libre (« c'est ma biblio »)
  lat numeric(9,5),
  lon numeric(9,5),
  source_ip_hash text,                  -- anti-abus (haché, jamais l'IP en clair)
  created_at timestamptz NOT NULL DEFAULT now(),
  -- modération
  reviewed_by uuid REFERENCES auth.users(id),
  reviewed_at timestamptz,
  review_note text,
  created_entry_id uuid REFERENCES public.cartography_entries(id) ON DELETE SET NULL
);
CREATE INDEX cartography_submissions_pending_idx ON public.cartography_submissions(created_at) WHERE status = 'pending';

REVOKE ALL ON public.cartography_submissions FROM anon, authenticated;
GRANT ALL ON public.cartography_submissions TO service_role;
ALTER TABLE public.cartography_submissions ENABLE ROW LEVEL SECURITY;
-- Aucune policy permissive : écriture par l'EF (service_role), lecture/modération via RPC SECDEF.

COMMENT ON TABLE public.cartography_submissions IS
  'Auto-déclarations « ajouter ma biblio » (MAP-J, paquet CARTO-7). Staging non vérifié : '
  'insert par l''Edge Function publique submit-cartography-entry (service_role) ; modération par '
  'la coordination via RPC SECDEF. À l''approbation → crée une fiche cartography_entries « cible » '
  'non publique. Table verrouillée (Scénario C).';

-- ── 2) Outbox de notification (enfilé par trigger ; consommé par notify-event) ─
CREATE TABLE public.cartography_submission_notification_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES public.cartography_submissions(id) ON DELETE CASCADE,
  event text NOT NULL DEFAULT 'cartography.submission_received',
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','sent','failed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  error text
);
CREATE INDEX cartography_submission_outbox_queued_idx ON public.cartography_submission_notification_outbox(created_at) WHERE status = 'queued';
REVOKE ALL ON public.cartography_submission_notification_outbox FROM anon, authenticated;
GRANT ALL ON public.cartography_submission_notification_outbox TO service_role;
ALTER TABLE public.cartography_submission_notification_outbox ENABLE ROW LEVEL SECURITY;
COMMENT ON TABLE public.cartography_submission_notification_outbox IS
  'File d''événements d''auto-déclaration carto (CARTO-7). Une ligne par soumission, enfilée par '
  'tg_cartography_submission_enqueue ; à consommer par le dispatcher notify-event → fede@anarbib.org. '
  'Modèle gazette_submission_notification_outbox.';

CREATE OR REPLACE FUNCTION public.fn_cartography_submission_enqueue()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
BEGIN
  INSERT INTO public.cartography_submission_notification_outbox (submission_id, event)
  VALUES (NEW.id, 'cartography.submission_received');
  RETURN NEW;
END $$;
ALTER FUNCTION public.fn_cartography_submission_enqueue() OWNER TO postgres;
CREATE TRIGGER tg_cartography_submission_enqueue
  AFTER INSERT ON public.cartography_submissions
  FOR EACH ROW EXECUTE FUNCTION public.fn_cartography_submission_enqueue();

-- ── 3) RPC de modération (coordination réseau, SECDEF) ────────────────────────
CREATE OR REPLACE FUNCTION api.fn_cartography_submission_list()
RETURNS TABLE (
  id uuid, status text, name text, city text, country text, categorie text,
  langue_fonds text[], site_url text, email text, tel text, adresse text,
  notes text, notes_locale text, submitter_note text, lat numeric, lon numeric,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: network admin only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
    SELECT s.id, s.status, s.name, s.city, s.country, s.categorie, s.langue_fonds, s.site_url,
           s.email, s.tel, s.adresse, s.notes, s.notes_locale, s.submitter_note, s.lat, s.lon, s.created_at
    FROM public.cartography_submissions s
    WHERE s.status = 'pending'
    ORDER BY s.created_at;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_cartography_submission_list() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_cartography_submission_list() TO authenticated;
COMMENT ON FUNCTION api.fn_cartography_submission_list() IS 'Liste les auto-déclarations en attente (network admin). Paquet CARTO-7.';

CREATE OR REPLACE FUNCTION api.fn_cartography_submission_approve(p_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
DECLARE s public.cartography_submissions%ROWTYPE; v_loc text; v_entry uuid;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: network admin only' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO s FROM public.cartography_submissions WHERE id = p_id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not found or already reviewed' USING ERRCODE = 'no_data_found';
  END IF;
  v_loc := COALESCE(NULLIF(s.notes_locale, ''), 'fr');
  INSERT INTO public.cartography_entries (
    name_i18n, city_i18n, country_i18n, notes_i18n,
    categorie, statut_anarbib, statut_geo, statut_public, contact_public,
    lat, lon, langue_fonds, site_url, adresse, email, tel, source, updated_by
  ) VALUES (
    jsonb_build_object(v_loc, COALESCE(s.name, '')),
    jsonb_build_object(v_loc, COALESCE(s.city, '')),
    jsonb_build_object(v_loc, COALESCE(s.country, '')),
    jsonb_build_object(v_loc, COALESCE(s.notes, '')),
    s.categorie, 'cible', 'ville', false, false,
    COALESCE(s.lat, 0), COALESCE(s.lon, 0), s.langue_fonds, s.site_url, s.adresse, s.email, s.tel,
    'auto-déclaration (MAP-J)', auth.uid()
  ) RETURNING id INTO v_entry;
  UPDATE public.cartography_submissions
    SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = now(), created_entry_id = v_entry
    WHERE id = p_id;
  RETURN v_entry;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_cartography_submission_approve(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_cartography_submission_approve(uuid) TO authenticated;
COMMENT ON FUNCTION api.fn_cartography_submission_approve(uuid) IS
  'Approuve une auto-déclaration (network admin) → crée une fiche cartography_entries « cible » '
  'NON publique (statut_public=FALSE, MAP-E). Paquet CARTO-7.';

CREATE OR REPLACE FUNCTION api.fn_cartography_submission_reject(p_id uuid, p_note text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: network admin only' USING ERRCODE = '42501';
  END IF;
  UPDATE public.cartography_submissions
    SET status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now(), review_note = NULLIF(p_note, '')
    WHERE id = p_id AND status = 'pending';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not found or already reviewed' USING ERRCODE = 'no_data_found';
  END IF;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_cartography_submission_reject(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_cartography_submission_reject(uuid, text) TO authenticated;
COMMENT ON FUNCTION api.fn_cartography_submission_reject(uuid, text) IS
  'Refuse une auto-déclaration (network admin) ; conserve la trace (mémoire). Paquet CARTO-7.';

COMMIT;
