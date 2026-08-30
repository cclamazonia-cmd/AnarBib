-- =========================================================================
-- Paquet B16 — le slug d'une bibliothèque garde ses lettres
-- =========================================================================
-- Date     : 2026-08-30
-- Chantier : parcours d'adhésion / provisionnement
-- Ref      : backlog v34 item B16
--
-- LE DÉFAUT
--
-- Dans `fn_provision_preactive_library`, `lower()` était appliqué APRÈS le
-- `regexp_replace(…, '[^a-z0-9]+', '-', 'g')`. Une majuscule n'appartenant pas
-- à `a-z`, elle était remplacée par un tiret AVANT d'avoir été minusculée.
-- Ce n'est pas la première lettre qui tombait, ce sont TOUTES les majuscules :
--
--   « Biblioteca Terra Livre »  ->  iblioteca-erra-ivre
--
-- Et le `translate()` censé replier les accentués était un no-op : ses deux
-- arguments de correspondance étaient la même chaîne, caractère pour caractère.
-- Les accentués tombaient donc dans le même `regexp_replace` :
--
--   « Associação Cultural Ñandú »  ->  associa-o-cultural-and
--
-- LA CORRECTION, ET LA DÉCISION QU'ELLE PORTE
--
-- Minusculer d'abord, et replier les accents avec `extensions.unaccent()` —
-- l'extension est installée sur cette base, dans le schéma `extensions`. Elle
-- est appelée qualifiée : le `search_path` de la fonction est figé à
-- `public, pg_catalog`, et on ne l'élargit pas pour un appel.
--
--   « Biblioteca Terra Livre »       ->  biblioteca-terra-livre
--   « Associação Cultural Ñandú »    ->  associacao-cultural-nandu
--   « Ateneu Llibertari de Gràcia »  ->  ateneu-llibertari-de-gracia
--
-- Le calcul sort de la fonction de provisionnement pour devenir
-- `fn_library_slug_from_name`, nommée et testable seule. C'est ce qui permet à
-- la suite `tests/sql/slug_biblioteca_tests.sql` d'exercer le cas majuscule et
-- le cas accentué sans avoir à provisionner une bibliothèque entière.
--
-- CE QU'ON NE FAIT PAS : renommer les slugs existants
--
-- `blmf`, `blmf-teste`, `btl`, `cira-marseille`, `mleg` ont été posés à la main
-- et sont corrects. Un slug vit dans les URL publiques, dans
-- `library_commons.library_slug` et dans la convention de chemin du stockage
-- `themes/<slug>/logo.png` : le renommer casserait les trois d'un coup, dont
-- l'affichage des logos. La correction ne vaut donc que pour les bibliothèques
-- à venir. C'est délibéré, et c'est écrit ici pour que personne n'ait à le
-- redécouvrir.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Le calcul du slug devient une fonction nommée
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_library_slug_from_name(p_name text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path = public, pg_catalog
AS $function$
  SELECT btrim(
           regexp_replace(
             lower(extensions.unaccent(coalesce(nullif(btrim(p_name), ''), 'biblioteca'))),
             '[^a-z0-9]+', '-', 'g'
           ),
           '-'
         );
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_library_slug_from_name(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_library_slug_from_name(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_library_slug_from_name(text) FROM authenticated;

COMMENT ON FUNCTION public.fn_library_slug_from_name(text) IS
  'Fabrique le slug d''une bibliotheque a partir de son nom : accents replies '
  '(extensions.unaccent), minuscules AVANT filtrage, tout le reste en tirets. '
  'Sortie du corps de fn_provision_preactive_library le 30/08/2026 (item B16) '
  'pour etre testable seule : jusque-la, lower() etait applique APRES le filtre '
  '[^a-z0-9], ce qui mangeait toutes les majuscules — « Biblioteca Terra Livre » '
  'donnait « iblioteca-erra-ivre ». Ne renomme AUCUN slug existant.';

-- -------------------------------------------------------------------------
-- 2. Le provisionnement s'en sert
-- -------------------------------------------------------------------------
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

  -- Idempotent : si deja provisionnee, renvoyer la biblio existante.
  if nullif(btrim(coalesce(v_request.approved_library_ref, '')), '') is not null then
    return v_request.approved_library_ref::uuid;
  end if;

  -- Slug : voir fn_library_slug_from_name (item B16 du 30/08/2026).
  v_base_slug := public.fn_library_slug_from_name(
    coalesce(nullif(btrim(v_request.library_short_name), ''),
             nullif(btrim(v_request.library_name), ''), 'biblioteca'));
  if v_base_slug is null or v_base_slug = '' then
    raise exception 'Nao foi possivel gerar um slug valido para a biblioteca.' using errcode = '23514';
  end if;
  v_final_slug := v_base_slug;
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
    logo_url, logo_file_key, is_test_mode, is_active
  ) values (
    v_library_id, v_final_slug, btrim(v_request.library_name),
    nullif(btrim(coalesce(v_request.library_short_name, '')), ''),
    v_email, v_reply_to, v_postal_address, null, null, false, true
  );

  if not exists (select 1 from public.library_service_state lss where lss.library_id = v_library_id) then
    insert into public.library_service_state (library_id) values (v_library_id);
  end if;

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

  update public.library_requests set approved_library_ref = v_library_id::text where id = p_request_id;
  update public.library_constitution_progress set library_id = v_library_id, updated_at = now()
    where request_id = p_request_id;

  return v_library_id;
end;
$function$;

-- -------------------------------------------------------------------------
-- 3. Vérification de structure (doctrine)
-- -------------------------------------------------------------------------
DO $$
BEGIN
  IF public.fn_library_slug_from_name('Biblioteca Terra Livre') <> 'biblioteca-terra-livre' THEN
    RAISE EXCEPTION 'slug majuscules : % au lieu de biblioteca-terra-livre',
      public.fn_library_slug_from_name('Biblioteca Terra Livre');
  END IF;
  IF public.fn_library_slug_from_name('Associação Cultural Ñandú') <> 'associacao-cultural-nandu' THEN
    RAISE EXCEPTION 'slug accents : % au lieu de associacao-cultural-nandu',
      public.fn_library_slug_from_name('Associação Cultural Ñandú');
  END IF;
  IF has_function_privilege('anon', 'public.fn_library_slug_from_name(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_library_slug_from_name reste ouverte a anon';
  END IF;
END $$;

COMMIT;
