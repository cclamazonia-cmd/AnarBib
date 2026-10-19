-- =========================================================================
-- NUMDIF — « Overige bestanden » passe en A + B, et une ressource versée se
-- réaligne sur le cas de son candidat
-- =========================================================================
-- Date     : 2026-10-19
-- Chantier : documents numériques — PDF déjà diffusés en ligne (REGISTRE §47)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Anarchief — ouvrir le lot Overige
-- Ref      : REGISTRE §47 NUMDIF-2, NUMDIF-4, NUMDIF-6 ; migrations
--            20261015182432_numdif_versement_cote_serveur (le versement) et
--            20261016083340_numdif6_la_note_dit_la_validation_par_lot ;
--            supabase/functions/realign-digital-resource/index.ts ;
--            tests/sql/numdif_realignement_tests.sql
--
-- POURQUOI
--   Dans la feuille de lots d'Anarchief.org (15/10/2026), le lot « Overige
--   bestanden (naam niet herkend) » portait la remarque « idem » sans lettre :
--   ses 156 PDF ont été versés en statut_inconnu (restreints, pdf-restrito),
--   la règle v0.1 voulant qu'un lot sans lettre reste restreint. Le 19/10/2026,
--   l'archiviste (J/M) a précisé par mail que « idem » veut dire « même lettre
--   qu'au-dessus » : A + B. La réponse du 19/10, validée par Xavier, s'engage à
--   ouvrir ces fichiers.
--
--   Aucun outil ne changeait la portée d'une ressource DÉJÀ versée : le cas
--   fixe le seau (NUMDIF-2, ingest.fn_numdif_destination) au versement, et
--   rien ensuite. Changer la portée, c'est déplacer le fichier d'un seau à
--   l'autre (pdf-restrito est privé, anarbib-pdf-public est public) : la base
--   seule ne le peut pas.
--
-- CE QUE FAIT LE PAQUET
--   1. Le cas des 156 candidats change (donnée) : diffusion_autorisee, lettre
--      « A + B », remarque « idem » citée et précisée, page de mention
--      « déclaration par lot … précisée le 19/10/2026 » ; une trace dans
--      tool_notes. Les ressources ne bougent PAS ici : elles restent
--      restreintes (le plus prudent) jusqu'à ce que leur fichier soit déplacé.
--   2. public.fn_digital_resource_realign_garde(ressource) — SOUS LE JETON de
--      l'appelant, mêmes règles que la garde du versement : ressource active
--      issue d'un candidat NUMDIF versé, coordination de sa bibliothèque ou
--      administration du réseau, bibliothèque encore détentrice. Rend le seau
--      et le chemin actuels, l'empreinte SHA-256, la destination que fixe le
--      cas, et « aligned » quand il n'y a rien à faire.
--   3. ingest.fn_digital_resource_realign_record(…) — à la CLÉ DE SERVICE
--      SEULE, après la copie par la fonction Edge : revérifie tout (portée,
--      détention, la ressource est encore où la garde l'a vue, seau du cas,
--      même chemin books/<notice>/…, empreinte, objet présent dans le seau de
--      destination), puis met la ressource au cas : seau, portée, type, statut
--      de droits, justification (règle du versement : NUMDIF-6 pour un lot),
--      et garde l'historique dans metadata.realignements.
--   Les deux sens marchent : un retrait à première demande (cas repassé en
--   statut_inconnu) ramène le fichier dans pdf-restrito par le même chemin.
--
-- LA FONCTION EDGE (realign-digital-resource), par ressource : double
--   authentification → garde → lecture du fichier en place + SHA-256 (avant)
--   → copie côté serveur vers le seau du cas, même chemin → lecture de la
--   copie + SHA-256 (après) → enregistrement → effacement de l'original. Un
--   échec avant l'enregistrement efface la copie ; la ressource désigne
--   toujours un objet présent, et la portée ne contredit jamais le seau
--   (fn_healthcheck_digital_resources, point 2).
--
-- CHECKLIST DOCTRINE
--   [x] DEFINER : SET search_path ; REVOKE … FROM PUBLIC, anon, authenticated
--       puis GRANT ciblé (garde : authenticated ; record : service_role seul)
--   [x] Donnée : critère et compte gardés (0 au banc, 156 en production,
--       sinon échec) ; ancre de justification comptée par ligne
--   [x] Aucun verrou exclusif de table (UPDATE de lignes, fonctions neuves)
-- =========================================================================

