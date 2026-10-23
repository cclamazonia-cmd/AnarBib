// =====================================================================
// D25 (23/10/2026) — un document Word/ODT se télécharge, il ne se lit pas.
// read-digital-asset (genre.ts) le dit « document » et signe l'URL en
// téléchargement sous son nom ; le lecteur a une branche « document » ; la
// notice liste les documents par la porte api.book_documents_v1 ; les six
// clés existent dans les onze langues.
// =====================================================================
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { inferViewerKind, nomDeTelechargement } from '../../supabase/functions/read-digital-asset/genre.ts';
import { LOCALE_CODES } from '../i18n/locales.js';

const racine = join(__dirname, '..', '..');
const lire = (p) => readFileSync(join(racine, p), 'utf8');

describe('inferViewerKind', () => {
  it.each([
    ['documento', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', null, 'document'],
    ['documento', null, null, 'document'],
    ['pdf_restrito', 'application/vnd.oasis.opendocument.text', null, 'document'],
    ['recurso_digital', 'application/msword', null, 'document'],
    ['pdf_publico', 'application/pdf', null, 'pdf'],
    ['link_externo', 'application/msword', 'https://exemple.org/a.doc', 'external_link'],
    ['epub', 'application/epub+zip', null, 'epub'],
    ['recurso_digital', 'application/zip', null, 'generic'],
  ])('%s / %s → %s', (rt, mt, su, attendu) => {
    expect(inferViewerKind(rt, mt, su)).toBe(attendu);
  });
});

describe('nomDeTelechargement', () => {
  it.each([
    ['books/42/1792020000000_Tekst.docx', 'Tekst.docx'],
    ['books/42/Vertaling.odt', 'Vertaling.odt'],
    ['books/42/2019_verslag.doc', '2019_verslag.doc'],   // une année n'est pas un horodatage
    ['', 'document'],
  ])('%s → %s', (chemin, attendu) => {
    expect(nomDeTelechargement(chemin)).toBe(attendu);
  });
});

describe('les écrans', () => {
  it('read-digital-asset signe en téléchargement pour un document seulement', () => {
    const src = lire('supabase/functions/read-digital-asset/index.ts');
    expect(src).toMatch(/viewerKind === "document" \? \{ download: nomDeTelechargement\(storagePath\) \} : undefined/);
  });
  it('le lecteur a sa branche document, la notice appelle la porte', () => {
    expect(lire('src/pages/public/ReaderPage.jsx')).toMatch(/viewerKind === 'document' && accessUrl/);
    const page = lire('src/pages/public/BookPage.jsx');
    expect(page).toMatch(/rpc\('book_documents_v1', \{ p_book_id: bookId \}\)/);
    expect(page).toMatch(/d\.access_granted/);
  });
  it('les six clés existent dans toutes les langues, sans valeur vide', () => {
    const cles = ['book.documents.label', 'book.documents.size', 'reader.document.title', 'reader.document.notice',
      'reader.document.download', 'error.edge.not_a_document'];
    for (const loc of LOCALE_CODES) {
      const l = JSON.parse(lire(`src/i18n/locales/${loc}.json`));
      for (const k of cles) expect(String(l[k] || '').trim(), `${loc} ${k}`).not.toBe('');
      expect(l['book.documents.size'], loc).toContain('{size}');
    }
  });
});
