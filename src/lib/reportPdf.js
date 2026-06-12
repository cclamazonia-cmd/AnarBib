// ============================================================================
// src/lib/reportPdf.js
// ============================================================================
// Génération PDF des rapports diagnostiques réseau (onglet « Rapports » de
// RedePage). Présentation pure : toutes les chaînes (titres, en-têtes de
// colonnes, libellés de pied) sont passées DÉJÀ TRADUITES par l'appelant —
// ce module ne connaît pas react-intl.
//
// `jspdf` est chargé en import DYNAMIQUE (≈200 ko) pour rester hors du chunk
// principal : il n'est tiré qu'au premier export PDF (même logique que
// src/components/account/ReaderCardSection.jsx).
//
// Limite connue : police standard Helvetica (encodage WinAnsi) → couvre le
// latin (PT/ES/FR/EN/CA/DE/NL/IT). Les caractères hors latin-1 (grec,
// espéranto ĉĝĥĵŝŭ, cyrillique) peuvent mal s'afficher ; acceptable car le
// contenu catalogue est quasi exclusivement latin.
//
// Paquet RAPPORTS-REDE — 12/06/2026.
// ============================================================================

// Mise en page A4 paysage (mm).
const LAYOUT = {
  margin: { l: 12, r: 12, t: 16, b: 14 },
  headerH: 7,
  rowH: 6,
  fontBody: 8,
  fontHeader: 8,
  fontTitle: 14,
  fontSub: 9,
};

// Tronque `text` pour tenir dans `maxW` (mm) à la police courante, avec ellipse.
function fit(doc, text, maxW) {
  if (text == null || text === '') return '';
  const s0 = String(text);
  if (doc.getTextWidth(s0) <= maxW) return s0;
  const ell = '…';
  let s = s0;
  while (s.length > 1 && doc.getTextWidth(s + ell) > maxW) s = s.slice(0, -1);
  return s + ell;
}

// Dessine une section (titre + sous-titre + table paginée). Avance les pages.
function drawSection(doc, section, ctx) {
  const { pageW, pageH, usableW, networkName } = ctx;
  const M = LAYOUT.margin;
  const { title, subtitle, columns, rows, totalLabel } = section;

  let y = M.t;
  if (networkName) {
    doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.setTextColor(120);
    doc.text(networkName, M.l, y);
  }
  y += 6;
  doc.setFont('helvetica', 'bold'); doc.setFontSize(LAYOUT.fontTitle); doc.setTextColor(20);
  doc.text(title, M.l, y);
  y += 6;
  if (subtitle) {
    doc.setFont('helvetica', 'normal'); doc.setFontSize(LAYOUT.fontSub); doc.setTextColor(90);
    const lines = doc.splitTextToSize(subtitle, usableW);
    doc.text(lines, M.l, y);
    y += lines.length * 4 + 2;
  }
  y += 2;

  // Largeurs de colonnes à partir des poids relatifs (`width`, défaut 1).
  const totalWeight = columns.reduce((s, c) => s + (c.width || 1), 0);
  const colW = columns.map((c) => ((c.width || 1) / totalWeight) * usableW);

  const drawColumnHeader = () => {
    doc.setFillColor(30, 41, 59);
    doc.rect(M.l, y, usableW, LAYOUT.headerH, 'F');
    doc.setFont('helvetica', 'bold'); doc.setFontSize(LAYOUT.fontHeader); doc.setTextColor(255);
    let x = M.l;
    columns.forEach((c, i) => {
      const right = c.align === 'right';
      const tx = right ? x + colW[i] - 2 : x + 2;
      doc.text(fit(doc, c.header, colW[i] - 4), tx, y + LAYOUT.headerH - 2, { align: right ? 'right' : 'left' });
      x += colW[i];
    });
    y += LAYOUT.headerH;
  };

  drawColumnHeader();

  doc.setFont('helvetica', 'normal'); doc.setFontSize(LAYOUT.fontBody);
  rows.forEach((row, ri) => {
    if (y + LAYOUT.rowH > pageH - M.b) {
      doc.addPage();
      y = M.t;
      doc.setFont('helvetica', 'bold'); doc.setFontSize(LAYOUT.fontTitle); doc.setTextColor(20);
      doc.text(title, M.l, y);
      y += 4;
      drawColumnHeader();
      doc.setFont('helvetica', 'normal'); doc.setFontSize(LAYOUT.fontBody);
    }
    if (ri % 2 === 0) {
      doc.setFillColor(241, 245, 249);
      doc.rect(M.l, y, usableW, LAYOUT.rowH, 'F');
    }
    doc.setTextColor(30);
    let x = M.l;
    columns.forEach((c, i) => {
      const right = c.align === 'right';
      const tx = right ? x + colW[i] - 2 : x + 2;
      const cell = row[i] == null ? '' : String(row[i]);
      doc.text(fit(doc, cell, colW[i] - 4), tx, y + LAYOUT.rowH - 1.8, { align: right ? 'right' : 'left' });
      x += colW[i];
    });
    y += LAYOUT.rowH;
  });

  if (totalLabel) {
    y += 2;
    if (y > pageH - M.b) { doc.addPage(); y = M.t; }
    doc.setFont('helvetica', 'italic'); doc.setFontSize(LAYOUT.fontBody); doc.setTextColor(90);
    doc.text(totalLabel, M.l, y);
  }
}

// Stampe le pied de page (date + pagination) sur toutes les pages, une fois le
// total connu. `labels.page(p, total)` est optionnel (défaut « p / total »).
function stampFooters(doc, { pageW, pageH }, labels) {
  const M = LAYOUT.margin;
  const total = doc.getNumberOfPages();
  for (let p = 1; p <= total; p++) {
    doc.setPage(p);
    doc.setFont('helvetica', 'normal'); doc.setFontSize(7); doc.setTextColor(130);
    const pageTxt = labels.page ? labels.page(p, total) : `${p} / ${total}`;
    doc.text(pageTxt, pageW - M.r, pageH - 6, { align: 'right' });
    if (labels.generatedAt) doc.text(labels.generatedAt, M.l, pageH - 6, { align: 'left' });
  }
}

/**
 * Génère un PDF à plusieurs sections (un rapport par section, nouvelle page
 * à chaque section). `labels` : { generatedAt?: string, page?: (p,total)=>string }.
 */
export async function generateMultiReportPdf({ filename, networkName, sections, labels = {} }) {
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const usableW = pageW - LAYOUT.margin.l - LAYOUT.margin.r;
  const ctx = { pageW, pageH, usableW, networkName };

  sections.forEach((section, i) => {
    if (i > 0) doc.addPage();
    drawSection(doc, section, ctx);
  });

  stampFooters(doc, ctx, labels);
  doc.save(filename || 'rapport.pdf');
}

/** Génère un PDF à une seule section. */
export async function generateReportPdf({ filename, networkName, title, subtitle, columns, rows, totalLabel, labels = {} }) {
  return generateMultiReportPdf({
    filename,
    networkName,
    labels,
    sections: [{ title, subtitle, columns, rows, totalLabel }],
  });
}
