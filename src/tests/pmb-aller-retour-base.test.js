// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/pmb-aller-retour-base.test.js
//
// LA PREUVE DE L'ALLER-RETOUR PAR LA BASE (H27, 28/09/2026). Trois maillons :
//   1. la VRAIE edge function d'import (banc monterEF) lit les deux fixtures
//      exportées par PMB 8.1 et rend ses lignes de staging ;
//   2. la suite SQL tests/sql/aller_retour_pmb_tests.sql, ENGENDRÉE ici, les
//      insère au banc, les promeut, fait approuver et publier le lot, puis
//      exige que fn_export_catalog_lote rende EXACTEMENT l'attendu figé
//      (tests/pmb/aller-retour-attendu.json) ;
//   3. ici, cet attendu — donc ce que la base exporte — est écrit en UNIMARC
//      par le chemin de l'écran Importations (serializeCatalog), relu, et
//      comparé zone par zone à l'enregistrement PMB d'origine. Les PERTES
//      ACCEPTÉES sont écrites ci-dessous avec leur raison, et les pertes
//      elles-mêmes, notice par notice, sont figées dans
//      tests/pmb/aller-retour-pertes.json : toute perte nouvelle fait échouer
//      le test, même sur une clé déjà acceptée.
// H21 lot 2 (05/10/2026) : les BROUILLONS que la promotion crée de ces lignes
// sont figés eux aussi (tests/pmb/aller-retour-brouillons.json, capturés avec
// la définition d'avant le lot 2) : la correspondance fichier → colonnes,
// devenue la fonction ingest.fn_import_row_as_book, ne doit rien changer à la
// création (T5) ; la création l'appelle (T6) ; la publication pose la base de
// chaque identifiant d'origine (T7) ; l'export lit l'enregistrement d'origine
// dans cette base, au même résultat que le repli sur marc_json.ingest (T8).
// Le test exige la suite SQL à jour. Pour l'engendrer, puis refaire l'attendu
// quand l'import ou l'export change EXPRÈS (et relire le diff de l'attendu) :
//   REGENERER_H27=1 npx vitest run src/tests/pmb-aller-retour-base.test.js
//   tests/pmb/capturer-attendu-h27.sh   (banc SQL local, voir son en-tête)

import { describe, it, expect } from 'vitest';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { monterEF } from './helpers/monter-ef.js';
import { serializeCatalog } from '../../supabase/functions/export-catalog-lote/serialize.ts';
import { parseMarcFile } from '../../supabase/functions/process-partner-catalog-import/marc.ts';
import { decodeImportBytes } from '../../supabase/functions/process-partner-catalog-import/encoding.ts';
// Les pertes acceptées, zone par zone, avec leur raison : un module partagé avec
// le tableau de couverture (docs/interop/couverture-pmb.md).
import { PERTES_ACCEPTEES } from './helpers/pmb-pertes-acceptees.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const RACINE = path.resolve(here, '..', '..');
const FIX = path.join(RACINE, 'tests', 'pmb', 'fixtures');
const SUITE = path.join(RACINE, 'tests', 'sql', 'aller_retour_pmb_tests.sql');
const ATTENDU = path.join(RACINE, 'tests', 'pmb', 'aller-retour-attendu.json');
const PERTES = path.join(RACINE, 'tests', 'pmb', 'aller-retour-pertes.json');
const BROUILLONS = path.join(RACINE, 'tests', 'pmb', 'aller-retour-brouillons.json');
const FICHIERS = ['pmb-8.1.1.1_jeu-de-test.unimarc.iso', 'pmb-8.1.1.1_cas-difficiles.unimarc.iso'];
const SECRET = 'banc-secret';

// Les lignes de staging que l'EF écrit pour un fichier (même banc que
// process-partner-catalog-import-banc.test.js).
async function lignesDe(nom) {
  const fichier = new Uint8Array(readFileSync(path.join(FIX, nom)));
  const run = { id: 42, source_id: 7, library_id: 'lib-1', bucket_id: 'catalogos_parceiros_raw',
    storage_path: `lib-1/${nom}`, original_filename: nom, detected_format: 'marc_iso2709', adapter_overrides: {}, error_log: [] };
  const ef = monterEF({
    entree: 'process-partner-catalog-import/index.ts',
    env: { ANARBIB_PARTNER_IMPORT_SECRET: SECRET },
    stockage: () => ({ data: new Blob([fichier]), error: null }),
    repondre: (_schema, table, a) => {
      if (table === 'partner_catalog_import_runs' && a('select')) return { data: run, error: null };
      if (table === 'partner_catalog_import_files' && a('select')) return { data: { id: 5, file_role: 'uploaded' }, error: null };
      if (table === 'partner_catalog_staging_rows' && a('select')) return { data: null, count: 0, error: null };
      return { data: null, error: null };
    },
    rpc: (_s, n) => ({ data: n === 'fn_match_partner_catalog_run' ? { matched: 0 } : { ok: true }, error: null }),
  });
  await ef.appeler(new Request('http://ef.local/', { method: 'POST',
    headers: { 'x-import-secret': SECRET, 'content-type': 'application/json' }, body: JSON.stringify({ run_id: 42 }) }));
  return ef.ecrits.filter((e) => e.table === 'partner_catalog_staging_rows' && e.op === 'insert').flatMap((e) => e.donnees);
}

