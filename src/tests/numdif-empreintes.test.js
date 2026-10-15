// =====================================================================
// NUMDIF D16 (15/10/2026) — les empreintes incrémentales du versement
// (supabase/functions/deposit-digital-candidate/empreintes.ts) donnent les
// mêmes SHA-256 et SHA-1 que node:crypto, quel que soit le découpage du flux.
// Depuis le 16/10 elles SONT node:crypto (natives : le JS pur dépassait les 2 s
// de CPU d'un appel au-delà de ~45 Mo) ; ce test garde l'interface (update
// enchaînable, hex), l'algorithme de chaque classe (vecteurs connus) et le
// découpage. L'égalité dans l'Edge Runtime lui-même a été mesurée au banc
// (image edge-runtime, voir l'en-tête de empreintes.ts).
// Session : File de candidats PDF.
// =====================================================================
import { describe, it, expect } from 'vitest';
import { createHash, randomBytes } from 'node:crypto';
import { Sha256, Sha1 } from '../../supabase/functions/deposit-digital-candidate/empreintes.ts';

const reference = (alg, buf) => createHash(alg).update(buf).digest('hex');
const enMorceaux = (H, buf, tailles) => {
  const h = new H();
  let i = 0, k = 0;
  while (i < buf.length) { const n = tailles[k++ % tailles.length]; h.update(buf.subarray(i, i + n)); i += n; }
  return h.hex();
};

describe('empreintes incrémentales', () => {
  it('les vecteurs connus (vide, « abc »)', () => {
    expect(new Sha256().hex()).toBe('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(new Sha256().update(new TextEncoder().encode('abc')).hex()).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(new Sha1().update(new TextEncoder().encode('abc')).hex()).toBe('a9993e364706816aba3e25717850c26c9cd0d89d');
  });

  it('toutes les tailles autour des frontières de bloc (0 à 200 octets)', () => {
    for (let n = 0; n <= 200; n++) {
      const buf = randomBytes(n);
      expect(new Sha256().update(buf).hex(), `sha256 n=${n}`).toBe(reference('sha256', buf));
      expect(new Sha1().update(buf).hex(), `sha1 n=${n}`).toBe(reference('sha1', buf));
    }
  });

  it('un flux de 3 Mo découpé n’importe comment donne la même empreinte', () => {
    const buf = randomBytes(3 * 1024 * 1024 + 17);
    for (const tailles of [[1, 63, 64, 65], [65536], [7, 4096, 13, 100000]]) {
      expect(enMorceaux(Sha256, buf, tailles)).toBe(reference('sha256', buf));
      expect(enMorceaux(Sha1, buf, tailles)).toBe(reference('sha1', buf));
    }
  });
});
