-- ============================================================================
-- F12 — un courriel refusé est rejoué, par destinataire refusé, un nombre borné de fois
-- (25/09/2026). Demandé par Xavier le 21/09, après le correctif « sent à tort » :
-- depuis outbox-verdict.ts, un refus du transport met la ligne en « failed »… et
-- rien ne la relisait jamais. Une panne d'une heure chez le transporteur, et des
-- convocations, des décisions de la gazette, des votes n'arrivaient jamais.
--
-- Ce que pose cette migration, sur les CINQ files dont les handlers lisent
-- outbox-verdict.ts (team — qui porte aussi network.*, assembleia et
-- library_profile —, lettre, gazette, cartography, bug_report) :
--   1. deux colonnes : refused_recipients (QUI a refusé, en données — plus une
--      phrase tronquée) et next_attempt_at (quand retenter) ; un état final
--      « abandoned » admis par chaque CHECK de statut ;
--   2. un trigger qui programme le prochain essai quand une ligne passe à
--      « failed » : 15 min, puis 1 h, puis 6 h (recul) ;
--   3. private.fn_outbox_rejouer(), lancée toutes les 15 min par le cron
--      anarbib-notify-outbox-retry : elle reposte à notify-event les lignes dont
--      l'heure est venue, AVEC la liste des refusés (« seulement ») — le transport
--      ne sert alors que ceux-là, jamais un destinataire déjà servi ; et elle passe
--      en « abandoned » une ligne qui a épuisé ses quatre essais ;
--   4. api.fn_outbox_abandonnees() / api.fn_outbox_acquitter() : la liste et le
--      geste qui fait sortir une ligne abandonnée (elle passe en « skipped » avec sa
--      raison), réservés à l'admin réseau ;
--   5. la sonde fn_healthcheck_notifications distingue « dont_en_rejeu » de
--      « dont_abandonnees » (corps réel, md5 551268a6…, deux remplacements comptés) ;
--   6. le cron dans fn_crons_attendus() (I26 : un cron neuf remplace aussi la liste).
--
-- Hors de cette migration, dans le code : outbox-verdict.ts rend la liste des
-- refusés, les huit handlers l'écrivent, _shared/transport/restriction.ts porte la
-- restriction « seulement » le temps d'un envoi (AsyncLocalStorage), et
-- safeSendEmail saute un destinataire déjà servi en le comptant comme servi.
-- Une ligne en échec SANS liste (le handler a levé, ou la dépêche n'a pas pu
-- partir) est rejouée pour tous ses destinataires : dans ces cas rien n'était parti.
-- Hors périmètre : authority_proposal_notification_outbox (son handler ne lit pas
-- outbox-verdict) et les deux files painel_* (dispatch_status, réconciliation propre).
-- Suites : tests/sql/courriels_rejeu_tests.sql, crons_planifies_tests (39 jobs).
-- Banc : src/tests/courriels-rejeu-banc.test.js.
-- ============================================================================

BEGIN;

-- ─── 1. Colonnes et état final ────────────────────────────────────────────────
ALTER TABLE public.team_notification_outbox
  ADD COLUMN IF NOT EXISTS refused_recipients text[],
  ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz;
ALTER TABLE public.team_notification_outbox DROP CONSTRAINT IF EXISTS team_notification_outbox_status_check;
ALTER TABLE public.team_notification_outbox ADD CONSTRAINT team_notification_outbox_status_check CHECK (status = ANY (ARRAY['pending'::text, 'sent'::text, 'failed'::text, 'skipped'::text, 'abandoned'::text]));
COMMENT ON COLUMN public.team_notification_outbox.refused_recipients IS 'F12 : adresses refusées par le transport au dernier essai (null = tous, ou rien de connu). Le rejeu ne sert qu''elles.';
COMMENT ON COLUMN public.team_notification_outbox.next_attempt_at IS 'F12 : prochain essai du cron anarbib-notify-outbox-retry (15 min, 1 h, 6 h après chaque échec) ; abandoned après quatre essais.';

ALTER TABLE public.lettre_notification_outbox
  ADD COLUMN IF NOT EXISTS refused_recipients text[],
  ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz;
