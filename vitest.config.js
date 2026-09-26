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
    testTimeout: 20000,
    hookTimeout: 20000,
    setupFiles: ['./src/tests/setup.js'],
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
      // Edge Functions Supabase (Deno, pas Node). Leurs tests purs (sans API
      // Deno autre que Deno.test) passent par src/tests/deno-tests-pont.test.js.
      '**/supabase/functions/**',
    ],
  },
});
