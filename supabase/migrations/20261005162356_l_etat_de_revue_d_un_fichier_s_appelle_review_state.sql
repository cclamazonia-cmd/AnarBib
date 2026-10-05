-- =====================================================================
-- C10 (05/10/2026) — la colonne de revue de digital_assets s'appelle
-- review_state.
--
-- Deux sens, un nom : `digital_assets.rights_status` est un ÉTAT DE REVUE
-- (to_review, public_domain_confirmed, source_reuse_allowed, restricted,
-- do_not_publish) — c'est lui que les fonctions de confirmation et de
-- publication posent avec is_public —, alors que `rights_status` de
-- book_digital_resources / book_draft_digital_resources est le VOCABULAIRE DES
-- DROITS (dominio_publico, cessao_autoral, licenca_livre, sob_direitos), et
-- celui de ingest.partner_catalog_received_assets le statut déclaré par la
-- partenaire. Seule la première change de nom ; les trois autres gardent le
-- leur.
--
-- Plan arrêté le 27/09 (backlog C10, décision de Xavier) :
--   (1) colonne, CHECK et index renommés ; les six fonctions qui la lisent
--       réécrites depuis leur définition RÉELLE (pg_get_functiondef, retours
--       chariot retirés), empreinte du corps relevée en production le 05/10,
--       remplacements COMPTÉS ;
--   (2) les sorties : `review_state` dans la liste des vérifiés (type de
--       retour changé → DROP + CREATE, droits et commentaire reposés) et dans
--       les clés JSON de l'attachement, de la confirmation et de l'export des
--       fonds ; le front et les Edge Functions suivent dans le même commit ;
--   (3) un paquet de fonds d'avant reste lisible : la réception lit
--       `review_state` puis, à défaut, `rights_status` (Edge Functions).
--
-- Aucune politique RLS, aucune vue, aucune politique de storage ne nomme la
-- colonne (relevé du 05/10) : la visibilité publique passe par is_public, que
-- les mêmes fonctions posent. Empreinte de (id, état, is_public, objet) des
-- digital_assets relevée avant : f0e4d078ec9a71f0bdd4263538965972 (1 ligne).
-- Aucune donnée n'est modifiée.
-- Suite : tests/sql/c10_etat_de_revue_tests.sql.
-- =====================================================================

ALTER TABLE public.digital_assets RENAME COLUMN rights_status TO review_state;
ALTER TABLE public.digital_assets RENAME CONSTRAINT digital_assets_rights_status_check TO digital_assets_review_state_check;
ALTER INDEX public.digital_assets_rights_status_idx RENAME TO digital_assets_review_state_idx;

COMMENT ON COLUMN public.digital_assets.review_state IS
  'C10 (05/10/2026) — état de REVUE du fichier (to_review, public_domain_confirmed, source_reuse_allowed, restricted, do_not_publish), posé avec is_public par fn_confirm_digital_asset_rights et fn_publish_digital_asset_from_resource. S''appelait rights_status, comme le vocabulaire des droits d''auteur de book_digital_resources : deux sens, un nom.';

DO $mig$
DECLARE
  r       record;
  v_def   text;
  v_md5   text;
  v_n     int;
  v_reste int;
