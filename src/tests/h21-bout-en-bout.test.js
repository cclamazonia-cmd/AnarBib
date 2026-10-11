// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/h21-bout-en-bout.test.js
//
// H21 LOT 8 — LE RÉIMPORT DE BOUT EN BOUT, SUR DES FICHIERS EXPORTÉS PAR PMB
// (11/10/2026). Trois maillons, sur le modèle de pmb-aller-retour-base.test.js :
//   1. la VRAIE edge function d'import (banc monterEF) lit les exports du jeu
//      de test que PMB 8.1 a produits lui-même (tests/pmb/fixtures :
//      jeu-de-test = premier export ; -v2, -v2-seuil, -v3 = les suivants,
//      tests/pmb/banc/deuxieme-export-h21.sh) et rend ses écritures : lignes
//      de staging et bilan du run ;
//   2. la suite SQL tests/sql/h21_bout_en_bout_tests.sql est ENGENDRÉE ici :
//      le gabarit tests/pmb/h21-bout-en-bout.gabarit.sql (écrit à la main) où
//      chaque marque /*@@…@@*/ reçoit ces écritures ; la suite rejoue, au banc,
//      ce que l'EF écrit, puis chaque geste de l'écran sous les rôles réels ;
//   3. ici, l'export UNIMARC qu'AnarBib tire de la base après le deuxième
//      import (figé par la suite : tests/pmb/h21-bout-en-bout-export.json)
//      est écrit par le chemin de l'écran (serializeCatalog), relu par
//      l'analyse, et rend les mêmes notices et exemplaires que le deuxième
//      fichier (hors retirés, hors exclus).
// Et le fichier compagnon tests/pmb/h21-bout-en-bout-cas.json dit chaque cas
// des fichiers : ce test vérifie qu'il est bien dans les fixtures, et que la
// liste est fermée dans les deux sens.
//
// Le test exige la suite SQL à jour. Pour l'engendrer :
//   REGENERER_H21L8=1 npx vitest run src/tests/h21-bout-en-bout.test.js
// Pour refaire l'export et les réponses de l'écran figés (banc SQL local) :
//   tests/pmb/capturer-h21-bout-en-bout.sh
// puis réengendrer la suite (même commande) : elle embarque l'export figé.

import { describe, it, expect } from 'vitest';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { monterEF } from './helpers/monter-ef.js';
import { serializeCatalog } from '../../supabase/functions/export-catalog-lote/serialize.ts';
import { parseMarcFile } from '../../supabase/functions/process-partner-catalog-import/marc.ts';
import { decodeImportBytes } from '../../supabase/functions/process-partner-catalog-import/encoding.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const RACINE = path.resolve(here, '..', '..');
const FIX = path.join(RACINE, 'tests', 'pmb', 'fixtures');
const GABARIT = path.join(RACINE, 'tests', 'pmb', 'h21-bout-en-bout.gabarit.sql');
const SUITE = path.join(RACINE, 'tests', 'sql', 'h21_bout_en_bout_tests.sql');
const CAS = path.join(RACINE, 'tests', 'pmb', 'h21-bout-en-bout-cas.json');
const EXPORT = path.join(RACINE, 'tests', 'pmb', 'h21-bout-en-bout-export.json');
const SECRET = 'banc-secret';
const FICHIERS = {
  v1: 'pmb-8.1.1.1_jeu-de-test.unimarc.iso',
  v2: 'pmb-8.1.1.1_jeu-de-test-v2.unimarc.iso',
  v2s: 'pmb-8.1.1.1_jeu-de-test-v2-seuil.unimarc.iso',
  v3: 'pmb-8.1.1.1_jeu-de-test-v3.unimarc.iso',
};

// Ce que l'EF écrit pour un fichier : ses lignes de staging (toutes leurs
// colonnes) et la dernière mise à jour du run (statut, nombre, bilan).
async function analyser(nom) {
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
  const rep = await ef.appeler(new Request('http://ef.local/', { method: 'POST',
    headers: { 'x-import-secret': SECRET, 'content-type': 'application/json' }, body: JSON.stringify({ run_id: 42 }) }));
  expect(rep.statut, `EF sur ${nom} : ${JSON.stringify(rep.corps ?? rep.texte)}`).toBe(200);
  const lignes = ef.ecrits.filter((e) => e.table === 'partner_catalog_staging_rows' && e.op === 'insert').flatMap((e) => e.donnees);
  const fin = ef.ecrits.filter((e) => e.table === 'partner_catalog_import_runs' && e.op === 'update'
    && e.donnees?.run_status === 'ready_for_review').at(-1)?.donnees;
  expect(fin, `bilan du run pour ${nom}`).toBeTruthy();
  // Ce que le banc remplace : le run et le fichier (ceux de la suite), les
  // horodatages et le résultat du rapprochement (la suite les pose elle-même).
  const lignesSql = lignes.map(({ run_id: _r, source_file_id: _f, ...l }) => l);
  const { parsed_at: _p, matched_at: _m, matching_result: _mr, counter_refresh_result: _c, ...resume } = fin.summary;
  return { lignes: lignesSql, brutes: lignes,
    fin: { detected_format: fin.detected_format, imported_rows: fin.imported_rows, parser_version: fin.parser_version, summary: resume } };
}

