-- Migration : ONBO-Q2 Lot 1 — fondation « biblio pré-active » pour la constitution
-- Auteur  : Claude (Opus 4.8)
-- Session : Onboarding / Oficina de constituição — câblage des volets
-- Date    : 2026-06-13 (UTC)
--
-- CONTEXTE — cf. docs/journal/cadrages/CADRAGE_ONBO_Q2_atelier_volets_preactive_2026-06-13.md
-- Pendant la constitution aucune biblio n'existe (création seulement à l'activation),
-- donc les champs des volets 1-9 sont des leurres. Voie A (spec §6.4) : créer la biblio
-- en PRÉ-ACTIVE (is_active=false) dès l'approbation ; les volets l'éditent via les
-- composants existants ; l'activation = BASCULE is_active=true au volet 10.
--
-- Ce Lot 1 (backend) :
--   1. library_constitution_progress.library_id (lien vers la biblio pré-active)
--   2. policy SELECT staff sur libraries (lire sa biblio même pré-active) — sans quoi
--      fn_library_visible_to_caller (exige is_active=true) la rend illisible.
--   3. fn_provision_preactive_library : crée la biblio pré-active (+ commons, email,
--      service_state, membership coordenador active), idempotent. INTERNE (REVOKE).
--   4. fn_approve_library_request : provisionne à l'approbation (atomique).
--   5. fn_activate_approved_library_request : « ensure-provisioned + FLIP » (+ sync des
--      axes volet 0). Réconcilie le correctif MLEG (A3) : la dérivation
--      accepts_public_signup vit dans le provisioning et est rejouée au flip.
--   6. my_constitution_progress_v1 : expose library_id + slug.

BEGIN;