BEGIN;

-- ── 1. Overige bestanden = A + B (mail de J/M du 19/10/2026) ───────────
DO $overige_a_b$
DECLARE
  c_ancre constant text := 'lettre J/M « — » (15/10/2026) ;';
  v_n int;
  v_sans_ancre int;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE position(c_ancre IN c.justification) = 0)
    INTO v_n, v_sans_ancre
    FROM ingest.digital_candidates c
   WHERE c.source_name = 'Anarchief.org' AND c.status = 'verse' AND c.source_case = 'statut_inconnu'
     AND c.justification LIKE '%lot « Overige bestanden (naam niet herkend) »%';

  IF v_n NOT IN (0, 156) OR v_sans_ancre > 0 THEN
    RAISE EXCEPTION 'Overige A + B : % candidat(s) au critère (0 ou 156 attendus), % sans l''ancre de lettre', v_n, v_sans_ancre;
  END IF;

  UPDATE ingest.digital_candidates c
     SET source_case = 'diffusion_autorisee',
         justification = replace(c.justification, c_ancre,
           'lettre J/M « A + B » (15/10/2026) ; remarque J/M : « idem » = même lettre que le lot au-dessus, '
           || 'précisé par mail de J/M du 19/10/2026 ;'),
         rights_mention = 'idem',
         rights_mention_page = 'déclaration par lot (Rechtenregeling v0.1, lettre J/M du 15/10/2026, précisée le 19/10/2026)',
         tool_notes = coalesce(c.tool_notes, '{}'::jsonb) || jsonb_build_object('reclassement_2026_10_19', jsonb_build_object(
           'de', 'statut_inconnu', 'vers', 'diffusion_autorisee',
           'motif', 'Mail de J/M du 19/10/2026 : « idem » = même lettre qu''au-dessus, donc A + B ; ouverture validée par Xavier (réponse du 19/10/2026, point 4).')),
         updated_at = now()
   WHERE c.source_name = 'Anarchief.org' AND c.status = 'verse' AND c.source_case = 'statut_inconnu'
     AND c.justification LIKE '%lot « Overige bestanden (naam niet herkend) »%';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'Overige A + B : % candidat(s) passé(s) en diffusion_autorisee', v_n;
END
$overige_a_b$;


