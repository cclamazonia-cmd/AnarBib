// ═══════════════════════════════════════════════════════════
// AnarBib — miroir d'images de la pile auto-hébergée (19/10/2026)
//
// Les six images de deploy/compose.yml viennent de Docker Hub. Pour ne plus en
// dépendre, une instance peut les tirer d'un registre miroir (zot mutualisé
// avec AnarcosyndicalismeBOOK) : IMAGE_PREFIX, vide par défaut, précède le nom
// de chaque image. Ce banc garde trois choses :
//   1. TOUTES les images du compose portent le préfixe : un service ajouté
//      sans lui échapperait au miroir sans que personne ne le voie ;
//   2. la variable existe, VIDE, dans .env.example : par défaut rien ne change ;
//   3. Caddy est écrit `library/caddy` (nom complet de l'image officielle
//      `caddy`, le seul chemin qu'un miroir connaisse), et le README l'explique.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const lire = (p) => readFileSync(join(ROOT, p), 'utf8');

const compose = lire('deploy/compose.yml');
const images = [...compose.matchAll(/^\s*image:\s*(\S+)\s*$/gm)].map((m) => m[1]);

describe('miroir d’images — deploy/compose.yml', () => {
  it('déclare les six images de la pile', () => {
    expect(images).toHaveLength(6);
  });

  it('chaque image commence par ${IMAGE_PREFIX:-}', () => {
    const sansPrefixe = images.filter((i) => !i.startsWith('${IMAGE_PREFIX:-}'));
    expect(sansPrefixe).toEqual([]);
  });

  it('chaque image garde sa version épinglée par une variable *_TAG', () => {
    for (const i of images) expect(i).toMatch(/:\$\{[A-Z_]+_TAG\}$/);
  });

  it('Caddy est écrit library/caddy, le chemin que connaît un miroir', () => {
    expect(images).toContain('${IMAGE_PREFIX:-}library/caddy:${CADDY_TAG}');
  });
});

describe('miroir d’images — réglage et documentation', () => {
  it('.env.example déclare IMAGE_PREFIX vide (Docker Hub par défaut)', () => {
    expect(lire('deploy/.env.example')).toMatch(/^IMAGE_PREFIX=$/m);
  });

  it('le README explique le réglage, le « / » final et library/caddy', () => {
    const readme = lire('deploy/README.md');
    expect(readme).toContain('### Miroir d\'images (facultatif)');
    expect(readme).toContain('IMAGE_PREFIX=registre.exemple.org/miroir/docker.io/');
    expect(readme).toContain('library/caddy');
  });
});
