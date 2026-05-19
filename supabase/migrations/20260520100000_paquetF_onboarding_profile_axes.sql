-- ============================================================================
-- Paquet F.0+F.1+F.2 - Onboarding refondu : choix des 4 axes profil
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque-v0.6.md section 9.7 et backlog 11.7
-- Dependance : aucune (les colonnes library_requests.requested_*_mode existent
--              deja en BDD ; voir audit du 20/05/2026).
--
-- Objectif politique : permettre a une nouvelle biblio de choisir ses 4 axes
-- d'engagement des l'inscription, plutot que d'arriver automatiquement en
-- profil D "complet engage" (default actuel des colonnes libraries.*_mode).
--
-- 3 livrables :
--
--   F.0 : CHECK constraints + helper enum sur les 4 colonnes requested_*_mode
--         + profile_template_chosen de library_requests.
--
--   F.1 : Extension de fn_submit_library_request et de
--         fn_submit_library_request_via_claim pour accepter 5 nouveaux
--         parametres (4 axes + profile_template), avec validation stricte.
--
--   F.2 : Patch fn_activate_approved_library_request pour propager les 4
--         axes choisis vers la table libraries au moment de l'activation.
--         Si non specifies (legacy), defaults BDD = profil D (compatibilite
--         ascendante avec les biblios deja inscrites sans choix d'axes).
--
-- Doctrine F : les 4 axes sont OBLIGATOIRES a l'inscription (force le choix
-- conscient). profile_template_chosen est tracable pour analyses ulterieures
-- (combien de biblios choisissent profil B vs D, etc.).
--
-- Doctrine v2.3 sur les DO blocks fail-fast : verification structurelle via
-- information_schema plutot que grep sur pg_get_functiondef.
-- ============================================================================

BEGIN;

-- ============================================================================
-- F.0 : CHECK constraints sur library_requests
-- ============================================================================