-- ── 2. La garde, sous le jeton de l'appelant ───────────────────────────
CREATE OR REPLACE FUNCTION public.fn_digital_resource_realign_garde(p_resource_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_r public.book_digital_resources%rowtype;
  v_c ingest.digital_candidates%rowtype;
  v_dest jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Acesso restrito a coordenacao da biblioteca detentora.'
      USING ERRCODE = '42501', HINT = 'error.digital_candidate.coord_only';
  END IF;
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = p_resource_id;
  IF FOUND THEN
    SELECT * INTO v_c FROM ingest.digital_candidates WHERE resource_id = v_r.id AND status = 'verse';
  END IF;
  IF v_r.id IS NULL OR v_c.id IS NULL OR NOT coalesce(v_r.is_active, false) OR v_r.status <> 'active'
     OR NOT (coalesce(public.fn_caller_is_network_admin(), false)
             OR v_c.library_id = ANY (coalesce(public.fn_caller_coordinator_library_ids(), '{}'::uuid[]))) THEN
    RAISE EXCEPTION 'Recurso nao encontrado.' USING ERRCODE = 'P0002', HINT = 'error.digital_candidate.not_found';
  END IF;
  IF NOT ingest.fn_numdif_peut_agir(v_c.library_id, v_c.book_id) THEN
    RAISE EXCEPTION 'A biblioteca nao detem mais esta ficha.' USING ERRCODE = '42501', HINT = 'error.digital_candidate.not_holding';
  END IF;
  v_dest := ingest.fn_numdif_destination(v_c.source_case);

  RETURN jsonb_build_object(
    'resource_id', v_r.id, 'candidate_id', v_c.id, 'book_id', v_r.book_id, 'library_id', v_c.library_id,
    'caller', auth.uid(), 'sha256', v_c.sha256, 'source_case', v_c.source_case,
    'from', jsonb_build_object('bucket', v_r.storage_bucket, 'path', v_r.storage_path),
    'destination', v_dest,
    'aligned', v_r.storage_bucket IS NOT DISTINCT FROM v_dest->>'storage_bucket'
               AND v_r.access_scope IS NOT DISTINCT FROM v_dest->>'access_scope'
               AND v_r.resource_type IS NOT DISTINCT FROM v_dest->>'resource_type'
               AND v_r.rights_status IS NOT DISTINCT FROM v_dest->>'rights_status');
END;
$function$;
COMMENT ON FUNCTION public.fn_digital_resource_realign_garde(bigint) IS
  'NUMDIF (19/10/2026) : la garde du réalignement d''une ressource versée sur le cas de son candidat, sous le jeton de '
  'l''appelant·e, avant tout geste à la clé de service (realign-digital-resource). Mêmes règles que la garde du versement. '
  'Rend seau et chemin actuels, SHA-256, destination du cas, et aligned. Hors de portée : introuvable.';


-- ── 3. L'enregistrement, à la clé de service seule ─────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_digital_resource_realign_record(
  p_resource_id bigint, p_uid uuid, p_from_bucket text, p_from_path text, p_bucket text, p_path text, p_sha256 text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_r public.book_digital_resources%rowtype;
  v_c ingest.digital_candidates%rowtype;
  v_dest jsonb;
  v_lot boolean;
  v_justif text;
BEGIN
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = p_resource_id FOR UPDATE;
  IF FOUND THEN
    SELECT * INTO v_c FROM ingest.digital_candidates WHERE resource_id = v_r.id AND status = 'verse' FOR UPDATE;
  END IF;
  IF v_r.id IS NULL OR v_c.id IS NULL OR NOT coalesce(v_r.is_active, false) OR v_r.status <> 'active' THEN
    RAISE EXCEPTION 'Recurso nao encontrado.' USING ERRCODE = 'P0002', HINT = 'error.digital_candidate.not_found';
  END IF;
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
  -- la ressource est encore là où la garde l'a vue (deux appels sur la même ressource : le second s'arrête ici)
  IF v_r.storage_bucket IS DISTINCT FROM p_from_bucket OR v_r.storage_path IS DISTINCT FROM p_from_path THEN
    RAISE EXCEPTION 'O recurso mudou de lugar desde a guarda.' USING ERRCODE = '55000', HINT = 'error.digital_candidate.wrong_bucket';
  END IF;
  v_dest := ingest.fn_numdif_destination(v_c.source_case);
  IF v_dest IS NULL OR p_bucket IS DISTINCT FROM v_dest->>'storage_bucket' THEN
    RAISE EXCEPTION 'Balde errado para o caso de origem.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.wrong_bucket';
  END IF;
  IF p_path IS DISTINCT FROM p_from_path OR p_path NOT LIKE 'books/' || v_c.book_id || '/%' OR p_path LIKE 'http%' OR p_path LIKE '%..%' THEN
    RAISE EXCEPTION 'Caminho de armazenamento invalido.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.bad_path';
  END IF;
  IF coalesce(lower(p_sha256), '') !~ '^[0-9a-f]{64}$' OR lower(p_sha256) IS DISTINCT FROM v_c.sha256
     OR (v_r.metadata ? 'sha256' AND lower(p_sha256) IS DISTINCT FROM v_r.metadata->>'sha256') THEN
    RAISE EXCEPTION 'A impressao SHA-256 difere da validada.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.fingerprint_mismatch';
  END IF;
  IF NOT private.fn_objet_stocke_existe(p_bucket, p_path) THEN
    RAISE EXCEPTION 'Arquivo ausente do armazenamento.' USING ERRCODE = 'P0002', HINT = 'error.digital_candidate.object_missing';
  END IF;

  -- même règle que le versement (fn_digital_candidate_deposit_record, NUMDIF-6)
  v_lot := coalesce(v_c.rights_mention_page LIKE 'déclaration par lot%', false)
           OR coalesce(v_c.justification LIKE '%NUMDIF-6%validation par lot%', false);
  v_justif := CASE WHEN v_lot AND v_c.source_case IN ('diffusion_autorisee', 'anti_copyright')
                   THEN v_c.justification || ' Declaração de direitos por lote do arquivista (Rechtenregeling v0.1).'
                   WHEN v_c.source_case IN ('diffusion_autorisee', 'anti_copyright')
                   THEN v_c.justification || ' Menção impressa na edição, p. ' || v_c.rights_mention_page
                        || ' : «' || v_c.rights_mention || '».'
                   ELSE v_c.justification END;

  UPDATE public.book_digital_resources r
     SET storage_bucket = p_bucket,
         storage_path = p_path,
         access_scope = v_dest->>'access_scope',
         resource_type = v_dest->>'resource_type',
         rights_status = v_dest->>'rights_status',
         rights_justification = v_justif,
         metadata = coalesce(r.metadata, '{}'::jsonb)
           || jsonb_build_object('source_case', v_c.source_case,
                'realignements', coalesce(r.metadata->'realignements', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
                  'le', now(), 'par', p_uid, 'source_case', v_c.source_case,
                  'de', jsonb_build_object('bucket', p_from_bucket, 'path', p_from_path, 'access_scope', v_r.access_scope),
                  'vers', jsonb_build_object('bucket', p_bucket, 'path', p_path, 'access_scope', v_dest->>'access_scope'),
                  'sha256', lower(p_sha256),
                  'via', 'edge_function:realign-digital-resource')))
   WHERE r.id = v_r.id;

  RETURN jsonb_build_object('resource_id', v_r.id, 'candidate_id', v_c.id,
                            'storage_bucket', p_bucket, 'storage_path', p_path,
                            'access_scope', v_dest->>'access_scope', 'rights_status', v_dest->>'rights_status');
