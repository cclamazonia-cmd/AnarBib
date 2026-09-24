-- =====================================================================
-- AnarBib — Tests d'acceptation : la sonde du transport mail
-- Date    : 2026-09-24  ·  Backlog v34 F7 / DOC-SILENCE-1 cas (a)
-- Ref     : migration 20260924180538_echec_de_transport_mail_ouvre_un_incident
--
-- Pourquoi cette suite existe : request-password-reset répond 200 quoi qu'il
-- arrive (anti-énumération). Quand le transport refuse, rien ne le disait à
-- personne. Le module partagé note désormais chaque échec dans
-- mail_transport_failures et health-probe en fait un incident `mail_transport`.
-- Ici on éprouve la partie base : la table, la sonde, ses droits, la CHECK.
--
--   T1 la table existe, RLS activée, fermée à anon
--   T2 sans échec récent, la sonde répond ok, rubrique vide, dans la forme
--      que lit health-probe ({ok booléen, rubriques en TABLEAUX, verifie_le})
--   T3 un échec noté à l'instant → pas ok, une entrée, avec label et erreur
--   T4 un échec vieux de 31 minutes ne compte plus → ok (le calme referme)
--   T5 ni anon ni authenticated n'exécutent la sonde ; service_role oui
--   T6 la CHECK accepte mail_transport et refuse toujours un genre inconnu
--
--   Bilan OK : 'MAIL-TRANSPORT OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed   int := 0;
  v_failed   int := 0;
  v_failures text[] := '{}';
  v_t        text;
  v          jsonb;
  v_refuse   boolean;
  v_id       bigint;
BEGIN
  -- Table propre pour la suite (le banc est jetable, la prod n'est pas ici).
  delete from public.mail_transport_failures;

  v_t := 'T1 table présente, RLS activée, fermée à anon';
  IF to_regclass('public.mail_transport_failures') IS NOT NULL
     AND (select relrowsecurity from pg_class where oid = 'public.mail_transport_failures'::regclass)
     AND NOT has_table_privilege('anon', 'public.mail_transport_failures', 'select')
     AND has_table_privilege('service_role', 'public.mail_transport_failures', 'insert')
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  v_t := 'T2 sans échec récent : ok, dans la forme lue par health-probe';
  v := public.fn_healthcheck_mail_transport();
  IF jsonb_typeof(v->'ok') = 'boolean' AND (v->>'ok')::boolean
     AND jsonb_typeof(v->'echecs_recents') = 'array' AND jsonb_array_length(v->'echecs_recents') = 0
     AND v ? 'verifie_le' AND v ? 'que_faire'
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T3 un échec à l''instant → pas ok, une entrée nommée';
  insert into public.mail_transport_failures (label, recipients, error)
    values ('password-reset', 1, 'Resend HTTP 401: {"message":"API key is invalid"}');
  v := public.fn_healthcheck_mail_transport();
  IF NOT (v->>'ok')::boolean
     AND jsonb_array_length(v->'echecs_recents') = 1
     AND v->'echecs_recents'->0->>'label' = 'password-reset'
     AND v->'echecs_recents'->0->>'erreur' like 'Resend HTTP 401%'
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T4 un échec vieux de 31 minutes ne compte plus';
  update public.mail_transport_failures set occurred_at = now() - interval '31 minutes';
  v := public.fn_healthcheck_mail_transport();
  IF (v->>'ok')::boolean AND jsonb_array_length(v->'echecs_recents') = 0
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T5 fermée à anon et authenticated, ouverte à service_role';
  IF NOT has_function_privilege('anon', 'public.fn_healthcheck_mail_transport()', 'execute')
     AND NOT has_function_privilege('authenticated', 'public.fn_healthcheck_mail_transport()', 'execute')
     AND has_function_privilege('service_role', 'public.fn_healthcheck_mail_transport()', 'execute')
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  v_t := 'T6 la CHECK accepte mail_transport et refuse un genre inconnu';
  insert into public.service_health_incidents (kind, reason)
    values ('mail_transport', 'suite mail_transport_tests') returning id into v_id;
  delete from public.service_health_incidents where id = v_id;
  BEGIN
    insert into public.service_health_incidents (kind, reason) values ('genre_inconnu', 'doit échouer');
    v_refuse := false;
  EXCEPTION WHEN check_violation THEN
    v_refuse := true;
  END;
  IF v_refuse THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  delete from public.mail_transport_failures;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'MAIL-TRANSPORT : % test(s) en échec — %', v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE NOTICE 'MAIL-TRANSPORT OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
