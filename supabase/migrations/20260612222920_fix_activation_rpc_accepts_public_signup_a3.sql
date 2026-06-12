-- Migration : nouvelles bibliothèques injoignables — fn_activate_approved_library_request
--             ne posait jamais accepts_public_signup (héritait DEFAULT false)
-- Auteur  : Claude (Opus 4.8)
-- Session : Multi / self-inscription — correctif du gap documenté par le paquet L.1.1
-- Date    : 2026-06-12 (UTC)
--
-- CONTEXTE
-- --------
-- Le paquet L.1.1 (20260512090000_paquetL11_accepts_public_signup.sql) a ajouté
-- la colonne libraries.accepts_public_signup avec DEFAULT false, en backfillant
-- les biblios existantes selon la doctrine A3 (visibility public/network -> true,
-- private -> false). Il avait explicitement averti :
--
--   « ATTENTION : pour les FUTURES biblios créées après ce paquet, le DEFAULT
--     est false. Il faudra soit modifier la valeur explicitement lors de la
--     création, soit ajouter un trigger BEFORE INSERT qui applique la logique
--     A3 automatiquement. »
--
-- Ce TODO n'a jamais été soldé. La RPC d'activation d'une biblio approuvée,
-- public.fn_activate_approved_library_request, n'insère PAS accepts_public_signup
-- -> toute biblio créée après le 12/05/2026 naît à false, donc :
--   - invisible dans le dropdown « Solicitar inscrição » (TabBiblios.jsx filtre
--     accepts_public_signup = true) ;
--   - rejetée par api.request_membership (« não aceita inscrições públicas »).
--
-- Symptôme observé : MLEG (Maloca Libertária / Biblioteca Emma Goldman, créée le
-- 06/06/2026, catalog_mode='network_published') restait injoignable alors que
-- BLMF et BTL (axes identiques) l'étaient.
--
-- CORRECTIF
-- ---------
-- 1. La RPC pose désormais accepts_public_signup à la création, en traduisant la
--    doctrine A3 sur le modèle à axes (paquet F) : une biblio publiée au réseau
--    (catalog_mode='network_published') accepte les inscriptions publiques ; une
--    biblio 'local_only' ne les accepte pas par défaut. Conforme au CHECK
--    chk_catalog_published_requires_network (network_published => observer|federated).
-- 2. Backfill correctif idempotent des biblios déjà actives et publiées au réseau
--    restées à false à cause du gap (corrige MLEG sur un env reconstruit ; no-op
--    là où le flag est déjà bon).
--
-- Aucune permission / policy / search_path / extension touchée : on remplace une
-- fonction existante à l'identique (un seul ajout : une colonne dans l'INSERT) et
-- on corrige des données. Pas de changement de signature, d'attributs ni de droits.

BEGIN;

-- -------------------------------------------------------------------------
-- 1. RPC d'activation : pose accepts_public_signup selon les axes (A3)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_activate_approved_library_request(p_request_id uuid, p_library_slug text DEFAULT NULL::text, p_grant_submitter_librarian boolean DEFAULT true, p_make_membership_primary boolean DEFAULT true)
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

  -- Paquet F (20/05/2026) : axes effectifs
  v_eff_catalog_mode text;
  v_eff_circulation_mode text;
  v_eff_network_mode text;
  v_eff_governance_mode text;
  -- Paquet G (20/05/2026) : profil choisi consciemment
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

  -- Slug
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
  -- Paquet G : profil choisi (NULL si pas explicite)
  v_eff_profile_template := v_request.profile_template_chosen;

  -- INSERT libraries enrichi avec les 4 axes + profile_template_chosen
  -- Correctif (gap L.1.1) : accepts_public_signup posé explicitement à la
  -- création, traduisant la doctrine A3 sur le modèle à axes — une biblio
  -- publiée au réseau accepte les inscriptions publiques, une biblio
  -- local_only non. Sans cela la colonne retombait sur DEFAULT false et la
  -- nouvelle biblio naissait injoignable (dropdown + request_membership).
  insert into public.libraries (
    slug, name, short_name, city, state, country,
    is_active, is_default,
    catalog_mode, circulation_mode, network_mode, governance_mode,
    profile_template_chosen,
    accepts_public_signup
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
    v_eff_profile_template,
    (v_eff_catalog_mode = 'network_published')
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

  -- Membership librarian
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

-- -------------------------------------------------------------------------
-- 2. Backfill correctif idempotent (gap L.1.1 sur les biblios déjà créées)
-- -------------------------------------------------------------------------
-- Aligne sur la doctrine A3 (modèle à axes) toute biblio active publiée au
-- réseau restée à false. Idempotent : no-op si le flag est déjà correct
-- (notamment en prod où MLEG a déjà été corrigée manuellement le 13/06/2026).
UPDATE public.libraries
   SET accepts_public_signup = true
 WHERE is_active = true
   AND catalog_mode = 'network_published'
   AND accepts_public_signup = false;

-- -------------------------------------------------------------------------
-- 3. Vérification automatique (rollback si incohérence résiduelle)
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_src        text;
  v_mismatch   int;
BEGIN
  -- La RPC pose bien le flag à la création
  v_src := pg_get_functiondef('public.fn_activate_approved_library_request(uuid, text, boolean, boolean)'::regprocedure);
  IF position('accepts_public_signup' in v_src) = 0 THEN
    RAISE EXCEPTION 'Vérification échouée : fn_activate_approved_library_request ne pose toujours pas accepts_public_signup. Rollback.';
  END IF;

  -- Plus aucune biblio active publiée au réseau injoignable
  SELECT count(*) INTO v_mismatch
  FROM public.libraries
  WHERE is_active = true
    AND catalog_mode = 'network_published'
    AND accepts_public_signup = false;
  IF v_mismatch > 0 THEN
    RAISE EXCEPTION 'Vérification échouée : % biblio(s) network_published encore à accepts_public_signup=false. Rollback.', v_mismatch;
  END IF;

  RAISE NOTICE 'Correctif accepts_public_signup A3 : RPC patchée + 0 biblio network_published injoignable.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé (à adapter ; ne restaure PAS les valeurs backfillées) :
-- =========================================================================
-- Restaurer l'ancienne définition de la fonction depuis la migration d'origine
-- (sans la colonne accepts_public_signup dans l'INSERT). Le backfill data n'est
-- pas réversible automatiquement : remettre à false manuellement les biblios
-- concernées si nécessaire.
-- =========================================================================
