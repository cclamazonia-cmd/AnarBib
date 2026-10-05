-- =========================================================================
-- Le dépôt numérique part des droits : la bibliothèque décide, la base garde
-- la cohérence, la publication garde les liens
-- =========================================================================
-- Date     : 2026-10-05
-- Chantier : ressources numériques (étape 4 : refonte du dépôt)
-- Auteur   : Claude (Opus 5.5), pour Xavier
-- Session  : Retours du catalogage & numérique
--
-- Décisions de Xavier (04/10/2026) : le formulaire de dépôt part du statut des
-- droits, puis du choix de la bibliothèque quant à l'accès ; l'espace de
-- stockage en découle. Une œuvre sous droits peut être mise en lecture publique
-- si — et seulement si — sa bibliothèque l'a choisi (« réglage de
-- bibliothèque »), avec un avertissement sur la responsabilité légale.
--
-- (1) libraries.digital_public_under_rights : le réglage. Il engage la
--     bibliothèque : seule sa coordination (ou l'administration du réseau) le
--     change — garde par trigger, la policy libraries_staff_update laissant
--     tout le staff écrire la ligne.
-- (2) Cohérence d'une ressource de brouillon, écrite depuis l'écran
--     (current_user = authenticated ; les copies système — reprise, réception
--     d'un fonds — passent par des fonctions SECURITY DEFINER et ne sont pas
--     rejugées) :
--       - l'espace de stockage suit l'accès : public ↔ anarbib-*-public,
--         réservé ↔ pdf-restrito / anarbib-*-restricted ;
--       - sous droits + public : le réglage de la bibliothèque du brouillon,
--         et une justification ;
--       - cession par l'auteur·rice, licence libre : une justification
--         (l'autorisation écrite, la licence).
--     Ne se rejuge qu'à l'insertion ou quand droits, accès ou espace changent :
--     une ressource ancienne s'édite sans être bloquée par ce qu'elle était.
-- (3) Publication sans recréation : publish_book_draft_digital_resources
--     supprimait puis réinsérait toutes les ressources publiées — les liens
--     de lecture (/ler/…?asset_id=) changeaient à chaque publication, et la
--     justification des droits comme l'empreinte audio (chromaprint/acoustid,
--     propres au publié) étaient perdues. Le brouillon garde désormais
--     published_resource_id ; la publication met à jour, insère le nouveau,
--     retire ce que le brouillon n'a plus. copy_book_digital_resources_to_draft
--     pose ce lien et recopie la justification.
-- (4) EPUB : les seaux anarbib-epub-* existaient sans chemin d'écran ; le
--     brouillon accepte resource_type = 'epub' (le publié l'acceptait déjà).
--     Vidéo et image : les seaux média n'acceptaient que l'audio.
--
-- CHECKLIST DOCTRINE
--   [x] Fonctions trigger en SECURITY INVOKER (la garde lit current_user),
--       SET search_path, REVOKE FROM PUBLIC, anon, authenticated, service_role
--       (aucun GRANT : le privilège n'est vérifié qu'à la création du trigger)
--   [x] Réécritures depuis les définitions réelles (pg_get_functiondef, 05/10)
--   [x] DO block de garde final
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- (1) Le réglage de bibliothèque
-- -------------------------------------------------------------------------
ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS digital_public_under_rights boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.libraries.digital_public_under_rights IS
  'La bibliothèque accepte de mettre en lecture publique des œuvres sous droits (par ex. trouvables en ligne), sous sa responsabilité. Décidé par sa coordination (20261005092916).';

-- SECURITY INVOKER, et c'est voulu : current_user doit rester celui de
-- l'appel (« authenticated » depuis l'écran) ; en DEFINER il vaudrait toujours
-- le propriétaire, et la garde ne mordrait jamais (constaté au banc, 05/10).
CREATE OR REPLACE FUNCTION public.tg_libraries_digital_policy_coord_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog, pg_temp
AS $$
BEGIN
  IF NEW.digital_public_under_rights IS DISTINCT FROM OLD.digital_public_under_rights
     AND current_user IN ('authenticated', 'anon')
     AND NOT (public.fn_caller_is_network_admin()
              OR NEW.id = ANY (public.fn_caller_coordinator_library_ids())) THEN
    RAISE EXCEPTION 'Réglage réservé à la coordination de la bibliothèque.'
      USING errcode = '42501', hint = 'error.library.digital_policy_coord_only';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.tg_libraries_digital_policy_coord_only() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_libraries_digital_policy_coord_only ON public.libraries;
CREATE TRIGGER trg_libraries_digital_policy_coord_only
  BEFORE UPDATE OF digital_public_under_rights ON public.libraries
  FOR EACH ROW EXECUTE FUNCTION public.tg_libraries_digital_policy_coord_only();

-- -------------------------------------------------------------------------
-- (4) EPUB côté brouillon
-- -------------------------------------------------------------------------
ALTER TABLE public.book_draft_digital_resources DROP CONSTRAINT IF EXISTS book_draft_digital_resources_resource_type_chk;
ALTER TABLE public.book_draft_digital_resources ADD CONSTRAINT book_draft_digital_resources_resource_type_chk
  CHECK (resource_type = ANY (ARRAY['pdf_publico','pdf_restrito','audio','video','image','link_externo','recurso_digital','epub']));

-- -------------------------------------------------------------------------
-- (2) Cohérence droits / accès / espace
-- -------------------------------------------------------------------------
-- SECURITY INVOKER pour la même raison : depuis une fonction DEFINER (reprise,
-- réception d'un fonds), current_user est son propriétaire et la copie passe.
CREATE OR REPLACE FUNCTION public.tg_draft_digital_resource_coherence()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog, pg_temp
AS $$
DECLARE
  v_public_buckets     constant text[] := ARRAY['anarbib-pdf-public', 'anarbib-media-public', 'anarbib-epub-public'];
  v_restricted_buckets constant text[] := ARRAY['pdf-restrito', 'anarbib-media-restricted', 'anarbib-epub-restricted'];
  v_permis boolean;
BEGIN
  -- Les copies système (reprise, réception d'un fonds) ne sont pas rejugées.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  -- Une ressource ancienne s'édite sans être bloquée par ce qu'elle était.
  IF TG_OP = 'UPDATE'
     AND NEW.rights_status IS NOT DISTINCT FROM OLD.rights_status
     AND NEW.access_scope IS NOT DISTINCT FROM OLD.access_scope
     AND NEW.storage_bucket IS NOT DISTINCT FROM OLD.storage_bucket
     AND NEW.rights_justification IS NOT DISTINCT FROM OLD.rights_justification THEN
    RETURN NEW;
  END IF;

  IF NEW.storage_bucket IS NOT NULL THEN
    IF NEW.access_scope = 'publico' AND NOT NEW.storage_bucket = ANY (v_public_buckets) THEN
      RAISE EXCEPTION 'Un document public se range dans un espace public.' USING hint = 'error.digital.bucket_scope';
    END IF;
    IF NEW.access_scope = 'conta_ativa' AND NOT NEW.storage_bucket = ANY (v_restricted_buckets) THEN
      RAISE EXCEPTION 'Un document réservé se range dans un espace réservé.' USING hint = 'error.digital.bucket_scope';
    END IF;
  END IF;

  IF NEW.rights_status IN ('cessao_autoral', 'licenca_livre', 'sob_direitos')
     AND (NEW.rights_status <> 'sob_direitos' OR NEW.access_scope = 'publico')
     AND btrim(coalesce(NEW.rights_justification, '')) = '' THEN
    RAISE EXCEPTION 'Justification des droits manquante.' USING hint = 'error.digital.justification_required';
  END IF;

  IF NEW.rights_status = 'sob_direitos' AND NEW.access_scope = 'publico' THEN
    SELECT coalesce(l.digital_public_under_rights, false) INTO v_permis
      FROM public.book_drafts d
      LEFT JOIN public.libraries l ON l.id = d.owner_library_id
     WHERE d.id = NEW.book_draft_id;
    IF NOT coalesce(v_permis, false) THEN
      RAISE EXCEPTION 'La bibliothèque n''a pas ouvert la lecture publique d''œuvres sous droits.'
        USING hint = 'error.digital.public_under_rights_not_allowed';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.tg_draft_digital_resource_coherence() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_draft_digital_resource_coherence ON public.book_draft_digital_resources;
CREATE TRIGGER trg_draft_digital_resource_coherence
  BEFORE INSERT OR UPDATE ON public.book_draft_digital_resources
  FOR EACH ROW EXECUTE FUNCTION public.tg_draft_digital_resource_coherence();

-- -------------------------------------------------------------------------
-- (3) Publication sans recréation
-- -------------------------------------------------------------------------
ALTER TABLE public.book_draft_digital_resources
  ADD COLUMN IF NOT EXISTS published_resource_id bigint;
COMMENT ON COLUMN public.book_draft_digital_resources.published_resource_id IS
  'Ressource publiée que ce brouillon met à jour (20261005092916) : la publication la modifie au lieu de la recréer, l''asset_id des liens de lecture reste stable.';
CREATE INDEX IF NOT EXISTS ix_book_draft_digital_resources_published_resource_id
  ON public.book_draft_digital_resources (published_resource_id);

-- Réécriture depuis la définition réelle (05/10/2026) : pose le lien, recopie la justification.
CREATE OR REPLACE FUNCTION public.copy_book_digital_resources_to_draft(p_book_id bigint, p_book_draft_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  delete from public.book_draft_digital_resources
  where book_draft_id = p_book_draft_id;

  insert into public.book_draft_digital_resources (
    book_draft_id, published_resource_id,
    resource_type, usage_type, access_scope, status, is_active,
    storage_bucket, storage_path, mime_type, language_code,
    source_name, source_url, attribution_text, rights_status, rights_justification,
    is_primary, bibliographic_match_validated, label, notes, metadata,
    activated_at, retired_at
  )
  select
    p_book_draft_id, r.id,
    r.resource_type, r.usage_type, r.access_scope,
    case when r.status = 'active' then 'draft' else r.status end,
    r.is_active,
    r.storage_bucket, r.storage_path, r.mime_type, r.language_code,
    r.source_name, r.source_url, r.attribution_text, r.rights_status, r.rights_justification,
    r.is_primary, r.bibliographic_match_validated, r.label, r.notes, r.metadata,
    r.activated_at, r.retired_at
  from public.book_digital_resources r
  where r.book_id = p_book_id;
end;
$function$;

-- Réécriture depuis la définition réelle (05/10/2026) : met à jour, insère, retire.
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
        activated_at, retired_at, language_code, source_name, source_url,
        attribution_text, rights_status, rights_justification, is_primary,
        bibliographic_match_validated, created_at, updated_at
      ) values (
        p_book_id, d.resource_type, d.usage_type, d.access_scope,
        case when d.status in ('draft', 'active') then 'active' else d.status end,
        coalesce(d.is_active, true),
        d.storage_bucket, d.storage_path, d.mime_type, d.label, d.notes, d.metadata,
        coalesce(d.activated_at, now()), d.retired_at, d.language_code, d.source_name, d.source_url,
        d.attribution_text, d.rights_status, d.rights_justification, coalesce(d.is_primary, false),
        coalesce(d.bibliographic_match_validated, false), now(), now()
      ) returning id into v_id;
      update public.book_draft_digital_resources
         set published_resource_id = v_id
       where id = d.id;
    end if;
    v_garder := v_garder || v_id;
  end loop;

  -- Ce que le brouillon n'a plus quitte le publié.
  delete from public.book_digital_resources
   where book_id = p_book_id
     and not (id = any (v_garder));
end;
$function$;

-- -------------------------------------------------------------------------
-- (4) Vidéo et image dans les seaux média (ils n'acceptaient que l'audio)
-- -------------------------------------------------------------------------
DO $seaux$
BEGIN
  IF to_regclass('storage.buckets') IS NOT NULL THEN
    UPDATE storage.buckets
       SET allowed_mime_types = ARRAY['audio/mpeg','audio/ogg','audio/flac','audio/wav',
                                      'video/mp4','video/webm','video/ogg',
                                      'image/jpeg','image/png','image/webp','image/tiff']
     WHERE id IN ('anarbib-media-public', 'anarbib-media-restricted');
  END IF;
END
$seaux$;

-- -------------------------------------------------------------------------
-- Garde
-- -------------------------------------------------------------------------
DO $garde$
BEGIN
  IF has_function_privilege('authenticated', 'public.tg_draft_digital_resource_coherence()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.tg_libraries_digital_policy_coord_only()', 'EXECUTE') THEN
    RAISE EXCEPTION 'fonctions trigger ouvertes au front';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgname IN ('trg_draft_digital_resource_coherence', 'trg_libraries_digital_policy_coord_only')) <> 2 THEN
    RAISE EXCEPTION 'triggers absents';
  END IF;
END
$garde$;

NOTIFY pgrst, 'reload schema';

COMMIT;