ALTER TABLE public.lettre_notification_outbox DROP CONSTRAINT IF EXISTS lettre_notification_outbox_status_check;
ALTER TABLE public.lettre_notification_outbox ADD CONSTRAINT lettre_notification_outbox_status_check CHECK (status = ANY (ARRAY['queued'::text, 'sent'::text, 'failed'::text, 'skipped'::text, 'abandoned'::text]));
COMMENT ON COLUMN public.lettre_notification_outbox.refused_recipients IS 'F12 : adresses refusées par le transport au dernier essai (null = tous, ou rien de connu). Le rejeu ne sert qu''elles.';
COMMENT ON COLUMN public.lettre_notification_outbox.next_attempt_at IS 'F12 : prochain essai du cron anarbib-notify-outbox-retry (15 min, 1 h, 6 h après chaque échec) ; abandoned après quatre essais.';

ALTER TABLE public.gazette_submission_notification_outbox
  ADD COLUMN IF NOT EXISTS refused_recipients text[],
  ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz;
ALTER TABLE public.gazette_submission_notification_outbox DROP CONSTRAINT IF EXISTS gazette_submission_outbox_status_check;
ALTER TABLE public.gazette_submission_notification_outbox ADD CONSTRAINT gazette_submission_outbox_status_check CHECK (status = ANY (ARRAY['queued'::text, 'sent'::text, 'failed'::text, 'skipped'::text, 'abandoned'::text]));
COMMENT ON COLUMN public.gazette_submission_notification_outbox.refused_recipients IS 'F12 : adresses refusées par le transport au dernier essai (null = tous, ou rien de connu). Le rejeu ne sert qu''elles.';
COMMENT ON COLUMN public.gazette_submission_notification_outbox.next_attempt_at IS 'F12 : prochain essai du cron anarbib-notify-outbox-retry (15 min, 1 h, 6 h après chaque échec) ; abandoned après quatre essais.';

ALTER TABLE public.cartography_submission_notification_outbox
  ADD COLUMN IF NOT EXISTS refused_recipients text[],
  ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz;
ALTER TABLE public.cartography_submission_notification_outbox DROP CONSTRAINT IF EXISTS cartography_submission_notification_outbox_status_check;
ALTER TABLE public.cartography_submission_notification_outbox ADD CONSTRAINT cartography_submission_notification_outbox_status_check CHECK (status = ANY (ARRAY['queued'::text, 'sent'::text, 'failed'::text, 'skipped'::text, 'abandoned'::text]));
COMMENT ON COLUMN public.cartography_submission_notification_outbox.refused_recipients IS 'F12 : adresses refusées par le transport au dernier essai (null = tous, ou rien de connu). Le rejeu ne sert qu''elles.';
COMMENT ON COLUMN public.cartography_submission_notification_outbox.next_attempt_at IS 'F12 : prochain essai du cron anarbib-notify-outbox-retry (15 min, 1 h, 6 h après chaque échec) ; abandoned après quatre essais.';

ALTER TABLE public.bug_report_notification_outbox
  ADD COLUMN IF NOT EXISTS refused_recipients text[],
  ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz;
ALTER TABLE public.bug_report_notification_outbox DROP CONSTRAINT IF EXISTS bug_report_notification_outbox_status_check;
ALTER TABLE public.bug_report_notification_outbox ADD CONSTRAINT bug_report_notification_outbox_status_check CHECK (status = ANY (ARRAY['queued'::text, 'sent'::text, 'failed'::text, 'skipped'::text, 'abandoned'::text]));
COMMENT ON COLUMN public.bug_report_notification_outbox.refused_recipients IS 'F12 : adresses refusées par le transport au dernier essai (null = tous, ou rien de connu). Le rejeu ne sert qu''elles.';
COMMENT ON COLUMN public.bug_report_notification_outbox.next_attempt_at IS 'F12 : prochain essai du cron anarbib-notify-outbox-retry (15 min, 1 h, 6 h après chaque échec) ; abandoned après quatre essais.';

-- ─── 2. Le recul, et le trigger qui programme le prochain essai ───────────────
CREATE OR REPLACE FUNCTION private.fn_outbox_prochain_essai(p_attempts integer)
RETURNS interval
LANGUAGE sql IMMUTABLE
SET search_path TO 'pg_catalog'
AS $$
  SELECT CASE WHEN p_attempts <= 1 THEN interval '15 minutes'
              WHEN p_attempts = 2 THEN interval '1 hour'
              WHEN p_attempts = 3 THEN interval '6 hours'
              ELSE interval '0' END;
