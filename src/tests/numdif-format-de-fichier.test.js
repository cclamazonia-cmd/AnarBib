// =====================================================================
// D25 (23/10/2026) — le format d'un fichier versé par la file NUMDIF
// (supabase/functions/deposit-digital-candidate/format.ts et nom.ts).
// Word et ODT sont admis, en téléchargement seulement : le format se lit au
// nom, le contenu doit porter la signature du format, et le nom final garde
// l'extension — c'est à elle que ingest.fn_digital_candidate_deposit_record
// reconnaît un document. Noms inventés : aucun contenu de source réelle.
// =====================================================================
import { describe, it, expect } from 'vitest';
import { estDocument, formatAttendu, LONGUEUR_TETE, signatureConforme } from '../../supabase/functions/deposit-digital-candidate/format.ts';
import { sanitize } from '../../supabase/functions/deposit-digital-candidate/nom.ts';

const octets = (...x) => new Uint8Array(x);
const texte = (s) => new TextEncoder().encode(s);
const PDF = texte('%PDF-1.7\n');
const ZIP = octets(0x50, 0x4b, 0x03, 0x04, 0x14, 0x00, 0x06, 0x00);
const OLE = octets(0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1);
const HTML = texte('<!DOCTYPE html>');

// la condition de la base (migration 20261023130916) : un chemin en .doc/.docx/.odt est un document
const documentPourLaBase = (chemin) => /\.(docx?|odt)$/i.test(chemin);

describe('formatAttendu — le nom décide du format', () => {
  it.each([
    ['Tekst.docx', 'docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    ['Vertaling.ODT', 'odt', 'application/vnd.oasis.opendocument.text'],
    ['oud.doc', 'doc', 'application/msword'],
    ['Scan.pdf', 'pdf', 'application/pdf'],
    ['sans-extension', 'pdf', 'application/pdf'],
    ['archive.zip', 'pdf', 'application/pdf'],
    ['', 'pdf', 'application/pdf'],
  ])('%s → %s', (nom, ext, mime) => {
    const f = formatAttendu(nom);
    expect(f.ext).toBe(ext);
    expect(f.mime).toBe(mime);
    expect(estDocument(f)).toBe(ext !== 'pdf');
  });
});

describe('signatureConforme — le contenu doit suivre le nom', () => {
  it('chaque format reconnaît sa signature', () => {
    expect(signatureConforme(formatAttendu('a.pdf'), PDF)).toBe(true);
    expect(signatureConforme(formatAttendu('a.docx'), ZIP)).toBe(true);
    expect(signatureConforme(formatAttendu('a.odt'), ZIP)).toBe(true);
    expect(signatureConforme(formatAttendu('a.doc'), OLE)).toBe(true);
  });
  it('une page web derrière un nom de document est refusée', () => {
    for (const nom of ['a.pdf', 'a.docx', 'a.odt', 'a.doc']) {
      expect(signatureConforme(formatAttendu(nom), HTML)).toBe(false);
    }
    expect(signatureConforme(formatAttendu('a.doc'), ZIP)).toBe(false);
    expect(signatureConforme(formatAttendu('a.docx'), OLE)).toBe(false);
    expect(signatureConforme(formatAttendu('a.pdf'), ZIP)).toBe(false);
  });
  it('une tête trop courte ne se juge pas encore (null), et la tête lue suffit à tous', () => {
    expect(signatureConforme(formatAttendu('a.doc'), OLE.subarray(0, 4))).toBeNull();
    expect(signatureConforme(formatAttendu('a.pdf'), octets())).toBeNull();
    for (const nom of ['a.pdf', 'a.docx', 'a.odt', 'a.doc']) {
      expect(formatAttendu(nom).signature.length).toBeLessThanOrEqual(LONGUEUR_TETE);
    }
  });
});

describe('sanitize — le nom final garde l\'extension du format', () => {
  it.each([
    ['Tekst.docx', 'docx', 'Tekst.docx'],
    ['Over de staat....odt', 'odt', 'Over_de_staat.odt'],
    ['Œuvres complètes.DOC', 'doc', '_uvres_completes.doc'],   // accents ôtés ; « Œ » n'est pas un caractère de mot
    ['Scan.pdf', 'pdf', 'Scan.pdf'],
    ['Scan.pdf', undefined, 'Scan.pdf'],
  ])('%s (%s) → %s', (nom, ext, attendu) => {
    const fin = sanitize(nom, ext);
    expect(fin).toBe(attendu);
    expect(`books/42/1760000000000_${fin}`.includes('..')).toBe(false);
  });
  it('la base reconnaît un document à son chemin, et un PDF n\'en est pas un', () => {
    for (const nom of ['Tekst.docx', 'Vertaling.odt', 'oud.doc']) {
      const f = formatAttendu(nom);
      expect(documentPourLaBase(`books/42/1760000000000_${sanitize(nom, f.ext)}`)).toBe(true);
    }
    expect(documentPourLaBase(`books/42/1760000000000_${sanitize('Scan.pdf', formatAttendu('Scan.pdf').ext)}`)).toBe(false);
  });
});