const COLONNES = ['row_no', 'external_key', 'item_type', 'title', 'subtitle', 'responsibility_statement', 'authors', 'publisher',
  'place_of_publication', 'publication_year', 'edition_statement', 'language', 'isbn', 'issn', 'subjects', 'raw_payload', 'normalized_payload'];
const TYPES_SQL = { row_no: 'integer', authors: 'jsonb', subjects: 'jsonb', raw_payload: 'jsonb', normalized_payload: 'jsonb' };
const dollar = (s) => { if (s.includes('$j$')) throw new Error('$j$ dans les données'); return `$j$${s}$j$`; };
const nExemplaires = (lignes) => lignes.reduce((n, l) => n + (l.normalized_payload?.items?.length ?? 0), 0);

function suiteSql(lignes, attendu, brouillons) {
  const donnees = JSON.stringify(lignes.map((l) => Object.fromEntries(COLONNES.map((c) => [c, l[c] ?? null]))));
  const nx = nExemplaires(lignes);
  const vides = lignes.filter((l) => !(l.normalized_payload?.items?.length)).length;
  return `-- =====================================================================
-- AnarBib — La preuve de l'aller-retour PMB, par la base (H27)
-- ENGENDRÉE par src/tests/pmb-aller-retour-base.test.js — ne pas modifier à la main :
--   REGENERER_H27=1 npx vitest run src/tests/pmb-aller-retour-base.test.js
--
-- Les ${lignes.length} lignes de staging que la VRAIE edge function d'import écrit pour
-- les deux fixtures exportées par PMB 8.1 (tests/pmb/fixtures) sont promues ;
-- le lot est approuvé, publié, puis exporté par fn_export_catalog_lote.
--
-- T1 promotion : une notice par ligne, un brouillon d'exemplaire par exemplaire (${nx}).
-- T2 publication du lot : toutes les notices, et EXACTEMENT les exemplaires du
--    fichier — les ${vides} notices qui n'en ont pas n'en reçoivent pas (IMP-25).
-- T3 l'export rend EXACTEMENT l'attendu figé (tests/pmb/aller-retour-attendu.json),
--    identifiants internes, tombos et id de la source mis à part.
-- T4 la réémission (IMP-22) : l'enregistrement d'origine revient tel quel, sans
--    ses zones d'exemplaire, pour la bibliothèque qui l'a importé.
-- T5 (H21 lot 2, juste après T1) la création est inchangée : les brouillons et
--    leurs responsabilités sont, champ par champ, ceux que la définition d'avant
--    le lot 2 créait (tests/pmb/aller-retour-brouillons.json), identifiants
--    internes et horodatages mis à part.
-- T6 (H21 lot 2) une seule règle : chaque brouillon est ce que
--    ingest.fn_import_row_as_book dit de sa ligne, et la création l'appelle.
-- T7 (H21 lot 2) la publication pose la base de chaque identifiant d'origine,
--    exacte (correspondance, enregistrement d'origine, ligne, run, confirmée).
-- T8 (H21 lot 2) l'export lu dans la base est identique à l'export par le
--    repli sur marc_json.ingest (le chemin d'avant), et lit bien la base.
--
-- Capture de l'attendu : avec anarbib.h27_capture = on, la suite émet l'export
-- projeté et les brouillons projetés en NOTICE (tests/pmb/capturer-attendu-h27.sh) ; avec
-- anarbib.h27_export = on, l'export complet et les autorités (le fichier du
-- réimport dans PMB : tests/pmb/banc/essai-reimport-pmb.sh).
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'ALLER-RETOUR-PMB OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans rôle (seed) -> admin réseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_src bigint; v_run bigint; v_lot bigint; v_res jsonb; v_exp jsonb; v_proj jsonb; v_ecarts text[];
  v_attendu jsonb := ${attendu ? `${dollar(JSON.stringify(attendu))}::jsonb` : 'NULL'};
  v_brouillons jsonb := ${brouillons ? `${dollar(JSON.stringify(brouillons))}::jsonb` : 'NULL'};
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "AR-PMB-", "year": false, "pad": 4}'::jsonb WHERE id = v_lib;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('PMB 8.1 (fixtures)', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/pmb.iso', 'pmb.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, ${COLONNES.join(', ')}, match_status, editorial_decision)
  SELECT v_run, ${COLONNES.map((c) => `r.${c}`).join(', ')}, 'new_record', 'accept_new'
    FROM jsonb_to_recordset(${dollar(donnees)}::jsonb)
      AS r(${COLONNES.map((c) => `${c} ${TYPES_SQL[c] || 'text'}`).join(', ')});

  -- ── T0 ──────────────────────────────────────────────────────────────
  -- Revue du 29/09 : le statut des lignes est posé ci-dessus à la main ; le
  -- chemin de l'écran, lui, passe par le rapprochement, qui cherche les
  -- doublons INTERNES au lot. Une revue et ses fascicules, un ensemble et ses
  -- tomes portent le même titre : aucun ne doit être pris pour le doublon de
  -- l'autre — une ligne signalée n'a plus que « Rejeter » à l'écran.
  v_t := 'T0 doublons internes au lot : aucune notice des fixtures n''est prise pour une autre';
  BEGIN
    v_res := ingest.fn_flag_intra_run_duplicates(v_run);
    IF (v_res->>'lignes_signalees')::int = 0
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run AND match_status <> 'new_record')
    THEN v_passed := v_passed+1;
    ELSE
      v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||(SELECT string_agg(coalesce(external_key, id::text), ', ' ORDER BY row_no)
                                                FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run AND match_status <> 'new_record'));
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 promotion : une notice par ligne, un brouillon d''exemplaire par exemplaire';
  BEGIN
    v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    v_lot := (v_res->>'batch_id')::bigint;
    -- Les bib_ref, comme fn_batch_assign_bib_refs les poserait.
    UPDATE public.book_drafts SET bib_ref = 'AR-PMB-REF-' || id WHERE batch_id = v_lot AND bib_ref IS NULL;
    IF (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot) = ${lignes.length}
       AND (SELECT count(*) FROM public.exemplar_drafts WHERE batch_id = v_lot) = ${nx}
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_res::text, 'NULL'), 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 (H21 lot 2) ──────────────────────────────────────────────────
  -- La correspondance fichier → colonnes est devenue une fonction
  -- (ingest.fn_import_row_as_book), que la création appelle : les brouillons
  -- doivent rester ceux que la définition d'avant créait. Projection : toute la
  -- ligne du brouillon, sans ce qui dépend du banc (identifiants internes,
  -- horodatages, référence posée en T1, numéro du run dans la note de
  -- provenance et dans la trace marc_json.ingest) ; ses responsabilités. Les
  -- deux copies volumineuses de marc_json (la ligne normalisée, l'enregistrement
  -- d'origine) sont comparées par leur empreinte.
  v_t := 'T5 la création est inchangée : brouillons et responsabilités identiques aux brouillons figés';
  BEGIN
    SELECT jsonb_agg(jsonb_build_object(
             'row_no', s.row_no,
             -- digital_resources_removed (D9, 06/10) : la trace des ressources
             -- supprimées d'un brouillon, née après la capture ; l'import n'y écrit pas
             'brouillon', (to_jsonb(d) - 'id' - 'batch_id' - 'bib_ref' - 'created_at' - 'updated_at' - 'last_opened_at'
                                       - 'publisher_id' - 'marc_json' - 'provenance_note' - 'digital_resources_removed')
                          || jsonb_build_object(
                               'provenance_note', regexp_replace(d.provenance_note, 'run [0-9]+', 'run #'),
                               'marc_json', jsonb_build_object(
                                 'normalise_md5', md5((d.marc_json - 'ingest' - 'anarbib_provenance')::text),
                                 'anarbib_provenance', (d.marc_json->'anarbib_provenance') - 'provenance_note',
                                 'ingest', (d.marc_json->'ingest') - 'run_id' - 'source_id' - 'staging_row_id' - 'source_file_id' - 'raw_payload',
                                 'raw_payload_md5', md5((d.marc_json->'ingest'->'raw_payload')::text))),
             'responsabilites', (SELECT jsonb_agg(to_jsonb(c) - 'id' - 'draft_id' - 'created_at' - 'updated_at' ORDER BY c.position)
                                   FROM public.book_draft_contributors c WHERE c.draft_id = d.id))
             ORDER BY s.row_no)
      INTO v_proj
      FROM public.book_drafts d
      JOIN ingest.partner_catalog_row_to_draft m ON m.draft_id = d.id
      JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id
     WHERE d.batch_id = v_lot;
    IF current_setting('anarbib.h27_capture', true) = 'on' THEN
      RAISE NOTICE 'H27-BROUILLONS %', v_proj::text;
    END IF;
    IF v_brouillons IS NULL THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : pas de brouillons figés (tests/pmb/capturer-attendu-h27.sh)');
    ELSIF v_proj = v_brouillons THEN
      v_passed := v_passed+1;
    ELSE
      SELECT array_agg(format('ligne %s %s : %s <> figé %s', coalesce(p->>'row_no', a->>'row_no'), k,
                              left(coalesce((p->'brouillon'->k)::text, (p->k)::text, '∅'), 120),
                              left(coalesce((a->'brouillon'->k)::text, (a->k)::text, '∅'), 120)) ORDER BY n, k)
        INTO v_ecarts
        FROM jsonb_array_elements(v_proj) WITH ORDINALITY x(p, n)
        FULL JOIN jsonb_array_elements(v_brouillons) WITH ORDINALITY y(a, m) ON m = n
        CROSS JOIN LATERAL jsonb_object_keys(coalesce(p->'brouillon', '{}'::jsonb) || coalesce(a->'brouillon', '{}'::jsonb)
                                             || jsonb_build_object('responsabilites', 1, 'row_no', 1)) k
       WHERE CASE WHEN k IN ('responsabilites', 'row_no') THEN p->k IS DISTINCT FROM a->k
                  ELSE p->'brouillon'->k IS DISTINCT FROM a->'brouillon'->k END;
      v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||coalesce(cardinality(v_ecarts), 0)||' écart(s) — '||array_to_string(v_ecarts[1:15], ' | '));
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 (H21 lot 2) ──────────────────────────────────────────────────
  -- Une seule règle : chaque brouillon est, colonne par colonne, ce que
  -- ingest.fn_import_row_as_book dit de sa ligne (colonnes, provenance, trace
  -- marc_json — sans les miroirs anarbib_* que pose un déclencheur —,
  -- responsabilités).
  v_t := 'T6 une seule règle : chaque brouillon est ce que fn_import_row_as_book dit de sa ligne';
  BEGIN
    SELECT array_agg(format('ligne %s : %s', x.row_no, x.k) ORDER BY x.row_no, x.k) INTO v_ecarts
      FROM (
        SELECT s.row_no, k.k
          FROM public.book_drafts d
          JOIN ingest.partner_catalog_row_to_draft m ON m.draft_id = d.id
          JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id
          CROSS JOIN LATERAL (SELECT ingest.fn_import_row_as_book(s, ingest.fn_h21_contexte_du_run(s.run_id)) AS v) f
          CROSS JOIN LATERAL (
            SELECT c.k FROM jsonb_each(f.v->'mapped' || f.v->'provenance') c(k, val)
             WHERE to_jsonb(d)->c.k IS DISTINCT FROM c.val
            UNION ALL
            SELECT 'marc_json' WHERE (d.marc_json - 'anarbib_provenance' - 'anarbib_acquisition' - 'anarbib_network') IS DISTINCT FROM f.v->'marc_json'
            UNION ALL
            SELECT 'responsabilites'
             WHERE coalesce((SELECT jsonb_agg(jsonb_build_object('position', c.position, 'name', c.name, 'role', c.role,
                                                                'is_primary', c.is_primary, 'nature', c.nature, 'role_code', c.role_code)
                                             ORDER BY c.position)
                               FROM public.book_draft_contributors c WHERE c.draft_id = d.id), '[]'::jsonb)
                   IS DISTINCT FROM f.v->'contributors') k
         WHERE d.batch_id = v_lot) x;
    IF v_ecarts IS NULL AND (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot) = ${lignes.length}
       AND position('ingest.fn_import_row_as_book(' IN pg_get_functiondef(
             'ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure)) > 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(array_to_string(v_ecarts[1:15], ', '), 'la création n''appelle pas la fonction')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 publication du lot : toutes les notices, tous les exemplaires';
  BEGIN
    v_res := public.fn_batch_review_request(v_lot);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.publish_catalog_batch(v_lot);
    IF (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot AND status = 'published') = ${lignes.length}
       AND (SELECT count(*) FROM public.exemplar_drafts WHERE batch_id = v_lot AND status = 'published') = ${nx}
       AND (SELECT count(*) FROM public.exemplares e
              JOIN public.book_holdings h ON h.id = e.holding_id
              JOIN public.book_drafts d ON d.published_book_id = h.book_id AND d.batch_id = v_lot
             WHERE e.library_id = v_lib) = ${nx}
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_res::text, 'NULL'), 400)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 l''export rend exactement l''attendu figé';
  BEGIN
    v_exp := public.fn_export_catalog_lote(v_lib);
    -- Les notices du lot, dans l'ordre du fichier ; sans ce qui dépend du banc
    -- (identifiants internes, référence, tombos) ni l'enregistrement réémis (T4).
    SELECT jsonb_build_object('library', v_exp->'library', 'records', jsonb_agg(jsonb_strip_nulls(
             (r - 'id' - 'bibRef' - 'authors' - 'source' - 'contributors' - 'items' - 'subjects' - 'work' - 'serial' - 'externalIds')
             || jsonb_build_object(
                  -- le schéma nomme la source par son id (« import:<id> ») : il dépend du banc
                  'externalIds', (SELECT jsonb_agg(e - 'scheme' ORDER BY n) FROM jsonb_array_elements(r->'externalIds') WITH ORDINALITY z(e, n)),
                  'contributors', (SELECT jsonb_agg(c - 'authorId' ORDER BY n) FROM jsonb_array_elements(r->'contributors') WITH ORDINALITY z(c, n)),
                  'items', (SELECT jsonb_agg(i - 'id' - 'tombo' ORDER BY n) FROM jsonb_array_elements(r->'items') WITH ORDINALITY z(i, n)),
                  'subjects', (SELECT jsonb_agg(x - 'id' ORDER BY n) FROM jsonb_array_elements(r->'subjects') WITH ORDINALITY z(x, n)),
                  'work', (r->'work') - 'id',
                  'serial', (r->'serial') - 'id',
                  'source', CASE WHEN r ? 'source' THEN ((r->'source') - 'fields')
                                   || jsonb_build_object('fieldsCount', jsonb_array_length(r->'source'->'fields')) END))
             ORDER BY s.row_no))
      INTO v_proj
      FROM jsonb_array_elements(v_exp->'records') r
      JOIN public.book_drafts d ON d.published_book_id = (r->>'id')::bigint AND d.batch_id = v_lot
      JOIN ingest.partner_catalog_row_to_draft m ON m.draft_id = d.id
      JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id;
    IF current_setting('anarbib.h27_capture', true) = 'on' THEN
      RAISE NOTICE 'H27-CAPTURE %', v_proj::text;
    END IF;
    -- L'export COMPLET des notices du lot, dans l'ordre où l'écran le reçoit
    -- (fn_export_catalog_lote pagine par id ; le sérialiseur range ensuite les
    -- périodiques avant les articles — revue du 28/09), et celui des
    -- autorités : le fichier du réimport dans PMB (tests/pmb/banc/essai-reimport-pmb.sh).
    IF current_setting('anarbib.h27_export', true) = 'on' THEN
      RAISE NOTICE 'H27-EXPORT %', jsonb_build_object(
        'library', v_exp->'library',
        'records', (SELECT jsonb_agg(r ORDER BY (r->>'id')::bigint)
                      FROM jsonb_array_elements(v_exp->'records') r
                      JOIN public.book_drafts d ON d.published_book_id = (r->>'id')::bigint AND d.batch_id = v_lot
                      JOIN ingest.partner_catalog_row_to_draft m ON m.draft_id = d.id
                      JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id),
        'authorities', public.fn_export_authorities_lote(v_lib))::text;
    END IF;
    IF v_attendu IS NULL THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : pas d''attendu figé (tests/pmb/capturer-attendu-h27.sh)');
    ELSIF v_proj = v_attendu THEN
      v_passed := v_passed+1;
    ELSE
      SELECT array_agg(format('%s %s : %s <> attendu %s', coalesce(p->>'originId', '#' || n), k,
                              left(coalesce((p->k)::text, '∅'), 120), left(coalesce((a->k)::text, '∅'), 120)) ORDER BY n, k)
        INTO v_ecarts
        FROM jsonb_array_elements(v_proj->'records') WITH ORDINALITY x(p, n)
        FULL JOIN jsonb_array_elements(v_attendu->'records') WITH ORDINALITY y(a, m) ON m = n
        CROSS JOIN LATERAL jsonb_object_keys(coalesce(p, '{}'::jsonb) || coalesce(a, '{}'::jsonb)) k
       WHERE p->k IS DISTINCT FROM a->k;
      IF v_proj->'library' IS DISTINCT FROM v_attendu->'library' THEN
        v_ecarts := ('library : ' || (v_proj->'library')::text) || coalesce(v_ecarts, ARRAY[]::text[]);
      END IF;
      v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||coalesce(cardinality(v_ecarts), 0)||' écart(s) — '||array_to_string(v_ecarts[1:15], ' | '));
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 réémission : l''enregistrement d''origine revient tel quel, sans ses zones d''exemplaire';
  BEGIN
    SELECT array_agg(s.external_key ORDER BY s.row_no) INTO v_ecarts
      FROM jsonb_array_elements(v_exp->'records') r
      JOIN public.book_drafts d ON d.published_book_id = (r->>'id')::bigint AND d.batch_id = v_lot
      JOIN ingest.partner_catalog_row_to_draft m ON m.draft_id = d.id
      JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id
     WHERE r->'source'->>'dialect' IS DISTINCT FROM s.raw_payload->>'marc_dialect'
        OR r->'source'->>'leader' IS DISTINCT FROM s.raw_payload->>'leader'
        OR r->'source'->>'itemTag' IS DISTINCT FROM s.raw_payload->>'item_tag'
        OR r->'source'->'fields' IS DISTINCT FROM (
             SELECT coalesce(jsonb_agg(f ORDER BY n), '[]'::jsonb)
               FROM jsonb_array_elements(s.raw_payload->'fields') WITH ORDINALITY z(f, n)
              WHERE f->>'tag' NOT IN ('995', '996', '852') AND f->>'tag' IS DISTINCT FROM s.raw_payload->>'item_tag');
    IF v_ecarts IS NULL AND (SELECT count(*) FROM jsonb_array_elements(v_exp->'records') r
                              JOIN public.book_drafts d ON d.published_book_id = (r->>'id')::bigint AND d.batch_id = v_lot
                             WHERE r ? 'source') = ${lignes.length}
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(array_to_string(v_ecarts[1:15], ', '), 'notices sans source')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 (H21 lot 2) ──────────────────────────────────────────────────
  -- La publication pose, pour chaque notice, la base de son identifiant
  -- d'origine (BLMF, import:<source>, 001) : ce que fn_import_row_as_book dit
  -- de la ligne, l'enregistrement d'origine, la ligne et le run, confirmée.
  v_t := 'T7 la publication pose la base de chaque identifiant d''origine, exacte';
  BEGIN
    SELECT array_agg(s.external_key ORDER BY s.row_no) INTO v_ecarts
      FROM public.book_drafts d
      JOIN ingest.partner_catalog_row_to_draft m ON m.draft_id = d.id
      JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id
      CROSS JOIN LATERAL (SELECT ingest.fn_import_row_as_book(s, ingest.fn_h21_contexte_du_run(s.run_id)) AS v) f
      LEFT JOIN public.book_external_ids e
             ON e.book_id = d.published_book_id AND e.library_id = v_lib AND e.scheme = 'import:' || v_src
            AND e.value = btrim(s.external_key)
      LEFT JOIN ingest.book_import_baselines bl ON bl.external_id_id = e.id
     WHERE d.batch_id = v_lot
       AND NOT (bl.id IS NOT NULL
                AND bl.mapped = f.v->'mapped' AND bl.contributors = f.v->'contributors'
                AND bl.subjects = f.v->'subjects' AND bl.raw_payload = s.raw_payload
                AND bl.payload_hash = f.v->>'payload_hash' AND bl.mapping_version = f.v->>'mapping_version'
                AND bl.staging_row_id = s.id AND bl.run_id = v_run
                AND bl.origine = 'import' AND bl.confirmed_at IS NOT NULL AND bl.reprise_champs_douteux = '{}'::text[]);
    IF v_ecarts IS NULL
       AND (SELECT count(*) FROM ingest.book_import_baselines bl
              JOIN public.book_external_ids e ON e.id = bl.external_id_id
              JOIN public.book_drafts d ON d.published_book_id = e.book_id AND d.batch_id = v_lot) = ${lignes.length}
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(array_to_string(v_ecarts[1:15], ', '), 'nombre de bases')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 (H21 lot 2) ──────────────────────────────────────────────────
  -- L'export lit l'enregistrement d'origine d'abord dans la base : sans les
  -- bases (repli sur marc_json.ingest, le chemin d'avant), il est IDENTIQUE,
  -- au caractère près ; une base altérée se voit dans l'export (preuve qu'il
  -- la lit). Les deux essais sont annulés.
  v_t := 'T8 l''export lu dans la base est identique à l''export par le repli, et lit bien la base';
  DECLARE v_sans jsonb; v_altere jsonb; v_cle text;
  BEGIN
    BEGIN
      DELETE FROM ingest.book_import_baselines bl
       USING public.book_external_ids e, public.book_drafts d
       WHERE e.id = bl.external_id_id AND d.published_book_id = e.book_id AND d.batch_id = v_lot;
      v_sans := public.fn_export_catalog_lote(v_lib);
      RAISE EXCEPTION 'annuler' USING ERRCODE = 'P0099';
    EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;
    BEGIN
      SELECT e.value INTO v_cle FROM ingest.book_import_baselines bl
        JOIN public.book_external_ids e ON e.id = bl.external_id_id
        JOIN public.book_drafts d ON d.published_book_id = e.book_id AND d.batch_id = v_lot
       ORDER BY e.id LIMIT 1;
      UPDATE ingest.book_import_baselines bl SET raw_payload = jsonb_set(bl.raw_payload, '{leader}', '"H21L2-BASE"')
        FROM public.book_external_ids e WHERE e.id = bl.external_id_id AND e.library_id = v_lib AND e.value = v_cle;
      v_altere := public.fn_export_catalog_lote(v_lib);
      RAISE EXCEPTION 'annuler' USING ERRCODE = 'P0099';
    EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;
    IF v_sans = v_exp
       AND (SELECT count(*) FROM ingest.book_import_baselines bl
              JOIN public.book_external_ids e ON e.id = bl.external_id_id
              JOIN public.book_drafts d ON d.published_book_id = e.book_id AND d.batch_id = v_lot) = ${lignes.length}
       AND (SELECT r->'source'->>'leader' FROM jsonb_array_elements(v_altere->'records') r WHERE r->>'originId' = v_cle) = 'H21L2-BASE'
       AND (SELECT count(*) FROM jsonb_array_elements(v_altere->'records') r WHERE r->'source'->>'leader' = 'H21L2-BASE') = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : sans base '||(v_sans = v_exp)::text||', base lue '
                    ||coalesce((SELECT r->'source'->>'leader' FROM jsonb_array_elements(v_altere->'records') r WHERE r->>'originId' = v_cle), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ALLER-RETOUR-PMB OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'ALLER-RETOUR-PMB ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
`;
}