$$;
REVOKE EXECUTE ON FUNCTION private.fn_outbox_prochain_essai(integer) FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION private.fn_outbox_prochain_essai(integer) IS 'F12 : recul du rejeu selon le nombre d''essais (1 → 15 min, 2 → 1 h, 3 → 6 h, 4 et plus → abandon au prochain passage).';

CREATE OR REPLACE FUNCTION private.fn_outbox_programmer_rejeu()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog'
AS $$
BEGIN
  IF NEW.status = 'failed' THEN
    NEW.next_attempt_at := now() + private.fn_outbox_prochain_essai(coalesce(NEW.attempts, 1));
  ELSIF NEW.status IN ('sent', 'skipped') THEN
    NEW.next_attempt_at := NULL;
  END IF;
  RETURN NEW;
END $$;
REVOKE EXECUTE ON FUNCTION private.fn_outbox_programmer_rejeu() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION private.fn_outbox_programmer_rejeu() IS 'F12 : trigger BEFORE UPDATE OF status des cinq files — programme le prochain essai d''une ligne en échec, l''efface d''une ligne servie ou sautée.';

DROP TRIGGER IF EXISTS tg_outbox_programmer_rejeu ON public.team_notification_outbox;
CREATE TRIGGER tg_outbox_programmer_rejeu BEFORE UPDATE OF status ON public.team_notification_outbox
  FOR EACH ROW EXECUTE FUNCTION private.fn_outbox_programmer_rejeu();
DROP TRIGGER IF EXISTS tg_outbox_programmer_rejeu ON public.lettre_notification_outbox;
CREATE TRIGGER tg_outbox_programmer_rejeu BEFORE UPDATE OF status ON public.lettre_notification_outbox
  FOR EACH ROW EXECUTE FUNCTION private.fn_outbox_programmer_rejeu();
DROP TRIGGER IF EXISTS tg_outbox_programmer_rejeu ON public.gazette_submission_notification_outbox;
CREATE TRIGGER tg_outbox_programmer_rejeu BEFORE UPDATE OF status ON public.gazette_submission_notification_outbox
  FOR EACH ROW EXECUTE FUNCTION private.fn_outbox_programmer_rejeu();
DROP TRIGGER IF EXISTS tg_outbox_programmer_rejeu ON public.cartography_submission_notification_outbox;
CREATE TRIGGER tg_outbox_programmer_rejeu BEFORE UPDATE OF status ON public.cartography_submission_notification_outbox
  FOR EACH ROW EXECUTE FUNCTION private.fn_outbox_programmer_rejeu();
DROP TRIGGER IF EXISTS tg_outbox_programmer_rejeu ON public.bug_report_notification_outbox;
CREATE TRIGGER tg_outbox_programmer_rejeu BEFORE UPDATE OF status ON public.bug_report_notification_outbox
  FOR EACH ROW EXECUTE FUNCTION private.fn_outbox_programmer_rejeu();

-- ─── 3. Le rejeu ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION private.fn_outbox_rejouer()
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'pg_temp'
AS $$
DECLARE
  v_files    constant text[] := ARRAY['team_notification_outbox', 'lettre_notification_outbox', 'gazette_submission_notification_outbox', 'cartography_submission_notification_outbox', 'bug_report_notification_outbox'];
  v_file     text;
  v_secret   text;
  v_url      text;
  v_n        bigint;
  v_abandon  jsonb := '{}'::jsonb;
  v_rejoue   jsonb := '{}'::jsonb;
  v_req      bigint;
  r          record;