const dollar = (s) => { if (s.includes('$j$')) throw new Error('$j$ dans les données'); return `$j$${s}$j$`; };

function suiteSql(gabarit, donnees, exportFige) {
  let sql = gabarit;
  const marques = new Set();
  for (const [cle, d] of Object.entries(donnees)) {
    const rempl = {
      [`/*@@LIGNES:${cle}@@*/`]: `${dollar(JSON.stringify(d.lignes))}::jsonb`,
      [`/*@@FIN:${cle}@@*/`]: `${dollar(JSON.stringify(d.fin))}::jsonb`,
      [`/*@@N:${cle}@@*/`]: String(d.lignes.length),
      [`/*@@NX:${cle}@@*/`]: String(d.lignes.reduce((n, l) => n + (l.normalized_payload?.items?.length ?? 0), 0)),
    };
    for (const [m, v] of Object.entries(rempl)) { marques.add(m); sql = sql.split(m).join(v); }
  }
  const mExport = '/*@@EXPORT@@*/';
  sql = sql.split(mExport).join(exportFige ? `${dollar(JSON.stringify(exportFige))}::jsonb` : 'NULL::jsonb');
  const reste = sql.match(/\/\*@@[^@]*@@\*\//g);
  if (reste) throw new Error(`marque sans donnée dans le gabarit : ${[...new Set(reste)].join(', ')}`);
  return `-- ENGENDRÉE par src/tests/h21-bout-en-bout.test.js depuis tests/pmb/h21-bout-en-bout.gabarit.sql\n`
    + `-- — ne pas modifier à la main : REGENERER_H21L8=1 npx vitest run src/tests/h21-bout-en-bout.test.js\n`
    + sql;
}

// Une notice relue, par son identifiant d'origine (001).
const parCle = (lignes) => new Map(lignes.map((l) => [l.external_key, l]));
const items = (l) => l?.normalized_payload?.items ?? [];

describe('H21 lot 8 — le réimport de bout en bout sur les fixtures PMB', async () => {
  const donnees = {};
  for (const [cle, nom] of Object.entries(FICHIERS)) donnees[cle] = await analyser(nom);
  // H21L8_DIAG=fichier : les écritures de l'EF, fichier par fichier.
  if (process.env.H21L8_DIAG) writeFileSync(process.env.H21L8_DIAG, JSON.stringify(donnees, null, 1));
  const cas = JSON.parse(readFileSync(CAS, 'utf8'));
  const exportFige = existsSync(EXPORT) ? JSON.parse(readFileSync(EXPORT, 'utf8')) : null;

  it('la suite SQL engendrée est à jour', () => {
    const sql = suiteSql(readFileSync(GABARIT, 'utf8'), donnees, exportFige);
    if (process.env.REGENERER_H21L8 === '1') writeFileSync(SUITE, sql);
    expect(existsSync(SUITE)).toBe(true);
    expect(readFileSync(SUITE, 'utf8') === sql, 'suite SQL périmée : REGENERER_H21L8=1').toBe(true);
  });

  it('PMB réexporte sa base de départ à l\'identique, hormis la date de l\'export', () => {
    const lire = (n) => readFileSync(path.join(FIX, n), 'utf8').split('\n');
    const a = lire('pmb-8.1.1.1_jeu-de-test.unimarc.txt');
    const b = lire('pmb-8.1.1.1_jeu-de-test-v1-reexport.unimarc.txt');
    expect(b).toHaveLength(a.length);
    const ecarts = a.map((x, i) => [x, b[i]]).filter(([x, y]) => x !== y);
    // la date de l'export : 801 $c de chaque notice, 100 $a des notices de bulletin
    expect(ecarts.every(([x, y]) => (/^801 /.test(x) && /^801 /.test(y)) || (/^100 /.test(x) && /^100 /.test(y)))).toBe(true);
    expect(ecarts.map(([x, y]) => [x.replace(/2026092\d/, 'D'), y.replace(/20261\d{3}/, 'D')]).every(([x, y]) => x === y)).toBe(true);
  });

  // Chaque cas du fichier compagnon, vérifié dans les fichiers tels que l'EF
  // les lit ; un cas sans vérification, ou une vérification sans cas, échoue.
  it('chaque cas du fichier compagnon est dans les fixtures (liste fermée)', () => {
    const v1 = parCle(donnees.v1.lignes); const v2 = parCle(donnees.v2.lignes);
    const v2s = parCle(donnees.v2s.lignes); const v3 = parCle(donnees.v3.lignes);
    const code = (l, c) => items(l).find((i) => i.source_item_code === c);
    const xid = (l, x) => items(l).find((i) => i.source_item_id === String(x));
    const tous = (m) => [...m.values()].flatMap(items);
    const memesChamps = (a, b, ...cles) => cles.every((k) => JSON.stringify(a[k]) === JSON.stringify(b[k]));
    const preuves = {
      'notice-inchangee': () => memesChamps(v1.get('1'), v2.get('1'), 'title', 'publisher', 'publication_year', 'isbn', 'authors')
        && JSON.stringify(items(v1.get('1'))) === JSON.stringify(items(v2.get('1'))),
      'exemplaire-inchange': () => JSON.stringify(xid(v1.get('1'), 1)) === JSON.stringify(xid(v2.get('1'), 1)),
      'exemplaire-ajoute': () => items(v2.get('2')).length === items(v1.get('2')).length + 1 && !!code(v2.get('2'), 'H21L8-AJOUT-2'),
      'cote-fichier-seul': () => code(v1.get('3'), '33700003413727').call_number === 'ER OPP' && code(v2.get('3'), '33700003413727').call_number === 'ER OPP 2',
      'champ-pmb-seul': () => v1.get('4').publication_year === '1998' && v2.get('4').publication_year === '1999',
      'note-fichier-seul': () => !code(v1.get('4'), '33700003470461').note && code(v2.get('4'), '33700003470461').note === 'Envoyé en reliure en 2026',
      'champ-anarbib-seul': () => memesChamps(v1.get('5'), v2.get('5'), 'publisher', 'publication_year', 'title'),
      'cote-anarbib-seul': () => JSON.stringify(xid(v1.get('5'), 5)) === JSON.stringify(xid(v2.get('5'), 5)),
      'note-deux-cotes': () => xid(v2.get('6'), 6).note === 'Reliure refaite en 2026, peut sortir.' && xid(v1.get('6'), 6).note !== xid(v2.get('6'), 6).note,
      'responsabilites-changees': () => v1.get('7').authors.length === 2 && v2.get('7').authors.length === 1,
      'conflit': () => v1.get('8').publication_year === '1993' && v2.get('8').publication_year === '1994',
      'champ-vide-par-pmb': () => !!v1.get('9').normalized_payload.pages && !v2.get('9').normalized_payload.pages,
      'partagee-appliquee': () => v2.get('10').publication_year === '1996',
      'partagee-ecartee': () => v2.get('11').publication_year === '1997',
      'reattribuee': () => v2.get('13').publication_year === '2000',
      'reetiquete': () => code(v2.get('14'), 'H21L8-REETIQ-15') && xid(v2.get('14'), 15).source_item_code === 'H21L8-REETIQ-15',
      'sans-code': () => xid(v2.get('15'), 16) && !xid(v2.get('15'), 16).source_item_code,
      'notice-absente': () => v1.has('16') && !v2.has('16') && !tous(v2).some((i) => i.source_item_id === '17'),
      'disparu-engage': () => !tous(v2).some((i) => i.source_item_id === '19' || i.source_item_code === '3370000451291'),
      'disparu-proposable': () => !tous(v2).some((i) => i.source_item_id === '18' || i.source_item_code === '3370000451290'),
      'code-repris': () => code(v2.get('19'), '3370000451292')?.source_item_id !== '20' && !!code(v2.get('19'), '3370000451292'),
      'deplace': () => !!xid(v1.get('42'), 23) && !items(v2.get('42')).length && !!xid(v2.get('44'), 23),
      'notice-nouvelle': () => !v1.has('61') && v2.has('61') && !!code(v2.get('61'), 'H21L8-NOUV-1'),
      'deplace-vers-nouvelle': () => !!xid(v1.get('50'), 28) && !!xid(v2.get('61'), 28) && !items(v2.get('50')).length,
      'export-complet': () => true,   // posé au dépôt par la suite (fn_import_set_export_complet), pas dans le fichier
      'seuil-sous': () => tous(v1).length === 33 && tous(v2).length === 32,
      'seuil-au-dessus': () => tous(v2s).length === 11 && !v2s.has('1-bull') && !v2s.has('2-bull'),
      'disparu-plus-recent-que-le-run': () => !tous(v2).some((i) => i.source_item_code === 'H21L8-V3-53') && !!code(v3.get('53'), 'H21L8-V3-53'),
      'retire-reapparait': () => !!xid(v3.get('18'), 18) && xid(v3.get('18'), 18).source_item_code === '3370000451290',
    };
    const ids = cas.cas.map((c) => c.id);
    expect(new Set(ids).size, 'identifiant de cas répété').toBe(ids.length);
    expect(ids.filter((i) => !(i in preuves)), 'cas sans vérification').toEqual([]);
    expect(Object.keys(preuves).filter((i) => !ids.includes(i)), 'vérification sans cas').toEqual([]);
    expect(cas.cas.filter((c) => !c.commentaire || !c.etape), 'cas sans commentaire ou sans étape de la suite').toEqual([]);
    expect(ids.filter((i) => !preuves[i]()), 'cas absent des fixtures').toEqual([]);
  });

  // L'aller-retour après le deuxième import (H24) : ce que la base exporte,
  // écrit en UNIMARC par le chemin de l'écran et relu par l'analyse, rend les
  // notices et les exemplaires du deuxième fichier — aux écarts près que le
  // fichier compagnon nomme un par un, avec leur raison (aller_retour) : la
  // notice réattribuée (pas détenue), la notice absente du fichier (gardée),
  // les exemplaires qu'un signal n'a pas écrits (AnarBib garde les siens),
  // le retiré (un retiré ne s'exporte pas), les valeurs AnarBib qu'un réimport
  // ne remplace pas (local seul, conflit, divergence écartée).
  it('l\'export d\'AnarBib après le deuxième import se relit : mêmes notices, mêmes exemplaires', () => {
    expect(exportFige, 'export figé absent : tests/pmb/capturer-h21-bout-en-bout.sh').not.toBeNull();
    const sortie = serializeCatalog(exportFige.records, 'unimarc_iso2709', {
      date: '20261011', bibliotheque: { nom: exportFige.library.short_name || exportFige.library.name || null,
        pays: exportFige.library.country ?? null, langue: exportFige.library.default_locale ?? null },
    });
    expect(sortie.avertissements).toEqual([]);
    const dec = decodeImportBytes(sortie.content, null);
    const relues = parseMarcFile({ text: dec.text, bytes: sortie.content, filename: 'export.mrc', encoding: dec.encoding }).entries;
    const relu = new Map(relues.map((r) => [r.mapped.externalKey, r]));
    expect(relu.size, 'identifiant d\'origine répété ou absent dans l\'export').toBe(relues.length);
    const ar = cas.aller_retour;
    const v1 = parCle(donnees.v1.lignes); const v2 = parCle(donnees.v2.lignes);
    const attendues = [...[...v2.keys()].filter((k) => !(k in ar.notices_exclues)), ...Object.keys(ar.notices_en_plus)].sort();
    expect([...relu.keys()].sort()).toEqual(attendues);
    const ecarts = [];
    for (const k of attendues) {
      const ligne = v2.get(k) ?? v1.get(k);
      const a = (ar.exemplaires[k]?.anarbib ?? items(ligne).map((i) => i.source_item_code).filter(Boolean)).slice().sort();
      const r = relu.get(k).mapped.items.map((i) => i.source_item_code).sort();
      if (JSON.stringify(a) !== JSON.stringify(r)) ecarts.push(`${k} : attendu ${a.join(',')} / relu ${r.join(',')}`);
      const fichier = { title: ligne.title, publisher: ligne.publisher, publicationYear: ligne.publication_year, isbn: ligne.isbn };
      for (const champ of Object.keys(fichier)) {
        const attendu = ar.valeurs_anarbib[k]?.[champ] ?? fichier[champ];
        if ((relu.get(k).mapped[champ] ?? null) !== (attendu ?? null)) ecarts.push(`${k} ${champ} : ${relu.get(k).mapped[champ]} ≠ ${attendu}`);
      }
    }
    expect(ecarts).toEqual([]);
    // chaque écart nommé dans le compagnon sert (pas d'exception morte)
    expect(Object.keys(ar.exemplaires).filter((k) => {
      return JSON.stringify(ar.exemplaires[k].anarbib.slice().sort()) === JSON.stringify(items(v2.get(k)).map((i) => i.source_item_code).filter(Boolean).sort());
    })).toEqual([]);
  });
});
