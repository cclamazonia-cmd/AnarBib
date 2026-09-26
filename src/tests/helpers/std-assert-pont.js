// Cale de `jsr:@std/assert` pour faire tourner sous vitest, TELS QUELS, les
// tests Deno des edge functions (H27(0), 26/09/2026) — voir
// src/tests/deno-tests-pont.test.js. vitest.config.js redirige l'import
// `jsr:@std/assert` (avec ou sans version épinglée) vers ce fichier.
//
// Seules les assertions employées par les tests pontés sont fournies ; une
// assertion manquante fait échouer l'import (« n'est pas exportée »), jamais
// passer un test en silence.
import { expect } from 'vitest';

// @std/assert compare en profondeur, types et valeurs : toEqual en est
// l'équivalent vitest (toStrictEqual distinguerait en plus une clé absente
// d'une clé à undefined, ce que @std/assert ne fait pas non plus).
export function assertEquals(actual, expected, msg) {
  expect(actual, msg).toEqual(expected);
}

export function assert(expr, msg) {
  expect(expr, msg).toBeTruthy();
}

// assertThrows(fn, ErrorClass?, msgIncludes?, msg?) — signature de @std/assert.
export function assertThrows(fn, ErrorClass, msgIncludes, msg) {
  let levee = null;
  try { fn(); } catch (e) { levee = e; }
  expect(levee, msg || 'une exception était attendue').not.toBeNull();
  if (typeof ErrorClass === 'function') expect(levee).toBeInstanceOf(ErrorClass);
  if (typeof msgIncludes === 'string') expect(String(levee?.message)).toContain(msgIncludes);
  return levee;
}
