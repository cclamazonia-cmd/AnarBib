-- ============================================================================
-- Renommage : fn_dispatch_circulation_notify_event -> fn_dispatch_notify_event
-- Item 3 cloture chantier « carte ma bibliotheque ». 2026-06-04.
-- ----------------------------------------------------------------------------
-- Le nom « circulation » etait trompeur : c'est un poster notify-event generique
-- (event, record_id, extra), utilise bien au-dela de la circulation (reader/
-- library messages, RGPD, outbox team...). 13 appelants referencent l'ancien nom.
--
-- Methode : on renomme le dispatcher canonique, puis on regenere chaque appelant
-- via pg_get_functiondef + replace (aucune reproduction manuelle de corps
-- critiques). ALTER ... RENAME preserve l'ACL (REVOKE) et SECURITY DEFINER ;
-- CREATE OR REPLACE preserve droits et commentaires.
-- Purement DB : le code EF/front ne reference pas le nom de la fonction.
-- ============================================================================

-- 1. Renommer le dispatcher canonique
ALTER FUNCTION public.fn_dispatch_circulation_notify_event(text, bigint, jsonb)
  RENAME TO fn_dispatch_notify_event;

-- 2. Reecrire chaque appelant referencant encore l'ancien nom.
--    On collecte d'abord les oids (pas de cursor live sur le catalogue pendant
--    qu'on recree des fonctions), puis FOREACH + EXECUTE.
DO $rewrite$
DECLARE
  v_oids oid[];
  v_oid  oid;
  v_def  text;
  v_count int := 0;
BEGIN
  SELECT array_agg(p.oid) INTO v_oids
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language  l ON l.oid = p.prolang
  WHERE p.prokind = 'f'
    AND n.nspname IN ('public','api')
    AND l.lanname IN ('plpgsql','sql')
    AND pg_get_functiondef(p.oid) LIKE '%fn_dispatch_circulation_notify_event%';

  IF v_oids IS NULL THEN
    RAISE NOTICE 'Aucun appelant a reecrire.';
    RETURN;
  END IF;

  FOREACH v_oid IN ARRAY v_oids LOOP
    v_def := replace(
      pg_get_functiondef(v_oid),
      'fn_dispatch_circulation_notify_event',
      'fn_dispatch_notify_event'
    );
    EXECUTE v_def;
    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE 'Reecriture: % appelant(s) mis a jour vers fn_dispatch_notify_event.', v_count;
END;
$rewrite$;

-- 3. Verification (rollback auto via bloc DO)
DO $verify$
DECLARE
  v_new int; v_old int; v_refs int;
BEGIN
  SELECT count(*) INTO v_new FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='fn_dispatch_notify_event';
  IF v_new <> 1 THEN RAISE EXCEPTION 'VERIF: fn_dispatch_notify_event introuvable (count=%).', v_new; END IF;

  SELECT count(*) INTO v_old FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='fn_dispatch_circulation_notify_event';
  IF v_old <> 0 THEN RAISE EXCEPTION 'VERIF: ancien nom encore present (count=%).', v_old; END IF;

  SELECT count(*) INTO v_refs
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_language l ON l.oid=p.prolang
   WHERE p.prokind='f' AND n.nspname IN ('public','api') AND l.lanname IN ('plpgsql','sql')
     AND pg_get_functiondef(p.oid) LIKE '%fn_dispatch_circulation_notify_event%';
  IF v_refs <> 0 THEN RAISE EXCEPTION 'VERIF: % fonction(s) referencent encore l''ancien nom.', v_refs; END IF;

  RAISE NOTICE 'VERIF OK: rename complet, 0 reference residuelle.';
END;
$verify$;

NOTIFY pgrst, 'reload schema';
