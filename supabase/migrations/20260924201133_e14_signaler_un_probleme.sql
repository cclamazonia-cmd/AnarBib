-- ============================================================================
-- E14 — « Signaler un problème » depuis l'application, sans compte, sans Codeberg
-- (24/09/2026). Demande de Xavier du 07/09 ; deux décisions prises le 24/09 :
-- aucun pont vers Codeberg (un admin recopie à la main s'il le juge utile), et un
-- accusé de réception simple quand la personne a laissé une adresse.
--
-- Modèle : cartography_submissions (20260618182516 + 20260618234207), le seul
-- circuit public existant — table verrouillée, Edge Function publique avec preuve
-- de travail Altcha, file → notify-event, RPC de file réservées à l'admin réseau —
-- avec l'anti-flood d'authority_duplicate_reports (une seule ligne OUVERTE par
-- défaut identique : « le même défaut signalé cinq fois ne fait pas cinq courriels »).
--
-- Ce que cette migration pose :
--   1. public.bug_reports (verrouillée : insert par la fonction, service_role) ;
--   2. public.bug_report_notification_outbox + trigger d'enfilage + trigger de
--      dépêche vers notify-event — l'adresse vient de private.fn_functions_base_url()
--      (I20), jamais codée en dur ;
--   3. api.fn_bug_report_list / api.fn_bug_report_close (DEFINER, admin réseau) ;
--   4. l'usage 'bug_report' admis par fn_consume_altcha_challenge (repris de la
--      définition RÉELLE de production, md5 a8e0233f, un seul IN élargi) ;
--   5. le kind 'bug_ip' admis par auth_rate_limits_kind_check (B26 : ajouter un
--      kind = élargir la contrainte ET tests/sql/compteurs_d_abus_tests.sql).
-- Suite : tests/sql/signalements_tests.sql. Bancs : src/tests/signalar-banc.test.js.
-- Sauvegarde : les deux tables sont classées dans deploy/bg2-known-tables.txt.
-- ============================================================================

BEGIN;

-- ─── 1. Les signalements ───────────────────────────────────────────────────────
CREATE TABLE public.bug_reports (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  status          text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  what_happened   text NOT NULL CHECK (length(what_happened) BETWEEN 10 AND 4000),
  expected        text CHECK (expected IS NULL OR length(expected) <= 2000),
  steps           text CHECK (steps IS NULL OR length(steps) <= 4000),
  page_path       text CHECK (page_path IS NULL OR length(page_path) <= 300),   -- page d'origine, remplie par le front
  locale          text CHECK (locale IS NULL OR length(locale) <= 10),
  role_hint       text CHECK (role_hint IS NULL OR length(role_hint) <= 40),      -- rôle de session, si connecté·e (indicatif)
  library_hint    text CHECK (library_hint IS NULL OR length(library_hint) <= 200),
  user_agent      text CHECK (user_agent IS NULL OR length(user_agent) <= 400),   -- lu côté serveur
  reporter_email  text CHECK (reporter_email IS NULL OR length(reporter_email) <= 200), -- facultatif : accusé de réception
  source_ip_hash  text,                                                           -- anti-abus, jamais l'IP en clair
  -- Anti-flood : la même page + les 200 premiers caractères = le même défaut.
  dedup_key       text GENERATED ALWAYS AS (coalesce(page_path, '') || '|' || lower(left(what_happened, 200))) STORED,
  created_at      timestamptz NOT NULL DEFAULT now(),
  closed_by       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  closed_at       timestamptz,
  close_note      text CHECK (close_note IS NULL OR length(close_note) <= 2000)
);
CREATE INDEX bug_reports_open_idx      ON public.bug_reports (created_at) WHERE status = 'open';
CREATE INDEX bug_reports_dedup_idx     ON public.bug_reports (dedup_key)  WHERE status = 'open';
CREATE INDEX bug_reports_closed_by_idx ON public.bug_reports (closed_by);   -- FK indexée (garde B21)
REVOKE ALL ON public.bug_reports FROM anon, authenticated;
GRANT ALL ON public.bug_reports TO service_role;
ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;
COMMENT ON TABLE public.bug_reports IS
  'Signalements de problème déposés depuis l''application (E14, 24/09/2026), sans compte. '
  'Insert par l''Edge Function publique submit-bug-report (service_role, Altcha + compteur bug_ip) ; '
  'lecture et clôture par l''admin réseau via api.fn_bug_report_list / _close. Aucun pont vers Codeberg : '
  'un admin recopie à la main s''il le juge utile. Table verrouillée (RLS, aucune policy : DOC-RPC-3).';
