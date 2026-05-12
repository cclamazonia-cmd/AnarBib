-- ============================================================================
-- Paquet 25.11quinquies — Aligner les RPCs sur les 4 valeurs frontend de
-- project_stage (correctif suite au paquet 25.11ter qui n'avait corrige que
-- le CHECK constraint de la table, pas la validation explicite dans les RPCs)
-- ============================================================================
-- CONTEXTE :
--   Le paquet 25.11ter a etendu le CHECK constraint de library_requests pour
--   accepter les 4 valeurs frontend + 2 legacy. MAIS les RPCs
--   fn_submit_library_request et fn_submit_library_request_via_claim font une
--   validation supplementaire en plpgsql :
--
--     if p_project_stage not in ('em_formacao', 'em_organizacao', 'em_funcionamento') then
--       raise exception 'Situação atual inválida.' ...
--
--   Cette validation rejette les valeurs frontend em_montagem, em_planejamento
--   et reativacao AVANT meme d'arriver au CHECK. Bug detecte en conditions
--   reelles : message "Erro: Situação atual inválida." lors de la soumission
--   d'une biblio "em_montagem".
--
-- DECISION :
--   Aligner la validation in-RPC sur la meme liste que le CHECK constraint
--   etendu au paquet 25.11ter : 4 valeurs frontend + 2 legacy.
-- ============================================================================

-- Patch fn_submit_library_request_via_claim : seule la ligne de validation
-- project_stage est changee. On utilise CREATE OR REPLACE qui remplace la
-- fonction sans affecter les autres patches eventuels appliques ailleurs.
CREATE OR REPLACE FUNCTION public.fn_submit_library_request_via_claim(
  p_claim_token text,
  p_library_name text,
  p_library_short_name text DEFAULT NULL::text,
  p_city text DEFAULT NULL::text,
  p_state_region text DEFAULT NULL::text,
  p_country text DEFAULT 'Brasil'::text,
  p_library_email text DEFAULT NULL::text,
  p_library_phone text DEFAULT NULL::text,
  p_library_address text DEFAULT NULL::text,
  p_project_stage text DEFAULT NULL::text,
  p_contact_name text DEFAULT NULL::text,
  p_contact_email text DEFAULT NULL::text,
  p_contact_phone text DEFAULT NULL::text,
  p_contact_role text DEFAULT NULL::text,
  p_first_manager_intent text DEFAULT 'sim'::text,
  p_summary text DEFAULT NULL::text,
  p_public_profile text DEFAULT NULL::text,
  p_collection_profile text DEFAULT NULL::text,
  p_needs text DEFAULT NULL::text,
  p_confirm_real boolean DEFAULT false,
  p_confirm_contact boolean DEFAULT false
)
RETURNS library_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_claim public.library_request_claims;
  v_row public.library_requests;
  v_email_snapshot text;
