// @vitest-environment node
/**
 * Métadonnées retirées des capas au dépôt (14/10/2026).
 *
 * Le module partagé `_shared/capas/metadonnees.ts` est la seule logique de
 * nettoyage : `cover_lookup` l'appelle côté serveur, le formulaire de
 * catalogage côté navigateur (src/lib/imageMetadata.js). Il a été vérifié
 * octet pour octet contre scripts/strip-cover-metadata.py sur les 898 objets
 * du bucket `covers` ; ces cas en gardent les comportements.
 *
 * Fixtures : images 8×6 produites par Pillow, porteuses de métadonnées.
 */
import { describe, it, expect } from 'vitest';
import { retirerMetadonnees, formatImage } from '../../supabase/functions/_shared/capas/metadonnees.ts';
import { fichierSansMetadonnees } from '@/lib/imageMetadata';

const b64 = (s) => new Uint8Array(Buffer.from(s, 'base64'));
const contient = (octets, texte) => Buffer.from(octets).includes(Buffer.from(texte, 'latin1'));

// EXIF (appareil « Canon », GPS, orientation 6) + commentaire « secret ».
const JPEG_EXIF = b64('/9j/4AAQSkZJRgABAQAAAQABAAD/4QB2RXhpZgAATU0AKgAAAAgAAwEPAAIAAAAGAAAAMgESAAMAAAABAAYAAIglAAQAAAABAAAAOAAAAABDYW5vbgAAAgABAAIAAAACUwAAAAACAAUAAAADAAAAVgAAAAAAAAABAAAAAQAAAAIAAAABAAAAAwAAAAH//gAIc2VjcmV0/9sAQwAGBAUGBQQGBgUGBwcGCAoQCgoJCQoUDg8MEBcUGBgXFBYWGh0lHxobIxwWFiAsICMmJykqKRkfLTAtKDAlKCko/9sAQwEHBwcKCAoTCgoTKBoWGigoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgo/8AAEQgABgAIAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/aAAwDAQACEQMRAD8A4Ciiivnj9hP/2Q==');
const JPEG_PROPRE = b64('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAAGAAgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDgKKKK+eP2E//Z');
// tEXt « Author: moi ».
const PNG_TEXTE = b64('iVBORw0KGgoAAAANSUhEUgAAAAgAAAAGCAIAAABxZ0isAAAACnRFWHRBdXRob3IAbW9pQe3liQAAABRJREFUeJxjPCEnx4ANMGEVpZMEAJsUARAoioAAAAAAAElFTkSuQmCC');
// EXIF « Canon » + XMP.
const WEBP_EXIF = b64('UklGRogAAABXRUJQVlA4WAoAAAAMAAAABwAABQAAVlA4IC4AAACwAQCdASoIAAYAAUAmJaACdLoABDAAAP7x3I/4DdfFtMv/vYL/3YL/3YL/WwAARVhJRiAAAABNTQAqAAAACAABAQ8AAgAAAAYAAAAaAAAAAENhbm9uAFhNUCAMAAAAPHg6eG1wbWV0YS8+');
// Extension de commentaire « secret ».
const GIF_COMM = b64('R0lGODlhCAAGAIEAAJkAAMwAAMwzMwAAACH+BnNlY3JldAAsAAAAAAgABgAACBcABQQQSHDgQIIFExoUgHAhAIUMDwYICAA7');

describe('retirerMetadonnees', () => {
  it('JPEG : retire EXIF (appareil, GPS) et commentaire, garde la seule orientation', () => {
    const { octets, retires, format } = retirerMetadonnees(JPEG_EXIF);
    expect(format).toBe('JPEG');
    expect(retires).toEqual(['EXIF', 'commentaire JPEG']);
    expect(contient(octets, 'Canon')).toBe(false);
    expect(contient(octets, 'secret')).toBe(false);
    // EXIF minimal : un seul champ, 0x0112 = 6, juste après l'APP0 JFIF.
    const app1 = Buffer.from(octets).indexOf(Buffer.from([0xff, 0xe1]));
    expect(app1).toBe(20);
    expect(octets.length).toBeLessThan(JPEG_EXIF.length);
    expect(Buffer.from(octets.subarray(app1 + 4, app1 + 10)).toString('latin1')).toBe('Exif\0\0');
    expect([...octets.subarray(app1 + 18, app1 + 20)]).toEqual([0, 1]);        // 1 entrée
    expect([...octets.subarray(app1 + 20, app1 + 22)]).toEqual([0x01, 0x12]);  // Orientation
    expect(octets[app1 + 29]).toBe(6);
    // Les données d'image sont recopiées telles quelles (pas de recompression).
    const sos = (b) => Buffer.from(b).subarray(Buffer.from(b).indexOf(Buffer.from([0xff, 0xda])));
    expect(sos(octets).equals(sos(JPEG_EXIF))).toBe(true);
  });

  it('JPEG sans métadonnée : rendu tel quel (même objet)', () => {
    const r = retirerMetadonnees(JPEG_PROPRE);
    expect(r.retires).toEqual([]);
    expect(r.octets).toBe(JPEG_PROPRE);
  });

  it('PNG : retire le texte, garde IHDR/IDAT/IEND', () => {
    const { octets, retires } = retirerMetadonnees(PNG_TEXTE);
    expect(retires).toEqual(['texte PNG « Author »']);
    expect(contient(octets, 'moi')).toBe(false);
    expect(contient(octets, 'IDAT') && contient(octets, 'IEND')).toBe(true);
  });

  it('WebP : retire EXIF et XMP, baisse les drapeaux VP8X, recalcule la taille RIFF', () => {
    const { octets, retires } = retirerMetadonnees(WEBP_EXIF);
    expect(retires).toEqual(['EXIF', 'XMP']);
    expect(contient(octets, 'Canon')).toBe(false);
    expect(octets[20] & 0x0c).toBe(0);
    expect(Buffer.from(octets).readUInt32LE(4)).toBe(octets.length - 8);
  });

  it('GIF : retire le commentaire', () => {
    const { octets, retires } = retirerMetadonnees(GIF_COMM);
    expect(retires).toEqual(['commentaire GIF']);
    expect(contient(octets, 'secret')).toBe(false);
    expect(octets[octets.length - 1]).toBe(0x3b);
  });

  it('format inconnu ou fichier tronqué : rendu tel quel, sans lever', () => {
    const avif = new Uint8Array([0, 0, 0, 0x20, ...Buffer.from('ftypavif')]);
    expect(formatImage(avif)).toBe('AVIF');
    expect(retirerMetadonnees(avif).octets).toBe(avif);
    const tronque = JPEG_EXIF.subarray(0, 40);
    const r = retirerMetadonnees(tronque);
    expect(r.octets).toBe(tronque);
    expect(r.erreur).toBeTruthy();
  });
});

describe('fichierSansMetadonnees', () => {
  it('rend un File nettoyé, même nom et même type', async () => {
    const f = new File([JPEG_EXIF], 'capa.jpg', { type: 'image/jpeg' });
    const p = await fichierSansMetadonnees(f);
    expect(p).not.toBe(f);
    expect(p.name).toBe('capa.jpg');
    expect(p.type).toBe('image/jpeg');
    expect(contient(new Uint8Array(await p.arrayBuffer()), 'Canon')).toBe(false);
  });

  it('rend le fichier d\'origine quand il est déjà propre', async () => {
    const f = new File([JPEG_PROPRE], 'capa.jpg', { type: 'image/jpeg' });
    expect(await fichierSansMetadonnees(f)).toBe(f);
  });
});
