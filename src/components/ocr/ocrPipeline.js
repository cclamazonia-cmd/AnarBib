/**
 * ocrPipeline.js — pipeline OCR navigateur AnarBib (piste B, P1 — POC)
 *
 * Cadrage : docs/journal/cadrages/CADRAGE_ocr_import_navigateur_2026-06-17.md
 * Session : OCR import navigateur (piste B)
 *
 * Logique PURE — aucun React, AUCUNE écriture base (contrat P1).
 *
 * Chaîne 100 % navigateur, zéro serveur, zéro LLM :
 *   1. pdf.js (vendor /vendor/pdfjs) → getTextContent() pour détecter un PDF
 *      « born-digital » (texte natif présent). Si oui → on prend le texte tel
 *      quel, PAS d'OCR (leçon Caderno-CAB : OCRiser de force un PDF déjà-texte
 *      = régression).
 *   2. sinon → rastériser les pages clés (couverture + ours/colophon) avec
 *      pdf.js, puis OCR avec tesseract.js (WASM self-host /vendor/tesseract).
 *
 * Les assets tesseract (worker + core WASM + .traineddata) sont auto-hébergés
 * sous /vendor/tesseract/ (cf. scripts/install-tesseract.sh). Rien ne sort du
 * navigateur. La cible prod (P2/P3) est le bucket anarbib-media-public/ocr/.
 */

import { createWorker, OEM } from 'tesseract.js';

// ─── Chemins de service (Vite sert public/ à la racine) ──────────────────
const PDFJS_BASE = '/vendor/pdfjs';
const TESS_BASE = '/vendor/tesseract';

// ─── pdf.js : réutilise le vendor déjà servi (cf. PdfViewer.jsx) ─────────
let pdfjsPromise = null;
export function loadPdfjs() {
  if (!pdfjsPromise) {
    pdfjsPromise = import(/* @vite-ignore */ `${PDFJS_BASE}/build/pdf.mjs`).then((mod) => {
      const pdfjs = mod.getDocument ? mod : (mod.default || mod);
      pdfjs.GlobalWorkerOptions.workerSrc = `${PDFJS_BASE}/build/pdf.worker.mjs`;
      return pdfjs;
    });
  }
  return pdfjsPromise;
}

/**
 * Ouvre un PDF depuis un ArrayBuffer (octets en mémoire — pas de réseau).
 * @returns {Promise<object>} le PDFDocumentProxy pdf.js
 */
export async function openPdf(arrayBuffer) {
  const pdfjs = await loadPdfjs();
  return pdfjs.getDocument({
    data: arrayBuffer,
    cMapUrl: `${PDFJS_BASE}/web/cmaps/`,
    cMapPacked: true,
    standardFontDataUrl: `${PDFJS_BASE}/web/standard_fonts/`,
    wasmUrl: `${PDFJS_BASE}/web/wasm/`,
    iccUrl: `${PDFJS_BASE}/web/iccs/`,
    useSystemFonts: false,
  }).promise;
}

/**
 * Concatène le texte natif d'une page (couche texte du PDF).
 * @returns {Promise<string>}
 */
async function getPageText(pdf, pageNum) {
  const page = await pdf.getPage(pageNum);
  const tc = await page.getTextContent();
  // pdf.js insère des items « EOL » (str vide) entre les lignes.
  return tc.items.map((it) => it.str || '').join(' ').replace(/\s+/g, ' ').trim();
}

/**
 * Détecte si le PDF est « born-digital » (couche texte exploitable présente).
 *
 * Heuristique simple, robuste : on échantillonne les premières pages et on
 * compte les caractères non-blancs. Un PDF tagué a des centaines de caractères
 * par page ; un scan-image en a ~0.
 *
 * @param {object} pdf
 * @param {object} [opts]
 * @param {number} [opts.maxPages=4]        pages échantillonnées
 * @param {number} [opts.minCharsPerPage=50] seuil moyen chars/page pour « texte »
 * @returns {Promise<{bornDigital:boolean, chars:number, sampledPages:number,
 *                     avgPerPage:number, text:string}>}
 */
export async function detectBornDigital(pdf, { maxPages = 4, minCharsPerPage = 50 } = {}) {
  const sampledPages = Math.min(pdf.numPages, maxPages);
  let text = '';
  for (let i = 1; i <= sampledPages; i += 1) {
    const t = await getPageText(pdf, i);
    if (t) text += `${t}\n`;
  }
  const chars = text.replace(/\s/g, '').length;
  const avgPerPage = sampledPages ? chars / sampledPages : 0;
  return {
    bornDigital: avgPerPage >= minCharsPerPage,
    chars,
    sampledPages,
    avgPerPage,
    text: text.trim(),
  };
}

/**
 * Extrait le texte natif de tout le document (born-digital), borné par sécurité.
 * @returns {Promise<{text:string, pages:number}>}
 */
export async function extractAllText(pdf, { maxPages = 50 } = {}) {
  const n = Math.min(pdf.numPages, maxPages);
  let text = '';
  for (let i = 1; i <= n; i += 1) {
    const t = await getPageText(pdf, i);
    text += `${t}\n\n`;
  }
  return { text: text.trim(), pages: n };
}

/**
 * Choisit les « pages clés » à OCRiser par défaut : couverture + tête de
 * document (verso du titre / ours) + pied de document (colophon parfois en
 * fin). Heuristique du cadrage §3.1 ; bornée à quelques pages pour la perf.
 * @returns {number[]} numéros de page (1-based), triés, sans doublon
 */
