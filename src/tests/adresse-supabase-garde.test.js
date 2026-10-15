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

import { describe, it, expect, vi, afterEach } from 'vitest';
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

// ── 15/10/2026, ticket #36 du camarade (carte toute blanche) ─────────────────
// Troisième voie, invisible aux deux gardes ci-dessus : relire la variable
// BRUTE. `mapTiles.js` et `coverThumbs.js` lisaient `VITE_SUPABASE_URL` en
// direct pour rester testables ; sur une pile auto-hébergée elle vaut 'auto',
// d'où `auto/storage/v1/object/public/map-tiles/…` — Caddy rendait index.html,
// Protomaps ne lisait rien. Une seule lecture permise : le résolveur sans effet
// de bord, `src/lib/supabaseUrl.js`.
const LECTEURS_PERMIS = ['src/lib/supabaseUrl.js'];
const LECTURE_BRUTE = /import\.meta\.env\.VITE_SUPABASE_URL\b/;

describe('VITE_SUPABASE_URL — une seule lecture, par le résolveur', () => {
  it('liste fermée des fichiers qui lisent la variable brute', () => {
    const lecteurs = new Set();
    for (const f of fichiers('src')) {
      const rel = relative(ROOT, join(ROOT, f)).replace(/\\/g, '/');
      const src = readFileSync(join(ROOT, f), 'utf8');
      src.split('\n').forEach((ligne) => {
        if (/^\s*(\/\/|\*)/.test(ligne)) return;
        if (LECTURE_BRUTE.test(ligne)) lecteurs.add(rel);
      });
    }
    expect([...lecteurs].sort()).toEqual(LECTEURS_PERMIS);
  });

  describe("sous 'auto', les adresses partent de l'origine de la page", () => {
    afterEach(() => { vi.unstubAllEnvs(); vi.resetModules(); });

    it('fond de carte : MAPTILES_URL', async () => {
      vi.stubEnv('VITE_SUPABASE_URL', 'auto');
      vi.stubEnv('VITE_MAPTILES_URL', '');
      vi.resetModules();
      const { MAPTILES_URL } = await import('@/lib/mapTiles');
      expect(MAPTILES_URL).toBe(`${window.location.origin}/storage/v1/object/public/map-tiles/planet-z13.pmtiles`);
      expect(MAPTILES_URL).not.toMatch(/^auto\//);
    });

    it('couvertures : coverUrl et coverThumbUrl', async () => {
      vi.stubEnv('VITE_SUPABASE_URL', 'auto');
      const { coverUrl, coverThumbUrl } = await import('@/lib/coverThumbs');
      const base = `${window.location.origin}/storage/v1/object/public/covers/`;
      expect(coverUrl('books/x/front.jpg')).toBe(`${base}books/x/front.jpg`);
      expect(coverThumbUrl('books/x/front.jpg')).toBe(`${base}books/x/front.jpg.thumb.jpg`);
    });

    it('une adresse explicite reste respectée telle quelle', async () => {
      vi.stubEnv('VITE_SUPABASE_URL', 'https://exemple.test');
      const { resolveSupabaseUrl } = await import('@/lib/supabaseUrl');
      expect(resolveSupabaseUrl()).toBe('https://exemple.test');
    });
  });
});