BEGIN
  -- a. Une ligne qui a épuisé ses quatre essais passe en « abandoned » : elle attend
  --    un geste humain (api.fn_outbox_acquitter), la sonde la nomme à part.
  FOREACH v_file IN ARRAY v_files LOOP
    EXECUTE format('UPDATE public.%I SET status = ''abandoned'', next_attempt_at = NULL'
                   ' WHERE status = ''failed'' AND attempts >= 4 AND coalesce(next_attempt_at, ''-infinity''::timestamptz) <= now()', v_file);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n > 0 THEN v_abandon := v_abandon || jsonb_build_object(v_file, v_n); END IF;
  END LOOP;

  -- b. Sans le secret du webhook, rien ne peut partir : on le dit, on ne fait rien.
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'WEBHOOK_SECRET_NOTIFY_EVENT';
  IF v_secret IS NULL OR v_secret = '' THEN
    RETURN jsonb_build_object('abandonnees', v_abandon, 'rejouees', v_rejoue, 'raison', 'WEBHOOK_SECRET_NOTIFY_EVENT absent : aucun rejeu');
  END IF;
  v_url := private.fn_functions_base_url() || '/functions/v1/notify-event';

  -- c. Les lignes dont l'heure est venue repartent vers notify-event, avec la liste
  --    des refusés : le transport ne servira qu'eux (restriction « seulement »).
  FOREACH v_file IN ARRAY v_files LOOP
    v_n := 0;
    FOR r IN EXECUTE format('SELECT id, event, attempts, refused_recipients FROM public.%I'
                            ' WHERE status = ''failed'' AND attempts < 4 AND next_attempt_at IS NOT NULL AND next_attempt_at <= now()'
                            ' ORDER BY id LIMIT 25', v_file)
    LOOP
      BEGIN
        SELECT net.http_post(
          url := v_url,
          body := jsonb_build_object('event', r.event, 'record_id', r.id, 'rejeu', true,
                                     'seulement', CASE WHEN r.refused_recipients IS NULL OR cardinality(r.refused_recipients) = 0
                                                       THEN NULL ELSE to_jsonb(r.refused_recipients) END),
          headers := jsonb_build_object('content-type', 'application/json', 'x-webhook-secret', v_secret)
        ) INTO v_req;
        -- Heure provisoire : si notify-event ne répond jamais, la ligne sera reprise.
        EXECUTE format('UPDATE public.%I SET attempts = attempts + 1, pg_net_request_id = $1,'
                       ' next_attempt_at = now() + private.fn_outbox_prochain_essai(attempts + 1) WHERE id = $2', v_file)
          USING v_req, r.id;
        v_n := v_n + 1;
      EXCEPTION WHEN OTHERS THEN
        EXECUTE format('UPDATE public.%I SET last_error = left(''rejeu : '' || $1, 500) WHERE id = $2', v_file) USING SQLERRM, r.id;
      END;
    END LOOP;
    IF v_n > 0 THEN v_rejoue := v_rejoue || jsonb_build_object(v_file, v_n); END IF;
  END LOOP;

  RETURN jsonb_build_object('abandonnees', v_abandon, 'rejouees', v_rejoue);
END $$;
REVOKE EXECUTE ON FUNCTION private.fn_outbox_rejouer() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION private.fn_outbox_rejouer() IS 'F12 : lancée par le cron anarbib-notify-outbox-retry. Abandonne les lignes à quatre essais, reposte à notify-event celles dont l''heure est venue, avec leurs refusés (« seulement »). Fermée à anon et authenticated.';

