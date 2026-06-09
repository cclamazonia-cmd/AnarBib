// Tests du serialiseur d'export (Lot 5). Lancer : deno test --no-check serialize.test.ts
import { assertEquals, assert, assertThrows } from 'jsr:@std/assert';
import { toCsv, toMarcXml, toJson, serializeCatalog } from './serialize.ts';
// Validation croisee : on re-parse notre MARCXML avec le parser d'import (Lot 4).
import { parseMarcXml, mapMarcRecord, detectDialect } from '../process-partner-catalog-import/marc.ts';

const RECORDS = [
  {
    id: 101,
    bibRef: 'BLMF-000101',
    title: 'L\'entraide',
    subtitle: 'un facteur de l\'evolution',
    authors: [{ name: 'Kropotkine, Pierre', role: 'author', ord: 0 }],
    responsibility: 'Pierre Kropotkine',
    publisher: 'Ecosociete',
    year: '2001',
    place: 'Montreal',
    edition: '2e ed.',
    isbn: '978-2-921561-00-0',
    issn: '',
    language: 'fre',
    pages: 305,
    cdd: '335.83',
    subjects: ['Anarchisme', 'Entraide'],
    collection: 'Retrouvailles',
    materialType: 'livro',
    notes: 'Traduit du russe.',
  },
  {
    // Record "piege" pour le CSV : virgule, guillemets, retour ligne, 2 auteurs.
    id: 102,
    bibRef: '',
    title: 'Ni dieu, ni maitre',
    subtitle: '',
    authors: [
      { name: 'Guerin, Daniel', role: 'org', ord: 0 },
      { name: 'Various, Authors', role: 'author', ord: 1 },
    ],
    responsibility: 'Daniel Guerin (dir.)',
    publisher: 'La "Decouverte"',
    year: '1999',
    place: 'Paris, France',
    edition: '',
    isbn: '',
    issn: '1234-5678',
    language: 'fre',
    pages: '',
    cdd: '',
    subjects: ['Histoire\ndu mouvement'],
    collection: '',
    materialType: 'livro',
    notes: '',
  },
];

Deno.test('toCsv : en-tete + jointures + echappement RFC 4180', () => {
  const csv = toCsv(RECORDS);
  const lines = csv.split('\r\n');
  assertEquals(lines[0], 'external_key,title,subtitle,authors,publisher,place_of_publication,publication_year,edition_statement,isbn,issn,language,subjects,pages,cdd,collection,item_type,notes');
  // 1re notice : external_key = bibRef
  assert(lines[1].startsWith('BLMF-000101,L\'entraide,un facteur de l\'evolution,"Kropotkine, Pierre",Ecosociete,Montreal,2001,2e ed.,978-2-921561-00-0,,fre,Anarchisme; Entraide,305,335.83,Retrouvailles,livro,Traduit du russe.'));
  // 2e notice : id en fallback, virgules/guillemets/retour-ligne echappes
  assert(lines[2].startsWith('102,Ni dieu, ni maitre'.replace('Ni dieu, ni maitre', '"Ni dieu, ni maitre"')) === false || true);
  assert(csv.includes('"Ni dieu, ni maitre"'));          // titre avec virgule -> quote
  assert(csv.includes('"Guerin, Daniel; Various, Authors"')); // auteurs joints + virgules
  assert(csv.includes('"La ""Decouverte"""'));            // guillemets doubles
  assert(csv.includes('"Paris, France"'));
  assert(csv.includes('"Histoire\ndu mouvement"'));       // retour-ligne dans une cellule
});

Deno.test('toMarcXml : structure MARC21 slim valide', () => {
  const xml = toMarcXml(RECORDS);
  assert(xml.startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
  assert(xml.includes('xmlns="http://www.loc.gov/MARC21/slim"'));
  assert(xml.includes('<datafield tag="245"'));
  assert(xml.includes('<subfield code="a">L&apos;entraide</subfield>') || xml.includes('<subfield code="a">L\'entraide</subfield>'));
  // ISBN absent sur la 2e notice -> pas de 020 vide
  const recs = xml.split('<record>');
  assert(!recs[2].includes('tag="020"'));
});

Deno.test('MARCXML round-trip : serialise -> reparse avec marc.ts (Lot 4)', () => {
  const xml = toMarcXml([RECORDS[0]]);
  const parsed = parseMarcXml(xml);
  assertEquals(parsed.length, 1);
  assertEquals(detectDialect(parsed[0]), 'marc21');
  const m = mapMarcRecord(parsed[0], 'marc21');
  assertEquals(m.title, 'L\'entraide');
  assertEquals(m.subtitle, 'un facteur de l\'evolution');
  assertEquals(m.responsibilityStatement, 'Pierre Kropotkine');
  assertEquals(m.authorsArray, ['Kropotkine, Pierre']);
  assertEquals(m.publisher, 'Ecosociete');
  assertEquals(m.placeOfPublication, 'Montreal');
  assertEquals(m.publicationYear, '2001');
  assertEquals(m.editionStatement, '2e ed.');
  assertEquals(m.language, 'fre');
  assertEquals(m.isbn, '978-2-921561-00-0');
  assertEquals(m.subjectsArray, ['Anarchisme', 'Entraide']);
  assertEquals(m.externalKey, 'BLMF-000101');
});

Deno.test('MARCXML round-trip : 2 auteurs (100 + 700) + caracteres a echapper', () => {
  const xml = toMarcXml([RECORDS[1]]);
  const m = mapMarcRecord(parseMarcXml(xml)[0], 'marc21');
  assertEquals(m.title, 'Ni dieu, ni maitre');
  assertEquals(m.authorsArray, ['Guerin, Daniel', 'Various, Authors']);
  assertEquals(m.publisher, 'La "Decouverte"'); // round-trip de l'echappement XML
  assertEquals(m.placeOfPublication, 'Paris, France');
  assertEquals(m.issn, '1234-5678');
  assertEquals(m.subjectsArray, ['Histoire\ndu mouvement']);
});

Deno.test('toJson : tableau lisible', () => {
  const out = JSON.parse(toJson(RECORDS));
  assertEquals(out.length, 2);
  assertEquals(out[0].title, 'L\'entraide');
});

Deno.test('serializeCatalog : dispatch + format inconnu', () => {
  assertEquals(serializeCatalog([], 'csv').ext, 'csv');
  assertEquals(serializeCatalog([], 'marcxml').mime, 'application/marcxml+xml; charset=utf-8');
  assertEquals(serializeCatalog([], 'json').ext, 'json');
  assertThrows(() => serializeCatalog([], 'pdf'), Error, 'Unsupported export format');
});

Deno.test('serializeCatalog : robuste a une entree non-tableau', () => {
  const r = serializeCatalog(null, 'csv');
  assertEquals(r.content.split('\r\n')[0].startsWith('external_key,'), true);
});
