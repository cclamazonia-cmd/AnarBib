// ═══════════════════════════════════════════════════════════
// CHEMIN DÉPÔT : supabase/functions/_shared/core/zip-borne.ts
//
// Ouvrir un ZIP qu'on n'a pas fabriqué, sans le laisser dicter la mémoire
// (19/10/2026). receive-fonds-bundle déballait un paquet de fonds par JSZip
// sans aucune borne : quelques Ko compressés peuvent se décompresser en
// plusieurs Go (« bombe zip »), et une seule entrée suffit à faire tomber la
// fonction — ou, sur une pile auto-hébergée, la machine qui la porte.
//
// Quatre bornes, toutes vérifiées AVANT d'avoir tout décompressé :
//   1. le paquet lui-même (octets compressés), avant JSZip.loadAsync ;
//   2. le nombre d'entrées ;
//   3. chaque entrée : la taille DÉCLARÉE par le répertoire central est lue
//      d'abord (refus immédiat), puis la taille RÉELLE est comptée pendant la
//      décompression — un répertoire central se falsifie, le flux non ;
//   4. le total décompressé sur le paquet, compté de même.
// La décompression d'une entrée passe par internalStream : on compte les
// morceaux à mesure, et on arrête le flux dès que la borne est franchie.
//
// Sans dépendance à Deno : chargé tel quel par vitest
// (src/tests/zip-borne.test.js), avec le vrai jszip du front.
// ═══════════════════════════════════════════════════════════

export class ZipRefuse extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ZipRefuse';
  }
}

export interface BornesZip {
  maxOctetsPaquet: number;
  maxEntrees: number;
  maxOctetsEntree: number;
  maxOctetsTotal: number;
}

const Mo = (n: number) => `${Math.round(n / 1e6)} Mo`;

// deno-lint-ignore no-explicit-any
type ZipLike = any;

/** Ouvre le paquet après avoir vérifié sa taille et son nombre d'entrées. */
// deno-lint-ignore no-explicit-any
export async function ouvrirZipBorne(JSZip: any, octets: ArrayBuffer | Uint8Array, bornes: BornesZip) {
  const taille = octets.byteLength;
  if (taille > bornes.maxOctetsPaquet) {
    throw new ZipRefuse(`Paquet trop lourd : ${Mo(taille)} (au plus ${Mo(bornes.maxOctetsPaquet)}).`);
  }
  const zip: ZipLike = await JSZip.loadAsync(octets);
  const entrees = Object.values(zip.files).filter((f: ZipLike) => !f.dir);
  if (entrees.length > bornes.maxEntrees) {
    throw new ZipRefuse(`Paquet de ${entrees.length} fichiers (au plus ${bornes.maxEntrees}).`);
  }
  let declare = 0;
  for (const f of entrees) {
    const t = Number((f as ZipLike)?._data?.uncompressedSize);
    if (Number.isFinite(t)) {
      if (t > bornes.maxOctetsEntree) throw new ZipRefuse(`« ${(f as ZipLike).name} » ferait ${Mo(t)} décompressé (au plus ${Mo(bornes.maxOctetsEntree)}).`);
      declare += t;
    }
  }
  if (declare > bornes.maxOctetsTotal) {
    throw new ZipRefuse(`Le paquet ferait ${Mo(declare)} décompressé (au plus ${Mo(bornes.maxOctetsTotal)}).`);
  }
  // Le compteur du total RÉEL, partagé par toutes les lectures de ce paquet.
  const etat = { lu: 0 };
  return {
    zip,
    /** Une entrée, décompressée sous les bornes (Uint8Array), ou null si absente. */
    async lire(chemin: string): Promise<Uint8Array | null> {
      const entree = zip.file(chemin);
      if (!entree || entree.dir) return null;
      return await decompresserBorne(entree, bornes, etat);
    },
    /** Une entrée en texte (UTF-8), sous les mêmes bornes. */
    async lireTexte(chemin: string): Promise<string | null> {
      const octets = await this.lire(chemin);
      return octets === null ? null : new TextDecoder().decode(octets);
    },
  };
}

function decompresserBorne(entree: ZipLike, bornes: BornesZip, etat: { lu: number }): Promise<Uint8Array> {
  return new Promise((resoudre, rejeter) => {
    const morceaux: Uint8Array[] = [];
    let total = 0;
    let fini = false;
    const flux = entree.internalStream('uint8array');
    const arreter = (e: Error) => {
      if (fini) return;
      fini = true;
      try { flux.pause(); } catch { /* le flux est peut-être déjà terminé */ }
      rejeter(e);
    };
    flux.on('data', (morceau: Uint8Array) => {
      if (fini) return;
      total += morceau.byteLength;
      etat.lu += morceau.byteLength;
      if (total > bornes.maxOctetsEntree) return arreter(new ZipRefuse(`« ${entree.name} » dépasse ${Mo(bornes.maxOctetsEntree)} décompressé.`));
      if (etat.lu > bornes.maxOctetsTotal) return arreter(new ZipRefuse(`Le paquet dépasse ${Mo(bornes.maxOctetsTotal)} décompressé.`));
      morceaux.push(morceau);
    });
    flux.on('error', (e: Error) => arreter(e instanceof Error ? e : new Error(String(e))));
    flux.on('end', () => {
      if (fini) return;
      fini = true;
      const out = new Uint8Array(total);
      let pos = 0;
      for (const m of morceaux) { out.set(m, pos); pos += m.byteLength; }
      resoudre(out);
    });
    flux.resume();
  });
}
