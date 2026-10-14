// =============================================================================
//  metadonnees.ts — retire les metadonnees embarquees d'une image, sans perte
// =============================================================================
//  Session : Metadonnees des capas
//
//  Une capa deposee dans le bucket PUBLIC `covers` n'a besoin que de ses
//  pixels. Ce module retire ce qui parle de la personne ou de l'appareil :
//  EXIF (appareil, date, coordonnees GPS), XMP, IPTC/Photoshop, commentaires,
//  JUMBF/C2PA, images secondaires MPF, texte PNG (tEXt/zTXt/iTXt), tIME…
//
//  SANS RECOMPRESSION : on retire des segments, on ne touche pas aux donnees
//  d'image. Est garde ce qui change le rendu sans rien dire de personne : le
//  profil ICC, le segment Adobe APP14, l'en-tete JFIF (sans sa miniature), les
//  blocs de rendu PNG et l'animation (APNG, WebP, boucle GIF), et l'ORIENTATION
//  EXIF quand elle n'est pas 1, reecrite seule dans un EXIF minimal.
//
//  AVIF/HEIF : laisse tel quel (les metadonnees y sont des items localises par
//  `iloc` ; les retirer oblige a recalculer des decalages). Un format inconnu
//  ou un fichier mal forme est rendu TEL QUEL, avec `erreur` renseignee : le
//  depot ne doit jamais echouer pour ca.
//
//  Utilise par : cover_lookup (image choisie dans la galerie / le lot) et, cote
//  navigateur via src/lib/imageMetadata.js, le fichier depose dans le
//  formulaire de catalogage. Reference de la meme logique pour le stock :
//  scripts/strip-cover-metadata.py (passe du 14/10/2026).
//  Pas d'API Deno ici : le module tourne aussi dans le navigateur et Vitest.
// =============================================================================

export interface Nettoyage {
  octets: Uint8Array;
  retires: string[];
  format: string;
  erreur?: string;
}

const ascii = (b: Uint8Array, i: number, n: number) =>
  String.fromCharCode(...b.subarray(i, i + n));
const u16be = (b: Uint8Array, i: number) => (b[i] << 8) | b[i + 1];
const u32be = (b: Uint8Array, i: number) => ((b[i] << 24) >>> 0) + (b[i + 1] << 16) + (b[i + 2] << 8) + b[i + 3];
const u32le = (b: Uint8Array, i: number) => (b[i] | (b[i + 1] << 8) | (b[i + 2] << 16)) + ((b[i + 3] << 24) >>> 0);
const commence = (b: Uint8Array, i: number, s: string) => ascii(b, i, s.length) === s;

function concat(parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}

export function formatImage(b: Uint8Array): string {
  if (b[0] === 0xff && b[1] === 0xd8) return 'JPEG';
  if (b.length > 8 && b[0] === 0x89 && commence(b, 1, 'PNG')) return 'PNG';
  if (commence(b, 0, 'RIFF') && commence(b, 8, 'WEBP')) return 'WEBP';
  if (commence(b, 0, 'GIF8')) return 'GIF';
  if (commence(b, 4, 'ftyp')) return ascii(b, 8, 4).trim().toUpperCase();
  return 'INCONNU';
}

// ── JPEG ──────────────────────────────────────────────────────────────────

function etiquetteJpeg(marker: number, b: Uint8Array, seg: number): string {
  if (marker === 0xfe) return 'commentaire JPEG';
  const n = marker - 0xe0;
  if (n === 1 && commence(b, seg, 'Exif\0')) return 'EXIF';
  if (n === 1 && commence(b, seg, 'http://ns.adobe.com/')) return 'XMP';
  if (n === 2 && commence(b, seg, 'MPF\0')) return 'MPF (images secondaires)';
  if (n === 13) return 'IPTC/Photoshop';
  if (n === 11) return 'JUMBF/C2PA';
  return `APP${n}`;
}

/** Orientation EXIF (1..8) lue dans un segment APP1 Exif, ou 0. */
function orientationExif(b: Uint8Array, seg: number, fin: number): number {
  const t = seg + 6; // apres "Exif\0\0"
  if (t + 8 > fin) return 0;
  const le = b[t] === 0x49; // "II"
  const r16 = (i: number) => (le ? b[i] | (b[i + 1] << 8) : u16be(b, i));
  const r32 = (i: number) => (le ? u32le(b, i) : u32be(b, i));
  const ifd = t + r32(t + 4);
  if (ifd + 2 > fin) return 0;
  const n = r16(ifd);
  for (let k = 0; k < n; k++) {
    const e = ifd + 2 + 12 * k;
    if (e + 12 > fin) return 0;
    if (r16(e) === 0x0112) return r16(e + 8);
  }
  return 0;
}

