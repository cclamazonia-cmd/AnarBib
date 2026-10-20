/**
 * capaPdf.js — la page 1 d'un PDF comme couverture (capas P3, puis en lot).
 *
 * Deux appelants, un seul rendu :
 *   · le bouton « page 1 du PDF » du formulaire de catalogage (une notice) ;
 *   · le lot de l'onglet « Couvertures » du Painel (20/10/2026, Anarchief.org :
 *     569 notices, aucune couverture, toutes avec un PDF public).
 *
 * Le rendu se fait dans le navigateur avec le pdf.js déjà servi depuis
 * /public/vendor/pdfjs : aucune dépendance serveur, rien qui manque sur une
 * pile auto-hébergée (cf. l'en-tête de coverThumbs.js).
 */

import { loadPdfjsCat, PDFJS_BASE } from './catalogacao/bookDraft';
import { resolveSupabaseUrl } from './supabaseUrl';

/** Largeur de la capa rendue, en px : celle du bouton du formulaire depuis P3. */
export const LARGEUR_CAPA_PDF = 800;

/** Le seau dont la page 1 peut devenir publique (api.capas_pdf_*). */
export const SEAU_PDF_PUBLIC = 'anarbib-pdf-public';

/**
 * Adresse publique d'un PDF du seau public, segment par segment encodé (les
 * noms versés portent espaces, accents, parenthèses).
 */
export function urlPdfPublic(chemin) {
  const p = String(chemin || '').replace(/^\/+/, '');
  if (!p) return '';
  const encode = p.split('/').map(encodeURIComponent).join('/');
  return `${resolveSupabaseUrl()}/storage/v1/object/public/${SEAU_PDF_PUBLIC}/${encode}`;
}

/** Taille d'une plage lue, en octets : celle que pdf.js demande par défaut. */
const PLAGE = 65536;

/** Délai au-delà duquel un PDF est déclaré illisible : la passe continue. */
const DELAI_MS = 120000;

/**
 * Prépare la lecture d'un PDF distant par plages (en-tête `Range`).
 *
 * pdf.js sait lire par plages tout seul, à condition de VOIR `Accept-Ranges`
 * dans la réponse. Supabase Storage sert bien les plages (206), mais n'expose
 * pas cet en-tête en CORS (constaté le 20/10/2026) : pdf.js croit le serveur
 * incapable et télécharge le fichier entier. On lui donne donc les plages à la
 * main (PDFDataRangeTransport). Mesuré sur deux PDF d'Anarchief : 1,0 Mo lu
 * sur 2,8 et 1,9 Mo sur 9,5 — sur 569 PDF (6,8 Go), la différence se compte en
 * gigaoctets de trafic sortant.
 *
 * Renvoie `{ range }` ou, si le serveur ignore les plages (200 au lieu de
 * 206), `{ data }` : le corps reçu EST alors le fichier entier.
 */
async function sourceParPlages(pdfjs, url, surEchec) {
  const tete = await fetch(url, { method: 'HEAD' });
  if (!tete.ok) throw new Error(`PDF injoignable (${tete.status})`);
  // Content-Length est un en-tête « safelisted » : toujours lisible en CORS.
  const longueur = Number(tete.headers.get('content-length'));
  const lire = async (debut, fin) => {
    const r = await fetch(url, { headers: { Range: `bytes=${debut}-${fin - 1}` } });
    if (r.status === 200) return { entier: await r.arrayBuffer() };
    if (r.status !== 206) throw new Error(`plage refusée (${r.status})`);
    return { morceau: new Uint8Array(await r.arrayBuffer()) };
  };
  if (!longueur) {
    const r = await fetch(url);
    if (!r.ok) throw new Error(`PDF injoignable (${r.status})`);
    return { data: await r.arrayBuffer() };
  }
  const premier = await lire(0, Math.min(PLAGE, longueur));
  if (premier.entier) return { data: premier.entier };
  const transport = new pdfjs.PDFDataRangeTransport(longueur, premier.morceau);
  transport.requestDataRange = (debut, fin) => {
    lire(debut, fin).then(
      (r) => (r.morceau ? transport.onDataRange(debut, r.morceau) : surEchec(new Error('plage ignorée'))),
      surEchec,
    );
  };
  return { range: transport, rangeChunkSize: PLAGE, disableAutoFetch: true, disableStream: true };
}

/**
 * Rend la page 1 d'un PDF sur un canvas hors écran.
 *
 * `source` : un ArrayBuffer (octets déjà en main), ou `{ url }` — lu alors par
 * plages, seulement ce qu'il faut pour la page 1 (voir sourceParPlages).
 * Un PDF qui ne se rend pas dans DELAI_MS est abandonné : l'erreur remonte,
 * l'appelant passe au suivant au lieu d'attendre une promesse qui ne vient pas.
 */
export async function rendrePage1(source, largeur = LARGEUR_CAPA_PDF) {
  const pdfjs = await loadPdfjsCat();
  const commun = {
    cMapUrl: `${PDFJS_BASE}/web/cmaps/`,
    cMapPacked: true,
    standardFontDataUrl: `${PDFJS_BASE}/web/standard_fonts/`,
  };

  let tache = null;
  let echec = null;
  let rejeter;
  const abandon = new Promise((_, reject) => { rejeter = reject; });
  abandon.catch(() => {});
  const arreter = (err) => {
    if (echec) return;
    echec = err;
    rejeter(err);
    tache?.destroy();
  };
  const minuterie = setTimeout(() => arreter(new Error('PDF trop long à lire')), DELAI_MS);

  let pdf = null;
  try {
    const params = source && typeof source === 'object' && 'url' in source
      ? await Promise.race([sourceParPlages(pdfjs, source.url, arreter), abandon])
      : { data: source };
    tache = pdfjs.getDocument({ ...commun, ...params });
    pdf = await Promise.race([tache.promise, abandon]);
    const page = await Promise.race([pdf.getPage(1), abandon]);
    const base = page.getViewport({ scale: 1 });
    const viewport = page.getViewport({ scale: largeur / base.width });
    const canvas = document.createElement('canvas');
    canvas.width = Math.floor(viewport.width);
    canvas.height = Math.floor(viewport.height);
    const ctx = canvas.getContext('2d');
    // Fond blanc : une page sans aplat sortirait noire une fois en JPEG.
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    // intent 'print' : pdf.js cadence le rendu « display » sur
    // requestAnimationFrame, qui ne se déclenche presque plus dans un onglet
    // caché — mesuré le 20/10 : 0,3 s en « print », 22 s en « display » pour la
    // même page. Une passe de 569 notices doit survivre à un changement d'onglet.
    await Promise.race([page.render({ canvasContext: ctx, viewport, intent: 'print' }).promise, abandon]);
    return canvas;
  } finally {
    clearTimeout(minuterie);
    if (pdf) pdf.destroy();
    else tache?.destroy();
  }
}

/** Canvas -> JPEG, à la qualité du bouton du formulaire. */
export async function canvasEnJpeg(canvas, qualite = 0.9) {
  const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/jpeg', qualite));
  if (!blob) throw new Error('toBlob failed');
  return blob;
}