-- ─── 4. La liste et le geste d'acquittement (admin réseau) ────────────────────
CREATE OR REPLACE FUNCTION api.fn_outbox_abandonnees()
RETURNS TABLE (file text, id bigint, event text, attempts integer, refused_recipients text[], last_error text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_file text;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: network admin only' USING ERRCODE = '42501';
  END IF;
  FOREACH v_file IN ARRAY ARRAY['team_notification_outbox', 'lettre_notification_outbox', 'gazette_submission_notification_outbox', 'cartography_submission_notification_outbox', 'bug_report_notification_outbox'] LOOP
    RETURN QUERY EXECUTE format('SELECT %L::text, o.id, o.event, o.attempts, o.refused_recipients, o.last_error, o.created_at'
                                ' FROM public.%I o WHERE o.status = ''abandoned'' ORDER BY o.created_at', v_file, v_file);
  END LOOP;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_outbox_abandonnees() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_outbox_abandonnees() TO authenticated;
COMMENT ON FUNCTION api.fn_outbox_abandonnees() IS 'F12 : les lignes de file abandonnées après quatre essais, toutes files confondues. Admin réseau seulement. Verdict : AUDIT_execute_authenticated_2026-09-01, complément du 25/09.';

CREATE OR REPLACE FUNCTION api.fn_outbox_acquitter(p_file text, p_id bigint, p_raison text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_n bigint;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: network admin only' USING ERRCODE = '42501';
  END IF;
  IF p_file IS NULL OR NOT (p_file = ANY (ARRAY['team_notification_outbox', 'lettre_notification_outbox', 'gazette_submission_notification_outbox', 'cartography_submission_notification_outbox', 'bug_report_notification_outbox'])) THEN
    RAISE EXCEPTION 'file inconnue : %', p_file USING ERRCODE = '22023';
  END IF;
  IF coalesce(btrim(p_raison), '') = '' THEN
    RAISE EXCEPTION 'une raison est requise pour acquitter' USING ERRCODE = '22023';
  END IF;
  EXECUTE format('UPDATE public.%I SET status = ''skipped'', next_attempt_at = NULL,'
                 ' skip_reason = left(format(''abandonné après %%s essais, acquitté le %%s : %%s'', attempts, current_date, $1), 500)'
                 ' WHERE id = $2 AND status = ''abandoned''', p_file)
    USING btrim(p_raison), p_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    RAISE EXCEPTION 'aucune ligne abandonnée % dans %', p_id, p_file USING ERRCODE = 'P0002';
  END IF;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_outbox_acquitter(text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_outbox_acquitter(text, bigint, text) TO authenticated;
COMMENT ON FUNCTION api.fn_outbox_acquitter(text, bigint, text) IS 'F12 : fait sortir une ligne abandonnée (elle passe en skipped, avec le nombre d''essais, la date et la raison). Admin réseau seulement ; raison obligatoire. Verdict : AUDIT_execute_authenticated_2026-09-01, complément du 25/09.';

-- ─── 5. La sonde distingue le rejeu de l'abandon ──────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_healthcheck_notifications()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'vault', 'extensions', 'pg_temp'
AS $fn$
declare
  v_vifs      jsonb := '[]'::jsonb;
  v_dormants  jsonb := '[]'::jsonb;
  v_types     jsonb := '[]'::jsonb;
  v_files     jsonb := '[]'::jsonb;
  v_crons     jsonb := '[]'::jsonb;
  v_contacts  jsonb := '[]'::jsonb;
  v_cron_dispo boolean := true;
  r record; f record;
  v_allowed text[]; v_declared text[]; v_missing text[];
  v_n bigint;
  v_rejeu bigint;
  v_abandon bigint;
begin
  begin
    perform 1 from cron.job limit 1;
  exception
    when undefined_table or invalid_schema_name or insufficient_privilege then
      v_cron_dispo := false;
  end;

  -- 1. Secrets lus dans le Vault par une fonction, mais absents du Vault.
  begin
    with refs as (
      select p.proname, m.arr[1] as nom
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      cross join lateral regexp_matches(
        pg_get_functiondef(p.oid),
        '(?:fn_internal_get_vault_secret\(|name\s*=\s*)''([A-Za-z0-9_]+)''', 'g') as m(arr)
      where n.nspname = 'public'
        and p.prokind = 'f'
        and p.proname <> 'fn_healthcheck_notifications'
        and pg_get_functiondef(p.oid) ilike '%vault%'
    ),
    plausibles as (
      select * from refs
      where nom ~ '^[A-Z][A-Z0-9_]{3,}$'
         or nom ~* '(secret|salt|token|key|url)$'
    ),
    manquants as (
      select p.nom, p.proname
      from plausibles p
      where not exists (select 1 from vault.secrets v where v.name = p.nom)
    ),
    classe as (
      select m.nom, m.proname,
             (v_cron_dispo
              and exists (select 1 from cron.job j where j.command like '%' || m.proname || '%')
              and not exists (select 1 from cron.job j
                              where j.command like '%' || m.proname || '%' and j.active)
             ) as dormant
      from manquants m
    ),
    agg as (
      select nom,
             string_agg(distinct proname, ', ') as lecteurs,
             bool_and(dormant) as tout_dormant
      from classe group by nom
    )
    select
      coalesce(jsonb_agg(jsonb_build_object('secret', nom, 'lu_par', lecteurs)
                         order by nom) filter (where not tout_dormant), '[]'::jsonb),
      coalesce(jsonb_agg(jsonb_build_object('secret', nom, 'lu_par', lecteurs,
                                            'raison', 'lecteur(s) appeles uniquement par un cron INACTIF')
                         order by nom) filter (where tout_dormant), '[]'::jsonb)
      into v_vifs, v_dormants
    from agg;
  exception
    when undefined_table or undefined_function or invalid_schema_name then
      v_vifs := jsonb_build_array(jsonb_build_object('erreur', 'Vault indisponible'));
  end;

  -- 2. event_type accepte par une fonction mais refuse par la CHECK de la table.
  for r in
    select t.relname as tbl,
           replace(t.relname, '_notification_events', '') as prefixe,
           pg_get_constraintdef(c.oid) as checkdef
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and c.contype = 'c'
      and t.relname like '%\_notification\_events'
      and pg_get_constraintdef(c.oid) like '%event_type%'
  loop
    select array_agg(distinct m.arr[1]) into v_allowed
    from regexp_matches(r.checkdef, '''([^'']+)''::text', 'g') as m(arr);
    continue when coalesce(array_length(v_allowed, 1), 0) = 0;

    for f in
      select p.oid, p.proname from pg_proc p
      join pg_namespace np on np.oid = p.pronamespace
      where np.nspname = 'public'
        and p.prokind = 'f'
        and p.proname <> 'fn_healthcheck_notifications'
        and pg_get_functiondef(p.oid) like '%' || r.tbl || '%'
    loop
      select array_agg(distinct m.arr[1]) into v_declared
      from regexp_matches(pg_get_functiondef(f.oid),
                          '''(' || r.prefixe || '_[a-z_]+)''', 'g') as m(arr)
      where m.arr[1] not like '%notification\_events' and m.arr[1] <> r.tbl;
      continue when coalesce(array_length(v_declared, 1), 0) = 0;

      select array_agg(d) into v_missing
      from unnest(v_declared) as d where d <> all (v_allowed);

      if coalesce(array_length(v_missing, 1), 0) > 0 then
        v_types := v_types || jsonb_build_object(
          'table', r.tbl, 'fonction', f.proname, 'types_refuses_par_la_check', v_missing);
      end if;
    end loop;
  end loop;

  -- 3. Files d'attente : lignes ni envoyees ni ignorees DEPUIS PLUS DE 15 MIN.
  --    Une ligne tout juste inseree n'est pas bloquee : l'envoi la traite en
  --    quelques secondes. Sans ce delai, un cron qui enfile a la meme minute
  --    que la sonde (team-invitations-remind a 09:35 UTC) ouvrait un incident
  --    a 09:35 et le refermait a 09:40, chaque jour.
  for r in
    select c.relname as tbl
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relname like '%outbox%'
      and exists (select 1 from pg_attribute a
                  where a.attrelid = c.oid and a.attname = 'status' and a.attnum > 0)
    order by c.relname
  loop
    -- F12 (25/09/2026) : la sonde distingue une ligne EN REJEU (failed, le cron
    -- anarbib-notify-outbox-retry la reprendra) d'une ligne ABANDONNÉE (abandoned,
    -- après quatre essais — elle attend un geste humain : api.fn_outbox_acquitter).
    execute format(
      'select count(*), count(*) filter (where status = ''failed''), count(*) filter (where status = ''abandoned'')'
      ' from public.%I where coalesce(status, '''') not in (''sent'', ''skipped'')'
      ' and created_at < now() - interval ''15 minutes''',
      r.tbl) into v_n, v_rejeu, v_abandon;
    if v_n > 0 then
      v_files := v_files || jsonb_build_object('file', r.tbl, 'lignes_non_traitees', v_n,
        'dont_en_rejeu', v_rejeu, 'dont_abandonnees', v_abandon);
    end if;
  end loop;

  -- 4. Crons de notification inactifs (informatif).
  if v_cron_dispo then
    select coalesce(jsonb_agg(jsonb_build_object('job', jobname, 'schedule', schedule)
                              order by jobname), '[]'::jsonb)
      into v_crons
    from cron.job
    where not active and (jobname ilike '%notify%' or jobname ilike '%digest%' or jobname ilike '%report%');
  end if;

  -- 5. Bibliotheques ACTIVES sans courriel de contact — INFORMATIF (cf. en-tete).
  begin
    select coalesce(jsonb_agg(jsonb_build_object(
             'bibliotheque', coalesce(l.short_name, l.name),
             'consequence', 'ne recevra jamais les notifications routees via library_contact_profiles (notify-document-permission-request)')
           order by coalesce(l.short_name, l.name)), '[]'::jsonb)
      into v_contacts
    from public.libraries l
    left join public.library_contact_profiles c on c.library_id = l.id
    where l.is_active and coalesce(c.contact_email, '') = '';
  exception
    when undefined_table or undefined_column then v_contacts := '[]'::jsonb;
  end;

  return jsonb_build_object(
    'ok', (jsonb_array_length(v_vifs) = 0
           and jsonb_array_length(v_types) = 0
           and jsonb_array_length(v_files) = 0),
    'verifie_le', now(),
    'secrets_absents_bloquants', v_vifs,
    'secrets_absents_dormants', v_dormants,
    'event_types_refuses_par_la_check', v_types,
    'files_non_traitees', v_files,
    'bibliotheques_actives_sans_contact_informatif', v_contacts,
    'crons_inactifs_pour_information', v_crons
  );
end $fn$;

-- ─── 6. Le cron, et la liste des crons attendus (I26) ─────────────────────────
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'anarbib-notify-outbox-retry';
SELECT cron.schedule('anarbib-notify-outbox-retry', '*/15 * * * *', $c$select private.fn_outbox_rejouer();$c$);

create or replace function private.fn_crons_attendus()
returns table (jobname text, schedule text, command text, active boolean)
language sql
immutable
set search_path to 'pg_temp'
as $fn$
  values
    ('anarbib-authority-resolve-due-daily', '45 3 * * *', $c$ SELECT api.fn_authority_resolve_due(); $c$, true),
    ('anarbib-catalog-audit-snapshot-purge', '17 4 * * *', $c$select public.fn_purge_audit_draft_snapshots();$c$, true),
    ('anarbib-circle-resolve-due-daily', '30 3 * * *', $c$ SELECT api.fn_circle_resolve_due(); $c$, true),
    ('anarbib-collective-removal-execute-daily', '15 3 * * *', $c$SELECT public.fn_cron_collective_removal_execute();$c$, true),
    ('anarbib-cooptation-reminders-daily', '25 9 * * *', $c$SELECT public.fn_cron_cooptation_send_reminders();$c$, true),
    ('anarbib-gazette-monthly-start', '0 6 15 * *', $c$select public.fn_gazette_build_call('start')$c$, true),
    ('anarbib-gazette-reconcile-tick', '*/5 * * * *', $c$select public.fn_gazette_build_call('tick')$c$, true),
    ('anarbib-gazette-translate-submissions', '*/10 * * * *', $c$select public.fn_gazette_translate_call()$c$, true),
    ('anarbib-health-probe', '*/5 * * * *', $c$
      select net.http_post(
        url := (private.fn_functions_base_url() || '/functions/v1/health-probe'),
        headers := jsonb_build_object(
          'content-type', 'application/json',
          'x-webhook-secret', (select decrypted_secret from vault.decrypted_secrets
                                where name = 'WEBHOOK_SECRET_HEALTH_PROBE')),
        body := '{}'::jsonb,
        timeout_milliseconds := 30000);
    $c$, true),
    ('anarbib-membership-expiry-daily', '40 6 * * *', $c$SELECT public.fn_cron_notify_membership_expiry();$c$, true),
    ('anarbib-notify-cross-library-digest-weekly', '30 8 * * 1', $c$SELECT public.fn_cron_notify_cross_library_digest();$c$, true),
    ('anarbib-notify-loan-cycle-daily', '15 9 * * *', $c$select public.fn_cron_notify_loan_cycle();$c$, true),
    ('anarbib-notify-outbox-retry', '*/15 * * * *', $c$select private.fn_outbox_rejouer();$c$, true),
    ('anarbib-notify-network-weekly-report-weekly', '15 8 * * 1', $c$ select public.fn_cron_notify_network_weekly_report(); $c$, true),
    ('anarbib-notify-weekly-report-weekly', '0 8 * * 1', $c$ select * from public.fn_cron_notify_weekly_report_per_library(); $c$, true),
    ('anarbib-oai-harvest-weekly', '20 4 * * 2', $c$SELECT ingest.fn_cron_import_harvest_oai();$c$, true),
    ('anarbib-oai-resolve-expired-votes', '45 3 * * *', $c$SELECT public.fn_oai_resolve_expired_votes();$c$, true),
    ('anarbib-peb-detect-overdue-daily', '40 3 * * *', $c$ SELECT public.fn_cron_peb_detect_overdue(); $c$, true),
    ('anarbib-purge-invitations-expirees', '40 3 * * *', $c$SELECT public.fn_purge_library_request_invitations();$c$, true),
    ('anarbib-recompute-holdings-availability', '43 4 * * *', $c$SELECT public.fn_v2_recompute_holdings_availability();$c$, true),
    ('anarbib-rede-digest-weekly', '0 9 * * 1', $c$SELECT public.fn_rede_digest_call();$c$, true),
    ('anarbib-request-eval-digest', '17 8 * * *', $c$SELECT public.fn_cron_request_eval_digest();$c$, true),
    ('anarbib-reservation-detect-no-show', '15 * * * *', $c$ SELECT public.fn_detect_no_show_reservations(); $c$, true),
    ('anarbib-reservation-expire-negotiation', '25 * * * *', $c$ SELECT public.fn_expire_negotiation_timeout(); $c$, true),
    ('anarbib-reservation-expire-solicitada', '5 * * * *', $c$ SELECT public.fn_expire_solicitada_reservations(); $c$, true),
    ('anarbib-rgpd-notify-weekly', '0 2 * * 0', $c$ SELECT public.fn_notify_users_before_purge(); $c$, true),
    ('anarbib-rgpd-purge-weekly', '0 3 * * 0', $c$ SELECT public.fn_purge_expired_data(p_dry_run := false); $c$, true),
    ('anarbib-tasks-detect-stale-recurrence-daily', '50 3 * * *', $c$ SELECT public.fn_cron_tasks_detect_stale_recurrence(); $c$, true),
    ('anarbib-team-inactive-cleanup', '0 4 * * *', $c$SELECT public.fn_cron_team_inactive_cleanup();$c$, true),
    ('anarbib-team-invitations-expire', '20 3 * * *', $c$SELECT public.fn_team_expire_invitations()$c$, true),
    ('anarbib-team-invitations-remind', '35 9 * * *', $c$SELECT public.fn_team_invitation_remind()$c$, true),
    ('anarbib-team-pending-removal-complete', '0 * * * *', $c$SELECT public.fn_cron_team_pending_removal_complete();$c$, true),
    ('anarbib-work-titles-autofill', '*/10 * * * *', $c$select public.fn_work_titles_autofill_call()$c$, true),
    ('anarbib_execute_profile_proposals', '*/15 * * * *', $c$SELECT public.fn_execute_due_profile_proposals();$c$, true),
    ('anarbib_expire_profile_proposals', '0 3 * * *', $c$SELECT public.fn_expire_overdue_profile_proposals();$c$, true),
    ('gc-fonds-deposits', '30 4 * * *', $c$ SELECT ingest.fn_cron_gc_deposits(); $c$, true),
    ('reconcile-authority-dispatch', '*/5 * * * *', $c$ SELECT public.fn_cron_reconcile_authority_dispatch(); $c$, true),
    ('reconcile-task-dispatch', '*/5 * * * *', $c$ select public.fn_cron_reconcile_task_dispatch(); $c$, true),
    ('refresh-mv-books-catalog-list', '*/15 * * * *', $c$SELECT public.refresh_mv_books_catalog_list_v1();$c$, true)
$fn$;

-- ─── Vérification ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_f text; v_n int;
BEGIN
  FOREACH v_f IN ARRAY ARRAY['team_notification_outbox', 'lettre_notification_outbox', 'gazette_submission_notification_outbox', 'cartography_submission_notification_outbox', 'bug_report_notification_outbox'] LOOP
    SELECT count(*) INTO v_n FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = v_f AND column_name IN ('refused_recipients', 'next_attempt_at');
    IF v_n <> 2 THEN RAISE EXCEPTION 'F12 : colonnes absentes sur %', v_f; END IF;
  END LOOP;
  IF has_function_privilege('authenticated', 'private.fn_outbox_rejouer()', 'EXECUTE')
     OR has_function_privilege('anon', 'api.fn_outbox_acquitter(text, bigint, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'F12 : droits inattendus';
  END IF;
  IF (SELECT count(*) FROM private.fn_crons_attendus()) <> 39 THEN
    RAISE EXCEPTION 'F12 : fn_crons_attendus doit porter 39 jobs';
  END IF;
END $$;

COMMIT;