/** APP1 minimal : un EXIF big-endian a un seul champ, l'orientation. */
function app1Orientation(o: number): Uint8Array {
  const payload = [
    0x45, 0x78, 0x69, 0x66, 0, 0,             // "Exif\0\0"
    0x4d, 0x4d, 0, 0x2a, 0, 0, 0, 8,          // "MM", 42, IFD0 a l'octet 8
    0, 1,                                     // 1 entree
    0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, o, 0, 0, // 0x0112 SHORT x1 = o
    0, 0, 0, 0,                               // pas d'IFD suivant
  ];
  const len = payload.length + 2;
  return new Uint8Array([0xff, 0xe1, len >> 8, len & 0xff, ...payload]);
}

function nettoyerJpeg(b: Uint8Array): { octets: Uint8Array; retires: string[] } {
  const tete: Uint8Array[] = [];
  const corps: Uint8Array[] = [];
  const retires: string[] = [];
  let orientation = 0;
  let apresSos = false;
  let i = 2;
  const n = b.length;
  let fin = n;

  while (i < n) {
    if (b[i] !== 0xff) throw new Error(`marqueur JPEG attendu a l'octet ${i}`);
    while (i < n && b[i] === 0xff) i++;
    if (i >= n) break;
    const m = b[i++];
    if (m === 0xd9) { corps.push(new Uint8Array([0xff, 0xd9])); fin = i; break; }
    if ((m >= 0xd0 && m <= 0xd7) || m === 0x01) { corps.push(new Uint8Array([0xff, m])); continue; }
    if (i + 2 > n) throw new Error('segment JPEG tronque');
    const len = u16be(b, i);
    const seg = i + 2;
    const plein = concat([new Uint8Array([0xff, m]), b.subarray(i, i + len)]);
    i += len;
    if (i > n) throw new Error('segment JPEG tronque');

    if (m === 0xda) {
      apresSos = true;
      corps.push(plein);
      // Donnees entropiques : jusqu'au prochain marqueur qui n'est ni un
      // octet bourre (FF00) ni un RSTn.
      let j = i;
      for (;;) {
        j = b.indexOf(0xff, j);
        if (j < 0 || j + 1 >= n) { corps.push(b.subarray(i)); i = n; break; }
        const s = b[j + 1];
        if (s === 0x00 || (s >= 0xd0 && s <= 0xd7)) { j += 2; continue; }
        if (s === 0xff) { j += 1; continue; }
        corps.push(b.subarray(i, j));
        i = j;
        break;
      }
      continue;
    }

    const estApp = m >= 0xe0 && m <= 0xef;
    if (!estApp && m !== 0xfe) {
      (apresSos ? corps : tete).push(plein);
      continue;
    }
    if (m === 0xe0 && commence(b, seg, 'JFIF\0') && len >= 16) {
      if (b[seg + 12] || b[seg + 13]) {
        retires.push('miniature JFIF');
        const s = b.slice(seg, seg + 14);
        s[12] = 0; s[13] = 0;
        tete.push(concat([new Uint8Array([0xff, 0xe0, 0, 16]), s]));
      } else {
        tete.push(plein);
      }
    } else if (m === 0xe2 && commence(b, seg, 'ICC_PROFILE\0')) {
      tete.push(plein);
    } else if (m === 0xee && commence(b, seg, 'Adobe')) {
      tete.push(plein);
    } else {
      if (m === 0xe1 && commence(b, seg, 'Exif\0') && !orientation) orientation = orientationExif(b, seg, i);
      retires.push(etiquetteJpeg(m, b, seg));
    }
  }

  if (fin < n && b.subarray(fin).some((x) => x !== 0)) retires.push('donnees apres la fin d\'image');
  if (!retires.length) return { octets: b, retires };
  if (orientation > 1 && orientation <= 8) {
    const pos = tete.length && tete[0][1] === 0xe0 ? 1 : 0;
    tete.splice(pos, 0, app1Orientation(orientation));
  }
  return { octets: concat([new Uint8Array([0xff, 0xd8]), ...tete, ...corps]), retires };
}

// ── PNG ───────────────────────────────────────────────────────────────────

const PNG_GARDES = new Set(['IHDR', 'PLTE', 'IDAT', 'IEND', 'tRNS', 'gAMA', 'cHRM', 'sRGB',
  'iCCP', 'sBIT', 'bKGD', 'pHYs', 'hIST', 'acTL', 'fcTL', 'fdAT', 'cICP', 'mDCV', 'cLLI']);

function nettoyerPng(b: Uint8Array): { octets: Uint8Array; retires: string[] } {
  const parts: Uint8Array[] = [b.subarray(0, 8)];
  const retires: string[] = [];
  let i = 8;
  while (i + 12 <= b.length) {
    const len = u32be(b, i);
    const type = ascii(b, i + 4, 4);
    const fin = i + 12 + len;
    if (fin > b.length) throw new Error('bloc PNG tronque');
    if (PNG_GARDES.has(type)) {
      parts.push(b.subarray(i, fin));
    } else if (type === 'eXIf') {
      retires.push('EXIF');
    } else if (type === 'tEXt' || type === 'zTXt' || type === 'iTXt') {
      const nul = b.indexOf(0, i + 8);
      const cle = ascii(b, i + 8, Math.max(0, Math.min(nul, fin) - (i + 8)));
      retires.push(/xmp/i.test(cle) ? 'XMP' : `texte PNG « ${cle} »`);
    } else {
      retires.push(type === 'tIME' ? 'date PNG (tIME)' : type);
    }
    i = fin;
    if (type === 'IEND') {
      if (b.subarray(i).some((x) => x !== 0)) retires.push('donnees apres la fin d\'image');
      break;
    }
  }
  return retires.length ? { octets: concat(parts), retires } : { octets: b, retires };
}

