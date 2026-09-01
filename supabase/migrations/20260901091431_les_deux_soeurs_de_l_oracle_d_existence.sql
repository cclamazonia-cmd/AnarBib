-- B14, schéma `public`, paquet 2 : les quatorze sœurs de l'oracle d'existence.
--
-- (Le titre disait « deux » quand la migration a été commencée. Le test écrit
-- dans la foulée en a trouvé douze de plus, en cherchant le message sans ses
-- accents. Le titre a suivi le relevé, pas l'inverse.)
--
-- CE QUE LE PAQUET PRÉCÉDENT AVAIT MANQUÉ. Le paquet 1 a fermé
-- `fn_painel_find_profile_by_lookup`, qui distinguait « compte trouvé, mais pas
-- dans votre bibliothèque » de « rien trouvé » — un test d'existence d'adresse
-- e-mail. Le correctif était juste et **isolé** : j'ai corrigé une fonction
-- sans chercher ses sœurs.
--
-- Cherchées par le MOTIF plutôt que par le nom (le second chemin qu'exige
-- `DOC-RECENS-1`) — un message contenant « não pertence … biblioteca » à côté
-- d'un message « introuvable » —, il y en avait deux autres tout de suite, puis
-- douze de plus quand le test a cherché sans les accents (bloc 3) :
--
--   1. `fn_painel_get_profile_by_id(p_profile_id uuid)` : la jumelle exacte,
--      par identifiant au lieu de l'e-mail. « Cadastro não encontrado. » contre
--      « Este cadastro não pertence à biblioteca ativa deste painel. »
--      Moins exploitable — un UUID ne se devine pas — mais même faute de forme.
--
--   2. `fn_attach_received_asset_record(p_received_asset_id bigint, …)` :
--      « Recurso recebido % introuvável. » contre « Recurso recebido não
--      pertence a uma biblioteca que você coordena. » Et ici l'identifiant est
--      un **bigint séquentiel** : il s'énumère en comptant. On apprend donc
--      combien de fonds ont été reçus dans le réseau, et jusqu'où va la
--      numérotation — la volumétrie des échanges entre bibliothèques, qui n'est
--      pas une donnée technique dans un réseau militant.
--
-- Aucune ne change de DROIT : elles refusaient déjà les mêmes
-- personnes. On unifie ce qu'elles disent en refusant, comme au paquet 1 —
-- doctrine de `api.resolve_reader_card` : la banalité du motif est le contrôle.
--
-- Les gardes elles-mêmes ne bougent pas : `can_manage_profile_from_my_libraries`
-- pour la première, la double garde (coordination du fonds reçu ET du livre
-- destinataire) pour la seconde. Seuls les messages sont rendus indiscernables.

-- ── 1. La jumelle par identifiant ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_painel_get_profile_by_id(p_profile_id uuid)
RETURNS public.profiles
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_row public.profiles;
  -- Message UNIQUE : « je n'ai rien pour vous », que le compte n'existe pas ou
  -- qu'il existe hors de vos bibliothèques. Ne pas le spécialiser (B14).
  c_msg constant text := 'Cadastro não encontrado.';
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if p_profile_id is null then
    raise exception 'Cadastro sem identificador válido.';
  end if;

  select p.* into v_row
  from public.profiles p
  where p.id = p_profile_id
  limit 1;

  if v_row.id is null or not public.can_manage_profile_from_my_libraries(v_row.id) then
    raise exception '%', c_msg;
  end if;

  return v_row;
end;
$function$;

COMMENT ON FUNCTION public.fn_painel_get_profile_by_id(uuid) IS
  'Profil par identifiant, pour le panneau. Rend UN SEUL message d''échec, que le compte existe hors de vos bibliothèques ou qu''il n''existe pas — unifié le 01/09/2026 (B14), en même temps que sa sœur fn_painel_find_profile_by_lookup. Même doctrine que api.resolve_reader_card.';

-- ── 2. La ressource reçue, dont l'identifiant est séquentiel ────────────────
-- Seul le message de la « garde 0 » change ; tout le reste du corps est
-- reconduit à l'identique.
-- Signature reprise À L'IDENTIQUE de l'existante, DEFAULT compris : sans le
-- « DEFAULT 'both' », PostgreSQL refuse le remplacement (« cannot change …
-- default »), et le search_path d'origine porte 'auth' — l'omettre casserait
-- auth.uid(). Une réécriture de corps ne doit RIEN changer d'autre que le corps.
CREATE OR REPLACE FUNCTION public.fn_attach_received_asset_record(
  p_received_asset_id bigint,
  p_book_id bigint,
  p_bucket_name text,
  p_object_path text,
  p_mode text DEFAULT 'both'::text
)
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
  -- Message UNIQUE pour « n'existe pas » et « pas à une biblio que vous
  -- coordonnez » : l'identifiant est un bigint séquentiel, donc énumérable —
  -- deux messages distincts donneraient la volumétrie des fonds reçus (B14).
  c_msg constant text := 'Recurso recebido não encontrado.';
BEGIN
  IF p_received_asset_id IS NULL OR p_book_id IS NULL THEN RAISE EXCEPTION 'received_asset_id e book_id obrigatorios.'; END IF;
  IF p_mode NOT IN ('export','read','both') THEN RAISE EXCEPTION 'mode inválido (%).', p_mode; END IF;
  IF p_bucket_name NOT IN ('pdf-restrito','anarbib-media-restricted') THEN RAISE EXCEPTION 'Bucket destino inválido (%).', p_bucket_name; END IF;
  IF p_object_path IS NULL OR p_object_path LIKE 'http%' THEN RAISE EXCEPTION 'Caminho de destino inválido.'; END IF;

  SELECT * INTO ra FROM ingest.partner_catalog_received_assets WHERE id = p_received_asset_id;
  IF NOT FOUND THEN RAISE EXCEPTION '%', c_msg; END IF;
  -- Idempotence : déjà attaché (asset OU lecture-seule marquée attached).
  IF ra.attached_digital_asset_id IS NOT NULL OR ra.deposit_status = 'attached' THEN
    RETURN jsonb_build_object('ok', true, 'asset_id', ra.attached_digital_asset_id, 'created', false, 'book_id', p_book_id);
  END IF;

  -- Garde 0 : le fichier reçu appartient à une biblio coordonnée par l'appelant.
  -- Même message que « introuvable » : voir c_msg.
  IF NOT public.fn_caller_is_network_admin() AND NOT EXISTS (
    SELECT 1 FROM ingest.partner_catalog_import_runs run
      JOIN public.user_library_memberships m ON m.library_id = run.library_id
     WHERE run.id = ra.run_id AND m.user_id = auth.uid() AND m.status = 'active' AND m.role = 'coordenador'
  ) THEN RAISE EXCEPTION '%', c_msg; END IF;

  -- Garde : coordenador d'une biblio détentrice du livre (ou admin réseau).
  SELECT (
    EXISTS (SELECT 1 FROM public.book_holdings h
              JOIN public.user_library_memberships m ON m.library_id = h.library_id
             WHERE h.book_id = p_book_id AND m.user_id = auth.uid()
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca detentora.'; END IF;

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
       rights_status, bucket_name, object_path, is_public, mime_type, file_size_bytes, checksum_sha256, notes)
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
    'rights_status', CASE WHEN v_asset_id IS NOT NULL THEN 'to_review' ELSE NULL END);
END;
$function$;

COMMENT ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) IS
  'Attache un fichier reçu d''un partenaire à une notice. Rend le MÊME message que la ressource n''existe pas ou qu''elle appartienne à une bibliothèque que vous ne coordonnez pas — unifié le 01/09/2026 (B14) : l''identifiant est un bigint séquentiel, deux messages distincts donnaient la volumétrie des fonds reçus dans le réseau.';

