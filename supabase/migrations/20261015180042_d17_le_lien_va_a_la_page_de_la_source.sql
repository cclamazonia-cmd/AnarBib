-- =========================================================================
-- D17 — Qui lit la copie restreinte voit le lien vers la PAGE de la source,
-- jamais vers le fichier
-- =========================================================================
-- Date     : 2026-10-15
-- Chantier : PDF sous droits déjà diffusés en ligne (REGISTRE §47, NUMDIF-3)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : D17 lien vers la page source
-- Ref      : docs/journal/cadrages/CADRAGE_pdf-sous-droits-diffuses_2026-10-15.md §4
--            20261006175037 (définitions précédentes de la publication et de
--            la reprise) ; 20261004215035 (définition précédente de
--            get_accessible_digital_asset_by_id_v2)
-- Suite    : tests/sql/d17_page_de_la_source_tests.sql
--
-- LE CONSTAT (15/10/2026).
--   Les sept ressources restreintes actives ont toutes une URL source ; cinq
--   désignent un fichier en téléchargement direct (/wp-content/uploads/…pdf,
--   /qdownload/…, /assets/…, un fichier dn….archive.org). La fonction Edge
--   read-digital-asset masque source_url pour toute ressource restreinte
--   servie depuis le stockage (incident de la ressource 61, 20/08) ; mais la
--   RPC qu'elle appelle, get_accessible_digital_asset_by_id_v2, est exposée à
--   PostgREST et rendait source_url à tout membre de la bibliothèque
--   détentrice : le masquage ne tenait que dans la fonction Edge.
--
-- LA DÉCISION (NUMDIF-3, option (b) du cadrage, Xavier, 15/10).
--   On enregistre deux adresses : le fichier (source_url, provenance, jamais
--   exposée pour une ressource restreinte) et la page qui le présente
--   (source_page_url : fiche archive.org/details/…, article, page du site).
--   Qui peut lire la copie voit la page ; le choix se fait côté serveur.
--
-- LE GESTE.
--   (1) source_page_url sur book_digital_resources et sa jumelle brouillon,
--       avec la même garde ^https?:// que source_url au brouillon.
--   (2) La reprise et la publication font suivre la colonne. Sans (2), une
--       publication effacerait la page du publié (elle recopie le brouillon).
--   (3) get_accessible_digital_asset_by_id_v2 rend source_page_url, et ne rend
--       plus source_url d'une ressource restreinte servie depuis le stockage.
--       Une ressource restreinte SANS fichier stocké garde son source_url : c'est
--       son chemin de lecture (accès « external_url »), pas une provenance.
--       Le type de retour change : DROP puis CREATE, droits reposés à
--       l'identique (anon, authenticated — portier du lectorat, cf.
--       documents_numeriques_tests T3 et grants_herites_tests).
--   (4) Les ressources Archive.org existantes reçoivent leur page, déduite de
--       l'URL du fichier : https://archive.org/details/<identifiant>. Les
--       autres pages se saisissent à la validation (classement D18, préparé à
--       part, non appliqué ici).
--
-- CHECKLIST DOCTRINE
--   [x] Fonctions SECURITY DEFINER : SET search_path, REVOKE EXECUTE … FROM
--       PUBLIC, anon, authenticated (publication et reprise : aucun GRANT,
--       appelées par publish_book_draft / create_book_draft_from_book /
--       ingest.fn_h21_copie_de_la_notice) ; la RPC de lecture regagne
--       anon et authenticated (exception assumée : c'est la porte publique).
--   [x] Pas de table neuve ; droits par table inchangés (une colonne neuve
--       hérite des GRANT de table). RLS inchangée.
--   [x] DO block de garde final
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- (1) La colonne, au publié et au brouillon
-- -------------------------------------------------------------------------
ALTER TABLE public.book_digital_resources
  ADD COLUMN IF NOT EXISTS source_page_url text;
ALTER TABLE public.book_digital_resources
  ADD CONSTRAINT book_digital_resources_source_page_url_chk
  CHECK (source_page_url IS NULL OR source_page_url ~* '^https?://');
COMMENT ON COLUMN public.book_digital_resources.source_page_url IS
  'NUMDIF-3 (15/10/2026) : la PAGE qui présente la copie trouvée ailleurs (fiche archive.org/details/…, article, page du site), à distinguer de source_url, l''adresse du FICHIER (provenance). Seule la page est montrée à qui peut lire une ressource restreinte ; source_url d''une ressource restreinte servie depuis le stockage n''est jamais rendue (get_accessible_digital_asset_by_id_v2, read-digital-asset).';

ALTER TABLE public.book_draft_digital_resources
  ADD COLUMN IF NOT EXISTS source_page_url text;
ALTER TABLE public.book_draft_digital_resources
  ADD CONSTRAINT book_draft_digital_resources_source_page_url_chk
  CHECK (source_page_url IS NULL OR source_page_url ~* '^https?://');
COMMENT ON COLUMN public.book_draft_digital_resources.source_page_url IS
  'NUMDIF-3 (15/10/2026) : la page qui présente la copie trouvée ailleurs ; recopiée vers book_digital_resources.source_page_url à la publication.';

-- -------------------------------------------------------------------------
-- (2) La reprise et la publication font suivre la colonne.
-- Réécritures depuis pg_get_functiondef (prod, 15/10) ; seule change la
-- présence de source_page_url à côté de source_url.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.copy_book_digital_resources_to_draft(p_book_id bigint, p_book_draft_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  delete from public.book_draft_digital_resources
  where book_draft_id = p_book_draft_id;

  -- D9 : la reprise repart de ce que la notice porte, rien n'y est « retiré »
  update public.book_drafts
     set digital_resources_removed = '{}'
   where id = p_book_draft_id
     and digital_resources_removed <> '{}';

  insert into public.book_draft_digital_resources (
    book_draft_id, published_resource_id,
    resource_type, usage_type, access_scope, status, is_active,
    storage_bucket, storage_path, mime_type, language_code,
    source_name, source_url, source_page_url, attribution_text, rights_status, rights_justification,
    is_primary, bibliographic_match_validated, label, notes, metadata,
    activated_at, retired_at
  )
  select
    p_book_draft_id, r.id,
    r.resource_type, r.usage_type, r.access_scope,
    case when r.status = 'active' then 'draft' else r.status end,
    r.is_active,
    r.storage_bucket, r.storage_path, r.mime_type, r.language_code,
    r.source_name, r.source_url, r.source_page_url, r.attribution_text, r.rights_status, r.rights_justification,
    r.is_primary, r.bibliographic_match_validated, r.label, r.notes, r.metadata,
    r.activated_at, r.retired_at
  from public.book_digital_resources r
  where r.book_id = p_book_id;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.copy_book_digital_resources_to_draft(bigint, bigint) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.publish_book_draft_digital_resources(p_book_draft_id bigint, p_book_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  d record;
  v_id bigint;
  v_garder bigint[] := '{}';
begin
  -- Le publié reflète l'état actif du brouillon. Une ressource déjà publiée
  -- est MISE À JOUR (même id : les liens /ler/…?asset_id= restent valables ;
  -- l'empreinte audio et les colonnes propres au publié sont conservées).
  for d in
    select *
      from public.book_draft_digital_resources
     where book_draft_id = p_book_draft_id
       and coalesce(is_active, true) = true
       and coalesce(status, 'draft') <> 'retired'
     order by id
  loop
    v_id := null;
    if d.published_resource_id is not null then
      update public.book_digital_resources r set
        resource_type = d.resource_type,
        usage_type = d.usage_type,
        access_scope = d.access_scope,
        status = case when d.status in ('draft', 'active') then 'active' else d.status end,
        is_active = coalesce(d.is_active, true),
        storage_bucket = d.storage_bucket,
        storage_path = d.storage_path,
        mime_type = d.mime_type,
        label = d.label,
        notes = d.notes,
        metadata = d.metadata,
        activated_at = coalesce(r.activated_at, d.activated_at, now()),
        retired_at = d.retired_at,
        language_code = d.language_code,
        source_name = d.source_name,
        source_url = d.source_url,
        source_page_url = d.source_page_url,
        attribution_text = d.attribution_text,
        rights_status = d.rights_status,
        rights_justification = d.rights_justification,
        is_primary = coalesce(d.is_primary, false),
        bibliographic_match_validated = coalesce(d.bibliographic_match_validated, false),
        updated_at = now()
       where r.id = d.published_resource_id
         and r.book_id = p_book_id
      returning r.id into v_id;
    end if;

    if v_id is null then
      insert into public.book_digital_resources (
        book_id, resource_type, usage_type, access_scope, status, is_active,
        storage_bucket, storage_path, mime_type, label, notes, metadata,
        activated_at, retired_at, language_code, source_name, source_url, source_page_url,
        attribution_text, rights_status, rights_justification, is_primary,
        bibliographic_match_validated, created_at, updated_at
      ) values (
        p_book_id, d.resource_type, d.usage_type, d.access_scope,
        case when d.status in ('draft', 'active') then 'active' else d.status end,
        coalesce(d.is_active, true),
        d.storage_bucket, d.storage_path, d.mime_type, d.label, d.notes, d.metadata,
        coalesce(d.activated_at, now()), d.retired_at, d.language_code, d.source_name, d.source_url, d.source_page_url,
        d.attribution_text, d.rights_status, d.rights_justification, coalesce(d.is_primary, false),
        coalesce(d.bibliographic_match_validated, false), now(), now()
      ) returning id into v_id;
      update public.book_draft_digital_resources
         set published_resource_id = v_id
       where id = d.id;
    end if;
    v_garder := v_garder || v_id;
  end loop;

  -- D9 (06/10/2026, décision de Xavier) : ne quitte le publié que ce que le
  -- brouillon dit de retirer — une ressource qu'il a supprimée
  -- (book_drafts.digital_resources_removed) ou qu'il porte retirée ou
  -- inactive. Une ressource publiée qu'il ignore (posée par la réception
  -- d'un fonds après sa création, ou brouillon créé sans reprise) reste.
  delete from public.book_digital_resources r
   where r.book_id = p_book_id
     and not (r.id = any (v_garder))
     and (r.id = any (coalesce((select bd.digital_resources_removed
                                  from public.book_drafts bd
                                 where bd.id = p_book_draft_id), '{}'))
          or exists (select 1 from public.book_draft_digital_resources dd
                      where dd.book_draft_id = p_book_draft_id
                        and dd.published_resource_id = r.id));
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.publish_book_draft_digital_resources(bigint, bigint) FROM PUBLIC, anon, authenticated;

-- -------------------------------------------------------------------------
-- (3) La porte de lecture rend la page, jamais le fichier d'une restreinte
-- -------------------------------------------------------------------------
-- Le portier ne change pas : mêmes conditions (compte actif ET membre d'une
-- bibliothèque détentrice pour conta_ativa ; bibliothèque visible). Seules
-- changent les adresses rendues.
DROP FUNCTION IF EXISTS public.get_accessible_digital_asset_by_id_v2(bigint);

CREATE FUNCTION public.get_accessible_digital_asset_by_id_v2(p_asset_id bigint)
 RETURNS TABLE(asset_id bigint, book_id bigint, resource_type text, usage_type text, access_scope text, mime_type text, storage_bucket text, storage_path text, language_code text, source_name text, source_url text, attribution_text text, rights_status text, label text, is_primary boolean, requires_active_account boolean, access_granted boolean, source_page_url text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_catalog
AS $function$
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
    -- NUMDIF-3 : l'adresse du FICHIER d'une ressource restreinte servie depuis
    -- le stockage ne sort jamais (la copie se lit par URL signée, révocable et
    -- attribuée). Une ressource sans fichier stocké garde la sienne : c'est
    -- son chemin de lecture.
    CASE
      WHEN r.access_scope = 'publico' OR r.storage_path IS NULL THEN r.source_url
    END AS source_url,
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
    END AS access_granted,
    r.source_page_url
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

REVOKE EXECUTE ON FUNCTION public.get_accessible_digital_asset_by_id_v2(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_accessible_digital_asset_by_id_v2(bigint) TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.get_accessible_digital_asset_by_id_v2(bigint) IS
  'Portier du lectorat numérique : rend la ressource si elle est publique, ou réservée et lue par un compte actif membre d''une bibliothèque détentrice (ou l''administration du réseau). NUMDIF-3 (15/10/2026) : rend source_page_url ; ne rend jamais source_url d''une ressource restreinte servie depuis le stockage.';

-- -------------------------------------------------------------------------
-- (4) Les ressources Archive.org existantes reçoivent leur page
-- -------------------------------------------------------------------------
-- archive.org/details/<id>, archive.org/download/<id>/…, <nœud>.archive.org/<n>/items/<id>/…
-- → https://archive.org/details/<id>. Un identifiant Archive.org s'écrit en
-- [A-Za-z0-9._-]. On ne touche qu'aux lignes sans page.
UPDATE public.book_digital_resources
   SET source_page_url = 'https://archive.org/details/'
       || substring(source_url FROM '^https?://(?:[A-Za-z0-9-]+\.)*archive\.org/(?:details|download|[0-9]+/items)/([A-Za-z0-9._-]+)')
 WHERE source_page_url IS NULL
   AND source_url ~* '^https?://(?:[A-Za-z0-9-]+\.)*archive\.org/(?:details|download|[0-9]+/items)/[A-Za-z0-9._-]+';

-- Au brouillon aussi : sinon la prochaine publication effacerait la page du
-- publié. Ce n'est pas un geste de catalogage : la reprise ne doit pas en être
-- marquée « touchée » (tg_book_draft_child_touches_retake lit ce réglage, posé
-- d'ordinaire par l'oubli d'une reprise ; rétabli juste après).
SELECT set_config('anarbib.retake_oubli', 'on', true);
UPDATE public.book_draft_digital_resources
   SET source_page_url = 'https://archive.org/details/'
       || substring(source_url FROM '^https?://(?:[A-Za-z0-9-]+\.)*archive\.org/(?:details|download|[0-9]+/items)/([A-Za-z0-9._-]+)')
 WHERE source_page_url IS NULL
   AND source_url ~* '^https?://(?:[A-Za-z0-9-]+\.)*archive\.org/(?:details|download|[0-9]+/items)/[A-Za-z0-9._-]+';
SELECT set_config('anarbib.retake_oubli', '', true);

-- -------------------------------------------------------------------------
-- Garde
-- -------------------------------------------------------------------------
DO $$
DECLARE v_n int;
BEGIN
  IF NOT has_function_privilege('anon', 'public.get_accessible_digital_asset_by_id_v2(bigint)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.get_accessible_digital_asset_by_id_v2(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou D17 : get_accessible_digital_asset_by_id_v2 doit rester ouverte à anon et authenticated (read-digital-asset)';
  END IF;
  IF has_function_privilege('authenticated', 'public.publish_book_draft_digital_resources(bigint,bigint)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.copy_book_digital_resources_to_draft(bigint,bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou D17 : publication et reprise des ressources restent fermées aux rôles de session';
  END IF;
  SELECT count(*) INTO v_n
    FROM public.book_digital_resources
   WHERE source_url ~* '^https?://(?:[A-Za-z0-9-]+\.)*archive\.org/(?:details|download|[0-9]+/items)/'
     AND source_page_url IS NULL;
  IF v_n > 0 THEN
    RAISE EXCEPTION 'Garde-fou D17 : % ressource(s) Archive.org sans page', v_n;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé : supabase/migrations/_rollback_20261015180042_d17_le_lien_va_a_la_page_de_la_source.sql
-- =========================================================================