// La réémission, telle que la base la fait (T4 de la suite l'exige identique).
const reemis = (l) => ({
  dialect: l.raw_payload.marc_dialect, leader: l.raw_payload.leader, itemTag: l.raw_payload.item_tag,
  fields: l.raw_payload.fields.filter((f) => !['995', '996', '852'].includes(f.tag) && f.tag !== l.raw_payload.item_tag),
});

// Les valeurs d'une zone, « zone$sous-zone » → valeur (une valeur vide ne dit
// rien). PMB joint ses mots-clés par « ; » dans une seule 610 $a ; l'export en
// écrit une par mot (UNIMARC) : on compare mot à mot.
function valeursDe(f) {
  if (!f.subfields) return [{ cle: f.tag, v: String(f.value ?? '').trim() }].filter((x) => x.v);
  return f.subfields.flatMap((s) => (f.tag === '610' && s.code === 'a' ? String(s.value).split(/\s*;\s*/) : [String(s.value)])
    .map((v) => ({ cle: `${f.tag}$${s.code}`, v: v.trim() })).filter((x) => x.v));
}
// Ce que l'origine porte et que la notice relue n'a plus.
function pertesDe(origine, relue) {
  const apres = new Set(relue.flatMap(valeursDe).map((x) => `${x.cle}=${x.v}`));
  return origine.flatMap((f) => valeursDe(f).filter((x) => !apres.has(`${x.cle}=${x.v}`)).map((x) => ({ ...x, zone: f })));
}

