// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/buckets-liste-fermee.test.js
//
// Les dix-sept buckets Storage de la production sont déclarés à TROIS endroits,
// qui servent trois moments différents :
//   * les migrations qui les CRÉENT (20260828000000 pour seize, 20260907234500
//     pour map-tiles) — le jour où l'on reconstruit une pile depuis le dépôt ;
//   * tests/sql/_ci_setup_storage_stub.sql — le stub qui les sème en CI, parce
//     que là aucun service Storage ne tourne ;
//   * deploy/bootstrap.sh — le nombre attendu au contrôle de l'étape 8.
//
// Le 12/10/2026, en préparant la VM d'ASR2026, deploy/README.md et l'étape 8
// de bootstrap.sh affirmaient encore « aucune migration ne crée de bucket »,
// phrase vraie le 26/08 et fausse depuis le 28/08 : une pile neuve aurait été
// déclarée saine avec zéro bucket. Cette garde tient les trois endroits
// ensemble : un bucket ajouté ou renommé en production se déclare dans les
// trois, ou la CI est rouge.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';

const racine = new URL('../../', import.meta.url);
const lire = (p) => readFileSync(new URL(p, racine), 'utf8');

// La liste fermée : les dix-sept identifiants relevés en production le 12/10/2026.
const ATTENDUS = [
  'anarbib-carte-rede',
  'anarbib-epub-public',
  'anarbib-epub-restricted',
  'anarbib-media-public',
  'anarbib-media-restricted',
  'anarbib-pdf-public',
  'authors',
  'catalogos_parceiros_raw',
  'covers',
  'library-privacy-public',
  'library-regimentos-private',
  'library-regimentos-public',
  'library-ui-assets',
  'map-tiles',
  'network-map',
  'partner-catalog-deposits',
  'pdf-restrito',
].sort();

// Identifiants insérés par un `insert into storage.buckets (id, …) values (...)`.
const idsInseres = (sql) => {
  const ids = new Set();
  const blocs = sql.matchAll(/insert\s+into\s+storage\.buckets\s*\([^)]*\)\s*values\s*([\s\S]*?)\s*on\s+conflict/gi);
  for (const [, valeurs] of blocs) {
    for (const [, id] of valeurs.matchAll(/\(\s*'([^']+)'\s*,/g)) ids.add(id);
  }
  return [...ids].sort();
};

const dossier = new URL('supabase/migrations/', racine);
const migrations = readdirSync(dossier).filter((f) => /^\d{14}_.*\.sql$/.test(f)).sort();
const parMigration = migrations
  .map((f) => ({ fichier: f, ids: idsInseres(readFileSync(new URL(f, dossier), 'utf8')) }))
  .filter((m) => m.ids.length > 0);
const idsMigrations = [...new Set(parMigration.flatMap((m) => m.ids))].sort();

const idsStub = idsInseres(lire('tests/sql/_ci_setup_storage_stub.sql'));

const bootstrap = lire('deploy/bootstrap.sh');
const attenduBootstrap = Number((bootstrap.match(/^BUCKETS_ATTENDUS=(\d+)$/m) || [])[1]);

describe('buckets Storage — une liste fermée, trois endroits', () => {
  it('les migrations créent exactement les dix-sept buckets de la production', () => {
    expect(idsMigrations).toEqual(ATTENDUS);
  });

  it('les deux migrations créatrices sont celles qu’on nomme', () => {
    expect(parMigration.map((m) => m.fichier)).toEqual([
      '20260828000000_storage_buckets_reconstructibles.sql',
      '20260907234500_bucket_map_tiles_fond_de_carte.sql',
    ]);
  });

  it('le stub Storage de la CI sème la même liste', () => {
    expect(idsStub).toEqual(ATTENDUS);
  });

  it('bootstrap.sh attend ce nombre-là à l’étape 8', () => {
    expect(attenduBootstrap).toBe(ATTENDUS.length);
  });

  it('bootstrap.sh ne dit plus que zéro bucket est attendu après le rejeu', () => {
    expect(bootstrap).not.toMatch(/AUCUNE migration ne CRÉE de bucket/);
    expect(lire('deploy/README.md')).not.toMatch(/aucune\s+migration ne crée les buckets/);
  });

  it('le plafond global Storage de .env.example couvre le plus gros bucket', () => {
    const env = lire('deploy/.env.example');
    const global = Number((env.match(/^STORAGE_FILE_SIZE_LIMIT=(\d+)$/m) || [])[1]);
    const plafonds = migrations
      .map((f) => readFileSync(new URL(f, dossier), 'utf8'))
      .flatMap((sql) => [...sql.matchAll(/(?:file_size_limit\s*(?:=|:=)\s*|'map-tiles',\s*true,\s*)(\d{6,})/g)].map((m) => Number(m[1])));
    expect(plafonds.length).toBeGreaterThan(0);
    expect(global).toBeGreaterThanOrEqual(Math.max(...plafonds));
  });
});
