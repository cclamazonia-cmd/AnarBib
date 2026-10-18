-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — fichiers réservés : chaque bibliothèque gère les siens
-- (17/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- RÈGLES POSÉES
--
-- 1. Les politiques Storage des espaces réservés entrent au dépôt. Celles de
--    pdf-restrito, library-regimentos-private et catalogos_parceiros_raw
--    étaient posées à la main en production (cf. B42, « 47 politiques hors
--    dépôt ») ; elles sont remplacées ici par des politiques versionnées :
--    - pdf-restrito : un objet se lit, se remplace ou se retire quand la
--      personne l'a versé elle-même, ou quand il est désigné par une ressource
--      d'une notice (brouillon modifiable, livre détenu par sa bibliothèque,
--      digital_asset d'un livre détenu) — private.fn_objet_reserve_gerable.
--      Un nouvel objet se verse sous books/<id d'un brouillon modifiable>/,
--      ou au chemin d'une ressource d'un tel brouillon (changement d'espace) —
--      private.fn_dossier_reserve_versable.
--    - library-regimentos-private : le premier dossier est le slug de la
--      bibliothèque ; seule son équipe y accède.
--    - catalogos_parceiros_raw : l'équipe dépose sous partner/ ; elle ne voit,
--      ne remplace et ne retire que ses propres dépôts. Le traitement se fait
--      côté serveur (clé de service), hors de ces politiques.
--
-- 2. book_digital_resources ne s'écrit plus en direct : toutes ses écritures
--    passent par des fonctions DEFINER (publish_book_draft_digital_resources,
--    fn_attach_received_asset_record, api.audio_resource_set_fingerprint),
--    vérifié en production le 17/10. Le front ne fait que la lire.
--
-- 3. Une ressource de brouillon placée dans un espace réservé désigne un
--    fichier rangé sous books/<id du brouillon>/, ou un fichier déjà rattaché
--    au livre que le brouillon reprend (tg_draft_digital_resource_coherence).
--
-- 4. fn_attach_received_asset_record n'enregistre que le chemin que l'Edge
--    Function attach-received-asset produit — attached/<livre>/<reçu>_… — et
--    seulement si l'objet existe.
--
-- 5. fn_revoke_digital_asset_record ne déclare orphelin (donc effaçable par
--    revoke-digital-asset) qu'un fichier rangé sous attached/<livre>/ et que
--    plus aucune ressource, brouillon compris, ne désigne.
--
-- 6. fn_import_create n'enregistre qu'un fichier de catalogos_parceiros_raw
--    versé par la personne qui crée l'import.
--
-- Corps des fonctions repris de la définition RÉELLE de production
-- (pg_get_functiondef, 17/10/2026), seules les règles ci-dessus ajoutées.
-- Tests : tests/sql/fichiers_reserves_par_bibliotheque_tests.sql.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Aides des politiques Storage ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION private.fn_objet_reserve_gerable(p_bucket text, p_name text, p_owner text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  select
    -- ce que la personne a versé elle-même, tant qu'elle est d'une équipe
    (p_owner is not null and p_owner = (select auth.uid())::text
       and cardinality(public.fn_caller_staff_library_ids()) > 0)
    or public.fn_caller_is_network_admin()
    -- désigné par une ressource d'un brouillon que la personne peut modifier
    or exists (
      select 1
        from public.book_draft_digital_resources r
        join public.book_drafts d on d.id = r.book_draft_id
       where r.storage_bucket = p_bucket and r.storage_path = p_name
         and public.fn_caller_can_edit_draft_library(
               coalesce(d.owner_library_id, private.fn_book_draft_creator_library(d.id, d.created_by)),
               d.created_by))
    -- désigné par une ressource d'un livre que sa bibliothèque détient
    or exists (
      select 1
        from public.book_digital_resources r
        join public.book_holdings h on h.book_id = r.book_id
       where r.storage_bucket = p_bucket and r.storage_path = p_name
         and h.library_id = any (public.fn_caller_staff_library_ids()))
    or exists (
      select 1
        from public.digital_assets a
        join public.book_holdings h on h.book_id = a.book_id
       where a.bucket_name = p_bucket and a.object_path = p_name
         and h.library_id = any (public.fn_caller_staff_library_ids()));
$function$;

REVOKE EXECUTE ON FUNCTION private.fn_objet_reserve_gerable(text, text, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.fn_objet_reserve_gerable(text, text, text) TO authenticated;
COMMENT ON FUNCTION private.fn_objet_reserve_gerable(text, text, text) IS
  'Vrai si l''appelant peut lire, remplacer ou retirer cet objet d''un espace réservé : versé par lui (équipe active), ou désigné par une ressource d''un brouillon modifiable ou d''un livre détenu par sa bibliothèque ; administration du réseau partout. Lue par les politiques Storage de pdf-restrito (17/10/2026).';

CREATE OR REPLACE FUNCTION private.fn_dossier_reserve_versable(p_bucket text, p_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  select
    p_name is not null
    and position('..' in p_name) = 0
    and (
      -- books/<id d'un brouillon modifiable>/…
      (split_part(p_name, '/', 1) = 'books'
       and split_part(p_name, '/', 2) ~ '^[0-9]{1,18}$'
       and split_part(p_name, '/', 3) <> ''
       and exists (
         select 1 from public.book_drafts d
          where d.id = split_part(p_name, '/', 2)::bigint
            and public.fn_caller_can_edit_draft_library(
                  coalesce(d.owner_library_id, private.fn_book_draft_creator_library(d.id, d.created_by)),
                  d.created_by)))
      -- ou le chemin d'une ressource d'un tel brouillon (changement d'espace)
      or exists (
        select 1
          from public.book_draft_digital_resources r
          join public.book_drafts d on d.id = r.book_draft_id
         where r.storage_path = p_name
           and public.fn_caller_can_edit_draft_library(
                 coalesce(d.owner_library_id, private.fn_book_draft_creator_library(d.id, d.created_by)),
                 d.created_by))
    );
$function$;

REVOKE EXECUTE ON FUNCTION private.fn_dossier_reserve_versable(text, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.fn_dossier_reserve_versable(text, text) TO authenticated;
COMMENT ON FUNCTION private.fn_dossier_reserve_versable(text, text) IS
  'Vrai si l''appelant peut verser cet objet dans un espace réservé : sous books/<id d''un brouillon qu''il peut modifier>/, ou au chemin d''une ressource d''un tel brouillon. Lue par les politiques Storage de pdf-restrito (17/10/2026).';

-- ─── Politiques Storage versionnées ────────────────────────────────────────
DO $storage$
BEGIN
  IF to_regclass('storage.objects') IS NULL THEN
    RAISE NOTICE 'storage.objects absent, politiques non posées';
    RETURN;
  END IF;

  -- pdf-restrito
  DROP POLICY IF EXISTS pdf_restrito_librarians_select ON storage.objects;
  DROP POLICY IF EXISTS pdf_restrito_librarians_insert ON storage.objects;
  DROP POLICY IF EXISTS pdf_restrito_librarians_update ON storage.objects;
  DROP POLICY IF EXISTS pdf_restrito_librarians_delete ON storage.objects;
  DROP POLICY IF EXISTS pdf_restrito_select ON storage.objects;
  DROP POLICY IF EXISTS pdf_restrito_insert ON storage.objects;
  DROP POLICY IF EXISTS pdf_restrito_update ON storage.objects;
  DROP POLICY IF EXISTS pdf_restrito_delete ON storage.objects;
  CREATE POLICY pdf_restrito_select ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'pdf-restrito' AND private.fn_objet_reserve_gerable(bucket_id, name, owner_id));
  CREATE POLICY pdf_restrito_insert ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'pdf-restrito' AND private.fn_dossier_reserve_versable(bucket_id, name));
  CREATE POLICY pdf_restrito_update ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'pdf-restrito' AND private.fn_objet_reserve_gerable(bucket_id, name, owner_id))
    WITH CHECK (bucket_id = 'pdf-restrito' AND private.fn_dossier_reserve_versable(bucket_id, name));
  CREATE POLICY pdf_restrito_delete ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'pdf-restrito' AND private.fn_objet_reserve_gerable(bucket_id, name, owner_id));

  -- library-regimentos-private : <slug de la bibliothèque>/…
  DROP POLICY IF EXISTS library_regimentos_private_librarians_select ON storage.objects;
  DROP POLICY IF EXISTS library_regimentos_private_librarians_insert ON storage.objects;
  DROP POLICY IF EXISTS library_regimentos_private_librarians_update ON storage.objects;
  DROP POLICY IF EXISTS library_regimentos_private_librarians_delete ON storage.objects;
  DROP POLICY IF EXISTS library_regimentos_private_equipe ON storage.objects;
  CREATE POLICY library_regimentos_private_equipe ON storage.objects FOR ALL TO authenticated
    -- objects.name qualifié : libraries a aussi une colonne name.
    USING (bucket_id = 'library-regimentos-private' AND EXISTS (
      SELECT 1 FROM public.libraries l
       WHERE l.slug = split_part(objects.name, '/', 1)
         AND public.user_can_act_as_staff_on_library(l.id)))
    WITH CHECK (bucket_id = 'library-regimentos-private' AND EXISTS (
      SELECT 1 FROM public.libraries l
       WHERE l.slug = split_part(objects.name, '/', 1)
         AND public.user_can_act_as_staff_on_library(l.id)));

  -- catalogos_parceiros_raw : dépôt sous partner/, chacun ne gère que les siens
  DROP POLICY IF EXISTS "catalogos_parceiros_raw staff manage" ON storage.objects;
  DROP POLICY IF EXISTS catalogos_parceiros_raw_depot ON storage.objects;
  DROP POLICY IF EXISTS catalogos_parceiros_raw_les_siens ON storage.objects;
  CREATE POLICY catalogos_parceiros_raw_depot ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'catalogos_parceiros_raw'
      AND split_part(name, '/', 1) = 'partner'
      AND (SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_painel = true)));
  CREATE POLICY catalogos_parceiros_raw_les_siens ON storage.objects FOR ALL TO authenticated
    USING (bucket_id = 'catalogos_parceiros_raw'
      AND owner_id = (SELECT auth.uid())::text
      AND (SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_painel = true)))
    WITH CHECK (bucket_id = 'catalogos_parceiros_raw'
      AND split_part(name, '/', 1) = 'partner'
      AND owner_id = (SELECT auth.uid())::text
      AND (SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_painel = true)));
  -- Pas de COMMENT ON POLICY : cf. 20261013182456 (refusé sur image auto-hébergée).
