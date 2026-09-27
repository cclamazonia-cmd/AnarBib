/**
 * photoCapa.js — la photo d'une couverture, prise avec le téléphone (27/09/2026).
 *
 * POURQUOI. Le fonds brésilien n'existe pas dans les catalogues ouverts : sur
 * 32 notices pt-BR sans ISBN tirées au hasard le 27/09, AUCUNE couverture
 * trouvée en ligne. La recherche automatique plafonne vers 25-30 % ; le reste
 * est une photo, prise en rayon, livre en main. Ce module prépare cette photo
 * dans le navigateur, avant tout envoi :
 *
 *  1. REDRESSÉE : l'orientation EXIF du téléphone est appliquée
 *     (`imageOrientation: 'from-image'`), plus un quart de tour à la main si
 *     la personne l'a demandé ;
 *  2. RÉDUITE : 1 600 px au plus sur le grand côté (une photo de téléphone en
 *     fait 4 000 et pèse 3 à 8 Mo ; le bucket `covers` plafonne à 10 Mo et la
 *     fiche publique n'affiche jamais plus de quelques centaines de pixels) ;
 *  3. RÉENCODÉE en JPEG par un canvas — ce qui retire TOUTES les métadonnées
 *     de la photo d'origine : position GPS du lieu où elle est prise, modèle du
 *     téléphone, date. Une bibliothèque n'a pas à publier l'adresse d'une
 *     bénévole avec la couverture d'un livre.
 */

export const PHOTO_MAX_COTE = 1600;
export const PHOTO_QUALITE = 0.85;

/**
 * Dimensions de sortie : réduites pour que le grand côté tienne dans `max`
 * (jamais agrandies), puis échangées si le quart de tour couche l'image.
 */
export function dimensionsPhoto(largeur, hauteur, quarts = 0, max = PHOTO_MAX_COTE) {
  const w0 = Math.max(1, Math.round(Number(largeur) || 0));
  const h0 = Math.max(1, Math.round(Number(hauteur) || 0));
  const echelle = Math.min(1, max / Math.max(w0, h0));
  const w = Math.max(1, Math.round(w0 * echelle));
  const h = Math.max(1, Math.round(h0 * echelle));
  const couchee = ((Number(quarts) % 4) + 4) % 2 === 1;
  return { dessinL: w, dessinH: h, toileL: couchee ? h : w, toileH: couchee ? w : h };
}

/**
 * Le chemin de la photo dans le bucket : le dossier de la notice (clé =
 * bib_ref, nettoyée comme cover_lookup la nettoie), un nom NEUF à chaque
 * photo — jamais par-dessus une capa existante, et jamais la même adresse
 * servie par le CDN pour deux images différentes.
 */
export function cheminPhoto(bibRef, horodatage = Date.now()) {
  const cle = String(bibRef || '').replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 120);
  if (!cle) return '';
  return `books/${cle}/photo-${Number(horodatage).toString(36)}.jpg`;
}

async function versBitmap(fichier) {
  if (typeof createImageBitmap === 'function') {
    try {
      return await createImageBitmap(fichier, { imageOrientation: 'from-image' });
    } catch {
      // Safari ancien : l'option n'existe pas — repli sur <img>, qui applique
      // l'orientation EXIF par défaut dans les navigateurs actuels.
    }
  }
  const url = URL.createObjectURL(fichier);
  try {
    const img = new Image();
    img.decoding = 'async';
    img.src = url;
    await img.decode();
    return img;
  } finally {
    URL.revokeObjectURL(url);
  }
}

/**
 * Prépare la photo : redressée, réduite, réencodée en JPEG sans métadonnées.
 * `quarts` : nombre de quarts de tour dans le sens des aiguilles d'une montre.
 */
export async function preparerPhoto(fichier, quarts = 0) {
  const source = await versBitmap(fichier);
  const largeur = source.width ?? source.naturalWidth;
  const hauteur = source.height ?? source.naturalHeight;
  const d = dimensionsPhoto(largeur, hauteur, quarts);
  const toile = document.createElement('canvas');
  toile.width = d.toileL;
  toile.height = d.toileH;
  const ctx = toile.getContext('2d');
  ctx.translate(d.toileL / 2, d.toileH / 2);
  ctx.rotate(((((Number(quarts) % 4) + 4) % 4) * Math.PI) / 2);
  ctx.drawImage(source, -d.dessinL / 2, -d.dessinH / 2, d.dessinL, d.dessinH);
  if (typeof source.close === 'function') source.close();
  const blob = await new Promise((ok) => toile.toBlob(ok, 'image/jpeg', PHOTO_QUALITE));
  if (!blob) throw new Error('photo illisible');
  return blob;
}