-- ── 3. DOUZE AUTRES, TROUVÉES PARCE QUE LE TEST A RÉVÉLÉ MON PROPRE ANGLE MORT ─
-- Le premier relevé par motif cherchait « não pertence » (accentué) et
-- « pertence à biblioteca ». Il rendait deux fonctions. La suite de test écrite
-- juste après cherchait AUSSI « nao pertence » sans accent — et en a trouvé
-- **douze de plus**, toute la famille `fn_import_*` :
--
--     RAISE EXCEPTION 'Run % introuvable', p_run_id;                  -- n'existe pas
--     RAISE EXCEPTION 'Run % nao pertence a esta biblioteca', …;      -- existe ailleurs
--
-- Même motif, mêmes conséquences, et sur des identifiants **bigint
-- séquentiels** : en incrémentant, un·e coordenador apprend combien d'imports
-- ont été faits dans le réseau et jusqu'où va la numérotation — l'activité de
-- catalogage des autres bibliothèques. La garde d'entrée (coordination ou
-- admin réseau) limite qui peut le faire, pas ce qu'on apprend.
--
-- **Chercher un texte dans une base multilingue doit couvrir les variantes
-- d'accentuation.** Mon « second chemin » était lui-même incomplet ; c'est le
-- test, en cherchant plus large, qui l'a montré — avant la CI, mais après que
-- j'aie cru avoir fini.
--
-- Substitution vérifiée (patron du wrap RLS `20260703203953`, avec le contrôle
-- que le paquet 3 du lot `api` y avait ajouté) : le message d'appartenance
-- devient celui de l'absence. Essayée à blanc en production avant écriture —
-- une occurrence par fonction, douze fonctions.

