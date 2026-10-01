-- =====================================================================
-- F1, suite (décision de Xavier, 01/10/2026) : une demande de consultation
-- expire 60 jours après sa création.
--
-- Le cron d'expiration (20261001194818, fn_cron_expire_consultas) suit la spec
-- flux-consultations v2.2 §5.3 : il expire les lignes dont expires_at est passé.
-- Or aucun écran ne pose expires_at (AccountPage, BookPage, CatalogPage
-- appellent api.create_consulta_local sans p_expires_at) : 22 lignes sur 22 à
-- NULL, le cron ne faisait rien. Désormais fn_v2_create_consulta_local_by_holdings,
-- la seule fonction qui crée des lignes de consultation, pose 60 jours quand
-- l'appel n'en donne pas. 60 jours = la borne haute d'un créneau (§5.4, « +1 h à
-- +60 j ») : une demande que personne n'a planifiée dans ce délai n'en aura pas.
--
-- Nouvelles demandes seulement (décision du 01/10) : les lignes existantes
-- gardent expires_at à NULL, aucune expiration en masse.
-- Réécriture depuis la définition RÉELLE, un remplacement compté, empreinte gardée.
-- Suite : tests/sql/branches_mortes_courriel_tests.sql (T19).
-- =====================================================================

DO $mig$
DECLARE
  v_def text;
  v_n int;
  v_avant text := $a$      'ativa',
      p_expires_at,
$a$;
  v_apres text := $b$      'ativa',
      -- 01/10/2026 (F1, décision de Xavier) : 60 jours si l'appel ne dit rien.
      coalesce(p_expires_at, timezone('utc', now()) + interval '60 days'),
$b$;
BEGIN
  IF (SELECT md5(replace(prosrc, E'\r', '')) FROM pg_proc
       WHERE oid = 'public.fn_v2_create_consulta_local_by_holdings(uuid,bigint[],timestamptz,text)'::regprocedure)
     <> '67f41b3b66c78c099fbb8a44ee775729' THEN
    RAISE EXCEPTION 'fn_v2_create_consulta_local_by_holdings a changé depuis le relevé du 01/10 — relire avant de réécrire';
  END IF;
  v_def := replace(pg_get_functiondef('public.fn_v2_create_consulta_local_by_holdings(uuid,bigint[],timestamptz,text)'::regprocedure), E'\r', '');
  v_n := (length(v_def) - length(replace(v_def, v_avant, ''))) / length(v_avant);
  IF v_n <> 1 THEN RAISE EXCEPTION 'ancre p_expires_at trouvée % fois (1 attendue)', v_n; END IF;
  EXECUTE replace(v_def, v_avant, v_apres);

  IF pg_get_functiondef('public.fn_v2_create_consulta_local_by_holdings(uuid,bigint[],timestamptz,text)'::regprocedure)
       NOT LIKE '%coalesce(p_expires_at, timezone(''utc'', now()) + interval ''60 days'')%' THEN
    RAISE EXCEPTION 'réécriture incomplète';
  END IF;
END
$mig$;
