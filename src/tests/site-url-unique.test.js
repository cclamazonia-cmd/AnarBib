// ═══════════════════════════════════════════════════════════
// AnarBib — l'adresse du site de présentation a UN foyer de chaque côté (21/09/2026)
//
// anarbib.org est le domaine canonique ; .is et .org.br sont des routes de repli
// (REGISTRE OPS-10). Le 21/09, en relisant le guide d'accueil posé le 16/09, on a
// compté : « https://anarbib.org » écrit en dur à vingt-trois endroits du dépôt —
// dix locales, dix chaînes du mail d'acceptation, la page d'inscription, deux
// liens du mail d'inscription. Un changement de canonique aurait demandé de les
// retrouver tous, dans dix langues, un soir de crise.
//
// Désormais : src/lib/siteUrl.js (front, VITE_SITE_URL) et
// supabase/functions/_shared/core/site-url.ts (mails, SITE_BASE_URL). Les textes
// ne portent que des chemins. Ce test refuse que l'adresse revienne ailleurs.
//
// Ce qu'il ne voit pas, et c'est dit : l'adresse de l'APPLICATION
// (https://app.anarbib.org) a son propre foyer côté mails (APP_BASE_URL dans
// _shared/core/env.ts) mais reste écrite en dur à quelques endroits de
// `register` — autre item, non couvert ici.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const FOYERS = new Set(['src/lib/siteUrl.js', 'supabase/functions/_shared/core/site-url.ts']);
const EXT = /\.(jsx?|tsx?|json)$/;

function* fichiers(rel) {
  const abs = join(ROOT, rel);
  if (statSync(abs).isDirectory()) {
    for (const e of readdirSync(abs)) {
      if (e === 'node_modules' || e === 'tests') continue;
      yield* fichiers(`${rel}/${e}`);
    }
  } else if (EXT.test(rel) && !/\.test\.[jt]sx?$/.test(rel)) yield rel;
}

describe('adresse du site de présentation — un seul foyer par côté', () => {
  it('« https://anarbib.org » n\'est écrit que dans les deux foyers', () => {
    const ailleurs = [];
    for (const racine of ['src', 'supabase/functions']) {
      for (const f of fichiers(racine)) {
        if (FOYERS.has(f)) continue;
        const t = readFileSync(join(ROOT, f), 'utf8');
        // « https://anarbib.org » mais pas « https://app.anarbib.org » ni un autre sous-domaine.
        const n = (t.match(/https:\/\/anarbib\.org/g) || []).length;
        if (n) ailleurs.push(`${f} ×${n}`);
      }
    }
    expect(ailleurs, 'passer par siteUrl() — src/lib/siteUrl.js ou _shared/core/site-url.ts').toEqual([]);
  });

  it('les deux foyers ont le même défaut, sans barre finale', () => {
    const front = readFileSync(join(ROOT, 'src/lib/siteUrl.js'), 'utf8');
    const mails = readFileSync(join(ROOT, 'supabase/functions/_shared/core/site-url.ts'), 'utf8');
    expect(front).toContain("|| 'https://anarbib.org')");
    expect(mails).toContain('|| "https://anarbib.org")');
  });

  it('siteUrl() compose base + chemin, avec ou sans barre initiale', async () => {
    const { siteUrl, SITE_BASE_URL } = await import('@/lib/siteUrl');
    expect(SITE_BASE_URL).toBe('https://anarbib.org');
    expect(siteUrl('/fr/accueil/')).toBe('https://anarbib.org/fr/accueil/');
    expect(siteUrl('el/ypodochi/')).toBe('https://anarbib.org/el/ypodochi/');
  });
});
