// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/receive-fonds-bundle-banc.test.js
//
// BANC DE L'EF receive-fonds-bundle — « Retraiter » un paquet de fonds (H21
// lot 0, cinquième passe, 30/09/2026). La VRAIE fonction, démarrée par monterEF
// (helpers/monter-ef.js : esbuild + require détourné, vrai _shared/core/secret-key.ts),
// devant une petite BASE SIMULÉE qui tient le run, ses lignes et ses fichiers
// reçus, et répond comme PostgREST répond (erreur = objet { code, details, hint,
// message }, sans lever). Chaque geste — lecture, écriture, téléchargement,
// RPC — est noté dans l'ordre où la fonction l'attend.
//
// Remplacé en plus de ce que monterEF remplace toujours (il le demande en tête) :
//   * l'import `npm:jszip@3` — monterEF ne sait charger que des chemins relatifs.
//     `esbuild.transformSync` est enveloppé POUR CE FICHIER (vi.mock) : le seul
//     spécifieur `npm:jszip@3` devient `./npm:jszip@3`, servi par `remplacements`
//     avec le VRAI JSZip 3 de node_modules (celui que Deno résout pour `npm:jszip@3`).
//     Le paquet lu par la fonction est donc un vrai ZIP, construit ici par JSZip.
//
// Ce qu'il fige :
//   1. run qui a déjà des lignes, force_reparse : l'effacement passe par la RPC
//      ingest.fn_h31_effacer_lignes_pour_retraitement (H31, 05/10/2026 : verrou
//      du run, garde de fn_import_dispatch REJOUÉE, lignes et fichiers reçus
//      effacés ensemble — p_fichiers_recus vrai), jamais par un DELETE direct.
//      La RPC refuse (garde H31, HINT error.import.reparse_after_promotion, ou
//      déclencheur trg_staging_rows_retenue_par_rapproche traversant la RPC —
//      messages et HINT LUS dans les migrations H31 et H21, P0001) : aucune
//      insertion, lignes et fichiers reçus intacts (depuis H30, le paquet est
//      téléchargé une fois, avant tout effacement, et n'est pas relu) ; les
//      lignes sont gardées : aucun statut écrit, le message ET sa HINT au
//      journal, 409 { ok: false, rows_kept: true } ;
//   2. la RPC en échec (délai) : l'effacement est d'un seul tenant, rien n'est
//      parti — 409 rows_kept comme un refus (avant H31, le second DELETE en
//      échec laissait les fichiers reçus sans leurs lignes, run 'failed') ;
//      un échec APRÈS l'effacement (insertion des lignes) : 'failed', 500 ;
//   3. TÉMOIN : RPC acceptée → lecture du paquet, l'effacement (RPC, run et
//      fichiers reçus), 'processing', puis les lignes, relecture de leurs ids,
//      fichiers reçus rattachés aux NOUVELLES lignes, run 'ready_for_review' ;
//   4. H30 (04/10/2026) : paquet illisible (Storage, pas un ZIP, sans manifeste,
//      JSON invalide, autre schéma) pendant un « Retraiter » → rien n'est touché,
//      le refus va au journal du run, 409 rows_kept ; premier import → 'failed'
//      comme avant ;
//   5. H30 : journal jamais écrasé quand sa relecture échoue, chemin « failed »
//      compris ; comptage des lignes en échec → 409 rows_kept, rien n'a bougé.
//   Les journaux exacts de 1, 2 et 3 ont été adaptés le 04/10 au nouvel ordre :
//   comptage, lecture du paquet, effacements, 'processing'.
//
// Contre-épreuves (30/09/2026, miroir hors dépôt, P5/D) : l'index.ts du commit
// 817c68c8 (les deux DELETE sans lire leur erreur) fait tomber 1 et 2 — il efface
// les fichiers reçus, télécharge, réinsère et bute sur (run_id, row_no) — et laisse
// passer le témoin. Mutants ciblés : erreur des lignes ignorée → 1 seul tombe ;
// erreur des fichiers reçus ignorée → 2 seul ; fichiers reçus effacés AVANT les
// lignes → 1, 2 et le témoin.
// H31 (05/10/2026) : les tests 1 à 3 et le journal de la troisième série sont
// réécrits pour la RPC. Contre-épreuves (mutants de index.ts, remis après
// chacun) : les deux DELETE d'avant H31 → 7 tombent (les cinq de la série 1,
// deux de la troisième) ; erreur de la RPC ignorée → 4 ; p_fichiers_recus faux
// → 4 (dont le témoin) ; lignes « lâchées » (lignesGardees faux) avant la RPC
// → 4. Les séries H30 passent sous chacun.