export function extractKeyPages(pdf, { maxPages = 5 } = {}) {
  const n = pdf.numPages;
  const candidates = [1, 2, 3, n - 1, n];
  const seen = new Set();
  const pages = [];
  for (const p of candidates) {
    if (p >= 1 && p <= n && !seen.has(p)) {
      seen.add(p);
      pages.push(p);
    }
  }
  pages.sort((a, b) => a - b);
  return pages.slice(0, maxPages);
}

/**
 * Rastérise une page sur un canvas hors-écran, à une résolution adaptée à
 * l'OCR (largeur cible ~1600px → meilleure reconnaissance qu'à l'échelle 1).
 * @returns {Promise<HTMLCanvasElement>}
 */
export async function rasterizePage(pdf, pageNum, { targetWidth = 1600 } = {}) {
  const page = await pdf.getPage(pageNum);
  const base = page.getViewport({ scale: 1 });
  const scale = Math.max(1, targetWidth / base.width);
  const viewport = page.getViewport({ scale });
  const canvas = document.createElement('canvas');
  canvas.width = Math.floor(viewport.width);
  canvas.height = Math.floor(viewport.height);
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  await page.render({ canvasContext: ctx, viewport }).promise;
  return canvas;
}

/**
 * Crée un worker tesseract.js entièrement auto-hébergé (rien ne sort du
 * navigateur). OEM par défaut = LSTM_ONLY → charge le core `-lstm` et la
 * traineddata `best_int` vendorisés.
 *
 * @param {string} lang code traineddata (défaut 'por')
 * @param {function} [onProgress] (m:{status,progress}) => void  (logger natif)
 * @returns {Promise<object>} worker tesseract (à terminer par le code appelant)
 */
export async function createOcrWorker(lang = 'por', onProgress) {
  return createWorker(lang, OEM.LSTM_ONLY, {
    workerPath: `${TESS_BASE}/worker.min.js`,
    // Répertoire → la lib choisit la variante WASM selon le support du
    // navigateur (relaxed-SIMD → SIMD → scalaire).
    corePath: `${TESS_BASE}/`,
    langPath: `${TESS_BASE}/lang`,
    logger: typeof onProgress === 'function' ? onProgress : undefined,
  });
}

/**
 * OCR d'une liste de canvas avec UN worker partagé.
 * @param {HTMLCanvasElement[]} canvases
 * @param {object} [opts]
 * @param {string} [opts.lang='por']
 * @param {function} [opts.onProgress] logger tesseract (status/progress)
 * @param {function} [opts.onPageDone] (index, total) => void
 * @returns {Promise<{text:string, confidence:number,
 *                    perPage:Array<{confidence:number, chars:number}>}>}
 */
export async function runOcr(canvases, { lang = 'por', onProgress, onPageDone } = {}) {
  const worker = await createOcrWorker(lang, onProgress);
  try {
    const perPage = [];
    const chunks = [];
    for (let i = 0; i < canvases.length; i += 1) {
      const { data } = await worker.recognize(canvases[i]);
      const txt = (data.text || '').trim();
      perPage.push({ confidence: data.confidence ?? 0, chars: txt.replace(/\s/g, '').length });
      if (txt) chunks.push(txt);
      if (typeof onPageDone === 'function') onPageDone(i + 1, canvases.length);
    }
    // Confiance globale = moyenne pondérée par le nb de caractères reconnus
    // (une page quasi vide ne doit pas tirer la moyenne).
    const totalChars = perPage.reduce((s, p) => s + p.chars, 0);
    const confidence = totalChars
      ? perPage.reduce((s, p) => s + p.confidence * p.chars, 0) / totalChars
      : (perPage.reduce((s, p) => s + p.confidence, 0) / (perPage.length || 1));
    return { text: chunks.join('\n\n'), confidence, perPage };
  } finally {
    await worker.terminate();
  }
}

/**
 * Orchestrateur de bout en bout (P1) : fichier PDF → texte + confiance.
 * AUCUNE écriture base. Idéal pour piloter l'UI.
 *
 * @param {File|Blob} file
 * @param {object} [opts]
 * @param {string} [opts.lang='por']
 * @param {function} [opts.onStage] (stage:string, info?:object) => void
 * @param {function} [opts.onProgress] logger tesseract (status/progress 0..1)
 * @returns {Promise<{mode:'born-digital'|'ocr', text:string, confidence:number,
 *                    numPages:number, detection:object, pages?:number[]}>}
 */
export async function processPdf(file, { lang = 'por', onStage, onProgress } = {}) {
  const stage = (s, info) => { if (typeof onStage === 'function') onStage(s, info); };

  stage('reading');
  const arrayBuffer = await file.arrayBuffer();

  stage('opening');
  const pdf = await openPdf(arrayBuffer);

  try {
    const numPages = pdf.numPages;

    stage('detecting');
    const detection = await detectBornDigital(pdf);

    if (detection.bornDigital) {
      // PDF déjà-texte → on prend la couche texte, PAS d'OCR.
      stage('extracting-text', { numPages });
      const { text } = await extractAllText(pdf);
      return {
        mode: 'born-digital',
        text: text || detection.text,
        confidence: 100, // texte natif = fiable
        numPages,
        detection,
      };
    }

    // Scan-image → OCR des pages clés.
    const pages = extractKeyPages(pdf);
    stage('rasterizing', { pages });
    const canvases = [];
    for (const p of pages) {
      canvases.push(await rasterizePage(pdf, p));
    }

    stage('ocr', { pages });
    const { text, confidence, perPage } = await runOcr(canvases, {
      lang,
      onProgress,
      onPageDone: (done, total) => stage('ocr-page', { done, total }),
    });

    return { mode: 'ocr', text, confidence, numPages, detection, pages, perPage };
  } finally {
    try { pdf.destroy(); } catch { /* noop */ }
  }
}