DO $
DECLARE
  r record;
  v_def text;
  v_new text;
  n int := 0;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
      FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public'
       AND p.prosecdef
       AND p.proname LIKE 'fn_import_%'
       AND p.prosrc ~* '(nao|não) pertence a esta biblioteca'
  LOOP
    v_def := pg_get_functiondef(r.oid);
    v_new := regexp_replace(v_def, '(nao|não) pertence a esta biblioteca', 'introuvable', 'g');

    IF v_new = v_def THEN
      RAISE EXCEPTION 'public.% : motif introuvable a la substitution — forme changee, migration interrompue', r.proname;
    END IF;

    EXECUTE v_new;
    n := n + 1;
  END LOOP;

  -- On ne fige PAS le compte à douze : un nombre exact écrit dans une migration
  -- devient faux dès qu'une fonction est ajoutée ou renommée ailleurs, et fait
  -- échouer un déploiement pour une raison qui n'est pas un défaut. L'invariant
  -- qui compte est vérifié par la garde de fin — *aucun* message d'appartenance
  -- ne subsiste. Ici on exige seulement d'avoir agi si le motif existait.
  IF n = 0 THEN
    RAISE NOTICE 'aucune fn_import_* ne portait le motif : rien a faire (deja unifie ?)';
  END IF;

  RAISE NOTICE 'messages d''appartenance unifies sur % fonctions fn_import_*', n;
END $;

-- ── Gardes de fin ───────────────────────────────────────────────────────────
DO $$
DECLARE v_reste text;
BEGIN
  -- Plus aucune fonction exposée ne distingue « existe ailleurs » de
  -- « n'existe pas » par ce motif de message.
  SELECT string_agg(n.nspname||'.'||p.proname, ', ')
    INTO v_reste
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname IN ('public','api')
     AND p.prosecdef
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND p.prosrc ~* 'não pertence|nao pertence|pertence à biblioteca|pertence a biblioteca';

  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'motif « existe mais pas chez vous » subsistant sur : % — rollback', v_reste;
  END IF;

  -- Les deux restent appelables : le refus vit dans le corps, pas dans le droit.
  IF NOT has_function_privilege('authenticated', 'public.fn_painel_get_profile_by_id(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_attach_received_asset_record(bigint, bigint, text, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'EXECUTE perdu : les ecrans casseraient au lieu de refuser — rollback';
  END IF;
END $$;
