// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/health-probe-catalogue-par-oeuvre.test.js
//
// CE QUE CE TEST PROTÈGE (B27, 21/09/2026). `api.catalog_works_v1` a dépassé les
// 3 s du rôle `anon` — treize appels anonymes sur treize en `57014` — sans que
// RIEN ne le montre : le front retombe sur la liste à plat, l'écran reste
// plein, et le regroupement par œuvre ne sert plus à aucun visiteur non
// connecté. Une panne que son repli masque parfaitement est une panne qui dure.
//
// La requête est réparée (migration 20260921111344) ; ce test garde ce qui la
// SURVEILLE : la sonde de santé appelle la RPC comme le front l'appelle pour un
// visiteur anonyme, et la juge sur le délai qui la tue en production.
//   1. la sonde existe, en POST, sur le schéma `api`, avec la clé anonyme ;
//   2. ses arguments sont ceux du premier chargement du catalogue — si le front
//      change sa page par défaut, la sonde doit suivre (même taille de page) ;
//   3. le seuil de lenteur de la sonde vaut le `statement_timeout` du rôle
//      `anon` (3 s) : le relever rendrait la sonde aveugle à cette panne-là.
// vitest.config.js exclut supabase/functions/** : on lit la SOURCE.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const lire = (rel) => readFileSync(new URL(rel, import.meta.url), 'utf8');
const sonde = lire('../../supabase/functions/health-probe/index.ts');
const lib = lire('../lib/catalogWorks.js');

// Le bloc de la sonde : de son `endpoint` à la fin de son objet `init`.
const debut = sonde.indexOf("endpoint: 'catalogue_par_oeuvre'");
const bloc = debut < 0 ? '' : sonde.slice(debut, sonde.indexOf('},\n    },', debut));

describe('health-probe — le catalogue par œuvre est surveillé (B27)', () => {
  it('la sonde existe : POST sur la RPC, schéma api, clé anonyme', () => {
    expect(debut, 'sonde catalogue_par_oeuvre absente').toBeGreaterThan(-1);
    expect(bloc).toContain('/rest/v1/rpc/catalog_works_v1');
    expect(bloc).toMatch(/method:\s*'POST'/);
    expect(bloc).toMatch(/'Content-Profile':\s*'api'/);
    // `h` porte apikey + Bearer de la clé ANONYME : jamais la clé secrète, qui passerait outre le délai du rôle
    expect(bloc).toMatch(/headers:\s*\{\s*\.\.\.h,/);
    expect(sonde).toMatch(/const h = \{ apikey: ANON, Authorization: `Bearer \$\{ANON\}` \}/);
  });

  it('ses arguments sont ceux du premier chargement du catalogue', () => {
    const m = bloc.match(/body:\s*JSON\.stringify\((\{[^)]*\})\)/);
    expect(m, 'corps de la sonde introuvable').not.toBeNull();
    const args = new Function('return ' + m[1])();
    expect(args.p_filters).toEqual({});
    expect(args.p_sort).toBe('relevance');
    expect(args.p_offset).toBe(0);
    const page = lib.match(/export const WORKS_PAGE_SIZE = (\d+);/);
    expect(page, 'WORKS_PAGE_SIZE introuvable').not.toBeNull();
    expect(args.p_limit).toBe(Number(page[1]));
  });

  it('le seuil de lenteur vaut le délai du rôle anon : 3 s', () => {
    const m = sonde.match(/const SEUIL_LENT_MS = (\d+);/);
    expect(m).not.toBeNull();
    expect(Number(m[1])).toBe(3000);
  });
});