-- 1. Lien biblio pré-active sur la progression -------------------------------
ALTER TABLE public.library_constitution_progress
  ADD COLUMN IF NOT EXISTS library_id uuid REFERENCES public.libraries(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.library_constitution_progress.library_id IS
  'Biblio pré-active (is_active=false) provisionnée à l''approbation pour que les volets '
  'éditent la vraie config. Basculée en active au volet 10. ONBO-Q2 Lot 1 (2026-06-13).';

-- 2. Policy SELECT staff (lire sa biblio même pré-active) --------------------
-- fn_library_visible_to_caller exige is_active=true au niveau racine → une biblio
-- pré-active est illisible même par sa coordinatrice. On ouvre une voie SELECT dédiée
-- au staff (s'ajoute en OR aux policies existantes).
DROP POLICY IF EXISTS "libraries_staff_read" ON public.libraries;
CREATE POLICY "libraries_staff_read"
ON public.libraries FOR SELECT TO authenticated
USING (public.user_can_act_as_staff_on_library(id));

COMMENT ON POLICY "libraries_staff_read" ON public.libraries IS
  'Le staff (membership active librarian/coordenador, ou admin réseau) lit toujours sa '
  'biblio, y compris pré-active (is_active=false) pendant la constitution. S''ajoute (OR) '
  'à libraries_public_read/_signup_read. ONBO-Q2 Lot 1 (2026-06-13).';

-- 3. fn_provision_preactive_library (INTERNE) -------------------------------
CREATE OR REPLACE FUNCTION public.fn_provision_preactive_library(p_request_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_request public.library_requests%rowtype;
  v_library_id uuid;
  v_base_slug text;
  v_final_slug text;
  v_suffix integer := 1;
  v_email text;
  v_reply_to text;
  v_postal_address text;
  v_eff_catalog_mode text;
  v_eff_circulation_mode text;
  v_eff_network_mode text;
  v_eff_governance_mode text;
  v_is_primary boolean;
begin
  select * into v_request from public.library_requests where id = p_request_id for update;
  if not found then
    raise exception 'Solicitacao nao encontrada.' using errcode = 'P0002';
  end if;

  -- Idempotent : si déjà provisionnée, renvoyer la biblio existante.
  if nullif(btrim(coalesce(v_request.approved_library_ref, '')), '') is not null then
    return v_request.approved_library_ref::uuid;
  end if;

  -- Slug (logique identique à l'activation historique)
  v_base_slug := lower(btrim(regexp_replace(translate(
      coalesce(nullif(btrim(v_request.library_short_name), ''),
               nullif(btrim(v_request.library_name), ''), 'biblioteca'),
      'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNnYyy',
      'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNnYyy'),
      '[^a-z0-9]+', '-', 'g')));
  v_base_slug := trim(both '-' from coalesce(v_base_slug, ''));
  if v_base_slug is null or v_base_slug = '' then
    raise exception 'Nao foi possivel gerar um slug valido para a biblioteca.' using errcode = '23514';
  end if;
  v_final_slug := v_base_slug;
  while exists (select 1 from public.libraries l where lower(l.slug)=lower(v_final_slug))
     or exists (select 1 from public.library_email_identity lei where lower(lei.library_slug)=lower(v_final_slug))
     or exists (select 1 from public.library_commons lc where lower(lc.library_slug)=lower(v_final_slug))
  loop
    v_suffix := v_suffix + 1;
    v_final_slug := v_base_slug || '-' || v_suffix::text;
  end loop;

  v_eff_catalog_mode     := coalesce(v_request.requested_catalog_mode, 'network_published');
  v_eff_circulation_mode := coalesce(v_request.requested_circulation_mode, 'full_sigb');
  v_eff_network_mode     := coalesce(v_request.requested_network_mode, 'federated');
  v_eff_governance_mode  := coalesce(v_request.requested_governance_mode, 'full_governance');

  -- Biblio PRÉ-ACTIVE : is_active=false (invisible catalogue/signup automatiquement,
  -- cf. fn_library_visible_to_caller + libraries_public_signup_read). accepts_public_signup
  -- posé selon A3 (réconcilie MLEG) — sans effet tant que la biblio reste pré-active.
  insert into public.libraries (
    slug, name, short_name, city, state, country,
    is_active, is_default,
    catalog_mode, circulation_mode, network_mode, governance_mode,
    profile_template_chosen, accepts_public_signup
  ) values (
    v_final_slug, btrim(v_request.library_name),
    nullif(btrim(coalesce(v_request.library_short_name, '')), ''),
    btrim(v_request.city), nullif(btrim(coalesce(v_request.state_region, '')), ''),
    coalesce(nullif(btrim(coalesce(v_request.country, '')), ''), 'Brasil'),
    false, false,
    v_eff_catalog_mode, v_eff_circulation_mode, v_eff_network_mode, v_eff_governance_mode,
    v_request.profile_template_chosen, (v_eff_catalog_mode = 'network_published')
  ) returning id into v_library_id;

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
    v_email, v_reply_to, v_postal_address, null, null, 'normal', false, true
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

  -- Membership coordenador ACTIVE pour la personne qui constitue (= submitter).
  -- Indispensable : user_can_act_as_staff_on_library passe → édition des volets +
  -- lecture via libraries_staff_read. Aligné spec §6.4 (rôle coordenador).
  v_is_primary := not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = v_request.submitted_by_user_id and m.status <> 'removed'
  );
  if not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = v_request.submitted_by_user_id and m.library_id = v_library_id
  ) then
    insert into public.user_library_memberships (user_id, library_id, role, is_primary, status)
    values (v_request.submitted_by_user_id, v_library_id, 'coordenador', v_is_primary, 'active');
  end if;

  -- Liens demande ↔ biblio + progression ↔ biblio
  update public.library_requests set approved_library_ref = v_library_id::text where id = p_request_id;
  update public.library_constitution_progress set library_id = v_library_id, updated_at = now()
    where request_id = p_request_id;

  return v_library_id;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_provision_preactive_library(uuid) FROM PUBLIC;
-- INTERNE : appelée uniquement par les RPC SECDEF d'approbation/activation (exécutées avec
-- les droits du propriétaire). Aucun GRANT à anon/authenticated.

COMMENT ON FUNCTION public.fn_provision_preactive_library(uuid) IS
  'Crée la biblio PRÉ-ACTIVE (is_active=false) d''une demande approuvée : libraries + '
  'commons + email_identity + service_state + membership coordenador active. Idempotent. '
  'Interne (fn_approve / fn_activate). ONBO-Q2 Lot 1 (2026-06-13).';

-- 4. Approbation : provisionne la biblio pré-active (atomique) ---------------
CREATE OR REPLACE FUNCTION api.fn_approve_library_request(p_request_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE v_req record; v_progress_id uuid;
BEGIN
    IF NOT public.fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only a network admin can approve a request' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_req FROM public.library_requests WHERE id = p_request_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002'; END IF;

    UPDATE public.library_requests
        SET request_status = 'aprovada', reviewed_at = now(), reviewed_by_user_id = auth.uid()
        WHERE id = p_request_id;

    -- Crée la constitution si absente (deadline +60 j, volet 0 laissé à faire — §3.3).
    INSERT INTO public.library_constitution_progress (request_id, coordenador_id)
        VALUES (p_request_id, v_req.submitted_by_user_id)
        ON CONFLICT (request_id) DO NOTHING
        RETURNING id INTO v_progress_id;
    IF v_progress_id IS NULL THEN
        SELECT id INTO v_progress_id FROM public.library_constitution_progress WHERE request_id = p_request_id;
    END IF;

    UPDATE public.profiles
        SET solicitante_state = 'coordenador_em_constituicao'
        WHERE id = v_req.submitted_by_user_id;

    -- ONBO-Q2 : provisionne la biblio pré-active (atomique avec l'approbation) pour que
    -- les volets aient une vraie biblio à éditer. Idempotent.
    PERFORM public.fn_provision_preactive_library(p_request_id);

    RETURN v_progress_id;
END;
$function$;

-- 5. Activation = ensure-provisioned + FLIP ---------------------------------
CREATE OR REPLACE FUNCTION public.fn_activate_approved_library_request(p_request_id uuid, p_library_slug text DEFAULT NULL::text, p_grant_submitter_librarian boolean DEFAULT true, p_make_membership_primary boolean DEFAULT true)
RETURNS TABLE(request_id uuid, library_id uuid, library_slug text, membership_id uuid, membership_role text, request_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_request public.library_requests%rowtype;
  v_library public.libraries%rowtype;
  v_library_id uuid;
  v_membership_id uuid;
  v_membership_role text := null;
begin
  if v_actor is not null then
    if public.fn_current_user_can_review_library_requests() is not true
       and public.fn_current_user_can_send_network_responses() is not true then
      raise exception 'Voce nao tem permissao para ativar bibliotecas aprovadas.' using errcode = '42501';
    end if;
  end if;
  if p_request_id is null then
    raise exception 'Informe a solicitacao aprovada a ativar.' using errcode = '23514';
  end if;

  select * into v_request from public.library_requests where id = p_request_id for update;
  if not found then
    raise exception 'Solicitacao nao encontrada.' using errcode = 'P0002';
  end if;
  if v_request.request_status <> 'aprovada' then
    raise exception 'So e possivel ativar tecnicamente uma solicitacao ja aprovada.' using errcode = '23514';
  end if;

  -- ONBO-Q2 : la biblio est désormais provisionnée (pré-active) à l'approbation. On
  -- s'assure qu'elle existe (idempotent ; couvre aussi les demandes legacy), puis on
  -- BASCULE is_active=true au lieu de tout créer.
  v_library_id := public.fn_provision_preactive_library(p_request_id);
  select * into v_library from public.libraries where id = v_library_id for update;

  -- Garde « déjà activée » : basée sur is_active (approved_library_ref est posé dès le
  -- provisioning, ne peut plus servir de témoin).
  if v_library.is_active then
    raise exception 'Esta solicitacao ja foi ativada tecnicamente.' using errcode = '23514';
  end if;

  -- FLIP + synchronise les axes depuis le volet 0 de l'atelier (la décision de
  -- constitution prime) + redérive accepts_public_signup (A3).
  -- Sous-requêtes scalaires (et non UPDATE…FROM) pour que le FLIP s'applique TOUJOURS,
  -- même sans row de progression : la jointure interne aurait sauté la bascule.
  update public.libraries l set
    is_active = true,
    catalog_mode    = coalesce((select cp.volet_0_catalog_mode    from public.library_constitution_progress cp where cp.request_id = p_request_id), l.catalog_mode),
    circulation_mode= coalesce((select cp.volet_0_circulation_mode from public.library_constitution_progress cp where cp.request_id = p_request_id), l.circulation_mode),
    network_mode    = coalesce((select cp.volet_0_network_mode     from public.library_constitution_progress cp where cp.request_id = p_request_id), l.network_mode),
    governance_mode = coalesce((select cp.volet_0_governance_mode  from public.library_constitution_progress cp where cp.request_id = p_request_id), l.governance_mode),
    accepts_public_signup = (coalesce((select cp.volet_0_catalog_mode from public.library_constitution_progress cp where cp.request_id = p_request_id), l.catalog_mode) = 'network_published'),
    updated_at = now()
  where l.id = v_library_id;

  -- Membership : le provisioning a créé une membership coordenador active. On l'assure
  -- active + is_primary selon le paramètre.
  -- Alias m. obligatoire : library_id (colonne) entrerait en collision avec le
  -- paramètre OUT library_id du RETURNS TABLE (« column reference is ambiguous »).
  if p_grant_submitter_librarian is true then
    -- is_primary défensif : true seulement si aucune AUTRE appartenance primaire active
    -- (sinon viol de ux_user_library_memberships_one_primary_active — bug latent de
    -- l'ancienne activation pour un·e solicitante déjà primaire ailleurs).
    update public.user_library_memberships m
       set status = 'active',
           is_primary = (coalesce(p_make_membership_primary, true)
                         and not exists (select 1 from public.user_library_memberships o
                                          where o.user_id = v_request.submitted_by_user_id
                                            and o.library_id <> v_library_id
                                            and o.is_primary and o.status = 'active')),
           updated_at = now()
     where m.user_id = v_request.submitted_by_user_id and m.library_id = v_library_id
     returning m.id, m.role into v_membership_id, v_membership_role;
  else
    select m.id, m.role into v_membership_id, v_membership_role
      from public.user_library_memberships m
     where m.user_id = v_request.submitted_by_user_id and m.library_id = v_library_id limit 1;
  end if;

  -- Le compte quitte l'état de constitution.
  update public.profiles set solicitante_state = null
   where id = v_request.submitted_by_user_id and solicitante_state = 'coordenador_em_constituicao';

  -- Traçabilité
  update public.library_requests
     set approved_membership_ref = case when v_membership_id is null then null else v_membership_id::text end,
         reviewed_at = coalesce(reviewed_at, now()),
         reviewed_by_user_id = coalesce(reviewed_by_user_id, v_actor)
   where id = v_request.id;

  return query
  select v_request.id, v_library_id, v_library.slug, v_membership_id, v_membership_role, 'aprovada'::text;
end;
$function$;

-- 6. Vue : expose library_id + slug -----------------------------------------
CREATE OR REPLACE VIEW api.my_constitution_progress_v1
WITH (security_invoker = true) AS
 SELECT cp.id, cp.request_id, cp.coordenador_id, cp.started_at, cp.deadline_at, cp.completed_at,
    cp.volet_0_profil_done, cp.volet_0_catalog_mode, cp.volet_0_circulation_mode,
    cp.volet_0_network_mode, cp.volet_0_governance_mode,
    cp.volet_1_identite_done, cp.volet_2_horaires_done, cp.volet_3_pessoas_done,
    cp.volet_4_catalogacao_done, cp.volet_5_circulacao_done, cp.volet_6_adhesion_done,
    cp.volet_7_emails_done, cp.volet_8_visibilidade_done, cp.volet_9_dados_done,
    cp.volet_10_regimento_done, cp.regimento_pdf_url, cp.created_at, cp.updated_at,
    r.library_name, r.request_status,
    cp.library_id, l.slug AS library_slug
   FROM public.library_constitution_progress cp
     JOIN public.library_requests r ON r.id = cp.request_id
     LEFT JOIN public.libraries l ON l.id = cp.library_id
  WHERE cp.coordenador_id = ( SELECT auth.uid() AS uid);

-- 7. Vérification structurelle (rollback auto si KO) ------------------------
DO $$
DECLARE v_activate text;
BEGIN
  IF NOT EXISTS (select 1 from information_schema.columns
     where table_schema='public' and table_name='library_constitution_progress' and column_name='library_id') THEN
    RAISE EXCEPTION 'KO: library_constitution_progress.library_id manquante';
  END IF;
  IF NOT EXISTS (select 1 from pg_policy where polrelid='public.libraries'::regclass and polname='libraries_staff_read') THEN
    RAISE EXCEPTION 'KO: policy libraries_staff_read manquante';
  END IF;
  IF has_function_privilege('authenticated', 'public.fn_provision_preactive_library(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'KO: fn_provision_preactive_library ne doit pas etre exposee a authenticated';
  END IF;
  v_activate := pg_get_functiondef('public.fn_activate_approved_library_request(uuid,text,boolean,boolean)'::regprocedure);
  IF position('fn_provision_preactive_library' in v_activate) = 0
     OR position('is_active = true' in v_activate) = 0 THEN
    RAISE EXCEPTION 'KO: fn_activate ne bascule pas via le provisioning';
  END IF;
  RAISE NOTICE 'ONBO-Q2 Lot 1 OK : provisioning pré-actif + libraries_staff_read + activation=flip.';
END $$;

COMMIT;
