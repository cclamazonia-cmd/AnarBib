-- ============================================================================
-- Paquet C.4a.1 — Patch fn_v2_create_emprestimo_interbibliotecas
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.3
-- Dependance : paquetC3c_rls_peb_composite.sql (helper fn_peb_authorized)
--
-- Objectif : ajouter un check fn_peb_authorized(lender, borrower) en debut
-- de fonction pour bloquer creation PEB si l'une des bibs n'a pas circulation
-- ou n'est pas federated. Doctrine politique : un PEB exige les deux bibs
-- en federation pleine avec circulation active (cf. spec §2.5).
--
-- Sans ce check, la fonction (SECURITY DEFINER) bypasse les RLS C.3c et
-- pourrait creer un PEB meme avec une biblio en off ou observer.
--
-- Point d'injection : juste apres la verification de permission
-- (user_can_manage_library), avant les autres validations metier.
-- Le check leve une exception P0001 avec hint i18n.
--
-- Risque : critique (modification d'une fonction de production). Mitigation :
-- definition exactement identique a l'originale, modulo le bloc ajoute.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_v2_create_emprestimo_interbibliotecas(p_payload jsonb)
 RETURNS interlibrary_loans_v2
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.interlibrary_loans_v2;
  v_request public.document_permission_requests;
  v_lender_library_id uuid;
  v_borrower_library_id uuid;
  v_initiated_by_library_id uuid;
  v_request_id uuid;
  v_status_global text;
  v_start_date date;
  v_due_date date;
  v_coordination_contact_name text;
  v_coordination_contact_email text;
  v_coordination_contact_phone text;
  v_logistics_mode text;
  v_meeting_point text;
  v_notes text;
  v_metadata jsonb;
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Payload inválido para criar empréstimo interbibliotecas.';
  end if;

  v_lender_library_id := nullif(trim(coalesce(p_payload->>'lender_library_id', '')), '')::uuid;
  v_borrower_library_id := nullif(trim(coalesce(p_payload->>'borrower_library_id', '')), '')::uuid;
  v_initiated_by_library_id := nullif(trim(coalesce(p_payload->>'initiated_by_library_id', '')), '')::uuid;
  v_request_id := nullif(trim(coalesce(p_payload->>'request_id', '')), '')::uuid;
  v_status_global := lower(trim(coalesce(p_payload->>'status_global', '')));
  v_start_date := nullif(trim(coalesce(p_payload->>'start_date', '')), '')::date;
  v_due_date := nullif(trim(coalesce(p_payload->>'due_date', '')), '')::date;
  v_coordination_contact_name := nullif(trim(coalesce(p_payload->>'coordination_contact_name', '')), '');
  v_coordination_contact_email := nullif(trim(coalesce(p_payload->>'coordination_contact_email', '')), '');
  v_coordination_contact_phone := nullif(trim(coalesce(p_payload->>'coordination_contact_phone', '')), '');
  v_logistics_mode := nullif(trim(coalesce(p_payload->>'logistics_mode', '')), '');
  v_meeting_point := nullif(trim(coalesce(p_payload->>'meeting_point', '')), '');
  v_notes := nullif(trim(coalesce(p_payload->>'notes', '')), '');
  v_metadata := coalesce(p_payload->'metadata', '{}'::jsonb);

  if v_lender_library_id is null then
    raise exception 'Biblioteca emprestadora ausente.';
  end if;

  if v_borrower_library_id is null then
    raise exception 'Biblioteca tomadora ausente.';
  end if;

  if v_lender_library_id = v_borrower_library_id then
    raise exception 'A biblioteca emprestadora e a tomadora precisam ser diferentes.';
  end if;

  if not public.user_can_manage_library(v_lender_library_id)
     and not public.user_can_manage_library(v_borrower_library_id) then
    raise exception 'Sem permissão para abrir empréstimo interbibliotecas entre estas bibliotecas.';
  end if;

  -- ============================================================
  -- PAQUET C.4a.1 — check profil PEB composite
  -- Les deux bibs doivent avoir circulation active ET etre federated.
  -- Spec §2.5 : PEB est une fonction inter-bibs federees.
  -- ============================================================
  if not public.fn_peb_authorized(v_lender_library_id, v_borrower_library_id) then
    raise exception 'Pelo menos uma das bibliotecas não está em condição de participar de empréstimo interbibliotecas (circulação desativada ou modo de rede não federado).'
      using errcode = 'P0001',
            hint = 'error.library.peb_not_authorized';
  end if;

  if v_initiated_by_library_id is null then
    v_initiated_by_library_id := case
      when public.user_can_manage_library(v_lender_library_id) then v_lender_library_id
      else v_borrower_library_id
    end;
  end if;

  if v_initiated_by_library_id not in (v_lender_library_id, v_borrower_library_id) then
    raise exception 'initiated_by_library_id precisa ser a biblioteca emprestadora ou a tomadora.';
  end if;

  if v_status_global = '' then
    v_status_global := case
      when v_start_date is null then 'preparacao'
      else 'aguardando_saida'
    end;
  end if;

  if v_status_global not in ('preparacao', 'aguardando_saida') then
    raise exception 'status_global inicial inválido. Usa preparacao ou aguardando_saida.';
  end if;

  if v_start_date is not null and v_due_date is not null and v_due_date < v_start_date then
    raise exception 'A data prevista de retorno não pode ser anterior à data de saída.';
  end if;

  if v_request_id is not null then
    select *
      into v_request
    from public.document_permission_requests
    where id = v_request_id;

    if v_request.id is null then
      raise exception 'Solicitação interbibliotecas não encontrada: %', v_request_id;
    end if;

    if v_request.status <> 'accepted' then
      raise exception 'A solicitação % ainda não está aceita.', v_request_id;
    end if;

    if not (
      (v_request.requester_library_id = v_lender_library_id and v_request.target_library_id = v_borrower_library_id)
      or
      (v_request.requester_library_id = v_borrower_library_id and v_request.target_library_id = v_lender_library_id)
    ) then
      raise exception 'A solicitação % não corresponde ao par de bibliotecas informado.', v_request_id;
    end if;
  end if;

  insert into public.interlibrary_loans_v2 (
    request_id,
    lender_library_id,
    borrower_library_id,
    initiated_by_library_id,
    status_global,
    start_date,
    due_date,
    coordination_contact_name,
    coordination_contact_email,
    coordination_contact_phone,
    logistics_mode,
    meeting_point,
    notes,
    metadata,
    created_at,
    created_by,
    updated_at,
    updated_by
  )
  values (
    v_request_id,
    v_lender_library_id,
    v_borrower_library_id,
    v_initiated_by_library_id,
    v_status_global,
    v_start_date,
    v_due_date,
    v_coordination_contact_name,
    v_coordination_contact_email,
    v_coordination_contact_phone,
    v_logistics_mode,
    v_meeting_point,
    v_notes,
    coalesce(v_metadata, '{}'::jsonb),
    timezone('utc', now()),
    auth.uid(),
    timezone('utc', now()),
    auth.uid()
  )
  returning * into v_row;

  perform public.fn_v2_log_emprestimo_interbibliotecas_event(
    p_loan_id := v_row.id,
    p_item_id := null,
    p_event_type := 'created',
    p_event_note := 'Empréstimo interbibliotecas criado.',
    p_payload := jsonb_build_object(
      'request_id', v_row.request_id,
      'lender_library_id', v_row.lender_library_id,
      'borrower_library_id', v_row.borrower_library_id,
      'status_global', v_row.status_global
    )
  );

  perform public.fn_v2_refresh_emprestimo_interbibliotecas_status_global(v_row.id);

  select *
    into v_row
  from public.interlibrary_loans_v2
  where id = v_row.id;

  return v_row;
end;
$function$;

-- ---------------------------------------------------------------------------
-- DO block de verification fail-fast
-- ---------------------------------------------------------------------------
DO $verif$
DECLARE
  v_count int;
  v_def text;
BEGIN
  -- a. Fonction existe
  SELECT count(*) INTO v_count FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_v2_create_emprestimo_interbibliotecas';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a : fn_v2_create_emprestimo_interbibliotecas introuvable apres patch';
  END IF;

  -- b. Definition contient fn_peb_authorized
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_v2_create_emprestimo_interbibliotecas';
  IF v_def NOT LIKE '%fn_peb_authorized%' THEN
    RAISE EXCEPTION 'VERIF_FAIL_b : la fonction patche ne contient pas fn_peb_authorized';
  END IF;

  -- c. Fonction est toujours SECURITY DEFINER avec search_path correct
  SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname = 'fn_v2_create_emprestimo_interbibliotecas'
     AND p.prosecdef = true
     AND array_to_string(p.proconfig, ',') LIKE '%public%';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_c : conformite doctrine v2 (SECURITY DEFINER + search_path) cassee';
  END IF;

  RAISE NOTICE 'Paquet C.4a.1 — Verification OK : fn_v2_create_emprestimo_interbibliotecas patchee avec check fn_peb_authorized';
END
$verif$;

COMMIT;
