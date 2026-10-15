// Empreintes SHA-256 et SHA-1 INCRÉMENTALES (NUMDIF D16, 15/10/2026).
// Session : File de candidats PDF.
//
// Pourquoi ici et pas crypto.subtle : crypto.subtle.digest veut tout le fichier
// d'un bloc. Le versement passe le PDF en flux, de la source au stockage, sans
// le tenir en mémoire (jusqu'à 500 Mo, la limite des seaux) : l'empreinte se
// calcule morceau par morceau, au passage. SHA-1 parce qu'une source MediaWiki
// (Anarchief, Wikisource) ne donne que lui : on le compare, et le SHA-256 se
// calcule au même premier téléchargement.
// Vérifié contre node:crypto par src/tests/numdif-empreintes.test.js.

const K256 = new Uint32Array([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

abstract class Bloc64 {
  protected tampon = new Uint8Array(64);
  protected rempli = 0;
  protected octets = 0;
  protected abstract compresser(bloc: Uint8Array, debut: number): void;
  protected abstract etat(): Uint32Array;

  update(donnees: Uint8Array): this {
    let i = 0;
    this.octets += donnees.length;
    if (this.rempli > 0) {
      const n = Math.min(64 - this.rempli, donnees.length);
      this.tampon.set(donnees.subarray(0, n), this.rempli);
      this.rempli += n; i = n;
      if (this.rempli < 64) return this;
      this.compresser(this.tampon, 0);
      this.rempli = 0;
    }
    for (; i + 64 <= donnees.length; i += 64) this.compresser(donnees, i);
    if (i < donnees.length) { this.tampon.set(donnees.subarray(i), 0); this.rempli = donnees.length - i; }
    return this;
  }

  hex(): string {
    const bits = this.octets * 8;
    const fin = new Uint8Array(((this.rempli + 9 + 63) >> 6) << 6);
    fin.set(this.tampon.subarray(0, this.rempli));
    fin[this.rempli] = 0x80;
    const dv = new DataView(fin.buffer);
    dv.setUint32(fin.length - 8, Math.floor(bits / 0x100000000));
    dv.setUint32(fin.length - 4, bits >>> 0);
    for (let i = 0; i < fin.length; i += 64) this.compresser(fin, i);
    return [...this.etat()].map((x) => x.toString(16).padStart(8, '0')).join('');
  }
}

export class Sha256 extends Bloc64 {
  private h = Uint32Array.of(0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19);
  private w = new Uint32Array(64);
  protected etat() { return this.h; }
  protected compresser(b: Uint8Array, d: number) {
    const w = this.w;
    for (let t = 0; t < 16; t++) w[t] = (b[d + 4 * t] << 24) | (b[d + 4 * t + 1] << 16) | (b[d + 4 * t + 2] << 8) | b[d + 4 * t + 3];
    for (let t = 16; t < 64; t++) {
      const x = w[t - 15], y = w[t - 2];
      const s0 = ((x >>> 7) | (x << 25)) ^ ((x >>> 18) | (x << 14)) ^ (x >>> 3);
      const s1 = ((y >>> 17) | (y << 15)) ^ ((y >>> 19) | (y << 13)) ^ (y >>> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) | 0;
    }
    let [a, bb, c, dd, e, f, g, h] = this.h;
    for (let t = 0; t < 64; t++) {
      const S1 = ((e >>> 6) | (e << 26)) ^ ((e >>> 11) | (e << 21)) ^ ((e >>> 25) | (e << 7));
      const ch = (e & f) ^ (~e & g);
      const t1 = (h + S1 + ch + K256[t] + w[t]) | 0;
      const S0 = ((a >>> 2) | (a << 30)) ^ ((a >>> 13) | (a << 19)) ^ ((a >>> 22) | (a << 10));
      const maj = (a & bb) ^ (a & c) ^ (bb & c);
      const t2 = (S0 + maj) | 0;
      h = g; g = f; f = e; e = (dd + t1) | 0; dd = c; c = bb; bb = a; a = (t1 + t2) | 0;
    }
    const H = this.h;
    H[0] = (H[0] + a) | 0; H[1] = (H[1] + bb) | 0; H[2] = (H[2] + c) | 0; H[3] = (H[3] + dd) | 0;
    H[4] = (H[4] + e) | 0; H[5] = (H[5] + f) | 0; H[6] = (H[6] + g) | 0; H[7] = (H[7] + h) | 0;
  }
}

export class Sha1 extends Bloc64 {
  private h = Uint32Array.of(0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0);
  private w = new Uint32Array(80);
  protected etat() { return this.h; }
  protected compresser(b: Uint8Array, d: number) {
    const w = this.w;
    for (let t = 0; t < 16; t++) w[t] = (b[d + 4 * t] << 24) | (b[d + 4 * t + 1] << 16) | (b[d + 4 * t + 2] << 8) | b[d + 4 * t + 3];
    for (let t = 16; t < 80; t++) { const x = w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16]; w[t] = (x << 1) | (x >>> 31); }
    let [a, bb, c, dd, e] = this.h;
    for (let t = 0; t < 80; t++) {
      let f: number, k: number;
      if (t < 20) { f = (bb & c) | (~bb & dd); k = 0x5a827999; }
      else if (t < 40) { f = bb ^ c ^ dd; k = 0x6ed9eba1; }
      else if (t < 60) { f = (bb & c) | (bb & dd) | (c & dd); k = 0x8f1bbcdc; }
      else { f = bb ^ c ^ dd; k = 0xca62c1d6; }
      const tmp = (((a << 5) | (a >>> 27)) + f + e + k + w[t]) | 0;
      e = dd; dd = c; c = (bb << 30) | (bb >>> 2); bb = a; a = tmp;
    }
    const H = this.h;
    H[0] = (H[0] + a) | 0; H[1] = (H[1] + bb) | 0; H[2] = (H[2] + c) | 0; H[3] = (H[3] + dd) | 0; H[4] = (H[4] + e) | 0;
  }
}
