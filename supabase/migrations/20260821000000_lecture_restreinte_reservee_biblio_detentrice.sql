-- =============================================================================
-- Lecture en ligne restreinte : reservee aux membres de la bibliotheque detentrice
-- =============================================================================
-- Date     : 2026-08-21
-- Chantier : ressources numeriques / droits de lecture
--
-- CE QUI CHANGE. Un PDF `access_scope = 'conta_ativa'` etait lisible par
-- N'IMPORTE QUEL compte actif du reseau. Il l'est desormais par les seuls
-- membres actifs d'une bibliotheque QUI DETIENT le livre.
--
-- POURQUOI. Un fonds numerise appartient a la bibliotheque qui l'a numerise et
-- qui repond de ses droits. « Restreint » devait vouloir dire « reserve a ses
-- lecteurs », pas « reserve aux personnes ayant un compte quelque part dans le
-- reseau » — ce qui, a l'echelle du reseau, ne restreint presque rien.
--
-- ⚠️ LE NOM DE LA VALEUR MENT DESORMAIS. `conta_ativa` se lit « compte actif »,
-- alors que la regle exige en plus l'appartenance. On garde la valeur (une
-- seule ressource restreinte existe au catalogue, et renommer entrainerait la
-- contrainte CHECK, le formulaire de catalogage et dix locales). A renommer
-- quand le vocabulaire des `access_scope` sera repris — meme famille que le
-- doublon `rights_status` signale au PLAN_DE_MARCHE §8.
--
-- CE QUI NE CHANGE PAS. Les ressources `publico` restent publiques ; la
-- condition de visibilite de la bibliotheque detentrice
-- (fn_library_visible_to_caller) reste appliquee ; et `fn_current_user_conta_ativa`
-- reste exigee EN PLUS (un compte restreint ou dont le mot de passe n'est pas
-- pose ne lit rien, meme membre).
--
-- CORRIGE AU PASSAGE un defaut qui rendait la regle inoperante : la page livre
-- lisait `has_access` / `bucket_name` / `object_path` sur
-- fn_book_restricted_pdf_state_for_current_user, qui ne renvoie AUCUN de ces
-- trois champs. La branche restreinte ne se declenchait donc JAMAIS, pour aucun
-- livre. La fonction expose maintenant `asset_id` : le frontend passe par
-- l'edge function `read-digital-asset`, qui re-verifie l'autorisation et signe
-- l'URL. Le seau et le chemin ne descendent plus jamais au navigateur.
-- =============================================================================

begin;

-- ── 1. Le predicat : membre actif d'une bibliotheque detentrice ─────────────
-- SECURITY DEFINER comme ses voisines (fn_current_user_is_member_of) : la
-- lecture de book_holdings ne doit pas dependre des policies de l'appelant.
create or replace function public.fn_current_user_is_member_of_holding_library(p_book_id bigint)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  select exists (
    select 1
    from public.book_holdings h
    where h.book_id = p_book_id
      and public.fn_current_user_is_member_of(h.library_id)
  );
$function$;

comment on function public.fn_current_user_is_member_of_holding_library(bigint) is
  'Vrai si l''appelant est membre ACTIF d''au moins une bibliotheque detenant ce livre. Porte la regle de lecture des ressources numeriques restreintes.';

revoke all on function public.fn_current_user_is_member_of_holding_library(bigint) from public;
grant execute on function public.fn_current_user_is_member_of_holding_library(bigint) to authenticated, service_role;

-- ── 2. La porte reelle : lue par l'edge function read-digital-asset ─────────
-- Signature inchangee -> create or replace suffit, les grants sont conserves.
create or replace function public.get_accessible_digital_asset_by_id_v2(p_asset_id bigint)
returns table(asset_id bigint, book_id bigint, resource_type text, usage_type text, access_scope text, mime_type text, storage_bucket text, storage_path text, language_code text, source_name text, source_url text, attribution_text text, rights_status text, label text, is_primary boolean, requires_active_account boolean, access_granted boolean)
language sql
stable
security definer
set search_path to 'public'
as $function$
  SELECT
    r.id AS asset_id,
    r.book_id,
    r.resource_type,
    r.usage_type,
    r.access_scope,
    r.mime_type,
    r.storage_bucket,
    r.storage_path,
    r.language_code,
    r.source_name,
    r.source_url,
    r.attribution_text,
    r.rights_status,
    r.label,
    r.is_primary,
    (r.access_scope = 'conta_ativa') AS requires_active_account,
    CASE
      WHEN r.access_scope = 'publico' THEN true
      WHEN r.access_scope = 'conta_ativa'
        THEN public.fn_current_user_conta_ativa()
         AND public.fn_current_user_is_member_of_holding_library(r.book_id)
      ELSE false
    END AS access_granted
  FROM public.book_digital_resources r
  WHERE r.id = p_asset_id
    AND r.status = 'active'
    AND COALESCE(r.is_active, false) = true
    AND (
      r.access_scope = 'publico'
      OR (
        r.access_scope = 'conta_ativa'
        AND public.fn_current_user_conta_ativa()
        AND public.fn_current_user_is_member_of_holding_library(r.book_id)
      )
    )
    AND EXISTS (
      SELECT 1
      FROM public.book_holdings h
      WHERE h.book_id = r.book_id
        AND public.fn_library_visible_to_caller(h.library_id)
    )
  LIMIT 1;
$function$;

-- ── 3. L'etat affiche par la page livre ────────────────────────────────────
-- La signature change (ajout de asset_id et user_is_member_of_holder) : il faut
-- DROP puis CREATE, `create or replace` ne sait pas modifier les colonnes de
-- sortie. On rend les grants a l'identique juste apres.
drop function if exists public.fn_book_restricted_pdf_state_for_current_user(text);
drop function if exists public.fn_book_restricted_pdf_state(text);

