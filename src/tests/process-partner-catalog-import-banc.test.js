// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/process-partner-catalog-import-banc.test.js
//
// BANC DE L'EF process-partner-catalog-import (H15, 26/09/2026). La VRAIE
// fonction, démarrée par monterEF (esbuild + require détourné, vrais modules
// relatifs marc.ts et encoding.ts), nourrie des fichiers EXPORTÉS PAR PMB 8.1
// (tests/pmb/fixtures). Faux client supabase : chaque écriture est notée ; le
// Storage rend la fixture. Rien d'autre n'est remplacé.
//
// Ce qu'il fige, de bout en bout (du téléchargement à l'UPDATE final du run) :
//   * un export UNIMARC en UTF-8 → 50 lignes, format 'marc_iso2709' (H28),
//     résumé d'encodage { used: utf-8, fallback: false, declared_unimarc: [50] },
//     aucun avertissement ;
//   * le même export en latin-1 → repli windows-1252 SUPPOSÉ, dit dans
//     summary.warnings ET sur la première ligne, mêmes titres qu'en UTF-8 ;
//   * forced_encoding imposé → honoré, sans repli ni contradiction ;
//   * forced_encoding inconnu → ignoré, dit ;
//   * un CSV enregistré en Windows-1252 → accents exacts, avertissement ;
//   * H19 : les exemplaires 995 jusqu'aux lignes importées ; le profil de la
//     bibliothèque décide des sous-zones ; un profil illisible arrête l'import ;
//   * H30 : le fichier est lu avant 'processing', l'effacement vient après
//     l'analyse ; illisible ou sans contenu pendant un « Retraiter », les lignes
//     restent et le refus va au journal ;
//   * H31 : l'effacement passe par la RPC ingest.fn_h31_effacer_lignes_pour_retraitement
//     (verrou du run, garde rejouée au moment d'effacer), jamais par un DELETE
//     direct ; refusée, les lignes restent, 409 rows_kept, la HINT au journal.
//     Contre-épreuves (05/10/2026, mutants de index.ts remis après chacun) :
//     DELETE direct d'avant H31 → les deux refus et le témoin tombent ; erreur
//     de la RPC ignorée → les deux refus ; 'processing' avant la RPC → les deux
//     refus et le témoin.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { monterEF } from './helpers/monter-ef.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const FIX = path.resolve(here, '..', '..', 'tests', 'pmb', 'fixtures');
const octets = (nom) => new Uint8Array(readFileSync(path.join(FIX, nom)));
const SECRET = 'banc-secret';
const EFFACEMENT = 'fn_h31_effacer_lignes_pour_retraitement';

