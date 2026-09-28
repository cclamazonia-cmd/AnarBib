/**
 * coverThumbs.js — vignettes de couverture pre-generees.
 *
 * Le catalogue affichait ses miniatures via `/storage/v1/render/image/...`,
 * l'endpoint de transformation d'images de Supabase Storage. On ne s'en sert
 * plus, pour deux raisons, dans cet ordre :
 *
 *  1. `deploy/compose.yml` ecarte imgproxy de la pile auto-hebergee (ligne 5)
 *     et pose `ENABLE_IMAGE_TRANSFORMATION: "false"` (ligne 175). Une page
 *     publique ne peut pas dependre d'un service que la recette de deploiement
 *     du projet exclut deliberement : sur une instance montee depuis ce depot,
 *     la grille afficherait des images cassees.
 *  2. Supabase facture ces transformations a l'image d'origine DISTINCTE et par
 *     mois — pas a la requete. Le compteur suit donc le taux de couverture en
 *     capas (244 notices sur 2671 au 25/08/2026), qui a vocation a monter.
 *
 * A la place, chaque capa porte un derive range a cote d'elle et servi comme un
 * objet ordinaire. Zero transformation, aucune colonne de base, aucune des 17
 * vues portant `cover_object_path` a modifier : la convention de nommage suffit.
 *
 * Le derive est produit dans le navigateur au depot (canvas, meme mecanique que
 * la capa « page 1 du PDF »), et par `scripts/backfill-cover-thumbs.py` pour le
 * stock deja en place.
 */

export const COVER_BUCKET = 'covers';

// ── L'adresse d'une capa neuve ──────────────────────────────────────────
//
// Jusqu'au 28/09/2026, le formulaire rangeait chaque capa a
// `books/<cle>/front.<ext>` et REMPLACAIT en place (`upsert`). Meme adresse,
// image differente : le bucket sert ses objets avec `Cache-Control:
// max-age=3600`, donc le navigateur qui avait affiche la premiere version —
// celui de la personne qui catalogue, forcement, puisqu'elle vient de la voir
// dans le formulaire — et le CDN devant lui resservaient l'ancienne image
// pendant une heure. Vecu le 28/09 sur deux series de tomes (MLEG-0145,
// BTL-TL-000447) : les fichiers stockes etaient justes, la page Oeuvre
// montrait la capa d'un autre tome, et rien en base ne l'expliquait.
//
// Regle depuis : une capa neuve a une adresse neuve, `capa-<horodatage en base
// 36>` — le nom que l'ecran de revue donnait deja (REGISTRE CAPAS-4) — et le
// depot se fait SANS upsert. L'ancien objet reste tant qu'une notice ou un
// brouillon le designe (un brouillon abandonne ne doit pas laisser la notice
// sans image) ; `scripts/purge-orphelins-covers.py` le retire une fois remplace
// (classe B). `photo-…` (Painel) et `front.<ext>` (le stock d'avant) restent des
// noms valides : la convention du derive ne depend pas du nom.

/** La cle du dossier de la notice : bib_ref ou id, nettoyee comme par cover_lookup et photoCapa. */
export function cleCapa(bibRefOuId) {
  return String(bibRefOuId ?? '').replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 120);
}

/** Le nom neuf, dans la forme que cover_lookup accepte (`capa-[a-z0-9]{1,20}`). */
export function nomCapaNeuf(horodatage = Date.now()) {
  return `capa-${Number(horodatage).toString(36)}`;
}

/** L'extension d'un fichier choisi, en minuscules et sure ; `jpg` si elle ne se lit pas. */
export function extensionCapa(nomFichier, defaut = 'jpg') {
  const nom = String(nomFichier || '');
  const i = nom.lastIndexOf('.');
  const ext = i > 0 ? nom.slice(i + 1).toLowerCase() : '';
  return /^[a-z0-9]{1,5}$/.test(ext) ? ext : defaut;
}

/** Le chemin complet d'une capa neuve dans le bucket ; vide sans cle. */
export function cheminCapaNeuf(bibRefOuId, ext = 'jpg', horodatage = Date.now()) {
  const cle = cleCapa(bibRefOuId);
  if (!cle) return '';
  return `books/${cle}/${nomCapaNeuf(horodatage)}.${ext}`;
}

// Boite du derive. L'affichage fait 30x44 px CSS dans la grille (24x34 en mode
// compact) : 128x192 couvre les ecrans jusqu'a 4x sans jamais recadrer, pour
// ~2 ko par vignette. Le ratio 2:3 est celui d'une couverture ; `contain` cote
// CSS fait le reste, donc on n'ajoute aucune marge ici.
export const THUMB_MAX_W = 128;
export const THUMB_MAX_H = 192;

const THUMB_QUALITY = 0.72;
const THUMB_SUFFIX = '.thumb.jpg';

// Base et client resolus a l'appel, pas au chargement du module : `npm test`
// tourne SANS VITE_SUPABASE_URL (la CI ne le fournit qu'a l'etape build, cf.
// .forgejo/workflows/ci.yml), et `./supabase` leve a l'import si la variable
// manque. Un import statique ici rendrait ce module intestable.
function storagePublicBase() {
  return `${import.meta.env.VITE_SUPABASE_URL}/storage/v1/object/public`;
}

async function client() {
  const { supabase } = await import('./supabase');
  return supabase;
}

