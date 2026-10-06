-- =====================================================================
-- J11 — Les restes de F1 sans lecteur quittent la base.
-- Autorisation écrite de Xavier, 06/10/2026 (« Oui, je l'autorise »).
--
-- F1 (01/10, 57a4aafc, 20261001194818) avait retiré les branches mortes de la
-- chaîne de courriel sans supprimer de données : trois colonnes de
-- library_notification_policies et la table loan_midpoint_message_log étaient
-- gardées, « sans lecteur » par COMMENT, leur suppression demandant une
-- autorisation écrite. Mesuré le 06/10 en production :
--   - reservation_mail_retirada_reagendada_enabled : ni lue ni écrite ;
--   - mid_loan_message_enabled, reading_recommendations_enabled : écrites par
--     upsert_library_notification_policies (clés d'une charge jsonb que
--     l'application n'envoie plus) et exposées par v_library_notification_context,
--     qu'aucune fonction Edge ne lit pour elles ;
--   - loan_midpoint_message_log : 0 ligne, aucun écrivain ; citée seulement par
--     un commentaire de fn_delete_history_item (le DELETE passe par cascade).
--
-- Ordre : garde (la table est vide), réécriture de l'upsert, vue recréée sans
-- les deux colonnes (security_invoker, commentaire et droits rejoués depuis
-- ceux de la base), colonnes supprimées, table supprimée, commentaire de
-- fn_delete_history_item mis à jour, garde finale. Réécritures depuis les
-- définitions réelles, ancres comptées, rien de retapé.
--
-- Exploitation : la table figurait dans ~/anarbib-ops/bg2-denylist.txt (hors
-- dépôt) ; retirée de cette liste AVANT le déploiement, sinon la sauvegarde
-- courte s'arrête sur « Corrige la denylist ». Retirée aussi de
-- deploy/bg2-known-tables.txt dans le même commit.
-- Suite : tests/sql/f1_restes_supprimes_tests.sql.
-- =====================================================================
DO $migration$
DECLARE
  v_def text;
  v_n int;
  v_vue text;
  v_acl aclitem[];
  v_cmt text;
  r record;
  -- upsert_library_notification_policies : trois ancres
  u1 constant text := E'    mid_loan_message_enabled,\n    reading_recommendations_enabled,\n';
  u2 constant text := E'    coalesce((p_policies->>''mid_loan_message_enabled'')::boolean, false),\n'
                   || E'    coalesce((p_policies->>''reading_recommendations_enabled'')::boolean, false),\n';
  u3 constant text := E'      mid_loan_message_enabled = excluded.mid_loan_message_enabled,\n'
                   || E'      reading_recommendations_enabled = excluded.reading_recommendations_enabled,\n';
  -- v_library_notification_context : une ancre
  w1 constant text := E'    pol.mid_loan_message_enabled,\n    pol.reading_recommendations_enabled,\n';
  -- fn_delete_history_item : le commentaire
  h1 constant text := ' + loan_midpoint_message_log';
BEGIN
  -- (0) garde : la table est vide, comme mesuré le 06/10
  SELECT count(*) INTO v_n FROM public.loan_midpoint_message_log;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'J11 : loan_midpoint_message_log porte % ligne(s) ; mesurée vide le 06/10, rien n''est supprimé', v_n;
  END IF;

  -- (1) l'upsert n'écrit plus les deux colonnes
  v_def := replace(pg_get_functiondef('public.upsert_library_notification_policies(uuid,jsonb)'::regprocedure), E'\r', '');
  IF (length(v_def) - length(replace(v_def, u1, ''))) / length(u1) <> 1
     OR (length(v_def) - length(replace(v_def, u2, ''))) / length(u2) <> 1
     OR (length(v_def) - length(replace(v_def, u3, ''))) / length(u3) <> 1 THEN
    RAISE EXCEPTION 'J11 : upsert_library_notification_policies n''est pas celle attendue';
  END IF;
  EXECUTE replace(replace(replace(v_def, u1, ''), u2, ''), u3, '');

  -- (2) la vue, recréée sans les deux colonnes
  v_vue := pg_get_viewdef('public.v_library_notification_context'::regclass, true);
  IF (length(v_vue) - length(replace(v_vue, w1, ''))) / length(w1) <> 1 THEN
    RAISE EXCEPTION 'J11 : v_library_notification_context n''est pas celle attendue';
  END IF;
  SELECT relacl INTO v_acl FROM pg_class WHERE oid = 'public.v_library_notification_context'::regclass;
  v_cmt := obj_description('public.v_library_notification_context'::regclass, 'pg_class');
  DROP VIEW public.v_library_notification_context;
  EXECUTE 'CREATE VIEW public.v_library_notification_context WITH (security_invoker = true) AS '
          || rtrim(replace(v_vue, w1, ''), E'; \n');
  REVOKE ALL ON public.v_library_notification_context FROM PUBLIC, anon, authenticated, service_role;
  FOR r IN SELECT a.grantee, a.privilege_type FROM aclexplode(v_acl) a
            WHERE a.grantee <> (SELECT relowner FROM pg_class WHERE oid = 'public.v_library_notification_context'::regclass)
  LOOP
    EXECUTE format('GRANT %s ON public.v_library_notification_context TO %s', r.privilege_type,
                   CASE WHEN r.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(r.grantee::regrole::text) END);
  END LOOP;
  IF v_cmt IS NOT NULL THEN
    EXECUTE format('COMMENT ON VIEW public.v_library_notification_context IS %L', v_cmt);
  END IF;
  IF (SELECT array_agg(x ORDER BY x) FROM (SELECT a.grantee::text || ':' || a.privilege_type x FROM pg_class c, aclexplode(c.relacl) a
        WHERE c.oid = 'public.v_library_notification_context'::regclass) s)
     IS DISTINCT FROM
     (SELECT array_agg(x ORDER BY x) FROM (SELECT a.grantee::text || ':' || a.privilege_type x FROM aclexplode(v_acl) a) s) THEN
    RAISE EXCEPTION 'J11 : les droits de v_library_notification_context ne sont pas ceux d''avant';
  END IF;

  -- (3) et (4) colonnes et table
  ALTER TABLE public.library_notification_policies
    DROP COLUMN reservation_mail_retirada_reagendada_enabled,
    DROP COLUMN mid_loan_message_enabled,
    DROP COLUMN reading_recommendations_enabled;
  DROP TABLE public.loan_midpoint_message_log;

  -- (5) le commentaire de fn_delete_history_item ne cite plus la table
  v_def := pg_get_functiondef('public.fn_delete_history_item(text,bigint)'::regprocedure);
  IF (length(v_def) - length(replace(v_def, h1, ''))) / length(h1) <> 1 THEN
    RAISE EXCEPTION 'J11 : fn_delete_history_item n''est pas celle attendue';
  END IF;
  EXECUTE replace(v_def, h1, '');
END
$migration$;

-- Garde finale
DO $garde$
BEGIN
  IF to_regclass('public.loan_midpoint_message_log') IS NOT NULL
     OR EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
                  AND table_name IN ('library_notification_policies', 'v_library_notification_context')
                  AND column_name IN ('reservation_mail_retirada_reagendada_enabled', 'mid_loan_message_enabled', 'reading_recommendations_enabled'))
     OR EXISTS (SELECT 1 FROM pg_proc WHERE prosrc ~ '(mid_loan_message_enabled|reading_recommendations_enabled|loan_midpoint_message_log)')
     OR NOT EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.v_library_notification_context'::regclass
                      AND reloptions @> ARRAY['security_invoker=true'])
     OR has_table_privilege('anon', 'public.v_library_notification_context', 'SELECT') THEN
    RAISE EXCEPTION 'J11 : suppression incomplète, ou vue sans security_invoker, ou ouverte à anon';
  END IF;
END
$garde$;
