-- ============================================================================
-- Paquet G hotfix (20/05/2026) : colonne profile_template_chosen sur libraries
-- ============================================================================
--
-- Contexte : le paquet G (LibraryProfileBanner) avait ete livre avec une lecture
-- de libraries.profile_template_chosen, mais la colonne n'existait que dans
-- library_requests (ou stockee par le wizard onboarding du paquet F).
--
-- Cette migration :
--   1. Ajoute la colonne sur libraries avec CHECK ('A','B','C','D','custom','NULL')
--   2. Toutes les biblios existantes restent NULL (= "pas choisi consciemment")
--      -> Le banner G s'affichera correctement pour BLMF, BTL, etc.
--   3. Patche fn_activate_approved_library_request pour propager
--      requested_profile_template depuis library_requests.profile_template_chosen
--   4. Patche fn_execute_library_profile_change pour recalculer le template
--      apres chaque transition (matchant le quadruplet final aux profils A/B/C/D
--      ou retombant sur 'custom' si pas de match exact).
--
-- Doctrine politique :
--   profile_template_chosen IS NULL  = biblio en profil par defaut, pas de choix
--                                      conscient (banner G s'affiche)
--   profile_template_chosen = 'A/B/C/D' = biblio sur profil-type pur, choisi
--                                          via wizard ou transition
--   profile_template_chosen = 'custom' = biblio sur configuration personnalisee,
--                                          choisie via transitions
--
-- Note : applique en prod via MCP apply_migration le 19/05/2026 21:38,
-- timestamp realigne de 20260519191117 vers 20260519280000.
-- Ce fichier represente l'etat exact applique.
-- ============================================================================

BEGIN;

-- 1. ALTER TABLE
ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS profile_template_chosen text DEFAULT NULL;

ALTER TABLE public.libraries
  DROP CONSTRAINT IF EXISTS chk_libraries_profile_template_chosen;

ALTER TABLE public.libraries
  ADD CONSTRAINT chk_libraries_profile_template_chosen
  CHECK (profile_template_chosen IS NULL
      OR profile_template_chosen IN ('A', 'B', 'C', 'D', 'custom'));

COMMENT ON COLUMN public.libraries.profile_template_chosen IS
  'Paquet G/F (20/05/2026) : profil-type choisi consciemment a la creation
   ou via transition. NULL = biblio en profil par defaut (banner G visible).
   A/B/C/D = profil-type pur. custom = configuration personnalisee.';

-- 2. fn_activate_approved_library_request : propager le choix
CREATE OR REPLACE FUNCTION public.fn_activate_approved_library_request(
  p_request_id uuid,
  p_library_slug text DEFAULT NULL::text,
  p_grant_submitter_librarian boolean DEFAULT true,
  p_make_membership_primary boolean DEFAULT true
)
RETURNS TABLE(request_id uuid, library_id uuid, library_slug text,
              membership_id uuid, membership_role text, request_status text)
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

  v_eff_catalog_mode text;
  v_eff_circulation_mode text;
  v_eff_network_mode text;
  v_eff_governance_mode text;
  v_eff_profile_template text;
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

  v_eff_catalog_mode    := coalesce(v_request.requested_catalog_mode, 'network_published');
  v_eff_circulation_mode := coalesce(v_request.requested_circulation_mode, 'full_sigb');
  v_eff_network_mode    := coalesce(v_request.requested_network_mode, 'federated');
  v_eff_governance_mode := coalesce(v_request.requested_governance_mode, 'full_governance');
  v_eff_profile_template := v_request.profile_template_chosen;

  insert into public.libraries (
    slug, name, short_name, city, state, country,
    is_active, is_default,
    catalog_mode, circulation_mode, network_mode, governance_mode,
    profile_template_chosen
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
    v_eff_governance_mode,
    v_eff_profile_template
  )
  returning id into v_library_id;

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

-- 3. fn_execute_library_profile_change : recalculer le template apres transition
CREATE OR REPLACE FUNCTION public.fn_execute_library_profile_change(p_proposal_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id     uuid := auth.uid();
  v_proposal      public.library_profile_proposals%ROWTYPE;
  v_is_staff      boolean := false;
  v_is_system     boolean := false;
  v_archive_result jsonb := NULL;
  v_new_template  text;
  v_lib           public.libraries%ROWTYPE;
BEGIN
  SELECT * INTO v_proposal
  FROM public.library_profile_proposals
  WHERE id = p_proposal_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'EXECUTE_PROPOSAL_NOT_FOUND : proposition introuvable (%)', p_proposal_id
      USING ERRCODE = 'no_data_found',
            HINT    = 'error.profile_change.proposal_not_found';
  END IF;

  v_is_system := (v_caller_id IS NULL);

  IF NOT v_is_system THEN
    v_is_staff := EXISTS (
      SELECT 1 FROM public.user_library_memberships
      WHERE library_id = v_proposal.library_id
        AND user_id    = v_caller_id
        AND status     = 'active'
        AND role IN ('librarian', 'coordenador')
    );

    IF NOT v_is_staff THEN
      RAISE EXCEPTION 'EXECUTE_NOT_AUTHORIZED : caller n''est ni staff de la biblio ni systeme cron'
        USING ERRCODE = 'insufficient_privilege',
              HINT    = 'error.profile_change.not_authorized';
    END IF;
  END IF;

  IF v_proposal.status NOT IN ('accepted_unanimous', 'accepted_majority') THEN
    RAISE EXCEPTION 'EXECUTE_PROPOSAL_NOT_ACCEPTED : proposition pas executable (status=%)', v_proposal.status
      USING ERRCODE = 'invalid_parameter_value',
            HINT    = 'error.profile_change.not_accepted';
  END IF;

  IF v_proposal.grace_period_until IS NULL OR v_proposal.grace_period_until > now() THEN
    RAISE EXCEPTION 'EXECUTE_GRACE_PERIOD_ACTIVE : carence active jusqu''a %', v_proposal.grace_period_until
      USING ERRCODE = 'invalid_parameter_value',
            HINT    = 'error.profile_change.grace_period_active';
  END IF;

  INSERT INTO public.library_profile_history (
    library_id, axis, old_value, new_value, changed_by, changed_at, motivation
  )
  VALUES (
    v_proposal.library_id,
    v_proposal.axis,
    v_proposal.old_value,
    v_proposal.new_value,
    COALESCE(v_caller_id, v_proposal.proposed_by),
    now(),
    'Transition type ' || v_proposal.transition_type ||
    ' (' || v_proposal.governance_required || ') : ' || v_proposal.motivation
  );

  IF    v_proposal.axis = 'catalog_mode'     THEN UPDATE public.libraries SET catalog_mode     = v_proposal.new_value WHERE id = v_proposal.library_id;
  ELSIF v_proposal.axis = 'circulation_mode' THEN UPDATE public.libraries SET circulation_mode = v_proposal.new_value WHERE id = v_proposal.library_id;
  ELSIF v_proposal.axis = 'network_mode'     THEN UPDATE public.libraries SET network_mode     = v_proposal.new_value WHERE id = v_proposal.library_id;
  ELSIF v_proposal.axis = 'governance_mode'  THEN UPDATE public.libraries SET governance_mode  = v_proposal.new_value WHERE id = v_proposal.library_id;
  END IF;

  -- Paquet G : recalculer profile_template_chosen base sur le nouveau quadruplet
  SELECT * INTO v_lib FROM public.libraries WHERE id = v_proposal.library_id;

  v_new_template := CASE
    WHEN v_lib.catalog_mode = 'local_only'
     AND v_lib.circulation_mode = 'off'
     AND v_lib.network_mode = 'isolated'
     AND v_lib.governance_mode = 'informal' THEN 'A'
    WHEN v_lib.catalog_mode = 'local_only'
     AND v_lib.circulation_mode = 'informal'
     AND v_lib.network_mode = 'isolated'
     AND v_lib.governance_mode = 'informal' THEN 'B'
    WHEN v_lib.catalog_mode = 'network_published'
     AND v_lib.circulation_mode = 'informal'
     AND v_lib.network_mode = 'observer'
     AND v_lib.governance_mode = 'staff_roles' THEN 'C'
    WHEN v_lib.catalog_mode = 'network_published'
     AND v_lib.circulation_mode = 'full_sigb'
     AND v_lib.network_mode = 'federated'
     AND v_lib.governance_mode = 'full_governance' THEN 'D'
    ELSE 'custom'
  END;

  UPDATE public.libraries
     SET profile_template_chosen = v_new_template
   WHERE id = v_proposal.library_id;

  IF v_proposal.axis = 'circulation_mode' AND v_proposal.new_value = 'off' THEN
    v_archive_result := public.fn_archive_library_circulation(
      v_proposal.library_id, p_proposal_id
    );
  END IF;

  IF v_proposal.axis = 'circulation_mode'
     AND v_proposal.old_value = 'full_sigb'
     AND v_proposal.new_value = 'informal' THEN
    v_archive_result := public.fn_archive_library_cotisations(
      v_proposal.library_id, p_proposal_id
    );
  END IF;

  UPDATE public.library_profile_proposals
  SET status       = 'completed',
      completed_at = now()
  WHERE id = p_proposal_id;

  UPDATE public.library_profile_grace_locks
  SET released_at = now()
  WHERE proposal_id = p_proposal_id
    AND released_at IS NULL;

  RETURN jsonb_build_object(
    'proposal_id',          p_proposal_id,
    'library_id',           v_proposal.library_id,
    'axis',                 v_proposal.axis,
    'old_value',            v_proposal.old_value,
    'new_value',            v_proposal.new_value,
    'completed_at',         now(),
    'executed_by_caller',   COALESCE(v_caller_id::text, 'system_cron'),
    'archive_result',       v_archive_result,
    'new_template_chosen',  v_new_template
  );
END;
$function$;

-- 4. DO block de verification
DO $verify$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'libraries'
      AND column_name = 'profile_template_chosen'
  ) THEN
    RAISE EXCEPTION 'VERIF FAIL : colonne libraries.profile_template_chosen manquante';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chk_libraries_profile_template_chosen'
  ) THEN
    RAISE EXCEPTION 'VERIF FAIL : contrainte chk_libraries_profile_template_chosen manquante';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.libraries
    WHERE slug IN ('blmf', 'btl')
      AND profile_template_chosen IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'VERIF FAIL : BLMF ou BTL ne devraient pas avoir profile_template_chosen renseigne';
  END IF;

  RAISE NOTICE 'Paquet G hotfix : verification OK';
END
$verify$;

COMMIT;