create function public.fn_book_restricted_pdf_state(p_bib_ref text)
returns table(
  bib_ref text,
  book_id bigint,
  asset_id bigint,
  book_exists boolean,
  has_reading_resource boolean,
  resource_status text,
  file_exists boolean,
  user_account_active boolean,
  user_is_member_of_holder boolean,
  can_show_read_button boolean
)
language plpgsql
stable
security definer
set search_path to 'public', 'auth', 'storage', 'pg_temp'
as $function$
declare
  v_book_id bigint := null;
  v_book_ref text := null;

  v_user_active boolean := false;
  v_is_member boolean := false;

  v_has_resource boolean := false;
  v_resource_id bigint := null;
  v_resource_status text := null;
  v_resource_is_active boolean := false;
  v_resource_access_scope text := '';
  v_storage_bucket text := null;
  v_storage_path text := null;

  v_file_exists boolean := false;
begin
  /* 1) Resolution canonique par la surface publique v2. */
  select
    coalesce(v.book_id, v.id)::bigint,
    v.bib_ref::text
  into
    v_book_id,
    v_book_ref
  from public.v_book_detail_public_v2 v
  where trim(coalesce(v.bib_ref, '')) = trim(coalesce(p_bib_ref, ''))
  limit 1;

  /* 2) Repli compat par local_bib_ref, seulement si la reference locale
        designe UN seul book_id (sinon faux positif multi-bibliotheque). */
  if v_book_id is null then
    with matched_holdings as (
      select h.book_id
      from public.book_holdings h
      where trim(coalesce(h.local_bib_ref, '')) = trim(coalesce(p_bib_ref, ''))
      group by h.book_id
    )
    select
      b.id::bigint,
      b.bib_ref::text
    into
      v_book_id,
      v_book_ref
    from matched_holdings mh
    join public.books b
      on b.id = mh.book_id
    where (select count(*) from matched_holdings) = 1
    limit 1;
  end if;

  v_user_active := public.fn_current_user_conta_ativa();

  if v_book_id is not null then
    v_is_member := public.fn_current_user_is_member_of_holding_library(v_book_id);

    select
      r.id,
      r.status::text,
      coalesce(r.is_active, false),
      coalesce(r.access_scope, ''),
      r.storage_bucket,
      r.storage_path
    into
      v_resource_id,
      v_resource_status,
      v_resource_is_active,
      v_resource_access_scope,
      v_storage_bucket,
      v_storage_path
    from public.book_digital_resources r
    where r.book_id::bigint = v_book_id
      and r.resource_type = 'pdf_restrito'
      and r.usage_type = 'leitura_online'
      and r.access_scope = 'conta_ativa'
    order by
      case
        when r.status = 'active' and coalesce(r.is_active, false) = true then 0
        else 1
      end,
      coalesce(r.updated_at, r.created_at) desc,
      r.id desc
    limit 1;

    if v_resource_id is not null then
      v_has_resource := true;

      if v_storage_bucket is not null
         and v_storage_path is not null then
        select exists (
          select 1
          from storage.objects so
          where so.bucket_id = v_storage_bucket
            and so.name = v_storage_path
        )
        into v_file_exists;
      end if;
    end if;
  end if;

  bib_ref := trim(coalesce(v_book_ref, p_bib_ref));
  book_id := v_book_id;
  -- asset_id n'est renvoye QUE si la lecture est autorisee : il sert a appeler
  -- read-digital-asset, jamais a designer une ressource qu'on n'a pas le droit
  -- de lire. Le seau et le chemin ne sortent pas d'ici (ils descendaient au
  -- navigateur dans l'intention d'origine ; l'edge function signe l'URL).
  book_exists := (v_book_id is not null);
  has_reading_resource := v_has_resource;
  resource_status := v_resource_status;
  file_exists := coalesce(v_file_exists, false);
  user_account_active := coalesce(v_user_active, false);
  user_is_member_of_holder := coalesce(v_is_member, false);
  can_show_read_button := (
    book_exists
    and has_reading_resource
    and resource_status = 'active'
    and v_resource_is_active = true
    and v_resource_access_scope = 'conta_ativa'
    and file_exists
    and user_account_active
    and user_is_member_of_holder
  );
  asset_id := case when can_show_read_button then v_resource_id else null end;

  return next;
end;
$function$;

comment on function public.fn_book_restricted_pdf_state(text) is
  'Etat de lecture d''un PDF restreint pour l''appelant. `can_show_read_button` exige un compte actif ET l''appartenance a une bibliotheque detentrice. `asset_id` n''est renseigne que si la lecture est autorisee.';

create function public.fn_book_restricted_pdf_state_for_current_user(p_bib_ref text)
returns table(
  bib_ref text,
  book_id bigint,
  asset_id bigint,
  book_exists boolean,
  has_reading_resource boolean,
  resource_status text,
  file_exists boolean,
  user_account_active boolean,
  user_is_member_of_holder boolean,
  can_show_read_button boolean
)
language sql
stable
security definer
set search_path to 'public', 'auth', 'storage', 'pg_temp'
as $function$
  select * from public.fn_book_restricted_pdf_state(p_bib_ref);
$function$;

-- Grants rendus a l'identique de l'etat d'avant le DROP (releves le 20/08) :
-- la fonction interne n'est PAS exposee a `authenticated`, seul le wrapper l'est.
revoke all on function public.fn_book_restricted_pdf_state(text) from public;
grant execute on function public.fn_book_restricted_pdf_state(text) to service_role;

revoke all on function public.fn_book_restricted_pdf_state_for_current_user(text) from public;
grant execute on function public.fn_book_restricted_pdf_state_for_current_user(text) to authenticated, service_role;

commit;
