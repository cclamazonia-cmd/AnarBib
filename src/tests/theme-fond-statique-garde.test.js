// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/theme-fond-statique-garde.test.js
//
// L'image de fond du thème par défaut (la photographie d'archive aux drapeaux noirs)
// est servie comme asset statique de l'application (`public/img/bg-anarbib.webp`),
// exactement comme le logo (`public/img/logo-anarbib.png`) et les polices
// (`public/fonts/`).
//
// POURQUOI CETTE GARDE.
// Le 20/09/2026 (commit 6cf45ef4), les URL vers la production Supabase en dur
// ont été retirées au profit de SUPABASE_URL (résolvant 'auto' en auto-hébergé).
// En l'absence de l'image dans le dépôt, une instance locale neuve (dont le bucket
// de stockage démarre vide) subissait une 404 sur le manifest et retombait sur
// `--brand-bg-image: none`, produisant un fond noir total.
//
// Cette garde vérifie deux choses :
//   1. `public/img/bg-anarbib.webp` existe et pèse au moins 50 Ko ;
//   2. `src/styles/theme-base.css` initialise `--brand-bg-image` sur cette image
//      locale (`url("/img/bg-anarbib.webp")`), garantissant un affichage immédiat
//      sans flash noir, sans dépendance réseau et sans prérequis de stockage.

import { describe, it, expect } from 'vitest';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

describe('fond de page par défaut — servi en statique sans dépendance Storage', () => {
  it('public/img/bg-anarbib.webp est présent dans le dépôt et non vide', () => {
    const bgPath = join(ROOT, 'public', 'img', 'bg-anarbib.webp');
    expect(existsSync(bgPath)).toBe(true);
    const stats = statSync(bgPath);
    expect(stats.size).toBeGreaterThan(50 * 1024); // ≈ 193 Ko
  });

  it('src/styles/theme-base.css référence /img/bg-anarbib.webp comme valeur par défaut', () => {
    const cssPath = join(ROOT, 'src', 'styles', 'theme-base.css');
    const css = readFileSync(cssPath, 'utf8');
    expect(css).toMatch(/--brand-bg-image:\s*url\(["']?\/img\/bg-anarbib\.webp["']?\);/);
  });
});
