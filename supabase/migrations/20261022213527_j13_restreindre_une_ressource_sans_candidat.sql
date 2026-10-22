-- =========================================================================
-- J13 — restreindre une ressource publique qui n'est pas passée par la file
-- NUMDIF (SNI 1994, Díaz 1978)
-- =========================================================================
-- Date     : 2026-10-22
-- Chantier : documents numériques — REGISTRE §47, NUMDIF-2 amendé le 22/10
-- Auteur   : Claude (assistant·e), pour la coordination
-- Ref      : 20261019145347_numdif_overige_a_b_et_realignement (garde,
--            enregistrement, fonction Edge realign-digital-resource)
--
-- POURQUOI
--   Relues contre NUMDIF-2 amendé, deux ressources « domaine public » ne le
--   sont pas et n'ont aucun candidat NUMDIF : la ressource 58 (document du
--   SNI sur le mouvement anarcho-punk de Belém, 1994, justification « à
--   vérifier ») et la ressource 65 (Carlos Díaz, « 16 Tesis sobre
--   Anarquismo », 1978, †2021, aucune justification). Décision de Xavier du
--   22/10/2026 : les restreindre, par la fonction de réalignement étendue.
--   La fonction ne savait déplacer que des ressources issues d'un candidat :
--   c'est le cas du candidat qui fixe le seau, et c'est son empreinte qui
--   prouve que le fichier n'a pas changé.
--
-- CE QUE FAIT LE PAQUET
--   1. La décision s'écrit DANS LA RESSOURCE : `metadata.restriction_demandee`
--      { le, par, motif, item }. Sans elle, rien ne change pour une ressource
--      sans candidat (elle reste introuvable pour la fonction).
--   2. La garde (`public.fn_digital_resource_realign_garde`) et
--      l'enregistrement (`ingest.fn_digital_resource_realign_record`) gagnent
--      un chemin « sans candidat » : ressource active, SANS candidat versé,
--      portant `restriction_demandee` ; appelant = administration du réseau
--      SEULE ; destination = celle du cas statut_inconnu (pdf-restrito,
--      conta_ativa, sob_direitos) — le seul sens permis est public →
--      restreint. Sans empreinte enregistrée, la fonction Edge prend celle du
--      fichier en place comme référence et la copie doit lui être identique ;
--      l'enregistrement la garde dans `metadata.sha256`, avec `restriction_faite` ;
--      la décision reste écrite, et la garde répond ensuite « aligned » (relancer
--      ne refait rien).
--   Patch par remplacement exact dans la définition RÉELLE (pg_get_functiondef),
--   une occurrence par motif, sinon échec : le chemin des candidats ne change
--   pas d'un caractère.
--   3. Les ressources 58 et 65 reçoivent la décision (compte 0 au banc, 2 en
--      production). Elles ne bougent pas ici : la fonction Edge les déplace.
--
-- Banc : tests/sql/numdif_restreindre_sans_candidat_tests.sql.
-- =========================================================================

BEGIN;

DO $patch$
DECLARE
  v_def text;
  v_motif text;
  v_neuf text;