begin
  if nullif(btrim(coalesce(p_claim_token, '')), '') is null then
    raise exception 'Link inválido.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_library_name, '')), '') is null then
    raise exception 'Informe o nome da biblioteca.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_city, '')), '') is null then
    raise exception 'Informe a cidade da biblioteca.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_country, '')), '') is null then
    raise exception 'Informe o país da biblioteca.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_library_email, '')), '') is null then
    raise exception 'Informe o e-mail principal da biblioteca.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_contact_name, '')), '') is null then
    raise exception 'Informe o nome da pessoa responsável pelo primeiro contato.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_contact_email, '')), '') is null then
    raise exception 'Informe o e-mail da pessoa responsável.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_summary, '')), '') is null then
    raise exception 'Informe uma breve apresentação da biblioteca ou coletivo.'
      using errcode = '23514';
  end if;

  -- Paquet 25.11quinquies : 4 valeurs frontend + 2 legacy DB tolerees.
  if p_project_stage not in (
    'em_funcionamento', 'em_montagem', 'em_planejamento', 'reativacao',
    'em_formacao', 'em_organizacao'
  ) then
    raise exception 'Situação atual inválida.'
      using errcode = '23514';
  end if;

  if coalesce(p_first_manager_intent, 'sim') not in ('sim', 'nao', 'a_definir') then
    raise exception 'Valor inválido para o primeiro perfil responsável.'
      using errcode = '23514';
  end if;

  if coalesce(p_confirm_real, false) is not true
     or coalesce(p_confirm_contact, false) is not true then
    raise exception 'As duas confirmações obrigatórias precisam estar marcadas.'
      using errcode = '23514';
  end if;

  select c.*
  into v_claim
  from public.library_request_claims c
  where c.claim_token_hash = public.fn_hash_claim_token(btrim(p_claim_token))
    and c.claim_purpose = 'library_request'
    and c.used_at is null
    and c.expires_at > now()
  for update;

  if not found then
    raise exception 'Este link não é mais válido. Solicite um novo acesso.'
      using errcode = '42501';
  end if;

  v_email_snapshot := lower(
    coalesce(
      nullif(btrim(v_claim.email_snapshot), ''),
      nullif(btrim(p_contact_email), ''),
      nullif(btrim(p_library_email), '')
    )
  );

  insert into public.library_requests (
    submitted_by_user_id,
    submitted_by_email_snapshot,
    library_name,
    library_short_name,
    city,
    state_region,
    country,
    library_email,
    library_phone,
    library_address,
    project_stage,
    contact_name,
    contact_email,
    contact_phone,
    contact_role,
    first_manager_intent,
    summary,
    public_profile,
    collection_profile,
    needs,
    confirm_real,
    confirm_contact
  )
  values (
    v_claim.user_id,
    v_email_snapshot,
    btrim(p_library_name),
    nullif(btrim(coalesce(p_library_short_name, '')), ''),
    btrim(p_city),
    nullif(btrim(coalesce(p_state_region, '')), ''),
    btrim(p_country),
    lower(btrim(p_library_email)),
    nullif(btrim(coalesce(p_library_phone, '')), ''),
    nullif(btrim(coalesce(p_library_address, '')), ''),
    p_project_stage,
    btrim(p_contact_name),
    lower(btrim(p_contact_email)),
    nullif(btrim(coalesce(p_contact_phone, '')), ''),
    nullif(btrim(coalesce(p_contact_role, '')), ''),
    coalesce(p_first_manager_intent, 'sim'),
    btrim(p_summary),
    nullif(btrim(coalesce(p_public_profile, '')), ''),
    nullif(btrim(coalesce(p_collection_profile, '')), ''),
    nullif(btrim(coalesce(p_needs, '')), ''),
    true,
    true
  )
  returning * into v_row;

  update public.library_request_claims
  set
    used_at = now(),
    used_by_request_id = v_row.id
  where id = v_claim.id
    and used_at is null;

  return v_row;
end;
$function$;


-- Patch fn_submit_library_request : meme alignement sur les 4 valeurs
-- frontend + 2 legacy DB.
CREATE OR REPLACE FUNCTION public.fn_submit_library_request(
  p_library_name text,
  p_library_short_name text DEFAULT NULL::text,
  p_city text DEFAULT NULL::text,
  p_state_region text DEFAULT NULL::text,
  p_country text DEFAULT 'Brasil'::text,
  p_library_email text DEFAULT NULL::text,
  p_library_phone text DEFAULT NULL::text,
  p_library_address text DEFAULT NULL::text,
  p_project_stage text DEFAULT NULL::text,
  p_contact_name text DEFAULT NULL::text,
  p_contact_email text DEFAULT NULL::text,
  p_contact_phone text DEFAULT NULL::text,
  p_contact_role text DEFAULT NULL::text,
  p_first_manager_intent text DEFAULT 'sim'::text,
  p_summary text DEFAULT NULL::text,
  p_public_profile text DEFAULT NULL::text,
  p_collection_profile text DEFAULT NULL::text,
  p_needs text DEFAULT NULL::text,
  p_confirm_real boolean DEFAULT false,
  p_confirm_contact boolean DEFAULT false
)
RETURNS library_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_email_snapshot text;
  v_row public.library_requests;