import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import JSZip from 'jszip';
import { monterEF } from './helpers/monter-ef.js';

vi.mock('esbuild', async (importOriginal) => {
  const reel = await importOriginal();
  const transformSync = (code, options) =>
    reel.transformSync(String(code).replace(/(['"])npm:jszip@3\1/g, '$1./npm:jszip@3$1'), options);
  return { ...reel, transformSync };
});

const here = path.dirname(fileURLToPath(import.meta.url));
const MIGRATION_H21 = path.resolve(here, '..', '..', 'supabase', 'migrations',
  '20261001200931_h21_lot0_la_revision_suit_le_brouillon_importe.sql');
const MIGRATION_H31 = path.resolve(here, '..', '..', 'supabase', 'migrations',
  '20261005124652_h31_retraiter_juge_au_moment_d_effacer.sql');
const EFFACEMENT = 'fn_h31_effacer_lignes_pour_retraitement';
const SECRET = 'banc-secret';
const RUN = 42;
const RUNS = 'ingest.partner_catalog_import_runs';
const LIGNES = 'ingest.partner_catalog_staging_rows';
const RECUS = 'ingest.partner_catalog_received_assets';
const PAQUET = 'catalogos_parceiros_raw/lib-1/fonds.zip';

// L'erreur que PostgREST rend quand la garde refuse l'effacement d'une ligne :
// RAISE sans ERRCODE → P0001 (HTTP 400). Message et HINT lus dans la définition
// de la garde, pas recopiés : si elle change de mots, ce banc suit.
function refusDeLaGarde(idLigne) {
  const sql = readFileSync(MIGRATION_H21, 'utf8');
  const corps = sql.split('FUNCTION ingest.fn_h21_ligne_retenue_par_exemplaire_rapproche()')[1]?.split('$function$;')[0] ?? '';
  const m = corps.match(/RAISE EXCEPTION '([^']*)', OLD\.id\s+USING HINT = '([^']*)'/);
  if (!m) throw new Error('garde fn_h21_ligne_retenue_par_exemplaire_rapproche introuvable dans la migration H21');
  return { code: 'P0001', details: null, hint: m[2], message: m[1].replace('%', String(idLigne)) };
}
// Le refus de la garde H31 rejouée par la RPC d'effacement (RAISE sans
// ERRCODE → P0001) : message et HINT lus dans la définition de la RPC.
function refusDeLaRpc() {
  const sql = readFileSync(MIGRATION_H31, 'utf8');
  const corps = sql.split(`FUNCTION ingest.${EFFACEMENT}(`)[1]?.split('$function$;')[0] ?? '';
  const m = corps.match(/RAISE EXCEPTION '([^']*)', p_run_id\s+USING HINT = '([^']*)'/);
  if (!m) throw new Error(`refus de ${EFFACEMENT} introuvable dans la migration H31`);
  return { code: 'P0001', details: null, hint: m[2], message: m[1].replace('%', String(RUN)) };
}
const DOUBLON = {
  code: '23505', details: `Key (run_id, row_no)=(${RUN}, 1) already exists.`, hint: null,
  message: 'duplicate key value violates unique constraint "partner_catalog_staging_rows_run_id_row_no_key"',
};
const DELAI = { code: '57014', details: null, hint: null, message: 'canceling statement due to statement timeout' };

// Le paquet relu : deux notices, un fichier annoncé mais absent du ZIP (parqué
// en metadata_only — le faux Storage n'a pas d'upload, et ce n'est pas le sujet).
const MANIFESTE = {
  schema: 'anarbib-fonds-export/v1', library_id: 'lib-source',
  records: [
    { id: 1, bibRef: 'SRC-1', title: 'O Estado', authors: [{ name: 'Bakunin', role: 'aut', ord: 1 }], year: 1873,
      assets: [{ asset_id: 71, kind: 'pdf', title: 'O Estado (PDF)', mime: 'application/pdf', file: 'files/71_o-estado.pdf' }] },
    { id: 2, bibRef: 'SRC-2', title: 'A Anarquia', publisher: 'Terra Livre', year: 1891, assets: [] },
  ],
};
const zipDuPaquet = (() => {
  const z = new JSZip();
  z.file('manifest.json', JSON.stringify(MANIFESTE));
  return z.generateAsync({ type: 'uint8array' });
})();

// H30 : `paquet` remplace la réponse du Storage (async () → { data, error }) ;
// `premier` = premier import (run en file, aucune ligne, aucun fichier reçu,
// sans force_reparse).
// `refusLecture` : erreur de la relecture du journal (select('error_log')) ;
// `refusComptage` : erreur du comptage des lignes du run.
// H31 : `refusEffacement` — 'garde' (la garde rejouée par la RPC), 'declencheur'
// (trg_staging_rows_retenue_par_rapproche à travers la RPC) ou un objet erreur
// (délai…) : ce que rend la RPC d'effacement ; `refusInsertion` : l'erreur de
// l'insertion des nouvelles lignes (échec APRÈS l'effacement).
async function retraiter({ refusEffacement = null, refusInsertion = null, paquet = null, premier = false, refusLecture = null, refusComptage = null } = {}) {
  const zip = await zipDuPaquet;
  const base = premier ? {
    run: {
      id: RUN, library_id: 'lib-1', bucket_id: 'catalogos_parceiros_raw', storage_path: 'lib-1/fonds.zip',
      detected_format: 'zip', run_status: 'queued', parser_version: null, imported_rows: 0,
      started_at: null, finished_at: null, error_log: [],
    },
    lignes: [],
    recus: [],
  } : {
    run: {
      id: RUN, library_id: 'lib-1', bucket_id: 'catalogos_parceiros_raw', storage_path: 'lib-1/fonds.zip',
      detected_format: 'zip', run_status: 'ready_for_review', parser_version: 'fonds_receive_v1', imported_rows: 2,
      started_at: '2026-09-29T10:00:00.000Z', finished_at: '2026-09-29T10:00:05.000Z',
      error_log: [{ at: '2026-09-29T09:00:00.000Z', error: 'essai précédent' }],
    },
    lignes: [{ id: 901, run_id: RUN, row_no: 1, title: 'O Estado' }, { id: 902, run_id: RUN, row_no: 2, title: 'A Anarquia' }],
    recus: [{ id: 51, run_id: RUN, staging_row_id: 901, source_asset_id: 71, deposit_status: 'metadata_only' }],
  };
  const avant = structuredClone(base);
  const refus = refusEffacement === 'garde' ? refusDeLaRpc()
    : refusEffacement === 'declencheur' ? refusDeLaGarde(base.lignes[0].id)
      : refusEffacement;
  let prochainId = 1001;
  const journal = [];
  const ef = monterEF({
    entree: 'receive-fonds-bundle/index.ts',
    env: { ANARBIB_PARTNER_IMPORT_SECRET: SECRET },
    remplacements: { 'npm:jszip@3': JSZip },
    stockage: (bucket, chemin) => {
      journal.push(`download ${bucket}/${chemin}`);
      return paquet ? paquet() : { data: new Blob([zip]), error: null };
    },
    rpc: (schema, nom, args) => {
      journal.push(`rpc ${nom}`);
      if (nom === EFFACEMENT) {
        // La RPC : une transaction — refusée, rien ne part ; acceptée, les lignes
        // du run et (si demandé) ses fichiers reçus partent ensemble.
        if (schema !== 'ingest' || args?.p_run_id !== RUN) throw new Error(`RPC ${nom} inattendue : ${schema} ${JSON.stringify(args)}`);
        if (refus) return { data: null, error: refus, status: 400 };
        const n = base.lignes.length;
        base.lignes = [];
        if (args.p_fichiers_recus === true) base.recus = [];
        return { data: n, error: null };
      }
      return { data: nom === 'fn_match_partner_catalog_run' ? { matched: 0 } : null, error: null };
    },
    repondre: (schema, table, a) => {
      const cible = `${schema}.${table}`;
      const geste = ['insert', 'update', 'upsert', 'delete'].find((op) => a(op)) ?? 'select';
      journal.push(`${geste} ${cible}`);
      const [colonne, valeur] = a('eq')?.args ?? [];
      if (geste !== 'insert' && (valeur !== RUN || colonne !== (cible === RUNS ? 'id' : 'run_id'))) {
        throw new Error(`filtre inattendu sur ${cible} : ${colonne} = ${valeur}`);
      }
      if (cible === RUNS && geste === 'select' && refusLecture && a('select').args[0] === 'error_log') return { data: null, error: refusLecture, status: 500 };
      if (cible === RUNS && geste === 'select') return { data: structuredClone(base.run), error: null };
      if (cible === RUNS && geste === 'update') { Object.assign(base.run, structuredClone(a('update').args[0])); return { data: null, error: null, status: 204 }; }
      if (cible === LIGNES && geste === 'select') {
        if (refusComptage && a('select').args[1]?.head) return { data: null, count: null, error: refusComptage, status: 500 };
        return a('select').args[1]?.head
          ? { data: null, count: base.lignes.length, error: null }
          : { data: base.lignes.map(({ id, row_no }) => ({ id, row_no })), error: null };
      }
      if (cible === LIGNES && geste === 'insert') {
        if (refusInsertion) return { data: null, error: refusInsertion, status: 500 };
        const neuves = a('insert').args[0];
        if (neuves.some((n) => base.lignes.some((l) => l.row_no === n.row_no))) return { data: null, error: DOUBLON, status: 409 };
        for (const n of neuves) base.lignes.push({ id: prochainId++, ...n });
        return { data: null, error: null, status: 201 };
      }
      if (cible === RECUS && geste === 'insert') { base.recus.push(...a('insert').args[0]); return { data: null, error: null, status: 201 }; }
      throw new Error(`appel inattendu : ${geste} ${cible}`);
    },
  });
  const r = await ef.appeler(new Request('http://ef.local/', {
    method: 'POST',
    headers: { 'x-import-secret': SECRET, 'content-type': 'application/json' },
    body: JSON.stringify(premier ? { run_id: RUN } : { run_id: RUN, force_reparse: true }),
  }));
  const ecrits = (table, op) => ef.ecrits.filter((e) => `${e.schema}.${e.table}` === table && e.op === op);
  const statuts = ecrits(RUNS, 'update').map((e) => e.donnees.run_status).filter(Boolean);
  return { ...r, base, avant, refus, journal, ecrits, statuts, ef };
}

describe('receive-fonds-bundle — « Retraiter » face à une ligne retenue (H21 lot 0, cinquième passe ; H31)', () => {
  it.each([
    ['la garde H31 rejouée au moment d\'effacer', 'garde', 'error.import.reparse_after_promotion', 'ja promovido'],
    ['le déclencheur du lot 0, à travers la RPC', 'declencheur', 'error.import.rows_held_by_items', '901'],
  ])('l\'effacement (RPC) refusé par %s : aucun statut écrit, lignes et fichiers reçus intacts, la HINT au journal, 409 rows_kept', async (_cas, refusEffacement, hint, motif) => {
    const r = await retraiter({ refusEffacement });
    // L'erreur est bien celle de la migration (lue, pas recopiée).
    expect(r.refus.hint).toBe(hint);
    expect(r.refus.message).toContain(motif);

    // Le paquet est lu AVANT (H30) ; l'effacement passe par la RPC (H31) ; rien
    // après le refus, sinon la trace au journal.
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `download ${PAQUET}`,
      `rpc ${EFFACEMENT}`,
      `select ${RUNS}`,
      `update ${RUNS}`,
    ]);
    expect(r.ef.rpcs).toEqual([{ schema: 'ingest', nom: EFFACEMENT, args: { p_run_id: RUN, p_fichiers_recus: true } }]);
    expect(r.ef.ecrits.filter((e) => e.op === 'delete')).toHaveLength(0);
    expect(r.ef.ecrits.filter((e) => e.op === 'insert')).toHaveLength(0);
    expect(r.ef.telechargements).toHaveLength(1);
    // Les fichiers reçus et les lignes sont restés.
    expect(r.base.recus).toEqual(r.avant.recus);
    expect(r.base.lignes).toEqual(r.avant.lignes);

    // Lignes gardées : le run tel quel, sa HINT au journal, 409 rows_kept.
    const attendu = `${r.refus.message} [${hint}] (lignes gardées, rien n'est retraité)`;
    expect(r.statut).toBe(409);
    expect(r.corps).toEqual({ ok: false, run_id: RUN, error: attendu, rows_kept: true });
    expect(r.statuts).toEqual([]);
    expect(r.base.run).toEqual({
      ...r.avant.run,
      error_log: [...r.avant.run.error_log, { at: expect.any(String), error: attendu }],
    });
  });

  it('la RPC d\'effacement en échec (délai) : d\'un seul tenant, rien n\'est parti — 409 rows_kept, aucun statut, lignes et fichiers reçus intacts', async () => {
    const r = await retraiter({ refusEffacement: DELAI });
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `download ${PAQUET}`,
      `rpc ${EFFACEMENT}`,
      `select ${RUNS}`,
      `update ${RUNS}`,
    ]);
    expect(r.ef.ecrits.filter((e) => e.op === 'insert' || e.op === 'delete')).toHaveLength(0);
    expect(r.base.recus).toEqual(r.avant.recus);
    expect(r.base.lignes).toEqual(r.avant.lignes);
    expect(r.statut).toBe(409);
    expect(r.corps).toEqual({ ok: false, run_id: RUN, rows_kept: true, error: `${DELAI.message} (lignes gardées, rien n'est retraité)` });
    expect(r.statuts).toEqual([]);
    expect(r.ecrits(RUNS, 'update').map((e) => Object.keys(e.donnees))).toEqual([['error_log']]);
  });

  it('échec APRÈS l\'effacement (insertion des lignes) : comme avant, le run passe en échec, 500', async () => {
    const r = await retraiter({ refusInsertion: DELAI });
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `download ${PAQUET}`,
      `rpc ${EFFACEMENT}`,
      `update ${RUNS}`,
      `insert ${LIGNES}`,
      `select ${RUNS}`,
      `update ${RUNS}`,
      `update ${RUNS}`,
    ]);
    expect(r.base.lignes).toEqual([]);
    expect(r.base.recus).toEqual([]);
    expect(r.statut).toBe(500);
    expect(r.corps.rows_kept).toBeUndefined();
    expect(r.statuts).toEqual(['processing', 'failed']);
    // Le journal (journaliser) puis le statut, séparément : l'UPDATE du statut
    // ne porte jamais error_log.
    const majs = r.ecrits(RUNS, 'update').map((e) => e.donnees);
    expect(majs.slice(1).map((d) => Object.keys(d).sort())).toEqual([['error_log'], ['run_status']]);
    expect(r.base.run.error_log).toEqual([...r.avant.run.error_log, { at: expect.any(String), error: DELAI.message }]);
  });

  it('TÉMOIN — RPC acceptée : lecture du paquet (H30), l\'effacement du run par la RPC (lignes et fichiers reçus), processing, puis les nouvelles lignes, les fichiers les suivent', async () => {
    const r = await retraiter();
    expect(r.statut).toBe(200);
    expect(r.corps).toMatchObject({ ok: true, run_id: RUN, inserted_rows: 2, received_metadata_only: 1, received_failed: 0 });
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `download ${PAQUET}`,
      `rpc ${EFFACEMENT}`,
      `update ${RUNS}`,
      `insert ${LIGNES}`,
      `select ${LIGNES}`,
      `insert ${RECUS}`,
      'rpc fn_match_partner_catalog_run',
      'rpc fn_refresh_partner_catalog_run_counters',
      `update ${RUNS}`,
    ]);
    // L'effacement vise le run, et lui seul, fichiers reçus compris ; aucun DELETE direct.
    expect(r.ef.rpcs[0]).toEqual({ schema: 'ingest', nom: EFFACEMENT, args: { p_run_id: RUN, p_fichiers_recus: true } });
    expect(r.ef.ecrits.filter((e) => e.op === 'delete')).toHaveLength(0);
    expect(r.base.lignes.map(({ id, row_no, title }) => ({ id, row_no, title }))).toEqual([
      { id: 1001, row_no: 1, title: 'O Estado' },
      { id: 1002, row_no: 2, title: 'A Anarquia' },
    ]);
    expect(r.base.recus).toHaveLength(1);
    expect(r.base.recus[0]).toMatchObject({ run_id: RUN, staging_row_id: 1001, source_asset_id: 71, deposit_status: 'metadata_only' });
    expect(r.statuts).toEqual(['processing', 'ready_for_review']);
    expect(r.base.run).toMatchObject({ run_status: 'ready_for_review', imported_rows: 2, error_log: r.avant.run.error_log });
  });
});