BEGIN
  -- 1. la garde
  v_def := pg_get_functiondef('public.fn_digital_resource_realign_garde(bigint)'::regprocedure);
  v_motif := E'  IF v_r.id IS NULL OR v_c.id IS NULL OR NOT coalesce(v_r.is_active, false) OR v_r.status <> ''active''\n     OR NOT (coalesce(public.fn_caller_is_network_admin(), false)';
  IF (length(v_def) - length(replace(v_def, v_motif, ''))) / length(v_motif) <> 1 THEN
    RAISE EXCEPTION 'J13 garde : motif introuvable ou ambigu';
  END IF;
  v_neuf := E'  -- J13 (22/10/2026) : une ressource SANS candidat dont la restriction est décidée\n'
    || E'  -- (metadata.restriction_demandee) ; administration du réseau seule, vers le restreint seulement.\n'
    || E'  IF v_r.id IS NOT NULL AND v_c.id IS NULL AND coalesce(v_r.metadata, ''{}''::jsonb) ? ''restriction_demandee'' THEN\n'
    || E'    IF NOT coalesce(v_r.is_active, false) OR v_r.status <> ''active'' OR NOT coalesce(public.fn_caller_is_network_admin(), false) THEN\n'
    || E'      RAISE EXCEPTION ''Recurso nao encontrado.'' USING ERRCODE = ''P0002'', HINT = ''error.digital_candidate.not_found'';\n'
    || E'    END IF;\n'
    || E'    v_dest := ingest.fn_numdif_destination(''statut_inconnu'');\n'
    || E'    RETURN jsonb_build_object(\n'
    || E'      ''resource_id'', v_r.id, ''candidate_id'', NULL, ''book_id'', v_r.book_id, ''library_id'', NULL,\n'
    || E'      ''caller'', auth.uid(), ''sha256'', v_r.metadata->>''sha256'', ''source_case'', ''statut_inconnu'', ''sans_candidat'', true,\n'
    || E'      ''from'', jsonb_build_object(''bucket'', v_r.storage_bucket, ''path'', v_r.storage_path),\n'
    || E'      ''destination'', v_dest,\n'
    || E'      ''aligned'', v_r.storage_bucket IS NOT DISTINCT FROM v_dest->>''storage_bucket''\n'
    || E'                 AND v_r.access_scope IS NOT DISTINCT FROM v_dest->>''access_scope''\n'
    || E'                 AND v_r.resource_type IS NOT DISTINCT FROM v_dest->>''resource_type''\n'
    || E'                 AND v_r.rights_status IS NOT DISTINCT FROM v_dest->>''rights_status'');\n'
    || E'  END IF;\n'
    || v_motif;
  EXECUTE replace(v_def, v_motif, v_neuf);

  -- 2. l'enregistrement
  v_def := pg_get_functiondef('ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text)'::regprocedure);
  v_motif := E'  IF v_r.id IS NULL OR v_c.id IS NULL OR NOT coalesce(v_r.is_active, false) OR v_r.status <> ''active'' THEN\n    RAISE EXCEPTION ''Recurso nao encontrado.''';
  IF (length(v_def) - length(replace(v_def, v_motif, ''))) / length(v_motif) <> 1 THEN
    RAISE EXCEPTION 'J13 enregistrement : motif introuvable ou ambigu';
  END IF;
  v_neuf := E'  -- J13 (22/10/2026) : le chemin SANS candidat, vers le restreint seulement (voir la garde)\n'
    || E'  IF v_r.id IS NOT NULL AND v_c.id IS NULL AND coalesce(v_r.metadata, ''{}''::jsonb) ? ''restriction_demandee'' THEN\n'
    || E'    IF NOT coalesce(v_r.is_active, false) OR v_r.status <> ''active'' THEN\n'
    || E'      RAISE EXCEPTION ''Recurso nao encontrado.'' USING ERRCODE = ''P0002'', HINT = ''error.digital_candidate.not_found'';\n'
    || E'    END IF;\n'
    || E'    IF p_uid IS NULL OR NOT EXISTS (SELECT 1 FROM public.network_administrators a WHERE a.user_id = p_uid AND a.status = ''active'') THEN\n'
    || E'      RAISE EXCEPTION ''Acesso restrito a administracao da rede.'' USING ERRCODE = ''42501'', HINT = ''error.digital_candidate.coord_only'';\n'
    || E'    END IF;\n'
    || E'    IF v_r.storage_bucket IS DISTINCT FROM p_from_bucket OR v_r.storage_path IS DISTINCT FROM p_from_path THEN\n'
    || E'      RAISE EXCEPTION ''O recurso mudou de lugar desde a guarda.'' USING ERRCODE = ''55000'', HINT = ''error.digital_candidate.wrong_bucket'';\n'
    || E'    END IF;\n'
    || E'    v_dest := ingest.fn_numdif_destination(''statut_inconnu'');\n'
    || E'    IF p_bucket IS DISTINCT FROM v_dest->>''storage_bucket'' THEN\n'
    || E'      RAISE EXCEPTION ''Balde errado para o caso de origem.'' USING ERRCODE = ''22023'', HINT = ''error.digital_candidate.wrong_bucket'';\n'
    || E'    END IF;\n'
    || E'    IF p_path IS DISTINCT FROM p_from_path OR p_path LIKE ''http%'' OR p_path LIKE ''%..%'' THEN\n'
    || E'      RAISE EXCEPTION ''Caminho de armazenamento invalido.'' USING ERRCODE = ''22023'', HINT = ''error.digital_candidate.bad_path'';\n'
    || E'    END IF;\n'
    || E'    IF coalesce(lower(p_sha256), '''') !~ ''^[0-9a-f]{64}$''\n'
    || E'       OR (v_r.metadata ? ''sha256'' AND lower(p_sha256) IS DISTINCT FROM v_r.metadata->>''sha256'') THEN\n'
    || E'      RAISE EXCEPTION ''A impressao SHA-256 difere da validada.'' USING ERRCODE = ''22023'', HINT = ''error.digital_candidate.fingerprint_mismatch'';\n'
    || E'    END IF;\n'
    || E'    IF NOT private.fn_objet_stocke_existe(p_bucket, p_path) THEN\n'
    || E'      RAISE EXCEPTION ''Arquivo ausente do armazenamento.'' USING ERRCODE = ''P0002'', HINT = ''error.digital_candidate.object_missing'';\n'
    || E'    END IF;\n'
    || E'    UPDATE public.book_digital_resources r\n'
    || E'       SET storage_bucket = p_bucket,\n'
    || E'           storage_path = p_path,\n'
    || E'           access_scope = v_dest->>''access_scope'',\n'
    || E'           resource_type = v_dest->>''resource_type'',\n'
    || E'           rights_status = v_dest->>''rights_status'',\n'
    || E'           rights_justification = coalesce(nullif(r.rights_justification, '''') || '' — '', '''')\n'
    || E'             || ''Restreint le '' || to_char(now() AT TIME ZONE ''UTC'', ''DD/MM/YYYY'') || '' : ''\n'
    || E'             || coalesce(v_r.metadata->''restriction_demandee''->>''motif'', ''décision de l''''administration du réseau'') || ''.'',\n'
    || E'           metadata = coalesce(r.metadata, ''{}''::jsonb)\n'
    || E'             || jsonb_build_object(''sha256'', lower(p_sha256),\n'
    || E'                  ''restriction_faite'', (v_r.metadata->''restriction_demandee'') || jsonb_build_object(''fait_le'', now(), ''fait_par'', p_uid),\n'
    || E'                  ''realignements'', coalesce(r.metadata->''realignements'', ''[]''::jsonb) || jsonb_build_array(jsonb_build_object(\n'
    || E'                    ''le'', now(), ''par'', p_uid, ''source_case'', ''statut_inconnu'', ''sans_candidat'', true,\n'
    || E'                    ''de'', jsonb_build_object(''bucket'', p_from_bucket, ''path'', p_from_path, ''access_scope'', v_r.access_scope),\n'
    || E'                    ''vers'', jsonb_build_object(''bucket'', p_bucket, ''path'', p_path, ''access_scope'', v_dest->>''access_scope''),\n'
    || E'                    ''sha256'', lower(p_sha256),\n'
    || E'                    ''via'', ''edge_function:realign-digital-resource'')))\n'
    || E'     WHERE r.id = v_r.id;\n'
    || E'    RETURN jsonb_build_object(''resource_id'', v_r.id, ''candidate_id'', NULL,\n'
    || E'                              ''storage_bucket'', p_bucket, ''storage_path'', p_path,\n'
    || E'                              ''access_scope'', v_dest->>''access_scope'', ''rights_status'', v_dest->>''rights_status'');\n'
    || E'  END IF;\n'
    || v_motif;
  EXECUTE replace(v_def, v_motif, v_neuf);