COMMENT ON COLUMN public.bug_reports.dedup_key IS
  'page_path + 200 premiers caractères en minuscules : un signalement identique encore OUVERT n''en crée pas un second (la fonction renvoie l''existant).';

-- ─── 2. La file vers notify-event ─────────────────────────────────────────────
CREATE TABLE public.bug_report_notification_outbox (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event             text NOT NULL,
  payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  status            text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'sent', 'failed', 'skipped')),
  pg_net_request_id bigint,
  attempts          integer NOT NULL DEFAULT 0,
  last_error        text,
  skip_reason       text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  sent_at           timestamptz
);
CREATE INDEX bug_report_outbox_queued_idx ON public.bug_report_notification_outbox (created_at) WHERE status = 'queued';
REVOKE ALL ON public.bug_report_notification_outbox FROM anon, authenticated;
GRANT ALL ON public.bug_report_notification_outbox TO service_role;
ALTER TABLE public.bug_report_notification_outbox ENABLE ROW LEVEL SECURITY;
COMMENT ON TABLE public.bug_report_notification_outbox IS
  'File des signalements (E14). Une ligne par signalement neuf (event bug_report.received + payload), '
  'enfilée par tg_bug_report_enqueue, dépêchée vers notify-event par tg_bug_report_outbox_dispatch. '
  'Modèle cartography_submission_notification_outbox. Le handler _shared/domain/bug-report.ts pose sent/failed/skipped.';

CREATE OR REPLACE FUNCTION public.fn_bug_report_enqueue()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
BEGIN
  INSERT INTO public.bug_report_notification_outbox (event, payload)
  VALUES (
    'bug_report.received',
    jsonb_build_object(
      'report_id',      NEW.id,
      'what_happened',  NEW.what_happened,
      'expected',       NEW.expected,
      'steps',          NEW.steps,
      'page_path',      NEW.page_path,
      'locale',         NEW.locale,
      'role_hint',      NEW.role_hint,
      'library_hint',   NEW.library_hint,
      'user_agent',     NEW.user_agent,
      'reporter_email', NEW.reporter_email,
      'created_at',     NEW.created_at
    )
  );
  RETURN NEW;
END $$;
ALTER FUNCTION public.fn_bug_report_enqueue() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_bug_report_enqueue() FROM PUBLIC;
CREATE TRIGGER tg_bug_report_enqueue
  AFTER INSERT ON public.bug_reports
  FOR EACH ROW EXECUTE FUNCTION public.fn_bug_report_enqueue();

-- Dépêche : même mécanique que fn_cartography_outbox_dispatch_trigger, mais
-- l'adresse de notify-event vient du réglage de l'instance (I20), pas d'un littéral.
CREATE OR REPLACE FUNCTION public.fn_bug_report_outbox_dispatch_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_url text;
  v_secret text;
  v_request_id bigint;
