// ═══════════════════════════════════════════════════════════
// AnarBib — la police des PDF engendrés dans le navigateur (jspdf)
// ═══════════════════════════════════════════════════════════
//
// Constat du 13/10/2026 (chantier « locale ro », lot 2 avancé) : jspdf n'a,
// de base, que les 14 polices standard du PDF, au jeu WinAnsi. Une ligne qui
// contient UN caractère hors de ce jeu y est écrite en octets UTF-16 bruts —
// toute la ligne sort illisible, lettres latines comprises. Mesuré sur la
// sortie de jspdf : le grec (« Αναγνώστης ») et le roumain (ș, ț, ă) étaient
// perdus, et même le « œ » français disparaissait (« cœur » → « cur »). Les
// rapports, le règlement, la liste des lecteur·rices et les rapports
// financiers d'une bibliothèque grecque étaient donc illisibles.
//
// Remède : DejaVu Sans (latin étendu, grec, cyrillique ; licence libre,
// src/assets/fonts/pdf/LICENSE), chargée À LA DEMANDE — seulement quand un
// PDF est produit, une fois par session (cache) — et posée sous le nom
// POLICE. jspdf n'embarque dans chaque PDF que les glyphes utilisés : le
// fichier produit reste léger.
//
// Si le chargement échoue (hors ligne, environnement de test), le document
// garde Helvetica : le PDF sort quand même, comme avant pour le latin.
// Les générateurs écrivent donc doc.setFont(policePdf(doc), …), jamais
// 'helvetica' en dur.

import regulier from '@/assets/fonts/pdf/DejaVuSans.ttf?url';
import gras from '@/assets/fonts/pdf/DejaVuSans-Bold.ttf?url';
import italique from '@/assets/fonts/pdf/DejaVuSans-Oblique.ttf?url';

export const POLICE = 'AnarBibSans';
const REPLI = 'helvetica';
const STYLES = [['normal', regulier], ['bold', gras], ['italic', italique]];
const enCache = new Map();

function enBase64(url) {
  if (!enCache.has(url)) {
    const p = fetch(url)
      .then((r) => { if (!r.ok) throw new Error(`police PDF ${url} : HTTP ${r.status}`); return r.arrayBuffer(); })
      .then((buf) => {
        const octets = new Uint8Array(buf);
        let s = '';
        for (let i = 0; i < octets.length; i += 0x8000) s += String.fromCharCode.apply(null, octets.subarray(i, i + 0x8000));
        return btoa(s);
      });
    p.catch(() => enCache.delete(url));   // un échec n'est pas mis en cache
    enCache.set(url, p);
  }
  return enCache.get(url);
}

/** Pose la police des PDF sur `doc` (jsPDF) ; rend le nom de la police posée. */
export async function poserPolicePdf(doc) {
  try {
    const donnees = await Promise.all(STYLES.map(([, url]) => enBase64(url)));
    STYLES.forEach(([style], i) => {
      const fichier = `${POLICE}-${style}.ttf`;
      doc.addFileToVFS(fichier, donnees[i]);
      doc.addFont(fichier, POLICE, style);
    });
    doc.__policeAnarBib = POLICE;
  } catch (e) {
    console.warn('[pdf] police DejaVu Sans indisponible, repli Helvetica (latin seul) :', e?.message || e);
    doc.__policeAnarBib = REPLI;
  }
  doc.setFont(doc.__policeAnarBib, 'normal');
  return doc.__policeAnarBib;
}

/** Le nom de police à passer à doc.setFont : celle posée par poserPolicePdf, sinon Helvetica. */
export const policePdf = (doc) => doc.__policeAnarBib || REPLI;