// ── WebP ──────────────────────────────────────────────────────────────────

const WEBP_GARDES = new Set(['VP8 ', 'VP8L', 'VP8X', 'ALPH', 'ANIM', 'ANMF', 'ICCP']);

function nettoyerWebp(b: Uint8Array): { octets: Uint8Array; retires: string[] } {
  const fin = Math.min(b.length, 8 + u32le(b, 4));
  const blocs: Uint8Array[] = [];
  const retires: string[] = [];
  let orientationNonNeutre = false;
  let i = 12;
  while (i + 8 <= fin) {
    const type = ascii(b, i, 4);
    const taille = u32le(b, i + 4);
    const total = 8 + taille + (taille & 1);
    if (WEBP_GARDES.has(type)) {
      blocs.push(b.slice(i, i + total));
    } else {
      if (type === 'EXIF') {
        // L'EXIF WebP n'a pas l'en-tete "Exif\0\0" : on le simule.
        const t = i + 8 - 6;
        const o = orientationExif(b, t, i + 8 + taille);
        if (o > 1) orientationNonNeutre = true;
      }
      retires.push(type === 'EXIF' ? 'EXIF' : type === 'XMP ' ? 'XMP' : type.trim());
    }
    i += total;
  }
  if (!retires.length) return { octets: b, retires };
  // Retirer une orientation non neutre ferait pivoter l'image : on s'abstient.
  if (orientationNonNeutre) throw new Error('orientation EXIF non neutre dans un WebP');
  for (const c of blocs) if (ascii(c, 0, 4) === 'VP8X') c[8] &= ~(0x08 | 0x04) & 0xff;
  const corps = concat([new TextEncoder().encode('WEBP'), ...blocs]);
  const l = corps.length;
  return {
    octets: concat([new TextEncoder().encode('RIFF'), new Uint8Array([l & 0xff, (l >> 8) & 0xff, (l >> 16) & 0xff, (l >>> 24) & 0xff]), corps]),
    retires,
  };
}

// ── GIF ───────────────────────────────────────────────────────────────────

function sousBlocs(b: Uint8Array, i: number): number {
  for (;;) {
    if (i >= b.length) throw new Error('GIF tronque');
    const t = b[i];
    i += 1 + t;
    if (t === 0) return i;
  }
}

function nettoyerGif(b: Uint8Array): { octets: Uint8Array; retires: string[] } {
  const f = b[10];
  let i = 13 + (f & 0x80 ? 3 * (2 << (f & 7)) : 0);
  const parts: Uint8Array[] = [b.subarray(0, i)];
  const retires: string[] = [];
  while (i < b.length) {
    const c = b[i];
    if (c === 0x3b) {
      parts.push(new Uint8Array([0x3b]));
      if (b.subarray(i + 1).some((x) => x !== 0)) retires.push('donnees apres la fin d\'image');
      break;
    }
    if (c === 0x21) {
      const label = b[i + 1];
      const j = sousBlocs(b, i + 2);
      if (label === 0xfe) {
        retires.push('commentaire GIF');
      } else if (label === 0xff) {
        const app = ascii(b, i + 3, 11);
        if (['NETSCAPE2.0', 'ANIMEXTS1.0', 'ICCRGBG1012'].includes(app)) parts.push(b.subarray(i, j));
        else retires.push(app.startsWith('XMP Data') ? 'XMP' : `extension GIF ${app}`);
      } else {
        parts.push(b.subarray(i, j));
      }
      i = j;
    } else if (c === 0x2c) {
      const lf = b[i + 9];
      const j = sousBlocs(b, i + 10 + (lf & 0x80 ? 3 * (2 << (lf & 7)) : 0) + 1);
      parts.push(b.subarray(i, j));
      i = j;
    } else {
      throw new Error(`bloc GIF inattendu a l'octet ${i}`);
    }
  }
  return retires.length ? { octets: concat(parts), retires } : { octets: b, retires };
}

// ── Entree ────────────────────────────────────────────────────────────────

export function retirerMetadonnees(entree: Uint8Array | ArrayBuffer): Nettoyage {
  const b = entree instanceof Uint8Array ? entree : new Uint8Array(entree);
  const format = formatImage(b);
  try {
    const r = format === 'JPEG' ? nettoyerJpeg(b)
      : format === 'PNG' ? nettoyerPng(b)
        : format === 'WEBP' ? nettoyerWebp(b)
          : format === 'GIF' ? nettoyerGif(b)
            : null;
    if (!r) return { octets: b, retires: [], format };
    return { octets: r.octets, retires: r.retires, format };
  } catch (err) {
    return { octets: b, retires: [], format, erreur: err instanceof Error ? err.message : String(err) };
  }
}