begin
  if v_user_id is null then
    raise exception 'Você precisa estar conectado para enviar esta solicitação.'
      using errcode = '42501';
  end if;

  if nullif(btrim(coalesce(p_library_name, '')), '') is null then
    raise exception 'Informe o nome da biblioteca.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_city, '')), '') is null then
    raise exception 'Informe a cidade da biblioteca.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_country, '')), '') is null then
    raise exception 'Informe o país da biblioteca.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_library_email, '')), '') is null then
    raise exception 'Informe o e-mail principal da biblioteca.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_contact_name, '')), '') is null then
    raise exception 'Informe o nome da pessoa responsável pelo primeiro contato.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_contact_email, '')), '') is null then
    raise exception 'Informe o e-mail da pessoa responsável.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(p_summary, '')), '') is null then
    raise exception 'Informe uma breve apresentação da biblioteca ou coletivo.'
      using errcode = '23514';
  end if;

  -- Paquet 25.11quinquies : 4 valeurs frontend + 2 legacy DB tolerees.
  if p_project_stage not in (
    'em_funcionamento', 'em_montagem', 'em_planejamento', 'reativacao',
    'em_formacao', 'em_organizacao'
  ) then
    raise exception 'Situação atual inválida.'
      using errcode = '23514';
  end if;

  if coalesce(p_first_manager_intent, 'sim') not in ('sim', 'nao', 'a_definir') then
    raise exception 'Valor inválido para o primeiro perfil responsável.'
      using errcode = '23514';
  end if;

  if coalesce(p_confirm_real, false) is not true
     or coalesce(p_confirm_contact, false) is not true then
    raise exception 'As duas confirmações obrigatórias precisam estar marcadas.'
      using errcode = '23514';
  end if;

  v_email_snapshot := lower(
    coalesce(
      nullif(btrim(auth.jwt() ->> 'email'), ''),
      nullif(btrim(p_contact_email), ''),
      nullif(btrim(p_library_email), '')
    )
  );

  insert into public.library_requests (
    submitted_by_user_id,
    submitted_by_email_snapshot,
    library_name,
    library_short_name,
    city,
    state_region,
    country,
    library_email,
    library_phone,
    library_address,
    project_stage,
    contact_name,
    contact_email,
    contact_phone,
    contact_role,
    first_manager_intent,
    summary,
    public_profile,
    collection_profile,
    needs,
    confirm_real,
    confirm_contact
  )
  values (
    v_user_id,
    v_email_snapshot,
    btrim(p_library_name),
    nullif(btrim(coalesce(p_library_short_name, '')), ''),
    btrim(p_city),
    nullif(btrim(coalesce(p_state_region, '')), ''),
    btrim(p_country),
    lower(btrim(p_library_email)),
    nullif(btrim(coalesce(p_library_phone, '')), ''),
    nullif(btrim(coalesce(p_library_address, '')), ''),
    p_project_stage,
    btrim(p_contact_name),
    lower(btrim(p_contact_email)),
    nullif(btrim(coalesce(p_contact_phone, '')), ''),
    nullif(btrim(coalesce(p_contact_role, '')), ''),
    coalesce(p_first_manager_intent, 'sim'),
    btrim(p_summary),
    nullif(btrim(coalesce(p_public_profile, '')), ''),
    nullif(btrim(coalesce(p_collection_profile, '')), ''),
    nullif(btrim(coalesce(p_needs, '')), ''),
    true,
    true
  )
  returning * into v_row;

  return v_row;
end;
$function$;


-- Verification post-migration : assertion que les 2 fonctions n'ont plus
-- l'ancienne liste restreinte. Si une autre source les remet en place, ce
-- DO block remontera une exception explicite.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('fn_submit_library_request', 'fn_submit_library_request_via_claim')
      AND pg_get_functiondef(p.oid) ILIKE '%not in (''em_formacao'', ''em_organizacao'', ''em_funcionamento'')%'
  ) THEN
    RAISE EXCEPTION 'Paquet 25.11quinquies : au moins un RPC contient encore l''ancienne validation restrictive a 3 valeurs.';
  END IF;
  RAISE NOTICE 'Paquet 25.11quinquies : les 2 RPCs acceptent maintenant les 4 valeurs frontend + 2 legacy.';
END
$$;