BEGIN
  v_url := private.fn_functions_base_url() || '/functions/v1/notify-event';
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'WEBHOOK_SECRET_NOTIFY_EVENT';
  IF v_secret IS NULL OR v_secret = '' THEN
    UPDATE public.bug_report_notification_outbox
       SET status = 'failed', last_error = 'WEBHOOK_SECRET_NOTIFY_EVENT vide ou introuvable dans vault', attempts = attempts + 1
     WHERE id = NEW.id;
    RETURN NEW;
  END IF;
  BEGIN
    SELECT net.http_post(
      url := v_url,
      body := jsonb_build_object('event', NEW.event, 'record_id', NEW.id),
      headers := jsonb_build_object('content-type', 'application/json', 'x-webhook-secret', v_secret)
    ) INTO v_request_id;
    UPDATE public.bug_report_notification_outbox
       SET pg_net_request_id = v_request_id, attempts = attempts + 1
     WHERE id = NEW.id;
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.bug_report_notification_outbox
       SET status = 'failed', last_error = SQLERRM, attempts = attempts + 1
     WHERE id = NEW.id;
  END;
  RETURN NEW;
END $$;
ALTER FUNCTION public.fn_bug_report_outbox_dispatch_trigger() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_bug_report_outbox_dispatch_trigger() FROM PUBLIC;
CREATE TRIGGER tg_bug_report_outbox_dispatch
  AFTER INSERT ON public.bug_report_notification_outbox
  FOR EACH ROW EXECUTE FUNCTION public.fn_bug_report_outbox_dispatch_trigger();

