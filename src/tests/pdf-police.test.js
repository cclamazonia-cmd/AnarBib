// Les PDF engendrés dans le navigateur écrivent le grec, le roumain et le « œ »
// (13/10/2026). Avec la seule Helvetica de jspdf (jeu WinAnsi), une ligne qui
// portait un caractère hors du jeu sortait en octets UTF-16 bruts, illisible
// en entier : mesuré sur « Αναγνώστης », « ș ț ă », et « cœur » → « cur ».
import { describe, it, expect, vi, afterEach } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { resolve, join, basename } from 'node:path';
import { jsPDF } from 'jspdf';

const POLICES = resolve(__dirname, '../assets/fonts/pdf');
// Le symptôme : des octets de contrôle (0x00, 0x03…) dans le texte d'une ligne.
const octetsDeControle = (t) => [...t].some((c) => c.charCodeAt(0) < 0x20);

// Module rechargé à neuf à chaque test : il garde les polices en cache.
const charger = async () => { vi.resetModules(); return import('../lib/pdfPolice.js'); };

const servirLesPolices = () => vi.stubGlobal('fetch', vi.fn(async (url) => {
  const octets = readFileSync(join(POLICES, basename(String(url).split('?')[0])));
  return new Response(octets, { status: 200 });
}));

// Les chaînes littérales des opérateurs de texte « (…) Tj » — pas les octets
// de la police embarquée, qui peuvent contenir n'importe quoi.
const textesLitteraux = (pdf) => [...pdf.matchAll(/\((?:[^()\\]|\\.)*\) Tj/g)].map((m) => m[0]);

afterEach(() => { vi.unstubAllGlobals(); vi.restoreAllMocks(); });

describe('la police des PDF', () => {
  it('pose DejaVu Sans et écrit grec, roumain et œ sans octets bruts', async () => {
    servirLesPolices();
    const { poserPolicePdf, policePdf, POLICE } = await charger();
    const doc = new jsPDF({ compress: false });
    expect(await poserPolicePdf(doc)).toBe(POLICE);
    expect(policePdf(doc)).toBe(POLICE);
    for (const style of ['normal', 'bold', 'italic']) {
      doc.setFont(policePdf(doc), style);
      doc.text(`Αναγνώστης — ș ț ă — cœur (${style})`, 10, 20);
    }
    const sortie = doc.output();
    expect(sortie).toContain(`/BaseFont /${POLICE}`);
    // Le défaut : des chaînes « (␀E␀l…) Tj » en Helvetica.
    expect(textesLitteraux(sortie).filter(octetsDeControle)).toEqual([]);
    // Avec la police embarquée, le texte part en identifiants de glyphes.
    expect(sortie).toMatch(/<[0-9A-Fa-f]{8,}> Tj/);
  });

  it('témoin : en Helvetica, la même ligne sort bien en octets bruts', () => {
    const doc = new jsPDF({ compress: false });
    doc.setFont('helvetica', 'normal');
    doc.text('Αναγνώστης', 10, 20);
    expect(textesLitteraux(doc.output()).some(octetsDeControle)).toBe(true);
  });

  it('se replie sur Helvetica si la police ne se charge pas, sans empêcher le PDF', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('', { status: 404 })));
    const avertir = vi.spyOn(console, 'warn').mockImplementation(() => {});
    const { poserPolicePdf, policePdf } = await charger();
    const doc = new jsPDF();
    expect(await poserPolicePdf(doc)).toBe('helvetica');
    doc.setFont(policePdf(doc), 'bold');
    doc.text('Rapport', 10, 10);
    expect(doc.output().length).toBeGreaterThan(100);
    expect(avertir).toHaveBeenCalled();
  });

  it("aucun générateur n'écrit en Helvetica en dur", () => {
    const fautes = [];
    const parcourir = (dir) => {
      for (const n of readdirSync(dir)) {
        const p = join(dir, n);
        if (statSync(p).isDirectory()) { if (n !== 'tests') parcourir(p); continue; }
        if (!/\.(js|jsx)$/.test(n) || n === 'pdfPolice.js') continue;
        if (/setFont\(\s*['"]helvetica['"]/.test(readFileSync(p, 'utf8'))) fautes.push(p);
      }
    };
    parcourir(resolve(__dirname, '..'));
    expect(fautes).toEqual([]);
  });
});
