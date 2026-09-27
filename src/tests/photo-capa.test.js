// La photo d'une couverture, préparée dans le navigateur (lib/photoCapa.js, 27/09/2026).
// Ce qui se calcule sans toile : les dimensions (réduites, jamais agrandies,
// échangées par un quart de tour) et le chemin (dossier de la notice, nom neuf).
import { describe, it, expect } from 'vitest';
import { cheminPhoto, dimensionsPhoto, PHOTO_MAX_COTE } from '@/lib/photoCapa';

describe('dimensionsPhoto', () => {
  it('une photo de téléphone (4 000 × 3 000) : le grand côté ramené à 1 600', () => {
    expect(PHOTO_MAX_COTE).toBe(1600);
    expect(dimensionsPhoto(4000, 3000)).toEqual({ dessinL: 1600, dessinH: 1200, toileL: 1600, toileH: 1200 });
    expect(dimensionsPhoto(3000, 4000)).toEqual({ dessinL: 1200, dessinH: 1600, toileL: 1200, toileH: 1600 });
  });

  it('une petite image n’est jamais agrandie', () => {
    expect(dimensionsPhoto(640, 960)).toEqual({ dessinL: 640, dessinH: 960, toileL: 640, toileH: 960 });
  });

  it('un quart de tour (dans un sens ou dans l’autre) couche la toile ; un demi-tour non', () => {
    expect(dimensionsPhoto(4000, 3000, 1)).toMatchObject({ toileL: 1200, toileH: 1600 });
    expect(dimensionsPhoto(4000, 3000, -1)).toMatchObject({ toileL: 1200, toileH: 1600 });
    expect(dimensionsPhoto(4000, 3000, 3)).toMatchObject({ toileL: 1200, toileH: 1600 });
    expect(dimensionsPhoto(4000, 3000, 2)).toMatchObject({ toileL: 1600, toileH: 1200 });
  });

  it('des dimensions absurdes ne font pas une toile vide', () => {
    expect(dimensionsPhoto(0, 0)).toEqual({ dessinL: 1, dessinH: 1, toileL: 1, toileH: 1 });
  });
});

describe('cheminPhoto', () => {
  it('le dossier de la notice (clé nettoyée comme par cover_lookup), un nom neuf en base 36', () => {
    expect(cheminPhoto('BTL-TL-000447', 1790531773827)).toBe(`books/BTL-TL-000447/photo-${(1790531773827).toString(36)}.jpg`);
    expect(cheminPhoto('CCLA 2023/107', 36)).toBe('books/CCLA_2023_107/photo-10.jpg');
  });

  it('le nom respecte la forme que la RPC exige (photo-[a-z0-9]{1,20}.jpg)', () => {
    expect(cheminPhoto('X', Date.now())).toMatch(/^books\/X\/photo-[a-z0-9]{1,20}\.jpg$/);
  });

  it('sans clé, pas de chemin', () => {
    expect(cheminPhoto('')).toBe('');
    expect(cheminPhoto(null)).toBe('');
  });
});
