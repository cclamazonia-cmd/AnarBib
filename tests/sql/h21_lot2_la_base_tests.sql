-- =====================================================================
-- AnarBib — Tests d'acceptation : la base de ce que l'import a apporté
-- (H21 lot 2, REGISTRE IMP-23, IMP-26, IMP-27, IMP-28)
-- Date    : 2026-10-05
-- Ref     : migration 20261005172708_h21_lot2_la_base_de_ce_que_l_import_a_apporte
--
-- Pour chaque identifiant d'origine (book_external_ids), la base
-- (ingest.book_import_baselines) garde ce que le dernier import ACCEPTÉ a
-- apporté pour la notice, par la correspondance ingest.fn_import_row_as_book,
-- que la création des brouillons appelle désormais.
--
-- T1  égalité de la création : sur chaque branche de la correspondance (MARC
--     avec responsabilités structurées, non-agents, rôle inconnu, code
--     d'origine trop long ; article et revue hôte ; fascicule ; ressource en
--     ligne ; CSV ; RIS sans ligne normalisée, collection et cote locale ;
--     collection = titre ; type de revue ; pages invalides ; clé répétée), les
--     brouillons, leurs responsabilités, les liens, l'état des lignes et le
--     résultat sont IDENTIQUES, champ par champ, à ceux de la définition d'AVANT
--     le lot 2 (recopiée ci-dessous telle que lue le 05/10/2026 — md5 de prosrc
--     a390fbedcca11e5d17c7c464239e805f — et rejouée dans la même transaction).
-- T2  une seule règle : chaque brouillon est ce que fn_import_row_as_book dit de
--     sa ligne — sauf source_record_id des deux lignes à clé répétée, que l'étape
--     du run (fn_h20_effacer_faux_identifiants) efface ensuite ; la fonction est
--     IMMUTABLE, n'écrit rien, rend deux fois la même chose.
-- T3  (a) publication d'un lot importé : une base par identifiant, exacte (la
--     valeur du FICHIER, pas la retouche faite au brouillon avant publication),
--     origine import, confirmée, ligne et run, aucun champ douteux.
-- T4  (a) un brouillon importé absorbé par un autre (api.merge_book_drafts) :
--     à la publication du survivant, son identifiant reçoit SA base (sa ligne).
-- T5  (b) absorption par une notice existante (api.merge_draft_into_book) : base
--     posée, confirmée ; une seconde absorption du même identifiant (nouveau run,
--     même source) AVANCE la base (nouvelle ligne, nouvelle valeur).
-- T6  (IMP-28 c) lot du PMB de BLMF réattribué à B : absorbé par B
--     (merge_draft_into_book) ou publié par l'administration, l'identifiant et la
--     base vont à BLMF ; aucun identifiant ni base pour B.
-- T7  (c) exemplaire rapproché publié sur une notice sans identifiant : base CRÉÉE
--     (origine import, NON confirmée) ; un second rapprochement du même
--     identifiant (nouveau run) ne l'avance pas ; un rapprochement sur une notice
--     dont la base est confirmée (T3) ne la touche pas.
-- T8  (c, IMP-28 c) rapproché publié à BLMF puis réattribué à B : base à BLMF
--     seulement.
-- T9  fusion de notices (fn_fusion_notices) : l'identifiant passe à la notice
--     gardée, la base le suit (même ligne de base, même contenu).
-- T10 suppression : l'identifiant supprimé emporte sa base ; la notice supprimée
--     emporte identifiant et base.
-- T11 une clé que fn_record_book_external_id n'a pas donnée (elle était déjà à une
--     autre notice) : aucune base, ni pour la nouvelle notice ni pour l'ancienne.
-- T12 une copie (« Éditer », create_book_draft_from_book) ne pose ni n'avance de
--     base, republiée comme absorbée.
-- T13 accès : l'API ne lit ni n'écrit la base (schéma ingest fermé, aucun droit) ;
--     avec un droit de lecture posé à l'essai, la policy ne montre à la
--     coordination que les bases de SA bibliothèque, toutes à l'administration ;
--     aucune écriture même alors.
-- T14 reprise (ingest.fn_h21_reprendre_les_bases) : depuis la ligne vivante du
--     brouillon importé publié, depuis celle d'un exemplaire rapproché publié,
--     depuis marc_json.ingest quand la ligne a disparu (reconstituée : même
--     correspondance que la ligne d'origine), rien sans source ; origine reprise,
--     champs douteux, non confirmée, bibliothèque de l'identifiant (le run de la
--     source 3 n'en a pas) ; les bases existantes intactes ; rejouée : rien de
--     plus, rien de changé.
-- T15 export : une notice d'une autre bibliothèque qui a absorbé un brouillon du
--     PMB de BLMF réémet, pour BLMF, l'enregistrement de BLMF (sa base), et pour
--     elle-même le sien — avant le lot 2, BLMF n'en avait aucun (case unique de
--     marc_json.ingest) ; sans base, l'export est celui d'avant.
-- T16 structure et droits : clé unique, cascade, RLS sans FORCE, une policy de
--     lecture, aucun droit pour anon/authenticated, fonctions internes fermées,
--     correspondance IMMUTABLE et appelée par la création.
-- Revue sceptique du 05/10 — la bibliothèque qui a importé ne manque plus en
-- silence (ingest.fn_h21_bibliotheque_importatrice et ses replis) :
-- T17 source sans bibliothèque (comme la source 3, MLEG) dont les identifiants
--     sont à MLEG, lot réattribué à B : publication et absorption posent
--     identifiant ET base à MLEG (repli 2), rien pour B, la cible.
-- T18 source neuve sans bibliothèque ni identifiants : la bibliothèque du
--     brouillon (repli 3), à la publication comme à l'absorption ; identifiants
--     de la source dans deux bibliothèques : pas de choix, celle du brouillon.
-- T19 exemplaire rapproché d'une ligne de la source MLEG, publié dans B :
--     identifiant ET base à MLEG (le rapprochement prend la même fonction).
--
-- Contre-épreuves du 05/10/2026 : mutants hors dépôt (…\scratchpad\l2\mutants),
-- chacun appliqué sur la définition VIVANTE (ancre comptée, sinon refus) dans la
-- transaction de la suite, puis annulé. Chaque écriture retirée fait tomber un test :
--   M01 (a) publication sans base                     10/19 — T3 T4 T6 T7 T9 T12 T14 T17 T18
--   M02 (a) absorbés sans base                        18/19 — T4
--   M03 (b) absorption sans base                      14/19 — T5 T6 T15 T17 T18
--   M04 (b) identifiant à la bibliothèque du brouillon 14/19 — T6 T8 T13 T17 T19
--   M05 (c) rapprochement sans base                   16/19 — T7 T8 T19
--   M06 (c) le rapprochement avance la base           17/19 — T7 T19
--   M07 base sans contrôle de la notice               18/19 — T11
--   M08 une copie prise pour le brouillon importé     18/19 — T12
--   M09 export sans la base                           18/19 — T15
--   M10 reprise sans le repli sur le brouillon        18/19 — T14
--   M11 reprise sans champs douteux                   18/19 — T14
--   M12 correspondance changée (ISSN d'un article)    18/19 — T1
--   M13 policy de lecture retirée                     17/19 — T13 T16
--   M14 base gardée quand l'identifiant part (FK)     16/19 — T10 T13 T16
--   M15 reprise : bibliothèque du run (piège 5)       18/19 — T14
--   M16 l'absorption n'avance pas la base             18/19 — T5
--   M17 base prise de la notice publiée (retouches)   13/19 — T3 T4 T5 T6 T17 T18
--   M18 correspondance changée (mots-clés)            18/19 — T1
--   Replis de la bibliothèque qui a importé (revue sceptique) :
--   M19 sans le repli sur les identifiants de la source 17/19 — T17 T19
--   M20 sans le repli de l'appelant                   18/19 — T18
--   M21 identifiants de la source sans unicité        18/19 — T18
--   M22 repli de l'appelant avant les identifiants    17/19 — T17 T19
--   M23 rapprochement : expression en ligne du lot 1  18/19 — T19
--   M24 publication sans repli                        18/19 — T18
--   M25 absorption sans repli                         18/19 — T18
--   Hors de cette suite (aller_retour_pmb_tests.sql) : M01 → T7 T8 ; M09 → T8 ;
--   M18 → T5 (31 brouillons) et T3.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'H21-LOT2-LA-BASE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans rôle (seed) -> admin réseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_libB uuid; v_coordB uuid; v_libM uuid; v_s5 bigint; v_km0 bigint;
  v_s1 bigint; v_s2 bigint; v_sB bigint; v_s3 bigint;
  v_req bigint; v_ra bigint; v_rab bigint; v_rm1 bigint; v_rm2 bigint; v_rr bigint; v_rc1 bigint; v_rc2 bigint; v_rc3 bigint;
  v_rt bigint; v_rdbl bigint; v_rrep bigint; v_rexp bigint; v_rexpb bigint;
  v_lot bigint; v_lot2 bigint; v_d1 bigint; v_d2 bigint; v_d3 bigint; v_b1 bigint; v_b2 bigint; v_b3 bigint;
  v_kB bigint; v_kB2 bigint; v_kC bigint; v_kT bigint; v_kX bigint; v_kF bigint; v_kR1 bigint; v_kR2 bigint; v_kR3 bigint; v_kR4 bigint;
  v_row bigint; v_row2 bigint; v_x bigint; v_e bigint; v_bl bigint; v_eid bigint; v_eid2 bigint;
  v_res jsonb; v_res2 jsonb; v_avant jsonb; v_apres jsonb; v_v jsonb; v_v2 jsonb; v_snap jsonb; v_snap2 jsonb;
  v_n int; v_m int; v_txt text; v_hint text; v_ok boolean; v_ts timestamptz;
  v_marc jsonb := '{"leader": "00000nam0 22000001i 450 ", "marc_dialect": "unimarc", "item_tag": "995",
                    "fields": [{"tag": "001", "value": "X"}, {"tag": "200", "ind1": "1", "ind2": " ", "subfields": [{"code": "a", "value": "Titre MARC"}]},
                               {"tag": "995", "ind1": " ", "ind2": " ", "subfields": [{"code": "f", "value": "CODE"}]}]}'::jsonb;
