// ═══════════════════════════════════════════════════════════
// AnarBib — fond de carte d'une instance auto-hébergée (16/10/2026)
//
// Ticket #36 du camarade (ASR2026), point 2 : une instance neuve n'a pas de fond
// de carte. Décision de Xavier (15/10) : chaque instance extrait le sien depuis
// le planet Protomaps, au zoom qu'elle peut porter — jamais de relais vers la
// production. Deux pièges que ce banc garde :
//   1. un extrait plus léger (z11) avec `maxDataZoom` figé à 13 donnerait une
//      carte VIDE aux zooms 12-13 : le front lit le zoom dans l'en-tête du
//      fichier (lireZoomMaxCarte), sans jamais lire un corps non borné ;
//   2. scripts/maptiles/televerser-tus.mjs vise la PRODUCTION par défaut :
//      deploy/scripts/fond-de-carte.sh lui passe l'adresse et la clé de
//      l'instance (deploy/.env), refuse un .env qui vise un projet hébergé, et
//      pose VITE_MAPTILES_URL quand le zoom n'est pas celui de la production.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { lireZoomMaxCarte, MAPTILES_MAX_DATA_ZOOM } from '@/lib/mapTiles';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const lire = (p) => readFileSync(join(ROOT, p), 'utf8');

// En-tête PMTiles v3 de 127 octets : magie, version, puis zooms min (100) et max (101).
function entete({ magie = 'PMTiles', version = 3, zmax = 11 } = {}) {
  const b = new Uint8Array(127);
  for (let i = 0; i < 7; i += 1) b[i] = magie.charCodeAt(i);
  b[7] = version;
  b[100] = 0;
  b[101] = zmax;
  return b;
}
const reponse = (status, octets) => ({ status, arrayBuffer: vi.fn(async () => octets.buffer) });

describe('lireZoomMaxCarte — le zoom vient du fichier, pas d’une constante', () => {
  it('lit le zoom maximal d’un extrait z11 et ne demande que l’en-tête', async () => {
    const fetcher = vi.fn(async () => reponse(206, entete({ zmax: 11 })));
    expect(await lireZoomMaxCarte('/storage/v1/object/public/map-tiles/planet-z11.pmtiles', fetcher)).toBe(11);
    const [, init] = fetcher.mock.calls[0];
    expect(init.headers.Range).toBe('bytes=0-126');
    expect(init.cache).toBe('no-store');
  });

  it('le fichier de la production (z13) donne 13', async () => {
    expect(await lireZoomMaxCarte('x', async () => reponse(206, entete({ zmax: 13 })))).toBe(13);
  });

  it('une réponse 200 (fichier ENTIER annoncé) est abandonnée sans lire le corps', async () => {
    const r = reponse(200, entete({ zmax: 9 }));
    expect(await lireZoomMaxCarte('x', async () => r)).toBe(MAPTILES_MAX_DATA_ZOOM);
    expect(r.arrayBuffer).not.toHaveBeenCalled();
  });

  it('autre chose qu’un PMTiles v3 (index.html, v2), une erreur réseau : repli 13', async () => {
    expect(await lireZoomMaxCarte('x', async () => reponse(206, entete({ magie: '<!doctyp' })))).toBe(MAPTILES_MAX_DATA_ZOOM);
    expect(await lireZoomMaxCarte('x', async () => reponse(206, entete({ version: 2 })))).toBe(MAPTILES_MAX_DATA_ZOOM);
    expect(await lireZoomMaxCarte('x', async () => { throw new Error('réseau'); })).toBe(MAPTILES_MAX_DATA_ZOOM);
    expect(await lireZoomMaxCarte('x', null)).toBe(MAPTILES_MAX_DATA_ZOOM);
  });

  it('addBasemap passe le zoom lu au greffon, plus la constante', () => {
    const src = lire('src/lib/mapTiles.js');
    expect(src).toMatch(/const maxDataZoom = await lireZoomMaxCarte\(\)/);
    expect(src).not.toMatch(/maxDataZoom:\s*MAPTILES_MAX_DATA_ZOOM/);
  });
});

describe('deploy/scripts/fond-de-carte.sh — vise l’instance, jamais la production', () => {
  const s = lire('deploy/scripts/fond-de-carte.sh');

  it('adresse et clé de l’instance, passées à la recette du projet', () => {
    expect(s).toMatch(/lire_env API_EXTERNAL_URL/);
    expect(s).toMatch(/lire_env SERVICE_ROLE_KEY/);
    expect(s).toMatch(/VITE_SUPABASE_URL="\$API" SUPABASE_SECRET_KEY="\$CLE"[^\n]*\\\n\s*bash "\$RACINE\/scripts\/maptiles\/extraire-planet\.sh" --extraire --televerser/);
  });

  it('refuse un deploy/.env qui vise un projet hébergé', () => {
    expect(s).toMatch(/\*supabase\.co\*\)/);
  });

  it('mesure par défaut, zoom borné à 13, contrôle 206 + zoom de l’en-tête', () => {
    expect(s).toMatch(/^EXTRAIRE=0$/m);
    expect(s).toMatch(/8\|9\|10\|11\|12\|13\)/);
    expect(s).toMatch(/-r 0-126/);
    expect(s).toMatch(/"\$CODE" != "206"/);
  });

  it('un zoom autre que 13 pose VITE_MAPTILES_URL et reconstruit le front', () => {
    expect(s).toMatch(/VITE_MAPTILES_URL=\/storage\/v1\/object\/public\/map-tiles\/\$OBJET/);
    expect(s).toMatch(/deploy\.sh" --front/);
  });
});