END $storage$;

-- ─── book_digital_resources : écritures par les fonctions seulement ────────
DROP POLICY IF EXISTS book_digital_resources_insert_catalogacao ON public.book_digital_resources;
DROP POLICY IF EXISTS book_digital_resources_update_catalogacao ON public.book_digital_resources;
DROP POLICY IF EXISTS book_digital_resources_delete_catalogacao ON public.book_digital_resources;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.book_digital_resources FROM PUBLIC, anon, authenticated;

-- ─── Ressources de brouillon : un fichier réservé reste dans sa notice ─────
CREATE OR REPLACE FUNCTION public.tg_draft_digital_resource_coherence()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_catalog', 'pg_temp'
AS $function$
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
     AND NEW.storage_path IS NOT DISTINCT FROM OLD.storage_path
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

  -- 17/10/2026 : un fichier d'un espace réservé est celui de cette notice —
  -- rangé sous books/<id du brouillon>/, ou déjà rattaché au livre repris.
  IF NEW.storage_bucket = ANY (v_restricted_buckets) AND NEW.storage_path IS NOT NULL
     AND NOT (
       (left(NEW.storage_path, length('books/' || NEW.book_draft_id || '/')) = 'books/' || NEW.book_draft_id || '/'
        AND position('..' in NEW.storage_path) = 0)
       -- (même chemin, l'espace peut changer : déplacement public ↔ réservé)
       OR EXISTS (
         SELECT 1 FROM public.book_drafts d
           JOIN public.book_digital_resources r ON r.book_id = d.published_book_id
          WHERE d.id = NEW.book_draft_id
            AND r.storage_path = NEW.storage_path)
     ) THEN
    RAISE EXCEPTION 'Le fichier n''est pas à l''endroit que la ressource déclare (%/%).', NEW.storage_bucket, NEW.storage_path
      USING hint = 'error.digital.file_not_in_bucket';
  END IF;

  -- 05/10 : le fichier déclaré existe à l'endroit déclaré (cf. en-tête).
  IF NEW.storage_bucket IS NOT NULL AND NEW.storage_path IS NOT NULL
     AND NOT private.fn_objet_stocke_existe(NEW.storage_bucket, NEW.storage_path) THEN
    RAISE EXCEPTION 'Le fichier n''est pas à l''endroit que la ressource déclare (%/%).', NEW.storage_bucket, NEW.storage_path
      USING hint = 'error.digital.file_not_in_bucket';
  END IF;
  RETURN NEW;
END;
$function$;

-- ─── Attache d'un fichier reçu : le chemin que l'Edge Function produit ─────
CREATE OR REPLACE FUNCTION public.fn_attach_received_asset_record(p_received_asset_id bigint, p_book_id bigint, p_bucket_name text, p_object_path text, p_mode text DEFAULT 'both'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth', 'pg_catalog'
AS $function$
DECLARE
  ra ingest.partner_catalog_received_assets%rowtype;
  v_authorized boolean;
  v_kind text;
  v_title text;
  v_asset_id bigint;
  v_resource_id bigint;
  v_rtype text;
  v_utype text;
  v_prefixe text;
BEGIN
  IF p_received_asset_id IS NULL OR p_book_id IS NULL THEN RAISE EXCEPTION 'received_asset_id e book_id obrigatorios.'; END IF;
  IF p_mode NOT IN ('export','read','both') THEN RAISE EXCEPTION 'mode inválido (%).', p_mode; END IF;
  IF p_bucket_name NOT IN ('pdf-restrito','anarbib-media-restricted') THEN RAISE EXCEPTION 'Bucket destino inválido (%).', p_bucket_name; END IF;
  IF p_object_path IS NULL OR p_object_path LIKE 'http%' THEN RAISE EXCEPTION 'Caminho de destino inválido.'; END IF;
  -- 17/10/2026 : le chemin a la forme que attach-received-asset produit,
  -- attached/<livre>/<reçu>_<nom> (contrôle sur les seuls arguments : il ne
  -- dit rien de la base ; l'existence de l'objet est vérifiée APRÈS les gardes).
  v_prefixe := 'attached/' || p_book_id || '/' || p_received_asset_id || '_';
  IF left(p_object_path, length(v_prefixe)) <> v_prefixe
     OR length(p_object_path) = length(v_prefixe)
     OR position('..' in p_object_path) > 0
     OR position('/' in substr(p_object_path, length(v_prefixe) + 1)) > 0 THEN
    RAISE EXCEPTION 'Caminho de destino inválido.';
  END IF;

  SELECT * INTO ra FROM ingest.partner_catalog_received_assets WHERE id = p_received_asset_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recurso recebido introuvável.'; END IF;
  -- (13/10/2026) Plus de retour « déjà attaché » ici : avant les gardes, il
  -- disait à n'importe quel compte qu'un fichier reçu existait, était attaché,
  -- et à quel asset. L'idempotence vit après les gardes, sous verrou (H31).

  -- Garde 0 : le fichier reçu appartient à une biblio coordonnée par l'appelant.
  IF NOT public.fn_caller_is_network_admin() AND NOT EXISTS (
    SELECT 1 FROM ingest.partner_catalog_import_runs run
      JOIN public.user_library_memberships m ON m.library_id = run.library_id
     WHERE run.id = ra.run_id AND m.user_id = auth.uid() AND m.status = 'active' AND m.role = 'coordenador'
  ) THEN RAISE EXCEPTION 'Recurso recebido introuvável.'; END IF;

  -- Garde : coordenador d'une biblio détentrice du livre (ou admin réseau).
  SELECT (
    EXISTS (SELECT 1 FROM public.book_holdings h
              JOIN public.user_library_memberships m ON m.library_id = h.library_id
             WHERE h.book_id = p_book_id AND m.user_id = auth.uid()
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Recurso recebido introuvável.'; END IF;
  -- 14/10/2026 : un livre inconnu est refusé comme le reste, administration
  -- comprise, au lieu de buter plus bas sur la clé étrangère.
  IF NOT EXISTS (SELECT 1 FROM public.books b WHERE b.id = p_book_id) THEN
    RAISE EXCEPTION 'Recurso recebido introuvável.';
  END IF;
  -- 17/10/2026 : l'objet déclaré existe (après les gardes : pas d'oracle).
  IF NOT private.fn_objet_stocke_existe(p_bucket_name, p_object_path) THEN
    RAISE EXCEPTION 'Caminho de destino inválido.';
  END IF;

  -- H31 (05/10/2026) : le run verrouillé (après les gardes d'accès), puis le
  -- fichier reçu relu sous verrou de ligne. Un « Retraiter » en cours
  -- (ingest.fn_h31_effacer_lignes_pour_retraitement, FOR UPDATE) est attendu :
  -- s'il a effacé ce fichier, refus « introuvable » ; un effacement qui arrive
  -- après attend cette attache, puis voit le fichier attaché et refuse.
  PERFORM 1 FROM ingest.partner_catalog_import_runs run WHERE run.id = ra.run_id FOR SHARE;
  SELECT * INTO ra FROM ingest.partner_catalog_received_assets WHERE id = p_received_asset_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recurso recebido introuvável.' USING HINT = 'error.edge.received_asset_not_found'; END IF;
  IF ra.attached_digital_asset_id IS NOT NULL OR ra.deposit_status = 'attached' THEN
    RETURN jsonb_build_object('ok', true, 'asset_id', ra.attached_digital_asset_id, 'created', false, 'book_id', p_book_id);
  END IF;

  v_kind := CASE
    WHEN p_bucket_name = 'pdf-restrito' THEN 'pdf'
    WHEN ra.mime_type LIKE 'image/%' THEN 'image'
    WHEN ra.mime_type LIKE 'audio/%' THEN 'audio'
    WHEN ra.mime_type LIKE 'video/%' THEN 'video'
    WHEN ra.asset_kind IN ('image','audio','video') THEN ra.asset_kind
    ELSE 'image' END;
  v_title := coalesce(nullif(trim(ra.title), ''), 'Recurso recebido');

  -- ── Export / partage : digital_asset to_review (couche curée) ──────────────
  IF p_mode IN ('export','both') THEN
    INSERT INTO public.digital_assets
      (asset_kind, title, book_id, source_name, attribution_text, source_license_name,
       review_state, bucket_name, object_path, is_public, mime_type, file_size_bytes, checksum_sha256, notes)
    VALUES
      (v_kind, v_title, p_book_id, coalesce(nullif(trim(ra.source_name), ''), 'AnarBib'),
       ra.attribution_text, ra.source_license_name, 'to_review', p_bucket_name, p_object_path, false,
       coalesce(ra.mime_type, 'application/octet-stream'), ra.file_size_bytes, ra.checksum_sha256,
       'Attaché depuis un fonds reçu (received_asset ' || p_received_asset_id || ') — à vérifier')
    RETURNING id INTO v_asset_id;
  END IF;

  -- ── Lecture locale : book_digital_resources (couche catalogue, même fichier) ─
  IF p_mode IN ('read','both') THEN
    v_rtype := CASE WHEN v_kind = 'pdf' THEN 'pdf_restrito' WHEN v_kind = 'audio' THEN 'audio'
                    WHEN v_kind = 'video' THEN 'video' ELSE 'image' END;
    v_utype := CASE WHEN v_kind = 'pdf' THEN 'leitura_online' WHEN v_kind = 'audio' THEN 'escuta_online'
                    ELSE 'visualizacao_online' END;
    -- rights_status reste NULL : le statut declare par le partenaire appartient
    -- a un autre vocabulaire et n'a pas ete verifie par nous. Il est conserve
    -- en clair dans la justification. (Migration vocabulaire, 2026-08-20.)
    INSERT INTO public.book_digital_resources
      (book_id, resource_type, usage_type, access_scope, status, is_active,
       storage_bucket, storage_path, mime_type, label, source_name, attribution_text,
       rights_status, rights_justification, is_primary, bibliographic_match_validated, notes)
    VALUES
      (p_book_id, v_rtype, v_utype, 'conta_ativa', 'active', true,
       p_bucket_name, p_object_path, coalesce(ra.mime_type, 'application/octet-stream'), v_title,
       nullif(trim(ra.source_name), ''), ra.attribution_text,
       NULL,
       'a verificar: recebido de ' || coalesce(nullif(trim(ra.source_name), ''), 'parceiro')
         || ' — status declarado na origem: '
         || coalesce(nullif(trim(ra.rights_status), ''), 'não informado'),
       false, true,
       'Attaché (lisible local) depuis un fonds reçu (received_asset ' || p_received_asset_id || ')')
    RETURNING id INTO v_resource_id;
  END IF;

  UPDATE ingest.partner_catalog_received_assets
     SET attached_digital_asset_id = v_asset_id, deposit_status = 'attached'
   WHERE id = p_received_asset_id;

  RETURN jsonb_build_object('ok', true, 'asset_id', v_asset_id, 'resource_id', v_resource_id,
    'created', true, 'book_id', p_book_id, 'mode', p_mode,
    'review_state', CASE WHEN v_asset_id IS NOT NULL THEN 'to_review' ELSE NULL END);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) TO authenticated, service_role;

-- ─── Révocation : n'est orphelin que le fichier d'une attache ──────────────
CREATE OR REPLACE FUNCTION public.fn_revoke_digital_asset_record(p_asset_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth', 'pg_catalog'
AS $function$
DECLARE
  da          public.digital_assets%rowtype;
  v_authorized boolean;
  v_ra_id     bigint;
  v_orphaned  boolean;
BEGIN
  IF p_asset_id IS NULL THEN RAISE EXCEPTION 'asset_id obrigatorio.'; END IF;

  SELECT * INTO da FROM public.digital_assets WHERE id = p_asset_id FOR UPDATE;
  IF NOT FOUND THEN
    -- Idempotent : déjà supprimé.
    RETURN jsonb_build_object('ok', true, 'asset_id', p_asset_id, 'deleted', false,
      'reason', 'already_gone', 'file_orphaned', false);
  END IF;

  -- Garde : coordenador d'une biblio détentrice du livre (ou admin réseau).
  SELECT (
    EXISTS (SELECT 1 FROM public.book_holdings h
              JOIN public.user_library_memberships m ON m.library_id = h.library_id
             WHERE h.book_id = da.book_id AND m.user_id = auth.uid()
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca detentora.'; END IF;

  -- Délie un éventuel fichier reçu : il retourne en file d'attache (ré-attachable).
  UPDATE ingest.partner_catalog_received_assets
     SET attached_digital_asset_id = NULL, deposit_status = 'deposited'
   WHERE attached_digital_asset_id = p_asset_id
   RETURNING id INTO v_ra_id;

  DELETE FROM public.digital_assets WHERE id = p_asset_id;

  -- Le fichier est-il devenu orphelin ? Seul un fichier d'attache de CE livre
  -- (attached/<livre>/…) que plus aucune ressource — brouillon compris — ne
  -- désigne → l'EF pourra le retirer du bucket. Sinon on le garde.
  v_orphaned := (
    da.bucket_name IS NOT NULL AND da.object_path IS NOT NULL
    AND left(da.object_path, length('attached/' || da.book_id || '/')) = 'attached/' || da.book_id || '/'
    AND position('..' in da.object_path) = 0
    AND NOT EXISTS (SELECT 1 FROM public.digital_assets d2
                     WHERE d2.bucket_name = da.bucket_name AND d2.object_path = da.object_path)
    AND NOT EXISTS (SELECT 1 FROM public.book_digital_resources r
                     WHERE r.storage_bucket = da.bucket_name AND r.storage_path = da.object_path)
    AND NOT EXISTS (SELECT 1 FROM public.book_draft_digital_resources r
                     WHERE r.storage_bucket = da.bucket_name AND r.storage_path = da.object_path)
  );

  RETURN jsonb_build_object('ok', true, 'asset_id', p_asset_id, 'deleted', true,
    'book_id', da.book_id, 'unlinked_received_asset', v_ra_id,
    'bucket_name', da.bucket_name, 'object_path', da.object_path,
    'file_orphaned', v_orphaned);
END;
$function$;

-- ─── Création d'un import : le fichier est celui que la personne a versé ───
CREATE OR REPLACE FUNCTION public.fn_import_create(p_source_id bigint, p_storage_path text, p_original_filename text, p_bucket_id text DEFAULT 'catalogos_parceiros_raw'::text, p_mime_type text DEFAULT NULL::text, p_size_bytes bigint DEFAULT NULL::bigint, p_sha256 text DEFAULT NULL::text, p_detected_format text DEFAULT 'unknown'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_source_library_id uuid;
  v_source_kind text;
  v_run_id bigint;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT s.library_id, s.source_kind INTO v_source_library_id, v_source_kind
  FROM ingest.partner_catalog_sources s
  WHERE s.id = p_source_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Source % introuvable', p_source_id;
  END IF;

  -- Meme message que « introuvable » : un refus ne dit pas si la chose existe
  -- ailleurs (B14, 20260901091431 — l'oracle d'existence). Le corps ci-dessus
  -- part de la definition REELLE (pg_get_functiondef en prod), pas du baseline.
  IF v_source_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Source % introuvable', p_source_id;
  END IF;

  -- 04/09/2026 : le catalogue d'une bibliotheque compagne n'entre que par
  -- l'administration du reseau (cf. en-tete). Le catalogue propre
  -- (own_catalog) et les autres provenances restent a la coordination.
  IF v_source_kind IN ('partner_deposit', 'oai_pmh') AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Deposito de catalogo companheiro reservado a administracao da rede.'
      USING HINT = 'error.import.deposit_admin_only';
  END IF;

  -- 17/10/2026 : le fichier est dans l'espace des dépôts, versé par la
  -- personne qui crée l'import.
  IF p_bucket_id IS DISTINCT FROM 'catalogos_parceiros_raw'
     OR NOT EXISTS (SELECT 1 FROM storage.objects so
                     WHERE so.bucket_id = 'catalogos_parceiros_raw'
                       AND so.name = p_storage_path
                       AND so.owner_id = (SELECT auth.uid())::text) THEN
    RAISE EXCEPTION 'Arquivo de importação inválido.';
  END IF;

  v_run_id := ingest.fn_create_partner_catalog_import(
    p_source_id         := p_source_id,
    p_storage_path      := p_storage_path,
    p_original_filename := p_original_filename,
    p_bucket_id         := p_bucket_id,
    p_mime_type         := p_mime_type,
    p_size_bytes        := p_size_bytes,
    p_sha256            := p_sha256,
    p_detected_format   := p_detected_format,
    p_requested_by      := v_actor.user_id
  );

  UPDATE ingest.partner_catalog_import_runs
  SET library_id = v_actor.library_id
  WHERE id = v_run_id AND library_id IS NULL;

  RETURN jsonb_build_object(
    'ok',         true,
    'run_id',     v_run_id,
    'library_id', v_actor.library_id
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_import_create(bigint, text, text, text, text, bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_import_create(bigint, text, text, text, text, bigint, text, text) TO authenticated, service_role;

-- ─── Vérifications ─────────────────────────────────────────────────────────
DO $verif$
BEGIN
  IF has_function_privilege('anon', 'private.fn_objet_reserve_gerable(text, text, text)', 'EXECUTE')
     OR has_function_privilege('anon', 'private.fn_dossier_reserve_versable(text, text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_attach_received_asset_record(bigint, bigint, text, text, text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_import_create(bigint, text, text, text, text, bigint, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fichiers réservés : une fonction est ouverte à anon';
  END IF;
  IF has_table_privilege('authenticated', 'public.book_digital_resources', 'INSERT')
     OR has_table_privilege('authenticated', 'public.book_digital_resources', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.book_digital_resources', 'DELETE') THEN
    RAISE EXCEPTION 'fichiers réservés : book_digital_resources reste inscriptible en direct';
  END IF;
  IF to_regclass('storage.objects') IS NOT NULL AND EXISTS (
       SELECT 1 FROM pg_policies
        WHERE schemaname = 'storage' AND tablename = 'objects'
          AND policyname IN ('pdf_restrito_librarians_select', 'library_regimentos_private_librarians_select',
                             'catalogos_parceiros_raw staff manage')) THEN
    RAISE EXCEPTION 'fichiers réservés : une ancienne politique Storage subsiste';
  END IF;
END $verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;