END
$patch$;

-- 3. la décision, dans les deux ressources (0 au banc, 2 en production)
DO $decision$
DECLARE
  v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM public.book_digital_resources r
   WHERE r.id IN (58, 65) AND r.rights_status = 'dominio_publico' AND r.access_scope = 'publico'
     AND NOT EXISTS (SELECT 1 FROM ingest.digital_candidates c WHERE c.resource_id = r.id AND c.status = 'verse');
  IF v_n NOT IN (0, 2) THEN
    RAISE EXCEPTION 'J13 sans candidat : % ressource(s) au critère (0 ou 2 attendues)', v_n;
  END IF;
  UPDATE public.book_digital_resources r
     SET metadata = coalesce(r.metadata, '{}'::jsonb) || jsonb_build_object('restriction_demandee', jsonb_build_object(
           'le', '2026-10-22', 'par', 'Xavier (administration du réseau)', 'item', 'J13',
           'motif', CASE WHEN r.id = 58
             THEN 'NUMDIF-2 amendé le 22/10/2026 : document de 1994 (Serviço Nacional de Informações), statut de droits non établi ; cas (c), décision de Xavier (J13)'
             ELSE 'NUMDIF-2 amendé le 22/10/2026 : Carlos Díaz est mort en 2021, l''œuvre n''est pas dans le domaine public et aucune mention de diffusion n''est relevée ; cas (c), décision de Xavier (J13)' END)),
         updated_at = now()
   WHERE r.id IN (58, 65) AND r.rights_status = 'dominio_publico' AND r.access_scope = 'publico'
     AND NOT EXISTS (SELECT 1 FROM ingest.digital_candidates c WHERE c.resource_id = r.id AND c.status = 'verse');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'J13 sans candidat : % ressource(s) marquée(s) restriction_demandee', v_n;
END
$decision$;

COMMIT;
