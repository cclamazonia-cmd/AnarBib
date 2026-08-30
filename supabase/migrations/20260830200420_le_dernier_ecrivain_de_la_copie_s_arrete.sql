-- =========================================================================
-- Paquet IDENTITE-MAIL — le dernier écrivain de la copie s'arrête
-- =========================================================================
-- Date     : 2026-08-30
-- Chantier : dédoublonnage de l'identité mail des bibliothèques
-- Ref      : 20260830194926 (retrait de la table et de la colonne)
--
-- CE QUE J'AI RATÉ, ET COMMENT
--
-- La migration précédente supprime `public.library_email_identity` et
-- `library_commons.email_delivery_mode`. J'avais cherché les dépendances avec
-- `pg_depend` — qui ne voit QUE les vues, les contraintes, les index : les
-- objets dont Postgres suit vraiment la dépendance. Le CORPS d'une fonction
-- PL/pgSQL n'en fait pas partie : c'est du texte, résolu à l'exécution. Une
-- fonction peut donc citer une table supprimée sans que rien ne le signale au
-- moment du DROP, et échouer seulement le jour où on l'appelle.
--
-- `fn_provision_preactive_library` — celle qui crée une bibliothèque
-- pré-active quand une demande d'adhésion est approuvée — faisait TROIS choses
-- avec les objets supprimés :
--   * elle consultait `library_email_identity` dans sa boucle d'unicité de slug ;
--   * elle INSÉRAIT dedans, ligne par ligne, à chaque provisionnement ;
--   * elle posait `email_delivery_mode` dans son insert `library_commons`.
--
-- C'est le job `sql-tests` qui l'a vue, sur deux suites d'onboarding
-- (onbo_q13_transfer_mandate, onbo_111_lot1_eval). Il rejoue le schéma depuis
-- zéro et APPELLE les fonctions — c'est-à-dire qu'il fait la seule chose qui
-- pouvait révéler le problème. La migration n'était pas encore appliquée en
-- production quand le rouge est tombé : rien n'a cassé pour personne.
--
-- La requête qui aurait évité ça, et qui vaut pour tout DROP :
--   select n.nspname||'.'||p.proname from pg_proc p
--     join pg_namespace n on n.oid = p.pronamespace
--    where p.prosrc ilike '%<objet_supprimé>%';
-- Elle rend ici exactement une fonction, celle-ci.
--
-- CE QUE ÇA CHANGE
--
-- Rien au comportement : la ligne `library_email_identity` que la fonction
-- créait était la copie que la vue `api.library_email_identity` DÉRIVE
-- désormais de `libraries` ⋈ `library_commons`. Une biblio provisionnée après
-- ce paquet a donc exactement la même identité d'expédition qu'avant — elle
-- n'est simplement plus écrite deux fois. La boucle de slug garde ses deux
-- vraies sources, `libraries` et `library_commons`.
-- =========================================================================

BEGIN;

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
  -- La troisième clause consultait public.library_email_identity, supprimée par
  -- 20260830194926. Elle n'apportait rien : cette table était alimentée par
  -- cette fonction même, en miroir de library_commons — jamais un slug ne
  -- pouvait s'y trouver sans être aussi dans l'une des deux autres.
  while exists (select 1 from public.libraries l where lower(l.slug)=lower(v_final_slug))
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

  -- `email_delivery_mode` retiré de l'insert : la colonne n'existe plus (elle
  -- n'était appliquée nulle part, le commutateur réel est library_mail_channels).
  insert into public.library_commons (
    library_id, library_slug, display_name, short_name,
    contact_email, reply_to_email, postal_address,
    logo_url, logo_file_key, is_test_mode, is_active
  ) values (
    v_library_id, v_final_slug, btrim(v_request.library_name),
    nullif(btrim(coalesce(v_request.library_short_name, '')), ''),
    v_email, v_reply_to, v_postal_address, null, null, false, true
  );

  -- L'insert dans public.library_email_identity est retiré : la table est
  -- supprimée, et api.library_email_identity dérive les mêmes champs de
  -- libraries ⋈ library_commons. L'identité d'expédition de la biblio est donc
  -- identique — elle n'est simplement plus écrite une seconde fois.

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

-- -------------------------------------------------------------------------
-- Vérification (doctrine) : plus aucune fonction ne cite les objets retirés.
-- -------------------------------------------------------------------------
-- `prosrc` contient les COMMENTAIRES du corps, pas seulement le code. Une
-- première version de cette assertion comparait le texte brut : elle a échoué
-- sur cette fonction même, dont les commentaires expliquent précisément ce qui
-- a été retiré et pourquoi. Le garde-fou refusait la correction à cause de sa
-- propre explication.
--
-- Et la raison pour laquelle je ne l'avais pas vu vaut d'être écrite : la
-- vérification contre la production avait été faite sur une version ALLÉGÉE du
-- corps, sans les commentaires — donc pas sur l'artefact livré. Vérifier une
-- variante n'est pas vérifier ce qu'on livre.
--
-- On retire donc les commentaires de ligne avant de comparer.
DO $$
DECLARE v_noms text;
BEGIN
  SELECT string_agg(n.nspname||'.'||p.proname, ', ' ORDER BY p.proname) INTO v_noms
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE regexp_replace(p.prosrc, '--[^\n]*', '', 'g') ILIKE '%library_email_identity%'
      OR regexp_replace(p.prosrc, '--[^\n]*', '', 'g') ILIKE '%email_delivery_mode%';
  IF v_noms IS NOT NULL THEN
    RAISE EXCEPTION 'des fonctions citent encore les objets retires : %', v_noms;
  END IF;
END $$;

COMMIT;
