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

function suiteSql(lignes, attendu) {
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
--
-- Capture de l'attendu : avec anarbib.h27_capture = on, la suite émet l'export
-- projeté en NOTICE (tests/pmb/capturer-attendu-h27.sh) ; avec
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

  it('la suite SQL engendrée est à jour', () => {
    const sql = suiteSql(lignes, attendu);
    if (process.env.REGENERER_H27 === '1') writeFileSync(SUITE, sql);
    expect(existsSync(SUITE)).toBe(true);
    expect(readFileSync(SUITE, 'utf8') === sql, 'suite SQL périmée : REGENERER_H27=1').toBe(true);
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
    const REVIENT = { '410$t': '225$a', '461$t': '225$a', '410$v': '225$v', '461$v': '200$h' };
    const nonRevenues = [];
    lignes.forEach((l, i) => {
      if (['periodico', 'artigo'].includes(attendu.records[i].materialType)) return;
      const ailleurs = relue(i).rawPayload.fields.filter((f) => f.tag === '225' || f.tag === '200').flatMap(valeursDe);
      for (const p of pertesDe(l.raw_payload.fields, relue(i).rawPayload.fields)) {
        const cible = REVIENT[p.cle];
        if (cible && !ailleurs.some((x) => x.cle === cible && x.v === p.v)) nonRevenues.push(`${l.external_key} ${p.cle} « ${p.v} »`);
      }
    });
    // « Le titre du périodique revient en 200 et 530 » (463 $t d'une notice de
    // bulletin PMB), son numéro en 200 $h, et l'ISSN qu'un PMB écrit en 010 $a
    // en 011 $a (revue du 28/09) : vérifié aussi.
    const REVIENT_BULLETIN = { '463$t': ['200$a', '530$a'], '200$i': ['200$h'], '010$a': ['011$a'] };
    lignes.forEach((l, i) => {
      if (attendu.records[i].materialType !== 'periodico') return;
      const relus = relue(i).rawPayload.fields.flatMap(valeursDe);
      for (const p of pertesDe(l.raw_payload.fields, relue(i).rawPayload.fields)) {
        for (const cible of REVIENT_BULLETIN[p.cle] ?? []) {
          if (!relus.some((x) => x.cle === cible && x.v === p.v)) nonRevenues.push(`${l.external_key} ${p.cle} « ${p.v} » → ${cible}`);
        }
      }
    });
    expect(nonRevenues).toEqual([]);
  });
});
