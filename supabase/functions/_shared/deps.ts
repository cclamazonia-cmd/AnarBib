// Dépendances épinglées des Edge Functions — UN SEUL ENDROIT (I16, 03/09/2026).
//
// Avant : une fonction épinglait `supabase-js@2.112.4` (env.ts), trente autres
// flottaient en `@2`, résolu au déploiement. Le 01/09, l'épinglée avait soixante
// versions de retard et ignorait les clés `sb_` que les flottantes supportaient
// en silence — le mélange donne le pire des deux régimes : on croit la version
// maîtrisée là où elle flotte, et à jour là où elle est figée.
//
// Décision (REGISTRE v0.16, I16 = A) : tout épingler, ici, et nulle part ailleurs.
//   · toute fonction importe `createClient` de ce module, jamais d'esm.sh ni de npm: ;
//   · la montée de version est un geste daté : on change le nombre ci-dessous, on
//     redéploie tout (config.toml ou ce fichier → la CI redéploie l'ensemble), on
//     note la date ; le recompte mensuel de CLAUDE.md relit ce nombre ;
//   · le banc `src/tests/supabase-js-epingle.test.js` casse si un import contourne
//     ce module.
//
// Version : 2.114.0 — dernière 2.x publiée le 03/09/2026 (registre npm).
export { createClient } from 'npm:@supabase/supabase-js@2.114.0';
export type { SupabaseClient } from 'npm:@supabase/supabase-js@2.114.0';
