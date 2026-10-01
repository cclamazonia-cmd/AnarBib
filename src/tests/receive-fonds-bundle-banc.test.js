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
//   1. run qui a déjà des lignes, force_reparse, le DELETE des lignes rend l'erreur
//      de trg_staging_rows_retenue_par_rapproche (message et HINT LUS dans la
//      migration H21, P0001) : aucun DELETE de partner_catalog_received_assets,
//      aucun téléchargement, aucune insertion ; les fichiers reçus restent. Le run
//      finit comme le catch le décide — CONSTAT, pas souhait : 'processing' puis
//      'failed', finished_at laissé à NULL, le message seul ajouté au journal
//      (le HINT n'y va pas), réponse 500 { error: message } ;
//   2. rien ne part non plus quand c'est le DELETE des fichiers reçus qui échoue
//      (les lignes, elles, sont déjà effacées : constat) ;
//   3. TÉMOIN : DELETE accepté → les deux effacements (filtrés sur le run), puis la
//      relecture du paquet (téléchargement, lignes, relecture de leurs ids,
//      fichiers reçus rattachés aux NOUVELLES lignes), run 'ready_for_review'.
//
// Contre-épreuves (30/09/2026, miroir hors dépôt, P5/D) : l'index.ts du commit
// 817c68c8 (les deux DELETE sans lire leur erreur) fait tomber 1 et 2 — il efface
// les fichiers reçus, télécharge, réinsère et bute sur (run_id, row_no) — et laisse
// passer le témoin. Mutants ciblés : erreur des lignes ignorée → 1 seul tombe ;
// erreur des fichiers reçus ignorée → 2 seul ; fichiers reçus effacés AVANT les
// lignes → 1, 2 et le témoin.

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

