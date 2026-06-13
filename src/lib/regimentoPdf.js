// ═══════════════════════════════════════════════════════════════════════════
// regimentoPdf.js — génère le « squelette de regimento » (spec onboarding §6.6).
//
// Doctrine : ce PDF n'est PAS un certificat de complétion. C'est un artefact de
// délibération collective — un point de départ à discuter en assemblée, à amender
// librement. Le wording le rend explicite (page de garde, préambule, [À DISCUTER],
// annexe « modifications collectives »).
//
// jspdf en import dynamique (≈200 ko hors chunk principal), comme reportPdf.js.
// ═══════════════════════════════════════════════════════════════════════════

const AXIS_KEYS = {
  catalog_mode: 'atelier.axis.catalog',
  circulation_mode: 'atelier.axis.circulation',
  network_mode: 'atelier.axis.network',
  governance_mode: 'atelier.axis.governance',
};

// config (optionnel) : { [voletN]: string[] } — décisions provisoires réellement
// saisies dans l'atelier (déjà localisées « Label : valeur »), imprimées sous chaque
// section concernée. Le PDF reste un point de départ : ces décisions sont marquées
// [À DISCUTER]. Si absent, sections génériques (rétrocompat).
export async function buildRegimentoPdf({ progress, axes, applicable, t, config }) {
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  const W = 210;
  const M = 20;            // marge
  const CW = W - 2 * M;    // largeur de contenu
  let y = 0;

  const libName = progress?.library_name || '—';

  const ensureSpace = (h) => { if (y + h > 285) { doc.addPage(); y = M; } };
  const heading = (txt, size = 13) => {
    ensureSpace(12);
    doc.setFont('helvetica', 'bold'); doc.setFontSize(size); doc.setTextColor(20, 20, 20);
    doc.text(txt, M, y); y += size * 0.5;
  };
  const para = (txt, size = 10) => {
    doc.setFont('helvetica', 'normal'); doc.setFontSize(size); doc.setTextColor(40, 40, 40);
    const lines = doc.splitTextToSize(txt, CW);
    lines.forEach(l => { ensureSpace(6); doc.text(l, M, y); y += size * 0.52; });
    y += 2;
  };
  const tag = (txt) => {
    doc.setFont('helvetica', 'italic'); doc.setFontSize(8); doc.setTextColor(150, 60, 55);
    ensureSpace(5); doc.text(txt, M, y); y += 5;
  };

  // ── Page de garde ──
  y = 70;
  doc.setFont('helvetica', 'bold'); doc.setFontSize(22); doc.setTextColor(20, 20, 20);
  doc.splitTextToSize(t({ id: 'atelier.pdf.title' }, { name: libName }), CW).forEach(l => { doc.text(l, M, y); y += 10; });
  y += 4;
  doc.setFont('helvetica', 'italic'); doc.setFontSize(12); doc.setTextColor(150, 60, 55);
  doc.splitTextToSize(t({ id: 'atelier.pdf.subtitle' }), CW).forEach(l => { doc.text(l, M, y); y += 7; });
  y += 10;
  doc.setFont('helvetica', 'normal'); doc.setFontSize(10); doc.setTextColor(40, 40, 40);
  doc.splitTextToSize(t({ id: 'atelier.pdf.preamble' }), CW).forEach(l => { doc.text(l, M, y); y += 5.4; });

  // ── Profil d'adoption (volet 0) ──
  doc.addPage(); y = M;
  heading(t({ id: 'atelier.pdf.profileHeading' }), 15);
  y += 2;
  Object.entries(AXIS_KEYS).forEach(([k, labelKey]) => {
    const val = axes?.[k];
    if (!val) return;
    ensureSpace(7);
    doc.setFont('helvetica', 'bold'); doc.setFontSize(10); doc.setTextColor(20, 20, 20);
    doc.text(`${t({ id: labelKey })} : `, M, y);
    doc.setFont('helvetica', 'normal'); doc.setTextColor(40, 40, 40);
    doc.text(t({ id: `atelier.axisValue.${val}` }), M + 55, y);
    y += 6;
  });
  y += 4;

  // ── Sections volets applicables ──
  (applicable || []).forEach(v => {
    if (v.regimento) return; // le volet 10 = ce document lui-même
    heading(`${t({ id: 'atelier.voletLabel' }, { n: v.n })} — ${t({ id: `atelier.${v.key}.title` })}`, 13);
    para(t({ id: `atelier.${v.key}.sub` }));
    // Décisions provisoires réellement saisies dans l'atelier (déjà localisées),
    // imprimées en puces sous la section. Elles restent [À DISCUTER].
    const entries = config?.[v.n] || [];
    entries.forEach(line => {
      doc.setFont('helvetica', 'normal'); doc.setFontSize(9.5); doc.setTextColor(55, 55, 55);
      doc.splitTextToSize(`•  ${line}`, CW - 4).forEach(l => { ensureSpace(5.4); doc.text(l, M + 4, y); y += 5; });
    });
    if (entries.length) y += 1;
    tag(t({ id: 'atelier.pdf.toDiscuss' }));
    y += 3;
  });

  // ── Annexe ──
  ensureSpace(30);
  heading(t({ id: 'atelier.pdf.annexHeading' }), 13);
  para(t({ id: 'atelier.pdf.annexBody' }));
  // lignes vides à remplir
  doc.setDrawColor(180, 180, 180);
  for (let i = 0; i < 6; i++) { ensureSpace(8); doc.line(M, y, W - M, y); y += 8; }

  // ── Pied de page sur toutes les pages ──
  const pages = doc.getNumberOfPages();
  for (let p = 1; p <= pages; p++) {
    doc.setPage(p);
    doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.setTextColor(130, 130, 130);
    doc.text(t({ id: 'atelier.pdf.footer' }), M, 292);
    doc.text(`${p} / ${pages}`, W - M, 292, { align: 'right' });
  }

  const safe = libName.replace(/[^\p{L}\p{N}]+/gu, '-').replace(/^-+|-+$/g, '').toLowerCase() || 'biblioteca';
  doc.save(`regimento-esqueleto-${safe}.pdf`);
}