BEGIN
  -- ── Décor ───────────────────────────────────────────────────────────
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "L2-T-", "year": false, "pad": 4}'::jsonb WHERE id = v_lib;
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level, tombo_pattern)
  VALUES (gen_random_uuid(), 'essai-h21-l2-b', 'Essai H21 lot 2 — B', true, 'private',
          '{"prefix": "L2B-T-", "year": false, "pad": 4}'::jsonb)
  RETURNING id INTO v_libB;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'h21l2-coordb-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id INTO v_coordB;
  INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_coordB, 'Essai', 'H21L2') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_coordB, v_libB, 'coordenador', 'active', true);

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('L2 PMB de BLMF', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_s1;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('L2 PMB de BLMF, nouvel export', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_s2;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('L2 PMB de B', v_libB, 'mapeada', 'own_catalog', true) RETURNING id INTO v_sB;
  -- comme la source 3 de la production : aucune bibliothèque (piège 5)
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('L2 source sans bibliotheque (comme la source 3)', NULL, 'mapeada', 'manual_upload', false) RETURNING id INTO v_s3;

  -- Outils de la suite (pg_temp, annulés avec elle).
  -- Projection d'un run promu : brouillons (sans id ni horodatage), responsabilités, lien, état des lignes.
  EXECUTE $o$
    CREATE FUNCTION pg_temp.l2_projection(p_run bigint) RETURNS jsonb LANGUAGE sql AS $f$
      SELECT jsonb_agg(jsonb_build_object(
               'row_no', s.row_no,
               'brouillon', to_jsonb(d) - 'id' - 'batch_id' - 'created_at' - 'updated_at' - 'last_opened_at',
               'responsabilites', (SELECT jsonb_agg(to_jsonb(c) - 'id' - 'draft_id' - 'created_at' - 'updated_at' ORDER BY c.position)
                                     FROM public.book_draft_contributors c WHERE c.draft_id = d.id),
               'ligne', jsonb_build_object('review_status', s.review_status, 'selected_for_draft', s.selected_for_draft,
                                           'lien', m.id IS NOT NULL, 'lien_lot', m.batch_id IS NOT NULL))
             ORDER BY s.row_no)
        FROM ingest.partner_catalog_staging_rows s
        LEFT JOIN ingest.partner_catalog_row_to_draft m ON m.staging_row_id = s.id
        LEFT JOIN public.book_drafts d ON d.id = m.draft_id
       WHERE s.run_id = p_run;
    $f$ $o$;
  -- Une base, telle que la table la garde (sans id ni horodatages d'écriture).
  EXECUTE $o$
    CREATE FUNCTION pg_temp.l2_base(p_lib uuid, p_src bigint, p_cle text) RETURNS jsonb LANGUAGE sql AS $f$
      SELECT to_jsonb(bl) - 'created_at' - 'updated_at' || jsonb_build_object('book_id', e.book_id)
        FROM public.book_external_ids e JOIN ingest.book_import_baselines bl ON bl.external_id_id = e.id
       WHERE e.library_id = p_lib AND e.scheme = 'import:' || p_src AND e.value = p_cle;
    $f$ $o$;
  -- Ce que la base d'une ligne doit être.
  EXECUTE $o$
    CREATE FUNCTION pg_temp.l2_attendu(p_row bigint) RETURNS jsonb LANGUAGE sql AS $f$
      SELECT ingest.fn_import_row_as_book(s, ingest.fn_h21_contexte_du_run(s.run_id))
        FROM ingest.partner_catalog_staging_rows s WHERE s.id = p_row;
    $f$ $o$;
  -- La base est-elle exactement celle de la ligne ?
  EXECUTE $o$
    CREATE FUNCTION pg_temp.l2_base_exacte(p_base jsonb, p_row bigint) RETURNS boolean LANGUAGE sql AS $f$
      SELECT p_base IS NOT NULL
         AND p_base->'mapped' = a->'mapped' AND p_base->'contributors' = a->'contributors'
         AND p_base->'subjects' = a->'subjects' AND p_base->'raw_payload' = a->'raw_payload'
         AND p_base->>'payload_hash' = a->>'payload_hash' AND p_base->>'mapping_version' = a->>'mapping_version'
         AND (p_base->>'staging_row_id')::bigint = p_row
         AND (p_base->>'run_id')::bigint = (SELECT run_id FROM ingest.partner_catalog_staging_rows WHERE id = p_row)
        FROM (SELECT pg_temp.l2_attendu(p_row) AS a) x;
    $f$ $o$;
  -- Promouvoir un run (lignes new_record/accept_new), poser les références, réviser, publier le lot.
  EXECUTE $o$
    CREATE FUNCTION pg_temp.l2_promouvoir(p_run bigint, p_qui uuid) RETURNS bigint LANGUAGE plpgsql AS $f$
    DECLARE v_lot bigint;
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_qui, 'role', 'authenticated')::text, true);
      v_lot := (public.fn_import_promote(p_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
      UPDATE public.book_drafts SET bib_ref = 'L2-REF-' || id WHERE batch_id = v_lot AND bib_ref IS NULL;
      RETURN v_lot;
    END $f$ $o$;
  EXECUTE $o$
    CREATE FUNCTION pg_temp.l2_reviser(p_lot bigint, p_qui uuid, p_admin uuid) RETURNS void LANGUAGE plpgsql AS $f$
    DECLARE v_res jsonb;
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_qui, 'role', 'authenticated')::text, true);
      v_res := public.fn_batch_review_request(p_lot);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_admin, 'role', 'authenticated')::text, true);
      PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_qui, 'role', 'authenticated')::text, true);
    END $f$ $o$;
  EXECUTE $o$
    CREATE FUNCTION pg_temp.l2_draft(p_run bigint, p_cle text) RETURNS bigint LANGUAGE sql AS $f$
      SELECT m.draft_id FROM ingest.partner_catalog_row_to_draft m
        JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id
       WHERE s.run_id = p_run AND s.external_key = p_cle;
    $f$ $o$;
  EXECUTE $o$
    CREATE FUNCTION pg_temp.l2_ligne(p_run bigint, p_cle text) RETURNS bigint LANGUAGE sql AS $f$
      SELECT s.id FROM ingest.partner_catalog_staging_rows s WHERE s.run_id = p_run AND s.external_key = p_cle;
    $f$ $o$;
  -- Rapprocher une ligne, réviser, publier son exemplaire (rend l'exemplaire publié).
  EXECUTE $o$
    CREATE FUNCTION pg_temp.l2_rapprocher(p_run bigint, p_row bigint, p_qui uuid, p_admin uuid) RETURNS bigint LANGUAGE plpgsql AS $f$
    DECLARE v_lot bigint; v_x bigint; v_e bigint;
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_qui, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_lot := (public.fn_import_reconcile_duplicates(p_run, ARRAY[p_row])->>'batch_id')::bigint;
      EXECUTE 'RESET ROLE';
      PERFORM pg_temp.l2_reviser(v_lot, p_qui, p_admin);
      SELECT x.id INTO v_x FROM public.exemplar_drafts x WHERE x.import_staging_row_id = p_row ORDER BY x.id DESC LIMIT 1;
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_e := public.publish_exemplar_draft(v_x);
      EXECUTE 'RESET ROLE';
      RETURN v_e;
    END $f$ $o$;

  -- La définition d'AVANT le lot 2 (oracle de T1), recopiée telle quelle.
  EXECUTE $oracle$
CREATE FUNCTION pg_temp.h21l2_creation_d_avant(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL::bigint[], p_batch_name text DEFAULT NULL::text, p_batch_notes text DEFAULT NULL::text, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'ingest', 'public', 'auth'
AS $function$
declare
  v_actor uuid;
  v_partner_name text;
  v_relation_status text;
  v_original_filename text;
  v_detected_format text;
  v_batch_id bigint;
  v_batch_library uuid;        -- IMP-27 (d)
  v_batch_neuf boolean := false;
  v_lot_repris bigint;
  v_lot_repris_nom text;
  v_batch_name text;
  v_batch_notes text;
  v_created_count integer := 0;
  v_requested_count integer := 0;
  v_draft_id bigint;
  v_refresh jsonb;
  v_collection_hint text;
  v_local_classification_hint text;
  v_provenance_note text;
  rec record;
begin
  v_actor := coalesce(p_created_by, auth.uid());

  select s.partner_name, s.relation_status, r.original_filename, r.detected_format
    into v_partner_name, v_relation_status, v_original_filename, v_detected_format
  from ingest.partner_catalog_import_runs r
  join ingest.partner_catalog_sources s on s.id = r.source_id
  where r.id = p_run_id;

  if not found then
    raise exception 'import_run % introuvable', p_run_id;
  end if;

  if coalesce(array_length(p_row_ids, 1), 0) > 0 then
    select count(*)::integer
      into v_requested_count
    from ingest.partner_catalog_staging_rows sr
    where sr.run_id = p_run_id
      and sr.id = any(p_row_ids)
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      -- IMP-26 (h) : une ligne « Accepté (rattaché) » ne devient jamais une
      -- notice ; un exemplaire sur la notice existante, c'est « Rapprocher ».
      and sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new';
  else
    select count(*)::integer
      into v_requested_count
    from ingest.partner_catalog_staging_rows sr
    where sr.run_id = p_run_id
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      and sr.selected_for_draft = true
      and sr.review_status = 'approved'
      -- IMP-26 (h) : une ligne « Accepté (rattaché) » ne devient jamais une
      -- notice ; un exemplaire sur la notice existante, c'est « Rapprocher ».
      and sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new';
  end if;

  if v_requested_count = 0 then
    raise exception 'Aucune ligne autorisée à convertir pour le run %', p_run_id;
  end if;

  v_batch_name := coalesce(
    nullif(trim(p_batch_name), ''),
    format(
      'Import parceiro #%s — %s — %s',
      p_run_id,
      left(coalesce(v_partner_name, 'parceiro sem nome'), 80),
      to_char(now() at time zone 'UTC', 'YYYY-MM-DD HH24:MI UTC')
    )
  );

  v_batch_notes := coalesce(
    nullif(trim(p_batch_notes), ''),
    format(
      'Lote criado a partir do import run %s (%s, formato %s).',
      p_run_id,
      coalesce(v_original_filename, 'arquivo sem nome'),
      coalesce(v_detected_format, 'unknown')
    )
  );

  -- B30 : le lot naît avec sa bibliothèque — celle que fn_import_promote
  -- tamponne ensuite sur ses notices : le run pour un catalogue propre, la
  -- destination pour un dépôt compagnon ou un entrepôt OAI (nulle tant qu'elle
  -- est inconnue : le lot est alors à l'administration).
  select case when s.source_kind in ('partner_deposit', 'oai_pmh') then s.destination_library_id
              else r.library_id end
    into v_batch_library
    from ingest.partner_catalog_import_runs r
    left join ingest.partner_catalog_sources s on s.id = r.source_id
   where r.id = p_run_id;

  -- IMP-27 (d) (29/09/2026) : une nouvelle sélection du run rejoint le lot
  -- qu'une promotion précédente de ce run a ouvert, tant qu'il est ouvert, de
  -- la même bibliothèque, et qu'aucune révision n'y est demandée ni approuvée
  -- (« retouches demandées » : la coordination y travaille encore) — une
  -- révision de moins pour l'administration à chaque sélection.
  select b.id, b.name into v_lot_repris, v_lot_repris_nom
    from public.catalog_batches b
   where b.status = 'open'
     and b.library_id is not distinct from v_batch_library
     and b.id in (select m.batch_id from ingest.partner_catalog_row_to_draft m
                   where m.run_id = p_run_id and m.batch_id is not null)
     and coalesce(public.fn_batch_review_status(b.id), 'aucune') in ('aucune', 'changes_requested')
   order by b.id desc
   limit 1
   for update of b;

  if v_lot_repris is not null then
    v_batch_id := v_lot_repris;
    v_batch_name := v_lot_repris_nom;
  else
    insert into public.catalog_batches (name, notes, created_by, library_id)
    values (v_batch_name, v_batch_notes, v_actor, v_batch_library)
    returning id into v_batch_id;
    v_batch_neuf := true;
  end if;

  for rec in
    select sr.*, r.original_filename, r.detected_format, s.partner_name, s.relation_status, s.source_kind
    from ingest.partner_catalog_staging_rows sr
    join ingest.partner_catalog_import_runs r on r.id = sr.run_id
    join ingest.partner_catalog_sources s on s.id = r.source_id
    where sr.run_id = p_run_id
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      and not exists (
        select 1 from ingest.partner_catalog_row_to_draft rd where rd.staging_row_id = sr.id
      )
      and (
        (coalesce(array_length(p_row_ids, 1), 0) > 0 and sr.id = any(p_row_ids))
        or
        (coalesce(array_length(p_row_ids, 1), 0) = 0 and sr.selected_for_draft = true and sr.review_status = 'approved')
      )
      -- IMP-26 (h) : une ligne « Accepté (rattaché) » ne devient jamais une
      -- notice ; un exemplaire sur la notice existante, c'est « Rapprocher ».
      and sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new'
    order by sr.row_no, sr.id
  loop
    v_collection_hint := ingest.fn_partner_catalog_extract_collection_hint(rec.normalized_payload, rec.raw_payload);
    v_local_classification_hint := ingest.fn_partner_catalog_extract_local_classification_hint(rec.normalized_payload, rec.raw_payload);

    v_provenance_note := format(
      'Importado de catálogo parceiro "%s" (%s, run %s, linha %s, formato bruto %s, relação %s, decisão %s).',
      rec.partner_name,
      coalesce(rec.original_filename, 'arquivo sem nome'),
      rec.run_id,
      rec.row_no,
      coalesce(rec.detected_format, 'unknown'),
      coalesce(rec.relation_status, 'sem_status'),
      coalesce(rec.editorial_decision, 'pending')
    );

    if v_local_classification_hint is not null then
      v_provenance_note := v_provenance_note || format(' Sinal local da parceira preservado: %s.', v_local_classification_hint);
    end if;

    insert into public.book_drafts (
      batch_id, action, status, titulo, subtitulo, autor, edicao,
      local_publicacao, editora, ano, isbn, issn, idioma, tipo_material,
      cdd, colecao, marc_json, created_by, updated_by, acquisition_mode,
      partner_source, source_record_id, import_format, import_method,
      provenance_note, mutualization_status, source_label, notas,
      -- H17 : pages, volume, adresse, périodique et article
      paginas, volume, digital_native_url, titulo_periodico,
      artigo_source, artigo_volume, artigo_issue, artigo_pages, data_edicao, numero
    ) values (
      v_batch_id,
      'create',
      'draft',
      nullif(trim(rec.title), ''),
      nullif(trim(rec.subtitle), ''),
      coalesce(nullif(trim(rec.responsibility_statement), ''), ingest.fn_format_partner_authors(rec.authors)),
      nullif(trim(rec.edition_statement), ''),
      nullif(trim(rec.place_of_publication), ''),
      nullif(trim(rec.publisher), ''),
      nullif(trim(rec.publication_year), ''),
      nullif(trim(rec.isbn), ''),
      -- H17 / H27 : un article n'a pas d'ISSN à lui — celui de sa revue d'abord
      -- (461 $x, 773 $x), l'export le rend en 461 $x ; un périodique, le sien.
      case when rec.normalized_payload->>'material_type' = 'artigo'
           then coalesce(nullif(btrim(rec.normalized_payload->'host'->>'issn'), ''), nullif(trim(rec.issn), ''))
           else coalesce(nullif(trim(rec.issn), ''),
                         case when rec.normalized_payload->>'material_type' = 'periodico'
                              then nullif(btrim(rec.normalized_payload->'host'->>'issn'), '') end)
      end,
      ingest.fn_idioma_bcp47(rec.language),
      -- tipo_material : H17, le type déduit du guide MARC (article dépouillé,
      -- périodique, son…) quand il est valide ; sinon le type brut (RIS/BibTeX).
      coalesce(case when rec.normalized_payload->>'material_type' = any (array['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine'])
                    then rec.normalized_payload->>'material_type' end,
      case lower(coalesce(nullif(trim(rec.item_type), ''), 'book'))
        when 'book' then 'livro'
        when 'livro' then 'livro'
        when 'jour' then 'periodico'
        when 'mgzn' then 'periodico'
        when 'news' then 'periodico'
        when 'newspaper' then 'periodico'
        when 'periodico' then 'periodico'
        when 'chap' then 'artigo'
        when 'inbook' then 'artigo'
        when 'article' then 'artigo'
        when 'artigo' then 'artigo'
        when 'thes' then 'tese'
        when 'tese' then 'tese'
        when 'rprt' then 'relatorio'
        when 'relatorio' then 'relatorio'
        when 'pamp' then 'tract'
        when 'tract' then 'tract'
        when 'zine' then 'zine'
        when 'elec' then 'recurso_digital'
        when 'sound' then 'audio'
        when 'audio' then 'audio'
        when 'video' then 'audiovisual'
        when 'mpct' then 'audiovisual'
        when 'audiovisual' then 'audiovisual'
        else 'livro'
      end),
      -- H17 : la classification (676 / 082).
      nullif(btrim(rec.normalized_payload->>'classification'), ''),
      coalesce(nullif(btrim(rec.normalized_payload->>'series'), ''),   -- H17 : 225/410, 490
      case
        when v_collection_hint is null then null
        -- H17 (revue) : la revue d'un article ou d'un fascicule n'est pas sa collection
        when rec.normalized_payload->>'material_type' in ('artigo', 'periodico') then null
        when lower(coalesce(rec.item_type, '')) ~ '(periodic|journal|article|boletim|periodico|periódico|jour)' then null
        when lower(regexp_replace(coalesce(v_collection_hint, ''), '\s+', ' ', 'g')) = lower(regexp_replace(coalesce(rec.title, ''), '\s+', ' ', 'g')) then null
        else v_collection_hint
      end),
      coalesce(rec.normalized_payload, '{}'::jsonb)
        || jsonb_build_object(
             'ingest',
             jsonb_build_object(
               'run_id', rec.run_id,
               'source_id', (select r2.source_id from ingest.partner_catalog_import_runs r2 where r2.id = rec.run_id),   -- H20
               'staging_row_id', rec.id,
               'row_no', rec.row_no,
               'source_file_id', rec.source_file_id,
               'partner_name', rec.partner_name,
               'relation_status', rec.relation_status,
               'original_filename', rec.original_filename,
               'detected_format', rec.detected_format,
               'raw_payload', coalesce(rec.raw_payload, '{}'::jsonb),
               'authors', coalesce(rec.authors, '[]'::jsonb),
               'subjects', coalesce(rec.subjects, '[]'::jsonb),
               'editorial_decision', rec.editorial_decision,
               'editorial_note', rec.editorial_note,
               'derived_collection_hint', v_collection_hint,
               'derived_local_classification_hint', v_local_classification_hint
             )
           ),
      v_actor,
      v_actor,
      null,
      'other_partner',                               -- partner_source : code valide (FK source_partner_code). Nom precis dans provenance_note/source_label.
      -- H20 : l'identifiant d'origine du fichier (001), ou rien — jamais le
      -- numéro de la ligne de staging, qui passait pour un numéro de PMB.
      nullif(trim(rec.external_key), ''),
      null,                                          -- import_format : NULL (evite FK source_format_code)
      null,                                          -- import_method : NULL (evite FK import_method_code)
      v_provenance_note,
      null,
      coalesce(rec.original_filename, rec.partner_name),
      nullif(concat_ws(E'\n\n',
        nullif(btrim(rec.normalized_payload->>'notes'), ''),
        case when nullif(btrim(rec.normalized_payload->>'url'), '') is not null
              and rec.normalized_payload->>'material_type' is distinct from 'recurso_digital'
             then 'Endereço eletrônico: ' || btrim(rec.normalized_payload->>'url') end,
        -- H27 : les mots-clés libres (610 / 653), à part des vedettes ; l'export
        -- les rend en 610 / 653 (_shared/marc/ecriture.ts, deplierNotes).
        case when jsonb_typeof(rec.normalized_payload->'keywords') = 'array'
              and jsonb_array_length(rec.normalized_payload->'keywords') > 0
             then 'Palavras-chave importadas: '
                  || array_to_string(array(select jsonb_array_elements_text(rec.normalized_payload->'keywords')), '; ') end,
      nullif(concat_ws(
        ' ',
        case
          when rec.subjects is not null
           and jsonb_typeof(rec.subjects) = 'array'
           and jsonb_array_length(rec.subjects) > 0
          then 'Assuntos importados: '
               || array_to_string(array(select jsonb_array_elements_text(rec.subjects)), '; ')
          else null
        end,
        case
          when v_local_classification_hint is not null
          then format('Classificação / cote local preservada da parceira: %s.', v_local_classification_hint)
          else null
        end
      ), '')), ''),
      -- H17
      case when (rec.normalized_payload->>'pages') ~ '^[0-9]{1,5}$' then (rec.normalized_payload->>'pages')::integer end,
      nullif(btrim(rec.normalized_payload->>'volume'), ''),
      case when rec.normalized_payload->>'material_type' = 'recurso_digital'
           then nullif(btrim(rec.normalized_payload->>'url'), '') end,
      case when rec.normalized_payload->>'material_type' = 'periodico'
           then coalesce(nullif(btrim(rec.normalized_payload->>'key_title'), ''), nullif(trim(rec.title), '')) end,
      case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->'host'->>'title'), '') end,
      case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->'host'->>'volume'), '') end,
      case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->'issue'->>'number'), '') end,
      case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->>'extent'), '') end,
      case when rec.normalized_payload->>'material_type' in ('artigo', 'periodico') then nullif(btrim(rec.normalized_payload->'issue'->>'date'), '') end,
      -- H17 (revue) : le numéro d'un fascicule (notice de bulletin de PMB)
      case when rec.normalized_payload->>'material_type' = 'periodico' then nullif(btrim(rec.normalized_payload->'issue'->>'number'), '') end
    ) returning id into v_draft_id;

    -- H18 (27/09/2026) : les responsabilités, structurées quand le fichier les
    -- porte (MARC : nom, nature, rôle, code d'origine) ; sinon les noms de la
    -- ligne (CSV, RIS : des chaînes ; recherche institutionnelle, paquet de
    -- fonds : des objets {name|label|display|family+given, role}), en
    -- auteur·rice sauf rôle AnarBib dit. La principale d'abord. Jamais un
    -- non-agent (« Collectif », « Vários » : CONV-8, entrée au titre).
    -- Aucune autorité n'est rattachée d'office : les rapprochements se
    -- proposent en révision du lot.
    insert into public.book_draft_contributors (draft_id, position, name, role, is_primary, nature, role_code)
    select v_draft_id, row_number() over (order by c.ord)::integer, left(btrim(c.value->>'name'), 500),
           case when c.value->>'role' = any (array['autor','coautor','organizacao','organizador','tradutor','ilustrador','prefaciador','coordenador','editor','realizador','roteirista','ator','interprete','compositor','narrador','produtor','locutor','outro']) then c.value->>'role' else 'outro' end,
           row_number() over (order by c.ord) = 1 and (c.value->'primary') is distinct from 'false'::jsonb,
           case when c.value->>'nature' in ('person', 'collective', 'congress') then c.value->>'nature' end,
           nullif(left(btrim(c.value->>'role_code'), 40), '')
      from jsonb_array_elements(case when jsonb_typeof(rec.normalized_payload->'contributors') = 'array'
                                     then rec.normalized_payload->'contributors' else '[]'::jsonb end)
           with ordinality as c(value, ord)
     where jsonb_typeof(c.value) = 'object' and nullif(btrim(c.value->>'name'), '') is not null
       and not public.fn_conv_est_non_agent(c.value->>'name');
    if not found then
      insert into public.book_draft_contributors (draft_id, position, name, role, is_primary)
      select v_draft_id, row_number() over (order by a.ord)::integer, left(n.nom, 500),
             case when a.value->>'role' = any (array['autor','coautor','organizacao','organizador','tradutor','ilustrador','prefaciador','coordenador','editor','realizador','roteirista','ator','interprete','compositor','narrador','produtor','locutor','outro']) then a.value->>'role' else 'autor' end,
             row_number() over (order by a.ord) = 1
        from jsonb_array_elements(case when jsonb_typeof(rec.authors) = 'array' then rec.authors else '[]'::jsonb end)
             with ordinality as a(value, ord)
        cross join lateral (select ingest.fn_h18_nom_d_auteur(a.value) as nom) n
       where n.nom is not null and not public.fn_conv_est_non_agent(n.nom);
    end if;

    insert into ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id, created_by)
    values (rec.id, rec.run_id, v_draft_id, v_batch_id, v_actor);

    update ingest.partner_catalog_staging_rows
       set created_book_draft_id = v_draft_id,
           review_status = 'draft_created',
           selected_for_draft = false
     where id = rec.id;

    v_created_count := v_created_count + 1;
  end loop;

  if v_created_count = 0 then
    -- IMP-27 (d) : un lot repris n'est pas à nous ; on ne supprime que le neuf.
    if v_batch_neuf then
      delete from public.catalog_batches where id = v_batch_id;
    end if;
    raise exception 'Aucun rascunho créé pour le run %', p_run_id;
  end if;

  -- H20 (revue du 28/09) : une clé que plusieurs lignes du run portent, ou le
  -- numéro d'un fascicule, n'est pas un identifiant d'origine : effacée des
  -- brouillons du run avant qu'une publication ne la recopie.
  perform ingest.fn_h20_effacer_faux_identifiants(p_run_id);

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);

  return jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch_id,
    'batch_name', v_batch_name,
    'requested_rows', v_requested_count,
    'created_drafts', v_created_count,
    'run', v_refresh
  );