// H30 (04/10/2026) — « Retraiter » exige un paquet lisible. Téléchargement,
// déballage, manifest.json présent, JSON valide, schéma attendu : tout est vérifié
// AVANT 'processing' et avant les deux effacements. Illisible alors que le run a
// des lignes : rien n'est touché, le refus va au journal du run, 409 rows_kept.
// Contre-épreuve (04/10/2026, miroir hors dépôt, index.ts du commit 07111e3d) :
// les six cas « Retraiter » (500 au lieu de 409), les trois cas H21 plus haut
// (ordre, statuts) et les quatre cas « journal et comptage » (HEAD passe en
// 'processing' avant d'effacer et ignore l'erreur du comptage) tombent ; les deux
// témoins du premier import passent : 13 tombent, 2 passent.
const zipDe = (fichiers) => {
  const z = new JSZip();
  for (const [nom, contenu] of Object.entries(fichiers)) z.file(nom, contenu);
  return z.generateAsync({ type: 'uint8array' });
};
const blob = async (octets) => ({ data: new Blob([await octets]), error: null });
const PAQUETS_ILLISIBLES = [
  ['le Storage rend une erreur', async () => ({ data: null, error: { message: 'Object not found' } }), /Object not found/],
  ['le Storage ne rend rien', async () => ({ data: null, error: null }), /returned no file/],
  ['ce n\'est pas un ZIP', () => blob(new TextEncoder().encode('titulo;autor\r\nO Estado;Bakunin\r\n')), /zip/i],
  ['ZIP sans manifest.json', () => blob(zipDe({ 'records.json': JSON.stringify(MANIFESTE) })), /manifest\.json absent/],
  ['manifest.json en JSON invalide', () => blob(zipDe({ 'manifest.json': '{"schema": "anarbib-fonds-export/v1", records: [' })), /manifest\.json illisible/],
  ['manifeste d\'un autre schéma', () => blob(zipDe({ 'manifest.json': JSON.stringify({ ...MANIFESTE, schema: 'anarbib-fonds-export/v0' }) })), /Schéma de manifeste inattendu : anarbib-fonds-export\/v0/],
];