async function retraiter({ refusLignes = false, refusRecus = null } = {}) {
  const zip = await zipDuPaquet;
  const base = {
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
  const refus = refusLignes ? refusDeLaGarde(base.lignes[0].id) : null;
  let prochainId = 1001;
  const journal = [];
  const ef = monterEF({
    entree: 'receive-fonds-bundle/index.ts',
    env: { ANARBIB_PARTNER_IMPORT_SECRET: SECRET },
    remplacements: { 'npm:jszip@3': JSZip },
    stockage: (bucket, chemin) => {
      journal.push(`download ${bucket}/${chemin}`);
      return { data: new Blob([zip]), error: null };
    },
    rpc: (_schema, nom) => {
      journal.push(`rpc ${nom}`);
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
      if (cible === RUNS && geste === 'select') return { data: structuredClone(base.run), error: null };
      if (cible === RUNS && geste === 'update') { Object.assign(base.run, structuredClone(a('update').args[0])); return { data: null, error: null, status: 204 }; }
      if (cible === LIGNES && geste === 'select') {
        return a('select').args[1]?.head
          ? { data: null, count: base.lignes.length, error: null }
          : { data: base.lignes.map(({ id, row_no }) => ({ id, row_no })), error: null };
      }
      if (cible === LIGNES && geste === 'delete') {
        if (refus) return { data: null, error: refus, status: 400 };
        base.lignes = [];
        return { data: null, error: null, status: 204 };
      }
      if (cible === LIGNES && geste === 'insert') {
        const neuves = a('insert').args[0];
        if (neuves.some((n) => base.lignes.some((l) => l.row_no === n.row_no))) return { data: null, error: DOUBLON, status: 409 };
        for (const n of neuves) base.lignes.push({ id: prochainId++, ...n });
        return { data: null, error: null, status: 201 };
      }
      if (cible === RECUS && geste === 'delete') {
        if (refusRecus) return { data: null, error: refusRecus, status: 500 };
        base.recus = [];
        return { data: null, error: null, status: 204 };
      }
      if (cible === RECUS && geste === 'insert') { base.recus.push(...a('insert').args[0]); return { data: null, error: null, status: 201 }; }
      throw new Error(`appel inattendu : ${geste} ${cible}`);
    },
  });
  const r = await ef.appeler(new Request('http://ef.local/', {
    method: 'POST',
    headers: { 'x-import-secret': SECRET, 'content-type': 'application/json' },
    body: JSON.stringify({ run_id: RUN, force_reparse: true }),
  }));
  const ecrits = (table, op) => ef.ecrits.filter((e) => `${e.schema}.${e.table}` === table && e.op === op);
  const statuts = ecrits(RUNS, 'update').map((e) => e.donnees.run_status).filter(Boolean);
  return { ...r, base, avant, refus, journal, ecrits, statuts, ef };
}

describe('receive-fonds-bundle — « Retraiter » face à une ligne retenue (H21 lot 0, cinquième passe)', () => {
  it('le DELETE des lignes refusé par la garde : aucun effacement des fichiers reçus, aucune relecture, le run finit comme le catch le décide', async () => {
    const r = await retraiter({ refusLignes: true });
    // L'erreur est bien celle de la garde (lue dans la migration).
    expect(r.refus.hint).toBe('error.import.rows_held_by_items');
    expect(r.refus.message).toContain('901');

    // Rien après le refus, sinon la trace de l'échec.
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `update ${RUNS}`,
      `delete ${LIGNES}`,
      `select ${RUNS}`,
      `update ${RUNS}`,
    ]);
    expect(r.ecrits(RECUS, 'delete')).toHaveLength(0);
    expect(r.ef.ecrits.filter((e) => e.op === 'insert')).toHaveLength(0);
    expect(r.ef.telechargements).toHaveLength(0);
    expect(r.ef.rpcs).toHaveLength(0);
    // Les fichiers reçus (et les lignes, refusées) sont restés.
    expect(r.base.recus).toEqual(r.avant.recus);
    expect(r.base.lignes).toEqual(r.avant.lignes);

    // Constat du catch — ni plus ni moins.
    expect(r.statut).toBe(500);
    expect(r.corps).toEqual({ error: r.refus.message });
    expect(r.statuts).toEqual(['processing', 'failed']);
    expect(r.base.run).toEqual({
      ...r.avant.run,
      run_status: 'failed',
      started_at: expect.any(String),
      finished_at: null,
      parser_version: 'fonds_receive_v1',
      error_log: [...r.avant.run.error_log, { at: expect.any(String), error: r.refus.message }],
    });
  });

  it('le DELETE des fichiers reçus en échec : levé aussi, rien n\'est relu ni inséré (les lignes, elles, sont parties)', async () => {
    const r = await retraiter({ refusRecus: DELAI });
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `update ${RUNS}`,
      `delete ${LIGNES}`,
      `delete ${RECUS}`,
      `select ${RUNS}`,
      `update ${RUNS}`,
    ]);
    expect(r.ef.ecrits.filter((e) => e.op === 'insert')).toHaveLength(0);
    expect(r.ef.telechargements).toHaveLength(0);
    expect(r.base.recus).toEqual(r.avant.recus);
    expect(r.base.lignes).toEqual([]);
    expect(r.statut).toBe(500);
    expect(r.statuts).toEqual(['processing', 'failed']);
    expect(r.base.run.error_log.at(-1)).toEqual({ at: expect.any(String), error: DELAI.message });
  });

  it('TÉMOIN — DELETE accepté : les deux effacements du run, puis la relecture du paquet, les fichiers suivent les nouvelles lignes', async () => {
    const r = await retraiter();
    expect(r.statut).toBe(200);
    expect(r.corps).toMatchObject({ ok: true, run_id: RUN, inserted_rows: 2, received_metadata_only: 1, received_failed: 0 });
    expect(r.journal).toEqual([
      `select ${RUNS}`,
      `select ${LIGNES}`,
      `update ${RUNS}`,
      `delete ${LIGNES}`,
      `delete ${RECUS}`,
      `download ${PAQUET}`,
      `insert ${LIGNES}`,
      `select ${LIGNES}`,
      `insert ${RECUS}`,
      'rpc fn_match_partner_catalog_run',
      'rpc fn_refresh_partner_catalog_run_counters',
      `update ${RUNS}`,
    ]);
    // Les deux effacements visent le run, et lui seul.
    for (const t of [LIGNES, RECUS]) {
      const [d] = r.ecrits(t, 'delete');
      expect(d.chaine.filter((c) => c.op === 'eq').map((c) => c.args)).toEqual([['run_id', RUN]]);
    }
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
