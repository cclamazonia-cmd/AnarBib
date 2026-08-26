import { describe, it, expect, vi, afterEach } from 'vitest';
import { thumbPathFor, coverUrl, coverThumbUrl, THUMB_MAX_W, THUMB_MAX_H } from '@/lib/coverThumbs';

// Pourquoi ce fichier. La convention de nommage du dérivé est écrite DEUX fois :
// ici (`thumbPathFor`, appliquée au dépôt d'une capa et à l'affichage de la
// grille) et dans `scripts/backfill-cover-thumbs.py` (`thumb_path_for`, appliquée
// à la reprise du stock). Une divergence entre les deux ne casserait rien de
// visible : elle produirait des vignettes rangées à un endroit que la grille ne
// regarde pas — des orphelins invisibles, et un catalogue qui retombe
// silencieusement sur les originaux pleine résolution. D'où ces cas, qui sont
// les mêmes des deux côtés.

afterEach(() => { vi.unstubAllEnvs(); });

describe('thumbPathFor — convention de nommage du dérivé', () => {
  it('suffixe le chemin complet', () => {
    expect(thumbPathFor('books/0000275/front.jpg')).toBe('books/0000275/front.jpg.thumb.jpg');
  });

  it('conserve l’extension d’origine dans le nom, quelle qu’elle soit', () => {
    expect(thumbPathFor('books/BTL-TL-000027/front.gif')).toBe('books/BTL-TL-000027/front.gif.thumb.jpg');
    expect(thumbPathFor('books/x/capa.webp')).toBe('books/x/capa.webp.thumb.jpg');
  });

  it('ne perd rien d’un nom à points multiples', () => {
    expect(thumbPathFor('books/x/1773-nom.avec.points.jpeg'))
      .toBe('books/x/1773-nom.avec.points.jpeg.thumb.jpg');
  });

  it('accepte un chemin sans extension', () => {
    expect(thumbPathFor('books/a.b/front')).toBe('books/a.b/front.thumb.jpg');
  });

  it('rend une chaîne vide pour une capa absente', () => {
    expect(thumbPathFor('')).toBe('');
    expect(thumbPathFor(null)).toBe('');
    expect(thumbPathFor(undefined)).toBe('');
  });

  it('est idempotent : le dérivé d’un dérivé reste le même chemin', () => {
    // Garde-fou pour la reprise, qui filtre sur ce suffixe pour ne pas
    // fabriquer des vignettes de vignettes.
    const t = thumbPathFor('books/x/front.jpg');
    expect(thumbPathFor(t)).toBe(t);
  });

  // ── La régression qui a motivé la règle actuelle ──────────────────────
  it('est INJECTIVE : deux originaux de même racine ne partagent pas leur dérivé', () => {
    // Cas réels du bucket au 26/08/2026. Une première version remplaçait
    // l'extension, si bien que `front.jpg` et `front.png` visaient le même
    // objet : le second écrasait le premier, et trois notices (00000251,
    // BTL-TL-001120, MLEG-0001) affichaient la vignette d'un AUTRE fichier que
    // leur capa déclarée. Même famille de bug que la collision `books/new/`
    // corrigée en P1 (spec-module-capas §3.1).
    const paires = [
      ['books/00000251/front.jpg', 'books/00000251/front.png'],
      ['books/BTL-TL-001120/front.jpg', 'books/BTL-TL-001120/front.png'],
      ['books/535/front.jpg', 'books/535/front.webp'],
      ['books/0000279/front.jpeg', 'books/0000279/front.jpg'],
    ];
    for (const [a, b] of paires) {
      expect(thumbPathFor(a)).not.toBe(thumbPathFor(b));
    }
  });
});

describe('URLs publiques', () => {
  it('vise object/public, jamais render/image', () => {
    vi.stubEnv('VITE_SUPABASE_URL', 'https://exemple.test');
    const url = coverThumbUrl('books/0000275/front.jpg');
    expect(url).toBe('https://exemple.test/storage/v1/object/public/covers/books/0000275/front.jpg.thumb.jpg');
    expect(url).not.toContain('render/image');
  });

  it('coverUrl sert l’original, utilisé comme repli par la grille', () => {
    vi.stubEnv('VITE_SUPABASE_URL', 'https://exemple.test');
    expect(coverUrl('books/0000275/front.jpg'))
      .toBe('https://exemple.test/storage/v1/object/public/covers/books/0000275/front.jpg');
  });

  it('rend une chaîne vide sans capa (pas d’URL bancale)', () => {
    vi.stubEnv('VITE_SUPABASE_URL', 'https://exemple.test');
    expect(coverUrl('')).toBe('');
    expect(coverThumbUrl(null)).toBe('');
  });
});

describe('boîte du dérivé', () => {
  it('garde le ratio 2:3 d’une couverture', () => {
    expect(THUMB_MAX_H / THUMB_MAX_W).toBe(1.5);
  });

  it('couvre l’affichage 30×44 px de la grille jusqu’à 4× de densité', () => {
    expect(THUMB_MAX_W).toBeGreaterThanOrEqual(30 * 4);
    expect(THUMB_MAX_H).toBeGreaterThanOrEqual(44 * 4);
  });
});
