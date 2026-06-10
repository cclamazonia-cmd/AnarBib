-- Migration : durcissement IMP-14 — wrappers d'import en coordenador-only
-- Auteur  : Claude Opus 4.8
-- Session : Durcissement IMP-14 (import/export sous l'autorite des coordinateurs)
-- Date    : 2026-06-10 (UTC)
--
-- Decision (Xavier) : la page Importacoes est gatee coordenador en navigation
-- (canSeeImportacoes = isCoord). Les wrappers RPC fn_import_* etaient eux gates
-- sur can_access_painel (= tout staff : librarian OU coordenador), ce qui
-- laissait un·e librarian appeler les RPC d'import directement via l'API alors
-- que la page lui est masquee. On aligne le backend sur la nav : coordenador
-- (ou admin reseau) uniquement.
--
-- Methode : on recree chaque wrapper a partir de sa definition LIVE
-- (pg_get_functiondef) en inserant un controle coordenador JUSTE APRES le
-- garde-fou staff existant. Aucune autre ligne n'est touchee. Idempotent
-- (saute si deja durci) et transactionnel (rollback complet si une fonction
-- echoue). fn_import_register_oai_source est exclu : deja restreint a l'admin
-- reseau (plus strict).

DO $mig$
DECLARE
  v_name  text;
  v_oid   oid;
  v_def   text;
  v_new   text;
  v_names text[] := ARRAY[
    'fn_import_create', 'fn_import_dispatch', 'fn_import_harvest_oai',
    'fn_import_ingest_candidate', 'fn_import_list_oai_sources', 'fn_import_list_run_rows',
    'fn_import_list_runs', 'fn_import_list_sources', 'fn_import_process_deposit',
    'fn_import_promote', 'fn_import_register_deposit_source', 'fn_import_set_editorial',
    'fn_import_set_rows_review'
  ];
BEGIN
  FOREACH v_name IN ARRAY v_names LOOP
    SELECT p.oid INTO v_oid
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_name;

    IF v_oid IS NULL THEN
      RAISE EXCEPTION 'IMP-14 : fonction public.% introuvable', v_name;
    END IF;

    v_def := pg_get_functiondef(v_oid);

    -- Idempotence : deja durci ?
    IF position('Acesso restrito ao coordenador da biblioteca.' in v_def) > 0 THEN
      CONTINUE;
    END IF;

    -- Insere le controle coordenador juste apres le garde-fou staff standard.
    v_new := regexp_replace(
      v_def,
      '(RAISE EXCEPTION ''Acesso bibliotecario obrigatorio\.'';\s*END IF;)',
      E'\\1\n  IF v_actor.role IS DISTINCT FROM ''coordenador'' AND NOT public.fn_caller_is_network_admin() THEN\n    RAISE EXCEPTION ''Acesso restrito ao coordenador da biblioteca.'';\n  END IF;',
      ''
    );

    IF v_new = v_def THEN
      RAISE EXCEPTION 'IMP-14 : ancre garde-fou introuvable dans % (abandon)', v_name;
    END IF;

    EXECUTE v_new;
    RAISE NOTICE 'IMP-14 : % durci (coordenador-only)', v_name;
  END LOOP;
END
$mig$;

-- Verification : les 13 wrappers portent desormais le controle coordenador.
DO $verif$
DECLARE
  v_name    text;
  v_missing text[] := ARRAY[]::text[];
  v_names   text[] := ARRAY[
    'fn_import_create', 'fn_import_dispatch', 'fn_import_harvest_oai',
    'fn_import_ingest_candidate', 'fn_import_list_oai_sources', 'fn_import_list_run_rows',
    'fn_import_list_runs', 'fn_import_list_sources', 'fn_import_process_deposit',
    'fn_import_promote', 'fn_import_register_deposit_source', 'fn_import_set_editorial',
    'fn_import_set_rows_review'
  ];
BEGIN
  FOREACH v_name IN ARRAY v_names LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = v_name
         AND p.prosrc ILIKE '%Acesso restrito ao coordenador da biblioteca.%'
    ) THEN
      v_missing := array_append(v_missing, v_name);
    END IF;
  END LOOP;

  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'IMP-14 : durcissement manquant sur : %', array_to_string(v_missing, ', ');
  END IF;

  RAISE NOTICE 'IMP-14 : 13 wrappers d''import durcis (coordenador-only). OK.';
END
$verif$;
