-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — attacher un fichier reçu se décide AVANT la clé de service
-- (13/10/2026, constat de l'audit B42 des Edge Functions, 069b76ea).
--
-- LE DÉFAUT. Dans l'Edge Function attach-received-asset, la seule décision de
-- permission était public.fn_attach_received_asset_record, appelée sous le
-- jeton de l'appelant APRÈS tout le travail fait à la clé de service :
-- lecture de ingest.partner_catalog_received_assets (404 / 409 avec asset_id /
-- 422 : un oracle d'existence et d'état sur un identifiant SÉQUENTIEL),
-- téléchargement du dépôt, upload(upsert: true) dans pdf-restrito ou
-- anarbib-media-restricted sous attached/<book_id>/<id>_<nom> (une copie
-- existante écrasée), puis effacement de cette copie si la RPC refusait. Tout
-- porteur d'un jeton valide — un simple lecteur — déclenchait ces effets.
--
-- LA CORRECTION. public.fn_attach_received_asset_garde(received_asset_id,
-- book_id) : DEFINER, STABLE, n'écrit rien, rend true ou lève. L'Edge Function
-- l'appelle sous le jeton de l'appelant, après la garde de double
-- authentification et AVANT le premier geste à la clé de service. Ses règles
-- sont celles de fn_attach_received_asset_record, lues en production le 13/10
-- (pg_get_functiondef), à l'identique :
--   (a) le fichier reçu existe et son run appartient à une bibliothèque dont
--       l'appelant est coordination active — ou il administre le réseau ;
--   (b) le livre est détenu (book_holdings) par une bibliothèque dont
--       l'appelant est coordination active — ou il administre le réseau.
-- Tout refus dit la même chose (« Recurso recebido introuvável. », HINT
-- error.edge.received_asset_not_found) : fichier inconnu, fichier d'une autre
-- bibliothèque, livre inconnu ou non détenu, lecteur, adhésion inactive — la
-- doctrine de l'oracle d'existence (B14). La RPC d'écriture garde ses propres
-- gardes : la garde avance la décision, elle ne la remplace pas. La suite
-- attach_recu_garde_tests T4 tient les deux d'accord, cas par cas.
--
-- ET DANS LA RPC D'ÉCRITURE, LE MÊME ORACLE. fn_attach_received_asset_record
-- rendait { ok, asset_id } pour un fichier déjà attaché AVANT ses gardes :
-- n'importe quel compte, en appelant la RPC directement, apprenait qu'un
-- fichier reçu existait, qu'il était attaché, et à quel digital_asset. Ce
-- retour précoce est retiré : la même idempotence existe déjà APRÈS les gardes
-- (relecture sous verrou, H31) ; une coordination légitime obtient la même
-- réponse qu'avant. Corps repris de la définition RÉELLE de production
-- (13/10/2026), ce bloc seul retiré.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_attach_received_asset_garde(p_received_asset_id bigint, p_book_id bigint)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_run_id bigint;
  v_admin boolean := public.fn_caller_is_network_admin();
BEGIN
  SELECT ra.run_id INTO v_run_id
    FROM ingest.partner_catalog_received_assets ra
   WHERE ra.id = p_received_asset_id;

  -- (a) le fichier reçu : il existe, et son run est d'une bibliothèque coordonnée.
  IF NOT FOUND OR NOT (v_admin OR EXISTS (
    SELECT 1 FROM ingest.partner_catalog_import_runs run
      JOIN public.user_library_memberships m ON m.library_id = run.library_id
     WHERE run.id = v_run_id AND m.user_id = auth.uid() AND m.status = 'active' AND m.role = 'coordenador'
  )) THEN
    RAISE EXCEPTION 'Recurso recebido introuvável.' USING HINT = 'error.edge.received_asset_not_found';
  END IF;

  -- (b) le livre : détenu par une bibliothèque coordonnée.
  IF NOT (v_admin OR EXISTS (
    SELECT 1 FROM public.book_holdings h
      JOIN public.user_library_memberships m ON m.library_id = h.library_id
     WHERE h.book_id = p_book_id AND m.user_id = auth.uid() AND m.status = 'active' AND m.role = 'coordenador'
  )) THEN
    RAISE EXCEPTION 'Recurso recebido introuvável.' USING HINT = 'error.edge.received_asset_not_found';
  END IF;

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_attach_received_asset_garde(bigint, bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_attach_received_asset_garde(bigint, bigint) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_attach_received_asset_garde(bigint, bigint) IS
  'Garde de permission de l''Edge Function attach-received-asset, appelée sous le jeton de l''appelant AVANT '
  'tout geste à la clé de service (13/10/2026). Mêmes règles que fn_attach_received_asset_record : coordination '
  'active de la bibliothèque du run du fichier reçu ET d''une bibliothèque détentrice du livre, ou administration '
  'du réseau. Refus unique « introuvable » (oracle d''existence, B14). N''écrit rien.';

-- ── fn_attach_received_asset_record : le retour « déjà attaché » passe après les gardes ──
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
BEGIN
  IF p_received_asset_id IS NULL OR p_book_id IS NULL THEN RAISE EXCEPTION 'received_asset_id e book_id obrigatorios.'; END IF;
  IF p_mode NOT IN ('export','read','both') THEN RAISE EXCEPTION 'mode inválido (%).', p_mode; END IF;
  IF p_bucket_name NOT IN ('pdf-restrito','anarbib-media-restricted') THEN RAISE EXCEPTION 'Bucket destino inválido (%).', p_bucket_name; END IF;
  IF p_object_path IS NULL OR p_object_path LIKE 'http%' THEN RAISE EXCEPTION 'Caminho de destino inválido.'; END IF;

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

-- CREATE OR REPLACE garde les droits existants ; on les redit quand même
-- (ouverte à authenticated : un écran vivant l'appelle par l'Edge Function,
-- b14_oracle_existence_forme T2, oracle_existence_ordre T3).
REVOKE ALL ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) TO authenticated, service_role;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.fn_attach_received_asset_garde(bigint, bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_attach_received_asset_record(bigint, bigint, text, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'attache d''un fichier reçu : ouverte à anon';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.fn_attach_received_asset_garde(bigint, bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'garde d''attache fermée à authenticated : l''Edge Function refuserait tout';
  END IF;
END $$;

COMMIT;
