import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: [
      { find: '@', replacement: path.resolve(__dirname, 'src') },
      // Les tests Deno des edge functions (marc.test.ts, serialize.test.ts) sont
      // joués TELS QUELS par src/tests/deno-tests-pont.test.js : leur import
      // `jsr:@std/assert` (épinglé ou non) est servi par une cale sur `expect`.
      // Sans ce pont ils ne tournaient nulle part (H27(0), 26/09/2026).
      { find: /^jsr:@std\/assert(@[\d.]+)?$/, replacement: path.resolve(__dirname, 'src/tests/helpers/std-assert-pont.js') },
    ],
  },
  test: {
    environment: 'jsdom',
    globals: true,
    // Le runner de la forge est la machine de développement elle-même : un run qui
    // tombe pendant un autre travail (build, banc SQL, téléversement) met 55 s au
    // lieu de 22, et les tests qui transpilent un gros module à la volée (esbuild)
    // ou lancent un script Node dépassent alors les 5 s par défaut. Constaté le
    // 20/09/2026 (run du commit f83c5f66) : quatre « Test timed out in 5000ms »
    // sur des tests qui prennent 1 à 2 s hors charge, déploiement backend sauté
    // pour rien. 20 s laisse la marge sans masquer un test réellement bloqué.
    //
    // 19/10/2026 : 20 s ne suffisent plus EN CI. Runs #1835 à #1840 rouges sur des
    // seuls « Test timed out in 20000ms », jamais les mêmes tests (1, 1, 2, 7, 2 :
    // surtout ceux qui montent ImportacoesPage, mais aussi bg2-ingest et un test
    // qui ne fait que lire les locales), sous une charge de 30 à 48 sur 8 cœurs —
    // runner + suites vitest complètes lancées en parallèle par les sessions. Un
    // délai par test (9cbf470c) ne rattrape qu'un nom à la fois. En CI (CI=true,
    // posé par l'étape « Tests » de ci.yml) : 60 s et UNE relance d'un test
    // échoué, qui couvre aussi l'échec par ricochet d'un voisin (#1839 : « expected
    // bound to be called »). En local, rien ne change : 20 s, aucune relance, pour
    // qu'un test lent ou instable se voie là où on le corrige.
    testTimeout: process.env.CI ? 60000 : 20000,
    hookTimeout: process.env.CI ? 60000 : 20000,
    retry: process.env.CI ? 1 : 0,
    setupFiles: ['./src/tests/setup.js'],
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
      // Edge Functions Supabase (Deno, pas Node). Leurs tests purs (sans API
      // Deno autre que Deno.test) passent par src/tests/deno-tests-pont.test.js.
      '**/supabase/functions/**',
      // Copies de travail des sessions (.claude/worktrees/<nom>/, I40, 19/10/2026) :
      // une suite lancée depuis ~/anarbib ramassait LEURS tests — 14 faux échecs
      // le 18/10, 7 le 19/10 — et chargeait le poste qui fait aussi tourner la CI.
      '**/.claude/**',
    ],
  },
});
