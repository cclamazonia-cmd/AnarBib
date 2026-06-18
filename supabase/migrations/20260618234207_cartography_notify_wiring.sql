-- =========================================================================
-- Paquet CARTO-8 — Câblage notify-event de l'auto-déclaration carto (MAP-J)
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : Cartographie du réseau (REGISTRE §34) — MAP-J / notification
-- Auteur   : AnarBib · Session : Carte réseau 10 locales
--
-- Refait l'outbox d'auto-déclaration au format « Gazette » (id BIGINT + payload
-- jsonb) pour le brancher sur le dispatcher notify-event, qui lit l'outbox PAR
-- record_id BIGINT (cf. handleCartographyEvent dans _shared/domain/cartography.ts).
--   1) enqueue (trigger sur cartography_submissions) → 1 ligne outbox (event+payload e-mail) ;
--   2) dispatch (trigger sur l'outbox) → net.http_post vers notify-event {event, record_id}
--      avec x-webhook-secret (vault WEBHOOK_SECRET_NOTIFY_EVENT), modèle gazette ;
--   3) notify-event → e-mail à fede@anarbib.org.
-- L'outbox CARTO-7 (id uuid, sans payload) est vide → recréation propre.
-- =========================================================================

BEGIN;

-- ── Remplacer l'outbox CARTO-7 (uuid) par le format Gazette (bigint + payload) ──
DROP TRIGGER IF EXISTS tg_cartography_submission_enqueue ON public.cartography_submissions;
DROP FUNCTION IF EXISTS public.fn_cartography_submission_enqueue();
DROP TABLE IF EXISTS public.cartography_submission_notification_outbox;

CREATE TABLE public.cartography_submission_notification_outbox (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','sent','failed','skipped')),
  pg_net_request_id bigint,
  attempts integer NOT NULL DEFAULT 0,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz
);
CREATE INDEX cartography_submission_outbox_queued_idx
  ON public.cartography_submission_notification_outbox(created_at) WHERE status = 'queued';
REVOKE ALL ON public.cartography_submission_notification_outbox FROM anon, authenticated;
GRANT ALL ON public.cartography_submission_notification_outbox TO service_role;
ALTER TABLE public.cartography_submission_notification_outbox ENABLE ROW LEVEL SECURITY;
COMMENT ON TABLE public.cartography_submission_notification_outbox IS
  'File d''événements d''auto-déclaration carto (CARTO-7/8). 1 ligne/soumission (event+payload e-mail), '
  'id BIGINT = record_id pour notify-event. Enfilée par tg_cartography_submission_enqueue, dispatchée '
  'par tg_cartography_outbox_dispatch vers notify-event. Modèle gazette_submission_notification_outbox.';

-- ── (1) enqueue : payload e-mail (destinataire éditorial réseau) ──────────────
CREATE OR REPLACE FUNCTION public.fn_cartography_submission_enqueue()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
BEGIN
  INSERT INTO public.cartography_submission_notification_outbox (event, payload)
  VALUES (
    'cartography.submission_received',
    jsonb_build_object(
      'to', 'fede@anarbib.org',
      'submission_id', NEW.id,
      'name', NEW.name,
      'city', NEW.city,
      'country', NEW.country,
      'categorie', NEW.categorie,
      'locale', NEW.notes_locale,
      'site_url', NEW.site_url
    )
  );
  RETURN NEW;
END $$;
ALTER FUNCTION public.fn_cartography_submission_enqueue() OWNER TO postgres;
CREATE TRIGGER tg_cartography_submission_enqueue
  AFTER INSERT ON public.cartography_submissions
  FOR EACH ROW EXECUTE FUNCTION public.fn_cartography_submission_enqueue();

-- ── (2) dispatch : net.http_post vers notify-event (modèle gazette) ───────────
CREATE OR REPLACE FUNCTION public.fn_cartography_outbox_dispatch_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
declare
  v_url text;
  v_secret text;
  v_request_id bigint;
  v_body jsonb;
begin
  v_url := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/notify-event';

  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'WEBHOOK_SECRET_NOTIFY_EVENT';

  if v_secret is null or v_secret = '' then
    update public.cartography_submission_notification_outbox
       set status = 'failed',
           last_error = 'WEBHOOK_SECRET_NOTIFY_EVENT vide ou introuvable dans vault',
           attempts = attempts + 1
     where id = NEW.id;
    return NEW;
  end if;

  v_body := jsonb_build_object('event', NEW.event, 'record_id', NEW.id);

  begin
    select net.http_post(
      url := v_url,
      body := v_body,
      headers := jsonb_build_object(
        'content-type', 'application/json',
        'x-webhook-secret', v_secret
      )
    ) into v_request_id;

    update public.cartography_submission_notification_outbox
       set pg_net_request_id = v_request_id,
           attempts = attempts + 1
     where id = NEW.id;
  exception
    when others then
      update public.cartography_submission_notification_outbox
         set status = 'failed',
             last_error = SQLERRM,
             attempts = attempts + 1
       where id = NEW.id;
  end;

  return NEW;
end;
$$;
ALTER FUNCTION public.fn_cartography_outbox_dispatch_trigger() OWNER TO postgres;
CREATE TRIGGER tg_cartography_outbox_dispatch
  AFTER INSERT ON public.cartography_submission_notification_outbox
  FOR EACH ROW EXECUTE FUNCTION public.fn_cartography_outbox_dispatch_trigger();

COMMIT;