/**
 * Chemin du derive : le chemin COMPLET de l'original, suffixe.
 *
 *   books/0000275/front.jpg       -> books/0000275/front.jpg.thumb.jpg
 *   books/BTL-TL-000027/front.gif -> books/BTL-TL-000027/front.gif.thumb.jpg
 *
 * La double extension n'est pas elegante, mais elle est le prix d'une propriete
 * qui compte : la fonction est INJECTIVE. Une premiere version remplacait
 * l'extension (`front.jpg` -> `front.thumb.jpg`), et deux originaux de meme
 * racine s'ecrasaient : `front.jpg` et `front.png` coexistent dans ce bucket
 * pour cinq notices, et trois d'entre elles se sont retrouvees avec la vignette
 * d'un AUTRE fichier que leur capa declaree. C'est la meme famille de bug que
 * la collision `books/new/` corrigee en P1 (spec-module-capas §3.1) : deux capas
 * distinctes ne doivent jamais viser le meme chemin.
 *
 * Toujours en .jpg en sortie quelle que soit l'entree : le derive est reencode,
 * et le JPEG est le seul format que tout navigateur affiche sans negociation.
 */
export function thumbPathFor(coverPath) {
  const p = String(coverPath || '').trim();
  if (!p) return '';
  // Idempotent : sans ce garde, un chemin deja derive s'empilerait. La reprise
  // s'appuie dessus pour ne pas fabriquer des vignettes de vignettes.
  if (p.endsWith(THUMB_SUFFIX)) return p;
  return `${p}${THUMB_SUFFIX}`;
}

/** URL publique de l'original. */
export function coverUrl(coverPath) {
  const p = String(coverPath || '').trim();
  return p ? `${storagePublicBase()}/${COVER_BUCKET}/${p}` : '';
}

/** URL publique du derive (vide si pas de capa). */
export function coverThumbUrl(coverPath) {
  const p = thumbPathFor(coverPath);
  return p ? coverUrl(p) : '';
}

// ── Generation ──────────────────────────────────────────────────────────

async function toBitmap(source) {
  if (source instanceof Blob) return createImageBitmap(source);
  // Canvas (capa « page 1 du PDF ») : drawImage l'accepte tel quel.
  if (source && typeof source === 'object' && 'width' in source && 'height' in source) return source;
  throw new Error('source non supportee');
}

/**
 * Redimensionne une source (File, Blob ou canvas) en vignette JPEG.
 * Ne recadre jamais : on tient dans la boite en gardant le ratio.
 */
export async function makeCoverThumbBlob(source) {
  const bmp = await toBitmap(source);
  const w = bmp.width;
  const h = bmp.height;
  if (!w || !h) throw new Error('image vide');

  const scale = Math.min(THUMB_MAX_W / w, THUMB_MAX_H / h, 1);
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.round(w * scale));
  canvas.height = Math.max(1, Math.round(h * scale));

  const ctx = canvas.getContext('2d');
  // Aplat blanc : le JPEG n'a pas de couche alpha, et une capa PNG transparente
  // virerait au noir sans ce fond.
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(bmp, 0, 0, canvas.width, canvas.height);
  if (typeof bmp.close === 'function') bmp.close();

  const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/jpeg', THUMB_QUALITY));
  if (!blob) throw new Error('toBlob a echoue');
  return blob;
}

/**
 * Produit et depose le derive de `coverPath`.
 *
 * `source` est facultatif : sans lui, on retelecharge l'original par l'API
 * Storage (`download`) plutot que par l'URL publique. Ce detour est
 * volontaire — l'URL publique passe par le CDN, qui peut encore servir la
 * PRECEDENTE capa pendant une heure apres un remplacement en place (`upsert`
 * sur un chemin stable : le stock `front.<ext>` d'avant le 28/09/2026, ou un
 * script), ce qui produirait la vignette du mauvais livre.
 *
 * Best-effort assume : en cas d'echec, on n'interrompt pas le depot de la capa.
 * Le catalogue retombe alors sur l'original via le `onError` de la grille, et
 * le prochain passage du script de reprise rattrapera le derive manquant.
 */
export async function writeCoverThumb(coverPath, source = null) {
  const thumbPath = thumbPathFor(coverPath);
  if (!thumbPath) return null;
  try {
    const sb = await client();
    let src = source;
    if (!src) {
      const { data, error } = await sb.storage.from(COVER_BUCKET).download(coverPath);
      if (error) throw error;
      src = data;
    }
    const blob = await makeCoverThumbBlob(src);
    const { error: upErr } = await sb.storage
      .from(COVER_BUCKET)
      .upload(thumbPath, blob, { upsert: true, contentType: 'image/jpeg' });
    if (upErr) throw upErr;
    return thumbPath;
  } catch (err) {
    console.warn('[capas] vignette non generee pour', coverPath, '-', err?.message || err);
    return null;
  }
}

/** Supprime le derive avec son original. Best-effort, meme raison. */
export async function removeCoverThumb(coverPath) {
  const thumbPath = thumbPathFor(coverPath);
  if (!thumbPath) return;
  try {
    const sb = await client();
    await sb.storage.from(COVER_BUCKET).remove([thumbPath]);
  } catch (err) {
    console.warn('[capas] vignette non supprimee pour', coverPath, '-', err?.message || err);
  }
}