describe('receive-fonds-bundle — « Retraiter » sans paquet lisible (H30)', () => {
  it.each(PAQUETS_ILLISIBLES)('run avec lignes, %s : ni processing ni DELETE (lignes, fichiers reçus), une entrée au journal, 409', async (_cas, paquet, motif) => {
    const r = await retraiter({ paquet });
    expect(r.statut).toBe(409);
    expect(r.corps).toMatchObject({ ok: false, run_id: RUN, rows_kept: true });
    expect(r.corps.error).toMatch(motif);
    expect(r.corps.error).toContain('les lignes sont gardées');
    // La lecture, puis la seule trace au journal.
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `download ${PAQUET}`,
      `select ${RUNS}`,
      `update ${RUNS}`,
    ]);
    expect(r.statuts).toEqual([]);
    expect(r.ecrits(LIGNES, 'delete')).toHaveLength(0);
    expect(r.ecrits(RECUS, 'delete')).toHaveLength(0);
    expect(r.ef.ecrits.filter((e) => e.op === 'insert')).toHaveLength(0);
    expect(r.ef.rpcs).toHaveLength(0);
    expect(r.base.lignes).toEqual(r.avant.lignes);
    expect(r.base.recus).toEqual(r.avant.recus);
    // Le run tel quel, une entrée de plus à son journal (le message de la réponse).
    expect(r.base.run).toEqual({
      ...r.avant.run,
      error_log: [...r.avant.run.error_log, { at: expect.any(String), error: r.corps.error }],
    });
  });

  it.each([PAQUETS_ILLISIBLES[0], PAQUETS_ILLISIBLES[3]])('TÉMOIN — premier import (aucune ligne), %s : comme avant, le run passe en échec, 500', async (_cas, paquet, motif) => {
    const r = await retraiter({ paquet, premier: true });
    expect(r.statut).toBe(500);
    expect(r.corps.error).toMatch(motif);
    expect(r.statuts.at(-1)).toBe('failed');
    expect(r.base.run.run_status).toBe('failed');
    expect(r.base.run.error_log).toEqual([{ at: expect.any(String), error: r.corps.error }]);
    expect(r.ecrits(LIGNES, 'delete')).toHaveLength(0);
    expect(r.ecrits(RECUS, 'delete')).toHaveLength(0);
    expect(r.ef.ecrits.filter((e) => e.op === 'insert')).toHaveLength(0);
    expect(r.base.lignes).toEqual([]);
  });
});

