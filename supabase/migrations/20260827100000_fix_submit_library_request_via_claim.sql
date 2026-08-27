-- =============================================================================
-- Reparer fn_submit_library_request_via_claim (elle echouait a coup sur)
-- =============================================================================
-- Date     : 2026-08-27
-- Chantier : inscription « je represente une bibliotheque » (collective_candidate)
--
-- LE DEFAUT. La fonction declarait `v_claim_context jsonb` et lui assignait le
-- resultat de `fn_get_library_request_claim_context(p_claim_token)` — qui ne rend
-- PAS du jsonb mais une TABLE(claim_id, email_snapshot, expires_at, claim_purpose,
-- is_valid). Postgres serialise alors la ligne composite et tente de la parser en
-- json : `invalid input syntax for type json` (22P02), des la PREMIERE instruction,
-- avec un jeton parfaitement valide. Aucun bloc `exception` autour : toute la RPC
-- meurt. Verifie en base le 27/08/2026 sur un claim de test cree puis supprime.
--
-- Et trois autres lectures visaient des cles qui n'existent nulle part :
--   ->>'valid'    la colonne s'appelle `is_valid`
--   ->>'email'    la colonne s'appelle `email_snapshot`
--   ->>'user_id'  jamais retournee par la fonction de contexte
-- La fonction avait ete ecrite contre une version imaginaire de son appelee.
--
-- POURQUOI PERSONNE NE L'A VU. Cette RPC n'est appelee que par
-- SolicitarBibliotecaPage quand l'URL porte un `?claim=` valide, c'est-a-dire
-- uniquement au bout du parcours `collective_candidate` — dont AUCUN compte
-- n'existait avant aujourd'hui (0 ligne, verifie). Le defaut dormait depuis
-- l'ecriture de la fonction. Il devient atteignable maintenant : le CTA du mail
-- de bienvenue pointe exactement dessus.
--
-- LA REPARATION. On lit le contexte dans un `record` (pas un jsonb), et on prend
-- user_id / email_snapshot la ou ils sont autoritatifs : dans la ligne que
-- `fn_consume_library_request_claim` rend deja. Rien de nouveau n'est invente,
-- aucune signature ne bouge.
--
-- METHODE, ET AVERTISSEMENT POUR LA PROCHAINE FOIS. Ce corps est celui d'origine,
-- extrait du baseline, avec SEPT remplacements chirurgicaux et rien d'autre.
-- NE PAS retaper cette fonction : sur ses ~160 lignes, une centaine sont des
-- validations d'enums dont les valeurs sont peu memorisables et tres plausibles
-- a mal deviner (les vraies sont network_published, full_sigb, staff_roles,
-- full_governance ; 'shared_read' ou 'collegial' sonnent juste et n'existent
-- pas). Une reecriture de memoire remplace un bug par plusieurs, et ceux-la
-- passeraient inapercus jusqu'a la premiere demande refusee a tort.
--
-- ORDRE PRESERVE : validation du jeton en tete, consommation APRES toutes les
-- validations de champs — un formulaire mal rempli ne doit pas bruler un claim
-- qui n'est utilisable qu'une fois.
--
-- EN PROFITANT : `used_by_request_id` restait NULL. La colonne existe pour relier
-- le claim a la demande produite ; elle est renseignee apres l'insert.
--
-- COMPATIBILITE FUTURE : `coalesce(auth.uid(), v_consumed.user_id)` est conserve.
-- C'est le point d'accroche du chantier « inviter une bibliotheque par lien », ou
-- la personne qui soumet n'est pas encore connectee. Aujourd'hui
-- library_request_claims.user_id est NOT NULL, donc la branche ne sert jamais.
-- =============================================================================