END;
$function$;
COMMENT ON FUNCTION ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text) IS
  'NUMDIF (19/10/2026) : enregistre le réalignement d''une ressource versée sur le cas de son candidat, après la copie du '
  'fichier par realign-digital-resource — revérifie portée, détention, place actuelle, seau du cas, chemin, empreinte, '
  'présence de l''objet ; met seau, portée, type, droits et justification au cas ; historique dans metadata.realignements. '
  'Clé de service SEULE.';


-- ── 4. Droits ──────────────────────────────────────────────────────────
REVOKE EXECUTE ON FUNCTION public.fn_digital_resource_realign_garde(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_digital_resource_realign_garde(bigint) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text) TO service_role;


-- ── 5. Vérification structurelle ───────────────────────────────────────
DO $realign_verif$
DECLARE
  v_e text := '';
  c_garde constant text := 'public.fn_digital_resource_realign_garde(bigint)';
  c_record constant text := 'ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text)';
BEGIN
  IF NOT has_function_privilege('authenticated', c_garde, 'EXECUTE') OR has_function_privilege('anon', c_garde, 'EXECUTE')
     OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a WHERE p.oid = c_garde::regprocedure AND a.grantee = 0) THEN
    v_e := v_e || ' garde';
  END IF;
  IF has_function_privilege('authenticated', c_record, 'EXECUTE') OR has_function_privilege('anon', c_record, 'EXECUTE')
     OR NOT has_function_privilege('service_role', c_record, 'EXECUTE')
     OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a WHERE p.oid = c_record::regprocedure AND a.grantee = 0) THEN
    v_e := v_e || ' record';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid IN (c_garde::regprocedure, c_record::regprocedure)
                AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
    v_e := v_e || ' definer';
  END IF;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'NUMDIF réalignement : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'NUMDIF réalignement : vérifications OK';
END
$realign_verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé (les fonctions ; la donnée se défait en sens inverse depuis
-- tool_notes->'reclassement_2026_10_19', et les fichiers déjà déplacés se
-- ramènent par la même fonction Edge une fois le cas remis) :
-- BEGIN;
--   DROP FUNCTION IF EXISTS ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text);
--   DROP FUNCTION IF EXISTS public.fn_digital_resource_realign_garde(bigint);
-- COMMIT;
-- =========================================================================