// H30, troisième passe (04/10/2026) : le journal du run n'est jamais écrasé
// (journaliser lit puis écrit, et lève si la lecture échoue) ; le comptage des
// lignes lit son erreur, et tant qu'elles ne sont pas comptées rien n'a bougé
// (lignes gardées) ; le catch « failed » journalise puis écrit le statut à part.
// Reste un CONSTAT : journal illisible, la réponse perd le motif du paquet.
describe('receive-fonds-bundle — journal et comptage en échec (H30)', () => {
  it('paquet illisible, run avec lignes, relecture du journal en échec : rien n\'est écrit (error_log non écrasé), 409 rows_kept', async () => {
    const r = await retraiter({ paquet: PAQUETS_ILLISIBLES[0][1], refusLecture: DELAI });
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `download ${PAQUET}`,
      `select ${RUNS}`,
      `select ${RUNS}`,
    ]);
    expect(r.ef.ecrits).toEqual([]);
    expect(r.base.run).toEqual(r.avant.run);
    expect(r.base.lignes).toEqual(r.avant.lignes);
    expect(r.base.recus).toEqual(r.avant.recus);
    expect(r.statut).toBe(409);
    expect(r.corps).toMatchObject({ ok: false, run_id: RUN, rows_kept: true });
    // CONSTAT : la réponse dit l'échec du journal, plus celui du paquet.
    expect(r.corps.error).toBe(`${DELAI.message} (lignes gardées, rien n'est retraité)`);
  });

  it('effacement (RPC) refusé par la garde, relecture du journal en échec : rien n\'est écrit, 409 rows_kept avec la HINT', async () => {
    const r = await retraiter({ refusEffacement: 'garde', refusLecture: DELAI });
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `download ${PAQUET}`,
      `rpc ${EFFACEMENT}`,
      `select ${RUNS}`,
    ]);
    expect(r.ef.ecrits).toEqual([]);
    expect(r.base.run).toEqual(r.avant.run);
    expect(r.base.lignes).toEqual(r.avant.lignes);
    expect(r.base.recus).toEqual(r.avant.recus);
    expect(r.statut).toBe(409);
    expect(r.corps).toEqual({
      ok: false, run_id: RUN, rows_kept: true,
      error: `${r.refus.message} [error.import.reparse_after_promotion] (lignes gardées, rien n'est retraité)`,
    });
  });

  it('échec après l\'effacement (insertion des lignes), relecture du journal en échec : error_log non écrasé, le run passe en failed, 500', async () => {
    const r = await retraiter({ refusInsertion: DELAI, refusLecture: DELAI });
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `download ${PAQUET}`,
      `rpc ${EFFACEMENT}`,
      `update ${RUNS}`,
      `insert ${LIGNES}`,
      `select ${RUNS}`,
      `update ${RUNS}`,
    ]);
    expect(r.statut).toBe(500);
    expect(r.statuts).toEqual(['processing', 'failed']);
    expect(r.ecrits(RUNS, 'update').map((e) => e.donnees).slice(1)).toEqual([{ run_status: 'failed' }]);
    // L'entrée d'avant (« essai précédent ») est toujours là, seule.
    expect(r.base.run.error_log).toEqual(r.avant.run.error_log);
    expect(r.base.run.run_status).toBe('failed');
  });

  it('comptage des lignes en échec : rien n\'a bougé — 409 rows_kept, l\'erreur au journal, aucun failed, ni téléchargement ni DELETE', async () => {
    const r = await retraiter({ refusComptage: DELAI });
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `select ${RUNS}`,
      `update ${RUNS}`,
    ]);
    expect(r.ef.telechargements).toHaveLength(0);
    expect(r.ecrits(LIGNES, 'delete')).toHaveLength(0);
    expect(r.ecrits(RECUS, 'delete')).toHaveLength(0);
    expect(r.ef.ecrits.filter((e) => e.op === 'insert')).toHaveLength(0);
    expect(r.ef.rpcs).toHaveLength(0);
    expect(r.base.lignes).toEqual(r.avant.lignes);
    expect(r.base.recus).toEqual(r.avant.recus);
    const attendu = `${DELAI.message} (lignes gardées, rien n'est retraité)`;
    expect(r.statut).toBe(409);
    expect(r.corps).toEqual({ ok: false, run_id: RUN, error: attendu, rows_kept: true });
    expect(r.statuts).toEqual([]);
    expect(r.base.run).toEqual({ ...r.avant.run, error_log: [...r.avant.run.error_log, { at: expect.any(String), error: attendu }] });
  });
});
