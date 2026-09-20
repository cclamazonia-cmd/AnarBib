// ═══════════════════════════════════════════════════════════
// AnarBib — le front ne porte pas l'adresse du projet en dur (20/09/2026)
//
// `src/lib/supabase.js` résout l'adresse de l'API : `VITE_SUPABASE_URL`, ou
// l'origine de la page quand elle vaut 'auto' (pile auto-hébergée derrière
// Caddy). Mais quatorze fichiers écrivaient
// « https://uflwmikiyjfnikiphtcp.supabase.co » en toutes lettres pour fabriquer
// des URL de Storage — couvertures, photos d'autorités, règlements, recueils,
// thèmes. Conséquences, mesurées en câblant les routes de repli le 20/09 :
//   · sur une pile auto-hébergée, ces images et ces PDF pointent vers NOTRE
//     production, pas vers la sienne — un fonds local affiché depuis un serveur
//     brésilien, ou rien du tout s'il est coupé ;
//   · le résolveur 'auto' de la PR #28 ne servait donc qu'à moitié.
//
// Ce banc garde deux choses :
//   1. plus aucune adresse `*.supabase.co` en dur dans `src/` — liste fermée,
//      `src/lib/supabase.js` seul excepté (il y porte PROJECT_REF, une
//      identité, avec le commentaire qui dit de ne pas en faire une adresse) ;
//   2. `PROJECT_REF` ne sert à fabriquer aucune URL : c'est l'erreur qu'avait
//      `theme.js`, invisible au grep d'adresse puisqu'elle était interpolée.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const EXCEPTES = new Set(['src/lib/supabase.js']); // liste fermée : l'identité du projet, nommée et commentée

function* fichiers(p) {
  const abs = join(ROOT, p);
  const st = statSync(abs);
  if (st.isDirectory()) {
    if (/(^|[\\/])(node_modules|dist|tests)$/.test(p)) return;
    for (const e of readdirSync(abs)) yield* fichiers(join(p, e));
  } else if (/\.(jsx?|tsx?)$/.test(p)) yield p;
}

const ADRESSE_EN_DUR = /['"`]https?:\/\/[a-z0-9-]+\.supabase\.co/i;
const URL_DEPUIS_REF = /https?:\/\/\$\{\s*PROJECT_REF\s*\}/;

describe('adresse du projet — le front la demande au résolveur, il ne l’écrit pas', () => {
  const dures = [];
  const interpolees = [];
  for (const f of fichiers('src')) {
    const rel = relative(ROOT, join(ROOT, f)).replace(/\\/g, '/');
    const src = readFileSync(join(ROOT, f), 'utf8');
    src.split('\n').forEach((ligne) => {
      if (/^\s*(\/\/|\*)/.test(ligne)) return; // un commentaire n'appelle rien
      if (ADRESSE_EN_DUR.test(ligne) && !EXCEPTES.has(rel)) dures.push(`${rel} : ${ligne.trim().slice(0, 110)}`);
      if (URL_DEPUIS_REF.test(ligne)) interpolees.push(`${rel} : ${ligne.trim().slice(0, 110)}`);
    });
  }

  it('aucune adresse *.supabase.co en dur — passer par SUPABASE_URL', () => {
    expect(dures).toEqual([]);
  });

  it('PROJECT_REF ne fabrique aucune adresse', () => {
    expect(interpolees).toEqual([]);
  });

  it('la liste des fichiers exceptés reste celle-ci, et elle est commentée', () => {
    expect([...EXCEPTES]).toEqual(['src/lib/supabase.js']);
    const src = readFileSync(join(ROOT, 'src/lib/supabase.js'), 'utf8');
    expect(src).toMatch(/jamais une adresse/);
  });

});
