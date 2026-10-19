// AnarBib — protections du HTML écrit à la main (17-19/10/2026).
// src/lib/html.js : echapperHtml, urlWebSure, normaliserUrlWeb, assainirNoteHtml ;
// et son usage par l'export PDF du catalogue (src/lib/catalogOpac.js).
import { describe, it, expect, vi, afterEach } from 'vitest';
import { echapperHtml, urlWebSure, normaliserUrlWeb, assainirNoteHtml } from '@/lib/html';
import { exportPDF } from '@/lib/catalogOpac';

describe('echapperHtml', () => {
  it('neutralise les cinq caractères actifs', () => {
    expect(echapperHtml(`<img src=x onerror="a('b')">&`)).toBe('&lt;img src=x onerror=&quot;a(&#39;b&#39;)&quot;&gt;&amp;');
  });
  it('rend une chaîne vide pour null et undefined', () => {
    expect(echapperHtml(null)).toBe('');
    expect(echapperHtml(undefined)).toBe('');
  });
});

describe('urlWebSure / normaliserUrlWeb', () => {
  it('garde http et https', () => {
    expect(urlWebSure('https://exemple.org/a?b=1')).toBe('https://exemple.org/a?b=1');
    expect(urlWebSure(' http://exemple.org ')).toBe('http://exemple.org');
  });
  it('refuse les autres schémas et les caractères suspects', () => {
    for (const v of ['javascript:alert(1)', 'JAVASCRIPT://x', 'data:text/html,x', 'vbscript:x', '//exemple.org',
      'https://exemple.org/a b', 'https://exemple.org/"x', "https://exemple.org/'x", '']) {
      expect(urlWebSure(v), v).toBeNull();
    }
  });
  it('complète un domaine nu et dit les refus', () => {
    expect(normaliserUrlWeb('exemple.org')).toEqual({ ok: true, url: 'https://exemple.org' });
    expect(normaliserUrlWeb('www.exemple.org/page')).toEqual({ ok: true, url: 'https://www.exemple.org/page' });
    expect(normaliserUrlWeb('')).toEqual({ ok: true, url: null });
    expect(normaliserUrlWeb('javascript:alert(1)').ok).toBe(false);
    expect(normaliserUrlWeb('pas une adresse').ok).toBe(false);
  });
});

describe('assainirNoteHtml', () => {
  it('garde la mise en forme du texte', () => {
    const html = assainirNoteHtml('<aside epub:type="footnote"><p>Une <em>note</em> <strong>forte</strong><sup>2</sup></p></aside>');
    expect(html).toBe('<div><p>Une <em>note</em> <strong>forte</strong><sup>2</sup></p></div>');
  });
  it('retire scripts, styles, cadres, images et attributs actifs', () => {
    const html = assainirNoteHtml(
      '<p onclick="x()" style="color:red" class="c">a<img src=x onerror="alert(1)"><script>alert(2)</script>'
      + '<iframe src="https://x"></iframe><svg onload="alert(3)"><circle/></svg>b</p>');
    expect(html).toBe('<p>ab</p>');
    expect(html).not.toMatch(/on\w+=|script|iframe|svg|img|style/i);
  });
  it('ne garde que les liens http(s), ouverts à part', () => {
    const html = assainirNoteHtml('<p><a href="javascript:alert(1)">piège</a> <a href="https://exemple.org">source</a> <a href="#ret">↩</a></p>');
    expect(html).toBe('<p>piège <a href="https://exemple.org" target="_blank" rel="noopener noreferrer">source</a> ↩</p>');
  });
  it('déballe une balise inconnue sans perdre son texte, et garde lang', () => {
    expect(assainirNoteHtml('<p lang="it"><custom-x data-a="1">testo</custom-x></p>')).toBe('<p lang="it">testo</p>');
  });
  it('rend une chaîne vide pour une note vide', () => {
    expect(assainirNoteHtml('')).toBe('');
    expect(assainirNoteHtml(null)).toBe('');
  });
});

describe('exportPDF', () => {
  afterEach(() => { vi.restoreAllMocks(); });
  it('échappe les champs des notices dans la fenêtre d’impression', () => {
    let ecrit = '';
    const fenetre = { document: { write: (h) => { ecrit += h; }, close: () => {} } };
    vi.spyOn(window, 'open').mockReturnValue(fenetre);
    const t = ({ id }) => id;
    exportPDF([{ bib_ref: 'R1', titulo: '<img src=x onerror=alert(1)>', subtitulo: '"x"', autor: 'A<b>', ano: '1936', editora: '<script>e()</script>' }], t);
    expect(ecrit).toContain('&lt;img src=x onerror=alert(1)&gt;');
    expect(ecrit).toContain('&lt;script&gt;e()&lt;/script&gt;');
    expect(ecrit).not.toContain('<img src=x');
    // le seul script de la fenêtre reste celui de l'impression
    expect(ecrit.match(/<script>/g)).toHaveLength(1);
  });
});