// `telechargement` (H30) : remplace la réponse du Storage (défaut : la fixture).
// `gestes` : lectures, écritures et téléchargements dans l'ordre où la fonction
// les fait ; un UPDATE du run porte son run_status (« update runs:processing »).
// `refusEffacement` (H31) : l'erreur PostgREST que rend la RPC d'effacement des
// lignes du run (ingest.fn_h31_effacer_lignes_pour_retraitement) ;
// `refusComptage` : celle du comptage des lignes.
// Les RPC entrent aussi dans `gestes` (« rpc <nom> »).
function banc({ fichier, nom = 'export.marc', adapter_overrides = {}, profil = null, existantes = 0, retraiter = false, telechargement = null, refusEffacement = null, refusComptage = null }) {
  const run = {
    id: 42, source_id: 7, library_id: 'lib-1', bucket_id: 'catalogos_parceiros_raw',
    storage_path: `lib-1/${nom}`, original_filename: nom, detected_format: 'marc_iso2709',
    adapter_overrides, error_log: [],
  };
  const gestes = [];
  const court = { partner_catalog_import_runs: 'runs', partner_catalog_staging_rows: 'lignes', partner_catalog_import_files: 'fichiers' };
  const ef = monterEF({
    entree: 'process-partner-catalog-import/index.ts',
    env: { ANARBIB_PARTNER_IMPORT_SECRET: SECRET },
    stockage: () => {
      gestes.push('download');
      return telechargement ? telechargement() : { data: new Blob([fichier]), error: null };
    },
    repondre: (schema, table, a) => {
      const geste = ['insert', 'update', 'upsert', 'delete'].find((op) => a(op)) ?? 'select';
      const statut = geste === 'update' && a('update').args[0]?.run_status;
      gestes.push(`${geste} ${court[table] ?? table}${statut ? `:${statut}` : ''}`);
      if (table === 'partner_catalog_import_runs' && a('select')) return { data: run, error: null };
      if (table === 'partner_catalog_import_files' && a('select')) return { data: { id: 5, file_role: 'uploaded' }, error: null };
      if (table === 'partner_catalog_staging_rows' && a('select') && refusComptage) return { data: null, count: null, error: refusComptage, status: 500 };
      if (table === 'partner_catalog_staging_rows' && a('select')) return { data: null, count: existantes, error: null };
      if (table === 'import_profiles' && profil) return profil(a);
      return { data: null, error: null };
    },
    rpc: (_s, nom) => {
      gestes.push(`rpc ${nom}`);
      if (nom === EFFACEMENT && refusEffacement) return { data: null, error: refusEffacement, status: 400 };
      if (nom === EFFACEMENT) return { data: existantes, error: null };
      return { data: nom === 'fn_match_partner_catalog_run' ? { matched: 0 } : { ok: true }, error: null };
    },
  });
  return async () => {
    const r = await ef.appeler(new Request('http://ef.local/', {
      method: 'POST',
      headers: { 'x-import-secret': SECRET, 'content-type': 'application/json' },
      body: JSON.stringify(retraiter ? { run_id: 42, force_reparse: true } : { run_id: 42 }),
    }));
    const lignes = ef.ecrits.filter((e) => e.table === 'partner_catalog_staging_rows' && e.op === 'insert').flatMap((e) => e.donnees);
    const finale = ef.ecrits.filter((e) => e.table === 'partner_catalog_import_runs' && e.op === 'update').map((e) => e.donnees)
      .find((d) => d.run_status === 'ready_for_review');
    const fichierMaj = ef.ecrits.find((e) => e.table === 'partner_catalog_import_files' && e.op === 'update')?.donnees;
    const echec = ef.ecrits.some((e) => e.table === 'partner_catalog_import_runs' && e.op === 'update' && e.donnees.run_status === 'failed');
    // H31 : effacer = appeler la RPC ; un DELETE direct des lignes ne doit plus exister.
    const efface = ef.rpcs.some((x) => x.nom === EFFACEMENT);
    const deleteDirect = ef.ecrits.some((e) => e.op === 'delete');
    const touche = ef.ecrits.some((e) => e.table === 'partner_catalog_import_runs' && e.op === 'update' && 'run_status' in e.donnees);
    const journal = ef.ecrits.filter((e) => e.table === 'partner_catalog_import_runs' && e.op === 'update' && e.donnees.error_log)
      .flatMap((e) => e.donnees.error_log);
    const statuts = ef.ecrits.filter((e) => e.table === 'partner_catalog_import_runs' && e.op === 'update' && e.donnees.run_status)
      .map((e) => e.donnees.run_status);
    return { ...r, lignes, finale, fichierMaj, echec, efface, deleteDirect, touche, journal, statuts, gestes, ef };
  };
}

const V = 'pmb-8.1.1.1_jeu-de-test';

