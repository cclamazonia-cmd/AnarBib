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
//     bibliothèque décide des sous-zones ; un profil illisible arrête l'import.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { monterEF } from './helpers/monter-ef.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const FIX = path.resolve(here, '..', '..', 'tests', 'pmb', 'fixtures');
const octets = (nom) => new Uint8Array(readFileSync(path.join(FIX, nom)));
const SECRET = 'banc-secret';

function banc({ fichier, nom = 'export.marc', adapter_overrides = {}, profil = null, existantes = 0, retraiter = false }) {
  const run = {
    id: 42, source_id: 7, library_id: 'lib-1', bucket_id: 'catalogos_parceiros_raw',
    storage_path: `lib-1/${nom}`, original_filename: nom, detected_format: 'marc_iso2709',
    adapter_overrides, error_log: [],
  };
  const ef = monterEF({
    entree: 'process-partner-catalog-import/index.ts',
    env: { ANARBIB_PARTNER_IMPORT_SECRET: SECRET },
    stockage: () => ({ data: new Blob([fichier]), error: null }),
    repondre: (schema, table, a) => {
      if (table === 'partner_catalog_import_runs' && a('select')) return { data: run, error: null };
      if (table === 'partner_catalog_import_files' && a('select')) return { data: { id: 5, file_role: 'uploaded' }, error: null };
      if (table === 'partner_catalog_staging_rows' && a('select')) return { data: null, count: existantes, error: null };
      if (table === 'import_profiles' && profil) return profil(a);
      return { data: null, error: null };
    },
    rpc: (_s, nom) => ({ data: nom === 'fn_match_partner_catalog_run' ? { matched: 0 } : { ok: true }, error: null }),
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
    const efface = ef.ecrits.some((e) => e.table === 'partner_catalog_staging_rows' && e.op === 'delete');
    const touche = ef.ecrits.some((e) => e.table === 'partner_catalog_import_runs' && e.op === 'update' && 'run_status' in e.donnees);
    const journal = ef.ecrits.filter((e) => e.table === 'partner_catalog_import_runs' && e.op === 'update' && e.donnees.error_log)
      .flatMap((e) => e.donnees.error_log);
    return { ...r, lignes, finale, fichierMaj, echec, efface, touche, journal };
  };
}

const V = 'pmb-8.1.1.1_jeu-de-test';

describe('process-partner-catalog-import sur un export PMB réel (H15, H28)', () => {
  let titresUtf8 = null;

  it('UNIMARC en UTF-8 : 50 lignes marc_iso2709, encodage utf-8 déclaré 50, aucun avertissement', async () => {
    const r = await banc({ fichier: octets(`${V}.unimarc.iso`) })();
    expect(r.statut).toBe(200);
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
    expect(r.finale.summary.items).toEqual({ rows_with_items: 31, items: 33, with_code: 33 });
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