CREATE OR REPLACE FUNCTION "public"."fn_submit_library_request_via_claim"("p_claim_token" "text", "p_library_name" "text", "p_library_short_name" "text" DEFAULT NULL::"text", "p_city" "text" DEFAULT NULL::"text", "p_state_region" "text" DEFAULT NULL::"text", "p_country" "text" DEFAULT 'Brasil'::"text", "p_library_email" "text" DEFAULT NULL::"text", "p_library_phone" "text" DEFAULT NULL::"text", "p_library_address" "text" DEFAULT NULL::"text", "p_project_stage" "text" DEFAULT NULL::"text", "p_contact_name" "text" DEFAULT NULL::"text", "p_contact_email" "text" DEFAULT NULL::"text", "p_contact_phone" "text" DEFAULT NULL::"text", "p_contact_role" "text" DEFAULT NULL::"text", "p_first_manager_intent" "text" DEFAULT 'sim'::"text", "p_summary" "text" DEFAULT NULL::"text", "p_public_profile" "text" DEFAULT NULL::"text", "p_collection_profile" "text" DEFAULT NULL::"text", "p_needs" "text" DEFAULT NULL::"text", "p_confirm_real" boolean DEFAULT false, "p_confirm_contact" boolean DEFAULT false, "p_requested_catalog_mode" "text" DEFAULT NULL::"text", "p_requested_circulation_mode" "text" DEFAULT NULL::"text", "p_requested_network_mode" "text" DEFAULT NULL::"text", "p_requested_governance_mode" "text" DEFAULT NULL::"text", "p_profile_template_chosen" "text" DEFAULT NULL::"text") RETURNS "public"."library_requests"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'extensions'
    AS $$
declare
  v_claim_context record;                    -- etait `jsonb` : c'est LE defaut repare
  v_consumed public.library_request_claims;  -- ligne rendue par la consommation
  v_user_id uuid := auth.uid();
  v_email_snapshot text;
  v_row public.library_requests;
begin
  -- Validation du token claim (reuse de la fonction existante).
  -- `select into` et non une assignation : la fonction rend une TABLE, pas un
  -- scalaire. Avec zero ligne le record est assigne mais tous ses champs sont
  -- NULL, d'ou le test sur claim_id en plus de FOUND.
  select c.claim_id, c.email_snapshot, c.expires_at, c.claim_purpose, c.is_valid
    into v_claim_context
    from public.fn_get_library_request_claim_context(p_claim_token) c;

  if not found or v_claim_context.claim_id is null or v_claim_context.is_valid is not true then
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

  -- Marquer le claim comme utilise. La ligne rendue porte user_id et
  -- email_snapshot : c'est la source autoritative. fn_get_..._context, elle,
  -- est exposee a `anon` et n'a pas a divulguer un user_id de plus.
  v_consumed := public.fn_consume_library_request_claim(p_claim_token);

  v_email_snapshot := lower(
    coalesce(
      nullif(btrim(v_consumed.email_snapshot), ''),
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
    coalesce(v_user_id, v_consumed.user_id),
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

  -- Boucler l'audit : la colonne used_by_request_id existe pour relier le
  -- claim a la demande qu'il a produite, et restait NULL. La consommation a
  -- lieu avant l'insert (l'id de la demande n'existe pas encore), d'ou ce
  -- rattrapage apres.
  update public.library_request_claims
     set used_by_request_id = v_row.id
   where id = v_consumed.id
     and used_by_request_id is null;

  return v_row;
end;
$$;


COMMENT ON FUNCTION public.fn_submit_library_request_via_claim(
  text, text, text, text, text, text, text, text, text, text, text, text, text,
  text, text, text, text, text, text, boolean, boolean, text, text, text, text, text
) IS 'Soumet une demande de bibliotheque au nom du porteur d''un claim valide. Repare le 2026-08-27 : la version d''origine assignait a un jsonb le resultat TABLE de fn_get_library_request_claim_context et echouait en 22P02 des la premiere instruction, meme avec un jeton valide. user_id et email_snapshot sont desormais lus dans la ligne rendue par fn_consume_library_request_claim.';
