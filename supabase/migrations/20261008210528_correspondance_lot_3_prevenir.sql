-- =====================================================================
-- AnarBib — G19 lot 3 : la correspondance prévient — cloche et courriel
-- Date    : 2026-10-08
-- Ref     : backlog v34 G19 ; REGISTRE CORR-2 (adresse collective), CORR-4
--           (pas de réponse par courriel), CORR-6 (l'administration ne lit pas).
--
-- 1. Un message nouveau (INSERT dans public.library_messages, par les RPC du
--    lot 1 seulement) lève l'événement `correspondance_message_created` vers
--    notify-event, par fn_dispatch_notify_event (HTTP vers la fonction Edge,
--    secret du coffre) ; le handler _shared/domain/correspondance.ts fait le
--    reste : une ligne de cloche par coordination active de chaque autre
--    bibliothèque du fil, un courriel à l'adresse collective de chacune dans
--    sa locale, rien si son canal est coupé. La fonction de déclencheur est
--    DEFINER et fermée à tous (un trigger n'a besoin d'aucun grant) ; un
--    envoi qui échoue n'annule jamais le message (fn_dispatch_notify_event
--    avale ses erreurs en WARNING, et le déclencheur aussi).
-- 2. Constat de la session voisine (08/10) : une bibliothèque en mode
--    `isolated` ne participe pas au réseau — elle ne reçoit pas de
--    correspondance. api.fn_correspondance_ouvrir la refuse désormais
--    (HINT error.correspondance.library_isolated, dix locales) ; l'écran ne
--    la propose déjà plus. Réécriture sur la définition VIVANTE par ancre
--    comptée ; signature, droits et search_path inchangés.
-- Suite : tests/sql/correspondance_lot1_tests.sql (T12, T13 ajoutés).
-- =====================================================================

-- ─────────────────────────────────────────────────────────────────────
-- 1. Le déclencheur
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tg_library_message_notifier()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  BEGIN
    PERFORM public.fn_dispatch_notify_event(
      'correspondance_message_created', NEW.id,
      jsonb_build_object('conversation_id', NEW.conversation_id, 'library_id', NEW.library_id));
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'tg_library_message_notifier(%): %', NEW.id, SQLERRM;
  END;
  RETURN NULL;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.tg_library_message_notifier() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_library_messages_notifier ON public.library_messages;
CREATE TRIGGER trg_library_messages_notifier
  AFTER INSERT ON public.library_messages
  FOR EACH ROW EXECUTE FUNCTION public.tg_library_message_notifier();

-- ─────────────────────────────────────────────────────────────────────
-- 2. Une bibliothèque isolée ne reçoit pas de correspondance
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION pg_temp.g19l3_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN RAISE EXCEPTION 'G19 lot 3 — % : ancre vide', p_quoi; END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN RAISE EXCEPTION 'G19 lot 3 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n; END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;
DO $g19l3_isolee$
DECLARE v_def text;
BEGIN
  v_def := replace(pg_get_functiondef('api.fn_correspondance_ouvrir(uuid, uuid, text, text, text)'::regprocedure), E'\r', '');
  v_def := pg_temp.g19l3_remplacer('fn_correspondance_ouvrir (destinataire)', v_def,
$a$  IF NOT EXISTS (SELECT 1 FROM public.libraries l WHERE l.id = p_destinataire_id AND l.is_active = true) THEN
    RAISE EXCEPTION 'library_not_found' USING errcode = 'P0002', hint = 'error.correspondance.library_not_found';
  END IF;
$a$,
$b$  IF NOT EXISTS (SELECT 1 FROM public.libraries l WHERE l.id = p_destinataire_id AND l.is_active = true) THEN
    RAISE EXCEPTION 'library_not_found' USING errcode = 'P0002', hint = 'error.correspondance.library_not_found';
  END IF;
  -- G19 lot 3 : une bibliothèque « isolée » ne participe pas au réseau.
  IF EXISTS (SELECT 1 FROM public.libraries l WHERE l.id = p_destinataire_id AND l.network_mode = 'isolated') THEN
    RAISE EXCEPTION 'library_isolated' USING errcode = '22023', hint = 'error.correspondance.library_isolated';
  END IF;
$b$);
  EXECUTE v_def;
END
$g19l3_isolee$;

-- ─────────────────────────────────────────────────────────────────────
-- 3. Vérifications
-- ─────────────────────────────────────────────────────────────────────
DO $g19l3_verif$
DECLARE v_e text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_library_messages_notifier' AND tgrelid = 'public.library_messages'::regclass AND NOT tgisinternal) THEN
    v_e := v_e || ' declencheur';
  END IF;
  IF has_function_privilege('authenticated', 'public.tg_library_message_notifier()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.tg_library_message_notifier()', 'EXECUTE')
     OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a WHERE p.oid = 'public.tg_library_message_notifier()'::regprocedure AND a.grantee = 0) THEN
    v_e := v_e || ' droits-declencheur';
  END IF;
  IF (SELECT prosrc FROM pg_proc WHERE oid = 'api.fn_correspondance_ouvrir(uuid, uuid, text, text, text)'::regprocedure) !~ 'library_isolated' THEN
    v_e := v_e || ' isolee';
  END IF;
  IF NOT has_function_privilege('authenticated', 'api.fn_correspondance_ouvrir(uuid, uuid, text, text, text)', 'EXECUTE')
     OR has_function_privilege('anon', 'api.fn_correspondance_ouvrir(uuid, uuid, text, text, text)', 'EXECUTE') THEN
    v_e := v_e || ' droits-ouvrir';
  END IF;
  IF v_e <> '' THEN RAISE EXCEPTION 'G19 lot 3 : vérification en échec :%', v_e; END IF;
  RAISE NOTICE 'G19 lot 3 : vérifications OK — le déclencheur prévient, une isolée ne reçoit pas';
END
$g19l3_verif$;

NOTIFY pgrst, 'reload schema';