end;
$function$
  $oracle$;

  -- ── Les lignes de T1/T2 : chaque branche de la correspondance ───────
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_s1, v_lib, 'essai/l2-egalite.iso', 'l2-egalite.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_req;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, item_type, title, subtitle, responsibility_statement, authors,
         publisher, place_of_publication, publication_year, edition_statement, language, isbn, issn, subjects, raw_payload, normalized_payload,
         match_status, editorial_decision, editorial_note)
  VALUES
  -- 1 MARC : responsabilités structurées (non-agent, nom vide, rôle inconnu, objet invalide, code trop long), collection, cdd, notes, url, mots-clés
  (v_req, 1, 'L2-EQ-1', 'am', ' Le titre  ', '', NULL, '["Dupont, Jean", "Collectif"]', ' Ed. X ', 'Paris', ' 1999 ', '2e ed.', 'fre',
   '2-07-036822-X', NULL, '["Anarchisme", "Syndicalisme"]', v_marc,
   '{"title": " Le titre  ", "material_type": "livro", "pages": "166", "series": " Medium ", "classification": " 840 ", "notes": " Une note ",
     "url": "http://ex.org/a", "keywords": ["k1", "k2"],
     "contributors": [{"name": "Dupont, Jean", "nature": "person", "role": "autor", "role_code": "070", "primary": true},
                      {"name": "Collectif", "role": "autor"}, {"name": "  ", "role": "autor"},
                      {"name": " Martin, Paul ", "role": "bizarre", "role_code": "   ", "primary": false}, "pas un objet",
                      {"name": "Org", "nature": "collective", "role": "organizacao", "role_code": "0123456789012345678901234567890123456789XYZ"}],
     "items": []}', 'new_record', 'accept_new', 'note de revue'),
  -- 2 article : ISSN de la revue hôte d'abord, revue, volume, numéro, date, pages ; auteurs objets (repli)
  (v_req, 2, 'L2-EQ-2', 'aa', 'Un article', NULL, NULL, '[{"family": "Doe", "given": "Ann", "role": "tradutor"}, {"label": "Vários"}]',
   NULL, NULL, '2001', NULL, 'spa', NULL, '9999-9999', '[]', '{}',
   '{"material_type": "artigo", "host": {"issn": " 1234-5678 ", "title": "Revue", "volume": "12"}, "issue": {"number": "3", "date": "2001"},
     "extent": "p. 10-20", "contributors": []}', 'new_record', 'accept_new', NULL),
  -- 3 fascicule : titre clé, numéro, date, ISSN de l'hôte faute du sien
  (v_req, 3, 'L2-EQ-3', 'as', 'Bulletin', NULL, NULL, '[]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '[]', '{}',
   '{"material_type": "periodico", "key_title": "Cle", "issue": {"number": "42", "date": "1930"}, "host": {"issn": "1111-2222"}}', 'new_record', 'accept_new', NULL),
  -- 4 ressource en ligne : l'adresse va à digital_native_url, pas aux notes
  (v_req, 4, 'L2-EQ-4', 'lm', 'En ligne', NULL, NULL, '[]', NULL, NULL, NULL, NULL, 'por', NULL, NULL, '[]', '{}',
   '{"material_type": "recurso_digital", "url": " http://num.example/x "}', 'new_record', 'accept_new', NULL),
  -- 5 CSV : type brut JOUR, mention de responsabilité, auteurs chaînes
  (v_req, 5, 'L2-EQ-5', 'JOUR', 'Journal CSV', NULL, 'Durand (dir.)', '["Durand"]', NULL, NULL, NULL, NULL, 'por', NULL, NULL, '[]',
   '{"numero": "5", "periodico": ""}', '{}', 'new_record', 'accept_new', NULL),
  -- 6 RIS : ligne normalisée vide ; collection (T2) et cote locale (CN) lues dans le brut
  (v_req, 6, 'L2-EQ-6', 'THES', 'These', NULL, NULL, '[{"family": "Roe", "given": "Bo"}]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '["Sujet"]',
   '{"ris": {"T2": "Collection RIS", "CN": "COTE-1"}}', '{}', 'new_record', 'accept_new', NULL),
  -- 7 collection = titre (espaces, casse) : pas de collection
  (v_req, 7, 'L2-EQ-7', 'pamp', 'Meme  titre', NULL, NULL, '[]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '[]', '{}',
   '{"collection": "meme titre", "material_type": "xyz"}', 'new_record', 'accept_new', NULL),
  -- 8 type de revue : la collection n'est pas gardée ; pages trop longues
  (v_req, 8, 'L2-EQ-8', 'Journal article', 'Article de revue', NULL, NULL, '[]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '[]', '{}',
   '{"collection": "Col", "pages": "123456"}', 'new_record', 'accept_new', NULL),
  -- 9 et 10 : la même clé deux fois dans le fichier (effacée des deux brouillons)
  (v_req, 9, 'L2-DUP', 'am', 'Doublon a', NULL, NULL, '[]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '[]', '{}', '{"material_type": "tract"}', 'new_record', 'accept_new', NULL),
  (v_req, 10, 'L2-DUP', 'am', 'Doublon b', NULL, NULL, '[]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '[]', '{}', '{"pages": " 12 "}', 'new_record', 'accept_new', NULL),
  -- 11 sans clé, type inconnu
  (v_req, 11, '  ', 'zz', 'Sans cle', NULL, NULL, '"pas une liste"', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '"pas une liste"', '{}',
   '{"pages": "7", "contributors": "pas une liste", "keywords": []}', 'new_record', 'accept_new', NULL);

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 egalite de la creation : brouillons, responsabilites, liens, lignes et resultat identiques a la definition d''avant';
  BEGIN
    BEGIN
      v_res := pg_temp.h21l2_creation_d_avant(v_req, ARRAY(SELECT id FROM ingest.partner_catalog_staging_rows WHERE run_id = v_req), 'L2 egalite', NULL, v_coord);
      v_avant := pg_temp.l2_projection(v_req);
      v_res2 := v_res - 'batch_id';
      RAISE EXCEPTION 'annuler' USING ERRCODE = 'P0099';
    EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;
    v_res := ingest.fn_create_book_drafts_from_import_rows(v_req, ARRAY(SELECT id FROM ingest.partner_catalog_staging_rows WHERE run_id = v_req), 'L2 egalite', NULL, v_coord);
    v_apres := pg_temp.l2_projection(v_req);
    IF v_avant = v_apres AND v_res - 'batch_id' = v_res2 AND jsonb_array_length(v_apres) = 11
       AND (v_res->>'created_drafts')::int = 11
       AND (SELECT count(*) FROM public.book_draft_contributors c JOIN public.book_drafts d ON d.id = c.draft_id WHERE d.batch_id = (v_res->>'batch_id')::bigint) = 6
    THEN v_passed := v_passed+1;
    ELSE
      SELECT string_agg(format('ligne %s %s', a->>'row_no', k), ', ') INTO v_txt
        FROM jsonb_array_elements(coalesce(v_avant, '[]')) WITH ORDINALITY x(a, n)
        JOIN jsonb_array_elements(coalesce(v_apres, '[]')) WITH ORDINALITY y(b, m) ON m = n
        CROSS JOIN LATERAL jsonb_object_keys(a->'brouillon' || jsonb_build_object('responsabilites', 1, 'ligne', 1)) k
       WHERE CASE WHEN k IN ('responsabilites', 'ligne') THEN a->k IS DISTINCT FROM b->k ELSE a->'brouillon'->k IS DISTINCT FROM b->'brouillon'->k END;
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt, '')||' resultat '||((v_res - 'batch_id') = v_res2)::text
                  ||' n='||coalesce(jsonb_array_length(v_apres), 0)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 une seule regle : chaque brouillon est ce que fn_import_row_as_book dit de sa ligne (sauf la cle repetee, effacee par le run)';
  BEGIN
    SELECT string_agg(format('ligne %s : %s', x.row_no, x.k), ', ' ORDER BY x.row_no, x.k) INTO v_txt
      FROM (
        SELECT s.row_no, k.k
          FROM ingest.partner_catalog_staging_rows s
          JOIN ingest.partner_catalog_row_to_draft m ON m.staging_row_id = s.id
          JOIN public.book_drafts d ON d.id = m.draft_id
          CROSS JOIN LATERAL (SELECT ingest.fn_import_row_as_book(s, ingest.fn_h21_contexte_du_run(s.run_id)) AS v) f
          CROSS JOIN LATERAL (
            SELECT c.k FROM jsonb_each(f.v->'mapped' || f.v->'provenance') c(k, val) WHERE to_jsonb(d)->c.k IS DISTINCT FROM c.val
            UNION ALL
            SELECT 'marc_json' WHERE (d.marc_json - 'anarbib_provenance' - 'anarbib_acquisition' - 'anarbib_network') IS DISTINCT FROM f.v->'marc_json'
            UNION ALL
            SELECT 'responsabilites'
             WHERE coalesce((SELECT jsonb_agg(jsonb_build_object('position', c.position, 'name', c.name, 'role', c.role,
                                                                'is_primary', c.is_primary, 'nature', c.nature, 'role_code', c.role_code) ORDER BY c.position)
                               FROM public.book_draft_contributors c WHERE c.draft_id = d.id), '[]'::jsonb) IS DISTINCT FROM f.v->'contributors') k
         WHERE s.run_id = v_req) x;
    v_n := (SELECT count(*) FROM public.book_drafts);
    v_v := ingest.fn_import_row_as_book((SELECT s FROM ingest.partner_catalog_staging_rows s WHERE s.run_id = v_req AND s.row_no = 1),
                                        ingest.fn_h21_contexte_du_run(v_req));
    v_v2 := ingest.fn_import_row_as_book((SELECT s FROM ingest.partner_catalog_staging_rows s WHERE s.run_id = v_req AND s.row_no = 1),
                                         ingest.fn_h21_contexte_du_run(v_req));
    IF v_txt = 'ligne 9 : source_record_id, ligne 10 : source_record_id'
       AND v_v = v_v2 AND v_n = (SELECT count(*) FROM public.book_drafts)
       AND (SELECT provolatile FROM pg_proc WHERE oid = 'ingest.fn_import_row_as_book(ingest.partner_catalog_staging_rows, jsonb)'::regprocedure) = 'i'
       AND v_v->'mapped'->>'titulo' = 'Le titre' AND v_v->'mapped'->>'colecao' = 'Medium'
       AND jsonb_array_length(v_v->'contributors') = 3
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt, 'aucun ecart (la cle repetee devait differer)')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 (a) publication d''un lot importe : une base par identifiant, exacte (le fichier, pas la retouche), confirmee';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s1, v_lib, 'essai/l2-a.iso', 'l2-a.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_ra;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, isbn, subjects, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_ra, 1, 'L2-A1', 'L2 Notice A1', '["Auteur, Un"]', NULL, '["Sujet A"]', v_marc,
            '{"title": "L2 Notice A1", "material_type": "livro", "classification": "320", "items": [],
              "contributors": [{"name": "Auteur, Un", "nature": "person", "role": "autor", "role_code": "070"}]}', 'new_record', 'accept_new'),
           (v_ra, 2, 'L2-A2', 'L2 Notice A2', '["Auteur, Deux"]', NULL, '[]', v_marc, '{"title": "L2 Notice A2", "items": []}', 'new_record', 'accept_new'),
           (v_ra, 3, 'L2-F1', 'L2 Notice a fondre', '[]', NULL, '[]', v_marc, '{"title": "L2 Notice a fondre", "items": []}', 'new_record', 'accept_new');
    v_lot := pg_temp.l2_promouvoir(v_ra, v_coord);
    v_d1 := pg_temp.l2_draft(v_ra, 'L2-A1');
    UPDATE public.book_drafts SET titulo = 'L2 Titre retouche avant publication' WHERE id = v_d1;
    PERFORM pg_temp.l2_reviser(v_lot, v_coord, v_admin);
    PERFORM public.publish_catalog_batch(v_lot);
    v_b1 := (SELECT published_book_id FROM public.book_drafts WHERE id = v_d1);
    v_b2 := (SELECT published_book_id FROM public.book_drafts WHERE id = pg_temp.l2_draft(v_ra, 'L2-A2'));
    v_v := pg_temp.l2_base(v_lib, v_s1, 'L2-A1');
    v_v2 := pg_temp.l2_base(v_lib, v_s1, 'L2-A2');
    IF pg_temp.l2_base_exacte(v_v, pg_temp.l2_ligne(v_ra, 'L2-A1')) AND pg_temp.l2_base_exacte(v_v2, pg_temp.l2_ligne(v_ra, 'L2-A2'))
       AND (v_v->>'book_id')::bigint = v_b1 AND (v_v2->>'book_id')::bigint = v_b2
       AND v_v->>'origine' = 'import' AND v_v->>'confirmed_at' IS NOT NULL AND v_v->'reprise_champs_douteux' = '[]'::jsonb
       AND v_v->'mapped'->>'titulo' = 'L2 Notice A1'
       AND (SELECT titulo FROM public.books WHERE id = v_b1) = 'L2 Titre retouche avant publication'
       AND v_v->'mapped'->>'cdd' = '320' AND v_v->'contributors'->0->>'role_code' = '070'
       AND v_v->'raw_payload' = v_marc
       AND (SELECT count(*) FROM ingest.book_import_baselines bl JOIN public.book_external_ids e ON e.id = bl.external_id_id
             JOIN public.book_drafts d ON d.published_book_id = e.book_id AND d.batch_id = v_lot) = 3
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_v::text, 'pas de base A1'), 300)); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 (a) un brouillon importe absorbe par un autre : a la publication du survivant, son identifiant recoit SA base';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s1, v_lib, 'essai/l2-ab.iso', 'l2-ab.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_rab;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_rab, 1, 'L2-AB1', 'L2 Survivant', v_marc, '{"title": "L2 Survivant", "items": []}', 'new_record', 'accept_new'),
           (v_rab, 2, 'L2-AB2', 'L2 Absorbe', v_marc, '{"title": "L2 Absorbe", "classification": "900", "items": []}', 'new_record', 'accept_new');
    v_lot := pg_temp.l2_promouvoir(v_rab, v_coord);
    PERFORM api.merge_book_drafts(pg_temp.l2_draft(v_rab, 'L2-AB1'), pg_temp.l2_draft(v_rab, 'L2-AB2'), '{}'::jsonb);
    PERFORM pg_temp.l2_reviser(v_lot, v_coord, v_admin);
    PERFORM public.publish_catalog_batch(v_lot);
    v_b1 := (SELECT published_book_id FROM public.book_drafts WHERE id = pg_temp.l2_draft(v_rab, 'L2-AB1'));
    v_v := pg_temp.l2_base(v_lib, v_s1, 'L2-AB1');
    v_v2 := pg_temp.l2_base(v_lib, v_s1, 'L2-AB2');
    IF pg_temp.l2_base_exacte(v_v, pg_temp.l2_ligne(v_rab, 'L2-AB1')) AND pg_temp.l2_base_exacte(v_v2, pg_temp.l2_ligne(v_rab, 'L2-AB2'))
       AND (v_v->>'book_id')::bigint = v_b1 AND (v_v2->>'book_id')::bigint = v_b1
       AND v_v2->'mapped'->>'titulo' = 'L2 Absorbe' AND v_v2->>'confirmed_at' IS NOT NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : survivant '||(v_v IS NOT NULL)::text||', absorbe '||coalesce(left(v_v2::text, 200), 'aucune')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 (b) absorption par une notice existante : base posee et confirmee ; une seconde absorption du meme identifiant l''avance';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Notice de B', 'L2-KB', 'livro', v_libB) RETURNING id INTO v_kB;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_kB, v_libB);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s1, v_lib, 'essai/l2-m1.iso', 'l2-m1.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_rm1;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_rm1, 1, 'L2-M1', 'L2 Absorbee, premier fichier', v_marc, '{"title": "L2 Absorbee, premier fichier", "items": []}', 'new_record', 'accept_new');
    PERFORM pg_temp.l2_promouvoir(v_rm1, v_coord);
    PERFORM api.merge_draft_into_book(pg_temp.l2_draft(v_rm1, 'L2-M1'), v_kB, '{}'::jsonb);
    v_v := pg_temp.l2_base(v_lib, v_s1, 'L2-M1');
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s1, v_lib, 'essai/l2-m2.iso', 'l2-m2.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_rm2;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_rm2, 1, 'L2-M1', 'L2 Absorbee, second fichier', jsonb_set(v_marc, '{leader}', '"00000nam0 22000001i 451 "'),
            '{"title": "L2 Absorbee, second fichier", "items": []}', 'new_record', 'accept_new');
    PERFORM pg_temp.l2_promouvoir(v_rm2, v_coord);
    PERFORM api.merge_draft_into_book(pg_temp.l2_draft(v_rm2, 'L2-M1'), v_kB, '{}'::jsonb);
    v_v2 := pg_temp.l2_base(v_lib, v_s1, 'L2-M1');
    IF pg_temp.l2_base_exacte(v_v, pg_temp.l2_ligne(v_rm1, 'L2-M1')) AND (v_v->>'book_id')::bigint = v_kB
       AND v_v->>'confirmed_at' IS NOT NULL AND v_v->>'origine' = 'import'
       AND pg_temp.l2_base_exacte(v_v2, pg_temp.l2_ligne(v_rm2, 'L2-M1'))
       AND v_v2->>'id' = v_v->>'id' AND v_v2->'mapped'->>'titulo' = 'L2 Absorbee, second fichier'
       AND (SELECT count(*) FROM public.book_external_ids e WHERE e.book_id = v_kB) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : premiere '||coalesce(left(v_v::text, 150), 'aucune')||' ; seconde '||coalesce(v_v2->'mapped'->>'titulo', 'aucune')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 (IMP-28 c) lot de BLMF reattribue a B : absorbe par B ou publie, identifiant et base a BLMF, rien pour B';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Autre notice de B', 'L2-KB2', 'livro', v_libB) RETURNING id INTO v_kB2;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_kB2, v_libB);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s1, v_lib, 'essai/l2-r.iso', 'l2-r.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_rr;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_rr, 1, 'L2-R1', 'L2 Reattribuee, absorbee par B', v_marc, '{"title": "L2 Reattribuee, absorbee par B", "items": []}', 'new_record', 'accept_new'),
           (v_rr, 2, 'L2-R2', 'L2 Reattribuee, publiee', v_marc, '{"title": "L2 Reattribuee, publiee", "items": []}', 'new_record', 'accept_new');
    v_lot := pg_temp.l2_promouvoir(v_rr, v_coord);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_reassign_library(v_lot, v_libB);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    PERFORM api.merge_draft_into_book(pg_temp.l2_draft(v_rr, 'L2-R1'), v_kB2, '{}'::jsonb);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_res := public.fn_batch_review_request(v_lot, 'L2 : lot reattribue a B');
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    v_b2 := public.publish_book_draft(pg_temp.l2_draft(v_rr, 'L2-R2'));
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_v := pg_temp.l2_base(v_lib, v_s1, 'L2-R1');
    v_v2 := pg_temp.l2_base(v_lib, v_s1, 'L2-R2');
    IF pg_temp.l2_base_exacte(v_v, pg_temp.l2_ligne(v_rr, 'L2-R1')) AND (v_v->>'book_id')::bigint = v_kB2
       AND pg_temp.l2_base_exacte(v_v2, pg_temp.l2_ligne(v_rr, 'L2-R2')) AND (v_v2->>'book_id')::bigint = v_b2
       AND EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = v_b2 AND h.library_id = v_libB)
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.library_id = v_libB AND e.value IN ('L2-R1', 'L2-R2'))
       AND NOT EXISTS (SELECT 1 FROM ingest.book_import_baselines bl JOIN public.book_external_ids e ON e.id = bl.external_id_id WHERE e.library_id = v_libB)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : identifiants='
         ||coalesce((SELECT string_agg(CASE e.library_id WHEN v_lib THEN 'BLMF' WHEN v_libB THEN 'B' ELSE '?' END||'/'||e.value
                                       ||'/base:'||(EXISTS (SELECT 1 FROM ingest.book_import_baselines bl WHERE bl.external_id_id = e.id))::text, ', ')
                       FROM public.book_external_ids e WHERE e.value IN ('L2-R1', 'L2-R2')), 'aucun')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 (c) rapprochement : base creee non confirmee si absente ; un second rapprochement ne l''avance pas ; une base confirmee intacte';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Notice rapprochee', 'L2-KC', 'livro', v_lib) RETURNING id INTO v_kC;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_kC, v_lib);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s1, v_lib, 'essai/l2-c1.iso', 'l2-c1.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_rc1;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_rc1, 1, 'L2-C1', 'L2 Rapprochee, premier fichier', v_marc, 'matched_book', 'pending', v_kC,
            '{"title": "L2 Rapprochee, premier fichier", "items": [{"source_item_code": "L2-C1-X", "call_number": "C X"}]}')
    RETURNING id INTO v_row;
    PERFORM pg_temp.l2_rapprocher(v_rc1, v_row, v_coord, v_admin);
    v_v := pg_temp.l2_base(v_lib, v_s1, 'L2-C1');
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s1, v_lib, 'essai/l2-c2.iso', 'l2-c2.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_rc2;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_rc2, 1, 'L2-C1', 'L2 Rapprochee, second fichier', v_marc, 'known_record', 'pending', v_kC,
            '{"title": "L2 Rapprochee, second fichier", "items": [{"source_item_code": "L2-C1-Y", "call_number": "C Y"}]}')
    RETURNING id INTO v_row2;
    PERFORM pg_temp.l2_rapprocher(v_rc2, v_row2, v_coord, v_admin);
    v_v2 := pg_temp.l2_base(v_lib, v_s1, 'L2-C1');
    -- la notice A1 (T3) : base confirmée ; un rapprochement d'un nouveau fichier n'y touche pas
    v_snap := pg_temp.l2_base(v_lib, v_s1, 'L2-A1');
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s1, v_lib, 'essai/l2-c3.iso', 'l2-c3.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_rc3;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_rc3, 1, 'L2-A1', 'L2 Notice A1, reimportee changee', v_marc, 'known_record', 'pending', (v_snap->>'book_id')::bigint,
            '{"title": "L2 Notice A1, reimportee changee", "items": [{"source_item_code": "L2-A1-Z", "call_number": "A Z"}]}')
    RETURNING id INTO v_row2;
    v_e := pg_temp.l2_rapprocher(v_rc3, v_row2, v_coord, v_admin);
    v_snap2 := pg_temp.l2_base(v_lib, v_s1, 'L2-A1');
    IF pg_temp.l2_base_exacte(v_v, v_row) AND (v_v->>'book_id')::bigint = v_kC
       AND v_v->>'origine' = 'import' AND v_v->>'confirmed_at' IS NULL
       AND v_v2 = v_v
       AND v_snap2 = v_snap AND v_e IS NOT NULL
       AND (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_kC) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : premiere '||coalesce(left(v_v::text, 160), 'aucune')
                    ||' ; avancee '||(v_v2 IS DISTINCT FROM v_v)::text||' ; A1 touchee '||(v_snap2 IS DISTINCT FROM v_snap)::text); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T8 ──────────────────────────────────────────────────────────────
  v_t := 'T8 (c, IMP-28 c) rapproche publie a BLMF puis reattribue a B : base a BLMF seulement';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Notice a reattribuer', 'L2-KT', 'livro', v_lib) RETURNING id INTO v_kT;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_kT, v_lib), (v_kT, v_libB);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s1, v_lib, 'essai/l2-t.iso', 'l2-t.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_rt;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_rt, 1, 'L2-T1', 'L2 Exemplaire reattribue', v_marc, 'matched_book', 'pending', v_kT,
            '{"title": "L2 Exemplaire reattribue", "items": [{"source_item_code": "L2-T1-X", "call_number": "T X"}]}')
    RETURNING id INTO v_row;
    v_e := pg_temp.l2_rapprocher(v_rt, v_row, v_coord, v_admin);
    SELECT x.id INTO v_x FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_row;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.exemplar_drafts
       SET target_library_id = v_libB, target_holding_id = NULL, tombo = NULL, updated_by = v_admin, batch_id = NULL
     WHERE id = v_x;
    PERFORM public.publish_exemplar_draft(v_x);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_v := pg_temp.l2_base(v_lib, v_s1, 'L2-T1');
    IF pg_temp.l2_base_exacte(v_v, v_row) AND (v_v->>'book_id')::bigint = v_kT
       AND (SELECT e.library_id FROM public.exemplares e WHERE e.id = v_e) = v_libB
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.library_id = v_libB AND e.value = 'L2-T1')
       AND NOT EXISTS (SELECT 1 FROM ingest.book_import_baselines bl JOIN public.book_external_ids e ON e.id = bl.external_id_id WHERE e.library_id = v_libB)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(left(v_v::text, 200), 'pas de base a BLMF')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T9 ──────────────────────────────────────────────────────────────
  v_t := 'T9 fusion de notices : l''identifiant passe a la notice gardee, la base le suit';
  BEGIN
    v_snap := pg_temp.l2_base(v_lib, v_s1, 'L2-F1');
    v_b3 := (v_snap->>'book_id')::bigint;
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Notice gardee', 'L2-KF', 'livro', v_lib) RETURNING id INTO v_kF;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_kF, v_lib);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_fusion_notices(v_kF, v_b3);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_snap2 := pg_temp.l2_base(v_lib, v_s1, 'L2-F1');
    IF v_snap IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.books WHERE id = v_b3)
       AND (v_snap2->>'book_id')::bigint = v_kF
       AND (v_snap2 - 'book_id') = (v_snap - 'book_id')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : avant '||coalesce(v_snap->>'book_id', '-')||' apres '||coalesce(left(v_snap2::text, 150), 'aucune')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 suppression : l''identifiant supprime emporte sa base ; la notice supprimee emporte identifiant et base';
  BEGIN
    v_bl := (pg_temp.l2_base(v_lib, v_s1, 'L2-A2')->>'id')::bigint;
    DELETE FROM public.book_external_ids WHERE library_id = v_lib AND scheme = 'import:' || v_s1 AND value = 'L2-A2';
    v_ok := NOT EXISTS (SELECT 1 FROM ingest.book_import_baselines WHERE id = v_bl);
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Notice a supprimer', 'L2-KX', 'livro', v_lib) RETURNING id INTO v_kX;
    PERFORM ingest.fn_record_book_external_id(v_kX, v_lib, v_s1, 'L2-X');
    v_ok := v_ok AND ingest.fn_h21_poser_base(v_kX, v_lib, v_s1, 'L2-X', ingest.fn_h21_base_de_la_ligne(pg_temp.l2_ligne(v_ra, 'L2-A2')), 'import', true, true);
    v_bl := (pg_temp.l2_base(v_lib, v_s1, 'L2-X')->>'id')::bigint;
    DELETE FROM public.books WHERE id = v_kX;
    IF v_ok AND v_bl IS NOT NULL AND NOT EXISTS (SELECT 1 FROM ingest.book_import_baselines WHERE id = v_bl)
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids WHERE value = 'L2-X')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_ok::text, 'NULL')||' '||coalesce(v_bl::text, 'pas de base')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 ─────────────────────────────────────────────────────────────
  v_t := 'T11 une cle deja a une autre notice (doublon) : aucune base, ni pour la nouvelle ni pour l''ancienne';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Detentrice de la cle', 'L2-KD', 'livro', v_lib) RETURNING id INTO v_kX;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_kX, v_lib);
    PERFORM ingest.fn_record_book_external_id(v_kX, v_lib, v_s1, 'L2-DBL');
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s1, v_lib, 'essai/l2-dbl.iso', 'l2-dbl.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_rdbl;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_rdbl, 1, 'L2-DBL', 'L2 Doublon cree malgre tout', v_marc, '{"title": "L2 Doublon cree malgre tout", "items": []}', 'new_record', 'accept_new');
    v_lot := pg_temp.l2_promouvoir(v_rdbl, v_coord);
    PERFORM pg_temp.l2_reviser(v_lot, v_coord, v_admin);
    PERFORM public.publish_catalog_batch(v_lot);
    v_b1 := (SELECT published_book_id FROM public.book_drafts WHERE id = pg_temp.l2_draft(v_rdbl, 'L2-DBL'));
    IF v_b1 IS NOT NULL AND v_b1 <> v_kX
       AND (SELECT e.book_id FROM public.book_external_ids e WHERE e.library_id = v_lib AND e.scheme = 'import:' || v_s1 AND e.value = 'L2-DBL') = v_kX
       AND pg_temp.l2_base(v_lib, v_s1, 'L2-DBL') IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(left(pg_temp.l2_base(v_lib, v_s1, 'L2-DBL')::text, 200), 'aucune base, notice '||coalesce(v_b1::text, '-'))); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T12 ─────────────────────────────────────────────────────────────
  v_t := 'T12 une copie (Editer) ne pose ni n''avance de base, republiee comme absorbee';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_snap := (SELECT to_jsonb(bl) FROM ingest.book_import_baselines bl WHERE bl.id = (pg_temp.l2_base(v_lib, v_s1, 'L2-A1')->>'id')::bigint);
    v_b1 := (pg_temp.l2_base(v_lib, v_s1, 'L2-A1')->>'book_id')::bigint;
    -- republiée : une reprise de la notice A1
    v_d2 := public.create_book_draft_from_book(v_b1);
    UPDATE public.book_drafts SET notas = 'L2 retouche par reprise' WHERE id = v_d2;
    PERFORM public.publish_book_draft(v_d2);
    -- absorbée : une autre reprise de A1, absorbée par sa propre notice, après
    -- que la ligne d'origine a changé (sonde : une copie qui relirait la ligne
    -- avancerait la base vers ce titre)
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Notice cataloguee hors import', 'L2-KR1', 'livro', v_lib) RETURNING id INTO v_kR1;
    v_d3 := public.create_book_draft_from_book(v_b1);
    UPDATE ingest.partner_catalog_staging_rows SET title = 'L2 Ligne relue entre-temps' WHERE id = pg_temp.l2_ligne(v_ra, 'L2-A1');
    v_n := (SELECT count(*) FROM ingest.book_import_baselines);
    PERFORM api.merge_draft_into_book(v_d3, v_b1, '{}'::jsonb);
    UPDATE ingest.partner_catalog_staging_rows SET title = 'L2 Notice A1' WHERE id = pg_temp.l2_ligne(v_ra, 'L2-A1');
    v_snap2 := (SELECT to_jsonb(bl) FROM ingest.book_import_baselines bl WHERE bl.id = (v_snap->>'id')::bigint);
    IF v_snap IS NOT NULL AND v_snap2 = v_snap
       AND (SELECT d.marc_json->'ingest' FROM public.book_drafts d WHERE d.id = v_d3) IS NOT NULL
       AND (SELECT d.status FROM public.book_drafts d WHERE d.id = v_d3) = 'cancelled'
       AND (SELECT count(*) FROM ingest.book_import_baselines) = v_n
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : base touchee '||(v_snap2 IS DISTINCT FROM v_snap)::text
                    ||', bases '||v_n||' -> '||(SELECT count(*) FROM ingest.book_import_baselines)); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T13 ─────────────────────────────────────────────────────────────
  v_t := 'T13 acces : l''API ne lit ni n''ecrit la base ; un droit pose a l''essai : policy staff de la bibliotheque / administration, aucune ecriture';
  DECLARE v_refus1 boolean := false; v_refus2 boolean := false; v_refus3 boolean := false; v_voit_blmf int; v_voit_b int; v_voit_admin int; v_tot int;
  BEGIN
    v_tot := (SELECT count(*) FROM ingest.book_import_baselines);
    -- une base pour B (publiée par B, T15 la rejouera) : posée à la main ici
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Base de B', 'L2-KR2', 'livro', v_libB) RETURNING id INTO v_kR2;
    PERFORM ingest.fn_record_book_external_id(v_kR2, v_libB, v_sB, 'L2-B-1');
    PERFORM ingest.fn_h21_poser_base(v_kR2, v_libB, v_sB, 'L2-B-1', ingest.fn_h21_base_de_la_ligne(pg_temp.l2_ligne(v_ra, 'L2-A1')), 'import', true, true);
    v_tot := v_tot + 1;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      PERFORM count(*) FROM ingest.book_import_baselines;
      EXECUTE 'RESET ROLE';
    EXCEPTION WHEN insufficient_privilege THEN v_refus1 := true; EXECUTE 'RESET ROLE'; END;
    BEGIN
      GRANT USAGE ON SCHEMA ingest TO authenticated;
      GRANT SELECT ON ingest.book_import_baselines TO authenticated;
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_voit_blmf := (SELECT count(*) FROM ingest.book_import_baselines);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
      v_voit_b := (SELECT count(*) FROM ingest.book_import_baselines);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
      v_voit_admin := (SELECT count(*) FROM ingest.book_import_baselines);
      BEGIN
        UPDATE ingest.book_import_baselines SET origine = 'reprise';
      EXCEPTION WHEN insufficient_privilege THEN v_refus2 := true; END;
      BEGIN
        DELETE FROM ingest.book_import_baselines;
      EXCEPTION WHEN insufficient_privilege THEN v_refus3 := true; END;
      EXECUTE 'RESET ROLE';
      RAISE EXCEPTION 'annuler' USING ERRCODE = 'P0099';
    EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_refus1 AND v_refus2 AND v_refus3 AND v_voit_b = 1 AND v_voit_admin = v_tot AND v_voit_blmf = v_tot - 1
       AND NOT has_schema_privilege('authenticated', 'ingest', 'USAGE')
       AND NOT has_table_privilege('authenticated', 'ingest.book_import_baselines', 'SELECT')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||format(' : refus %s/%s/%s, BLMF voit %s, B voit %s, admin voit %s sur %s',
                    v_refus1, v_refus2, v_refus3, v_voit_blmf, v_voit_b, v_voit_admin, v_tot)); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T14 ─────────────────────────────────────────────────────────────
  -- L'état de la production le 05/10 : des identifiants sans base. On le
  -- reproduit en effaçant les bases que la publication vient de poser, sur un
  -- run de la source sans bibliothèque (comme la source 3 de MLEG).
  v_t := 'T14 reprise : ligne vivante, exemplaire rapproche, marc_json a defaut, rien sans source ; idempotente, bases existantes intactes';
  DECLARE v_r1 jsonb; v_r2 jsonb; v_avant_rep jsonb; v_existantes jsonb; v_existantes2 jsonb; v_reconst jsonb; v_rep1 jsonb; v_rep2 jsonb; v_rep3 jsonb; v_rep_aprs jsonb;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s3, NULL, 'essai/l2-reprise.csv', 'l2-reprise.csv', 'csv', 'ready_for_review') RETURNING id INTO v_rrep;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, subjects, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_rrep, 1, 'L2-REP-1', 'L2 Reprise par la ligne', '["Rep, Un"]', '["S1"]', '{"numero": "L2-REP-1", "titulo": "L2 Reprise par la ligne"}',
            '{"title": "L2 Reprise par la ligne", "authors": ["Rep, Un"], "subjects": ["S1"], "external_key": "L2-REP-1", "classification": "100"}', 'new_record', 'accept_new'),
           (v_rrep, 2, 'L2-REP-2', 'L2 Reprise par le brouillon', '["Rep, Deux"]', '["S2"]', '{"numero": "L2-REP-2", "titulo": "L2 Reprise par le brouillon"}',
            '{"title": "L2 Reprise par le brouillon", "authors": ["Rep, Deux"], "subjects": ["S2"], "external_key": "L2-REP-2", "series": "Col R", "pages": "77"}', 'new_record', 'accept_new');
    v_res := ingest.fn_create_book_drafts_from_import_rows(v_rrep, ARRAY(SELECT id FROM ingest.partner_catalog_staging_rows WHERE run_id = v_rrep), 'L2 reprise', NULL, v_admin);
    v_lot := (v_res->>'batch_id')::bigint;
    UPDATE public.book_drafts SET bib_ref = 'L2-REF-' || id, initial_copies_library_id = v_lib WHERE batch_id = v_lot;
    v_res := public.fn_batch_review_request(v_lot, 'L2 : reprise');
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM public.publish_catalog_batch(v_lot);
    v_kR3 := (SELECT published_book_id FROM public.book_drafts WHERE id = pg_temp.l2_draft(v_rrep, 'L2-REP-1'));
    v_kR4 := (SELECT published_book_id FROM public.book_drafts WHERE id = pg_temp.l2_draft(v_rrep, 'L2-REP-2'));
    -- les identifiants, comme la reprise H20 les a posés en production (bibliothèque : celle de l'identifiant)
    PERFORM ingest.fn_record_book_external_id(v_kR3, v_lib, v_s3, 'L2-REP-1');
    PERFORM ingest.fn_record_book_external_id(v_kR4, v_lib, v_s3, 'L2-REP-2');
    -- ce que la ligne 2 donnait avant de disparaître
    v_reconst := pg_temp.l2_attendu(pg_temp.l2_ligne(v_rrep, 'L2-REP-2'));
    v_r2 := ingest.fn_h21_base_de_la_ligne(pg_temp.l2_ligne(v_rrep, 'L2-REP-1'));
    v_row := pg_temp.l2_ligne(v_rrep, 'L2-REP-1');
    DELETE FROM ingest.partner_catalog_staging_rows WHERE id = pg_temp.l2_ligne(v_rrep, 'L2-REP-2');
    -- un identifiant sans aucune source (notice cataloguée hors import)
    PERFORM ingest.fn_record_book_external_id(v_kR1, v_lib, v_s3, 'L2-REP-SANS');
    -- l'exemplaire rapproché de T7 : sa base effacée, la ligne vivante demeure
    DELETE FROM ingest.book_import_baselines bl USING public.book_external_ids e
     WHERE e.id = bl.external_id_id AND e.library_id = v_lib AND e.value = 'L2-C1';
    v_existantes := (SELECT jsonb_agg(to_jsonb(bl) ORDER BY bl.id) FROM ingest.book_import_baselines bl);
    v_r1 := ingest.fn_h21_reprendre_les_bases();
    v_rep1 := pg_temp.l2_base(v_lib, v_s3, 'L2-REP-1');
    v_rep2 := pg_temp.l2_base(v_lib, v_s3, 'L2-REP-2');
    v_rep3 := pg_temp.l2_base(v_lib, v_s1, 'L2-C1');
    v_existantes2 := (SELECT jsonb_agg(to_jsonb(bl) ORDER BY bl.id) FROM ingest.book_import_baselines bl
                       WHERE bl.id <= (SELECT max((x->>'id')::bigint) FROM jsonb_array_elements(v_existantes) x));
    v_rep_aprs := (SELECT jsonb_agg(to_jsonb(bl) ORDER BY bl.id) FROM ingest.book_import_baselines bl);
    v_r2 := v_r2;  -- (la base attendue de la ligne 1)
    v_res2 := ingest.fn_h21_reprendre_les_bases();
    IF (v_r1->>'identifiants_sans_base')::int >= 4 AND (v_r1->>'depuis_la_ligne')::int >= 2 AND (v_r1->>'depuis_le_brouillon')::int >= 1
       AND (v_r1->>'sans_source')::int >= 1
       -- la ligne vivante
       AND pg_temp.l2_base_exacte(v_rep1, v_row) AND v_rep1->>'origine' = 'reprise' AND v_rep1->>'confirmed_at' IS NULL
       AND (v_rep1->>'book_id')::bigint = v_kR3
       AND (SELECT array_agg(x ORDER BY x) FROM jsonb_array_elements_text(v_rep1->'reprise_champs_douteux') x)
           = ARRAY['artigo_issue', 'artigo_pages', 'artigo_source', 'artigo_volume', 'cdd', 'colecao', 'contributors', 'data_edicao',
                   'digital_native_url', 'issn', 'notas', 'numero', 'paginas', 'tipo_material', 'titulo_periodico', 'volume']
       AND (v_rep1->>'imported_at')::timestamptz = (SELECT created_at FROM ingest.partner_catalog_staging_rows WHERE id = v_row)
       -- le brouillon, la ligne disparue : même correspondance que la ligne d'origine
       AND v_rep2->'mapped' = v_reconst->'mapped' AND v_rep2->'contributors' = v_reconst->'contributors'
       AND v_rep2->'subjects' = v_reconst->'subjects' AND v_rep2->'raw_payload' = v_reconst->'raw_payload'
       AND v_rep2->>'origine' = 'reprise' AND (v_rep2->>'book_id')::bigint = v_kR4 AND v_rep2->'mapped'->>'colecao' = 'Col R'
       -- l'exemplaire rapproché
       AND v_rep3->>'origine' = 'reprise' AND (v_rep3->>'book_id')::bigint = v_kC
       AND (v_rep3->>'staging_row_id')::bigint = (SELECT id FROM ingest.partner_catalog_staging_rows WHERE run_id = v_rc2)
       -- rien sans source
       AND pg_temp.l2_base(v_lib, v_s3, 'L2-REP-SANS') IS NULL
       -- les bases existantes intactes ; rejouée : rien de plus, rien de changé
       AND v_existantes2 = v_existantes
       AND (v_res2->>'identifiants_sans_base')::int = (v_r1->>'sans_source')::int
       AND (v_res2->>'depuis_la_ligne')::int = 0 AND (v_res2->>'depuis_le_brouillon')::int = 0
       AND (SELECT jsonb_agg(to_jsonb(bl) ORDER BY bl.id) FROM ingest.book_import_baselines bl) = v_rep_aprs
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_r1::text, '-')||' / '||coalesce(v_res2::text, '-')
                    ||' ; ligne '||coalesce(left(v_rep1::text, 120), 'aucune')||' ; brouillon '||coalesce(left((v_rep2->'mapped')::text, 160), 'aucune')
                    ||' ; attendu '||left((v_reconst->'mapped')::text, 160)||' ; rapproche '||coalesce(v_rep3->>'staging_row_id', 'aucune')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T15 ─────────────────────────────────────────────────────────────
  v_t := 'T15 export : la notice de B qui a absorbe un brouillon du PMB de BLMF reemet pour chacune SON enregistrement ; sans base, celui d''avant';
  DECLARE v_expA jsonb; v_expB jsonb; v_sans jsonb; v_raw_blmf jsonb; v_raw_b jsonb; v_kE bigint;
  BEGIN
    v_raw_b := jsonb_set(v_marc, '{fields,1,subfields,0,value}', '"Titre du PMB de B"');
    v_raw_blmf := jsonb_set(v_marc, '{fields,1,subfields,0,value}', '"Titre du PMB de BLMF"');
    -- B importe et publie sa notice (marc_json.ingest : le run de B)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_sB, v_libB, 'essai/l2-exp-b.iso', 'l2-exp-b.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_rexpb;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_rexpb, 1, 'B-77', 'L2 Notice partagee', v_raw_b, '{"title": "L2 Notice partagee", "items": []}', 'new_record', 'accept_new');
    v_lot := pg_temp.l2_promouvoir(v_rexpb, v_coordB);
    PERFORM pg_temp.l2_reviser(v_lot, v_coordB, v_admin);
    PERFORM public.publish_catalog_batch(v_lot);
    v_kE := (SELECT published_book_id FROM public.book_drafts WHERE id = pg_temp.l2_draft(v_rexpb, 'B-77'));
    -- BLMF importe la même œuvre et l'absorbe dans la notice de B (et y prend un fonds)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_kE, v_lib);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s1, v_lib, 'essai/l2-exp.iso', 'l2-exp.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_rexp;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_rexp, 1, 'L2-E1', 'L2 Notice partagee (BLMF)', v_raw_blmf, '{"title": "L2 Notice partagee (BLMF)", "items": []}', 'new_record', 'accept_new');
    PERFORM pg_temp.l2_promouvoir(v_rexp, v_coord);
    PERFORM api.merge_draft_into_book(pg_temp.l2_draft(v_rexp, 'L2-E1'), v_kE, '{}'::jsonb);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_expA := (SELECT r FROM jsonb_array_elements(public.fn_export_catalog_lote(v_lib)->'records') r WHERE (r->>'id')::bigint = v_kE);
    v_expB := (SELECT r FROM jsonb_array_elements(public.fn_export_catalog_lote(v_libB)->'records') r WHERE (r->>'id')::bigint = v_kE);
    BEGIN
      DELETE FROM ingest.book_import_baselines bl USING public.book_external_ids e WHERE e.id = bl.external_id_id AND e.book_id = v_kE;
      v_sans := jsonb_build_object(
        'blmf', (SELECT r FROM jsonb_array_elements(public.fn_export_catalog_lote(v_lib)->'records') r WHERE (r->>'id')::bigint = v_kE),
        'b', (SELECT r FROM jsonb_array_elements(public.fn_export_catalog_lote(v_libB)->'records') r WHERE (r->>'id')::bigint = v_kE));
      RAISE EXCEPTION 'annuler' USING ERRCODE = 'P0099';
    EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_expA->'source'->'fields'->1->'subfields'->0->>'value' = 'Titre du PMB de BLMF'
       AND v_expA->>'originId' = 'L2-E1'
       AND v_expB->'source'->'fields'->1->'subfields'->0->>'value' = 'Titre du PMB de B'
       AND NOT (v_expA->'source'->'fields' @> '[{"tag": "995"}]')
       -- sans base : BLMF n'a rien (case unique : marc_json.ingest est celui de B), B le sien
       AND NOT (v_sans->'blmf' ? 'source') AND v_sans->'b'->'source' = v_expB->'source'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : BLMF '||coalesce((v_expA->'source')::text, 'sans source')
                    ||' ; B '||coalesce(left((v_expB->'source')::text, 120), 'sans source')||' ; sans base '||left(coalesce(v_sans::text, '-'), 200)); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T16 ─────────────────────────────────────────────────────────────
  v_t := 'T16 structure et droits : cle unique, cascade, RLS sans FORCE, policy de lecture, aucun droit API, fonctions internes fermees';
  DECLARE v_f text; v_ko text := '';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conrelid = 'ingest.book_import_baselines'::regclass AND c.contype = 'f'
                    AND c.confrelid = 'public.book_external_ids'::regclass AND c.confdeltype = 'c') THEN v_ko := v_ko || ' cascade'; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = 'ingest.book_import_baselines'::regclass AND i.indisunique
                    AND i.indkey::text = (SELECT attnum::text FROM pg_attribute WHERE attrelid = 'ingest.book_import_baselines'::regclass AND attname = 'external_id_id'))
      THEN v_ko := v_ko || ' unique'; END IF;
    IF NOT (SELECT relrowsecurity AND NOT relforcerowsecurity FROM pg_class WHERE oid = 'ingest.book_import_baselines'::regclass) THEN v_ko := v_ko || ' rls'; END IF;
    IF (SELECT count(*) FROM pg_policy WHERE polrelid = 'ingest.book_import_baselines'::regclass AND polcmd = 'r') <> 1
       OR (SELECT count(*) FROM pg_policy WHERE polrelid = 'ingest.book_import_baselines'::regclass) <> 1 THEN v_ko := v_ko || ' policy'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.role_table_grants WHERE table_schema = 'ingest' AND table_name = 'book_import_baselines'
                AND grantee IN ('anon', 'authenticated', 'PUBLIC')) THEN v_ko := v_ko || ' droits-table'; END IF;
    FOREACH v_f IN ARRAY ARRAY[
      'ingest.fn_import_row_as_book(ingest.partner_catalog_staging_rows, jsonb)', 'ingest.fn_h21_contexte_du_run(bigint)',
      'ingest.fn_h21_base_de_la_ligne(bigint)', 'ingest.fn_h21_base_du_brouillon(bigint)',
      'ingest.fn_h21_poser_base(bigint, uuid, bigint, text, jsonb, text, boolean, boolean)',
      'ingest.fn_h21_poser_base_du_brouillon(bigint, bigint, boolean)', 'ingest.fn_h21_poser_base_rapprochee(bigint, bigint, uuid)',
      'ingest.fn_h21_bibliotheque_importatrice(bigint, bigint, uuid)',
      'ingest.fn_h21_reprendre_les_bases()'] LOOP
      IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
         OR NOT has_function_privilege('service_role', v_f, 'EXECUTE') THEN v_ko := v_ko || ' ' || v_f; END IF;
    END LOOP;
    IF position('ingest.fn_import_row_as_book(' IN pg_get_functiondef('ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure)) = 0
      THEN v_ko := v_ko || ' creation'; END IF;
    IF NOT has_function_privilege('authenticated', 'public.fn_export_catalog_lote(uuid, bigint, integer)', 'EXECUTE')
       OR NOT has_function_privilege('authenticated', 'api.merge_draft_into_book(bigint, bigint, jsonb)', 'EXECUTE') THEN v_ko := v_ko || ' ecran'; END IF;
    IF v_ko = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_ko); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T17 ─────────────────────────────────────────────────────────────
  -- La source 3 de la production : aucune bibliothèque, ni sur la source ni sur
  -- ses runs ; ses identifiants d'origine sont tous à MLEG (revue sceptique du 05/10).
  v_t := 'T17 (3 bis, repli 2) source sans bibliotheque dont les identifiants sont a MLEG, lot reattribue a B : publication et absorption posent identifiant ET base a MLEG, rien pour B';
  DECLARE v_r5 bigint; v_l5 bigint; v_kpub bigint; v_bm1 jsonb; v_bm2 jsonb;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    INSERT INTO public.libraries (id, slug, name, is_active, visibility_level, tombo_pattern)
    VALUES (gen_random_uuid(), 'essai-h21-l2-mleg', 'Essai H21 lot 2 — MLEG', true, 'private', '{"prefix": "L2M-T-", "year": false, "pad": 4}'::jsonb)
    RETURNING id INTO v_libM;
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('L2 MLEG, source sans bibliotheque', NULL, 'mapeada', 'manual_upload', false) RETURNING id INTO v_s5;
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Notice MLEG deja importee', 'L2-KM0', 'livro', v_libM) RETURNING id INTO v_km0;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_km0, v_libM), (v_km0, v_libB);
    PERFORM ingest.fn_record_book_external_id(v_km0, v_libM, v_s5, 'M-0');
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s5, NULL, 'essai/l2-mleg.csv', 'l2-mleg.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r5;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, subjects, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_r5, 1, 'M-1', 'L2 MLEG publiee', '["Mleg, Un"]', '[]', '{"numero": "M-1"}', '{"title": "L2 MLEG publiee"}', 'new_record', 'accept_new'),
           (v_r5, 2, 'M-2', 'L2 MLEG absorbee', '[]', '[]', '{"numero": "M-2"}', '{"title": "L2 MLEG absorbee"}', 'new_record', 'accept_new');
    v_res := ingest.fn_create_book_drafts_from_import_rows(v_r5, ARRAY(SELECT id FROM ingest.partner_catalog_staging_rows WHERE run_id = v_r5), 'L2 MLEG', NULL, v_admin);
    v_l5 := (v_res->>'batch_id')::bigint;
    UPDATE public.book_drafts SET bib_ref = 'L2-REF-' || id WHERE batch_id = v_l5;
    PERFORM public.fn_batch_reassign_library(v_l5, v_libB);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    PERFORM api.merge_draft_into_book(pg_temp.l2_draft(v_r5, 'M-2'), v_km0, '{}'::jsonb);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_res := public.fn_batch_review_request(v_l5, 'L2 : MLEG');
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    v_kpub := public.publish_book_draft(pg_temp.l2_draft(v_r5, 'M-1'));
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_bm1 := pg_temp.l2_base(v_libM, v_s5, 'M-1');
    v_bm2 := pg_temp.l2_base(v_libM, v_s5, 'M-2');
    IF pg_temp.l2_base_exacte(v_bm1, pg_temp.l2_ligne(v_r5, 'M-1')) AND (v_bm1->>'book_id')::bigint = v_kpub
       AND pg_temp.l2_base_exacte(v_bm2, pg_temp.l2_ligne(v_r5, 'M-2')) AND (v_bm2->>'book_id')::bigint = v_km0
       AND EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = v_kpub AND h.library_id = v_libB)
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.scheme = 'import:' || v_s5 AND e.library_id <> v_libM)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : identifiants='
         ||coalesce((SELECT string_agg(CASE e.library_id WHEN v_libM THEN 'MLEG' WHEN v_libB THEN 'B' WHEN v_lib THEN 'BLMF' ELSE '?' END||'/'||e.value
                                       ||'/base:'||(EXISTS (SELECT 1 FROM ingest.book_import_baselines bl WHERE bl.external_id_id = e.id))::text, ', ' ORDER BY e.value)
                       FROM public.book_external_ids e WHERE e.scheme = 'import:' || v_s5), 'aucun')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T18 ─────────────────────────────────────────────────────────────
  v_t := 'T18 (3 bis, repli 3) source neuve sans bibliotheque ni identifiants : a la bibliotheque du brouillon ; identifiants de la source dans deux bibliotheques : pas de choix, la bibliotheque du brouillon';
  DECLARE v_s4 bigint; v_s6 bigint; v_r4 bigint; v_r6 bigint; v_l4 bigint; v_l6 bigint; v_kn bigint; v_kp4 bigint; v_kp6 bigint;
          v_ka1 bigint; v_ka2 bigint; v_libC uuid; v_bn1 jsonb; v_bn2 jsonb; v_ba1 jsonb;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    INSERT INTO public.libraries (id, slug, name, is_active, visibility_level) VALUES (gen_random_uuid(), 'essai-h21-l2-c', 'Essai H21 lot 2 — C', true, 'private')
    RETURNING id INTO v_libC;
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('L2 source neuve sans bibliotheque', NULL, 'mapeada', 'manual_upload', false) RETURNING id INTO v_s4;
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('L2 source sans bibliotheque, identifiants partages', NULL, 'mapeada', 'manual_upload', false) RETURNING id INTO v_s6;
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Identifiant a BLMF', 'L2-KA1', 'livro', v_lib) RETURNING id INTO v_ka1;
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Identifiant a C', 'L2-KA2', 'livro', v_libC) RETURNING id INTO v_ka2;
    PERFORM ingest.fn_record_book_external_id(v_ka1, v_lib, v_s6, 'A-0');
    PERFORM ingest.fn_record_book_external_id(v_ka2, v_libC, v_s6, 'A-00');
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('L2 Notice qui absorbe N-2', 'L2-KN', 'livro', v_lib) RETURNING id INTO v_kn;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_kn, v_lib);
    -- la source neuve : lot donné à BLMF
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s4, NULL, 'essai/l2-neuve.csv', 'l2-neuve.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r4;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, subjects, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_r4, 1, 'N-1', 'L2 Source neuve, publiee', '[]', '[]', '{"numero": "N-1"}', '{"title": "L2 Source neuve, publiee"}', 'new_record', 'accept_new'),
           (v_r4, 2, 'N-2', 'L2 Source neuve, absorbee', '[]', '[]', '{"numero": "N-2"}', '{"title": "L2 Source neuve, absorbee"}', 'new_record', 'accept_new');
    v_l4 := (ingest.fn_create_book_drafts_from_import_rows(v_r4, ARRAY(SELECT id FROM ingest.partner_catalog_staging_rows WHERE run_id = v_r4), 'L2 neuve', NULL, v_admin)->>'batch_id')::bigint;
    UPDATE public.book_drafts SET bib_ref = 'L2-REF-' || id WHERE batch_id = v_l4;
    PERFORM public.fn_batch_reassign_library(v_l4, v_lib);
    -- la source aux identifiants partagés : lot donné à B
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s6, NULL, 'essai/l2-partagee.csv', 'l2-partagee.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r6;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, subjects, raw_payload, normalized_payload, match_status, editorial_decision)
    VALUES (v_r6, 1, 'A-1', 'L2 Identifiants partages, publiee', '[]', '[]', '{"numero": "A-1"}', '{"title": "L2 Identifiants partages, publiee"}', 'new_record', 'accept_new');
    v_l6 := (ingest.fn_create_book_drafts_from_import_rows(v_r6, ARRAY(SELECT id FROM ingest.partner_catalog_staging_rows WHERE run_id = v_r6), 'L2 partagee', NULL, v_admin)->>'batch_id')::bigint;
    UPDATE public.book_drafts SET bib_ref = 'L2-REF-' || id WHERE batch_id = v_l6;
    PERFORM public.fn_batch_reassign_library(v_l6, v_libB);
    v_res := public.fn_batch_review_request(v_l6, 'L2 : identifiants partages');
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    v_kp6 := public.publish_book_draft(pg_temp.l2_draft(v_r6, 'A-1'));
    -- BLMF absorbe N-2, fait réviser et publie N-1
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM api.merge_draft_into_book(pg_temp.l2_draft(v_r4, 'N-2'), v_kn, '{}'::jsonb);
    PERFORM pg_temp.l2_reviser(v_l4, v_coord, v_admin);
    v_kp4 := public.publish_book_draft(pg_temp.l2_draft(v_r4, 'N-1'));
    v_bn1 := pg_temp.l2_base(v_lib, v_s4, 'N-1');
    v_bn2 := pg_temp.l2_base(v_lib, v_s4, 'N-2');
    v_ba1 := pg_temp.l2_base(v_libB, v_s6, 'A-1');
    IF pg_temp.l2_base_exacte(v_bn1, pg_temp.l2_ligne(v_r4, 'N-1')) AND (v_bn1->>'book_id')::bigint = v_kp4
       AND pg_temp.l2_base_exacte(v_bn2, pg_temp.l2_ligne(v_r4, 'N-2')) AND (v_bn2->>'book_id')::bigint = v_kn
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.scheme = 'import:' || v_s4 AND e.library_id <> v_lib)
       AND pg_temp.l2_base_exacte(v_ba1, pg_temp.l2_ligne(v_r6, 'A-1')) AND (v_ba1->>'book_id')::bigint = v_kp6
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.scheme = 'import:' || v_s6 AND e.value = 'A-1' AND e.library_id <> v_libB)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : identifiants='
         ||coalesce((SELECT string_agg(CASE e.library_id WHEN v_libC THEN 'C' WHEN v_libB THEN 'B' WHEN v_lib THEN 'BLMF' ELSE '?' END||'/'||e.value
                                       ||'/base:'||(EXISTS (SELECT 1 FROM ingest.book_import_baselines bl WHERE bl.external_id_id = e.id))::text, ', ' ORDER BY e.value)
                       FROM public.book_external_ids e WHERE e.scheme IN ('import:' || v_s4, 'import:' || v_s6)), 'aucun')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  -- ── T19 ─────────────────────────────────────────────────────────────
  v_t := 'T19 (3 bis, rapprochement) exemplaire d''une ligne de la source sans bibliotheque (MLEG) publie dans B : identifiant ET base a MLEG, rien pour B';
  DECLARE v_r7 bigint; v_l7 bigint; v_row7 bigint; v_x7 bigint; v_e7 bigint; v_bm3 jsonb;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_s5, NULL, 'essai/l2-mleg-rappr.csv', 'l2-mleg-rappr.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r7;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, subjects, raw_payload, normalized_payload, match_status, editorial_decision, proposed_book_id)
    VALUES (v_r7, 1, 'M-3', 'L2 MLEG rapprochee', '[]', '[]', '{"numero": "M-3"}', '{"title": "L2 MLEG rapprochee"}', 'matched_book', 'accept_duplicate', v_km0)
    RETURNING id INTO v_row7;
    -- l'exemplaire rapproché (« Rapprocher » exige un run d'une bibliothèque : posé comme il l'aurait été)
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('L2 rapprochement MLEG', v_coordB, v_libB) RETURNING id INTO v_l7;
    INSERT INTO public.exemplar_drafts (batch_id, import_staging_row_id, target_library_id, target_bib_ref, source_item_code, created_by, updated_by)
    VALUES (v_l7, v_row7, v_libB, 'L2-KM0', 'M-3-X', v_coordB, v_coordB) RETURNING id INTO v_x7;
    PERFORM pg_temp.l2_reviser(v_l7, v_coordB, v_admin);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_e7 := public.publish_exemplar_draft(v_x7);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_bm3 := pg_temp.l2_base(v_libM, v_s5, 'M-3');
    IF pg_temp.l2_base_exacte(v_bm3, v_row7) AND (v_bm3->>'book_id')::bigint = v_km0 AND v_bm3->>'confirmed_at' IS NULL
       AND (SELECT e.library_id FROM public.exemplares e WHERE e.id = v_e7) = v_libB
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.scheme = 'import:' || v_s5 AND e.library_id <> v_libM)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : identifiants='
         ||coalesce((SELECT string_agg(CASE e.library_id WHEN v_libM THEN 'MLEG' WHEN v_libB THEN 'B' ELSE '?' END||'/'||e.value
                                       ||'/base:'||(EXISTS (SELECT 1 FROM ingest.book_import_baselines bl WHERE bl.external_id_id = e.id))::text, ', ' ORDER BY e.value)
                       FROM public.book_external_ids e WHERE e.scheme = 'import:' || v_s5), 'aucun')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'H21-LOT2-LA-BASE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'H21-LOT2-LA-BASE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
