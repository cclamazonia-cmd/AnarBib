-- =========================================================================
-- Paquet NUMDIF-D16 — verser un candidat validé côté serveur, sans clé
-- manipulée par une personne
-- =========================================================================
-- Date     : 2026-10-15
-- Chantier : documents numériques — PDF déjà diffusés en ligne (REGISTRE §47)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : File de candidats PDF
-- Ref      : backlog v34 D16 ; REGISTRE §47 NUMDIF-4 (et NUMDIF-1, 2, 3) ;
--            migration 20261015172008 (la file, D13) ;
--            supabase/functions/deposit-digital-candidate/index.ts
--
-- POURQUOI
--   Le 14/10, les deux Reclus ont été versés par une commande lancée à la main
--   dans WSL, avec la clé de service (la clé legacy refusée, seule sb_secret
--   dans l'en-tête apikey passait) ; puis la ligne book_digital_resources a
--   été écrite à la main. NUMDIF-4 : le versement se fait côté serveur, par une
--   fonction Edge appelée avec le jeton de la coordination, qui télécharge
--   elle-même l'URL validée et vérifie l'empreinte figée à la validation.
--
-- CONSIGNES DE XAVIER (15/10, en cours de lot) : le versement tourne PAR LOTS,
-- AVEC REPRISE (la fonction Edge prend une liste et rend ce qui reste ; l'état
-- vit en base, un lot interrompu se relance) ; il accepte une source qui ne
-- donne qu'un SHA-1 (MediaWiki : Anarchief) et calcule le SHA-256 au premier
-- téléchargement (section 0, et l'enregistrement). Capacité : 35 Go utilisés,
-- 52 avec Anarchief, dans le palier — le fichier passe en flux jusqu'à 500 Mo.
--
-- CE QUE FAIT LE PAQUET — la colonne sha1 (section 0), puis trois fonctions,
-- dans l'ordre où la fonction Edge les appelle :
--   1. public.fn_digital_candidate_deposit_garde(candidat) — SOUS LE JETON de
--      l'appelant, AVANT tout geste à la clé de service : coordination de la
--      bibliothèque du candidat (ou administration du réseau), bibliothèque
--      encore détentrice, candidat « à verser ». Rend ce qu'il faut pour
--      télécharger et vérifier : URL du fichier, empreinte, taille, seau.
--      Hors de portée = « introuvable » (pas d'oracle sur un identifiant).
--   2. public.fn_digital_candidate_deposit_failed(candidat, raison) — sous le
--      jeton : le refus se DIT, et il se garde (deposit_error,
--      deposit_attempted_at) : empreinte qui diffère, fichier injoignable,
--      trop lourd, pas un PDF. Le candidat reste « à verser » : la
--      coordination le rejette ou le refait chercher.
--   3. ingest.fn_digital_candidate_deposit_record(candidat, personne, seau,
--      chemin, empreinte, taille) — à la CLÉ DE SERVICE SEULE, après le dépôt
--      dans le stockage : revérifie tout (statut, portée de la personne,
--      détention, seau que fixe le cas, chemin books/<notice>/…, empreinte
--      égale à celle de la validation, objet présent dans le stockage), crée
--      la ressource avec les champs des ressources 77 et 78 (source,
--      attribution, justification, bibliographic_match_validated, métadonnées
--      sha256/page_count/source_file/deposited_via…), et passe le candidat à
--      « versé ». Fermée à authenticated À DESSEIN : les bibliothécaires
--      peuvent écrire dans pdf-restrito et anarbib-pdf-public (politiques
--      *_librarians_insert) ; si cette fonction leur était ouverte, un fichier
--      déposé à la main se ferait enregistrer sans que personne n'en ait
--      comparé l'empreinte.
--
-- NUMDIF-3, au gabarit de D17 (20261015180042, appliquée avant ce paquet) : la
-- ressource porte DEUX adresses — source_url = le fichier (provenance, que
-- get_accessible_digital_asset_by_id_v2 ne rend jamais pour une ressource
-- restreinte stockée) et source_page_url = la page qui le présente.
--
-- CHECKLIST DOCTRINE
--   [x] Fonctions DEFINER : SET search_path ; REVOKE EXECUTE ... FROM PUBLIC,
--       anon (portes) ou FROM PUBLIC, anon, authenticated (record) ; GRANT ciblé
--   [x] DO block de vérification STRUCTUREL ; le fonctionnel vit dans
--       tests/sql/numdif_versement_tests.sql
-- =========================================================================

BEGIN;

-- ── 0. Une source qui ne donne qu'un SHA-1 (consigne de Xavier, 15/10) ──
-- MediaWiki (Anarchief, Wikisource, Commons) publie le SHA-1 de ses fichiers,
-- pas le SHA-256. Un candidat peut donc arriver avec le seul SHA-1 : il se
-- valide, et le versement compare le SHA-1 puis retient le SHA-256 calculé à
-- ce premier téléchargement (section 3). La file de D13 l'apprend ici.
ALTER TABLE ingest.digital_candidates ADD COLUMN IF NOT EXISTS sha1 text;
ALTER TABLE ingest.digital_candidates DROP CONSTRAINT IF EXISTS digital_candidates_sha1_check;
ALTER TABLE ingest.digital_candidates ADD CONSTRAINT digital_candidates_sha1_check
  CHECK (sha1 IS NULL OR sha1 ~ '^[0-9a-f]{40}$');
ALTER TABLE ingest.digital_candidates DROP CONSTRAINT IF EXISTS digital_candidates_meme_edition;
ALTER TABLE ingest.digital_candidates ADD CONSTRAINT digital_candidates_meme_edition
  CHECK (status NOT IN ('valide', 'verse')
         OR (verdict = 'meme_edition' AND source_case IS NOT NULL AND (sha256 IS NOT NULL OR sha1 IS NOT NULL)
             AND nullif(btrim(justification), '') IS NOT NULL));
ALTER TABLE ingest.digital_candidates DROP CONSTRAINT IF EXISTS digital_candidates_verse_sha256;
ALTER TABLE ingest.digital_candidates ADD CONSTRAINT digital_candidates_verse_sha256
  CHECK (status <> 'verse' OR sha256 IS NOT NULL);
COMMENT ON COLUMN ingest.digital_candidates.sha1 IS
  'L''empreinte SHA-1 que donne la source quand elle ne donne qu''elle (MediaWiki). Le versement la compare, puis retient le '
  'SHA-256 calculé au premier téléchargement : un candidat versé a toujours son SHA-256.';

-- Proposer et décider l'apprennent par substitution VÉRIFIÉE de leur définition
-- vivante (D13, 20261015172008) : une ancre absente fait échouer la migration.
CREATE OR REPLACE FUNCTION pg_temp.numdif_remplacer(p_def text, p_old text, p_new text)
 RETURNS text LANGUAGE plpgsql AS $r$
BEGIN
  IF position(p_old IN p_def) = 0 THEN
    RAISE EXCEPTION 'NUMDIF-D16 : ancre absente : %', left(p_old, 90);
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$r$;

DO $numdif_d16_sha1$
DECLARE v text;
BEGIN
  v := pg_get_functiondef('public.fn_digital_candidates_propose(uuid, jsonb)'::regprocedure);
  v := pg_temp.numdif_remplacer(v, $a$sha256 = lower(nullif(btrim(v_c->>'sha256'), '')),$a$,
         $a$sha256 = lower(nullif(btrim(v_c->>'sha256'), '')),
            sha1 = lower(nullif(btrim(v_c->>'sha1'), '')),$a$);
  v := pg_temp.numdif_remplacer(v, $a$tool_notes, sha256, file_size_bytes,$a$, $a$tool_notes, sha256, sha1, file_size_bytes,$a$);
  v := pg_temp.numdif_remplacer(v, $a$lower(nullif(btrim(v_c->>'sha256'), '')), nullif(v_c->>'file_size_bytes', '')::bigint,$a$,
         $a$lower(nullif(btrim(v_c->>'sha256'), '')), lower(nullif(btrim(v_c->>'sha1'), '')), nullif(v_c->>'file_size_bytes', '')::bigint,$a$);
  EXECUTE v;

  v := pg_get_functiondef('public.fn_digital_candidate_decide(bigint, text, text, text, text, text, text, text, text)'::regprocedure);
  v := pg_temp.numdif_remplacer(v, $a$IF v_c.sha256 IS NULL THEN$a$, $a$IF v_c.sha256 IS NULL AND v_c.sha1 IS NULL THEN$a$);
  v := pg_temp.numdif_remplacer(v, $a$'Candidato sem impressao SHA-256.'$a$, $a$'Candidato sem impressao SHA-256 nem SHA-1.'$a$);
  EXECUTE v;
END
$numdif_d16_sha1$;

-- ── 1. La garde, sous le jeton de l'appelant ───────────────────────────
CREATE OR REPLACE FUNCTION public.fn_digital_candidate_deposit_garde(p_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_c ingest.digital_candidates%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Acesso restrito a coordenacao da biblioteca detentora.'
      USING ERRCODE = '42501', HINT = 'error.digital_candidate.coord_only';
  END IF;
  SELECT * INTO v_c FROM ingest.digital_candidates WHERE id = p_id;
  IF NOT FOUND OR NOT (coalesce(public.fn_caller_is_network_admin(), false)
                       OR v_c.library_id = ANY (coalesce(public.fn_caller_coordinator_library_ids(), '{}'::uuid[]))) THEN
    RAISE EXCEPTION 'Candidato nao encontrado.' USING ERRCODE = 'P0002', HINT = 'error.digital_candidate.not_found';
  END IF;
  IF NOT ingest.fn_numdif_peut_agir(v_c.library_id, v_c.book_id) THEN
    RAISE EXCEPTION 'A biblioteca nao detem mais esta ficha.' USING ERRCODE = '42501', HINT = 'error.digital_candidate.not_holding';
  END IF;
  IF v_c.status = 'verse' THEN
    RAISE EXCEPTION 'Candidato ja enviado.' USING ERRCODE = '55000', HINT = 'error.digital_candidate.already_deposited';
  END IF;
  IF v_c.status <> 'valide' THEN
    RAISE EXCEPTION 'So um candidato validado se envia.' USING ERRCODE = '55000', HINT = 'error.digital_candidate.not_validated';
  END IF;

  RETURN jsonb_build_object(
    'id', v_c.id, 'book_id', v_c.book_id, 'library_id', v_c.library_id, 'caller', auth.uid(),
    'file_url', v_c.file_url, 'sha256', v_c.sha256, 'sha1', v_c.sha1, 'file_size_bytes', v_c.file_size_bytes,
    'original_filename', v_c.original_filename,
    'destination', ingest.fn_numdif_destination(v_c.source_case));
END;
$function$;
COMMENT ON FUNCTION public.fn_digital_candidate_deposit_garde(bigint) IS
  'NUMDIF-D16 (15/10/2026, NUMDIF-4) : la garde du versement, sous le jeton de l''appelant·e, avant tout geste à la clé de '
  'service (deposit-digital-candidate). Coordination de la bibliothèque du candidat ou administration du réseau, bibliothèque '
  'encore détentrice, candidat validé. Rend URL du fichier, empreinte, taille, destination. Hors de portée : introuvable.';


-- ── 2. Le refus se dit, et se garde ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_digital_candidate_deposit_failed(p_id bigint, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_c ingest.digital_candidates%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Acesso restrito a coordenacao da biblioteca detentora.'
      USING ERRCODE = '42501', HINT = 'error.digital_candidate.coord_only';
  END IF;
  SELECT * INTO v_c FROM ingest.digital_candidates WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR NOT (coalesce(public.fn_caller_is_network_admin(), false)
                       OR v_c.library_id = ANY (coalesce(public.fn_caller_coordinator_library_ids(), '{}'::uuid[]))) THEN
    RAISE EXCEPTION 'Candidato nao encontrado.' USING ERRCODE = 'P0002', HINT = 'error.digital_candidate.not_found';
  END IF;
  IF v_c.status <> 'valide' THEN
    RAISE EXCEPTION 'So um candidato validado se envia.' USING ERRCODE = '55000', HINT = 'error.digital_candidate.not_validated';
  END IF;
  UPDATE ingest.digital_candidates
     SET deposit_error = left(coalesce(nullif(btrim(p_reason), ''), 'echec'), 500),
         deposit_attempted_at = now(), updated_at = now()
   WHERE id = p_id;
  RETURN jsonb_build_object('id', p_id, 'status', v_c.status, 'deposit_error', left(coalesce(nullif(btrim(p_reason), ''), 'echec'), 500));
END;
$function$;
COMMENT ON FUNCTION public.fn_digital_candidate_deposit_failed(bigint, text) IS
  'NUMDIF-D16 (15/10/2026) : note le refus d''un versement (empreinte qui diffère, fichier injoignable, trop lourd, pas un PDF) '
  'sur le candidat, qui reste « à verser ». Même portée que la garde. Appelée par deposit-digital-candidate sous le jeton.';


-- ── 3. L'enregistrement, à la clé de service seule ─────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_digital_candidate_deposit_record(
  p_id bigint, p_uid uuid, p_bucket text, p_path text, p_sha256 text, p_sha1 text, p_size bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_c ingest.digital_candidates%rowtype;
  v_b public.books%rowtype;
  v_dest jsonb;
  v_edition text;
  v_justif text;
  v_lang text;
  v_res bigint;
BEGIN
  SELECT * INTO v_c FROM ingest.digital_candidates WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Candidato nao encontrado.' USING ERRCODE = 'P0002', HINT = 'error.digital_candidate.not_found';
  END IF;
  IF v_c.status <> 'valide' THEN
    RAISE EXCEPTION 'So um candidato validado se envia (%).', v_c.status USING ERRCODE = '55000', HINT = 'error.digital_candidate.not_validated';
  END IF;
  -- la personne qui a demandé le versement : coordination de la bibliothèque, ou administration du réseau
  IF p_uid IS NULL OR NOT (
       EXISTS (SELECT 1 FROM public.network_administrators a WHERE a.user_id = p_uid AND a.status = 'active')
       OR EXISTS (SELECT 1 FROM public.user_library_memberships m
                   WHERE m.user_id = p_uid AND m.library_id = v_c.library_id AND m.status = 'active'
                     AND m.role IN ('coordenador', 'administrador'))) THEN
    RAISE EXCEPTION 'Acesso restrito a coordenacao da biblioteca detentora.' USING ERRCODE = '42501', HINT = 'error.digital_candidate.coord_only';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = v_c.book_id AND h.library_id = v_c.library_id) THEN
    RAISE EXCEPTION 'A biblioteca nao detem mais esta ficha.' USING ERRCODE = '42501', HINT = 'error.digital_candidate.not_holding';
  END IF;
  -- NUMDIF-4 : le fichier versé est celui qu'on a regardé — SHA-256 s'il est
  -- connu ; sinon le SHA-1 de la source (MediaWiki), et le SHA-256 calculé à ce
  -- premier téléchargement est retenu.
  IF coalesce(lower(p_sha256), '') !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'Impressao SHA-256 do arquivo ausente.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.fingerprint_mismatch';
  END IF;
  IF v_c.sha256 IS NOT NULL THEN
    IF lower(p_sha256) IS DISTINCT FROM v_c.sha256 THEN
      RAISE EXCEPTION 'A impressao SHA-256 difere da validada.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.fingerprint_mismatch';
    END IF;
  ELSIF v_c.sha1 IS NOT NULL THEN
    IF lower(coalesce(p_sha1, '')) IS DISTINCT FROM v_c.sha1 THEN
      RAISE EXCEPTION 'A impressao SHA-1 difere da validada.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.fingerprint_mismatch';
    END IF;
    UPDATE ingest.digital_candidates SET sha256 = lower(p_sha256), updated_at = now() WHERE id = p_id;
    v_c.sha256 := lower(p_sha256);
  ELSE
    RAISE EXCEPTION 'Candidato sem impressao SHA-256 nem SHA-1.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.no_fingerprint';
  END IF;
  v_dest := ingest.fn_numdif_destination(v_c.source_case);
  IF v_dest IS NULL OR p_bucket IS DISTINCT FROM v_dest->>'storage_bucket' THEN
    RAISE EXCEPTION 'Balde errado para o caso de origem.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.wrong_bucket';
  END IF;
  IF p_path IS NULL OR p_path NOT LIKE 'books/' || v_c.book_id || '/%' OR p_path LIKE 'http%' OR p_path LIKE '%..%' THEN
    RAISE EXCEPTION 'Caminho de armazenamento invalido.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.bad_path';
  END IF;
  IF NOT private.fn_objet_stocke_existe(p_bucket, p_path) THEN
    RAISE EXCEPTION 'Arquivo ausente do armazenamento.' USING ERRCODE = 'P0002', HINT = 'error.digital_candidate.object_missing';
  END IF;

  SELECT * INTO v_b FROM public.books WHERE id = v_c.book_id;
  v_edition := nullif(concat_ws(', ', v_c.found_publisher, v_c.found_place, v_c.found_year), '');
  v_justif := CASE WHEN v_c.source_case IN ('diffusion_autorisee', 'anti_copyright')
                   THEN v_c.justification || ' Menção impressa na edição, p. ' || v_c.rights_mention_page
                        || ' : «' || v_c.rights_mention || '».'
                   ELSE v_c.justification END;
  v_lang := CASE WHEN v_b.idioma ~ '^[a-z]{2,3}(-[A-Z]{2})?$' THEN v_b.idioma END;

  INSERT INTO public.book_digital_resources (
    book_id, resource_type, usage_type, access_scope, status, is_active, is_primary, mime_type,
    label, notes, metadata, source_url, source_page_url, source_name, attribution_text,
    rights_status, rights_justification, bibliographic_match_validated,
    storage_bucket, storage_path, language_code, activated_at)
  VALUES (
    v_c.book_id, v_dest->>'resource_type', 'leitura_online', v_dest->>'access_scope', 'active', true,
    NOT EXISTS (SELECT 1 FROM public.book_digital_resources r
                 WHERE r.book_id = v_c.book_id AND r.is_primary AND r.is_active AND r.status = 'active'),
    'application/pdf',
    left(v_b.titulo || coalesce(' — ' || v_edition, '') || ' (fac-símile)', 300),
    'Fac-símile da edição da ficha, verificado na folha de rosto'
      || coalesce(' (p. ' || v_c.title_page_number || ' do arquivo)', '')
      || coalesce(' : ' || v_edition, '') || '. Candidato NUMDIF n.º ' || v_c.id
      || ', validado pela coordenação da biblioteca detentora em ' || to_char(v_c.decided_at AT TIME ZONE 'UTC', 'DD/MM/YYYY') || '.',
    jsonb_strip_nulls(jsonb_build_object(
      'sha256', v_c.sha256, 'sha1', coalesce(v_c.sha1, lower(p_sha1)),
      'page_count', v_c.page_count, 'source_file', v_c.original_filename,
      'file_size_bytes', coalesce(p_size, v_c.file_size_bytes), 'source_identifier', v_c.source_identifier,
      'deposited_via', 'edge_function:deposit-digital-candidate', 'deposit_session', 'File de candidats PDF (NUMDIF)',
      'numdif_candidate_id', v_c.id, 'source_case', v_c.source_case)),
    -- NUMDIF-3 (D17) : le fichier en provenance, la page à montrer
    v_c.file_url, v_c.page_url,
    v_c.source_name,
    'Fonte: ' || coalesce(v_c.source_name, '—') || coalesce(' (identificador ' || v_c.source_identifier || ')', ''),
    v_dest->>'rights_status', v_justif, true,
    p_bucket, p_path, v_lang, now())
  RETURNING id INTO v_res;

  UPDATE ingest.digital_candidates
     SET status = 'verse', resource_id = v_res, deposited_by = p_uid, deposited_at = now(),
         deposit_error = NULL, deposit_attempted_at = now(), updated_at = now()
   WHERE id = p_id;

  RETURN jsonb_build_object('id', p_id, 'status', 'verse', 'resource_id', v_res,
                            'storage_bucket', p_bucket, 'storage_path', p_path,
                            'access_scope', v_dest->>'access_scope');
END;
$function$;
COMMENT ON FUNCTION ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint) IS
  'NUMDIF-D16 (15/10/2026, NUMDIF-4) : enregistre le versement d''un candidat validé, après dépôt dans le stockage par '
  'deposit-digital-candidate — revérifie statut, portée de la personne, détention, seau du cas, chemin, empreinte, présence de '
  'l''objet ; crée la ressource (champs des ressources 77 et 78) ; candidat « versé ». Clé de service SEULE : un fichier '
  'déposé à la main par un·e bibliothécaire ne se fait pas enregistrer sans comparaison d''empreinte.';


-- ── 4. Droits ──────────────────────────────────────────────────────────
REVOKE EXECUTE ON FUNCTION public.fn_digital_candidate_deposit_garde(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_digital_candidate_deposit_garde(bigint) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_digital_candidate_deposit_failed(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_digital_candidate_deposit_failed(bigint, text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint) TO service_role;


-- ── 5. Vérification structurelle ───────────────────────────────────────
DO $numdif_d16_verif$
DECLARE
  v_e text := '';
  v_f text;
BEGIN
  FOREACH v_f IN ARRAY ARRAY['public.fn_digital_candidate_deposit_garde(bigint)', 'public.fn_digital_candidate_deposit_failed(bigint, text)'] LOOP
    IF NOT has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' porte(' || v_f || ')';
    END IF;
  END LOOP;
  v_f := 'ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint)';
  IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
     OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
     OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
    v_e := v_e || ' record';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p
              WHERE p.oid IN ('public.fn_digital_candidate_deposit_garde(bigint)'::regprocedure,
                              'public.fn_digital_candidate_deposit_failed(bigint, text)'::regprocedure,
                              'ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint)'::regprocedure)
                AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
    v_e := v_e || ' definer';
  END IF;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'NUMDIF-D16 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'NUMDIF-D16 : vérifications OK';
END
$numdif_d16_verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé :
-- BEGIN;
--   DROP FUNCTION IF EXISTS ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint);
--   DROP FUNCTION IF EXISTS public.fn_digital_candidate_deposit_failed(bigint, text);
--   DROP FUNCTION IF EXISTS public.fn_digital_candidate_deposit_garde(bigint);
-- COMMIT;
-- =========================================================================
