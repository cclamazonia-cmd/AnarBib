// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/deno-tests-pont.test.js
//
// POURQUOI CE FICHIER EXISTE (H27(0), 26/09/2026). Les tests du parseur MARC
// (process-partner-catalog-import/marc.test.ts) et du sérialiseur d'export
// (export-catalog-lote/serialize.test.ts) sont des tests Deno. Or la CI ne
// lance aucun `deno test`, et vitest exclut supabase/functions/** : ces 16
// tests ne tournaient NULLE PART. On allait retoucher le parseur (H15-H19)
// sans filet.
//
// Plutôt que de les porter (deux copies qui divergeraient), on les joue tels
// quels : `Deno.test(nom, fn)` devient `it(nom, fn)`, et `jsr:@std/assert` est
// servi par une cale sur `expect` (src/tests/helpers/std-assert-pont.js,
// alias dans vitest.config.js). `deno test --no-check` reste possible sur le
// poste (~/.deno/bin/deno).
//
// Limites : le pont ne vérifie pas les types (deno check signale des
// paramètres implicitement `any`), et il ne convient qu'aux tests PURS — un
// test qui appelle Deno.env, Deno.readTextFile ou importe https:// n'y a pas
// sa place (mail-strings*.test.ts, laissés hors du pont).
//
// Un pont silencieux (zéro test enregistré) serait un faux vert : le dernier
// `it` exige le compte exact, à mettre à jour quand on ajoute un Deno.test.

import { it, expect, vi, afterAll } from 'vitest';

// marc.test.ts 13 + encoding.test.ts 5 + serialize.test.ts 7 (26/09/2026, H15)
const ATTENDUS = 25;

let enregistres = 0;
vi.stubGlobal('Deno', {
  test: (nom, fn) => {
    enregistres += 1;
    it(`[deno] ${nom}`, fn);
  },
});
afterAll(() => vi.unstubAllGlobals());

// Chemins littéraux (un import dynamique à chemin calculé échappe à l'analyse
// de Vite) ; un fichier ajouté ici doit l'être aussi dans ATTENDUS.
await import('../../supabase/functions/process-partner-catalog-import/marc.test.ts');
await import('../../supabase/functions/process-partner-catalog-import/encoding.test.ts');
await import('../../supabase/functions/export-catalog-lote/serialize.test.ts');

it('le pont a enregistré tous les tests Deno attendus', () => {
  expect(enregistres).toBe(ATTENDUS);
});
