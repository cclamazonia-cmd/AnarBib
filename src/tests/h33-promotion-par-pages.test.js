// ═══════════════════════════════════════════════════════════
// AnarBib — H33, suite (14/10/2026) : la promotion va par pages plus petites.
//
// T08 (tests/sql/h33_rapprocher_gros_fichier_tests.sql) a rougi le 13/10 :
// « Promouvoir » 200 x 25 = 8 099 ms pour les 8 s des appels de l'API, sous la
// charge d'un second job. La note de H33 : réduire la page, jamais le seuil.
// Ce banc tient l'accord entre l'écran et la base :
//   * les plafonds de la promotion (src/lib/importItemUpdates.js) sont ceux
//     que la dernière migration de la promotion pose dans
//     ingest.fn_create_book_drafts_from_import_rows ;
//   * les deux appels de fn_import_promote (Importations, assistant) passent
//     par pagesDePromotion, et aucun par pagesParExemplaires ;
//   * les autres gestes gardent 200 lignes / 5 000 exemplaires.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import {
  pagesDePromotion, pagesParExemplaires, PLAFOND_LIGNES, PLAFOND_EXEMPLAIRES,
  PLAFOND_PROMOTION_LIGNES, PLAFOND_PROMOTION_EXEMPLAIRES,
} from '@/lib/importItemUpdates.js';

const RACINE = path.resolve(__dirname, '..', '..');
const lire = (rel) => readFileSync(path.join(RACINE, rel), 'utf8');
const lignes = (n, k) => Array.from({ length: n }, (_, i) => ({ id: i + 1, exemplaires: Array(k) }));

describe('la page de la promotion', () => {
  it('100 lignes et 2 500 exemplaires du fichier ; les autres gestes gardent 200 / 5 000', () => {
    expect(PLAFOND_PROMOTION_LIGNES).toBe(100);
    expect(PLAFOND_PROMOTION_EXEMPLAIRES).toBe(2500);
    expect(PLAFOND_LIGNES).toBe(200);
    expect(PLAFOND_EXEMPLAIRES).toBe(5000);
    expect(pagesDePromotion(lignes(250, 0)).map((p) => p.length)).toEqual([100, 100, 50]);
    expect(pagesDePromotion(lignes(200, 25)).map((p) => p.length)).toEqual([100, 100]);
    expect(pagesDePromotion(lignes(200, 30)).map((p) => p.length)).toEqual([83, 83, 34]);
    expect(pagesParExemplaires(lignes(200, 25)).map((p) => p.length)).toEqual([200]);
  });

  it('les plafonds de l’écran sont ceux de la dernière migration de la promotion', () => {
    const dir = path.join(RACINE, 'supabase', 'migrations');
    const f = readdirSync(dir).filter((x) => /^\d{14}_.*\.sql$/.test(x)).sort().reverse()
      .find((x) => readFileSync(path.join(dir, x), 'utf8').includes("using hint = 'error.import.promotion_page_too_large'"));
    expect(f).toBeTruthy();
    const sql = readFileSync(path.join(dir, f), 'utf8');
    const posee = sql.slice(sql.lastIndexOf('$b$', sql.indexOf("using hint = 'error.import.promotion_page_too_large'")));
    expect(Number(posee.match(/if v_requested_count > (\d+) then/)[1])).toBe(PLAFOND_PROMOTION_LIGNES);
    expect(Number(posee.match(/if v_items_demandes > (\d+) then/)[1])).toBe(PLAFOND_PROMOTION_EXEMPLAIRES);
    expect(posee).toContain("using hint = 'error.import.promotion_page_too_many_items'");
  });

  it('les deux appels de fn_import_promote passent par pagesDePromotion', () => {
    // E6 (23/10/2026) : l'appel de la page vit dans ImportReviewQueue.jsx
    for (const rel of ['src/pages/importacoes/ImportReviewQueue.jsx', 'src/pages/importacoes/ImportWizard.jsx']) {
      const s = lire(rel);
      const appels = [...s.matchAll(/supabase\.rpc\('fn_import_promote'/g)];
      expect(appels.length, rel).toBe(1);
      const avant = s.slice(Math.max(0, appels[0].index - 200), appels[0].index);
      expect(avant, rel).toMatch(/for \(const page of pagesDePromotion\(/);
      expect(avant, rel).not.toMatch(/pagesParExemplaires\(/);
    }
  });
});
