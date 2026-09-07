// Garde E5 (07/09/2026) : les pages de carte ne chargent plus rien depuis un domaine
// tiers. Avant ce jour, trois composants tiraient leurs tuiles de tile.openstreetmap.org,
// ce qui livrait l'adresse IP de chaque visiteuse à un tiers (INV-5). Le fond est
// désormais un fichier PMTiles servi par nous (src/lib/mapTiles.js).
//
// Deux contrôles :
//   1. aucun fichier de src/ ne cite tile.openstreetmap.org ;
//   2. tout fichier qui crée une carte Leaflet (`L.map(`) passe par addBasemap.
// Le lien « Voir sur la carte » de la fiche publique (BibliotecaPublicaPage) n'est
// pas concerné : il navigue vers openstreetmap.org sur un clic explicite (PUBLIB-O1).
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { basemapLang, MAPTILES_MAX_DATA_ZOOM, MAPTILES_MAX_ZOOM } from '@/lib/mapTiles';

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.(jsx?|tsx?)$/.test(name)) out.push(p);
  }
  return out;
}

const SRC = join(process.cwd(), 'src');
const files = walk(SRC).filter((p) => !p.includes(`${join('src', 'tests')}`));

describe('cartes sans domaine tiers (E5)', () => {
  it('aucun fichier de src/ ne cite tile.openstreetmap.org', () => {
    const fautifs = files.filter((p) => readFileSync(p, 'utf8').includes('tile.openstreetmap.org'));
    expect(fautifs).toEqual([]);
  });

  it('toute carte Leaflet passe par addBasemap (src/lib/mapTiles.js)', () => {
    const cartes = files.filter((p) => /\bL\.map\(/.test(readFileSync(p, 'utf8')));
    expect(cartes.length).toBeGreaterThanOrEqual(3);
    const sansFond = cartes.filter((p) => {
      const src = readFileSync(p, 'utf8');
      return !(src.includes("from '@/lib/mapTiles'") && src.includes('addBasemap('));
    });
    expect(sansFond).toEqual([]);
  });

  it('aucune carte ne crée de L.tileLayer (raster distant)', () => {
    const fautifs = files.filter((p) => /\bL\.tileLayer\(/.test(readFileSync(p, 'utf8')));
    expect(fautifs).toEqual([]);
  });

  it('langue des étiquettes : présentes dans le fond, sinon noms locaux', () => {
    expect(basemapLang('fr')).toBe('fr');
    expect(basemapLang('pt-BR')).toBe('pt');
    expect(basemapLang('el')).toBe('el');
    expect(basemapLang('ca')).toBeUndefined();
    expect(basemapLang('eo')).toBeUndefined();
    expect(basemapLang('')).toBeUndefined();
    expect(MAPTILES_MAX_DATA_ZOOM).toBeLessThanOrEqual(MAPTILES_MAX_ZOOM);
  });
});