describe('H27 — la preuve de l\'aller-retour PMB, par la base', async () => {
  const lignes = [];
  for (const f of FICHIERS) lignes.push(...await lignesDe(f));
  lignes.forEach((l, i) => { l.row_no = i + 1; });
  const attendu = existsSync(ATTENDU) ? JSON.parse(readFileSync(ATTENDU, 'utf8')) : null;
  const brouillons = existsSync(BROUILLONS) ? JSON.parse(readFileSync(BROUILLONS, 'utf8')) : null;

  it('la suite SQL engendrée est à jour', () => {
    const sql = suiteSql(lignes, attendu, brouillons);
    if (process.env.REGENERER_H27 === '1') writeFileSync(SUITE, sql);
    expect(existsSync(SUITE)).toBe(true);
    expect(readFileSync(SUITE, 'utf8') === sql, 'suite SQL périmée : REGENERER_H27=1').toBe(true);
  });

  // H21 lot 2 : un brouillon figé par ligne des fixtures, dans l'ordre du fichier.
  it('les brouillons figés couvrent chaque ligne des fixtures, dans l\'ordre', () => {
    expect(brouillons, 'brouillons figés absents : tests/pmb/capturer-attendu-h27.sh').not.toBeNull();
    expect(brouillons.map((b) => b.row_no)).toEqual(lignes.map((l) => l.row_no));
    expect(brouillons.map((b) => b.brouillon.titulo)).toEqual(lignes.map((l) => (l.title ?? '').replace(/^ +| +$/g, '') || null));
  });

  it('l\'attendu figé couvre chaque notice des fixtures, dans l\'ordre', () => {
    expect(attendu, 'attendu absent : tests/pmb/capturer-attendu-h27.sh').not.toBeNull();
    expect(attendu.records.map((r) => r.originId ?? null)).toEqual(lignes.map((l) => l.external_key ?? null));
  });

  it('ce que la base exporte, écrit en UNIMARC, ne perd que les pertes acceptées', () => {
    const lib = attendu.library;
    const records = attendu.records.map((r, i) => ({ ...r, source: reemis(lignes[i]) }));
    const sortie = serializeCatalog(records, 'unimarc_iso2709', {
      date: '20260928', bibliotheque: { nom: lib.short_name || lib.name || null, pays: lib.country ?? null, langue: lib.default_locale ?? null },
    });
    expect(sortie.avertissements).toEqual([]);
    const dec = decodeImportBytes(sortie.content, null);
    const relues = parseMarcFile({ text: dec.text, bytes: sortie.content, filename: 'export.mrc', encoding: dec.encoding }).entries;
    expect(relues).toHaveLength(lignes.length);
    // L'export range les périodiques avant les articles (revue du 28/09) : une
    // notice relue se retrouve par son identifiant d'origine, pas par son rang.
    const parCle = new Map(relues.map((r) => [r.mapped.externalKey, r]));
    expect(parCle.size, 'identifiant d\'origine répété ou absent dans l\'export').toBe(lignes.length);
    const relue = (i) => parCle.get(lignes[i].external_key);
    expect(lignes.filter((l, i) => !relue(i)).map((l) => l.external_key)).toEqual([]);
    // … et l'ordre lui-même : aucun article avant un périodique.
    const types = relues.map((r) => r.mapped.materialType);
    expect(types.lastIndexOf('periodico')).toBeLessThan(types.indexOf('artigo'));
    const pertes = new Map();
    const diag = {};
    lignes.forEach((l, i) => {
      for (const p of pertesDe(l.raw_payload.fields, relue(i).rawPayload.fields)) {
        if (!pertes.has(p.cle)) pertes.set(p.cle, []);
        pertes.get(p.cle).push(`${l.external_key} « ${p.v.slice(0, 50)} »`);
        // H27_DIAG=fichier : chaque perte avec sa zone d'origine et les zones de
        // même étiquette réécrites — de quoi juger une clé avant de l'accepter.
        (diag[p.cle] ??= []).push({ notice: l.external_key, valeur: p.v, origine: p.zone,
          reecrites: relue(i).rawPayload.fields.filter((g) => g.tag === p.zone.tag) });
      }
    });
    if (process.env.H27_DIAG) writeFileSync(process.env.H27_DIAG, JSON.stringify(diag, null, 1));
    const nouvelles = [...pertes.keys()].filter((k) => !(k in PERTES_ACCEPTEES)).sort();
    expect(nouvelles.map((k) => `${k} ×${pertes.get(k).length} : ${pertes.get(k).slice(0, 2).join(' ; ')}`)).toEqual([]);
    // Une perte acceptée qui ne se produit plus est retirée de la liste.
    expect(Object.keys(PERTES_ACCEPTEES).filter((k) => !pertes.has(k)).sort()).toEqual([]);
    // Les pertes ELLES-MÊMES, notice par notice, sont figées (revue du 28/09) :
    // accepter une clé ne doit pas laisser passer une perte de plus sur une
    // autre notice (tous les titres, toutes les langues…). Refaites avec la
    // suite (REGENERER_H27=1) ; relire leur diff avant de committer.
    const figees = Object.fromEntries([...pertes].sort(([a], [b]) => a.localeCompare(b)).map(([k, v]) => [k, [...v].sort()]));
    if (process.env.REGENERER_H27 === '1') writeFileSync(PERTES, JSON.stringify(figees, null, 1) + '\n');
    expect(figees, 'pertes changées : REGENERER_H27=1, puis relire le diff de tests/pmb/aller-retour-pertes.json')
      .toEqual(JSON.parse(readFileSync(PERTES, 'utf8')));
    // « La collection revient en 225 », « le tome en 200 $h » : vérifié, pas
    // seulement dit (hors fascicules et articles, dont la 461 est la revue).
    // Le titre de série PMB (461 $t) revient en collection, ou — quand la
    // notice a déjà une collection — en note « Série: » (revue du 29/09).
    const REVIENT = {
      '410$t': [['225$a', (v) => v]], '410$v': [['225$v', (v) => v]], '461$v': [['200$h', (v) => v]],
      '461$t': [['225$a', (v) => v], ['300$a', (v) => `Série: ${v}`]],
    };
    const nonRevenues = [];
    lignes.forEach((l, i) => {
      if (['periodico', 'artigo'].includes(attendu.records[i].materialType)) return;
      const ailleurs = relue(i).rawPayload.fields.filter((f) => ['225', '200', '300'].includes(f.tag)).flatMap(valeursDe);
      for (const p of pertesDe(l.raw_payload.fields, relue(i).rawPayload.fields)) {
        const cibles = REVIENT[p.cle];
        if (cibles && !cibles.some(([cle, f]) => ailleurs.some((x) => x.cle === cle && x.v === f(p.v)))) nonRevenues.push(`${l.external_key} ${p.cle} « ${p.v} »`);
      }
    });
    // « Le titre du périodique revient en 200 et 530 » (463 $t d'une notice de
    // bulletin PMB), son numéro en 200 $h, et l'ISSN qu'un PMB écrit en 010 $a
    // en 011 $a (revue du 28/09) : vérifié aussi.
    const REVIENT_BULLETIN = { '463$t': ['200$a', '530$a'], '200$i': ['200$h'], '010$a': ['011$a'] };
    lignes.forEach((l, i) => {
      if (attendu.records[i].materialType !== 'periodico') return;
      const relus = relue(i).rawPayload.fields.flatMap(valeursDe);
      // d'une 463 à deux $t, le premier est le titre du BULLETIN : il ne revient pas (sans champ)
      const titres463 = l.raw_payload.fields.filter((f) => f.tag === '463').flatMap(valeursDe).filter((x) => x.cle === '463$t').map((x) => x.v);
      for (const p of pertesDe(l.raw_payload.fields, relue(i).rawPayload.fields)) {
        if (p.cle === '463$t' && titres463.length > 1 && p.v === titres463[0]) continue;
        for (const cible of REVIENT_BULLETIN[p.cle] ?? []) {
          if (!relus.some((x) => x.cle === cible && x.v === p.v)) nonRevenues.push(`${l.external_key} ${p.cle} « ${p.v} » → ${cible}`);
        }
      }
    });
    expect(nonRevenues).toEqual([]);
  });
});