describe('process-partner-catalog-import sur un export PMB réel (H15, H28)', () => {
  let titresUtf8 = null;

  it('UNIMARC en UTF-8 : 50 lignes marc_iso2709, encodage utf-8 déclaré 50, aucun avertissement', async () => {
    const r = await banc({ fichier: octets(`${V}.unimarc.iso`) })();
    expect(r.statut).toBe(200);
    // Premier import : rien à effacer (ni RPC d'effacement, ni DELETE).
    expect(r.efface).toBe(false);
    expect(r.deleteDirect).toBe(false);
    expect(r.corps.ok).toBe(true);
    expect(r.corps.detected_format).toBe('marc_iso2709');
    expect(r.lignes).toHaveLength(50);
    expect(r.finale.detected_format).toBe('marc_iso2709');
    expect(r.finale.summary.encoding).toEqual({ used: 'utf-8', forced: null, fallback: false, declared_unimarc: ['50'] });
    expect(r.finale.summary.warnings).toEqual([]);
    expect(r.lignes.flatMap((l) => l.warnings)).toEqual([]);
    expect(r.fichierMaj.meta.encoding.used).toBe('utf-8');
    // H16 : la couverture est au run (et ses comptes au fichier).
    expect(r.finale.summary.coverage).toMatchObject({ kind: 'marc', records: 50 });
    expect(r.finale.summary.coverage.zones.find((z) => z.tag === '995' && z.code === 'f')).toMatchObject({ status: 'repris', occurrences: 33 });
    // H19 : les exemplaires voyagent jusqu'aux lignes importées, et se comptent.
    // H21 lot 6a : with_item_id — l'identifiant interne de PMB (996 $9 expl_id)
    expect(r.finale.summary.items).toEqual({ rows_with_items: 31, items: 33, with_code: 33, with_item_id: 33 });
    expect(r.lignes.flatMap((l) => l.normalized_payload.items)).toHaveLength(33);
    expect(r.lignes[0].normalized_payload.items[0]).toMatchObject({ source_item_code: '33700004388761', call_number: 'JR SOU' });
    expect(r.finale.summary.coverage_counts.total).toBe(r.finale.summary.coverage.zones.length);
    expect(r.finale.summary.skipped_rows).toBe(0);
    expect(r.fichierMaj.meta.coverage_counts).toEqual(r.finale.summary.coverage_counts);
    expect(JSON.stringify(r.lignes.map((l) => [l.title, l.authors, l.publisher]))).not.toContain('�');
    titresUtf8 = r.lignes.map((l) => l.title);
  });

  it('H19 — le profil de la bibliothèque décide des sous-zones d\'exemplaire (IMP-21 c)', async () => {
    // Profil qui intervertit code et cote : la ligne importée doit le suivre,
    // et la couverture aussi. La lecture est `select('*')` : elle tient même
    // quand l'EF est déployée avant la migration qui ajoute items_mapping.
    let colonnes = null;
    const r = await banc({
      fichier: octets(`${V}.unimarc.iso`), adapter_overrides: { profile_id: 9 },
      profil: (a) => { colonnes = a('select').args[0]; return { data: { column_mappings: null, default_values: null, items_mapping: { code: 'k', call_number: 'f' } }, error: null }; },
    })();
    expect(colonnes).toBe('*');
    expect(r.corps.ok).toBe(true);
    expect(r.lignes[0].normalized_payload.items[0]).toMatchObject({ source_item_code: 'JR SOU', call_number: '33700004388761' });
    expect(r.finale.summary.coverage.zones.find((z) => z.tag === '995' && z.code === 'k')).toMatchObject({ status: 'repris' });
  });

  it('H19 — « Retraiter » avec un profil supprimé depuis l\'import : rien n\'est effacé, le run reste tel quel, l\'erreur va à son journal', async () => {
    const r = await banc({
      fichier: octets(`${V}.unimarc.iso`), adapter_overrides: { profile_id: 9 }, existantes: 50, retraiter: true,
      profil: () => ({ data: null, error: null }),
    })();
    expect(r.statut).toBe(409);
    expect(r.efface).toBe(false);
    expect(r.touche).toBe(false);
    expect(r.lignes).toHaveLength(0);
    expect(r.journal.map((e) => e.message).join()).toContain('not found');
  });

  it('H19 — premier import, profil illisible : rien n\'est lu, le run passe en échec (visible), l\'erreur va à son journal', async () => {
    const r = await banc({
      fichier: octets(`${V}.unimarc.iso`), adapter_overrides: { profile_id: 9 },
      profil: () => ({ data: null, error: { message: 'column import_profiles.items_mapping does not exist' } }),
    })();
    expect(r.statut).toBe(409);
    expect(r.echec).toBe(true);
    expect(r.efface).toBe(false);
    expect(r.lignes).toHaveLength(0);
    expect(r.journal.map((e) => e.message).join()).toContain('unreadable');
  });

  it('le même export en latin-1 : repli windows-1252 supposé, dit au run et sur la 1re ligne, mêmes titres', async () => {
    const r = await banc({ fichier: octets(`${V}.unimarc-latin1.iso`) })();
    expect(r.statut).toBe(200);
    expect(r.finale.summary.encoding).toMatchObject({ used: 'windows-1252', forced: null, fallback: true, declared_unimarc: ['50'] });
    const w = r.finale.summary.warnings;
    expect(w).toHaveLength(2);
    expect(w[0]).toContain('suppose windows-1252');
    expect(w[1]).toContain('declare de l\'Unicode');
    expect(r.lignes[0].warnings.slice(0, 2)).toEqual(w);
    expect(r.lignes.slice(1).flatMap((l) => l.warnings)).toEqual([]);
    expect(r.lignes.map((l) => l.title)).toEqual(titresUtf8);
  });

  it('forced_encoding windows-1252 : honoré, sans repli ni contradiction', async () => {
    const r = await banc({ fichier: octets(`${V}.unimarc-latin1.iso`), adapter_overrides: { forced_encoding: 'windows-1252' } })();
    expect(r.finale.summary.encoding).toMatchObject({ used: 'windows-1252', forced: 'windows-1252', fallback: false });
    expect(r.finale.summary.warnings).toEqual([]);
    // Les axes employés sont consignés : l'écran les relit pour « Retraiter ».
    expect(r.finale.summary.adapter).toEqual({ forced_format: null, forced_vocabulary: null, forced_encoding: 'windows-1252', profile_id: null });
    expect(r.lignes.map((l) => l.title)).toEqual(titresUtf8);
  });

  it('forced_encoding inconnu : ignoré, dit, détection automatique', async () => {
    const r = await banc({ fichier: octets(`${V}.unimarc-latin1.iso`), adapter_overrides: { forced_encoding: 'macintosh' } })();
    expect(r.finale.summary.encoding).toMatchObject({ used: 'windows-1252', forced: null, fallback: true });
    expect(r.finale.summary.warnings[0]).toContain('Encodage impose inconnu');
  });

  it('un CSV enregistré en Windows-1252 : accents exacts et avertissement sur la 1re ligne', async () => {
    const texte = 'titulo;autor\r\nDéjà vu;Élisée Reclus\r\nL’œuvre;Louise Michel\r\n';
    const cp1252 = Uint8Array.from([...texte].map((c) => ({ '’': 0x92, 'œ': 0x9c })[c] ?? c.charCodeAt(0)));
    const r = await banc({ fichier: cp1252, nom: 'catalogue.csv' })();
    expect(r.statut).toBe(200);
    expect(r.corps.detected_format).toBe('csv');
    expect(r.lignes.map((l) => l.title)).toEqual(['Déjà vu', 'L’œuvre']);
    expect(r.lignes[0].warnings[0]).toContain('suppose windows-1252');
    expect(r.finale.summary.encoding).toMatchObject({ used: 'windows-1252', fallback: true, declared_unimarc: [] });
  });

  it('H16 — un CSV : colonnes reprises, relues en indice, gardées en brut ; lignes vides écartées et comptées', async () => {
    const texte = 'titulo;autor;cote;tipo_material\r\nO Estado;Bakunin;320 BAK;livro\r\n;;;livro\r\nA Anarquia;Malatesta;320 MAL;livro\r\n';
    const r = await banc({ fichier: new TextEncoder().encode(texte), nom: 'catalogue.csv' })();
    expect(r.statut).toBe(200);
    const col = (h) => r.finale.summary.coverage.columns.find((c) => c.header === h);
    expect(r.finale.summary.coverage.kind).toBe('csv');
    expect(col('titulo')).toMatchObject({ status: 'repris', field: 'title', occurrences: 2 });
    expect(col('autor')).toMatchObject({ status: 'repris', field: 'author' });
    expect(col('cote')).toMatchObject({ status: 'indice', field: 'cote' });
    expect(col('tipo_material')).toMatchObject({ status: 'brut', field: null, occurrences: 3 });
    expect(r.finale.summary.coverage_counts).toEqual({ repris: 2, indice: 1, brut: 1, laisse: 0, total: 4 });
    // La ligne « ;;;livro » n'a aucun contenu bibliographique : écartée, et comptée.
    expect(r.lignes).toHaveLength(2);
    expect(r.finale.summary.skipped_rows).toBe(1);
  });
});

