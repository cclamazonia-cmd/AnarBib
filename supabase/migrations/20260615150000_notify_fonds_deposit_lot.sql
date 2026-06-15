-- =========================================================================
-- Chantier « gestion des fichiers numériques », point 7 (D3 d'EX-4) — notif réceptrice.
--
-- Un transfert DIRECT de fonds (EX-4) dépose un lot dans la file de revue de la
-- companheira réceptrice SANS l'avertir : elle pouvait ne jamais le voir. On crée
-- donc une TÂCHE IN-APP (painel_internal_tasks) pour la biblio réceptrice à la
-- finalisation du run (ready_for_review). Mail laissé en suivi (non bloquant).
--
-- L'appelant (EF deposit-fonds-direct) agit pour le compte de la SOURCE → il n'est
-- pas staff de la réceptrice → fn_task_create (INVOKER, gardé par RLS) ne convient
-- pas. D'où une RPC SECURITY DEFINER dédiée, réservée à service_role (l'EF).
-- =========================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_notify_fonds_deposit_received(p_run_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, ingest, pg_catalog
AS $$
DECLARE
  v_run     ingest.partner_catalog_import_runs%rowtype;
  v_source  text;
  v_notices int;
  v_files   int;
  v_tag     text;
  v_task_id uuid;
  v_title_i18n jsonb;
BEGIN
  IF p_run_id IS NULL THEN RAISE EXCEPTION 'run_id obrigatorio.'; END IF;
  SELECT * INTO v_run FROM ingest.partner_catalog_import_runs WHERE id = p_run_id;
  IF NOT FOUND OR v_run.library_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'run/library introuvable');
  END IF;

  v_source  := coalesce(v_run.summary->>'source_name', 'companheira');
  v_notices := coalesce((v_run.summary->>'inserted_rows')::int, v_run.imported_rows, 0);
  v_files   := coalesce((v_run.summary->>'received_files_deposited')::int, 0);
  v_tag     := 'fonds-run:' || p_run_id::text;

  -- Idempotence : une seule tâche par run.
  IF EXISTS (SELECT 1 FROM public.painel_internal_tasks t
              WHERE t.library_id = v_run.library_id AND t.tags @> ARRAY[v_tag]) THEN
    RETURN jsonb_build_object('ok', true, 'created', false, 'reason', 'déjà notifié');
  END IF;

  v_title_i18n := jsonb_build_object(
    'pt-BR', 'Lote de fundos recebido — rever e anexar',
    'fr',    'Lot de fonds reçu — examiner et attacher',
    'es',    'Lote de fondos recibido — revisar y adjuntar',
    'en',    'Funds batch received — review and attach',
    'it',    'Lotto di fondi ricevuto — esaminare e allegare',
    'de',    'Bestandslieferung erhalten — prüfen und anhängen',
    'ca',    'Lot de fons rebut — revisar i adjuntar',
    'eo',    'Fonduso ricevita — kontroli kaj aldoni',
    'nl',    'Fondsenpartij ontvangen — controleren en koppelen',
    'el',    'Ελήφθη παρτίδα αρχείων — έλεγχος και επισύναψη'
  );

  INSERT INTO public.painel_internal_tasks
    (library_id, title, title_i18n, description, priority, status, tags, created_by)
  VALUES
    (v_run.library_id,
     'Lote de fundos recebido — rever e anexar',
     v_title_i18n,
     format('Origem: %s · %s notices · %s ficheiros. Rever em Importações (fila de revisão) e anexar os ficheiros aos livros.',
            v_source, v_notices, v_files),
     'media', 'pendente',
     ARRAY['fonds-recebido', v_tag], NULL)
  RETURNING id INTO v_task_id;

  RETURN jsonb_build_object('ok', true, 'created', true, 'task_id', v_task_id,
    'library_id', v_run.library_id, 'source', v_source);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_notify_fonds_deposit_received(bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fn_notify_fonds_deposit_received(bigint) TO service_role;

COMMENT ON FUNCTION public.fn_notify_fonds_deposit_received(bigint) IS
  'Chantier fichiers numériques (point 7 / D3 EX-4). Crée une tâche in-app (painel_internal_tasks) '
  'pour la biblio réceptrice d''un dépôt direct de fonds. Idempotent par run (tag fonds-run:<id>). '
  'INTERNE : réservé à service_role (appelé par l''EF deposit-fonds-direct à la finalisation).';

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                  WHERE n.nspname='public' AND p.proname='fn_notify_fonds_deposit_received') THEN
    RAISE EXCEPTION 'verify (pt7): fn_notify_fonds_deposit_received manquante';
  END IF;
  IF has_function_privilege('authenticated', 'public.fn_notify_fonds_deposit_received(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'verify (pt7): la notif ne doit pas être exécutable par authenticated';
  END IF;
  RAISE NOTICE 'point 7 OK : notif in-app de dépôt direct (D3).';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   DROP FUNCTION IF EXISTS public.fn_notify_fonds_deposit_received(bigint);
-- =========================================================================