-- ─── 3. La file, côté admin réseau ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.fn_bug_report_list()
RETURNS TABLE (
  id uuid, status text, what_happened text, expected text, steps text, page_path text,
  locale text, role_hint text, library_hint text, user_agent text, reporter_email text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: network admin only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
    SELECT r.id, r.status, r.what_happened, r.expected, r.steps, r.page_path,
           r.locale, r.role_hint, r.library_hint, r.user_agent, r.reporter_email, r.created_at
    FROM public.bug_reports r
    WHERE r.status = 'open'
    ORDER BY r.created_at;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_bug_report_list() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_bug_report_list() TO authenticated;
COMMENT ON FUNCTION api.fn_bug_report_list() IS
  'Signalements ouverts (E14). Admin réseau seulement (42501 sinon). Verdict : AUDIT_execute_authenticated_2026-09-01, complément du 24/09.';

CREATE OR REPLACE FUNCTION api.fn_bug_report_close(p_id uuid, p_note text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: network admin only' USING ERRCODE = '42501';
  END IF;
  UPDATE public.bug_reports
     SET status = 'closed', closed_by = auth.uid(), closed_at = now(), close_note = nullif(left(p_note, 2000), '')
   WHERE id = p_id AND status = 'open';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'signalement introuvable ou déjà clos : %', p_id USING ERRCODE = 'P0002';
  END IF;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_bug_report_close(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_bug_report_close(uuid, text) TO authenticated;
COMMENT ON FUNCTION api.fn_bug_report_close(uuid, text) IS
  'Clôt un signalement ouvert (E14), avec une note facultative. Admin réseau seulement. Verdict : AUDIT_execute_authenticated_2026-09-01, complément du 24/09.';

-- ─── 4. Altcha : l'usage 'bug_report' ─────────────────────────────────────────
-- Corps repris de la définition RÉELLE en production le 24/09 (md5 du prosrc :
-- a8e0233fd8a8d575eefacf10cae5f07f) ; un seul changement, la liste des usages.
CREATE OR REPLACE FUNCTION public.fn_consume_altcha_challenge(p_challenge text, p_expires_at timestamp with time zone, p_purpose text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_insere boolean;
begin
  if p_purpose not in ('register', 'cartography', 'bug_report') then
    raise exception 'usage inconnu : %', p_purpose using errcode = '22023';
  end if;

  -- Un défi déjà périmé n'a pas à être accepté, même s'il est neuf.
  if p_expires_at <= now() then
    return false;
  end if;

  insert into public.altcha_consumed_challenges (challenge, expires_at, purpose)
  values (p_challenge, p_expires_at, p_purpose)
  on conflict (challenge) do nothing
  returning true into v_insere;

  -- Purge opportuniste : une ligne périmée ne sert plus à rien, puisqu'un défi
  -- périmé est de toute façon refusé plus haut.
  delete from public.altcha_consumed_challenges where expires_at < now() - interval '1 hour';

  return coalesce(v_insere, false);
end;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_consume_altcha_challenge(text, timestamptz, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_consume_altcha_challenge(text, timestamptz, text) TO service_role;

-- La TABLE porte sa propre liste (CHECK altcha_consumed_challenges_purpose_check,
-- relevée en production le 24/09 : register, cartography) : l'élargir aussi, sinon
-- la fonction accepte l'usage et l'insertion le refuse — attrapé par la suite
-- signalements_tests au rejeu local, avant tout déploiement (allowlist ≠ CHECK, B26).
ALTER TABLE public.altcha_consumed_challenges DROP CONSTRAINT IF EXISTS altcha_consumed_challenges_purpose_check;
ALTER TABLE public.altcha_consumed_challenges
  ADD CONSTRAINT altcha_consumed_challenges_purpose_check
  CHECK (purpose = ANY (ARRAY['register'::text, 'cartography'::text, 'bug_report'::text]));

-- ─── 5. Le compteur d'abus 'bug_ip' ───────────────────────────────────────────
ALTER TABLE public.auth_rate_limits DROP CONSTRAINT IF EXISTS auth_rate_limits_kind_check;
ALTER TABLE public.auth_rate_limits
  ADD CONSTRAINT auth_rate_limits_kind_check
  CHECK (kind = ANY (ARRAY[
    'ip'::text, 'email'::text,               -- login
    'geocode_ip'::text,                      -- geocode
    'carto_ip'::text,                        -- submit-cartography-entry
    'gazette_ip'::text, 'gazette_email'::text, 'gazette_prefill'::text,  -- submit-gazette-contribution
    'bug_ip'::text                           -- submit-bug-report (E14, 24/09/2026)
  ]));
COMMENT ON TABLE public.auth_rate_limits IS
  'Compteurs d''abus des Edge Functions (login, geocode, cartographie, gazette, signalements). '
  'Ajouter un kind = élargir auth_rate_limits_kind_check ET tests/sql/compteurs_d_abus_tests.sql (B25/B26, 16/09/2026 ; E14, 24/09/2026).';

-- ─── Vérification ─────────────────────────────────────────────────────────────
DO $$
DECLARE c text;
BEGIN
  IF to_regclass('public.bug_reports') IS NULL OR to_regclass('public.bug_report_notification_outbox') IS NULL THEN
    RAISE EXCEPTION 'E14 : tables absentes';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tg_bug_report_enqueue')
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tg_bug_report_outbox_dispatch') THEN
    RAISE EXCEPTION 'E14 : triggers absents';
  END IF;
  SELECT pg_get_constraintdef(oid) INTO c FROM pg_constraint WHERE conname = 'auth_rate_limits_kind_check';
  IF c IS NULL OR position('bug_ip' IN c) = 0 THEN
    RAISE EXCEPTION 'E14 : le kind bug_ip n''est pas admis';
  END IF;
  SELECT pg_get_constraintdef(oid) INTO c FROM pg_constraint WHERE conname = 'altcha_consumed_challenges_purpose_check';
  IF c IS NULL OR position('bug_report' IN c) = 0 THEN
    RAISE EXCEPTION 'E14 : l''usage Altcha bug_report n''est pas admis par la table';
  END IF;
  IF has_table_privilege('anon', 'public.bug_reports', 'SELECT') OR has_table_privilege('authenticated', 'public.bug_reports', 'INSERT') THEN
    RAISE EXCEPTION 'E14 : bug_reports doit rester fermée à anon et authenticated';
  END IF;
END $$;

COMMIT;