// H30 (04/10/2026) — « Retraiter » exige le fichier. Le fichier est lu AVANT le
// passage en 'processing' et AVANT l'effacement des lignes ; illisible alors que
// le run a des lignes : rien n'est touché, le refus va au journal du run, 409.
// Passes suivantes (même jour) : l'effacement est déplacé juste avant l'insertion,
// APRÈS le décodage et l'analyse, et un run qui a des lignes ne passe en
// 'processing' qu'à ce moment-là. Un échec avant (fichier vide, CSV sans donnée,
// MARC sans notice, aucune ligne retenue) ou le DELETE refusé par le déclencheur
// H21 gardent les lignes : journal « … [HINT] (rows kept, nothing reprocessed) »,
// 409 { rows_kept: true }, aucun 'failed', aucune RPC.
// Contre-épreuve (04/10/2026, miroir hors dépôt, index.ts du commit 07111e3d) :
// les deux « téléchargement en échec », les quatre « analyse en échec », le
// DELETE refusé et l'ordre du témoin lisible tombent (500 au lieu de 409 :
// processing, DELETE des lignes, puis 'failed') ; les trois témoins du premier
// import passent (même issue avant et après), comme les neuf tests d'avant H30.
describe('process-partner-catalog-import — « Retraiter » sans fichier lisible (H30)', () => {
  const ECHECS = [
    ['le Storage rend une erreur', () => ({ data: null, error: { message: 'Object not found' } }), 'Object not found'],
    ['le Storage ne rend rien', () => ({ data: null, error: null }), 'no file'],
  ];

  it.each(ECHECS)('force_reparse, run avec lignes, %s : ni processing ni DELETE, une entrée au journal, 409', async (_cas, telechargement, motif) => {
    const r = await banc({ fichier: octets(`${V}.unimarc.iso`), existantes: 50, retraiter: true, telechargement })();
    expect(r.statut).toBe(409);
    expect(r.corps).toMatchObject({ ok: false, run_id: 42 });
    expect(r.corps.error).toContain(motif);
    // Lu avant tout geste d'écriture ; après le refus, la seule trace au journal.
    expect(r.gestes).toEqual(['select runs', 'select fichiers', 'select lignes', 'download', 'select runs', 'update runs']);
    expect(r.touche).toBe(false);
    expect(r.statuts).toEqual([]);
    expect(r.efface).toBe(false);
    expect(r.ef.ecrits.filter((e) => e.op === 'insert')).toHaveLength(0);
    expect(r.fichierMaj).toBeUndefined();
    expect(r.ef.rpcs).toHaveLength(0);
    expect(r.journal).toHaveLength(1);
    expect(r.journal[0].message).toContain(motif);
    expect(r.journal[0].message).toContain('the rows were kept');
  });

  it.each(ECHECS)('TÉMOIN — premier import (aucune ligne), %s : comme avant, le run passe en échec, 500', async (_cas, telechargement, motif) => {
    const r = await banc({ fichier: octets(`${V}.unimarc.iso`), existantes: 0, telechargement })();
    expect(r.statut).toBe(500);
    expect(r.corps.ok).toBe(false);
    expect(r.echec).toBe(true);
    expect(r.statuts.at(-1)).toBe('failed');
    expect(r.statuts).not.toContain('ready_for_review');
    expect(r.efface).toBe(false);
    expect(r.lignes).toHaveLength(0);
    expect(r.fichierMaj).toEqual({ parse_status: 'error' });
    expect(r.journal).toHaveLength(1);
    expect(r.journal[0].message).toContain(motif === 'no file' ? 'returned no file' : motif);
  });

  // Le fichier se lit mais ne donne rien : l'échec vient de l'analyse, AVANT
  // 'processing' (un run qui a des lignes n'y passe qu'au moment d'effacer) et
  // AVANT l'effacement, déplacé juste avant l'insertion.
  const ANALYSES_EN_ECHEC = [
    ['fichier vide', { fichier: new TextEncoder().encode(' \r\n  \r\n'), nom: 'catalogue.csv' }, 'Import file is empty.'],
    ['CSV à en-tête seul', { fichier: new TextEncoder().encode('titulo;autor\r\n'), nom: 'catalogue.csv' }, 'CSV contains a header row but no data rows.'],
    ['MARC (forcé) sans notice', {
      fichier: new TextEncoder().encode('<?xml version="1.0" encoding="UTF-8"?>\n<collection xmlns="http://www.loc.gov/MARC21/slim"></collection>\n'),
      nom: 'export.xml', adapter_overrides: { forced_format: 'marc' },
    }, 'Format MARC force'],
    // Analysé, mais aucune colonne bibliographique : aucune ligne retenue.
    ['CSV sans aucune ligne retenue', { fichier: new TextEncoder().encode('tipo_material;cote\r\nlivro;320 BAK\r\nfolheto;320 MAL\r\n'), nom: 'catalogue.csv' }, 'Parsed file produced no rows.'],
  ];

  it.each(ANALYSES_EN_ECHEC)('force_reparse, run avec lignes, %s : ni run_status ni DELETE ni RPC, une entrée au journal, 409 rows_kept', async (_cas, o, motif) => {
    const r = await banc({ ...o, existantes: 50, retraiter: true })();
    expect(r.statut).toBe(409);
    expect(r.corps).toMatchObject({ ok: false, run_id: 42, rows_kept: true });
    expect(r.corps.error).toContain(motif);
    expect(r.gestes).toEqual(['select runs', 'select fichiers', 'select lignes', 'download', 'select runs', 'update runs']);
    expect(r.touche).toBe(false);
    expect(r.statuts).toEqual([]);
    expect(r.efface).toBe(false);
    expect(r.ef.ecrits.filter((e) => e.op === 'insert')).toHaveLength(0);
    expect(r.ef.rpcs).toHaveLength(0);
    expect(r.fichierMaj).toBeUndefined();
    expect(r.journal).toHaveLength(1);
    expect(r.journal[0].message).toBe(`${motif.endsWith('force') ? r.corps.error : motif} (rows kept, nothing reprocessed)`);
  });

  // H31 (05/10/2026) : l'effacement est la RPC qui verrouille le run et rejoue
  // la garde de fn_import_dispatch ; son refus (garde, ou déclencheur du lot 0
  // à travers elle) suit le chemin H30 : lignes gardées, 409 rows_kept.
  it.each([
    ['la garde rejouée au moment d\'effacer (reparse_after_promotion)', {
      code: 'P0001', details: null, hint: 'error.import.reparse_after_promotion',
      message: 'Import 42 ja promovido em rascunhos : nao pode ser reprocessado.',
    }],
    ['le déclencheur du lot 0 à travers la RPC (rows_held_by_items)', {
      code: 'P0001', details: null, hint: 'error.import.rows_held_by_items',
      message: 'Ligne d\'import 901 retenue par un exemplaire rapproche non publie.',
    }],
  ])('force_reparse, run avec lignes, effacement (RPC) refusé par %s : 409 rows_kept, la HINT au journal, aucun failed', async (_cas, refus) => {
    const r = await banc({ fichier: octets(`${V}.unimarc.iso`), existantes: 50, retraiter: true, refusEffacement: refus })();
    expect(r.statut).toBe(409);
    expect(r.corps).toMatchObject({ ok: false, run_id: 42, rows_kept: true, error: refus.message });
    expect(r.gestes).toEqual(['select runs', 'select fichiers', 'select lignes', 'download', `rpc ${EFFACEMENT}`, 'select runs', 'update runs']);
    expect(r.ef.rpcs).toEqual([{ schema: 'ingest', nom: EFFACEMENT, args: { p_run_id: 42, p_fichiers_recus: false } }]);
    expect(r.deleteDirect).toBe(false);
    expect(r.ef.ecrits.filter((e) => e.op === 'insert')).toHaveLength(0);
    expect(r.fichierMaj).toBeUndefined();
    expect(r.echec).toBe(false);
    // 'processing' ne vient qu'après un effacement réussi : refusé, le run est intact.
    expect(r.touche).toBe(false);
    expect(r.statuts).toEqual([]);
    expect(r.journal).toHaveLength(1);
    expect(r.journal[0].message).toBe(`${refus.message} [${refus.hint}] (rows kept, nothing reprocessed)`);
  });

  it('comptage des lignes en échec : rien n\'a bougé — 409 rows_kept, l\'erreur au journal, ni run_status ni téléchargement ni DELETE', async () => {
    const delai = { code: '57014', details: null, hint: null, message: 'canceling statement due to statement timeout' };
    const r = await banc({ fichier: octets(`${V}.unimarc.iso`), existantes: 50, retraiter: true, refusComptage: delai })();
    expect(r.statut).toBe(409);
    expect(r.corps).toMatchObject({ ok: false, run_id: 42, rows_kept: true, error: delai.message });
    expect(r.gestes).toEqual(['select runs', 'select fichiers', 'select lignes', 'select runs', 'update runs']);
    expect(r.ef.telechargements).toHaveLength(0);
    expect(r.touche).toBe(false);
    expect(r.statuts).toEqual([]);
    expect(r.echec).toBe(false);
    expect(r.efface).toBe(false);
    expect(r.ef.ecrits.filter((e) => e.op === 'insert')).toHaveLength(0);
    expect(r.ef.rpcs).toHaveLength(0);
    expect(r.fichierMaj).toBeUndefined();
    expect(r.journal).toHaveLength(1);
    expect(r.journal[0].message).toBe(`${delai.message} (rows kept, nothing reprocessed)`);
  });

  it('TÉMOIN — premier import (sans « Retraiter »), comptage en échec : le run passe en échec, 500 — jamais « en cours » sans fin', async () => {
    // Revue sceptique du 04/10 : avec une garde des lignes vraie d'emblée, ce
    // run restait « uploaded/queued », affiché « en cours » sans fin. La garde
    // ne vaut que pour un retraitement (force_reparse).
    const delai = { code: '57014', details: null, hint: null, message: 'canceling statement due to statement timeout' };
    const r = await banc({ fichier: octets(`${V}.unimarc.iso`), refusComptage: delai })();
    expect(r.statut).toBe(500);
    expect(r.corps.rows_kept).toBeUndefined();
    expect(r.statuts).toEqual(['failed']);
    expect(r.efface).toBe(false);
  });

  it('TÉMOIN — premier import (aucune ligne), échec d\'analyse (CSV à en-tête seul) : comme avant, le run passe en échec, 500', async () => {
    const r = await banc({ fichier: new TextEncoder().encode('titulo;autor\r\n'), nom: 'catalogue.csv' })();
    expect(r.statut).toBe(500);
    expect(r.corps.ok).toBe(false);
    expect(r.corps.rows_kept).toBeUndefined();
    expect(r.echec).toBe(true);
    expect(r.statuts).toEqual(['processing', 'failed']);
    expect(r.efface).toBe(false);
    expect(r.lignes).toHaveLength(0);
    expect(r.fichierMaj).toEqual({ parse_status: 'error' });
    expect(r.ef.rpcs).toHaveLength(0);
    expect(r.journal).toHaveLength(1);
    expect(r.journal[0].message).toBe('CSV contains a header row but no data rows.');
  });

  it('TÉMOIN — fichier lisible : lecture, (analyse), effacement des lignes du run (RPC H31), processing, réinsertion, d\'un seul tenant', async () => {
    const r = await banc({ fichier: octets(`${V}.unimarc.iso`), existantes: 50, retraiter: true })();
    expect(r.statut).toBe(200);
    expect(r.lignes).toHaveLength(50);
    const i = (g) => r.gestes.indexOf(g);
    expect(r.gestes.filter((g) => g === 'download')).toHaveLength(1);
    expect(r.gestes.filter((g) => g === `rpc ${EFFACEMENT}`)).toHaveLength(1);
    expect(r.deleteDirect).toBe(false);
    expect(r.gestes.filter((g) => g === 'update runs:processing')).toHaveLength(1);
    expect(r.gestes.slice(0, i('download') + 1)).toEqual(['select runs', 'select fichiers', 'select lignes', 'download']);
    // L'analyse (invisible ici) se fait entre la lecture et l'effacement : les cas
    // « analyse en échec » plus haut le prouvent (ni DELETE ni 'processing').
    expect(r.gestes.slice(i('download'), i('download') + 4)).toEqual(['download', `rpc ${EFFACEMENT}`, 'update runs:processing', 'insert lignes']);
    // La RPC vise le run, et lui seul, sans fichiers reçus (un import de fichier n'en a pas).
    expect(r.ef.rpcs.filter((x) => x.nom === EFFACEMENT)).toEqual([{ schema: 'ingest', nom: EFFACEMENT, args: { p_run_id: 42, p_fichiers_recus: false } }]);
    expect(r.statuts).toEqual(['processing', 'ready_for_review']);
  });
});