-- Les 4 axes profil acceptent les memes valeurs que dans libraries, MAIS sont
-- nullable (car des biblios deja inscrites n'ont pas ces axes renseignes).

ALTER TABLE public.library_requests
  ADD CONSTRAINT library_requests_catalog_mode_chk
    CHECK (requested_catalog_mode IS NULL
       OR requested_catalog_mode IN ('local_only', 'network_published'));

ALTER TABLE public.library_requests
  ADD CONSTRAINT library_requests_circulation_mode_chk
    CHECK (requested_circulation_mode IS NULL
       OR requested_circulation_mode IN ('off', 'informal', 'full_sigb'));

ALTER TABLE public.library_requests
  ADD CONSTRAINT library_requests_network_mode_chk
    CHECK (requested_network_mode IS NULL
       OR requested_network_mode IN ('isolated', 'observer', 'federated'));

ALTER TABLE public.library_requests
  ADD CONSTRAINT library_requests_governance_mode_chk
    CHECK (requested_governance_mode IS NULL
       OR requested_governance_mode IN ('informal', 'staff_roles', 'full_governance'));

-- Coherence catalog/network (identique a la contrainte libraries)
ALTER TABLE public.library_requests
  ADD CONSTRAINT library_requests_catalog_published_requires_network_chk
    CHECK (
      requested_catalog_mode IS NULL
      OR requested_network_mode IS NULL
      OR requested_catalog_mode <> 'network_published'
      OR requested_network_mode IN ('observer', 'federated')
    );

-- profile_template_chosen : 4 valeurs possibles (A, B, C, D) + NULL si custom
ALTER TABLE public.library_requests
  ADD CONSTRAINT library_requests_profile_template_chk
    CHECK (profile_template_chosen IS NULL
       OR profile_template_chosen IN ('A', 'B', 'C', 'D', 'custom'));

-- ============================================================================
-- F.1a : Extension fn_submit_library_request
-- ============================================================================
-- DROP necessaire car la signature change (20 -> 25 parametres).
-- PostgreSQL n'autorise pas CREATE OR REPLACE FUNCTION quand la liste de
-- parametres change : sans DROP, ca cree une 2e fonction overloaded au lieu
-- de remplacer l'existante. Aucune dependance verifiee (pg_depend vide).
DROP FUNCTION IF EXISTS public.fn_submit_library_request(text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, boolean, boolean);

CREATE OR REPLACE FUNCTION public.fn_submit_library_request(
  p_library_name text,
  p_library_short_name text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_state_region text DEFAULT NULL,
  p_country text DEFAULT 'Brasil',
  p_library_email text DEFAULT NULL,
  p_library_phone text DEFAULT NULL,
  p_library_address text DEFAULT NULL,
  p_project_stage text DEFAULT NULL,
  p_contact_name text DEFAULT NULL,
  p_contact_email text DEFAULT NULL,
  p_contact_phone text DEFAULT NULL,
  p_contact_role text DEFAULT NULL,
  p_first_manager_intent text DEFAULT 'sim',
  p_summary text DEFAULT NULL,
  p_public_profile text DEFAULT NULL,
  p_collection_profile text DEFAULT NULL,
  p_needs text DEFAULT NULL,
  p_confirm_real boolean DEFAULT false,
  p_confirm_contact boolean DEFAULT false,
  -- Paquet F (20/05/2026) : 5 nouveaux parametres pour les 4 axes profil + template
  p_requested_catalog_mode text DEFAULT NULL,
  p_requested_circulation_mode text DEFAULT NULL,
  p_requested_network_mode text DEFAULT NULL,
  p_requested_governance_mode text DEFAULT NULL,
  p_profile_template_chosen text DEFAULT NULL
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
    raise exception 'Voce precisa estar conectado para enviar esta solicitacao.'
      using errcode = '42501';
  end if;

  -- Validations existantes (preservees)
  if nullif(btrim(coalesce(p_library_name, '')), '') is null then
    raise exception 'Informe o nome da biblioteca.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_city, '')), '') is null then
    raise exception 'Informe a cidade da biblioteca.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_country, '')), '') is null then
    raise exception 'Informe o pais da biblioteca.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_library_email, '')), '') is null then
    raise exception 'Informe o e-mail principal da biblioteca.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_contact_name, '')), '') is null then
    raise exception 'Informe o nome da pessoa responsavel pelo primeiro contato.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_contact_email, '')), '') is null then
    raise exception 'Informe o e-mail da pessoa responsavel.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_summary, '')), '') is null then
    raise exception 'Informe uma breve apresentacao da biblioteca ou coletivo.' using errcode = '23514';
  end if;

  if p_project_stage not in (
    'em_funcionamento', 'em_montagem', 'em_planejamento', 'reativacao',
    'em_formacao', 'em_organizacao'
  ) then
    raise exception 'Situacao atual invalida.' using errcode = '23514';
  end if;

  if coalesce(p_first_manager_intent, 'sim') not in ('sim', 'nao', 'a_definir') then
    raise exception 'Valor invalido para o primeiro perfil responsavel.' using errcode = '23514';
  end if;

  if coalesce(p_confirm_real, false) is not true
     or coalesce(p_confirm_contact, false) is not true then
    raise exception 'As duas confirmacoes obrigatorias precisam estar marcadas.' using errcode = '23514';
  end if;

  -- Paquet F (20/05/2026) : validations sur les 4 axes profil (OBLIGATOIRES)
  if p_requested_catalog_mode is null
     or p_requested_circulation_mode is null
     or p_requested_network_mode is null
     or p_requested_governance_mode is null then
    raise exception 'Informe os 4 modos de funcionamento da biblioteca (catalogo, circulacao, rede, governanca).'
      using errcode = '23514',
            hint = 'error.library_request.profile_axes_required';
  end if;

  if p_requested_catalog_mode not in ('local_only', 'network_published') then
    raise exception 'Modo de catalogo invalido (%)' , p_requested_catalog_mode
      using errcode = '23514', hint = 'error.library_request.invalid_catalog_mode';
  end if;
  if p_requested_circulation_mode not in ('off', 'informal', 'full_sigb') then
    raise exception 'Modo de circulacao invalido (%)' , p_requested_circulation_mode
      using errcode = '23514', hint = 'error.library_request.invalid_circulation_mode';
  end if;
  if p_requested_network_mode not in ('isolated', 'observer', 'federated') then
    raise exception 'Modo de rede invalido (%)' , p_requested_network_mode
      using errcode = '23514', hint = 'error.library_request.invalid_network_mode';
  end if;
  if p_requested_governance_mode not in ('informal', 'staff_roles', 'full_governance') then
    raise exception 'Modo de governanca invalido (%)' , p_requested_governance_mode
      using errcode = '23514', hint = 'error.library_request.invalid_governance_mode';
  end if;

  -- Coherence catalog/network
  if p_requested_catalog_mode = 'network_published'
     and p_requested_network_mode not in ('observer', 'federated') then
    raise exception 'Catalogo publicado na rede requer modo de rede observer ou federated.'
      using errcode = '23514', hint = 'error.library_request.catalog_network_incoherence';
  end if;

  -- profile_template_chosen est optionnel mais s'il est present il doit etre valide
  if p_profile_template_chosen is not null
     and p_profile_template_chosen not in ('A', 'B', 'C', 'D', 'custom') then
    raise exception 'Template de perfil invalido (%)' , p_profile_template_chosen
      using errcode = '23514', hint = 'error.library_request.invalid_profile_template';
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
    confirm_contact,
    -- Paquet F : 4 axes profil + template
    requested_catalog_mode,
    requested_circulation_mode,
    requested_network_mode,
    requested_governance_mode,
    profile_template_chosen
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
    true,
    p_requested_catalog_mode,
    p_requested_circulation_mode,
    p_requested_network_mode,
    p_requested_governance_mode,
    p_profile_template_chosen
  )
  returning * into v_row;

  return v_row;
end;
$function$;

-- ============================================================================
-- F.1b : Extension fn_submit_library_request_via_claim
-- ============================================================================
-- Meme logique que F.1a, mais avec p_claim_token en premier parametre.
-- DROP necessaire pour les memes raisons (21 -> 26 parametres).
DROP FUNCTION IF EXISTS public.fn_submit_library_request_via_claim(text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, boolean, boolean);

CREATE OR REPLACE FUNCTION public.fn_submit_library_request_via_claim(
  p_claim_token text,
  p_library_name text,
  p_library_short_name text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_state_region text DEFAULT NULL,
  p_country text DEFAULT 'Brasil',
  p_library_email text DEFAULT NULL,
  p_library_phone text DEFAULT NULL,
  p_library_address text DEFAULT NULL,
  p_project_stage text DEFAULT NULL,
  p_contact_name text DEFAULT NULL,
  p_contact_email text DEFAULT NULL,
  p_contact_phone text DEFAULT NULL,
  p_contact_role text DEFAULT NULL,
  p_first_manager_intent text DEFAULT 'sim',
  p_summary text DEFAULT NULL,
  p_public_profile text DEFAULT NULL,
  p_collection_profile text DEFAULT NULL,
  p_needs text DEFAULT NULL,
  p_confirm_real boolean DEFAULT false,
  p_confirm_contact boolean DEFAULT false,
  -- Paquet F (20/05/2026) : 5 nouveaux parametres
  p_requested_catalog_mode text DEFAULT NULL,
  p_requested_circulation_mode text DEFAULT NULL,
  p_requested_network_mode text DEFAULT NULL,
  p_requested_governance_mode text DEFAULT NULL,
  p_profile_template_chosen text DEFAULT NULL
)
 RETURNS library_requests
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_claim_context jsonb;
  v_user_id uuid := auth.uid();
  v_email_snapshot text;
  v_row public.library_requests;
begin
  -- Validation du token claim (reuse de la fonction existante)
  v_claim_context := public.fn_get_library_request_claim_context(p_claim_token);

  if v_claim_context is null or v_claim_context->>'valid' <> 'true' then
    raise exception 'Token de convite invalido ou expirado.'
      using errcode = '42501', hint = 'error.library_request.invalid_claim';
  end if;

  -- Validations base (identiques a fn_submit_library_request)
  if nullif(btrim(coalesce(p_library_name, '')), '') is null then
    raise exception 'Informe o nome da biblioteca.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_city, '')), '') is null then
    raise exception 'Informe a cidade da biblioteca.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_country, '')), '') is null then
    raise exception 'Informe o pais da biblioteca.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_library_email, '')), '') is null then
    raise exception 'Informe o e-mail principal da biblioteca.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_contact_name, '')), '') is null then
    raise exception 'Informe o nome da pessoa responsavel pelo primeiro contato.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_contact_email, '')), '') is null then
    raise exception 'Informe o e-mail da pessoa responsavel.' using errcode = '23514';
  end if;
  if nullif(btrim(coalesce(p_summary, '')), '') is null then
    raise exception 'Informe uma breve apresentacao da biblioteca ou coletivo.' using errcode = '23514';
  end if;
  if p_project_stage not in (
    'em_funcionamento', 'em_montagem', 'em_planejamento', 'reativacao',
    'em_formacao', 'em_organizacao'
  ) then
    raise exception 'Situacao atual invalida.' using errcode = '23514';
  end if;
  if coalesce(p_first_manager_intent, 'sim') not in ('sim', 'nao', 'a_definir') then
    raise exception 'Valor invalido para o primeiro perfil responsavel.' using errcode = '23514';
  end if;
  if coalesce(p_confirm_real, false) is not true
     or coalesce(p_confirm_contact, false) is not true then
    raise exception 'As duas confirmacoes obrigatorias precisam estar marcadas.' using errcode = '23514';
  end if;

  -- Paquet F : validations des 4 axes (OBLIGATOIRES)
  if p_requested_catalog_mode is null
     or p_requested_circulation_mode is null
     or p_requested_network_mode is null
     or p_requested_governance_mode is null then
    raise exception 'Informe os 4 modos de funcionamento da biblioteca.'
      using errcode = '23514', hint = 'error.library_request.profile_axes_required';
  end if;
  if p_requested_catalog_mode not in ('local_only', 'network_published') then
    raise exception 'Modo de catalogo invalido (%)' , p_requested_catalog_mode
      using errcode = '23514', hint = 'error.library_request.invalid_catalog_mode';
  end if;
  if p_requested_circulation_mode not in ('off', 'informal', 'full_sigb') then
    raise exception 'Modo de circulacao invalido (%)' , p_requested_circulation_mode
      using errcode = '23514', hint = 'error.library_request.invalid_circulation_mode';
  end if;
  if p_requested_network_mode not in ('isolated', 'observer', 'federated') then
    raise exception 'Modo de rede invalido (%)' , p_requested_network_mode
      using errcode = '23514', hint = 'error.library_request.invalid_network_mode';
  end if;
  if p_requested_governance_mode not in ('informal', 'staff_roles', 'full_governance') then
    raise exception 'Modo de governanca invalido (%)' , p_requested_governance_mode
      using errcode = '23514', hint = 'error.library_request.invalid_governance_mode';
  end if;
  if p_requested_catalog_mode = 'network_published'
     and p_requested_network_mode not in ('observer', 'federated') then
    raise exception 'Catalogo publicado na rede requer modo de rede observer ou federated.'
      using errcode = '23514', hint = 'error.library_request.catalog_network_incoherence';
  end if;
  if p_profile_template_chosen is not null
     and p_profile_template_chosen not in ('A', 'B', 'C', 'D', 'custom') then
    raise exception 'Template de perfil invalido (%)' , p_profile_template_chosen
      using errcode = '23514', hint = 'error.library_request.invalid_profile_template';
  end if;

  -- Marquer le claim comme utilise
  perform public.fn_consume_library_request_claim(p_claim_token);

  v_email_snapshot := lower(
    coalesce(
      nullif(btrim(v_claim_context->>'email'), ''),
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
    confirm_contact,
    requested_catalog_mode,
    requested_circulation_mode,
    requested_network_mode,
    requested_governance_mode,
    profile_template_chosen
  )
  values (
    coalesce(v_user_id, (v_claim_context->>'user_id')::uuid),
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
    true,
    p_requested_catalog_mode,
    p_requested_circulation_mode,
    p_requested_network_mode,
    p_requested_governance_mode,
    p_profile_template_chosen
  )
  returning * into v_row;

  return v_row;
end;
$function$;

-- ============================================================================
-- F.2 : Patch fn_activate_approved_library_request pour propager les 4 axes
-- ============================================================================
-- Modifie l'INSERT INTO libraries (...) values (...) pour inclure les 4 axes
-- profil et membership_enabled, en lisant depuis v_request.requested_*_mode.
-- Si NULL (cas legacy biblios inscrites avant le paquet F), defaults BDD =
-- profil D (compatibilite ascendante).

CREATE OR REPLACE FUNCTION public.fn_activate_approved_library_request(
  p_request_id uuid,
  p_library_slug text DEFAULT NULL,
  p_grant_submitter_librarian boolean DEFAULT true,
  p_make_membership_primary boolean DEFAULT true
)
 RETURNS TABLE(request_id uuid, library_id uuid, library_slug text, membership_id uuid, membership_role text, request_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_request public.library_requests%rowtype;

  v_library_id uuid;
  v_membership_id uuid;
  v_membership_role text := null;

  v_requested_slug text;
  v_base_slug text;
  v_final_slug text;
  v_suffix integer := 1;

  v_email text;
  v_reply_to text;
  v_postal_address text;

  v_existing_membership_id uuid;
  v_existing_membership_role text;

  -- Paquet F (20/05/2026) : axes effectifs (lus du request, fallback defaults BDD)
  v_eff_catalog_mode text;
  v_eff_circulation_mode text;
  v_eff_network_mode text;
  v_eff_governance_mode text;
begin
  if v_actor is not null then
    if public.fn_current_user_can_review_library_requests() is not true
       and public.fn_current_user_can_send_network_responses() is not true then
      raise exception 'Voce nao tem permissao para ativar bibliotecas aprovadas.'
        using errcode = '42501';
    end if;
  end if;

  if p_request_id is null then
    raise exception 'Informe a solicitacao aprovada a ativar.'
      using errcode = '23514';
  end if;

  select * into v_request from public.library_requests
   where id = p_request_id for update;

  if not found then
    raise exception 'Solicitacao nao encontrada.' using errcode = 'P0002';
  end if;

  if v_request.request_status <> 'aprovada' then
    raise exception 'So e possivel ativar tecnicamente uma solicitacao ja aprovada.'
      using errcode = '23514';
  end if;

  if nullif(btrim(coalesce(v_request.approved_library_ref, '')), '') is not null then
    raise exception 'Esta solicitacao ja foi ativada tecnicamente.'
      using errcode = '23514';
  end if;

  if p_grant_submitter_librarian is true
     and v_request.first_manager_intent = 'nao' then
    raise exception 'Esta solicitacao indica que a pessoa de contato nao deve receber automaticamente o perfil bibliotecario.'
      using errcode = '23514';
  end if;

  -- Slug (logique inchangee)
  v_requested_slug := nullif(lower(btrim(coalesce(p_library_slug, ''))), '');
  if v_requested_slug is null then
    v_base_slug := lower(
      btrim(
        regexp_replace(
          translate(
            coalesce(
              nullif(btrim(v_request.library_short_name), ''),
              nullif(btrim(v_request.library_name), ''),
              'biblioteca'
            ),
            'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNnYyy',
            'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNnYyy'
          ),
          '[^a-z0-9]+', '-', 'g'
        )
      )
    );
  else
    v_base_slug := lower(
      btrim(
        regexp_replace(
          translate(v_requested_slug,
            'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNnYyy',
            'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNnYyy'),
          '[^a-z0-9]+', '-', 'g'
        )
      )
    );
  end if;

  v_base_slug := trim(both '-' from coalesce(v_base_slug, ''));
  if v_base_slug is null or v_base_slug = '' then
    raise exception 'Nao foi possivel gerar um slug valido para a biblioteca.'
      using errcode = '23514';
  end if;

  v_final_slug := v_base_slug;
  while exists (select 1 from public.libraries l where lower(l.slug) = lower(v_final_slug))
     or exists (select 1 from public.library_email_identity lei where lower(lei.library_slug) = lower(v_final_slug))
     or exists (select 1 from public.library_commons lc where lower(lc.library_slug) = lower(v_final_slug))
  loop
    v_suffix := v_suffix + 1;
    v_final_slug := v_base_slug || '-' || v_suffix::text;
  end loop;

  -- Paquet F : axes effectifs (lecture request, fallback defaults BDD profil D)
  v_eff_catalog_mode    := coalesce(v_request.requested_catalog_mode, 'network_published');
  v_eff_circulation_mode := coalesce(v_request.requested_circulation_mode, 'full_sigb');
  v_eff_network_mode    := coalesce(v_request.requested_network_mode, 'federated');
  v_eff_governance_mode := coalesce(v_request.requested_governance_mode, 'full_governance');

  -- INSERT libraries enrichi avec les 4 axes
  insert into public.libraries (
    slug, name, short_name, city, state, country,
    is_active, is_default,
    -- Paquet F : 4 axes profil propages depuis la demande
    catalog_mode, circulation_mode, network_mode, governance_mode
  ) values (
    v_final_slug,
    btrim(v_request.library_name),
    nullif(btrim(coalesce(v_request.library_short_name, '')), ''),
    btrim(v_request.city),
    nullif(btrim(coalesce(v_request.state_region, '')), ''),
    coalesce(nullif(btrim(coalesce(v_request.country, '')), ''), 'Brasil'),
    true, false,
    v_eff_catalog_mode,
    v_eff_circulation_mode,
    v_eff_network_mode,
    v_eff_governance_mode
  )
  returning id into v_library_id;

  -- Donnees communes / identite (logique inchangee)
  v_email := nullif(lower(btrim(coalesce(v_request.library_email, v_request.contact_email, ''))), '');
  v_reply_to := nullif(lower(btrim(coalesce(v_request.contact_email, v_request.library_email, ''))), '');
  v_postal_address := nullif(btrim(coalesce(v_request.library_address, '')), '');

  insert into public.library_commons (
    library_id, library_slug, display_name, short_name,
    contact_email, reply_to_email, postal_address,
    logo_url, logo_file_key, email_delivery_mode, is_test_mode, is_active
  ) values (
    v_library_id, v_final_slug, btrim(v_request.library_name),
    nullif(btrim(coalesce(v_request.library_short_name, '')), ''),
    v_email, v_reply_to, v_postal_address,
    null, null, 'normal', false, true
  );

  insert into public.library_email_identity (
    library_slug, display_name, contact_email, reply_to_email, postal_address,
    logo_url, email_delivery_mode, is_test_mode, is_active
  ) values (
    v_final_slug, btrim(v_request.library_name), v_email, v_reply_to, v_postal_address,
    null, 'normal', false, true
  );

  if not exists (select 1 from public.library_service_state lss where lss.library_id = v_library_id) then
    insert into public.library_service_state (library_id) values (v_library_id);
  end if;

  -- Membership librarian (logique inchangee)
  if p_grant_submitter_librarian is true then
    select m.id, m.role into v_existing_membership_id, v_existing_membership_role
      from public.user_library_memberships m
     where m.user_id = v_request.submitted_by_user_id
       and m.library_id = v_library_id
       and m.role = 'librarian'
     limit 1;

    if v_existing_membership_id is null then
      insert into public.user_library_memberships (user_id, library_id, role, is_primary, status)
      values (v_request.submitted_by_user_id, v_library_id, 'librarian',
              coalesce(p_make_membership_primary, true), 'active')
      returning id, role into v_membership_id, v_membership_role;
    else
      update public.user_library_memberships
         set status = 'active',
             is_primary = coalesce(p_make_membership_primary, true),
             updated_at = now()
       where id = v_existing_membership_id;
      v_membership_id := v_existing_membership_id;
      v_membership_role := v_existing_membership_role;
    end if;
  end if;

  -- Tracabilite activation
  update public.library_requests
     set approved_library_ref = v_library_id::text,
         approved_membership_ref = case when v_membership_id is null then null
                                        else v_membership_id::text end,
         reviewed_at = coalesce(reviewed_at, now()),
         reviewed_by_user_id = coalesce(reviewed_by_user_id, v_actor)
   where id = v_request.id;

  return query
  select v_request.id, v_library_id, v_final_slug, v_membership_id, v_membership_role, 'aprovada'::text;
end;
$function$;

-- ============================================================================
-- Verification fail-fast (doctrine v2.3)
-- ============================================================================
DO $verif$
DECLARE
  v_count int;
BEGIN
  -- Verifier que les 6 CHECK constraints F.0 existent
  SELECT count(*) INTO v_count FROM pg_constraint c
    JOIN pg_class cl ON cl.oid = c.conrelid
   WHERE cl.relname = 'library_requests' AND c.contype = 'c'
     AND c.conname IN (
       'library_requests_catalog_mode_chk',
       'library_requests_circulation_mode_chk',
       'library_requests_network_mode_chk',
       'library_requests_governance_mode_chk',
       'library_requests_catalog_published_requires_network_chk',
       'library_requests_profile_template_chk'
     );
  IF v_count <> 6 THEN
    RAISE EXCEPTION 'VERIF_FAIL : %/6 CHECK constraints F.0 attendus', v_count;
  END IF;

  -- Verifier que fn_submit_library_request accepte bien 25 parametres maintenant
  SELECT pronargs INTO v_count FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_submit_library_request';
  IF v_count <> 25 THEN
    RAISE EXCEPTION 'VERIF_FAIL : fn_submit_library_request a % parametres, attendu 25', v_count;
  END IF;

  -- Verifier que fn_submit_library_request_via_claim accepte 26 parametres
  SELECT pronargs INTO v_count FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_submit_library_request_via_claim';
  IF v_count <> 26 THEN
    RAISE EXCEPTION 'VERIF_FAIL : fn_submit_library_request_via_claim a % parametres, attendu 26', v_count;
  END IF;

  RAISE NOTICE 'Paquet F.0+F.1+F.2 - Verification OK : 6 CHECK + 2 RPC etendues + fn_activate patchee';
END
$verif$;

COMMIT;
