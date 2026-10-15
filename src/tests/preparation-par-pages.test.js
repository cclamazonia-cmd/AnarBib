// CHEMIN DÉPÔT : src/tests/preparation-par-pages.test.js
//
// 15/10/2026 — « Préparer la mise à jour » suit la promotion du 14/10 : 100
// lignes et 2 500 exemplaires du fichier par appel. T18b de h21_lot6b
// (200 x 25) a dépassé quatre fois les 8 s des appels de l'API sous la charge
// du runner ; la page se réduit, jamais le seuil. Ce test garde l'accord entre
// l'écran (pagesDePreparation) et la base (la dernière migration qui pose la
// page de préparation), et que le recalcul garde 200 / 5 000.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import {
  pagesDePreparation, pagesParExemplaires, PLAFOND_LIGNES, PLAFOND_EXEMPLAIRES,
  PLAFOND_PREPARATION_LIGNES, PLAFOND_PREPARATION_EXEMPLAIRES,
} from '@/lib/importItemUpdates.js';

const RACINE = path.resolve(__dirname, '..', '..');
const lignes = (n, k) => Array.from({ length: n }, (_, i) => ({ id: i + 1, exemplaires: Array(k) }));

describe('la page de « Préparer la mise à jour »', () => {
  it('100 lignes et 2 500 exemplaires du fichier ; le recalcul garde 200 / 5 000', () => {
    expect(PLAFOND_PREPARATION_LIGNES).toBe(100);
    expect(PLAFOND_PREPARATION_EXEMPLAIRES).toBe(2500);
    expect(PLAFOND_LIGNES).toBe(200);
    expect(PLAFOND_EXEMPLAIRES).toBe(5000);
    expect(pagesDePreparation(lignes(250, 0)).map((p) => p.length)).toEqual([100, 100, 50]);
    expect(pagesDePreparation(lignes(200, 25)).map((p) => p.length)).toEqual([100, 100]);
    expect(pagesDePreparation(lignes(100, 30)).map((p) => p.length)).toEqual([83, 17]);
    expect(pagesParExemplaires(lignes(200, 25)).map((p) => p.length)).toEqual([200]);
  });

  it('les plafonds de l’écran sont ceux de la dernière migration de la préparation', () => {
    const dir = path.join(RACINE, 'supabase', 'migrations');
    const f = readdirSync(dir).filter((x) => /^\d{14}_.*\.sql$/.test(x)).sort().reverse()
      .find((x) => readFileSync(path.join(dir, x), 'utf8').includes("HINT = 'error.import.preparation_page_too_many_items'"));
    expect(f).toBeTruthy();
    const sql = readFileSync(path.join(dir, f), 'utf8');
    const posee = sql.slice(sql.indexOf('$b$', sql.indexOf("'les lignes'")));
    expect(Number(posee.match(/IF coalesce\(cardinality\(p_row_ids\), 0\) > (\d+) THEN/)[1])).toBe(PLAFOND_PREPARATION_LIGNES);
    expect(Number(posee.match(/IF v_items_demandes > (\d+) THEN/)[1])).toBe(PLAFOND_PREPARATION_EXEMPLAIRES);
    expect(posee).toContain("HINT = 'error.import.update_page_too_large'");
  });
});
