// ═══════════════════════════════════════════════════════════
// AnarBib — aucun nom importé deux fois dans une Edge Function (21/09/2026)
//
// INCIDENT du 21/09/2026, 20 h 45 → correctif le soir même : `register` a répondu
// 503 BOOT_ERROR en production — les inscriptions étaient fermées — parce qu'un
// script de pose rejoué (« vérification d'idempotence ») avait DUPLIQUÉ la ligne
//     import { APP_BASE_URL, appUrl } from "../_shared/core/app-url.ts";
// Deno refuse de démarrer un module qui déclare deux fois le même nom. Or rien ne
// l'a vu : esbuild, qui transpile les bancs (register-banc et les autres), tolère
// le doublon en sortie CommonJS ; ESLint ignore supabase/functions ; et la CI
// déploie sans démarrer la fonction. Le banc était vert, le déploiement vert, la
// fonction morte.
//
// Ce test ferme le trou pour toutes les fonctions : dans chaque fichier .ts de
// supabase/functions, un nom local ne peut être lié que par UN import.
// (Leçon d'outillage, écrite aussi en mémoire : dans un script de pose, tester la
// présence du REMPLACEMENT avant de compter l'ancre — une ancre qui est un préfixe
// de son remplacement se « retrouve » à chaque passe.)
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const BASE = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'supabase', 'functions');

function* fichiers(rel = '') {
  for (const e of readdirSync(join(BASE, rel), { withFileTypes: true })) {
    const p = rel ? `${rel}/${e.name}` : e.name;
    if (e.isDirectory()) yield* fichiers(p);
    else if (/\.ts$/.test(e.name)) yield p;
  }
}

/** Noms locaux liés par les imports d'un source (défaut, espace de noms, nommés avec `as`). */
export function nomsImportes(src) {
  const noms = [];
  const sansCommentaires = src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  for (const m of sansCommentaires.matchAll(/^\s*import\s+(?!type\b)([^'"]*?)\s+from\s*['"][^'"]+['"]/gm)) {
    let clause = m[1].trim();
    const accolades = clause.match(/\{([\s\S]*)\}/);
    if (accolades) {
      for (const brut of accolades[1].split(',')) {
        const t = brut.trim().replace(/^type\s+/, '');
        if (!t) continue;
        noms.push(t.includes(' as ') ? t.split(' as ')[1].trim() : t);
      }
      clause = clause.replace(accolades[0], '').replace(/,/g, ' ').trim();
    }
    const etoile = clause.match(/\*\s+as\s+([A-Za-z_$][\w$]*)/);
    if (etoile) { noms.push(etoile[1]); clause = clause.replace(etoile[0], '').trim(); }
    if (/^[A-Za-z_$][\w$]*$/.test(clause)) noms.push(clause);
  }
  return noms;
}

describe('Edge Functions — un nom ne s\'importe qu\'une fois par fichier', () => {
  it('le détecteur voit un doublon, et ne s\'alarme pas pour rien', () => {
    expect(nomsImportes('import { a, b as c } from "./x.ts";\nimport d, { e } from "./y.ts";\nimport * as f from "./z.ts";')).toEqual(['a', 'c', 'e', 'd', 'f']);
    const doublon = 'import { APP_BASE_URL, appUrl } from "./app-url.ts";\nimport { APP_BASE_URL, appUrl } from "./app-url.ts";';
    expect(nomsImportes(doublon).filter((n) => n === 'appUrl')).toHaveLength(2);
    expect(nomsImportes('// import { a } from "./x.ts";\nimport { a } from "./x.ts";')).toEqual(['a']);
  });

  it('aucun fichier de supabase/functions ne lie deux fois le même nom', () => {
    const fautifs = [];
    let vus = 0;
    for (const f of fichiers()) {
      vus += 1;
      const noms = nomsImportes(readFileSync(join(BASE, f), 'utf8'));
      const doubles = [...new Set(noms.filter((n, i) => noms.indexOf(n) !== i))];
      if (doubles.length) fautifs.push(`${f} : ${doubles.join(', ')}`);
    }
    expect(vus).toBeGreaterThan(80);
    expect(fautifs, 'Deno refuse de démarrer la fonction (503 BOOT_ERROR)').toEqual([]);
  });
});
