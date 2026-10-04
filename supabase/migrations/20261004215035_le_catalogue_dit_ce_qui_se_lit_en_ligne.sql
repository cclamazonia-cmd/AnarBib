-- =========================================================================
-- Le catalogue dit ce qui se lit en ligne, et à qui c'est réservé
-- =========================================================================
-- Date     : 2026-10-04
-- Chantier : ressources numériques (étape 1 : indicateur et accès)
-- Auteur   : Claude (Opus 5.5), pour Xavier
-- Session  : Retours du catalogage & numérique
--
-- Constat en production le 04/10/2026 : 19 livres ont un PDF public actif,
-- AUCUN ne porte l'indicateur « Lire en ligne » du catalogue ; le seul livre
-- badgé est celui dont le PDF est réservé (livre 1434, BTL), que l'anonyme ne
-- peut pas lire. Cause : has_online_reading des vues matérialisées
-- (mv_books_catalog_list_v1 / _network_v1) ne compte que
--   resource_type = 'pdf_restrito' AND access_scope = 'conta_ativa'.
-- Recréer ces vues emporterait leurs dépendants (catalog_works_v1…) pour un
-- badge : on sert l'information à part, toujours fraîche (les vues ne se
-- rafraîchissent que toutes les 15 min), pour les seuls livres affichés.
--
-- (1) catalog_digital_access_v1(p_book_ids) : par livre visible de l'appelant,
--     les usages publics (lire, écouter, voir, lien), la présence d'une
--     ressource réservée, si l'appelant peut la lire, et les bibliothèques
--     détentrices à nommer (« réservé aux lecteur·rices de … »).
--     Mêmes règles que la fiche : ressource active ; publique = validée
--     bibliographiquement (get_book_primary_public_digital_asset_v2) ;
--     réservée = fichier présent (fn_book_restricted_pdf_state) ; livre
--     visible = un détenteur visible (fn_library_visible_to_caller).
-- (2) Décision de Xavier (04/10) : l'administration du réseau lit aussi les
--     PDF réservés aux bibliothèques détentrices, sans adhésion. Le prédicat
--     unique fn_current_user_is_member_of_holding_library l'apprend ; ses deux
--     appelants (get_accessible_digital_asset_by_id_v2, fn_book_restricted_pdf_state,
--     relevés dans pg_proc le 04/10) suivent. Le compte actif reste exigé.
--
-- CHECKLIST DOCTRINE
--   [x] SECURITY DEFINER : SET search_path ; REVOKE FROM PUBLIC, anon,
--       authenticated, service_role ; GRANT ciblé
--   [x] catalog_digital_access_v1 ouverte à anon : catalogue public, ne rend
--       que des booléens, des usages et des noms de bibliothèques déjà publics
--       pour les livres visibles de l'appelant (jamais seau, chemin ni URL)
--   [x] DO block de garde final
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- (2) L'administration du réseau compte comme détentrice
-- -------------------------------------------------------------------------
-- Réécriture depuis la définition réelle (pg_get_functiondef, 04/10/2026).
CREATE OR REPLACE FUNCTION public.fn_current_user_is_member_of_holding_library(p_book_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- 20261004215035 : l'administration du réseau lit ce que les bibliothèques
  -- détentrices réservent à leurs membres (décision de Xavier, 04/10/2026).
  select public.fn_caller_is_network_admin()
      or exists (
        select 1
        from public.book_holdings h
        where h.book_id = p_book_id
          and public.fn_current_user_is_member_of(h.library_id)
      );
$function$;

-- -------------------------------------------------------------------------
-- (1) L'accès numérique des livres affichés
-- -------------------------------------------------------------------------
-- Le fichier d'une ressource réservée existe-t-il ? storage.objects manque sur
-- une base reconstruite sans stockage (banc CI) : la requête est dynamique, et
-- sans table on ne peut rien affirmer, on répond vrai (la lecture, elle, passe
-- par read-digital-asset qui échoue proprement si le fichier manque).
CREATE OR REPLACE FUNCTION private.fn_storage_object_exists(p_bucket text, p_path text)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_ok boolean;
BEGIN
  IF p_bucket IS NULL OR p_path IS NULL THEN
    RETURN false;
  END IF;
  IF to_regclass('storage.objects') IS NULL THEN
    RETURN true;
  END IF;
  EXECUTE 'select exists (select 1 from storage.objects where bucket_id = $1 and name = $2)'
     INTO v_ok USING p_bucket, p_path;
  RETURN v_ok;
END;
$$;

REVOKE EXECUTE ON FUNCTION private.fn_storage_object_exists(text, text) FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.catalog_digital_access_v1(p_book_ids bigint[])
RETURNS TABLE (
  book_id              bigint,
  public_usages        text[],
  has_restricted       boolean,
  can_read_restricted  boolean,
  restricted_libraries jsonb
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  with ids as (
    -- Une page du catalogue, pas un export : 500 livres au plus.
    select distinct x as book_id
      from unnest((coalesce(p_book_ids, '{}'::bigint[]))[1:500]) as x
     where x is not null
  ),
  visibles as (
    select i.book_id
      from ids i
     where exists (select 1 from public.book_holdings h
                    where h.book_id = i.book_id
                      and public.fn_library_visible_to_caller(h.library_id))
  ),
  ressources as (
    select r.book_id, r.usage_type, r.access_scope
      from public.book_digital_resources r
      join visibles v on v.book_id = r.book_id
     where r.status = 'active'
       and coalesce(r.is_active, false)
       and (
         (r.access_scope = 'publico' and coalesce(r.bibliographic_match_validated, false))
         or (r.access_scope = 'conta_ativa'
             and (r.storage_path is null
                  or private.fn_storage_object_exists(r.storage_bucket, r.storage_path)))
       )
  ),
  par_livre as (
    select r.book_id,
           coalesce(array_agg(distinct r.usage_type order by r.usage_type)
                      filter (where r.access_scope = 'publico'), '{}'::text[]) as public_usages,
           bool_or(r.access_scope = 'conta_ativa') as has_restricted
      from ressources r
     group by r.book_id
  )
  select p.book_id,
         p.public_usages,
         p.has_restricted,
         p.has_restricted
           and public.fn_current_user_conta_ativa()
           and public.fn_current_user_is_member_of_holding_library(p.book_id) as can_read_restricted,
         case when p.has_restricted then (
           select coalesce(jsonb_agg(jsonb_build_object('slug', l.slug, 'name', l.name) order by l.name), '[]'::jsonb)
             from (select distinct l2.id, l2.slug, l2.name
                     from public.book_holdings h
                     join public.libraries l2 on l2.id = h.library_id
                    where h.book_id = p.book_id
                      and public.fn_library_visible_to_caller(l2.id)) l
         ) end as restricted_libraries
    from par_livre p;
$$;

COMMENT ON FUNCTION public.catalog_digital_access_v1(bigint[]) IS
  'Accès numérique des livres affichés par le catalogue (20261004215035) : usages publics, ressource réservée, droit de lecture de l''appelant, bibliothèques détentrices. Remplace has_online_reading des vues matérialisées, qui ne comptait que les PDF réservés.';

REVOKE EXECUTE ON FUNCTION public.catalog_digital_access_v1(bigint[]) FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.catalog_digital_access_v1(bigint[]) TO anon, authenticated, service_role;

-- -------------------------------------------------------------------------
-- Garde
-- -------------------------------------------------------------------------
DO $garde$
BEGIN
  IF NOT has_function_privilege('anon', 'public.catalog_digital_access_v1(bigint[])', 'EXECUTE') THEN
    RAISE EXCEPTION 'catalog_digital_access_v1 fermée à anon : le catalogue public ne verrait plus rien';
  END IF;
  IF (SELECT prosecdef FROM pg_proc WHERE oid = 'public.fn_current_user_is_member_of_holding_library(bigint)'::regprocedure) IS NOT TRUE THEN
    RAISE EXCEPTION 'fn_current_user_is_member_of_holding_library doit rester SECURITY DEFINER';
  END IF;
END
$garde$;

NOTIFY pgrst, 'reload schema';

COMMIT;