BEGIN
  -- (fonction, empreinte du corps au 05/10, occurrences de rights_status visant
  --  digital_assets, occurrences qui doivent RESTER — l'autre table)
  FOR r IN
    SELECT * FROM (VALUES
      ('public.fn_confirm_digital_asset_rights(bigint)',               '2c741ff35e0eddb4c4aba642084347ef', 7, 0),
      ('public.fn_export_fonds_eligible_count(uuid)',                  '18146c05d42c27d29f80dfb25830e91f', 1, 0),
      ('public.fn_export_fonds_records(uuid,bigint[])',                'a1e9cf1870563088a201805468ac29a4', 4, 0),
      ('public.fn_publish_digital_asset_from_resource(bigint)',        '4a650c211a853247a3d0b0ce5db2cbcf', 2, 0)
    ) AS t(fn, md5, n, reste)
  LOOP
    SELECT md5(replace(prosrc, E'\r', '')) INTO v_md5 FROM pg_proc WHERE oid = r.fn::regprocedure;
    IF v_md5 <> r.md5 THEN
      RAISE EXCEPTION 'C10 : % a changé depuis le relevé du 05/10 — relire avant de réécrire', r.fn;
    END IF;
    v_def := replace(pg_get_functiondef(r.fn::regprocedure), E'\r', '');
    v_n := (length(v_def) - length(replace(v_def, 'rights_status', ''))) / length('rights_status');
    IF v_n <> r.n THEN
      RAISE EXCEPTION 'C10 : % — rights_status trouvé % fois (% attendues)', r.fn, v_n, r.n;
    END IF;
    EXECUTE replace(v_def, 'rights_status', 'review_state');
    IF pg_get_functiondef(r.fn::regprocedure) LIKE '%rights_status%' THEN
      RAISE EXCEPTION 'C10 : réécriture incomplète de %', r.fn;
    END IF;
  END LOOP;

  -- fn_attach_received_asset_record nomme les DEUX tables : seules l'insertion
  -- dans digital_assets et la clé JSON rendue changent ; la ligne de
  -- book_digital_resources, son commentaire et le statut déclaré (ra.) restent.
  SELECT md5(replace(prosrc, E'\r', '')) INTO v_md5 FROM pg_proc
   WHERE oid = 'public.fn_attach_received_asset_record(bigint,bigint,text,text,text)'::regprocedure;
  IF v_md5 <> '30fbab5e1e664ccd557be38706663ca7' THEN
    RAISE EXCEPTION 'C10 : fn_attach_received_asset_record a changé depuis le relevé du 05/10 — relire avant de réécrire';
  END IF;
  v_def := replace(pg_get_functiondef('public.fn_attach_received_asset_record(bigint,bigint,text,text,text)'::regprocedure), E'\r', '');
  FOR r IN
    SELECT * FROM (VALUES
      ($a$       rights_status, bucket_name, object_path, is_public, mime_type, file_size_bytes, checksum_sha256, notes)$a$,
       $a$       review_state, bucket_name, object_path, is_public, mime_type, file_size_bytes, checksum_sha256, notes)$a$),
      ($a$    'rights_status', CASE WHEN v_asset_id IS NOT NULL THEN 'to_review' ELSE NULL END);$a$,
       $a$    'review_state', CASE WHEN v_asset_id IS NOT NULL THEN 'to_review' ELSE NULL END);$a$)
    ) AS t(vieux, neuf)
  LOOP
    v_n := (length(v_def) - length(replace(v_def, r.vieux, ''))) / length(r.vieux);
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'C10 : fn_attach_received_asset_record — ancre trouvée % fois (1 attendue) : %', v_n, left(r.vieux, 60);
    END IF;
    v_def := replace(v_def, r.vieux, r.neuf);
  END LOOP;
  v_reste := (length(v_def) - length(replace(v_def, 'rights_status', ''))) / length('rights_status');
  IF v_reste <> 3 THEN
    RAISE EXCEPTION 'C10 : fn_attach_received_asset_record — % rights_status restants (3 attendus : commentaire, book_digital_resources, ra.)', v_reste;
  END IF;
  EXECUTE v_def;

  -- fn_list_verified_digital_assets : le nom de colonne fait partie du type de
  -- retour (RETURNS TABLE) — CREATE OR REPLACE le refuse ; DROP + CREATE, puis
  -- droits et commentaire reposés à l'identique (relevés le 05/10 :
  -- postgres, authenticated, service_role ; ni PUBLIC ni anon).
  SELECT md5(replace(prosrc, E'\r', '')) INTO v_md5 FROM pg_proc
   WHERE oid = 'public.fn_list_verified_digital_assets(uuid)'::regprocedure;
  IF v_md5 <> '3e86d547987f40eaba84c4ca5bfb60c0' THEN
    RAISE EXCEPTION 'C10 : fn_list_verified_digital_assets a changé depuis le relevé du 05/10 — relire avant de réécrire';
  END IF;
  v_def := replace(pg_get_functiondef('public.fn_list_verified_digital_assets(uuid)'::regprocedure), E'\r', '');
  v_n := (length(v_def) - length(replace(v_def, 'rights_status', ''))) / length('rights_status');
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'C10 : fn_list_verified_digital_assets — rights_status trouvé % fois (2 attendues : type de retour, corps)', v_n;
  END IF;
  DROP FUNCTION public.fn_list_verified_digital_assets(uuid);
  EXECUTE replace(v_def, 'rights_status', 'review_state');
END
$mig$;

REVOKE ALL ON FUNCTION public.fn_list_verified_digital_assets(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_list_verified_digital_assets(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_list_verified_digital_assets(uuid) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_list_verified_digital_assets(uuid) IS
  'Chantier fichiers numériques (c). Audit des digital_assets des livres d''une biblio (provenance, verified_by/at, origine reçue). Pour la dé-vérification. Reservé coordenador / admin réseau. C10 (05/10/2026) : la colonne rendue s''appelle review_state (état de revue), plus rights_status.';
