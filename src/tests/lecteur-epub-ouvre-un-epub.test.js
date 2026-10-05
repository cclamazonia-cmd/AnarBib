// ═══════════════════════════════════════════════════════════
// AnarBib — D6 (05/10/2026) : le lecteur EPUB ouvre un EPUB.
//
// Verdict de D6 (docs/journal/audits/AUDIT_lecteur_epub_D6_2026-10-05.md) :
// epub.js est CONSERVÉ, épinglé à 0.3.93, avec @xmldom/xmldom forcé en 0.8
// (package.json, « overrides ») ; foliate-js est le remplaçant désigné. Ce banc
// est la condition de la conservation : il construit un EPUB 3 complet
// (mimetype non compressé en tête, container, OPF, nav, deux chapitres XHTML)
// et l'ouvre avec la bibliothèque que l'application embarque — métadonnées,
// ordre de lecture, table des matières, texte d'un chapitre. Une montée de
// version qui casse l'ouverture d'un livre rougit ici, pas chez une lectrice.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import JSZip from 'jszip';
import ePub from 'epubjs';

const RACINE = path.resolve(__dirname, '../..');

async function construireEpub() {
  const zip = new JSZip();
  zip.file('mimetype', 'application/epub+zip', { compression: 'STORE' });
  zip.file('META-INF/container.xml', `<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>`);
  zip.file('OEBPS/content.opf', `<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">urn:uuid:5a1d0e6b-d6d6-4e8a-9a1b-000000000d06</dc:identifier>
    <dc:title>L’Entraide, un facteur de l’évolution</dc:title>
    <dc:creator>Pierre Kropotkine</dc:creator>
    <dc:language>fr</dc:language>
    <meta property="dcterms:modified">2026-10-05T00:00:00Z</meta>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="c1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="chap2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="c1"/><itemref idref="c2"/></spine>
</package>`);
  const page = (titre, corps) => `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="fr"><head><title>${titre}</title></head>
<body>${corps}</body></html>`;
  zip.file('OEBPS/nav.xhtml', page('Sommaire',
    '<nav epub:type="toc"><ol><li><a href="chap1.xhtml">L’entraide chez les animaux</a></li><li><a href="chap2.xhtml">L’entraide chez les humains</a></li></ol></nav>'));
  zip.file('OEBPS/chap1.xhtml', page('Chapitre I', '<h1>L’entraide chez les animaux</h1><p>La lutte pour l’existence n’est pas toute l’histoire.</p>'));
  zip.file('OEBPS/chap2.xhtml', page('Chapitre II', '<h1>L’entraide chez les humains</h1><p>Les institutions d’entraide traversent les siècles.</p>'));
  return zip.generateAsync({ type: 'arraybuffer', mimeType: 'application/epub+zip' });
}

describe('le lecteur EPUB ouvre un EPUB (D6)', () => {
  it('métadonnées, ordre de lecture, table des matières, texte d’un chapitre', async () => {
    const book = ePub(await construireEpub());
    await book.opened;
    const meta = await book.loaded.metadata;
    expect(meta.title).toBe('L’Entraide, un facteur de l’évolution');
    expect(meta.creator).toBe('Pierre Kropotkine');
    expect(meta.language).toBe('fr');

    expect(book.spine.spineItems.map((s) => s.href)).toEqual(['chap1.xhtml', 'chap2.xhtml']);

    const nav = await book.loaded.navigation;
    expect(nav.toc.map((t) => t.label.trim())).toEqual(['L’entraide chez les animaux', 'L’entraide chez les humains']);

    const section = book.spine.get(1);
    const doc = await section.load(book.load.bind(book));
    expect(doc.textContent).toContain('Les institutions d’entraide traversent les siècles.');
    book.destroy();
  });

  it('la version est épinglée, et xmldom forcé sur la ligne corrigée', () => {
    const pkg = JSON.parse(readFileSync(path.join(RACINE, 'package.json'), 'utf8'));
    expect(pkg.dependencies.epubjs).toBe('0.3.93');
    expect(pkg.overrides?.epubjs?.['@xmldom/xmldom']).toBe('^0.8.13');
    const lock = JSON.parse(readFileSync(path.join(RACINE, 'package-lock.json'), 'utf8'));
    const xmldom = lock.packages['node_modules/@xmldom/xmldom'] || lock.packages['node_modules/epubjs/node_modules/@xmldom/xmldom'];
    expect(xmldom.version.startsWith('0.8.')).toBe(true);
  });
});
