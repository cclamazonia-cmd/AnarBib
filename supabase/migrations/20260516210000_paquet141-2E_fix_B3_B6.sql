-- ============================================================
-- Paquet 141.2.E — Fix bugs B3 et B6 (16/05/2026 soiree)
-- ============================================================
-- Bugs identifies en QA prod apres deploiement 141.2.A-D :
--
-- B6 (motif annulation biblio absent du mail) : ordre des UPDATEs
--   dans fn_v2_set_consulta_linhas_workflow faisait que le trigger
--   lifecycle se declenchait sur UPDATE de consulta_linhas_v2.item_status
--   AVANT que consulta_item_workflow_v2.workflow_note soit mis a jour.
--   Le trigger lisait donc l'ancienne note (note de creation initiale).
--
-- B3 (motif refus lecteur absent du mail) : le trigger workflow propage
--   NEW.workflow_note dans le payload mais le motif du refus est dans
--   NEW.schedule_reply_note (colonne dediee aux notes de refus). Manque
--   de propagation de schedule_reply_note dans le payload.
--
-- Fixes :
--   1. Inverser l'ordre dans fn_v2_set_consulta_linhas_workflow :
--      INSERT/UPSERT workflow_v2 AVANT UPDATE linhas_v2.
--   2. Modifier trg_notify_consulta_workflow pour aussi propager
--      schedule_reply_note dans le payload de consulta_v2_resposta_creneau.
--
-- Side-effects analysees :
--   - Trigger workflow s'execute toujours sur INSERT/UPDATE workflow_v2,
--     mais sa branche workflow_stage='cancelada_biblioteca' n'existe pas
--     (event non emis), donc pas de double notification.
--   - L'ordre des UPDATEs n'a pas d'impact sur fn_v2_refresh_consulta_status_global
--     (appele en fin de fonction, prend l'etat final).
--
-- DOCTRINE SECURITE : SECURITY DEFINER + REVOKE FROM PUBLIC sur les
-- 2 fonctions modifiees (trigger workflow + RPC interne). La RPC interne
-- garde aussi son GRANT TO authenticated/service_role car appellee par
-- api.advance_consulta (qui est appellee par les clients authentifies).
-- ============================================================

-- ============================================================
-- SECTION 1 — Inverser l'ordre des UPDATEs dans 
--             fn_v2_set_consulta_linhas_workflow (Fix B6)
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_v2_set_consulta_linhas_workflow(
  p_consulta_id bigint,
  p_line_nos integer[],
  p_workflow_stage text,
  p_workflow_note text DEFAULT NULL::text,
  p_consultation_scheduled_for timestamp with time zone DEFAULT NULL::timestamp with time zone
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_stage text := trim(coalesce(p_workflow_stage, ''));
  v_library_id uuid;
  v_updated int := 0;
begin
  if v_uid is null then
    raise exception 'Sessão inválida.';
  end if;

  if coalesce(array_length(p_line_nos, 1), 0) = 0 then
    raise exception 'Selecione ao menos uma linha de consulta.';
  end if;

  if v_stage = '' then
    raise exception 'Etapa de workflow obrigatória.';
  end if;

  if v_stage not in (
    'em_preparacao',
    'consulta_agendada',
    'consulta_realizada',
    'nao_compareceu',
    'cancelada_biblioteca',
    'expirada'
  ) then
    raise exception 'Etapa de workflow inválida para consulta local: %', v_stage;
  end if;

  if v_stage = 'consulta_agendada' and p_consultation_scheduled_for is null then
    raise exception 'Informe a data e hora da consulta agendada.';
  end if;

  select c.library_id
    into v_library_id
  from public.consultas_locais_v2 c
  where c.id = p_consulta_id;

  if v_library_id is null then
    raise exception 'Consulta local não encontrada.';
  end if;

  if not exists (
    select 1
    from api.my_access a
    where a.user_id = v_uid
      and a.can_access_painel = true
      and a.library_id = v_library_id
  ) then
    raise exception 'Você não pode gerir esta consulta local.';
  end if;

  -- ============================================================
  -- ORDRE INVERSE (Fix B6, 16/05/2026) :
  -- AVANT : UPDATE linhas_v2 PUIS INSERT workflow_v2
  --   -> Le trigger lifecycle (AFTER UPDATE linhas_v2) se declenchait
  --      AVANT que workflow_v2.workflow_note soit ecrite.
  --      Il lisait donc l'ancienne note (note de creation initiale).
  --
  -- APRES : INSERT workflow_v2 PUIS UPDATE linhas_v2
  --   -> Le trigger lifecycle (AFTER UPDATE linhas_v2) se declenche
  --      APRES que workflow_v2.workflow_note soit a jour.
  --      Il lit donc la bonne note (motif d'annulation par la biblio).
  -- ============================================================

  -- Etape 1 : INSERT/UPSERT consulta_item_workflow_v2
  insert into public.consulta_item_workflow_v2 (
    consulta_id,
    line_no,
    workflow_stage,
    workflow_note,
    consultation_scheduled_for,
    updated_at,
    updated_by
  )
  select
    cl.consulta_id,
    cl.line_no,
    v_stage,
    nullif(trim(p_workflow_note), ''),
    p_consultation_scheduled_for,
    timezone('utc', now()),
    v_uid
  from public.consulta_linhas_v2 cl
  where cl.consulta_id = p_consulta_id
    and cl.line_no = any(p_line_nos)
  on conflict (consulta_id, line_no)
  do update
     set workflow_stage = excluded.workflow_stage,
         workflow_note = coalesce(excluded.workflow_note, public.consulta_item_workflow_v2.workflow_note),
         consultation_scheduled_for = coalesce(excluded.consultation_scheduled_for, public.consulta_item_workflow_v2.consultation_scheduled_for),
         schedule_reply_status = case
           when excluded.workflow_stage = 'consulta_agendada' then null
           else public.consulta_item_workflow_v2.schedule_reply_status
         end,
         schedule_reply_note = case
           when excluded.workflow_stage = 'consulta_agendada' then null
           else public.consulta_item_workflow_v2.schedule_reply_note
         end,
         schedule_reply_at = case
           when excluded.workflow_stage = 'consulta_agendada' then null
           else public.consulta_item_workflow_v2.schedule_reply_at
         end,
         updated_at = excluded.updated_at,
         updated_by = excluded.updated_by;

  -- Etape 2 : UPDATE consulta_linhas_v2 (declenche trigger lifecycle apres
  -- que workflow_note soit a jour)
  update public.consulta_linhas_v2 cl
     set item_status = case
           when v_stage = 'consulta_realizada' then 'consultada'
           when v_stage = 'cancelada_biblioteca' then 'cancelada_biblioteca'
           when v_stage = 'expirada' then 'expirada'
           else cl.item_status
         end,
         cancelled_at = case
           when v_stage = 'cancelada_biblioteca' then coalesce(cl.cancelled_at, timezone('utc', now()))
           else cl.cancelled_at
         end,
         consulted_at = case
           when v_stage = 'consulta_realizada' then coalesce(cl.consulted_at, timezone('utc', now()))
           else cl.consulted_at
         end,
         expired_at = case
           when v_stage = 'expirada' then coalesce(cl.expired_at, timezone('utc', now()))
           else cl.expired_at
         end,
         updated_at = timezone('utc', now())
   where cl.consulta_id = p_consulta_id
     and cl.line_no = any(p_line_nos)
     and cl.item_status = 'ativa';

  get diagnostics v_updated = row_count;

  perform public.fn_v2_refresh_consulta_status_global(p_consulta_id);

  return v_updated;
end;
$function$;

COMMENT ON FUNCTION public.fn_v2_set_consulta_linhas_workflow(bigint, integer[], text, text, timestamp with time zone) IS
  'Fonction interne workflow consultas v2. v2 (16/05/2026) : ordre des UPDATEs inverse (workflow_v2 avant linhas_v2) pour fix B6 (note d''annulation biblio dans mail lecteur). Cf. doctrine paquet 141.2.E.';

-- DOCTRINE SECURITE : REVOKE FROM PUBLIC + GRANT explicit
REVOKE EXECUTE ON FUNCTION public.fn_v2_set_consulta_linhas_workflow(bigint, integer[], text, text, timestamp with time zone) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_v2_set_consulta_linhas_workflow(bigint, integer[], text, text, timestamp with time zone) TO authenticated, service_role;

-- ============================================================
-- SECTION 2 — Refacto trg_notify_consulta_workflow pour propager
--             schedule_reply_note dans le payload (Fix B3)
-- ============================================================

CREATE OR REPLACE FUNCTION public.trg_notify_consulta_workflow()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_event text;
  v_flag_column text;
  v_enabled boolean;
  v_library_id uuid;
  v_local_consultation_enabled boolean;
  v_payload jsonb;
  v_emit_em_preparacao boolean := false;
  v_emit_agendada boolean := false;
  v_emit_resposta boolean := false;
  v_emit_nao_compareceu boolean := false;
BEGIN
  -- B2 : Transition workflow_stage -> em_preparacao
  IF TG_OP = 'UPDATE'
     AND NEW.workflow_stage = 'em_preparacao'
     AND OLD.workflow_stage IS DISTINCT FROM NEW.workflow_stage
  THEN
    v_emit_em_preparacao := true;
  END IF;

  -- Transition workflow_stage -> consulta_agendada
  IF (TG_OP = 'INSERT' AND NEW.workflow_stage = 'consulta_agendada')
     OR (TG_OP = 'UPDATE'
         AND NEW.workflow_stage = 'consulta_agendada'
         AND (OLD.workflow_stage IS DISTINCT FROM NEW.workflow_stage
              OR OLD.consultation_starts_at IS DISTINCT FROM NEW.consultation_starts_at
              OR OLD.consultation_ends_at IS DISTINCT FROM NEW.consultation_ends_at))
  THEN
    v_emit_agendada := true;
  END IF;

  -- B5 : Transition workflow_stage -> nao_compareceu
  IF TG_OP = 'UPDATE'
     AND NEW.workflow_stage = 'nao_compareceu'
     AND OLD.workflow_stage IS DISTINCT FROM NEW.workflow_stage
  THEN
    v_emit_nao_compareceu := true;
  END IF;

  -- Transition schedule_reply_status -> confirmado / recusado
  IF TG_OP = 'UPDATE'
     AND OLD.schedule_reply_status IS DISTINCT FROM NEW.schedule_reply_status
     AND NEW.schedule_reply_status IN ('confirmado_leitor', 'recusado_leitor')
  THEN
    v_emit_resposta := true;
  END IF;

  IF NOT v_emit_em_preparacao AND NOT v_emit_agendada 
     AND NOT v_emit_resposta AND NOT v_emit_nao_compareceu THEN
    RETURN NEW;
  END IF;

  SELECT cl.library_id INTO v_library_id
  FROM public.consultas_locais_v2 cl
  WHERE cl.id = NEW.consulta_id;

  v_local_consultation_enabled := true;
  IF v_library_id IS NOT NULL THEN
    SELECT local_consultation_enabled INTO v_local_consultation_enabled
    FROM public.library_notification_policies
    WHERE library_id = v_library_id;
    v_local_consultation_enabled := COALESCE(v_local_consultation_enabled, true);
  END IF;

  IF NOT v_local_consultation_enabled THEN
    RETURN NEW;
  END IF;

  -- Emission 1 : consulta_v2_em_preparacao (B2)
  IF v_emit_em_preparacao THEN
    v_flag_column := 'consulta_mail_em_preparacao_enabled';
    v_event := 'consulta_v2_em_preparacao';
    v_enabled := true;
    IF v_library_id IS NOT NULL THEN
      EXECUTE format('SELECT %I FROM public.library_notification_policies WHERE library_id = $1', v_flag_column) 
        INTO v_enabled USING v_library_id;
      v_enabled := COALESCE(v_enabled, true);
    END IF;
    IF v_enabled THEN
      v_payload := jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no));
      IF NEW.workflow_note IS NOT NULL AND trim(NEW.workflow_note) <> '' THEN
        v_payload := v_payload || jsonb_build_object('workflow_note', NEW.workflow_note);
      END IF;
      PERFORM public.fn_dispatch_circulation_notify_event(v_event, NEW.consulta_id, v_payload);
    END IF;
  END IF;

  -- Emission 2 : consulta_v2_agendada
  IF v_emit_agendada THEN
    v_flag_column := 'consulta_mail_agendada_enabled';
    v_event := 'consulta_v2_agendada';
    v_enabled := true;
    IF v_library_id IS NOT NULL THEN
      EXECUTE format('SELECT %I FROM public.library_notification_policies WHERE library_id = $1', v_flag_column)
        INTO v_enabled USING v_library_id;
      v_enabled := COALESCE(v_enabled, true);
    END IF;
    IF v_enabled THEN
      v_payload := jsonb_build_object(
        'line_nos', jsonb_build_array(NEW.line_no),
        'consultation_starts_at', NEW.consultation_starts_at,
        'consultation_ends_at',   NEW.consultation_ends_at
      );
      IF NEW.workflow_note IS NOT NULL AND trim(NEW.workflow_note) <> '' THEN
        v_payload := v_payload || jsonb_build_object('workflow_note', NEW.workflow_note);
      END IF;
      PERFORM public.fn_dispatch_circulation_notify_event(v_event, NEW.consulta_id, v_payload);
    END IF;
  END IF;

  -- Emission 3 : consulta_v2_nao_compareceu (B5)
  IF v_emit_nao_compareceu THEN
    v_flag_column := 'consulta_mail_nao_compareceu_enabled';
    v_event := 'consulta_v2_nao_compareceu';
    v_enabled := true;
    IF v_library_id IS NOT NULL THEN
      EXECUTE format('SELECT %I FROM public.library_notification_policies WHERE library_id = $1', v_flag_column)
        INTO v_enabled USING v_library_id;
      v_enabled := COALESCE(v_enabled, true);
    END IF;
    IF v_enabled THEN
      v_payload := jsonb_build_object(
        'line_nos', jsonb_build_array(NEW.line_no),
        'consultation_starts_at', NEW.consultation_starts_at
      );
      IF NEW.workflow_note IS NOT NULL AND trim(NEW.workflow_note) <> '' THEN
        v_payload := v_payload || jsonb_build_object('workflow_note', NEW.workflow_note);
      END IF;
      PERFORM public.fn_dispatch_circulation_notify_event(v_event, NEW.consulta_id, v_payload);
    END IF;
  END IF;

  -- Emission 4 : consulta_v2_resposta_creneau (fix B3 : propage schedule_reply_note)
  IF v_emit_resposta THEN
    v_flag_column := 'consulta_mail_resposta_creneau_enabled';
    v_event := 'consulta_v2_resposta_creneau';
    v_enabled := true;
    IF v_library_id IS NOT NULL THEN
      EXECUTE format('SELECT %I FROM public.library_notification_policies WHERE library_id = $1', v_flag_column)
        INTO v_enabled USING v_library_id;
      v_enabled := COALESCE(v_enabled, true);
    END IF;
    IF v_enabled THEN
      v_payload := jsonb_build_object(
        'line_nos', jsonb_build_array(NEW.line_no),
        'schedule_reply_status', NEW.schedule_reply_status
      );
      -- Paquet 141.2.E (16/05/2026) : Fix B3.
      -- Le motif du refus par le lecteur est dans NEW.schedule_reply_note,
      -- pas dans NEW.workflow_note. On propage les 2 (workflow_note pour
      -- compatibilite avec doctrine generale, schedule_reply_note pour
      -- le motif specifique du refus).
      IF NEW.workflow_note IS NOT NULL AND trim(NEW.workflow_note) <> '' THEN
        v_payload := v_payload || jsonb_build_object('workflow_note', NEW.workflow_note);
      END IF;
      IF NEW.schedule_reply_note IS NOT NULL AND trim(NEW.schedule_reply_note) <> '' THEN
        v_payload := v_payload || jsonb_build_object('schedule_reply_note', NEW.schedule_reply_note);
      END IF;
      PERFORM public.fn_dispatch_circulation_notify_event(v_event, NEW.consulta_id, v_payload);
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.trg_notify_consulta_workflow() IS
  'Trigger workflow consultas v2. v3 (16/05/2026) : propage schedule_reply_note dans payload consulta_v2_resposta_creneau (Fix B3 motif refus lecteur).';

-- DOCTRINE SECURITE : REVOKE FROM PUBLIC (correction dette doctrinale)
REVOKE EXECUTE ON FUNCTION public.trg_notify_consulta_workflow() FROM PUBLIC;

-- ============================================================
-- SECTION 3 — Verification finale (DO-block)
-- ============================================================

DO $$
DECLARE
  v_fn_body text;
  v_trg_body text;
  v_fn_public_count int;
  v_trg_public_count int;
BEGIN
  -- 3.1 fn_v2_set_consulta_linhas_workflow : verifier l'inversion de l'ordre
  SELECT pg_get_functiondef(p.oid) INTO v_fn_body
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.proname = 'fn_v2_set_consulta_linhas_workflow';
  
  -- L'INSERT consulta_item_workflow_v2 doit apparaitre AVANT l'UPDATE consulta_linhas_v2
  IF position('insert into public.consulta_item_workflow_v2' in v_fn_body) >=
     position('update public.consulta_linhas_v2' in v_fn_body) THEN
    RAISE EXCEPTION 'Verification echouee : INSERT workflow_v2 n est pas AVANT UPDATE linhas_v2';
  END IF;
  
  RAISE NOTICE 'OK : fn_v2_set_consulta_linhas_workflow : INSERT workflow_v2 AVANT UPDATE linhas_v2 (Fix B6)';
  
  -- 3.2 trg_notify_consulta_workflow : verifier propagation schedule_reply_note
  SELECT pg_get_functiondef(p.oid) INTO v_trg_body
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.proname = 'trg_notify_consulta_workflow';
  
  IF v_trg_body NOT LIKE '%schedule_reply_note%' THEN
    RAISE EXCEPTION 'Verification echouee : trg_notify_consulta_workflow ne propage pas schedule_reply_note';
  END IF;
  
  RAISE NOTICE 'OK : trg_notify_consulta_workflow propage schedule_reply_note (Fix B3)';
  
  -- 3.3 ACL : PUBLIC n'a plus EXECUTE
  SELECT count(*) INTO v_fn_public_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid,
       unnest(p.proacl) AS aclitem
  WHERE n.nspname = 'public' 
    AND p.proname = 'fn_v2_set_consulta_linhas_workflow'
    AND aclitem::text LIKE '=%';
  
  IF v_fn_public_count > 0 THEN
    RAISE EXCEPTION 'Verification echouee : fn_v2_set_consulta_linhas_workflow conserve un GRANT TO PUBLIC';
  END IF;
  
  SELECT count(*) INTO v_trg_public_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid,
       unnest(p.proacl) AS aclitem
  WHERE n.nspname = 'public' 
    AND p.proname = 'trg_notify_consulta_workflow'
    AND aclitem::text LIKE '=%';
  
  IF v_trg_public_count > 0 THEN
    RAISE EXCEPTION 'Verification echouee : trg_notify_consulta_workflow conserve un GRANT TO PUBLIC';
  END IF;
  
  RAISE NOTICE 'OK : PUBLIC ne peut plus EXECUTE les 2 fonctions';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Paquet 141.2.E applique avec succes';
  RAISE NOTICE '  - B6 Fix : ordre UPDATEs inverse dans fn_v2_set_consulta_linhas_workflow';
  RAISE NOTICE '  - B3 Fix : schedule_reply_note propage dans trg_notify_consulta_workflow';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'IMPORTANT : pour completer B3, le handler EF (consultas.ts) doit aussi';
  RAISE NOTICE 'lire schedule_reply_note du payload et l afficher dans le mail.';
  RAISE NOTICE 'Voir sous-paquet 141.2.F (a venir).';
END $$;
