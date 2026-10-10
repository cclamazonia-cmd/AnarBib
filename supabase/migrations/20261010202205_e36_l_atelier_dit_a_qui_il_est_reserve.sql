-- =====================================================================
-- AnarBib — E36 : l'Atelier des autorités dit à qui il est réservé
-- Date    : 2026-10-10
-- Ref     : backlog v34 E36 (constat de Xavier, 10/10 : le lien d'un courriel
--           de proposition, ouvert avec un compte lecteur, affichait deux fois
--           « erreur technique (42501) »).
--
-- Les RPC de l'Atelier refusaient juste (équipes, contributeurs du réseau,
-- administration) mais sans mot traduisible : `localizeError` ne traduit que
-- les HINT en `error.*`, et les trois RPC de lecture n'en portaient aucun ;
-- les RPC d'écriture portaient des HINT `atelier.error.*`, jamais traduits.
--
--   1. api.fn_authority_list()               → HINT error.atelier.reserved
--   2. api.conv_revue_resume(), conv_revue_list(…) → HINT error.atelier.reservedStaff
--   3. api.fn_authority_propose / apply / object, api.fn_work_title_validate,
--      public.fn_work_proposal_check, public.fn_authority_split :
--      `atelier.error.X` → `error.atelier.X` (vingt-cinq clés dans les dix locales,
--      scripts/i18n-add-atelier-erreurs.cjs).
-- Chaque fonction est réécrite sur sa définition vivante (md5 vérifié, ancre
-- comptée) : corps, droits et DEFINER inchangés. Suite : tests/sql/atelier_reserve_tests.sql.
-- =====================================================================

DO $e36$
DECLARE
  v text; n int;
  r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('api.fn_authority_list()'::regprocedure,                           'd40eef2c9a908f691c0b5cef92666d07',
       'USING ERRCODE = ''42501'';', 'USING ERRCODE = ''42501'', HINT = ''error.atelier.reserved'';', 1),
    ('api.conv_revue_resume()'::regprocedure,                           '99c6f66d02ad015121112fe3d6d2e902',
       'raise exception ''acesso reservado à equipe'' using errcode = ''42501'';', 'raise exception ''acesso reservado à equipe'' using errcode = ''42501'', hint = ''error.atelier.reservedStaff'';', 1),
    ('api.conv_revue_list(text,text,integer,integer)'::regprocedure,    '1b3db06753b967490d894654f81c129a',
       'raise exception ''acesso reservado à equipe'' using errcode = ''42501'';', 'raise exception ''acesso reservado à equipe'' using errcode = ''42501'', hint = ''error.atelier.reservedStaff'';', 1),
    ('api.fn_authority_propose(text,text,bigint,bigint,jsonb,text)'::regprocedure, '750652481cf5561a39ce7721ddf787d7',
       'hint = ''atelier.error.', 'hint = ''error.atelier.', 7),
    ('api.fn_authority_apply(uuid)'::regprocedure,                      '3caa722408c571a530e2b152ede41481',
       'hint = ''atelier.error.', 'hint = ''error.atelier.', 5),
    ('api.fn_authority_object(uuid,uuid,text)'::regprocedure,           '2d66cb34e1717ec148debbf25954278e',
       'HINT = ''atelier.error.', 'HINT = ''error.atelier.', 2),
    ('api.fn_work_title_validate(bigint,text,text)'::regprocedure,      '318d901bf556ba6b276b50c3026fe56b',
       'hint = ''atelier.error.', 'hint = ''error.atelier.', 3),
    ('public.fn_authority_split(bigint,jsonb,text)'::regprocedure,      'f8450d6c198c920349e66d6706bf2857',
       'hint = ''atelier.error.', 'hint = ''error.atelier.', 1),
    ('public.fn_work_proposal_check(text,bigint,bigint,jsonb)'::regprocedure, 'e3f0857d8fae57ba402b54da4d43f0eb',
       'hint = ''atelier.error.', 'hint = ''error.atelier.', 17)
  ) AS t(fn, md5_attendu, ancre, remplacement, attendu) LOOP
    v := pg_get_functiondef(r.fn);
    IF md5(v) <> r.md5_attendu THEN
      RAISE EXCEPTION 'E36 : % n''est pas la définition attendue (md5 %) — repartir de la définition réelle', r.fn, md5(v);
    END IF;
    n := (length(v) - length(replace(v, r.ancre, ''))) / length(r.ancre);
    IF n <> r.attendu THEN
      RAISE EXCEPTION 'E36 : ancre « % » trouvée % fois dans % (attendu %)', r.ancre, n, r.fn, r.attendu;
    END IF;
    v := replace(v, r.ancre, r.remplacement);
    EXECUTE v;
    RAISE NOTICE 'E36 : % réécrite (% remplacement(s))', r.fn, n;
  END LOOP;
END
$e36$;

DO $e36_verif$
DECLARE v_e text := '';
BEGIN
  IF pg_get_functiondef('api.fn_authority_list()'::regprocedure) NOT LIKE '%error.atelier.reserved''%' THEN v_e := v_e || ' list'; END IF;
  IF pg_get_functiondef('api.conv_revue_resume()'::regprocedure) NOT LIKE '%error.atelier.reservedStaff%' THEN v_e := v_e || ' resume'; END IF;
  IF pg_get_functiondef('api.conv_revue_list(text,text,integer,integer)'::regprocedure) NOT LIKE '%error.atelier.reservedStaff%' THEN v_e := v_e || ' revue_list'; END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname IN ('public', 'api', 'private') AND p.prosrc LIKE '%atelier.error.%') THEN v_e := v_e || ' hints-anciens'; END IF;
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'api' AND p.proname IN ('fn_authority_list','conv_revue_resume','conv_revue_list','fn_authority_propose','fn_authority_apply','fn_authority_object')
         AND p.prosecdef AND coalesce(p.proconfig::text, '') LIKE '%search_path%') <> 6 THEN v_e := v_e || ' definer-ou-search_path'; END IF;
  IF has_function_privilege('anon', 'api.fn_authority_list()', 'EXECUTE') THEN v_e := v_e || ' anon-list'; END IF;
  IF v_e <> '' THEN RAISE EXCEPTION 'E36 : vérification en échec :%', v_e; END IF;
  RAISE NOTICE 'E36 : vérifications OK — neuf fonctions de l''Atelier portent des HINT traduisibles, droits inchangés';
END
$e36_verif$;

NOTIFY pgrst, 'reload schema';
